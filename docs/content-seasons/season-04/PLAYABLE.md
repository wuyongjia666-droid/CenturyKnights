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
