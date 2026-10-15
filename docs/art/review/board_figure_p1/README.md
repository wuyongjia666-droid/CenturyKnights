# Board figure P1 过目样张（脸/色边界迭代）

## 本轮相对「黑罩脸」否决的改动
1. **脸**：硬编码头部分区 — 正脸整盘肤色；眼睛仅两处小点；发只在后上顶。禁止整脸发色/眼槽黑罩。
2. **体块**：加强鼻/眉/颧/下颌顶点位移（无布尔）。
3. **色边界**：动态颈线；躯干硬高度带；靴/裤分界 `bisect` 切环；去掉易造成腰部锯齿的家徽环。
4. **对照**：`vs_portrait/captain_vs_plate.png` = 棋子 + 立绘 + 发/肤/外套/内衬色条。

## 诚实自评（推送前目视）
| 项 | 状态 |
|--|--|
| 整脸黑罩 | **已消除** — 正脸为肤色，眼为小深色点 |
| 鼻眉下颌可读 | **仍偏软** — 有位移暗示，棋盘尺度下仍不像立绘五官 |
| 色边锯齿 | **减轻未清** — 领口/腰线仍有三角锯齿；未达「干净材质岛」 |
| 相对立绘 | 气质与配色方向接近色条，形仍是棋盘 LOD 小人 |

**过目未通过，不宣称 P1 完成。**

## 路径
- `cards/{captain,hunter,bandit*}.png`
- `vs_portrait/captain_vs_plate.png` + `captain_palette.json`
- `organic_preview/compose_*.png`
- `desktop_*_1280x720.png`

重建：`tools/models/build_organic_board_overrides.py` → `board_figures_v1.py` → `board_figure_shots.tscn`
