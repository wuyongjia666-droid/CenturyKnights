# 团长棋子：农场全身 → 混元全身 → 进棋盘（主线）

> **2026-10-16 硬教训**：对混元全身做 soft COLLAPSE 到 ~38k **会碎裂**（大衣碎片、脸裂、脚碎）。不得再宣称「减面质量几乎不掉」。  
> 换头路线已弃用。碎裂 38k **已撤出** `cast_leader__board.glb`。

---

## 0. 原则
1. 全身一次成型；禁止换头当主线。
2. **禁止**对混元开壳网格做激进 COLLAPSE 当棋盘档（尤其 &lt;100k）。
3. 脸近景必须对照源模 `face_src`；裂则 **不得宣称过关**。
4. 大衣冷灰；A-pose。

## 1. 当前交付（临时 Path A，**未过关**）

| 项 | 路径 | 说明 |
|---|---|---|
| 源 | `.../hunyuan_fullbody/captain_farm_front_fullbody.glb` | ~1.5M |
| **棋盘 GLB（临时）** | `project/assets/models/units/cast_leader__board.glb` | **~140k**，原 UV/albedo；**脸近景仍裂，NO PASS** |
| 审图 | `.../hunyuan_fullbody/board_ready_v2/` | 含 SELF_REVIEW / face 对比 |
| 减面脚本 | `tools/models/reduce_hunyuan_fullbody_board.py` | 仅用于较高 LOD；勿再压到 38k 当交付 |
| 重拓扑尝试 | `tools/models/remesh_bake_hunyuan_board.py` | Path B 试过，未干净 |

### 目标（尚未达到）
- Success = 全身连贯、脸对照源模可读、大衣非碎片。
- 优选：体素/四边重拓扑 + 从高模烘 albedo/normal，再压到可用面数且不裂。

## 2. 归档
- 38k soft COLLAPSE：失败，已撤。
- 换头 v2–v5：实验归档。
