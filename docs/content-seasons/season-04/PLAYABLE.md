# 内容季 #4 · 可玩章 ·《家训上的灯》

> 原著 [`NOVEL.md`](NOVEL.md) → 圣经 [`BIBLE.md`](BIBLE.md) → 游戏章 `project/data/story/chapters/cs04_01.json`。
> 口吻：大白话；单行 ≤60 汉字。团长键 `leader`。
> 验收：`content_season_playable_s04_check` 载入本章并走到对白，断言 schema + lint 干净 + 选「训与行并排」。

## 章信息

| 项 | 值 |
|---|---|
| id | `cs04_01` |
| 标题 | 家训上的灯 |
| legacy_index | 404 |
| 文件 | `project/data/story/chapters/cs04_01.json` |

## 拍列表

| 拍 | 标题 | 要做什么 |
|---|---|---|
| `preach` | 挂训 | 绣词入旗角；旗册誊名 |
| `echo` | 月结 | 老管事出示家训回响；对不上 |
| `hourglass` | 两行 | 沙漏上行名、下行数；并排 |
| `bridge` | 门廊 | 问粮；带牌 |
| `tavern` | 选题 | 并排纸；选择 |
| `ledger` | 入册 | 末页入柜；收束 |

## 关键

- **训与行并排** → flag `cs04_kept_parallel`，进 `ledger` 收束。
- **先只留训条** → flag `cs04_doctrine_only`，仍进收束，旁白点明沙漏还在亮。

## 说话人

旁白、leader、书记官、老管事、槐里·青禾、石垒·晚担、苇原·灯影、老旗手、掌柜。

## 加深（本刀）

- 原著 `NOVEL.md` 中篇加厚至 ≥14k 汉字；优先人物弧与专属场景（家训与行），少用公式补页。
- 可玩章 `cs04_01.json` 对白加厚至 100+ 行；单行 ≤60 汉字。
- **所有权不变**：visit「去看月份怎么往前走」；battle「先试一锋 / 再试锋镝 / 继续」。
- 验收：`content_season_playable_s04_check` 行数闸 ≥70；另跑 visit_authored / battle_authored / hub_entry。
## 第二可玩章 · 训阴上的灯

| 项 | 值 |
|---|---|
| id | `cs04_02` |
| 标题 | 训阴上的灯 |
| legacy_index | 414 |
| 文件 | `project/data/story/chapters/cs04_02.json` |

回读章：正面已记，副面/阴面空行要能念。拍：主题开场 → 加深 → 沙漏 visit → 门廊试锋 → 酒馆选题 → 入谱。

- **训行仍并** → flag `cs04_back_parallel`，进 `ledger`。
- 验收：`content_season_playable_s04_02_check`。

## 中章口头去套话（mid-oral）

- 访/战/酒馆回程里跨章复读的套话改成该拍自己的句子；入谱拍不动。
- 前三拍无条件收束仍不是旁白。CTA、`锋收回来`、`mid_lost` 门闸不变。
- `_02` 胜后口语的 `when` 改挂本章 `csNN_02_mid_fought`，试锋得手才念得出。
- 真 E2E：`content_season_mid_oral_chain_check`（hub→章→战/访→回，二十章；断链或中章复读即失败）。

## 中途战 / 据点 / 回程加厚（hub-chain）

- 中途战拍：试锋前口语加厚；`mid_lost` 仍为拍末可见行（needle「锋收回来」）。
- 据点 visit 拍：时漏/验盏前口语加厚；CTA「去看月份怎么往前走」不变。
- 酒馆回程：挂板前口语加厚，收束回堡入谱。
- 真 E2E：`content_season_hub_chain_check`（hub→章→战/访→回抽样）；`battle_retry` LIVE 扩至 S01–S10 `_01`；playable walk_to_choice→220。

- mid_fought 胜后口语 + 据点 visit/酒馆回程加厚（全十季 _01/_02）；`hub_chain` LIVE 扩至 cs01–cs10 _01。

## 沙漏 visit 口头加厚（visit-oral）

- 各章 visit 拍（hourglass/audit/birth）加厚季题名著口头（`_vhg*`），全库去重。
- 验收：`content_season_visit_oral_chain_check` — hub chip → 针口头 → 去看月份 → 同拍回 → 继续。
