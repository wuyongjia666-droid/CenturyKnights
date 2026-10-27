extends Node
## Fat heraldry wave-13 E2E: MarketCrestStrip / SkillCrestStrip / TavernCrestStrip
## — _cloth_beside Field cloth + arms_kind ownership — desk + mobile.
## Real market / skill_tree / tavern; no EmptyHost (filled tavern only).

const MARKET := "res://scenes/hub/market.tscn"
const SKILL := "res://scenes/hub/skill_tree.tscn"
const TAVERN := "res://scenes/hub/tavern.tscn"

var _fails: Array = []


func _ready() -> void:
	await get_tree().process_frame
	await _run_helpers()
	await _run_desktop()
	await _run_mobile()
	_source_contracts()
	if _fails.is_empty():
		print("HERALDRY MARKET SKILL TAVERN SCENE PASS")
		get_tree().quit(0)
	else:
		for f in _fails:
			print("FAIL heraldry market skill tavern scene: ", f)
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
	GameState.new_game("市技酒馆旗学徽", "灰旗", GameState.crest_color)
	GameState.set_flag("chapter0_done", true)
	UnlockSchedule.install()
	World.events_enabled = false
	World.rivals_enabled = false
	GameState.food = 40
	GameState.iron = 40
	GameState.silver = 8000
	GameState.morale = 80
	GameState.skill_points = 3
	World.pos = "ash_capital"
	World.arrive("ash_capital")
	World.travel = {}
	World.pending_event = {}
	World.encounter = {}
	World.active.clear()
	var lead: CKCharacter = GameState.get_leader()
	var kin := CKCharacter.new()
	kin.id = "mst_tavern_kin"
	kin.name = "族聘"
	kin.age = 24
	kin.alive = true
	kin.in_roster = false
	kin.family_id = str(lead.family_id)
	kin.job_id = "light_inf"
	kin.rank = "knight"
	GameState.tavern_candidates = [kin]


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
	var mk := CKHeraldryField.place_market_crest_strip(host, Vector2(8, 8))
	_ok(mk != null and mk.name == "MarketCrestStrip", "helper MarketCrestStrip")
	_ok(mk != null and mk.get_child_count() == 2, "helper market child_count=2")
	var mbn := mk.find_child("MarketBanner", true, false) if mk else null
	_ok(_route(mbn, "market_banner"), "helper market_banner")
	_ok(mbn != null and str(mbn.get_meta("arms_kind", "")) == "lb_market_arms", "helper market kind")
	var sk := CKHeraldryField.place_skill_crest_strip(host, Vector2(200, 8))
	_ok(sk != null and sk.name == "SkillCrestStrip", "helper SkillCrestStrip")
	_ok(sk != null and sk.get_child_count() == 2, "helper skill child_count=2")
	var sbn := sk.find_child("SkillBanner", true, false) if sk else null
	_ok(_route(sbn, "skill_banner"), "helper skill_banner")
	_ok(sbn != null and str(sbn.get_meta("arms_kind", "")) == "lb_skill_arms", "helper skill kind")
	var lead: CKCharacter = GameState.get_leader()
	var tv := CKHeraldryField.place_tavern_crest_strip(host, lead, Vector2(400, 8))
	_ok(tv != null and tv.name == "TavernCrestStrip", "helper TavernCrestStrip")
	_ok(tv != null and tv.get_child_count() == 3, "helper tavern child_count=3")
	var tbn := tv.find_child("TavernBanner", true, false) if tv else null
	_ok(_route(tbn, "tavern_banner"), "helper tavern_banner")
	_ok(tbn != null and str(tbn.get_meta("arms_kind", "")) == "lb_tavern_arms", "helper tavern kind")
	_ok(tbn != null and str(tbn.tooltip_text).find("城堡") < 0, "helper tavern not castle_view tip")
	host.queue_free()
	await _settle(2)


func _assert_market(tag: String) -> void:
	_boot()
	var page := _open(MARKET)
	await _settle(12)
	if page.has_method("apply_mobile_layout") and tag.begins_with("mob"):
		page.call("apply_mobile_layout")
		await _settle(6)
	var strip := page.find_child("MarketCrestStrip", true, false)
	_ok(_route(strip, "market_strip"), "%s/market market_strip" % tag)
	if strip != null:
		_ok(_route(strip.find_child("CastleArms", true, false), "strip_company"), "%s/market strip_company" % tag)
		var bn := strip.find_child("MarketBanner", true, false)
		_ok(_route(bn, "market_banner"), "%s/market market_banner" % tag)
		_ok(bn != null and str(bn.get_meta("arms_kind", "")) == "lb_market_arms", "%s/market MarketBanner kind" % tag)
		_ok(strip.get_child_count() == 2, "%s/market child_count=2" % tag)
	page.queue_free()
	await _settle(2)


