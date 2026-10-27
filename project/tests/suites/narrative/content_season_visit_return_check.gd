extends Node
## Mid-chapter visit must reopen the same content season at the saved beat.
## Root cause: visit stamped story_return = return_scene (hub after #437).
## Fix: own story_return_chapter + player scene; take_story_return → request_chapter.

const PLAYER := "res://scenes/story/chapter_player.tscn"
const HUB := "res://scenes/hub/castle_hub.tscn"
const CH0 := "res://data/story/chapters/ch0.json"
const RET0 := "res://scenes/story/chapter0.tscn"
const SIDES := [
	"res://scenes/hub/hourglass.tscn",
	"res://scenes/hub/quests.tscn",
	"res://scenes/hub/atlas_view.tscn",
]
## One mid beat per season (visit-owning beat when present; else a mid story beat).
## LIVE covers all ten so a hub-return regression cannot hide in an untested season.
const CASES := [
	{"cid": "cs01_01", "mid": "audit"},
	{"cid": "cs01_02", "mid": "hourglass"},
	{"cid": "cs02_01", "mid": "birth"},
	{"cid": "cs02_02", "mid": "hourglass"},
	{"cid": "cs03_01", "mid": "hourglass"},
	{"cid": "cs03_02", "mid": "hourglass"},
	{"cid": "cs03_03", "mid": "hourglass"},
	{"cid": "cs04_01", "mid": "hourglass"},
	{"cid": "cs04_02", "mid": "hourglass"},
	{"cid": "cs04_03", "mid": "hourglass"},

	{"cid": "cs05_01", "mid": "hourglass"},
	{"cid": "cs05_02", "mid": "hourglass"},
	{"cid": "cs05_03", "mid": "hourglass"},
	{"cid": "cs06_03", "mid": "hourglass"},
	{"cid": "cs06_01", "mid": "hourglass"},
	{"cid": "cs06_02", "mid": "hourglass"},
	{"cid": "cs07_01", "mid": "hourglass"},
	{"cid": "cs07_02", "mid": "hourglass"},
	{"cid": "cs08_01", "mid": "hourglass"},
	{"cid": "cs08_02", "mid": "hourglass"},
	{"cid": "cs09_01", "mid": "hourglass"},
	{"cid": "cs09_02", "mid": "hourglass"},
	{"cid": "cs10_01", "mid": "hourglass"},
	{"cid": "cs10_02", "mid": "hourglass"},
]


func _ready() -> void:
	var err := await _run()
	if err != "":
		print("FAIL content_season_visit_return: ", err)
		get_tree().quit(1)
		return
	print("CONTENT SEASON VISIT RETURN PASS")
	get_tree().quit(0)


func _run() -> String:
	var err := _source_gate()
	if err != "":
		return err
	err = await _ch0_visit_still_chapter0()
	if err != "":
		return err
	for row in CASES:
		err = await _mid_visit_roundtrip(str(row["cid"]), str(row["mid"]))
		if err != "":
			return err
	return ""


func _source_gate() -> String:
	var src := FileAccess.get_file_as_string("res://scripts/story/chapter_player.gd")
	if src.find("story_return_chapter") < 0:
		return "chapter_player missing story_return_chapter"
	# visit must not stamp return_scene into story_return (hub land leak).
	var visit_at := src.find('"visit":')
	if visit_at < 0:
		return "visit op missing"
	var visit_block := src.substr(visit_at, 640)
	if visit_block.find('set_meta("story_return", str(_chapter.get("return_scene"') >= 0:
		return "visit still stamps return_scene into story_return"
	if visit_block.find("story_return_chapter") < 0:
		return "visit does not stamp story_return_chapter"
	var cat := FileAccess.get_file_as_string("res://scripts/narrative/story_catalog.gd")
	if cat.find("story_return_chapter") < 0:
		return "take_story_return ignores story_return_chapter"
	if cat.find("request_chapter(chapter_id)") < 0 and cat.find("return request_chapter(") < 0:
		return "take_story_return does not request_chapter"
	print("OK source gate")
	return ""


