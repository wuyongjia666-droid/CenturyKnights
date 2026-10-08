# CenturyKnights 风格锁 · Style Lock v8.7

> **One style, everywhere.** This file plus its machine-readable twin `style-lock-v87.json` is the single source of truth for every generated or authored visual: portrait paper-doll parts, hero busts, full-body sheets, city/atlas plates, weapon & item icons, 3D materials and the toon shader. Every generator (character worker, atlas/cities worker, icon scripts, Blender pipeline) MUST read `style-lock-v87.json` instead of hand-writing prompts. Nothing is ingested into `project/assets/` without passing the consistency gate (section 7).

The visual anchor is the shipped v8 bust/hero set (`v8_hero_*`, `v8_bust_*`): calibrated reference plates that all pass the gate.

## 1. Direction (locked)
- **2026 contemporary fantasy.** Luminous ink-void world, frosted glass and frosted brushed-chrome, technical woven fabrics, hairline 1px frost trims, clean modern silhouettes.
- **Forbidden:** medieval/gothic, parchment, aged paper, sepia, gold, gilding, brass, baroque ornament, warm/golden lighting, heavy black inking, chibi, photo-real, 3D-render look.

## 2. Palette (from Stitch `tokens.json`)
| Role | Hex | Use |
|---|---|---|
| void / voidGlow | `#07080C` / `#10141C` | backgrounds, deep shadow |
| panel / elevated | `#161B24` / `#1C2330` | UI panels; also **ink-navy** fabric |
| slate | `#2A3442` | secondary fabric, shadow tint |
| frosted silver | `#C9D3DE` | metal, armour plates |
| frost white / text | `#F4F7FB` | highlights, light cloth |
| **primary frost** | `#6ED4FF` | focus, primary trims, rim light, ally emissive |
| **ally mint** | `#5EE0B5` | ally/heal accents only (small) |
| **enemy coral** | `#FF7A70` | enemy accents/rim, deny |
| **ember** | `#FF8A3D` | **VFX sparks only**, never a fill or a costume colour |
| lineart | `#0A0E14` | contours / 3D outline |
| plate bg | `#D9DEE3` | neutral generation background (keyed out on ingest) |

Genome colours (hair, eyes, skin, bloodline marks) are the **only** extra hues allowed; they are rendered within the same lighting and finish.

## 3. Lighting
- **Key:** cool white from the upper-left front (azimuth 45° camera-left, elevation 40°).
- **Rim:** thin crystal-frost `#6ED4FF` from the back-right. Enemies use a coral `#FF7A70` rim in 3D.
- **Fill:** soft cool ambient with no warm bounce.
- Godot key-light vector: `(-0.55, 0.65, 0.52)`. The cutscene `DirectionalLight3D` and every Blender bake/QA render use the same direction.

## 4. Line & finish
- **Line:** thin clean dark-slate `#0A0E14` contour on the silhouette (~1.5px at 1024px), lighter interior lines, no hatching.
- **Finish:** refined semi-realistic illustration with soft airbrushed painterly shading, crisp edges, matte fabrics, and frosted chrome with small sharp speculars.

## 5. Cameras (per asset class)
| Class | Camera |
|---|---|
| Portrait part (paper-doll) | Front view, eye level, 85mm. Head top at 10% from the top, chin at 52%, shoulders fill the width. **All parts share one canvas (1024²) and one face anchor.** |
| Hero bust (bespoke) | Three-quarter view facing camera-left, chest-up |
| Full-body sheet (3D source) | Orthographic turnaround, FRONT on the left / BACK on the right, A-pose arms at 35°, empty hands |
| Weapon / item icon | Isolated, 30° three-quarter top-down, diagonal bottom-left → top-right |
| City / atlas plate | Three-quarter aerial at 35° elevation, key light upper-left, atmospheric depth toward the top |
| 3D cutscene | 28–34° FOV, eye height 1.35m |

## 6. Prompts (Qwen-Image 2.1 on farm :8322)
- **Prefix:** `style-lock-v87.json → qwen.prefix`. It is prepended verbatim, then the asset-specific text follows.
- **Negative:** `qwen.negative`, used verbatim; generators may only append to it.
- **Side accents:**
  - `qwen.ally_accent`: allies get small mint accents.
  - `qwen.enemy_accent`: enemies get coral accents and darker charcoal fabrics.
- **Sampler:** euler/simple, 28 steps, cfg 1.0.
- Reference-conditioned jobs (bust → full body, base → part edit) pass the anchor plate as `images.image_1`, so identity and finish carry over.

## 7. Consistency gate (`tools/art/style_check_v87.py`) — mandatory before ingest
1. **Run:**
   ```
   python3 tools/art/style_check_v87.py check <candidates…> --kind portrait|sheet|city|icon|texture --sheet review.png --json review.json
   ```
2. **What it measures:** metrics on the subject (the plate background is removed):
   - gold ratio, parchment ratio, warm ratio (natural skin exempt), mean saturation, cool bias;
   - Lab a/b chroma-histogram χ² distance to the nearest reference plate.
3. **Pass rule:** a plate fails if any metric is outside the thresholds in `style-lock-v87.json → check`. Failing plates are **rejected** and must not be copied into `project/assets/`. Re-roll them with a new seed.
4. **Review sheet:** the `--sheet` output pairs each candidate with its nearest reference, shows the metrics, and draws a mint (pass) or coral (reject) frame. Every ingest batch commits its review sheet under `docs/art/review/`.
5. **Calibration:** `style_check_v87.py calibrate` must report all reference plates PASS. Old cartoon/parchment plates (`leader_default.png`, `bandit.png`, `bamboo_boss.png`, `harbor_thug.png`) are REJECTED, which proves the gate discriminates.

## 8. 3D toon shader / materials
- **Shading:** 2-band ramp with a 0.08 soft edge; shadow tint `#2A3442` at 0.55.
- **Rim:** frost `#6ED4FF` (enemy `#FF7A70`), power 3, strength 0.55.
- **Outline:** inverted hull 0.006m, `#0A0E14`.
- **Highlights and trims:** a single sharp specular on metal only. Emissive trim is ×2.2 frost (ally) or ×2.0 coral (enemy).
- **Albedo:** textures projected from style-locked concept sheets keep their painted albedo. Genome colours drive the hair/eye/skin/mark material parameters, never new texture paintings.

## 9. Reference sheet
`docs/art/review/style_reference_v87.png` is the canonical reference sheet. It holds the six reference plates, the palette swatches and the light-direction diagram. Workers compare against it visually, and the gate compares against it numerically.
