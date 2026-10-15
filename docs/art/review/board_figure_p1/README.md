# Board figure P1 过目样张

按 `docs/design/pawn-redesign-opus.md` §6 P1 / 附录 A：正式模块化套件（非 farm_cast 整模、非 #301）。

## 文件
- `desktop_before_1280x720.png` / `desktop_after_1280x720.png` — ch0_pass 桌面 A/B（关/开 3D 棋子）
- `cards/captain.png` — 团长（outfit_captain + sword + cape）
- `cards/hunter.png` — 猎手（outfit_hunter + bow）
- `cards/bandit_weak.png` / `bandit.png` / `bandit_archer.png` / `bandit_chief.png` — 山贼四模板

## 资产
- `project/assets/models/board/board_figures_v1.glb` + `.json`
- `project/data/board_figures.json`
- 生成器：`tools/models/board_figures_v1.py`

## 发型 overrides
`project/data/plate_palette_overrides.json` 仍待人工复核发型标注（P0 留下的 needs_review）。

重渲：
```bash
xvfb-run -a godot --path project --rendering-driver opengl3 \
  --scene res://tests/suites/battle/board_figure_shots.tscn \
  -- --out=$PWD/docs/art/review/board_figure_p1
```
