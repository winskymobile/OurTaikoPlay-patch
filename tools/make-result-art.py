#!/usr/bin/env python3
"""Draw the Simplified/Traditional result-board art that the patched runtime embeds.

The result board's difficulty tabs and judge labels are painted into two sprites, so the
translation table cannot reach them. This script redraws both sprites from the translations
in UiText.cs, in the game's own lettering (FOT-OedKtr Std E / 大江户勘亭流.otf), and writes
the PNGs that build-runtime-dll.sh embeds into OurTaiko.Runtime.dll.

    tools/make-result-art.py [source-tree] [output-dir]

The font is FOT-OedKtrStdE.otf next to this script, falling back to the source tree's
大江户勘亭流.otf.
"""
import os
import re
import sys
from PIL import Image, ImageDraw, ImageFilter, ImageFont

HERE = os.path.dirname(os.path.abspath(__file__))
SRC = sys.argv[1] if len(sys.argv) > 1 else os.path.join(HERE, '..', '..', 'OurTaikoPlay')
OUT = sys.argv[2] if len(sys.argv) > 2 else os.path.join(HERE, '..', 'build', 'art')

UI = os.path.join(SRC, 'Assets/OurTaiko/Runtime/Core/UiText.cs')
DIFFICULTY = os.path.join(SRC, 'Assets/OurTaiko/Art/result/score/difficulty.png')
JUDGE = os.path.join(SRC, 'Assets/OurTaiko/Art/result/score/max_combo_ja.png')
SCORE = os.path.join(SRC, 'Assets/OurTaiko/Art/result/score/score_shinuchi_ja.png')
CLEAR = os.path.join(SRC, 'Assets/OurTaiko/Art/result/gauge/clear_ja.png')
CLEAR_DARK = os.path.join(SRC, 'Assets/OurTaiko/Art/result/gauge/clear_dark_ja.png')
FONTS = [
    os.path.join(HERE, '..', 'FOT-OedKtrStdE.otf'),
    os.path.join(HERE, 'FOT-OedKtrStdE.otf'),
    os.path.join(SRC, 'Assets/OurTaiko/Art/大江户勘亭流.otf'),
]

# The fifth tab is Ura, but the shipped art labels it おに just like the fourth tab.
DIFFICULTY_KEYS = ['かんたん', 'ふつう', 'むずかしい', 'おに', 'おに(裏)']
JUDGE_KEYS = ['良', '可', '不可', '連打数', '最大コンボ数']
# Interior (white glyph) boxes measured from max_combo_ja.png; the outline sits outside them.
JUDGE_BOXES = [(15, 3, 53, 48), (15, 68, 54, 111), (14, 131, 86, 174),
               (10, 192, 129, 235), (13, 253, 211, 297)]
# The shipped tab's white glyphs sit at x=125..216 and are about 20 px tall.
TAB_LEFT = 124
TAB_HEIGHT = 22
TAB_OUTLINE = (40, 20, 10, 255)
# A plain fill column in each tab, past its old word (used to rebuild the gradient).
SAMPLE_X = [228, 210, 250, 190, 190]


def font_path():
    for path in FONTS:
        if os.path.exists(path):
            return path
    raise SystemExit('no FOT-OedKtrStdE.otf next to tools/, and no 大江户勘亭流.otf in the source tree')


def read_translations():
    text = open(UI, encoding='utf-8').read()
    rows = {}
    for key, args in re.findall(r'\["((?:[^"\\]|\\.)*)"\]\s*=\s*Row\(((?:.|\n)*?)\),\n', text):
        rows[key] = re.findall(r'"((?:[^"\\]|\\.)*)"', args)
    return rows


def ink_box(font, text):
    """Bounding box of the filled glyphs, without their outline."""
    image = Image.new('L', (font.size * (len(text) + 2), font.size * 3), 0)
    ImageDraw.Draw(image).text((font.size, font.size), text, font=font, fill=255)
    box = image.getbbox()
    return (box[0] - font.size, box[1] - font.size,
            box[2] - font.size, box[3] - font.size)


def fit(text, path, max_w, height, cap=96):
    """Largest size whose filled glyphs fit max_w and are at most `height` tall."""
    size = cap
    while size > 8:
        font = ImageFont.truetype(path, size)
        box = ink_box(font, text)
        if box[3] - box[1] <= height and box[2] - box[0] <= max_w:
            return font, box
        size -= 1
    raise SystemExit(f'cannot fit {text!r}')


def erase_tab_text(tab, sample_x):
    """Repaint the old word with the tab's own fill, leaving its border and icon alone.

    `sample_x` is a plain fill column past the word; its colour per row is the gradient the
    word area should have. Every pixel in the word column that differs from that fill (the
    white glyph and its black outline) is replaced.
    """
    px = tab.load()
    for y in range(35, 74):
        expected = px[sample_x, y]
        for x in range(118, 252):
            r, g, b, a = px[x, y]
            if a > 8 and abs(r - expected[0]) + abs(g - expected[1]) + abs(b - expected[2]) > 20:
                px[x, y] = expected



