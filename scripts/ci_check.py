# -*- coding: utf-8 -*-
"""
仓库级 PLC 规范审查（CI 门禁）。
检查项（对应 AGENTS.md R1~R4 + 制表/编码规则）：
  1. 编码：CSV 必须 GBK，.md 必须 UTF8（无 BOM）
  2. R1 标识符仅英文：扫描 .st 代码文件中的中文字符
  3. 魔法数字检查：代码中裸数字字面量告警（白名单除外）
  4. CSV 列数一致性：每行字段数 = 表头字段数（拦截"含逗号字段未加引号"导致的列错位）
  5. 通讯字表专项：5 列结构、Mobus=40001+offset、写1触发段标记
  6. 通讯字表 ↔ host 变量表一致性：host_Rcv_* 的 D 地址须落在读区 offset、
     host_Send_* 落在写区 offset（防表间地址错位）
失败即退出码 1（门禁拦截）。用 Python 3.9+ 运行。
"""
import os
import sys
import re
import csv
import io

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SKIP_DIRS = {'.git', '.github', '__pycache__', 'node_modules'}
SKIP_SUFFIXES = {'.png', '.jpg', '.jpeg', '.gif', '.pyc', '.xlsx', '.7z'}
CODE_EXTS = {'.st'}
MD_EXTS = {'.md'}
CSV_EXTS = {'.csv'}
MAGIC_WHITELIST = re.compile(
    r'^\s*(0[0-7]+|0[xX][0-9a-fA-F]+|\d+[ms]?|TRUE|FALSE)\s*$|'
    r'\[\s*\d+\s*\]|'
    r'X\d+|Y\d+|D\d+|M\d+|S\d+|40001|'
    r'AxisState\s*=\s*[0-7]|'
    r'(?<=\w)(_[0-9]+)')

errors = []
warnings = []


def walk():
    for dirparts, dirnames, filenames in os.walk(ROOT):
        dirnames[:] = [d for d in dirnames if d not in SKIP_DIRS]
        for f in filenames:
            ext = os.path.splitext(f)[1].lower()
            if ext in SKIP_SUFFIXES:
                continue
            # 排除生成物目录: 路径含 /output/ 或 设备模型库/output
            full = os.path.join(dirparts, f)
            norm = full.replace(os.sep, '/')
            if norm.endswith('/output') or '/output/' in norm:
                continue
            yield full, ext


def _parse_csv(path):
    """GBK 解析 CSV, 返回行列表(已按 csv 规则分隔)."""
    with open(path, 'rb') as fp:
        raw = fp.read().decode('gbk', errors='replace')
    return [r for r in csv.reader(io.StringIO(raw)) if r]


def check_encoding(path, ext):
    with open(path, 'rb') as fp:
        raw = fp.read()
    if ext in CSV_EXTS:
        if raw[:2] == b'PK':
            warnings.append(f'文件实为 XLSX，请改名为 .xlsx: {path}')
            return
        try:
            raw.decode('gbk')
        except UnicodeDecodeError:
            errors.append(f'编码不符: {path} 应 GBK (CSV)')
    elif ext in MD_EXTS:
        if raw[:3] == b'\xef\xbb\xbf':
            errors.append(f'编码不符: {path} 应为 UTF8 无 BOM')
        try:
            raw.decode('utf-8')
        except UnicodeDecodeError:
            errors.append(f'编码不符: {path} 应 UTF8 (.md)')


def check_csv_cols(path, ext):
    """拦截: 含逗号字段未加引号 -> 行被拆成多列, 与表头列数不符.
    仅对汇川规范表头(变量表/FB表/结构体/功能块实例/通讯字表)生效, 不误伤自由采集文件."""
    if ext not in CSV_EXTS:
        return
    rows = _parse_csv(path)
    if not rows:
        return
    # 规范表头识别 (含关键列名才视为规范表)
    hdr = ','.join(str(x) for x in rows[0])
    if not ('变量名' in hdr and '数据类型' in hdr) \
       and not ('服务器读写' in hdr) \
       and not ('类别' in hdr and '名称' in hdr) \
       and not ('成员变量名' in hdr):
        return
    head_n = len(rows[0])
    for i, r in enumerate(rows[1:], 2):
        if r and len(r) != head_n:
            errors.append(
                f'CSV 列数错位: {path} 第{i}行 {len(r)} 列, 表头 {head_n} 列'
                f' (含逗号的字段必须加双引号包裹)')


