#!/usr/bin/env python3
"""Build project/assets/art/heraldry_vector.json — hand-authored vector heraldry art.

Original frost-palette designs. Fragments are SVG snippets with placeholders that the
Godot renderer (CKHeraldryVector) substitutes at render time:
  {T} tincture  {TL} tincture light  {TD} tincture dark  {K} ink outline
  {M0}..{M4} frost-metal ramp (dark→bright)  {A}/{AD}/{AL} mantling outer  {B}/{BD} mantling lining
  {G} gem (frost azure)  {GL} gem light  {S} supporter body  {SL} supporter light  {SD} supporter dark
Charges / cadency live in a 100x100 box centred on (50,50).
"""
from __future__ import annotations
import json, math
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "project/assets/art/heraldry_vector.json"
SW = 'stroke="{K}" stroke-width="2.6" stroke-linejoin="round" stroke-linecap="round"'


def f(v: float) -> str:
    return f"{v:.2f}".rstrip("0").rstrip(".")


def pts(p) -> str:
    return " ".join(f"{f(x)},{f(y)}" for x, y in p)


def star(cx, cy, n, r1, r2, rot=-90.0):
    out = []
    for i in range(n * 2):
        r = r1 if i % 2 == 0 else r2
        a = math.radians(rot + i * 180.0 / n)
        out.append((cx + r * math.cos(a), cy + r * math.sin(a)))
    return out


def main_shape(d: str, extra: str = "") -> str:
    return f'<path d="{d}" fill="{{T}}" {SW} {extra}/>'


def poly(p, fill="{T}", stroke=True, extra="") -> str:
    s = SW if stroke else 'stroke="none"'
    return f'<polygon points="{pts(p)}" fill="{fill}" {s} {extra}/>'


def hl(d: str, col="{TL}", w=1.8, op=0.85) -> str:
    return f'<path d="{d}" fill="none" stroke="{col}" stroke-width="{w}" stroke-linecap="round" stroke-linejoin="round" opacity="{op}"/>'


def circle(cx, cy, r, fill="{T}", stroke=True, extra="") -> str:
    s = SW if stroke else 'stroke="none"'
    return f'<circle cx="{f(cx)}" cy="{f(cy)}" r="{f(r)}" fill="{fill}" {s} {extra}/>'


def ring_d(cx, cy, r1, r2) -> str:
    return (f"M{f(cx-r1)},{f(cy)} a{f(r1)},{f(r1)} 0 1,0 {f(2*r1)},0 a{f(r1)},{f(r1)} 0 1,0 {f(-2*r1)},0 Z "
            f"M{f(cx-r2)},{f(cy)} a{f(r2)},{f(r2)} 0 1,1 {f(2*r2)},0 a{f(r2)},{f(r2)} 0 1,1 {f(-2*r2)},0 Z")


def crescent_d(cx, cy, r, off) -> str:
    # outer circle minus offset inner circle, horns up
    return (f"M{f(cx-r)},{f(cy)} A{f(r)},{f(r)} 0 1,0 {f(cx+r)},{f(cy)} "
            f"A{f(r*0.82)},{f(r*0.82)} 0 1,1 {f(cx-r)},{f(cy)} Z")


def leaf_d(cx, cy, l, w, rot=0.0) -> str:
    a = math.radians(rot)
    def tp(x, y):
        return (cx + x * math.cos(a) - y * math.sin(a), cy + x * math.sin(a) + y * math.cos(a))
    p0, p1 = tp(0, -l), tp(0, l)
    c1, c2 = tp(w * 1.25, -l * 0.35), tp(w * 0.9, l * 0.55)
    c3, c4 = tp(-w * 0.9, l * 0.55), tp(-w * 1.25, -l * 0.35)
    return (f"M{f(p0[0])},{f(p0[1])} C{f(c1[0])},{f(c1[1])} {f(c2[0])},{f(c2[1])} {f(p1[0])},{f(p1[1])} "
            f"C{f(c3[0])},{f(c3[1])} {f(c4[0])},{f(c4[1])} {f(p0[0])},{f(p0[1])} Z")


def wave_band(y, amp, thick, x0=10, x1=90, n=3) -> str:
    seg = (x1 - x0) / n
    top = f"M{f(x0)},{f(y)} "
    for i in range(n):
        xa = x0 + i * seg
        top += f"C{f(xa+seg*0.25)},{f(y-amp)} {f(xa+seg*0.75)},{f(y+amp)} {f(xa+seg)},{f(y)} "
    bot = f"L{f(x1)},{f(y+thick)} "
    for i in range(n, 0, -1):
        xa = x0 + i * seg
        bot += f"C{f(xa-seg*0.25)},{f(y+thick+amp)} {f(xa-seg*0.75)},{f(y+thick-amp)} {f(xa-seg)},{f(y+thick)} "
    return top + bot + "Z"


def wave_line(y, amp, x0=14, x1=86, n=3) -> str:
    seg = (x1 - x0) / n
    d = f"M{f(x0)},{f(y)} "
    for i in range(n):
        xa = x0 + i * seg
        d += f"C{f(xa+seg*0.25)},{f(y-amp)} {f(xa+seg*0.75)},{f(y+amp)} {f(xa+seg)},{f(y)} "
    return d


