# 内容季 #9 · 可玩章 ·《血验上的灯》

> 原著 [`NOVEL.md`](NOVEL.md) → 圣经 [`BIBLE.md`](BIBLE.md) → 游戏章 `project/data/story/chapters/cs09_01.json`。
> 口吻：大白话；单行 ≤60 汉字。团长键 `leader`。
> 验收：`content_season_playable_s09_check` 载入本章并走到对白，断言 schema + lint 干净 + 选「血验并排记」。

## 章信息

| 项 | 值 |
|---|---|
| id | `cs09_01` |
| 标题 | 血验上的灯 |
| legacy_index | 409 |
| 文件 | `project/data/story/chapters/cs09_01.json` |

## 拍列表

| 拍 | 标题 | 要做什么 |
|---|---|---|
| `yard` | 挂栏 | 血名入名册；旗册誊栏 |
| `blood` | 血验 | 老管事出示未结；点验待对 |
| `hourglass` | 两行 | 沙漏上行栏、下行未结；并排 |
| `bridge` | 门廊 | 问谁入验；带牌 |
| `tavern` | 选题 | 并排纸；选择 |
| `ledger` | 入册 | 末页入柜；收束 |

## 关键选择

- **血验并排记** → flag `cs09_kept_blood`，进 `ledger` 收束。
- **先钉血名** → flag `cs09_name_blood`，仍进收束，旁白点明沙漏还在亮。

## 说话人

旁白、leader、书记官、老管事、岁吏、槐里·青禾、石垒·晚担、苇原·灯影、老旗手、掌柜。

## 加深（本刀）

- 原著 `NOVEL.md` 中篇汉字 ≥12000，场景与对照册加厚，口吻口语化。
- 可玩章 `cs09_01.json` 对白加厚至 100+ 行；单行仍 ≤60 汉字。
- **所有权不变**：`hourglass` 拍挂 visit「去看月份怎么往前走」；`bridge` 拍挂 battle「先试一锋 / 再试锋镝 / 继续」。
- 验收：`content_season_playable_s09_check` 行数闸提高到 ≥70；另跑 visit_authored / battle_authored / hub_entry。


## 第二可玩章（本刀）

| 项 | 值 |
|---|---|
| id | `cs09_02` |
| 标题 | 验册上的灯 |
| 文件 | `project/data/story/chapters/cs09_02.json` |
| 验收 | `content_season_playable_s09_02_check` |

- 选题：**验空并排** → flag `cs09_book_parallel`；备选 **先催血名**。
- 所有权不变：`hourglass` visit「去看月份怎么往前走」；`bridge` battle「先试一锋 / 再试锋镝 / 继续」。
- 枢纽：`playable_chapters` 挂进 `StoryCatalog.content_season_entries`（主 `playable_chapter` 仍为 `_01`）。
