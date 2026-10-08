#!/usr/bin/env python3
"""v8.5 authored VFX — replaces every farmed/mis-sliced battle FX frame.

Why: diffusion-farmed "FX sheets" came back as illustration panels (characters,
castles, white paper) and legacy slices were fragments / opaque squares. Game VFX
must be authored. This renders additive light fields at 4x supersample, tone-maps
them (1-exp) and converts to straight-alpha RGBA so they read on dark maps at
64px cells. Palette = design-system-v8: frost / mint / coral / ember, white cores.

Outputs into project/assets/art/fx/:
  <kind>_dense_<i>.png  128px hi-res (battle draws scaled to a per-kind size)
  <kind>_<i>.png        64px legacy names (other call sites)
"""
from pathlib import Path
import math
import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
FX = ROOT / "project/assets/art/fx"
SS = 4

FROST = np.array([0.55, 0.80, 1.00])
ICE = np.array([0.80, 0.93, 1.00])
MINT = np.array([0.35, 1.00, 0.72])
CORAL = np.array([1.00, 0.42, 0.36])
EMBER = np.array([1.00, 0.70, 0.30])
WHITE = np.array([1.0, 1.0, 1.0])


def ease_out(t):
    return 1 - (1 - t) ** 3


def ease_in_out(t):
    return 3 * t * t - 2 * t * t * t


class Canvas:
    def __init__(self, w, h=None):
        self.w, self.h = w * SS, (h or w) * SS
        self.ow, self.oh = w, (h or w)
        ys, xs = np.mgrid[0:self.h, 0:self.w].astype(np.float32)
        self.x = xs / self.w  # 0..1
        self.y = ys / self.h
        self.aspect = self.w / self.h
        self.L = np.zeros((self.h, self.w, 3), np.float32)

    def _add(self, field, color, k):
        self.L += field[..., None] * (np.asarray(color, np.float32) * k)

    def blob(self, cx, cy, r, color, k=1.0, power=2.0):
        dx = (self.x - cx) * self.aspect
        dy = self.y - cy
        d = np.sqrt(dx * dx + dy * dy) / max(r, 1e-4)
        self._add(np.exp(-d ** power), color, k)

    def seg(self, x0, y0, x1, y1, w0, w1, color, k=1.0, glow=2.2):
        ax, ay = x0 * self.aspect, y0
        bx, by = x1 * self.aspect, y1
        px, py = self.x * self.aspect, self.y
        vx, vy = bx - ax, by - ay
        ll = vx * vx + vy * vy + 1e-9
        t = np.clip(((px - ax) * vx + (py - ay) * vy) / ll, 0, 1)
        dx, dy = px - (ax + t * vx), py - (ay + t * vy)
        d = np.sqrt(dx * dx + dy * dy)
        w = w0 + (w1 - w0) * t
        core = np.exp(-(d / np.maximum(w, 1e-4)) ** 2)
        halo = np.exp(-(d / np.maximum(w * glow * 2.0, 1e-4)) ** 1.5) * 0.35
        self._add(core + halo, color, k)

    def ring(self, cx, cy, r, w, color, k=1.0, a0=None, a1=None, dashes=0, duty=0.6, rot=0.0, sy=1.0, glow=True):
        dx = (self.x - cx) * self.aspect
        dy = (self.y - cy) / sy
        dist = np.sqrt(dx * dx + dy * dy)
        d = np.abs(dist - r)
        f = np.exp(-(d / max(w, 1e-4)) ** 2)
        if glow:
            f = f + np.exp(-(d / max(w * 4, 1e-4)) ** 1.4) * 0.3
        ang = (np.arctan2(dy, dx) - rot) % (2 * math.pi)
        if a0 is not None:
            span = (a1 - a0) % (2 * math.pi) or 2 * math.pi
            rel = (ang - a0 % (2 * math.pi)) % (2 * math.pi)
            f = f * (rel <= span)
        if dashes:
            ph = (ang / (2 * math.pi) * dashes) % 1.0
            f = f * (ph < duty)
        self._add(f, color, k)

    def fill_disc(self, cx, cy, r, color, k=1.0, soft=0.02, sy=1.0):
        dx = (self.x - cx) * self.aspect
        dy = (self.y - cy) / sy
        d = np.sqrt(dx * dx + dy * dy)
        f = np.clip((r - d) / max(soft, 1e-4), 0, 1)
        self._add(f, color, k)

    def image(self):
        rgb = 1.0 - np.exp(-self.L)
        a = np.clip(rgb.max(2) * 1.35, 0, 1) ** 0.85
        col = np.where(a[..., None] > 1e-4, rgb / np.maximum(a[..., None], 1e-4), 0)
        col = np.clip(col, 0, 1)
        # premultiplied float box-downsample (SSxSS) -> no dark fringes / no uint8 loss
        pm = np.dstack([col * a[..., None], a])
        pm = pm.reshape(self.oh, SS, self.ow, SS, 4).mean(axis=(1, 3))
        al = pm[..., 3:4]
        rgb2 = np.where(al > 1e-4, pm[..., :3] / np.maximum(al, 1e-4), 0)
        out = np.dstack([np.clip(rgb2, 0, 1), np.clip(al, 0, 1)])
        return Image.fromarray((out * 255 + 0.5).astype(np.uint8), "RGBA")


