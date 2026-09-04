# -*- coding: utf-8 -*-
"""ST 生成器: 用 Jinja2 从 SQLite 设备模型库生成 SBR_00~08."""
import os, sqlite3, sys
import jinja2

BASE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DB_PATH = os.path.join(BASE, 'db', 'model.db')
TEMPLATES = os.path.join(BASE, 'templates')
OUT = os.path.join(BASE, 'output')


def load_context(con, project):
    """从 DB 组装 Jinja2 上下文."""
    pid = con.execute('SELECT id FROM project WHERE name=?', (project,)).fetchone()[0]
    row = con.execute('SELECT name, plc_model, comm_proto, archetype, base_dir FROM project WHERE id=?', (pid,)).fetchone()
    p = {'name': row[0], 'plc_model': row[1], 'comm_proto': row[2], 'archetype': row[3], 'base_dir': row[4]}
    ctx = {'project': p}

    def actuator_dict(row):
        return {'kind': row[2], 'name_cn': row[3], 'eng_name': row[4], 'idx': row[5],
                'cmd_struct': row[6], 'status_struct': row[7],
                'fb_instance': row[8], 'axis_handle': row[9]}

    ctx['actuators'] = {
        'servos': [actuator_dict(r) for r in con.execute(
            'SELECT * FROM actuator WHERE project_id=? AND kind="servo" ORDER BY idx', (pid,))],
        'steppers': [actuator_dict(r) for r in con.execute(
            'SELECT * FROM actuator WHERE project_id=? AND kind="stepper" ORDER BY idx', (pid,))],
        'rollers': [actuator_dict(r) for r in con.execute(
            'SELECT * FROM actuator WHERE project_id=? AND kind="roller" ORDER BY idx', (pid,))],
    }
    ctx['comm'] = {
        'write': list(con.execute('SELECT var_name, name_cn, d_addr FROM comm_reg WHERE project_id=? AND direction="write" ORDER BY d_addr', (pid,))),
        'read': list(con.execute('SELECT var_name, name_cn, d_addr FROM comm_reg WHERE project_id=? AND direction="read" ORDER BY d_addr', (pid,))),
    }
    ctx['io'] = list(con.execute('SELECT var_name, data_type, address, comment, filter_mode FROM variable '
                                 'WHERE project_id=? AND category="io" ORDER BY rowid', (pid,)))
    ctx['consts'] = list(con.execute('SELECT name, data_type, value, comment FROM const_item WHERE project_id=? ORDER BY rowid', (pid,)))
    ctx['pos_tables'] = list(con.execute('SELECT axis_idx, pos_no, position FROM position_table WHERE project_id=? ORDER BY axis_idx, pos_no', (pid,)))
    return ctx


def resolve_template(env, ctx, sbr):
    """按原型优先 archetype/<name>/<sbr>, 否则 common/<sbr>."""
    archetype = ctx['project']['archetype']
    for prefix in ('archetype/%s' % archetype, 'common'):
        name = '%s/%s' % (prefix, sbr)
        try:
            env.loader.get_source(env, name)
            return name
        except jinja2.TemplateNotFound:
            continue
    raise FileNotFoundError('无模板: ' + sbr)


def render(ctx, env, sbr_file, out_dir):
    name = resolve_template(env, ctx, sbr_file)
    tmpl = env.get_template(name)
    text = tmpl.render(ctx)
    text = text.replace('\r\n', '\n').replace('\n', '\r\n')
    out_name = sbr_file[:-3] if sbr_file.endswith('.j2') else sbr_file   # 去掉 .j2 -> .st
    with open(os.path.join(out_dir, out_name), 'wb') as f:
        f.write(text.encode('gbk'))
    print('[gen] %s' % out_name)


def main(project=None):
    con = sqlite3.connect(DB_PATH)
    if project:
        con.execute('SELECT 1 FROM project WHERE name=?', (project,)).fetchone() or sys.exit('工程不存在')
    else:
        project = con.execute('SELECT name FROM project LIMIT 1').fetchone()[0]
    ctx = load_context(con, project)
    out_dir = os.path.join(OUT, project)
    os.makedirs(out_dir, exist_ok=True)

    env = jinja2.Environment(loader=jinja2.FileSystemLoader(TEMPLATES),
                             trim_blocks=True, lstrip_blocks=True)
    # 全部 SBR 文件 (00~08); 原型优先 archetype/<name>/ 否则 common/
    for sbr in ['SBR_00_数据类型与常量.st.j2', 'SBR_01_通用FB库.st.j2',
                'SBR_02_IO映射.st.j2', 'SBR_03_安全回路.st.j2',
                'SBR_04_模式管理.st.j2', 'SBR_05_手动控制.st.j2',
                'SBR_06_自动控制.st.j2', 'SBR_07_轴控制与输出.st.j2',
                'SBR_08_主调度.st.j2', 'SBR_host_通讯主站.st.j2',
                'SBR_status_状态呈现.st.j2']:
        if resolve_template(env, ctx, sbr) is not None:
            render(ctx, env, sbr, out_dir)
    con.close()


if __name__ == '__main__':
    main(sys.argv[1] if len(sys.argv) > 1 else None)
