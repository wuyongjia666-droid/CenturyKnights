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

## Side screens opened by chapter "visit" reopen the SAME chapter once.
## Prefer story_return_chapter (owned reopen via request_chapter) over a bare scene path.
## Chapter JSON return_scene is the END-of-chapter hub land — never used for mid-visit.
static func take_story_return(fallback: String) -> String:
	var chapter_id := ""
	if GameState.has_meta("story_return_chapter"):
		chapter_id = str(GameState.get_meta("story_return_chapter", ""))
		GameState.set_meta("story_return_chapter", "")
	var scene_ret := ""
	if GameState.has_meta("story_return"):
		scene_ret = str(GameState.get_meta("story_return", ""))
		GameState.set_meta("story_return", "")
	if chapter_id != "":
		return request_chapter(chapter_id)
	if scene_ret != "":
		return scene_ret
	return fallback

static func archive_replay_enabled() -> bool:
	return false

## Content-season chapters (csNN_MM) live beside volume JSON but are not
## CKStoryState / hub mainline progression — they open via hub ContentSeasonRow
## (StoryCatalog.content_season_entries), never via EmptyHost CTA.
const SEASONS_INDEX := "res://data/content_seasons/index.json"
const SEASONS_DIR := "res://data/content_seasons"

static func is_content_season_id(chapter_id: String) -> bool:
	return chapter_id.begins_with("cs")

## Playable content-season chapters for the castle hub entry. Empty when none
## are playable — callers must skip the row (no EmptyHost / empty CTA).
static func content_season_entries() -> Array:
	var out: Array = []
	if not FileAccess.file_exists(SEASONS_INDEX):
		return out
	var idx = JSON.parse_string(FileAccess.get_file_as_string(SEASONS_INDEX))
	if typeof(idx) != TYPE_DICTIONARY:
		return out
	for sid in idx.get("seasons", []):
		var season_path := SEASONS_DIR.path_join("%s.json" % str(sid))
		if not FileAccess.file_exists(season_path):
			continue
		var data = JSON.parse_string(FileAccess.get_file_as_string(season_path))
		if typeof(data) != TYPE_DICTIONARY:
			continue
		var status := str(data.get("status", ""))
		if not status.begins_with("playable"):
			continue
		var chapter_ids: Array = []
		var primary := str(data.get("playable_chapter", ""))
		if primary != "" and is_content_season_id(primary):
			chapter_ids.append(primary)
		var more = data.get("playable_chapters", [])
		if typeof(more) == TYPE_ARRAY:
			for mid in more:
				var extra := str(mid)
				if extra == "" or not is_content_season_id(extra):
					continue
				if chapter_ids.has(extra):
					continue
				chapter_ids.append(extra)
		if chapter_ids.is_empty():
			continue
		for chapter_id in chapter_ids:
			var chapter_path := CHAPTERS_DIR.path_join("%s.json" % str(chapter_id))
			if not FileAccess.file_exists(chapter_path):
				continue
			var ch_title := str(data.get("title_zh", chapter_id))
			var ch_title_en := str(data.get("title_en", chapter_id))
			# Secondary chapters prefer their own JSON title / title_en.
			if str(chapter_id) != primary:
				var ch_data = JSON.parse_string(FileAccess.get_file_as_string(chapter_path))
				if typeof(ch_data) == TYPE_DICTIONARY:
					var own := str(ch_data.get("title", ""))
					var own_en := str(ch_data.get("title_en", ""))
					if own != "":
						ch_title = own
					if own_en != "":
						ch_title_en = own_en
			out.append({
				"season_id": str(data.get("id", sid)),
				"title": ch_title,
				"title_en": ch_title_en,
				"chapter_id": str(chapter_id),
				"path": chapter_path,
				"scene": PLAYER_SCENE,
			})
	return out

## Hub chips: zh title by default; English shell uses title_en (l10n gate).
static func content_season_label(entry: Dictionary) -> String:
	if Locale != null and str(Locale.lang).begins_with("en"):
		var en := str(entry.get("title_en", ""))
		if en != "":
			return en
	return str(entry.get("title", entry.get("chapter_id", "")))

## JSON path of a chapter id ("e1_01" lives in era1_01.json). "" when the id is unknown.
static func path_for(chapter_id: String) -> String:
	if chapter_id == "":
		return ""
	for row in mainline_entries():
		if str(row.get("id", "")) == chapter_id:
			return str(row.get("path", ""))
	return ""

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
