# m173 模拟器冒烟步骤（fat #10 底板）

> 目标路径：标题 → 创角 → 枢纽 → 一战 → 再战。  
> **模拟器绿 ≠ 真机过关。** 报告入库后仍须用户真机勾 [`unified-dual-signoff.md`](./unified-dual-signoff.md)。

## 环境

| 项 | 要求 |
|----|------|
| 机器 | m173（Hyper-V / WHPX 加速） |
| 模拟器 | `emulator-5554` 或当前 AVD；**禁止**无加速长跑 |
| APK | Release `main-35024036` → `CenturyKnights-android-35024036.apk` |
| tip | `35024036f211ce4b9afd8a0745a21998584517db` |
| adb | `adb devices` 见 device；先 `adb uninstall` 旧包若签名冲突 |

## 步骤与期望

1. **安装**  
   `adb install -r CenturyKnights-android-35024036.apk`  
   期望：Success；`dumpsys package` version 与签发 tip 包一致。

2. **标题**  
   冷启动到主菜单。  
   期望：可见「新的百年 / 继续 / 设置」等中文 CTA；无 FATAL；截图 `01-title.png`。

3. **创角**  
   新的百年 → 命名（姓/名/旗色任意合法）→ 确认立团。  
   期望：进入立团/命名流且能完成；截图 `02-naming.png`。

4. **枢纽**  
   创角后抵达城堡枢纽（军务/同袍等）。  
   期望：NavRail/关键页可点、无裁字 P0；截图 `03-hub.png`。

5. **一战**  
   从军务/练习/清匪等入口进一局战棋，至少完成一次命中。  
   期望：棋盘可操作；命中有可读反馈；截图 `04-battle.png`。

6. **再战**  
   打到结算板 → 点「再战」→ 同图重进。  
   期望：不经标题菜单重进棋盘；输入未丢；截图 `05-rematch.png`。

## 报告入库

将结果写入：

- 仓库：`docs/playtest/reports/m173-smoke-35024036.md`
- 截图目录（本机或入库）：`docs/playtest/reports/m173-smoke-35024036/`（01–05）
- 可选：bot store / 父代理机器路径（在报告里写绝对路径）

报告模板字段：日期（Asia/Shanghai）、APK sha256、adb 设备、逐步 PASS/FAIL、截图路径、**明确声明「未代真机签收」**。

## box / CI 能做的（本刀已做）

- 同 tip Release 双端资产存在性 + SHA256 记录
- headless：`smoke_runner` + fat #10 suite（标题/创角代数 + 枢纽挂载 + 再战闭环对照）
- **不能**：在 box 上冒充 m173 Hyper-V 装 APK 长跑

## 父代理 / 有 m173 连接时

1. 下载上述 APK  
2. 按本节 1–6 执行并截图  
3. 填 `docs/playtest/reports/m173-smoke-35024036.md`  
4. 仍把 [`unified-dual-signoff.md`](./unified-dual-signoff.md) §4 留给用户签字
