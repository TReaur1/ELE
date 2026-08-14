# -*- coding: utf-8 -*-
"""
git_sync: collab-relay 的 git 同步/推送代理
============================================
功能:
  1. 定时 fetch origin main, 检测新提交并广播到 relay 消息通道(@ALL)
  2. push 代理: 消费 relay 的 push_request 事件, 由本机(网络可用)代为 git push
     (解决 DSH 等 harness 推送通道被网络阻塞的问题)

用法:
  python git_sync.py --repo <仓库路径> [--interval 30] [--relay http://127.0.0.1:8790]
流程约定(DSH -> git_sync):
  1. DSH 在本地提交完成 -> 调 MCP 工具 git_push_proxy(agent, commit)
  2. git_sync 轮询 relay 的 push_request 事件 -> 代执行 git push origin main
  3. push 结果广播到消息通道(@ALL)
"""
import argparse
import json
import os
import subprocess
import sys
import time
import urllib.request


def _req(relay, method, path, body=None, timeout=10):
    data = json.dumps(body, ensure_ascii=False).encode('utf-8') if body is not None else None
    r = urllib.request.Request(relay + path, data=data, method=method,
                               headers={'Content-Type': 'application/json'})
    with urllib.request.urlopen(r, timeout=timeout) as resp:
        return json.loads(resp.read().decode('utf-8'))


def git(repo, *args):
    """执行 git 命令, 返回 (code, stdout)"""
    proc = subprocess.run(['git', '-C', repo, *args],
                          capture_output=True, text=True, encoding='utf-8',
                          errors='replace', timeout=60)
    return proc.returncode, proc.stdout.strip() + proc.stderr.strip()


def fetch_new(repo, relay):
    """fetch origin main, 若有新提交则广播; 返回新提交数"""
    before = git(repo, 'rev-parse', 'origin/main')[1]
    code, _ = git(repo, 'fetch', 'origin', 'main')
    if code != 0:
        return 0
    after = git(repo, 'rev-parse', 'origin/main')[1]
    if after and after != before:
        try:
            _req(relay, 'POST', '/msg', {
                'from': 'git_sync', 'to': 'ALL', 'topic': 'git',
                'body': f'远程 main 更新: {before[:8]}..{after[:8]} (请 git pull)'})
        except Exception:
            pass
        return 1
    return 0


def poll_push_requests(repo, relay, seen):
    """轮询 push_request 事件并代理推送"""
    try:
        rows = _req(relay, 'GET', '/git/push_requests')
    except Exception:
        return
    for row in rows or []:
        rid = row['id']
        if rid in seen:
            continue
        seen.add(rid)
        agent = row.get('agent', 'unknown')
        commit = row.get('commit_sha', '')
        try:
            code, out = git(repo, 'push', 'origin', 'main')
            ok = code == 0
        except Exception as e:
            ok, out = False, str(e)
        try:
            _req(relay, 'POST', '/msg', {
                'from': 'git_sync', 'to': 'ALL', 'topic': 'git',
                'body': f'[push代理] {agent} 的提交推送{"成功" if ok else "失败"}: {out[:200]}'})
        except Exception:
            pass


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--repo', default=r'C:\Users\kaanh\Documents\Default Project')
    ap.add_argument('--interval', type=int, default=30, help='fetch 间隔秒')
    ap.add_argument('--relay', default='http://127.0.0.1:8790')
    args = ap.parse_args()
    seen = set()
    print(f'[git_sync] repo={args.repo} relay={args.relay} interval={args.interval}s')
    while True:
        try:
            fetch_new(args.repo, args.relay)
            poll_push_requests(args.repo, args.relay, seen)
        except Exception as e:
            print(f'[git_sync] 循环异常: {e}', flush=True)
        time.sleep(args.interval)


if __name__ == '__main__':
    main()
