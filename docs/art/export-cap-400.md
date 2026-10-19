# 导出体积硬顶 400 MiB（Android）

> 实测基线：`main-a61ff4e8`（2026-10-18）  
> APK **541.1 MiB**（567,392,532 B）· Windows zip **748.6 MiB**  
> #321（456 张补图）预计再给 Android **+~39–45 MiB**，合完后约 **580–586 MiB**。

硬顶 `CAP = 400 MiB` 写在 `tools/ci/export_size_report.py`。#316 已让 Android 只打立绘库 **medium+small**（去掉 large 母版，APK −228 MB）。本文件记录拆包结果、杠杆排序，以及第一刀（medium-only）的收益。

## 1. APK 实测拆解（main-a61ff4e8）

解压后 `.godot/imported` ≈ 529 MiB（纹理已转 ETC2/ASTC `.ctex`），`libgodot_android.so` ≈ 63 MiB。

| 类别 | APK 内约 | 说明 |
|---|---:|---|
| 血统库 medium | 101.2 MiB | 1595 张 × ~65 KiB |
| 血统库 small | 57.7 MiB | 1595 张 × ~37 KiB |
| models（含 albedo `.ctex`） | 58.0 MiB | 棋子/单位贴图偏大 |
| art/atlas | 55.7 MiB | 源 31.5 → 导入膨胀 |
| `.scn` 网格 | 31.3 MiB | 棋子/场景 |
| portraits/expressions | 26.0 MiB | 含 large+medium+small |
| art/scenes + story | 25.1 MiB | |
| portraits/other（hireuniq 等） | 20.1 MiB | 仍被招募链引用，不能 silently 删 |
| art/estates | 20.5 MiB | |
| audio (ogg+wav) | ~22 MiB | |
| art/tokens | 15.6 MiB | |
| art/ui / doll / castle / battle / fx | ~47 MiB | 合计 |
| fonts | 5.9 MiB | |
| 原生库 | ~70 MiB | Godot + libc++ |

源文件估算（Android 过滤后，本仓 `a61ff4e8`）：**475.5 MiB**；打进 APK 后约 **541 MiB**（导入开销 + 原生库）。

## 2. 杠杆排序（相对合入 #321 后的 ~586 MiB）

| 杠杆 | 约节省 | 画质风险 | 要不要农场 | 能否单做 |
|---|---:|---|---|---|
| **A. Android 血统库只留 medium（去掉 small）** | **~74 MiB** | 低：列表用中档回落，略耗显存 | 否 | ✅ 本 PR |
| B. Android 血统库只留 small（去掉 medium） | ~130 MiB | **中高**：对话半身发糊 | 否 | 可选 |
| C. 排除 hireuniq / 旧 bust（需改招募回落） | ~20 MiB | 中：无 bank 命中时变卡通/空 | 否 | 需改代码 |
| D. atlas 源图半分辨率再导入 | ~28 MiB | 中：场景板糊 | 否 | 可选 |
| E. 表情/speaker 去掉 large 母版（Android） | ~15 MiB | 低（有 medium） | 否 | 下一切 |
| F. 棋子 albedo 压到 ≤512 / 更低 JPG | ~25 MiB | 中：与精致棋子标准冲突 | 否 | 与 P2 协调 |
| G. 音频再压 | ~5 MiB | 低 | 否 | 小 |
| H. 砍掉大半血统库 / 只留 250 热门 | **100+ MiB** | **高** / 或要重算覆盖 | 可能要补图 | **需用户拍板** |
| I. 重出更小分辨率立绘 | 视规格 | 视规格 | **要** | 停，先问 |

**单靠 A–G 叠满**大约能到 **~370–410 MiB**，贴着硬顶且要动 atlas/棋子/招募链。  
**稳妥到 ≤400 且不大伤可读性**，几乎一定要动血统库规模（H）或重出更小图（I）——这两条不静默做。

## 3. 本 PR 做了什么（第一刀）

1. `export_presets.cfg` Android：在 #316 去掉 large 的基础上，再排除 `assets/art/portraits/genome/bank/*.small.webp`。  
2. `CKArtPaths` 档位回落不变：要 small/large 时会落到 medium。  
3. `android_tier_pack_check`：断言只打 medium；medium-only 临时库仍能列 stem、服务 large/small。  
4. `export_size_report.py`：Windows / Android **分开**统计，并打印 bank 三档字节。  
5. 修正 `test_shipping_quality` 里与 #316 冲突的旧断言。

### 预期体积

| | 源估算 (Android) | APK（估） |
|---|---:|---:|
| main-a61ff4e8（medium+small） | 475.5 MiB | **541.1 MiB**（实测 release） |
| 本 PR（medium-only） | **417.2 MiB** | **482.1 MiB**（本地 `build_android.sh`，−59.0 MiB） |
| + #321 后（medium-only，估） | — | **~511 MiB**（456×~65 KiB medium ≈ +29 MiB；旧 +39 含 small） |

本 PR 后 APK 内 genome bank 条目 = **1595**（仅 medium；#316 时为 3190）。  
距 400 还差约 **82–120 MiB**，见 §2 选项 B–I，等用户选。

## 4. 不做什么

- 不派农场、不重出立绘。  
- 不删 hireuniq / 大半 bank。  
- 不合入；等过目。  
- 不跟 #321 抢图：本分支基于 `main`，#321 合入后本过滤规则可干净 rebase。
