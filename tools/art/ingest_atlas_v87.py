#!/usr/bin/env python3
"""Ingest v8.7 atlas farm outputs (city vignettes, smith interiors, item icons) after the style-lock gate.

  ingest_atlas_v87.py <farm_out_dir> [--dry]

Farm files are named 8322__<label>__<comfy file>.png (tools/farm_v87/farm.ps1 fetch). For each label the newest
file is judged with tools/art/style_check_v87.judge (kind city / icon). Only PASS plates are written:
  v87_city_<id>      -> project/assets/art/atlas/cities/v87_city_<id>.jpg    (1280x720, q90)
  v87_smith_<nation> -> project/assets/art/atlas/smiths/v87_smith_<nation>.jpg (1280x720, q90)
  v87_item_<id>      -> project/assets/art/ui/items/v87_item_<id>.png         (256x256, plate bg keyed to alpha)
Rejects are listed (with reasons) in docs/art/review/atlas_v87_ingest.json and shown red on the contact sheets
docs/art/review/atlas_v87_{city,icon}_sheet.jpg. Missing art keeps the procedural fallbacks in city.gd / atlas_view.gd.
"""
import json, os, re, sys
import numpy as np
from PIL import Image, ImageDraw, ImageFont

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
sys.path.insert(0, os.path.dirname(__file__))
import style_check_v87 as sc  # noqa: E402

OUT = {
    "v87_city_": ("city", "project/assets/art/atlas/cities", (1280, 720)),
    "v87_smith_": ("city", "project/assets/art/atlas/smiths", (1280, 720)),
    "v87_item_": ("icon", "project/assets/art/ui/items", (256, 256)),
}
REVIEW = os.path.join(ROOT, "docs/art/review")
# human sign-off from the contact sheets: {"crop": {label: y0..1}, "reject": {label: reason}}
OVERRIDES = os.path.join(REVIEW, "atlas_v87_overrides.json")


def key_background(im: Image.Image) -> Image.Image:
    """flood the plate background from the border into alpha (icons sit on dark glass tiles in-game)"""
    a = np.asarray(im.convert("RGB")).astype(np.int32)
    h, w, _ = a.shape
    border = np.concatenate([a[0], a[-1], a[:, 0], a[:, -1]])
    bg = np.median(border, axis=0)
    dist = np.abs(a - bg).sum(-1)
    near = dist < 42
    seen = np.zeros((h, w), bool)
    stack = [(0, x) for x in range(w)] + [(h - 1, x) for x in range(w)] + [(y, 0) for y in range(h)] + [(y, w - 1) for y in range(h)]
    while stack:
        y, x = stack.pop()
        if y < 0 or y >= h or x < 0 or x >= w or seen[y, x] or not near[y, x]:
            continue
        seen[y, x] = True
        stack.extend(((y + 1, x), (y - 1, x), (y, x + 1), (y, x - 1)))
    alpha = np.where(seen, 0, 255).astype(np.uint8)
    # soft edge: partially transparent where close to bg next to the keyed region
    edge = (~seen) & (dist < 70)
    alpha[edge] = np.clip((dist[edge] - 42) / 28.0 * 255, 60, 255).astype(np.uint8)
    rgba = np.dstack([a.astype(np.uint8), alpha])
    return Image.fromarray(rgba, "RGBA")


def ui_band(path):
    """Detect a model-drawn UI/title bar (full-width crisp horizontal edge with a flat band below it).
    Returns the y (0..1) where the band starts, or None. The locked prefix names the game, and Qwen sometimes
    paints a caption bar with garbled title text along the bottom — that is off-style and must not ship."""
    g = np.asarray(Image.open(path).convert("L").resize((320, 180))).astype(np.float32) / 255.0
    h = g.shape[0]
    dy = np.abs(np.diff(g, axis=0))            # (h-1, w)
    frac = (dy > 0.06).mean(axis=1)            # share of columns with an edge on this row
    best = None
    for y in range(int(h * 0.45), h - 4):
        if frac[y] < 0.55:
            continue
        below = g[y + 2:]
        if below.size == 0:
            continue
        # flat band: low vertical variation across most columns
        flat = (np.abs(np.diff(below, axis=0)) < 0.03).mean()
        if flat > 0.8:
            best = (y + 1) / h
            break
    # flat floor: a solid caption bar shows as near-constant rows up from the bottom edge
    rowstd = g.std(axis=1)
    y0 = h
    while y0 > int(h * 0.5) and rowstd[y0 - 1] < 0.09:
        y0 -= 1
    if h - y0 >= int(h * 0.05) and rowstd[h - 3:].mean() < 0.06:
        best = min(best, y0 / h) if best is not None else y0 / h
    # hairline: one crisp full-width rule with quiet rows beneath it
    fr2 = (dy > 0.04).mean(axis=1)
    for y in range(int(h * 0.6), h - 3):
        if fr2[y] >= 0.6 and rowstd[y + 2:].mean() <= 0.09:
            best = min(best, (y + 1) / h) if best is not None else (y + 1) / h
            break
    return best


