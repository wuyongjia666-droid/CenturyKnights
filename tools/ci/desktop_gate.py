#!/usr/bin/env python3
"""Desktop gate (mouse, no mobile reflow): offscreen, overlap, clipped text, misaligned buttons,
small font / click target, placeholder art. Ratchet against desktop_baseline.json (can only go down)."""
import json, sys, os, glob, collections
from PIL import Image, ImageDraw
out = sys.argv[1]; sheet_dir = sys.argv[2] if len(sys.argv) > 2 and not sys.argv[2].startswith("--") else os.path.join(out, "sheets")
rep = json.load(open(os.path.join(out, "layout.json")))
fails = []  # (class, message)
for s in rep:
    name = s["shot"]; vw, vh = s["viewport"]
    rects = []; btns = collections.defaultdict(list)
    for it in s["items"]:
        x, y, rw, rh = it["rect"]; t = it["text"]
        if it["type"] == "Placeholder":
            fails.append(("placeholder", f"{name}: placeholder art {t!r} at {it['path'].split('/')[-1]}")); continue
        if rw <= 1 or rh <= 1:
            continue
        if not it.get("in_scroll") and (x < -2 or y < -2 or x + rw > vw + 2 or y + rh > vh + 2):
            fails.append(("offscreen", f"{name}: offscreen {it['type']} {t!r} {[round(v) for v in it['rect']]}"))
        if t.strip() and it.get("need_w", 0) > rw + 4 and not it.get("clipped"):
            fails.append(("clipped_text", f"{name}: clipped text {t!r} needs {it['need_w']:.0f} has {rw:.0f}"))
        if t and it["font"] < 12:
            fails.append(("small_font", f"{name}: small font {it['font']} {t!r}"))
        if it["type"].endswith("Button") and not it.get("clipped") and min(rw, rh) < 20:
            fails.append(("small_click", f"{name}: small click target {t!r} {rw:.0f}x{rh:.0f}"))
        if it["type"].endswith("Button"):
            btns[it["path"].rsplit("/", 1)[0]].append((x, y, rw, rh, t))
        if t and not it.get("clipped"):
            rects.append((x, y, rw, rh, it))
    for par, bs in btns.items():
        for i in range(len(bs)):
            for j in range(i + 1, len(bs)):
                a, b = bs[i], bs[j]
                if a[4] and b[4] and 1.5 < abs(a[1] - b[1]) < 8 and abs(a[3] - b[3]) < 8:
                    fails.append(("misaligned", f"{name}: misaligned {a[4]!r} vs {b[4]!r} dy={abs(a[1]-b[1]):.0f}"))
    for i in range(len(rects)):
        for j in range(i + 1, len(rects)):
            a, b = rects[i], rects[j]
            ix = min(a[0]+a[2], b[0]+b[2]) - max(a[0], b[0]); iy = min(a[1]+a[3], b[1]+b[3]) - max(a[1], b[1])
            if ix > 4 and iy > 4 and not (a[4]["path"].startswith(b[4]["path"]) or b[4]["path"].startswith(a[4]["path"])):
                fails.append(("overlap", f"{name}: overlap {a[4]['text']!r} x {b[4]['text']!r}"))
os.makedirs(sheet_dir, exist_ok=True)
groups = {}
for p in sorted(glob.glob(os.path.join(out, "*.png"))):
    groups.setdefault(p.rsplit("_", 1)[1], []).append(p)
for res, ps in groups.items():
    th = [Image.open(p).convert("RGB") for p in ps]
    tw = 640; thh = int(tw * th[0].height / th[0].width); cols = 4; rows = (len(th) + cols - 1) // cols
    sheet = Image.new("RGB", (cols * (tw + 10), rows * (thh + 30)), (40, 40, 40)); d = ImageDraw.Draw(sheet)
    for k, (im, p) in enumerate(zip(th, ps)):
        cx, cy = (k % cols) * (tw + 10), (k // cols) * (thh + 30)
        sheet.paste(im.resize((tw, thh)), (cx, cy + 25)); d.text((cx + 4, cy + 6), os.path.basename(p), fill=(255, 255, 255))
    sheet.save(os.path.join(sheet_dir, f"desktop_sheet_{res}"))
open(os.path.join(out, "gate_fails.txt"), "w").write("\n".join(m for _, m in fails))
cnt = collections.Counter(c for c, _ in fails)
print(f"DESKTOP GATE: {len(fails)} issues"); [print(" ", m) for _, m in fails[:60]]
base_p = os.path.join(os.path.dirname(os.path.abspath(__file__)), "desktop_baseline.json")
if "--write-baseline" in sys.argv:
    json.dump(dict(cnt), open(base_p, "w"), indent=1, sort_keys=True); print("baseline written"); sys.exit(0)
base = json.load(open(base_p)) if os.path.exists(base_p) else {}
bad = [k for k, v in cnt.items() if v > int(base.get(k, 0))]
print("classes:", dict(cnt)); print("REGRESSED:" if bad else "DESKTOP GATE PASS (ratchet)", bad)
sys.exit(1 if bad else 0)
