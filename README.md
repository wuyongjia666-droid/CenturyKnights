# 百年骑士·同型原创 / CenturyKnights

**原作同型玩法研究项目**（系统级致敬，非素材/剧情/地图 1:1 复制，非破解反编译）。

- 引擎：Godot 4.3
- 工作标题（中）：百年骑士·同型原创
- 工程 ID（英）：CenturyKnights
- 垂直切片：约 30–45 分钟「第零章·灰旗初升」加长闭环（程序立绘/战旗 → 战棋 → 招募 → 城堡 → 联姻遗传 → 岁月）

## 快速运行

```bash
cd project
godot --path .
# 冒烟
godot --headless --path . --scene res://tests/smoke_runner.tscn
# 战棋 e2e（模拟点击选→移→攻）
godot --headless --path . --scene res://tests/tactics_e2e.tscn
# CI 全套（失败非 0，成功时最后一行是 CI ALL PASS）
../scripts/install_godot.sh
../scripts/run_ci.sh
```

## CI

`scripts/install_godot.sh` 下载 Godot 4.3-stable linux x86_64，校验 SHA256，并把 `godot` 链接到 `~/.local/bin`。重复执行不会重新下载。已有二进制时用 `GODOT_BIN=/path/to/godot ./scripts/install_godot.sh`。

`./scripts/run_ci.sh` 会先跑 `tools/ci/json_lint.py`，再自动发现 `project/tests/suites/*/` 下的 `*_check.tscn` 与 `*_check.gd`。发现数量打印为 `suites discovered: N`。每个用例必须打印 `PASS`，失败时 `quit(1)`。同名 `.gd` 与 `.tscn` 成对时只跑场景（`.gd` 是场景脚本）。

GitHub Actions 工作流是 `.github/workflows/ci.yml`（`pull_request` 与 `push` 到 `main`）。它缓存 Godot 与 `project/.godot/imported`，先 import 再执行 `scripts/run_ci.sh`。失败时上传 `/tmp/ck_*.log`。

## Android 调试包

桌面版仍是 1280×720。手机（或 `CK_FORCE_MOBILE=1`）在运行时把拉伸改为 `expand`，按安全区摆放界面，目标分辨率是 **1080×1920（16:9）** 和 **1080×2400（20:9）**，横竖屏都能转。战棋盘和舆图保持 2D：点按＝选中/确认，长按＝情报，单指平移，双指缩放。鼠标左键仍在按下时选中，右键取消，滚轮缩放。战斗指令在手机上收进底栏。名册、酒馆、工坊列表可滚动，主按钮高度按 44dp 换算；舆图节点和顶栏返回键有上限，避免盖住 Stitch 霜色版式。低配手机会关掉 3D 过场的 MSAA、阴影和粒子，并改用简化着色；中配手机把 MSAA 降到 2×。可选 `CK_SIMPLE_TOON=1` 或存档设置 `simple_toon`。iOS 不在这次范围内。

密钥只走环境变量，**不要把 `.keystore` / `.jks` 或密码提交进仓库**。`export_presets.cfg` 里的签名字段留空。本机编辑器第一次打开 Android 导出界面时，会在编辑器配置里生成 debug keystore；纯命令行环境没有这份配置，需要自己设下面的变量。示例在 `project/android/signing.example.env`（复制为 `project/android/signing.local.env`，该文件已被 gitignore）：

- `GODOT_ANDROID_KEYSTORE_DEBUG_PATH` / `USER` / `PASSWORD`
- `GODOT_ANDROID_KEYSTORE_RELEASE_PATH` / `USER` / `PASSWORD`

Gradle：`minSdk` 24（Forward Plus / Vulkan）、`targetSdk` 34，调试包为 APK，架构 `arm64-v8a` 与模拟器用的 `x86_64`。

### Linux

```bash
# JDK 17、Android SDK、与编辑器同版本的 Godot 4.3 导出模板
export JAVA_HOME=/usr/lib/jvm/java-17-openjdk-amd64
export ANDROID_SDK_ROOT="$HOME/Android/Sdk"
# 编辑器里先做一次：项目 → 安装 Android 构建模板
./scripts/build_android.sh
# 产物：exports/android/CenturyKnights-debug.apk
```

SDK、JDK、Godot 或 Gradle 模板缺失时，脚本以状态码 2 退出并说明缺什么，不会去猜密钥。

### Windows

在 PowerShell 中安装 JDK 17 与 Android Studio（SDK 通常在 `%LOCALAPPDATA%\Android\Sdk`），再用 Git Bash 或 WSL 执行同一脚本：

```bash
export JAVA_HOME="/c/Program Files/Java/jdk-17"
export ANDROID_SDK_ROOT="$LOCALAPPDATA/Android/Sdk"
export GODOT="/c/Program Files/Godot/Godot_v4.3-stable_win64.exe"
./scripts/build_android.sh
```

也可以在 Godot 4.3 里打开工程，导出预设选 **Android**，用「导出项目（调试）」打出 APK。编辑器需在 **编辑器设置 → Export → Android** 填 SDK 与 JDK 路径；脚本会尝试把这两个路径写入 `editor_settings-4.3.tres`。

### 真机 / 模拟器手测

无头 CI 不代替实机。装上调试 APK 后：

1. 1080×1920 与 1080×2400（或同比例模拟器）各开一次。刘海和底部手势条不盖住顶栏标题与底栏按钮。
2. 主菜单能点进新旗号。顶栏「返回」能点到。
3. 战棋：点按选中并移动，再点敌人攻击；长按只刷新情报、不移动；单指平移、双指缩放棋盘；底栏可攻击、战技、待命、取消、结束回合。棋盘仍是 2D。
4. 过场能播完，跳过按钮能点。低内存设备上不应再喷 3D 粒子。
5. 舆图：点聚落选中，再点一次启程；长按只显示情报；单指平移、双指缩放。
6. 名册、酒馆、工坊列表能滑动，行和招募按钮容易点中。
7. 回到桌面：鼠标左键选子、右键取消、滚轮缩放仍然有效，`./scripts/run_ci.sh` 保持通过。

## Windows 试玩包

见 GitHub Releases 最新：`CenturyKnights-windows-v7.18.0-depth.zip Ch229–231 + 第三十八卷瓷市中段 Ch232–234；教学约 4 vs 2）。

## 20 分钟怎么玩

1. **新的旗号** → 起姓起名选纹章色  
2. 第零章对白推进 → **隘口之夜**战棋教学（歼灭）  
3. **烽火酒馆**招募 1 人  
4. 进入 **灰旗堡** 枢纽  
5. **联姻廷**：看「子嗣期望」→ 成婚  
6. 推进一月 **初啼**，打开族谱看血胤混合条  
7. **岁月沙漏**跳至丰收月 → 生成 **王朝手记**

## 目录

| 路径 | 说明 |
|------|------|
| `project/` | Godot 工程 |
| `_bmad-output/planning-artifacts/` | GDD / epics / sprint |
| `docs/style-bible.md` | 美术风格占位稿 |
| `exports/` | Windows 导出（本地） |

## 边界

- 原创剧情、地名、家族名、UI 文案（简体中文）
- 禁止：反编译、搬运对标资产与原文、复用 GeneRanch