def make_difficulty(rows, language, path, out):
    sheet = Image.open(DIFFICULTY).convert('RGBA')
    result = Image.new('RGBA', sheet.size, (0, 0, 0, 0))
    for i, key in enumerate(DIFFICULTY_KEYS):
        tab = sheet.crop((i * 320, 0, (i + 1) * 320, 96))
        erase_tab_text(tab, SAMPLE_X[i])
        text = rows[key][language]
        font, ink = fit(text, path, 138, TAB_HEIGHT, cap=22)
        draw = ImageDraw.Draw(tab)
        x = TAB_LEFT - ink[0]
        y = 54 - (ink[1] + ink[3]) // 2
        draw.text((x, y), text, font=font, fill=(255, 255, 255, 255),
                  stroke_width=3, stroke_fill=TAB_OUTLINE)
        result.paste(tab, (i * 320, 0))
    result.save(out)
    print('wrote', out, result.size)


def make_caption(rows, language, path, source, key, out, rect, filled, outline,
                 stroke, glyph_height, center=False):
    """Redraw a one-word caption sprite (スコア / クリア) inside its original sprite rect."""
    sheet = Image.open(source).convert('RGBA')
    x0, y0, width, height = rect
    text = rows[key][language]
    font, ink = fit(text, path, width - 2 * stroke, glyph_height, cap=glyph_height)
    outer = font.getbbox(text, stroke_width=stroke)
    x = (width - (outer[2] - outer[0])) // 2 - outer[0] if center else -outer[0]
    y = (height - (outer[3] - outer[1])) // 2 - outer[1]
    sprite = Image.new('RGBA', (width, height), (0, 0, 0, 0))
    draw = ImageDraw.Draw(sprite)
    draw.text((x, y), text, font=font, fill=filled,
              stroke_width=stroke, stroke_fill=outline or (0, 0, 0, 255))
    image = Image.new('RGBA', sheet.size, (0, 0, 0, 0))
    image.paste(sprite, (x0, y0))
    image.save(out)
    print('wrote', out, image.size, 'sprite', rect)
    return image


def band_colors(sheet, box):
    """Top and bottom colours of a glyph, ignoring its black outline."""
    x0, y0, x1, y1 = box
    bands = {}
    for y in range(y0, y1):
        colors = []
        for x in range(x0, x1):
            r, g, b, a = sheet.getpixel((x, y))
            if a > 200 and max(r, g, b) > 90:
                colors.append((r, g, b))
        if colors:
            bands[y] = tuple(sum(c[i] for c in colors) // len(colors) for i in range(3))
    ys = sorted(bands)
    top = bands[ys[min(2, len(ys) - 1)]]
    bottom = bands[ys[max(-3, -len(ys))]]
    return top, bottom


def gradient(size, top, bottom):
    im = Image.new('RGBA', size)
    px = im.load()
    for y in range(size[1]):
        t = y / max(1, size[1] - 1)
        color = tuple(round(top[i] * (1 - t) + bottom[i] * t) for i in range(3)) + (255,)
        for x in range(size[0]):
            px[x, y] = color
    return im


def make_judge(rows, language, path, out):
    sheet = Image.open(JUDGE).convert('RGBA')
    result = Image.new('RGBA', sheet.size, (0, 0, 0, 0))
    black = Image.new('RGBA', sheet.size, (0, 0, 0, 255))
    for (box, key) in zip(JUDGE_BOXES, JUDGE_KEYS):
        x0, y0, x1, y1 = box
        text = rows[key][language]
        font, ink = fit(text, path, x1 - x0 - 8, y1 - y0 - 8, cap=44)
        outer = font.getbbox(text, stroke_width=3)
        mask = Image.new('L', sheet.size, 0)
        draw = ImageDraw.Draw(mask)
        x = x0 + 4 - outer[0]
        y = y0 + (y1 - y0 - (outer[3] - outer[1])) // 2 - outer[1]
        draw.text((x, y), text, font=font, fill=255)
        top, bottom = band_colors(sheet, box)
        fill = Image.new('RGBA', sheet.size, (0, 0, 0, 0))
        fill.paste(gradient((x1 - x0, y1 - y0), top, bottom), (x0, y0))
        outline = mask.filter(ImageFilter.MaxFilter(7))
        result.paste(black, (0, 0), outline)
        result.paste(fill, (0, 0), mask)
    result.save(out)
    print('wrote', out, result.size)


def main():
    os.makedirs(OUT, exist_ok=True)
    path = font_path()
    print('font', path)
    rows = read_translations()
    for language, suffix in ((1, 'zh'), (2, 'zh_tw')):
        make_difficulty(rows, language, path, os.path.join(OUT, f'difficulty.{suffix}.png'))
        make_judge(rows, language, path, os.path.join(OUT, f'judge.{suffix}.png'))
        make_caption(rows, language, path, SCORE, 'スコア',
                     os.path.join(OUT, f'score.{suffix}.png'),
                     (0, 0, 420, 48), (255, 255, 255, 255), None, 0, 29, True)
        make_caption(rows, language, path, CLEAR, 'クリア',
                     os.path.join(OUT, f'clear.{suffix}.png'),
                     (0, 4, 64, 31), (255, 255, 255, 255), (0, 0, 0, 255), 3, 29)
        make_caption(rows, language, path, CLEAR_DARK, 'クリア',
                     os.path.join(OUT, f'clear_dark.{suffix}.png'),
                     (0, 4, 64, 31), (144, 144, 144, 255), (32, 32, 32, 255), 3, 29)


if __name__ == '__main__':
    main()