def snowflake(cx, cy, r, arm_w=4.2) -> str:
    out = []
    for k in range(6):
        a = math.radians(k * 60 - 90)
        ca, sa = math.cos(a), math.sin(a)
        def tp(u, v):
            return (cx + u * ca - v * sa, cy + u * sa + v * ca)
        arm = [tp(0, -arm_w/2), tp(r*0.55, -arm_w/2), tp(r*0.68, -r*0.22), tp(r*0.74, -r*0.18),
               tp(r*0.66, -arm_w/2), tp(r, -arm_w*0.25), tp(r*1.04, 0), tp(r, arm_w*0.25), tp(r*0.66, arm_w/2),
               tp(r*0.74, r*0.18), tp(r*0.68, r*0.22), tp(r*0.55, arm_w/2), tp(0, arm_w/2)]
        out.append(arm)
    d = ""
    for arm in out:
        d += "M" + " L".join(f"{f(x)},{f(y)}" for x, y in arm) + " Z "
    return d


CHARGES: dict[str, str] = {}
C = CHARGES

C["ring"] = main_shape(ring_d(50, 50, 30, 19), 'fill-rule="evenodd"') + hl("M30,40 A22,22 0 0,1 46,25")
C["annulet"] = main_shape(ring_d(50, 50, 26, 18), 'fill-rule="evenodd"') + hl("M32,42 A19,19 0 0,1 44,29")
C["hollow"] = main_shape("M50,14 L84,50 L50,86 L16,50 Z M50,32 L68,50 L50,68 L32,50 Z", 'fill-rule="evenodd"') + hl("M24,50 L50,22")
C["lozenge"] = poly([(50, 12), (80, 50), (50, 88), (20, 50)]) + hl("M27,50 L50,21 L73,50") + \
    '<path d="M50,12 L50,88 M20,50 L80,50" stroke="{TD}" stroke-width="1.4" opacity="0.6"/>'
C["arc"] = main_shape("M14,66 A38,38 0 0,1 86,66 L74,66 A26,26 0 0,0 26,66 Z") + hl("M21,60 A31,31 0 0,1 50,34")
C["shadow_arc"] = main_shape("M12,62 A40,40 0 0,1 88,62 L76,62 A28,28 0 0,0 24,62 Z") + \
    main_shape(crescent_d(50, 62, 14, 0).replace("Z", "Z"), 'transform="rotate(180 50 62)"') + \
    poly(star(50, 26, 4, 8, 2.6)) + hl("M19,56 A33,33 0 0,1 46,30")
C["crescent"] = main_shape("M22,40 A30,30 0 1,0 78,40 A25,25 0 1,1 22,40 Z") + hl("M27,52 A24,24 0 0,0 50,72")
C["wave"] = main_shape(wave_band(38, 9, 9)) + main_shape(wave_band(56, 9, 9)) + hl(wave_line(39.5, 8, 14, 86))
C["jade_wave"] = main_shape(wave_band(30, 10, 10)) + main_shape(wave_band(50, 10, 10)) + main_shape(wave_band(70, 8, 8, 20, 80, 2)) + \
    hl(wave_line(31.5, 9, 14, 86)) + hl(wave_line(51.5, 9, 14, 86))
C["tide"] = main_shape("M12,70 C24,40 46,26 66,32 C80,36 86,50 78,58 C70,64 60,58 62,50 C64,44 72,46 72,50 "
                       "C66,40 46,40 36,56 C30,66 32,72 36,76 L12,76 Z") + hl("M20,66 C30,46 46,36 62,38")
C["leaf"] = main_shape(leaf_d(50, 50, 36, 16)) + '<path d="M50,16 L50,84 M50,40 L38,30 M50,52 L36,44 M50,40 L62,30 M50,52 L64,44 M50,64 L40,58 M50,64 L60,58" stroke="{TD}" stroke-width="1.8" fill="none" stroke-linecap="round"/>'
C["fog_leaf"] = main_shape(leaf_d(42, 50, 32, 13, -18)) + main_shape(leaf_d(60, 54, 28, 11, 24)) + \
    '<path d="M42,20 L42,80 M60,28 L60,80" stroke="{TD}" stroke-width="1.6" fill="none" transform="rotate(0)"/>' + \
    hl("M18,84 C34,78 50,90 66,82 C76,78 84,82 88,84", "{TL}", 2.4, 0.8)
C["chevron_mark"] = poly([(12, 74), (50, 26), (88, 74), (74, 74), (50, 44), (26, 74)]) + hl("M19,70 L50,32")
C["iron_chevron"] = poly([(10, 78), (50, 22), (90, 78), (72, 78), (50, 48), (28, 78)]) + \
    poly([(30, 78), (50, 54), (70, 78)], "{TD}") + hl("M18,74 L50,29 L82,74", "{TL}", 1.6) + \
    ''.join(circle(x, y, 1.9, "{TL}", False) for x, y in [(24, 66), (76, 66), (50, 34)])
