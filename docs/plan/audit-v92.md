# 百年骑士 / CenturyKnights · v9.2 全面审计与执行计划

> 角色：主审 / 游戏总监。范围：通读 `docs/design/*`、`docs/art/*`、`_bmad-output/planning-artifacts/*`、`project/data/*`、`project/scripts/**`、`project/autoload/*`、`project/tests/*`、`project/scenes/**`、`scripts/run_ci.sh`、`tools/**`、导出预设。
> 基线：`main@e755b71c`（含 PR #7、#8）。这份文档**只做规划**，不改任何玩法代码。
> 配套：`docs/plan/backlog-v92.json`（任务卡的唯一数据源，本文第 6 节是它的可读摘要）。
> 美术锁：`docs/art/style-lock-v89.json`（继承 v87）——2026 当代奇幻、磨砂玻璃、霜青 `#6ED4FF`、友军薄荷 `#5EE0B5`、敌军珊瑚 `#FF7A70`、墨蓝底 `#07080C/#161B24`；**禁止**中世纪、羊皮纸、做旧纸、棕褐、鎏金/黄铜、暖金光。

---

## 0. 结论先行

1. **系统的广度已经够了，深度和打磨远远不够。** 舆图贸易（74 城、17 货、106 路、223 件装备）和十国血律已经是本项目最强的两块，单拿出来能和《诸神皇冠：百年骑士团》以及 Battle Brothers 的同类子系统比。但战斗只有一种胜利条件，佣兵没有代价，剧情是模板灌水，音乐只有三段 9–14 秒的程序化循环，招牌功能 Plan A 基因立绘在仓库里是 **0 张**。
2. **最大的质量负债是剧情。** 235 章、3,486 行对白、10 个说话者，有名有姓的角色只有一位（`苇原·灯影`）。0 个选项，0 段支援对话。第 2 章以后基本是换名词的模板，比如「第二十四卷中段完成（v4.7）」这种系统口吻直接写进了对白。这正是负责人说的「靠剧情体量灌水」，必须冻结并重写成一条有作者的主线。
3. **最大的架构风险是 Plan A 立绘发不出货。** `CKGenomePortrait.texture()`（`project/scripts/art/genome_portrait.gd:473`）只按 `unit_id` 查 `res://…/genome/<id>_<stage>.png` 或 `user://genome_portrait_cache/`。玩家存档里运行时出生的子嗣，在发行版里不可能有离线农场渲染出的图。要么做「基因描述分桶立绘库」（本计划 ART-01 / FARM-01），要么承认 Plan A 只覆盖预制角色。这是一个产品决策，排在 P0。
4. **工程地基不够。** 仓库里没有 `.github/workflows`，`scripts/run_ci.sh` 末尾自己写着「token 有 workflow 权限时再加」，所以 CI 其实没跑过。`GameState` 有 3,468 行、235 个 `data_chapterN` 加 235 个 `chapterN_beat` 字段。`battle_controller.gd` 有 4,215 行，其中 `_mark_map_victory` 是一条 400 个分支的 `elif map_id ==` 梯子。`castle_hub.gd` 里有 469 处 `chapterN_done` 判断。导出预设是 `all_resources`，259MB 的 `farm_inbox` 和 75MB 已退役的纸娃娃资产会一起打进 APK/PCK。只有一个存档槽，没有备份，也没有暂停菜单。
5. **执行方式：** 共 11 条流，其中 10 条可由 Grok 4.7 云代理并行执行，另有 1 条依赖本地农场（暂停中）。每个热点文件只归一条流所有。第 0 波先合并 3 张地基卡（INF-01 真 CI、CORE-01 章节状态表化、CORE-02 GameState 领域拆分），其余流从第一天起就能做不碰这些文件的卡。

### 各维度评分（0–10，参照对应维度的一线标杆）

| 维度 | 分 | 一句话 | 参照 |
|---|---|---|---|
| 核心循环与节奏 | 5 | 循环闭合（`full_chain_e2e`），但百年 1,200 个月缺少纪元结构，17 个城堡入口第一天就全部开放 | 诸神皇冠 / 三房 |
| 战术深度 | 4 | ZoC + 交战锁有辨识度；只有歼灭一种胜利条件，没有高低差、朝向、战争迷雾、天气、撤销、危险区 | FE 三房/Engage、三角战略 |
| 佣兵 / 经济 | 5 | 月饷、粮耗、仓耗真实存在；没有永久死亡和伤病树，种子 91 的百年模拟里 0 个见底年 | Battle Brothers |
| 城堡建设 | 3 | 5 栋建筑 × Lv5 只是数字变化，画面不变（`castle_hub.gd` 固定 Stitch 栏） | 诸神皇冠 |
| 联姻 / 血统（模拟） | 8 | 十国十律、121 位点、152 征、继承法从遗传律推出，属于原创亮点 | CK3 |
| 联姻 / 血统（回报） | 4 | 战斗回报主要只有资质区间和 10 个王技，容貌位点几乎只影响立绘 | CK3 / 诸神皇冠 |
| 剧情 / 角色 / 对白 | 1.5 | 模板章、单一具名角色、无选项、无支援对话 | 三房 / 三角战略 |
| 新手引导 | 2 | 只有第零章脚本；`tutorial_highlight` 设置项只存不读 | FE Engage |
| UX / UI 一致性 | 6 | 运行时已统一为 Frost v8.6；残留金色 `#c9a227` 共 25 处，`docs/style-bible.md` 与锁定风格相矛盾 | — |
| 音频 | 1.5 | 3 段单声道 22kHz 程序化循环（9 / 12 / 14 秒）+ 39 个短音效 | 任意商业 SRPG |
| 手感 / juice | 5 | 棋盘有震屏、伤害数字和帧特效；过场 hit-stop 只有暴击一种 | Engage |
| 3D 战斗过场 | 4 | 32 个绑骨 GLB 共用 8 个动作；箭矢是圆柱体；靠换色区分 | FE Engage |
| 美术覆盖 | 3 | 基因立绘 0、城市 39/74、铁匠铺 0/11、物品 0/223、场景 15 | — |
| 性能 | 4 | 启动时解析 235 个章节 JSON；77 张 PNG 超过 3MB；没有任何性能门禁 | — |
| 存档 / 读档 | 3 | 单槽，没有原子写和备份；存档里嵌入整份 `world_v87` | — |
| 移动端 | 5 | 触控路由、安全区、44dp 做得认真；Android 预设没开 ETC2/ASTC，Gradle 模板不在仓库，包体失控 | — |
| 本地化 | 1 | `locale.gd` 只有约 56 个 key；约 6,000 个中文字面量硬编码在 `.gd` 里 | — |
| 无障碍 | 2 | 只有文字速度和减弱动效；没有色盲模式和字号缩放 | 三房 / BB |
| 内容体量（按质量折算） | 2 | 400 张图大多是 11×7 的歼灭战；有效内容大约只够 6–8 小时 | 30–50h 目标 |
| 技术债 / 测试 | 4 | 断言型 e2e 质量不错；战斗公式、AI、经济曲线、存档损坏、性能都没有单测；CI 未上线 | — |

---

## 1. 仓库实测基线（全部可复核）

| 项 | 数 | 证据 |
|---|---|---|
| 代码规模（非章节 `.gd`） | ≈33.9k 行 | `find project -name "*.gd" -not -path "*/story/*" \| xargs wc -l` |
| 最大文件 | `battle_controller.gd` 4,215 / `game_state.gd` 3,468 / `world.gd` 1,693 / `bloodline_v89.gd` 1,575 | 同上 |
| 章节 | 235 × (`data/chapterN.json` + `scripts/story/chapterN.gd` + `scenes/story/chapterN.tscn`) | `project/data`、`project/scripts/story` |
| 对白 | 3,486 行 / 878 beat / 10 个说话者 / 1 个具名角色 / 0 个选项 | 子审计脚本统计 |
| 战斗图 | 400 张（主要尺寸 11×7 ×106、10×7 ×77、11×8 ×67；最大 12×9） | `project/data/maps.json` |
| 胜利条件 | 只有「歼灭」 | `battle_controller.gd:3042–3055` `_check_end` |
| 地形 | 6 种（平原/林/丘/水/桥/堡），无高度 | `project/autoload/battle_rules.gd:4–11` |
| 职业 | 9（5 个一阶 → 4 个二阶，二阶的 `promote_to` 为空） | `project/data/jobs.json` |
| 战技 | 36（其中 10 个王技） | `project/data/skills.json` |
| 出战人数 | 3 + 议事厅等级（4–8），UI 文案写「最多四人」 | `game_state.gd:1260–1262`、`castle_hub.gd` 导航 |
| 城市 / 道路 / 货物 / 装备 / 路遇 | 74 / 106 / 17 / 223 / 18 | `project/data/world_v87.json`、`world_items_v87.json` |
| 委托模板 | 7 类 + 73 条名誉委托 | `world_v87.json` |
| 敌对家族 | 3 | `project/data/rival_houses.json` |
| 血统 | 31 条血胤、10 国冕征血律、121 位点、152 征 | `project/data/bloodlines_v89.json`、`docs/design/bloodlines-v89.md` |
| 基因立绘（Plan A） | **0 张**（`assets/art/portraits/genome/` 为空目录） | `ls project/assets/art/portraits/genome` |
| 城市图 | 39 / 74（47 张送审，8 张因饱和度被拒） | `project/assets/art/atlas/cities`、`docs/art/review/atlas_v87_ingest.json` |
| 铁匠铺 / 物品图标 | 0 / 11、0 / 223 | `docs/design/atlas-cities-v87.md` §10 |
| 场景底图 / 庄园图 | 15 / 4 | `assets/art/scenes`、`assets/art/estates` |
| 3D 模型 | 32 个单位 GLB（8 动作：idle/advance/attack/skill/hit/dodge/crit/death）+ 8 个发型模块 | `project/scripts/art/unit_model.gd:12` |
| 音乐 | 3 段：`music_hub` 12s、`music_battle` 9s、`music_castle` 14s，单声道 22.05kHz，程序化生成 | `project/assets/sfx`、`autoload/music.gd` |
| 资产体积 | `project/assets` 794MB；`farm_inbox` 259MB；`doll` 75MB；`.git` 748MB | `du -sh` |
| 导出过滤 | `export_filter="all_resources"`，只排除 `tests/*,*.md` | `project/export_presets.cfg:8–10,49–51` |
| Android 纹理压缩 | 预设里没有 ETC2/ASTC 键（ETC2 只在 Windows 预设里设为 false） | `export_presets.cfg:23–26` |
| CI | `scripts/run_ci.sh` 17 步；**没有** `.github/`；本环境没有 `godot` | `scripts/run_ci.sh:71–74` |
| 存档 | 单文件 `user://century_knights_save.json`，`schema v9.1` | `game_state.gd:547,2876,3163` |
| 本地化 | 约 56 个 key；`Locale.t` 约 61 处调用；中文字面量约 6,000 个 | `project/autoload/locale.gd` |

