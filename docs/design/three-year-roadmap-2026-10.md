# CenturyKnights（百年骑士）三年迭代路线 · 2026-10-22

> 状态：**时间压缩冲刺·内容全量**（2026-10-25）— 收的是时间表，三年内容（耐玩闭环 + 季#1–#3 + 商店工程）**不砍、可扩充**；今日尽量推完  
> 基线仓库：随 `main` 前进（本文件变更记录为真源）；Y1-A 代码侧已收口  
> 试玩包：最新 `main-<sha8>` Release（Android APK + Windows zip）；用户统一试玩只在全部做完后  
> 约束：Y1-B / 内容季 / 商店文档与代码 CI 全绿可自合；**不花钱正式提审**；不 force-push；默认禁用 CloudAgent；保画质不做 H/I；统一试玩前自包 E2E；禁止 EmptyHost/how 表面刷刀

---

## 0. 一句话

三年内把《百年骑士》做成 **安卓 + Windows 商店同日 1.0**（Steam 稍后），寿命靠 **无限王朝沙盒** 撑住；叙事以「内容季」持续加长，不设「打完五代就结束」。Year1 先过 **手游可玩硬门槛**（战棋手感 + 手游/端游立绘对齐），再开内容季量产。

---

## 1. 已锁定决策

| 项 | 决定 |
|----|------|
| 三年终点 | 商店 1.0：安卓 + Windows 同日；Steam 延后约一季 |
| 不做 | iOS、主机、PVP、内购、默认 CloudAgent、压画质砍包（H/I） |
| 游戏寿命 | **无限沙盒**（岁月/联姻/继承/领地/委托可一直滚）；「纪元」= 内容季，不是通关上限 |
| 1.0 内容量 | 至少 **3 条打磨好的内容季** + 耐玩闭环立住；第 4+ 季可发售后免费更新 |
| 产能主脊柱 | 叙事与系统深度（纪元故事、岁课、职印、联姻血脉） |
| Year1 门禁 | 手感/立绘继续 suite+emu 自验（代码侧已收口）；**2026-10-25**：内容季真写不再等真机签收；统一试玩只在全部做完后 |
| 售卖（推荐已采纳） | 一次性买断，无内购；可用商店试玩分钟或独立 Demo |
| 包体（推荐已采纳） | 安装包压到商店友好区间；大立绘/语音走按需下载 / Asset Pack；禁 H/I |
| 推进授权 | 2026-10-25：全权含内容；时间压缩冲刺·内容全量（不砍季#1–#3/耐玩/商店工程）；Y1-B/内容/商店 CI 绿可自合；**花钱正式提审 / force-push 仍禁** |

### 立绘问题口径（2026-10-22 澄清）

手游「缺立绘」优先按 **端游已有、手游与端游资源路径/档位/打包不一致** 排查与修复，而不是默认重跑农场。缺图清单以「同剧情节点：Windows 有图、Android 无图」为复现标准。

---

## 2. 成功标准（1.0）

1. **手游战棋可玩**：选中、移动、攻击、镜头在真机上不别扭（用户验收，CI 绿灯不算过关）
2. **立绘对齐**：对白用到的角色在安卓与 Windows 表现一致；已知不一致项清零
3. **耐玩闭环**：不靠主线也能玩下去（招募 / 委托 / 战棋 / 联姻传代 / 领地 / 岁课形成月循环）
4. **商店可上架**：安卓 + Windows 过审；买断上架
5. **≥3 条内容季**达到可卖打磨度

---

## 3. 三年排期

### Year1（约 → 2027-10）两段式，不可颠倒

#### Y1-A（约 3～4 个月）手游硬门槛

| 周 | 目标 |
|----|------|
| 1–2 | 战棋触控问题审计 + 手游/端游立绘不一致审计（清单 + 复现）；每周手感包 |
| 3–6 | 选中 / 拖移 / 确认、命中盒、镜头；战斗 HUD 可读；真机 2～3 轮 |
| 7–10 | 立绘路径/档位/导出对齐清零；枢纽页安全区 / 截断扫尾；Y1-A 签收包 |
| 11–13 | 签收通过 → 内容季 #1 选题 + 开写小说；空团结局规则拍板；确认农场 Qwen 可用（勾选清单：[`y1a-acceptance-checklist-2026-10.md`](./y1a-acceptance-checklist-2026-10.md)） |

