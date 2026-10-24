# Y1-A 手游审计清单（2026-10）

> 分支：`fix/y1a-mech-c-dialogue-hub-layout` · 基线 `main`（含 #331–#338）  
> 范围：机制 C 枢纽安全区 / 对话板布局。合入纪律（2026-10-24）：Y1-A / hub-mobile CI 全绿由 playforge 自合；体验项仍待真机签收。  
> 用户口径：端游/Windows **有图**，手游缺或不一致；战棋难选中、操作不便。全权推进，但 **不要让用户上手玩**。
>
> ### 落地状态（2026-10-23）
> | 项 | 状态 |
> |---|---|
> | 立绘机制 A（`dialogue_portrait` large 门闩） | **DONE**（#331） |
> | T-P0-1 更大 slop + sticky 近单位 | **DONE**（#331） |
> | T-P0-2 `SOFT_R=0.90` + 偏心测试 | **DONE**（#331） |
> | T-P0-3 预览加粗 + 拇指确认区 + 拖到格松手确认（默认开） | **DONE**（#331） |
> | 立绘运行时 medium 加载测试 | **DONE**（#332） |
> | T-P1-1 选中时提高长按门槛（`LONG_MS_SELECTED=900`） | **DONE**（#333 线） |
> | T-P1-2 pan/zoom→格纯数学契约 | **DONE**（#333） |
> | T-P1-2 真实安全区 + 镜头变换 | **DONE**（#334）：修安全区坐标被算两次；设备 `get_display_safe_area` 真机仍待签收 |
> | T-P1-3 3D 视觉命中（视觉偏置） | **DONE**（#348）：空格点脸/头 → 吸回下方单位；`visual_bias_unit_pos` + `battle_feel_check` |
> | T-P1-4 拖移落格精确指格 | **DONE**（#349）：移动/落子用 `_pointer_to_cell`；攻击仍 soft；离合法格清幽灵；`drag_move_cell` / `drag_land_cell` |
> | 立绘 exists/resolve medium 回落（机制 A 根因） | **DONE（#350）**：`CKArtPaths.resolve` 在 portraits 路径上 large 被 exclude 时落到 `.medium.webp`；`android_tier_pack_check` |
> | 剧情立绘端游↔手游对齐核查 | **DONE**（#335） |
> | 9 人无图农场回填（配角 4 + 反派 5） | **DONE**（#337 cast/farm 接线；#338 入库真立绘） |
> | 枢纽安全区 / 对话板布局（机制 C） | **DONE（#339）**：`SpeakerCaption` 显式宽高（钉死 ≥80px）；CastleHub 手机入口改 3 列门槛 + 瓷砖高度留白，家族「同袍」不再被 NavRail 半裁；`mobile_dialogue_hub_layout_check` |
> | 正式 APK 加速冒烟 | **PARTIAL PASS（2026-10-24）** — m173 Hyper-V/WHPX emulator-5554：安装+启动到主菜单 PASS（报告 box `ck-e2e-apk-smoke-m173-2026-10-24.md`）。**真机手感/立绘 = 待用户自玩签收**（用户 2026-10-24 明确不装、后面自己玩）；box 无加速勿长跑。 |
> | T-P2-1 Forecast / 单位信息条横屏可读 | **DONE（#341）**：字号地板 + 防挤扁契约 |
> | 枢纽 apply_mobile 扫尾（dossier/rival/inheritance 挤扁硬修） | **DONE（#345）**；真机签收仍 NEXT |
> | 真机签收「不难选中」 | **待用户自玩签收**（playforge 不代装；清单 §3） |
> | Y1-A 签收包（可勾选） | **清单** → [`y1a-acceptance-checklist-2026-10.md`](./y1a-acceptance-checklist-2026-10.md) |

---

## 0. 复现口径（安卓 vs Windows）

| 项 | Windows（桌面） | Android（发行包） |
|---|---|---|
| 导出过滤 | `export_presets.cfg` 桌面 preset：几乎不砍立绘档 | Android preset：`exclude_filter` 见 §2 |
| 血统库 bank | large + medium + small | **仅 medium**（#322；large/small 排除） |
| 表情 expressions | 三档齐全 | **去掉 large 母版**（#324；保留 `.medium` / `.small`） |
| speakers | 三档齐全 | **按 stem 排除 `speakers/<name>.webp` large**（#324） |
| hireface / hire_*_plate | 源在仓，但代码已跳过 | 导出排除（#325）；与玩家可见脸无关 |
| 输入 | 鼠标点选 / 右键取消 | `InputRouter` 触控：松手=tap，滑=pan，长按=情报 |

