# 崩溃闸 / 性能档清单

> 可执行门禁：下列命令失败 = 不得标「商店工程通过」。不代替真机签收。  
> 关键词：`perf_budget.json`、`mobile_gate`（供 `store_prep` 短语门禁）。

## 崩溃闸（必过）

| id | 门禁 | 怎么跑 |
|---|---|---|
| ci_aggregate | PR/main CI 聚合 `ci` 绿 | GitHub Actions |
| mobile_gate | 手游布局门禁 | `python3 tools/ci/mobile_gate.py` |
| desktop_gate | 桌面布局门禁 | `python3 tools/ci/desktop_gate.py` |
| dynasty_end | 空团/团灭不崩 | Godot suite `dynasty_end_stub_check` / `dynasty_wipeout_check` |
| save_roundtrip | 存档往返 | `project/tests/save_roundtrip_check` |
| store_prep | 商店文档 + 中篇字数闸 + 出包干跑 | `python3 tools/ci/store_prep_check.py` |
| store_pack_dry | 脚本/预设/listing 实质体积 | `python3 tools/ci/store_packaging_dry_check.py` |

发版前额外：2400×1080 横屏 AVD 冒烟（见 `docs/design/mobile-landscape.md`）。

## 性能档

预算文件：`tools/ci/perf_budget.json`

| 档 | 含义 | 预算字段 |
|---|---|---|
| boot | 启动到可交互 | `boot_ms`（含 slack） |
| mem | 静态内存 | `memory_static_bytes` |
| tex | 纹理内存 | `texture_mem_bytes` |
| scenes | 分场景加载 | `scenes_ms.*`（main_menu / castle_hub / battle / atlas_view） |

跑法：CI perf job；本地改场景后对比 `perf_budget.json`，超 `value * slack` 须解释或改预算。移动档破预算不得用「端游还行」搪塞。

## 崩溃上报（上架前）

- 默认单机：**不收集**  
- 若开启崩溃通道：须在 `privacy-policy-draft.md` 写明，并提供关闭开关  
- 密钥 / DSN **不进 git**

## 本清单勾选（工程自检）

- [ ] `python3 tools/ci/store_prep_check.py` 退出码 0  
- [ ] `python3 tools/ci/store_packaging_dry_check.py` 退出码 0  
- [ ] `python3 tools/ci/export_size_report.py` 退出码 0 或 1  
- [ ] 最近一次 `main-<sha8>` Release 含 APK + zip + SHA256  
- [ ] 无 keystore / 密码进库  
- [ ] 季中篇字数闸未削弱（≥12000 汉字 / 对标季1）
