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
	if not ResourceLoader.exists(path):
		return "farm plate missing " + path
	var missing := UnitArt.expression_plate_path("c01", "怒")
	if not missing.ends_with("v92_expr_c01_anger.png"):
		return "missing path " + missing
	if ResourceLoader.exists(missing):
		return "anger plate unexpectedly present"
	GameState.new_game("烬行", "灰旗", GameState.crest_color)
	var leader = GameState.get_leader()
	if leader == null:
		return "no leader"
	var base := UnitArt.portrait(leader, 120)
	var plate = load(path)
	if not (plate is Texture2D):
		return "plate load"
	var shown := UnitArt.dialogue_portrait(str(people[0].get("name", "")), "惊", leader, 120)
	if shown == null or shown != plate:
		return "ingested plate not used"
	var fallback := UnitArt.dialogue_portrait(str(people[0].get("name", "")), "怒", leader, 120)
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
