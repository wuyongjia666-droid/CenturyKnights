# 包体与按需资源报告口径

> 商店友好安装包；**禁 H/I 砍画质**。本页是可执行口径。

## 现行自动门禁

```bash
python3 tools/ci/export_size_report.py
```

- 按 `project/export_presets.cfg` 的 Windows / Android `exclude_filter` 估算 `project/` 源字节  
- 预算：`tools/ci/ratchet.json`（`export_base_budget_bytes` + 基因库板数 × `export_bank_bytes_per_plate`）  
- 单板超过 `export_bank_plate_max_bytes` 直接失败  
- 硬参考 CAP：400 MiB；打印 `EXPORT CAP_STATUS <platform> UNDER|OVER <bytes>`  
- Android 血统库硬闸：`EXPORT ANDROID_BANK_CONTRACT medium_only=1`（master/small 不得进包）  
- 基因肖像：Windows 可含 large+medium+small；Android 仅 medium

退出码：`0` 未破预算且 Android medium_only；`1` 超预算或合同破；其它 = 脚本坏。  
`store_prep` / `store_packaging_dry` 要求见到 `EXPORT SIZE PASS`。

## 2026-10-27 干跑摘录（Asia/Shanghai）

| 平台 | EXPORT SIZE | CAP_STATUS | BANK |
|---|---:|---|---|
| Windows Desktop | 827693373 | OVER（预期，含 master） | master+medium+small |
| Android | 443497321 | OVER（~423 MiB 源估） | **medium_only=1** |

预算 `EXPORT BUDGET` ≈ 847556000 → 双平台均未破预算 → `EXPORT SIZE PASS`。

## 按需资源（Year2 落地，今日文档化）

| 策略 | 状态 | 说明 |
|---|---|---|
| 导出排除大档立绘 | 已做 | Android exclude large/small genome plates |
| medium_only 硬闸 | 已做 | `export_size_report` + packaging dry |
| Play Asset Delivery / 安装后下载 | **未接线** | 正式提审前选型；今日不花钱开通 |
| CAP ≤400 MiB | **未闭合** | 见 `docs/art/export-cap-400.md`；H/I 需用户拍板 |
| 禁 H/I 压画质 | 已锁定 | 路线红线 |

## 平台对照

| 平台 | 今日产物 | 商店正式包 | 包体复核 |
|---|---|---|---|
| Android | CI debug APK / `build_android.sh` | AAB 人工（不缴费提审） | `export_size_report.py` |
| Windows | `build_windows.sh` + Release zip | MSIX 另刀 | 同上 |

破预算时：先削按需/exclude，再议 ratchet；**禁止**用降画质预设充绿。
