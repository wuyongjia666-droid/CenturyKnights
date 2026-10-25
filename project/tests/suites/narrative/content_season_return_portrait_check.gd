extends Node
## 内容季 E2E 硬化：cs01..cs10 return_scene→hub；走完 ledger 回城堡；
## 季章具名说话人（掌柜/岁吏/书记官）出真实 plate（#436 路径对齐后）。

const Schema = preload("res://scripts/narrative/chapter_schema.gd")
const LintScript = preload("res://scripts/narrative/dialogue_lint.gd")
const PLAYER := "res://scenes/story/chapter_player.tscn"
const HUB := "res://scenes/hub/castle_hub.tscn"
const CHAPTERS := [
	"cs01_01", "cs02_01", "cs03_01", "cs04_01", "cs05_01",
	"cs06_01", "cs07_01", "cs08_01", "cs09_01", "cs10_01",
]
## Choice label → expected flag (first option on tavern beat).
const CHOICE := {
	"cs01_01": ["把无写进谱", "cs01_wrote_wu"],
	"cs02_01": ["两行并排留", "cs02_kept_parallel"],
	"cs03_01": ["功与粮并排", "cs03_kept_parallel"],
	"cs04_01": ["训与行并排", "cs04_kept_parallel"],
	"cs05_01": ["空椅并排链", "cs05_kept_chain"],
	"cs06_01": ["校场并排记", "cs06_kept_yard"],
	"cs07_01": ["仪典并排记", "cs07_kept_rite"],
	"cs08_01": ["祖祠并排记", "cs08_kept_stele"],
	"cs09_01": ["血验并排记", "cs09_kept_blood"],
	"cs10_01": ["城印并排记", "cs10_kept_seal"],
}
const PLATE_SPEAKERS := ["掌柜", "岁吏", "书记官", "老旗手", "老管事"]

func _ready() -> void:
	var err := await _run()
	if err != "":
		print("FAIL content_season_return_portrait: ", err)
		get_tree().quit(1)
		return
	print("CONTENT SEASON RETURN PORTRAIT PASS")
	get_tree().quit(0)


func _run() -> String:
	for cid in CHAPTERS:
		var err := _static_chapter(cid)
		if err != "":
			return err
	# Deep walk: every season chapter return + portrait smoke (not sample-only).
	for cid in CHAPTERS:
		var err2 := await _walk_return_and_portraits(cid)
		if err2 != "":
			return err2
	# UnitArt smoke for every season speaker plate path (no silhouette).
	var err3 := _speaker_plates()
	if err3 != "":
		return err3
	return ""


func _static_chapter(cid: String) -> String:
	var path := "res://data/story/chapters/%s.json" % cid
	if not FileAccess.file_exists(path):
		return "missing " + path
	var schema := Schema.validate_file(path)
	if not schema.is_empty():
		return "%s schema %s" % [cid, str(schema[0])]
	var data = JSON.parse_string(FileAccess.get_file_as_string(path))
	if typeof(data) != TYPE_DICTIONARY:
		return "%s not dict" % cid
	if str(data.get("return_scene", "")) != HUB:
		return "%s return_scene want hub got %s" % [cid, data.get("return_scene")]
	var lines := 0
	for beat in data.get("beats", []):
		lines += (beat.get("lines", []) as Array).size()
	if lines < 30:
		return "%s too few lines %d" % [cid, lines]
	return ""


func _speaker_plates() -> String:
	for sp in PLATE_SPEAKERS:
		var tex: Texture2D = UnitArt.dialogue_portrait(sp, "", null, 120)
		if tex == null:
			return "dialogue_portrait(%s) null" % sp
		if tex.get_width() < 32 or tex.get_height() < 32:
			return "dialogue_portrait(%s) tiny %dx%d" % [sp, tex.get_width(), tex.get_height()]
		print("OK plate %s %dx%d" % [sp, tex.get_width(), tex.get_height()])
	# Companion name used across seasons — slot resolve must not silhouette.
	var deng: Texture2D = UnitArt.dialogue_portrait("苇原·灯影", "", null, 120)
	if deng == null:
		return "dialogue_portrait(苇原·灯影) null"
	print("OK plate 苇原·灯影 %dx%d" % [deng.get_width(), deng.get_height()])
	return ""


func _walk_return_and_portraits(cid: String) -> String:
	var path := "res://data/story/chapters/%s.json" % cid
	var choice: Array = CHOICE[cid]
	GameState.new_game("烬行", "灰旗", GameState.crest_color)
	var packed: PackedScene = load(PLAYER)
	if packed == null:
		return "player missing"
	var player = packed.instantiate()
	player.chapter_path = path
	player.lock_path = true
	player.suppress_scene_change = true
	add_child(player)
	await get_tree().process_frame
	await get_tree().process_frame
	var saw_plate := false
	var steps := 0
	while steps < 80:
		player.simulate_finish_dialogue()
		await get_tree().process_frame
		await get_tree().process_frame
		var kind := str(player.test_capture.get("portrait_kind", ""))
		if kind == "plate" and player.get("_portrait") != null and player.get("_portrait").texture != null:
			saw_plate = true
		var labels: Array = player.action_labels()
		if labels.find(str(choice[0])) >= 0:
			break
		var advanced := false
		for needle in ["继续", "继续 ▶"]:
			if player.simulate_press_action_containing(needle):
				advanced = true
				break
		if not advanced:
			player.queue_free()
			return "%s stuck before choice beat=%s labels=%s" % [cid, player.current_beat_id(), str(labels)]
		steps += 1
		await get_tree().process_frame
	if not saw_plate:
		player.queue_free()
		return "%s never showed plate portrait during walk" % cid
	if not player.simulate_press_action_containing(str(choice[0])):
		player.queue_free()
		return "%s could not press %s" % [cid, choice[0]]
	await get_tree().process_frame
	await get_tree().process_frame
	if not GameState.flag(str(choice[1])):
		player.queue_free()
		return "%s flag %s not set" % [cid, choice[1]]
	if player.current_beat_id() != "ledger":
		player.queue_free()
		return "%s expected ledger got %s" % [cid, player.current_beat_id()]
	player.simulate_finish_dialogue()
	await get_tree().process_frame
	await get_tree().process_frame
	if not player.simulate_press_action_containing("灰旗堡"):
		player.queue_free()
		return "%s hub return missing labels=%s" % [cid, str(player.action_labels())]
	await get_tree().process_frame
	var scene := str(player.test_capture.get("scene", ""))
	if scene != HUB:
		player.queue_free()
		return "%s return scene want hub got %s" % [cid, scene]
	print("OK walk %s plate+return hub" % cid)
	player.queue_free()
	await get_tree().process_frame
	return ""
