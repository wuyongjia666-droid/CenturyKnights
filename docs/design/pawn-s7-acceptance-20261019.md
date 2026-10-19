# 棋子 §7 验收收口（2026-10-19）

> 对标 `pawn-redesign-opus.md` §7 + 方案 A（`pawn-gate-proposal-20261017.md`）。  
> 基线 tip：P4 合入 `2bc94c8fd`（32 职标志件 + 22 主题标志 + 退出 board_compact）。  
> 机器可读状态：`project/data/board_figure_s7_acceptance.json`。

## 结论（一句话）

**CI 能证明的方案 A / 覆盖 / 配色静态门禁已绿；像素可读性盲测与真机帧率仍要用户/实机。** 不假装在 llvmpipe 上重测了 §7.1 全表。

## CI 现在能证明的（DONE）

| § | 项 | 门禁 |
|---|---|---|
| 7.1 / 7.3 / 7.4 | 方案 A 航运档预算：每件 ≤15k 三角、≤1.0MB、≤1 张贴图边长 ≤512；`pathc_ship`+`pathc_weapons` 总量 ≤45MB | `tools/ci/pathc_ship_gate.py`（lint） |
| 7.1 | 32 职 + 22 `theme_signs` + kit 部件解析；剪影指纹不撞；`deferred_pathc_meshes` 清单 | `board_figure_gate.py` + `board_figure_check` |
| 7.1 | 22 敌人主题色板槽（cloth/armor/leather）静态阵营色域；4 个 bandit 模板组装配色 + 24 建旗色板 | `board_figure_check` + gate 内主题扫描 |
| 7.1 | 手机头高 ≥24px：**记录**原型 §4.3 最小 28.8px（CELL 103）；CI 不重测像素 | `board_figure_s7_acceptance.json` + gate |
| 7.3 | P3 源契约：空闲 12–15Hz、人数上限 24/32、光晕 blit、低端默认替身（`CK_FORCE_MOBILE`） | `unit_layer_check` / `mobile_unit_layer_check` |
| 7.4 | 棋子资源总量远低于 45MB（当前航运档约 8.2MiB） | `pathc_ship_gate` |

## 故意不卡门禁 / 软拆分（诚实）

§7.1 桌面像素表（轮廓 ≥0.65、分离度 ≥0.40、ΔE、认人进前 3 等）来自**全模块化 Path C 原型**（§4.2）。航运现实是：

- Path C 贴图航运档只覆盖主角/猎手/首领壳 + 少量 outfit（见 `docs/art/review/board_figure_p4_deferred.md`，**29** 职仍用 kit 占位）。
- CI 跑在 llvmpipe 上，无法诚实复现 §4 的像素测量。

因此：

- 门槛数值仍保留在 `project/data/board_figure_baseline.json` → `thresholds_s7_1`，供对照与日后离线重测。
- **不对「全 32 职 Path C 像素分」做假绿。** 状态：`PROTOTYPE_RECORDED_NOT_GATED` / `NEED_USER`。

## 仍需用户 / 实机（NEED_USER）

| § | 项 | 说明 |
|---|---|---|
| 7.2 | 人工盲测 | 5 人 × 10 张棋盘图连线立绘 ≥80%；3 秒读「人/武器/敌我」≥90% |
| 7.2 | 用户最终 A/B | 确认「每个棋子都像立绘里的那个人，有头、有身体、有武器」 |
| 7.3 | 中端安卓帧率 | 实时 3D 16 人：空闲 ≥58；走/攻 ≥55（1% low ≥45） |
| 7.3 | 低端替身 | ≥58fps；开局烘焙 ≤300ms；内存增量 ≤20MB |
| 7.3 | 桌面 GPU | 单位层 ≤1.0ms@1080p（真机 GPU，非 llvmpipe） |
| 7.1 | 全职像素复测（可选） | 待更多 Path C LOD 落地后再离线跑轮廓/分离度/ΔE |

## 样张路径

目录：`docs/art/review/board_figure_s7/`

- 桌面 A/B：`desktop_before_1280x720.png` / `desktop_after_1280x720.png`（及 `battle_after_1280x720.png`）
- 手机（`CK_FORCE_MOBILE`）：`mobile/battle_after_*.png`
- 单位卡：`cards/*.png`

（若某张因无头显未生成，以同目录既有 P1 / pathc_ship 样张作对照；本 PR 以能生成的为准。）

## 延期 Path C

完整 32 职贴图航运 LOD **未**在本收口强行烘焙（预算与观感优先）。清单：`docs/art/review/board_figure_p4_deferred.md`。

## Qwen

`@100.127.28.107:8003` 在本收口时不可达；未派农场任务。

## 不做

- 包体刀 H/I（砍热门库 / 重出更小图）
- 握持改动
- CloudAgent / force-push / farm
