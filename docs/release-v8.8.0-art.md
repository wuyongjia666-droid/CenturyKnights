# v8.8.0-art · Paper-doll part sheets + expanded modular outfits

## Highlights
- **2D paper-doll parts (batch E)**: farmed ember/river/common_ash (+ frost scraps) style-gated via `style_check_v87.py`, extracted/ingested into `project/assets/art/doll/`. `UnitArt.portrait` prefers `CKPortraitDoll.compose` for non-named cast so random recruits/heirs use composited portraits.
- **3D modular outfits**: full job set m/f — squire, light_inf, heavy_inf, hunter, apprentice, light_cavalry, warrior, archer, priest (18 outfit GLBs on shared armature).
- **Hair clip polish**: module scale 0.90 + slight Y lift on head bone attachment.
- **Atlas**: no atlas farm queue on m173 this turn; left for atlas worker (weapon icons / city plates when ready).
- **Enemies**: existing bandit theme retained; more themes when farm returns.

## Proof screens
`/workspace/v8.8.0-art_screens/`: `trio_2d_doll.png` (parent→child 2D compose), `trio_3d.png` (same genome 3D modular), `outfits_qa.png`, `doll_parts_batch_e.png`.

## Style lock
Frost #6ED4FF · mint #5EE0B5 · coral #FF7A70 · ember #FF8A3D — contemporary fantasy, not medieval. Gate: `tools/art/style_check_v87.py`.

## Release
- Tag: v8.8.0-art
- ZIP: https://github.com/wuyongjia666-droid/CenturyKnights/releases/download/v8.8.0-art/CenturyKnights-windows-v8.8.0-art.zip
- SHA256: `2311b592c101be033410da7a24ffcb00fd5f049bcfb752011091fc6650c60ad2`
