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
python3 tools/ci/store_prep_check.py
```

## 验证记录

干跑证据与复跑命令见 [`export-paths-verification-record.md`](./export-paths-verification-record.md)。

```bash
python3 tools/ci/store_verify_records_check.py
```