C["spark"] = poly(star(50, 50, 4, 38, 9)) + poly(star(50, 50, 4, 18, 5, -45), "{TL}", False, 'opacity="0.9"')
C["mullet"] = poly(star(50, 52, 5, 38, 16)) + hl("M50,16 L41,40 L14,40", "{TL}", 1.6)
C["filament"] = main_shape("M50,12 C60,30 40,40 50,52 C60,64 40,72 50,88 L46,88 C36,72 56,64 46,52 C36,40 56,30 46,12 Z") + \
    circle(50, 12, 5) + circle(48, 88, 5) + poly(star(70, 34, 4, 10, 3), "{TL}") + poly(star(30, 66, 4, 8, 2.4), "{TL}")
C["notch"] = main_shape("M20,20 L80,20 L80,80 L62,80 L62,56 L50,44 L38,56 L38,80 L20,80 Z") + hl("M24,76 L24,24 L76,24")
C["ember_notch"] = main_shape("M20,30 L80,30 L80,84 L62,84 L62,64 L50,54 L38,64 L38,84 L20,84 Z") + \
    main_shape("M50,6 C58,14 62,20 56,28 C54,22 50,22 50,26 C46,22 44,16 50,6 Z", 'fill="{TL}"') + hl("M24,80 L24,34 L76,34")
C["bars"] = "".join(main_shape(f"M14,{y} L86,{y} L86,{y+11} L14,{y+11} Z") + hl(f"M17,{y+2.6} L83,{y+2.6}", "{TL}", 1.4) for y in (22, 44.5, 67))
C["bend_mark"] = poly([(18, 12), (32, 12), (82, 88), (68, 88)]) + hl("M23,15 L72,85")
C["tower"] = main_shape("M28,88 L28,34 L22,34 L22,18 L32,18 L32,24 L40,24 L40,18 L50,18 L50,24 L60,24 L60,18 L68,18 L68,24 L78,24 L78,18 L78,34 L72,34 L72,88 Z") + \
    '<path d="M42,88 L42,68 A8,8 0 0,1 58,68 L58,88 Z" fill="{K}" opacity="0.85"/>' + \
    '<rect x="46" y="42" width="8" height="12" rx="4" fill="{K}" opacity="0.8"/>' + hl("M31,84 L31,36")
C["bridge"] = main_shape("M8,48 L92,48 L92,60 L86,60 L86,82 L74,82 L74,72 A12,12 0 0,0 62,60 L38,60 A12,12 0 0,0 26,72 L26,82 L14,82 L14,60 L8,60 Z") + \
    main_shape("M8,48 L8,40 L92,40 L92,48 Z", 'fill="{TL}"') + \
    ''.join(f'<rect x="{x}" y="32" width="6" height="8" fill="{{T}}" {SW}/>' for x in (12, 30, 47, 64, 82)) + \
    hl("M30,74 A10,10 0 0,1 40,64 L60,64 A10,10 0 0,1 70,74", "{TD}", 1.6)
C["lantern"] = main_shape("M36,30 L64,30 L70,40 L70,72 L64,80 L36,80 L30,72 L30,40 Z") + \
    '<path d="M38,42 L62,42 L62,70 L38,70 Z" fill="{TL}" stroke="{TD}" stroke-width="1.6"/>' + \
    main_shape("M40,30 L44,22 L56,22 L60,30 Z") + '<path d="M44,22 A6,6 0 0,1 56,22" fill="none" stroke="{K}" stroke-width="2.6"/>' + \
    main_shape("M42,80 L58,80 L54,88 L46,88 Z") + '<path d="M50,48 C55,54 54,62 50,64 C46,62 45,54 50,48 Z" fill="{T}" opacity="0.9"/>'
C["glass_lantern"] = main_shape("M34,28 L66,28 L74,44 L66,82 L34,82 L26,44 Z") + \
    '<path d="M36,44 L64,44 L60,74 L40,74 Z" fill="{TL}" stroke="{TD}" stroke-width="1.6" opacity="0.95"/>' + \
    '<path d="M50,28 L50,82 M26,44 L74,44" stroke="{TD}" stroke-width="1.6" fill="none"/>' + \
    main_shape("M40,28 L45,18 L55,18 L60,28 Z") + circle(50, 13, 5) + \
    poly(star(50, 59, 4, 9, 2.8), "{T}", False) + hl("M37,47 L42,71", "{GL}", 1.6)
C["flake"] = main_shape(snowflake(50, 50, 38)) + circle(50, 50, 7, "{TL}")
C["salt_crystal"] = poly([(50, 10), (74, 26), (74, 62), (50, 90), (26, 62), (26, 26)]) + \
    poly([(50, 10), (74, 26), (50, 40), (26, 26)], "{TL}") + poly([(50, 40), (74, 26), (74, 62), (50, 90)], "{TD}") + \
    '<path d="M50,40 L50,90" stroke="{K}" stroke-width="1.6"/>'
C["reed"] = "".join(main_shape(leaf_d(x, y, l, 5, r)) for x, y, l, r in [(38, 52, 34, -12), (50, 46, 38, 0), (62, 52, 34, 12)]) + \
    '<path d="M38,86 C40,70 44,60 50,50 M62,86 C60,70 56,60 50,50 M50,86 L50,50" stroke="{K}" stroke-width="2.4" fill="none"/>' + \
    '<rect x="46" y="10" width="8" height="18" rx="4" fill="{TD}" stroke="{K}" stroke-width="2.2"/>'
