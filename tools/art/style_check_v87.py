#!/usr/bin/env python3
"""Style-lock v8.7 consistency gate. Every generated plate (portrait part, full-body sheet, city plate,
weapon icon, 3D texture) must pass BEFORE ingest into project/assets.

  style_check_v87.py check  <img...> [--sheet out.png] [--json out.json] [--kind portrait|sheet|city|icon|texture]
  style_check_v87.py calibrate            # prints metrics of the reference set (must all pass)

Metrics (computed on the subject: pixels that differ from the plate background):
  gold_ratio       saturated yellow/brass pixels (hue 32-58deg, s>0.42, v>0.35)       -> no gold filigree
  parchment_ratio  low-sat warm beige (hue 20-50, s 0.12-0.40, v>0.55)                -> no parchment
  warm_ratio       any warm saturated pixel (hue <60 or >330, s>0.30)                 -> cool palette
  mean_sat         mean HSV saturation                                                 -> restrained palette
  cool_bias        mean(B) - mean(R) on subject (0..1)                                 -> frost key/rim
  lab_dist         chi-square distance of a/b-chroma histogram vs reference set        -> palette family
A plate passes when every metric is inside the thresholds in docs/art/style-lock-v87.json["check"].
The side-by-side sheet shows candidate | nearest reference with the metrics, for human sign-off.
"""
import json, os, sys
import numpy as np
from PIL import Image, ImageDraw, ImageFont

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
LOCK = json.load(open(os.path.join(ROOT, "docs/art/style-lock-v87.json")))
PORTRAITS = os.path.join(ROOT, "project/assets/art/portraits")
TH = LOCK["check"]

def _load(p, size=384):
    im = Image.open(p).convert("RGBA")
    im.thumbnail((size, size))
    a = np.asarray(im).astype(np.float32) / 255.0
    rgb, alpha = a[..., :3], a[..., 3]
    # subject mask: alpha, minus pixels close to the border-median background colour
    border = np.concatenate([rgb[0], rgb[-1], rgb[:, 0], rgb[:, -1]])
    bg = np.median(border, axis=0)
    diff = np.abs(rgb - bg).sum(-1)
    mask = (alpha > 0.5) & (diff > 0.10)
    if mask.mean() < 0.05:
        mask = alpha > 0.5
    return rgb, mask

def _hsv(rgb):
    r, g, b = rgb[..., 0], rgb[..., 1], rgb[..., 2]
    mx, mn = rgb.max(-1), rgb.min(-1)
    d = mx - mn + 1e-6
    h = np.where(mx == r, ((g - b) / d) % 6, np.where(mx == g, (b - r) / d + 2, (r - g) / d + 4)) * 60.0
    s = np.where(mx > 0, (mx - mn) / (mx + 1e-6), 0)
    return h, s, mx

def _lab_ab(rgb):
    def lin(c): return np.where(c > 0.04045, ((c + 0.055) / 1.055) ** 2.4, c / 12.92)
    l = lin(rgb)
    x = l @ np.array([0.4124, 0.2126, 0.0193]); y = l @ np.array([0.3576, 0.7152, 0.1192]); z = l @ np.array([0.1805, 0.0722, 0.9505])
    f = lambda t: np.where(t > 0.008856, np.cbrt(t), 7.787 * t + 16 / 116)
    fx, fy, fz = f(x / 0.9505), f(y), f(z / 1.089)
    return 500 * (fx - fy), 200 * (fy - fz)

def _hist(rgb, mask):
    a, b = _lab_ab(rgb[mask])
    h, _, _ = np.histogram2d(np.clip(a, -60, 60), np.clip(b, -60, 60), bins=12, range=[[-60, 60], [-60, 60]])
    h = h.flatten() + 1e-3
    return h / h.sum()

def metrics(p):
    rgb, mask = _load(p)
    h, s, v = _hsv(rgb)
    hm, sm, vm = h[mask], s[mask], v[mask]
    n = max(1, mask.sum())
    # natural skin is exempt from warm/cool/parchment tests (faces are the subject of portrait parts)
    skin = (hm < 32) & (sm > 0.10) & (sm < 0.62) & (vm > 0.30)
    ns = ~skin
    nn = max(1, ns.sum())
    m = {
        "gold_ratio": float(((hm > 32) & (hm < 58) & (sm > 0.42) & (vm > 0.35)).sum() / n),
        "parchment_ratio": float(((hm > 20) & (hm < 50) & (sm > 0.12) & (sm < 0.40) & (vm > 0.55) & ns).sum() / n),  # skin-exempt like warm/cool
        "warm_ratio": float(((((hm < 60) | (hm > 330)) & (sm > 0.30)) & ns).sum() / n),
        "skin_ratio": float(skin.sum() / n),
        "mean_saturation": float(sm.mean()) if mask.any() else 0.0,
        "cool_bias": float((rgb[mask][ns][:, 2] - rgb[mask][ns][:, 0]).mean()) if ns.any() else 0.0,
    }
    return m, _hist(rgb, mask)

