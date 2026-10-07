# v7.20.0-depth · 系统深度第二十一轮（仍停加卷）

## 美术（置顶 · 一等公民）

### 农场出图 / UI / 动画
| 项 | 说明 |
|----|------|
| **探测** | `tools/farm_queue/probe_farm.sh` → Qwen `192.168.9.244:8322` 优先；SN local `:8329` 双投 |
| **本轮结果** | **timeout**（执行箱不在 m173 LAN）· 详见 `docs/farm/probe-v7.20.0-depth.md` |
| **队列** | `tools/farm_queue/shots_v720.json` + `submit_ck_v720_queue.py`（dual；禁 SN cloud / *Api / Flux）— 农场一通立即批量补板 |
| **skills** | `create-game-assets` / `game-ui-ux` / `godot-animation` / `game-feel` / `audio-design` |
| **Active Theory 动效** | `UIFX`：错落入场、按压微交互、悬停抬起、闲置呼吸、分层确认爆发；时长对齐前端（按压~120ms / 面板~280ms） |
| **UI 板（interim）** | 商队/市集横幅、属地三偏向图标、义役芯片、商队航线图标、ZoC pulse 6 帧 — 待农场板替换 `farm_inbox` |
| **脸** | 开放寻址指派（同 id 稳定、超长王朝不共槽）；corrupt `682` 已修 |

## 战棋
- ZoC 音效按距选中单位的曼哈顿距离衰减音量（锁脱更响）
- 悬停锁代价格拉 ZoC pulse FX 帧

## 城堡 / 谱系 / 贸易（真决策，非只芯片）
- **属地改作**：粮作 / 钱作 / 戍卫（10 银、冷却 2 月；改月结结构与劫掠）
- **陆桥商队**：粮/铁/香料航线投资，三月交割，途中劫险（义役/商路旁注减险）
- **联姻义役**：六月每月 5 银 → 声望/士气/护路；欠缴惩罚
- 家训「商本」`commerce`/`trade` 双键对齐

## 不做
- 无新剧情卷

## 下载
- `CenturyKnights-windows-v7.20.0-depth.zip`
- SHA256：`dbda7b50f3b01cd6c04ff26f196146ee29066e6ba87c67595b4f7929ee2ecc74`

## CI
- `./scripts/run_ci.sh` → **ALL PASS**