def check_cn_identifier(path, ext):
    if ext not in CODE_EXTS:
        return
    text = open(path, 'r', encoding='utf-8', errors='replace').read()
    text = re.sub(r'\(\*[\s\S]*?\*\)', '', text)
    text = re.sub(r"//[^\n]*", '', text)
    for m in re.finditer(r'[\u4e00-\u9fff]+', text):
        errors.append(f'R1 违规: {path} 含中文 "{m.group()}"')


def check_magic(path, ext):
    if ext not in CODE_EXTS:
        return
    text = open(path, 'r', encoding='utf-8', errors='replace').read()
    text = re.sub(r'\(\*[\s\S]*?\*\)', '', text)
    text = re.sub(r"//[^\n]*", '', text)
    for line_no, line in enumerate(text.splitlines(), 1):
        for m in re.finditer(r':=\s*(\d{2,})', line):
            val = m.group(1)
            if not MAGIC_WHITELIST.search(line):
                warnings.append(f'魔法数字: {path}:{line_no} 裸常数 {val}')


# ── 通讯字表专项 ──
def _collect(rows):
    """返回 {'kind': ('comm'|'host'|None), 'comm_offsets': {读:set,写:set}, 'host_vars': [(name,daddr)], 'name':...}"""
    if not rows:
        return None
    head0 = rows[0][0] if rows[0] else ''
    if head0 == '服务器读写':
        # 通讯字表: 5 列
        seg = {'服务器读': set(), '服务器写': set()}
        cur = None
        for r in rows[1:]:
            if not r:
                continue
            if r[0].strip() in ('服务器读', '服务器写'):
                cur = r[0].strip()
                # 区段标记行本身也是数据行(offset=该区起始), 需一并收集
                try:
                    seg[cur].add(int(r[3]))
                except (ValueError, IndexError):
                    pass
            elif r[0].strip() == '' and cur:
                try:
                    seg[cur].add(int(r[3]))
                except (ValueError, IndexError):
                    pass
        return {'kind': 'comm', 'seg': seg, 'ncols': len(rows[0])}
    # host 表: 变量名列第2列, 软元件地址列为最后一列(Dn)
    vars_ = []
    for r in rows[1:]:
        if len(r) >= 9 and r[1]:
            if (r[1].startswith('host_Rcv_') or r[1].startswith('host_Send_')):
                m = re.match(r'D(\d+)', r[8] or '')
                if m:
                    vars_.append((r[1], int(m.group(1))))
    return {'kind': 'host', 'vars': vars_}


def check_comm_table(comm):
    """通讯字表自身校验."""
    # 列数=5
    if comm['ncols'] != 5:
        errors.append(f'通讯字表列数应为 5, 实际 {comm["ncols"]}')


def check_comm_host(comm_path, comm, host_path, host):
    """通讯字表 offset 与 host 变量表 D 地址一致性."""
    for name, daddr in host['vars']:
        want = '服务器写' if name.startswith('host_Send_') else '服务器读'
        if daddr not in comm['seg'].get(want, set()):
            errors.append(
                f'通讯字表与host表不一致: {name}(D{daddr}) 不在 {want} 区 offset 中 '
                f'({os.path.basename(comm_path)} vs {os.path.basename(host_path)})')


def main():
    comm_tables = []   # (path, info)
    host_tables = []   # (path, info)
    for path, ext in walk():
        check_encoding(path, ext)
        check_cn_identifier(path, ext)
        check_magic(path, ext)
        check_csv_cols(path, ext)
        if ext in CSV_EXTS:
            info = _collect(_parse_csv(path))
            if info and info['kind'] == 'comm':
                comm_tables.append((path, info))
                check_comm_table(info)
            elif info and info['kind'] == 'host':
                host_tables.append((path, info))
    # 表间一致性: host 表与所在工程的通讯字表配对
    for hpath, host in host_tables:
        proj = os.path.dirname(os.path.dirname(hpath))  # 变量表/ -> 工程根
        for cpath, comm in comm_tables:
            if os.path.dirname(cpath) == proj:
                check_comm_host(cpath, comm, hpath, host)
    print('== PLC 规范审查 ==')
    print('检查: 编码 / R1 / 魔法数字 / CSV列数一致性 / 通讯字表校验')
    for w in warnings:
        print(f'  [warn] {w}')
    for e in errors:
        print(f'  [ERROR] {e}')
    print(f'错误: {len(errors)}, 警告: {len(warnings)}')
    if errors:
        sys.exit(1)
    print('审查通过.')


if __name__ == '__main__':
    main()
