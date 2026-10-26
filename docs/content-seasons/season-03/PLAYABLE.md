# 内容季 #3 · 可玩章 ·《榜上的收成》

> 原著 [`NOVEL.md`](NOVEL.md) → 圣经 [`BIBLE.md`](BIBLE.md) → 游戏章 `project/data/story/chapters/cs03_01.json`。
> 口吻：大白话；单行 ≤60 汉字。团长键 `leader`。
> 验收：`content_season_playable_s03_check` 载入本章并走到对白，断言 schema + lint 干净 + 选「功与粮并排」。

## 章信息

| 项 | 值 |
|---|---|
| id | `cs03_01` |
| 标题 | 榜上的收成 |
| legacy_index | 403 |
| 文件 | `project/data/story/chapters/cs03_01.json` |

## 拍列表

| 拍 | 标题 | 要做什么 |
|---|---|---|
| `merit` | 记功 | 书记官写朝报摘要；交付入栏 |
| `estate` | 月结 | 老管事出示属地月结；对不上 |
| `hourglass` | 两行 | 沙漏上行功、下行粮；并排刻 |
| `bridge` | 桥上 | 陆桥念拓片；粮价问下行 |
| `tavern` | 钉墙 | 白纸黄纸并排；选择 |
| `ledger` | 入册 | 对照册入柜；收束 |

## 关键

- **功与粮并排** → flag `cs03_kept_parallel`，进 `ledger` 收束。
- **先只留功** → flag `cs03_merit_only`，仍进收束，旁白点明黄纸还在墙上。

## 说话人

旁白、leader、书记官、老管事、槐里·青禾、石垒·晚担、苇原·灯影、老旗手、掌柜。  
`supporting_v92` 登记 **书记官**（若尚无）。

## 加深（本刀）

- 原著 `NOVEL.md` 中篇加厚至 ≥14k 汉字；优先人物弧与专属场景（功与粮），少用公式补页。
- 可玩章 `cs03_01.json` 对白加厚至 100+ 行；单行 ≤60 汉字。
- **所有权不变**：visit「去看月份怎么往前走」；battle「先试一锋 / 再试锋镝 / 继续」。
- 验收：`content_season_playable_s03_check` 行数闸 ≥70；另跑 visit_authored / battle_authored / hub_entry。
## 第二可玩章 · 榜阴上的灯

| 项 | 值 |
|---|---|
| id | `cs03_02` |
| 标题 | 榜阴上的灯 |
| legacy_index | 413 |
| 文件 | `project/data/story/chapters/cs03_02.json` |

回读章：正面已记，副面/阴面空行要能念。拍：主题开场 → 加深 → 沙漏 visit → 门廊试锋 → 酒馆选题 → 入谱。

- **功粮仍并** → flag `cs03_back_parallel`，进 `ledger`。
- 验收：`content_season_playable_s03_02_check`。

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
