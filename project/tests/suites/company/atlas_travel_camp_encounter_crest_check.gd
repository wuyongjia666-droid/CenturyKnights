extends Node
## Fat heraldry E2E: atlas travel / camp / encounter full-scene crests (团徽 + 领地徽|敌徽).

const ATLAS_SCN := preload("res://scenes/hub/atlas_view.tscn")
var _fails: Array = []

func _ready() -> void:
	await get_tree().process_frame
	_setup()
	await _ui_travel_hud_crests()
	await _ui_halt_travel_crests()
	await _ui_stopover_travel_crests()
	await _ui_camp_event_crests()
	await _ui_road_event_travel_crests()
	await _ui_encounter_crests()
	await _ui_mobile_travel_crests()
	if _fails.is_empty():
		print("ATLAS TRAVEL CAMP ENCOUNTER CREST PASS")
		get_tree().quit(0)
	else:
		for f in _fails:
			print("FAIL atlas travel/camp/encounter crest: ", f)
		get_tree().quit(1)

func _ok(cond: bool, msg: String) -> void:
	print("ROW %s %s" % ["PASS" if cond else "FAIL", msg])
	if not cond:
		_fails.append(msg)

func _setup() -> void:
	GameState.new_game("行徽", "灰旗", GameState.crest_color)
	GameState.set_flag("chapter0_done", true)
	UnlockSchedule.install()
	World.events_enabled = false
	World.rivals_enabled = false
	for nid in World.nations.keys():
		World.rep_nation[str(nid)] = 50
	GameState.food = 40
	GameState.silver = 8000
	GameState.morale = 80
	World.pos = "ash_capital"
	World.arrive("ash_capital")
	World.travel = {}
	World.pending_event = {}
	World.encounter = {}
	World.active.clear()
	World.travel_log.clear()

func _settle(n: int = 6) -> void:
	for i in n:
		await get_tree().process_frame

func _assert_travel_strip(host: Node, where: String, expect_nid: String) -> void:
	var strip = host.find_child("TravelCrestStrip", true, false)
	_ok(strip != null, "%s TravelCrestStrip" % where)
	if strip == null:
		return
	var ca = strip.find_child("CastleArms", true, false)
	_ok(ca != null and str(ca.get_meta("arms_kind", "")) == "gen2_36", "%s 团徽" % where)
	if expect_nid != "":
		var terr = strip.find_child("TerritoryArms", true, false)
		_ok(terr != null and str(terr.get_meta("arms_kind", "")) == "lb_territory_arms", "%s 领地徽" % where)
		_ok(terr != null and str(terr.get_meta("nation_id", "")) == expect_nid, "%s territory nation" % where)
		_ok(terr != null and str(terr.get_meta("arms_core", "")) != str(ca.get_meta("arms_core", "")), "%s terr != company" % where)
		_ok(str(strip.get_meta("nation_id", "")) == expect_nid, "%s strip meta nation" % where)
	else:
		_ok(strip.find_child("TerritoryArms", true, false) == null, "%s no TerritoryArms" % where)

func _ui_travel_hud_crests() -> void:
	var nid := World.nation_of("ash_capital")
	_ok(nid != "", "ash_capital has nation")
	var page: Control = ATLAS_SCN.instantiate()
	get_tree().root.add_child(page)
	await _settle(10)
	_assert_travel_strip(page, "hud", nid)
	page.queue_free()
	await _settle(2)

func _ui_halt_travel_crests() -> void:
	var nid := World.nation_of(World.pos)
	var page: Control = ATLAS_SCN.instantiate()
	get_tree().root.add_child(page)
	await _settle()
	page.call("_show_travel_halt_modal")
	await _settle(8)
	var modal := page.find_child("TravelHaltModal", true, false)
	_ok(modal != null, "TravelHaltModal")
	_assert_travel_strip(modal if modal else page, "halt", nid)
	page.queue_free()
	await _settle(2)

func _ui_stopover_travel_crests() -> void:
	var nid := World.nation_of(World.pos)
	var page: Control = ATLAS_SCN.instantiate()
	get_tree().root.add_child(page)
	await _settle()
	page.call("_show_stopover_modal")
	await _settle(8)
	var modal := page.find_child("StopoverModal", true, false)
	_ok(modal != null, "StopoverModal")
	_assert_travel_strip(modal if modal else page, "stopover", nid)
	page.queue_free()
	await _settle(2)

