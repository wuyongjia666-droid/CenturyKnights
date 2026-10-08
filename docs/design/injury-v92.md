# 伤病与永久死亡 v9.2

玩家在开局选择伤亡模式。数据在 `project/data/injuries.json`，结算在 `CKInjury`。

## 模式

- `classic`：被击倒后按难度和溢出伤害掷骰，掷中则阵亡。
- `casual`：被击倒只撤退，留下伤，不会死。这是缺省，也是种子 91 百年脚本团用的标准模式。脚本团不写 `settings.casualty_mode`，也不订阅战斗场景，所以银、粮、代数不变。

开局界面归 UX。写入方式：`CKInjury.set_mode("classic")` 或 `"casual"`，落在 `GameState.settings.casualty_mode`。

## 掷骰

死亡概率 = 难度底数（0.05 / 0.10 / 0.18 / 0.28 / 0.40）+ 溢出伤害 × 0.04，溢出加成不超过 0.45，总概率不超过 0.85。骰子是单独的 `RandomNumberGenerator`，种子来自击倒上下文，不推进 `GameState.rng`。

没死的时候再掷一档：

- 轻伤：1–2 个月，可以出战。秋收和祠堂祈愈会清掉。
- 重伤：3–6 个月，`deploy_block_reason` 返回「重伤休养，还要 N 个月」。战斗部署界面由 battle 流读取这个字符串。
- 永久伤：断指（技艺 -2，直接写进 `stats.skl`）或跛足（移动 -1，走 `combat_mods` / `move_mod`，战斗公式仍归 battle 流）。

## 阵亡

阵亡者 `alive = false`、`in_roster = false`，仍留在 `GameState.characters` 里，族谱把亡故画成先祖。遗言写进 `blood_meta.stele`（`cause` / `words` / `when` / `killer` / `name`）和 `lineage_log`。界面归 dynasty 流。团长阵亡时走现有的 `Lineage.transfer_banner("death")`。

## 治疗

月结只给有记录的轻伤和重伤减一个月，不消耗经营随机流。祠堂祈愈清轻伤、按祠堂等级缩短重伤，并回满生命。永久伤用 1 药材（`mitigate(c, "clinic")`）或已装备的兵器（`mitigate(c, "heirloom")`）缓解。医所建筑在 CMP-03，在那之前祠堂代行药材缓解。
