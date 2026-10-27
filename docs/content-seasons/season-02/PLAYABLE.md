# 内容季 #2 · 可玩章 ·《婚约上的灯》

> 原著 [`NOVEL.md`](NOVEL.md) → 圣经 [`BIBLE.md`](BIBLE.md) → 游戏章 `project/data/story/chapters/cs02_01.json`。
> 口吻：大白话；单行 ≤60 汉字。团长键 `leader`。
> 验收：`content_season_playable_s02_check` 载入本章并走到对白，断言 schema + lint 干净 + 选「两行并排留」。

## 章信息

| 项 | 值 |
|---|---|
| id | `cs02_01` |
| 标题 | 婚约上的灯 |
| legacy_index | 402 |
| 文件 | `project/data/story/chapters/cs02_01.json` |

## 拍列表

| 拍 | 标题 | 要做什么 |
|---|---|---|
| `seal` | 落印 | 书记官落印；姓写入名册 |
| `estate` | 属地条 | 老管事出示婚仪月回响；待诞育 |
| `birth` | 回执 | 听回写脉偏；两版都记 |
| `tavern` | 摘抄 | 掌柜挂板；留指甲痕 |
| `ledger` | 并排 | 选择：两行并排留 / 先压下行 |

## 关键

- **两行并排留** → flag `cs02_kept_parallel`，进 `ledger` 收束。
- **先压下行** → flag `cs02_held_lamp`，仍进收束，旁白点明半截话会自己长（对标原著「待对」）。

## 说话人

旁白、leader、书记官、老管事、听回、槐里·青禾、石垒·晚担、苇原·灯影、老旗手、掌柜。  
新增：`supporting_v92` 登记 **书记官**、**老管事**（若尚无）；**庭吏** 可玩章可不登场。

## 加深（本刀）

- 原著 `NOVEL.md` 中篇加厚至 ≥14k 汉字；优先人物弧与专属场景（婚约/验盏），少用公式补页。
- 可玩章 `cs02_01.json` 对白加厚至 100+ 行；单行 ≤60 汉字。
- **所有权不变**：visit「去看月份怎么往前走」；battle「先试一锋 / 再试锋镝 / 继续」。
- 验收：`content_season_playable_s02_check` 行数闸 ≥70；另跑 visit_authored / battle_authored / hub_entry。
## 第二可玩章 · 副笺上的灯

| 项 | 值 |
|---|---|
| id | `cs02_02` |
| 标题 | 副笺上的灯 |
| legacy_index | 412 |
| 文件 | `project/data/story/chapters/cs02_02.json` |

回读章：正面已记，副面/阴面空行要能念。拍：主题开场 → 加深 → 沙漏 visit → 门廊试锋 → 酒馆选题 → 入谱。

- **偏仍并排** → flag `cs02_slip_parallel`，进 `ledger`。
- 验收：`content_season_playable_s02_02_check`。

## plate-final

前三拍收束不为旁白，保证 return_portrait 走得到具名板面。

## 中章口头去套话（mid-oral）

- 访/战/酒馆回程里跨章复读的套话改成该拍自己的句子；入谱拍不动。
- 前三拍无条件收束仍不是旁白。CTA、`锋收回来`、`mid_lost` 门闸不变。
- `_02` 胜后口语的 `when` 与战旗同挂季级 `csNN_mid_fought`（与 hub_chain / battle_authored 对齐），试锋得手才念得出。
- 真 E2E：`content_season_mid_oral_chain_check`（hub→章→战/访→回，二十章；断链或中章复读即失败）。

## 中途战 / 据点 / 回程加厚（hub-chain）

- 中途战拍：试锋前口语加厚；`mid_lost` 仍为拍末可见行（needle「锋收回来」）。
- 据点 visit 拍：时漏/验盏前口语加厚；CTA「去看月份怎么往前走」不变。
- 酒馆回程：挂板前口语加厚，收束回堡入谱。
- 真 E2E：`content_season_hub_chain_check`（hub→章→战/访→回抽样）；`battle_retry` LIVE 扩至 S01–S10 `_01`；playable walk_to_choice→220。

- mid_fought 胜后口语 + 据点 visit/酒馆回程加厚（全十季 _01/_02）；`hub_chain` LIVE 扩至 cs01–cs10 _01。

- ledger 回程名著加厚（入谱前口语 uniquify）；hub_chain 含 _02 抽样；ledger_payoff 扩走。

## 沙漏 visit 口头加厚（visit-oral）

- 各章 visit 拍（hourglass/audit/birth）加厚季题名著口头（`_vhg*`），全库去重。
- 验收：`content_season_visit_oral_chain_check` — hub chip → 针口头 → 去看月份 → 同拍回 → 继续。

