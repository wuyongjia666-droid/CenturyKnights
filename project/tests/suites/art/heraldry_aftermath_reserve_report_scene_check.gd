extends Node
## Fat heraldry wave-10 E2E: AftermathCrestStrip / ReserveCrestStrip / ReportCrestStrip
## — strip_company + cloth banner child field_route ownership — desk + mobile.
## Real atlas_view / deploy / BattleReport.present; no EmptyHost.

const ATLAS := "res://scenes/hub/atlas_view.tscn"
const DEPLOY := "res://scenes/hub/deploy.tscn"

var _fails: Array = []


func _ready() -> void:
	await get_tree().process_frame
	await _run_helpers()
	await _run_desktop()
	await _run_mobile()
	_source_contracts()
	if _fails.is_empty():
		print("HERALDRY AFTERMATH RESERVE REPORT SCENE PASS")
		get_tree().quit(0)
	else:
		for f in _fails:
			print("FAIL heraldry aftermath reserve report scene: ", f)
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
	GameState.new_game("战后预备战报旗学徽", "灰旗", GameState.crest_color)
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
	World.last_aftermath.clear()
	World.last_battle_aftermath.clear()
	if GameState.has_meta("battle_foe_nation"):
		GameState.remove_meta("battle_foe_nation")


func _seed_reserve() -> CKCharacter:
	var lead: CKCharacter = GameState.get_leader()
	if lead != null and not (lead.id in GameState.deploy_ids):
		GameState.deploy_ids = [lead.id]
	var bench := CKCharacter.new()
	bench.id = "reserve_kin_w10"
	bench.name = "候旗"
	bench.age = 23
	bench.alive = true
	bench.in_roster = true
	bench.is_leader = false
	bench.family_id = str(lead.family_id) if lead else ""
	bench.job_id = "light_inf"
	bench.rank = "knight"
	bench.gender = "m"
	GameState.characters[bench.id] = bench
	GameState.buildings["hall"] = 4
	GameState.house_mods["reserve_id"] = bench.id
	return bench


func _open(path: String) -> Control:
	var page: Control = (load(path) as PackedScene).instantiate()
	page.set_anchors_preset(Control.PRESET_TOP_LEFT)
	page.position = Vector2.ZERO
	page.size = Vector2(1280, 720)
	get_tree().root.add_child(page)
	return page


func _run_helpers() -> void:
	_boot()
	var lead: CKCharacter = GameState.get_leader()
	var host := Control.new()
	add_child(host)
	var aft := CKHeraldryField.place_aftermath_crest_strip(host, Vector2(8, 8), "ashbanner")
	_ok(aft != null and aft.name == "AftermathCrestStrip", "helper AftermathCrestStrip")
	_ok(aft != null and aft.get_child_count() == 3, "helper aftermath child_count=3")
	_ok(_route(aft.find_child("AftermathBanner", true, false) if aft else null, "aftermath_banner"), "helper aftermath_banner")
	var res := CKHeraldryField.place_reserve_crest_strip(host, lead, Vector2(200, 8))
	_ok(res != null and res.name == "ReserveCrestStrip", "helper ReserveCrestStrip")
	_ok(res != null and res.get_child_count() == 3, "helper reserve child_count=3")
	_ok(_route(res.find_child("ReserveBanner", true, false) if res else null, "reserve_banner"), "helper reserve_banner")
	var rep := CKHeraldryField.place_report_crest_strip(host, Vector2(400, 8), "ashbanner")
	_ok(rep != null and rep.name == "ReportCrestStrip", "helper ReportCrestStrip")
	_ok(rep != null and rep.get_child_count() == 3, "helper report child_count=3")
	_ok(_route(rep.find_child("ReportBanner", true, false) if rep else null, "report_banner"), "helper report_banner")
	host.queue_free()
	await _settle(2)


