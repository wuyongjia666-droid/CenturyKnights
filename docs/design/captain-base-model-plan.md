# 团长棋子：农场全身 → 混元全身 → 进棋盘（主线）

> **2026-10-16 硬教训**：对混元全身做 soft COLLAPSE 到 ~38k **会碎裂**（大衣碎片、脸裂、脚碎）。不得再宣称「减面质量几乎不掉」。  
> 换头路线已弃用。碎裂 38k **已撤出** `cast_leader__board.glb`。  
> **2026-10-16 用户裁定**：不减面——原混元全身仅做高度/朝向归一化进棋盘。

---

## 0. 原则
1. 全身一次成型；禁止换头当主线。
2. **禁止**对混元开壳网格做激进 COLLAPSE 当棋盘档（尤其 &lt;100k）。soft COLLAPSE ~140k 近景仍裂，亦不可当「过关」。
3. 脸近景必须对照源模 `face_src`；裂则 **不得宣称过关**。
4. 大衣冷灰；A-pose。
5. **团长当前路径 = 全三角 normalize-only**（见下），不是 soft reduce。

## 1. 当前交付（Path C：不减面 normalize-only）

| 项 | 路径 | 说明 |
|---|---|---|
| 源 | `.../hunyuan_fullbody/captain_farm_front_fullbody.glb` | ~1.5M tris |
| **棋盘 GLB** | `project/assets/models/units/cast_leader__board.glb` | **~1.499M tris / ~75MB**；仅高度≈1.85m、脚底 z=0、脸朝 −Y；**零 COLLAPSE/DECIMATE/remesh** |
| 审图 | `.../hunyuan_fullbody/board_ready_noreduce/` | SELF_REVIEW / face 对比 / figure_* |
| 脚本 | `tools/models/normalize_hunyuan_fullbody_board.py` | normalize + export + render |
| 旧减面脚本 | `tools/models/reduce_hunyuan_fullbody_board.py` | **勿再用于团长棋盘交付**；仅实验/高 LOD 参考 |
| 重拓扑尝试 | `tools/models/remesh_bake_hunyuan_board.py` | Path B 试过，未干净 |

### QA（executor 目视 Read 后）
- 全身连贯：**PASS**
- 脸对照源模：**PASS（parity）**；发际暗缝为源模自带
- 大衣非碎片：**PASS**
- 运行时过重：已知；后续若要减面必须 **重拓扑/烘贴**，禁止 soft COLLAPSE

## 2. 归档
- 38k soft COLLAPSE：失败，已撤。
- ~140k soft COLLAPSE 临时件：近景仍裂，已由全三角件替换。
- 换头 v2–v5：实验归档。

---

## 3. 量产路径锁定（2026-10-16 用户裁定）

**团长 Path C（混元全身 normalize-only）是特例 LOOK 参考，不是量产管线。**

默认量产 = **Opus #299 模块化**（见 `docs/design/pawn-redesign-opus.md` §5 / §6）：

| 角色类型 | 身体 | 脸 | 服装/武器 | 混元云端 |
|---|---|---|---|---|
| 杂兵 / 多数首领 | 通用身 m/f/heavy | **共享脸库**（可复用） | 职业/主题壳 | **不用** |
| 主角团 / 关键 BOSS | 通用身 | 立绘同源独特脸（本机/农场出，接到通用身） | 职业壳 + 专属件 | 仅关键角色或底模需要时 |
| 团长（已过关） | Path C 全三角 `__board` 可作对照；量产棋盘仍优先 Opus 套件 | 立绘/混元脸作 LOOK | Opus `outfit_captain` | 已出全身，**不再为每人复跑** |

硬规则：
1. **禁止**对混元开壳网格做 soft COLLAPSE 进棋盘。
2. 用户**不想**每次上云端混元出模；量产不得要求「每角色混元全身」。
3. 减面若需要：只走重拓扑/烘贴，且须过目过关。
4. 接头翻车时：修本机接脸流程，不回退「每人混元全身」。
