# Opus 量产样板（2026-10-16 夜）

配方：`docs/design/board-figure-mass-recipe.md`

- **未**跑混元云端；**未** soft COLLAPSE；**未**接头焊身。
- `head_m` = 生成器颅面（`planes`，982 tris）。有机塌脸 `head_m`/`head_f` 已迁入 `board_parts/_qa_fail/`。

| 图 | 内容 | 目视 QA（executor Read） |
|---|---|---|
| `01_generic_body_m.png` | 套件 `body_m` | **PASS** — 干净模块化男身，颈桩待插头部件 |
| `02_shared_grunt_face_head_m.png` | 生成器 `head_m` 近景 | **PASS** — 眉/鼻/眼窝/嘴可读的硬面共享脸（非写实） |
| `03_shared_grunt_on_generic_body.png` | body+head+hair+山贼壳+club | **PASS** — 量产剪影可读；发 LOD 有锯齿缝（已知，不挡样板） |
| `03b_kit_assemble_grunt.png` | 同上头近景 | **PASS** — 共享脸在组装上可读 |
| `04_captain_kit_on_generic_body.png` | body+head+captain壳+sword | **PASS（壳）** — 团长量产壳成立；头仍是共享颅面（独特脸=整件换 `head_*`，不焊） |
| `05_captain_kit_face_closeup.png` | 上项头近景 | **PASS** — 同共享颅面近景 |
| `06_compose_bandit_weak_look.png` | t1 有机 compose LOOK | **LOOK** — 对照用，非量产焊身路径 |

## 结论
- 量产配方可演示：通用身 + 共享生成器头 + 职业壳。
- 团长独特脸下一步：农场/本机出合格 `head_captain.glb`（或角色专用 stem）**整件替换**，禁止再走混元头焊身。
- Godot 卡：`docs/art/review/board_figure_p1/cards/`；Path C LOOK：`.../hunyuan_noreduce/`。

生成：`blender --background --python tools/models/preview_opus_mass_sample.py`
