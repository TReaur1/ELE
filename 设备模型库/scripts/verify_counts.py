# -*- coding: utf-8 -*-
import os, sqlite3
BASE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DB = os.path.join(BASE, 'db', 'model.db')
OUT = os.path.join(BASE, 'output')

con = sqlite3.connect(DB)
print('=== DB 工程 ===')
for r in con.execute('SELECT name, archetype FROM project'):
    print('  ', r[0], '|', r[1])

print('=== 各工程 comm_reg / 重复检查 ===')
for (name,) in con.execute('SELECT name FROM project'):
    pid = con.execute('SELECT id FROM project WHERE name=?', (name,)).fetchone()[0]
    n = con.execute('SELECT COUNT(*) FROM comm_reg WHERE project_id=?', (pid,)).fetchone()[0]
    print('  %s: comm_reg=%d' % (name, n))

print('=== 输出 host 表行数 ===')
for name in ['virtual_project', 'seq_project']:
    p = os.path.join(OUT, name, 'VariableTable_host.csv')
    if os.path.exists(p):
        import codecs
        data = open(p, 'rb').read().decode('gbk')
        rows = [l for l in data.split('\r\n') if l.startswith(tuple('123456789'))]
        last = rows[-1].split(',')[:4] if rows else []
        print('  %s: %d 行, 末行=%s' % (name, len(rows), last))
    else:
        print('  %s: 文件不存在' % name)

con.close()
