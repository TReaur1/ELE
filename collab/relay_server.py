# -*- coding: utf-8 -*-
"""
collab-relay 多 Agent 实时协作中心 (纯标准库, 零依赖)
========================================================
提供 4 个通道:
  1. 消息    /msg         (@定向/广播, 长轮询 25s 准实时)
  2. 状态    /status      (心跳 60s 判离线)
  3. 任务    /task        (open -> claim -> done -> 编排器 review, 认领互斥;
                          驳回自动回 open 重做)
  4. git 代理 /git/push, /git/sync  (解决 DSH 推送阻塞)

启动: python relay_server.py [--port 8790] [--db collab.db]
依赖: Python 3.9+, 无第三方库。
"""
import argparse
import json
import os
import sqlite3
import threading
import time
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from urllib.parse import urlparse, parse_qs

DEFAULT_PORT = 8790
HEARTBEAT_TIMEOUT = 60          # 秒, 超过判离线
LONGPOLL_TIMEOUT = 25           # 秒, 长轮询最长等待
DB_PATH = os.path.join(os.path.dirname(os.path.abspath(__file__)), 'collab.db')


def now():
    return int(time.time())


class DB:
    def __init__(self, path):
        self.conn = sqlite3.connect(path, check_same_thread=False)
        self.lock = threading.Lock()
        with self.lock:
            self.conn.executescript('''
            CREATE TABLE IF NOT EXISTS messages(
                seq INTEGER PRIMARY KEY AUTOINCREMENT,
                ts INTEGER NOT NULL,
                sender TEXT NOT NULL,
                receiver TEXT NOT NULL,   -- agent 名 或 'ALL'
                topic TEXT DEFAULT '',
                body TEXT NOT NULL
            );
            CREATE TABLE IF NOT EXISTS agents(
                name TEXT PRIMARY KEY,
                role TEXT DEFAULT '',
                state TEXT DEFAULT 'offline',
                task TEXT DEFAULT '',
                note TEXT DEFAULT '',
                heartbeat INTEGER DEFAULT 0
            );
            CREATE TABLE IF NOT EXISTS tasks(
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                title TEXT NOT NULL,
                detail TEXT DEFAULT '',
                assignee TEXT DEFAULT '',
                role TEXT DEFAULT '',       -- 任务角色: 生成/审查/测试 等, 空=任意 agent 可认领
                state TEXT DEFAULT 'open',  -- open/claimed/done
                claimed_by TEXT DEFAULT '',
                created_at INTEGER NOT NULL,
                claimed_at INTEGER DEFAULT 0,
                done_at INTEGER DEFAULT 0,
                result TEXT DEFAULT '',
                review TEXT DEFAULT '',         -- ''/approved/rejected (编排器验收)
                review_note TEXT DEFAULT '',
                reviewed_by TEXT DEFAULT '',
                reviewed_at INTEGER DEFAULT 0
            );
            CREATE TABLE IF NOT EXISTS git_events(
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                ts INTEGER NOT NULL,
                commit_sha TEXT DEFAULT '',
                agent TEXT DEFAULT '',
                action TEXT NOT NULL
            );
            ''')
            # 旧库迁移: 补齐 v1.1 新增列 (幂等)
            existing = {r[1] for r in self.conn.execute('PRAGMA table_info(tasks)').fetchall()}
            for col, ddl in [('role', 'TEXT DEFAULT ""'),
                             ('review', 'TEXT DEFAULT ""'),
                             ('review_note', 'TEXT DEFAULT ""'),
                             ('reviewed_by', 'TEXT DEFAULT ""'),
                             ('reviewed_at', 'INTEGER DEFAULT 0')]:
                if col not in existing:
                    self.conn.execute(f'ALTER TABLE tasks ADD COLUMN {col} {ddl}')
            self.conn.commit()

    def insert_msg(self, sender, receiver, topic, body):
        with self.lock:
            cur = self.conn.execute(
                'INSERT INTO messages(ts,sender,receiver,topic,body) VALUES(?,?,?,?,?)',
                (now(), sender, receiver, topic, body))
            self.conn.commit()
            return cur.lastrowid

    def msgs_since(self, receiver, since):
        with self.lock:
            rows = self.conn.execute(
                'SELECT seq,ts,sender,receiver,topic,body FROM messages '
                'WHERE seq>? AND (receiver=? OR receiver="ALL") ORDER BY seq',
                (since, receiver)).fetchall()
        return [{'seq': r[0], 'ts': r[1], 'sender': r[2], 'receiver': r[3],
                 'topic': r[4], 'body': r[5]} for r in rows]

    def last_seq(self):
        with self.lock:
            row = self.conn.execute('SELECT COALESCE(MAX(seq),0) FROM messages').fetchone()
        return row[0]

    def upsert_agent(self, name, role, state, task, note):
        with self.lock:
            self.conn.execute(
                'INSERT INTO agents(name,role,state,task,note,heartbeat) VALUES(?,?,?,?,?,?) '
                'ON CONFLICT(name) DO UPDATE SET role=?,state=?,task=?,note=?,heartbeat=?',
                (name, role, state, task, note, now(), role, state, task, note, now()))
            self.conn.commit()

    def agents(self):
        with self.lock:
            rows = self.conn.execute('SELECT * FROM agents').fetchall()
        out = []
        for r in rows:
            online = (r[5] > 0 and now() - r[5] <= HEARTBEAT_TIMEOUT)
            out.append({'name': r[0], 'role': r[1],
                        'state': r[2] if online else 'offline',
                        'task': r[3] if online else '',
                        'note': r[4] if online else '',
                        'heartbeat': r[5], 'online': online})
        return out

    def create_task(self, title, detail, assignee, role=''):
        with self.lock:
            cur = self.conn.execute(
                'INSERT INTO tasks(title,detail,assignee,role,state,created_at) VALUES(?,?,?,?,?,?)',
                (title, detail, assignee or '', role or '', 'open', now()))
            self.conn.commit()
            return cur.lastrowid

    def claim_task(self, tid, agent):
        with self.lock:
            row = self.conn.execute(
                'SELECT state,claimed_by FROM tasks WHERE id=?', (tid,)).fetchone()
            if not row:
                return 'not_found'
            if row[0] == 'claimed':
                return 'already_claimed:' + (row[1] or '')
            if row[0] == 'done':
                return 'already_done'
            self.conn.execute(
                'UPDATE tasks SET state="claimed",claimed_by=?,claimed_at=? WHERE id=?',
                (agent, now(), tid))
            self.conn.commit()
            return 'ok'

    def done_task(self, tid, agent, result):
        with self.lock:
            row = self.conn.execute(
                'SELECT state,claimed_by FROM tasks WHERE id=?', (tid,)).fetchone()
            if not row:
                return 'not_found'
            if row[0] == 'open':
                return 'not_claimed'
            self.conn.execute(
                'UPDATE tasks SET state="done",done_at=?,result=? WHERE id=?',
                (now(), result or '', tid))
            self.conn.commit()
            return 'ok'

    def review_task(self, tid, agent, approved, note):
        """编排器验收: approved=通过归档; rejected=打回重做(回 open, 保留驳回意见)"""
        with self.lock:
            row = self.conn.execute(
                'SELECT state FROM tasks WHERE id=?', (tid,)).fetchone()
            if not row:
                return 'not_found'
            if row[0] != 'done':
                return 'not_done:' + row[0]
            new_state = 'done' if approved else 'open'
            self.conn.execute(
                'UPDATE tasks SET state=?,review=?,review_note=?,reviewed_by=?,reviewed_at=? '
                'WHERE id=?',
                (new_state, 'approved' if approved else 'rejected', note or '',
                 agent or '', now(), tid))
            self.conn.commit()
            return 'ok' if approved else 'rejected'

    def tasks(self, state=None):
        cols = ('id,title,detail,assignee,role,state,claimed_by,created_at,'
                'claimed_at,done_at,result,review,review_note,reviewed_by,reviewed_at')
        with self.lock:
            if state:
                rows = self.conn.execute(
                    f'SELECT {cols} FROM tasks WHERE state=? ORDER BY id DESC', (state,)).fetchall()
            else:
                rows = self.conn.execute(f'SELECT {cols} FROM tasks ORDER BY id DESC').fetchall()
        return [{'id': r[0], 'title': r[1], 'detail': r[2], 'assignee': r[3],
                 'role': r[4], 'state': r[5], 'claimed_by': r[6], 'created_at': r[7],
                 'claimed_at': r[8], 'done_at': r[9], 'result': r[10],
                 'review': r[11], 'review_note': r[12],
                 'reviewed_by': r[13], 'reviewed_at': r[14]} for r in rows]

    def add_git_event(self, action, agent, commit):
        with self.lock:
            self.conn.execute(
                'INSERT INTO git_events(ts,commit_sha,agent,action) VALUES(?,?,?,?)',
                (now(), commit or '', agent or '', action))
            self.conn.commit()

    def git_push_requests(self):
        with self.lock:
            rows = self.conn.execute(
                "SELECT id,ts,commit_sha,agent FROM git_events "
                "WHERE action='push_request' ORDER BY id").fetchall()
        return [{'id': r[0], 'ts': r[1], 'commit_sha': r[2], 'agent': r[3]}
                for r in rows]


