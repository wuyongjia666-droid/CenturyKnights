# 棋盘棋子量产配方（锁定 2026-10-16）

> 用户拍板。执行以本文 + `pawn-redesign-opus.md` §5/§6/§8.0 + `captain-base-model-plan.md` §3 为准。

## 一句话

**通用身 + 职业壳 +（共享/独特）头部件**；脸跟立绘取色；服装/脸本机或农场出；**混元只留给关键角色/底模 LOOK**；**禁止接头焊身**；**禁止 soft COLLAPSE**。

## 角色分档

| 档 | 身体 | 头/脸 | 服装武器 | 混元云端 |
|---|---|---|---|---|
| 杂兵 / 多数首领 | `body_m` / `body_f` / `body_heavy` | **共享** `head_m`/`head_f`（生成器颅面；可复用） | 职业/主题壳 | **不用** |
| 主角团 / 关键 BOSS | 同上通用身 | **独特**头部件：农场/本机出合格 `head_*.glb` **整件替换**套件头 | 职业壳 + 专属件 | 仅必要时 |
| 团长（已过关 LOOK） | Path C 全三角 normalize-only 作对照 | 立绘/混元脸作 LOOK | Opus `outfit_captain` | 已出全身，**不再为每人复跑** |

## 管线步骤（量产）

1. **身**：`tools/models/board_figures_v1.py` 生成 `body_*`（共享）。
2. **壳**：同脚本生成 `outfit_*` / `weapon_*` / `sign_*`；立绘槽着色走 `plate_palette` + `board_figure.gdshader`。
3. **头**：
   - 默认：生成器 `build_head`（硬面眉鼻颌，棋盘可读）。
   - 升级：把合格 `head_*.glb` 放进 `tools/models/board_parts/` **同名覆盖**（整件替换）。
   - **不要**把混元头或 compose 头切片焊到 `body_*` 颈桩上。
4. **发**：8 款 `hair_*` LOD（农场模块优先）。
5. **组装**：`CKBoardFigure.spec_for` / `build`；映射唯一来源 `data/board_figures.json`。
6. **过目**：`docs/art/review/board_figure_opus_mass/` 样板 + Godot cards。

## 禁止

| 禁止 | 原因 |
|---|---|
| 每人上云端混元出全身 | 贵、慢；用户明确不要 |
| soft COLLAPSE / 激进减面混元开壳 | 大衣/脸/脚碎裂（38k、~140k 均翻车） |
| 接头焊身（head-attach） | 颈缝/比例/开壳反复失败，已弃用 |
| 把未过关覆盖放进 `board_parts/` 根目录 | 会污染套件；坏件进 `_qa_fail/` |
| 合 #310 资产前无用户目视 OK | 用户锁定 |

## 团长特例

- Path C：`docs/art/review/board_figure_p1/hunyuan_noreduce/cast_leader__board.glb`（~1.5M，**不进导出**）。
- 量产棋盘仍用 Opus 套件；Path C 只作 LOOK。

## 样板

`docs/art/review/board_figure_opus_mass/` — 通用身 + 共享生成器头 + 山贼壳 / 团长壳。

生成：`blender --background --python tools/models/preview_opus_mass_sample.py`

## 与 Opus 分期关系

- P0+P1：本 PR #310（套件接入）；**合入前须用户目视资产**。
- P2 动作 / P3 手机分档：**已合**。P4 全职业/主题标志件映射 + 套件 `sign_*`：**本 PR**；Path C 航运铺满见 `board_figure_p4_deferred.md`。§7 实机盲测/帧率仍待用户机。


## Path C 通用件已过目（2026-10-16）

用户确认混元云端 Path C 精致款可用。已入库 LOOK：

- `docs/art/review/board_figure_hunyuan_cloud/pathc_native/`（9 通用 + hunter_m/f + bandit_chief）
- 登记 `project/data/board_figure_pathc.json`

**量产视觉标准 = Path C**；方块 Opus kit 样板已 CANCELLED。  
运行时包体仍用套件/`farm_cast`，Path C 不进 `project/assets`（导出预算）。航运减面只许重拓扑/烘贴，禁止 soft COLLAPSE。
