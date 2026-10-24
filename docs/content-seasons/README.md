# 内容季流水（工程脚手架）

对齐 [`docs/design/three-year-roadmap-2026-10.md`](../design/three-year-roadmap-2026-10.md) §4。  
**不可跳步**：选题 → 小说 → 圣经 → 可玩章 → 系统加深 → 立绘/资源 → 试玩包。

| 季 | 目录 | 机器表 | 状态 |
|---|---|---|---|
| #1 | [`season-01/`](./season-01/) | `project/data/content_seasons/season_01.json` | 选题脚手架（待 Y1-A 真机签收后再扩写小说） |

每季目录约定：

- `TOPIC.md` — 旗/灯冲突 + 本季加深的 1 个系统（选题）
- `NOVEL.md` — 中篇（签收后才写）
- `BIBLE.md` — 动机 / 节拍 / 口吻
- `PLAYABLE.md` — 大白话可玩章，单行 ≤60 字
- `ACCEPTANCE.md` — 系统加深的 PR 验收条

CI：`suite_content_season_scaffold_check` 校验机器表字段与目录骨架；**不**要求小说正文存在（闸门：签收前不开扩写）。