**建议对比步骤（同存档 / 同对话节点）**

1. Windows 与 Android 装 **同一 release tag**（或同 commit 导出）。  
2. 读同一存档，进 **同一章同一 beat**（优先 ch0 含「掌柜 / 稳婆 / 老旗手 / 石垒·荞娘」等 supporting 说话人的行）。  
3. 记录：说话人名、是否半身立绘、是否剪影、表情是否对得上桌面。  
4. 同存档进教程战 / 任意战棋：连点同一格棋子 10 次，记成功选中次数；再试「点选 → 点移动格 → 确认」全流程。  
5. **不要**用编辑器「全资源在盘」的 Android 模拟器冒充发行包——发行包才应用 `exclude_filter`。本仓可用 `tools/ci/export_size_report.py` + `android_tier_pack_check` 在 CI 侧模拟档位。

本审计 **未**在用户手机上跑；下列「根因」凡未跑发行包验证的，标为 **假设**。

### APK 冒烟环境缺口

- box 与用户机 m173 **均无 KVM / 硬件加速**；无加速 emulator 会 ANR，**禁止再开长跑**。  
- 自动化套件（触控 / 立绘门闩 / `battle_feel` / mobile shots）在 CI/本机 Godot 侧有效，**不能替代**发行 APK 手指手感。  
- **待有**：带 KVM 的 CI runner，或真机/代理设备，再跑正式 APK 冒烟。

---

## 1. 战棋触控

### 1.1 相关实现路径

| 角色 | 路径 |
|---|---|
| 输入 FSM / 点格 | `project/scripts/battle/battle_controller.gd`（`_gui_input` → `_apply_board_gesture` → `_click_cell`） |
| 触控手势路由 | `project/scripts/platform/input_router.gd`（`LONG_MS=480`，mobile `_slop()`≈0.75×`hit_px` + `sticky_fn`） |
| 胖指软命中 | `project/scripts/battle/battle_pick.gd`（`SOFT_R=0.90` 格） |
| 移动/攻击二次确认 | `project/scripts/battle/battle_touch_confirm.gd` + `project/scripts/battle/ui/battle_mobile_bar.gd` |
| 命中尺寸 | `project/scripts/platform/device_profile.gd`（`hit_px`，48dp） |
| 契约测试 | `project/tests/suites/battle/battle_feel_check.gd`（软点选几何 + 源码契约） |
| 3D 棋子层（不接管输入） | `project/scripts/battle/unit_layer_3d.gd`（注释：2D 板保留 input） |

### 1.2 假设根因（标假设）与优先级

| ID | 优先级 | 现象（用户） | 假设根因 | 依据 |
|---|---|---|---|---|
| T-P0-1 | **P0 · DONE** | 难选中棋子 | ~~tap→pan~~：mobile slop 0.75×hit（36–72）+ 近单位 sticky×1.55；微动仍发 tap | `input_router.gd` |
| T-P0-2 | **P0 · DONE** | 点边格选不中 | ~~SOFT_R=0.62~~ → **0.90**；`battle_feel_check` 覆盖偏心 0.88 格 | `battle_pick.gd` |
| T-P0-3 | **P0 · DONE** | 操作不便 | 预览描边加粗；确认键落拇指区；**拖到格松手确认**（`touch_drag_commit`，手游默认开） | `battle_touch_confirm.gd` / `battle_mobile_bar.gd` |
| T-P1-1 | **P1 · DONE** | 误触长按 | 选中单位时 `long_ms_fn` → `LONG_MS_SELECTED=900`；慢速点选仍为 tap；故意长按仍可情报 | `input_router.gd` / `battle_controller.gd` |
| T-P1-2 | **P1 · PR #334** | 缩放/平移后点偏 | ~~假设~~ **已证实并修复**：`_gui_input` 收到的是控件本地坐标，旧代码又做一次 `get_global_transform()` 逆变换；有安全区内缩时点偏一个内缩距离。现先抬回视口坐标；镜头上下限走 `BattlePick.clamp_pan / zoom_about`。`mobile_safe_area_touch_check` 真实 push_input 覆盖 | `battle_controller.gd` / `battle_pick.gd` / `mobile_chrome.gd` |
| T-P1-3 | **P1 · DONE** | 棋子「看起来」难点 | 3D 立像伸进上方一格；**视觉偏置**：手指空格 + 下方格有活单位 + 落点在立像竖向范围 → 选中下方单位（方案 1）。轮廓矩形 / 3D 射线仍不进本阶段 | `battle_pick.gd`（`visual_bias_unit_pos`） |
| T-P1-4 | **P1 · DONE** | 拖到格松手卡手 | 移动预览/松手曾走 `BattlePick.resolve`，邻单位 soft 吸走空地 → 幽灵不跟手。现 **move=精确指格**、attack=soft；离合法格/`非法松手`清幽灵 | `battle_touch_confirm.gd`（`drag_land_cell`） / `battle_pick.gd`（`drag_move_cell`） |
| T-P2-1 | **P2 · 本 PR** | 信息不够 | Forecast 桌面固定 340×132 + clip，字号被 `ensure_min_fonts` 抬到 22 后竖向挤扁；现手机：字号地板、列/面板最小尺寸、关 clip、按 `m_board_area` 安全区放置；`MobileSide` 标签最小行高；`mobile_forecast_layout_check` | `forecast_panel` / `battle_mobile_side` / `_unit_panel` |

