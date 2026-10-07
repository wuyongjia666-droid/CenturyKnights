# 农场探测 · v7.21.0-depth（经 m173 中继）

## 路径（用户锁定）
- Box **不能**直连 `192.168.9.244` → 必须经 machine **m173** `ea57a68e-3181-4765-a112-852a6cab095d`
- Qwen `http://192.168.9.244:8322` · SenseNova local `http://192.168.9.244:8329`
- 脚本：`D:\cursor-userdata\dot-cursor\skills\aic-farm\scripts\`（及 `C:\Users\m1736\.cursor\skills\aic-farm\scripts`）

## 探测步骤与证据
1. ListMachines → m173 `connected: true`
2. 在 m173 上 `Invoke-WebRequest http://192.168.9.244:8322/system_stats` → **超时**
3. 在 m173 上 `ping 192.168.9.244` → **2/2 丢失（100%）**
4. `ipconfig` → m173 本机 **`192.168.31.34`**（`192.168.31.0/24`）
5. `route print` → **无** `192.168.9.0` 路由（仅默认网关 `192.168.31.1`）
6. TCP 探测 `127.0.0.1` / `192.168.31.244` / `192.168.31.173` / `192.168.9.244` 之 `8322/8329` → **全部 closed/timeout**
7. m173 本机无 Comfy 监听端口

## 根因
**网段隔离**：农场 Comfy 在 `192.168.9.244`，中继机 m173 在 `192.168.31.34`，当前无跨网段路由/VPN/桥接，故中继亦不可达。非脚本或双投配置问题。

## 队列（已备，农场一通立即全投）
- `tools/farm_queue/shots_v721.json`（18 shots：UI 横幅/图标/FX 条/月结面板/肖像概念/战斗背景）
- m173 启动器：`tools/farm_queue/submit_on_m173.ps1`（dual_submit，禁 SN api）
- 收回目录：`project/assets/art/farm_inbox/`

## 本轮落地
- **无农场板落地**（无法提交）
- interim UI/FX 保留并加强动效；板到位后按 id 替换同名资源
