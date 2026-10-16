# 团长棋子：通用身体 + 换头 + 职业外壳（模块化锁定）

> 状态：**已锁定**（2026-10-16，用户确认）。  
> 不再为每个人做全身；身体几套通用，脸按立绘每人一份，职业靠外套/武器辨识。  
> 团长混元云端半身（`captain_v8_hero_leader_hunyuan_v31`）用户已认可「看着很像」，本轮把它的**头**接到现有 `cast_leader` 通用男身上做棋盘件验证。

对照输出：`/workspace/board_figure_p1_review/captain_v2/`（本轮实装在 `attached/`）。

---

## 0. 锁定原则（2026-10-16）

1. **通用身体池**：男/女各若干身高体型档（先复用现有 `cast_*` / `outfit_*_t1_*`），**不是**一人一身。
2. **每人一张脸**：立绘忠实的头（几何+贴图都来自出模/修模，禁止把立绘脸平贴成面具）。
3. **职业辨识靠外壳 + 武器**：灰大衣/剑 = 团长；弓 = 猎手；斧 = 山贼……棋盘距离一眼能分职业。
4. **验收**  
   - 脸：能认出是立绘里那个人（中近景可读）。  
   - 手不挡脸。  
   - 武器/外套在棋盘俯视/斜视下可辨职业。
5. 旧「整身重做混元」方案（本文 v2 §2–§8）降为**可选补强**；主线改走模块化。PR #301 kit 拼装思路可复用职业武器槽，但脸必须是立绘忠实头，不是 kit 通用头。

## 0.1 职业辨识（外壳 + 武器轮廓）

棋盘距离脸不可读细节，**必须**靠：
1. **外套色/形**与立绘一致（团长 = 冷灰大衣，禁止霜白）；
2. **武器轮廓加粗**到棋盘俯视可辨（剑/弓/斧 silhouette）。

抛光脚本：`tools/models/polish_captain_board.py`（**仅**冷灰 albedo remap + 轻微剑加粗；**不改**已验收脸 UV/面数）。

> **v3 翻车记录**：曾用抬领删面/NeckPlug/剑连乘毁模；已回滚到 fe0c42cc（attached_v2）再安全抛光。禁止再对身体做破坏性几何「修复」。

## 1. 模块拆分

| 模块 | 内容 | 来源（团长试点） |
|---|---|---|
| Body | 躯干+四肢+现成领/衣底 | `cast_leader` / `cast_leader__board`（去原头） |
| Head | 颈切干净的头+发 | 混元云端 bust → 颈切 → 减面 ~8–15k tris |
| Outfit shell | 外套/肩甲等可换外壳 | 暂用身体自带灰大衣；后续可换 `outfit_*` |
| Weapon | 剑/弓/斧… | 身体自带 `Weapon` 或 `board_figures.json` 的 weapon_* |

运行时加载：`UnitModel.instantiate(..., board=true)` 已优先 `cast_<key>__board.glb`；团长无需改 GD 即可吃到新头。

## 1.1 头面数预算（2026-10-16 修正）

| LOD | 用途 | 目标 tris | 做法 |
|---|---|---|---|
| LOD0 | 演出/特写对照 | **80k–150k**（现 ~120k） | 颈切后软减，**保留混元 UV/贴图** |
| Board | 棋盘 `__board.glb` | **25k–40k**（现 ~38k） | 从 LOD0 **分步** collapse，禁止 150万→1万一次砸 |
| 失败教训 | v1 | ~12k | 碎脸；已废弃 |

对照目录：`board_figure_p1_review/captain_v2/attached_v2/`。

## 2. 团长试点流程（已跑）

1. 混元云端图生 3D（半身，用户认可脸）。资产：  
   `board_figure_p1_review/captain_v2/hunyuan_cloud/captain_v8_hero_leader_hunyuan_v31.glb`
2. Blender 脚本 `tools/models/attach_hunyuan_head_to_leader.py`：  
   - 在脖子最细处 bisect 切头（约 bust 局部 z=0.60）  
   - 减面到 ~12k tris，贴图压到 1024²  
   - 删掉 `cast_leader` 原头（颈骨以上）  
   - 对齐 head 骨，整头权重绑 `head`  
   - 保留 `Weapon` 剑
3. 导出棋盘件：`project/assets/models/units/cast_leader__board.glb`  
   审查副本与渲染：`board_figure_p1_review/captain_v2/attached/`

## 3. 验收清单（诚实判定）

| # | 项 | 本轮 |
|---|---|---|
| 1 | 中景脸能认出是立绘同人 | 部分过：全身/35°可读；极近景减面裂纹明显 |
| 2 | 手不挡脸 | 过：手在身前持剑，离开脸 |
| 3 | 剑/大衣能辨职业 | 部分过：剑细长可读；大衣现为 cast_leader 霜白漆，不是立绘冷灰——外壳换色/换壳待下一轮 |
| 4 | 颈缝不崩 | 部分过：有接缝，高领遮一部分 |
| 5 | 棋盘 1280×720 可辨 | 见 `attached/desktop_after_1280x720.png`（若有）|

**不过就写不过**：极近景头发/额有碎面；头略偏大；身体材质仍是旧霜白，不是立绘灰大衣。

## 4. 下一步（未做）

- 通用身体池定档（男标准/男壮/女标准…）与头颈接口规范（颈半径、朝向 -Y、头骨空间）。  
- 职业外壳：灰大衣真正几何或至少 plate_palette 冷灰；武器 silhouette 加粗方便棋盘辨认。  
- 头：重拓扑或 voxel+bake，消裂纹；可选更高 LOD 演出件。  
- 其余角色：同一套「出头 → 接到对应性别身体 → 套职业壳」。

## 5. 资产与工具路径

| 用途 | 路径 |
|---|---|
| 立绘真值 | `project/assets/art/portraits/v8_hero_leader_m.webp` |
| 混元半身源 | `/workspace/board_figure_p1_review/captain_v2/hunyuan_cloud/captain_v8_hero_leader_hunyuan_v31.glb` |
| 换头脚本 | `tools/models/attach_hunyuan_head_to_leader.py` |
| 棋盘 GLB | `project/assets/models/units/cast_leader__board.glb` |
| 审查图 | `/workspace/board_figure_p1_review/captain_v2/attached/` |
| Godot 加载 | `UnitModel` → `cast_leader__board.glb`；`CKBoardFigure` |

## 6. 附录：旧 v2「整身重做」摘要

旧方案要求概念三视图 → 本地混元全身 → Blender 重拓扑/雕脸/换手/绑骨 → LOD。在用户改为「通用身+换头」后，**不再作为团长主线**；若某角色没有可用身体档，再回退旧流程只补身体档，不一人一身。
