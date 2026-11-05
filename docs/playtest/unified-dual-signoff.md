# 统一试玩双端签发 · 签收对照清单（fat #10）

> **本清单是真机签收底板，不替代用户签字。**  
> 模拟器 / CI / box 冒烟绿 ≠ 真机过关。体验过关只认下方「用户签字区」。  
> 规格：满分抬分肥刀 #10「统一试玩双端签发」。

## 0. 同 tip 双端包（签发底座）

| 项 | 值 |
|----|----|
| 签发 tip（full） | `35024036f211ce4b9afd8a0745a21998584517db` |
| tip 短 sha | `35024036` |
| GitHub Release tag | `main-35024036` |
| Release 标题 | 试玩包 · main 35024036 |
| Android 资产名 | `CenturyKnights-android-35024036.apk` |
| Windows 资产名 | `CenturyKnights-windows-35024036.zip` |
| 校验文件 | `SHA256-35024036.txt`（随 Release） |
| Android 内容 sha256 | `491bd62cc2b545f867511d56bf21e9008fcec221d8792e598d31c404b8ade99a` |
| Windows 内容 sha256 | `d9dedf319e87b47c4d7943c47906c607314760fb10487716994c63cd0fe8ac8f` |
| Release URL | https://github.com/wuyongjia666-droid/CenturyKnights/releases/tag/main-35024036 |
| 合入锚点 | fat #1–#9 → PRs #736–#744；本 tip = #744 合入后 main |

下载：https://github.com/wuyongjia666-droid/CenturyKnights/releases/tag/main-35024036

**装包纪律**：Windows 与 Android **必须同 tip**；禁止混用旧试玩包勾满分表。

---

## 1. Y1-A §3 真机必验（可勾）

来源：[`docs/design/y1a-acceptance-checklist-2026-10.md`](../design/y1a-acceptance-checklist-2026-10.md) §3。  
装 **同一 release / 同 commit** 的 Windows 与 Android 后再勾。

### 3.1 战棋选中手感「不难选中」

- [ ] 点**底座/脚圈** 10 次，成功选中 ≥ 8
- [ ] 点**脸/头** 10 次，成功选中 ≥ 7（对照底座）
- [ ] 点选 → 点移动格 → 确认（或拖到格松手）全流程不卡手
- [ ] 选中后慢点不会误出情报；故意长按仍可出情报

### 3.2 安全区 / 镜头

- [ ] 刘海/挖孔侧点格子：落点与手指一致，不偏一个内缩
- [ ] 捏合缩放后点选仍准；松手不误落子
- [ ] 拖棋与拖地图不抢手势

### 3.3 对话板 / 枢纽布局（机制 C）

- [ ] 对白 **SpeakerPlate 名签**不被裁扁、不截半字
- [ ] 枢纽 **「同袍」** 等 NavRail 旁标签不被裁切
- [ ] 横屏 / 竖屏各扫一眼，无「有板无字」错觉

### 3.4 枢纽字号地板

- [ ] **城市场**等页无竖向挤扁字（解锁文案、阶梯标题可读）
- [ ] market / estates / works / forge 扫一眼，无异常扁字

### 3.5 Forecast / 单位信息条

- [ ] 手机**横屏** Forecast 字号可读、不挤成一条线
- [ ] 侧栏单位信息行高够点、够读

### 3.6 剧情立绘

- [ ] ch0 等节点：supporting 说话人 Android 为**半身**，非剪影
- [ ] 与 Windows **同档观感**（允许 medium 比 large 略软 = 机制 B，**算过**）
- [ ] 已知曾缺图的 9 人有板（非假图/占位色块）

---

## 2. 满分表 1–9 冒烟勾（同 tip 包）

每条：真机/自玩「能走通关键路径」即可勾；自动化 suite 名仅作对照，**不能代替手指**。

| # | 肥刀 | 冒烟路径（最少） | 对照 suite（CI/本地已绿） | 勾 |
|---|------|------------------|---------------------------|----|
| 1 | 战棋命中手感+再战闭环 | 练习战命中有反馈 → 结算板 → 再战重进 → 回堡枢纽 | `combat_rematch_juice_fat` | [ ] |
| 2 | 战棋反馈音层整链 | 选中→确认→命中→结算四段可辨 SFX | `combat_sfx_layer_fat` | [ ] |
| 3 | 月循环耐玩一季硬化 | 一事→一战/属地→月结回响可读→进下月 | `month_loop_playable_harden_fat` | [ ] |
| 4 | 属地威胁→围城→解决 | 枢纽见威胁→战或抚→威胁降/清 + 两处 UI 一致 | `territory_threat_siege_resolve_fat` / mobile 同名 | [ ] |
| 5 | 大地图城·委托·补给 | ≥2 城可进；接委托→交→奖励可读 | `atlas_city_commission_supply_fat` / mobile | [ ] |
| 6 | 联姻血脉可读钩子 | 联姻/诞下在族谱或沙漏可读；承旗有板 | `marriage_bloodline_readable_hook_fat` / mobile | [ ] |
| 7 | 已有季可玩硬化 S01–S10 | 抽样 ≥3 季：进章→关键选择/战→出口 | `content_season_s01_s10_playable_harden_fat` | [ ] |
| 8 | 酒馆编制上阵情感闭环 | 招到→花名册见人→编成可选→上场 | `tavern_roster_deploy_feel_fat` / mobile | [ ] |
| 9 | 承旗/团灭/再开百年 | 团灭结局板回标题/再开；或承旗进编制+族谱；新局不脏读 | `banner_handoff_wipeout_century_fat` / mobile | [ ] |

---

## 3. m173 模拟器冒烟（底板，≠ 真机过关）

路径：**标题 → 创角 → 枢纽 → 一战 → 再战**。

- 步骤与期望：[`docs/playtest/m173-smoke-handoff.md`](./m173-smoke-handoff.md)
- 报告目录：[`docs/playtest/reports/`](./reports/)（本 tip 报告文件名含 `35024036`）
- 红线：box **无**硬件加速 → 禁止无加速长跑 emulator；m173 用 Hyper-V/WHPX。
- **禁止**把本节绿勾成「真机签收通过」。

---

## 4. 用户签字区（只认这里）

> 代理 / CI / m173 **不得**代填「签收：通过」。

| 项 | 填写 |
|----|------|
| 真机型号 / 系统 | |
| 装包 tip / tag | `35024036` / `main-35024036`（须一致） |
| Android sha256（对照 SHA256-*.txt） | |
| Windows sha256 | |
| §1 Y1-A §3 全部勾完 | |
| §2 满分 1–9 冒烟全部勾完 | |
| **签收：通过 / 打回** | （用户亲笔） |
| 日期（Asia/Shanghai） | |

打回时写：失败条目、截图/录屏路径、是否只要再出一版同 tip 包。
