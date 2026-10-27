extends Node
## Fat heraldry wave-3 E2E: castle hub banner_plate routes, castle view strip,
## tavern hire strip + cloth banner, atlas PartyToken company arms, and battle
## order/report/forecast Field ownership — desk + mobile. Real scenes; no EmptyHost.

const CASTLE_HUB := "res://scenes/hub/castle_hub.tscn"
const CASTLE_VIEW := "res://scenes/hub/castle_view.tscn"
const TAVERN := "res://scenes/hub/tavern.tscn"
const ATLAS := "res://scenes/hub/atlas_view.tscn"
const BATTLE := "res://scenes/battle/battle.tscn"

var _fails: Array = []


func _ready() -> void:
	await get_tree().process_frame
	await _run_desktop()
	await _run_mobile()
	_source_contracts()
	if _fails.is_empty():
		print("HERALDRY CASTLE TAVERN ATLAS SCENE PASS")
		get_tree().quit(0)
	else:
		for f in _fails:
			print("FAIL heraldry castle tavern atlas scene: ", f)
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
	GameState.new_game("城酒图战徽", "霜旗", GameState.crest_color)
	GameState.chapter0_flags["chapter0_done"] = true
	GameState.chapter0_flags["ch0_playing"] = false
	GameState.set_flag("chapter0_done", true)
	UnlockSchedule.install()
	World.events_enabled = false
	World.rivals_enabled = false
	GameState.silver = 9000
	GameState.food = 40
	GameState.iron = 40
	GameState.morale = 80
	for nid in World.nations.keys():
		World.rep_nation[str(nid)] = 50
	World.pos = "ash_capital"
	World.arrive("ash_capital")
	World.travel = {}
	World.pending_event = {}
	World.encounter = {}
	World.active.clear()
	GameState.set_meta("city_id", "ash_capital")
	var lead: CKCharacter = GameState.get_leader()
	if lead != null:
		lead.rank = "baron"
		lead.gender = "m"
		if not (lead.id in GameState.deploy_ids):
			GameState.deploy_ids = [lead.id]
	# Tavern hire pool so focus arms attach.
	var kin := CKCharacter.new()
	kin.id = "cta_kin"
	kin.name = "城聘"
	kin.age = 24
	kin.alive = true
	kin.in_roster = false
	kin.family_id = str(lead.family_id) if lead != null else ""
	kin.job_id = "light_inf"
	kin.rank = "knight"
	GameState.tavern_candidates = [kin]
	GameState.set_meta("battle_foe_nation", "ashbanner")
	GameState.set_meta("battle_map", "ch0_pass")


func _open(path: String) -> Control:
	var page: Control = (load(path) as PackedScene).instantiate()
	page.set_anchors_preset(Control.PRESET_TOP_LEFT)
	page.position = Vector2.ZERO
	page.size = Vector2(1280, 720)
	get_tree().root.add_child(page)
	return page


func _assert_castle_hub(tag: String) -> void:
	_boot()
	var page := _open(CASTLE_HUB)
	await _settle(12)
	if page.has_method("apply_mobile_layout") and tag.begins_with("mob"):
		page.call("apply_mobile_layout")
		await _settle(6)
	var strip := page.find_child("CastleBannerStrip", true, false)
	_ok(_route(strip, "banner_plate"), "%s/hub banner_plate" % tag)
	if strip != null:
		_ok(_route(strip.find_child("CastleArms", true, false), "strip_company"), "%s/hub strip_company" % tag)
		_ok(_route(strip.find_child("CastleBanner", true, false), "castle_hub_banner"), "%s/hub castle_hub_banner" % tag)
	page.queue_free()
	await _settle(2)


func _assert_castle_view(tag: String) -> void:
	_boot()
	var page := _open(CASTLE_VIEW)
	await _settle(12)
	if page.has_method("apply_mobile_layout") and tag.begins_with("mob"):
		page.call("apply_mobile_layout")
		await _settle(6)
	var strip := page.find_child("CastleViewCrestStrip", true, false)
	_ok(_route(strip, "castle_view_strip"), "%s/view castle_view_strip" % tag)
	if strip != null:
		_ok(_route(strip.find_child("CastleArms", true, false), "strip_company"), "%s/view strip_company" % tag)
		_ok(_route(strip.find_child("CastleViewBanner", true, false), "castle_view_banner"), "%s/view castle_view_banner" % tag)
	page.queue_free()
	await _settle(2)


func _assert_tavern(tag: String) -> void:
	_boot()
	var page := _open(TAVERN)
	await _settle(12)
	if page.has_method("apply_mobile_layout") and tag.begins_with("mob"):
		page.call("apply_mobile_layout")
		await _settle(6)
	var strip := page.find_child("TavernCrestStrip", true, false)
	_ok(_route(strip, "tavern_strip"), "%s/tavern tavern_strip" % tag)
	if strip != null:
		_ok(_route(strip.find_child("CastleArms", true, false), "strip_company"), "%s/tavern strip_company" % tag)
		_ok(_route(strip.find_child("HireFocusArms", true, false), "tavern_focus"), "%s/tavern tavern_focus" % tag)
		_ok(_route(strip.find_child("TavernBanner", true, false), "tavern_banner"), "%s/tavern tavern_banner" % tag)
	page.queue_free()
	await _settle(2)