func _assert_skill(tag: String) -> void:
	_boot()
	var page := _open(SKILL)
	await _settle(12)
	if page.has_method("apply_mobile_layout") and tag.begins_with("mob"):
		page.call("apply_mobile_layout")
		await _settle(6)
	var strip := page.find_child("SkillCrestStrip", true, false)
	_ok(_route(strip, "skill_strip"), "%s/skill skill_strip" % tag)
	if strip != null:
		_ok(_route(strip.find_child("CastleArms", true, false), "strip_company"), "%s/skill strip_company" % tag)
		var bn := strip.find_child("SkillBanner", true, false)
		_ok(_route(bn, "skill_banner"), "%s/skill skill_banner" % tag)
		_ok(bn != null and str(bn.get_meta("arms_kind", "")) == "lb_skill_arms", "%s/skill SkillBanner kind" % tag)
		_ok(strip.get_child_count() == 2, "%s/skill child_count=2" % tag)
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
		var bn := strip.find_child("TavernBanner", true, false)
		_ok(_route(bn, "tavern_banner"), "%s/tavern tavern_banner" % tag)
		_ok(bn != null and str(bn.get_meta("arms_kind", "")) == "lb_tavern_arms", "%s/tavern TavernBanner kind" % tag)
		_ok(strip.get_child_count() == 3, "%s/tavern child_count=3" % tag)
	_ok(page.find_child("EmptyHost", true, false) == null, "%s/tavern filled no EmptyHost" % tag)
	page.queue_free()
	await _settle(2)


func _run_pass(tag: String) -> void:
	await _assert_market(tag)
	await _assert_skill(tag)
	await _assert_tavern(tag)


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
		"market_strip", "market_banner",
		"skill_strip", "skill_banner",
		"tavern_strip", "tavern_banner", "tavern_focus",
		"strip_company",
	]:
		var lit := field.find('set_meta("field_route", "%s")' % route) >= 0
		var arg := field.find('"%s"' % route) >= 0
		_ok(lit or arg, "field source route %s" % route)
	_ok(field.find('_cloth_beside(host, shield, "MarketBanner"') >= 0, "field market via _cloth_beside")
	_ok(field.find('_cloth_beside(host, shield, "SkillBanner"') >= 0, "field skill via _cloth_beside")
	_ok(field.find('_cloth_beside(host, shield, "TavernBanner"') >= 0, "field tavern via _cloth_beside")
	_ok(field.find('"lb_market_arms"') >= 0, "field lb_market_arms")
	_ok(field.find('"lb_skill_arms"') >= 0, "field lb_skill_arms")
	_ok(field.find('"lb_tavern_arms"') >= 0, "field lb_tavern_arms")
	_ok(field.find('Locale.t("lb_castle_view_arms")') < 0
			or field.find('tavern_banner", "lb_castle_view') < 0, "tavern no fake castle_view tip")
	# Tavern cloth must not still hardcode castle_view tip on the banner block.
	_ok(field.find('bn.set_meta("field_route", "tavern_banner")') < 0, "tavern banner not manual")
	var mk := FileAccess.get_file_as_string("res://scripts/hub/market.gd")
	_ok(mk.find("CKHeraldryField.place_market_crest_strip") >= 0
			or mk.find("CKHeraldryChrome.place_market_crest_strip") >= 0, "market wires Field")
	var sk := FileAccess.get_file_as_string("res://scripts/hub/skill_tree.gd")
	_ok(sk.find("CKHeraldryField.place_skill_crest_strip") >= 0
			or sk.find("CKHeraldryChrome.place_skill_crest_strip") >= 0, "skill_tree wires Field")
	var tv := FileAccess.get_file_as_string("res://scripts/hub/tavern.gd")
	_ok(tv.find("CKHeraldryField.place_tavern_crest_strip") >= 0
			or tv.find("CKHeraldryChrome.place_tavern_crest_strip") >= 0, "tavern wires Field")
	var loc := FileAccess.get_file_as_string("res://data/locale/lineb.csv")
	_ok(loc.find("lb_market_arms,") >= 0, "locale lb_market_arms")
	_ok(loc.find("lb_skill_arms,") >= 0, "locale lb_skill_arms")
	_ok(loc.find("lb_tavern_arms,") >= 0, "locale lb_tavern_arms")
