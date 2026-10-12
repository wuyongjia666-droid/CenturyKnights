# 手机手感 · 全面屏 · 队旗 DIY（v9.3 设计 backlog）

> 角色：UX / 表现打磨。基线：`main@8033cb0c`。  
> 来源：Android 实机试玩反馈 + 通读 `mobile_chrome` / `MobileLayout` / `BattleMobileBar` / `InputRouter` / `naming` / `UnitArt.banner` / 城堡枢纽 / 族谱 / 对白 / 城堡剪影。  
> **本文件只定稿与验收**，不改玩法公式、不改战斗规则、不合并其他设计 PR。  
> 风格锁：当代奇幻、磨砂玻璃、霜青 `#6ED4FF`、友军薄荷 `#5EE0B5`、敌军珊瑚 `#FF7A70`、墨蓝底；**禁止**中世纪做旧、羊皮纸、鎏金/黄铜、暖金 `#c9a227`。  
> 相关未决：设计稿 [#123](https://github.com/wuyongjia666-droid/CenturyKnights/pull/123)（祖辈年事入争档）仍待用户拍板，**勿合并任何设计 PR**，除非用户明示。

---

## 1. 用户问题（试玩原话 → 产品判断）

| # | 反馈 | 产品判断 | 证据（现状） |
|---|---|---|---|
| A | 手机手感差，尤其行动 / 移动 | 触控已有路由，但战术确认流仍是「点格子即生效」的桌面思维；底栏按钮挤、误触与拖移难分 | `InputRouter`（pan/pinch/tap）已在；`battle_controller._click_cell` 选中后点可达格 **立刻落子**；`BattleMobileBar` 五键横排 |
| B | 不是真全面屏 / 边到边 | 导出开了 `immersive_mode`，但运行时未主动收系统栏 / 刘海 cutout；根节点仍按 1280×720 letterbox 缩放，竖屏上下留黑边 | `export_presets.cfg` `screen/immersive_mode=true`；`MobileChrome` 只做 safe inset + `MobileLayout.fit`（`s = min(..., 1.0)`） |
| C | 队旗难看；要丰富 DIY（多色、样式、纹样）；纹章重要 | 开局只轮换 5 色；旗面是预烘焙单色布 + 6 帧飘动；无分层纹章、无堡内预览、无二次编辑 | `naming.gd` `_colors` 仅 5 项；`UnitArt.banner` → `banner_<hex>_wN.png`；`GameState.crest_color` 单字段字符串 |

次要但玩家可见：枢纽导航条在竖屏下手点费劲；城堡剪影仍是几何多边形；对白立绘 120px 在高 DPI 上偏糊；族谱 / 名录列表已有 `extend_portrait_lists`，但多数子页未声明 `apply_mobile_layout`。

---

## 2. 手机 UX（手感与全面屏）

### 2.1 目标手感

- **一点一义**：选人 / 看情报 / 确认移动 / 确认攻击 在触控上可区分，不靠右键。
- **大靶、少键**：主行动 ≥ 48dp（逻辑像素按 `DeviceProfile.hit_px()` 换算后不低于该值）；战斗底栏不超过 4 个主按钮 + 1 个溢出。
- **边到边内容、安全区内控件**：背景与棋盘可吃到刘海/圆角外缘；按钮、字幕、资源条落在 `DisplayServer.get_display_safe_area()` 内。
- **竖屏一等公民**：枢纽与对白以竖屏为默认；战术棋盘默认横屏，但竖屏可玩（底栏 + 可折叠情报轨）。

### 2.2 触控靶与行动条

| 项 | 设计 | 落点（实现时） |
|---|---|---|
| 最小触控 | 全局 `ensure_hit_targets` 下限改为 **48dp**（现 `HIT_DP = 44`）；NavRail 例外保留但行高 ≥ 40dp 且可滚动 | `device_profile.gd`、`mobile_layout.gd` |
| 战斗底栏 | 主键：**攻击 / 待命 / 取消**；「战技」与「结束回合」进溢出菜单或长按待命旁的次级槽；键宽随安全区均分，文字 16→可缩为图标+短标签 | `battle_mobile_bar.gd` |
| 枢纽导航 | 竖屏：左侧 142px 轨改为 **底部 Tab 或抽屉**（P1）；横屏保持左轨 | `castle_hub.gd` + UX 流 |
| 误触 | 底栏与棋盘之间保留 ≥ 8dp 死区；拖移 `SLOP` 从 22 调到与 DPI 挂钩（约 0.5× `hit_px`） | `input_router.gd` |

### 2.3 移动 / 攻击确认

现状：选中单位后，点可达格 **直接移动**；攻击须先按「攻击」再点敌人，但点到即结算，无二次确认。

**新交互（手机；桌面可保留单击生效，设置里可关确认）：**

1. **选中** → 高亮移动域。  
2. **点可达格** → 单位 **幽灵预览** 落到该格，底栏出现 **「确认移动」/「取消」**；未确认前可改点其他格。  
3. **确认移动** 后进入行动阶段；可点「攻击」进入攻击域，或「待命」结束。  
4. **攻击**：点敌人 → 预报面板置顶（命中 / 伤域 / 标签）+ **「确认攻击」**；确认后才 `_do_attack`。  
5. **长按** 仍只看情报（单位 / 地形），永不落子。  
6. 撤销：移动确认前免费改点；确认后仍走现有灯盏回溯（若已解锁），不另造系统。

验收口径见 §5 P0-BTL。

### 2.4 平移 / 缩放

已有：`InputRouter` 单指 pan、双指 pinch、滚轮 zoom；`_clamp_board_pan` / `_zoom_board_at`。

补强：

- 默认缩放：开局或换图时，棋盘 **完整入画**（含安全区），再允许捏合 0.75×–2.0×。  
- 选中单位时，若单位在底栏或刘海遮挡带，**轻推 pan** 使其露出（不做强硬跟镜）。  
- 捏合中心以双指中点为准（已有）；避免缩放时整板跳动（检查 `_board_pan` 与 `mobile_origin` 叠加）。  
- 舆图 `atlas_view` 复用同一路由参数，SLOP/惯性一致（P1）。

### 2.5 安全区 · 刘海 · 沉浸式全面屏

| 层 | 要求 |
|---|---|
| Android 系统 UI | 保持/核实 `screen/immersive_mode=true`；必要时在导出模板或插件层设置 `SYSTEM_UI_FLAG_LAYOUT_STABLE \| LAYOUT_FULLSCREEN \| LAYOUT_HIDE_NAVIGATION`（或 Android 11+ `WindowInsetsController` 等价），并 `layoutInDisplayCutoutMode=shortEdges`，让内容画进刘海两侧 |
| Godot `DisplayServer` | 启动与 `NOTIFICATION_APPLICATION_FOCUS_IN` 时：`window_set_mode(WINDOW_MODE_FULLSCREEN)`（或 borderless + 清栏）；每次焦点回来重读 `get_display_safe_area()`，写入 `mobile_insets` |
| `MobileChrome` | 背景层（`UIKit.void_bg` / 战斗底图）铺满 **物理窗口**；交互根仍 inset。区分 `content_insets`（控件）与 `paint_rect`（可出血） |
| Letterbox | 竖屏不再强制把 1280×720 整页缩进可用区后上下留大黑边：枢纽/对白改为 **锚定顶栏 + 可伸展中部滚动**（已有 `extend_portrait_lists` 思路推广）；战斗场景横屏优先，竖屏时棋盘区吃满宽度、情报改抽屉 |
| 底栏 | `BattleMobileBar.place` 已减 `bottom` inset；需同时避开手势条，底 padding ≥ `max(inset.bottom, 8dp)` |

### 2.6 竖屏 vs 横屏

| 场景 | 默认 | 备注 |
|---|---|---|
| 主菜单 / 命名 / 设置 / 枢纽 / 族谱 / 宫廷 / 对白 | 竖屏优先 | 顶栏 + 滚动主体 + 底安全区 |
| 战术战斗 / 部署预览 | **横屏优先**（可提示旋转） | 竖屏可玩：底栏 + 可折叠右轨 |
| 城堡剪影 `castle_view` | 横屏更佳 | 竖屏改为 3×3 宫格按钮 + 小预览，不硬挤 9 个横向剪影 |

方向锁定不做死；用 `DisplayServer.screen_get_orientation` 只做布局分支。

---

## 3. 队旗 DIY（模块化分层）

### 3.1 问题拆解

- 开局 `naming.gd` 只有 5 个命名色，且仍列「灰烬金 `#c9a227`」（风格锁已迁移到霜银等）。  
- 旗面资产是「整布单色 + 飘动帧」，**没有纹章图层**；城堡 / 枢纽用的 `UIKit` banner 预览同理。  
- `GameState` 仅存 `crest_color: String`，无法表达样式 / 纹样 / 徽记。  
- 国别 `CKCourtChrome.NATION_MARK` 已有几何徽（bars/arc/wave…），但未接到玩家队旗。

### 3.2 模块层（从底到顶）

```
field     底布色 / 双色分割
charge    主纹分割（横分、纵分、斜割、四分、山形…）
border    镶边（细线、齿边、霜环、无）
emblem    徽记（几何单色剪影；可对称）
```

每层独立枚举 + 着色；合成顺序固定。输出：

1. **运行时纹理**：`UnitArt.banner_layers(spec) -> Texture2D`（缓存 key = spec 哈希）。  
2. **小旗 / 宽条**：现有 `banner` / `banner_wide` 改为读 spec。  
3. **存档**：`GameState.banner_spec`（Dictionary）；`crest_color` 保留为 `field` 主色的兼容别名（旧档迁移）。

### 3.3 色板

| 来源 | 内容 |
|---|---|
| 国别预设 | 十国各 1 套推荐（主色 + 辅色 + 默认 emblem kind），取自 `NATION_MARK` ink + 风格锁霜系 |
| 自由 DIY | 色轮 / 色板 ≥ **24** 个霜系安全色（含现有 `banner_*` hex：`6ed4ff` `5ee0b5` `c9d3de` `3a6ea5` …）；禁止写回 `#c9a227` |
| 对比度门禁 | emblem 与 field 的相对亮度差 ≥ 阈值，否则提示「远看辨不清」 |

### 3.4 样式与纹样体量（P0 最小集）

| 层 | P0 数量 | 例子 |
|---|---|---|
| field | 单色 + 双色横/纵 | 纯霜银、上霜下潮 |
| charge | 6 | 无、横带、纵带、斜带、山形、中轴 |
| border | 4 | 无、细线、双线、霜齿 |
| emblem | 12 | 环、弧、浪、叶、chevron、火花、丝缕、潮汐、缺口、横杠、对角、空心圆（可复用 `NationMark.kind`） |

P1 再扩纹样与「姓氏首字」几何单字（不是书法贴图）。

### 3.5 预览与保存

- **命名页**：左侧大队旗实时预览（含飘动帧可选）；右侧分层控件。  
- **城堡预览**：`castle_view` / 枢纽顶栏挂同一 `banner_spec`；议事厅剪影旁悬旗。  
- **保存到旗号**：确认后写入 `GameState.banner_spec` + 刷新 `UnitArt` 缓存；月结 / 继承不重置（禅让只换人，不换旗，除非仪式另开）。  
- **再编辑入口**：设置或枢纽「旗饰」页（P1）；联姻誓礼「旗饰」礼物可解锁一枚额外 emblem（已有 `vow_banner` 钩子，只做表现）。

### 3.6 非目标（队旗）

- 不做玩家上传图片。  
- 不做与十国官方纹章撞车的具名历史纹样。  
- 不改兵种数值、不给 DIY 加属性加成（纯表现）。

---

## 4. 其他打磨（读码所得，按玩家可见度排序）

优先级分：**立刻看得见** → **常用路径** → **边角**。

### 4.1 立刻看得见

1. **开局命名色仍含暖金语义**：`naming.gd` 默认「灰烬金」与风格锁冲突；DIY 落地前至少把默认五色改成霜系并更名。  
2. **战斗点格即走**：见 §2.3 —— 试玩「手感差」的主因。  
3. **竖屏 letterbox**：枢纽整页缩小居中，上下大空；应顶对齐并伸展列表（`extend_portrait_lists` 仅覆盖名录/图鉴/族谱）。  
4. **城堡剪影过素**：`castle_view.gd` 九栋均为三角形 `Polygon2D`，升级只换高度；至少挂队旗 + 分层冻色块/简单窗点，避免「程序员灰块」。  
5. **对白立绘偏小**：`chapter_player` 固定 120×120；手机应按安全区加到 ~160–200 逻辑像素，并保证表情回退清晰。

### 4.2 常用路径

6. **枢纽 NavRail**：竖屏 142px 列 + `SHOW_NEVER` 滚动，条目多时难发现；待办角标有但分组标题 9px 难点。  
7. **部署 / 训练 / 锻造等子页**：大量仍用已退役 `RETIRE_CHROME` 横幅分支；统一 Frost top_bar，去掉死代码路径（表现向）。  
8. **预报面板与手机底栏重叠**：`ForecastPanel` 与 `BattleMobileBar` 同抢下半屏，确认攻击时应把预报锚在底栏之上。  
9. **族谱跳动条**：`LineageJumps` 在 `apply_mobile_layout` 里重定位，但跳转按钮触控高度仅强制 44；与 48dp 新标准对齐。  
10. **宫廷新闻危机条**：`court_news` 横条 `custom_minimum_size.x = 1100`，竖屏必溢出；改自适应宽。

### 4.3 边角 / 功能小升级

11. **设置项**：增加「触控确认移动/攻击」「显示帧率」「简易卡通（已有 simple_toon）」归类到「手机」分组。  
12. **暂停菜单**：`MobileLayout.place_pause` 已居中；补安全区 padding，避免贴刘海。  
13. **长按提示文案**：战斗内已写「长按看情报」；首次战斗用 Coach 气泡教一次（复用 `LampCoach`）。  
14. **队旗在对话旁白**：旁白回退 `UnitArt.banner` 时应用 DIY spec，避免圆裁方旗难看。  
15. **无障碍**：色盲安全已部分靠形状（圆/三角）；队旗 emblem 不依赖唯色分辨（边框+形状双通道）——随 DIY 验收。

---

## 5. 有序 backlog（供 playforge 领卡）

验收写「玩家可感知」语句；实现卡拆 PR 时一卡一流，不改本文件未点名的玩法数字。

### P0 — 试玩下周必须能感觉到

#### P0-MOB-01 · 沉浸式全面屏与安全区

- **为何**：反馈 B；现在只有导出开关 + letterbox。  
- **范围**：`MobileChrome`、`DeviceProfile`、`export_presets` / Android 窗口 insets；战斗底图与 void 背景可出血。  
- **验收**：  
  1. Android 实机（挖孔/刘海）进入游戏后无持久状态栏/手势白条占内容；滑动边缘不露出桌面壁纸条。  
  2. 顶栏资源与底栏按钮完整落在 safe area 内，不被挖孔遮挡。  
  3. 焦点从多任务返回后 insets 仍正确（自动化：强制改 safe rect 的 headless 烟测可接受）。  
- **依赖**：无。 **体量**：M。

#### P0-MOB-02 · 战斗触控确认（移动 / 攻击）

- **为何**：反馈 A 的核心。  
- **范围**：`battle_controller` 选中态增加 `preview_cell`；手机默认开启确认；桌面默认关闭（设置可改）。  
- **验收**：  
  1. 手机：点可达格只出幽灵预览，不改 `su.pos`；点「确认移动」后位置与音效与现网一致。  
  2. 手机：攻击在确认前不扣血、不开过场。  
  3. 长按永不落子；取消/点他人单位行为与现网一致。  
  4. 现有战斗套件（objectives / rewind / deploy 等）全绿。  
- **依赖**：无。 **体量**：M。

#### P0-MOB-03 · 战斗底栏与棋盘手势

- **为何**：五键过挤；拖移易误触。  
- **范围**：`BattleMobileBar`、`InputRouter.SLOP`、默认 fit-zoom。  
- **验收**：  
  1. 主栏 ≤ 4 可见主按钮，触高 ≥ 48dp，与底 inset 对齐。  
  2. 单指拖移不触发点选；双指缩放后单位仍可点中。  
  3. 开局棋盘完整入画（11×7 类图不裁角）。  
- **依赖**：P0-MOB-01（inset）。 **体量**：S–M。

#### P0-BNR-01 · 队旗 DIY 最小集 + 存档

- **为何**：反馈 C。  
- **范围**：`banner_spec` 数据；`UnitArt` 分层合成；`naming.gd` 编辑器；旧 `crest_color` 迁移；城堡/枢纽/对白读取新预览。  
- **验收**：  
  1. 开局可选 ≥ 24 色、6 charge、4 border、12 emblem；实时预览。  
  2. 新开局存档再读，旗面一致；旧档仅 `crest_color` 时自动生成等价 spec（单色 field + 默认 emblem）。  
  3. 堡内 / 枢纽至少一处大队旗预览与开局一致。  
  4. 风格锁：无 `#c9a227` 新写入；`crest_palette_check` 类门禁更新后通过。  
- **依赖**：无（可与 MOB 并行）。 **体量**：L。

#### P0-POL-01 · 竖屏枢纽与命名霜色

- **为何**：进游戏第一眼。  
- **范围**：`MobileLayout` 推广顶对齐；`naming` 默认色表改霜系；`castle_hub` 竖屏列表可滚完。  
- **验收**：  
  1. 1080×2400 逻辑竖屏：顶栏贴 safe top，底提示贴 safe bottom，中间无大块无意义黑带。  
  2. 命名页不再出现「灰烬金 / #c9a227」可选。  
- **依赖**：P0-MOB-01。 **体量**：S。

### P1 — 第二波（常用路径）

| ID | 标题 | 验收要点 | 体量 |
|---|---|---|---|
| P1-MOB-04 | 竖屏战斗布局 | 情报轨可折叠；预报锚在底栏上；旋转提示只出现一次 | M |
| P1-MOB-05 | 枢纽底 Tab / 抽屉导航 | 竖屏不再依赖 142px 左轨点所有入口；待办角标保留 | M |
| P1-BNR-02 | 旗饰再编辑 + 城堡悬旗动画 | 枢纽可改旗；`castle_view` 主楼旁飘旗 6 帧 | M |
| P1-POL-02 | 对白立绘与选项区 | 立绘 ≥ 160 逻辑 px；选项卡不与字幕重叠；跳过键 ≥ 48dp | S |
| P1-POL-03 | 宫廷 / 族谱 / 新闻自适应宽 | 无横向强制 1100；跳跃条 48dp | S |
| P1-POL-04 | 设置「手机」分组 | 触控确认、沉浸式（只读状态）、简易卡通归组 | S |
| P1-ATL-01 | 舆图手势与战斗对齐 | 同 SLOP / 惯性；双指缩放不跳 | S |

### P2 — 有余力

| ID | 标题 | 备注 |
|---|---|---|
| P2-BNR-03 | 姓氏几何单字 emblem | 程序化笔画，非法贴 |
| P2-BNR-04 | 国别一键套装 + 微调 | 套装只是预设 spec |
| P2-POL-05 | 清理 RETIRE_CHROME 死横幅分支 | 纯代码卫生 |
| P2-POL-06 | 城堡剪影换正式模块图 | 依农场/美术排期 |
| P2-A11Y-01 | 队旗色盲预览开关 | 灰阶对比预览 |

### 领卡约定（playforge）

- 一卡一个 PR；PR 正文中文；不碰 `docs/release-*.md`、不改版本号。  
- 不新增 autoload；字符串进 `project/data/locale/<流>.csv`。  
- 风格只用 UIKit/Frost token。  
- 战斗公式、伤病、经济、继承法 **不在本 backlog 授权范围内**。  
- 与 [#123](https://github.com/wuyongjia666-droid/CenturyKnights/pull/123) 无代码交集；若文案冲突，等用户拍板后再改提案，不抢合。

---

## 6. 不在范围（Out of scope）

- 玩法系统改版：战斗公式、ZoC、胜利条件、伤病、经济、继承、血律、出战人数钳制等（见 #123 与既有 v92 设计）。  
- 新职业 / 新地图 / 新章节正文。  
- 玩家自定义上传队旗图片、拍照生成纹章。  
- iOS 专用特性（可顺手兼容 safe area，但不单开 iOS 工程卡）。  
- 包体瘦身、CI、ETC2 之外的基础设施（已有 INF 流）。  
- 重做 3D 过场或音频总线。  
- 合并或推进 [#123](https://github.com/wuyongjia666-droid/CenturyKnights/pull/123)（祖辈年事）及其他待拍板设计稿。  
- 本 PR 自身：**只新增本设计文档**，不改 `project/scripts/**` 玩法代码。

---

## 附录 A · 关键文件索引

| 主题 | 路径 |
|---|---|
| 全面屏 / inset | `project/autoload/mobile_chrome.gd`、`project/scripts/platform/mobile_layout.gd`、`project/scripts/platform/device_profile.gd` |
| 触控路由 | `project/scripts/platform/input_router.gd` |
| 战斗手感 | `project/scripts/battle/battle_controller.gd`、`project/scripts/battle/ui/battle_mobile_bar.gd`、`forecast_panel.gd` |
| 队旗 | `project/scripts/story/naming.gd`、`project/scripts/art/unit_art.gd`、`project/assets/art/banners/`、`project/assets/art/crest_palette_v92.json`、`tools/art/recolor_banners_v92.py` |
| 国别徽 | `project/scripts/ui/court_chrome.gd`（`NATION_MARK`） |
| 枢纽 / 城堡 | `project/scripts/hub/castle_hub.gd`、`castle_view.gd` |
| 族谱 | `project/scripts/hub/lineage_view.gd` |
| 对白 | `project/scripts/story/chapter_player.gd` |
| 导出 | `project/export_presets.cfg`（`screen/immersive_mode`） |

## 附录 B · 验收场景脚本（人工）

1. 1080×2400 竖屏进主菜单 → 命名 → 改旗 → 进第零章：旗在对白旁白/堡内一致，无系统栏遮字。  
2. 横屏打一局教学战：选人 → 点格（仅预览）→ 确认移动 → 攻击预览 → 确认攻击；期间双指缩放、单指平移无误触。  
3. 挖孔机：顶栏银两数字不被挖孔切开；底栏「确认」可点。  
4. 读旧档：仅有 `crest_color` 的存档开得起来，旗为单色等价物。