**Y1-A 不做**：29 职全量 Path C、纹章大改、Steam 页、为压包牺牲画质。

#### Y1-B（余下约 8～9 个月）内容季 #1 + 耐玩骨架

- 内容季 #1：小说（对标《那个字》）→ 圣经 → 可玩章（口语对白）
- 系统加深：岁课 UI 落点、职印/专师可感、联姻/继承边角
- 视觉：只补本季必需；立绘优先对齐已有端游资源

### Year2（约 → 2028-10）

- 内容季 #2、#3
- 每季 1 个「月循环能摸到」的系统加深
- 商店工程：按需资源落地、性能档、商店页、崩溃闸
- 年末：内部可卖预览版（可仍未正式上架）

### Year3（约 → 2029-10）

- 内容季 #4（产能够则 #5）+ 百年数值收口
- 封闭 → 公开试玩 → 修 P0
- **约 2029 Q3–Q4**：安卓 + Windows 1.0 同日
- Steam：1.0 后约一季内跟进

---

## 4. 内容季标准流水（不可跳步）

1. 选题：该季「旗/灯」冲突 + 要加深的 1 个系统  
2. 小说：中篇，用户过目  
3. 圣经：动机、节拍、对白口吻  
4. 可玩章：大白话，单行 ≤60 字  
5. 系统加深：写进月循环 + PR 验收标准  
6. 立绘/资源：本季出场角色安卓/Windows 对齐；清单归零才算季完工  
7. 试玩包：Y1-A/hub-mobile CI 绿自合进 main → Release → 真机签收  

产能假设：正常年份约 1～1.5 条内容季；Year1 因 Y1-A 门禁偏少是预期。

---

## 5. 工程与管线纪律

- 引擎：Godot 4.3；平台：Windows + Android（iOS 不做）
- 主控：playforge；实现纪律：poteto（可验证、少 slop）；BMGD 管阶段
- 反方：本地 Qwen challenge/review（`100.127.28.107:8003` 恢复后例行）；接受/驳回写入 PR
- 裁判：仓库测试 / CI；**体验过关以真机签收为准**
- 合 main：Y1-A / hub-mobile 用 `--merge --delete-branch`，CI 全绿由 playforge 自合；其余范围仍请示；禁止 force-push / 花钱
- 发布：push main → `main-<sha8>` 自动出 Windows zip + Android APK
- 立绘/3D：`tools/farm_queue`；优先修打包/路径不一致，再考虑补生成

---

## 6. 风险闸门

| 风险 | 闸门 |
|------|------|
| 手感不过就扩内容 | 手感/立绘并行 suite+emu；内容季真写已授权；统一试玩在全部做完后 |
| 叙事断档 | 季开工前锁定小说选题；写不完缩季 |
| 农场不可达 | 先做纯代码手感 / 路径对齐；恢复后再补生成 |
| 包体膨胀 | 新大资源默认按需；禁 H/I |
| 沙盒无聊 | 每季必须带 1 个可摸到的系统加深 |
| 范围蔓延 | Path C 全量 / 纹章大改 / Steam 不进 Y1 主线 |

---

## 7. 附录 · 仍待拍板（不堵 Y1-A）

- 空团/团灭是否中途「王朝终结」→ **已 stub**：无可承旗 / 战场团灭无存活可承旗名册 → `house_mods.dynasty_end` + 枢纽/沙漏/属地 `DynastyEndPanel`/`ToTitle`（#382 + 团灭边角；细规则仍可迭代）
- 买断定价数字
- 安卓按需方案具体选型（如 Play Asset Delivery）

---

## 8. 附录 · 现状锚点（规划日）

详见工作区采集稿逻辑；仓库真源：