class Handler(BaseHTTPRequestHandler):
    db = None

    def _send(self, code, obj):
        data = json.dumps(obj, ensure_ascii=False).encode('utf-8')
        self.send_response(code)
        self.send_header('Content-Type', 'application/json; charset=utf-8')
        self.send_header('Content-Length', str(len(data)))
        self.end_headers()
        self.wfile.write(data)

    def _body(self):
        length = int(self.headers.get('Content-Length') or 0)
        if length == 0:
            return {}
        raw = self.rfile.read(length).decode('utf-8', errors='replace')
        try:
            return json.loads(raw)
        except json.JSONDecodeError:
            return {}

    def do_GET(self):
        p = urlparse(self.path)
        q = parse_qs(p.query)
        if p.path == '/health':
            return self._send(200, {'ok': True, 'ts': now()})
        if p.path == '/msg':
            receiver = (q.get('to') or ['ALL'])[0]
            since = int((q.get('since') or ['0'])[0])
            wait = (q.get('wait') or ['1'])[0]
            if wait == '0':  # 短轮询: 立即返回 (供后台守护/脚本)
                msgs = self.db.msgs_since(receiver, since)
                return self._send(200, {'messages': msgs, 'latest': self.db.last_seq()})
            # 长轮询: 最多等待 LONGPOLL_TIMEOUT 秒
            deadline = time.time() + LONGPOLL_TIMEOUT
            while True:
                msgs = self.db.msgs_since(receiver, since)
                if msgs:
                    return self._send(200, {'messages': msgs, 'latest': msgs[-1]['seq']})
                if time.time() >= deadline:
                    return self._send(200, {'messages': [], 'latest': self.db.last_seq()})
                time.sleep(0.5)
        if p.path == '/status':
            return self._send(200, {'agents': self.db.agents()})
        if p.path == '/task':
            state = (q.get('state') or [''])[0] or None
            return self._send(200, {'tasks': self.db.tasks(state)})
        if p.path == '/git/push_requests':
            return self._send(200, self.db.git_push_requests())
        return self._send(404, {'error': 'not found'})

    def do_POST(self):
        p = urlparse(self.path)
        b = self._body()
        if p.path == '/msg':
            sender = b.get('from', 'unknown')
            receiver = b.get('to', 'ALL')
            topic = b.get('topic', '')
            body = b.get('body', '')
            if not body:
                return self._send(400, {'error': 'body required'})
            seq = self.db.insert_msg(sender, receiver, topic, body)
            return self._send(200, {'seq': seq})
        if p.path == '/status':
            name = b.get('agent') or b.get('name')
            if not name:
                return self._send(400, {'error': 'agent required'})
            self.db.upsert_agent(name, b.get('role', ''), b.get('state', 'idle'),
                                 b.get('task', ''), b.get('note', ''))
            return self._send(200, {'ok': True})
        if p.path == '/task':
            title = b.get('title', '')
            if not title:
                return self._send(400, {'error': 'title required'})
            tid = self.db.create_task(title, b.get('detail', ''), b.get('assignee', ''),
                                      b.get('role', ''))
            return self._send(200, {'task_id': tid})
        if p.path == '/task/claim':
            tid = b.get('task_id')
            agent = b.get('agent', '')
            if tid is None:
                return self._send(400, {'error': 'task_id required'})
            return self._send(200, {'result': self.db.claim_task(int(tid), agent)})
        if p.path == '/task/done':
            tid = b.get('task_id')
            agent = b.get('agent', '')
            if tid is None:
                return self._send(400, {'error': 'task_id required'})
            return self._send(200, {'result': self.db.done_task(int(tid), agent, b.get('result', ''))})
        if p.path == '/task/review':
            # 编排器验收: {task_id, agent, approved, note}; 驳回则任务回 open 可重做
            tid = b.get('task_id')
            if tid is None:
                return self._send(400, {'error': 'task_id required'})
            result = self.db.review_task(int(tid), b.get('agent', ''),
                                         bool(b.get('approved')), b.get('note', ''))
            return self._send(200, {'result': result})
        if p.path == '/git/push':
            # push 代理: 由 git_sync.py 侧实际执行, 这里记录事件
            self.db.add_git_event('push_request', b.get('agent', ''), b.get('commit', ''))
            return self._send(200, {'result': 'recorded'})
        if p.path == '/git/sync':
            self.db.add_git_event('sync_request', b.get('agent', ''), '')
            return self._send(200, {'result': 'recorded'})
        return self._send(404, {'error': 'not found'})

    def log_message(self, *args):
        pass


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--port', type=int, default=DEFAULT_PORT)
    ap.add_argument('--db', default=DB_PATH)
    args = ap.parse_args()
    Handler.db = DB(args.db)
    srv = ThreadingHTTPServer(('127.0.0.1', args.port), Handler)
    print(f'[collab-relay] 启动于 http://127.0.0.1:{args.port}  db={args.db}')
    try:
        srv.serve_forever()
    except KeyboardInterrupt:
        print('\n[collab-relay] 已停止')


if __name__ == '__main__':
    main()
