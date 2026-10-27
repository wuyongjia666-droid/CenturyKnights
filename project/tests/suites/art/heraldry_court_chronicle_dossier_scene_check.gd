extends Node
## Fat heraldry wave-4 E2E: court gazette / yearcard / blood / skill / rival /
## dossier yeartrace+purse child field_route ownership — desk + mobile.
## Real scenes; no EmptyHost.

const COURT := "res://scenes/hub/court_news.tscn"
const YEARCARD := "res://scenes/hub/sui_yearcard.tscn"
const BLOOD := "res://scenes/hub/blood_test.tscn"
const SKILL := "res://scenes/hub/skill_tree.tscn"
const RIVAL := "res://scenes/hub/rival_houses.tscn"
const DOSSIER := "res://scenes/hub/unit_dossier.tscn"

var _fails: Array = []


func _ready() -> void:
	await get_tree().process_frame
	await _run_desktop()
	await _run_mobile()
	_source_contracts()
	if _fails.is_empty():
		print("HERALDRY COURT CHRONICLE DOSSIER SCENE PASS")
		get_tree().quit(0)
	else:
		for f in _fails:
			print("FAIL heraldry court chronicle dossier scene: ", f)
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


func _seed_news() -> void:
	var nid := World.nation_of(str(World.pos))
	if nid == "":
		nid = "ashbanner"
	if typeof(World.get("royal_courts")) != TYPE_DICTIONARY:
		World.royal_courts = {"nations": {}}
	var nations: Dictionary = World.royal_courts.get("nations", {})
	if typeof(nations) != TYPE_DICTIONARY:
		nations = {}
	var house: Dictionary = nations.get(nid, {})
	if typeof(house) != TYPE_DICTIONARY:
		house = {}
	var log: Array = house.get("log", [])
	if typeof(log) != TYPE_ARRAY:
		log = []
	log.append({
		"year": int(Calendar.year),
		"kind": "birth",
		"text": "wave4 seed birth under %s" % nid,
	})
	house["log"] = log
	nations[nid] = house
	World.royal_courts["nations"] = nations


func _boot(rivals: bool = false) -> void:
	GameState.new_game("朝岁血技敌档", "霜旗", GameState.crest_color)
	GameState.chapter0_flags["chapter0_done"] = true
	GameState.chapter0_flags["ch0_playing"] = false
	GameState.set_flag("chapter0_done", true)
	UnlockSchedule.install()
	World.events_enabled = false
	World.rivals_enabled = rivals
	GameState.silver = 9000
	GameState.food = 40
	GameState.iron = 40
	GameState.skill_points = 3
	World.pos = "ash_capital"
	World.arrive("ash_capital")
	_seed_news()
	var lead: CKCharacter = GameState.get_leader()
	if lead != null:
		lead.rank = "baron"
		CKPurse.set_purse(lead, 11)
		GameState.set_meta("dossier_id", lead.id)
	GameState.set_meta("dossier_back", "res://scenes/hub/estates.tscn")
	# Yearcard inbox seed
	var cid := str(lead.id) if lead != null else ""
	GameState.house_mods["sui_inbox"] = [{
		"cid": cid,
		"id": "wave4_year_seed",
		"band": "sui",
		"title": "wave4 seed",
		"body": "crest e2e",
		"side": "left",
		"outcome": "ok",
	}]
	for c in GameState.characters.values():
		if c.alive:
			c.blood_meta["verified"] = false


func _open(path: String) -> Control:
	var page: Control = (load(path) as PackedScene).instantiate()
	page.set_anchors_preset(Control.PRESET_TOP_LEFT)
	page.position = Vector2.ZERO
	page.size = Vector2(1280, 720)
	get_tree().root.add_child(page)
	return page


func _assert_court(tag: String) -> void:
	_boot(false)
	var page := _open(COURT)
	await _settle(14)
	if page.has_method("apply_mobile_layout") and tag.begins_with("mob"):
		page.call("apply_mobile_layout")
		await _settle(8)
	var gaz := page.find_child("GazetteCrestStrip", true, false)
	_ok(_route(gaz, "gazette_strip"), "%s/court gazette_strip" % tag)
	if gaz != null:
		_ok(_route(gaz.find_child("CastleArms", true, false), "strip_company"), "%s/court strip_company" % tag)
		_ok(_route(gaz.find_child("GazetteNationArms", true, false), "gazette_nation"), "%s/court gazette_nation" % tag)
	var list := page.find_child("NewsRows", true, false)
	if list != null:
		var row_arms := list.find_child("GazetteNationArms", true, false)
		_ok(_route(row_arms, "news_row"), "%s/court news_row" % tag)
	else:
		_ok(false, "%s/court NewsRows" % tag)
	page.queue_free()
	await _settle(2)


func _assert_yearcard(tag: String) -> void:
	_boot(false)
	var page := _open(YEARCARD)
	await _settle(14)
	if page.has_method("apply_mobile_layout") and tag.begins_with("mob"):
		page.call("apply_mobile_layout")
		await _settle(8)
	var yhead := page.find_child("YearArmsHead", true, false)
	_ok(_route(yhead, "yearcard_row"), "%s/yearcard yearcard_row" % tag)
	var ya := page.find_child("YearArms", true, false)
	_ok(_route(ya, "yearcard_arms"), "%s/yearcard yearcard_arms" % tag)
	page.queue_free()
	await _settle(2)


