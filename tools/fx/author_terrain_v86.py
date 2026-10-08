#!/usr/bin/env python3
"""v8.6 board terrain: seamless 256px top-down painterly textures (periodic FFT noise, hillshade,
canopy, ripples, masonry, planks). Contemporary-fantasy grade: desaturated, cool ink shadows.
Out: project/assets/art/terrain_v86/<id>.png"""
import numpy as np, pathlib
from PIL import Image
ROOT = pathlib.Path(__file__).resolve().parents[2]
OUT = ROOT / "project/assets/art/terrain_v86"; OUT.mkdir(parents=True, exist_ok=True)
N = 256
def fnoise(beta, seed, n=N):
    r = np.random.default_rng(seed)
    w = r.standard_normal((n, n))
    f = np.fft.fft2(w)
    ky = np.fft.fftfreq(n)[:, None]; kx = np.fft.fftfreq(n)[None, :]
    k = np.sqrt(kx**2 + ky**2); k[0, 0] = 1
    out = np.real(np.fft.ifft2(f / k**beta))
    out -= out.min(); out /= out.max()
    return out
def shade(h, amp=1.0, light=(-0.6, -0.8, 0.9)):
    gx = (np.roll(h, -1, 1) - np.roll(h, 1, 1)) * amp
    gy = (np.roll(h, -1, 0) - np.roll(h, 1, 0)) * amp
    nrm = np.stack([-gx, -gy, np.ones_like(h)], -1)
    nrm /= np.linalg.norm(nrm, axis=-1, keepdims=True)
    L = np.array(light); L = L / np.linalg.norm(L)
    return np.clip((nrm * L).sum(-1), 0, 1)
def mix(a, b, t):
    a = np.array(a); b = np.array(b)
    return a + (b - a) * t[..., None]
def save(name, rgb):
    Image.fromarray((np.clip(rgb, 0, 1) * 255).astype(np.uint8), "RGB").save(OUT / f"{name}.png")
    print("TERRAIN", name)
def smooth(e0, e1, x):
    t = np.clip((x - e0) / (e1 - e0), 0, 1); return t * t * (3 - 2 * t)
yy, xx = np.mgrid[0:N, 0:N].astype(float)

def ground(c1, c2, c3, seed, speck=0.035, relief=6.0):
    lo = fnoise(2.2, seed); mid = fnoise(1.4, seed + 1); hi = fnoise(0.6, seed + 2)
    col = mix(c1, c2, smooth(0.25, 0.8, lo))
    col = col * (1 - 0.35 * smooth(0.6, 0.9, mid)[..., None]) + np.array(c3) * 0.35 * smooth(0.6, 0.9, mid)[..., None]
    col += (hi[..., None] - 0.5) * speck * 2
    sh = shade(lo * 0.6 + mid * 0.4, relief)
    return col * (0.78 + 0.32 * sh[..., None])

