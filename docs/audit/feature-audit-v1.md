# 百年骑士 全功能审查 v1（2026-10-13）

基线：`origin/main` @ `c5e0e0f7`。方法：全部 39 个场景在 Xvfb + opengl3 下以 **2400×1080 横屏** 截图（临时 capture 脚本，未提交），并对照 `scripts/` 代码与 `docs/design/*`。
已有设计盘点 `docs/design/ux-navigation-v1.md` 的条目不重复展开，仅在此登记状态。

严重度：**P0** 功能走不通/路由错/玩家被卡住；**P1** 明显难用、占位、空页、与设计不符；**P2** 打磨。
Owner 列：`owned:<线>` 表示已有运行中的线负责，本表仅记录不派工；`WS-A..D` 为下文建议的新工作流。

## 汇总

| 类别 | P0 | P1 | P2 | 合计 |
|---|---|---|---|---|
| 未认领（WS-A..D） | 6 | 27 | 14 | 47 |
| 已认领（owned） | 4 | 6 | 1 | 11 |

## 审查表

| # | 功能 | 问题 | 严重度 | 建议修法 | Owner |
|---|---|---|---|---|---|
| 1 | 城堡全景 castle_view | 五个尖角占位图标 + 四个按钮（医所/书院/宝库/使馆）全部 `change_scene_to_file("works.tscn")`（castle_view.gd:116），点什么都进工事升级 | P0 | 各建筑跳到对应页（医所→shrine，宝库→estates/旗库，书院→train/skill_tree，使馆→rival_houses）；未建成的显示锁定卡+开放条件 | WS-A |
| 2 | 城堡全景 castle_view | 美术为占位三角形，无背景、无标签、左上「返回工事」而非返回城堡 | P1 | 用城堡立面图 + 热区；返回走统一返回栈 | WS-A |
| 3 | 全局导航 | 97 处写死 `change_scene_to_file`，无返回栈；同页不同入口返回同一处（ux-navigation-v1 §2.1） | P0 | 引入 `Nav.push/pop` autoload，逐页替换；ESC/返回键统一走 pop | WS-A |
| 4 | Android 返回键 | `quit_on_go_back` 未设置，按返回可能直接退出且同时弹暂停 | P0 | project.godot 设 false，返回键→Nav.pop | owned:手游专线（核对是否已含） |
| 5 | 暂停菜单 | 2400×1080 下面板贴右边缘被裁切；战斗中「回到灰旗堡」无确认、不算撤退 | P1 | 居中；战斗中改为「撤退」并确认 | 布局 owned:手游专线；撤退逻辑 WS-D |
| 6 | 城堡主页 | 顶栏「主菜单」一键回标题无确认；页脚「B 返回中枢 / Y 快速休整 / LB RB」无对应输入（castle_hub.gd 236/302） | P1 | 加确认弹层；删除假提示或实现 | WS-A |
| 7 | 城堡主页 | 导航轨 27 个入口平铺五组，新解锁无提示（ux P0-7） | P1 | 新入口红点 + 一次性提示；未开放灰显写开放条件 | WS-A |
| 8 | 起名/团徽 naming | 2400×1080 下右侧团旗与表单被裁出屏幕，页面无 Frost chrome，像调试页 | P0 | 改为左表单右预览两栏，套 Frost chrome | 布局 owned:手游专线；样式 WS-A |
| 9 | 标题 main_menu | 「同型原创」副标题意义不明；无版本号/继续存档预览 | P2 | 改副标题；「继续历程」显示存档摘要 | WS-A |
| 10 | 读档 save_slots | 旧样式纯文本列表，空槽仍显示可点的灰「读档」，无截图/时间/章节卡 | P1 | 存档卡（团徽、章节、游戏内日期、实际时间），空槽禁用并写「空」 | WS-A |
| 11 | 设置 settings | 只有语言/缩放/色盲/棋子预览，缺音量、动效减弱、战斗动画开关、操作说明；右侧大片空白 | P1 | 分组：画面/声音/战斗/无障碍；加「战斗动画：开/仅暴击/关」 | WS-A |
| 12 | 制作人员 credits | 只列字体许可，无团队/美术来源 | P2 | 补制作与素材来源 | WS-A |
| 13 | 酒馆 tavern | 候选人需滚动才能看完 | P1 | 一排横摆 | owned:手游专线 |
| 14 | 酒馆 tavern | 三个候选同价 25、属性差异小，刷新规则不透明（右上「免费刷新 1/1」无说明） | P2 | 候选分稀有度/价格带；刷新说明 tooltip | WS-C |
| 15 | 花名册 roster | 右下「血脉详情/换装/委派出战」按钮与卡片底边不齐；特质卡空白多 | P1 | 按钮行对齐 | owned:手游专线 |
| 16 | 骑士档案 unit_dossier | 中栏「第二梯度 2 类目尚未解锁详情」整栏空，右栏子嗣区只一个按钮 | P1 | 中栏放生平/伤病/战绩；未解锁写解锁条件 | WS-A |
| 17 | 工事 works | 右侧升级按钮大且不齐 | P1 | 对齐小按钮 | owned:手游专线 |
| 18 | 工事 works | 五项升级全部同价「80 银·3 铁·10 粮」，无收益数值对比，「查看全景」跳到占位全景 | P1 | 按建筑分价；按钮旁显示升级后效果 | WS-A |
| 19 | 旗塾 train | 旧样式（无 chrome），只有一句说明 + 一个「转职→轻骑」按钮，大片空白；与 campaign_v92 e3_03 冲突（ux §2.2） | P1 | 迁 Frost；列出可受训者、费用、时长、预期属性 | WS-A |
| 20 | 战技树 skill_tree | 旧样式；节点文字重叠（「破阵翻越一步 T1」与连线重叠），小地图框空 | P1 | 迁 Frost；节点自动布局避免重叠；小地图要么做要么删 | WS-A |
| 21 | 请爵 title_promote | 「封地 12/8」超出上限仍显示满格，看不出差什么条件；「请爵」按钮灰而无原因 | P1 | 缺条件红字列出；超额显示为达成 | WS-A |
| 22 | 祠堂 shrine | 三张卡信息足，但「修缮」只是跳工事；无霜月祭说明 | P2 | 祭典说明 + 本月可祭状态 | WS-A |
| 23 | 先祖碑 ancestors | 开局空页，仅「碑上还没有人」，无排版 | P1 | Frost 化；空态说明「族人去世后在此立碑」+ 示意 | WS-A |
| 24 | 羁绊 support_viewer | 城堡已有入口但内容为空「还没有可看的羁绊」；ux 文档标为孤儿 | P1 | 显示羁绊列表与解锁条件；无则列出可培养的组合 | WS-A |
| 25 | 朝报 court_news | 开局空「这一栏还没有朝报」，五个筛选按钮全空 | P2 | 开局写入入团/建堡等初始条目 | WS-A |
| 26 | 敌宅交涉 rival_houses | 旧样式；右侧 6 个青色大按钮堆叠，费用写在按钮文字里，无结果预期 | P1 | Frost 化；行为卡（费用/效果/风险） | WS-A |
| 27 | 岁月沙漏 hourglass | 旧样式；右侧「推进结果」开局空框；「教程：跳至半收月」按钮常驻正式界面 | P1 | Frost 化；去掉教程按钮或仅调试显示 | WS-A |
| 28 | 授旗礼 lineage_rite | 旧样式；两栏几乎空，「授旗礼（分支）」术语难懂 | P1 | Frost 化；空态说明谁可授旗、何时 | WS-A |
| 29 | 继承 inheritance | 旧样式，三个大青按钮（十年旗/宅地加深/调合）无效果说明 | P1 | Frost 化；每项写后果 | WS-A |
| 30 | 嗣位校场 heir_rivalry | 旧样式；开局只有一个「闭幕」按钮的空框 | P1 | 无继承人时显示说明而不是空赛场 | WS-A |
| 31 | 血检 blood_test | 结果区开局仅一句；按钮在左下离结果远 | P2 | 选人→结果同栏 | WS-A |
| 32 | 族谱 lineage_view | 孩子多了不可用 | P1 | 头像墙 + 详情谱 | owned:族谱重做线 |
| 33 | 婴儿立绘 | 出生显示少年立绘 | P0 | 年龄段统一立绘 | owned:婴儿立绘线 |
| 34 | 联姻 marriage | 信息密度极高（64% 匹配、底部一长串小字收益），不懂哪个数重要 | P1 | 只突出 3 个关键数，其余收进「详情」 | WS-C |
| 35 | 岁课 sui_ke | 卡池薄、重复 | P1 | 加厚目录 | owned:延后功能线 |
| 36 | 属地/属事处/私囊 estates | 私囊/属事处未做 | P1 | 按 v92 方案 | owned:延后功能线 |
| 37 | 属地 estates | 四个田庄全部「未开放」+「空」，开局整页灰；「全面巡视」无反馈 | P1 | 首块田庄开局可用；巡视后弹结果 | WS-C |
| 38 | 市集 market | 只有粮/铁/药三种商品，价格不随月份变化感弱 | P2 | 加季节波动与事件价格 | owned:延后功能线（杂货）／其余 WS-C |
| 39 | 铁匠 forge | 只能+2 锻造一条路线，无装备外观变化；「升级工坊」跳工事 | P2 | 显示打造后属性对比并在立绘/棋子上体现 | WS-C |
| 40 | 委托榜 quests | 旧样式；三条委托无地图位置/风险，按钮全是相同青条 | P1 | Frost 化；委托卡带地点、星级、奖励、剩余月 | WS-C |
| 41 | 舆图 atlas_view | 左栏 12 城名单与地图节点无联动高亮；底部「出战编成」返回回城堡（ux §2.2） | P1 | 名单 hover/点击同步地图；返回回舆图 | WS-C |
| 42 | 跑图 | 节点间移动无行军动画/遭遇事件，跨月旅行无反馈 | P1 | 行军动画 + 路上事件卡（atlas-cities-v87 §4） | WS-C |
| 43 | 城市 city | 七个页签，城门图之外右侧两栏大段空白；「可在此交付」空 | P2 | 空栏放城内传闻/NPC | WS-C |
| 44 | 城市铁匠 | 小城「此地没有铁匠铺」页签仍可点进空页 | P2 | 无铁匠时隐藏或锁定页签 | WS-C |
| 45 | 领地夺取 territory | territory.md §5 失守/反夺与 §6 舆图表现（归属色、驻军数）未在舆图上可见 | P1 | 舆图节点显示归属与驻军；失守事件弹窗 | WS-C |
| 46 | 出战编成 deploy | 出战可无限重复（审查 P1-3）；空位卡「+ 空位」无点击反馈 | P1 | 每月次数/疲劳；空位点开选人 | WS-D |
| 47 | 战斗 HUD | 拥挤、提示叠字、触控难 | P0 | 横屏重做 | owned:手游专线 |
| 48 | 战斗 AI | tactics_ai 仅 7 个函数，敌人行为单一（直冲最近目标） | P1 | 加集火残血、守点、撤退、治疗兵后排等行为 | WS-D |
| 49 | 3D 战斗动画 cutscene | 背景是灰白方块占位建筑，人物剪影白，无地形 | P1 | 换正式背景/地面，按地形选场景 | WS-D |
| 50 | 战斗结算 battle_report | 战败回第零章（ux §2.3）；奖励只列数字 | P0 | 战败回城堡并结算伤病；奖励逐项动画 | WS-D |
| 51 | 战斗目标 | combat-objectives-v92「增援」规则未在 HUD 预告 | P2 | 增援前一回合预警 | WS-D |
| 52 | 平衡 | balance-v92 与实际：开局 120 银，工事升级 80 银，第一月几乎只能做一件事 | P1 | 按 balance-v92 校准起始资金与首月收入，跑 campaign_sim 验证 | WS-D |
| 53 | 事件 life_events | 60 张事件卡，触发无弹窗插图 | P2 | 事件卡配插图与选择 | owned:延后功能线 |
| 54 | 新手剧情 chapter0 | 未体现小说；对白页只有团旗占位立绘 | P1 | 按 tutorial-story-v2 | owned:新手剧情线 |
| 55 | 卷章 chapter_player | 对白页人物位只显示团旗，不显示说话人立绘/表情 | P1 | 说话人立绘 + 表情 | owned:新手剧情线 |
| 56 | 团徽 heraldry | 团徽固定只在起名时一次（#147）；无任何地方可预览大图 | P2 | 档案/朝报页可查看大图 | WS-A |
| 57 | 存档 | 自动存档无提示 | P2 | 角落存档图标 0.5 秒 | WS-A |
| 58 | 血脉图鉴 codex | 列表内大量灰色占位块（未解锁字）无说明 | P2 | 灰块加「？」与解锁提示 | WS-A |

