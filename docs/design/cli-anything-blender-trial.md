# CLI-Anything Blender 试用接入（科技日报 10-15）

> 状态：本机试用完成（2026-10-15）。**不替换** Hunyuan GLB → Blender 后处理 → Godot 主路径；接到 BMAD/BMGD 做实现与验收辅助。未动 AIComics。

## 1. 本机已装

| 项 | 位置 / 命令 |
|---|---|
| Python venv | `/workspace/cli-anything-venv` |
| Hub | `cli-anything-hub` 0.4.1 → `cli-hub` |
| Blender harness | `cli-anything-blender`（`cli-hub install blender`） |
| Godot harness | `cli-anything-godot`（`cli-hub install godot`） |
| 系统 Blender | `/home/box/.local/bin/blender` **4.2.8 LTS** |
| Dry-run 证据 | `/workspace/cli-anything-trial/blender-dryrun/proof.png`（CYCLES 8spp，真实 `blender --background --python`） |

PATH 提示：`export PATH="/workspace/cli-anything-venv/bin:/home/box/.local/bin:$PATH"`

`npx skills add HKUDS/CLI-Anything` 因本机 Node 20 < skills 要求的 Node ≥22.20 失败；不影响 pip/hub 路径。

## 2. Blender harness 实际能做什么（只读结论）

**架构**：JSON 场景（`.blend-cli.json`）→ 生成 bpy 脚本 →（可选）`blender --background --python`。

**命令组**：`scene` / `object`（仅基本体 cube/sphere/…）/ `material` / `modifier`（含 subdivision、decimate、bevel、boolean、smooth 等）/ `camera` / `light` / `animation` / `render` / `preview` / `session`。

**真正驱动 bpy 的路径**：
- `preview capture` → 内部调 `blender_backend.render_scene_headless`（会调真实 Blender）。
- `render execute` → **只写** `_render_script.py` 并返回 `command` 字符串，**默认不执行** Blender；Agent 需自行 `blender --background --python <script>`（或用下方包装脚本）。

**本机已知坑（Blender 4.2）**：
- 生成脚本写 `BLENDER_EEVEE`，4.2 只认 `BLENDER_EEVEE_NEXT` → `preview capture --recipe quick` 会失败。
- 用 `CYCLES` 或 `WORKBENCH`，或运行前把脚本里的 `BLENDER_EEVEE` 替换为 `BLENDER_EEVEE_NEXT`（见 `tools/art/cli_anything_blender_run.sh`）。

**做不到（对团长底模关键）——不要指望 harness 替代现有脚本**：
- 无 GLB/glTF 导入导出命令
- 无雕刻 / 投影烘焙 / 法线烘焙 / UV
- 无 retopo 专用流（只有 decimate modifier）
- 无绑骨 / 权重
- 无「对着立绘修脸」类操作

这些仍走主路径：`tools/models/retopo_farm_hunyuan.py`、`rig_mesh_v87.py`、以及按需新写的 bpy 脚本（与现有 `tools/art/*_blender.py` 同模式：`blender --background --python script.py -- args`）。

## 3. 接到 CenturyKnights / 团长底模方案的用法（轻量）

主路径不变：`Hunyuan GLB → Blender 后处理 → Godot`（见 `docs/design/captain-base-model-plan.md` §3–5）。

| 阶段 | 用 CLI-Anything？ | 用法 |
|---|---|---|
| 概念图 / 混元出模 | 否 | 农场 Qwen/Hunyuan |
| 清理 / retopo / 脸雕 / 手换 / 衣褶 / 投影烘 / UV | **否（专用 bpy）** | 现有 + 新 bpy；Agent 用 Shell 调 `blender --background --python` |
| 对照拼板灯光/相机/快渲 | **可用** | harness 建场景灯位 + CYCLES preview；或包装脚本跑生成的 bpy |
| Godot 验收截图 / 工程检查 | **可用** | `cli-anything-godot`（project/scene/script）；不替换 `scripts/ci_godot_run.sh` |

包装脚本：`tools/art/cli_anything_blender_run.sh`  
用法：`cli-anything-blender … render execute /path/out.png --overwrite` 之后，再：

```bash
tools/art/cli_anything_blender_run.sh /path/to/_render_script.py
```

会 patch EEVEE→EEVEE_NEXT 并调用本机 Blender。

## 4. 边界（已遵守）

- 未接农场 Flux / 非 H3 视频 API
- 未改 AIComics 农场脚本、书内 skill、硬锁路径
- 不替换 BMAD/BMGD 主流程；本试用只增强 Agent 调 Blender 的操作面
- 资产主路径仍是 Hunyuan → Blender → Godot

## 5. 下一步（需用户/管线点头后再做）

1. 给团长 Blender 阶段写专用 bpy（导入混元 GLB、正交参考图、导出对照渲染），仍用 `blender --background --python`，必要时用 harness 只管灯/相机 JSON。
2. 若要长期用 `preview capture`，可给 harness 提 EEVEE_NEXT 兼容补丁，或固定 CYCLES/WORKBENCH recipe。
3. Godot harness 与 `scripts/ci_godot_run.sh` 对照做只读验收命令清单（另开小任务）。
