# 百年骑士 v9.3 — 领地争夺（Territory）

> 状态：设计定稿，分 PR 落地。数据：`project/data/territory_v93.json`（由 `tools/world/territory_sites.py` 生成）。
> 运行时：`project/scripts/company/territory.gd`（`CKTerritory`，状态挂在 `World.territory`）。复用：舆图节点/道路（`World`）、遭遇战（`World.start_encounter`）、委托榜（`World.boards` / `turn_in`）、月度总线（`CKMonthBus` world 相）、纹章渲染（`CKHeraldryRender`）、存档（`world_v87` 子键）。

## 1. 定位（用户决定，2026-10-12）

- 玩家是**一支佣兵团**。本堡灰旗堡（`hq`）与团徽（`GameState.banner_spec`）**永久不变**，本堡领地固定。
- 本堡**永远不会丢失**：`hq` 不是领地点，所有夺取/失守/争夺接口对 `hq` 直接拒绝，测试断言。
- 世界很大，十国 + 陆桥上散落着**中立领地**：村寨、矿坑、渡口、林舍、盐场、烽台。佣兵团可以占下它们收资源。
- 占领领地不是“建国”：我们是挂旗收保护费的佣兵团，领地挂的永远是**团徽**，不随联姻或家族变化。

## 2. 领地点

- 32 处，每国 3 处（10 国 × 3）+ 陆桥 2 处。每处挂在一个已有舆图节点（`anchor`，非都城、非本堡）旁，坐标 = 锚点坐标 + 小偏移，画在同一张国度板块上。
- **产出取自该国资源表**：矿坑出本国特材（烬灰钢/影曜石/河玉/灯琉璃/霜晶/熔曜玻/盐晶/峡钢锭/星砂/南泽硬木），村寨出粮/茶/药材/铁料，渡口以过路银为主附带货物，林舍出皮/硬木，盐场出盐晶/星砂，烽台不产货。

| 种类 | 月银 | 月货 | 基础维护 | 危险 | 特性 |
|---|---|---|---|---|---|
| 村寨 | 10 | 6 | 4 | 1 | 粮/药材类大宗 |
| 矿坑 | 6 | 3 | 6 | 2 | 本国特材（锻造材料） |
| 渡口 | 22 | 1 | 5 | 1 | 过路银 |
| 林舍 | 8 | 3 | 4 | 2 | 皮/木 |
| 盐场 | 12 | 3 | 5 | 1 | 盐晶/星砂 |
| 烽台 | 4 | 0 | 5 | 2 | 同国其他领地被争夺几率 −3% |

敌对之邦（朔影国）领地危险 +1。

## 3. 夺取：两条路

前置：该国邦交声望 ≥10（敌对之邦 ≥30），同时持有不超过 8 处。部队必须身处锚点节点。

1. **强攻（SRPG 战斗）**：在锚点发起 `start_encounter("territory_assault")`，危险 = 领地危险 +1，生物群系与敌人模板沿用锚点与该国。胜 → 占领，但**民心未附**：前 2 个月产出减半。败 → 走遭遇战败退规则。
2. **委托链（和平归附）**：在锚点委托榜贴出两步链：
   - 第 1 步「收购」：给寨民送一批他们缺的货（锚点求购货），交付即消耗；
   - 第 2 步「追缉」：清掉附近盘踞的匪帮（目标为邻近聚落，到达即战），回锚点交付。
   - 完成 → 占领，无民心惩罚，另加锚点城声望。
   链步就是普通委托（带 `territory` 字段），走同一个委托榜、同一个交付按钮、同一个期限与放弃规则。

被对手夺走的领地（`owner = rival:<id>`）可以再强攻夺回，危险再 +1。

## 4. 经营：产出、驻军、维护

- 每月（`CKMonthBus` world 相）对每处我方领地结算：
  - 银：`yield_silver`；货：`yield_qty` 份本地货。粮/铁/药材入城堡库存，其余入货舱；货舱满则由当地代理按基础价 70% 折银。
  - 维护：`upkeep + 驻军等级 × 4` 银。银不足 → 驻军降一级并记日志（驻军 0 时不再降）。
  - 民心未附或正被争夺时产出减半。
- **驻军** 0–3 级，每升一级 40 银（在锚点或本堡远程下令均可）。驻军降低被争夺几率（每级 −2%），也决定无人救援时的自守几率。

### 4.1 屯营（原第二据点的玩法价值）

