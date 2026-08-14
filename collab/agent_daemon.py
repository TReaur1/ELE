# -*- coding: utf-8 -*-
"""
agent_daemon: collab-relay 后台常驻响应守护 (纯标准库)
=====================================================
让对话型 harness (opencode/DSH) 具备后台常驻响应能力:
  - 轮询 relay 消息通道: 定向/广播消息落盘到 inbox (notify 模式)
  - 轮询任务队列: open 任务 -> 认领 -> 执行 -> 完成 -> 广播 (auto 模式)

两种模式:
  notify (默认, 安全): 检测到 @自己/ALL 的消息与 open 任务 -> 追加写 collab/inbox_<agent>.md
                       (人工或下次会话读取; 不消耗 API, 不自动执行)
  auto   (进阶):       消息仍 notify; 任务 (assignee=自己或未指定) 自动认领并执行
                       --run-cmd (默认调用 opencode run 无人值守), 结果写回任务+广播

用法:
  python agent_daemon.py --mode notify [--agent opencode] [--interval 3]
  python agent_daemon.py --mode auto   [--run-cmd "opencode run"] [--task-timeout 600]

安全设计:
  - auto 模式只自动处理"任务"(有认领互斥, 防重复), 消息一律 notify (防自动回复循环)
  - 忽略自己发起的消息 (sender == 自身 daemon 名)
  - 一次只处理一个任务 (处理中不上报新认领)
"""
import argparse
import json
import os
import subprocess
import sys
import time
import urllib.request

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.dirname(HERE)
INBOX = os.path.join(HERE, 'inbox.md')


def _req(relay, method, path, body=None, timeout=35):
    data = json.dumps(body, ensure_ascii=False).encode('utf-8') if body is not None else None
    r = urllib.request.Request(relay + path, data=data, method=method,
                               headers={'Content-Type': 'application/json'})
    with urllib.request.urlopen(r, timeout=timeout) as resp:
        return json.loads(resp.read().decode('utf-8'))


def _now():
    return time.strftime('%Y-%m-%d %H:%M:%S')


def append_inbox(inbox, text):
    with open(inbox, 'a', encoding='utf-8') as f:
        f.write(text + '\n')


