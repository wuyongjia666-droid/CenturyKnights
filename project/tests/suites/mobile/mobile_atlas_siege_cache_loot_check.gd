extends Node
## Mobile E2E: unanswered siege loot → SiegeLootModal on phone layout.

const PHONE := Vector2i(2400, 1080)
const ATLAS_SCN := preload("res://scenes/hub/atlas_view.tscn")
const SITE := "t_ash_cinderpit"

func _ready() -> void:
	var err := await _run()
	if err != "":
		print("FAIL mobile atlas siege cache loot: ", err)
		get_tree().quit(1)
	else:
		print("MOBILE ATLAS SIEGE CACHE LOOT PASS")
		get_tree().quit(0)

func _set_phone_window() -> void:
	DisplayServer.window_set_size(PHONE)
	await get_tree().process_frame

func _boot() -> void:
	GameState.new_game("MobileSiegeLoot", "灰旗", GameState.crest_color)
	GameState.set_flag("chapter0_done", true)
	UnlockSchedule.install()
	World.events_enabled = false
	World.rivals_enabled = false
	for nid in World.nations.keys():
		World.rep_nation[str(nid)] = 50
	GameState.food = 40
	GameState.silver = 600
	GameState.morale = 70
	World.hub_tour.clear()
	World.travel = {}
	World.pending_event = {}
	World.encounter = {}
	World.last_siege_alert = {}
	World.last_siege_loot = {}
	CKTerritory.last_month_report = {}

func _run() -> String:
	if not DeviceProfile.is_mobile():
		return "DeviceProfile.is_mobile() false — need CK_FORCE_MOBILE=1"
	await _set_phone_window()
	_boot()
	var st: Dictionary = CKTerritory.state(SITE)
	st.owner = CKTerritory.NEUTRAL
	st.garrison = 0
	st.stockade = false
	st.cache_food = 0
	st.threat = {}
	CKTerritory._put(SITE, st)
	var anchor := str(CKTerritory.site(SITE).get("anchor", ""))
	World.pos = anchor
	World.arrive(anchor)
	CKTerritory.capture(SITE, "chain")
	st = CKTerritory.state(SITE)
	st.garrison = 4
	st.stockade = true
	st.cache_food = 10
	st.threat = {}
	CKTerritory._put(SITE, st)
	CKTerritory.start_threat(SITE)
	st = CKTerritory.state(SITE)
	st.threat["months"] = 1
	CKTerritory._put(SITE, st)
	World.last_siege_alert = {}
	World.last_siege_loot = {}
	CKTerritory.apply_month(0.0)
	if World.last_siege_loot.is_empty():
		return "expected last_siege_loot after hold resolve"
	if int(World.last_siege_loot.get("looted", 0)) != 5:
		return "expected looted 5 got %s" % World.last_siege_loot.get("looted", 0)
	World.last_territory_month = {}
	World.last_siege_alert = {}
	var atlas: Node = ATLAS_SCN.instantiate()
	add_child(atlas)
	await get_tree().process_frame
	await get_tree().process_frame
	if atlas.has_method("_check_siege_loot"):
		atlas.call("_check_siege_loot")
	await get_tree().process_frame
	var panel = atlas.find_child("SiegeLootModal", true, false)
	if panel == null:
		atlas.queue_free()
		return "SiegeLootModal missing on mobile"
	var ok_btn = panel.get_node_or_null("SiegeLootOk")
	if ok_btn == null:
		atlas.queue_free()
		return "SiegeLootOk missing"
	ok_btn.emit_signal("pressed")
	await get_tree().process_frame
	if atlas.find_child("SiegeLootModal", true, false) != null:
		atlas.queue_free()
		return "modal not cleared"
	atlas.queue_free()
	return ""
