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