---

## 2. 分维度审计

每个维度按「现状证据 → 对标差距 → 判断」展开。对标只比**机制类型**，不复制对标作品的文本、数值表和美术。

### 2.1 核心循环与节奏

**现状**
- 第零章的闭环是真实的：起名 → 隘口之夜 → 酒馆 → 灰旗堡 → 联姻 → 初啼 → 丰收手记，`tests/full_chain_e2e.gd`（672 行）有断言覆盖。
- 时间单位是 1 个月（`autoload/calendar.gd:69–170`）：发饷、封地、衰老、妊娠、5 月春令、8 月丰收、3/9 月流言、1 月王室结算。舆图上 30 日翻 1 个月（`world.gd:556–572`）。
- 百年 = 1,200 个月。按 30–50 小时算，平均每个游戏月只有 1.5–2.5 分钟的玩家时间，而岁月沙漏（`hub/hourglass.gd`）允许跳月，节奏密度实际上由玩家自己决定。
- `castle_hub.gd` 第一天就开放 17 个导航入口（出战、名册、酒馆、工坊、市集、祠堂、属地、联姻、族谱、舆图、委托、训练、战技树、工事、沙漏、授旗礼、设置），没有渐进解锁。

**差距**
- 三房按「节」、诸神皇冠按年节庆、CK3 按「人生」组织长线，玩家每段都有阶段性目标。我们没有纪元结构：百年里没有「这一代要完成什么」，也没有纪元反派和纪元高潮。种子 91 模拟（`docs/design/balance-v91.md`）证明经济不会崩，却也说明百年是均匀的平原，没有起伏。
- 系统一次全部开放，新玩家面对 17 个入口无从下手，这正是诸神皇冠这类经营 SRPG 最常见的劝退点。

**判断**：引入「五纪元 × 每代一个王朝志向」的结构（NAR-01、DYN-02），城堡入口按纪元和章节渐进开放（NAR-05、UX-06）。

### 2.2 战术深度（地形、职业、技能、AI、难度）

**现状**
- 地形 6 种，只有移动消耗、回避、防御三项数值（`battle_rules.gd:4–11`）。夹击是「防守方旁边还有我方单位」时命中 +15、伤害 +1（`:72–131`），没有背击和朝向。
- ZoC 与交战锁是本作有辨识度的机制：脱离消耗普通 1、控带内 2、锁定 3（`battle_controller.gd:2149–2154`），棋盘上标注「控 / 脱2 / 锁3」。
- 公式：命中 = 70 + 技 + 敏/2 − 回避，限制在 5–99；伤害 = max(1, 攻 − 防/2) ± 1；暴击 1.5×；敏捷高出 4 点追击（`battle_rules.gd:85–148`）。
- 胜利条件**只有歼灭**（`_check_end`，`battle_controller.gd:3042–3055`）。「护送」只是地图主题和插科打诨（`_is_escort_map` 只判断 `theme == "escort"`，`:630`），系统目录 B09「歼灭/到达/防守」标为 MVP，实际没有实现。
- 失败可以无代价重试：全员回满 HP，旗标保留（`:3100–3107`）。
- 职业 9 个、2 阶，没有三转（系统目录 C07 期望约 20 个职业 × 3 阶）。「克制」是 5 种职能标签矩阵（`battle_rules.gd:18–70`），不是武器体系。
- AI：`tactics_ai.gd` 只有 141 行，是主题权重加技能打分。移动与目标选择在 `_enemy_ai`（`battle_controller.gd:2899–3040`），属于单步贪心，没有多回合规划，也没有集火协同。
- 难度 0–4 由地图 id 推出（`game_state.gd:2316–2344`），主要体现在敌方技能配置上。玩家没有难度选择，没有撤销，也没有全图危险区（只显示所选单位的射程，`battle_controller.gd:1669–1687`）。预测是文字信息加飘字，不是 FE 那种双栏预测面板。

**差距**
- FE 三房和 Engage 的基线是：多种胜利条件、危险区、双栏预测、天刻或类似回溯、约 40 个职业、连携或羁绊加成。三角战略的基线是：高低差、朝向、可互动地形、天气元素。我们在这些点上**全部缺席**。
- 400 张图有 205 张带主题，但规则同构，量大而质薄。出战 4–8 人、地图 11×7，单场的决策空间很小。

**判断**：战斗要从「多图同构」改成「少图异构」。优先级依次是：胜利条件系统（BTL-02）、可读性三件套（危险区、预测、撤销；BTL-03、BTL-04）、难度模式（BTL-05）。之后再做职业树、地形、AI 2.0（BTL-06 到 BTL-08）。

### 2.3 佣兵团与经济

**现状**
- 招募有两个来源：城堡酒馆 3 人（`game_state.gd:1190`），城市酒馆按国度血脉池刷人。月薪 = 6 + 阶 × 3 + 等级 + 血统溢价（`character_factory.gd:80`）。
- 月结：发饷，每人耗粮 1；银不够士气 −15，粮不够士气 −20，孩子获得营养不良（`game_state.gd:2081–2113`）。粮仓腐耗的说明见 `balance-v91.md`。
- 委托：舆图 7 类（递送、护送、追缉、清剿、驰援、收购、打探），每城 2–5 条，最多同时 5 条；城堡只有 11 条硬编码任务（`game_state.gd:1214–1238`）。
- 伤病：击倒后 `injured = true`，祠堂或丰收时清除。出战界面只把带伤者着色，不阻止出战（`deploy.gd:159`）。**没有永久死亡**，只有 70 岁老死（`calendar.gd:106–109`）。

**差距**
- Battle Brothers 的灵魂是「每个人都可能死，每场仗都算账」：永久伤、阵亡、逃兵、欠饷哗变。诸神皇冠也有临时伤和永久伤（系统目录 B12/B13）。我们这里伤病只是一个能洗掉的旗标。
- 种子 91 跑完百年，年末银 5,774、峰值 6,851，0 个见底年（`balance-v91.md:20`）。经济能撑住是好事，但这意味着中后期没有压力。现在的门禁只看「年末」这一个时间点。

**判断**：做伤病表、经典与休闲两种模式（CMP-01），把经济门禁改成按纪元的压力曲线（CMP-02），再加对手佣兵团和委托链（CMP-04）。

### 2.4 城堡建设

**现状**：5 栋建筑（议事厅、校场、市集、工坊、祠堂）× Lv5，升级费用 80/160/280/450 银外加铁和粮（`game_state.gd:519,1241–1255`）；4 块封地 Lv1–3（`hub/estates.gd`）。城堡页面是固定的 Stitch 布局（`castle_hub.gd:20–70`），**升级之后画面不变**。

**差距**：诸神皇冠和大多数经营类游戏，都靠「看着自己的城长起来」提供长线满足感。系统目录里的 F05 多城堡、F07 多神庙也没有做。

**判断**：做分层合成的城堡可视成长（CMP-03 写代码和占位图，FARM-05 出正式图），新增 4 栋功能建筑（医所、书院、宝库、使馆），分别把伤病、教育、传家宝、外交接入城堡。

### 2.5 联姻、血统、遗传的回报

**现状**
- 有两层基因组。`CKGenome`（v8.7）是 5 个孟德尔位点加多基因面型（`genome.gd:8–18`）。`CKBloodline`（v8.9）是 10 个冕征位点、111 个禀性位点和 12 种遗传律（`bloodline_v89.gd:12`）。继承法从遗传律推出（`bloodlines-v89.md` §0、§2.4），这是真正原创而且有深度的设计。
- 回报链：`blood_mix` → 六维资质区间 → 派生属性（`character.gd:70–104`），以及显冕 → 10 个王技之一（`bloodline_v89.gd:1024–1039`）。禀性加成很小（例如 `sturdy` +8% HP）。
- 妊娠固定 1 个月（`lineage.gd:79–81`）。敌对家族只有 3 个。v8.7 遗留的 `bloodlines.json`（4 行）和 `CKGenome.BLOOD` 回退表，与 v8.9 的 31 条血胤并存。

**差距**
- CK3 的血统回报是「特质 → 可见的能力和政治后果 → 家族目标」。诸神皇冠的回报是「血统特征 → 显眼的战斗强度」。我们的模拟复杂度远高于玩家能感受到的战斗差异，大部分位点只是立绘 DNA。
- 没有王朝志向，没有先祖碑（D17 标为 POST），也没有「为了某个目标去配婚」的明确奖励回路。

**判断**：做血统战斗回报（DYN-01）：让约 20 个禀性有战术效果，王技按纯度和合子型分阶，子嗣预测里显示战斗投影。再加王朝志向（DYN-02）、十国敌对家族（DYN-03）、人生事件（DYN-04）。**锁定数字不能动**：`GENOME PASS silver=0.237 midparent_width=0.064`、`KINSHIP PASS mean=0.839 silver_skip=0.156`，以及 `CKGenome.cross` 的抽签顺序。

