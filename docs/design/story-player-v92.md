# 章节播放器 v9.2（NAR-02）

一个场景播放 `data/story/chapters/*.json`。第零章仍从 `scenes/story/chapter0.tscn` 进入，脚本是同一个播放器，`lock_path` 锁在 `ch0.json`。

## 旧卷

1–234 章的 `chapterN.gd` / `chapterN.tscn` 删除，不再作为主线，也不提供重玩入口。模板对白留在 `data/chapterN.json`：`CKStoryState` 按这个路径懒加载，核心套件会读第 11 章。播放器忽略这些文件，也忽略 `chapters/lint_*.json`。

第零章末拍「踏上第一章·陆桥烽火」仍在，按下后由老旗手说明旧卷已封存，不切到已删除的场景。

## 入口 API（UX-06 / 舆图）

`StoryCatalog`（`scripts/narrative/story_catalog.gd`）：

- `mainline_entries()`：当前可播章节，含 id、标题、JSON 路径、场景。
- `request_chapter(id)`：写入 `story_chapter_id`，返回要打开的场景。`ch0` 返回 `chapter0.tscn`。
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
| `archive_notice` | 旧卷封存说明 |

条件写在 `when`：`flag`、`not_flag`、`any_flag`、`not_any_flag`、`bloodline`、`companion`、`all`、`any`、`not`。

`objective` 先记在 meta `battle_objective`。战斗脚本还不读它，等 BTL-02。

## 第零章

流程与原来的节拍门相同：隘口、招募、枢纽、联姻、初啼、丰收、手记。说话者「系统」已改成老旗手、灯影、掌柜、管事、春令使者或稳婆。单行不超过六十个汉字。
