"""Рисует превью циферблата (docs/preview.png) и иконку приложения
(resources/drawables/launcher_icon.png) той же геометрией, что и source/LcdBlockView.mc.

Запуск из корня репозитория:
    pip install pillow
    python3 tools/preview.py
"""
import math
from pathlib import Path

from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parent.parent
SCREEN = 260
BG, FG, LINE = (0, 0, 0), (255, 255, 255), (170, 170, 170)

# те же символы, что в _glyphs в LcdBlockView.mc
GLYPHS = {
    "0": [0,0,2,0, 2,0,2,2, 0,2,2,2, 0,0,0,2],
    "1": [2,0,2,2],
    "2": [0,0,2,0, 2,0,2,1, 0,1,2,1, 0,1,0,2, 0,2,2,2],
    "3": [0,0,2,0, 2,0,2,2, 0,2,2,2, 0,1,2,1],
    "4": [0,0,0,1, 0,1,2,1, 2,0,2,2],
    "5": [0,0,2,0, 0,0,0,1, 0,1,2,1, 2,1,2,2, 0,2,2,2],
    "6": [0,0,2,0, 0,0,0,2, 0,2,2,2, 2,1,2,2, 0,1,2,1],
    "7": [0,0,2,0, 2,0,2,2],
    "8": [0,0,2,0, 2,0,2,2, 0,2,2,2, 0,0,0,2, 0,1,2,1],
    "9": [0,1,2,1, 0,0,0,1, 0,0,2,0, 2,0,2,2, 0,2,2,2],
    "A": [0,0,0,2, 0,0,2,0, 2,0,2,2, 0,1,2,1],
    "D": [0,0,3,0, 3,0,2,3, 2,3,2,4, 2,4,3,2, 0,2,3,2, 0,0,0,2],
    "E": [0,0,2,0, 0,0,0,2, 0,2,2,2, 0,1,2,1],
    "F": [0,0,2,0, 0,0,0,2, 0,1,2,1],
    "H": [0,0,0,2, 2,0,2,2, 0,1,2,1],
    "I": [1,0,1,2],
    "M": [0,0,0,2, 0,0,2,0, 2,0,2,2, 1,0,1,1],
    "N": [0,0,0,2, 0,0,2,0, 2,0,2,2],
    "O": [0,0,2,0, 2,0,2,2, 0,2,2,2, 0,0,0,2],
    "P": [0,0,0,2, 0,0,2,0, 2,0,2,1, 0,1,2,1],
    "R": [0,0,0,2, 0,0,2,0, 2,0,2,1, 0,1,2,1, 1,1,2,2],
    "S": [0,0,2,0, 0,0,0,1, 0,1,2,1, 2,1,2,2, 0,2,2,2],
    "T": [0,0,2,0, 1,0,1,2],
    "U": [0,0,0,2, 0,2,2,2, 2,0,2,2],
    "W": [0,0,0,2, 0,2,2,2, 2,0,2,2, 1,1,1,2],
}

# раскладка - те же константы, что в LcdBlockView.mc
DATE = dict(x=51, y=52, w=15, h=26, t=4, step=20)
LINE1_Y, LINE2_Y = 89, 179
P = dict(x=30, y=104, w=12, h=18, t=4, step=0)
TIME = dict(y=102, w=36, h=66, t=9, step=42)
TIME_X, MIN_X = 48, 146
SEC = dict(x=148, y=192, w=24, h=40, t=6, step=30)


def thick(d, x1, y1, x2, y2, t, color):
    dx, dy = x2 - x1, y2 - y1
    ln = math.hypot(dx, dy)
    nx, ny = -dy / ln * t / 2, dx / ln * t / 2
    pts = [(x1 + nx, y1 + ny), (x2 + nx, y2 + ny), (x2 - nx, y2 - ny), (x1 - nx, y1 - ny)]
    d.polygon([(int(px + 0.5), int(py + 0.5)) for px, py in pts], fill=color)


def glyph(d, seg, x, y, w, h, t, color):
    q = (w - t) * 3 // 10
    xs = [x, x + (w - t) // 2, x + w - t, x + w - t - q]
    ys = [y, y + (h - t) // 2, y + h - t, y + q, y + h - t - q]
    r = max(1, t // 3)
    for i in range(0, len(seg), 4):
        x1, y1, x2, y2 = xs[seg[i]], ys[seg[i + 1]], xs[seg[i + 2]], ys[seg[i + 3]]
        if x1 == x2 or y1 == y2:
            rx, ry = min(x1, x2), min(y1, y2)
            rw, rh = abs(x2 - x1) + t, abs(y2 - y1) + t
            d.rounded_rectangle([rx, ry, rx + rw - 1, ry + rh - 1], radius=r, fill=color)
        else:
            thick(d, x1 + t / 2, y1 + t / 2, x2 + t / 2, y2 + t / 2, t, color)
            d.rectangle([x1, y1, x1 + t - 1, y1 + t - 1], fill=color)
            d.rectangle([x2, y2, x2 + t - 1, y2 + t - 1], fill=color)


def text(d, s, x, y, w, h, t, step, color=FG):
    for i, ch in enumerate(s):
        if ch in GLYPHS:
            glyph(d, GLYPHS[ch], x + i * step, y, w, h, t, color)


def pad(n):
    return f"{n:2d}"


def preview(month=10, day=29, dow="THU", hour=12, minute=11, sec=59, pm=True):
    img = Image.new("RGB", (SCREEN, SCREEN), (120, 120, 120))
    d = ImageDraw.Draw(img)
    d.ellipse([0, 0, SCREEN - 1, SCREEN - 1], fill=BG)

    d.rectangle([24, LINE1_Y, 24 + 212 - 1, LINE1_Y + 1], fill=LINE)
    d.rectangle([28, LINE2_Y, 28 + 204 - 1, LINE2_Y + 1], fill=LINE)

    dx, dy = DATE["x"], DATE["y"]
    text(d, pad(month), **DATE)
    thick(d, dx + 42, dy + 24, dx + 50, dy + 2, DATE["t"], FG)
    text(d, pad(day), dx + 54, dy, DATE["w"], DATE["h"], DATE["t"], DATE["step"])
    text(d, dow, dx + 104, dy, DATE["w"], DATE["h"], DATE["t"], DATE["step"])

    if pm:
        text(d, "P", **P)

    text(d, pad(hour), TIME_X, **TIME)
    d.rectangle([131, 119, 138, 126], fill=FG)
    d.rectangle([131, 143, 138, 150], fill=FG)
    text(d, f"{minute:02d}", MIN_X, **TIME)

    text(d, f"{sec:02d}", **SEC)

    out = ROOT / "docs" / "preview.png"
    out.parent.mkdir(exist_ok=True)
    img.resize((SCREEN * 2, SCREEN * 2), Image.NEAREST).save(out)
    print("saved", out)


def icon():
    size = 40
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.ellipse([0, 0, size - 1, size - 1], fill=BG)
    d.rectangle([6, 9, 33, 9], fill=LINE)
    d.rectangle([6, 30, 33, 30], fill=LINE)
    text(d, "12", 8, 12, 10, 16, 3, 13)
    out = ROOT / "resources" / "drawables" / "launcher_icon.png"
    img.save(out)
    print("saved", out)


if __name__ == "__main__":
    preview()
    icon()
