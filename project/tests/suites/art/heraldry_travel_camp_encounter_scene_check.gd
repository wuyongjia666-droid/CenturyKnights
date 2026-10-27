extends Node
## Fat heraldry wave-16 E2E: TravelCrestStrip / CampCrestStrip / EncounterCrestStrip
## — _cloth_beside Field cloth + arms_kind ownership — desk + mobile.
## Real atlas_view travel HUD / camp event / encounter modal. No EmptyHost.

const ATLAS := "res://scenes/hub/atlas_view.tscn"

var _fails: Array = []


func _ready() -> void:
	await get_tree().process_frame
	await _run_helpers()
	await _run_desktop()
	await _run_mobile()
	_source_contracts()
	if _fails.is_empty():
		print("HERALDRY TRAVEL CAMP ENCOUNTER CLOTH SCENE PASS")
		get_tree().quit(0)
	else:
		for f in _fails:
			print("FAIL heraldry travel camp encounter cloth scene: ", f)
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
	GameState.new_game("行路夜营遭遇旗学徽", "灰旗", GameState.crest_color)
	GameState.set_flag("chapter0_done", true)
	UnlockSchedule.install()
	World.events_enabled = false
	World.rivals_enabled = false
	GameState.food = 40
	GameState.iron = 40
	GameState.silver = 8000
	GameState.morale = 80
	World.pos = "ash_capital"
	World.arrive("ash_capital")
	World.travel = {}
	World.pending_event = {}
	World.encounter = {}
	World.active.clear()


func _open(path: String) -> Control:
	var page: Control = (load(path) as PackedScene).instantiate()
	page.set_anchors_preset(Control.PRESET_TOP_LEFT)
	page.position = Vector2.ZERO
	page.size = Vector2(1280, 720)
	get_tree().root.add_child(page)
	return page


func _run_helpers() -> void:
	_boot()
	var host := Control.new()
	add_child(host)
	var tv := CKHeraldryField.place_travel_crest_strip(host, Vector2(8, 8), "ashbanner")
	_ok(tv != null and tv.name == "TravelCrestStrip", "helper TravelCrestStrip")
	_ok(tv != null and tv.get_child_count() == 3, "helper travel child_count=3")
	var tvbn := tv.find_child("TravelBanner", true, false) if tv else null
	_ok(_route(tvbn, "travel_banner"), "helper travel_banner")
	_ok(tvbn != null and str(tvbn.get_meta("arms_kind", "")) == "lb_travel_arms", "helper travel kind")
	var cp := CKHeraldryField.place_camp_crest_strip(host, Vector2(200, 8), "ashbanner")
	_ok(cp != null and cp.name == "CampCrestStrip", "helper CampCrestStrip")
	_ok(cp != null and cp.get_child_count() == 3, "helper camp child_count=3")
	var cpbn := cp.find_child("CampBanner", true, false) if cp else null
	_ok(_route(cpbn, "camp_banner"), "helper camp_banner")
	_ok(cpbn != null and str(cpbn.get_meta("arms_kind", "")) == "lb_camp_arms", "helper camp kind")
	var enc := CKHeraldryField.place_encounter_crest_strip(host, Vector2(400, 8), "ashbanner")
	_ok(enc != null and enc.name == "EncounterCrestStrip", "helper EncounterCrestStrip")
	_ok(enc != null and enc.get_child_count() == 3, "helper encounter child_count=3")
	var encbn := enc.find_child("EncounterBanner", true, false) if enc else null
	_ok(_route(encbn, "encounter_banner"), "helper encounter_banner")
	_ok(encbn != null and str(encbn.get_meta("arms_kind", "")) == "lb_encounter_arms", "helper encounter kind")
	host.queue_free()
	await _settle(2)


