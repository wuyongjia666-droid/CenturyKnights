# 战斗规则 v9.2（单一来源）

数字以 `project/autoload/battle_rules.gd` 的常量与函数为准。信息面板通过 `BattleRules.engagement_note` 读取脱离消耗，不另写死数字。

本文件只记录现有规则，不改公式。对标作品的数值没有被搬进来。

## 派生属性

`CKCharacter`（`project/scripts/characters/character.gd`）

| 属性 | 公式 | 位置 |
|---|---|---|
| 命中基础 | 70 + 技 + 敏/2 + 临时命中 + 装备 | `derived_hit` |
| 攻击 | 职业 `base_atk` + 力/2 + 武器 + 装备 | `derived_atk` |
| 防御 | 职业 `base_def` + 体/3 + 临时防御 − 破防 + 装备 | `derived_def` |
| 回避 | 敏 + 感/2 + 装备 | `derived_avo` |
| 暴击率 | 5 + 技/3；特质 `lucky` 再 +3；再加临时暴击与装备 | `derived_crit` |
| 移动 | 职业 `move` + 装备 | `derived_move` |

除法按 Godot 的浮点除法再取整，正数相当于向零截断。

## 地形

`BattleRules.TERRAIN` / `terrain_info`

| id | 名 | 移动消耗 | 回避 | 防御 |
|---|---|---|---|---|
| plain | 平地 | 1 | 0 | 0 |
| forest | 林 | 2 | 15 | 1 |
| hill | 丘 | 2 | 10 | 2 |
| water | 水 | 3 | 5 | 0 |
| bridge | 桥 | 1 | 0 | 0 |
| fort | 垒 | 2 | 20 | 3 |

## 命中

`calc_hit`

1. 从攻击方命中基础减去防守方回避。
2. 防守方所在地形的回避加成乘以 `extras.terrain_mul`（默认 1）后加入回避。
3. 攻击方有 `brave` 且为近战：命中 +5。有 `keen_eye` 且非近战：命中 +5。
4. 防守方有 `night_owl` 且地形是林：回避 +5。
5. 等级差 × 2 加入命中。
6. 夹击（`extras.flank`）：命中 + `FLANK_HIT`（15）。
7. 加上兵种克制的 `hit_mod` 与 `extras.hit_mod`。
8. 结果限制在 `HIT_MIN`–`HIT_MAX`（5–99）。

## 伤害

`calc_damage_range`

1. 地形防御 × `terrain_mul`，再加上 `extras.flat_def`。
2. 有效防御 = 防守派生防御 + 地形防御 + 克制 `def_mod`。
3. 原始伤害 = max(1, 攻击 − 有效防御/2)。
4. 加上克制 `dmg_mod`。夹击再 + `FLANK_DMG`（1）。再加上 `extras.dmg_mod`。
5. 显示区间是 [max(1, 原始−1), max(1, 原始+1)]。

掷骰在 `roll_attack`：1–100 ≤ 命中则命中；命中后再掷 1–100 ≤ 暴击率则暴击，伤害变为 `int(伤害 × CRIT_MULT)`，`CRIT_MULT` 为 1.5。暴击在扣血之前乘算。

## 兵种克制

`job_role` / `role_mods`。职业来自 `project/data/jobs.json`。

| 职能 | 判定 |
|---|---|
| tank | `heavy_inf`、`warrior` |
| cavalry | `light_cavalry`、`squire` |
| ranger | `atk_type == ranged` |
| mage | `atk_type == magic` |
| skirmisher | 其余近战 |

修正按下面的顺序累加，标签被后写的覆盖：

| 条件 | 命中 | 伤害 | 防御（加在防守方） | 标签 |
|---|---|---|---|---|
| 近战职能打 ranger | 0 | +2 | 0 | 近压远 |
| ranger 打轻步或骑突 | +8 | 0 | 0 | 远射克 |
| mage 打 tank | 0 | +3 | 0 | 秘破甲 |
| tank 挨轻步或骑突打 | 0 | 0 | +2 | 铁壁承 |
| 骑突打秘术或轻步 | +5 | +2 | 0 | 骑突 |

## 夹击、连击、反击

| 规则 | 位置 | 常量 / 条件 |
|---|---|---|
| 夹击 | `has_flank` | 防守格相邻还有一名存活的攻击方同伴，且不是攻击者本人 |
| 连击 | `can_follow_up` | 攻击方敏 ≥ 防守方敏 + `FOLLOW_UP_AGI`（4） |
| 反击 | `can_counter` | 防守方仍存活。近战距离恰好 1。远程或秘术距离 1 或 2 |

`preview` 的命中和伤害区间必须等于 `calc_hit` 与 `calc_damage_range`。连击、夹击、克制标签写在 `preview.tags`。

## 控制地带与脱离

`in_zoc` / `move_costs` / `leave_cost_for`

相邻敌人格是控带。进入控带后不能再往外走。从控带走到非控带时，这一步的移动消耗加上脱离代价。

| 状态 | 常量 | 现在的值 | 谁在用 |
|---|---|---|---|
| 未交战（这一步其实加不到脱离上） | `LEAVE_COST_DEFAULT` | 1 | `leave_cost_for` |
| 人在控带里 | `LEAVE_COST_ENGAGED` | 2 | `battle_controller._compute_move_cells` |
| 交战锁定 | `LEAVE_COST_LOCK` | 3 | 同上，优先于控带 |

`extras`：`ignore_zoc` 忽略控带；`leave_free` 不加脱离代价；`zoc_extra_cost` 在走进控带时再加。

面板与锁定教学文案走 `engagement_note` 和这两个常量。以前面板写的是「锁定 +2、交战 +1」，和实际传给 `move_costs` 的 3 / 2 不一致。现在文案直接显示常量。

## 血统战术

`tac` 读 `CKCharacter.tactical_amount`。基因组为空时返回 0，避免公式夹具在第一次查询时抽开国者。键和效果：

| 键 | 效果 | 代码 |
|---|---|---|
| range_high | 站在丘上时攻击距离 +数量 | `attack_reach` |
| counter | `extras.counter` 时伤害 +数量 | `calc_damage_range` |
| night_hit | `extras.night` 时命中 +数量 | `calc_hit` |
| first_hit | `extras.opening` 时命中 +数量 | `calc_hit` |
| forest_avo | 守在林中时回避 +数量 | `calc_hit` |
| zoc_ignore | 可忽略控带的次数 | `zoc_charges` |
| fort_def | 守在垒上时防御 +数量 | `calc_damage_range` |
| push | 命中后击退格数，再加技能的 push | `push_tiles` |
| heal_pulse | 己方回合开始时治疗 | `heal_pulse` |

王技伤害走 `royal_damage`：读 `royal_skill_scale(nation)`。倍率 ≤ 0 时不改原伤害。正冕 1.0 保持原值，残响 0.6，满冕 1.35。

## 手算抽查

全属性 8、1 级、无特质、无武器。轻步对轻步、平地、无夹击：

- 命中基础 82，回避 12，命中 70。
- 攻击 9，防御 5，原始伤害 7，区间 6–8。

同对位夹击：命中 85，区间 7–9。

猎手打轻步、平地：远射克命中 +8，命中 78，区间 6–8。

学徒秘术打重步、垒、夹击、地形倍率 2、额外防御 1：秘破甲，命中 45，区间 4–6。

这四条都在 `formula_matrix.json` 里，测试直接比对 `calc_hit` / `calc_damage_range` / `preview`。
