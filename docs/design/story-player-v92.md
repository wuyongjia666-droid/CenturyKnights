# 章节播放器 v9.2（NAR-02）

一个场景播放 `data/story/chapters/*.json`。第零章仍从 `scenes/story/chapter0.tscn` 进入，脚本是同一个播放器，`lock_path` 锁在 `ch0.json`。

## 旧卷

1–234 章的 `chapterN.gd` / `chapterN.tscn` 删除，不再作为主线，也不提供重玩入口。模板对白留在 `data/chapterN.json`：`CKStoryState` 按这个路径懒加载，核心套件会读第 11 章。播放器忽略这些文件，也忽略 `chapters/lint_*.json`。

第零章末拍按钮改为「踏上第一卷·过路银的收据」：写 `chapter0_done`，用 `open_chapter` 进入 `e1_01`（v9.2.1，审查 P1-5）。不再弹旧卷封存提示，也不再 `set_beat` 旧卷第 1 章。

## 入口 API（UX-06 / 舆图）

`StoryCatalog`（`scripts/narrative/story_catalog.gd`）：

- `mainline_entries()`：当前可播章节，含 id、标题、JSON 路径、场景。
- `request_chapter(id)`：写入 `story_chapter_id`，返回要打开的场景。`ch0` 返回 `chapter0.tscn`。
- `path_for(id)`：章节 id 对应的 JSON 路径（`e1_01` → `era1_01.json`）。播放器只按这个路径加载，**不拿 id 拼文件名**。id 不在目录里时报错、显示「章节结束」和回城按钮，**不回落 `ch0.json`**（v9.2.1，审查 P0-1）。
- `archive_replay_enabled()`：恒为 false。

城堡梯子、`World.mainline_marker()` 里的 `chapter%d.tscn` 不在本流。见文末交接。

## 章节形状

节拍含台词（`id` / `speaker` / `text`）、`actions`、可选 `prepare`。动作的 `do` 是一组 op：

| op | 作用 |
|---|---|
| `goto` | 跳到节拍；`next` 读本拍的 `next` |
| `set_flag` | 写旗标 |
| `set_beat` | 写某一章的节拍指针（兼容垫片） |
| `battle` | `map` + `objective`，并记下返回场景 |
| `scene` | 切到枢纽场景 |
| `advance` / `fast_harvest` | 第零章的月份与丰收 |
| `journal` | 王朝手记，并标记第零章完成 |
| `ensure_reputation` | 春令试婚前把灰烬邦声望补到友善 |
| `archive_notice` | 旧卷封存说明（保留兼容，主线不再使用） |
| `open_chapter` | `id`：经 `StoryCatalog.request_chapter(id)` 打开另一章（第零章 → `e1_01`） |
| `visit` | 打开委托板、舆图、沙漏等侧屏；侧屏的「返回」回到本章当前拍（`StoryCatalog.take_story_return`） |
| `adjust` | 按差值改银、粮、士气、各邦声望，并可写一条日志 |
| `skip_battle` / `auto_recruit` / `auto_marry` | 序章「教学从简」：战斗按胜结算、按银招一人、择一席入座 |

`advance` 可带 `until_flag`（加 `max` 上限）：一直推进月份，直到旗标成立。台词可带 `stage`（`music` / `tension` / `camera` / `pace`）和 `expression`，见 `docs/story/prologue-bible.md` 第 8 节。台词里的 `{surname}` 换成玩家写下的姓。

条件写在 `when`：`flag`、`not_flag`、`any_flag`、`not_any_flag`、`bloodline`、`companion`、`all`、`any`、`not`。节拍和单句台词也可以带 `when`。不满足的节拍顺着 `next` 跳过，不满足的台词不显示。

`battle` 把 `objective` 记在 meta `battle_objective`。真正结算的是地图 JSON 里的 `objective`（BTL-02）。第一纪元八场在 `data/maps/story_era1.json`，章节在 `data/story/chapters/era1_*.json`。第二、三纪元十六章在 `era2_*.json`、`era3_*.json`，地图在 `story_era2.json`、`story_era3.json`。

台词里的 `{heir}` 在显示时换成族谱上还活着、且 `parent_ids` 含当前旗主 id 的那个人的名字。没有这样的人时，换成 `narrative.csv` 的 `nar06_no_heir`。授旗章 `e3_05` 的 `rite` 节拍用这一处，不把孩子的名字写死。

## 章节结束协议（v9.2.1，审查 P0-2）

- 每一拍都要有出路。末拍（`next` 为空）没有可见动作时，播放器补一个「回到灰旗堡」（`story_back_to_hub`），回城堡枢纽。
- 进入末拍时这一拍已写进 `CKStoryState`，主线游标（`HubTodo.mainline_target()`）以「存的拍 == 目录里的 `last_beat`」判定本章完成，回城后「继续主线」打开下一章。
- 返回键 / ESC 仍打开暂停菜单；暂停菜单有「回到灰旗堡」（`pause_hub`），任何场景都能离开，不必回标题再读档。
- 测试：`chapter_player_check` 断言 e1–e5 每一章的末拍至少有一个可见动作。

## legacy_index 取值（审查 P1-6）

| 范围 | 用途 |
|---|---|
| 0 | 第零章（另存在 `chapter0_beat`） |
| 1–234 | 封存旧卷，只读兼容 |
| 101–399 | 卷章（现用：第一卷 101–108，第二、三卷 201–216，第四、五卷 301–316） |

`CKStoryState.CHAPTER_COUNT = 400`。旧存档只有 0–234 键，缺的键按默认拍载入（`LEGACY_COUNT = 235` 仅用于旧档兼容测试）。新卷的 `legacy_index` 必须小于 `CHAPTER_COUNT`，`chapter_player_check` 会验证每章 `set_beat` 后能读回。

## 第零章

流程与原来的节拍门相同：隘口、招募、枢纽、联姻、初啼、丰收、手记。说话者「系统」已改成老旗手、灯影、掌柜、管事、春令使者或稳婆。单行不超过六十个汉字。
