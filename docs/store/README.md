# 商店工程准备（不花钱正式提审）

> 对齐路线 Year2「商店工程」：按需资源、性能档、商店页、崩溃闸。  
> **本目录可执行**：清单 + 脚本 + CI 门禁；不代替 Google Play / Microsoft Store 付费提审。

| 文件 | 用途 |
|---|---|
| [`export-paths.md`](./export-paths.md) | Android APK + Windows zip 出包路径（本地脚本 / Actions） |
| [`listing-copy-zh.md`](./listing-copy-zh.md) | 商店页文案草稿（中文；英译后补） |
| [`crash-perf-gates.md`](./crash-perf-gates.md) | 崩溃闸 / 性能档清单（对脚本与预算文件） |
| [`package-budget.md`](./package-budget.md) | 包体与按需资源报告口径 |
| [`CHECKLIST.md`](./CHECKLIST.md) | 上架前可勾选总清单（提审缴费项标「不做/未付费」） |
| [`play-listing-full.md`](./play-listing-full.md) | Google Play 控制台字段完整稿 |
| [`ms-store-listing-full.md`](./ms-store-listing-full.md) | Microsoft Store / Partner Center 完整稿 |
| [`privacy-policy-draft.md`](./privacy-policy-draft.md) | 隐私政策草稿（上架前静态页） |
| [`age-rating-draft.md`](./age-rating-draft.md) | IARC / 年龄分级问卷预填意图 |

## 一键门禁

```bash
# 文档齐全 + 导出预算脚本可跑 + 出包干跑门禁 + 性能预算文件存在
python3 tools/ci/store_prep_check.py
python3 tools/ci/store_packaging_dry_check.py

# 包体估算（相对 project/，按 export_presets 排除规则）
python3 tools/ci/export_size_report.py
```

CI：`store_prep_check` 由 `scripts/run_ci.sh` / lint 路径外的显式步骤可调用；PR 改 `docs/store/**` 或 `tools/ci/store_prep_check.py` 时应本地先跑绿。

## 验证记录

| 文件 | 用途 |
|---|---|
| [`privacy-verification-record.md`](./privacy-verification-record.md) | 隐私主张静态核对 |
| [`age-rating-verification-record.md`](./age-rating-verification-record.md) | 分级问卷意图核对 |
| [`export-paths-verification-record.md`](./export-paths-verification-record.md) | 出包路径干跑证据 |

```bash
python3 tools/ci/store_verify_records_check.py
```
