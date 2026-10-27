extends Node
## Mobile twin: ContestStake + EchoLine_contest under CK_FORCE_MOBILE.

const ATLAS_SCN := preload("res://scenes/hub/atlas_view.tscn")
const SITE := "t_ash_cinderpit"
const MARKER := "MOBILE TERRITORY CONTEST STAKE CLAIM PASS"

func _ready() -> void:
	OS.set_environment("CK_FORCE_MOBILE", "1")
	var err := await _run()
	OS.set_environment("CK_FORCE_MOBILE", "")
	if err != "":
		print("FAIL mobile territory contest stake claim: ", err)
		get_tree().quit(1)
	else:
		print(MARKER)
		get_tree().quit(0)


func _run() -> String:
	await get_tree().process_frame
	GameState.new_game("拉锯加码机", "灰旗", GameState.crest_color)
	GameState.chapter0_flags["chapter0_done"] = true
	GameState.chapter0_flags["ch0_playing"] = false
	UnlockSchedule.install()
	World.events_enabled = false
	World.rivals_enabled = true
	World.rivals = [
		{"id": "rv_a", "name": "灰烬狼团", "pos": "ash_capital", "home": "ash_capital", "stolen": {}, "price_mul": 1.0},
		{"id": "rv_b", "name": "盐湾镖旗", "pos": "ash_capital", "home": "ash_capital", "stolen": {}, "price_mul": 1.0},
	]
	for nid in World.nations.keys():
		World.rep_nation[str(nid)] = 50
	GameState.silver = 9000
	GameState.food = 40
	GameState.house_mods.erase("month_echo")
	World.last_neutral_contest = {}
	var st: Dictionary = CKTerritory.state(SITE)
	st.owner = CKTerritory.NEUTRAL
	st.garrison = 0
	st.stockade = false
	st.unrest = 0
	st.threat = {}
	st.contest = {}
	CKTerritory._put(SITE, st)
	CKTerritory.start_neutral_contest(SITE, [
		{"id": "rival:rv_a", "name": "灰烬狼团", "pressure": 3},
		{"id": "rival:rv_b", "name": "盐湾镖旗", "pressure": 2},
	])
	var atlas: Control = ATLAS_SCN.instantiate()
	get_tree().root.add_child(atlas)
	for _i in 10:
		await get_tree().process_frame
	if atlas.find_child("ContestTugModal", true, false) == null and atlas.has_method("_check_neutral_contest"):
		atlas.call("_check_neutral_contest")
		for _j in 8:
			await get_tree().process_frame
	var panel := atlas.find_child("ContestTugModal", true, false) as Control
	if panel == null:
		atlas.queue_free()
		return "ContestTugModal missing"
	var btn := panel.find_child("ContestStake", true, false) as Button
	if btn == null or btn.disabled:
		atlas.queue_free()
		return "ContestStake missing/disabled"
	btn.pressed.emit()
	for _k in 10:
		await get_tree().process_frame
	if str(CKEconomyState.month_echo_snapshot().get("contest", "")) == "":
		atlas.queue_free()
		return "missing month_echo.contest"
	panel = atlas.find_child("ContestTugModal", true, false) as Control
	if panel == null:
		atlas.queue_free()
		return "modal closed after stake"
	var el := panel.find_child("EchoLine_contest", true, false) as Label
	if el == null or el.text == "":
		atlas.queue_free()
		return "EchoLine_contest missing"
	# Resolve claim
	var resolved: Array = CKTerritory.tick_neutral_contests(true)
	if resolved.is_empty() or str(resolved[0].get("winner", "")) != "company":
		atlas.queue_free()
		return "mobile resolve want company"
	if not CKTerritory.owned(SITE):
		atlas.queue_free()
		return "mobile site not owned"
	print("mobile stake→claim ok")
	atlas.queue_free()
	await get_tree().process_frame
	return ""
