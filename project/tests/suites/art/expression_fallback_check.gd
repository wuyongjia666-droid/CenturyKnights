extends Node
## ART-06: ingested expression plates win; missing plates fall back to the base portrait.

func _ready() -> void:
	var err := _run()
	if err != "":
		print("FAIL expression: ", err)
		get_tree().quit(1)
	get_tree().quit(0)

func _repo() -> String:
	return ProjectSettings.globalize_path("res://").path_join("..")

func _shipped(logical_png: String, webp_name: String) -> String:
	var shipped := CKArtPaths.resolve(logical_png)
	if not shipped.ends_with(webp_name):
		return "shipped " + shipped
	if not CKArtPaths.exists(shipped):
		return "farm plate missing " + shipped
	return ""

func _same_plate(shown, plate) -> bool:
	if shown == null or plate == null:
		return false
	if shown == plate:
		return true
	var a: Image = shown.get_image()
	var b: Image = plate.get_image()
	if a == null or b == null:
		return false
	return a.get_width() == b.get_width() and a.get_height() == b.get_height() and a.get_data() == b.get_data()

func _run() -> String:
	var cast_file := FileAccess.get_file_as_string("res://data/cast/companions_v92.json")
	var cast = JSON.parse_string(cast_file)
	var people: Array = cast.get("companions", [])
	if people.size() != 12:
		return "cast %d" % people.size()
	if UnitArt.companion_slot(str(people[0].get("name", ""))) != "c01":
		return "first slot"
	if UnitArt.companion_slot(str(people[11].get("name", ""))) != "c12":
		return "last slot"
	if UnitArt.companion_slot(str(people[0].get("cast_key", ""))) != "c01":
		return "cast key"
	if UnitArt.expression_key("惊") != "surprise" or UnitArt.expression_key("喜") != "joy":
		return "emotion key"
	var path := UnitArt.expression_plate_path("c01", "惊")
	if not path.ends_with("v92_expr_c01_surprise.png"):
		return "path " + path
	var shipped := _shipped(path, "v92_expr_c01_surprise.webp")
	if shipped != "":
		return shipped
	var anger := UnitArt.expression_plate_path("c01", "怒")
	if not anger.ends_with("v92_expr_c01_anger.png"):
		return "anger path " + anger
	var anger_shipped := _shipped(anger, "v92_expr_c01_anger.webp")
	if anger_shipped != "":
		return anger_shipped
	GameState.new_game("烬行", "灰旗", GameState.crest_color)
	var leader = GameState.get_leader()
	if leader == null:
		return "no leader"
	var base := UnitArt.portrait(leader, 120, CKArtPaths.TIER_MEDIUM)
	var plate := CKArtPaths.load_portrait(path, CKArtPaths.TIER_MEDIUM)
	if not (plate is Texture2D):
		return "plate load"
	# D-02: c01 (灯影) uses her token face until the expression reshoot lands; plate wiring is
	# checked on c02 with the same files below.
	if UnitArt.dialogue_portrait(str(people[0].get("name", "")), "惊", leader, 120) != base:
		return "c01 did not fall back to the token face"
	path = UnitArt.expression_plate_path("c02", "惊")
	anger = UnitArt.expression_plate_path("c02", "怒")
	plate = CKArtPaths.load_portrait(path, CKArtPaths.TIER_MEDIUM)
	if not (plate is Texture2D):
		return "c02 plate load"
	var shown := UnitArt.dialogue_portrait(str(people[1].get("name", "")), "惊", leader, 120)
	if not _same_plate(shown, plate):
		return "ingested plate not used"
	var anger_plate := CKArtPaths.load_portrait(anger, CKArtPaths.TIER_MEDIUM)
	if not (anger_plate is Texture2D):
		return "anger plate load"
	var shown_anger := UnitArt.dialogue_portrait(str(people[1].get("name", "")), "怒", leader, 120)
	if not _same_plate(shown_anger, anger_plate):
		return "anger plate not used"
	var fallback := UnitArt.dialogue_portrait("not-a-companion", "怒", leader, 120)
	if fallback == null or fallback != base:
		return "missing plate did not use the base portrait"
	var queue_text := FileAccess.get_file_as_string(_repo().path_join("tools/farm_queue/v92_expressions.json"))
	var queue = JSON.parse_string(queue_text)
	var jobs: Array = queue.get("jobs", [])
	if jobs.size() != 60:
		return "jobs %d" % jobs.size()
	var seeds := {}
	for row in jobs:
		var slot := str(row.get("companion_slot", ""))
		if not seeds.has(slot):
			seeds[slot] = int(row.get("seed", 0))
		elif int(row.get("seed", 0)) != int(seeds[slot]):
			return "seed split " + slot
		if str(row.get("emotion", "")) == "resolve":
			return "old emotion"
	if seeds.size() != 12:
		return "slots %d" % seeds.size()
	var out: Array = []
	var code := OS.execute("python3", [_repo().path_join("tools/farm_queue/validate_queue_v92.py")], out, true)
	var text := " ".join(out)
	if code != 0 or text.find("QUEUE PASS") < 0:
		return "validator %d %s" % [code, text.left(180)]
	print("EXPRESSION FALLBACK PASS companions=12 emotions=5 jobs=60")
	return ""