C["anvil"] = main_shape("M10,30 L72,30 C82,30 90,36 92,42 L72,42 L66,48 C62,52 62,56 66,58 L72,58 L72,70 L82,70 L82,80 L18,80 L18,70 L28,70 L28,58 L34,58 C38,56 38,52 34,48 L24,42 C16,40 10,36 10,30 Z") + \
    hl("M14,32 L72,32 C80,32 86,36 88,40", "{TL}", 1.8)
C["starbridge"] = main_shape("M8,72 A42,42 0 0,1 92,72 L80,72 A30,30 0 0,0 20,72 Z") + \
    "".join(poly(star(x, y, 4, r, r * 0.3)) for x, y, r in [(50, 20, 10), (24, 38, 7), (76, 38, 7)]) + hl("M15,66 A35,35 0 0,1 46,38")
C["constellation"] = '<path d="M20,70 L38,46 L58,52 L76,26 M38,46 L32,22 M58,52 L70,78" stroke="{TD}" stroke-width="2.2" fill="none" stroke-dasharray="1 3.4" stroke-linecap="round"/>' + \
    "".join(poly(star(x, y, 4, r, r * 0.32)) for x, y, r in [(20, 70, 9), (38, 46, 11), (58, 52, 8), (76, 26, 12), (32, 22, 7), (70, 78, 8)])
C["zephyr"] = main_shape("M12,40 C30,24 56,26 64,38 C70,48 62,58 52,54 C44,50 48,42 54,44 L54,40 C44,36 36,46 42,54 C50,64 70,60 76,48 C84,32 72,18 56,16 L60,12 C80,12 92,30 86,48 C78,70 50,74 36,62 C28,54 30,40 38,36 C28,34 20,38 12,40 Z") + \
    main_shape("M12,70 C30,62 50,64 66,72 L64,78 C50,70 32,70 14,76 Z") + hl("M18,38 C32,28 52,28 60,38")
C["ash_plume"] = main_shape("M50,90 C46,70 30,60 28,40 C26,24 40,12 50,8 C46,22 54,26 58,18 C68,30 74,46 66,62 C62,70 56,76 54,90 Z") + \
    '<path d="M50,88 C50,60 48,40 50,14 M50,40 L38,30 M50,52 L36,44 M50,64 L40,58 M50,46 L62,36 M50,58 L64,50" stroke="{TD}" stroke-width="1.7" fill="none" stroke-linecap="round"/>' + hl("M34,40 C34,28 42,18 48,14")
C["ice_crown"] = main_shape("M16,74 L16,36 L30,52 L40,22 L50,46 L60,22 L70,52 L84,36 L84,74 Z") + \
    main_shape("M14,74 L86,74 L86,86 L14,86 Z", 'fill="{TD}"') + \
    "".join(poly([(x, y - 6), (x + 4, y), (x, y + 6), (x - 4, y)], "{TL}") for x, y in [(30, 80), (50, 80), (70, 80)]) + \
    "".join(poly(star(x, y, 4, 6, 2)) for x, y in [(16, 30), (40, 16), (60, 16), (84, 30)]) + hl("M20,70 L20,44 L28,54")

# ---------------- Helms (box 200x200, centred x=100, bowl top ~y=10, neck base y=190) ----------------
HELM_BASE = (
    '<path d="M100,8 C140,8 162,42 164,92 C166,128 158,156 146,176 L132,192 L68,192 L54,176 C42,156 34,128 36,92 C38,42 60,8 100,8 Z" '
    'fill="url(#hm_metal)" stroke="{K}" stroke-width="3.6" stroke-linejoin="round"/>'
    '<path d="M100,10 C100,40 100,160 100,190" stroke="{M4}" stroke-width="2.4" opacity="0.55"/>'
    '<path d="M100,10 C76,12 54,34 48,84" fill="none" stroke="{M4}" stroke-width="4" stroke-linecap="round" opacity="0.7"/>'
    '<path d="M150,70 C158,104 156,140 140,170" fill="none" stroke="{M0}" stroke-width="5" stroke-linecap="round" opacity="0.45"/>'
    '<path d="M60,176 L140,176 L132,192 L68,192 Z" fill="{M1}" stroke="{K}" stroke-width="3"/>'
    + "".join(f'<circle cx="{x}" cy="184" r="3.2" fill="{{M4}}" stroke="{{K}}" stroke-width="1.4"/>' for x in (78, 100, 122))
)
HELMS = {
    "closed": HELM_BASE +
        '<path d="M44,92 C60,84 140,84 156,92 L152,104 C136,98 64,98 48,104 Z" fill="{K}" opacity="0.92"/>'
        '<path d="M50,118 C66,112 134,112 150,118" fill="none" stroke="{K}" stroke-width="3" opacity="0.9"/>'
        + "".join(f'<rect x="{x}" y="128" width="5" height="12" rx="2" fill="{{K}}" opacity="0.85"/>' for x in (70, 84, 112, 126))
        + '<path d="M100,92 L100,170" stroke="{M4}" stroke-width="3.4" opacity="0.6"/>',
    "grilled": HELM_BASE +
        '<path d="M52,76 C70,68 130,68 148,76 L150,148 C130,160 70,160 50,148 Z" fill="{K}" opacity="0.92" stroke="{K}" stroke-width="2"/>'
        + "".join(f'<path d="M{x},74 L{x},{156 - abs(x-100)*0.25:.0f}" stroke="url(#hm_metal)" stroke-width="7" stroke-linecap="round"/>' for x in (64, 82, 100, 118, 136))
        + '<path d="M54,110 C80,104 120,104 146,110" fill="none" stroke="url(#hm_metal)" stroke-width="5"/>'
        + '<path d="M52,76 C70,68 130,68 148,76" fill="none" stroke="{M4}" stroke-width="5"/>',
    "royal": HELM_BASE +
        '<path d="M52,76 C70,68 130,68 148,76 L150,148 C130,160 70,160 50,148 Z" fill="{K}" opacity="0.92"/>'
        + "".join(f'<path d="M{x},74 L{x},{156 - abs(x-100)*0.25:.0f}" stroke="url(#hm_metal)" stroke-width="6.5" stroke-linecap="round"/>' for x in (64, 82, 100, 118, 136))
        + '<path d="M54,110 C80,104 120,104 146,110" fill="none" stroke="url(#hm_metal)" stroke-width="5"/>'
        + '<path d="M52,76 C70,68 130,68 148,76" fill="none" stroke="{M4}" stroke-width="5"/>'
        + '<path d="M70,40 C84,30 116,30 130,40" fill="none" stroke="{G}" stroke-width="4" stroke-linecap="round"/>'
        + '<path d="M92,52 L100,40 L108,52 L100,64 Z" fill="{G}" stroke="{K}" stroke-width="2"/><path d="M97,47 L100,43 L103,47" stroke="{GL}" stroke-width="1.6" fill="none"/>',
}

