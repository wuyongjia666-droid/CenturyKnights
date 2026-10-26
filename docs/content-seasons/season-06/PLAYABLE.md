# 内容季 #6 · 可玩章 ·《校场上的灯》

> 原著 [`NOVEL.md`](NOVEL.md) → 圣经 [`BIBLE.md`](BIBLE.md) → 游戏章 `project/data/story/chapters/cs06_01.json`。
> 口吻：大白话；单行 ≤60 汉字。团长键 `leader`。
> 验收：`content_season_playable_s06_check` 载入本章并走到对白，断言 schema + lint 干净 + 选「校场并排记」。

## 章信息

| 项 | 值 |
|---|---|
| id | `cs06_01` |
| 标题 | 校场上的灯 |
| legacy_index | 406 |
| 文件 | `project/data/story/chapters/cs06_01.json` |

## 拍列表

| 拍 | 标题 | 要做什么 |
|---|---|---|
| `yard` | 挂栏 | 可比试入名册；旗册誊栏 |
| `spar` | 校场 | 老管事出示未结；疤待对 |
| `hourglass` | 两行 | 沙漏上行栏、下行未结；并排 |
| `bridge` | 门廊 | 问谁站；带牌 |
| `tavern` | 选题 | 并排纸；选择 |
| `ledger` | 入册 | 末页入柜；收束 |

## 关键选择

- **校场并排记** → flag `cs06_kept_yard`，进 `ledger` 收束。
- **先钉胜者名** → flag `cs06_name_victor`，仍进收束，旁白点明沙漏还在亮。

## 说话人

旁白、leader、书记官、老管事、岁吏、槐里·青禾、石垒·晚担、苇原·灯影、老旗手、掌柜。

## 加深（本刀）

- 原著 `NOVEL.md` 中篇加厚至 ≥14k 汉字；优先人物弧与专属场景（空椅/沙圈/仪典），少用公式补页。
- 可玩章 `cs06_01.json` 对白加厚至 100+ 行；单行 ≤60 汉字。
- **所有权不变**：`hourglass` visit「去看月份怎么往前走」；`bridge` battle「先试一锋 / 再试锋镝 / 继续」。
- 验收：`content_season_playable_s06_check` 行数闸 ≥70；另跑 visit_authored / battle_authored / hub_entry。


## 第二可玩章（本刀）

| 项 | 值 |
|---|---|
| id | `cs06_02` |
| 标题 | 见章 JSON |
| 文件 | `project/data/story/chapters/cs06_02.json` |
| 验收 | `content_season_playable_s06_02_check` |

- 选题：**空条并排** → flag `cs06_book_parallel`；备选 **封胜催坐**。
- 所有权不变：`hourglass` visit「去看月份怎么往前走」；`bridge` battle「先试一锋 / 再试锋镝 / 继续」。
- 枢纽：`playable_chapters` 挂进 `StoryCatalog.content_season_entries`（主 `playable_chapter` 仍为 `_01`）。

## 加深（人物弧硬化 · 本刀）

- 小说去重：夜抄/校场重复段改为独有人物弧（青禾/晚担/灯影/岁吏等），汉字仍约 14k+。
- `cs06_01` 对白加厚至约 130 行；保留 visit@hourglass 与 battle@bridge CTA 原文。
- 前三拍收束不为旁白（plate-final），保证 return_portrait 走得到板面。
- suite 行数闸保持 ≥70；walk_to_choice 提到 200，兜住加厚对白。
- 主题：校场/胜册——并排留真，不催假胜/假入谱。

## 第二可玩章加深（本刀）

- `cs06_02` 口语加厚至约 124–130 行；保留 visit@hourglass / battle@bridge CTA 与 mid_lost 门闸。
- 前三拍收束不为旁白；suite walk_to_choice 提到 220。

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

## 开场主题口头加厚（theme-open）

- 各章首拍加 `_thm1`–`_thm6` 季题名著口头，全库去重；收束非旁白。
- 验收：`content_season_theme_open_chain_check` — hub chip → 首拍针口头 → 下一拍。
