# 包体与按需资源报告口径

## 现行自动门禁

```bash
python3 tools/ci/export_size_report.py
```

- 按 `project/export_presets.cfg` 的 Windows / Android `exclude_filter` 估算 `project/` 源字节  
- 预算：`tools/ci/ratchet.json`  
  - `export_base_budget_bytes` + 基因库板数 × `export_bank_bytes_per_plate`  
  - 单板超过 `export_bank_plate_max_bytes` 直接失败  
- 硬参考 CAP：400 MiB（报告内 advisory）；Android 为打包主目标  
- 基因肖像：Windows 可含 large+medium+small；Android 仅 medium（large/small exclude）

## 按需资源（Year2 落地，今日文档化）

| 策略 | 状态 | 说明 |
|---|---|---|
| 导出排除大档立绘 | 已做 | Android exclude large/small genome plates |
| Play Asset Delivery / 安装后下载 | **未接线** | 正式提审前选型；今日不花钱开通 |
| 禁 H/I 压画质 | 已锁定 | 路线红线 |

新增大资源默认：先能 exclude / 按需，再进 APK。

## 报告归档

每次准备统一试玩包时，把 `export_size_report.py` 标准输出贴进 Release notes 或 `exports/SHA256-*.txt` 旁备忘；本仓库不强制提交生成物。
