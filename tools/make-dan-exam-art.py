#!/usr/bin/env python3
"""Draw the Simplified/Traditional 段位道場 exam art the patched runtime embeds.

The exam conditions are painted into sprites, so the translation table cannot reach them:
the eight condition labels (dan_select and dan_result share one set, the in-play panel has
its own), the 合格条件 header, and the 以上/未満 badges. This script redraws them in the
game's own lettering (FOT-OedKtrStdE.otf), keeping each original's size, left edge and
glyph height, and writes the PNGs build-runtime-dll.sh embeds into OurTaiko.Runtime.dll.

    tools/make-dan-exam-art.py [source-tree] [output-dir]
"""
import os
import sys
from PIL import Image, ImageDraw, ImageFont

HERE = os.path.dirname(os.path.abspath(__file__))
SRC = sys.argv[1] if len(sys.argv) > 1 else os.path.join(HERE, '..', '..', 'OurTaikoPlay')
OUT = sys.argv[2] if len(sys.argv) > 2 else os.path.join(HERE, '..', 'build', 'art')
ART = os.path.join(SRC, 'Assets/OurTaiko/Art')
FONTS = [
    os.path.join(HERE, '..', 'FOT-OedKtrStdE.otf'),
    os.path.join(HERE, 'FOT-OedKtrStdE.otf'),
    os.path.join(SRC, 'Assets/OurTaiko/Art/大江户勘亭流.otf'),
]
INK = (255, 255, 255, 255)
OUTLINE = (80, 60, 45, 255)

# DanExamType order: gauge, good, ok, bad, hits, score, combo, rolls.
LABELS = {
    'gauge': ('魂ゲージ', '魂槽', '魂槽'),
    'judgeperfect': ('良の数', '良数', '良數'),
    'judgegood': ('可の数', '可数', '可數'),
    'judgebad': ('不可の数', '不可数', '不可數'),
    'hit': ('叩けた数', '击中数', '擊中數'),
    'score': ('スコア', '得分', '得分'),
    'combo': ('最大コンボ数', '最大连击数', '最大連擊數'),
    'roll': ('連打数', '连打数', '連打數'),
}
SETS = {
    # folder, file prefix, centred? (dan_select/dan_result align left, the in-play panel centres)
    'dan_result/exam_info': ('exam_', False),
    'game/dan_info': ('exam_play_', True),
}
HEADER = ('合格条件', '合格条件', '合格條件')
# The confirmation popup: the question (white on a black outline) and the two answers (black).
CONFIRM = {
    'confirmation_text': ('この課題に挑戦するのかッ？', '要挑战这个课题吗？', '要挑戰這個課題嗎？'),
    'yes': ('挑戦する', '挑战', '挑戰'),
    'no': ('挑戦しない', '不挑战', '不挑戰'),
}
LANGS = {1: 'zh', 2: 'zh_tw'}


def font_path():
    for path in FONTS:
        if os.path.exists(path):
            return path
    raise SystemExit('no FOT-OedKtrStdE.otf next to tools/')


def ink_box(font, text):
    """The filled glyphs only: the outline is drawn outside this box."""
    w = font.size * (len(text) + 2)
    image = Image.new('L', (w, font.size * 3), 0)
    ImageDraw.Draw(image).text((font.size, font.size), text, font=font, fill=255)
    box = image.getbbox()
    return (box[0] - font.size, box[1] - font.size, box[2] - font.size, box[3] - font.size)


def fit(text, path, height, cap=120):
    """Largest size whose inked glyphs are about `height` tall."""
    best = None
    for size in range(cap, 8, -1):
        stroke = max(1, round(size * 0.13))
        font = ImageFont.truetype(path, size)
        box = ink_box(font, text)
        h = box[3] - box[1]
        if h <= height:
            return font, box, stroke
        best = (font, box, stroke)
    return best


def white_box(image):
    xs, ys = [], []
    for y in range(image.height):
        for x in range(image.width):
            p = image.getpixel((x, y))
            if p[3] > 200 and p[0] > 240 and p[1] > 240 and p[2] > 240:
                xs.append(x)
                ys.append(y)
    if not xs:
        return None
    return min(xs), min(ys), max(xs), max(ys)


