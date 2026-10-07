# Release v0.1.2-tactics-fix

- URL: https://github.com/wuyongjia666-droid/CenturyKnights/releases/tag/v0.1.2-tactics-fix
- Asset: https://github.com/wuyongjia666-droid/CenturyKnights/releases/download/v0.1.2-tactics-fix/CenturyKnights-windows-tactics-fix.zip
- ZIP SHA256: `(pending export)`
- EXE SHA256: `(pending export)`

## Fix
- 战棋全屏 `ColorRect` 默认拦截鼠标，`_gui_input` 收不到左键，点选/移动/攻击全部失效
- 背景与信息面板改为 `MOUSE_FILTER_IGNORE`；理顺选中 → 移动 → 攻击模式 FSM
- 攻击需先点「攻击模式」再点射程内敌军；右键取消选中

## Verify
```
./scripts/run_ci.sh
# expect: smoke + layout + tactics_e2e PASS
godot --headless --path project --scene res://tests/tactics_e2e.tscn
# expect: === TACTICS E2E PASS ===
```