### 2.6 剧情、角色、对白

**现状**
- 体量统计见第 1 节。第 0 章和第 1 章是手写的。从大约第 2 章开始是克隆结构，例如：
  - ch150：「二十四卷要在雪印战场盖上中段印」…「第二十四卷中段完成（v4.7）」
  - ch234：「三十八卷要在瓷印战场盖上中段印」…「第三十八卷中段完成（v6.1）」
- 全语料里「第#章完成」出现 151 次，「第#卷中段」51 次，「印若已落，便可回堡…」35 次。
- `chapter150.gd` 和 `chapter230.gd` 去掉数字后差异很小（都是 78–79 行的同一套脚手架，只有 id、地图和赏银不同）。
- 系统目录把 A05「第一章及以后」和 A06「重大抉择」都标为 POST，但 v1–v6 的发布节奏是每版加约 3 章（`docs/release-v1.*` 到 `v6.*`），在 MVP 之外堆出了 234 章。

**差距**：三房和三角战略的叙事基线是：具名同伴 10–30 人、每人有弧线、支援对话、关键选择会改变后续剧情。我们在这些方面几乎是零。系统口吻的对白（卷号、版本号）会直接破坏沉浸。

**判断**：**冻结 235 章，改成数据驱动的单一章节播放器**（NAR-02）。写故事圣经和五纪元约 40 章的主线脊柱（NAR-01），然后按纪元重写（NAR-03、NAR-06、NAR-07）。旧章节归档为「旧卷档案」，不再计入主线。另加对白 lint，禁止卷号和版本号进入对白（NAR-08）。

### 2.7 新手引导

**现状**：第零章脚本就是全部引导。设置里的「新手高亮指引」只有 `settings.gd:46–48` 写入和 `game_state.gd:512` 默认值，全仓库**没有任何地方读取它**。`bloodline_codex` 是血统百科，不是玩法帮助。

**差距**：Engage 有一套「首次接触提示 + 可重看教程库」。我们的系统更多，引导反而更少。

**判断**：做引导引擎（coach mark 遮罩、首次提示注册表、系统百科，UX-01），配合渐进解锁的内容（NAR-05）。

### 2.8 UX / UI 一致性

**现状**
- 运行时统一用 `UIKit` + `frost.gd` → `assets/ui/theme.tres`，`RETIRE_CHROME := true` 关掉了 v8.5 的绘制边框。这一块已经比较统一。
- 残留问题：
  - 默认纹章色是 `#c9a227`（`game_state.gd`、`story/naming.gd`）。
  - 富文本里的金色 `[color=#c9a227]` 共 25 处（`hourglass.gd`、`lineage_rite.gd`、`rival_houses.gd`、`skill_tree.gd`、`battle_controller.gd`）。
  - 战斗信息面板里有 `#ff6b4a`、`#e07070`、`#8ecae6` 等硬编码色值（`battle_controller.gd:4172–4178`）。
  - `docs/style-bible.md` 仍在写灰金 `#c9a227`、旗红和羊皮纸文字色，**和锁定风格直接矛盾**。
  - `UIKit.PARCHMENT` 命名残留。
- 信息架构：26 个 hub 场景平铺，没有「本月待办」汇总。

**判断**：做风格 ratchet 门禁（INF-07，色值数只许减不许增）、重写 style-bible（UX-05），以及信息架构的分组和待办中心（UX-06）。

### 2.9 音频

**现状**：3 段音乐，单声道 22.05kHz，9、12、14 秒循环（`music.gd` 注释写明是程序生成）。39 个短音效，没有总线分层、流式 OGG 或自适应层；设置里只有开关，没有音量滑条。

**差距**：一局 30–50 小时，战斗音乐每 9 秒重复一次，会听几千遍。这是所有维度里性价比最高的短板。

**判断**：先做音乐导演系统（交叉淡入、场景状态层、总线、ducking），再充实曲库，目标至少 12 首、每首 90 秒以上（AUD-01）。正式曲目要外包作曲或本地生成，卡里标为 `needs_external_audio`。代理能交付的是系统，加上一套比现状明显更好的程序化合成占位曲（双声道 44.1kHz、≥60 秒、有段落）。

### 2.10 手感 / juice

**现状**：棋盘震屏用的是 trauma² 曲线（`battle_controller.gd:852–861`），有伤害数字（`:1728–1740`）、斩击/暴击/火花帧和回合横幅，音效覆盖命中、未命中、暴击、技能、治疗、移动、回合。过场里 hit-stop 只在暴击时触发（`combat_cutscene.gd:467–471`，`time_scale = 0.35`）。

**差距**：缺少按武器重量区分的 hit-stop、移动端触感（haptics）、可配置的震屏强度（无障碍需要），以及 UI 层统一的按压反馈。

**判断**：CUT-05（过场受击反馈）加 UX-09（UI juice 和触感）。

### 2.11 3D 战斗过场质量

**现状**：`combat_cutscene.gd`（519 行）用 SubViewport + World3D，地面是贴图四边形，镜头只做 FOV 补间，带黑边 HUD，可跳过，有 1× / 2× 速度。32 个 GLB 共用 8 个动作。远程攻击的投射物是程序化圆柱体（`:376–400`）。敌人大多是 `bandit_axe` / `bandit_bow` 换色（`unit_model.gd:116–154`）。一次交锋要好几秒。

**差距**：FE Engage 的过场标准是：每个职业有自己的动作、镜头有模板、技能有专属演出，而且可以随时关闭或只看关键演出。

**判断**：先做节奏预算和播放模式（CUT-01），再补镜头模板（CUT-03）、投射物和王技特效（CUT-04）、职业动作原型库（CUT-02）。新网格和坐骑要农场（FARM-06）。

### 2.12 美术覆盖缺口（缺失或占位）

| 类别 | 有 | 需要 | 现在的回退方案 |
|---|---|---|---|
| Plan A 基因立绘 | 0 | 预制角色 × 5 阶段 + **运行时出生者的分桶库**（估计 4–6k 张） | `hireuniq` 781 张、v8 胸像、geno、程序立绘 |
| 对话表情差分 | 0 | 12 名同伴 × 5 种表情 | 无 |
| 城市图 | 39 | 74（另需重绘 8 张被拒的） | 国度板块裁切 |
| 铁匠铺内景 / 物品图标 | 0 / 0 | 11 / 223 | 程序化玻璃字形 |
| 剧情场景底图 | 15 | 约 50（40 章主线 + 关键事件） | 复用 |
| 庄园 / 城堡分层图 | 4 / 0 | 封地 × 等级 / 5 栋 × 3 阶 + 底图 | 无 |
| 3D 敌军派系 | 换色 | 10 国 × 至少 2 种轮廓 | 换色 |
| 新职业单位与棋子 | — | 约 11 个新职业（配合 BTL-06） | 无 |
| 坐骑 | 0 | 骑兵 | 骑兵没有马 |
| 音乐 | 3 段短循环 | ≥12 首 | — |

**仍在仓库里的遗留资产**：`farm_inbox` 259MB 的原始出图；已退役的纸娃娃 `doll/` 75MB；`hireface_*` 600 张和等位组合图 436 张（代码已跳过，但文件还在）；按金色纹章色键入的旗帜（`banner_c9a227_w*.png`）。

### 2.13 性能

**现状**
- `GameState._load_data()` 每次启动都会 `FileAccess` + `JSON.parse` 全部 235 个章节文件（`game_state.gd:568–820`）。
- `load(` 约 89 处，`preload(` 只有 9 处。77 张 PNG 超过 3MB（例如 `lineage_backdrop.png` 4.7MB）。
- 仓库里没有任何启动时间、帧率或内存门禁。性能预算只存在于过场（`device_profile.gd:73–102`）。

**判断**：章节懒加载（CORE-01）、性能基线和门禁（INF-03）、资产瘦身（ART-02、INF-02）。

### 2.14 存档 / 读档

**现状**
- 单槽 JSON（`game_state.gd:547`）。`save_game` 逐个列出 `chapter0_beat` 到 `chapter234_beat`（`:2876–3118`）。
- 迁移只覆盖 v8.7 / v8.8 → v9.1（`:2814–2850`）。解析失败直接返回 false，没有备份，没有原子写，没有自动存档。存档里嵌入整份 `world_v87` 静态数据。
- 没有暂停菜单。Android 切到后台时不会保存（没有处理 `NOTIFICATION_APPLICATION_PAUSED`）。

**判断**：一个 100 年的战役只靠一个没有备份的单槽，是事故级风险。做存档 2.0（CORE-03）、自动存档与暂停菜单（CORE-04）、存档差量化（CORE-07）。

### 2.15 移动端

**现状**：`device_profile.gd`、`input_router.gd`、`mobile_layout.gd` 和 `mobile_chrome.gd` 做得认真（44dp、安全区、低端机降级过场），README 里也有手测清单。

**问题**
- Android 预设缺少纹理压缩设置。
- `project/android/` 只有 `signing.example.env`，没有 Gradle 模板。
- `all_resources` 导出会把 farm_inbox 和纸娃娃打进包。
- 没有 iOS（README 明确不在范围内）。

**判断**：INF-02（包体瘦身和预设）、INF-05（Android 构建 job）、UX-08（竖屏和触控覆盖自动扫描）。

### 2.16 本地化

**现状**：`locale.gd` 只有约 56 个 zh_CN key。全仓库约 6,000 个中文字面量（约 5,900 个在玩法代码里），`Locale.t` 只有约 61 处调用。没有 `.csv` 或 `.po` 文件。字体是 GB2312 子集加项目扫描（`tools/fonts/subset_fonts_v86.py`），新写的生僻字有变成豆腐块的风险。

**判断**：做 CSV 翻译管线、按流拆分翻译文件、i18n ratchet 门禁（UX-03、INF-08），字体覆盖纳入 CI（UX-04）。英文先覆盖 UI 外壳，剧情的英文放到 P2。