- 任一我方领地可修**屯营**：120 银，月产 +12 银、+6 粮（入城堡粮仓），驻军上限 3 → 4。每处只能修一次；失守时屯营保留在原地（夺回后仍在），契约保底随失守作废。
- 原来「走完一国剧情委托链 → 可得第二据点」改为：走完后获得一次**免费屯营**（`stockade_credit`），下一次修屯营不花银。
- 旧据点的「主堡⇄据点调兵」按钮删除：驻军按领地计，增派驻军走领地弹窗。

## 5. 争夺与失守

- 每月每处领地：几率 = 5% + 2%×危险 − 2%×驻军 − 烽台 3%（同国有我方烽台）+ 4%（对手佣兵团就在该国），上限 20%，下限 0。
- 来犯者：该国有对手佣兵团则为该团（`World.rivals`），否则为本国匪帮。生成**威胁**：限期 30 日。舆图上该领地旗帜闪红并写入城堡日志。
- 部队在期限内到达锚点 → 自动弹出**守卫战**（`territory_defend`）。胜：保住，锚点城声望 +3，威胁解除；败：领地落入来犯者之手。
- 期限内没去：按驻军自守，成功率 = 10% + 25%×驻军。守住则驻军 −1；守不住则失守（对手团夺走则成为 `rival:<id>`，匪帮夺走则回到中立）。
- **本堡永不失守**：争夺只遍历领地点；`hq` 不在领地表中，`capture/lose` 对 `hq` 返回失败。

## 6. 舆图表现

- 国度视图上每处领地画一个小旗位：中立 = 灰色空旗杆；我方 = **团徽小旗**（`CKHeraldryRender.compose_texture(GameState.banner_spec, …)`，按 spec 缓存）；对手 = 对手团色旗；受威胁 = 红色脉冲环。
- 选中锚点节点时右栏列出它的领地：产出、维护、驻军、状态，按钮「强攻」「贴出归附委托」「增派驻军」「前往守卫」，禁用时写原因（声望不足/不在此地/银不足/已达上限）。
- 世界视图只画我方领地计数徽记，避免拥挤。

## 7. 存档与迁移

- 状态存在 `World.to_save()["territory"]`：`{"v":1, "sites": {id: {owner, garrison, unrest, threat}}, "log": [...]}`。只存与默认不同的点。
- 旧档无此键 → 全部中立，零迁移成本；未知 id 丢弃；字段缺失按默认补。
- **第二据点并入领地（2026-10-12 用户决定）**：只有一座主堡。旧档里的 `holdings.second_seat` 读档时转成**同一聚落旁**的我方领地（锚点相同优先，否则同国最近的空领地），带屯营、原驻军（据点驻军，上限 4）与**契约保底**：该领地每月净银不低于 +6、粮不低于 +6（即旧据点 18−12 银、+6 粮），永不比旧据点少。转换后 `second_seat` 删除，`second_hold_offer` 不再读写。

## 8. 测试

`project/tests/suites/company/territory_check`：数据完整（32 处、每国 ≥3、锚点存在且非本堡/都城、产出货物属于该国资源表）；强攻与委托链两条夺取路径；月度产出/维护/降驻军；争夺→守卫战胜/败/逾期自守；`hq` 永不失守；存档往返与旧档迁移。

## 9. 中立拉锯加码与落幕归属（Territory fat）

中立点可被多方拉锯（`start_neutral_contest`）。玩家三条路：

1. **驰援截击**（原有）：赶到锚点强攻，`intervene_contest` → `assault`。
2. **加码截夺**（本刀）：`contest_stake` 花银（`contest_stake_cost` = 规则底 + 危险×12）写入 `company` 阵营压力（高于当前最高压），月回读 `month_echo.contest`；落幕时压力最高者得手——本团则 `capture(id, "contest")`（驻军≥1、短民心未附、产出入账）。
3. **观望**：`watch_contest`，下一月仍可加码/截击。

UI：`ContestTugModal` 增 `ContestStake` + `EchoLine_contest`；`TerritoryMonthModal` 增 `ContestLine`（落幕/未决）+ `EchoLine_contest`。

E2E：`territory_contest_stake_claim_check` + mobile twin。

## 10. 失守反夺交令与月回读（Territory fat）

失守后 `_post_reclaim` 在锚点委托榜贴出一发「反夺」hunt（`territory_reclaim`）。玩家三条路：

