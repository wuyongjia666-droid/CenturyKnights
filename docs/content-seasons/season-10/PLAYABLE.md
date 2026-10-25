# 内容季 #10 · 可玩章 ·《印上的灯》

> 原著 [`NOVEL.md`](NOVEL.md) → 圣经 [`BIBLE.md`](BIBLE.md) → 游戏章 `project/data/story/chapters/cs10_01.json`。
> 口吻：大白话；单行 ≤60 汉字。团长键 `leader`。
> 验收：`content_season_playable_s10_check` 载入本章并走到对白，断言 schema + lint 干净 + 选「城印并排记」。

## 章信息

| 项 | 值 |
|---|---|
| id | `cs10_01` |
| 标题 | 印上的灯 |
| legacy_index | 410 |
| 文件 | `project/data/story/chapters/cs10_01.json` |

## 拍列表

| 拍 | 标题 | 要做什么 |
|---|---|---|
| `yard` | 挂栏 | 城印名入名册；旗册誊栏 |
| `affairs` | 本城之事 | 老管事出示未办；声望不足 |
| `seal` | 盖印 | 六门印厅；印未盖档案红脸 |
| `hourglass` | 两行 | 沙漏上行栏、下行未盖；并排 |
| `bridge` | 门廊 | 问谁盖印；带牌 |
| `tavern` | 选题 | 并排纸；选择 |
| `ledger` | 入册 | 末页入柜；收束 |

## 关键选择

- **城印并排记** → flag `cs10_kept_seal`，进 `ledger` 收束。
- **先钉城印** → flag `cs10_name_seal`，仍进收束，旁白点明沙漏还在亮。

## 说话人

旁白、leader、书记官、老管事、岁吏、槐里·青禾、石垒·晚担、苇原·灯影、老旗手、掌柜。

## 对白规则

单行 ≤60 汉字；大白话；机制点名：职印、盖印、本城之事、声望、沙漏两行、六门印。

## 加深（本刀）

- 原著 `NOVEL.md` 中篇汉字 ≥12000，场景与对照册加厚，口吻口语化。
- 可玩章 `cs10_01.json` 对白加厚至 100+ 行；单行仍 ≤60 汉字。
- **所有权不变**：`hourglass` 拍挂 visit「去看月份怎么往前走」；`bridge` 拍挂 battle「先试一锋 / 再试锋镝 / 继续」。
- 验收：`content_season_playable_s10_check` 行数闸提高到 ≥70；另跑 visit_authored / battle_authored / hub_entry。


## 第二可玩章（本刀）

| 项 | 值 |
|---|---|
| id | `cs10_02` |
| 标题 | 印底上的灯 |
| 文件 | `project/data/story/chapters/cs10_02.json` |
| 验收 | `content_season_playable_s10_02_check` |

- 选题：**印底并排留** → flag `cs10_base_parallel`；备选 **先催城印**。
- 所有权不变：`hourglass` visit「去看月份怎么往前走」；`bridge` battle「先试一锋 / 再试锋镝 / 继续」。
- 枢纽：`playable_chapters` 挂进 `StoryCatalog.content_season_entries`（主 `playable_chapter` 仍为 `_01`）。

## 第二可玩章加深（本刀）

- `cs10_02` 口语加厚至约 124–130 行；保留 visit@hourglass / battle@bridge CTA 与 mid_lost 门闸。
- 前三拍收束不为旁白；suite walk_to_choice 提到 220。
