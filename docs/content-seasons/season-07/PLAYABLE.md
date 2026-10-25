# 内容季 #7 · 可玩章 ·《仪典上的灯》

> 原著 [`NOVEL.md`](NOVEL.md) → 圣经 [`BIBLE.md`](BIBLE.md) → 游戏章 `project/data/story/chapters/cs07_01.json`。
> 口吻：大白话；单行 ≤60 汉字。团长键 `leader`。
> 验收：`content_season_playable_s07_check` 载入本章并走到对白，断言 schema + lint 干净 + 选「仪典并排记」。

## 章信息

| 项 | 值 |
|---|---|
| id | `cs07_01` |
| 标题 | 仪典上的灯 |
| legacy_index | 407 |
| 文件 | `project/data/story/chapters/cs07_01.json` |

## 拍列表

| 拍 | 标题 | 要做什么 |
|---|---|---|
| `yard` | 挂栏 | 路名入名册；旗册誊栏 |
| `rite` | 仪典 | 老管事出示未结；盖印待对 |
| `hourglass` | 两行 | 沙漏上行栏、下行未结；并排 |
| `bridge` | 门廊 | 问谁入；带牌 |
| `tavern` | 选题 | 并排纸；选择 |
| `ledger` | 入册 | 末页入柜；收束 |

## 关键选择

- **仪典并排记** → flag `cs07_kept_rite`，进 `ledger` 收束。
- **先钉路名** → flag `cs07_name_path`，仍进收束，旁白点明沙漏还在亮。

## 说话人

旁白、leader、书记官、老管事、岁吏、槐里·青禾、石垒·晚担、苇原·灯影、老旗手、掌柜。

## 加深（本刀）

- 原著 `NOVEL.md` 中篇加厚至 ≥14k 汉字；优先人物弧与专属场景（空椅/沙圈/仪典），少用公式补页。
- 可玩章 `cs07_01.json` 对白加厚至 100+ 行；单行 ≤60 汉字。
- **所有权不变**：`hourglass` visit「去看月份怎么往前走」；`bridge` battle「先试一锋 / 再试锋镝 / 继续」。
- 验收：`content_season_playable_s07_check` 行数闸 ≥70；另跑 visit_authored / battle_authored / hub_entry。


## 第二可玩章（本刀）

| 项 | 值 |
|---|---|
| id | `cs07_02` |
| 标题 | 见章 JSON |
| 文件 | `project/data/story/chapters/cs07_02.json` |
| 验收 | `content_season_playable_s07_02_check` |

- 选题：**空条并排** → flag `cs07_gene_parallel`；备选 **封路催坐**。
- 所有权不变：`hourglass` visit「去看月份怎么往前走」；`bridge` battle「先试一锋 / 再试锋镝 / 继续」。
- 枢纽：`playable_chapters` 挂进 `StoryCatalog.content_season_entries`（主 `playable_chapter` 仍为 `_01`）。

## 加深（人物弧硬化 · 本刀）

- 小说去重：夜抄/校场重复段改为独有人物弧（青禾/晚担/灯影/岁吏等），汉字仍约 14k+。
- `cs07_01` 对白加厚至约 130 行；保留 visit@hourglass 与 battle@bridge CTA 原文。
- 前三拍收束不为旁白（plate-final），保证 return_portrait 走得到板面。
- suite 行数闸保持 ≥70；walk_to_choice 提到 200，兜住加厚对白。
- 主题：仪典/宗谱——并排留真，不催假胜/假入谱。