1. **月报按钮**：`TerritoryMonthModal` 的 `TerritoryMonthReclaim` 跳到锚点看榜。
2. **接令开战**：接榜 → 赶到目标开战 → 回锚点交令 → `_finish_reclaim` → `capture(id, "reclaim")`（驻军≥1、短民心未附）。
3. **月回读**：交令成功写入 `month_echo.reclaim`；月报增 `ReclaimLine`（待交）+ `EchoLine_reclaim`（得手）。

E2E：`territory_reclaim_quest_echo_check` + mobile twin。


## 11. 守卫得手与月回读（Territory fat）

来犯威胁（`start_threat`）挂起后，玩家赶到锚点开战（`defend` / `intercept` / `on_arrive`）→ `territory_defend`。

1. **胜**：清威胁、锚点声望 +3，写入 `month_echo.defend`（locale `terr_echo_defend`）。
2. **败**：`lose` 落入来犯者（原有路径，本刀不改）。
3. **月回读**：`TerritoryMonthModal` 增 `DefendLine`（待守威胁）+ `EchoLine_defend`（得手）。

E2E：`territory_defend_hold_echo_check` + mobile twin。

## 12. 强攻得手与月回读（Territory fat）

中立/对手领地在锚点发起 `territory_assault`，胜 → `capture(how=assault)`（民心未附 `unrest` 月数按规则）。

1. **胜**：写入 `month_echo.assault`（locale `terr_echo_assault`：地名·月银·未附月数）。
2. **败**：走遭遇败退（本刀不改）。
3. **月回读**：`TerritoryMonthModal` 增 `UnrestLine`（民心未附待定）+ `EchoLine_assault`（得手）。

E2E：`territory_assault_seize_echo_check` + mobile twin。

## 13. 归附得手与月回读（Territory fat）

中立领地在锚点贴两阶归附委托（`post_chain` → gather → hunt）→ 交令收尾 `capture(how=chain)`（驻军≥1、无民心未附）。

1. **得手**：写入 `month_echo.chain`（locale `terr_echo_chain`：地名·月银·驻军）。
2. **贴令**：仅上榜，不写得手回读。
3. **月回读**：`TerritoryMonthModal` 增 `ChainLine`（待交归附令）+ `EchoLine_chain`（得手）。

E2E：`territory_chain_attach_echo_check` + mobile twin。

## 14. 拉锯落幕 ContestResolveModal（Territory fat）

中立拉锯 `tick_neutral_contests` 落幕时写入 `World.last_contest_resolve`（最新一条），大地图弹出 `ContestResolveModal`——对齐围城 `SiegeLootModal` 的事后确认，而不是再加一条 `month_echo` 碎条。

1. **得手**（`outcome=won`）：本团压力最高 → `capture(how=contest)`，正文月银/驻军。
2. **旁落**（`outcome=lost`）：`rival:*` 得手，领地易主。
3. **散场**（`outcome=miss`）：流寇/截击失败，点仍中立但民心动荡。
4. **链路**：月报 / 围城辎重 OK 之后、`ContestTugModal` 之前检查；同点落幕时清掉未读 `last_neutral_contest`。

E2E：`atlas_contest_resolve_check` + `mobile_atlas_contest_resolve_check`。

## 15. 自守落幕 ThreatResolveModal（Territory fat）

未应答围城 `_resolve_unanswered` 落幕时写入 `World.last_threat_resolve`（最新一条），大地图弹出 `ThreatResolveModal`——对齐 `ContestResolveModal` / `SiegeLootModal` 的事后确认。粮仓劫掠仍走 `SiegeLootModal`；本模态只报驻军守成 / 据点易主。

1. **守住**（`outcome=held`）：威胁清除，驻军 −1，正文驻军前后与守成率。
2. **失守**（`outcome=lost`）：`lose(id, by)` 前写入；据点易主。
3. **链路**：月报 / 围城劫仓 OK 之后、`ContestResolveModal` 之前检查；新威胁 `start_threat` 时清掉同点未读落幕。

E2E：`atlas_threat_resolve_check` + `mobile_atlas_threat_resolve_check`。

## 16. 收买 / 斥候与月回读（Territory fat）

围城悬临期间的 Improve-plan #1 对策：`bribe_threat` / `scout_threat` 得手写入月回读，`SiegeAlertModal` 留模态贴 `EchoLine_*`（对齐 muster / sister，不再收买后立刻关窗）。