def rng(seed):
    return np.random.default_rng(seed)


# ---------------------------------------------------------------- effects
def fx_hit(t, size=128, palette=(ICE, FROST, EMBER), shards=14, seed=3, reach=0.46, crit=False):
    c = Canvas(size)
    r = rng(seed)
    core, mid, hot = palette
    e = ease_out(t)
    fade = (1 - t) ** 1.25
    c.blob(0.5, 0.5, 0.10 + 0.05 * e, WHITE, 3.2 * (1 - t) ** 3)
    c.blob(0.5, 0.5, 0.20 + 0.10 * e, mid, 0.9 * (1 - t) ** 2)
    angs = r.uniform(0, 2 * math.pi, shards)
    lens = r.uniform(0.55, 1.0, shards)
    for i, (a, ln) in enumerate(zip(angs, lens)):
        r0 = 0.04 + 0.30 * e * ln
        r1 = 0.08 + reach * e * ln
        x0, y0 = 0.5 + math.cos(a) * r0, 0.5 + math.sin(a) * r0
        x1, y1 = 0.5 + math.cos(a) * r1, 0.5 + math.sin(a) * r1
        col = hot if i % 3 == 0 else core
        c.seg(x0, y0, x1, y1, 0.016 * (1 - t * 0.6), 0.002, col, 1.6 * fade)
    c.ring(0.5, 0.5, 0.12 + 0.32 * e, 0.010 + 0.006 * (1 - t), mid, 1.3 * (1 - t) ** 2)
    if crit:
        c.ring(0.5, 0.5, 0.06 + 0.22 * e, 0.008, hot, 1.1 * (1 - t) ** 2)
        star = 2.4 * max(0.0, 1 - t * 2.2)
        c.seg(0.5 - 0.48 * e, 0.5, 0.5 + 0.48 * e, 0.5, 0.008, 0.008, WHITE, star)
        c.seg(0.5, 0.5 - 0.40 * e, 0.5, 0.5 + 0.40 * e, 0.006, 0.006, WHITE, star * 0.8)
    for i in range(10):  # flying sparks
        a = r.uniform(0, 2 * math.pi)
        sp = r.uniform(0.25, 0.48)
        d = 0.06 + sp * e
        c.blob(0.5 + math.cos(a) * d, 0.5 + math.sin(a) * d + 0.05 * t * t, 0.012, hot, 1.4 * fade)
    return c.image()


def fx_slash(t, size=128, col=FROST):
    c = Canvas(size)
    a0, a1 = math.radians(-200), math.radians(40)
    head = ease_out(min(1.0, (t + 0.12) * 2.2))
    tail = ease_in_out(max(0.0, min(1.0, (t - 0.30) * 1.6)))
    fade = 1.0 if t < 0.55 else max(0.0, 1 - (t - 0.55) / 0.45)
    R = 0.36
    n = 70
    ah, at = a0 + (a1 - a0) * head, a0 + (a1 - a0) * tail
    if ah - at < 1e-3:
        return c.image()
    for i in range(n):
        u = i / (n - 1)
        a = at + (ah - at) * u
        prof = math.sin(math.pi * min(1, u * 1.05)) ** 0.7
        rr = R + 0.03 * prof
        x, y = 0.5 + math.cos(a) * rr, 0.52 + math.sin(a) * rr * 0.82
        w = 0.010 + 0.034 * prof
        c.blob(x, y, w, WHITE, 0.85 * fade * (0.35 + 0.65 * u))
        c.blob(x, y, w * 2.4, col, 0.40 * fade)
    # leading glint
    x, y = 0.5 + math.cos(ah) * (R + 0.02), 0.52 + math.sin(ah) * (R + 0.02) * 0.82
    c.blob(x, y, 0.05, WHITE, 2.2 * fade * (1 - t))
    return c.image()