### 1.4 T-P1-3：3D 立像的「视觉命中」（视觉偏置已落地）

**结论先说**：玩家觉得「点棋子难」，一部分原因是**按模型点，落点却按格子算**。原先假设「模型比格子小」不对——实际是**模型比格子高，并且往上伸进上方一格**。

**几何（来自代码常量，非估计）**

| 量 | 值 | 来源 |
|---|---|---|
| 立像屏幕高度 | `FIG_CELLS = 1.30` 格（正交相机，俯角 38°，已按 cos 补偿） | `unit_layer_3d.gd` |
| 脚底位置 | 本格自上而下 **0.62** 格处 | `board_units.gd · feet_px` |
| 立像竖向范围（以本格左上为原点，单位：格） | y ∈ **[−0.68, 0.62]**；头顶比本格上沿高 0.68 格 | 由上两行推出 |
| 立像宽度 | 约 0.4–0.5 格（人形） | 目测截图；横向不是问题 |
| 命中规则 | 先看手指格有无活单位 → **空格则 `visual_bias_unit_pos`（下方立像）** → 再 `SOFT_R = 0.90` | `battle_pick.gd · resolve` |

**按身体部位点下去会发生什么**（假设上方一格是空地）

| 点的位置 | 离本格中心 | 结果 |
|---|---|---|
| 脚 / 底座圈（y≈0.5–0.62） | ≤0.12 格 | 本格，命中 |
| 胸口（模型 55% 高，y≈−0.10） | ≈0.60 格 | 落在上方格，但软命中吸回本单位，**命中** |
| 脸（约模型 88% 高，y≈−0.52） | ≈1.02 格 | 超出 `SOFT_R`；**视觉偏置吸回本单位**（空指格 + 下方活单位） |
| 头顶 | ≈1.18 格 | 同上，**落空** |

- 立像竖向 **48%** 在本格内；**78%** 在软命中半径内；最上面约 22%（脸/头）原先点不中 → **现由视觉偏置覆盖**（冠上仍 miss）。
- 上方一格**有别的单位**时更糟：手指所在格有活单位优先，点到本单位的胸口/头会**选中上面那个单位**。
- 2D 棋子 / 低端机烘焙替身也是贴着格子画的，问题主要出在 3D 立像。

**落地（方案 1 · 视觉偏置）**
- T-P0 已合、m173 APK 冒烟过主菜单后，落地最低风险方案：空指格 + 下方活单位 + 落点 y ∈ [`FIG_TOP`,`FIG_FEET`]（−0.68…0.62）→ 选中下方单位。
- **不**再放大 `SOFT_R`（相邻抢点）；轮廓矩形 / 3D 射线仍搁置。
- 契约：`battle_feel_check._visual_bias`（点脸命中、SOFT_R 独测仍 miss、冠上/死单位/无下方不误吸）。

**仍可后续升级**
1. **轮廓矩形命中**：宽 ≈0.5 格 × 高 1.3 格；重叠取更「前」脚底。
2. **3D 射线拾取**：成本高，手机 15Hz 层不建议优先。

**真机签收**：按 §0 第 4 步，底座与脸各点 10 次记成功率（清单 §3.1）。

### 1.3 修复顺序