func _assert_blood(tag: String) -> void:
	_boot(false)
	var page := _open(BLOOD)
	await _settle(12)
	if page.has_method("apply_mobile_layout") and tag.begins_with("mob"):
		page.call("apply_mobile_layout")
		await _settle(6)
	var bd := page.find_child("BloodCrestStrip", true, false)
	_ok(_route(bd, "blood_strip"), "%s/blood blood_strip" % tag)
	if bd != null:
		_ok(_route(bd.find_child("CastleArms", true, false), "strip_company"), "%s/blood strip_company" % tag)
		_ok(_route(bd.find_child("BloodBanner", true, false), "blood_banner"), "%s/blood blood_banner" % tag)
	var qarms := page.find_child("BloodQueueArms", true, false)
	_ok(_route(qarms, "blood_queue"), "%s/blood blood_queue" % tag)
	page.queue_free()
	await _settle(2)


func _assert_skill(tag: String) -> void:
	_boot(false)
	var page := _open(SKILL)
	await _settle(12)
	if page.has_method("apply_mobile_layout") and tag.begins_with("mob"):
		page.call("apply_mobile_layout")
		await _settle(6)
	var sk := page.find_child("SkillCrestStrip", true, false)
	_ok(_route(sk, "skill_strip"), "%s/skill skill_strip" % tag)
	if sk != null:
		_ok(_route(sk.find_child("CastleArms", true, false), "strip_company"), "%s/skill strip_company" % tag)
		_ok(_route(sk.find_child("SkillBanner", true, false), "skill_banner"), "%s/skill skill_banner" % tag)
	var spa := page.find_child("SkillPersonArms", true, false)
	_ok(_route(spa, "skill_person"), "%s/skill skill_person" % tag)
	page.queue_free()
	await _settle(2)


func _assert_rival(tag: String) -> void:
	_boot(true)
	var page := _open(RIVAL)
	await _settle(14)
	if page.has_method("apply_mobile_layout") and tag.begins_with("mob"):
		page.call("apply_mobile_layout")
		await _settle(8)
	var houses: Array = GameState.data_rivals.get("houses", []) if typeof(GameState.data_rivals) == TYPE_DICTIONARY else []
	_ok(not houses.is_empty(), "%s/rival houses exist" % tag)
	if not houses.is_empty():
		var hid := str(houses[0].get("id", ""))
		var btn := page.find_child("House_%s" % hid, true, false)
		_ok(btn != null, "%s/rival House_%s" % [tag, hid])
		if btn != null:
			_ok(_route(btn.find_child("RivalArms", true, false), "rival_arms"), "%s/rival rival_arms" % tag)
	page.queue_free()
	await _settle(2)


func _assert_dossier(tag: String) -> void:
	_boot(false)
	var page := _open(DOSSIER)
	await _settle(16)
	if page.has_method("apply_mobile_layout") and tag.begins_with("mob"):
		page.call("apply_mobile_layout")
		await _settle(8)
	var yt := page.find_child("YeartracePanel", true, false)
	_ok(yt != null, "%s/dossier YeartracePanel" % tag)
	if yt != null:
		_ok(_route(yt.find_child("YeartraceArmsHead", true, false), "yeartrace"), "%s/dossier yeartrace" % tag)
		_ok(_route(yt.find_child("YeartraceArms", true, false), "yeartrace_arms"), "%s/dossier yeartrace_arms" % tag)
	var purse := page.find_child("PursePlate", true, false)
	_ok(_route(purse, "purse_plate"), "%s/dossier purse_plate" % tag)
	if purse != null:
		_ok(_route(purse.find_child("PurseArms", true, false), "purse_arms"), "%s/dossier purse_arms" % tag)
	var chips: Array = []
	for n in page.find_children("ChipArms", "", true, false):
		if str(n.get_meta("field_route", "")) == "dossier_chip":
			chips.append(n)
	_ok(chips.size() >= 1, "%s/dossier dossier_chip count>=1 got %d" % [tag, chips.size()])
	page.queue_free()
	await _settle(2)


func _run_pass(tag: String) -> void:
	await _assert_court(tag)
	await _assert_yearcard(tag)
	await _assert_blood(tag)
	await _assert_skill(tag)
	await _assert_rival(tag)
	await _assert_dossier(tag)


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
		"gazette_strip", "gazette_nation", "news_row",
		"yearcard_row", "yearcard_arms",
		"yeartrace", "yeartrace_arms",
		"purse_plate", "purse_arms",
		"blood_strip", "blood_banner", "blood_queue",
		"skill_strip", "skill_banner", "skill_person",
		"rival_arms", "dossier_chip", "dossier_chip_badge", "dossier_crest",
		"strip_company",
	]:
		var lit := field.find('set_meta("field_route", "%s")' % route) >= 0
		var arg := field.find('"%s"' % route) >= 0
		_ok(lit or arg, "field source route %s" % route)
	var hubs := {
		"court_news": "res://scripts/hub/court_news.gd",
		"sui_yearcard": "res://scripts/hub/sui_yearcard.gd",
		"blood_test": "res://scripts/hub/blood_test.gd",
		"skill_tree": "res://scripts/hub/skill_tree.gd",
		"rival_houses": "res://scripts/hub/rival_houses.gd",
		"unit_dossier": "res://scripts/hub/unit_dossier.gd",
		"sui_yeartrace_ui": "res://scripts/hub/sui_yeartrace_ui.gd",
	}
	for hub in hubs.keys():
		var src := FileAccess.get_file_as_string(hubs[hub])
		_ok(src.find("CKHeraldryField.") >= 0, "%s wires Field" % hub)
