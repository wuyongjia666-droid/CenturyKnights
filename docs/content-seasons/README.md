# 内容季流水（工程脚手架）

对齐 [`docs/design/three-year-roadmap-2026-10.md`](../design/three-year-roadmap-2026-10.md) §4。  
**不可跳步**：选题 → 小说 → 圣经 → 可玩章 → 系统加深 → 立绘/资源 → 试玩包。

| 季 | 目录 | 机器表 | 状态 |
|---|---|---|---|
| #1 | [`season-01/`](./season-01/) | `project/data/content_seasons/season_01.json` | 选题脚手架 v2（待 Y1-A 真机签收后再扩写小说） |

每季目录约定：

- `TOPIC.md` — 旗/灯冲突 + 本季加深的 1 个系统（选题）
- `CHECKLIST.md` — 选题清单（与机器表 `topic_checklist` 对齐）
- `NOVEL.md` — 中篇（签收后才写）
- `BIBLE.md` — 动机 / 节拍 / 口吻
- `PLAYABLE.md` — 大白话可玩章，单行 ≤60 字
- `ACCEPTANCE.md` — 系统加深 + 流水门禁的 PR 验收条（与 `acceptance[]` 对齐）

机器表（v2）额外字段：

- `topic_checklist[]` — 选题清单项（`id` / `label_zh` / `required`）
- `acceptance[]` — 验收条（`id` / `label_zh` / `suite` / `done`）；`suite` 须为仓库内 `.tscn`
- `pipeline_stages` — 每步 `doc` / `gate` / `open`；受闸门的步骤在签收前 `open: false`

CI：`suite_content_season_scaffold_check` 校验机器表、清单、验收 suite 路径与目录骨架；**不**要求小说正文存在（闸门：签收前不开扩写）。
