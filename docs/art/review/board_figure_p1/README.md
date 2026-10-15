# Board figure P1 过目样张（整模轻量 collapse + 贴图聚类上色）

## 硬改路线（相对「扁帽/糊脸/锯齿」否决）
1. **整模底**：混元优先（无贴图则 NN 从 cast/enemy 贴图取色）；只 weld + 分步 collapse（4–7k），**禁止**粗体素、**禁止**高度 bisect 切槽。
2. **顶点色**：albedo 采样 → k-means 聚类 → plate 槽；连通域吸收碎岛；服装用软高度先验（只改槽标签，不切网格）。
3. **发型**：源模发过扁则叠 `hair_*` LOD（≤1k），坐在头顶且略后移；compose 为整模（不再拼 head+扁帽）。
4. **脸**：前额朝向肤色 + 小眼点；仍偏软。

## 诚实自评
| 项 | 状态 |
|--|--|
| 有发型轮廓 | **部分** — 团长有深色发块/LOD，仍偏盔帽，不如立绘 swept |
| 干净色区 | **未过** — 相对 bisect 锯齿减轻，聚色仍有碎边 |
| 脸可读 | **未过** — 肤色有，五官仍糊 |
| 过目 | **未通过** — 不宣称完成 |

重建：`build_organic_board_overrides.py` → `board_figures_v1.py` → `godot --import` → `board_figure_shots.tscn`