def draw_label(source, text, target, centred):
    original = Image.open(source).convert('RGBA')
    box = white_box(original)
    if box is None:
        raise SystemExit('no white glyphs in ' + source)
    left, top, right, bottom = box
    height = bottom - top + 1
    font, ink, stroke = fit(text, FONT, height)
    canvas = Image.new('RGBA', original.size, (0, 0, 0, 0))
    draw = ImageDraw.Draw(canvas)
    # ink box is relative to the drawing origin; place its inked left/top where the original's was
    x = (left + right - (ink[0] + ink[2])) // 2 if centred else left
    y = (top + bottom - (ink[1] + ink[3])) // 2
    draw.text((x - ink[0], y - ink[1]), text, font=font, fill=INK,
              stroke_width=stroke, stroke_fill=OUTLINE)
    canvas.save(target)


def opaque_box(image):
    xs, ys = [], []
    for y in range(image.height):
        for x in range(image.width):
            if image.getpixel((x, y))[3] > 128:
                xs.append(x); ys.append(y)
    if not xs:
        return None
    return min(xs), min(ys), max(xs), max(ys)


def draw_simple(source, text, target, fill, outline=None):
    """Redraw one painted line at the original's size, left edge and glyph height."""
    original = Image.open(source).convert('RGBA')
    box = white_box(original) if fill[0] > 200 else opaque_box(original)
    left, top, right, bottom = box
    height = bottom - top + 1
    font, ink, _ = fit(text, FONT, height)
    stroke = max(1, round(font.size * 0.13)) if outline else 0
    canvas = Image.new('RGBA', original.size, (0, 0, 0, 0))
    x = (left + right - (ink[0] + ink[2])) // 2 if fill[0] <= 200 else left
    y = (top + bottom - (ink[1] + ink[3])) // 2
    ImageDraw.Draw(canvas).text((x - ink[0], y - ink[1]), text, font=font, fill=fill,
                                stroke_width=stroke, stroke_fill=outline or fill)
    canvas.save(target)


def draw_header(source, text, target):
    original = Image.open(source).convert('RGBA')
    # keep the shipped tab's exact shape, repaint it flat and letter it again
    mask = original.getchannel('A').point(lambda a: 255 if a > 40 else 0)
    canvas = Image.new('RGBA', original.size, (0, 0, 0, 0))
    canvas.paste(Image.new('RGBA', original.size, OUTLINE), (0, 0), mask)
    box = white_box(original)
    left, top, right, bottom = box
    height = bottom - top + 1
    font, ink, _ = fit(text, FONT, height)
    draw = ImageDraw.Draw(canvas)
    x = (left + right - (ink[0] + ink[2])) // 2
    y = (top + bottom - (ink[1] + ink[3])) // 2
    draw.text((x - ink[0], y - ink[1]), text, font=font, fill=INK)
    canvas.save(target)


FONT = font_path()


def main():
    os.makedirs(OUT, exist_ok=True)
    made = 0
    for folder, (prefix, centred) in SETS.items():
        for name, (ja, zh, zh_tw) in LABELS.items():
            source = os.path.join(ART, folder, 'exam_' + name + '.png')
            if not os.path.exists(source):
                print('  ! missing', source)
                continue
            for index, language in ((1, zh), (2, zh_tw)):
                target = os.path.join(OUT, '%s%s.%s.png' % (prefix, name, LANGS[index]))
                draw_label(source, language, target, centred)
                made += 1
    for name, (ja, zh, zh_tw) in CONFIRM.items():
        source = os.path.join(ART, 'dan_select/confirm_box', name + '.png')
        if not os.path.exists(source):
            print('  ! missing', source)
            continue
        outline = (0, 0, 0, 255) if name == 'confirmation_text' else None
        # the runtime asks for confirm_text / confirm_yes / confirm_no
        short = 'text' if name == 'confirmation_text' else name
        for index, language in ((1, zh), (2, zh_tw)):
            target = os.path.join(OUT, 'confirm_%s.%s.png' % (short, LANGS[index]))
            draw_simple(source, language, target, INK if name == 'confirmation_text' else (0, 0, 0, 255), outline)
            made += 1
    source = os.path.join(ART, 'dan_select/yellow_box/exam_header.png')
    if os.path.exists(source):
        for index in (1, 2):
            target = os.path.join(OUT, 'exam_header.%s.png' % LANGS[index])
            draw_header(source, HEADER[index], target)
            made += 1
    print('wrote %d exam sprites to %s' % (made, OUT))


if __name__ == '__main__':
    main()
