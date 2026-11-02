# 包体与按需资源报告口径

> 商店友好安装包；**禁 H/I 砍画质**。本页是可执行口径。

## 现行自动门禁

```bash
python3 tools/ci/export_size_report.py
python3 tools/ci/store_ondemand_check.py
```

- 按 `project/export_presets.cfg` 的 Windows / Android `exclude_filter` 估算 `project/` 源字节  
- 预算：`tools/ci/ratchet.json`（`export_base_budget_bytes` + 基因库板数 × `export_bank_bytes_per_plate`）  
- 单板超过 `export_bank_plate_max_bytes` 直接失败  
- 硬参考 CAP：400 MiB；打印 `EXPORT CAP_STATUS <platform> UNDER|OVER <bytes>`  
- Android 血统库硬闸：`EXPORT ANDROID_BANK_CONTRACT medium_only=1`（master/small 不得进包）  
- 基因肖像：Windows 可含 large+medium+small；Android 仅 medium  
- 按需清单：`docs/store/ondemand-assets.json`（与 exclude / `CKArtPaths` / `CKOnDemandArt` 合同对齐）  
- `store_ondemand_check`：清单存在、deferred 全进 Android exclude、关键路径不静默丢图、源估 **CAP UNDER**

退出码：`export_size_report` → `0` 未破预算且 Android medium_only；`1` 超预算或合同破。  
`store_ondemand_check` → `0` 见 `STORE ONDEMAND PASS`；`1` 清单/排除/关键路径/CAP 不同步。  
`store_prep` / `store_packaging_dry` 要求见到 `EXPORT SIZE PASS`；lint 另跑 ondemand 门禁。

## 2026-11-03 干跑摘录（Asia/Shanghai）

| 平台 | EXPORT SIZE | CAP_STATUS | BANK |
|---|---:|---|---|
| Windows Desktop | 795240665 | OVER（预期，含 master） | master+medium+small |
| Android | 411044613 | **UNDER**（约 392.00 MiB，余 ~8.00 MiB） | **medium_only=1** |

预算 `EXPORT BUDGET` ≈ 847556000 → 双平台均未破预算 → `EXPORT SIZE PASS`。  
Android **源估 CAP≤400 已闭合（UNDER）**：#734 归档未用 `v92_estate_*` / `v92_scene_*`（ART-02）后达成。  
**APK 实包另测**（导入开销 + 原生库；本盒缺 JDK 时走 CI Release）。**H/I 仍用户-only**，禁止用降画质/砍血统库充绿。

## 按需资源脚手架（本刀落地，可跑）

| 策略 | 状态 | 说明 |
|---|---|---|
| 导出排除大档立绘 | 已做 | Android exclude large/small genome plates + speaker/expression larges |
| medium_only 硬闸 | 已做 | `export_size_report` + packaging dry + ondemand check |
| 按需清单 + CI | **已做** | `ondemand-assets.json` + `store_ondemand_check.py` + suite `ondemand_cap_closeout_check` |
| 运行时缺大图回落 medium | **已做** | `CKArtPaths` tier 回落 + `CKOnDemandArt.resolve_pack_safe` / `load_pack_safe` |
| Play Asset Delivery / 安装后下载 | **未接线** | Year2；正式提审前选型；今日不花钱开通 |
| 源估 CAP ≤400 MiB | **已闭合 UNDER** | 见上表；APK 实包另测 |
| 禁 H/I 压画质 | 已锁定 | 路线红线 |

## 平台对照

| 平台 | 今日产物 | 商店正式包 | 包体复核 |
|---|---|---|---|
| Android | CI debug APK / `build_android.sh` | AAB 人工（不缴费提审） | `export_size_report.py` + `store_ondemand_check.py` |
| Windows | `build_windows.sh` + Release zip | MSIX 另刀 | 同上 |

破预算时：先削按需/exclude，再议 ratchet；**禁止**用降画质预设充绿。

## 截图证据轨（与 CAP 正交）

商店五张横屏证据包见 `screenshots-checklist.md` / `shots-manifest.json`；**不**借截图轨关闭 Android CAP≤400。CAP H/I（砍基因库 / 降画质重导出）仍 **用户-only blocker**，本页口径不变：禁 H/I 压画质充绿。
