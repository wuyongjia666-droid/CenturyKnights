# 内容季 #2 · 可玩章 ·《婚约上的灯》

> 原著 [`NOVEL.md`](NOVEL.md) → 圣经 [`BIBLE.md`](BIBLE.md) → 游戏章 `project/data/story/chapters/cs02_01.json`。
> 口吻：大白话；单行 ≤60 汉字。团长键 `leader`。
> 验收：`content_season_playable_s02_check` 载入本章并走到对白，断言 schema + lint 干净 + 选「两行并排留」。

## 章信息

| 项 | 值 |
|---|---|
| id | `cs02_01` |
| 标题 | 婚约上的灯 |
| legacy_index | 402 |
| 文件 | `project/data/story/chapters/cs02_01.json` |

## 拍列表

| 拍 | 标题 | 要做什么 |
|---|---|---|
| `seal` | 落印 | 书记官落印；姓写入名册 |
| `estate` | 属地条 | 老管事出示婚仪月回响；待诞育 |
| `birth` | 回执 | 听回写脉偏；两版都记 |
| `tavern` | 摘抄 | 掌柜挂板；留指甲痕 |
| `ledger` | 并排 | 选择：两行并排留 / 先压下行 |

## 关键

- **两行并排留** → flag `cs02_kept_parallel`，进 `ledger` 收束。
- **先压下行** → flag `cs02_held_lamp`，仍进收束，旁白点明半截话会自己长（对标原著「待对」）。

## 说话人

旁白、leader、书记官、老管事、听回、槐里·青禾、石垒·晚担、苇原·灯影、老旗手、掌柜。  
新增：`supporting_v92` 登记 **书记官**、**老管事**（若尚无）；**庭吏** 可玩章可不登场。

## 加深（本刀）

- 原著 `NOVEL.md` 中篇加厚至 ≥14k 汉字；优先人物弧与专属场景（婚约/验盏），少用公式补页。
- 可玩章 `cs02_01.json` 对白加厚至 100+ 行；单行 ≤60 汉字。
- **所有权不变**：visit「去看月份怎么往前走」；battle「先试一锋 / 再试锋镝 / 继续」。
- 验收：`content_season_playable_s02_check` 行数闸 ≥70；另跑 visit_authored / battle_authored / hub_entry。
## 第二可玩章 · 副笺上的灯

| 项 | 值 |
|---|---|
| id | `cs02_02` |
| 标题 | 副笺上的灯 |
| legacy_index | 412 |
| 文件 | `project/data/story/chapters/cs02_02.json` |

回读章：正面已记，副面/阴面空行要能念。拍：主题开场 → 加深 → 沙漏 visit → 门廊试锋 → 酒馆选题 → 入谱。

- **偏仍并排** → flag `cs02_slip_parallel`，进 `ledger`。
- 验收：`content_season_playable_s02_02_check`。
