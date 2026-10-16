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