# ---------------- Crowns (box 200x110, base band y 70..100) ----------------
def crown(points_def, band_gems, top_gems, arches=False):
    s = ""
    if arches:
        s += ('<path d="M34,72 C40,20 92,10 100,18 C108,10 160,20 166,72" fill="none" stroke="{K}" stroke-width="10" stroke-linecap="round"/>'
              '<path d="M34,72 C40,20 92,10 100,18 C108,10 160,20 166,72" fill="none" stroke="url(#cr_metal)" stroke-width="6" stroke-linecap="round"/>'
              '<path d="M100,18 L100,72" stroke="{K}" stroke-width="10"/><path d="M100,18 L100,72" stroke="url(#cr_metal)" stroke-width="6"/>')
    s += f'<path d="{points_def}" fill="url(#cr_metal)" stroke="{{K}}" stroke-width="3.4" stroke-linejoin="round"/>'
    s += '<path d="M22,70 L178,70 L174,100 L26,100 Z" fill="url(#cr_band)" stroke="{K}" stroke-width="3.4" stroke-linejoin="round"/>'
    s += '<path d="M26,76 L174,76" stroke="{M4}" stroke-width="2" opacity="0.8"/><path d="M28,95 L172,95" stroke="{M0}" stroke-width="2" opacity="0.6"/>'
    for i, (x, kind) in enumerate(band_gems):
        if kind == "oval":
            s += f'<ellipse cx="{x}" cy="85" rx="8" ry="6" fill="{{G}}" stroke="{{K}}" stroke-width="2"/><ellipse cx="{x-2}" cy="83" rx="3" ry="2" fill="{{GL}}"/>'
        else:
            s += f'<path d="M{x},77 L{x+7},85 L{x},93 L{x-7},85 Z" fill="{{M4}}" stroke="{{K}}" stroke-width="2"/>'
    for x, y, r in top_gems:
        s += f'<circle cx="{x}" cy="{y}" r="{r}" fill="url(#cr_pearl)" stroke="{{K}}" stroke-width="2"/>'
    return s

CROWNS = {
    "knight": ('<path d="M24,70 C24,50 60,42 100,42 C140,42 176,50 176,70" fill="none" stroke="{K}" stroke-width="12"/>'
               '<path d="M24,70 C24,50 60,42 100,42 C140,42 176,50 176,70" fill="none" stroke="url(#cr_metal)" stroke-width="7"/>'
               + crown("M22,70 L178,70 L178,70 Z", [(50, "dia"), (100, "oval"), (150, "dia")], [])),
    "baron": crown("M22,70 L30,56 L170,56 L178,70 Z", [(46, "dia"), (78, "oval"), (122, "oval"), (154, "dia")],
                   [(30, 50, 7), (65, 48, 7), (100, 46, 7), (135, 48, 7), (170, 50, 7)]),
    "count": crown("M22,70 L26,40 L40,58 L58,30 L76,56 L100,24 L124,56 L142,30 L160,58 L174,40 L178,70 Z",
                   [(46, "dia"), (78, "oval"), (122, "oval"), (154, "dia")], [(26, 34, 7), (58, 24, 7), (100, 18, 8), (142, 24, 7), (174, 34, 7)]),
    "duke": crown("M22,70 L24,34 C34,44 40,46 46,36 L56,54 L70,26 C78,38 86,40 92,30 L100,14 L108,30 C114,40 122,38 130,26 L144,54 L154,36 C160,46 166,44 176,34 L178,70 Z",
                  [(46, "oval"), (78, "dia"), (100, "oval"), (122, "dia"), (154, "oval")], [(24, 28, 6), (70, 20, 6), (100, 8, 7), (130, 20, 6), (176, 28, 6)]),
    "royal": crown("M22,70 L26,30 L44,52 L62,20 L80,48 L100,10 L120,48 L138,20 L156,52 L174,30 L178,70 Z",
                   [(40, "oval"), (70, "dia"), (100, "oval"), (130, "dia"), (160, "oval")], [(26, 24, 6), (62, 14, 6), (138, 14, 6), (174, 24, 6)], arches=True)
               + '<circle cx="100" cy="10" r="11" fill="{G}" stroke="{K}" stroke-width="2.6"/><path d="M100,-4 L100,24 M86,10 L114,10" stroke="{M4}" stroke-width="3"/>'
               + '<circle cx="96" cy="6" r="3" fill="{GL}"/>',
}