### 2.17 无障碍

有：文字速度、减弱动效、过场开关和倍速、规则透视。
缺：色盲模式（薄荷和珊瑚在红绿色弱下难以区分，**而这正是本作的敌我主编码**）、字号和 UI 缩放、高对比度、震屏强度、按住与点按的切换（UX-02）。

### 2.18 30–50 小时所需内容体量

按「质量折算」估算：一张同构的 11×7 歼灭图约等于 0.1 张有效关卡，一个 14 行的模板章约等于 0.05 章有效剧情。

| 内容 | 现有（折算后） | 30–50h 目标 | 对应卡 |
|---|---|---|---|
| 主线章节（作者稿） | 2（ch0、ch1） | 40（5 纪元 × 8 章） | NAR-01/03/06/07 |
| 支线 / 人物事件 | ≈0 | 20 条支线 + 60 张人生事件卡 | NAR-04、DYN-04 |
| 具名同伴 | 1 | 12（每人 3 段弧线节点） | NAR-01/04 |
| 支援对话 | 0 | 40 段起步，目标 80 | NAR-04 |
| 手调关卡（带胜利条件） | ≈0 | 60（主线 40 + 支线 20），尺寸 10×8 到 18×14 | BTL-02、NAR-03/06/07 |
| 程序化遭遇（舆图） | 有 | 保留，按 BTL-02 加入目标多样性 | CMP-04 |
| 职业 / 战技 | 9 / 36 | 约 20 / 约 90 | BTL-06 |
| 路遇事件 | 18 | 48 | CMP-09 |
| 节庆 | 2（春令、丰收） | 5 | CMP-05 |
| 音乐 | 35 秒 | ≥12 首、≥25 分钟 | AUD-01 |
| 立绘 | 0 张基因图 | 分桶库 4–6k + 同伴表情差分 | ART-01、FARM-01/04 |

**节奏模型（目标约 40h）**：主线战斗 40 场 × 18 分钟 ≈ 12h；支线和舆图战斗 40 场 × 10 分钟 ≈ 7h；舆图、贸易、委托 ≈ 9h；城堡、联姻、王朝 ≈ 7h；剧情和支援阅读 ≈ 5h。按纪元算，每代约 8 小时、约 20 年游戏时间，平均每个游戏月约 2 分钟。

### 2.19 技术债与测试缺口

**结构性债务**（几乎没有 TODO，债务藏在结构里）
- `battle_controller.gd`
  - 102 个函数、4,215 行。
  - 约 549 行主题插科打诨常量（`:78–626`）。
  - `_mark_map_victory` 约 800 行、400 个分支（`:3302–4105`）。
  - 主题插科打诨和音效各有一条长 if 梯子（`:636–782`）。
  - `_cast_buff_skill` 与 `_cast_buff_skill_for_team` 是双胞胎实现。
- `game_state.gd`：104 个函数、518 个变量、470 个章节字段。
- `castle_hub.gd`：469 处 `chapterN_done`。
- `world.gd` 1,693 行；`bloodline_v89.gd` 1,575 行（88 个静态函数）。
- 多个版本层并存：`world_v87`、`bloodlines_v89`、`court_v90`、balance v91，加上遗留的 `bloodlines.json`。

**测试**：断言型 e2e 是真的，每个测试 `quit(1)` 并在 CI 里 grep PASS。下列方面**没有覆盖**：
- 战斗公式矩阵（地形 × 夹击 × 克制 × 暴击 × 追击）
- AI 回归
- 按纪元的经济曲线
- 截断或乱码存档
- 启动、帧率、内存
- 235 个章节场景的加载（`scene_load_check` 不加载 story）
- 对白质量
- 视觉回归截图

**CI 本身没有上线**（没有 `.github`，本环境也没有 godot）。

---

## 3. 对标一览：我们弱在哪、缺什么

| 机制（只比机制类型） | 诸神皇冠* | FE 三房 / Engage | 三角战略 | Battle Brothers | CK3 | 我们 |
|---|---|---|---|---|---|---|
| 多胜利条件 | 有 | 有 | 有 | 合同目标 | — | **缺** |
| 危险区 / 预测 / 回溯 | 部分 | 有 | 有 | 部分 | — | **缺** |
| 高低差 / 朝向 / 天气 | — | 部分 | 有 | 高低差 | — | **缺** |
| 职业树规模 | 约 20、三阶 | 约 40 | 固定角色 | 背景 + 技能 | — | 9、二阶 |
| 羁绊 / 支援 | — | 有 | 信念系统 | — | 关系 | **缺** |
| 永久伤 / 阵亡 | 有 | 经典模式 | — | 有（核心） | 有 | **缺** |
| 城堡可视成长 | 有 | 修道院 | — | — | 建筑 | **缺** |
| 跑图贸易 | 弱 | — | — | 有 | — | **强**（超越） |
| 血统遗传可读性 | 强（但我们规避了其外观套路） | — | — | — | 强 | **强**（原创十律） |
| 血统战斗回报 | 强 | — | — | — | 中 | 弱 |
| 王朝目标 / 家族荣誉 | 弱 | — | — | — | 强 | **缺** |
| 节庆 | 5 种 | 节日 | — | — | 活动 | 2 种 |
| 剧情选择 | 有 | 路线分歧 | 核心 | 事件 | 事件 | **缺** |
| 多存档 / 自动存档 | 有 | 有 | 有 | 有 | 有 | **缺** |

\* 只依据 `_bmad-output/planning-artifacts/systems-catalog.md` 里整理的公开机制类型，不引用原作文本、数值或美术。

---

## 4. 并行执行架构

### 4.1 流与文件所有权

**规则：一个文件只归一条流所有。** 其他流需要修改时，在自己的 PR 里写一节「交接」，由所有者流来做。

| 流（parallel_group） | 拥有（可写） | 不可碰 |
|---|---|---|
| **S01-infra** | `.github/**`、`scripts/**`、`tools/ci/**`（新建）、`tools/audit_v840_usage.py`、`project/project.godot`、`project/export_presets.cfg`、`project/android/**`、`.gitignore`、`.gitattributes`、`project/tests/smoke_*`、`project/tests/scene_load_check.gd`、`project/tests/suites/infra/**`、`README.md` | 其他所有玩法代码 |
| **S02-core** | `project/autoload/game_state.gd`、`project/autoload/calendar.gd`、`project/scripts/core/**`（新建）、`project/scripts/ui/main_menu.gd`、`project/scenes/ui/main_menu.tscn`、`project/scenes/ui/{pause_menu,save_slots}.tscn`（新建）、`project/tests/save_roundtrip_check.*`、`project/tests/suites/core/**` | 剧情、战斗、hub 脚本 |
| **S03-battle** | `project/scripts/battle/{battle_controller,battle_maps,tactics_ai}.gd`、`project/scripts/battle/ui/**`（新建）、`project/scripts/battle/enemy_loadout.gd`（CORE-02 之后）、`project/autoload/battle_rules.gd`、`project/data/{maps,jobs,skills,enemy_skill_tables}.json`、`project/data/maps/**`（`story_*.json` 除外）、`project/data/battle_banter.json`（新建）、`project/scenes/battle/battle.tscn`、`project/scripts/hub/{deploy,skill_tree,train}.gd` 及对应 `.tscn`、`project/tests/tactics_e2e.*`、`project/tests/suites/battle/**` | `combat_cutscene.gd`、`unit_model.gd`、`game_state.gd` |
| **S04-cutscene** | `project/scripts/battle/combat_cutscene.gd`、`project/scripts/art/unit_model.gd`、`project/shaders/**`、`project/assets/models/**`、`tools/models/**`、`project/data/enemy_themes.json`、`project/tests/enemy_theme_check.*`、`project/tests/suites/cutscene/**` | `battle_controller.gd` |
| **S05-company** | `project/autoload/world.gd`、`project/data/{world_v87,world_items_v87}.json`、`tools/world/**`、`project/scripts/company/**`（新建；CORE-02 拆出的 `economy_state.gd` 归这里）、`project/scripts/hub/{roster,tavern,forge,market,shrine,quests,works,estates,city,atlas_view,hourglass,castle_view}.gd` 及对应 `.tscn`、`project/scripts/sim/campaign_sim.gd`、`project/tests/{atlas_e2e,campaign_century_check}.*`、`docs/design/balance-*.md`、`project/tests/suites/company/**` | `castle_hub.gd`（属 UX）、`game_state.gd` |
| **S06-dynasty** | `project/autoload/lineage.gd`、`project/scripts/characters/**`、`project/data/{bloodlines,bloodlines_v89,rival_houses,names,appearance,traits}.json`、`project/scripts/hub/{marriage,lineage_view,lineage_rite,inheritance,heir_rivalry,rival_houses,court_news,bloodline_codex,blood_test,unit_dossier,title_promote,ancestors}.gd` 及对应 `.tscn`、`project/scripts/ui/court_chrome.gd`、`tools/{check_bloodlines_v89,gen_trait_sets_v89}.py`、`project/tests/{genome_check,bloodline_v89_check,court_v90_check,court_ui_check,trio_*}.*`、`project/tests/suites/dynasty/**` | `genome_portrait.gd`（属 art）、`game_state.gd` |
| **S07-narrative** | `project/scripts/story/**`、`project/scenes/story/**`、`project/data/chapter*.json`、`project/data/story/**`、`project/data/cast/**`（新建）、`project/scripts/narrative/**`（新建）、`project/tests/full_chain_e2e.*`、`project/tests/suites/narrative/**`、`docs/design/story-*.md` | `maps.json`（故事图写进 `data/maps/story_*.json`，靠 BTL-01 的多文件加载器读取） |
| **S08-ux** | `project/autoload/{frost,locale,mobile_chrome}.gd`、`project/scripts/ui/{ui_kit,ui_fx,unit_card,settings,credits}.gd`、`project/scripts/ui/widgets/**`（新建）、`project/scripts/platform/**`、`project/scripts/hub/castle_hub.gd`、`project/scenes/hub/castle_hub.tscn`、`project/scenes/ui/{settings,credits}.tscn`、`project/assets/ui/**`、`project/assets/fonts/**`、`tools/fonts/**`、`project/data/locale/strings.csv`（并负责注册各流的 csv）、`docs/style-bible.md`、`docs/art/design-system-v8.md`、`docs/licenses.md`、`project/tests/{layout_check,touch_router_check}.*`、`project/tests/suites/ux/**` | 各 hub 的业务脚本 |
| **S09-audio** | `project/autoload/{music,sfx}.gd`、`project/assets/sfx/**`、`project/assets/music/**`（新建）、`tools/audio/**`（新建）、`project/assets/music/LICENSES.md`、`project/default_bus_layout.tres`（新建）、`project/tests/suites/audio/**` | 其余全部 |
| **S10-art** | `project/scripts/art/{unit_art,genome_portrait,portrait_doll,atlas_art}.gd`、`project/assets/art/**`（不含 `genome/` 的正式出图）、`tools/art/**`、`tools/farm_queue/**`、`tools/farm_v87/**`、`tools/fx/**`、`docs/art/**`（`design-system-v8.md` 与 `review/` 除外）、`project/tests/{portrait_manifest_check,kinship_portrait_check}.*`、`project/tests/suites/art/**` | 玩法代码 |
| **S11-farm**（本地，暂停） | `project/assets/art/portraits/genome/**`、`assets/art/atlas/cities/**`、`assets/art/atlas/smith/**`、`assets/art/items/**`、`assets/art/scenes/**`、`assets/art/estates/**`、`assets/art/castle/**`、`assets/models/**`（新 GLB）、`docs/art/review/**` | 代码 |

