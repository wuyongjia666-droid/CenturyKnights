# 内容季 #5 · 可玩章 ·《空椅上的灯》

> 原著 [`NOVEL.md`](NOVEL.md) → 圣经 [`BIBLE.md`](BIBLE.md) → 游戏章 `project/data/story/chapters/cs05_01.json`。
> 口吻：大白话；单行 ≤60 汉字。团长键 `leader`。
> 验收：`content_season_playable_s05_check` 载入本章并走到对白，断言 schema + lint 干净 + 选「空椅并排链」。

## 章信息

| 项 | 值 |
|---|---|
| id | `cs05_01` |
| 标题 | 空椅上的灯 |
| legacy_index | 405 |
| 文件 | `project/data/story/chapters/cs05_01.json` |

## 拍列表

| 拍 | 标题 | 要做什么 |
|---|---|---|
| `court` | 挂栏 | 待定嗣入名册；旗册誊栏 |
| `chair` | 空椅 | 老管事出示椅空；链未到 |
| `hourglass` | 两行 | 沙漏上行栏、下行空；并排 |
| `bridge` | 门廊 | 问谁坐；带牌 |
| `tavern` | 选题 | 并排纸；选择 |
| `ledger` | 入册 | 末页入柜；收束 |

## 关键

- **空椅并排链** → flag `cs05_kept_chain`，进 `ledger` 收束。
- **先钉名上椅** → flag `cs05_name_first`，仍进收束，旁白点明沙漏还在亮。

## 说话人

旁白、leader、书记官、老管事、岁吏、槐里·青禾、石垒·晚担、苇原·灯影、老旗手、掌柜。

## 加深（本刀）

- 原著 `NOVEL.md` 中篇加厚至 ≥14k 汉字；优先人物弧与专属场景（空椅/沙圈/仪典），少用公式补页。
- 可玩章 `cs05_01.json` 对白加厚至 100+ 行；单行 ≤60 汉字。
- **所有权不变**：`hourglass` visit「去看月份怎么往前走」；`bridge` battle「先试一锋 / 再试锋镝 / 继续」。
- 验收：`content_season_playable_s05_check` 行数闸 ≥70；另跑 visit_authored / battle_authored / hub_entry。


## 第二可玩章（本刀）

| 项 | 值 |
|---|---|
| id | `cs05_02` |
| 标题 | 见章 JSON |
| 文件 | `project/data/story/chapters/cs05_02.json` |
| 验收 | `content_season_playable_s05_02_check` |

- 选题：**链仍并排** → flag `cs05_reread_parallel`；备选 **栏优先催坐**。
- 所有权不变：`hourglass` visit「去看月份怎么往前走」；`bridge` battle「先试一锋 / 再试锋镝 / 继续」。
- 枢纽：`playable_chapters` 挂进 `StoryCatalog.content_season_entries`（主 `playable_chapter` 仍为 `_01`）。

## plate-final

前三拍收束不为旁白，保证 return_portrait 走得到具名板面。

## 第二可玩章加深（本刀）

- `cs05_02` 口语加厚至约 124–130 行；保留 visit@hourglass / battle@bridge CTA 与 mid_lost 门闸。
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

## 酒馆挂板口头加厚（tavern-plate）

- 各章 `tavern` 拍入谱选择前加 `_tvp1`–`_tvp6` 季题名著口头，全库去重；收束非旁白。
- 验收：`content_season_tavern_plate_chain_check` — hub chip → 酒馆针口头 → 挂板选择 → ledger。

## 开场主题口头加厚（theme-open）

- 各章首拍加 `_thm1`–`_thm6` 季题名著口头，全库去重；收束非旁白。
- 验收：`content_season_theme_open_chain_check` — hub chip → 首拍针口头 → 下一拍。


## 章末收束口头（close-oral）

- 各章 `ledger` 拍末 `_cls1`–`_cls8`：战后回家、把这一季的东西放进柜、季尾灯影。全库去重；末句不是旁白。
- 跨章复读的入谱套话改成该季自己的句子。不新开内容季，不写 EmptyHost，不加 month_echo。
- 不碰开场 `_thm`、二拍 `_sec`、访月 `_vhg`/`_msr`、战拍 `_bpl`、酒馆 `_tvp`、入谱回程 `_ldg`。
- 验收：`content_season_close_oral_chain_check` — hub 芯片 → 章末收束口头 → 回到灰旗堡。