1. **收买**：一次性；扣银；`months → 0`；写入 `month_echo.bribe`（locale `terr_echo_bribe`：地名·银）。
2. **斥候**：首次扣银写入 `scouted` + intel 与 `month_echo.scout`（locale `terr_echo_scout`：地名·银·守成%）；再探只回读已有 intel，不重写回读。
3. **UI**：`SiegeBribe` / `SiegeScout` 成功后禁用按钮、贴 `EchoLine_bribe` / `EchoLine_scout`；领地面板 `_echo_strip` 与 `month_echo_lines` 收录 bribe/scout。

E2E：`territory_siege_bribe_scout_echo_check` + mobile twin。

## 17. 城堡 HubTodo 领地威胁 chip（Territory fat · J14）

J14：领地受威胁只写日志，城堡不提醒、也没有带路。本刀在城堡「本月待办」挂 `territory_threat` chip，深链回大地图围城告急模态——不是再开一层 month_echo 薄片，也不是完整领地簿（P1-UX-04）。

1. **计数**：`CKTerritory.threatened_owned()` —— 自有且 `threat` 非空的据点。
2. **chip**：`HubTodo` category `territory_threat` / group `military` / locale `ux_todo_territory_threat`；`LINKS` → `atlas_view.tscn`。count=0 不入 snapshot。
3. **带路**：城堡 desk/mobile chip 点按先 `HubTodo.prepare_nav` → `CKTerritory.hub_requeue_siege_alert()`（优先 months 最大者，phase declared/imminent），再 `CKNav.go` 舆图；`SiegeAlertModal` 弹出。
4. **清零**：威胁解除（截击/收买落幕/`_resolve_unanswered`）后 chip 自然消失。

E2E：`territory_hub_todo_threat_check` + mobile twin；`todo_due_check` 覆盖无威胁不显示 / 有威胁可链。

## 18. 属地威胁整链闭环（Territory fat · 禁止再拆 chip/echo/modal）

玩家看得见的一条链，不拆薄片：

1. **威胁出现**：`start_threat` / 月结来犯 → 城堡 HubTodo `territory_threat`（severity=block）。
2. **待办带路**：chip → `hub_requeue_siege_alert` → 舆图 `SiegeAlertModal`。
3. **应战/贿探**：模态上截击/收买/斥候；收买·斥候写 `month_echo.bribe/scout` 并贴 `EchoLine_*`（威胁仍在，仅缓兵/探明）。
4. **结算**：守卫得手写 `month_echo.defend`；逾期自守 `_resolve_unanswered` 弹 `ThreatResolveModal` 并写 `month_echo.threat_held` / `threat_lost`。
5. **沙漏回读**：有 echo 时 Result 列 `EchoLine_*`；Forecast 在威胁未清时挂 `ThreatPending` + `ToSiegeThreat`（再深链围城告急）。
6. **清零**：威胁字典清空后 chip 与 Forecast 条一起消失。

E2E：`territory_threat_closed_loop_check` + mobile twin（城堡→围城→贿探→沙漏→自守落幕/守卫一整条）。

## 19. 领地簿整链（Territory fat · P1-UX-04）

城堡主页「领地簿」页：归旗属地一览，不是 chip 切片，也不是再拆一口 echo。

1. **入口**：城堡舆图组 `territory`（`year_one` 与 atlas 同开）；场景 `territory_ledger.tscn`。
2. **列表**：`owned_ids` → 月银 / 驻军 / 未附 / 屯营 / 威胁标签。
3. **远程增派 / 屯营**：调用既有 `reinforce` / `build_stockade`（可远程，无需亲临锚点）。
4. **告急围城**：行内按钮 → `hub_requeue_siege_alert_site(id)` → 跳舆图弹出 `SiegeAlertModal`（对齐 HubTodo J14，但按点指定）。
5. **前往舆图**：`CKNav` params `site=` + `GameState` meta `atlas_territory_site` / `atlas_select`；`atlas_view` `_ready` 消费后 `_open_territory_site`。
6. **E2E**：`territory_ledger_closed_loop_check` + `mobile_territory_ledger_closed_loop_check`。

## 20. 免费屯营整链（Territory fat · 禁止再拆 credit/chip/ledger）

玩家看得见的一条链，不拆薄片：

