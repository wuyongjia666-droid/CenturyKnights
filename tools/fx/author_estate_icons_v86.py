#!/usr/bin/env python3
"""v8.6 estate holding + KPI icons: frost line glyphs (crystal #6ED4FF strokes, mint accents), transparent,
4x supersampled. Replaces the v7 blob icons. Out: project/assets/art/estates/<hid>.png (128px),
project/assets/art/ui/v86/kpi_{grain,cash,fortify}.png (64px)."""
import math
from pathlib import Path
from PIL import Image, ImageDraw, ImageFilter

ROOT = Path(__file__).resolve().parents[2] / "project/assets/art"
FROST = (110, 212, 255, 255)
MINT = (94, 224, 181, 255)
DIM = (110, 212, 255, 110)
SS = 4

def canvas(n):
    return Image.new("RGBA", (n * SS, n * SS), (0, 0, 0, 0))

def P(n, pts):
    return [(x * n * SS, y * n * SS) for x, y in pts]

def poly(d, n, pts, col=FROST, w=0.035, closed=False):
    q = P(n, pts)
    if closed:
        q = q + [q[0]]
    d.line(q, fill=col, width=max(1, int(w * n * SS)), joint="curve")
    r = w * n * SS / 2
    for x, y in (q[0], q[-1]):
        d.ellipse([x - r, y - r, x + r, y + r], fill=col)

def wave(d, n, y, x0, x1, amp, k, col=FROST, w=0.03):
    pts = [(x0 + (x1 - x0) * t / 40, y + amp * math.sin(t / 40 * math.pi * 2 * k)) for t in range(41)]
    poly(d, n, pts, col, w)

def circle(d, n, cx, cy, r, col=FROST, w=0.035, fill=None):
    q = P(n, [(cx - r, cy - r), (cx + r, cy + r)])
    d.ellipse(q, outline=col, width=max(1, int(w * n * SS)), fill=fill)

def finish(img, n, out):
    small = img.resize((n, n), Image.LANCZOS)
    glow = small.filter(ImageFilter.GaussianBlur(n / 40))
    a = glow.split()[3].point(lambda v: int(v * 0.55))
    glow.putalpha(a)
    base = Image.alpha_composite(glow, small)
    out.parent.mkdir(parents=True, exist_ok=True)
    base.save(out)
    print("ICON", out.relative_to(ROOT.parent.parent))

def reed_ford(n=128):
    im = canvas(n); d = ImageDraw.Draw(im)
    for i, x in enumerate((0.30, 0.40, 0.50)):
        top = 0.22 + i * 0.05
        poly(d, n, [(x, 0.66), (x + 0.02, 0.45), (x + 0.05, top)], MINT, 0.028)
        q = P(n, [(x + 0.025, top - 0.07), (x + 0.075, top + 0.05)])
        d.ellipse(q, outline=MINT, width=int(0.026 * n * SS))
    poly(d, n, [(0.55, 0.56), (0.84, 0.56), (0.78, 0.63), (0.61, 0.63)], FROST, 0.032, True)
    poly(d, n, [(0.70, 0.56), (0.70, 0.36), (0.80, 0.50), (0.70, 0.50)], FROST, 0.026)
    wave(d, n, 0.72, 0.16, 0.86, 0.018, 3)
    wave(d, n, 0.81, 0.24, 0.78, 0.014, 2.5, DIM)
    finish(im, n, ROOT / "estates/reed_ford.png")

def stone_slope(n=128):
    im = canvas(n); d = ImageDraw.Draw(im)
    poly(d, n, [(0.12, 0.80), (0.42, 0.30), (0.56, 0.46), (0.66, 0.36), (0.90, 0.80)], FROST, 0.034)
    for r, y in enumerate((0.70, 0.62, 0.54)):
        x0 = 0.44 + r * 0.03; x1 = 0.80 - r * 0.02
        poly(d, n, [(x0, y), (x1, y)], MINT, 0.024)
        k = 3 - r
        for j in range(k + 1):
            xx = x0 + (x1 - x0) * (j + (0.5 if r % 2 else 0)) / (k + 0.5)
            if xx < x1:
                poly(d, n, [(xx, y), (xx, y + 0.08 if r == 0 else y + 0.08)], MINT, 0.02)
    poly(d, n, [(0.44, 0.78), (0.82, 0.78)], MINT, 0.024)
    poly(d, n, [(0.42, 0.30), (0.42, 0.18), (0.52, 0.22), (0.42, 0.26)], FROST, 0.024)
    finish(im, n, ROOT / "estates/stone_slope.png")

