# 内容季流水（工程脚手架）

对齐 [`docs/design/three-year-roadmap-2026-10.md`](../design/three-year-roadmap-2026-10.md) §4。  
**不可跳步**：选题 → 小说 → 圣经 → 可玩章 → 系统加深 → 立绘/资源 → 试玩包。

| 季 | 目录 | 机器表 | 状态 |
|---|---|---|---|
| #1 | [`season-01/`](./season-01/) | `project/data/content_seasons/season_01.json` | 小说+圣经+可玩章草稿（`cs01_01`） |
| #2 | [`season-02/`](./season-02/) | `project/data/content_seasons/season_02.json` | 选题脚手架起步 |

每季目录约定：

- `TOPIC.md` — 旗/灯冲突 + 本季加深的 1 个系统（选题）
- `CHECKLIST.md` — 选题清单（与机器表 `topic_checklist` 对齐）
- `NOVEL.md` — 中篇
- `BIBLE.md` — 动机 / 节拍 / 口吻
- `PLAYABLE.md` — 大白话可玩章，单行 ≤60 字
- `ACCEPTANCE.md` — 系统加深 + 流水门禁的 PR 验收条（与 `acceptance[]` 对齐）

机器表（v3）额外字段：

- `topic_checklist[]` — 选题清单项（`id` / `label_zh` / `required`）
- `acceptance[]` — 验收条（`id` / `label_zh` / `suite` / `done`）；`suite` 须为仓库内 `.tscn`
- `pipeline_stages` — 每步 `doc` / `gate` / `open`
- `playable_chapter` / `playable_path` — 可玩章 id 与资源路径（季 #1）

CI：`suite_content_season_scaffold_check` + `suite_content_season_playable_check`。
