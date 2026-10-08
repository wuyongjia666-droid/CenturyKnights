extends Node

const BANNED := ["勇士节", "亡人节"]

func _ready() -> void:
	var err := _run()
	if err != "":
		print("FAIL festival: ", err)
		get_tree().quit(1)
	else:
		print("FESTIVAL PASS")
		get_tree().quit(0)

func _run() -> String:
	var names := _names()
	if CKFestivals.rows().size() != 5:
		return "count %d" % CKFestivals.rows().size()
	var lint := _lint(names)
	if lint != "":
		return lint
	GameState.new_game("烬行", "灰旗", GameState.crest_color)
	CKFestivals.reset_counts()
	CKFestivals.install()
	Calendar.reset()
	Calendar.advance(12)
	for id in ["spring", "harvest", "barter", "tourney", "memorial"]:
		if int(CKFestivals.fired.get(id, 0)) != 1:
			return "%s fired %s" % [id, str(CKFestivals.fired)]
	GameState.food = 20
	GameState.silver = 10
	var barter: Dictionary = CKFestivals.play(GameState, "barter")
	if not bool(barter.get("ok", false)) or GameState.food != 12 or GameState.silver != 16:
		return "barter %s" % str(barter)
	var before := int(GameState.reputation.get("ashland", 0))
	var tourney: Dictionary = CKFestivals.play(GameState, "tourney")
	if bool(tourney.get("battle", true)) or str(tourney.get("waiting", "")) != "BTL-11":
		return "tourney launched a battle"
	if int(GameState.reputation.get("ashland", 0)) != before + 2:
		return "tourney rep"
	GameState.house_mods["wound_months"] = 2
	var memorial: Dictionary = CKFestivals.play(GameState, "memorial")
	if int(memorial.get("wound_months", -1)) != 1:
		return "memorial"
	return ""

func _names() -> PackedStringArray:
	var out: PackedStringArray = []
	for row in CKFestivals.rows():
		out.append(Locale.t(str(row.get("name_key", ""))))
		out.append(Locale.t(str(row.get("blurb_key", ""))))
	return out

func _lint(lines: PackedStringArray) -> String:
	var proj := ProjectSettings.globalize_path("res://")
	if proj.ends_with("/"):
		proj = proj.substr(0, proj.length() - 1)
	var lock := FileAccess.get_file_as_string(proj.get_base_dir().path_join("docs/art/style-lock-v89.json"))
	var parsed = JSON.parse_string(lock)
	var forbid: Array = []
	if typeof(parsed) == TYPE_DICTIONARY:
		forbid = parsed.get("anti_trope", {}).get("forbid_in_positive", [])
	for line in lines:
		for banned in BANNED:
			if line.find(banned) >= 0:
				return "banned name " + banned
		var low := line.to_lower()
		for word in forbid:
			var w := str(word).to_lower()
			if w != "" and low.find(w) >= 0:
				return "anti-trope %s in %s" % [w, line]
	return ""
