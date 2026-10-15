# Board figures farm status (2026-10-15 Asia/Shanghai ~12:15)

## Shipped farm cast t1 (#306 / main-bbd10400)
- `leader_m/f`, `bandit`, `bandit_archer` → retopo ≤5500 tris → `project/assets/models/board/farm_cast/`
- `CKBoardFigure` loads farm casts for captain/leader + bandit templates

## Shipped farm cast t1b (this PR)
- `hunter_m/f`, `bandit_chief`, `bandit_weak` → same retopo pipeline (`tools/models/retopo_farm_hunyuan.py`)
- Ally hunters: `job_id` in `hunter`/`archer` or `job_role == ranger` → gendered `hunter_*.glb` (cross-gender fallback, else primitives)
- Enemy: `bandit_chief` / `bandit_weak` use own GLB when present (else `bandit`)
- Raw hy in `tools/models/board_parts/farm_inbox/` (gitignored)
- **Not** PR #301 modular kit

## Tris (FINAL)
| file | tris | h |
|------|------|---|
| hunter_m | 5500 | 1.85 |
| hunter_f | 5500 | 1.85 |
| bandit_chief | 5500 | 1.85 |
| bandit_weak | 5498 | 1.85 |

## Optional not wired
- `base_body_*`, `outfit_*` stay inbox-only (modular rejected with #301)

## Fix: farm colour + no capsule mix (post-d2c48b58 screenshot)
- **Grey clay root cause:** farm path painted one muted `coat` with strong wrap shadows; whole-mesh looked like unpainted clay. `_solidify_board` never ran and only looked at surface overrides (not `material_override`).
- **Fix:** `board_figure.gdshader` height bands (hair/skin/coat/pants/boots) + `board_compact` flatten; `_farm_mat` lifts luminance; assemble sets override + surface materials; unit layer calls `_solidify_board` after build.
- **Temporary job remap (until dedicated GLBs):**
  - `leader_*` ← `is_leader` / `cast_key=leader` / captain / banner / tank|heavy_inf|warrior
  - `hunter_*` ← all other allies (light_inf, squire non-leader, apprentice, cavalry, mage, ranger, …)
  - `bandit*` ← enemy templates; unknown enemy → `bandit`
- Goal: opening/tutorial 3D fight shows **only** farm_cast silhouettes (no Godot capsules).
