# Release v0.1.1-home-fix

- URL: https://github.com/wuyongjia666-droid/CenturyKnights/releases/tag/v0.1.1-home-fix
- Asset: https://github.com/wuyongjia666-droid/CenturyKnights/releases/download/v0.1.1-home-fix/CenturyKnights-windows-home-fix.zip
- ZIP SHA256: `bbfbf4353e8b00f5394817984cf7cd5d6a3817faea64bd54e836704edad15cf2`
- EXE SHA256: `3bd0ddf2a1d87c7ff5cba51120d08e13505c12e32eecc5c965ddb1776de56304`

## Fix
- 主菜单误用 `PRESET_CENTER` + 硬编码 `position(440,160)`，Windows 窗口比例变化时跑偏
- 改为全屏 `CenterContainer` 居中；设置/起名页同步
- `window/stretch/aspect`：`expand` → `keep`（16:9 黑边，布局稳定）

## Verify
```
godot --headless --path project --script res://tests/layout_check.gd
# expect: PASS main menu centered, drift=(0, 0)
```
