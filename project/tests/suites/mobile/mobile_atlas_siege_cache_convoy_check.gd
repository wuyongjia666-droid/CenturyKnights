extends Node
## Mobile E2E: SiegeAlert → SiegeEvacuate under phone layout.

const PHONE := Vector2i(2400, 1080)
const ATLAS_SCN := preload("res://scenes/hub/atlas_view.tscn")
const SITE := "t_ash_cinderpit"
const DEST := "t_ash_millrun"

func _ready() -> void:
	var err := await _run()
	if err != "":
		print("FAIL mobile atlas siege cache convoy: ", err)
		get_tree().quit(1)
	else:
		print("MOBILE ATLAS SIEGE CACHE CONVOY PASS")
		get_tree().quit(0)

func _set_phone_window() -> void:
	DisplayServer.window_set_size(PHONE)
	await get_tree().process_frame

func _run() -> String:
	if not DeviceProfile.is_mobile():
		return "DeviceProfile.is_mobile() false — need CK_FORCE_MOBILE=1"
	await _set_phone_window()
	GameState.new_game("MobileConvoy", "灰旗", GameState.crest_color)
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
	World.last_siege_convoy = {}
	World.last_territory_month = {}
	for id in [SITE, DEST]:
		var st0: Dictionary = CKTerritory.state(id)
		st0.owner = CKTerritory.NEUTRAL
		st0.garrison = 0
		st0.stockade = false
		st0.cache_food = 0
		st0.threat = {}
		CKTerritory._put(id, st0)
	for id in [DEST, SITE]:
		var anch := str(CKTerritory.site(id).get("anchor", ""))
		World.pos = anch
		World.arrive(anch)
		CKTerritory.capture(id, "chain")
		var st := CKTerritory.state(id)
		st.garrison = 2
		st.stockade = true
		st.cache_food = 0 if id == DEST else 12
		st.threat = {}
		CKTerritory._put(id, st)
	CKTerritory.start_threat(SITE)
	World.last_territory_month = {}
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
	var btn = panel.get_node_or_null("SiegeEvacuate")
	if btn == null:
		atlas.queue_free()
		return "SiegeEvacuate missing"
	btn.emit_signal("pressed")
	await get_tree().process_frame
	if CKTerritory.cache_food(SITE) != 0:
		atlas.queue_free()
		return "source cache not emptied"
	if CKTerritory.cache_food(DEST) <= 0:
		atlas.queue_free()
		return "dest did not receive"
	atlas.queue_free()
	return ""