1. ~~**P0** InputRouter slop / sticky~~ → **DONE**  
2. ~~**P0** SOFT_R + battle_feel_check~~ → **DONE**  
3. ~~**P0** 确认流预览 / 拇指区 / 拖松手确认~~ → **DONE**  
4. ~~**P1** 长按阈值与选中态互斥~~ → **DONE**（`LONG_MS_SELECTED`）  
5. ~~**P1** pan/zoom→格纯契约~~ → **DONE**（#334）；真机安全区对拍仍 NEXT。  
6. ~~**P1** T-P1-3 视觉偏置~~ → **DONE**（#348）。  
7. ~~**P1** T-P1-4 拖移落格精确指格~~ → **DONE**（#349）。
7b. ~~立绘 exists/resolve medium 回落~~ → **DONE（#350）**。  
8. ~~正式 APK 冒烟~~ → **PARTIAL**（m173 Hyper-V 主菜单 PASS）；**待用户自玩签收**（不代装真机）。
9. **代码刀空跑结论（2026-10-24）**：搁置项以外、不依赖真机装包的 Y1-A 可落地代码已无；下一动作只等用户自玩勾清单。

---

## 2. 立绘：导出与加载差异

### 2.1 Android `exclude_filter`（发行相关摘录）

来源：`project/export_presets.cfg` Android preset（#322 / #324 / #325）：

- `assets/art/portraits/genome/bank/*_<16hex>.webp`（large 母版）  
- `assets/art/portraits/genome/bank/*.small.webp`  
- `assets/art/portraits/expressions/*_{anger,joy,neutral,sorrow,surprise}.webp`（**large**；不匹配 `.medium`/`.small`）  
- `assets/art/portraits/speakers/<stem>.webp`（逐 stem 列出的 large）  
- `assets/art/portraits/hireface_*.webp`、`hire_*_plate.webp`（死重；代码本就不展示）  
- 另有 legacy `music_*.wav`（与立绘无关）

文档：`docs/art/export-cap-400.md`。门闩测试：`project/tests/suites/art/android_tier_pack_check.gd`。

### 2.2 加载路径

| 步骤 | 代码 |
|---|---|
| 对白入口 | `chapter_player.gd` → `_speaker_portrait` → `UnitArt.dialogue_portrait` |
| 同伴表情 | `companion_slot` → `expression_plate_path` → `_try_load(..., TIER_MEDIUM)` |
| 名册角色 | `UnitArt.portrait` → genome bank / hireuniq / bust…（`art_paths.resolve_portrait` 档位回落） |
| Supporting | `speaker_plate_path` ← `data/cast/supporting_v92.json` 的 `portrait` |
| 失败回退 | `speaker_silhouette`（纯色剪影） |

档位回落本身（`CKArtPaths.resolve_portrait`）在 **medium-only 盘**上是正确的：要 large/small 时会落到 medium。`android_tier_pack_check` 已覆盖。

### 2.3 「手游无图 / 不一致、端游有图」的具体机制

#### 机制 A（**高置信 · 本 PR 已小修**）— `dialogue_portrait` 用 large-only `exists` 当门闩

```text
dialogue_portrait:
  if _art_exists(expression_or_speaker_path):   # ← CKArtPaths.exists → 只探 large .webp
      _try_load(..., medium)
  else:
      … 落到 silhouette / 别的脸
```

- Windows：large 在包内 → `exists` 真 → 加载 medium/large → **有立绘**。  
- Android：large 被 exclude → `exists` 假 → **跳过** `_try_load`（哪怕 `.medium.webp` 仍在包内）→ supporting 说话人变 **剪影**；有 `who` 的同伴可能落到 token/bank 脸 → **与桌面表情板不一致**。  

磁盘核对（本仓 `ffd2b365`）：`speakers/` 25 stem **均有** medium；`expressions/` 无「仅有 large、无 medium」的 stem。问题不在缺 medium 文件，而在 **门闩不认 medium**。

ch0 / era1_01 对话里命中 supporting 路线的说话人（数据枚举，非臆造角色名）包括：  
`掌柜`、`稳婆`、`老旗手`、`老管事`、`石垒·晚担`、`石垒·荞娘`、`渡口·把头`、`春令使者`、`盟友亲属`、`活口`、`新来的人`、`槐里·景伯`、`槐里·青禾`、`鸦渡·衡舟` 等。

#### 机制 B（中置信）— 导出与桌面档位不同导致「观感不一致」

- bank / 表情在 Android 最高只到 medium：半身仍应清晰，但比 Windows large 略软（**质量差一档，不是空白**）。  
- `hireface` 排除 **不是** 缺图原因（`UnitArt.portrait` 已强制 `ft = null`）。

