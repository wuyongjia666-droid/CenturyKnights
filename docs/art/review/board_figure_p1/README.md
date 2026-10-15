# Board figure P1 过目样张（写实体块重做）

按 `docs/design/pawn-redesign-opus.md` §3.2 / §6 P1：正式模块化套件必须**高于** Godot 基本体原型（球手、光头椭圆、透明方块外套）。

## 本轮相对被否批次的改动
- **头**：颅 + 脸板 + 眉弓 / 鼻楔 / 下颌 / 下巴 / 颧骨 / 深色眼窝（五官在头骨外，不再埋进椭圆）
- **手**：掌 + 指团 + 拇指的连指手，不再是球
- **身体**：收腰短裙体积、加粗锥形四肢、肩颈过渡
- **服装**：车削外套壳 + 领 / 翻领 / 下摆 / 衣褶体积；斗篷加厚侧裹
- **发型**：程序化贴头皮 LOD（≤1.2k），发量后收露出脸
- 顶点色槽 + 合并 1 网格 + 约 4–6k 面/人 + 0 贴图

## 文件
- `desktop_before_1280x720.png` / `desktop_after_1280x720.png` — ch0_pass 桌面 A/B
- `cards/captain.png`、`hunter.png`、`bandit_*.png` — Godot 着色器卡片
- `blender_preview/` — Cycles 组装预览（同套件）

## 资产
- `project/assets/models/board/board_figures_v1.glb` + `.json`
- 生成器：`tools/models/board_figures_v1.py`（`quality: sculptural_blocks_v2`）

重渲：
```bash
blender --background --python tools/models/board_figures_v1.py -- --out project/assets/models/board
xvfb-run -a godot --path project --rendering-driver opengl3 \
  --scene res://tests/suites/battle/board_figure_shots.tscn \
  -- --out=$PWD/docs/art/review/board_figure_p1
```

**过目未通过前不宣称 P1 完成。**
