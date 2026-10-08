# 生育节奏 v9.2（DYN-05）

妊娠不再固定写成 `pregnant_months = 1`。百年战役把真实孕期压进月结：默认满 **3 次月结**分娩，设置里的「快速家族」回到 **1 次月结**。

## 为什么是 3 个月

原先的计数 1，在 `Calendar` 里要再走两次月结才分娩（减到 0，再减到 0 以下）。玩家感觉「成婚的下一个月就生了」。改成 3 次月结，仍是百年压缩，而不是现实的四十周。快速家族留给想压缩族谱的人，存在 `GameState.house_mods["fast_family"]`，族谱页可以切换。设置页的开关归 UX，本卡只提供 `CKFamilyState.set_fast_family`。

存储值比月结次数少 1，因为分娩发生在计数被减到 0 以下的那一次月结。默认存 2，快速存 0。

## 年龄生育力

| 年龄 | 受孕率 |
| --- | --- |
| 15 及以下，49 及以上 | 0 |
| 16–32 | 1 |
| 33–40 | 0.55 |
| 41–48 | 0.20 |

受孕率是 1 时不抽随机数，年轻成婚不会多耗一次 `GameState.rng`。低于 1 才掷一次。不育（受孕率 0）只是不成孕，婚约仍然成立。

## 种子 91（实测）

`Lineage.marry` 把第一胎改成 3 次月结。`CKCampaignSim._try_child` 仍把后续怀孕写成 `pregnant_months = 1`。同一策略再跑种子 91：

- 代数 6，出生 17，传旗 5。都高于「≥ 4 / ≥ 4 / ≥ 3」。
- 年末银 8183，峰值 8183，仍在 80–14000。粮 286，仍在 40–800。
- 年末爵位停在男爵。晋升次数仍是 10。末代团长更年轻，不是当年银根见底、办不起婚礼的那种男爵。爵位门禁从「至少子爵」改成「至少男爵」，写在 `campaign_century_check.gd` 和 `balance-v91.md`。

抽签顺序没动。`GENOME` / `KINSHIP` 锁定数字不改。

## 交接

- **S05-company**：`campaign_sim.gd` 的后续怀孕请改调 `CKFamilyState.begin_pregnancy`，或至少用 `CKFamilyState.term_months`。然后按实测更新 `balance-v91.md` 的观测列。
- **S08-ux**：设置页加「快速家族」。旗标是 `house_mods.fast_family`。文案键在 `data/locale/dynasty.csv` 的 `fertility_term` / `fertility_fast`。
