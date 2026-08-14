# -*- coding: utf-8 -*-
import sqlite3, json, sys
db = r'C:\Users\kaanh\Documents\Default Project\collab\collab.db'
c = sqlite3.connect(db)
c.row_factory = sqlite3.Row
rows = c.execute("SELECT name FROM sqlite_master WHERE type='table'").fetchall()
print('TABLES:', [r[0] for r in rows])
for t in rows:
    name = t[0]
    if name == 'messages':
        ms = c.execute('SELECT * FROM messages ORDER BY seq DESC LIMIT 10').fetchall()
        print('--- last 10 messages ---')
        for m in ms:
            print(json.dumps(dict(m), ensure_ascii=False))
    else:
        ts = c.execute(f'SELECT * FROM {name} ORDER BY rowid').fetchall()
        print(f'--- {name} ({len(ts)} rows) ---')
        for x in ts:
            print(json.dumps(dict(x), ensure_ascii=False))