# ---------------- Mantling (box 600x420, helm centre at (300,80); shield top ~y=150) ----------------
def mantling_side(sign: int) -> str:
    def X(x):
        return 300 + sign * x
    lobes = [
        # (outer path, lining fold path)
        (f"M{X(40)},70 C{X(120)},40 {X(190)},60 {X(214)},120 C{X(232)},166 {X(204)},196 {X(176)},188 "
         f"C{X(200)},170 {X(196)},140 {X(170)},130 C{X(150)},124 {X(140)},140 {X(150)},156 C{X(120)},150 {X(100)},120 {X(110)},96 Z",
         f"M{X(176)},188 C{X(200)},170 {X(196)},140 {X(170)},130 C{X(186)},146 {X(190)},170 {X(176)},188 Z"),
        (f"M{X(150)},150 C{X(210)},150 {X(250)},200 {X(250)},260 C{X(250)},300 {X(226)},320 {X(204)},314 "
         f"C{X(222)},296 {X(222)},270 {X(204)},258 C{X(190)},250 {X(176)},262 {X(182)},278 C{X(160)},262 {X(150)},230 {X(160)},206 "
         f"C{X(150)},190 {X(140)},170 {X(150)},150 Z",
         f"M{X(204)},314 C{X(222)},296 {X(222)},270 {X(204)},258 C{X(226)},270 {X(230)},300 {X(204)},314 Z"),
        (f"M{X(170)},250 C{X(206)},280 {X(214)},340 {X(194)},376 C{X(182)},398 {X(160)},404 {X(146)},392 "
         f"C{X(166)},384 {X(176)},360 {X(164)},344 C{X(156)},334 {X(144)},340 {X(144)},352 C{X(128)},330 {X(134)},296 {X(156)},276 Z",
         f"M{X(146)},392 C{X(166)},384 {X(176)},360 {X(164)},344 C{X(182)},358 {X(176)},388 {X(146)},392 Z"),
    ]
    s = ""
    for outer, fold in lobes:
        s += f'<path d="{outer}" fill="url(#mt_outer)" stroke="{{K}}" stroke-width="3.2" stroke-linejoin="round"/>'
        s += f'<path d="{fold}" fill="{{B}}" stroke="{{K}}" stroke-width="2.4" stroke-linejoin="round"/>'
    # flowing vein strokes
    s += (f'<path d="M{X(60)},76 C{X(130)},62 {X(184)},86 {X(196)},140" fill="none" stroke="{{AL}}" stroke-width="3" stroke-linecap="round" opacity="0.7"/>'
          f'<path d="M{X(166)},170 C{X(206)},190 {X(232)},230 {X(232)},270" fill="none" stroke="{{AL}}" stroke-width="3" stroke-linecap="round" opacity="0.6"/>'
          f'<path d="M{X(170)},280 C{X(194)},306 {X(198)},340 {X(186)},366" fill="none" stroke="{{AL}}" stroke-width="2.6" stroke-linecap="round" opacity="0.55"/>')
    return s

MANTLING = mantling_side(-1) + mantling_side(1)

# ---------------- Supporters (box 200x360, facing RIGHT toward shield; feet on y≈350) ----------------
def eye(x, y):
    return f'<circle cx="{x}" cy="{y}" r="3.4" fill="{{K}}"/><circle cx="{x+1}" cy="{y-1}" r="1.2" fill="{{GL}}"/>'

BODY = 'fill="url(#sp_body)" stroke="{K}" stroke-width="3.4" stroke-linejoin="round" stroke-linecap="round"'
DETAIL = 'fill="none" stroke="{SD}" stroke-width="2.4" stroke-linecap="round" opacity="0.8"'
LIGHT = 'fill="none" stroke="{SL}" stroke-width="2.6" stroke-linecap="round" opacity="0.85"'