### 4.2 全局规则（每条流都必须遵守）

1. **不新增 autoload**（`project.godot` 只归 infra）。新模块一律用 `class_name` 加静态函数，或者挂成现有 autoload 的子节点。
2. **不改 `scripts/run_ci.sh`。** INF-01 之后，CI 会自动发现 `project/tests/suites/<流>/*_check.tscn` 和 `*_check.gd`。每个用例必须打印 `<NAME> PASS`，失败时 `quit(1)`。INF-01 合并之前，先把测试放进自己流的 suites 目录，合并后自动接入。
3. **新字符串**写进 `project/data/locale/<流>.csv`（`keys,zh_CN,en`；`en` 可以先留空）。不要改别人的 csv。
4. **锁定数字不能动**，除非卡片明确要求重新调参：`GENOME PASS silver=0.237 midparent_width=0.064`、`KINSHIP PASS mean=0.839 silver_skip=0.156`、种子 91 百年的各项目标带（`docs/design/balance-v91.md`）。确需调整的卡（CMP-02、DYN-05）必须同时更新 balance 文档和门禁，并写清理由。
5. **风格锁**：只用 `UIKit` / `Frost` 的色彩 token。新代码里不许出现 `#c9a227`、parchment、金色或暖光。美术提示词一律走 `style-lock-v89.json` 的前缀和负面词，入库前过 `tools/art/style_check_v87.py`。
6. **原创 IP**：不搬运对标作品的资产、文本、角色名、地名、数值表。外部素材必须是自己生成的，或者有许可证清单（`docs/licenses.md`）。
7. **版本号和发布说明**（`docs/release-*.md`、导出版本字段）由负责人统一处理，流内不改。
8. **第 0 波例外**：CORE-02 会新建 `scripts/company/economy_state.gd`、`scripts/battle/enemy_loadout.gd`、`scripts/characters/family_state.gd`，合并后分别移交 S05、S03、S06。在那之前，这三条流不得创建同名文件。
9. **一张卡一个 PR**（S 号的小卡允许两张合并）。PR 正文用中文，结构是：做了什么 / 验收逐条对照 / CI 输出末尾 / 截图 / 没做的部分 / 交接。

### 4.3 波次与依赖

```
第 0 波（先合并，越快越好）
  INF-01 真 CI + 自动发现 ──────┐
  CORE-01 章节状态表化 ─────────┼──> 解锁 NAR-02、UX-06
  CORE-02 GameState 领域拆分 ───┘──> 解锁 CMP-01/02、BTL-05、DYN-01 中需要碰 game_state 的部分

第 1 波（与第 0 波同时开工，只做不依赖第 0 波的卡）
  S03 BTL-01 → BTL-02 → BTL-03 → BTL-04 …
  S04 CUT-01 → CUT-03 → CUT-04 …
  S05 CMP-09、CMP-04（world.gd 内部）…
  S06 DYN-08 → DYN-01 …
  S07 NAR-01（纯文档 + 数据）→ NAR-08 …
  S08 UX-01、UX-02、UX-04 …
  S09 AUD-01 → AUD-02 …
  S10 ART-01 → ART-02 → ART-03 …

农场波（农场恢复后）
  FARM-01（依赖 ART-01 的清单）→ FARM-02 … FARM-07
```

已知外部冲突：草稿 PR #9（v9.1.0-art，改了 `project/export_presets.cfg` 和 `scripts/build_windows.sh`）应先合并或关闭，INF-02 再动导出预设。

---

## 5. 前十 P0（按顺序）

1. **INF-01**：上线真 CI（GitHub Actions + Godot 4.3 headless + 测试自动发现）。现在所有「CI 绿」都没法复核。
2. **CORE-01**：GameState 章节状态表化。删掉 470 个章节字段，章节懒加载，旧存档兼容。
3. **CORE-03**：存档 2.0。3 个手动槽 + 自动档 + 原子写 + `.bak` 轮换 + 损坏回退。
4. **NAR-02**：数据驱动章节播放器。用一个场景替换 235 套 `gd/tscn`，模板章归档冻结。
5. **NAR-01**：故事圣经与五纪元约 40 章主线脊柱，外加 12 名具名同伴。
6. **BTL-02**：胜利 / 失败条件系统（占领、防守、生存、护送、斩首、撤离、保护）+ 目标 HUD。
7. **BTL-03 + BTL-04**：危险区、双栏预测、回合内撤销与限次回溯。
8. **ART-01**：Plan A 发货覆盖架构「基因立绘分桶库」。让运行时出生的子嗣也有 Qwen 立绘。
9. **CMP-01**：伤病表 + 经典（永久死亡）/ 休闲模式，补上佣兵团的代价。
10. **INF-02 + ART-02**：包体瘦身。把 farm_inbox、纸娃娃和退役立绘移出导出，Android 开启 ETC2/ASTC，加包体预算门禁。

其余 P0：CORE-02（领域拆分，第 0 波）、BTL-01（战斗控制器拆分阶段 1，是 BTL-02 的前置）、NAR-03（第一纪元 8 章作者稿）、UX-01（引导引擎）、DYN-01（血统战斗回报）、AUD-01（音乐系统与曲库）、CORE-04（自动存档 + 暂停菜单 + Android 后台保存）、FARM-01（基因立绘库出图，农场）。

---

## 6. Backlog 摘要

完整字段见 `docs/plan/backlog-v92.json`：`id / title / priority / why / scope / files / acceptance / dependencies / needs_farm / size / parallel_group`。

| 流 | P0 | P1 | P2 | 依赖农场 |
|---|---|---|---|---|
| S01-infra | INF-01, INF-02 | INF-03, INF-04, INF-05, INF-07, INF-08 | INF-06 | — |
| S02-core | CORE-01, CORE-02, CORE-03, CORE-04 | CORE-05, CORE-06 | CORE-07, CORE-08 | — |
| S03-battle | BTL-01, BTL-02, BTL-03, BTL-04 | BTL-05, BTL-06, BTL-07, BTL-08, BTL-09, BTL-10, BTL-12 | BTL-11, BTL-13 | — |
| S04-cutscene | — | CUT-01, CUT-02, CUT-03, CUT-04, CUT-05, CUT-07 | CUT-06 | CUT-06（依赖 FARM-06） |
| S05-company | CMP-01 | CMP-02, CMP-03, CMP-04, CMP-05, CMP-07, CMP-09 | CMP-06, CMP-08 | CMP-03 的正式图在 FARM-05 |
| S06-dynasty | DYN-01 | DYN-02, DYN-03, DYN-04, DYN-05, DYN-06, DYN-08 | DYN-07 | — |
| S07-narrative | NAR-01, NAR-02, NAR-03 | NAR-04, NAR-05, NAR-06, NAR-07, NAR-08 | NAR-09 | 背景和表情图在 FARM-04 |
| S08-ux | UX-01 | UX-02, UX-03, UX-04, UX-05, UX-06, UX-08, UX-09 | UX-07 | — |
| S09-audio | AUD-01 | AUD-02, AUD-03 | AUD-04 | 正式曲目需外部作曲 |
| S10-art | ART-01, ART-02 | ART-03, ART-04, ART-05 | ART-06 | — |
| S11-farm | FARM-01 | FARM-02, FARM-03, FARM-04, FARM-05, FARM-06 | FARM-07 | **全部** |

---

## 7. 每条流的执行提示词（可直接粘贴）

以下每段都是自包含的。把一段粘贴给一个 Grok 4.7 云代理即可，农场那段交给本地农场机。

### 7.0 公共前言（已嵌入下面每一段，无需单独粘贴）