# --- base grounds per biome family
save("grass", ground((0.15, 0.20, 0.18), (0.22, 0.28, 0.22), (0.30, 0.35, 0.27), 11))
d = ground((0.25, 0.23, 0.21), (0.34, 0.31, 0.27), (0.40, 0.37, 0.31), 21, 0.05)
cr = fnoise(1.6, 23); ridge = (1 - np.abs(cr * 2 - 1)) ** 14
save("dust", d * (1 - 0.35 * ridge[..., None]))
s = ground((0.70, 0.76, 0.84), (0.86, 0.90, 0.95), (0.95, 0.97, 1.0), 31, 0.02, 9.0)
save("snow", s)
# paved stone (running bond)
def masonry(slab_w, slab_h, base, var, grout, seed, bevel=0.22):
    r = np.random.default_rng(seed)
    rows = N // slab_h; cols = N // slab_w
    col = np.zeros((N, N, 3)); tint = np.zeros((N, N))
    edge = np.zeros((N, N)); lit = np.zeros((N, N))
    for ry in range(rows):
        off = (slab_w // 2) * (ry % 2)
        for cx in range(cols):
            t = r.uniform(-1, 1)
            x0 = cx * slab_w + off
            xs = (np.arange(x0, x0 + slab_w)) % N
            ys = np.arange(ry * slab_h, ry * slab_h + slab_h)
            tint[np.ix_(ys, xs)] = t
            lx = (np.arange(slab_w))[None, :].repeat(slab_h, 0).astype(float)
            ly = (np.arange(slab_h))[:, None].repeat(slab_w, 1).astype(float)
            dist = np.minimum.reduce([lx, ly, slab_w - 1 - lx, slab_h - 1 - ly])
            edge[np.ix_(ys, xs)] = dist
            lit[np.ix_(ys, xs)] = np.where((lx < 3) | (ly < 3), 1.0, np.where((lx > slab_w - 4) | (ly > slab_h - 4), -1.0, 0.0))
    n = fnoise(0.9, seed + 5); n2 = fnoise(2.0, seed + 6)
    col = np.array(base)[None, None, :] + tint[..., None] * np.array(var) + (n[..., None] - 0.5) * 0.06 + (n2[..., None] - 0.5) * 0.08
    col = col * (1 + bevel * lit[..., None] * smooth(0, 3, 3 - np.minimum(edge, 3))[..., None])
    g = smooth(0.0, 2.2, edge)
    col = mix(grout, (0, 0, 0), np.zeros((N, N))) * (1 - g[..., None]) + col * g[..., None]
    return col
save("stone", masonry(64, 32, (0.29, 0.31, 0.34), (0.035, 0.035, 0.04), (0.10, 0.11, 0.13), 41))
save("fort", masonry(64, 64, (0.24, 0.26, 0.30), (0.03, 0.03, 0.035), (0.06, 0.07, 0.09), 51, 0.42))

# forest canopy
def forest(seed=61):
    r = np.random.default_rng(seed)
    base = ground((0.07, 0.10, 0.09), (0.10, 0.14, 0.12), (0.12, 0.16, 0.13), seed, 0.02)
    col = base.copy()
    trees = [(r.uniform(0, N), r.uniform(0, N), r.uniform(15, 27)) for _ in range(46)]
    trees.sort(key=lambda t: t[1])
    angn = fnoise(1.0, seed + 3)
    for (cx, cy, rad) in trees:
        dx = (xx - cx + N / 2) % N - N / 2; dy = (yy - cy + N / 2) % N - N / 2
        # shadow
        sdx = dx - 7; sdy = dy - 9
        sd = np.sqrt(sdx**2 + sdy**2)
        sm = 1 - smooth(rad * 0.75, rad * 1.15, sd)
        col *= (1 - 0.45 * sm)[..., None]
        ang = np.arctan2(dy, dx)
        lobe = 1 + 0.12 * np.sin(ang * r.integers(5, 9) + r.uniform(0, 6)) + 0.08 * (angn - 0.5)
        dd = np.sqrt(dx**2 + dy**2) / lobe
        m = 1 - smooth(rad - 1.5, rad + 0.5, dd)
        hc = r.uniform(0, 1)
        cc = mix((0.12, 0.22, 0.17), (0.20, 0.31, 0.22), np.full((N, N), hc))
        # dome shading: light from top-left
        nz = np.sqrt(np.clip(1 - (dd / rad) ** 2, 0, 1))
        lam = np.clip((-dx * 0.55 - dy * 0.7) / (rad + 1e-6) * 0.6 + nz * 0.8, 0, 1.2)
        tex = fnoise(0.5, seed + int(hc * 1000))
        tc = cc * (0.55 + 0.6 * lam[..., None]) * (0.9 + 0.2 * tex[..., None])
        col = col * (1 - m[..., None]) + tc * m[..., None]
    return col
save("forest", forest())

# hill: hillshade + topographic contours
h = fnoise(2.7, 71) * 0.8 + fnoise(1.6, 72) * 0.2
hs = shade(h, 40.0)
c = mix((0.24, 0.24, 0.20), (0.38, 0.36, 0.28), smooth(0.2, 0.9, h))
c = c * (0.45 + 0.75 * hs[..., None])
fr = (h * 9.0) % 1.0
contour = smooth(0.0, 0.06, fr) * (1 - smooth(0.94, 1.0, fr))
c = c * (0.86 + 0.14 * contour[..., None])
c += (fnoise(0.6, 73)[..., None] - 0.5) * 0.05
save("hill", c)

# water: deep teal, ripple caustics, specular
n1 = fnoise(1.8, 81); n2 = fnoise(1.1, 82); n3 = fnoise(0.7, 83)
w = mix((0.05, 0.12, 0.17), (0.08, 0.20, 0.27), smooth(0.2, 0.9, n1))
rip = np.sin((n2 * 26 + n1 * 8) * np.pi)
lines = smooth(0.82, 0.98, rip)
w = w + lines[..., None] * np.array([0.10, 0.22, 0.26]) * (0.4 + 0.6 * n3[..., None])
spec = smooth(0.93, 1.0, n3) * smooth(0.5, 0.95, lines)
w += spec[..., None] * 0.25
save("water", w)

# bridge: planks over shadowed water
pl = np.zeros((N, N, 3))
r = np.random.default_rng(91)
ph = 32
grain = np.array(Image.fromarray((fnoise(1.2, 92) * 255).astype(np.uint8)).resize((N, N // 8)).resize((N, N), Image.BILINEAR)) / 255.0
for i in range(N // ph):
    t = r.uniform(-1, 1)
    base = np.array((0.32, 0.27, 0.22)) + t * 0.035
    ys = slice(i * ph, (i + 1) * ph)
    pl[ys] = base
ly = (yy % ph)
gap = smooth(0, 2.5, ly) * (1 - smooth(ph - 3, ph - 0.5, ly))
lit = np.where(ly < 3, 1.12, np.where(ly > ph - 5, 0.82, 1.0))
pl = pl * (0.82 + 0.3 * grain[..., None]) * lit[..., None]
pl = pl * gap[..., None] + np.array((0.04, 0.07, 0.09)) * (1 - gap[..., None])
# nails
for i in range(N // ph):
    for nx in (20, 236):
        d2 = (xx - nx) ** 2 + (yy - (i * ph + ph / 2)) ** 2
        pl *= (1 - 0.5 * (d2 < 4.5))[..., None]
save("bridge", pl)

# edge-breakup noise (grey, tileable)
nz = fnoise(1.5, 101)
Image.fromarray((nz * 255).astype(np.uint8), "L").convert("RGB").save(OUT / "noise.png"); print("TERRAIN noise")
