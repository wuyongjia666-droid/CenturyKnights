# Board figure P1 过目样张（有机 compose）

按 `docs/design/pawn-redesign-opus.md` §3.2 / §3.7。本轮禁止再堆 cube/cylinder。

## 做法
1. `tools/models/build_organic_board_overrides.py`
   - 优先 `farm_inbox/hy_*.glb`，否则 `farm_cast/*.glb`
   - **焊接**（旧 farm_cast 几乎是孤立三角面，会在 Godot 碎裂）
   - 体素重拓扑 → 流形 → 塌缩到 ≤5600 → 轻 Laplacian → 头放大 → POINT 顶点色槽
2. 覆盖通道写入 `tools/models/board_parts/compose_*.glb`
3. `board_figures_v1.py` 并入套件；`CKBoardFigure` 用 `compose` 跳过 body/head/hair/outfit
4. 保留主光镜像 / 敌方阵营色；0 贴图；`board_figure_check` PASS

## 诚实自评（推送前目视）
| | 相对前两批否决 | 相对立绘写实 |
|--|--|--|
| 团长/猎手/山贼 | **不再是球+方块/拼装块**；连贯有机曲面，外套有体积，能认作小人 | 仍是棋盘 LOD：脸多为体块暗示，手是连指，衣褶粗；色区边界锯齿 |
| 技术 | 流形约 5.3–5.6k 面；顶点色槽可读（肤/发/外套/裤/靴） | farm_cast 原盘面未焊接问题已在 compose 管道修；磁盘上旧 farm_cast 仍碎，勿直接当正式件 |

**过目未通过前不宣称 P1 完成。** 请对照 `cards/` 与立绘判断是否够「像立绘里的人」。

## 文件
- `cards/*.png` — Godot 着色器卡片
- `desktop_*_1280x720.png` — ch0_pass A/B
- `organic_preview/` — Blender 黏土
- `vs_portrait/compose_row.png` — 四卡横排

重建见 `tools/models/board_parts/README.md`。