func _ch0_visit_still_chapter0() -> String:
	GameState.new_game("烬行", "灰旗", GameState.crest_color)
	var packed: PackedScene = load(PLAYER)
	var player = packed.instantiate()
	player.suppress_scene_change = true
	player.lock_path = true
	player.chapter_path = CH0
	add_child(player)
	await get_tree().process_frame
	await get_tree().process_frame
	player.simulate_goto_beat("0.6")
	await get_tree().process_frame
	player.simulate_visit(SIDES[0])
	await get_tree().process_frame
	var err := ""
	if str(player.test_capture.get("scene", "")) != SIDES[0]:
		err = "ch0 visit scene want hourglass got %s" % str(player.test_capture.get("scene", ""))
	elif str(GameState.get_meta("story_return_chapter", "")) != "ch0":
		err = "ch0 story_return_chapter want ch0 got %s" % str(GameState.get_meta("story_return_chapter", ""))
	elif str(GameState.get_meta("story_return", "")) != RET0:
		err = "ch0 story_return want chapter0 got %s" % str(GameState.get_meta("story_return", ""))
	player.queue_free()
	await get_tree().process_frame
	if err != "":
		return err
	var ret := StoryCatalog.take_story_return("hub")
	if ret != RET0:
		return "ch0 take_story_return want %s got %s" % [RET0, ret]
	if StoryCatalog.take_story_return("hub") != "hub":
		return "ch0 story return not consumed"
	print("OK ch0 visit → chapter0")
	return ""


func _mid_visit_roundtrip(cid: String, mid: String) -> String:
	for side in SIDES:
		var err := await _one_side(cid, mid, side)
		if err != "":
			return err
	print("OK visit roundtrip %s @ %s ×%d sides" % [cid, mid, SIDES.size()])
	return ""


func _one_side(cid: String, mid: String, side: String) -> String:
	GameState.new_game("烬行", "灰旗", GameState.crest_color)
	var scene := StoryCatalog.request_chapter(cid)
	if scene != StoryCatalog.player_scene():
		return "%s request_chapter scene %s" % [cid, scene]
	var packed: PackedScene = load(PLAYER)
	var player = packed.instantiate()
	player.suppress_scene_change = true
	player.lock_path = false
	player.chapter_path = ""
	add_child(player)
	await get_tree().process_frame
	await get_tree().process_frame
	player.simulate_goto_beat(mid)
	await get_tree().process_frame
	var err := ""
	if player.current_beat_id() != mid:
		err = "%s mid want %s got %s" % [cid, mid, player.current_beat_id()]
	elif GameState.story.season_beat(cid) != mid:
		err = "%s cursor not %s before visit" % [cid, mid]
	if err == "":
		player.simulate_visit(side)
		await get_tree().process_frame
		if str(player.test_capture.get("scene", "")) != side:
			err = "%s visit scene want %s got %s" % [cid, side, str(player.test_capture.get("scene", ""))]
		elif str(GameState.get_meta("story_return_chapter", "")) != cid:
			err = "%s story_return_chapter want %s got %s" % [
				cid, cid, str(GameState.get_meta("story_return_chapter", ""))]
		elif str(GameState.get_meta("story_return", "")) != StoryCatalog.player_scene():
			err = "%s story_return must be player not hub (got %s)" % [
				cid, str(GameState.get_meta("story_return", ""))]
	player.queue_free()
	await get_tree().process_frame
	if err != "":
		return err
	# Side-screen _back path: take_story_return owns reopen.
	var ret := StoryCatalog.take_story_return(HUB)
	if ret != StoryCatalog.player_scene():
		return "%s/%s take want player got %s" % [cid, side.get_file(), ret]
	if str(GameState.get_meta("story_chapter_id", "")) != cid:
		return "%s/%s story_chapter_id not restored" % [cid, side.get_file()]
	if GameState.story.season_beat(cid) != mid:
		return "%s/%s season cursor lost after take (got %s)" % [
			cid, side.get_file(), GameState.story.season_beat(cid)]
	if StoryCatalog.take_story_return(HUB) != HUB:
		return "%s/%s take not consumed" % [cid, side.get_file()]
	# Reopen chapter_player the way CKNav.replace(player) would.
	player = packed.instantiate()
	player.suppress_scene_change = true
	player.lock_path = false
	player.chapter_path = ""
	add_child(player)
	await get_tree().process_frame
	await get_tree().process_frame
	if player.current_beat_id() != mid:
		err = "%s/%s reopen want %s got %s" % [cid, side.get_file(), mid, player.current_beat_id()]
	player.queue_free()
	await get_tree().process_frame
	return err
