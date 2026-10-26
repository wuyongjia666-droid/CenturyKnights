# Android + Windows 出包路径

## 本地

| 平台 | 命令 | 产物 |
|---|---|---|
| Windows | `bash scripts/build_windows.sh` | `exports/CenturyKnights.exe`（及同目录依赖） |
| Android Debug APK | `bash scripts/build_android.sh` | `exports/android/CenturyKnights-debug.apk` |

前置：

- Godot **4.3** 在 `PATH` 或设 `GODOT=`
- Windows：导出模板 `4.3.stable`（`windows_release_x86_64.exe`）
- Android：JDK 17（`JAVA_HOME`）、Android SDK（`ANDROID_SDK_ROOT`）、工程已装 Android 构建模板（`project/android/build.gradle`）
- 签名：只走环境变量 / `project/android/signing.local.env`（gitignore）；**禁止**提交 keystore

详见仓库根 `README.md` §Android / Windows。

## GitHub Actions（自动试玩包）

- 工作流：`.github/workflows/release.yml`
- 触发：`push` → `main`，或 `v*` 标签，或 `workflow_dispatch`
- 构建：复用 `.github/workflows/build.yml`（`windows: true` + `android: true`）
- 发布：GitHub Release 标签 `main-<sha8>`（或版本标签），附件 Windows zip + Android APK + `SHA256-<sha8>.txt`
- 新 `main` push 会取消未跑完的旧 release（concurrency）

**正式商店提审包**（AAB / 签名正式包 / 商店控制台上传）不在本仓库自动缴费流程内；需要时人工用同一导出预设出包，密钥仍不进库。

## 校验

```bash
test -f scripts/build_android.sh
test -f scripts/build_windows.sh
test -f .github/workflows/release.yml
python3 tools/ci/export_size_report.py
python3 tools/ci/store_packaging_dry_check.py
python3 tools/ci/store_verify_records_check.py
python3 tools/ci/store_prep_check.py
```

干跑证据与 `EXPORT CAP_STATUS` / `medium_only` 合同见 [`export-paths-verification-record.md`](./export-paths-verification-record.md)。Android CAP OVER 时预算仍可通过；闭合 CAP 见 `docs/art/export-cap-400.md`（H/I 用户拍板）。

## 正式提审包（人工，不缴费自动化）

| 目标 | 今日做法 | 备注 |
|---|---|---|
| Play AAB | 本机 Godot 导出 Android 正式预设 → AAB | CI 仍发 debug APK 试玩；AAB 不进自动缴费 |
| Play 上传 | 业主 Play Console 人工 | **不缴费提审**则停在上传前 |
| MS 商店包 | 需 MSIX/打包另刀 | 今日仅 zip 试玩 |
| 签名 | Play App Signing / 本地 upload key | keystore **禁止**进 git |
| 包体复核 | `python3 tools/ci/export_size_report.py` | 超预算先削按需资源，禁 H/I 砍画质 |

## 与门禁的关系

- `store_prep_check.py`：文档齐全 + 季#2/#3 中篇 ≥12000 汉字 + 嵌套 packaging dry  
- `store_packaging_dry_check.py`：脚本/预设/workflow/listing 实质体积  
- 两者都绿才算「商店工程可重复」，**不等于**已提审

## 验证记录

干跑证据与复跑命令见 [`export-paths-verification-record.md`](./export-paths-verification-record.md)。

```bash
python3 tools/ci/store_verify_records_check.py
```

