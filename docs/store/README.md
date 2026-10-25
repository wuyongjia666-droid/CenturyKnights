# 商店工程准备（不花钱正式提审）

> 对齐路线 Year2「商店工程」：按需资源、性能档、商店页、崩溃闸。  
> **本目录可执行**：清单 + 脚本 + CI 门禁；不代替 Google Play / Microsoft Store 付费提审。  
> **字数闸**：内容季中篇 ≥12000 汉字 / 对标季1；禁止靠删 `too thin` 断言偷工（见已关 #406）。

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
python3 tools/ci/store_prep_check.py
python3 tools/ci/store_packaging_dry_check.py
python3 tools/ci/export_size_report.py
```

## 分工边界

| 线 | 做 | 不做 |
|---|---|---|
| 商店深刀（本目录） | 完整稿、出包干跑、抬高字数闸 | 不缴费提审；不写季#3 正文（内容专线） |
| 内容季专线 | 中篇正文 / 可玩章 / playable suite | 不削弱字数闸换绿 |

季#3 正文未满 12000 时 `store_prep` 会红——这是预期，等内容专线 #409，**禁止**降门槛。
