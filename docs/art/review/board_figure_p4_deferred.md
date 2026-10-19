# Board figure P4 — deferred Path C shipping meshes

> Generated with P4 mapping PR. Kit shells + signature parts cover all 32 jobs / 22 themes.
> Path C textured shipping LOD stays within `pathc_ship_gate` ≤45MB; do **not** bake the full 32-job set in this PR.

## Shipping now (Path C)

| Stem | Role |
|---|---|
| `cast_leader` | Protagonist leader |
| `hunter_m` / `hunter_f` | Cast dengying + hunter LOOK |
| `bandit_chief` | Key boss unique face |
| `outfit_light_inf_t1_*` | Light-inf t1 shell |
| `outfit_hunter_t1_*` | Hunter t1 shell |
| `outfit_leader_coat_t1_*` | Captain coat shell |
| `base_body_m` / `base_body_f` | Shared bodies |
| `pathc_weapons/{sword,spear,axe,bow}` | Weapon LOD |

## Deferred (kit placeholder — readable via `board_figures.json`)

Count: **29** jobs without dedicated Path C shipping LOD.

| Job | Tier | Line | Kit outfit/compose | Weapon | Signs |
|---|---|---|---|---|---|
| `squire` | 1 | rider | `outfit_squire` | `weapon_sword` | sign_cape_short |
| `light_cavalry` | 2 | rider | `outfit_squire` | `weapon_spear` | sign_cape_short |
| `outrider` | 3 | rider | `outfit_squire` | `weapon_spear` | sign_cape_long,sign_scarf |
| `bridge_tax` | 3 | rider | `outfit_squire` | `weapon_spear` | sign_cape_long,sign_waist_badge |
| `warrior` | 2 | light | `outfit_light_inf` | `weapon_greatsword` | sign_pauldron_L |
| `veteran` | 3 | light | `outfit_light_inf` | `weapon_greatsword` | sign_waist_cape,sign_pauldron_both |
| `forge_brow` | 3 | light | `outfit_militia` | `weapon_hammer` | sign_goggles |
| `heavy_inf` | 1 | heavy | `outfit_heavy_inf` | `weapon_sword` | sign_pauldron_both |
| `sentinel` | 2 | heavy | `outfit_heavy_inf` | `weapon_sword` | sign_pauldron_both |
| `bulwark` | 3 | heavy | `outfit_heavy_inf` | `weapon_sword` | sign_pauldron_both,sign_cape_short |
| `archer` | 2 | hunter | `compose_hunter` | `weapon_bow` | sign_shoulder_strap |
| `marksman` | 3 | hunter | `compose_hunter` | `weapon_bow` | sign_scarf_long |
| `apprentice` | 1 | arcane | `outfit_apprentice` | `weapon_staff` | — |
| `mage` | 2 | arcane | `outfit_apprentice` | `weapon_staff` | sign_scarf |
| `lu_wai` | 3 | arcane | `outfit_apprentice` | `weapon_staff` | sign_bookcase |
| `warlock` | 3 | arcane | `outfit_apprentice` | `weapon_staff` | sign_cape_long |
| `priest` | 2 | priest | `outfit_apprentice` | `weapon_staff` | sign_theme_lamp |
| `medic` | 3 | priest | `outfit_apprentice` | `weapon_staff` | sign_medkit |
| `yan_zhan` | 3 | priest | `outfit_apprentice` | `weapon_staff` | sign_theme_lamp |
| `militia` | 1 | militia | `outfit_militia` | `weapon_spear` | sign_back_hat |
| `skirmisher` | 2 | militia | `outfit_militia` | `weapon_dagger` | — |
| `pathfinder` | 3 | militia | `outfit_militia` | `weapon_dagger` | sign_cloak |
| `banner` | 1 | banner | `outfit_banner` | `weapon_banner` | — |
| `standard` | 2 | banner | `outfit_banner` | `weapon_banner` | sign_pauldron_L |
| `salt_yin` | 3 | banner | `outfit_banner` | `weapon_banner` | sign_waist_badge |
| `acolyte` | 1 | cantor | `outfit_apprentice` | `weapon_staff` | — |
| `cantor` | 2 | cantor | `outfit_apprentice` | `weapon_book` | sign_shoulder_strap |
| `chorister` | 3 | cantor | `outfit_apprentice` | `weapon_book` | sign_scarf_long |
| `frost_wait` | 3 | cantor | `outfit_apprentice` | `weapon_staff` | sign_cape_long |

## Follow-ups

1. Bake Path C shipping LOD for high-traffic t2/t3 jobs (warrior, mage, sentinel, standard, …) when export budget allows.
2. Unique heads for remaining protagonist cast: head part swap into `board_parts/` (整件替换，禁止焊头).
3. Qwen `@100.127.28.107:8003` was **unreachable** during P4; no farm dispatch.

