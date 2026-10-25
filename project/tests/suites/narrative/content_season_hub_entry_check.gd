extends Node
## 内容季枢纽入口：三季可玩章挂进 ContentSeasonRow（非 EmptyHost / 非空态 CTA）；
## 主线梯子仍跳过 cs*；开章走 StoryCatalog.request_chapter。

const Todo := preload("res://scripts/ui/widgets/todo_center.gd")
const EXPECTED := ["cs01_01", "cs02_01", "cs03_01"]

var _fails: Array = []

func _ready() -> void:
	await get_tree().process_frame
	Todo.reset_for_tests()
	_catalog()
	_mainline_skips()
	_source_no_empty_host()
	await _hub_row()
	if _fails.is_empty():
		print("CONTENT SEASON HUB ENTRY PASS")
		get_tree().quit(0)
	else:
		for f in _fails:
			print("FAIL content_season_hub_entry: ", f)
		get_tree().quit(1)


func _ok(cond: bool, msg: String) -> void:
	if not cond:
		_fails.append(msg)


func _catalog() -> void:
	var rows: Array = StoryCatalog.content_season_entries()
	_ok(rows.size() == EXPECTED.size(), "entries size %d" % rows.size())
	var seen := {}
	for row in rows:
		var cid := str(row.get("chapter_id", ""))
		seen[cid] = true
		_ok(StoryCatalog.is_content_season_id(cid), "not cs id %s" % cid)
		_ok(FileAccess.file_exists(str(row.get("path", ""))), "missing path %s" % cid)
		_ok(str(row.get("title", "")) != "", "empty title %s" % cid)
		_ok(str(row.get("scene", "")) == StoryCatalog.player_scene(), "scene %s" % cid)
	for cid in EXPECTED:
		_ok(bool(seen.get(cid, false)), "missing %s" % cid)


func _mainline_skips() -> void:
	for row in Todo.mainline_rows():
		_ok(not StoryCatalog.is_content_season_id(str(row.get("id", ""))), "mainline leaked %s" % str(row.get("id", "")))


func _source_no_empty_host() -> void:
	var src := FileAccess.get_file_as_string("res://scripts/hub/castle_hub.gd")
	_ok(src.find("ContentSeasonRow") >= 0, "hub missing ContentSeasonRow")
	_ok(src.find("content_season_entries") >= 0, "hub ignores catalog")
	_ok(src.find("_open_content_season") >= 0, "hub missing open helper")
	# Content-season helpers must not spawn EmptyHost when the list is empty.
	var block_start := src.find("func _add_content_season_row_desk")
	var block_end := src.find("## Lock sheet", block_start)
	_ok(block_start >= 0 and block_end > block_start, "season helpers missing")
	if block_start >= 0 and block_end > block_start:
		var block := src.substr(block_start, block_end - block_start)
		# Ban constructing EmptyHost nodes; comments naming the ban are OK.
		_ok(block.find('name = "EmptyHost"') < 0 and block.find("EmptyHost.new") < 0, "EmptyHost node in season helpers")
		_ok(block.find("is_empty()") >= 0, "season helpers never skip empty")


func _hub_row() -> void:
	GameState.new_game("烬行", "灰旗", GameState.crest_color)
	var packed: PackedScene = load("res://scenes/hub/castle_hub.tscn")
	_ok(packed != null, "castle_hub missing")
	if packed == null:
		return
	var hub = packed.instantiate()
	add_child(hub)
	await get_tree().process_frame
	await get_tree().process_frame
	var row := hub.find_child("ContentSeasonRow", true, false)
	_ok(row != null, "ContentSeasonRow missing")
	if row == null:
		hub.queue_free()
		await get_tree().process_frame
		return
	for cid in EXPECTED:
		var chip := hub.find_child("Season_%s" % cid, true, false) as BaseButton
		_ok(chip != null, "chip %s missing" % cid)
	_ok(hub.has_method("_open_content_season"), "open helper missing at runtime")
	# Arm chapter meta the same way the chip does (without CKNav.replace in suite).
	_ok(StoryCatalog.request_chapter("cs01_01") == StoryCatalog.player_scene(), "player for cs01")
	_ok(str(GameState.get_meta("story_chapter_id", "")) == "cs01_01", "meta cs01")
	_ok(StoryCatalog.request_chapter("cs03_01") == StoryCatalog.player_scene(), "player for cs03")
	_ok(str(GameState.get_meta("story_chapter_id", "")) == "cs03_01", "meta cs03")
	hub.queue_free()
	await get_tree().process_frame