def crop_band(im, yb, size):
    """cut everything from the band down, then top-anchored centre crop back to the target aspect"""
    w, h = im.size
    cut = int(h * yb) - int(h * 0.02)
    im = im.crop((0, 0, w, max(1, cut)))
    tw = int(round(cut * size[0] / size[1]))
    x0 = max(0, (w - tw) // 2)
    im = im.crop((x0, 0, x0 + min(w, tw), cut))
    return im.resize(size, Image.LANCZOS)


def contact(rows, out, cell, cols):
    if not rows:
        return
    pad = 22
    W = cols * cell
    H = ((len(rows) + cols - 1) // cols) * (cell + pad)
    img = Image.new("RGB", (W, H), (7, 8, 12))
    dr = ImageDraw.Draw(img)
    try:
        font = ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSansMono.ttf", 11)
    except Exception:
        font = ImageFont.load_default()
    for i, (label, path, m) in enumerate(rows):
        x, y = (i % cols) * cell, (i // cols) * (cell + pad)
        t = Image.open(path).convert("RGB")
        t.thumbnail((cell - 6, cell - 6))
        img.paste(t, (x + 3, y + 3))
        col = (94, 224, 181) if m["pass"] else (255, 122, 112)
        dr.rectangle([x, y, x + cell - 1, y + cell - 1], outline=col, width=2)
        txt = label.replace("v87_", "")[:26] + ((" x " if not m["pass"] else " ~ ") + ",".join(m["fails"]) if m["fails"] else "")
        dr.text((x + 3, y + cell + 4), txt, fill=col, font=font)
    img.save(out, quality=82)


def main(argv):
    if not argv:
        print(__doc__)
        return 2
    src, dry = argv[0], "--dry" in argv
    files = {}
    for f in sorted(os.listdir(src)):
        m = re.match(r"^\d+__(v87_(?:city|smith|item)_[A-Za-z0-9_]+?)__.*\.png$", f)
        if m:
            files[m.group(1)] = os.path.join(src, f)  # newest (sorted) wins
    ov = json.load(open(OVERRIDES)) if os.path.exists(OVERRIDES) else {"crop": {}, "reject": {}}
    report = {"passed": [], "rejected": {}, "counts": {}}
    sheets = {"city": [], "icon": []}
    for label, path in sorted(files.items()):
        pre = next(p for p in OUT if label.startswith(p))
        kind, dst_dir, size = OUT[pre]
        m = sc.judge(path, kind)
        band = ui_band(path) if kind == "city" else None
        if label in ov.get("crop", {}):
            band = min(band, float(ov["crop"][label])) if band is not None else float(ov["crop"][label])
        if label in ov.get("reject", {}):
            m["pass"] = False
            m["fails"] = list(m["fails"]) + ["review:" + str(ov["reject"][label])]
        if band is not None:
            m["ui_band"] = round(band, 3)
            if band < 0.72:
                m["pass"] = False
                m["fails"] = list(m["fails"]) + ["ui-overlay"]
            else:
                m["fails"] = list(m["fails"]) + (["cropped-ui"] if m["pass"] else [])
        sheets[kind].append((label, path, m))
        if not m["pass"]:
            report["rejected"][label] = m["fails"]
            continue
        report["passed"].append(label)
        if dry:
            continue
        os.makedirs(os.path.join(ROOT, dst_dir), exist_ok=True)
        im = Image.open(path)
        if kind == "icon":
            im = key_background(im).resize(size, Image.LANCZOS)
        else:
            im = im.convert("RGB")
            if band is not None:
                im = crop_band(im, band, size)
                report.setdefault("cropped", []).append(label)
            if im.size != size:
                im = im.resize(size, Image.LANCZOS)
        if kind == "icon":
            im.save(os.path.join(ROOT, dst_dir, label + ".png"), optimize=True)
        else:  # opaque 1280x720 vignettes ship as q90 JPG (~10x smaller than PNG)
            im.save(os.path.join(ROOT, dst_dir, label + ".jpg"), quality=90, optimize=True, progressive=True)
            stale = os.path.join(ROOT, dst_dir, label + ".png")
            if os.path.exists(stale):
                os.remove(stale)
                if os.path.exists(stale + ".import"):
                    os.remove(stale + ".import")
    for pre, (kind, _, _) in OUT.items():
        report["counts"][pre.rstrip("_")] = {"seen": sum(1 for l in files if l.startswith(pre)),
                                             "passed": sum(1 for l in report["passed"] if l.startswith(pre))}
    os.makedirs(REVIEW, exist_ok=True)
    contact(sheets["city"], os.path.join(REVIEW, "atlas_v87_city_sheet.jpg"), 240, 6)
    contact(sheets["icon"], os.path.join(REVIEW, "atlas_v87_icon_sheet.jpg"), 128, 12)
    json.dump(report, open(os.path.join(REVIEW, "atlas_v87_ingest.json"), "w"), ensure_ascii=False, indent=1)
    print(json.dumps(report["counts"]), "rejected:", len(report["rejected"]))
    for k, v in report["rejected"].items():
        print("  REJECT", k, v)
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