def fx_heal(t, size=128):
    c = Canvas(size)
    r = rng(11)
    e = ease_out(t)
    bell = math.sin(math.pi * min(1, t * 1.1))
    c.ring(0.5, 0.70, 0.16 + 0.24 * e, 0.012, MINT, 1.4 * (1 - t) ** 1.5, sy=0.38)
    c.fill_disc(0.5, 0.70, 0.14 + 0.20 * e, MINT, 0.12 * (1 - t), soft=0.08, sy=0.38)
    for i in range(16):
        x = 0.5 + r.uniform(-0.28, 0.28)
        sp = r.uniform(0.35, 0.65)
        ph = r.uniform(0, 0.35)
        tt = max(0.0, t - ph)
        y = 0.74 - sp * ease_out(min(1, tt * 1.4))
        k = math.sin(math.pi * min(1, tt * 1.5)) * 1.6
        c.blob(x, y, 0.013, ICE if i % 4 == 0 else MINT, k)
        c.seg(x, y, x, y + 0.06, 0.006, 0.001, MINT, k * 0.5)
    pk = 2.0 * max(0.0, math.sin(math.pi * min(1.0, t * 1.6)))
    s = 0.10
    c.seg(0.5, 0.42 - s, 0.5, 0.42 + s, 0.020, 0.020, MINT, pk)
    c.seg(0.5 - s, 0.42, 0.5 + s, 0.42, 0.020, 0.020, MINT, pk)
    c.blob(0.5, 0.42, 0.06, WHITE, pk * 0.6)
    return c.image()


def fx_lock(t, size=128):
    c = Canvas(size)
    e = ease_out(t)
    rad = 0.46 - 0.16 * e
    fade = 1.0 if t < 0.7 else max(0.0, 1 - (t - 0.7) / 0.3)
    c.ring(0.5, 0.5, rad, 0.010, CORAL, 1.3 * fade, dashes=12, duty=0.55, rot=t * 0.8)
    off = 0.40 - 0.14 * e
    L = 0.10
    for sx, sy in ((-1, -1), (1, -1), (-1, 1), (1, 1)):
        cx, cy = 0.5 + sx * off, 0.5 + sy * off
        c.seg(cx, cy, cx - sx * L, cy, 0.012, 0.012, CORAL, 1.5 * fade)
        c.seg(cx, cy, cx, cy - sy * L, 0.012, 0.012, CORAL, 1.5 * fade)
    c.blob(0.5, 0.5, 0.16, CORAL, 1.6 * max(0.0, (t - 0.55) * 2.2) * fade)
    return c.image()


def fx_shield(t, size=128):
    c = Canvas(size)
    prog = min(1.0, t * 2.0)
    fade = 1.0 if t < 0.75 else max(0.0, 1 - (t - 0.75) / 0.25)
    R = 0.36
    pts = [(0.5 + R * math.cos(math.radians(90 + 60 * i)), 0.5 + R * math.sin(math.radians(90 + 60 * i))) for i in range(7)]
    total = prog * 6
    for i in range(6):
        f = max(0.0, min(1.0, total - i))
        if f <= 0:
            continue
        (x0, y0), (x1, y1) = pts[i], pts[i + 1]
        c.seg(x0, y0, x0 + (x1 - x0) * f, y0 + (y1 - y0) * f, 0.011, 0.011, FROST, 1.6 * fade)
    c.fill_disc(0.5, 0.5, R * 0.86, FROST, 0.16 * prog * fade, soft=0.10)
    sh = max(0.0, min(1.0, (t - 0.3) * 2.0))
    c.ring(0.5, 0.5, R * 0.62, 0.006, ICE, 0.9 * sh * fade, dashes=6, duty=0.7, rot=t * 1.2)
    c.blob(0.5, 0.5, 0.08, WHITE, 0.9 * prog * fade)
    return c.image()


def fx_spark(t, size=128):
    c = Canvas(size)
    r = rng(29)
    e = ease_out(t)
    fade = (1 - t) ** 1.3
    for i in range(22):
        a = r.uniform(0, 2 * math.pi)
        sp = r.uniform(0.18, 0.46)
        d = sp * e
        x, y = 0.5 + math.cos(a) * d, 0.5 + math.sin(a) * d + 0.12 * t * t
        xb, yb = 0.5 + math.cos(a) * d * 0.7, 0.5 + math.sin(a) * d * 0.7 + 0.10 * t * t
        c.seg(xb, yb, x, y, 0.004, 0.009, EMBER if i % 2 else ICE, 1.6 * fade)
    c.blob(0.5, 0.5, 0.08, WHITE, 2.0 * (1 - t) ** 3)
    return c.image()