## 酒馆挂板口头加厚（tavern-plate）

- 各章 `tavern` 拍入谱选择前加 `_tvp1`–`_tvp6` 季题名著口头，全库去重；收束非旁白。
- 验收：`content_season_tavern_plate_chain_check` — hub chip → 酒馆针口头 → 挂板选择 → ledger。

## 第二主题拍口头加厚（second-beat）

- 各章第二主题拍加 `_sec1`–`_sec6` 季题名著口头，全库去重；收束非旁白。
- 验收：`content_season_second_beat_chain_check` — hub chip → 二拍针口头 →（非中途战）继续。
## 开场主题口头加厚（theme-open）

- 各章首拍加 `_thm1`–`_thm6` 季题名著口头，全库去重；收束非旁白。
- 验收：`content_season_theme_open_chain_check` — hub chip → 首拍针口头 → 下一拍。

## 章末收束口头（close-oral）

- 各章 `ledger` 拍末 `_cls1`–`_cls8`：战后回家、把这一季的东西放进柜、季尾灯影。全库去重；末句不是旁白。
- 跨章复读的入谱套话改成该季自己的句子。不新开内容季，不写 EmptyHost，不加 month_echo。
- 不碰开场 `_thm`、二拍 `_sec`、访月 `_vhg`/`_msr`、战拍 `_bpl`、酒馆 `_tvp`、入谱回程 `_ldg`。
- 验收：`content_season_close_oral_chain_check` — hub 芯片 → 章末收束口头 → 回到灰旗堡。
## 访月整装口头加厚（muster-plate）

- 各章 visit 拍（hourglass/audit/birth）在 `_vhg` 后加 `_msr1`–`_msr6` 季题整装口头，全库去重；收束非旁白。
- 验收：`content_season_muster_plate_chain_check` — hub chip → 整装针口头。
- 不碰 `_bpl`/`_thm`/`_sec`/`_tvp`/`_ldg`。

## 访月离厅口头加厚（visit-exit）

- 各章 visit 拍（audit/birth/hourglass）在 `_vst` 后、`vis_mv4` 前加 `_vex1`–`_vex6` 离厅口头，全库去重；收束非旁白。
- 验收：`content_season_visit_exit_chain_check` — hub chip → 离厅针口头。
- 不碰 `_bpl`/`_vop`/`_arr`/`_lop`/`_tvx`/`_opn`/`_cls`/`_sec`。

## 西阁开柜口头加厚（ledger-open）

- 各章 `ledger` 拍首加 `_lop1`–`_lop6` 进阁开柜口头（`_ldg`/`_cls` 前），全库去重；收束非旁白。
- 验收：`content_season_ledger_open_chain_check` — hub chip → 开柜针口头。
- 不碰 `_bpl`/`_sec`/`_arr`/`_cls`/`_msr`/`_tvp`。
## 酒馆离店口头加厚（tavern-exit）

- 各章 `tavern` 在 `_tvn` 后、`ret_mv` 前加 `_tvx1`–`_tvx6` 离店口头，全库去重；收束非旁白。
- 验收：`content_season_tavern_exit_chain_check` — hub chip → 离店针口头。
- 不碰 `_bpl`/`_arr`/`_lop`/`_cls`/`_sec`/`_tvp`。


## 酒馆到店口头加厚（tavern-arrival）

- 各章 `tavern` 拍首加 `_arr1`–`_arr6` 到店整装口头（`_tvp` 前），全库去重；收束非旁白。
- 验收：`content_season_tavern_arrival_chain_check` — hub chip → 到店针口头。
- 不碰 `_bpl`/`_cls`/`_sec`/`_msr`/`_tvp`/`_ldg`。

## 开场入门口头加厚（open-door）

- 各章首拍拍首加 `_opn1`–`_opn6` 入门整装口头（`_thm` 前），全库去重；收束非旁白。
- 验收：`content_season_open_door_chain_check` — hub chip → 入门针口头。
- 不碰 `_bpl`/`_arr`/`_lop`/`_tvx`/`_vop`/`_cls`/`_sec`/`_tvp`。

## 访月入厅口头加厚（visit-open）

- 各章 visit 拍（audit/birth/hourglass）拍首加 `_vop1`–`_vop6` 入厅整装口头（`_vhg`/`_msr` 前），全库去重；收束非旁白。
- 验收：`content_season_visit_open_chain_check` — hub chip → 入厅针口头。
- 不碰 `_bpl`/`_arr`/`_lop`/`_tvx`/`_cls`/`_sec`/`_tvp`。

## 墨干合页口头加厚（ink-dry）