- `_bmad-output/planning-artifacts/game-brief.md` / `gdd-mvp.md` / `systems-catalog.md`
- `docs/design/story-bible-v92.md`（叙事脊柱；**不作寿命上限**）
- `docs/art/export-cap-400.md`（包体；H/I 已停）
- `docs/design/pawn-s7-acceptance-20261019.md`（棋子 CI DONE / 真机 NEED_USER）

---

## 9. 变更记录

| 日期 | 变更 |
|------|------|
| 2026-10-25 | Y1-B 战棋月回响：battle win/lose → `house_mods.month_echo.battle` + estates/hourglass 回读 + `month_echo_battle_check` |
| 2026-10-25 | Y1-B 酒馆招募月回响：recruit → `house_mods.month_echo.recruit` + estates/hourglass 回读 + `month_echo_recruit_check` |
| 2026-10-25 | **时间压缩冲刺，内容全量**：日程压缩、三年内容不砍；联姻→继承→嗣位端到端可玩链 + `marriage_heir_chain_check`（多场景回读） |
| 2026-10-25 | **时间压缩冲刺·内容全量**：文首状态改；今日目标季#1–#3 + 商店工程；内容不等签收 |
| 2026-10-25 | 内容季 #2/#3 脚手架 v2 + 开写：`season-02`《婚约上的灯》初稿、`season-03`《榜上的收成》§1–§8；多季 `content_season_scaffold_check` |
| 2026-10-25 | 商店工程准备（不缴费）：`docs/store/*` + `tools/ci/store_prep_check.py`（导出路径/文案/崩溃性能/包体口径） |
| 2026-10-25 | 商店工程深刀（不缴费）：Play/MS 完整字段稿 + 隐私/分级草稿 + `store_packaging_dry_check`（出包脚本/预设/release 干跑） |
| 2026-10-25 | 联姻→继承→嗣位端到端可玩链 + `marriage_heir_chain_check`（多场景回读） |
| 2026-10-25 | Y1-B 岁课 UI 落点加深：城堡家庭导航常驻 ToSuiYear + 未读角标（todo→family）+ `sui_hub_entry_check` |
| 2026-10-25 | Y1-B 联姻无对象空态：EmptyHost why/how + ToTavern/ToRoster + `marriage_empty_cta_check` |
| 2026-10-25 | Y1-B 花名册空编制：EmptyHost why/how + ToTavern + `roster_empty_cta_check` |
| 2026-10-25 | Y1-B 内容季 #2：中篇《婚约上的灯》（≥1.2万汉字）+ 圣经 + 可玩章 `cs02_01` + playable_s02 suite；scaffold 多季；#403 体量不足关闭 |
| 2026-10-25 | Y1-B 内容季 #1：中篇《回执上的灯》+ 圣经 + 可玩章 `cs01_01` + playable suite；业主全权开 `novel_allowed`；#2 选题起步 |
| 2026-10-25 | Y1-B 季#2/#3 开写加深（《婚约上的灯》《榜上的收成》）+ 商店工程门禁 `store_prep_check`；合 #405 后 rebase |
| 2026-10-25 | Y1-B 内容季 #1：中篇《回执上的灯》+ 圣经 + 可玩章 `cs01_01` + playable suite；业主全权开 `novel_allowed` |
| 2026-10-25 | Y1-B 请爵顶阶空态：EmptyHost how + ToCity（职印）+ `title_promote_top_cta_check` |
| 2026-10-25 | Y1-B 酒馆柜上无人：EmptyHost why/how + ToRoster + `tavern_empty_cta_check` |
| 2026-10-25 | Y1-B 委托榜空态：EmptyHostActive→ToAtlas / EmptyHostBoard→ToHourglass + `quests_empty_cta_check` |
| 2026-10-25 | Y1-B 档案缺人空态：EmptyHost why/how + ToRoster + `dossier_missing_empty_cta_check` |
| 2026-10-25 | Y1-B 敌宅空列表：EmptyHost why/how + ToCourtNews + `rival_houses_empty_cta_check` |
| 2026-10-25 | Y1-B 同袍空羁绊：EmptyHost why/how + ToRoster + `support_empty_cta_check` |
| 2026-10-25 | Y1-B 验血 idle 右栏：EmptyHost why/how + ToMarriage（全验完对齐 #369）+ `blood_test_idle_cta_check` |
| 2026-10-25 | Y1-B 沙漏空 log：EmptyHost why/how + ToCourtNews + `hourglass_empty_cta_check` |
| 2026-10-25 | Y1-B 岁课空 inbox how：EmptyHost + `sui_year_empty_how`（ToHourglass 既有）+ suite 断言 |
| 2026-10-25 | Y1-B 战技树无人/无树 how：EmptyHost + ToTavern/ToTitlePromote + suite 断言 |
| 2026-10-25 | Y1-B 属地月回响空 how：EmptyHost + ToHourglass + `month_echo_estates_check` 断言 |
| 2026-10-25 | Y1-B 旗塾导师/晋升空 how：EmptyHost + ToTavern/ToTitlePromote + suite 断言 |
| 2026-10-25 | Y1-B 朝报分类空 / 验血左队列 how：EmptyHost + ToHourglass/ToMarriage + suite 断言 |
| 2026-10-25 | Y1-B 旗塾传习/晋升月回响：tutor/promo → `house_mods.month_echo` + estates/hourglass 回读 + `month_echo_train_check` |
| 2026-10-25 | Y1-B 嗣位答完年可感链：ToHeirRivalry(+ToRivals) 闭合 #29↔#30 + `inheritance_done_cta_check` |
| 2026-10-25 | Y1-B 嗣位校场无继承人空态（#30）：EmptyHost why + ToMarriage/ToTavern + `heir_rivalry_empty_cta_check` |
| 2026-10-25 | Y1-B 战场团灭 → 同一 `dynasty_end`（reason=`wipeout`；战后 defer 承旗 + `close_after_battle`）+ `dynasty_wipeout_check` |
| 2026-10-25 | Y1-B 空团结局 stub：无可承旗 → `house_mods.dynasty_end` + 枢纽/沙漏/属地可感 + `dynasty_end_stub_check` |
| 2026-10-25 | Y1-B 诞育/联姻月回响：birth/marriage → `house_mods.month_echo` + estates 回读 + suite |
| 2026-10-25 | Y1-B 委托月回响：交付/逾期记入 `house_mods.month_echo.commission` + estates/hourglass 回读 + suite |
| 2026-10-25 | Y1-B 内容季流水脚手架加深：topic_checklist / acceptance[] / pipeline_stages + suite v2（仍不扩小说） |
| 2026-10-25 | Y1-B 月循环加深：属地 MonthEchoPanel 回读上月收成/领地月结 + `month_echo_estates_check` |
| 2026-10-25 | Y1-B 开刀：继承页答完后 mobile 重跑 `apply_mobile_layout`（AnswerScroll / FONT / HIT）+ `mobile_inheritance_reshow_check` |
| 2026-10-24 | Y1-A 清单 §4：ae109ae1 模拟器冒烟 #348–#350 PASS（真机仍待自玩签收） |
| 2026-10-24 | Y1-B 岁课年迹：`sui_yeartrace_check`（resolve→持久年迹→ack 不抹；档案 YeartracePanel） |
| 2026-10-24 | Y1-B 年迹族谱可见：lineage_view / bloodline_codex 可点开只读 + `sui_yeartrace_lineage_check` |
| 2026-10-24 | Y1-B 内容季选题脚手架：`docs/content-seasons/season-01` + `content_season_scaffold_check`（签收前不扩写小说） |
| 2026-10-24 | Y1-B 职印六门端到端：`job_seal_six_check`（本城之事→盖印→转职×6）；族谱 mobile 见 #353 |
| 2026-10-24 | Y1-B 开刀：岁课月循环端到端冒烟 `sui_month_loop_check`（生日→inbox→yearcard→ack→todo 清零）；枢纽族谱契约见 #353 |
| 2026-10-24 | Y1-A 代码门闩收口（#331–#350）；可自主代码刀空；**待用户自玩签收**（用户不装、后面自己玩）；内容季仍等签收后 |
| 2026-10-22 | 初版：路线 A；无限沙盒；Y1-A 手游门禁；立绘=端游/手游对齐；全权推进 |