## 工作流分组（未认领项）

与已认领线（手游专线：`mobile_layout.gd`/`device_profile.gd`/`court_chrome.gd`/战斗 HUD `scripts/battle/ui/*`；延后功能；新手剧情 `scenes/story/chapter0`、`data/story`；婴儿立绘 `portrait_*`；族谱 `lineage_view.gd`）避开文件。

| 工作流 | 范围（条目） | 文件区域 |
|---|---|---|
| **WS-A 城堡壳与旧页迁移** | 1,2,3,6,7,9–12,16,18–31,56–58 | `autoload/`（新 Nav）、`scripts/hub/castle_hub.gd` `castle_view.gd` `works.gd` `train.gd` `skill_tree.gd` `title_promote.gd` `shrine.gd` `ancestors.gd` `court_news.gd` `rival_houses.gd` `hourglass.gd` `lineage_rite.gd` `inheritance.gd` `heir_rivalry.gd` `blood_test.gd` `unit_dossier.gd` `bloodline_codex.gd`、`scripts/ui/main_menu.gd` `settings.gd` `credits.gd`、`scripts/core/save_slots.gd` `autosave.gd`、`scripts/narrative/support_viewer.gd`、`story/naming.gd` |
| **WS-C 舆图·城镇·经营** | 14,34,37–45 | `scripts/hub/atlas_view.gd` `atlas_territory.gd` `city.gd` `quests.gd` `market.gd` `forge.gd` `estates.gd`(与延后线协调私囊段) `tavern.gd`(仅数据/刷新逻辑) `marriage.gd`、`scripts/company/territory.gd`、`data/world*` |
| **WS-D 战斗内容与平衡** | 5(撤退),46,48–52 | `scripts/battle/tactics_ai.gd` `ai_planner.gd` `combat_cutscene.gd` `cutscene_*.gd` `objectives.gd` `victory_rewards.gd` `enemy_loadout.gd` `battle_report.gd`→注意它在 `battle/ui/`，需与手游专线约定只改结算逻辑；`scripts/hub/deploy.gd`、`scripts/sim/campaign_sim.gd`、`data/balance*` |

说明：WS-A 体量大，可再拆为 **WS-A1 导航/城堡/全景/工事/主菜单/设置/存档**（1–3,6,7,9–12,18,57）与 **WS-B 旧样式页 Frost 迁移**（16,19–31,56,58），两者文件不重叠，即 4 条并行线。
`castle_hub.gd`、`tavern.gd`、`roster.gd` 手游专线也会改布局，WS-A1/WS-C 进入前需与手游专线 rebase 协调。
