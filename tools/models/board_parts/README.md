# board_parts

人工精修 / 覆盖通道（同名 stem 会替换 `board_figures_v1.py` 生成件）。

## 目录约定
- `compose_*.glb` — 整件有机 compose（团长/猎手/山贼等 t1 LOOK）。量产默认仍走「通用身 + 头部件 + 职业壳」；compose 作过目对照与过渡接线。
- `farm_inbox/` — 本机投放混元/Qwen 原模（大文件 gitignore）。
- `_qa_fail/` — **目视未过关、禁止再当 override** 的部件。当前：`head_m` / `head_f` 有机覆盖开壳塌脸（2026-10-16）。生成器会跳过本目录。

## 硬规则（2026-10-16）
1. **禁止接头焊身**（混元头 / compose 头切片接到通用身）——翻车多次，已弃用。
2. 脸 = **套件头部件整件替换**（生成器颅面，或农场出的合格 `head_*.glb` 覆盖），不是焊。
3. 团长 Path C 混元全身 normalize-only 只作 LOOK 参考，不进量产包。
4. **禁止** soft COLLAPSE 混元开壳。

Retopo 实验：
```bash
blender -b -P tools/models/retopo_farm_hunyuan.py -- \
  tools/models/board_parts/farm_inbox/hy_leader_m.glb \
  project/assets/models/board/farm_cast/leader_m.glb 5500
```
