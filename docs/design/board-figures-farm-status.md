# Board figures farm status (2026-10-15 Asia/Shanghai ~11:30)

## Shipped this PR (farm cast t1)
- Hunyuan ready: `leader_m/f`, `bandit`, `bandit_archer` → retopo ≤5500 tris → `project/assets/models/board/farm_cast/*.glb`
- `CKBoardFigure` loads farm casts for captain/leader + bandit templates (else Godot primitives)
- Raw hy drops in `tools/models/board_parts/farm_inbox/` (gitignored); retopo: `tools/models/retopo_farm_hunyuan.py`
- **Not** PR #301

## Pipeline still running on m173
- hy_batch: remaining hunter / bandit_chief / base…
- hy_outfit_r2: haired outfits on :8327

## Keep vs reshoot (Qwen)
- Keep: cast leader/hunter/bandit sheets
- Reshot: outfit_r2 (haired)
