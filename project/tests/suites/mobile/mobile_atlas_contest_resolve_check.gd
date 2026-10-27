extends Node
## Mobile twin: ContestResolveModal after neutral contest settle.

const ATLAS_SCN := preload("res://scenes/hub/atlas_view.tscn")
const SITE := "t_ash_cinderpit"
const MARKER := "MOBILE ATLAS CONTEST RESOLVE PASS"
const PHONE := Vector2i(2400, 1080)

func _ready() -> void:
	OS.set_environment("CK_FORCE_MOBILE", "1")
	var err := await _run()
	OS.set_environment("CK_FORCE_MOBILE", "")
	if err != "":
		print("FAIL mobile atlas contest resolve: ", err)
		get_tree().quit(1)
	else:
		print(MARKER)
		get_tree().quit(0)

func _run() -> String:
	await get_tree().process_frame
	DisplayServer.window_set_size(PHONE)
	await get_tree().process_frame
	if not DeviceProfile.is_mobile():
		return "DeviceProfile.is_mobile() false — need CK_FORCE_MOBILE=1"
	GameState.new_game("MobileContestResolve", "灰旗", GameState.crest_color)
	GameState.set_flag("chapter0_done", true)
	UnlockSchedule.install()
	World.events_enabled = false
	World.rivals_enabled = true
	World.rivals = [
		{"id": "rv_a", "name": "灰烬狼团", "pos": "ash_capital", "home": "ash_capital", "stolen": {}, "price_mul": 1.0},
		{"id": "rv_b", "name": "盐湾镖旗", "pos": "ash_capital", "home": "ash_capital", "stolen": {}, "price_mul": 1.0},
	]
	for nid in World.nations.keys():
		World.rep_nation[str(nid)] = 50
	GameState.food = 40
	GameState.silver = 600
	GameState.morale = 70
	World.hub_tour.clear()
	World.travel = {}
	World.pending_event = {}
	World.encounter = {}
	World.last_territory_month = {}
	World.last_siege_alert = {}
	World.last_siege_loot = {}
	World.last_neutral_contest = {}
	World.last_contest_resolve = {}
	CKTerritory.last_month_report = {}
	var st: Dictionary = CKTerritory.state(SITE)
	st.owner = CKTerritory.NEUTRAL
	st.garrison = 0
	st.unrest = 0
	st.threat = {}
	st.contest = {}
	st.stockade = false
	st.cache_food = 0
	CKTerritory._put(SITE, st)
	CKTerritory.start_neutral_contest(SITE, [
		{"id": "rival:rv_a", "name": "灰烬狼团", "pressure": 3},
		{"id": "rival:rv_b", "name": "盐湾镖旗", "pressure": 2},
	])
	CKTerritory.tick_neutral_contests(true)
	if World.last_contest_resolve.is_empty():
		return "expected last_contest_resolve after rival settle"
	if str(World.last_contest_resolve.get("outcome", "")) != "lost":
		return "expected outcome lost got %s" % World.last_contest_resolve.get("outcome", "")
	World.last_territory_month = {}
	World.last_siege_alert = {}
	World.last_siege_loot = {}
	World.last_neutral_contest = {}
	var atlas: Node = ATLAS_SCN.instantiate()
	add_child(atlas)
	await get_tree().process_frame
	await get_tree().process_frame
	if atlas.has_method("_check_contest_resolve"):
		atlas.call("_check_contest_resolve")
	await get_tree().process_frame
	var panel = atlas.find_child("ContestResolveModal", true, false)
	if panel == null:
		atlas.queue_free()
		return "ContestResolveModal missing on mobile"
	var ok_btn = panel.get_node_or_null("ContestResolveOk")
	if ok_btn == null:
		atlas.queue_free()
		return "ContestResolveOk missing"
	ok_btn.emit_signal("pressed")
	await get_tree().process_frame
	if atlas.find_child("ContestResolveModal", true, false) != null:
		atlas.queue_free()
		return "modal not cleared"
	atlas.queue_free()
	return ""
