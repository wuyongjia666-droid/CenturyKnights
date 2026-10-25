# 崩溃闸 / 性能档清单

> 可执行门禁：下列命令失败 = 不得标「商店工程通过」。不代替真机签收。

## 崩溃闸（必过）

| id | 门禁 | 怎么跑 |
|---|---|---|
| ci_aggregate | PR/main CI 聚合 `ci` 绿 | GitHub Actions |
| mobile_gate | 手游布局门禁 | `python3 tools/ci/mobile_gate.py` |
| desktop_gate | 桌面布局门禁 | `python3 tools/ci/desktop_gate.py` |
| dynasty_end | 空团/团灭不崩 | Godot suite `dynasty_end_stub_check` / `dynasty_wipeout_check` |
| save_roundtrip | 存档往返 | `project/tests/save_roundtrip_check` |

发版前额外（设计已写）：2400×1080 横屏 AVD 冒烟——主流程点击 + 每页返回；黑边/裁切/卡死/崩溃阻止发版（见 `docs/design/mobile-landscape.md`）。

## 性能档

预算文件：`tools/ci/perf_budget.json`

| 档 | 含义 | 预算字段 |
|---|---|---|
| boot | 启动到可交互 | `boot_ms`（含 slack） |
| mem | 静态内存 | `memory_static_bytes` |
| tex | 纹理内存 | `texture_mem_bytes` |
| scenes | 分场景加载 | `scenes_ms.*`（main_menu / castle_hub / battle / atlas_view） |

跑法：仓库现有 perf 采集 job（CI）；本地改场景后对比 `perf_budget.json`，超 `value * slack` 须解释或改预算并说明原因。

## 本清单勾选（工程自检）

- [ ] `python3 tools/ci/store_prep_check.py` 退出码 0  
- [ ] `python3 tools/ci/export_size_report.py` 退出码 0（包体未破 ratchet）  
- [ ] 最近一次 `main-<sha8>` Release 含 APK + zip + SHA256  
- [ ] 无 keystore / 密码进库（`git grep` 自检）  
- [ ] 真机/模拟器冒烟笔记链到当次包（统一试玩时补）
