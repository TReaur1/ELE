# -*- coding: utf-8 -*-
"""一键生成 + 审查.
用法: python scripts/generate.py <project>
流程: 加载规格单 -> 生成表格 -> 生成ST -> 审查ST
若审查发现未声明符号/R1违规, 返回非0退出码.
"""
import os, subprocess, sys

BASE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))


def run(script, *args):
    r = subprocess.run([sys.executable, os.path.join(BASE, 'scripts', script)] + list(args),
                       capture_output=True, text=True, encoding='gbk', errors='replace')
    for line in (r.stdout or '').splitlines():
        print(line)
    if r.returncode != 0:
        print('[error] %s 退出码=%d\n%s' % (script, r.returncode, (r.stderr or '').strip()))
        return False
    return True


def main():
    if len(sys.argv) < 2:
        print('用法: python scripts/generate.py <project>'); sys.exit(2)
    proj = sys.argv[1]
    spec = os.path.join(BASE, 'spec', proj + '.json')
    if not os.path.exists(spec):
        print('规格单不存在: %s' % spec); sys.exit(2)

    ok = True
    ok &= run('load_spec.py', spec)
    ok &= run('generate_tables.py', proj)
    ok &= run('generate_st.py', proj)
    ok &= run('review_st.py', proj)

    print('\n[%s] %s' % ('完成' if ok else '失败', proj))
    sys.exit(0 if ok else 1)


if __name__ == '__main__':
    main()
