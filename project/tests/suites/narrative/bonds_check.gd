extends Node
## NAR-04：四十段支援有阶、对白守则干净、相邻作战会升阶。

const LintScript := preload("res://scripts/narrative/dialogue_lint.gd")
const VIEWER := "res://scenes/story/support_viewer.tscn"
const CAST := "res://data/cast/companions_v92.json"

func _ready() -> void:
	var err := await _run()
	if err != "":
		print("FAIL bonds: ", err)
		get_tree().quit(1)
	else:
		print("BONDS PASS")
		get_tree().quit(0)

func _run() -> String:
	var rows: Array = Bonds.conversations()
	if rows.size() != 40:
		return "count %d" % rows.size()
	var ranks := {"C": 0, "B": 0, "A": 0}
	var people := {}
	for row in rows:
		var rank_id := str(row.get("rank", ""))
		if not ranks.has(rank_id):
			return "rank %s" % rank_id
		ranks[rank_id] = int(ranks[rank_id]) + 1
		people[str(row.get("a", ""))] = true
		people[str(row.get("b", ""))] = true
		if typeof(row.get("lines", null)) != TYPE_ARRAY or row.get("lines", []).is_empty():
			return "empty " + str(row.get("id", ""))
	var cast = JSON.parse_string(FileAccess.get_file_as_string(CAST))
	var companions: Array = cast.get("companions", [])
	if companions.size() < 12:
		return "cast %d" % companions.size()
	var covered := 0
	for person in companions:
		if people.has(str(person.get("id", ""))):
			covered += 1
	if covered < 12:
		return "covered %d" % covered
	var lint = LintScript.new()
	var loaded := lint.load_rules()
	if loaded != "":
		return loaded
	var report: Dictionary = lint.scan_dir("res://data/story/supports")
	var violations: Array = report.get("violations", [])
	if not violations.is_empty():
		return "lint %s" % str(violations[0])
	GameState.new_game("烬行", "灰旗", GameState.crest_color)
	if Bonds.rank("dengying", "zhegan") != "":
		return "rank before fights"
	Bonds.note_adjacent("dengying", "zhegan")
	if Bonds.rank("weiyuan_dengying", "baiyuan_zhegan") != "":
		return "one fight ranked"
	Bonds.note_adjacent("苇原·灯影", "白垣·折杆")
	if Bonds.rank("dengying", "zhegan") != "C":
		return "C got %s" % Bonds.rank("dengying", "zhegan")
	Bonds.note_event("dengying", "zhegan", 3)
	if Bonds.rank("dengying", "zhegan") != "B":
		return "B got %s points %d" % [Bonds.rank("dengying", "zhegan"), Bonds.points("dengying", "zhegan")]
	Bonds.note_event("dengying", "zhegan", 4)
	if Bonds.rank("dengying", "zhegan") != "A":
		return "A got %s" % Bonds.rank("dengying", "zhegan")
	var battle_err := _battle_pairs()
	if battle_err != "":
		return battle_err
	var view_err := await _viewer()
	if view_err != "":
		return view_err
	print("OK supports=40 C=%d B=%d A=%d" % [ranks["C"], ranks["B"], ranks["A"]])
	return ""

func _battle_pairs() -> String:
	GameState.new_game("烬行", "灰旗", GameState.crest_color)
	var near := _unit("xiaoxian", Vector2i(1, 1))
	var beside := _unit("pingshao", Vector2i(2, 1))
	var far := _unit("chenban", Vector2i(6, 4))
	var foe := _unit("yuguang", Vector2i(1, 2))
	foe["team"] = "enemy"
	var same := _unit("zhensheng", Vector2i(1, 1))
	var added: int = Bonds.note_battle([near, beside, far, foe, same])
	if added != 2:
		return "adjacent pairs %d" % added
	if Bonds.rank("xiaoxian", "pingshao") != "":
		return "one battle ranked early"
	Bonds.note_battle([near, beside])
	if Bonds.rank("影针·小弦", "渔火·平梢") != "C":
		return "battle rank %s" % Bonds.rank("xiaoxian", "pingshao")
	if Bonds.points("xiaoxian", "chenban") != 0:
		return "far pair scored"
	if Bonds.points("xiaoxian", "yuguang") != 0:
		return "enemy scored"
	return ""

func _unit(key: String, pos: Vector2i) -> Dictionary:
	var who := CKCharacter.new()
	who.cast_key = key
	who.hp = 10
	who.alive = true
	return {"char": who, "pos": pos, "team": "player"}

func _viewer() -> String:
	var packed: PackedScene = load(VIEWER)
	var viewer = packed.instantiate()
	viewer.suppress_scene_change = true
	add_child(viewer)
	await get_tree().process_frame
	await get_tree().process_frame
	if viewer.titles().is_empty():
		return "viewer listed nothing at C"
	if not viewer.open_containing("带信"):
		return "missing C title %s" % str(viewer.titles())
	if viewer.current_text() == "":
		return "empty line"
	for _i in 8:
		viewer.press_continue()
	if not GameState.flag("bond_seen:xiaoxian_pingshao_c"):
		return "seen flag missing"
	viewer.queue_free()
	return ""
