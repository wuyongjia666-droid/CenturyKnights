# 导出路径验证记录（不缴费 · 干跑）

> 对 `export-paths.md` 的**可执行核对**。本记录**不出正式商店包、不上传、不花费**。  
> 记录时点：2026-10-25 10:35 Asia/Shanghai · git `9a7c5990`  
> 关键词：`build_android.sh`、`build_windows.sh`、`release.yml`、`验证记录`。

## 结论摘要

| 检查 | 结果 |
|---|---|
| 本地脚本存在且非空 | 见下方证据块 |
| `export_presets.cfg` 含 Windows Desktop + Android | 通过 |
| `release.yml` / `build.yml` 双平台路径 | 通过（文件存在；workflow 文本另见 packaging dry） |
| keystore / signing.local.env **未**进 git | 通过 |
| `store_packaging_dry_check` | 通过（见证据） |
| `export_size_report` | 通过或预算提示（exit 0/1 可接受） |
| 正式 AAB / 付费提审 | **未做**（授权禁止） |

## 证据块（本机干跑摘录）

```
date: 2026-10-25 10:35 CST
git: 480bb831 (origin/main)
--- scripts ---
OK scripts/build_android.sh (6623 bytes)
OK scripts/build_windows.sh (2157 bytes)
OK .github/workflows/release.yml (2782 bytes)
OK .github/workflows/build.yml (2707 bytes)
OK project/export_presets.cfg (5086 bytes)
OK tools/ci/export_size_report.py (6999 bytes)
OK tools/ci/store_packaging_dry_check.py (6336 bytes)
--- packaging dry ---
STORE PACKAGING DRY PASS
exit:0
--- export_size_report (may be 0/1) ---
EXPORT PLATFORM Windows Desktop
EXPORT EXCLUDED 260722903
EXPORT DIR data 4850403
EXPORT DIR scripts 2111729
EXPORT BANK_TIERS master=284724948 medium=132107832 small=76260794 other=0
EXPORT SIZE 826069216
EXPORT BANK plates=2051 bytes=493093574 per_plate=256000 plate_max=600000
EXPORT NONBANK 332975642 base=322500000
EXPORT BUDGET 847556000
EXPORT CAP 419430400
EXPORT TARGET 262144000
EXPORT NOTE Windows active budget is above the 400MiB cap (ships large bank masters); Android is the packing target.

EXPORT PLATFORM Android
EXPORT EXCLUDED 644918955
EXPORT DIR data 4850403
EXPORT DIR scripts 2111729
EXPORT BANK_TIERS master=0 medium=132107832 small=0 other=0
EXPORT SIZE 441873164
EXPORT BANK plates=2051 bytes=132107832 per_plate=256000 plate_max=600000
EXPORT NONBANK 309765332 base=322500000
EXPORT BUDGET 847556000
EXPORT CAP 419430400
EXPORT TARGET 262144000
EXPORT NOTE Android source estimate is above the 400MiB hard cap; see docs/art/export-cap-400.md for measured APK breakdown and next levers.

EXPORT SIZE PASS
exit:0
--- presets names ---
3:name="Windows Desktop"
35:application/company_name="AshBanner Studio"
36:application/product_name="百年骑士·同型原创"
44:name="Android"
80:version/name="9.1.0"
81:package/unique_name="com.ashbanner.centuryknights"
82:package/name="百年骑士"
--- gitignore secrets ---
13:*.keystore
14:*.jks
15:project/android/signing.local.env
--- tracked secret-like ---
none tracked
```

## 复跑命令

```bash
test -f scripts/build_android.sh && test -f scripts/build_windows.sh
test -f .github/workflows/release.yml
python3 tools/ci/store_packaging_dry_check.py
python3 tools/ci/export_size_report.py
python3 tools/ci/store_verify_records_check.py
```

真机 / CI 出包冒烟（APK+zip）仍以 `main-<sha8>` Release 为准；本记录不代替那次附件核对。

## 包体备注

若 `export_size_report` 提示 Android 源估超 400MiB CAP：跟 `docs/art/export-cap-400.md` 与 `package-budget.md`，**禁止**用降画质预设充绿（路线红线）。

## 修订

| 日期 (Asia/Shanghai) | 变更 |
|---|---|
| 2026-10-25 10:35 Asia/Shanghai | 首份导出验证记录；干跑 packaging + size report + 密钥未跟踪 |
