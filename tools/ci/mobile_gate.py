#!/usr/bin/env python3
"""Mobile gate: letterbox bars, offscreen clipping, text overlap, touch size, font size. Writes contact sheets."""
import json, sys, os, glob, re
from PIL import Image, ImageDraw
import numpy as np
out = sys.argv[1]; sheet_dir = sys.argv[2] if len(sys.argv) > 2 else out
rep = json.load(open(os.path.join(out, "layout.json")))
fails = []
for s in rep:
    name = s["shot"]; vw, vh = s["viewport"]
    img = np.asarray(Image.open(os.path.join(out, name + ".png")).convert("RGB")).astype(int)
    h, w, _ = img.shape
    band = max(4, w // 100)
    for side, sl in (("left", img[:, :band]), ("right", img[:, -band:]), ("top", img[:band]), ("bottom", img[-band:])):
        if sl.max() < 12:
            fails.append(f"{name}: letterbox bar {side}")
    scale = h / vh  # px per canvas unit
    dp = h / 411.0 if w / h > 1.7 else h / 800.0  # approx dp for landscape phone/tablet
    rects = []
    for it in s["items"]:
        x, y, rw, rh = it["rect"]
        if rw <= 1 or rh <= 1:
            continue
        if x < -2 or y < -2 or x + rw > vw + 2 or y + rh > vh + 2:
            fails.append(f"{name}: offscreen {it['type']} '{it['text']}' {it['rect']}")
        if it["type"].endswith("Button") and min(rw, rh) * scale < 48 * dp * 0.9:
            fails.append(f"{name}: small touch {it['text']!r} {rw:.0f}x{rh:.0f}")
        if it["text"] and it["font"] * scale < 12 * dp:
            fails.append(f"{name}: small font {it['font']} '{it['text']}'")
        if it["text"] and re.search(r"\[(A|B|X|Y|ESC|ENTER)\]|\sESC$", it["text"]):
            fails.append(f"{name}: keyhint {it['text']!r}")
        if it["text"]:
            rects.append((x, y, rw, rh, it))
    for i in range(len(rects)):
        for j in range(i + 1, len(rects)):
            a, b = rects[i], rects[j]
            ix = min(a[0]+a[2], b[0]+b[2]) - max(a[0], b[0]); iy = min(a[1]+a[3], b[1]+b[3]) - max(a[1], b[1])
            if ix > 4 and iy > 4 and not (a[4]["path"].startswith(b[4]["path"]) or b[4]["path"].startswith(a[4]["path"])):
                fails.append(f"{name}: overlap '{a[4]['text']}' x '{b[4]['text']}'")
# contact sheets per resolution
os.makedirs(sheet_dir, exist_ok=True)
groups = {}
for p in sorted(glob.glob(os.path.join(out, "*.png"))):
    groups.setdefault(p.rsplit("_", 1)[1], []).append(p)
for res, ps in groups.items():
    th = [Image.open(p).convert("RGB") for p in ps]
    tw = 600; thh = int(tw * th[0].height / th[0].width)
    cols = 3; rows = (len(th) + cols - 1) // cols
    sheet = Image.new("RGB", (cols * (tw + 10), rows * (thh + 30)), (255, 0, 255))
    d = ImageDraw.Draw(sheet)
    for k, (im, p) in enumerate(zip(th, ps)):
        cx, cy = (k % cols) * (tw + 10), (k // cols) * (thh + 30)
        sheet.paste(im.resize((tw, thh)), (cx, cy + 25)); d.text((cx + 4, cy + 6), os.path.basename(p), fill=(255, 255, 255))
    sheet.save(os.path.join(sheet_dir, f"sheet_{res}"))
open(os.path.join(out, "gate_fails.txt"), "w").write("\n".join(fails))
print(f"MOBILE GATE: {len(fails)} issues")
for f in fails[:80]: print(" ", f)
# Ratchet: letterbox bars always fail; other classes may not grow past baseline.
import collections, re
cnt = collections.Counter(re.split(r"[ ']", f.split(": ", 1)[1])[0] + ("_" + f.split(": ", 1)[1].split()[1] if f.split(": ", 1)[1].startswith(("small", "offscreen")) else "") for f in fails)
base_p = os.path.join(os.path.dirname(__file__), "mobile_baseline.json")
if "--write-baseline" in sys.argv:
    json.dump(dict(cnt), open(base_p, "w"), indent=1, sort_keys=True); print("baseline written"); sys.exit(0)
base = json.load(open(base_p)) if os.path.exists(base_p) else {}
bad = [k for k, v in cnt.items() if k == "letterbox" or v > int(base.get(k, 0) * 1.05) + 2]
print("classes:", dict(cnt))
print("REGRESSED:" if bad else "MOBILE GATE PASS (ratchet)", bad)
sys.exit(1 if bad else 0)
