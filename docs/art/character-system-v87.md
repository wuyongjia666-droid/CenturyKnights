# CenturyKnights 角色系统 · Modular Genetic Characters v8.7

> **Goal:** players read bloodline, family and history from a face, the way 诸神皇冠 lets you spot the royal birthmark or the gold-eyed line in a tavern, and then go past it. Here traits can skip generations, mixed blood visibly blends, faces age, and battle scars and honours stay on the face for life. All of it is in **one locked style** (`style-lock-v87.md`), in both the **2D portrait** and the **3D cutscene** model, driven by the **same genome**.

## 0. Principles
1. **Genome → phenotype → render.** Data never stores pictures, only genes, and both renderers read the same phenotype.
2. **Modular, not per-unit.** Random units are assembled at runtime from shared parts. Only named heroes get bespoke busts and heads.
3. **One skeleton, one canvas.** Every 3D part is skinned to the shared `build_standins_v86` armature, so animations are shared. Every 2D part is painted on one 1024² canvas with one face anchor, so layers align.
4. **Style lock everywhere.** Parts are generated with the locked Qwen prefix/negative and must pass `tools/art/style_check_v87.py` before ingest.

## 1. Genome v2 (`CKCharacter.genome`, saved; `appearance` stays as the phenotype cache)
### 1.1 Mendelian loci (diploid: two alleles, one from each parent)
| Locus | Alleles (dominance high → low) | Expression |
|---|---|---|
| `hair` | ink_black > ash_brown > ember_red > wheat > **frost_silver (recessive)** | Dominant allele. Adjacent-rank heterozygotes blend 20% toward the other (mixed tones) |
| `eyes` | dusk > slate > pine > river_blue > amber > **rime (recessive, frost_crown-linked)** | Same rule; rime = pale glacier iris with a frost ring |
| `brow` | thick > straight > arch > soft | Dominant |
| `ears` | round > **crest (recessive)** | crest = fine pointed ear tip, the old 霜冕 royal sign |
| `mark` | none > **crown_rime (recessive)**; `ember_sigil` incompletely dominant | crown_rime = frost-crystal birthmark at the left temple (emissive frost). ember_sigil = ember vein line under the eye, faint in heterozygotes |

**Skip-generation.** A recessive trait shows only when homozygous, so two carriers (black-haired, round-eared parents) can have a silver-haired, crest-eared child: the grandmother's line returns. The tavern/lineage UI shows "携带" (carrier) chips when the player has scouted a character's genes.

### 1.2 Polygenic face & body (continuous, family resemblance)
`face = {width, jaw, cheek, nose, eye_tilt, eye_size, brow_height}` and `body = {height, build}`, each in [-1, 1].

`child = 0.5·(father + mother) + 0.15·N(0,1) + 0.10·(bloodline_mean − midparent)`, which regresses toward the bloodline mean.

Siblings therefore share their parents' face shape while still differing. In 2D the values drive the face-base warp (mesh-warp control points on the face canvas); in 3D they drive head shape keys and bone scales (height ±6%, build via shoulder/hips/limb scale).

### 1.3 Bloodline (existing `blood_mix`)
| Bloodline | Face base | Default skin | Linked traits |
|---|---|---|---|
| common_ash 灰烬民胤 | broad, practical | warm neutral | none |
| river_ward 河卫血胤 | lean, long-eyed | fair cool | raises river_blue frequency |
| ember_noble 余烬贵胤 | high cheek, strong brow | olive | carries `ember_sigil` |
| frost_crown 霜冕王胤 | narrow, tall, fine | porcelain | carries `crown_rime`, `crest`, `rime`, `frost_silver` |

- **Mixed blood:** the face base is a blend. 2D crossfades the two bloodline bases with the secondary weight, limited to the face mask. 3D blends the shared-topology bloodline head shape keys. A 50/50 ember × frost child visibly sits between both parents.
- **Founders:** they roll alleles from bloodline-weighted allele tables, so frost_crown founders are often silver/rime/crest carriers. A legacy `appearance` dict is converted with both alleles equal to the phenotype.

### 1.4 Acquired, non-heritable (persist on the face for life)
| Kind | Trigger | 2D | 3D |
|---|---|---|---|
| `scars[]` (slot: cheek_l, cheek_r, brow_l, brow_r, chin, neck) | Taking a crit at ≤25% HP, or surviving a "fell" result | scar decal layer per slot | head decal (normal + albedo) |
| `honors[]` | Rank promotion (baron: frost collar pin; count: rime circlet; duke: crown-line frost tattoo), battle titles | equipment/mark overlay | emissive frost trim on the outfit and circlet mesh |
| `age_stage` | young < 18 ≤ adult < 45 ≤ elder | youth base / elder wrinkle layer, hair greys toward silver with age | head shape key `elder`, hair desaturation, posture offset |

The legacy inherited `scar` allele is migrated into `scars[]` and is no longer inherited.

## 2. 2D portrait = runtime paper-doll (`scripts/art/portrait_doll.gd` + `portrait_doll.gdshader`)
Canvas: 1024² front view (style-lock "portrait part" camera). Layer stack, back to front:

| # | Layer | Source part | Runtime treatment |
|---|---|---|---|
| 0 | plate | void + vignette (UIKit) | faction rim (frost / coral) |
| 1 | hair_back | `hair/<style>_<g>_back` | gradient-map by hair colour |
| 2 | outfit | `outfit/<job>_t<tier>_<g>` | ally/enemy accent swap |
| 3 | face base | `face/<bloodline>_<g>_<age>` (+ 2nd bloodline crossfade) | skin tint (luminance-preserving), polygenic mesh-warp |
| 4 | ears | `ears/crest_<g>` | skin tint |
| 5 | eyes | iris mask from the base | hue/value recolour by eye allele; rime adds a frost ring |
| 6 | brows | `brow/<id>_<g>` | tinted toward hair colour |
| 7 | marks | `mark/crown_rime`, `mark/ember_sigil`, `scar/<slot>`, `elder/<bloodline>_<g>` | emissive add for rime |
| 8 | hair_front | `hair/<style>_<g>_front` | gradient-map by hair colour |
| 9 | equipment | `equip/<honor or gear>` | — |

**Part generation ("edit-diff", guarantees alignment and style).**
1. Qwen generates one **neutral base** per bloodline × gender, with neutral grey cropped hair and a neutral undershirt.
2. Every other part is a **reference edit of that same base**, e.g. "add <hairstyle>", "add a fine pointed ear tip", "add a frost-crystal birthmark at the left temple", "age to 60".
3. `tools/art/doll_extract_v87.py` subtracts base from edit in Lab space, then cleans the mask (threshold, morphological open/close, feather 2px) to cut the part out as RGBA.
4. Hair and brow parts are generated in **neutral silver-grey**, so the gradient map can paint any genome colour.
5. Named heroes keep their bespoke busts. The doll is used for every generated unit, child and tavern recruit.

## 3. 3D cutscene = modular rig (`scripts/art/unit_model.gd`)
Assembly: `base_body[g][build]` + `head[bloodline mix]` + `hair[style]` + `outfit[job][tier]` + `weapon` + `honors`, all skinned to the shared armature, with genome-driven material parameters.

| Module | Source | Pipeline |
|---|---|---|
| Base body m/f (lean / std / broad as bone-scale presets) | Qwen turnaround → Hunyuan3D-v2 (:8327) | `tools/models/rig_mesh_v87.py`: cleanup → decimate → landmark auto-rig → re-pose to the canonical rest → shared NLA actions |
| Outfit per job × tier × gender | Qwen turnaround of the outfit on the body → Hunyuan3D | same canonicalisation, then head/hands cut at the neck/wrist loops, then weights transferred from the base body |
| Head per bloodline × gender (+ named heroes) | Qwen head turnaround → Hunyuan3D | shrinkwrap onto the canonical head topology so all heads are shape keys of one mesh (bloodline blend + face params + elder) |
| Hair per style | Qwen hair-on-mannequin turnaround → Hunyuan3D | bound to `head`; genome tint via material |
| Weapon | `build_standins_v86.build_weapon` (sword/axe/spear/bow, shield, quiver) | hand-socket bound |

- **Textures:** Hunyuan3D-v2 on the farm is geometry-only (no paint model installed; Trellis2 weights absent). Albedo is **projected from the style-locked turnaround** (front/back planar projection blended by normal, seam fill) in Blender. Genome colours are material parameters, not new textures: hair/skin/eye tints and a mark emissive mask.
- **Shader:** the style-lock §8 toon ramp, frost/coral rim, inverted-hull outline.
- **Fallback resolution order** (unchanged API):
  1. `cast_<key>.glb` (named);
  2. modular assembly;
  3. `enemy_<tmpl>.glb`;
  4. archetype stand-in.

## 4. Farm batch (all jobs queued at once)
- **Driver:** `tools/farm_v87/farm.ps1` runs on the m173 relay and binds the physical NIC (`--interface 192.168.20.2 --noproxy '*'`). This bypasses the FlClash TUN without changing any proxy config.
- **Generators:** `tools/farm_v87/gen_*.py` build the ComfyUI API graphs from `style-lock-v87.json`.

| Batch | Port | Jobs |
|---|---|---|
| A cast & heroes full-body turnarounds (bust-referenced) | 8322 | leader, dengying, militia_a/b, bandit_weak, bandit_archer, 7 v8 heroes |
| B base bodies | 8322 | m, f |
| C outfits | 8322 | 9 jobs × m/f (ally) + 4 bandit templates (enemy) |
| D face bases | 8322 | 4 bloodlines × m/f |
| E part edits (after D) | 8322 | hair 5 styles × front/back, brows 4, ears crest, marks 2, scars 3, elder, youth |
| F meshes (after A–C) | 8327 | Hunyuan3D-v2 shape: GeneRanch "peak" graph (res 8192, 50 steps, cfg 8, octree 512, surface net 0.6) |

## 5. Proof slice (v8.7 ship gate)
1. **Tutorial cast:** 灰旗 leader, 苇原灯影 dengying, militia ×2, 隘口流匪 (bandit_weak), 匪弓手 (bandit_archer). Each needs a real 3D model in the cutscene and a style-gate-passing portrait.
2. **Inheritance trio:**
   - **Father:** ember_noble 0.7 / frost_crown 0.3, ink_black hair carrying frost_silver, round ears carrying crest.
   - **Mother:** river_ward, wheat hair carrying frost_silver, carrying crest.
   - **Child:** frost_silver hair and crest ears (both recessive, skip-generation), mixed face, father's brow, mother's eyes.
   - Rendered as 2D dolls and 3D models side by side in `/workspace/v8.7.0-art_screens/`.
3. Every ingested plate has a review sheet in `docs/art/review/`.