> 你在仓库 `wuyongjia666-droid/CenturyKnights` 工作。这是 Godot 4.3 的原创 SRPG《百年骑士 / CenturyKnights》：战棋 + 佣兵团 + 城堡 + 联姻传代 + 跑图贸易，2D 棋盘加 FE 式 3D 战斗过场。
> 开工前先通读 `docs/plan/audit-v92.md` 和 `docs/plan/backlog-v92.json`，找到属于你这条流的卡，按 `dependencies` 的顺序做。
> **风格锁**：2026 当代奇幻、磨砂玻璃、霜青 `#6ED4FF`、薄荷 `#5EE0B5`（友）、珊瑚 `#FF7A70`（敌），墨蓝底，见 `docs/art/style-lock-v89.json`。禁止中世纪、羊皮纸、棕褐、鎏金、暖金光。颜色只通过 `UIKit` / `Frost` 的 token 使用。
> **原创**：不搬运对标作品的任何资产、文本、名字或数值。
> **文件所有权**：只改审计文档 §4.1 里你这条流拥有的文件。需要改别人的文件时，在 PR 里写「交接」节，不要自己动手。不新增 autoload，不改 `scripts/run_ci.sh`，新测试放进 `project/tests/suites/<你的流>/`，打印 `<NAME> PASS`，失败时 `quit(1)`。新字符串写进 `project/data/locale/<你的流>.csv`。
> **锁定数字**：`GENOME PASS silver=0.237 midparent_width=0.064`、`KINSHIP PASS mean=0.839 silver_skip=0.156`、种子 91 百年目标带（`docs/design/balance-v91.md`）。除非卡片要求，否则不能动。
> **CI**：环境里没有 godot 时，先运行 `scripts/install_godot.sh`（INF-01 之后才有）。在那之前手动下载 `https://github.com/godotengine/godot/releases/download/4.3-stable/Godot_v4.3-stable_linux.x86_64.zip`，解压后链接为 `godot`。然后执行 `cd project && godot --headless --import`（或 `godot --headless --editor --quit`）完成首次导入，再运行 `./scripts/run_ci.sh`。最后一行必须是 `CI ALL PASS`。
> **交付**：一张卡一个 PR。从最新的 `main` 切分支。不改版本号，不写 `docs/release-*.md`。PR 正文用中文，结构是：做了什么 / 验收逐条对照（引用 backlog 的 acceptance）/ CI 输出末尾 20 行 / 截图（有 UI 变化时）/ 没做的部分 / 交接。

### 7.1 S01-infra（CI、包体、性能、门禁）

```
你是 CenturyKnights 的基础设施工程师。仓库 wuyongjia666-droid/CenturyKnights（Godot 4.3）。
先读 docs/plan/audit-v92.md（重点 §1、§2.13、§2.15、§2.19、§4）和 docs/plan/backlog-v92.json 中 parallel_group=="S01-infra" 的卡。
按顺序做：INF-01 → INF-07 → INF-08 → INF-02 → INF-03 → INF-05 → INF-04 → INF-06。

硬性要求：
- 你拥有：.github/**、scripts/**、tools/ci/**、tools/audit_v840_usage.py、project/project.godot、project/export_presets.cfg、project/android/**、.gitignore、.gitattributes、project/tests/smoke_*、project/tests/scene_load_check.gd、project/tests/suites/infra/**、README.md。其他文件一律不改，需要改就在 PR 里写「交接」。
- INF-01：新增 scripts/install_godot.sh（下载 Godot 4.3-stable linux 并校验 SHA256，可重复执行）、.github/workflows/ci.yml（PR 和 push main 时触发，缓存 godot 与 .godot/imported，先 import 再执行 scripts/run_ci.sh）。run_ci.sh 增加自动发现 project/tests/suites/*/ 下的 *_check.tscn / *_check.gd，逐个运行并 grep "PASS"。如果推送 workflow 文件因 token 缺 workflow 权限被拒，把文件放到 docs/ci/ci.yml.template，在 PR 里写明需要负责人手动复制，并把这一点列为未完成项。
- INF-02：草稿 PR #9 也改了 export_presets.cfg，先确认它已合并或已关闭再动。export 改为排除 farm_inbox/、doll/、stitch_exports/、_src_*/ 以及 ART-02 清单里的退役资产；Android 预设开启 ETC2/ASTC。新增 tools/ci/export_size_report.py，计算预计导出体积，超过预算（初始 400MB，目标 250MB）就让 CI 失败。
- INF-07 / INF-08：tools/ci/style_lint.py（统计 .gd 里的 #c9a227、parchment 和 UIKit 之外的硬编码 #RRGGBB）和 tools/ci/i18n_ratchet.py（统计没有走 Locale 的中文字面量）。基线写进 tools/ci/ratchet.json，数值只许降不许升。
- 风格锁：2026 当代奇幻、磨砂玻璃、霜青/薄荷/珊瑚，禁止中世纪、羊皮纸、鎏金（docs/art/style-lock-v89.json）。
- 不新增 autoload，不改玩法代码，不改版本号，不写 release 说明。
- 每张卡一个 PR，./scripts/run_ci.sh 必须以 "CI ALL PASS" 结束。PR 正文用中文：做了什么 / 验收逐条对照 / CI 末尾 20 行 / 没做的部分 / 交接。
```

### 7.2 S02-core（状态、存档、主菜单）

```
你是 CenturyKnights 的核心状态与存档工程师。仓库 wuyongjia666-droid/CenturyKnights（Godot 4.3）。
先读 docs/plan/audit-v92.md（§2.13、§2.14、§2.19、§4）和 backlog-v92.json 中 parallel_group=="S02-core" 的卡。
顺序：CORE-01 → CORE-02 → CORE-03 → CORE-04 → CORE-05 → CORE-06 → CORE-07 → CORE-08。CORE-01 和 CORE-02 属于第 0 波，其他流在等，优先尽快合并。

硬性要求：
- 你拥有：project/autoload/game_state.gd、project/autoload/calendar.gd、project/scripts/core/**、project/scripts/ui/main_menu.gd、project/scenes/ui/main_menu.tscn、新建的 pause_menu/save_slots 场景、project/tests/save_roundtrip_check.*、project/tests/suites/core/**。
- CORE-01：不准编辑 235 个 scripts/story/chapterN.gd（归 narrative）。在 GameState 里用 _get/_set 做兼容垫片，让 GameState.chapterN_beat / data_chapterN 的读写继续可用，底层改成 story 字典，章节 JSON 按需加载。旧 v9.1 存档读入后无损迁移。
- CORE-02：纯重构，行为必须完全一致。把经济、敌方配置、家庭这三块拆到 scripts/company/economy_state.gd、scripts/battle/enemy_loadout.gd、scripts/characters/family_state.gd，GameState 保留转发函数。campaign_century 的种子 91 数字必须逐项相同（银 5774、粮 280、5 代、15 次出生等）。拆出的文件合并后归 company / battle / dynasty 流所有，在 PR 里写明交接。
- CORE-03 / CORE-04：多槽存档、原子写（先写 .tmp 再 rename）、.bak 轮换 3 份、解析失败时回退到 .bak，并有截断、乱码、v8.7、v8.8、v9.1 五种 fixture 测试。自动存档时机：月结、战前、战后、Android 的 NOTIFICATION_APPLICATION_PAUSED。暂停菜单要处理 Esc 和 Android 返回键。
- 锁定数字：GENOME/KINSHIP PASS 和种子 91 目标带不能动。
- 风格锁：Frost UI token（UIKit），霜青/薄荷/珊瑚，禁止羊皮纸和金色。新字符串写进 project/data/locale/core.csv。
- 不新增 autoload，不改 scripts/run_ci.sh。新测试放进 project/tests/suites/core/，打印 "<NAME> PASS"。
- 每张卡一个 PR，./scripts/run_ci.sh 以 "CI ALL PASS" 结束。PR 正文用中文：做了什么 / 验收逐条对照 / CI 末尾 / 截图 / 没做的部分 / 交接。
```

### 7.3 S03-battle（战术深度与可读性）

```
你是 CenturyKnights 的战斗设计兼工程师，目标是让棋盘达到 FE 三房 / Engage、三角战略的可读性与深度，但机制必须是原创实现。仓库 wuyongjia666-droid/CenturyKnights（Godot 4.3）。
先读 docs/plan/audit-v92.md（§2.2、§2.10、§2.19、§3、§4）和 backlog-v92.json 中 parallel_group=="S03-battle" 的卡。
顺序：BTL-01 → BTL-10 → BTL-02 → BTL-03 → BTL-04 → BTL-12 → BTL-05（依赖 CORE-02）→ BTL-08 → BTL-07 → BTL-06 → BTL-09 → BTL-11 → BTL-13。

硬性要求：
- 你拥有：scripts/battle/{battle_controller,battle_maps,tactics_ai}.gd、scripts/battle/ui/**、autoload/battle_rules.gd、data/{maps,jobs,skills,enemy_skill_tables}.json、data/maps/**、data/battle_banter.json、scenes/battle/battle.tscn、scripts/hub/{deploy,skill_tree,train}.gd、tests/tactics_e2e.*、tests/suites/battle/**。不准碰 combat_cutscene.gd、unit_model.gd（归 cutscene 流）和 game_state.gd（归 core 流）。
- BTL-01 先做「黄金快照」：用旧代码为 400 张图各导出一份胜利旗标、赏银、解锁结果，存为 fixture；重构后逐图比对必须完全一致。插科打诨常量移到 data/battle_banter.json，400 分支的 elif 改成 maps 数据字段 on_victory。新增信号 unit_downed(char, info) 和 battle_finished(result)。battle_maps.gd 支持加载 data/maps/*.json，narrative 流会在那里放故事图。
- 棋盘保持 2D；手机上的长按、单指平移、双指缩放不能退化（tests/touch_router_check 必须通过）。
- 锁定数字：种子 91 百年目标带不能动。如果公式改动导致模拟变化，在 PR 里写「交接」给 company 流，不要自己改 campaign_sim.gd。
- 风格锁：敌我只用 UIKit 的 mint/coral token，危险区用珊瑚半透明，禁止新增硬编码色值（style ratchet 会拦）。新字符串写进 data/locale/battle.csv。
- 原创：回溯机制要有自己的名字和规则（例如和本作「灯」的意象结合），不要用「天刻之脉」之类的对标名称。
- 不新增 autoload，不改 run_ci.sh。每张卡一个 PR，CI 以 "CI ALL PASS" 结束，有 UI 变化的卡附截图。PR 正文用中文：做了什么 / 验收逐条对照 / CI 末尾 / 截图 / 没做的部分 / 交接。
```

