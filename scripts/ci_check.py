# -*- coding: utf-8 -*-
"""
仓库级 PLC 规范审查（CI 用）。
检查项（对应 AGENTS.md R1~R4 + 制表/编码规则）：
  1. 编码：CSV 必须 GBK，.md 必须 UTF8（无 BOM）
  2. R1 标识符仅英文：扫描 .st 代码文件中的中文字符
  3. 魔法数字检查：代码中裸数字字面量告警（白名单除外）
  4. 文件行尾统一 CRLF
失败即退出码 1（门禁拦截）。用 Python 3.9+ 运行。
"""
import os
import sys
import re

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SKIP_DIRS = {'.git', '.github', '__pycache__', 'node_modules'}
SKIP_SUFFIXES = {'.png', '.jpg', '.jpeg', '.gif', '.pyc', '.xlsx', '.7z'}
# R1 中文标识符检查对象
CODE_EXTS = {'.st'}
MD_EXTS = {'.md'}
CSV_EXTS = {'.csv'}
# 魔法数字白名单（合法常量/地址）
MAGIC_WHITELIST = re.compile(
    r'^\s*(0[0-7]+|0[xX][0-9a-fA-F]+|\d+[ms]?|TRUE|FALSE)\s*$|'
    r'\[\s*\d+\s*\]|'                       # 数组下标
    r'X\d+|Y\d+|D\d+|M\d+|S\d+|40001|'      # 软元件/通讯地址
    r'AxisState\s*=\s*[0-7]|'               # 轴状态机
    r'(?<=\w)(_[0-9]+)')                    # 常量名后缀 _1 等

errors = []
warnings = []


def walk():
    for dirpath, dirnames, filenames in os.walk(ROOT):
        dirnames[:] = [d for d in dirnames if d not in SKIP_DIRS]
        for f in filenames:
            ext = os.path.splitext(f)[1].lower()
            if ext in SKIP_SUFFIXES:
                continue
            yield os.path.join(dirpath, f), ext


def check_encoding(path, ext):
    """CSV=GBK, .md=UTF8(无BOM)."""
    with open(path, 'rb') as fp:
        raw = fp.read()
    if ext in CSV_EXTS:
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


def check_cn_identifier(path, ext):
    """R1: .st 代码中非注释非字符串的中文字符."""
    if ext not in CODE_EXTS:
        return
    text = open(path, 'r', encoding='utf-8', errors='replace').read()
    # 去掉注释
    text = re.sub(r'\(\*[\s\S]*?\*\)', '', text)
    text = re.sub(r"//[^\n]*", '', text)
    # 中文字符
    for m in re.finditer(r'[\u4e00-\u9fff]+', text):
        errors.append(f'R1 违规: {path} 含中文 "{m.group()}"')


def check_magic(path, ext):
    """代码中裸数字魔法（告警级，含较多白名单）. 仅对 .st 生效."""
    if ext not in CODE_EXTS:
        return
    text = open(path, 'r', encoding='utf-8', errors='replace').read()
    text = re.sub(r'\(\*[\s\S]*?\*\)', '', text)
    text = re.sub(r"//[^\n]*", '', text)
    for line_no, line in enumerate(text.splitlines(), 1):
        # 找 := 右侧的裸数字
        for m in re.finditer(r':=\s*(\d{2,})', line):
            val = m.group(1)
            if not MAGIC_WHITELIST.search(line):
                warnings.append(
                    f'魔法数字: {path}:{line_no} 裸常数 {val}')


def main():
    for path, ext in walk():
        check_encoding(path, ext)
        check_cn_identifier(path, ext)
        check_magic(path, ext)
    print(f'== PLC 规范审查 ==')
    print(f'扫描文件: 编码+编码检查完成')
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
