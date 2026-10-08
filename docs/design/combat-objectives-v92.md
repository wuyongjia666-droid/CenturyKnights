# 战斗目标 v9.2

判定代码在 `BattleObjectives`（`project/scripts/battle/objectives.gd`）。战斗控制器只负责调用：部署时 `deploy_npcs`，回合开始和玩家落子后 `spawn_due`，然后 `outcome`。顶栏文案在 `ObjectiveHud`（`project/scripts/battle/ui/objective_hud.gd`），中文来自 `project/data/locale/battle.csv`。

没有 `objective` 字段的图，类型是 `rout`。400 张旧图因此仍是歼灭战。

## 字段

`objective.type`：

| type | 字段 | 胜利 |
|---|---|---|
| rout | 无 | 场上没有存活的 `team == "enemy"` |
| seize | `tile: [x, y]` | 有存活玩家站在该格 |
| defend | `tiles`, `turns` | 回合数 ≥ `turns`，且每一格都有存活玩家 |
| survive | `turns` | 回合数 ≥ `turns`，且至少一名玩家存活 |
| escort | `npc`（单位 tag）, `exit_tile` | 该 tag 的单位存活并站在出口 |
| boss | `unit_tag` | 该 tag 已经登场，且全部倒下 |
| escape | `n`, `exit_tiles` | 站在任一出口上的存活玩家 ≥ `n` |
| protect | `unit_tag` | 该 tag 存活，且敌军已清空 |

`failure`（可与任意目标并用）：

| 字段 | 失败原因 |
|---|---|
| `leader_down: true` | 已部署的玩家主将 `hp <= 0` |
| `vip_down: "<tag>"` | 该 tag 已登场且没有存活者 |
| `turn_limit: N` | `_round_no > N` |

护送目标或保护目标倒下时，原因同为 `vip_down`，不必再写 `failure`。玩家全灭且胜利条件尚未成立时，原因是 `wipe`。

回合数在玩家回合开始时加一，开战即为第 1 回合。`survive` / `defend` 用 `>=`，`turn_limit` 用 `>`。因此「守 2 回合、上限 3 回合」会在第 2 回合开始、人已站上据点时获胜；第 4 回合开始仍未达成则因上限失败。

## 判定顺序

`outcome`：

1. 胜利条件已经成立则胜。歼灭在双方同归于尽时仍算胜，与改前 `_check_end` 先看敌军是否清空一致。斩首、占领、撤离同理：条件先成立就胜。
2. 否则依次检查主将倒下、保护/护送对象倒下、`failure.vip_down`、回合上限、玩家全灭。
3. 都没有则战斗继续。

友军 `team == "ally"` 不算敌军，也不算玩家。占领、防守、生存、撤离只数玩家。护送看 tag，不看队伍。

未登场的增援不阻止歼灭。波次要在胜利条件达成前出现，就把 `turn` 写在仍有敌军活着的回合里。

## 增援

`reinforcements[]`：`id`、`team`、`spots`、`templates`、`tags`，外加 `turn` 或 `trigger_tile`（可同时写，满足其一即触发）。`id` 只触发一次，记在战斗节点的 `reinf_done`。

出生格若有存活单位，按曼哈顿距离 1、2、3 找空格。三环内没有空格就跳过这个单位，不再补刷。

开战 NPC 写在 `npcs[]`（`name`、`tag`、`spot`、`team`），用 `CKCharacter.new()` 生成友军，不走 `CharacterFactory.make_enemy`。敌军增援仍走 `make_enemy`。普通敌军的 tag 写在与 `enemy_templates` 对齐的 `enemy_tags`。

玩家与友军互不构成控制带（`_same_side`）。敌军会把友军当作可攻击目标。

## 目标 HUD

`ObjectiveHud` 是顶栏里的一条玻璃条，用 `UIKit` 的 glass、accent、text。桌面和已经按安全区挪过根节点的手机布局，放在右上 `(904, 12)`，与右侧栏同宽，不压棋盘。

若节点上已有 `mobile_insets` 但根节点还留在原点，条带改到 `top + 8`。1080×2400 上由 `MobileLayout.fit` 把整块 1280×720 根放进安全区后，条带的全局矩形落在安全区内部。

## 测试图

`project/data/maps/test_objectives.json` 每种胜利条件一张，另有主将失败、回合增援、踩格增援。不改 `data/maps.json` 里的旧图。