### 7.4 S04-cutscene（3D 战斗过场）

```
你是 CenturyKnights 的 3D 过场 / 技术美术。目标是让 FE 式过场「短、准、帅」，并且可以关闭。仓库 wuyongjia666-droid/CenturyKnights（Godot 4.3）。
先读 docs/plan/audit-v92.md（§2.10、§2.11）、docs/art/style-lock-v89.json 的 toon_3d 与 cameras 两节，以及 backlog-v92.json 中 parallel_group=="S04-cutscene" 的卡。
顺序：CUT-01 → CUT-03 → CUT-05 → CUT-04 → CUT-07 → CUT-02；CUT-06 等农场恢复。

硬性要求：
- 你拥有：scripts/battle/combat_cutscene.gd、scripts/art/unit_model.gd、shaders/**、assets/models/**、tools/models/**、data/enemy_themes.json、tests/enemy_theme_check.*、tests/suites/cutscene/**。不准碰 battle_controller.gd（过场的输入数据格式由它决定；需要新字段时在 PR 里写交接给 battle 流）。
- 风格锁：toon 两段色阶，阴影 #2A3442，边缘光友军 #6ED4FF / 敌军 #FF7A70，描边 #0A0E14，FOV 28–34。ember 色 #FF8A3D 只能用在火花特效上。禁止暖金光、羊皮纸和任何中世纪暗调。
- 低端机（device_profile 的 low tier）必须有降级路径：GPU 粒子换成 CPU 粒子或直接不播，关闭 MSAA。tests/touch_router_check 里的过场预算表必须通过。
- 每个时序都必须能用 headless 测出来：把时间线做成数据，测试读取总时长，不靠渲染。
- 不新增 autoload，不改 run_ci.sh。新测试放进 tests/suites/cutscene/，打印 "<NAME> PASS"。新字符串写进 data/locale/cutscene.csv。
- 不需要农场的新几何体用程序化网格或现有 GLB 组合；需要新模型就写进 FARM 卡的清单，不要自己从外部下载模型。
- 每张卡一个 PR，CI 以 "CI ALL PASS" 结束，附过场截图或录屏。PR 正文用中文。
```

### 7.5 S05-company（佣兵团、经济、城堡、舆图）

```
你是 CenturyKnights 的经营系统设计兼工程师。目标是 Battle Brothers 级别的「每场仗都算账」，同时保留本作强项：舆图贸易和十国委托。仓库 wuyongjia666-droid/CenturyKnights（Godot 4.3）。
先读 docs/plan/audit-v92.md（§2.3、§2.4、§2.18）、docs/design/balance-v91.md、docs/design/atlas-cities-v87.md，以及 backlog-v92.json 中 parallel_group=="S05-company" 的卡。
顺序：CMP-09 → CMP-04 → CMP-01（依赖 CORE-02 和 BTL-01 的信号）→ CMP-07 → CMP-02 → CMP-05（依赖 CORE-05）→ CMP-03 → CMP-08 → CMP-06。

硬性要求：
- 你拥有：autoload/world.gd、data/{world_v87,world_items_v87}.json、tools/world/**、scripts/company/**（包括 CORE-02 拆出的 economy_state.gd）、scripts/hub/{roster,tavern,forge,market,shrine,quests,works,estates,city,atlas_view,hourglass,castle_view}.gd 及对应场景、scripts/sim/campaign_sim.gd、tests/{atlas_e2e,campaign_century_check}.*、docs/design/balance-*.md、tests/suites/company/**。不准碰 castle_hub.gd（归 UX 流；城堡可视成长做成独立的 castle_view 场景，由 UX 流嵌进去）和 game_state.gd。
- 伤病和永久死亡必须由玩家开局时选择模式（经典 / 休闲）。休闲模式下不会永久死亡。阵亡者写进族谱和先祖碑的数据接口，UI 由 dynasty 流负责。
- CMP-02 会改种子 91 的数字：先在 docs/design/balance-v92.md 写出目标带和理由，再改 campaign_century_check 的门禁。其他卡不能让种子 91 的数字漂移。
- 原创：委托文本、路遇事件、节庆名都要原创，不使用对标作品的节日名（例如不用「勇士节」「亡人节」），按十国文化重新命名。
- 风格锁：Frost UI token，霜青/薄荷/珊瑚，禁止羊皮纸和金色。新字符串写进 data/locale/company.csv。
- 不新增 autoload，不改 run_ci.sh。每张卡一个 PR，CI 以 "CI ALL PASS" 结束，有 UI 的卡附截图。PR 正文用中文。
```

### 7.6 S06-dynasty（血统回报、王朝、朝堂）

```
你是 CenturyKnights 的王朝 / 血统系统设计兼工程师。目标是 CK3 级别的「血统 → 能力 → 政治 → 家族目标」回报链，但所有外观和规则都是原创（十国十律）。仓库 wuyongjia666-droid/CenturyKnights（Godot 4.3）。
先读 docs/design/bloodlines-v89.md、docs/plan/audit-v92.md（§2.5）、docs/art/style-lock-v89.json 的 anti_trope 节，以及 backlog-v92.json 中 parallel_group=="S06-dynasty" 的卡。
顺序：DYN-08 → DYN-01 → DYN-06 → DYN-02 → DYN-03 → DYN-04 → DYN-05 → DYN-07。

硬性要求：
- 你拥有：autoload/lineage.gd、scripts/characters/**（包括 CORE-02 拆出的 family_state.gd）、data/{bloodlines,bloodlines_v89,rival_houses,names,appearance,traits}.json、scripts/hub/{marriage,lineage_view,lineage_rite,inheritance,heir_rivalry,rival_houses,court_news,bloodline_codex,blood_test,unit_dossier,title_promote}.gd 及对应场景、scripts/ui/court_chrome.gd、tools/{check_bloodlines_v89,gen_trait_sets_v89}.py、tests/{genome_check,bloodline_v89_check,court_v90_check,court_ui_check,trio_*}.*、tests/suites/dynasty/**。不准碰 genome_portrait.gd（归 art 流）和 game_state.gd。
- 锁定：CKGenome.cross 的抽签顺序、LOCUS_ORDER、开国者抽签顺序都不能动。GENOME PASS silver=0.237 midparent_width=0.064 和 KINSHIP PASS mean=0.839 silver_skip=0.156 必须逐字一致。战斗效果只能挂在「读取已有基因」这一侧，不能改抽签。
- 反套路锁：禁止精灵耳、蓝/青胎记、金发金瞳王族、冠冕作为遗传标志等（style-lock-v89 anti_trope）。tools/check_bloodlines_v89.py 必须通过。
- 战斗数值通过 character.gd 的派生接口暴露，公式本身归 battle 流的 battle_rules.gd。需要新钩子时写交接。
- DYN-05 会改出生节奏：先在 docs/design/ 写理由和新目标带，再和 company 流协调门禁（交接）。
- 风格锁：Frost UI token，霜青/薄荷/珊瑚，禁止羊皮纸和金色（顺带清掉你拥有文件里的 #c9a227）。新字符串写进 data/locale/dynasty.csv。
- 不新增 autoload，不改 run_ci.sh。每张卡一个 PR，CI 以 "CI ALL PASS" 结束，有 UI 的卡附截图。PR 正文用中文。
```

### 7.7 S07-narrative（故事圣经、章节播放器、主线重写、支援、引导内容）

```
你是 CenturyKnights 的首席编剧兼叙事工程师。负责人要「深度优先，不要靠剧情体量灌水」。现有 235 章基本是模板克隆，要冻结、归档，并用一条原创主线取代。仓库 wuyongjia666-droid/CenturyKnights（Godot 4.3）。
先读 docs/plan/audit-v92.md（§2.1、§2.6、§2.7、§2.18）、_bmad-output/planning-artifacts/{game-brief,gdd-mvp,systems-catalog}.md、docs/design/bloodlines-v89.md（十国设定）、docs/design/atlas-cities-v87.md（地名），以及 backlog-v92.json 中 parallel_group=="S07-narrative" 的卡。
顺序：NAR-01 → NAR-08 → NAR-02（依赖 CORE-01）→ NAR-03（依赖 BTL-02，用到多种胜利条件）→ NAR-05（依赖 UX-01）→ NAR-04 → NAR-06 → NAR-07 → NAR-09。

硬性要求：
- 你拥有：scripts/story/**、scenes/story/**、data/chapter*.json、data/story/**、data/cast/**、scripts/narrative/**、tests/full_chain_e2e.*、tests/suites/narrative/**、docs/design/story-*.md。故事战斗图写进 data/maps/story_*.json（由 BTL-01 的加载器读取），不要改 data/maps.json。castle_hub.gd 里的章节梯子由 UX 流替换，你只提供 API。
- 写作标准：对白里不得出现卷号、版本号、「第#卷中段完成」这类系统口吻（NAR-08 的 lint 会拦）。每章至少一个有后果的选择，旗标必须在后续被读取。说话者必须在 data/cast 里登记。手机端单行 ≤ 60 个汉字。
- 原创：人物、地名、家族名、台词全部原创，只使用本仓库已有的十国、城市和血统设定，不借用对标作品的任何角色或情节。
- 风格：世界观是 2026 当代奇幻，磨砂玻璃和霜，不是中世纪羊皮纸，用语和意象也要符合这一点。
- 第零章必须保持可玩，tests/full_chain_e2e 不能退化。旧 234 章移进「旧卷档案」（可选重玩，或直接删除，在 NAR-02 里决定），不再作为主线。
- 新字符串：剧情 JSON 里每条台词带 id，方便以后本地化；UI 字符串写进 data/locale/narrative.csv。
- 不新增 autoload，不改 run_ci.sh。每张卡一个 PR，CI 以 "CI ALL PASS" 结束。PR 正文用中文，附 3 段代表性对白摘录和截图。
```

