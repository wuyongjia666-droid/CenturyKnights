# 农场探测 · v7.20.0-depth（Asia/Shanghai）

## 步骤
1. `tools/farm_queue/probe_farm.sh`
2. 目标：`http://192.168.9.244:8322`（Qwen 优先）、`http://192.168.9.244:8329`（SenseNova local 双投）
3. 可达则 `python3 tools/farm_queue/submit_ck_v720_queue.py`（dual；禁 SN cloud / *Api / Flux）
4. 出图落 `project/assets/art/farm_inbox/` → 归一化进 UI/肖像/FX

## 本轮结果
| 目标 | 结果 | 原因 |
|------|------|------|
| 127.0.0.1:8322 / 8329 | 连接拒绝 | 本机无 Comfy 中继 |
| m173 / 192.168.1.173 等 | 不可达 | 非精确主机名 |
| **192.168.9.244:8322** | **timeout** | 执行箱不在 m173 LAN（无路由/VPN） |
| **192.168.9.244:8329** | **timeout** | 同上 |

## 队列
- `tools/farm_queue/shots_v720.json` — UI 横幅/属地三图标/联姻义役/ZoC FX 帧/手绘肖像概念板/月结面板
- `tools/farm_queue/submit_ck_v720_queue.py` — 农场一通立即双投

## 本轮替代（非最终）
- skills：`create-game-assets` / `game-ui-ux` / `godot-animation` / `game-feel` / `audio-design`
- 手调/UI 动效/程序音量电报已进包；农场板到位后替换 `farm_inbox` 占位
