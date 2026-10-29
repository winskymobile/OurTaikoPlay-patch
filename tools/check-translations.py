#!/usr/bin/env python3
"""Check the UiText table before shipping a patched DLL.

Every Settings()/SettingsFormat()/InGame() key used by the settings screens must
have a table row, and every row must carry ja/zh/zh_tw/ko. Run from anywhere:

    tools/check-translations.py [source-tree]
"""
import glob
import os
import re
import sys

src = sys.argv[1] if len(sys.argv) > 1 else os.path.join(os.path.dirname(__file__), "..", "..", "OurTaikoPlay")
ui = os.path.join(src, "Assets/OurTaiko/Runtime/Core/UiText.cs")
if not os.path.exists(ui):
    sys.exit(f"no UiText.cs under {src}")

text = open(ui, encoding="utf-8").read()
rows = re.findall(r'\["((?:[^"\\]|\\.)*)"\]\s*=\s*Row\(((?:.|\n)*?)\),\n', text)
table = {}
for key, args in rows:
    columns = re.findall(r'"((?:[^"\\]|\\.)*)"', args)
    table[key] = columns

problems = []
for key, columns in table.items():
    if len(columns) != 4 or any(not c.strip() for c in columns):
        problems.append(f"row has {len(columns)} columns: {key}")

used = set()
for path in glob.glob(os.path.join(src, "Assets/OurTaiko/Runtime/**/*.cs"), recursive=True):
    body = open(path, encoding="utf-8").read()
    for call in ("Settings", "SettingsFormat", "InGame"):
        for key in re.findall(rf'{call}\("((?:[^"\\]|\\.)*)"', body):
            used.add(key)

for key in sorted(used):
    if key not in table:
        problems.append(f"no translation for: {key!r}")

for key in sorted(table):
    if len(re.findall(r"\{\d\}", key)) and key not in used:
        problems.append(f"placeholder key never used: {key!r}")

print(f"{len(table)} rows, {len(used)} keys used by the runtime")
if problems:
    print("\n".join("  " + p for p in problems))
    sys.exit(1)
print("translations OK")
