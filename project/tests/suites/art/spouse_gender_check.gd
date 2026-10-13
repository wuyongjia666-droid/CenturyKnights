extends Node
## P0 playtest: a male captain's marriage candidates are women (and the reverse), face plates included.

func _ready() -> void:
	var err := _run()
	if err != "":
		print("FAIL spouse gender: ", err)
		get_tree().quit(1)
	else:
		print("SPOUSE GENDER PASS")
		get_tree().quit(0)

func _run() -> String:
	for g in ["m", "f"]:
		GameState.new_game("烬行", "灰旗", GameState.crest_color)
		GameState.get_leader().gender = g
		var want := "f" if g == "m" else "m"
		for k in 4:
			GameState.refresh_marriage_candidates()
			for c in GameState.marriage_candidates:
				if str(c.gender) != want:
					return "captain %s got candidate %s gender %s" % [g, c.name, c.gender]
	var keys: Array = (JSON.parse_string(FileAccess.get_file_as_string(CKPortraitBank.SEX_INDEX)).get("sex", {}) as Dictionary).keys()
	var f := 0
	for key in keys:
		if CKPortraitBank.plate_sex(str(key)) == "f":
			f += 1
	if keys.size() < 100 or f < 5:
		return "bank sex labels thin: %d/%d" % [f, keys.size()]
	for s in ["m", "f"]:
		for key in CKPortraitBank._same_sex(keys, s):
			if CKPortraitBank.plate_sex(str(key)) != s:
				return "bank filter let %s through for %s" % [key, s]
	return ""