func _ui_camp_event_crests() -> void:
	## Synthetic camp — avoid pending_event auto-open racing the suite call.
	World.cancel_travel()
	World.pending_event = {}
	World.travel = {}
	World.encounter = {}
	World.pos = "ash_capital"
	World.arrive("ash_capital")
	var ev := {
		"id": "camp_night",
		"kind": "camp",
		"title": "夜营",
		"text": "队伍扎营歇脚。",
		"b": "ash_capital",
		"options": [{"label": "休息", "fx": {}}],
	}
	var nid := World.nation_of("ash_capital")
	var page: Control = ATLAS_SCN.instantiate()
	get_tree().root.add_child(page)
	await _settle(8)
	page.call("_show_event_modal", ev)
	await _settle(10)
	var modal := page.find_child("EventModal", true, false)
	_ok(modal != null, "EventModal camp")
	var strip = (modal if modal else page).find_child("CampCrestStrip", true, false)
	_ok(strip != null, "camp CampCrestStrip")
	if strip != null:
		var ca = strip.find_child("CastleArms", true, false)
		var terr = strip.find_child("TerritoryArms", true, false)
		_ok(ca != null and str(ca.get_meta("arms_kind", "")) == "gen2_36", "camp 团徽")
		_ok(terr != null and str(terr.get_meta("arms_kind", "")) == "lb_territory_arms", "camp 领地徽")
		_ok(terr != null and str(terr.get_meta("nation_id", "")) == nid, "camp territory nation")
	page.queue_free()
	await _settle(2)

func _ui_road_event_travel_crests() -> void:
	var nid := World.nation_of("ash_capital")
	var ev := {
		"id": "merchant",
		"kind": "road",
		"title": "商队",
		"text": "路上遇见商队。",
		"b": "ash_capital",
		"options": [{"label": "路过", "fx": {}}],
	}
	var page: Control = ATLAS_SCN.instantiate()
	get_tree().root.add_child(page)
	await _settle()
	page.call("_show_event_modal", ev)
	await _settle(8)
	var modal := page.find_child("EventModal", true, false)
	_ok(modal != null, "EventModal road")
	_assert_travel_strip(modal if modal else page, "road-event", nid)
	_ok((modal if modal else page).find_child("CampCrestStrip", true, false) == null, "road-event no CampCrestStrip")
	page.queue_free()
	await _settle(2)

func _ui_encounter_crests() -> void:
	World.cancel_travel()
	World.pending_event = {}
	World.travel = {}
	World.encounter = {}
	World.pos = "ash_capital"
	World.arrive("ash_capital")
	World.begin_travel("fog_vale")
	var enc: Dictionary = World.start_encounter("road", {"node": "hq", "from": "ash_capital", "danger": 2})
	var foe := str(enc.get("nation", ""))
	_ok(foe != "", "encounter nation set")
	## Snapshot enc then clear live encounter so atlas _ready does not auto-open.
	var enc_snap: Dictionary = enc.duplicate(true)
	World.encounter = {}
	var page: Control = ATLAS_SCN.instantiate()
	get_tree().root.add_child(page)
	await _settle(8)
	page.call("_show_encounter_modal", enc_snap)
	await _settle(10)
	var modal := page.find_child("EncounterModal", true, false)
	_ok(modal != null, "EncounterModal")
	var strip = (modal if modal else page).find_child("EncounterCrestStrip", true, false)
	_ok(strip != null, "EncounterCrestStrip")
	if strip != null:
		var ca = strip.find_child("CastleArms", true, false)
		var foe_arms = strip.find_child("FoeArms", true, false)
		_ok(ca != null and str(ca.get_meta("arms_kind", "")) == "gen2_36", "encounter 团徽")
		_ok(foe_arms != null and str(foe_arms.get_meta("arms_kind", "")) == "lb_rv_arms", "encounter 敌徽")
		_ok(foe_arms != null and str(foe_arms.get_meta("nation_id", "")) == foe, "encounter foe nation")
		_ok(foe_arms != null and str(foe_arms.get_meta("arms_core", "")) != str(ca.get_meta("arms_core", "")), "encounter foe != company")
	_ok(page.find_child("AftermathCrestStrip", true, false) == null, "encounter not AftermathCrestStrip")
	World.cancel_travel()
	World.encounter = {}
	page.queue_free()
	await _settle(2)

func _ui_mobile_travel_crests() -> void:
	OS.set_environment("CK_FORCE_MOBILE", "1")
	_ok(DeviceProfile.is_mobile(), "CK_FORCE_MOBILE flips DeviceProfile")
	var nid := World.nation_of("ash_capital")
	World.pos = "ash_capital"
	World.arrive("ash_capital")
	var page: Control = ATLAS_SCN.instantiate()
	get_tree().root.add_child(page)
	await _settle(12)
	if page.has_method("apply_mobile_layout"):
		page.call("apply_mobile_layout")
		await _settle(6)
	_assert_travel_strip(page, "mob-hud", nid)
	page.queue_free()
	await _settle(2)
	OS.set_environment("CK_FORCE_MOBILE", "")