def fx_pop(t, size=128):
    c = Canvas(size)
    e = ease_out(t)
    c.ring(0.5, 0.5, 0.14 + 0.28 * e, 0.016 * (1 - t) + 0.004, CORAL, 1.5 * (1 - t) ** 1.5)
    for i in range(8):
        a = i * math.pi / 4 + 0.3
        r0, r1 = 0.16 + 0.18 * e, 0.24 + 0.24 * e
        c.seg(0.5 + math.cos(a) * r0, 0.5 + math.sin(a) * r0, 0.5 + math.cos(a) * r1, 0.5 + math.sin(a) * r1, 0.012, 0.003, ICE, 1.3 * (1 - t) ** 2)
    c.blob(0.5, 0.5, 0.10, WHITE, 1.8 * (1 - t) ** 3)
    return c.image()


def fx_zoc(t, size=128):
    c = Canvas(size)
    br = 0.5 + 0.5 * math.sin(2 * math.pi * t)
    c.ring(0.5, 0.5, 0.40 + 0.04 * br, 0.010, CORAL, 0.9 + 0.6 * br, dashes=16, duty=0.5, rot=t * math.pi / 4)
    c.ring(0.5, 0.5, 0.30, 0.006, CORAL, 0.35 + 0.3 * br)
    return c.image()


def fx_turn(t, size=128):
    c = Canvas(size)
    bell = math.sin(math.pi * min(1.0, t * 1.15))
    c.seg(0.04, 0.5, 0.96, 0.5, 0.010, 0.010, ICE, 1.8 * bell)
    c.seg(0.5, 0.14, 0.5, 0.86, 0.008, 0.008, ICE, 1.3 * bell)
    c.seg(0.28, 0.28, 0.72, 0.72, 0.005, 0.005, FROST, 0.8 * bell)
    c.seg(0.72, 0.28, 0.28, 0.72, 0.005, 0.005, FROST, 0.8 * bell)
    c.blob(0.5, 0.5, 0.12, WHITE, 2.4 * bell)
    c.ring(0.5, 0.5, 0.18 + 0.2 * ease_out(t), 0.008, FROST, 1.2 * (1 - t))
    return c.image()


def fx_unlock(t, size=128):
    c = Canvas(size)
    r = rng(41)
    e = ease_out(t)
    fade = 1.0 if t < 0.6 else max(0.0, 1 - (t - 0.6) / 0.4)
    c.ring(0.5, 0.5, 0.30, 0.012, MINT, 1.6 * fade, a0=0.0, a1=max(0.01, 2 * math.pi * min(1.0, t * 1.8)), rot=-math.pi / 2)
    c.ring(0.5, 0.5, 0.20 + 0.25 * e, 0.008, ICE, 1.0 * (1 - t) ** 2)
    c.blob(0.5, 0.5, 0.12, MINT, 1.8 * max(0.0, (t - 0.35)) * fade)
    for i in range(12):
        a = r.uniform(0, 2 * math.pi)
        d = 0.30 + 0.16 * e
        c.blob(0.5 + math.cos(a) * d, 0.5 + math.sin(a) * d - 0.1 * t, 0.012, ICE, 1.4 * fade * min(1.0, t * 3))
    return c.image()


def fx_select(t, size=128):
    """Looping selection reticle (frame t in [0,1) wraps)."""
    c = Canvas(size)
    br = 0.5 + 0.5 * math.cos(2 * math.pi * t)
    rot = 2 * math.pi * t / 4  # quarter turn per loop -> seamless with 4 ticks
    c.ring(0.5, 0.5, 0.42 - 0.015 * br, 0.008, FROST, 1.0 + 0.4 * br, dashes=4, duty=0.72, rot=rot + math.pi / 4 * 0.28)
    for i in range(4):
        a = rot + i * math.pi / 2
        r0, r1 = 0.44, 0.50
        c.seg(0.5 + math.cos(a) * r0, 0.5 + math.sin(a) * r0, 0.5 + math.cos(a) * r1, 0.5 + math.sin(a) * r1, 0.012, 0.006, ICE, 1.6)
    c.ring(0.5, 0.5, 0.34, 0.004, FROST, 0.35 + 0.25 * br)
    return c.image()


