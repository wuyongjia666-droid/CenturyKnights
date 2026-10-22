# Y1-A 手游审计清单（2026-10）

> 分支：`fix/y1a-mobile-audit` · 基线 `main` @ `ffd2b365`  
> 范围：**只审计**（+ 一处立绘门闩小修）。未真机验收。不合 main，等你说合。  
> 用户口径：端游/Windows **有图**，手游缺或不一致；战棋难选中、操作不便。

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

---

## 1. 战棋触控

### 1.1 相关实现路径

| 角色 | 路径 |
|---|---|
| 输入 FSM / 点格 | `project/scripts/battle/battle_controller.gd`（`_gui_input` → `_apply_board_gesture` → `_click_cell`） |
| 触控手势路由 | `project/scripts/platform/input_router.gd`（`InputRouter`：`LONG_MS=480`，`_slop()`≈0.5×`hit_px`） |
| 胖指软命中 | `project/scripts/battle/battle_pick.gd`（`SOFT_R=0.62` 格） |
| 移动/攻击二次确认 | `project/scripts/battle/battle_touch_confirm.gd` + `project/scripts/battle/ui/battle_mobile_bar.gd` |
| 命中尺寸 | `project/scripts/platform/device_profile.gd`（`hit_px`，48dp） |
| 契约测试 | `project/tests/suites/battle/battle_feel_check.gd`（软点选几何 + 源码契约） |
| 3D 棋子层（不接管输入） | `project/scripts/battle/unit_layer_3d.gd`（注释：2D 板保留 input） |

### 1.2 假设根因（标假设）与优先级

| ID | 优先级 | 现象（用户） | 假设根因 | 依据 |
|---|---|---|---|---|
| T-P0-1 | **P0** | 难选中棋子 | **tap 被当成 pan**：手指微动超过 `_slop()`（手机上可达 ~22–56px）则 `moved=true`，松手只 `swallow` 不发 `tap` | `input_router.gd` `_screen_drag` / `_screen_touch` |
| T-P0-2 | **P0** | 点边格选不中 | **软命中半径偏紧**：`SOFT_R=0.62`×格边；胖指落在格缝时仍可能 miss；与 T-P0-1 叠加更糟 | `battle_pick.gd`；`battle_feel_check` 只验理想几何 |
| T-P0-3 | **P0** | 操作不便 | **二次确认 + 底栏换页**：移动/攻击先 preview，须再点「确认」；横屏时命令栏在右侧轨，与「点棋盘」视线分裂 | `battle_touch_confirm.gd`、`battle_mobile_bar.gd`、`BattlePick.focus_cell` 偏左 |
| T-P1-1 | P1 | 误触长按 | 按住 ≥480ms 变「长按看情报 / 危险区」，本意防误触结束回合，但会吞掉慢速点选 | `InputRouter.LONG_MS` |
| T-P1-2 | P1 | 缩放/平移后点偏 | `_pointer_to_cell` / `BattlePick._board_local` 依赖 `_board_pan`/`_board_zoom`；若某机型 `get_global_transform` 与安全区 inset 不一致会偏一格（**假设，需真机**） | `battle_controller.gd` `_screen_to_local` |
| T-P1-3 | P1 | 棋子「看起来」难点 | 3D/stand-in 视觉比格子小，命中仍按整格；玩家按「模型」点会偏（**假设**） | `unit_layer_3d.gd` 不参与 pick |
| T-P2-1 | P2 | 信息不够 | 血量/射程/敌我差依赖右侧信息条 + Forecast；手机横屏阶段区被压缩时可读性下降 | `forecast_panel` / `_unit_panel` 布局 |

### 1.3 建议修复顺序（触控，仅建议）

1. **P0** 调 `InputRouter`：选中单位优先时提高 tap 容忍（更大 slop，或「落点近单位则禁止升格为 pan」）。  
2. **P0** 调 `BattlePick.SOFT_R`（例如 0.85–1.0）并扩展 `battle_feel_check` 覆盖胖指偏心。  
3. **P0** 确认流：保留防误触，但预览格加大描边 + 确认键始终在拇指区；评估「拖到格松手即确认」作为可选项。  
4. **P1** 长按阈值与选中态互斥；镜头 `focus_cell` 真机标定。  
5. **P1** 安全区 / transform 对拍脚本（CI 用 `CK_FORCE_MOBILE` + 多种 viewport）。

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

#### 机制 C（低置信 / 待真机）— 布局

- `UIKit.stitch_dialogue` 按 1280×720 摆 `SpeakerPlate`；手机靠 `MobileLayout` / `widen_dialogue` 适配。若某机型裁切或缩放异常，可能「像没图」（**假设**）。优先用机制 A 解释「桌面有脸、手机剪影」。

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

---

## 3. 90 天内建议修复顺序（Y1-A）

| 周 | 主题 | 产出 |
|---|---|---|
| 1–2 | 审计收口 + 立绘机制 A 合入（本 PR 或 follow-up） | 同节点 Android/Windows 截图对比清单 |
| 3–4 | T-P0-1 / T-P0-2（slop + SOFT_R） | 每周手感包；扩展 `battle_feel_check` |
| 5–6 | T-P0-3 确认流与拇指区 | 横屏轨 + 预览描边；你真机签「不难选中」 |
| 7–8 | 剧情立绘扫尾（机制 A 后仍剪影的节点） | 按章缺图表（只列数据能证明的 speaker） |
| 9–10 | 枢纽安全区 / 对话板布局（机制 C） | 截图闸 |
| 11–13 | Y1-A 签收包 | 你签字后才开内容季 #1 |

**不做（本阶段）**：H/I 砍库压画质；29 职 Path C 全量；Steam；合 main 未经你点头。

---

## 4. P0 条目汇总

触控 P0：`T-P0-1`、`T-P0-2`、`T-P0-3`（3）  
立绘 P0：机制 A（1）  

**合计 P0 = 4**

优先改的三个文件（建议下一刀）：

1. `project/scripts/platform/input_router.gd` — tap/pan 升格  
2. `project/scripts/battle/battle_pick.gd` — `SOFT_R` / 软命中  
3. `project/scripts/art/unit_art.gd` — `dialogue_portrait`（本 PR 已动）

（确认流则跟 `battle_touch_confirm.gd` / `battle_mobile_bar.gd`。）