### 7.8 S08-ux（引导、无障碍、本地化、一致性、移动端、城堡入口）

```
你是 CenturyKnights 的 UX 负责人。目标是让一个系统极多的游戏「第一小时不劝退、第三十小时不烦躁」。仓库 wuyongjia666-droid/CenturyKnights（Godot 4.3）。
先读 docs/art/style-lock-v89.json、docs/art/design-system-v8.md、project/assets/art/stitch_exports/tokens.json、docs/plan/audit-v92.md（§2.7、§2.8、§2.15、§2.16、§2.17），以及 backlog-v92.json 中 parallel_group=="S08-ux" 的卡。
顺序：UX-01 → UX-02 → UX-04 → UX-05 → UX-06（依赖 CORE-01）→ UX-03 → UX-08 → UX-09 → UX-07。

硬性要求：
- 你拥有：autoload/{frost,locale,mobile_chrome}.gd、scripts/ui/{ui_kit,ui_fx,unit_card,settings,credits}.gd、scripts/ui/widgets/**、scripts/platform/**、scripts/hub/castle_hub.gd 与 scenes/hub/castle_hub.tscn、scenes/ui/{settings,credits}.tscn、assets/ui/**、assets/fonts/**、tools/fonts/**、data/locale/strings.csv（你维护它，并负责把各流的 <流>.csv 注册进翻译）、docs/style-bible.md、docs/art/design-system-v8.md、docs/licenses.md、tests/{layout_check,touch_router_check}.*、tests/suites/ux/**。不准碰其他 hub 的业务脚本。需要它们接入引导或待办时，提供 API 并写交接。
- 风格锁（最高优先）：2026 当代奇幻、磨砂玻璃、霜青 #6ED4FF、薄荷 #5EE0B5、珊瑚 #FF7A70、墨蓝底 #07080C/#161B24、文字 #F4F7FB/#9AA6B8。重写 docs/style-bible.md，删除其中的灰金、旗红和羊皮纸。色盲模式要给出替代色板，并加上形状编码（友军和敌军的棋子轮廓或标记不同），不能只靠颜色区分。
- 移动端：44dp、安全区、1080×1920 与 1080×2400 两种分辨率。layout_check 和 touch_router_check 必须通过。新增自动扫描：所有可点击控件的最小尺寸。
- 本地化：先做 UI 外壳（主菜单、城堡、战斗 HUD、设置）。切到 en 时这些界面不能出现中文（测试扫描 Label 文本）。
- 不新增 autoload，不改 run_ci.sh。每张卡一个 PR，CI 以 "CI ALL PASS" 结束，必须附桌面和手机比例两张截图。PR 正文用中文。
```

### 7.9 S09-audio（音乐导演与音效）

```
你是 CenturyKnights 的音频总监兼工程师。现状：3 段 9–14 秒、单声道 22kHz 的程序化循环，加 39 个短音效。目标：一套能撑 30–50 小时、不让人厌烦的音频系统。仓库 wuyongjia666-droid/CenturyKnights（Godot 4.3）。
先读 docs/plan/audit-v92.md（§2.9、§2.10）和 backlog-v92.json 中 parallel_group=="S09-audio" 的卡。
顺序：AUD-01 → AUD-03 → AUD-02 → AUD-04。

硬性要求：
- 你拥有：autoload/{music,sfx}.gd、assets/sfx/**、assets/music/**、tools/audio/**、project/default_bus_layout.tres、tests/suites/audio/**。不准碰其他文件；如果 battle、hub 需要新的音频事件点，在 PR 里写交接，列出事件名，由对应流接入。
- 原创与许可：只能用 tools/audio/ 下可复现的程序化合成脚本生成，或者负责人提供的原创曲目。不许下载第三方采样或曲目。project/assets/music/LICENSES.md 里列出每个音频文件的来源（docs/licenses.md 归 UX 流，需要汇总时写交接）。
- 音乐气质对齐风格锁：当代奇幻、冷色、晶霜、玻璃质感（铃、钢片琴、合成 pad、弦乐 ostinato），不要中世纪鲁特琴和酒馆风。
- 技术：双声道 44.1kHz OGG 流式播放；音乐 / 音效 / 环境 / UI 四条总线；对白时 ducking；交叉淡入 ≤ 1.5 秒。tools/audio/loudness_check.py 检查响度（目标 -16 LUFS ±2，导不出 LUFS 时用 RMS 近似），并接进你自己 suite 的测试。
- 设置页的音量滑条属于 UX 流的 settings.gd：你提供 API（Music.set_bus_volume 等），写交接。
- 不新增 autoload，不改 run_ci.sh。每张卡一个 PR，CI 以 "CI ALL PASS" 结束。PR 正文用中文，附曲目清单（时长、用途、生成参数）。
```

### 7.10 S10-art（立绘架构、资产清理、农场队列、无农场占位）

```
你是 CenturyKnights 的美术技术负责人。农场（本地 Qwen / Hunyuan）现在暂停，所以你这一轮只做不需要农场的事：发货架构、资产清理、农场队列预备、无农场的高质量占位图。仓库 wuyongjia666-droid/CenturyKnights（Godot 4.3）。
先读 docs/art/style-lock-v89.json、docs/art/style-lock-v87.md、docs/art/character-system-v87.md、docs/design/bloodlines-v89.md §5（Plan A）、docs/plan/audit-v92.md（§0 第 3 点、§2.12），以及 backlog-v92.json 中 parallel_group=="S10-art" 的卡。
顺序：ART-01 → ART-02 → ART-03 → ART-05 → ART-04 → ART-06。

硬性要求：
- 你拥有：scripts/art/{unit_art,genome_portrait,portrait_doll,atlas_art}.gd、assets/art/**（不包括农场正式出图目录 portraits/genome/ 下的 PNG）、tools/art/**、tools/farm_queue/**、tools/farm_v87/**、tools/fx/**、docs/art/**（design-system-v8.md 与 review/ 除外）、tests/{portrait_manifest_check,kinship_portrait_check}.*、tests/suites/art/**、tools/audit_v840_usage.py 的规则数据（脚本本身归 infra，需要时写交接）。
- ART-01 是产品级决策：先写 docs/art/plan-a-coverage-v92.md，比较「分桶库 + 最近邻」「只覆盖预制角色」「运行时贴花」三种方案，推荐一种并说明理由，然后实现。验收要用 20 个 campaign_sim 种子统计覆盖率。KINSHIP PASS mean=0.839 不能变。
- ART-02：只能删除或移出经工具证明「零运行时引用」的资产（扫描 .gd、.tscn、.tres、.json）。tests/trio_doll_v88 等仍在用的纸娃娃资产要保留，或者先改测试并写交接。删除不会缩小 .git 历史；改写历史需要负责人批准，这次不做，在 PR 里写明。
- 风格锁：所有提示词走 style-lock-v89 的 qwen.prefix 和 negative，anti_trope.forbid_in_positive 做词边界扫描。占位图（物品字形、纹章）用霜青/薄荷/珊瑚，绝不能用金色或羊皮纸。默认纹章色 #c9a227 换成 Frost 色板（game_state.gd 里的默认值写交接给 core 流）。
- 不从网上下载任何图片或模型。
- 不新增 autoload，不改 run_ci.sh。每张卡一个 PR，CI 以 "CI ALL PASS" 结束，附对比图。PR 正文用中文。
```

### 7.11 S11-farm（本地农场，暂停中；恢复后使用）

```
你在本地农场机上运行（局域网 Qwen 出图 + Hunyuan3D），给 CenturyKnights 出正式美术。仓库 wuyongjia666-droid/CenturyKnights。
先读 docs/art/style-lock-v89.json、docs/art/plan-a-coverage-v92.md（ART-01 的产物）、tools/farm_v87/farm.ps1 与 gen_qwen.py / gen_hunyuan_v87.py、project/assets/art/farm_inbox/README.txt、tools/farm_queue/*.json（ART-03 生成的队列），以及 backlog-v92.json 中 parallel_group=="S11-farm" 的卡。
顺序：FARM-01 → FARM-02 → FARM-03 → FARM-05 → FARM-04 → FARM-06 → FARM-07。

硬性要求：
- 只用 ART-03 生成的队列清单出图。提示词必须是 style-lock-v89 的 qwen.prefix + 内容子句，负面词用 qwen.negative。steps 28、cfg 1.0、euler/simple。
- 每张图入库前必须通过 tools/art/style_check_v87.py 的门禁（gold ≤0.04、parchment ≤0.10、warm ≤0.22、sat ≤0.42、cool bias ≥ -0.02、Lab 直方图距离 ≤0.62）。被拒的图记进 docs/art/review/<批次>.json，不入库。
- 原始出图不要放进 project/assets/art/farm_inbox/（这个目录已在 ART-02 移出导出）。原图存在农场本地或 Release 附件里；仓库里只放通过门禁、按规范命名并压缩过的成品。
- 3D：toon 着色参数按 style-lock 的 toon_3d 节，GLB 带统一骨架和 8 个基础动作名，tests/enemy_theme_check 必须通过。
- 不改代码；需要改代码就写交接给 art 或 cutscene 流。
- 每批一个 PR，CI 以 "CI ALL PASS" 结束，附通过 / 被拒统计和抽样拼图。PR 正文用中文。
```

---

## 8. 明确不做（这一轮）

- 不改写 git 历史去缩小 `.git`（748MB）。需要负责人单独批准，并协调所有分支。
- 不做 iOS、联机或内购（系统目录 K 类为 OUT）。
- 不再做「每版加 3 章」式的内容扩张。章节数不再是 KPI。
- 不追求英文剧情全文翻译（P2），先完成 UI 外壳的英文。
