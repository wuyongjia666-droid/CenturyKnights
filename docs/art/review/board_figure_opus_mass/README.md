# Opus 量产样板（2026-10-16）

默认量产 = 通用身 + 共享/独特脸 + 职业壳  
（`docs/design/pawn-redesign-opus.md` §5，`docs/design/captain-base-model-plan.md` §3）

本批**未**跑混元云端；**未** soft COLLAPSE。

| 图 | 内容 | 目视 QA（executor Read） |
|---|---|---|
| `01_generic_body_m.png` | 套件 `body_m` | **PASS** — 干净模块化男身，无头桩待接头 |
| `02_shared_grunt_face_head_m.png` | `head_m.glb` 近景 | **FAIL** — 有机头覆盖件开壳/脸塌，不可当共享脸过关 |
| `03_shared_grunt_on_generic_body.png` | `compose_bandit_weak` 整模 | **PARTIAL** — 兜帽杂兵剪影可读，脸在帽影里；作「共享脸角色」占位，非精修脸 |
| `03b_kit_assemble_grunt.png` | `body_m`+`head_m`+发+山贼壳 | **FAIL** — 同 `head_m` 问题，接头未过关 |
| `04_captain_face_on_generic_body.png` | 左 `compose_captain` / 右 `body_m` 对照 | **PARTIAL** — 只证明量产身 vs 团长 LOOK 捐赠件并置；**尚未**把团长脸焊到通用身上 |
| `05_captain_face_closeup_on_body.png` | `compose_captain` 头近景（Blender 粘土） | **FAIL** — Cycles 粘土下脸不可辨；Godot 卡 `board_figure_p1/cards/captain.png` 更可读，接脸流程仍待修 |

## 结论（诚实）
- 通用身路径可用，可铺职业壳。
- **共享脸 / 团长脸接到通用身** 尚未过关：`head_m` 与 compose 头切片在本机预览里不可用。
- 下一步（P1 收尾→P2）：重修 `head_m`（或不用坏覆盖、走生成器颅面），做颈部焊点；再 P2 姿态/武器。

生成：`blender --background --python tools/models/preview_opus_mass_sample.py`
