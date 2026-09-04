# -*- coding: utf-8 -*-
"""golden 回归测试: 全工程重新生成, 逐字节比对 tests/golden/ 基准产物.

用法:
  python scripts/test_golden.py            # 比对 (模板/脚本改动后应 PASS)
  python scripts/test_golden.py --bless    # 以当前生成为基准重铸 golden (改动确认后执行)

基准覆盖: 各工程 SBR_*.st 生成物 (表/XLSX 含时间戳类内容不比对).
"""
import filecmp
import glob
import os
import shutil
import subprocess
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
BASE = os.path.dirname(HERE)
GOLDEN = os.path.join(BASE, 'tests', 'golden')
PROJECTS = ['virtual_project', 'seq_project', 'demo_seq']
sys.path.insert(0, HERE)
import generate_st  # noqa: E402  复用其 DB/OUT/模板渲染


def render_all():
    """把三工程 ST 产物渲染到临时目录, 返回 {project: {file: bytes}}."""
    import sqlite3
    con = sqlite3.connect(generate_st.DB_PATH)
    out = {}
    for proj in PROJECTS:
        ctx = generate_st.load_context(con, proj)
        import jinja2
        env = jinja2.Environment(loader=jinja2.FileSystemLoader(generate_st.TEMPLATES),
                                 trim_blocks=True, lstrip_blocks=True)
        files = {}
        for sbr in sorted(glob.glob(os.path.join(generate_st.TEMPLATES, '*', '*.st.j2'))):
            sbr_file = os.path.basename(sbr)
            try:
                name = generate_st.resolve_template(env, ctx, sbr_file)
            except FileNotFoundError:
                continue
            text = env.get_template(name).render(ctx)
            text = text.replace('\r\n', '\n').replace('\n', '\r\n')
            out_name = sbr_file[:-3]
            files[out_name] = text.encode('gbk')
        out[proj] = files
    con.close()
    return out


def main():
    bless = '--bless' in sys.argv
    cur = render_all()
    if bless:
        if os.path.isdir(GOLDEN):
            shutil.rmtree(GOLDEN)
        for proj, files in cur.items():
            os.makedirs(os.path.join(GOLDEN, proj), exist_ok=True)
            for name, data in files.items():
                with open(os.path.join(GOLDEN, proj, name), 'wb') as f:
                    f.write(data)
        print('[bless] 基准已重铸: %s (%d 工程)' % (GOLDEN, len(cur)))
        return 0
    fail = 0
    for proj, files in cur.items():
        gdir = os.path.join(GOLDEN, proj)
        if not os.path.isdir(gdir):
            print('[FAIL] 缺基准: %s (先 --bless)' % proj)
            fail += 1
            continue
        gfiles = {os.path.basename(p): p for p in glob.glob(os.path.join(gdir, '*'))}
        for name, data in sorted(files.items()):
            gp = os.path.join(gdir, name)
            if name not in gfiles:
                print('[FAIL] %s/%s 基准中不存在' % (proj, name))
                fail += 1
            elif open(gp, 'rb').read() != data:
                print('[FAIL] %s/%s 与基准不一致' % (proj, name))
                fail += 1
        for name in gfiles:
            if name not in files:
                print('[WARN] %s/%s 基准多余 (模板已删?)' % (proj, name))
    print('结果:', 'ALL PASS' if fail == 0 else '%d FAIL' % fail)
    return 0 if fail == 0 else 1


if __name__ == '__main__':
    sys.exit(main())
