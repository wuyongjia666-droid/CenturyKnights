extends Node
## Fat heraldry wave-8 E2E: atlas TravelCrestStrip / CampCrestStrip / EncounterCrestStrip
## — strip_company + cloth banner child field_route ownership — desk + mobile.
## Real atlas_view scenes; no EmptyHost.

const ATLAS := "res://scenes/hub/atlas_view.tscn"

var _fails: Array = []


func _ready() -> void:
	await get_tree().process_frame
	await _run_desktop()
	await _run_mobile()
	_source_contracts()
	if _fails.is_empty():
		print("HERALDRY TRAVEL CAMP ENCOUNTER SCENE PASS")
		get_tree().quit(0)
	else:
		for f in _fails:
			print("FAIL heraldry travel camp encounter scene: ", f)
		get_tree().quit(1)


func _ok(cond: bool, msg: String) -> void:
	print("ROW %s %s" % ["PASS" if cond else "FAIL", msg])
	if not cond:
		_fails.append(msg)


func _settle(n: int = 8) -> void:
	for _i in n:
		await get_tree().process_frame


func _route(n: Node, want: String) -> bool:
	return n != null and str(n.get_meta("field_route", "")) == want


func _boot() -> void:
	GameState.new_game("行营旗学徽", "灰旗", GameState.crest_color)
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


func _open() -> Control:
	var page: Control = (load(ATLAS) as PackedScene).instantiate()
	page.set_anchors_preset(Control.PRESET_TOP_LEFT)
	page.position = Vector2.ZERO
	page.size = Vector2(1280, 720)
	get_tree().root.add_child(page)
	return page


func _assert_travel(tag: String) -> void:
	_boot()
	var nid := World.nation_of("ash_capital")
	var page := _open()
	await _settle(14)
	if page.has_method("apply_mobile_layout") and tag.begins_with("mob"):
		page.call("apply_mobile_layout")
		await _settle(8)
	var strip := page.find_child("TravelCrestStrip", true, false)
	_ok(_route(strip, "travel_strip"), "%s/travel travel_strip" % tag)
	if strip != null:
		_ok(_route(strip.find_child("CastleArms", true, false), "strip_company"), "%s/travel strip_company" % tag)
		if nid != "":
			_ok(_route(strip.find_child("TerritoryArms", true, false), "travel_territory"), "%s/travel travel_territory" % tag)
		_ok(_route(strip.find_child("TravelBanner", true, false), "travel_banner"), "%s/travel travel_banner" % tag)
	page.queue_free()
	await _settle(2)


func _assert_camp(tag: String) -> void:
	_boot()
	var nid := World.nation_of("ash_capital")
	var ev := {
		"id": "camp_night",
		"kind": "camp",
		"title": "夜营",
		"text": "队伍扎营歇脚。",
		"b": "ash_capital",
		"options": [{"label": "休息", "fx": {}}],
	}
	var page := _open()
	await _settle(10)
	if page.has_method("apply_mobile_layout") and tag.begins_with("mob"):
		page.call("apply_mobile_layout")
		await _settle(6)
	page.call("_show_event_modal", ev)
	await _settle(10)
	var modal := page.find_child("EventModal", true, false)
	_ok(modal != null, "%s/camp EventModal" % tag)
	var host: Node = modal if modal else page
	var strip := host.find_child("CampCrestStrip", true, false)
	_ok(_route(strip, "camp_strip"), "%s/camp camp_strip" % tag)
	if strip != null:
		_ok(_route(strip.find_child("CastleArms", true, false), "strip_company"), "%s/camp strip_company" % tag)
		if nid != "":
			_ok(_route(strip.find_child("TerritoryArms", true, false), "camp_territory"), "%s/camp camp_territory" % tag)
		_ok(_route(strip.find_child("CampBanner", true, false), "camp_banner"), "%s/camp camp_banner" % tag)
	page.queue_free()
	await _settle(2)


func _assert_encounter(tag: String) -> void:
	_boot()
	World.begin_travel("fog_vale")
	var enc: Dictionary = World.start_encounter("road", {"node": "hq", "from": "ash_capital", "danger": 2})
	var foe := str(enc.get("nation", ""))
	_ok(foe != "", "%s/encounter nation set" % tag)
	var enc_snap: Dictionary = enc.duplicate(true)
	World.encounter = {}
	var page := _open()
	await _settle(10)
	if page.has_method("apply_mobile_layout") and tag.begins_with("mob"):
		page.call("apply_mobile_layout")
		await _settle(6)
	page.call("_show_encounter_modal", enc_snap)
	await _settle(10)
	var modal := page.find_child("EncounterModal", true, false)
	_ok(modal != null, "%s/encounter EncounterModal" % tag)
	var host: Node = modal if modal else page
	var strip := host.find_child("EncounterCrestStrip", true, false)
	_ok(_route(strip, "encounter_strip"), "%s/encounter encounter_strip" % tag)
	if strip != null:
		_ok(_route(strip.find_child("CastleArms", true, false), "strip_company"), "%s/encounter strip_company" % tag)
		_ok(_route(strip.find_child("FoeArms", true, false), "encounter_foe"), "%s/encounter encounter_foe" % tag)
		_ok(_route(strip.find_child("EncounterBanner", true, false), "encounter_banner"), "%s/encounter encounter_banner" % tag)
	World.cancel_travel()
	World.encounter = {}
	page.queue_free()
	await _settle(2)


func _run_pass(tag: String) -> void:
	await _assert_travel(tag)
	await _assert_camp(tag)
	await _assert_encounter(tag)


func _run_desktop() -> void:
	OS.set_environment("CK_FORCE_MOBILE", "0")
	await _run_pass("desk")


func _run_mobile() -> void:
	OS.set_environment("CK_FORCE_MOBILE", "1")
	_ok(DeviceProfile.is_mobile(), "CK_FORCE_MOBILE flips DeviceProfile")
	await _run_pass("mob")
	OS.set_environment("CK_FORCE_MOBILE", "")


func _source_contracts() -> void:
	var field := FileAccess.get_file_as_string("res://scripts/art/heraldry_field.gd")
	for route in [
		"travel_strip", "travel_territory", "travel_banner",
		"camp_strip", "camp_territory", "camp_banner",
		"encounter_strip", "encounter_foe", "encounter_banner",
		"strip_company",
	]:
		var lit := field.find('set_meta("field_route", "%s")' % route) >= 0
		var arg := field.find('"%s"' % route) >= 0
		_ok(lit or arg, "field source route %s" % route)
	var src := FileAccess.get_file_as_string("res://scripts/hub/atlas_view.gd")
	_ok(src.find("CKHeraldryField.place_travel_crest_strip") >= 0, "atlas wires travel Field")
	_ok(src.find("CKHeraldryField.place_camp_crest_strip") >= 0, "atlas wires camp Field")
	_ok(src.find("CKHeraldryField.place_encounter_crest_strip") >= 0, "atlas wires encounter Field")