#### 机制 C（本 PR 落地）— 布局

- 证据（headless `layout.json`）：`phone_20x9_nonotch` / `tablet_4x3` 下 `SpeakerPlate` 内 Label **width≈1px + clipped**；`castle_family` 下 `Locked_bonds`「同袍」被 NavRail 半裁。
- 修复：`SpeakerCaption` 显式 `size`/`custom_minimum_size`（≥80），`widen_dialogue` / sync 调用 `layout_speaker_caption`；CastleHub `_m_entry_grid` 列宽门槛 320→272（1600 根宽走 3 列）+ 瓷砖高度多留 6px，末行不再贴齐裁切。
- 真机观感仍 **待签收**；自动化见 `mobile_dialogue_hub_layout_check`。

#### 机制 D（数据缺口，两端一致）

- `supporting_v92.json` 中 4 人无 `portrait` 路径（`tengqiao_xinyu`、`dukou_ahe`、`jinghu_hutie`、`lengyao_shouhuo`）— **桌面同样无板**，不是 Android 专有。

### 2.4 验证步骤（立绘）

1. 发行 APK 与 Windows 同 commit。  
2. ch0 找到「掌柜」或「稳婆」台词：Android 修前应剪影、修后应半身；Windows 始终半身。  
3. 同伴「苇原·灯影」：c01 在 `EXPR_RESHOOT` 上，两端都走 token 脸（刻意）；「白垣·折杆」等应走表情板，修后 Android 应与 Windows 同档 medium。  
4. CI：`android_tier_pack_check` + 本 PR 增加的 `dialogue_portrait` 门闩契约。

### 2.5 本 PR 小修（非大改）

- 文件：`project/scripts/art/unit_art.gd` · `dialogue_portrait`  
- 改动：去掉对 `_art_exists(path)` / `_art_exists(sp_path)` 的 large 门闩，直接 `_try_load(..., TIER_MEDIUM)`（内部已 `resolve_portrait`）。  
- 回归：`android_tier_pack_check.gd` 增加源码契约，防止门闩回潮。
- **根因加固（本 PR）**：`CKArtPaths.resolve`/`exists`/`load_texture` 对 `/portraits/` 路径在 large 缺失或被 `pack_excluded` 时回落到 medium/small，避免其它仍走 `exists()` 门闩的调用点在 Android 上假阴性。

---

## 3. 90 天内建议修复顺序（Y1-A）

| 周 | 主题 | 产出 |
|---|---|---|
| 1–2 | 审计 + 机制 A + 触控 P0（本 PR #331） | **DONE（代码）**；真机对比仍 **NEXT** |
| 3–4 | 每周手感包给你验 T-P0 | **NEXT（需用户真机）** |
| 5–6 | T-P1 长按 / pan-zoom 契约 + 真实安全区 | **DONE（代码）**：#333 + PR #334；真机签收仍 **NEXT** |
| 7–8 | 剧情立绘扫尾（机制 A 后仍剪影的节点） | **DONE**（#335 核查；#337/#338 九人入库） |
| 9–10 | 枢纽安全区 / 对话板布局（机制 C） | **DONE（#339+#345 等）**；真机签收仍 NEXT |
| 11–13 | Y1-A 签收包 | **清单已写** → [`y1a-acceptance-checklist-2026-10.md`](./y1a-acceptance-checklist-2026-10.md)；真机勾完才开内容季 #1 |

**不做（本阶段）**：H/I 砍库压画质；29 职 Path C 全量；Steam；花钱 / force-push。Y1-A·hub-mobile CI 绿由 playforge 自合。

---

## 4. P0 条目汇总

触控 P0：`T-P0-1`、`T-P0-2`、`T-P0-3` → **全部 DONE（本 PR）**  
立绘 P0：机制 A → **DONE**  

**合计 P0 = 4 / 4 代码侧完成**；真机签收仍开放。

下一刀：

1. **APK 冒烟**：待有 KVM 或真机代理（本环境勿再开无加速 emulator）  
2. ~~安全区 / `get_global_transform` 对拍~~ → **DONE** #334（真机只需确认设备返回的安全区）  
3. ~~对话板手机布局（机制 C）~~ → **本 PR**  
4. 枢纽 apply_mobile 代码侧扫尾 + T-P1 + 立绘 medium 回落均已合；**待用户自玩签收**：按 [`y1a-acceptance-checklist-2026-10.md`](./y1a-acceptance-checklist-2026-10.md) 勾完后才开内容季（playforge 不代装）
