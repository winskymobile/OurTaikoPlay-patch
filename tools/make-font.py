#!/usr/bin/env python3
"""Prepare FOT-OedKtr Std E (大江户勘亭流) for the Simplified/Traditional tables.

The game's Japanese lettering has no cmap entries for a few Traditional Chinese
forms used by UiText (啟, 戶, 內, 絕, 虛, 錄). Their Japanese variants (啓, 戸,
内, 絶, 虚, 録) are the same glyphs in this typeface, so this script adds cmap
aliases instead of mixing in a second font. The result keeps the game's own
lettering and outline weight everywhere.

    tools/make-font.py [source-tree] [source.otf] [out.otf]

Requires fontTools: python3 -m pip install fonttools
"""
import ast
import os
import re
import sys

try:
    from fontTools.ttLib import TTFont
except ImportError:
    sys.exit("fontTools is required: python3 -m pip install fonttools")

here = os.path.dirname(os.path.abspath(__file__))
src = sys.argv[1] if len(sys.argv) > 1 else os.path.join(here, "..", "..", "OurTaikoPlay")
source = sys.argv[2] if len(sys.argv) > 2 else os.path.join(
    src, "Assets/OurTaiko/Art/大江户勘亭流.otf")
out = sys.argv[3] if len(sys.argv) > 3 else os.path.join(here, "..", "FOT-OedKtrStdE.otf")

# Traditional form -> the variant this Japanese typeface actually contains.
VARIANTS = {
    "啟": "啓", "戶": "戸", "內": "内", "絕": "絶", "虛": "虚", "錄": "録",
    "強": "强", "說": "説", "眾": "衆", "專": "専", "戰": "戦", "龍": "竜",
    "圖": "図", "藝": "芸", "體": "体", "國": "国", "廣": "広", "轉": "転",
    "實": "実", "學": "学", "樂": "楽", "發": "発", "氣": "気", "關": "関",
}

ui = os.path.join(src, "Assets/OurTaiko/Runtime/Core/UiText.cs")
text = open(ui, encoding="utf-8").read()
rows = re.findall(r'\["((?:[^"\\]|\\.)*)"\]\s*=\s*Row\(((?:.|\n)*?)\),\n', text)
chars = set()
for _, args in rows:
    columns = re.findall(r'"((?:[^"\\]|\\.)*)"', args)
    if len(columns) != 4:
        continue
    for column in columns[1:3]:
        chars.update(ast.literal_eval('"' + column + '"'))
chars.update("0123456789★☆（）()・：:！!？?…—-/ ")

font = TTFont(source, fontNumber=0)
tables = [t for t in font["cmap"].tables if t.isUnicode()]
covered = set()
for table in tables:
    covered.update(table.cmap)

missing = sorted(ch for ch in chars if ord(ch) not in covered and ch not in "\n\r\t")
added = {}
for ch in missing:
    variant = VARIANTS.get(ch)
    if variant is None:
        sys.exit(f"no known Japanese variant for {ch!r} (U+{ord(ch):04X})")
    if ord(variant) not in covered:
        sys.exit(f"the typeface has neither {ch!r} nor its variant {variant!r}")
    for table in tables:
        if ord(variant) in table.cmap:
            table.cmap[ord(ch)] = table.cmap[ord(variant)]
    added[ch] = variant

font.save(out)
print("aliased " + "".join(f"{k}->{v} " for k, v in added.items()))
print("wrote", out, os.path.getsize(out), "bytes")