func _assert_aftermath(tag: String) -> void:
	_boot()
	World.cancel_travel()
	World.pos = "ash_capital"
	World.arrive("ash_capital")
	World.begin_travel("fog_vale")
	var enc: Dictionary = World.start_encounter("road", {"node": "hq", "from": "ash_capital", "danger": 2})
	var r: Dictionary = World.on_battle_end(true)
	var af: Dictionary = r.get("aftermath", {})
	_ok(str(af.get("nation", "")) != "", "%s/aftermath af.nation" % tag)
	var page := _open(ATLAS)
	await _settle(10)
	if page.has_method("apply_mobile_layout") and tag.begins_with("mob"):
		page.call("apply_mobile_layout")
		await _settle(6)
	page.call("_show_battle_aftermath_modal", af)
	await _settle(10)
	var strip := page.find_child("AftermathCrestStrip", true, false)
	_ok(_route(strip, "aftermath_strip"), "%s/aftermath aftermath_strip" % tag)
	if strip != null:
		_ok(_route(strip.find_child("CastleArms", true, false), "strip_company"), "%s/aftermath strip_company" % tag)
		_ok(_route(strip.find_child("FoeArms", true, false), "aftermath_foe"), "%s/aftermath aftermath_foe" % tag)
		_ok(_route(strip.find_child("AftermathBanner", true, false), "aftermath_banner"), "%s/aftermath aftermath_banner" % tag)
		_ok(strip.get_child_count() == 3, "%s/aftermath child_count=3" % tag)
	page.queue_free()
	await _settle(2)
	World.cancel_travel()


func _assert_reserve(tag: String) -> void:
	_boot()
	_seed_reserve()
	var page := _open(DEPLOY)
	await _settle(12)
	if page.has_method("apply_mobile_layout") and tag.begins_with("mob"):
		page.call("apply_mobile_layout")
		await _settle(8)
	var strip := page.find_child("ReserveCrestStrip", true, false)
	_ok(_route(strip, "reserve_strip"), "%s/reserve reserve_strip" % tag)
	if strip != null:
		_ok(_route(strip.find_child("CastleArms", true, false), "strip_company"), "%s/reserve strip_company" % tag)
		_ok(_route(strip.find_child("ReserveArms", true, false), "reserve_focus"), "%s/reserve reserve_focus" % tag)
		_ok(_route(strip.find_child("ReserveBanner", true, false), "reserve_banner"), "%s/reserve reserve_banner" % tag)
		_ok(strip.get_child_count() == 3, "%s/reserve child_count=3" % tag)
	page.queue_free()
	await _settle(2)


func _assert_report(tag: String) -> void:
	_boot()
	GameState.set_meta("battle_foe_nation", "ashbanner")
	var lead: CKCharacter = GameState.get_leader()
	var host := _ReportHost.new()
	host.units = [{"char": lead, "pos": Vector2i(0, 0), "team": "player", "done": false}]
	add_child(host)
	BattleReport.present(host, true, 12, 0, {lead.id: [lead.exp, false]})
	await _settle(6)
	var layer := host.get_node_or_null("ResultReport")
	_ok(layer != null, "%s/report ResultReport" % tag)
	var strip: Node = null
	if layer != null:
		strip = layer.find_child("ReportCrestStrip", true, false)
	_ok(_route(strip, "report_strip"), "%s/report report_strip" % tag)
	if strip != null:
		_ok(_route(strip.find_child("CastleArms", true, false), "strip_company"), "%s/report strip_company" % tag)
		_ok(_route(strip.find_child("FoeArms", true, false), "report_foe"), "%s/report report_foe" % tag)
		_ok(_route(strip.find_child("ReportBanner", true, false), "report_banner"), "%s/report report_banner" % tag)
		_ok(strip.get_child_count() == 3, "%s/report child_count=3" % tag)
	host.queue_free()
	await _settle(2)


func _run_pass(tag: String) -> void:
	await _assert_aftermath(tag)
	await _assert_reserve(tag)
	await _assert_report(tag)


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
		"aftermath_strip", "aftermath_foe", "aftermath_banner",
		"reserve_strip", "reserve_focus", "reserve_banner",
		"report_strip", "report_foe", "report_banner",
		"strip_company",
	]:
		var lit := field.find('set_meta("field_route", "%s")' % route) >= 0
		var arg := field.find('"%s"' % route) >= 0
		_ok(lit or arg, "field source route %s" % route)
	var atlas := FileAccess.get_file_as_string("res://scripts/hub/atlas_view.gd")
	_ok(atlas.find("CKHeraldryField.place_aftermath_crest_strip") >= 0
			or atlas.find("CKHeraldryChrome.place_aftermath_crest_strip") >= 0, "atlas wires aftermath Field")
	var deploy := FileAccess.get_file_as_string("res://scripts/hub/deploy.gd")
	_ok(deploy.find("CKHeraldryField.place_reserve_crest_strip") >= 0, "deploy wires reserve Field")
	var report := FileAccess.get_file_as_string("res://scripts/battle/ui/battle_report.gd")
	_ok(report.find("CKHeraldryField.place_report_crest_strip") >= 0, "battle_report wires Field")


class _ReportHost:
	extends Node
	var map_name := "Drill"
	var _round_no := 2
	var _world_enc := true
	var units: Array = []