def fog_vale(n=128):
    im = canvas(n); d = ImageDraw.Draw(im)
    # leaf
    pts = [(0.50 + 0.20 * math.sin(t / 30 * math.pi) * (1 - t / 30 * 0.25), 0.70 - 0.46 * t / 30) for t in range(31)]
    pts2 = [(0.50 - 0.20 * math.sin(t / 30 * math.pi) * (1 - t / 30 * 0.25), 0.70 - 0.46 * t / 30) for t in range(31)]
    poly(d, n, pts, MINT, 0.032); poly(d, n, pts2, MINT, 0.032)
    poly(d, n, [(0.50, 0.80), (0.50, 0.30)], MINT, 0.026)
    for k, y in enumerate((0.42, 0.52, 0.60)):
        poly(d, n, [(0.50, y), (0.50 + 0.11 - k * 0.02, y - 0.07)], MINT, 0.02)
        poly(d, n, [(0.50, y), (0.50 - 0.11 + k * 0.02, y - 0.07)], MINT, 0.02)
    wave(d, n, 0.74, 0.12, 0.40, 0.012, 1.5, FROST, 0.026)
    wave(d, n, 0.82, 0.22, 0.86, 0.012, 2.5, FROST, 0.026)
    wave(d, n, 0.66, 0.62, 0.90, 0.012, 1.5, DIM, 0.024)
    finish(im, n, ROOT / "estates/fog_vale.png")

def tide_bridge(n=128):
    im = canvas(n); d = ImageDraw.Draw(im)
    poly(d, n, [(0.10, 0.50), (0.90, 0.50)], FROST, 0.034)
    arch = [(0.22 + 0.56 * t / 40, 0.70 - 0.16 * math.sin(math.pi * t / 40)) for t in range(41)]
    poly(d, n, arch, FROST, 0.03)
    for x in (0.22, 0.78):
        poly(d, n, [(x, 0.50), (x, 0.74)], FROST, 0.034)
    for x in (0.36, 0.50, 0.64):
        y = 0.70 - 0.16 * math.sin(math.pi * (x - 0.22) / 0.56)
        poly(d, n, [(x, 0.50), (x, y)], DIM, 0.02)
    poly(d, n, [(0.72, 0.50), (0.72, 0.22)], MINT, 0.026)
    poly(d, n, [(0.72, 0.23), (0.86, 0.28), (0.72, 0.34)], MINT, 0.026, True)
    wave(d, n, 0.82, 0.10, 0.90, 0.016, 3.5)
    finish(im, n, ROOT / "estates/tide_bridge.png")

def kpi_grain(n=64):
    im = canvas(n); d = ImageDraw.Draw(im)
    for dx, tilt in ((-0.14, -0.10), (0.0, 0.0), (0.14, 0.10)):
        poly(d, n, [(0.5 + dx * 0.4, 0.86), (0.5 + dx + tilt * 0.3, 0.30)], FROST, 0.05)
        for k in range(3):
            y = 0.30 + k * 0.11
            cx = 0.5 + dx + tilt * 0.3 * (1 - k * 0.2)
            q = P(n, [(cx - 0.06, y - 0.06), (cx + 0.06, y + 0.05)])
            d.ellipse(q, outline=FROST, width=int(0.045 * n * SS))
    poly(d, n, [(0.34, 0.68), (0.66, 0.68)], MINT, 0.05)
    finish(im, n, ROOT / "ui/v86/kpi_grain.png")

def kpi_cash(n=64):
    im = canvas(n); d = ImageDraw.Draw(im)
    poly(d, n, [(0.18, 0.38), (0.5, 0.18), (0.82, 0.38)], FROST, 0.05, False)
    poly(d, n, [(0.16, 0.40), (0.84, 0.40)], FROST, 0.05)
    for x in (0.28, 0.43, 0.57, 0.72):
        poly(d, n, [(x, 0.46), (x, 0.70)], FROST, 0.05)
    poly(d, n, [(0.16, 0.78), (0.84, 0.78)], FROST, 0.05)
    circle(d, n, 0.5, 0.30, 0.04, MINT, 0.045)
    finish(im, n, ROOT / "ui/v86/kpi_cash.png")

def kpi_fortify(n=64):
    im = canvas(n); d = ImageDraw.Draw(im)
    poly(d, n, [(0.26, 0.84), (0.26, 0.30), (0.34, 0.30), (0.34, 0.20), (0.42, 0.20), (0.42, 0.30), (0.58, 0.30),
                (0.58, 0.20), (0.66, 0.20), (0.66, 0.30), (0.74, 0.30), (0.74, 0.84)], FROST, 0.05)
    poly(d, n, [(0.20, 0.84), (0.80, 0.84)], FROST, 0.05)
    poly(d, n, [(0.44, 0.84), (0.44, 0.64), (0.50, 0.58), (0.56, 0.64), (0.56, 0.84)], MINT, 0.045)
    poly(d, n, [(0.42, 0.44), (0.58, 0.44)], MINT, 0.045)
    finish(im, n, ROOT / "ui/v86/kpi_fortify.png")

if __name__ == "__main__":
    for f in (reed_ford, stone_slope, fog_vale, tide_bridge, kpi_grain, kpi_cash, kpi_fortify):
        f()
