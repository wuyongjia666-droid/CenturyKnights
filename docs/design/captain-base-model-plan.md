# 团长棋子：全身参考 → 混元全身出模（主线锁定）

> 状态：**主线改回全身出模**（2026-10-16）。换头接到 `cast_leader` 的路因头身/外壳不匹配被否；半身混元脸曾获认可，但拼身失败。  
> 新主线：农场 Qwen 出**全身 A-pose 参考**（立绘锁脸）→ 混元云端**全身**图生 3D → Blender 修模进 Godot。  
> 农场参考批次：`/workspace/board_figure_p1_review/captain_v2/farm_fullbody_ref/`（见该目录 `FARM_STATUS.md`）。

---

## 0. 原则
1. **全身几何一次成型**：比例、大衣、手脚在同一份混元网格上解决；禁止再用「小头接大身」当主线。
2. **脸必须是立绘同人**：参考图用 `v8_hero_leader_m`；农场图生带 identity ref。
3. **大衣冷灰**（#586070–#707888），禁止霜白/冰甲乱涂当团长正装。
4. **A-pose、手离脸**；武器可后加模块，参考图空手。
5. 旧换头试点（attached_v2–v5）仅作实验归档，不再继续迭代 NeckPlug/毁领抛光。

## 0.1 农场全身参考（当前阻塞点）

| 项 | 值 |
|---|---|
| 批次目录 | `/workspace/board_figure_p1_review/captain_v2/farm_fullbody_ref/` |
| 生成脚本 | `tools/farm_v87/gen_captain_fullbody_qwen.py` |
| 端口 | Qwen Comfy `192.168.9.244:8322`（须在 **m173** 提交） |
| jobs | front / 34° / side / back + turnaround sheet |
| 本机探测 | `bash tools/farm_queue/probe_farm.sh` → 2026-10-16 为 **UNREACHABLE** |

再生 jobs（不需农场在线）：
```bash
python3 tools/farm_v87/gen_captain_fullbody_qwen.py \
  /workspace/board_figure_p1_review/captain_v2/farm_fullbody_ref
```
出图（m173）：
```powershell
powershell -File tools/farm_v87/farm.ps1 submit <batchDir>
powershell -File tools/farm_v87/farm.ps1 watch  <batchDir>
```

父代理在农场出图就绪后，用浏览器走混元云端全身生成（本执行器无浏览器）。

## 1. 混元全身出模（云端，父代理）
1. 输入：农场精选 `captain_fullbody_front`（优先）+ 可选 34/side 多视图。
2. 参数参考 `tools/farm_queue/farm06_hunyuan_smoke.json`（steps 50, cfg 8, octree 512）；云端 UI 对齐同级。
3. 导出 GLB → `/workspace/board_figure_p1_review/captain_v2/hy_fullbody/`。
4. 验收：头身约 7–7.5 头；冷灰大衣；手不挡脸；与立绘同人。

## 2. Blender → Godot
- `rig_mesh_v87.py` 归一 + 绑骨；棋盘 LOD collapse（禁止 150万→1万一次砸脸）。
- 输出 `cast_leader__board.glb` / 演出 LOD；替换时保留用户已认可的脸质。

## 3. 归档：换头实验（不要再主推）
- attached_v2：混元半身头 ~38k + cast_leader，脸曾获「可以」。
- v3：抛光毁模（NeckPlug/抬领）— 已回滚。
- v4/v5：安全冷灰 + 头×1.60 — 仍难解决「身体外壳≠立绘」；故改全身出模。

---


---
## 附录：上一版全文已由「全身出模」主线替代
上一版模块化换头长文见 git 历史 `fe0c42cc`/`ef823d61` 时代的同路径文件。
