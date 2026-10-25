# 内容季流水（工程脚手架）

对齐 [`docs/design/three-year-roadmap-2026-10.md`](../design/three-year-roadmap-2026-10.md) §4。  
**不可跳步**：选题 → 小说 → 圣经 → 可玩章 → 系统加深 → 立绘/资源 → 试玩包。

| 季 | 目录 | 机器表 | 状态 |
|---|---|---|---|
| #1 | [`season-01/`](./season-01/) | `project/data/content_seasons/season_01.json` | 小说+圣经+可玩章草稿（`cs01_01`） |
| #2 | [`season-02/`](./season-02/) | `project/data/content_seasons/season_02.json` | **小说初稿已开写**（婚约上的灯；诞育/联姻月回响） |
| #3 | [`season-03/`](./season-03/) | `project/data/content_seasons/season_03.json` | **中篇+可玩章 `cs03_01`**（榜上的收成；委托/属地月回响） |
| #4 | [`season-04/`](./season-04/) | `project/data/content_seasons/season_04.json` | **中篇+可玩章 `cs04_01`**（家训上的灯；家训月回响） |
| #5 | [`season-05/`](./season-05/) | `project/data/content_seasons/season_05.json` | **中篇+可玩章 `cs05_01`**（空椅上的灯；联姻→继承→嗣位链） |
| #6 | [`season-06/`](./season-06/) | `project/data/content_seasons/season_06.json` | **中篇+可玩章 `cs06_01`**（校场上的灯；嗣位校场争锋） |
| #7 | [`season-07/`](./season-07/) | `project/data/content_seasons/season_07.json` | **中篇+可玩章 `cs07_01`**（仪典上的灯；认宗仪典） |
| #8 | [`season-08/`](./season-08/) | `project/data/content_seasons/season_08.json` | **中篇+可玩章 `cs08_01`**（祖祠上的灯；祖祠） |
| #9 | [`season-09/`](./season-09/) | `project/data/content_seasons/season_09.json` | **中篇+可玩章 `cs09_01`**（血验上的灯；血验） |
| #10 | [`season-10/`](./season-10/) | `project/data/content_seasons/season_10.json` | **中篇+可玩章 `cs10_01`**（印上的灯；职印） |

每季目录约定：

- `TOPIC.md` — 旗/灯冲突 + 本季加深的 1 个系统（选题）
- `CHECKLIST.md` — 选题清单（与机器表 `topic_checklist` 对齐）
- `NOVEL.md` — 中篇
- `BIBLE.md` — 动机 / 节拍 / 口吻
- `PLAYABLE.md` — 大白话可玩章，单行 ≤60 字
- `ACCEPTANCE.md` — 系统加深 + 流水门禁的 PR 验收条（与 `acceptance[]` 对齐）

机器表（v2+）额外字段：

- `topic_checklist[]` — 选题清单项（`id` / `label_zh` / `required`）
- `acceptance[]` — 验收条（`id` / `label_zh` / `suite` / `done`）；`suite` 须为仓库内 `.tscn`
- `pipeline_stages` — 每步 `doc` / `gate` / `open`
- `playable_chapter` / `playable_path` — 可玩章 id 与资源路径（季 #1 已开）

CI：`suite_content_season_scaffold_check` 校验 **index 内全部季**；`suite_content_season_playable_check` 走季#1 `cs01_01`；`content_season_playable_s03_check` / `s04` / `s05` / `s06` / `s07` / `s08` / `s09` 走对应可玩章。  
季#2..#9 要求正文开写（≥12000 汉字）。商店工程并行见 [`docs/store/`](../store/)。

## 分工边界

- **季#1 专线**：`season-01/`、可玩章 `cs01_01`、playable suite；本专线合入时只跟进闸门，不改其正文。
- **本专线（季#2/#3 + 商店）**：`season-02/`、`season-03/`、`docs/store/`、多季 index/suite、路线文首状态。
