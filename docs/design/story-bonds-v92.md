# 羁绊 v9.2（NAR-04）

同伴两两积累点数。`Bonds.rank(a, b)` 给战斗流用，返回 `"C"`、`"B"`、`"A"`，没有结阶时返回空字符串。`a` 和 `b` 可以是同伴 id、`cast_key`，或名册上的名字。

点数存在 `story.flags`，键是 `bond:较小id|较大id`。新游戏会随故事旗标一起清掉。存档走现有的 `chapter0_flags`。

| 阶 | 点数 |
|---|---|
| C | 2 |
| B | 5 |
| A | 9 |

`Bonds.note_adjacent(a, b)` 记一场相邻作战，返回新的阶。`Bonds.note_battle(units)` 在战斗结束时调用，只统计存活己方同伴，切比雪夫距离为 1 算相邻，同一对每场只加 1 点。`Bonds.note_event(a, b, amount)` 给定剧情加点。

已解锁的段在 `res://scenes/story/support_viewer.tscn` 里看。城堡按钮归 UX：有 `Bonds.available()` 时打开这个场景。战斗结束处归 BTL：`battle_finished` 之后调用 `Bonds.note_battle(units)`。

首批 40 段在 `data/story/supports/era_bonds.json`，每段带 `C`、`B` 或 `A`。
