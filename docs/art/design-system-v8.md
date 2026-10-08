# CenturyKnights Visual System · v8.0.0-art

**Vibe lock (2026):** cutting-edge global contemporary fantasy SRPG — luminous ink voids, frosted matte chrome, crystal frost + mint/coral signals, editorial illustration.  
**Explicit rejects:** retro medieval cliché, aged-paper kitsch, gothic stone thrift, warm-metal frames.

## Coverage matrix (ship once — no half redesign)

| Domain | Deliverable | Farm / code |
|--------|-------------|-------------|
| Design tokens | palette, type, spacing, elevation | `UIKit` consts |
| Control states | hover / press / focus / disabled **every** control | `UIKit` + `UIFX.wire_tree` |
| Motion | AT page_enter, shimmer, panel_rise, list_ripple, nav_slide | `ui_fx.gd` |
| UI kit plates | panel, nav rail, top bar, buttons, modal, HP, crest, battle HUD | `v8_ui_*` |
| All hubs + menu | 20 fullscreen 1920×1080 backdrops | `v8_hub_*` |
| Battle | 14 biome backdrops (map 400 fights → biome) | `v8_battle_biome_*` |
| Campaign scene maps | key chapter stages | `v8_scene_*` |
| World atlas | world + political + landbridge + 10 nations | `v8_atlas_*` + `atlas_v8.json` |
| Portraits | 8 hero keys + 24 busts; thumbs downscale only | `v8_hero_*` / `v8_bust_*` |
| Tokens | 8 readable 128px | `v8_token_*` |
| FX | 6 sheets × 6 frames | `v8_fx_*` |

## Palette

| Token | Role |
|-------|------|
| ink void / matte slate | grounds & panels |
| crystal frost (`ACCENT`) | primary CTA / focus |
| mint (`OK`) | ally / heal |
| coral (`DANGER`) | enemy / deny |
| ember (sparks only) | FX heat, never chrome fill |

## Control law

Every `BaseButton` + focusable field: **normal · hover · pressed · focus · disabled** styles + `UIFX` motion. `wire_tree` on every hub `_ready`.

## Atlas law

Borders readable without text; nation plates + world plates; wire via `project/data/atlas_v8.json`.

## Stitch (live UI)
- Landing pad: `project/assets/art/stitch_exports/` → `tools/farm_queue/ingest_stitch_exports.py`
- Skeletons: `docs/art/stitch_skeletons_v8/` (local placeholders until live exports arrive)
- Integrate castle / battle / menu / atlas screens into hub layout + control states when PNGs/HTML land.

## Pipeline

1. Stitch skeletons when API key present (else local HTML wireframes).
2. Queue **all** `shots_v800_art.json` on Qwen `:8322` via m173.
3. Ingest → replace thin procedural everywhere visible.
4. Ship **v8.0.0-art** CI + Windows zip.

## v8.5 laws
- **VFX are authored, not farmed.** Runtime FX come from `tools/fx/author_vfx_v85.py` (additive light, 4× supersample, straight alpha). Farmed "FX sheets" are illustration panels and go to `rejected_v840/`.
- **FX sizing on 56px cells:** draw centered, 1.35–1.9× cell (slash 80, heal 84, crit 108, lock/shield 80, spark 76, select reticle CELL+18). Never 128px raw.
- **Linear filtering** project-wide (`default_texture_filter=1`); painted art must never be NEAREST-downscaled.
- **No load-in-draw.** Never `load()` inside `_draw*`; use `_tex()` cache + `_warm_fx_cache()` (first GL load in draw records a white placeholder).
- **9-slice margins must contain the art border** (`panel_chrome_half`: texture 25/21, content 26/22).
- **Cartoon-key ban.** Pre-v8 cartoon portraits (`*_f_<job>.png`, `hire_*_plate`, `*_face_plate`, role plates, leader_default) are never shown; route to v8 hero/bust/farm faces.
- **Zero leftover plates.** `tools/audit_v840_usage.py` runs in CI and fails on any unused v840 output.
- **Stitch live design system "CenturyKnights Frost"** (`docs/art/stitch_skeletons_v8/live_v850/tokens.json`) is the layout reference; palette matches UIKit (void #07080C, frost #6ED4FF, mint #5EE0B5, coral #FF7A70, ember sparks only).

---

## v8.6 laws — Stitch layout parity (supersedes painted chrome)

1. **Ink void first.** Every screen starts from `UIKit.void_bg` (frost_void shader: #07090D base, 48px grid at 3%). Painted backdrops survive only as a ≤10% atmospheric wash (`make_themed_bg`). No painted plates, banner strips, or ice-crystal frames.
2. **Flat panels, 1px strokes.** `UIKit.panel_at` = #0E1117 @ 0.90 + 1px white@0.10. Focus = 2px frost (#6ED4FF) stroke + 14px soft glow. Nothing else glows.
3. **Chrome skeleton.** 56px `top_bar` (● CENTURY KNIGHTS // context · boxed resource chips · 返回 ESC) → editorial `page_head` (mono eyebrow `— X // SECTOR`, 30px title, mono English subtitle, one-line desc) → content → 28px `footer_bar` with keycaps at y692.
4. **Hierarchy by type, not boxes.** 30 title / 22 section hero / 15–17 row title / 12 body / 9–10 mono meta. Mono (JetBrains) for numbers, IDs, eyebrows; Noto Sans SC for prose.
5. **Colour is semantic.** Frost = primary/focus/selection; mint = ally/heal/OK; coral = enemy/deny/insufficient; ember = sparks only. Warm-metal trim and aged-paper textures are rejected.
6. **Every action has a key.** CTAs carry `[A]`/`[ENTER]` keycaps; secondary actions are ghost buttons with their key (`[W]`, `[S]`); ESC always backs out. Hover / pressed / focus / disabled states on every control.
7. **Whitespace over filler.** Empty slots render as dashed-quiet "空位 / SLOT AVAILABLE", not stretched panels.
8. **Battle board is the hero.** HUD lives in the right rail + a centred turn pill (第 N 回合 · PHASE chip); objectives top-right; nothing overlays the board.
