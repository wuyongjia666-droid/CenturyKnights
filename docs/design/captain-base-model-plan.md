# 团长棋子：农场全身参考 → 混元全身 → 软减面（主线）

> 状态：**主线锁定全身出模**（2026-10-16）。换头接到 `cast_leader` 因头身/外壳不匹配已弃用。  
> 主线：农场 Qwen **全身 A-pose 参考**（立绘锁脸）→ 混元云端 **全身** 图生 3D → Blender **软多步减面**（保 UV/albedo）→ Godot `cast_leader__board.glb`。

---

## 0. 原则
1. **全身几何一次成型**：比例、大衣、手脚同一份混元网格；禁止「小头接大身」当主线。
2. **脸必须是立绘同人**：参考用 `v8_hero_leader_m` / 农场 front；减面后近景若裂脸则 **不得宣称过关**。
3. **大衣冷灰**（#586070–#707888），禁止霜白/冰甲乱涂。
4. **A-pose、手离脸**；武器可后加模块。
5. 换头试点（attached_v2–v5）仅归档；禁止 NeckPlug / 炸领 / 一次 150万→1万砸脸。

## 1. 已落地资产（PR #310）

| 项 | 路径 | 说明 |
|---|---|---|
| 混元全身源 | `/workspace/board_figure_p1_review/captain_v2/hunyuan_fullbody/captain_farm_front_fullbody.glb` | ~1.5M tris，农场 front 出模 |
| 农场参考 | `.../farm_fullbody_ref/out/front.png` 等 | Qwen :8322 |
| LOD0 | `.../hunyuan_fullbody/board_ready/cast_leader_fullbody_lod0.glb` | ~140k，保 UV，4k 贴图 |
| 棋盘 GLB | `project/assets/models/units/cast_leader__board.glb` | **~38k** tris，2k 贴图，高 ~1.85m |
| 减面脚本 | `tools/models/reduce_hunyuan_fullbody_board.py` | 多步 COLLAPSE，禁 one-shot |
| 审图 | `.../board_ready/` | front / 35° / face / vs farm |

### 棋盘档目标
- **Board：35–40k**（当前 38k）软多步，保 UV+albedo。
- **LOD0：~120–160k**（当前 140k）演出/近景备用。

### 已知缺口（诚实）
- 38k 近景脸相对源模有 **减面裂纹/折面**；全身剪影与腿脚完整。脸过关需：护脸加权/重拓扑，或提高近景 LOD，勿再砸面。

## 2. 减面流程（可复现）
```bash
blender --background --python tools/models/reduce_hunyuan_fullbody_board.py -- \
  --src /workspace/board_figure_p1_review/captain_v2/hunyuan_fullbody/captain_farm_front_fullbody.glb \
  --out-board project/assets/models/units/cast_leader__board.glb \
  --out-lod0 /workspace/board_figure_p1_review/captain_v2/hunyuan_fullbody/board_ready/cast_leader_fullbody_lod0.glb \
  --render-dir /workspace/board_figure_p1_review/captain_v2/hunyuan_fullbody/board_ready \
  --lod0-tris 140000 --board-tris 38000 --height 1.85 --tex-board 2048
```

## 3. 归档：换头实验（不要再主推）
- attached_v2：混元半身头曾获认可脸。
- v3：NeckPlug/抬领毁模 — 已回滚。
- v4/v5：安全冷灰 + 头×1.60 — 仍难解外壳≠立绘 → **改全身出模**。

## 4. 农场全身参考（辅助）
| 项 | 值 |
|---|---|
| 批次 | `/workspace/board_figure_p1_review/captain_v2/farm_fullbody_ref/` |
| 脚本 | `tools/farm_v87/gen_captain_fullbody_qwen.py` |
| 提交 | m173 + `farm.ps1 submit/watch` |

---
上一版换头长文见 git 历史（`fe0c42cc` / `ef823d61` 时代同路径）。
