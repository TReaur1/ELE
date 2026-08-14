# -*- coding: utf-8 -*-
"""agent_daemon 测试: notify 落盘 + auto 任务闭环"""
import json
import os
import socket
import subprocess
import sys
import time
import urllib.request

HERE = os.path.dirname(os.path.abspath(__file__))
RELAY = 'http://127.0.0.1:8791'
PORT = 8791
FLAGS = subprocess.CREATE_NO_WINDOW | subprocess.CREATE_NEW_PROCESS_GROUP


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
    r = urllib.request.Request(RELAY + path, data=data, method=method,
                               headers={'Content-Type': 'application/json'})
    with urllib.request.urlopen(r, timeout=timeout) as resp:
        return json.loads(resp.read().decode('utf-8'))


def spawn(*args):
    return subprocess.Popen([sys.executable, os.path.join(HERE, args[0]), *args[1:]],
                            creationflags=FLAGS, stdout=subprocess.DEVNULL,
                            stderr=subprocess.DEVNULL, cwd=HERE)


def main():
    db = os.path.join(HERE, 'test_daemon.db')
    inbox = os.path.join(HERE, 'test_inbox.md')
    for f in (db, inbox):
        if os.path.exists(f):
            os.remove(f)
    relay = spawn('relay_server.py', '--port', str(PORT), '--db', db)
    ok = True

    def check(name, cond, extra=''):
        nonlocal ok
        safe = extra.encode('ascii', 'replace').decode('ascii') if extra else ''
        print(f'  [{"PASS" if cond else "FAIL"}] {name} {safe}')
        if not cond:
            ok = False

    try:
        if not wait_port(PORT):
            print('relay 未就绪'); return 1
        print('=== notify 模式 ===')
        daemon = spawn('agent_daemon.py', '--relay', RELAY, '--agent', 'opencode',
                       '--mode', 'notify', '--interval', '1', '--inbox', inbox)
        time.sleep(2)
        req('POST', '/msg', {'from': 'DSH', 'to': 'opencode', 'topic': '协作', 'body': '守护进程测试消息'})
        req('POST', '/task', {'title': '守护测试任务', 'detail': '验证notify', 'assignee': 'opencode'})
        time.sleep(3)
        content = open(inbox, encoding='utf-8').read()
        check('inbox 含消息', '守护进程测试消息' in content, content[:100])
        check('inbox 含任务', '守护测试任务' in content)
        daemon.terminate()
        time.sleep(0.5)

        print('=== auto 模式 (echo 假命令验证流程) ===')
        daemon2 = spawn('agent_daemon.py', '--relay', RELAY, '--agent', 'opencode',
                        '--mode', 'auto', '--interval', '1', '--inbox', inbox,
                        '--run-cmd', 'echo {}', '--task-timeout', '60')
        time.sleep(2)
        req('POST', '/task', {'title': '自动执行任务', 'detail': '验证auto闭环', 'assignee': 'opencode'})
        time.sleep(5)
        tasks = req('GET', '/task')['tasks']
        auto = [t for t in tasks if t['title'] == '自动执行任务']
        check('auto 任务已认领并完成', auto and auto[0]['state'] == 'done' and auto[0]['claimed_by'].endswith('-daemon'),
              json.dumps(auto[0], ensure_ascii=False) if auto else 'not found')
        check('auto 任务 result 非空', auto and bool(auto[0].get('result')))
        msgs = req('GET', '/msg?to=ALL&since=0')['messages']
        broadcast = [m for m in msgs if m['sender'].endswith('-daemon') and m['topic'] == '任务']
        check('完成广播已发', len(broadcast) >= 1, json.dumps(broadcast[-1], ensure_ascii=False)[:100] if broadcast else '')
        status = req('GET', '/status')['agents']
        daemon_st = [a for a in status if a['name'].endswith('-daemon')]
        check('daemon 状态在线', bool(daemon_st) and daemon_st[0]['online'])

        daemon2.terminate()
        print()
        print('结果:', 'ALL PASS' if ok else 'HAS FAIL')
        return 0 if ok else 1
    finally:
        for p in (relay,):
            try:
                p.terminate()
            except Exception:
                pass


if __name__ == '__main__':
    sys.exit(main())
