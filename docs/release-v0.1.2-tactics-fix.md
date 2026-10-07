# Release v0.1.2-tactics-fix

- URL: https://github.com/wuyongjia666-droid/CenturyKnights/releases/tag/v0.1.2-tactics-fix
- Asset: https://github.com/wuyongjia666-droid/CenturyKnights/releases/download/v0.1.2-tactics-fix/CenturyKnights-windows-tactics-fix.zip
- ZIP SHA256: `ba481dc8e25678d0d2aca72878f2c4605ebce79e0d0cf427a4a855ae462322a6`
- EXE SHA256: `99e2fa855d9bf409c6e998d57afcb642826a56e1ac90982c089559133a8c79f9`

## Fix
- 战棋全屏 `ColorRect` 默认拦截鼠标，`_gui_input` 收不到左键，点选/移动/攻击全部失效
- 背景与信息面板改为 `MOUSE_FILTER_IGNORE`；理顺选中 → 移动 → 攻击模式 FSM
- 射程内可直接点敌军攻击；「攻击模式」锁定只攻不移且超距不夺选中；右键取消

## Verify
```
./scripts/run_ci.sh
# expect: smoke + layout + tactics_e2e PASS
godot --headless --path project --scene res://tests/tactics_e2e.tscn
# expect: === TACTICS E2E PASS ===
```
