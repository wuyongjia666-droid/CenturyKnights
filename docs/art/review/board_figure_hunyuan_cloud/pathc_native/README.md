# Path C 通用身 + 职业壳 + 关键角色（用户过目通过 2026-10-16）

精致款质量锁：混元云端图生3D V3.1 · ~1.5M 面 · 原生贴图 · **normalize-only**（禁止 soft COLLAPSE / 减面 / 重拓扑进本目录）。

## 资产

| stem | GLB（normalize 后） | 角色 | 过目图 |
|---|---|---|---|
| `base_body_m` | `base_body_m__board.glb` | 通用男身 | `*_front/35deg/face.png` |
| `base_body_f` | `base_body_f__board.glb` | 通用女身 | 同上 |
| `outfit_hunter_t1_m/f` | `outfit_hunter_t1_*__board.glb` | 猎人职业壳 | 同上 |
| `outfit_leader_coat_t1_m/f` | `outfit_leader_coat_t1_*__board.glb` | 团长外套壳 | 同上 |
| `outfit_light_inf_t1_m/f` | `outfit_light_inf_t1_*__board.glb` | 轻步兵壳 | 同上 |
| `hunter_m` / `hunter_f` | `hunter_*__board.glb` | 关键猎手 | 同上 |
| `bandit_chief` | `bandit_chief__board.glb` | 山贼头目 | 同上 |
| 团长（已有） | `../board_figure_p1/hunyuan_noreduce/cast_leader__board.glb` | LOOK 标准 | 上级目录 `leader_m_pathc_*` |

登记表：`project/data/board_figure_pathc.json`（由 `board_figures.json` → `pathc_look` 引用）。

## 接线规则（#310）

1. **本目录 = LOOK / 源模真相**，不进 Godot 导出（`export_size` / UnitModel 不会自动选用）。
2. 运行时棋盘仍走 `board_figures_v1` 套件 + `farm_cast`，直到有合格航运体积烘贴件。
3. 量产配方（通用身 + 职业壳）以本批 Path C 为视觉标准；方块 Opus kit 已停（见 `board_figure_opus_mass/CANCELLED.txt`）。
4. **禁止**接头焊身；**禁止**把本目录 GLB 拷进 `project/assets/models/units/` 除非先解决导出预算并经用户目视。

## 源

混元云端网页产物：`/workspace/board_figure_hunyuan_review/cast3_textured/out/*_v2/*_pathc_native.glb`  
归一化：`tools/models/normalize_hunyuan_fullbody_board.py` 同规则（本批用无重渲脚本）。