func _assert_atlas(tag: String) -> void:
	_boot()
	var page := _open(ATLAS)
	await _settle(14)
	if page.has_method("apply_mobile_layout") and tag.begins_with("mob"):
		page.call("apply_mobile_layout")
		await _settle(8)
	var tok := page.find_child("PartyToken", true, false) as Control
	_ok(tok != null, "%s/atlas PartyToken" % tag)
	_ok(_route(tok, "atlas_party_token"), "%s/atlas atlas_party_token" % tag)
	if tok != null:
		var arms := tok.find_child("TokenArms", true, false)
		_ok(_route(arms, "atlas_party"), "%s/atlas atlas_party" % tag)
		_ok(arms != null and str(arms.get_meta("arms_kind", "")) == "gen2_36", "%s/atlas TokenArms 团徽" % tag)
		# Glyph label hidden under company arms.
		for c in tok.get_children():
			if c is Label:
				_ok(not (c as CanvasItem).visible, "%s/atlas PartyToken label hidden" % tag)
	page.queue_free()
	await _settle(2)


func _assert_battle(tag: String) -> void:
	_boot()
	GameState.set_meta("battle_foe_nation", "ashbanner")
	GameState.set_meta("battle_map", "ch0_pass")
	var page := _open(BATTLE)
	await _settle(16)
	if page.has_method("apply_mobile_layout") and tag.begins_with("mob"):
		page.call("apply_mobile_layout")
		await _settle(8)
	var order := page.find_child("BattleOrderCrest", true, false) as Control
	_ok(_route(order, "battle_order"), "%s/battle battle_order" % tag)
	if order != null:
		_ok(_route(order.find_child("CastleArms", true, false), "strip_company"), "%s/battle order strip_company" % tag)
		var chip0 := order.find_child("OrderChip0", true, false)
		_ok(_route(chip0, "battle_order_chip"), "%s/battle battle_order_chip" % tag)

	# Forecast panel arms (Field pin).
	ForecastPanel.attach(page)
	await _settle(4)
	var lead: CKCharacter = GameState.get_leader()
	var panel := page.get_node_or_null("ForecastPanel") as Control
	_ok(panel != null, "%s/battle ForecastPanel" % tag)
	if panel != null:
		CKHeraldryField.pin_forecast_arms(panel, lead, "player", "ashbanner")
		await _settle(2)
		_ok(_route(panel.get_node_or_null("ForecastOursArms"), "forecast_ours"), "%s/battle forecast_ours" % tag)
		_ok(_route(panel.get_node_or_null("ForecastFoeArms"), "forecast_foe"), "%s/battle forecast_foe" % tag)

	# Report crest strip + row arms (Field place/attach on the live battle host).
	var rep := CKHeraldryField.place_report_crest_strip(page, Vector2(700, 12), "ashbanner", Vector2(36, 44))
	_ok(_route(rep, "report_strip"), "%s/battle report_strip" % tag)
	if rep != null:
		_ok(_route(rep.find_child("CastleArms", true, false), "strip_company"), "%s/battle report strip_company" % tag)
		_ok(_route(rep.find_child("FoeArms", true, false), "report_foe"), "%s/battle report_foe" % tag)
	if lead != null:
		var row := CKHeraldryField.attach_report_row_arms(page, lead, Vector2(60, 80), Vector2(22, 26))
		_ok(_route(row, "report_row"), "%s/battle report_row" % tag)

	if GameState.has_meta("battle_foe_nation"):
		GameState.remove_meta("battle_foe_nation")
	page.queue_free()
	await _settle(2)


func _run_pass(tag: String) -> void:
	await _assert_castle_hub(tag)
	await _assert_castle_view(tag)
	await _assert_tavern(tag)
	await _assert_atlas(tag)
	await _assert_battle(tag)


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
		"castle_hub_banner", "tavern_banner", "atlas_party", "atlas_party_token",
		"banner_plate", "strip_company", "battle_order", "battle_order_chip",
		"report_strip", "report_foe", "report_row", "forecast_ours", "forecast_foe",
		"castle_view_banner", "tavern_focus",
	]:
		var lit := field.find('set_meta("field_route", "%s")' % route) >= 0
		var arg := field.find('"%s"' % route) >= 0
		_ok(lit or arg, "field source route %s" % route)
	var hubs := {
		"castle_hub": "res://scripts/hub/castle_hub.gd",
		"castle_view": "res://scripts/hub/castle_view.gd",
		"tavern": "res://scripts/hub/tavern.gd",
		"atlas_view": "res://scripts/hub/atlas_view.gd",
		"battle_controller": "res://scripts/battle/battle_controller.gd",
		"battle_report": "res://scripts/battle/ui/battle_report.gd",
		"forecast_panel": "res://scripts/battle/ui/forecast_panel.gd",
	}
	for hub in hubs.keys():
		var src := FileAccess.get_file_as_string(hubs[hub])
		_ok(src.find("CKHeraldryField.") >= 0, "%s wires Field" % hub)
	var atlas := FileAccess.get_file_as_string("res://scripts/hub/atlas_view.gd")
	_ok(atlas.find("attach_party_token_arms") >= 0, "atlas_view attaches party token arms")
