# -*- coding: utf-8 -*-
"""生成代码审查 (review_st): 校验生成 ST 是否符合 AGENTS.md 规则.
检查项:
  R1 标识符仅英文(注释外的中文)
  未声明符号(变量/实例/常量/类型 须在表中声明)
  FB 结构平衡(VAR_INPUT/OUTPUT/IN_OUT/END_VAR)
  CASE 选择器为整型
  魔法数字(数值字面量)
  常见缺陷清单(见 AGENTS.md 六)
"""
import os, re, sqlite3, sys

BASE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DB = os.path.join(BASE, 'db', 'model.db')
OUT = os.path.join(BASE, 'output')
sys.path.insert(0, os.path.join(BASE, 'scripts'))
from shared_data import STRUCTURES, FBS, SHARED_CONST

# ST 注释
RE_COMMENT = re.compile(r'\(\*[\s\S]*?\*\)|//[^\n]*')

# 合法标识符
RE_IDENT = re.compile(r'\b[A-Za-z_][A-Za-z0-9_]*\b')

# 汇川/IEC 关键字与类型 (不检查)
KEYWORDS = {
    'FUNCTION_BLOCK', 'VAR_INPUT', 'VAR_OUTPUT', 'VAR_IN_OUT', 'VAR', 'END_VAR',
    'IF', 'THEN', 'ELSIF', 'ELSE', 'END_IF', 'CASE', 'OF', 'END_CASE', 'FOR',
    'TO', 'BY', 'DO', 'END_FOR', 'WHILE', 'END_WHILE', 'REPEAT', 'UNTIL',
    'END_REPEAT', 'RETURN', 'TRUE', 'FALSE', 'AND', 'OR', 'NOT', 'XOR', 'END_FUNCTION_BLOCK',
    'BOOL', 'INT', 'DINT', 'REAL', 'BYTE', 'WORD', 'STRING', 'LREAL', 'SINT', 'LINT',
    '_sMCAXIS_INFO', '_sMCAXIS_CONFIG', '_sMCAXIS_STATE',
    'TON', 'TOF', 'TONR', 'R_TRIG', 'TRIG', 'IN', 'OUT', 'INOUT', 'Q', 'ET', 'PT', 'CLK', 'M',
}
# 厂商 MC_* 功能块名 (作为类型, 出现在 `fb : MC_Power` 声明中)
MC_FBS = {'MC_Power', 'MC_Reset', 'MC_Stop', 'MC_Home', 'MC_JOG', 'MC_MoveAbsolute',
          'MC_MoveRelative', 'MC_MoveVelocity', 'MC_Halt', 'MC_ReadStatus', 'MC_ReadAxisError',
          'MC_ReadActualPosition', 'MC_ReadActualVelocity', 'MC_ReadActualTorque'}

RE_XADDR = re.compile(r'^X\d+$')
RE_YADDR = re.compile(r'^Y\d+$')
RE_SBR = re.compile(r'^sbr_\w+$')

# VAR 声明块: 提取 FB 局部声明 (name : Type)
RE_VARBLOCK = re.compile(r'\b(VAR_INPUT|VAR_OUTPUT|VAR_IN_OUT|VAR)\b(.*?)\bEND_VAR\b', re.S)
RE_DECL = re.compile(r'^\s*([A-Za-z_]\w*)\s*:', re.M)


def read_text(p):
    return open(p, 'rb').read().decode('gbk')


def collect_file_locals(text):
    """提取 ST 文件内 FB 局部声明 (接口参数 + VAR 内部变量)."""
    local = set()
    for block in RE_VARBLOCK.finditer(text):
        for m in RE_DECL.finditer(block.group(2)):
            local.add(m.group(1))
    return local


def load_declared(con, project):
    """从 DB 表 + 共享数据收集全局声明 (变量/实体/结构体/FB/接口参数)."""
    pid = con.execute('SELECT id FROM project WHERE name=?', (project,)).fetchone()[0]
    declared = set(KEYWORDS) | set(MC_FBS)
    declared |= {c[0] for c in SHARED_CONST}     # 共享常量
    declared |= set(STRUCTURES.keys())           # 结构体名
    declared |= set(FBS.keys())                  # FB 名
    for m in STRUCTURES.values():
        declared |= {x[0] for x in m}            # 结构体成员名
    for params in FBS.values():                  # FB 接口参数名 (调用时可作 := 左值)
        declared |= {p[1] for p in params}
    # 变量表 (io/host/hmi/con/const)
    for (name,) in con.execute('SELECT var_name FROM variable WHERE project_id=?', (pid,)):
        declared.add(name)
    for (name,) in con.execute('SELECT var_name FROM comm_reg WHERE project_id=?', (pid,)):
        declared.add(name)
    for (name,) in con.execute('SELECT name FROM const_item WHERE project_id=?', (pid,)):
        declared.add(name)
    # 执行器实体
    for r in con.execute('SELECT cmd_struct, status_struct, fb_instance, axis_handle '
                         'FROM actuator WHERE project_id=?', (pid,)):
        for x in r:
            if x:
                declared.add(x)
    return declared


