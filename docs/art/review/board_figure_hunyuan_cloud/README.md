# 混元云端棋子过目（2026-10-16 夜）

**停用**本地方块套件（Opus kit cubes）。本目录 = 农场 Hunyuan `:8327` 已出模 + 团长 Path C 全身。

来源：
- `hy_rough`：`/workspace/farm_board_fig_hy_ready/*.glb`（m173 `board_fig_t1/hy_batch` 同步，混元粗模 ~0.9–1.4M tris）
- `farm_cast`：同批 retopo ≤5.5k 进包件
- `pathc_fullbody`：团长混元全身 normalize-only（~1.5M）

## 优先给用户看（混元粗模，非方块）

| 角色 | 正视 | 35° | 脸近景 |
|---|---|---|---|
| 团长 leader_m | `leader_m_hy_rough_front.png` | `…_35deg.png` | `…_face.png` |
| 猎手 hunter_m | `hunter_m_hy_rough_front.png` | `…_35deg.png` | `…_face.png` |
| 山贼头目 bandit_chief | `bandit_chief_hy_rough_front.png` | `…_35deg.png` | `…_face.png` |
| 团长 Path C（已过关 LOOK） | `leader_m_pathc_fullbody_front.png` | `…_35deg.png` | `…_face.png` |

对照：`vs_portrait_*.png`、`refs/qwen_*.png`（出模用的立绘/转面）。

## QA（executor Read）
- `leader_m_hy_rough_front`：**PASS** — 写实大衣/护甲/脸，非方块肢
- `hunter_m_hy_rough_front`：**PASS** — 写实长发与层衣
- `bandit_chief_hy_rough_front`：**PASS** — 壮硕写实甲胄

## 说明
- 本机 box **不能**直连 `192.168.9.244:8327`；提交须在 **m173** 跑 `gen_hunyuan_v87.py` + `farm.ps1`。
- 上述三件 **已在农场混元出过**（2026-10-15）；本次是 Blender 粘土过目重渲，未再排队云端。
- 若用户要「更贴当前立绘」重跑：在 m173 用最新 Qwen 转面 → `gen_hunyuan_v87.py` → `:8327`。


## Path C 通用 9 件 + 关键猎手/头目（2026-10-16 夜用户过目通过）

目录：[`pathc_native/`](pathc_native/) — normalize-only GLB + 正面/35°/脸过目图。

- 通用身：`base_body_m` / `base_body_f`
- 职业壳：猎人 / 团长外套 / 轻步兵（各 m+f）
- 关键角色：`hunter_m` / `hunter_f` / `bandit_chief`（团长 LOOK 仍在 `board_figure_p1/hunyuan_noreduce/`）
- 登记：`project/data/board_figure_pathc.json`；`board_figures.json` → `pathc_look`

**不进导出包。** 合 #310 前仍须用户对运行时接线目视 OK。
