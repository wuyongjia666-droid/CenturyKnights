# 职业三阶（BTL-06）

数据在 `project/data/jobs.json`。三阶职业带 `promote_from` 和 `mechanic`。战斗公式只读这些字段，实现在 `project/autoload/battle_rules.gd`。

| 机制 | 效果 | 函数 |
| --- | --- | --- |
| canto | 攻击后还能再移动一次 | `can_canto` |
| riposte | 反击命中 +10 | `class_hit_bonus` |
| guard_adj | 相邻友军防御 +3 | `adjacent_class_def` |
| long_range | 不能近射，射程 +1 | `min_range` / `attack_reach` |
| overheal | 治疗溢出转为护盾 | `apply_class_heal` |
| pierce | 目标防御按一半计算 | `class_def_scale` |
| ambush | 夹击命中 +10 | `class_hit_bonus` |
| rally | 相邻友军防御 +1 | `adjacent_class_def` |
| hymn | 回合治疗脉冲 +2 | `heal_pulse` |

职业精通：`note_class_mastery` 在该职业下累计 3 场胜利后，把 `mastery_skill` 放进技能列表。技能表扩到 90 条，见 `project/data/skills.json`。

演武场与技能树用 `class_paths` / `class_path_text` 显示三阶路径。

克制沿用 `BattleRules.role_mods`：骑突对秘术和轻步、重装对轻步和骑突、近战对远射、远射对轻步和骑突、秘术对重装。这些配对不要求落在 25%–75%。其余 1v1 要落在这个区间里。
