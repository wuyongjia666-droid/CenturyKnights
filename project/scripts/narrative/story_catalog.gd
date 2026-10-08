class_name StoryCatalog
extends RefCounted
## NAR-02 交给 UX-06 / 舆图的章节入口。城堡梯子仍在 castle_hub.gd，本类不改那份脚本。
##
## 用法：
##   StoryCatalog.mainline_entries() -> [{id, title, path, scene}]
##   StoryCatalog.request_chapter(id) 写入 meta story_chapter_id，返回播放器场景。
##   第零章请继续打开 chapter0.tscn（lock_path），命名、酒馆、联姻、族谱、沙漏都指着它。
##   StoryCatalog.archive_replay_enabled() == false：旧 1–234 章不重玩。

const PLAYER_SCENE := "res://scenes/story/chapter_player.tscn"
const CHAPTER0_SCENE := "res://scenes/story/chapter0.tscn"
const CHAPTERS_DIR := "res://data/story/chapters"

static func player_scene() -> String:
	return PLAYER_SCENE

static func chapter0_scene() -> String:
	return CHAPTER0_SCENE

static func archive_replay_enabled() -> bool:
	return false

static func request_chapter(chapter_id: String) -> String:
	GameState.set_meta("story_chapter_id", chapter_id)
	if chapter_id == "ch0":
		return CHAPTER0_SCENE
	return PLAYER_SCENE

static func mainline_entries() -> Array:
	var out: Array = []
	var dir := DirAccess.open(CHAPTERS_DIR)
	if dir == null:
		return out
	dir.list_dir_begin()
	var name := dir.get_next()
	while name != "":
		if name.ends_with(".json") and not name.begins_with("lint_"):
			var path := CHAPTERS_DIR.path_join(name)
			var data = JSON.parse_string(FileAccess.get_file_as_string(path))
			if typeof(data) == TYPE_DICTIONARY and (data as Dictionary).has("beats"):
				var id := str(data.get("id", name.get_basename()))
				out.append({
					"id": id,
					"title": str(data.get("title", id)),
					"path": path,
					"scene": CHAPTER0_SCENE if id == "ch0" else PLAYER_SCENE,
				})
		name = dir.get_next()
	dir.list_dir_end()
	out.sort_custom(func(a, b): return str(a["id"]) < str(b["id"]))
	return out
