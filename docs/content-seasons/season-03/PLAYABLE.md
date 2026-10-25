# 内容季 #3 · 可玩章 ·《榜上的收成》

> 原著 [`NOVEL.md`](NOVEL.md) → 圣经 [`BIBLE.md`](BIBLE.md) → 游戏章 `project/data/story/chapters/cs03_01.json`。
> 口吻：大白话；单行 ≤60 汉字。团长键 `leader`。
> 验收：`content_season_playable_s03_check` 载入本章并走到对白，断言 schema + lint 干净 + 选「功与粮并排」。

## 章信息

| 项 | 值 |
|---|---|
| id | `cs03_01` |
| 标题 | 榜上的收成 |
| legacy_index | 403 |
| 文件 | `project/data/story/chapters/cs03_01.json` |

## 拍列表

| 拍 | 标题 | 要做什么 |
|---|---|---|
| `merit` | 记功 | 书记官写朝报摘要；交付入栏 |
| `estate` | 月结 | 老管事出示属地月结；对不上 |
| `hourglass` | 两行 | 沙漏上行功、下行粮；并排刻 |
| `bridge` | 桥上 | 陆桥念拓片；粮价问下行 |
| `tavern` | 钉墙 | 白纸黄纸并排；选择 |
| `ledger` | 入册 | 对照册入柜；收束 |

## 关键

- **功与粮并排** → flag `cs03_kept_parallel`，进 `ledger` 收束。
- **先只留功** → flag `cs03_merit_only`，仍进收束，旁白点明黄纸还在墙上。

## 说话人

旁白、leader、书记官、老管事、槐里·青禾、石垒·晚担、苇原·灯影、老旗手、掌柜。  
`supporting_v92` 登记 **书记官**（若尚无）。

## 加深（本刀）

- 原著 `NOVEL.md` 中篇加厚至 ≥14k 汉字；优先人物弧与专属场景（功与粮），少用公式补页。
- 可玩章 `cs03_01.json` 对白加厚至 100+ 行；单行 ≤60 汉字。
- **所有权不变**：visit「去看月份怎么往前走」；battle「先试一锋 / 再试锋镝 / 继续」。
- 验收：`content_season_playable_s03_check` 行数闸 ≥70；另跑 visit_authored / battle_authored / hub_entry。