_REF = None
def ref_hists():
    global _REF
    if _REF is None:
        _REF = [(r, metrics(os.path.join(PORTRAITS, r))[1]) for r in TH["reference_set"]]
    return _REF

def chi(a, b):
    return float(0.5 * (((a - b) ** 2) / (a + b)).sum())

def judge(p, kind="portrait"):
    m, hst = metrics(p)
    dists = sorted((chi(hst, rh), r) for r, rh in ref_hists())
    m["lab_dist"], m["nearest_ref"] = dists[0][0], dists[0][1]
    fails = []
    if m["gold_ratio"] > TH["max_gold_ratio"]: fails.append("gold")
    if m["parchment_ratio"] > TH["max_parchment_ratio"]: fails.append("parchment")
    if m["warm_ratio"] > TH["max_warm_ratio"]: fails.append("warm")
    if m["mean_saturation"] > TH["max_mean_saturation"]: fails.append("saturation")
    if m["cool_bias"] < TH["min_cool_bias"]: fails.append("not-cool")
    if kind in ("portrait", "sheet") and m["lab_dist"] > TH["max_lab_hist_distance"]: fails.append("palette-drift")
    m["pass"], m["fails"] = not fails, fails
    return m

def sheet(results, out):
    cell = 300
    W, H = cell * 2 + 360, cell * len(results)
    img = Image.new("RGB", (W, max(H, cell)), (7, 8, 12))
    dr = ImageDraw.Draw(img)
    try: font = ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSansMono.ttf", 15)
    except Exception: font = ImageFont.load_default()
    for i, (p, m) in enumerate(results):
        y = i * cell
        for j, src in enumerate([p, os.path.join(PORTRAITS, m["nearest_ref"])]):
            t = Image.open(src).convert("RGB"); t.thumbnail((cell - 8, cell - 8))
            img.paste(t, (j * cell + 4, y + 4))
        col = (94, 224, 181) if m["pass"] else (255, 122, 112)
        dr.rectangle([0, y, cell * 2 - 1, y + cell - 1], outline=col, width=3)
        lines = [os.path.basename(p)[:34], "PASS" if m["pass"] else "REJECT: " + ",".join(m["fails"])]
        lines += ["%s %.3f" % (k, m[k]) for k in ("gold_ratio", "parchment_ratio", "warm_ratio", "mean_saturation", "cool_bias", "lab_dist")]
        lines += ["ref " + m["nearest_ref"]]
        for k, ln in enumerate(lines):
            dr.text((cell * 2 + 12, y + 12 + k * 22), ln, fill=col if k == 1 else (244, 247, 251), font=font)
    img.save(out)

def main(argv):
    if not argv or argv[0] == "calibrate":
        files = [os.path.join(PORTRAITS, r) for r in TH["reference_set"]]
        kind = "portrait"
    else:
        files, kind, out_sheet, out_json = [], "portrait", None, None
        it = iter(argv[1:])
        for a in it:
            if a == "--sheet": out_sheet = next(it)
            elif a == "--json": out_json = next(it)
            elif a == "--kind": kind = next(it)
            else: files.append(a)
    res = [(f, judge(f, kind)) for f in files]
    for f, m in res:
        print(("PASS  " if m["pass"] else "REJECT") + " %-44s gold %.3f parch %.3f warm %.3f sat %.3f cool %+.3f lab %.3f %s" % (
            os.path.basename(f)[:44], m["gold_ratio"], m["parchment_ratio"], m["warm_ratio"], m["mean_saturation"], m["cool_bias"], m["lab_dist"], ",".join(m["fails"])))
    if argv and argv[0] == "check":
        if out_sheet: sheet(res, out_sheet)
        if out_json: json.dump({os.path.basename(f): m for f, m in res}, open(out_json, "w"), indent=1)
    return 0 if all(m["pass"] for _, m in res) else 1

if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