- 各章 `ledger` 拍在 `_ldg_end` 后、`_cls1` 前加 `_ink1`–`_ink6` 墨干合页口头，全库去重；收束非旁白。
- 验收：`content_season_ink_dry_chain_check` — hub chip → 墨干针口头。
- 不碰 `_lop`/`_ldg`/`_cls`/`_bpl`/`_aud`/`_vex`/`_msr`/`_opn`。

## 访月落笔口头加厚（audit-pen）

- 各章 visit 拍（audit/birth/hourglass）在 `_vhg` 前加 `_aud1`–`_aud6` 落笔口头，全库去重；收束非旁白。
- 验收：`content_season_audit_pen_chain_check` — hub chip → 落笔针口头。
- 不碰 `_vop`/`_vhg`/`_msr`/`_bpl`/`_lop`/`_cls`/`_sec`/`_tvp`/`_wex`/`_opn`/`_vex`。

## 战后收锋口头加厚（battle-settle）
- 各章试锋胜后 `_win4` 后、`mid_lost`（若有）前加 `_wex1`–`_wex6` 收锋口头，全库去重；收束非旁白。
- 验收：`content_season_battle_settle_chain_check` — hub chip → 收锋针口头。
- 不碰 `_bpl`/`_tvx`/`_lop`/`_vop`/`_opn`/`_vex`/`_thm`/`_sec`。

## 回堡靴程口头加厚（return-boot）

- 各章 `tavern` 拍在 `_tvx6` 后、`_ret_mv4` 前加 `_rtn1`–`_rtn6` 回堡靴程口头，全库去重；收束非旁白。
- 验收：`content_season_return_boot_chain_check` — hub chip → 靴程针口头。
- 不碰 `_arr`/`_tvp`/`_tvn`/`_tvx`/`_lop`/`_cls`/`_wex`/`_ink`/`_opn`。

## 挂板前息口头加厚（board-approach）

- 各章 `tavern` 拍在 `_ret_mv3` 后、`_tvp1` 前加 `_brd1`–`_brd6` 挂板前息口头，全库去重；收束非旁白。
- 验收：`content_season_board_approach_chain_check` — hub chip → 板前针口头。
- 不碰 `_arr` / `_tvp` / `_tvn` / `_tvx` / `_rtn` / `_lop` / `_cls` / `_wex` / `_ink` / `_aud`。

## 板后耳语口头加厚（after-board-hush）

- 各章 `tavern` 拍在 `_tvp6` 后、`_tvn1` 前加 `_aft1`–`_aft6` 板后耳语口头，全库去重；收束非旁白。
- 验收：`content_season_after_board_hush_chain_check` — hub chip → 板后针口头。
- 不碰 `_arr`/`_tvp`/`_tvn`/`_tvx`/`_brd`/`_rtn`/`_lop`/`_cls`/`_wex`/`_ink`/`_aud`。

## 席末静口口头加厚（seat-hush）

- 各章 `tavern` 拍在 `_tvn4` 后、`_tvx1` 前加 `_sth1`–`_sth6` 席末静口口头，全库去重；收束非旁白。
- 验收：`content_season_seat_hush_chain_check` — hub chip → 席末针口头。
- 不碰 `_arr`/`_tvp`/`_aft`/`_tvn`/`_tvx`/`_brd`/`_rtn`/`_lop`/`_cls`/`_wex`/`_ink`/`_aud`。

## 厅角停步口头加厚（hall-pause）

- 各章第二主题拍在 `_sec6` 后、离开该拍前加 `_hlp1`–`_hlp6` 厅角停步口头，全库去重；收束非旁白。
- 验收：`content_season_hall_pause_chain_check` — hub chip → 厅角针口头。
- 不碰 `_arr`/`_tvp`/`_aft`/`_tvn`/`_tvx`/`_sth`/`_brd`/`_rtn`/`_lop`/`_cls`/`_wex`/`_ink`/`_aud`/`_sec`/`_bpl`/`_msr`/`_vop`。

## 门内落定口头加厚（open-settle）

- 各章首拍在 `_thm6` 后、离开该拍前加 `_ods1`–`_ods6` 门内落定口头，全库去重；收束非旁白。
- 验收：`content_season_open_settle_chain_check` — hub chip → 门内针口头。
- 不碰 `_arr`/`_tvp`/`_aft`/`_tvn`/`_tvx`/`_sth`/`_brd`/`_rtn`/`_lop`/`_cls`/`_wex`/`_ink`/`_aud`/`_sec`/`_hlp`/`_bpl`/`_msr`/`_vop`/`_opn`/`_thm`。

## 门槛外望口头加厚（threshold-gaze）

