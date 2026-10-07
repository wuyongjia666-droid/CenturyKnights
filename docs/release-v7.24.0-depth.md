# v7.24.0-depth · 系统深度第二十五轮（仍停加卷 · FX 切片 + v724 农场）

## 美术 / UI / 动画（置顶 · skills + Active Theory）

| 交付 | 说明 |
|------|------|
| **FX 切片** | `hit_spark`/`dmg_pop`/`lock`/`zoc_pulse` + **slash/crit/heal/unlock/shield/spark** → `*_0..5`；`tools/farm_queue/slice_fx_sheets.py` |
| **战棋** | 切片帧已接 hit_spark/dmg_pop/zoc；**交战锁定爆发** `_lock_burst_fx`；crit/slash/heal/shield/spark/lock kind 用新帧 |
| **农场 v724** | Qwen×23（sheets+英雄肖像+ZoC/月结芯片+按钮 chrome）；SN 仍在抽 v722（大图暂不替换 Qwen） |
| **AT** | `page_exit`；大厅旗标 breathe；hourglass wire；商队 escort `chip_pulse` |

## 不做
- 无新剧情卷

## 下载
- `CenturyKnights-windows-v7.24.0-depth.zip`
- SHA256：`b0b1e59c2ccc85b0dd176bbd2da5eb7936ba18ace258fd449faf43eac8329909`

## CI
- `./scripts/run_ci.sh` → **ALL PASS**
