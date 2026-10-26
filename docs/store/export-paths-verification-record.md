# 导出路径验证记录（不缴费 · 干跑）

> 对 `export-paths.md` 的**可执行核对**。本记录**不出正式商店包、不上传、不花费**。  
> 记录时点：2026-10-27 00:08 Asia/Shanghai
> 关键词：`build_android.sh`、`build_windows.sh`、`release.yml`、`验证记录`。

## 结论摘要

| 检查 | 结果 |
|---|---|
| 本地脚本存在且非空 | 见下方证据块 |
| `export_presets.cfg` 含 Windows Desktop + Android；产物路径对齐 | 通过（`CenturyKnights.exe` / `CenturyKnights-debug.apk`） |
| Android 血统库 **medium_only** 排除规则 | 通过（排除 master + small；`EXPORT ANDROID_BANK_CONTRACT medium_only=1`） |
| `release.yml` / `build.yml` 双平台路径 + 附件命名 | 通过（`main-` / `CenturyKnights-android-` / `SHA256-` / windows-zip） |
| keystore / signing.local.env **未**进 git | 通过 |
| `store_packaging_dry_check` | **STORE PACKAGING DRY PASS** |
| `export_size_report` | **EXPORT SIZE PASS**（预算内；Android CAP 仍 OVER，见包体备注） |
| CI lint 接线 | `run_ci.sh` 含 export_size / store_prep / store_packaging_dry / store_verify_records |
| 正式 AAB / 付费提审 | **未做**（授权禁止） |
| 本机 `build_windows.sh` | **通过**（2026-10-27 00:10 Asia/Shanghai → `exports/CenturyKnights.exe` ~913 MiB；rcedit 警告可忽略） |
| 本机 `build_android.sh` | **未跑通**（盒上缺 JDK 包源；CI / 用户机） |

## 证据块（本机干跑摘录）

```
date: 2026-10-27 00:08 Asia/Shanghai
git: 33e28515 (worktree feat/store-eng-prep-e2e @ origin/main base)
--- scripts ---
OK scripts/build_android.sh (6623 bytes)
OK scripts/build_windows.sh (2157 bytes)
OK .github/workflows/release.yml (2782 bytes)
OK .github/workflows/build.yml (2707 bytes)
OK project/export_presets.cfg (5086 bytes)
OK tools/ci/export_size_report.py (7856 bytes)
OK tools/ci/store_packaging_dry_check.py (10966 bytes)
OK tools/ci/store_prep_check.py (7927 bytes)
OK tools/ci/store_verify_records_check.py (2132 bytes)
--- packaging dry ---
STORE PACKAGING DRY PASS
exit:0
--- export_size_report ---
EXPORT PLATFORM Windows Desktop
EXPORT EXCLUDED 6244637
EXPORT BANK_TIERS master=284724948 medium=132107832 small=76260794 other=0
EXPORT SIZE 827693373
EXPORT BANK plates=2051 bytes=493093574 per_plate=256000 plate_max=600000
EXPORT NONBANK 334599799 base=322500000
EXPORT BUDGET 847556000
EXPORT CAP 419430400
EXPORT TARGET 262144000
EXPORT CAP_STATUS Windows Desktop OVER 827693373
EXPORT NOTE Windows active budget is above the 400MiB cap (ships large bank masters); Android is the packing target.

EXPORT PLATFORM Android
EXPORT EXCLUDED 390440689
EXPORT BANK_TIERS master=0 medium=132107832 small=0 other=0
EXPORT SIZE 443497321
EXPORT BANK plates=2051 bytes=132107832 per_plate=256000 plate_max=600000
EXPORT NONBANK 311389489 base=322500000
EXPORT BUDGET 847556000
EXPORT CAP 419430400
EXPORT TARGET 262144000
EXPORT CAP_STATUS Android OVER 443497321
EXPORT ANDROID_BANK_CONTRACT medium_only=1
EXPORT NOTE Android source estimate is above the 400MiB hard cap; see docs/art/export-cap-400.md for measured APK breakdown and next levers.

EXPORT SIZE PASS
--- presets / paths ---
Windows export_path=../exports/CenturyKnights.exe
Android export_path=../exports/android/CenturyKnights-debug.apk
package/unique_name=com.ashbanner.centuryknights
permissions/internet=false
--- gitignore secrets ---
*.keystore
*.jks
project/android/signing.local.env
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
python3 tools/ci/store_prep_check.py
```

真机 / CI 出包冒烟（APK+zip）仍以 `main-<sha8>` Release 为准；本记录不代替那次附件核对。本机若缺 JDK / Android 构建模板，Android 本地出包会 exit 2（工程预期）；Windows 导出模板齐全时可跑 `bash scripts/build_windows.sh`。

## 包体备注

- `EXPORT CAP_STATUS Android OVER`：源估约 423 MiB > 400 MiB CAP；`medium_only=1` 已硬闸。后续杠杆见 `docs/art/export-cap-400.md`（H/I 需用户拍板），**禁止**用降画质预设充绿。
- Windows CAP OVER 为预期（含 master bank）；打包主目标仍是 Android。

## 用户侧 blocker（本轨无法代劳）

- [ ] 正式 `main-<sha8>` Release 双平台附件过目（CI 出包，非本干跑）
- [ ] 本机/CI 确认 `build_android.sh` 在 JDK17 + SDK 环境成功（本盒缺 JDK 包源）
- [ ] 隐私政策公网 URL / 付费商店账号（见隐私与支持验证记录）

## 修订

| 日期 (Asia/Shanghai) | 变更 |
|---|---|
| 2026-10-25 10:36 Asia/Shanghai | 首份导出验证记录；干跑 packaging + size report + 密钥未跟踪 |
| 2026-10-27 00:08 Asia/Shanghai | 刷新证据：CAP_STATUS / medium_only 硬闸、CI lint 接线、产物路径对齐、用户 blocker 表 |
