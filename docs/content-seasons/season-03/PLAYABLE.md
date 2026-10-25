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

## 第二可玩章 · 榜阴上的灯

| 项 | 值 |
|---|---|
| id | `cs03_02` |
| 标题 | 榜阴上的灯 |
| legacy_index | 413 |
| 文件 | `project/data/story/chapters/cs03_02.json` |

回读章：正面已记，副面/阴面空行要能念。拍：主题开场 → 加深 → 沙漏 visit → 门廊试锋 → 酒馆选题 → 入谱。

- **功粮仍并** → flag `cs03_back_parallel`，进 `ledger`。
- 验收：`content_season_playable_s03_02_check`。
