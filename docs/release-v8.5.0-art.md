# v8.5.0-art · Wired chrome, authored VFX, readable battle

## Vibe
2026 cutting-edge contemporary fantasy — luminous ink void, frosted chrome, crystal frost accent; mint = ally/heal, coral = enemy/deny, ember = sparks only. Not medieval.

## Every v840 UI plate is now on screen (audit: LEFTOVER 0, enforced in CI)
- **Battle unit card** (`scripts/ui/unit_card.gd`): v840 unit-card frame converted to frosted chrome with a clipped portrait window, name/class, **HP bar kit** (frame + under + ally-mint / enemy-coral gradient fills, tweened), **skill chips** (hover scale, dimmed when not ready, tooltips), compact stats. Replaces the 96px portrait.
- **Lineage**: v840 lineage card → 232px frosted card with portrait window, main bloodline + traits; **bloodline strip** → tintable TextureProgressBars per bloodline; authored lineage-link FX; lineage banner.
- **Estates**: **focus bar** + per-focus **grain / cash / fortify cards** (ink→frost duotone, current focus accent + pulse, deny feedback); old photographic banner retired.
- **Marriage**: dual portrait frame with real oval-clipped portraits (leader left, candidate right), marriage banner, authored vow-seal FX on marry.
- Global frosted panel chrome with correct 9-slice margins; readable accent-button text.

## Battle FX — re-authored and verified in real renders
- The v840 "dense FX sheets" were illustration panels, not VFX → rejected. All runtime FX (hit/slash/heal/crit/lock/shield/spark/select/ZOC/turn/seal/link) now procedurally authored: additive light, 4× supersampled, straight alpha.
- Sized for 56px cells from headless OpenGL screenshots: slash 80, heal 84, crit 108, lock/shield 80, spark 76, hit-spark 72, select reticle cell+18 (coral on enemies).
- Fixed white-square FX (GL first-load inside `_draw`) with a pre-warmed texture cache.
- Project texture filter → linear (no aliased painted art).
- Job tokens: readability pass (clean field + team rim) — legible at board size.
- Named cast / recruits / candidates now use v8 hero/bust faces; pre-v8 cartoon portraits banned. Enemies use v8.3 coral elite silhouettes (interim).

## Reliability
- New CI stages: **scene_load_check** (instantiates all 23 scenes) and **art usage audit**. Scene check caught and fixed a long-standing market.gd parse error.

## Stitch
- Live Google Stitch project ("CenturyKnights Frost" design system — palette identical to UIKit) produced 24 screens on m173; snapshot pulled to m173 (`stitch_pull_v850`). Transfer to the repo was blocked by m173 connectivity at ship time — ingest follows as a docs-only commit.

## Known gaps (next)
- Battle board terrain is still flat tiles → v8.6 board-plate redesign.
- Enemy portraits are interim silhouettes → Qwen enemy-bust farm.

## Download
- `CenturyKnights-windows-v8.5.0-art.zip` (490,457,104 bytes)
- SHA256：731dceeeb158f06fcc2968b1cad1b494f8f0a1d799f9cbecbec6f8259f83f92f

## CI
- ALL PASS (smoke · layout · scene_load · art audit · tactics e2e · full-chain e2e)
