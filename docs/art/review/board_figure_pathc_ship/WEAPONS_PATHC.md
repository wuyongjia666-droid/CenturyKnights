# Path C 武器（混元精致款 → 航运 LOD）

用户否决几何手搓武器后，改为混元云端文生3D（V3.1）出母版，再 Voxel/烘贴成棋盘档。

| 件 | 用途 | 母版（箱外） | 航运 GLB |
|---|---|---|---|
| sword | 团长 / 轻步兵 | `/workspace/pathc_ship/weapons_pathc/masters/sword.glb` (~60MB) | `assets/models/board/pathc_weapons/sword.glb` (~1.2MB) |
| bow | 猎人 | `.../bow.glb` (~87MB) | `bow.glb` (~1.1MB) |
| axe | 山贼头目 | `.../axe.glb` (~84MB) | `axe.glb` (~1.3MB) |
| spear | 民兵/轻骑（预留） | `.../spear.glb` (~61MB) | `spear.glb` (~1.0MB) |

- 接线：`board_figures.json` → `pathc_ship.weapon_glb` + `board_figure.gd` `_attach_ship_weapon`
- 棋盘实机：`board_ch0_weapons_pathc.png`、`board_e1_ford_weapons_pathc.png`（头目斧）
- 母版不进 git；仅航运档 + 对照截图进 PR #313

## 握持 v2 + 航运瘦身（grip_v2/）

- 航运 GLB 原是未焊接三角汤（顶点≈索引）。焊接后减面到 35%（剑 12.0k→4.2k 面、弓 10.0k→3.5k、斧 12.0k→4.2k、矛 9.0k→3.2k），albedo 512→384 JPG q82。
  四件 GLB 合计 4,649,140 → 1,637,632 B；`export_size_report.py` 从 FAIL（超 878,617 B）变 PASS（余量约 2.3 MB）。
- 握持改为数据驱动：`board_figures.json pathc_ship.grip`（每件武器的柄心 g、本地轴 a/b、目标朝向 dir/side、scale、手心偏移 off），
  `grip_body[stem][weapon]` 可按身体覆盖偏移。柄心精确落在实测手点（向掌心偏移约 5cm）。
- 对照：`grip_v2/close_front_q34_before_after.png`、`close_hand_before_after.png`、`board_crop3x_before_after.png`、`board_ch31_forge_before_after.png`、`board_ch0_pass_before_after.png`。
- 已知限制：航运件是静态 A-pose 网格，手指张开，无法真正合拢握住柄；目前是柄穿过掌心/指间。

## 握持 v3（grip_v3/）

用户反馈「剑柄拿反、很多没拿对部位」。查母版/航运 GLB 本地轴后重算 `pathc_ship.grip`：

| 件 | 本地轴发现 | 握点 g | 朝向 |
|---|---|---|---|
| sword | 长轴 Y；尖端 Y−、护手 Y≈+0.34（最宽）、柄/圆头 Y+；刃薄 Z | 柄中 [0,0.52,0]（护手与圆头之间） | a→圆头；tip 朝前下外（−Z 前，角色面朝 −Z） |
| bow | 长轴 Y；曲臂在 XZ；握把近原点 | 弓把中 [0.06,0,0.04] | 竖持；弦/腹可读 |
| axe | 斧头在 +Y（X 向最宽，月刃朝 −X）；柄在 −Y，柄心 X≈0.35 | 下段缠柄 [0.35,−0.36,0] | 斧头朝上前外 |
| spear | 矛尖 +Y；叶刃 ~Y+0.4；杆向 −Y | 杆约 1/3 处 [0,−0.36,0]（原 −0.12 偏高） | 尖朝上前；鐏近地 |

v2 主要问题：剑/矛/斧的 `dir` 把尖端指到 +Z（朝镜头=角色背后），看起来像柄拿反。v3 把 tip/head 翻到 −Z（前方）。

对照：`grip_v3/close_hand_before_after.png`、`close_front_q34_before_after.png`、`board_crop3x_before_after.png`、`axis_sword_*.png`。

已知限制仍在：静态开掌，手指合不上；柄穿过掌心。未改模型体积。
