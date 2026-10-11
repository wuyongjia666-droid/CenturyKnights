# CI：什么时候跑什么

必需检查只有一个：聚合作业 **`ci`**（`.github/workflows/ci.yml` 最后一个作业）。它等 `changes`、`farm-queue`、`lint`、`godot-suites`、`shots` 全部结束；任何一个 `failure` / `cancelled` 就失败，`skipped` 算通过。分支保护只需要勾选 `ci`。

## 推送前（必做）

```bash
scripts/precheck.sh            # 约 2–3 分钟：lint、各种 ratchet、农场队列、.import 漂移、关键 Godot 套件
scripts/precheck.sh --no-godot # 约 10 秒：只跑 Python 部分
```

**代理（agent）每次 push 前必须跑 `scripts/precheck.sh` 并看到 `PRECHECK PASS`。** 它按 PR 的方式和 `origin/main` 的 merge-base 比较（`CK_BASE=<分支>` 可改）。覆盖：农场队列校验与单测、JSON/风格/gdlint、i18n 字面量 ratchet、导出体积估算、基因库索引、`.import` 漂移，以及 Godot 套件：基因库（快速模式）、百年战役、结局、章节播放器、本地化 CSV、表情回退、立绘清单、场景加载。完整一遍：`scripts/run_ci.sh`。

## 触发与内容

| 事件 | lint | godot-suites | shots | 基因库 |
|---|---|---|---|---|
| PR，只改 `docs/**`、`tools/farm_queue/**`（队列 JSON 以外）等 | 跑 | 跳过 | 跳过 | 结构检查 |
| PR，改了 `project/**`、`scripts/**`、`tools/ci/**` 等 | 跑 | 跑（快速） | 跑 | 单种子重放 + 只解码 PR 改动的图 |
| PR，改了基因库生成器或清单（见下） | 跑 | 跑（完整） | 跑 | 20 种子完整重放 |
| merge queue（`merge_group`） | 跑 | 跑（快速） | 跑 | 同普通 PR |
| push 到 `main`、每日定时（UTC 19:23）、手动 | 跑（完整） | 跑（完整） | 跑 | 20 种子重放 + 解码所有未验证过的图 |

`farm-queue` 每次都跑（约 20 秒）。

“基因库生成器或清单”指：`project/scripts/art/portrait_bank.gd`、`genome_portrait.gd`、`project/scripts/characters/genome.gd`、`bloodline_v89.gd`、`tools/farm_queue/genome_bank_v92.json`、`docs/art/style-lock-*.json`、`portrait_bank_check.*`。

同一 PR 的新提交会取消旧的 CI（`concurrency: cancel-in-progress`），`main` 上的运行不取消。

## 为什么快

- **Godot 套件并行**：`scripts/run_ci.sh godot` 用 `xargs -P $(nproc)` 同时跑套件；每个进程有自己的 `XDG_DATA_HOME`，`user://` 存档互不干扰。带墙钟预算的 `perf_boot`、`ai_regression`、`impact` 在池子跑完后单独跑。失败时列出所有失败的套件，不在第一个就停。
- **基因库检查分层**：`portrait_bank_check` 原来每次重放 20 局百年战役（CI 上约 13 分钟）。快速模式只重放第一个种子：桶按个体确定、第一个种子先产出，所以它的桶必须逐字段等于清单里的同名桶，漂移照样能抓到。`CK_PORTRAIT_BANK_FULL=1` 走完整 20 种子并要求数量完全相等。
- **基因库图片索引**：`tools/ci/portrait_bank_index.py` 每次检查每张图的三档（大/中/小）和 `.import` 是否齐全，并打印 git blob 内容索引摘要；只有 PR 改动的图才用 Pillow 解码校验尺寸（768×1024、2/3、1/2）和是否纯色。`main` / 夜间解码全部，已验证的 blob 记在缓存里，下次跳过。
- **缓存**：Godot 二进制、导出模板（只保留 Windows/Android）、Android SDK、`project/.godot`。`.godot` 的 key 是 `git rev-parse HEAD:project`（资源树哈希），只在 `main` 上保存；PR 恢复 `main` 最新的一份，只导入自己改动的资源。
- **`.import` 一致**：以前 `tools/art/compress_shipping_webp.py`、`build_portrait_tiers.py` 按 `md5(相对路径)` 写 `.ctex` 名，Godot 用的是 `md5("res://"+路径)`，约 3300 张 WebP 每次都被重新导入（CI 上 import 约 3.7 分钟）。工具已修正，`.import` 文件已用 Godot 重新生成。`godot-suites` 和 precheck 在 import 后检查 `.import` 有没有被改写或新增，有就失败并提示提交。
- **lint 与 Godot 分开**：`scripts/run_ci.sh lint` 不需要 Godot，几秒出结果；checkout 用 `filter: blob:none`，不拉历史大文件。

## 计数从数据推导，不写死

| 以前 | 现在 |
|---|---|
| `test_submit_v92.py` 写死 2062 / 2067 / 2073 张、35 座城 | 直接数 `tools/farm_queue/v92_*.json` 与 `genome_bank_v92.json` 的行数 |
| `ratchet.json` 的 `export_budget_bytes` 每加一批图就要改 | 预算 = `export_base_budget_bytes`（基因库以外）+ 基因库图数 × `export_bank_bytes_per_plate`；单张超过 `export_bank_plate_max_bytes` 直接失败 |
| 基因库 1600 / 1605 桶 | 快速模式按子集比对；完整模式和清单逐条比对，数量来自清单本身 |

新加基因库图、队列行时不用再改任何数字。基础预算和单图上限仍是棘轮：非基因库内容变大、或者有单张图异常大，CI 照样失败。

## 自动合并 / merge queue

- `ci` 在 `pull_request` 和 `merge_group` 上都会报告，并且跳过的子作业不会让它卡在 pending，所以 `gh pr merge --auto --squash` 能在变绿后自动合并。
- 需要仓库管理员在 Settings 打开一次 **Allow auto-merge**（目前是关的），并在分支保护或 ruleset 里把必需检查设为 `ci`；如果要 merge queue，在 ruleset 里开启 “Require merge queue”。

## 发布

`.github/workflows/release.yml`：每次 push 到 `main`（以及 `v*` 标签）并行构建 Windows zip 和 Android 调试 APK（`build.yml`，带上面的缓存），然后建 GitHub Release `main-<sha8>`（标签则用标签名），附上 zip、APK 和 `SHA256-<sha8>.txt`。新的 `main` push 会取消还没跑完的旧发布。`android.yml` 仍可手动只打 APK。改动构建脚本、导出预设或 `.github/actions/**` 的 PR 会自动跑一遍 `build.yml` 验证。

## 本地

```bash
scripts/install_godot.sh
(cd project && godot --headless --import)
scripts/run_ci.sh          # 全部；lint 或 godot 只跑一半
CK_PORTRAIT_BANK_FULL=1 scripts/run_ci.sh godot   # 和 main 一样的完整基因库重放
CK_JOBS=2 scripts/run_ci.sh godot                 # 限制并行数
```