class Daemon:
    def __init__(self, relay, agent, mode, interval, inbox,
                 run_cmd, task_timeout, status_name):
        self.relay = relay
        self.agent = agent
        self.mode = mode
        self.interval = interval
        self.inbox = inbox or INBOX
        self.run_cmd = run_cmd
        self.task_timeout = task_timeout
        self.status_name = status_name or f'{agent}-daemon'
        self.last_seq = 0
        self.busy = False

    def status(self, state, task='', note=''):
        try:
            _req(self.relay, 'POST', '/status',
                 {'agent': self.status_name, 'state': state,
                  'task': task, 'role': 'background-daemon', 'note': note})
        except Exception:
            pass

    def handle_messages(self):
        """notify 模式: 新消息落盘 inbox (auto 模式同, 消息不自动回复)"""
        try:
            r = _req(self.relay, 'GET',
                     f'/msg?to={self.agent}&since={self.last_seq}&wait=0', timeout=10)
        except Exception:
            return
        for m in r.get('messages', []):
            if m['sender'] == self.status_name:
                continue
            self.last_seq = max(self.last_seq, m['seq'])
            line = f"[{_now()}] #{m['seq']} {m['sender']} -> {m['receiver']} [{m.get('topic','')}] {m.get('body','')}"
            print(line, flush=True)
            append_inbox(self.inbox, line)
        if r.get('latest', 0) > self.last_seq:
            self.last_seq = r['latest']

    def handle_tasks(self):
        """任务处理: notify=记录; auto=认领并执行"""
        if self.busy:
            return
        try:
            tasks = _req(self.relay, 'GET', '/task?state=open')['tasks']
        except Exception:
            return
        mine = [t for t in tasks
                if t['assignee'] in ('', self.agent) or t['assignee'].lower() == self.agent.lower()]
        if not mine:
            return
        task = mine[0]
        if self.mode == 'notify':
            line = f"[{_now()}] [任务#{task['id']}] {task['title']} | {task.get('detail','')} | assignee={task.get('assignee','未指定')}"
            print(line, flush=True)
            append_inbox(self.inbox, line)
            return
        # auto 模式: 认领 -> 执行 -> 完成
        try:
            claim = _req(self.relay, 'POST', '/task/claim',
                         {'task_id': task['id'], 'agent': self.status_name})
        except Exception:
            return
        if claim.get('result') != 'ok':
            return
        self.busy = True
        self.status('busy', task=f"#{task['id']} {task['title']}")
        try:
            prompt = (f"协作任务 #{task['id']}: {task['title']}\n"
                      f"详情: {task.get('detail','')}\n"
                      f"请执行并汇报结果(简短)。遵守仓库 AGENTS.md 规则。")
            done, out = self._run(prompt)
            result = out[-400:] if len(out) > 400 else out
            _req(self.relay, 'POST', '/task/done',
                 {'task_id': task['id'], 'agent': self.status_name,
                  'result': ('完成' if done else '失败') + ' | ' + result})
            _req(self.relay, 'POST', '/msg',
                 {'from': self.status_name, 'to': 'ALL', 'topic': '任务',
                  'body': f"任务#{task['id']}「{task['title']}」"
                          f"{'已完成' if done else '执行失败'}: {result[:200]}"})
        finally:
            self.busy = False
            self.status('idle')

    def _run(self, prompt):
        """执行处理命令. run_cmd 支持 {} 占位符替换 prompt; 否则把 prompt 作为参数追加."""
        try:
            if '{}' in self.run_cmd:
                cmd = self.run_cmd.replace('{}', f'"{prompt}"')
                proc = subprocess.run(cmd, shell=True, cwd=REPO, capture_output=True,
                                      text=True, encoding='utf-8', errors='replace',
                                      timeout=self.task_timeout)
            else:
                proc = subprocess.run([self.run_cmd, prompt], cwd=REPO, capture_output=True,
                                      text=True, encoding='utf-8', errors='replace',
                                      timeout=self.task_timeout)
            out = (proc.stdout or '') + (proc.stderr or '')
            return proc.returncode == 0, out.strip()
        except subprocess.TimeoutExpired:
            return False, f'执行超时(>{self.task_timeout}s)'
        except Exception as e:
            return False, str(e)

    def run(self):
        print(f'[agent_daemon] agent={self.agent} mode={self.mode} '
              f'relay={self.relay} interval={self.interval}s', flush=True)
        # 初始: 上报在线 + 初始化 last_seq
        try:
            r = _req(self.relay, 'GET', '/msg?to=ALL&since=0&wait=0', timeout=10)
            self.last_seq = r.get('latest', 0)
        except Exception:
            pass
        self.status('idle', note='daemon 运行中')
        while True:
            self.handle_messages()
            self.handle_tasks()
            time.sleep(self.interval)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--relay', default='http://127.0.0.1:8790')
    ap.add_argument('--agent', default='opencode', help='收件人 agent 名')
    ap.add_argument('--status-name', default='', help='状态看板上的名称 (默认 <agent>-daemon)')
    ap.add_argument('--mode', choices=['notify', 'auto'], default='notify')
    ap.add_argument('--interval', type=int, default=3, help='轮询间隔秒')
    ap.add_argument('--inbox', default='', help='notify 落盘文件')
    ap.add_argument('--run-cmd', default='opencode', help='auto 模式执行命令 (支持 {} 占位)')
    ap.add_argument('--task-timeout', type=int, default=600, help='任务执行超时秒')
    args = ap.parse_args()
    Daemon(args.relay, args.agent, args.mode, args.interval, args.inbox,
           args.run_cmd, args.task_timeout, args.status_name).run()


if __name__ == '__main__':
    main()
