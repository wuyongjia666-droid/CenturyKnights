# v7.21.0-depth · 系统深度第二十二轮（仍停加卷）

## 农场出图 / UI / 动画（置顶）

| 项 | 结果 |
|----|------|
| 中继 | m173 `ea57a68e-3181-4765-a112-852a6cab095d` connected |
| Qwen :8322 / SN :8329 | **不可达**（经 m173 探测） |
| 证据 | ping 192.168.9.244 **100% 丢失**；m173 本机 IP **192.168.31.34**；**无** 192.168.9.0 路由；TCP 8322/8329 全 timeout |
| 根因 | **网段隔离**（31.x ↔ 9.x），非脚本问题 |
| 队列 | `shots_v721.json` 18 shots 已扩；已 Copy 到 m173 `C:\Users\m1736\CenturyKnights_farm\` + `submit_on_m173.ps1` |
| 落地板 | **无**（无法提交） |
| 动效 | ZoC **AudioStreamPlayer2D** 立体声 pan + 距离；设置「减动效」；工事/敌宅/设置错落入场 |

详见 `docs/farm/probe-v7.21.0-depth.md`。

## 战棋 / 系统
- ZoC hover：听者在选中单位，声源在悬停格 → pan + 音量衰减
- UI：前端式层级 + Active Theory 微交互延续

## 不做
- 无新剧情卷

## 下载
- `CenturyKnights-windows-v7.21.0-depth.zip`
- SHA256：`a948f93e90d7e445ff2c5cb3be13ea905a8d3c50179a955c52cd31e116dfe559`

## CI
- `./scripts/run_ci.sh` → **ALL PASS**
