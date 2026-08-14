# -*- coding: utf-8 -*-
import os
BASE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(BASE, 'output')

def read(p):
    return open(p, 'rb').read().decode('gbk')

checks = [
    ('seq_project', 'SBR_06_自动控制.st',
     ['con_Step_No', 'con_StepRun', 'con_Step_Init', 'con_Start', 'con_Stop',
      'host_Send_Start', 'host_Send_Stop', 'host_Send_Home', 'host_Rcv_Step_No', 'host_Rcv_StepRun']),
    ('seq_project', 'SBR_05_手动控制.st', ['r_StepFwd', 'con_Step_No']),
]
for proj, st_file, refs in checks:
    st = read(os.path.join(OUT, proj, st_file))
    host = read(os.path.join(OUT, proj, 'VariableTable_host.csv'))
    con = read(os.path.join(OUT, proj, 'VariableTable_con.csv'))
    inst = read(os.path.join(OUT, proj, '功能块实例.csv'))
    tables = host + con + inst
    print('=== %s/%s ===' % (proj, st_file))
    for ref in refs:
        in_st = ref in st
        declared = ref in tables
        status = 'OK' if (in_st and declared) else ('ST未用' if not in_st else '未声明!')
        print('  %s: ST引用=%s 声明=%s => %s' % (ref, in_st, declared, status))
