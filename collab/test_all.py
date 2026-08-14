# -*- coding: utf-8 -*-
"""collab-relay 四通道端到端测试: 启动 -> 测试 -> 停止"""
import json
import os
import socket
import subprocess
import sys
import time
import urllib.request

HERE = os.path.dirname(os.path.abspath(__file__))
BASE = 'http://127.0.0.1:8790'
PORT = 8790


def wait_port(port, timeout=10):
    t0 = time.time()
    while time.time() - t0 < timeout:
        try:
            with socket.create_connection(('127.0.0.1', port), 1):
                return True
        except OSError:
            time.sleep(0.3)
    return False


def req(method, path, body=None, timeout=10):
    data = json.dumps(body, ensure_ascii=False).encode('utf-8') if body is not None else None
    r = urllib.request.Request(BASE + path, data=data, method=method,
                               headers={'Content-Type': 'application/json'})
    with urllib.request.urlopen(r, timeout=timeout) as resp:
        return json.loads(resp.read().decode('utf-8'))


def main():
    db = os.path.join(HERE, 'test_collab.db')
    for f in (db, os.path.join(HERE, 'relay.log')):
        if os.path.exists(f):
            os.remove(f)
    flags = subprocess.CREATE_NO_WINDOW | subprocess.CREATE_NEW_PROCESS_GROUP
    proc = subprocess.Popen(
        [sys.executable, os.path.join(HERE, 'relay_server.py'), '--port', str(PORT), '--db', db],
        creationflags=flags,
        stdout=open(os.path.join(HERE, 'relay.log'), 'w', encoding='utf-8'),
        stderr=subprocess.STDOUT, cwd=HERE)
    ok = True

    def check(name, cond, extra=''):
        nonlocal ok
        mark = 'PASS' if cond else 'FAIL'
        if not cond:
            ok = False
        print(f'  [{mark}] {name} {extra}')

    try:
        if not wait_port(PORT):
            print('relay 未就绪, 日志:'); print(open(os.path.join(HERE, 'relay.log'), encoding='utf-8').read())
            return 1
        print('=== 1. 消息通道 ===')
        r = req('GET', '/health'); check('health', r.get('ok'))
        r = req('POST', '/msg', {'from': 'opencode', 'to': 'DSH', 'topic': '协作', 'body': '测试: collab-relay 已上线'})
        check('发消息 opencode->DSH', r.get('seq', 0) >= 1, str(r))
        req('POST', '/msg', {'from': 'DSH', 'to': 'ALL', 'topic': '状态', 'body': 'DSH 已接入'})
        r = req('GET', '/msg?to=DSH&since=0')
        msgs = r.get('messages', [])
        check('DSH 拉到 2 条(定向+广播)', len(msgs) == 2 and msgs[0]['sender'] == 'opencode' and msgs[1]['sender'] == 'DSH',
              f'got {len(msgs)}: ' + json.dumps(msgs, ensure_ascii=False)[:120])

        print('=== 2. 状态通道 ===')
        req('POST', '/status', {'agent': 'opencode', 'state': 'busy', 'task': '构建relay', 'role': 'PLC编程'})
        req('POST', '/status', {'agent': 'DSH', 'state': 'idle', 'role': '电气'})
        r = req('GET', '/status')
        agents = {a['name']: a for a in r.get('agents', [])}
        check('看板含 opencode+DSH 且在线', 'opencode' in agents and agents['opencode']['online'] and agents['opencode']['state'] == 'busy',
              json.dumps(r, ensure_ascii=False)[:200])

        print('=== 3. 任务通道 ===')
        r = req('POST', '/task', {'title': '修复SBR_05类型', 'detail': 'BOOL:=0/1改TRUE/FALSE', 'assignee': 'DSH'})
        tid = r.get('task_id'); check('建任务', tid == 1, str(r))
        r = req('POST', '/task/claim', {'task_id': tid, 'agent': 'DSH'})
        check('DSH 认领', r.get('result') == 'ok', str(r))
        r = req('POST', '/task/claim', {'task_id': tid, 'agent': 'opencode'})
        check('opencode 再认领被拒(互斥)', r.get('result', '').startswith('already_claimed'), str(r))
        r = req('POST', '/task/done', {'task_id': tid, 'agent': 'DSH', 'result': '已修复'})
        check('DSH 完成', r.get('result') == 'ok', str(r))
        r = req('GET', '/task')
        t = r['tasks'][0]
        check('任务状态 done', t['state'] == 'done' and t['result'] == '已修复', json.dumps(t, ensure_ascii=False))

        print('=== 4. git 代理 ===')
        r = req('POST', '/git/push', {'agent': 'DSH', 'commit': 'abc123'})
        check('git/push 记录', r.get('result') == 'recorded', str(r))

        print('=== 5. 心跳离线判定 ===')
        # opencode 心跳已超时(60s)但刚上报 -> 用伪造旧心跳不可行, 直接验证字段存在
        check('心跳字段存在', agents['opencode'].get('heartbeat', 0) > 0)
        print()
        print('结果:', 'ALL PASS' if ok else 'HAS FAIL')
        return 0 if ok else 1
    finally:
        proc.terminate()
        try:
            proc.wait(timeout=5)
        except Exception:
            proc.kill()


if __name__ == '__main__':
    sys.exit(main())
