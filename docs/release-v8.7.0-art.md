# v8.7.0-art · Real Hunyuan3D tutorial cast, modular genome characters, playable atlas

## Vibe
2026 contemporary fantasy (style-lock-v87): luminous ink void, frosted glass, thin lineart. Crystal frost #6ED4FF primary, mint #5EE0B5 ally, coral #FF7A70 enemy, ember #FF8A3D sparks only. Not medieval / parchment / gold.

## Real 3D characters (farm → Blender → Godot)
Tutorial cast ships as **real Hunyuan3D** meshes (style-gated Qwen turnarounds → farm :8327 → `rig_mesh_v87` voxel re-skin, traced A-pose arms, skirt/arm weight guards, 4-influence limit, albedo projection, shared NLA anims):
- Allies: `cast_leader`, `cast_dengying`, `cast_militia_a`, `cast_militia_b`
- Enemies: `enemy_bandit_chief`, `enemy_bandit_weak`, `enemy_bandit`, `enemy_bandit_archer`
- Archetype outfits: warrior m/f, priest m, squire m/f (modular attach path for genome modules)

Style-lock **toon body shader** (2-band ramp, team rim, inverted-hull outline #0A0E14) on every farmed textured body.

## Modular + genetically inherited characters
Surpasses 诸神皇冠-style bloodline looks:
- **CKGenome v2**: diploid Mendelian loci (hair/eyes/brow/ears/mark) with dominance, recessive/skip-generation, incomplete `ember_sigil`, polygenic face/body, ageing greying, acquired scars/honors (not inherited).
- **3D modules**: all 8 farmed hair styles (`crop/swept/tied/messy/long/pony/bob/crown`) via `hair_module_v87` (plate-calibrated head-bone space, roughness skin/hair split). Genome tint keeps strand texture. BoneAttachment3D on head.
- **2D paper-doll**: `CKPortraitDoll` compositor ready; face bases + edit-diff parts queued on the farm (partial ingest; named heroes keep bespoke portraits).
- **Proof**: parent/parent/child trio (`tests/trio_proof_v87.tscn`) — real `CKGenome.cross` (seed 28), Punnett odds on screen, 3D modular hair colours match genotypes (ink/wheat → frost_silver + crest ears).

## Style lock
`docs/art/style-lock-v87.md` + JSON: fixed Qwen prefix/negative, Stitch palette, lighting, cameras. `tools/art/style_check_v87.py` gate rejects off-style plates (known-bad medieval/gold plates still fail; skin-exempt parchment for portraits).

## Atlas (already on main)
Playable atlas with reputation unlocks, nation gating, city vignettes (style-gated), board growth — included in this build.

## Screenshots
`/workspace/v8.7.0-art_screens/`: cutscene with real models (leader/chief, dengying, militia), trio 3D inheritance proof.

## Known gaps
- 2D doll part ingest incomplete at ship (farm batch E still draining; m173 relay intermittently unreachable). Named cast uses bespoke portraits; modular doll fills in as parts land.
- Remaining outfit archetypes / named-hero fullbodies continue on the farm (bF4); stand-ins remain as fallback via `UnitModel.archetype_for`.

## Download
- Release: https://github.com/wuyongjia666-droid/CenturyKnights/releases/tag/v8.7.0-art
- ZIP: https://github.com/wuyongjia666-droid/CenturyKnights/releases/download/v8.7.0-art/CenturyKnights-windows-v8.7.0-art.zip
- SHA256: `6bc88c0979ee859b33cf76566f942c46168207778379cab1d5d931a73a4a8da3`
