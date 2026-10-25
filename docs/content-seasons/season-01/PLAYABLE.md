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
