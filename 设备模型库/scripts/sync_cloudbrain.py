# -*- coding: utf-8 -*-
"""cloud_brain 派生图清单 (命名空间隔离).
实体名按 工程:类型:名 命名, 避免跨工程全局名冲突.
仅打印待写入清单, 由 AI 据清单调用 cloud_brain MCP 工具执行.
用法: python scripts/sync_cloudbrain.py <project>
"""
import os, sqlite3, sys

BASE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DB_PATH = os.path.join(BASE, 'db', 'model.db')


def collect(project):
    con = sqlite3.connect(DB_PATH)
    pid = con.execute('SELECT id FROM project WHERE name=?', (project,)).fetchone()[0]
    p = con.execute('SELECT plc_model, comm_proto, archetype FROM project WHERE id=?', (pid,)).fetchone()
    ns = project  # 命名空间前缀
    entities = []
    relations = []

    entities.append(('%s:project' % ns, 'project',
                     ['PLC=%s' % p[0], 'proto=%s' % p[1], 'archetype=%s' % p[2]]))
    for r in con.execute('SELECT name_cn, kind, eng_name, idx, fb_instance, axis_handle, cmd_struct '
                         'FROM actuator WHERE project_id=? ORDER BY kind, idx', (pid,)):
        name_cn, kind, eng, idx, fb, ah, cmd = r
        e = '%s:%s_M%d_%s' % (ns, kind, idx, eng)
        entities.append((e, 'actuator', ['type=%s' % kind, 'name=%s' % name_cn, 'fb=%s' % (fb or '')]))
        if cmd:
            entities.append(('%s:cmd_%s' % (ns, cmd), 'cmd_entity', ['type=%s' % name_cn]))
            relations.append((e, 'has_command', '%s:cmd_%s' % (ns, cmd)))
        if ah:
            entities.append(('%s:axis_%s_M%d' % (ns, eng, idx), 'axis_handle', []))
            relations.append((e, 'uses_axis', '%s:axis_%s_M%d' % (ns, eng, idx)))
        # 伺服的命令/状态通讯寄存器关系
        for row in con.execute('SELECT var_name FROM comm_reg WHERE project_id=? AND var_name LIKE ? '
                               'ORDER BY d_addr', (pid, '%_' + eng + '_%')):
            reg = '%s:reg:%s' % (ns, row[0])
            entities.append((reg, 'comm_reg', []))
            relations.append((e, 'has_cmd', reg))
    # 所有通讯寄存器实体
    for r in con.execute('SELECT var_name, name_cn, direction, d_addr, data_type FROM comm_reg '
                         'WHERE project_id=? ORDER BY d_addr', (pid,)):
        var, cn, direction, d, dt = r
        entities.append(('%s:reg:%s' % (ns, var), 'comm_reg',
                         ['name=%s' % cn, 'dir=%s' % direction, 'd=%d' % d,
                          ('REAL占2地址' if dt.upper() in ('REAL', 'DINT') else '')]))
    con.close()
    return entities, relations


if __name__ == '__main__':
    project = sys.argv[1] if len(sys.argv) > 1 else 'virtual_project'
    entities, relations = collect(project)
    print('=== 实体 (%d, 命名空间前缀 %s:) ===' % (len(entities), project))
    for name, etype, obs in entities:
        print('  %s [%s] %s' % (name, etype, ' '.join(x for x in obs if x)))
    print('=== 关系 (%d) ===' % len(relations))
    for a, rel, b in relations:
        print('  %s -(%s)-> %s' % (a, rel, b))
