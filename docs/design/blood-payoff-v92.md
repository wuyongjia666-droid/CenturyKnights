# 血统战斗回报 v9.2（DYN-01）

战术禀性和王技分阶只读取已经抽好的基因。`CKGenome.cross`、`CKBloodline.cross_sig`、`LOCUS_ORDER` 和开国者抽签顺序都不改。

## 战术禀性

`project/data/bloodlines_v89.json` 的 `tactics` 登记 20 个已有禀性位点（十国各 2 个）。显隐沿用 `CKBloodline.express_trait`：`tier` 为 `royal` 或 `noble` 才生效，`latent` 不生效。`display_tier` 把王级改写成贵级之后，仍然算显出。

`CKBloodPayoff.tactical_mods()` 把显出的 `key` / `amount` 加总。`CKCharacter.tactical_amount()` 只暴露这个数。`derived_atk` 等现有派生不读它，避免种子 91 的战斗数值漂移。伤害、射程、控带怎么使用这些键，归 `battle_rules.gd`。

子嗣概率用 `CKBloodline._child_pairs`，女男各占一半。数值位点走和 `trait_odds` 相同的正态累积，不另抽一次。

期望伤害模拟里，个体战力是 `10 + range_high × 6`（显出才有 `range_high`）。定向每代留下战力最高的 4 人，拷贝数只在战力相同时用来分先后。随机配婚留下同一胎次里先出生的 4 人。比的是三代之后队内随机配对的子嗣期望战力。

## 王技分阶

只在 `CKBloodline.royal_nations` 已经显冕时分阶。纯度是 `blood_mix` 里该国王胤 id 的权重。

| 条件 | 阶 | 倍率 |
| --- | --- | --- |
| 拷贝 ≥ 2 且纯度 ≥ 0.75 | 3 满冕 | 1.35 |
| 拷贝 ≥ 2，或纯度 ≥ 0.5 | 2 正冕 | 1.0 |
| 其余显冕 | 1 残响 | 0.6 |
| 未显冕 | 0 | 0 |

二倍体拷贝数是王级等位的个数。互补律按配对等位里已经出现的个数计。X / Y 单倍体：已显且纯度 ≥ 0.75 视作满份（2），否则 1。数值位点：不低于 `royal_min + 0.1` 算 2 份，否则 1。倍率读 `royal_skill_tiers`。`skills.json` 不改。

## 没有做的部分

需要 `family_state` 的子嗣档案、以及把倍率写进战斗结算，等 CORE-02 与战斗流。本卡不创建 `family_state.gd`，也不改 `game_state.gd`。
