# 内容季 #1 · 可玩章 ·《回执上的灯》

> 原著 [`NOVEL.md`](NOVEL.md) → 圣经 [`BIBLE.md`](BIBLE.md) → 游戏章 `project/data/story/chapters/cs01_01.json`。
> 口吻：大白话；单行 ≤60 汉字。团长键 `leader`。
> 验收：`suite_content_season_playable_check` 载入本章并走到对白，断言 schema + lint 干净 + 关键「把无写进谱」。

## 章信息

| 项 | 值 |
|---|---|
| id | `cs01_01` |
| 标题 | 回执上的灯 |
| legacy_index | 401 |
| 文件 | `project/data/story/chapters/cs01_01.json` |

## 拍列表

| 拍 | 标题 | 要做什么 |
|---|---|---|
| `open` | 纸先到 | 岁吏送回执；看见空格子 |
| `hall` | 空格子 | 青禾 / 晚担 / 灯影表态 |
| `audit` | 验盏 | 听回写「无」；团长确认 |
| `tavern` | 挂板 | 掌柜挂七天；闲话起 |
| `ledger` | 入谱 | 选择：把无写进谱 / 先压下不挂 |

## 关键

- **把无写进谱** → flag `cs01_wrote_wu`，进 `ledger` 收束。
- **先压下不挂** → flag `cs01_held_back`，仍进收束，但旁白点明纸会自己找路（对标原著「不签则挂酒馆」）。

## 说话人

旁白、leader、岁吏、听回、槐里·青禾、石垒·晚担、苇原·灯影、老旗手、掌柜。  
新增：`supporting_v92` 登记 **岁吏**、**听回**。

## 加深（深散文轨）

- 对白加厚至约 108 行；suite 行数闸 30→70，walk_to_choice 40→140。
- 保留厅前试锋 CTA「先试一锋 / 再试锋镝 / 继续，去验盏」与验盏 visit「去看月份怎么往前走」。
- 收束选择不变：「把无写进谱」/「先压下不挂谱」。

## 第二可玩章 · 副页上的灯

| 项 | 值 |
|---|---|
| id | `cs01_02` |
| 标题 | 副页上的灯 |
| legacy_index | 411 |
| 文件 | `project/data/story/chapters/cs01_02.json` |

回读章：正面已记，副面/阴面空行要能念。拍：主题开场 → 加深 → 沙漏 visit → 门廊试锋 → 酒馆选题 → 入谱。

- **空格并排留** → flag `cs01_slip_parallel`，进 `ledger`。
- 验收：`content_season_playable_s01_02_check`。

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

## 西阁开柜口头加厚（ledger-open）

- 各章 `ledger` 拍首加 `_lop1`–`_lop6` 进阁开柜口头（`_ldg`/`_cls` 前），全库去重；收束非旁白。
- 验收：`content_season_ledger_open_chain_check` — hub chip → 开柜针口头。
- 不碰 `_bpl`/`_sec`/`_arr`/`_cls`/`_msr`/`_tvp`。
