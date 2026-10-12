#!/usr/bin/env python3
"""Inject rank_badges (per-title genealogy badges, 64x64 SVG, frost palette) into heraldry_v2.json.
Not cadency: badges show a person's noble title tier, never birth order or legitimacy."""
import json
from pathlib import Path
P = Path(__file__).resolve().parents[2] / "project/assets/art/heraldry_v2.json"
INK, DISC, RIM_D, RIM_L, M0, M1, M2, GEM, GEML = "#0a0e14", "#1c2330", "#5c7a9a", "#e8f6ff", "#6f8296", "#c5d0dc", "#f4f9ff", "#6ed4ff", "#e8f6ff"
DEFS = (f'<defs><linearGradient id="rk_rim" x1="0" y1="0" x2="1" y2="1"><stop offset="0" stop-color="{RIM_L}"/><stop offset="1" stop-color="{RIM_D}"/></linearGradient>'
        f'<linearGradient id="rk_met" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="{M2}"/><stop offset="0.55" stop-color="{M1}"/><stop offset="1" stop-color="{M0}"/></linearGradient>'
        f'<radialGradient id="rk_disc" cx="0.35" cy="0.3" r="0.8"><stop offset="0" stop-color="#2e3a4c"/><stop offset="1" stop-color="{DISC}"/></radialGradient></defs>')
def medal(double=False):
    s = f'<circle cx="32" cy="32" r="29" fill="url(#rk_disc)" stroke="url(#rk_rim)" stroke-width="3"/>'
    if double:
        s += f'<circle cx="32" cy="32" r="24.5" fill="none" stroke="{GEM}" stroke-width="1" opacity="0.55"/>'
    return s
MET = f'fill="url(#rk_met)" stroke="{INK}" stroke-width="1.6" stroke-linejoin="round"'
def band(y=40, h=7):
    return f'<path d="M16,{y} L48,{y} L47,{y+h} L17,{y+h} Z" {MET}/><path d="M18,{y+1.6} L46,{y+1.6}" stroke="{M2}" stroke-width="1" opacity="0.9"/>'
def pearl(x, y, r=2.6):
    return f'<circle cx="{x}" cy="{y}" r="{r}" fill="{M2}" stroke="{INK}" stroke-width="1.2"/>'
def gem(x, y, r=2.6):
    return f'<path d="M{x},{y-r} L{x+r},{y} L{x},{y+r} L{x-r},{y} Z" fill="{GEM}" stroke="{INK}" stroke-width="1"/>'
def svg(body):
    return f'<svg xmlns="http://www.w3.org/2000/svg" width="64" height="64" viewBox="0 0 64 64">{DEFS}{body}</svg>'
B = {
    # 勋士：竖向霜针（pin），单宝石
    "knight": svg(medal() + f'<path d="M32,12 L37,30 L32,52 L27,30 Z" {MET}/><path d="M32,14 L32,50" stroke="{M2}" stroke-width="1"/>'
                  f'<path d="M22,30 L42,30" stroke="{INK}" stroke-width="5" stroke-linecap="round"/><path d="M22,30 L42,30" stroke="{M1}" stroke-width="2.6" stroke-linecap="round"/>' + gem(32, 30, 3.4)),
    # 男爵：素环 + 四珠
    "baron": svg(medal() + band(36, 8) + "".join(pearl(x, 32, 3) for x in (19, 28, 36, 45)) + gem(32, 40, 2.4)),
    # 子爵：环 + 六短珠柱
    "viscount": svg(medal(True) + band(38, 8) + "".join(f'<path d="M{x},38 L{x},30" stroke="{INK}" stroke-width="2.6"/><path d="M{x},38 L{x},30" stroke="{M1}" stroke-width="1.2"/>' + pearl(x, 28, 2.4) for x in (18, 24, 30, 34, 40, 46)) + gem(32, 42, 2.2)),
    # 伯爵：五尖顶珠冠
    "count": svg(medal(True) + f'<path d="M16,40 L17,24 L22,33 L27,20 L32,31 L37,20 L42,33 L47,24 L48,40 Z" {MET}/>' + band(40, 7)
                 + "".join(pearl(x, y, 2.4) for x, y in ((17, 22), (27, 18), (37, 18), (47, 22))) + gem(32, 28, 3) + gem(24, 43.5, 1.8) + gem(40, 43.5, 1.8)),
    # 侯爵：高叶冠（霜叶五瓣）
    "duke": svg(medal(True) + f'<path d="M16,40 L16,26 C19,30 21,30 22,26 L25,32 L27,18 C29,22 31,22 32,12 C33,22 35,22 37,18 L39,32 L42,26 C43,30 45,30 48,26 L48,40 Z" {MET}/>' + band(40, 7)
                + gem(32, 22, 3.2) + gem(22, 34, 2.2) + gem(42, 34, 2.2) + gem(32, 43.5, 2) + pearl(32, 11, 2.2)),
    # 王室：拱冠 + 霜球
    "royal": svg(medal(True) + f'<path d="M18,40 C18,22 30,18 32,20 C34,18 46,22 46,40" fill="none" stroke="{INK}" stroke-width="4.6"/><path d="M18,40 C18,22 30,18 32,20 C34,18 46,22 46,40" fill="none" stroke="{M1}" stroke-width="2.4"/>'
                 f'<path d="M32,20 L32,40" stroke="{INK}" stroke-width="4.6"/><path d="M32,20 L32,40" stroke="{M1}" stroke-width="2.4"/>' + band(40, 7)
                 + f'<circle cx="32" cy="14" r="4.6" fill="{GEM}" stroke="{INK}" stroke-width="1.4"/><circle cx="30.6" cy="12.6" r="1.4" fill="{GEML}"/>' + gem(24, 43.5, 1.8) + gem(32, 43.5, 2.2) + gem(40, 43.5, 1.8)),
}
d = json.loads(P.read_text(encoding="utf-8"))
d["rank_badges"] = B
d["rank_badge_order"] = ["knight", "baron", "viscount", "count", "duke", "royal"]
P.write_text(json.dumps(d, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
print("rank badges", list(B))
