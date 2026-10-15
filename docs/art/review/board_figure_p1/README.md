# Board figure P1 过目样张（头保留 + hair_* 模块）

## 本轮相对「光头两点眼」否决的改动
1. **头**：禁止头部体素。混元头强 weld + collapse ~1.8k；五官体块位移。compose 只出躯干。
2. **发**：强制挂 8 款 `hair_*` LOD（farm 模块入库并横向放大）。卡片相机曾裁掉过高发顶，已压到帧内；团长可见深色发块（仍非立绘 swept 轮廓）。
3. **身**：farm 躯干 LOD；靴/腰/领 bisect + edge_split 后 POINT 上色。
4. **配色**：plate_palettes；近黑发抬亮度地板。
5. **对照**：cards / vs_portrait / desktop_after / organic_preview。

## 诚实自评
| 项 | 状态 |
|--|--|
| 光头 | **部分改善** — 卡片上已有发块，轮廓仍扁/不像立绘发型 |
| 面具糊脸 | **减轻未清** — 非体素头，棋盘尺度五官仍软 |
| 领口腰锯齿 | **减轻未清** |
| 过目 | **未通过** — 不宣称完成 |

重建：`build_organic_board_overrides.py` → `board_figures_v1.py` → `godot --import` → `board_figure_shots.tscn`