def wash(col, size=64, bracket=0.30):
    c = Canvas(size)
    m = 0.06
    # thin full border
    for (x0, y0, x1, y1) in ((m, m, 1 - m, m), (1 - m, m, 1 - m, 1 - m), (1 - m, 1 - m, m, 1 - m), (m, 1 - m, m, m)):
        c.seg(x0, y0, x1, y1, 0.012, 0.012, col, 0.35, glow=1.2)
    # bright corner brackets
    for sx, sy in ((0, 0), (1, 0), (0, 1), (1, 1)):
        cx = m if sx == 0 else 1 - m
        cy = m if sy == 0 else 1 - m
        dx = bracket if sx == 0 else -bracket
        dy = bracket if sy == 0 else -bracket
        c.seg(cx, cy, cx + dx, cy, 0.018, 0.010, col, 1.4, glow=1.2)
        c.seg(cx, cy, cx, cy + dy, 0.018, 0.010, col, 1.4, glow=1.2)
    c.fill_disc(0.5, 0.5, 0.62, col, 0.10, soft=0.25)
    return c.image()


def fx_seal(t, size=128):
    c = Canvas(size)
    p1 = min(1.0, t * 1.6)
    p2 = max(0.0, min(1.0, t * 1.6 - 0.15))
    bloom = max(0.0, (t - 0.55) / 0.45)
    c.ring(0.40, 0.5, 0.20, 0.010, MINT, 1.6, a0=0.0, a1=max(0.01, 2 * math.pi * p1), rot=math.pi)
    c.ring(0.60, 0.5, 0.20, 0.010, FROST, 1.6, a0=0.0, a1=max(0.01, 2 * math.pi * p2), rot=0.0)
    c.ring(0.5, 0.5, 0.44, 0.005, ICE, 1.0 * min(1.0, t * 2), dashes=24, duty=0.35, rot=t * 0.6)
    c.ring(0.5, 0.5, 0.40, 0.004, FROST, 0.5 * min(1.0, t * 2))
    c.blob(0.5, 0.5, 0.10 + 0.06 * bloom, WHITE, 2.2 * bloom * (1.2 - bloom * 0.4))
    c.blob(0.5, 0.5, 0.24, MINT, 0.6 * bloom)
    return c.image()


def fx_link(t, w=256, h=64):
    c = Canvas(w, h)
    x0, x1 = 0.08, 0.92
    head = x0 + (x1 - x0) * ease_out(min(1.0, t * 1.5))
    for nx, col in ((x0, MINT), (x1, FROST)):
        c.blob(nx, 0.5, 0.13, WHITE, 1.6)
        c.ring(nx, 0.5, 0.26, 0.03, col, 1.3)
    n = 48
    for i in range(n):
        u = i / (n - 1)
        x = x0 + (head - x0) * u
        y = 0.5 + 0.12 * math.sin(u * math.pi * 2 + t * 6) * (1 - abs(2 * u - 1))
        col = MINT * (1 - u) + FROST * u
        c.blob(x, y, 0.05, col, 0.8)
    for k in range(3):
        px = x0 + ((t * 1.4 + k / 3) % 1.0) * (head - x0)
        c.blob(px, 0.5, 0.10, WHITE, 1.6 * min(1.0, t * 3))
    return c.image()


def write(kind, fn, frames=6, legacy=True, dense=True, legacy_size=64, **kw):
    for i in range(frames):
        t = i / frames  # never the fully-faded t=1 frame
        im = fn(t, **kw)
        if dense:
            im.save(FX / f"{kind}_dense_{i}.png")
        if legacy:
            im.resize((legacy_size, legacy_size), Image.LANCZOS).save(FX / f"{kind}_{i}.png")
    print("FX", kind, frames)


def main():
    write("hit", fx_hit, legacy=False)
    for i in range(6):  # legacy overlay name used by battle fallback
        fx_hit(i / 6).resize((64, 64), Image.LANCZOS).save(FX / f"hit_spark_{i}.png")
    write("slash", fx_slash)
    write("heal", fx_heal)
    write("crit", lambda t: fx_hit(t, palette=(WHITE, CORAL, EMBER), shards=18, seed=7, reach=0.5, crit=True))
    write("lock", fx_lock)
    write("shield", fx_shield)
    write("spark", fx_spark)
    write("dmg_pop", fx_pop, legacy_size=48)
    write("zoc_pulse", fx_zoc)
    write("turn_flash", fx_turn)
    write("unlock", fx_unlock)
    write("select", fx_select, frames=8)
    write("marriage_seal", fx_seal, frames=8, legacy=False)
    for i in range(8):
        fx_link(i / 8).save(FX / f"lineage_link_{i}.png")
    print("FX lineage_link 8")
    wash(FROST).save(FX / "select_wash.png")
    wash(np.array([0.45, 0.95, 0.85])).save(FX / "move_wash.png")
    wash(CORAL).save(FX / "attack_wash.png")
    print("FX washes 3")


if __name__ == "__main__":
    main()
