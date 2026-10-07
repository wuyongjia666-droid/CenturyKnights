# Release v0.1.3-tutorial-fix

- URL: https://github.com/wuyongjia666-droid/CenturyKnights/releases/tag/v0.1.3-tutorial-fix
- Asset: https://github.com/wuyongjia666-droid/CenturyKnights/releases/download/v0.1.3-tutorial-fix/CenturyKnights-windows-tutorial-fix.zip
- ZIP SHA256: `b28fee1991860ecee6d662a470cdf6cdeec573ba97f4bf7a707d610422b775b3`
- EXE SHA256: `de202e88f61be20930f4ee64b293f8cab3aa44927fb7d10d112fd42b3e921aa4`

## Fix
- 第零章教学战「两人打一群」：开局花名册仅团长+苇原·灯影（2），却部署 4 敌（含匪首 str10/vit9）
- `ch0_pass` 现补 2 名临时「灰旗民兵」至我军 4 人；敌军改为 2 名弱流匪（`bandit_weak`，无弓无匪首）
- e2e 断言部署约 4 vs ≤3，并验证战后返回章节可用「前往烽火酒馆」推进（非软锁）

## Balance numbers
| Side | Before | After |
|------|--------|-------|
| Player | 2 (leader+ally) | 4 (leader+ally+2 militia guests) |
| Enemy | 4 (2 bandit + archer + chief) | 2 (bandit_weak ×2) |
| Weak foe stats | — | str5 vit5 skl4 agi5 (was bandit 7/6/5/6; chief 10/9) |

## Verify
```
./scripts/run_ci.sh
# expect: smoke + layout + tactics_e2e + full_chain_e2e PASS
# full_chain prints: OK battle deploy balance 4 vs 2
```

## Player verify
1. 新的旗号 → 起名 → 推进到「隘口之夜」→「开始战斗教学」
2. 棋盘应见约 4 个蓝方圆点、2 个红方；击败后点「返回章节」→「前往烽火酒馆」
