# -*- coding: utf-8 -*-
"""collab-relay 启动脚本 (Windows)
用法: python start_relay.py [--port 8790] [--db collab.db]
"""
import argparse
import os
import subprocess
import sys

HERE = os.path.dirname(os.path.abspath(__file__))


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--port', type=int, default=8790)
    ap.add_argument('--db', default='collab.db')
    args = ap.parse_args()
    log = open(os.path.join(HERE, 'relay.log'), 'a', encoding='utf-8')
    flags = subprocess.CREATE_NO_WINDOW | subprocess.CREATE_NEW_PROCESS_GROUP
    p = subprocess.Popen(
        [sys.executable, os.path.join(HERE, 'relay_server.py'),
         '--port', str(args.port), '--db', os.path.join(HERE, args.db)],
        creationflags=flags, stdout=log, stderr=subprocess.STDOUT,
        cwd=HERE)
    print(f'[start_relay] 已启动 relay PID={p.pid} port={args.port} '
          f'(日志: collab/relay.log)')


if __name__ == '__main__':
    main()