- 各章首拍在 `_ods6` 后、离开该拍前加 `_rim1`–`_rim6` 门槛外望口头，全库去重；收束非旁白。
- 验收：`content_season_threshold_gaze_chain_check` — hub chip → 门槛针口头。
- 不碰 `_arr`/`_tvp`/`_aft`/`_tvn`/`_tvx`/`_sth`/`_brd`/`_rtn`/`_lop`/`_cls`/`_wex`/`_ink`/`_aud`/`_sec`/`_hlp`/`_bpl`/`_msr`/`_vop`/`_opn`/`_thm`/`_ods`。

## 帘边驻足口头加厚（curtain-halt）

- 各章首拍在 `_rim6` 后、离开该拍前加 `_crn1`–`_crn6` 帘边驻足口头，全库去重；收束非旁白。
- 验收：`content_season_curtain_halt_chain_check` — hub chip → 帘边针口头。
- 不碰 `_arr`/`_tvp`/`_aft`/`_tvn`/`_tvx`/`_sth`/`_brd`/`_rtn`/`_lop`/`_cls`/`_wex`/`_ink`/`_aud`/`_sec`/`_hlp`/`_bpl`/`_msr`/`_vop`/`_opn`/`_thm`/`_ods`/`_rim`。

## 门风过袖口头加厚（sleeve-wind）

- 各章首拍在 `_crn6` 后、离开该拍前加 `_slv1`–`_slv6` 门风过袖口头，全库去重；收束非旁白。
- 验收：`content_season_sleeve_wind_chain_check` — hub chip → 门风针口头。
- 不碰 `_arr`/`_tvp`/`_aft`/`_tvn`/`_tvx`/`_sth`/`_brd`/`_rtn`/`_lop`/`_cls`/`_wex`/`_ink`/`_aud`/`_sec`/`_hlp`/`_bpl`/`_msr`/`_vop`/`_opn`/`_thm`/`_ods`/`_rim`/`_crn`。

## 缝光一瞥口头加厚（seam-glimpse）

- 各章首拍在 `_slv6` 后、离开该拍前加 `_gln1`–`_gln6` 缝光一瞥口头，全库去重；收束非旁白。
- 验收：`content_season_seam_glimpse_chain_check` — hub chip → 缝光针口头。
- 不碰 `_arr`/`_tvp`/`_aft`/`_tvn`/`_tvx`/`_sth`/`_brd`/`_rtn`/`_lop`/`_cls`/`_wex`/`_ink`/`_aud`/`_sec`/`_hlp`/`_bpl`/`_msr`/`_vop`/`_opn`/`_thm`/`_ods`/`_rim`/`_crn`/`_slv`。

## 门槛半步口头加厚（threshold-halfstep）

- 各章首拍在 `_gln6` 后、离开该拍前加 `_hst1`–`_hst6` 门槛半步口头，全库去重；收束非旁白。
- 验收：`content_season_threshold_halfstep_chain_check` — hub chip → 门槛半步针口头。
- 不碰既有 `_gln`/`_slv`/`_crn`/`_rim` 等 plate 链。

## 门闩一触口头加厚（latch-touch）

- 各章首拍在 `_hst6` 后、离开该拍前加 `_blt1`–`_blt6` 门闩一触口头，全库去重；收束非旁白。
- 验收：`content_season_latch_touch_chain_check` — hub chip → 门闩一触针口头。
- 不碰既有 `_hst`/`_gln`/`_slv`/`_crn`/`_rim` 等 plate 链。

## 门枢一转口头加厚（hinge-turn）

- 各章首拍在 `_blt6` 后、离开该拍前加 `_hng1`–`_hng6` 门枢一转口头，全库去重；收束非旁白。
- 验收：`content_season_hinge_turn_chain_check` — hub chip → 门枢一转针口头。
- 不碰既有 `_blt`/`_hst`/`_gln`/`_slv`/`_crn`/`_rim` 等 plate 链。

## 门轴一响口头加厚（axle-creak）

- 各章首拍在 `_hng6` 后、离开该拍前加 `_axl1`–`_axl6` 门轴一响口头，全库去重；收束非旁白。
- 验收：`content_season_axle_creak_chain_check` — hub chip → 门轴一响针口头。
- 不碰既有 `_hng`/`_blt`/`_hst`/`_gln`/`_slv`/`_crn`/`_rim` 等 plate 链。

## 门环一叩口头加厚（knocker-knock）

- 各章首拍在 `_axl6` 后、离开该拍前加 `_knk1`–`_knk6` 门环一叩口头，全库去重；收束非旁白。
- 验收：`content_season_knocker_knock_chain_check` — hub chip → 门环一叩针口头。
- 不碰既有 `_axl`/`_hng`/`_blt`/`_hst`/`_gln`/`_slv`/`_crn`/`_rim` 等 plate 链。
