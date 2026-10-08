# v8.6.0-art · Stitch layout parity, real battle terrain, 3D combat cutscenes

## Vibe
2026 contemporary fantasy: luminous ink void, frosted glass, thin 1px strokes. Crystal frost #6ED4FF is primary/focus, mint #5EE0B5 is ally/heal, coral #FF7A70 is enemy/deny, and ember is for sparks only. Not medieval.

## Stitch ingest
- All 24 Google Stitch screens (1920×1080 PNG and HTML) and `tokens.json` are now in the repo at `project/assets/art/stitch_exports/`, mirrored to `docs/art/stitch_skeletons_v8/`. Tokenized asset URLs were redacted.

## Layout rebuilt per Stitch reference
| Stitch | Screen | Status |
|---|---|---|
| 01 | Main menu | matched (editorial left column, indexed list, key art kept) |
| 02 | Castle hub | matched |
| 03 | Atlas | structure matched (painted plate map) |
| 05 | Deploy | matched |
| 06 | Battle HUD | matched (turn pill 第 N 回合 + PHASE chip, objective top-right, Q/W/E/Enter keycaps, END PLAYER TURN CTA) |
| 08/09 | Victory/Defeat | matched (post-action report) |
| 10/11 | Roster + unit detail | matched (detail merged into the roster dossier) |
| 12 | Tavern | matched |
| 13 | Forge | matched |
| 14 | Market | matched |
| 15 | Temple (祠堂) | matched |
| 16 | Estates | matched |
| 17 | Marriage | matched |
| 18 | Lineage | matched |
| 21 | Dialogue | matched (shared skin for all 236 story chapters) |
| 23 | Settings | tokens and shell, plus a 3D-cutscene toggle |
| 04/07/19/20/22/24 | Chapter select / forecast / birth / years / save-load / components | tokens only: the chapter picker lives in the hub, the forecast in the battle rail, single-slot saves, and the components are in `UIKit` |

Works also got a Stitch-language rebuild. Every remaining minor screen now sits on the ink-void base.

## Battle
- Real terrain ground shader: authored top-down textures, feathered blends and biome grading. The board fits the stage at up to 104px per cell, and tokens have contact shadows.
- **3D Fire Emblem–style combat cutscenes** (vertical slice). A SubViewport stage plays when an attack resolves: attack, skill, hit, crit, dodge and death beats.
  - Space skips, Tab toggles speed. Settings let you turn the cutscenes off or default them to 2×.
  - Rigged stand-in GLBs (shared armature, Blender 4.2) cover the tutorial cast.
  - Tactics logic is unchanged and covered by CI.

## Fixes
- 子嗣期望 no longer overlaps (marriage rebuild).
- Apprentice tokens are readable again.
- Named portraits key by `cast_key` (character id), not by name.
- Estate holdings and KPI glyphs use the new frost icon set, plus market icons.

## Known gaps
- **Hunyuan3D is unavailable on m173.** The machine has no NVIDIA GPU or driver, no Hunyuan3D-2 or hy3dgen, no torch, diffusers, trimesh, pymeshlab or rembg, no ComfyUI, no Blender, and no listening service. The cutscenes ship with Blender-authored stand-ins.
- **The enemy-portrait Qwen batch did not run.** The farm endpoint timed out, and m173 was offline at ship time.
