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
