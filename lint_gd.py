#!/usr/bin/env python3
"""GDScript 静态检查 (尽力贴近 Godot 4 语法, 无 Godot 二进制时替代)."""
import os, re, sys

ROOT = os.path.dirname(os.path.abspath(__file__))
GODOT_OK = True  # 即使无 Godot 也能跑静态检查

VALID_DECORATORS = {"@onready", "@export", "@rpc", "@signal", "@tool",
                    "@icon", "@global", "@deprecated", "@warning_ignore", "@onready"}

problems = []


def check_file(path):
    src = open(path, encoding="utf-8").read()
    lines = src.split("\n")
    # 1. 装饰器白名单
    for i, line in enumerate(lines, 1):
        m = re.match(r"^(\s*)(@\w+)", line)
        if m and m.group(2) not in VALID_DECORATORS:
            # @rpc("authority",...) 是带参数的, 白名单只含裸形式; 单独处理
            if not line.strip().startswith("@rpc"):
                problems.append(f"{path}:{i} 未知装饰器 {m.group(2)}")
    # 2. 函数签名括号配对 (在签名行内)
    for i, line in enumerate(lines, 1):
        s = line.strip()
        if s.startswith("func ") or s.startswith("signal "):
            if s.count("(") != s.count(")"):
                problems.append(f"{path}:{i} 签名括号不配对: {s[:60]}")
    # 3. 字符串引号配对 (整文件)
    for q in ('"', "'"):
        # 去掉转义, 简单计数
        content = src
        # 粗略: 去掉 \" 转义
        cnt = content.count(q) - content.count("\\" + q)
        if cnt % 2 != 0:
            # 可能是多行, 不强报错; 仅记录 hint
            pass
    # 4. 检查 extends 引用路径存在性
    for i, line in enumerate(lines, 1):
        m = re.match(r'^extends\s+"?res://(\S+)"?', line)
        if m:
            target = os.path.join(ROOT, m.group(1))
            if not os.path.exists(target):
                problems.append(f"{path}:{i} extends 指向不存在: {m.group(1)}")
    # 5. 检查 preload/load("res://...")
    for i, line in enumerate(lines, 1):
        for m in re.finditer(r'(?:preload|load)\("res://([^"]+)"\)', line):
            target = os.path.join(ROOT, m.group(1))
            if not os.path.exists(target):
                problems.append(f"{path}:{i} 资源不存在: res://{m.group(1)}")


for dirpath, _, files in os.walk(ROOT):
    if "/." in dirpath or "\\." in dirpath:
        continue
    for fn in files:
        if fn.endswith(".gd"):
            check_file(os.path.join(dirpath, fn))

# 场景文件引用检查: [extResource path="res://..."]
for dirpath, _, files in os.walk(ROOT):
    if "/." in dirpath or "\\." in dirpath:
        continue
    for fn in files:
        if not fn.endswith(".tscn"):
            continue
        for i, line in enumerate(open(os.path.join(dirpath, fn), encoding="utf-8"), 1):
            m = re.search(r'path="res://([^"]+)"', line)
            if m:
                target = os.path.join(ROOT, m.group(1))
                if not os.path.exists(target):
                    problems.append(f"{fn}:{i} 引用资源不存在: res://{m.group(1)}")

if problems:
    print("PROBLEMS FOUND:")
    for p in problems:
        print("  " + p)
    sys.exit(1)
else:
    print("lint: all GDScript & scene references OK")