func _assert_atlas(tag: String) -> void:
	var nid := World.nation_of("ash_capital")
	if nid == "":
		nid = "ashbanner"
	_boot()
	var page := _open(ATLAS)
	await _settle(12)
	if page.has_method("apply_mobile_layout") and tag.begins_with("mob"):
		page.call("apply_mobile_layout")
		await _settle(6)

	var travel := page.find_child("TravelCrestStrip", true, false)
	_ok(_route(travel, "travel_strip"), "%s/atlas travel_strip" % tag)
	if travel != null:
		_ok(_route(travel.find_child("CastleArms", true, false), "strip_company"), "%s/atlas travel strip_company" % tag)
		var terr := travel.find_child("TerritoryArms", true, false)
		if nid != "":
			_ok(_route(terr, "travel_territory"), "%s/atlas travel_territory" % tag)
		var bn := travel.find_child("TravelBanner", true, false)
		_ok(_route(bn, "travel_banner"), "%s/atlas travel_banner" % tag)
		_ok(bn != null and str(bn.get_meta("arms_kind", "")) == "lb_travel_arms", "%s/atlas TravelBanner kind" % tag)

	# Camp night event.
	World.pending_event = {}
	World.cancel_travel()
	World.pending_event = {}
	World.travel = {}
	World.encounter = {}
	page.call("_show_event_modal", {
		"id": "camp_night",
		"kind": "camp",
		"title": "夜营",
		"text": "队伍扎营歇脚。",
		"b": "ash_capital",
		"options": [{"label": "休息", "fx": {}}],
	})
	await _settle(8)
	var camp_modal := page.find_child("EventModal", true, false)
	_ok(camp_modal != null, "%s/atlas EventModal camp" % tag)
	var camp := page.find_child("CampCrestStrip", true, false)
	_ok(_route(camp, "camp_strip"), "%s/atlas camp_strip" % tag)
	if camp != null:
		_ok(_route(camp.find_child("CastleArms", true, false), "strip_company"), "%s/atlas camp strip_company" % tag)
		var ct := camp.find_child("TerritoryArms", true, false)
		if nid != "":
			_ok(_route(ct, "camp_territory"), "%s/atlas camp_territory" % tag)
		var cbn := camp.find_child("CampBanner", true, false)
		_ok(_route(cbn, "camp_banner"), "%s/atlas camp_banner" % tag)
		_ok(cbn != null and str(cbn.get_meta("arms_kind", "")) == "lb_camp_arms", "%s/atlas CampBanner kind" % tag)
	page.call("_clear_modal")
	await _settle(2)

	# Encounter modal.
	World.encounter = {}
	page.call("_show_encounter_modal", {
		"nation": nid,
		"label": "遭遇",
		"node": "ash_capital",
		"danger": 2,
		"map": {"enemy_templates": ["bandit"]},
	})
	await _settle(8)
	var enc_modal := page.find_child("EncounterModal", true, false)
	_ok(enc_modal != null, "%s/atlas EncounterModal" % tag)
	var enc := page.find_child("EncounterCrestStrip", true, false)
	_ok(_route(enc, "encounter_strip"), "%s/atlas encounter_strip" % tag)
	if enc != null:
		_ok(_route(enc.find_child("CastleArms", true, false), "strip_company"), "%s/atlas encounter strip_company" % tag)
		_ok(_route(enc.find_child("FoeArms", true, false), "encounter_foe"), "%s/atlas encounter_foe" % tag)
		var ebn := enc.find_child("EncounterBanner", true, false)
		_ok(_route(ebn, "encounter_banner"), "%s/atlas encounter_banner" % tag)
		_ok(ebn != null and str(ebn.get_meta("arms_kind", "")) == "lb_encounter_arms", "%s/atlas EncounterBanner kind" % tag)
	page.call("_clear_modal")
	await _settle(2)

	_ok(page.find_child("EmptyHost", true, false) == null, "%s/atlas no EmptyHost" % tag)
	page.queue_free()
	await _settle(2)


func _run_desktop() -> void:
	OS.set_environment("CK_FORCE_MOBILE", "0")
	await _assert_atlas("desk")


func _run_mobile() -> void:
	OS.set_environment("CK_FORCE_MOBILE", "1")
	_ok(DeviceProfile.is_mobile(), "CK_FORCE_MOBILE flips DeviceProfile")
	await _assert_atlas("mob")
	OS.set_environment("CK_FORCE_MOBILE", "")


func _source_contracts() -> void:
	var field := FileAccess.get_file_as_string("res://scripts/art/heraldry_field.gd")
	for route in [
		"travel_strip", "travel_banner", "travel_territory",
		"camp_strip", "camp_banner", "camp_territory",
		"encounter_strip", "encounter_banner", "encounter_foe",
		"strip_company",
	]:
		var lit := field.find('set_meta("field_route", "%s")' % route) >= 0
		var arg := field.find('"%s"' % route) >= 0
		_ok(lit or arg, "field source route %s" % route)
	_ok(field.find('_cloth_beside(host, shield, "TravelBanner"') >= 0, "field travel via _cloth_beside")
	_ok(field.find('_cloth_beside(host, shield, "CampBanner"') >= 0, "field camp via _cloth_beside")
	_ok(field.find('_cloth_beside(host, shield, "EncounterBanner"') >= 0, "field encounter via _cloth_beside")
	_ok(field.find('"lb_travel_arms"') >= 0, "field lb_travel_arms")
	_ok(field.find('"lb_camp_arms"') >= 0, "field lb_camp_arms")
	_ok(field.find('"lb_encounter_arms"') >= 0, "field lb_encounter_arms")
	var atlas := FileAccess.get_file_as_string("res://scripts/hub/atlas_view.gd")
	_ok(atlas.find("CKHeraldryField.place_travel_crest_strip") >= 0
			or atlas.find("CKHeraldryChrome.place_travel_crest_strip") >= 0, "atlas wires travel Field")
	_ok(atlas.find("CKHeraldryField.place_camp_crest_strip") >= 0
			or atlas.find("CKHeraldryChrome.place_camp_crest_strip") >= 0, "atlas wires camp Field")
	_ok(atlas.find("CKHeraldryField.place_encounter_crest_strip") >= 0
			or atlas.find("CKHeraldryChrome.place_encounter_crest_strip") >= 0, "atlas wires encounter Field")
	var loc := FileAccess.get_file_as_string("res://data/locale/lineb.csv")
	_ok(loc.find("lb_travel_arms,") >= 0, "locale lb_travel_arms")
	_ok(loc.find("lb_camp_arms,") >= 0, "locale lb_camp_arms")
	_ok(loc.find("lb_encounter_arms,") >= 0, "locale lb_encounter_arms")