SUPPORTERS = {
    # Frost stag, rampant-ish upright, antlers of ice
    "stag": (
        f'<path d="M64,350 L74,262 C60,240 56,206 66,180 C56,160 58,130 76,116 L92,104 C96,90 104,80 116,76 L128,70 C134,72 140,80 140,86 '
        f'L152,92 C156,96 154,102 148,104 L130,106 C124,118 122,132 128,146 C142,150 158,140 168,126 L176,132 C168,152 150,168 132,170 '
        f'C138,192 136,220 124,244 L134,300 L150,320 L140,330 L118,306 L106,256 L96,262 L98,350 Z" {BODY}/>'
        f'<path d="M108,78 C100,60 96,44 102,24 M100,50 L84,40 M102,36 L92,22 M104,62 L90,60" fill="none" stroke="{{K}}" stroke-width="7" stroke-linecap="round"/>'
        f'<path d="M108,78 C100,60 96,44 102,24 M100,50 L84,40 M102,36 L92,22 M104,62 L90,60" fill="none" stroke="{{SL}}" stroke-width="3.4" stroke-linecap="round"/>'
        f'<path d="M124,74 C128,54 138,40 152,30 M132,54 L146,52 M140,42 L148,28" fill="none" stroke="{{K}}" stroke-width="7" stroke-linecap="round"/>'
        f'<path d="M124,74 C128,54 138,40 152,30 M132,54 L146,52 M140,42 L148,28" fill="none" stroke="{{SL}}" stroke-width="3.4" stroke-linecap="round"/>'
        + eye(130, 86) +
        f'<path d="M80,124 C72,150 72,176 82,196" {LIGHT}/><path d="M96,186 C100,212 98,236 90,252" {DETAIL}/>'
        f'<path d="M86,350 L88,300" {DETAIL}/><path d="M62,352 L100,352" stroke="{{K}}" stroke-width="4"/>'
    ),
    # Frost wolf, upright
    "wolf": (
        f'<path d="M70,350 L76,270 C62,246 58,212 70,184 C60,160 64,130 84,116 L96,106 L100,74 L112,92 L124,72 L130,96 '
        f'C140,100 152,108 160,114 L170,120 C172,126 166,130 160,128 L146,128 C140,136 132,140 126,142 C140,150 156,146 170,136 '
        f'L178,144 C164,162 146,170 130,170 C136,194 134,222 120,246 L130,300 L146,318 L136,328 L114,306 L104,256 L96,262 L98,350 Z" {BODY}/>'
        f'<path d="M66,240 C40,250 26,280 34,310 C40,296 48,288 58,286 C50,300 52,316 60,326 C62,300 70,280 80,268" {BODY}/>'
        + eye(132, 108) +
        f'<path d="M146,128 L160,128" stroke="{{K}}" stroke-width="2.4"/>'
        f'<path d="M88,124 C78,150 78,176 88,196" {LIGHT}/><path d="M98,186 C102,212 100,236 92,252" {DETAIL}/>'
        f'<path d="M84,140 L94,150 M86,156 L98,164 M90,172 L100,178" {DETAIL}/><path d="M64,352 L102,352" stroke="{{K}}" stroke-width="4"/>'
    ),
    # Crane / heron, tall standing bird with spread wing
    "crane": (
        f'<path d="M100,40 C112,30 128,32 132,44 L176,56 L132,56 C128,70 116,76 108,90 C100,106 104,124 116,140 '
        f'C132,160 134,196 118,224 C106,244 86,252 70,248 C58,240 52,224 56,206 C60,184 76,166 90,150 C96,140 94,126 90,112 '
        f'C84,88 86,56 100,40 Z" {BODY}/>'
        f'<path d="M76,170 C44,150 22,110 20,70 C34,90 44,96 56,98 C46,82 42,66 44,50 C58,74 72,90 90,104 C86,130 84,150 76,170 Z" {BODY}/>'
        f'<path d="M30,80 C44,104 60,118 80,128 M42,62 C54,88 70,104 86,116" {DETAIL}/>'
        f'<path d="M86,246 L80,350 M98,246 L104,350" stroke="{{K}}" stroke-width="7" stroke-linecap="round"/>'
        f'<path d="M86,246 L80,350 M98,246 L104,350" stroke="{{SL}}" stroke-width="3" stroke-linecap="round"/>'
        f'<path d="M62,352 L96,352 M90,352 L124,352" stroke="{{K}}" stroke-width="4" stroke-linecap="round"/>'
        f'<path d="M108,32 C112,22 120,20 126,24 C120,26 114,30 112,36 Z" fill="{{G}}" stroke="{{K}}" stroke-width="2"/>'
        + eye(120, 44) + f'<path d="M104,62 C96,90 96,116 110,140" {LIGHT}/>'
    ),
    # Griffon-like frost eagle, upright with raised wing
    "eagle": (
        f'<path d="M96,60 C106,46 126,44 138,54 L156,60 C162,64 160,72 152,74 L140,72 C136,84 128,92 120,98 '
        f'C140,116 148,150 140,184 C134,210 120,232 104,244 L110,300 L128,320 L116,330 L96,308 L90,262 L80,262 L84,350 L64,350 L64,250 '
        f'C52,226 50,192 60,160 C66,130 80,108 96,96 C88,84 88,70 96,60 Z" {BODY}/>'
        f'<path d="M84,110 C56,96 30,64 22,24 C38,42 50,48 62,50 C52,36 48,22 50,8 C66,34 80,50 98,62 C94,80 90,96 84,110 Z" {BODY}/>'
        f'<path d="M32,40 C44,62 60,78 78,88 M54,24 C64,46 78,62 92,72" {DETAIL}/>'
        f'<path d="M152,62 L162,66 L152,74 Z" fill="{{SD}}" stroke="{{K}}" stroke-width="2"/>'
        + eye(132, 62) +
        f'<path d="M76,150 L90,158 M74,170 L90,178 M76,190 L92,196 M80,210 L94,214" {DETAIL}/>'
        f'<path d="M70,130 C62,160 62,196 72,224" {LIGHT}/><path d="M58,352 L92,352" stroke="{{K}}" stroke-width="4"/>'
    ),
    # Frost bear, upright
    "bear": (
        f'<path d="M64,350 L68,272 C50,248 44,206 54,170 C58,148 70,128 86,118 C84,102 90,86 104,80 C106,70 114,66 120,72 '
        f'C130,74 142,82 150,94 L160,100 C164,106 160,112 152,112 L140,112 C138,124 132,132 124,138 C140,148 156,148 168,140 '
        f'L176,150 C160,166 140,172 124,170 C132,200 128,232 114,252 L122,300 L138,318 L126,328 L104,306 L96,262 L90,268 L94,350 Z" {BODY}/>'
        f'<circle cx="112" cy="76" r="9" {BODY}/>'
        + eye(132, 96) +
        f'<path d="M150,108 C146,112 142,112 140,112" stroke="{{K}}" stroke-width="2.4"/>'
        f'<path d="M72,150 C64,180 66,216 78,240" {LIGHT}/><path d="M90,200 C96,220 96,240 90,256" {DETAIL}/>'
        f'<path d="M60,352 L98,352" stroke="{{K}}" stroke-width="4"/>'
    ),
    # Sea-drake (hippocamp-like), coiled tail
    "seadrake": (
        f'<path d="M98,52 C110,40 130,40 140,50 L164,58 C170,62 168,70 160,72 L142,74 C140,86 132,94 124,100 '
        f'C140,118 146,150 136,182 C128,206 112,222 98,228 C118,240 134,262 132,290 C130,318 108,340 80,342 C56,344 40,326 44,306 '
        f'C48,290 62,284 74,290 C66,296 64,306 72,312 C86,320 104,308 104,290 C104,268 86,252 66,244 C54,226 52,194 60,164 '
        f'C66,136 80,112 98,98 C90,86 90,64 98,52 Z" {BODY}/>'
        f'<path d="M96,56 C84,44 78,30 82,14 C90,28 98,32 108,34 C102,22 104,12 112,4 C114,20 120,30 130,38" {BODY}/>'
        f'<path d="M86,110 C70,90 50,84 30,90 C44,98 50,106 52,118 C40,114 30,118 22,128 C42,130 58,138 70,150" {BODY}/>'
        + eye(130, 60) +
        f'<path d="M76,160 L92,168 M74,180 L92,188 M76,200 L94,206 M82,218 L98,222" {DETAIL}/>'
        f'<path d="M70,150 C62,180 64,210 76,232" {LIGHT}/><path d="M60,310 C70,330 96,332 112,318" {DETAIL}/>'
    ),
}

