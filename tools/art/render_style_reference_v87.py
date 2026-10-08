#!/usr/bin/env python3
"""Renders docs/art/review/style_reference_v87.png from docs/art/style-lock-v87.json (reference plates, palette, light)."""
import json, os
from PIL import Image, ImageDraw, ImageFont
ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
L = json.load(open(os.path.join(ROOT, "docs/art/style-lock-v87.json")))
P = os.path.join(ROOT, "project/assets/art/portraits/")
W, H = 1920, 1080
im = Image.new("RGB", (W, H), (7, 8, 12)); d = ImageDraw.Draw(im)
f = lambda s: ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf", s)
try:
    cj = lambda s: ImageFont.truetype("/usr/share/fonts/opentype/noto/NotoSansCJK-Regular.ttc", s); cj(10)
except Exception:
    cj = f
d.text((48, 36), "CenturyKnights 风格锁 · STYLE LOCK v8.7", font=cj(40), fill=(244, 247, 251))
d.text((48, 90), "reference plates (all PASS the gate)  ·  palette from Stitch tokens.json  ·  key light upper-left / frost rim back-right", font=f(18), fill=(154, 166, 184))
x = 48
for r in L["check"]["reference_set"]:
    t = Image.open(P + r).convert("RGB"); t = t.resize((int(t.width * 520 / t.height), 520)); t = t.crop((0, 0, min(t.width, 290), 520))
    im.paste(t, (x, 140)); d.rectangle([x, 140, x + t.width - 1, 659], outline=(94, 224, 181), width=2)
    d.text((x + 6, 666), r.replace(".png", ""), font=f(14), fill=(154, 166, 184)); x += t.width + 14
y, x = 720, 48
for k, v in L["palette"].items():
    c = tuple(int(v[i:i + 2], 16) for i in (1, 3, 5))
    d.rounded_rectangle([x, y, x + 120, y + 70], 8, fill=c, outline=(60, 66, 78))
    d.text((x, y + 76), k[:17], font=f(13), fill=(244, 247, 251)); d.text((x, y + 94), v, font=f(13), fill=(154, 166, 184))
    x += 132
    if x > W - 520: x = 48; y += 130
cx, cy = 1720, 880
d.ellipse([cx - 70, cy - 70, cx + 70, cy + 70], outline=(42, 52, 66), width=2)
d.ellipse([cx - 40, cy - 55, cx + 40, cy + 55], fill=(28, 35, 48), outline=(110, 212, 255), width=3)
d.line([cx - 150, cy - 150, cx - 60, cy - 60], fill=(244, 247, 251), width=4); d.text((cx - 190, cy - 178), "KEY 45° / 40°", font=f(15), fill=(244, 247, 251))
d.line([cx + 150, cy - 120, cx + 50, cy - 30], fill=(110, 212, 255), width=3); d.text((cx + 50, cy - 150), "RIM frost", font=f(15), fill=(110, 212, 255))
d.text((48, 1040), "forbidden: medieval · parchment · gold · warm key light · heavy ink · ember fills   |   gate: tools/art/style_check_v87.py", font=f(16), fill=(255, 122, 112))
im.save(os.path.join(ROOT, "docs/art/review/style_reference_v87.png"))