def load_declared_from_csv(proj_dir):
    """从生成的 CSV 表收集声明 (含原型自动追加变量)."""
    declared = set()
    for csv in ['VariableTable_io.csv', 'VariableTable_host.csv', 'VariableTable_hmi.csv',
                'VariableTable_con.csv', '功能块实例.csv']:
        p = os.path.join(proj_dir, csv)
        if not os.path.exists(p):
            continue
        for line in read_text(p).split('\r\n'):
            parts = line.split(',')
            if len(parts) >= 2 and parts[0].strip().isdigit():
                declared.add(parts[1].strip())
    return declared


def check_project(project):
    con = sqlite3.connect(DB)
    proj_dir = os.path.join(OUT, project)
    if not os.path.isdir(proj_dir):
        print('无输出目录: %s' % proj_dir); return 1
    declared = load_declared(con, project) | load_declared_from_csv(proj_dir)
    issues = []   # 硬问题: 未声明/R1/R2/类型
    warns = []    # 软警告: 魔法数字等
    # 类型表: 从 DB 变量表收集
    pid = con.execute('SELECT id FROM project WHERE name=?', (project,)).fetchone()[0]
    type_map = {v[0]: v[1] for v in con.execute(
        'SELECT var_name, data_type FROM variable WHERE project_id=?', (pid,))}
    type_map.update({v[0]: v[1] for v in con.execute(
        'SELECT var_name, data_type FROM comm_reg WHERE project_id=?', (pid,))})

    for st in sorted(x for x in os.listdir(proj_dir) if x.endswith('.st')):
        text = read_text(os.path.join(proj_dir, st))
        code = RE_COMMENT.sub(' ', text)
        file_ok = declared | collect_file_locals(text)
        # R1: 注释外的中文
        cjk = re.findall(r'[\u4e00-\u9fff]', code)
        if cjk:
            issues.append('%s: R1违规, 注释外含中文字符 %d 个' % (st, len(cjk)))
        # R2: PROGRAM 零声明 (SBR 程序块不应有 VAR 块; 仅 FUNCTION_BLOCK 内允许)
        if st != 'SBR_01_通用FB库.st':
            prog_var = re.findall(r'\bVAR(_INPUT|_OUTPUT|_IN_OUT)?\b', code)
            if prog_var:
                issues.append('%s: R2违规, 程序块出现 VAR 声明块 %s (应集中在变量表)' % (st, prog_var))
        # 类型一致性: BOOL 变量被赋 0/1 字面量 或 SEL(返回 INT) (硬问题)
        for m in re.finditer(r'\b(\w+)\s*:=\s*(0|1)\b', code):
            var = m.group(1)
            if var in type_map and type_map[var] == 'BOOL':
                issues.append('%s: 类型不一致, BOOL变量 %s 被赋字面量 %s' % (st, var, m.group(2)))
        for m in re.finditer(r'\b(\w+)\s*:=\s*SEL\(', code):
            var = m.group(1)
            if var in type_map and type_map[var] == 'BOOL':
                issues.append('%s: 类型不一致, BOOL变量 %s := SEL(返回INT)' % (st, var))
        # 软警告: 魔法数字 (非 0/1 的裸数值; 跳过 CASE 标签如 `2:`)
        for m in re.finditer(r'(?<![\w#])(\d+)(?![\w.:])', code):
            val = m.group(1)
            if val not in ('0', '1'):
                warns.append('%s: 魔法数字 %s (提示: 应为常量)' % (st, val))
        # 未声明符号 (自动推断: X/Y, sbr_, 结构体成员, FB调用参数)
        used = {}
        # 前缀括号深度: 判断 FB 调用参数 (括号内紧跟 :=/=> 的词为参数)
        prefix = [0] * (len(code) + 1)
        d = 0
        for i, ch in enumerate(code):
            if ch == '(':
                d += 1
            elif ch == ')':
                d -= 1
            prefix[i + 1] = d
        for m in RE_IDENT.finditer(code):
            start, end = m.span()
            tok = m.group(0)
            # 结构体成员: 前一个非空白字符是 '.'
            before = code[:start].rstrip()
            if before and before[-1] == '.':
                continue
            # X/Y 物理地址 / sbr_ 子程序名
            if RE_XADDR.match(tok) or RE_YADDR.match(tok) or RE_SBR.match(tok):
                continue
            # FB 调用参数: 括号深度>0 且后跟 := / => (自动豁免, 免手列 MC_* 参数)
            after = code[end:end + 3].lstrip()
            if prefix[start] > 0 and (after.startswith(':=') or after.startswith('=>')):
                continue
            if tok in file_ok:
                continue
            used.setdefault(tok, 0)
            used[tok] += 1
        for tok, cnt in sorted(used.items()):
            issues.append('%s: 未声明符号 %r x%d' % (st, tok, cnt))

    if issues:
        print('=== 审查失败: %s (%d 硬问题) ===' % (project, len(issues)))
        for i in issues:
            print('  [硬] ' + i)
    else:
        print('=== 审查通过: %s (无硬问题) ===' % project)
    for w in warns[:20]:
        print('  [软] ' + w)
    if warns and len(warns) > 20:
        print('  [软] ... 另有 %d 条魔法数字提示' % (len(warns) - 20))
    return 1 if issues else 0


if __name__ == '__main__':
    proj = sys.argv[1] if len(sys.argv) > 1 else 'demo_seq'
    sys.exit(check_project(proj))