NATION_SUPPORTERS = {
    "ashbanner": ["wolf", "wolf"], "shuoying": ["eagle", "wolf"], "qinghe": ["crane", "crane"],
    "lantern": ["crane", "stag"], "frostcrown": ["stag", "stag"], "emberold": ["bear", "wolf"],
    "saltmarsh": ["seadrake", "seadrake"], "irongorge": ["bear", "bear"], "starriver": ["eagle", "eagle"],
    "southzephyr": ["stag", "crane"],
}

# frost-metal ramp (dark→bright) — frost silver, never gold
METAL = ["#3a4a5e", "#6f8296", "#a9b8c8", "#d6e1ec", "#f4f9ff"]
SUPPORTER_TONES = {"body": "#c5d0dc", "light": "#f4f9ff", "dark": "#5c7a9a", "deep": "#6f8296"}
GEM = {"base": "#6ed4ff", "light": "#e8f6ff"}
RIBBON = {"face": "#e8f6ff", "shade": "#a8c5d4", "back": "#5c7a9a", "text": "#1c2330", "edge": "#2e6f8f"}
COMPARTMENT = {"top": "#d0dde8", "side": "#7e9ab4", "deep": "#3a6ea5", "ice": "#9be4ff"}
BANNER = {"pole_dark": "#3a4555", "pole_lit": "#a9b8c8", "finial": "#6ed4ff"}


def main() -> None:
    data = {
        "schema": 1,
        "note": "Hand-authored original vector heraldry art (frost palette). Generated by tools/art/build_heraldry_vector.py.",
        "charge_box": 100,
        "charges": CHARGES,
        "helms": HELMS,
        "crowns": CROWNS,
        "mantling": MANTLING,
        "supporters": SUPPORTERS,
        "nation_supporters": NATION_SUPPORTERS,
        "metal": METAL,
        "supporter_tones": SUPPORTER_TONES,
        "gem": GEM,
        "ribbon": RIBBON,
        "compartment": COMPARTMENT,
        "banner": BANNER,
    }
    OUT.write_text(json.dumps(data, ensure_ascii=False, indent=1) + "\n", encoding="utf-8")
    print("wrote", OUT, "charges", len(CHARGES))


if __name__ == "__main__":
    main()
