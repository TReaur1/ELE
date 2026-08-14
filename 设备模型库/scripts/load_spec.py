# -*- coding: utf-8 -*-
"""设备模型库: 加载 JSON 规格单到 SQLite, 并校验一致性约束."""
import json, os, re, sqlite3, sys

BASE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DB_PATH = os.path.join(BASE, 'db', 'model.db')
SCHEMA_PATH = os.path.join(BASE, 'db', 'schema.sql')

R1_RE = re.compile(r'^[A-Za-z_][A-Za-z0-9_]*$')   # R1: 英文标识符
WIDE32 = ('REAL', 'DINT', 'DWORD', 'TIME')          # 32位: 占2个D地址


def log(msg):
    print('[load] ' + msg)


def init_db():
    """建表(不重建, 支持多工程追加). 若工程已存在则先删除该工程数据."""
    con = sqlite3.connect(DB_PATH)
    con.executescript(open(SCHEMA_PATH, encoding='utf-8').read())
    con.commit()
    return con


def check_r1(name, ctx):
    if not R1_RE.match(name):
        raise ValueError('%s 标识符 %r 不符合 R1(仅英文/数字/下划线, 不以数字开头)' % (ctx, name))


def check_comm_overlap(regs):
    """校验 32位占2地址: 检查 D 地址是否重叠."""
    used = {}  # d_addr -> 占用标签
    for r in regs:
        d = r['d_addr']
        wide = r['data_type'].upper() in WIDE32
        span = 2 if wide else 1
        for off in range(span):
            a = d + off
            if a in used:
                raise ValueError('通讯寄存器 D%d(%s) 与 D%d(%s) 重叠(32位%s占2地址)'
                                 % (d, r['name_cn'], a, used[a], r['data_type']))
            used[a] = r['name_cn']
        # 写入 modbus 地址标注
        r['_span'] = span
        r['_modbus'] = ('400%02d' % (1 + d)) if span == 1 else ('400%02d-%02d' % (1 + d, 1 + d + 1))


def load(spec_path):
    spec = json.load(open(spec_path, encoding='utf-8'))
    proj = spec['project']
    check_r1(proj['name'], '工程名')

    con = init_db()
    cur = con.cursor()

    # 若工程已存在, 先删除其数据 (级联), 再重新加载
    existing = cur.execute('SELECT id FROM project WHERE name=?', (proj['name'],)).fetchone()
    if existing:
        cur.execute('DELETE FROM project WHERE id=?', (existing[0],))
        con.commit()

    cur.execute('INSERT INTO project(name, plc_model, comm_proto, archetype, base_dir) VALUES (?,?,?,?,?)',
                (proj['name'], proj['plc_model'], proj['comm_proto'], proj['archetype'], proj.get('base_dir')))
    pid = cur.lastrowid

    for a in spec.get('actuators', []):
        for k in ('eng_name', 'cmd_struct', 'status_struct', 'fb_instance', 'axis_handle'):
            if a.get(k):
                check_r1(a[k], '执行器')
        cur.execute('INSERT INTO actuator(project_id, kind, name_cn, eng_name, idx, cmd_struct, status_struct, fb_instance, axis_handle) '
                    'VALUES (?,?,?,?,?,?,?,?,?)',
                    (pid, a['kind'], a['name_cn'], a['eng_name'], a['idx'],
                     a.get('cmd_struct'), a.get('status_struct'), a.get('fb_instance'), a.get('axis_handle')))

    # 通讯寄存器: 校验重叠
    write = spec.get('comm_write', [])
    read = spec.get('comm_read', [])
    all_regs = [dict(r, direction='write') for r in write] + [dict(r, direction='read') for r in read]
    check_comm_overlap(all_regs)
    for r in all_regs:
        check_r1(r['var_name'], '通讯变量')
        cur.execute('INSERT INTO comm_reg(project_id, direction, var_name, name_cn, data_type, d_addr, modbus_addr, comment) '
                    'VALUES (?,?,?,?,?,?,?,?)',
                    (pid, r['direction'], r['var_name'], r['name_cn'], r['data_type'], r['d_addr'], r['_modbus'], r.get('comment')))

    for v in spec.get('io', []):
        check_r1(v['var_name'], 'IO变量')
        cur.execute('INSERT INTO variable(project_id, category, var_name, data_type, address, comment, filter_mode, filter_ms) '
                    'VALUES (?,?,?,?,?,?,?,?)',
                    (pid, 'io', v['var_name'], v['data_type'], v.get('address'),
                     v.get('comment'), v.get('filter_mode', 'builtin'), v.get('filter_ms')))

    pos = spec.get('position_tables', {})
    for axis_idx, table in pos.items():
        for i, p in enumerate(table, 1):
            cur.execute('INSERT INTO position_table(project_id, axis_idx, pos_no, position) VALUES (?,?,?,?)',
                        (pid, int(axis_idx), i, float(p)))

    for c in spec.get('constants', []):
        check_r1(c['name'], '常量')
        cur.execute('INSERT INTO const_item(project_id, name, data_type, value, comment) VALUES (?,?,?,?,?)',
                    (pid, c['name'], c['data_type'], c['value'], c.get('comment')))

    con.commit()
    con.close()
    log('工程 %r 已入库: 执行器=%d 通讯寄存器=%d IO=%d 位置表=%d 常量=%d'
        % (proj['name'], len(spec.get('actuators', [])), len(all_regs),
           len(spec.get('io', [])), sum(len(t) for t in pos.values()), len(spec.get('constants', []))))
    return proj['name']


if __name__ == '__main__':
    spec_file = sys.argv[1] if len(sys.argv) > 1 else os.path.join(BASE, 'spec', 'virtual_project.json')
    load(spec_file)
