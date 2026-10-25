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

## 加深（深散文轨）

- 对白加厚至约 108 行；suite 行数闸 30→70，walk_to_choice 40→140。
- 保留厅前试锋 CTA「先试一锋 / 再试锋镝 / 继续，去验盏」与验盏 visit「去看月份怎么往前走」。
- 收束选择不变：「把无写进谱」/「先压下不挂谱」。

## 第二可玩章 · 副页上的灯

| 项 | 值 |
|---|---|
| id | `cs01_02` |
| 标题 | 副页上的灯 |
| legacy_index | 411 |
| 文件 | `project/data/story/chapters/cs01_02.json` |

回读章：正面已记，副面/阴面空行要能念。拍：主题开场 → 加深 → 沙漏 visit → 门廊试锋 → 酒馆选题 → 入谱。

- **空格并排留** → flag `cs01_slip_parallel`，进 `ledger`。
- 验收：`content_season_playable_s01_02_check`。

## plate-final

前三拍收束不为旁白，保证 return_portrait 走得到具名板面。