1. **发额度**：一国剧情委托链走完 → `grant_stockade_credit` → `_log` + `month_echo.stockade_credit`（`terr_echo_stockade_credit`）。
2. **待办带路**：城堡 HubTodo `stockade_credit` chip（count=额度）→ `territory_ledger`。
3. **领地簿**：顶栏 `TerritoryCreditBanner`；未建屯营行按钮改「免费建屯营」；详情写免费/耗银。
4. **消费**：`build_stockade` 花额度（cost=0）→ `month_echo.stockade` → chip 随额度清零。
5. **回读**：属地月报条 `EchoLine_stockade_credit`（发）+ `EchoLine_stockade`（筑成）。

E2E：`territory_stockade_credit_loop_check` + mobile twin。

## 21. 失守反夺整链（Territory fat · 禁止再拆 chip/ledger/hourglass/echo）

玩家看得见的一条链，不拆薄片：

1. **失守发令**：`lose` → `_post_reclaim` 在锚点告示栏贴「反夺」hunt；`pending_reclaim_ids` 扫描 board/active。
2. **待办带路**：城堡 HubTodo `territory_reclaim`（severity=block, count=待反夺数）→ `prepare_nav` → `hub_focus_reclaim`（写 `atlas_select` / `atlas_territory_site`）→ 舆图。
3. **领地簿**：顶栏 `TerritoryReclaimBanner` + `TerritoryReclaimGoto` → 同深链跳舆图。
4. **沙漏 Forecast**：`ReclaimPending` + `ToReclaim` 深链舆图焦点。
5. **交令得手**：`turn_in` / `_finish_reclaim` → `capture(how=reclaim)` → `month_echo.reclaim`；chip / Forecast / 簿条清零。
6. **月回报**：`last_month_report.reclaims` 始终取 `pending_reclaim_ids()`（跨月仍可见）；TerritoryMonth `ReclaimLine` + `EchoLine_reclaim`。

E2E：`territory_reclaim_closed_loop_check` + mobile twin；`todo_due_check` 覆盖无反夺不显示 / 有反夺可链。


## 22. 民心未附 / 安抚整链（Territory fat · 禁止再拆 chip/ledger/hourglass/echo）

玩家看得见的一条链，不拆薄片：

1. **未附出现**：`capture(how=assault|contest|reclaim…)` 写入 `unrest` 月数；月结产出减半，每月自然 −1。
2. **待办带路**：城堡 HubTodo `territory_unrest`（severity=block, count=`unrest_owned_ids()`）→ `territory_ledger`。
3. **领地簿**：顶栏 `TerritoryUnrestBanner`；选中未附点可「安抚」：`appease(id)` 花银（`appease_cost` = 规则底 + 危险×12）立刻清零 unrest。
4. **沙漏 Forecast**：`UnrestPending` + `ToAppease` 深链领地簿。
5. **安抚得手**：`appease` → `month_echo.appease`（`terr_echo_appease`）→ chip / Forecast / 簿条随 unrest 清零。
6. **月回报**：TerritoryMonth 既有 `UnrestLine`；有 echo 时贴 `EchoLine_appease`。

E2E：`territory_unrest_appease_loop_check` + mobile twin；`todo_due_check` 覆盖无未附不显示 / 有未附可链。


## 23. 归附委托整链（Territory fat · 禁止再拆 chip/ledger/hourglass/echo）

玩家看得见的一条链，不拆薄片：

1. **贴令**：中立点 `post_chain` → 锚点告示栏两阶归附委托（gather→hunt）；`pending_chain_ids` 扫描 board/active（`chain` 且非 reclaim）。
2. **待办带路**：城堡 HubTodo `territory_chain`（urgency=block, count=待交数）→ `prepare_nav` → `hub_focus_chain`（写 `atlas_select` / `atlas_territory_site`）→ 舆图。
3. **领地簿**：顶栏 `TerritoryChainBanner` + `TerritoryChainGoto` → 同深链跳舆图。
4. **沙漏 Forecast**：`ChainPending` + `ToChain` 深链舆图焦点。
5. **交令得手**：`turn_in` / `on_quest_done` 收尾 `capture(how=chain)` → `month_echo.chain`；chip / Forecast / 簿条随 `_clear_chain` 清零。
6. **月回报**：`last_month_report.chains` 取 `pending_chain_ids()`；TerritoryMonth 既有 `ChainLine` + `EchoLine_chain`（§13）。

E2E：`territory_chain_commission_loop_check` + mobile twin；`todo_due_check` 覆盖无归附不显示 / 有归附可链。
