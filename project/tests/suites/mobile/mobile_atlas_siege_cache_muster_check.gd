extends Node
## Mobile E2E: SiegeAlert → SiegeMuster under phone layout.

const PHONE := Vector2i(2400, 1080)
const ATLAS_SCN := preload("res://scenes/hub/atlas_view.tscn")
const SITE := "t_ash_cinderpit"

func _ready() -> void:
	var err := await _run()
	if err != "":
		print("FAIL mobile atlas siege cache muster: ", err)
		get_tree().quit(1)
	else:
		print("MOBILE ATLAS SIEGE CACHE MUSTER PASS")
		get_tree().quit(0)

func _set_phone_window() -> void:
	DisplayServer.window_set_size(PHONE)
	await get_tree().process_frame

func _run() -> String:
	if not DeviceProfile.is_mobile():
		return "DeviceProfile.is_mobile() false — need CK_FORCE_MOBILE=1"
	await _set_phone_window()
	GameState.new_game("MobileMuster", "灰旗", GameState.crest_color)
	GameState.set_flag("chapter0_done", true)
	UnlockSchedule.install()
	World.events_enabled = false
	World.rivals_enabled = false
	for nid in World.nations.keys():
		World.rep_nation[str(nid)] = 50
	GameState.food = 30
	GameState.silver = 8000
	World.hub_tour.clear()
	World.last_siege_alert = {}
	World.last_siege_muster = {}
	World.last_territory_month = {}
	var st0: Dictionary = CKTerritory.state(SITE)
	st0.owner = CKTerritory.NEUTRAL
	st0.garrison = 0
	st0.stockade = false
	st0.threat = {}
	st0.cache_food = 0
	CKTerritory._put(SITE, st0)
	var cost := CKTerritory.muster_cache_cost(SITE)
	var anchor := str(CKTerritory.site(SITE).get("anchor", ""))
	World.pos = anchor
	World.arrive(anchor)
	CKTerritory.capture(SITE, "chain")
	var st := CKTerritory.state(SITE)
	st.garrison = 1
	st.stockade = true
	st.cache_food = cost + 2
	st.threat = {}
	CKTerritory._put(SITE, st)
	CKTerritory.start_threat(SITE)
	var atlas: Node = ATLAS_SCN.instantiate()
	add_child(atlas)
	await get_tree().process_frame
	await get_tree().process_frame
	if atlas.has_method("_check_siege_alert"):
		atlas.call("_check_siege_alert")
	await get_tree().process_frame
	var panel = atlas.find_child("SiegeAlertModal", true, false)
	if panel == null:
		atlas.queue_free()
		return "SiegeAlertModal missing"
	var btn = panel.get_node_or_null("SiegeMuster")
	if btn == null:
		atlas.queue_free()
		return "SiegeMuster missing"
	btn.emit_signal("pressed")
	await get_tree().process_frame
	if int(CKTerritory.state(SITE).garrison) != 2:
		atlas.queue_free()
		return "garrison not 2 after muster"
	if CKTerritory.cache_food(SITE) != 2:
		atlas.queue_free()
		return "cache not spent"
	atlas.queue_free()
	await get_tree().process_frame
	return ""
