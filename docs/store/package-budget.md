# 包体与按需资源报告口径

> 商店友好安装包；**禁 H/I 砍画质**。本页是可执行口径。

## 现行自动门禁

```bash
python3 tools/ci/export_size_report.py
```

- 按 `project/export_presets.cfg` 的 Windows / Android `exclude_filter` 估算 `project/` 源字节  
- 预算：`tools/ci/ratchet.json`（`export_base_budget_bytes` + 基因库板数 × `export_bank_bytes_per_plate`）  
- 单板超过 `export_bank_plate_max_bytes` 直接失败  
- 硬参考 CAP：400 MiB（advisory）；Android 为打包主目标  
- 基因肖像：Windows 可含 large+medium+small；Android 仅 medium

退出码：`0` 未破预算；`1` 超预算但脚本可用（`store_prep` 仍接受 0/1）；其它 = 脚本坏。

## 按需资源（Year2 落地，今日文档化）

| 策略 | 状态 | 说明 |
|---|---|---|
| 导出排除大档立绘 | 已做 | Android exclude large/small genome plates |
| Play Asset Delivery / 安装后下载 | **未接线** | 正式提审前选型；今日不花钱开通 |
| 禁 H/I 压画质 | 已锁定 | 路线红线 |

## 平台对照

| 平台 | 今日产物 | 商店正式包 | 包体复核 |
|---|---|---|---|
| Android | CI debug APK / `build_android.sh` | AAB 人工（不缴费提审） | `export_size_report.py` |
| Windows | `build_windows.sh` + Release zip | MSIX 另刀 | 同上 |

破预算时：先削按需/exclude，再议 ratchet；**禁止**用降画质预设充绿。
