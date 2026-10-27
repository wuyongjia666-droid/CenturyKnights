extends Node
## Fat heraldry E2E: CityCrestStrip / NationCrestStrip / GazetteCrestStrip
## — strip_company + cloth banner child field_route ownership — desk + mobile.
## Real city / bloodline_codex / court_news scenes; no EmptyHost.

const CITY_SCN := "res://scenes/hub/city.tscn"
const CODEX_SCN := "res://scenes/hub/bloodline_codex.tscn"
const NEWS_SCN := "res://scenes/hub/court_news.tscn"

var _fails: Array = []


func _ready() -> void:
	await get_tree().process_frame
	await _run_helpers()
	await _run_desktop()
	await _run_mobile()
	_source_contracts()
	if _fails.is_empty():
		print("HERALDRY CITY NATION GAZETTE SCENE PASS")
		get_tree().quit(0)
	else:
		for f in _fails:
			print("FAIL heraldry city nation gazette scene: ", f)
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


func _boot_city(cid: String = "ash_capital") -> void:
	GameState.new_game("城邦朝报旗学徽", "灰旗", GameState.crest_color)
	GameState.set_flag("chapter0_done", true)
	UnlockSchedule.install()
	World.events_enabled = false
	World.rivals_enabled = false
	for nid in World.nations.keys():
		World.rep_nation[str(nid)] = 50
	GameState.food = 40
	GameState.silver = 8000
	GameState.morale = 80
	World.pos = cid
	World.arrive(cid)
	GameState.set_meta("city_id", cid)


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
		"text": "suite seed birth under %s" % nid,
	})
	house["log"] = log
	nations[nid] = house
	World.royal_courts["nations"] = nations


func _open(path: String) -> Control:
	var page: Control = (load(path) as PackedScene).instantiate()
	page.set_anchors_preset(Control.PRESET_TOP_LEFT)
	page.position = Vector2.ZERO
	page.size = Vector2(1280, 720)
	get_tree().root.add_child(page)
	return page


func _run_helpers() -> void:
	_boot_city()
	var host := Control.new()
	add_child(host)
	var city := CKHeraldryField.place_city_crest_strip(host, "ash_capital", Vector2(8, 8))
	_ok(city != null and city.name == "CityCrestStrip", "helper CityCrestStrip")
	_ok(city != null and city.get_child_count() == 3, "helper city child_count=3")
	_ok(_route(city.find_child("CityBanner", true, false) if city else null, "city_banner"), "helper city_banner")
	var nid := World.nation_of("ash_capital")
	if nid == "":
		nid = "ashbanner"
	var nat := CKHeraldryField.place_nation_crest_strip(host, nid, Vector2(200, 8))
	_ok(nat != null and nat.name == "NationCrestStrip", "helper NationCrestStrip")
	_ok(nat != null and nat.get_child_count() == 3, "helper nation child_count=3")
	_ok(_route(nat.find_child("NationBanner", true, false) if nat else null, "nation_banner"), "helper nation_banner")
	var natbn := nat.find_child("NationBanner", true, false) if nat else null
	_ok(natbn != null and str(natbn.get_meta("arms_kind", "")) == "lb_nation_arms", "helper nation kind")
	var gaz := CKHeraldryField.place_gazette_crest_strip(host, nid, Vector2(400, 8))
	_ok(gaz != null and gaz.name == "GazetteCrestStrip", "helper GazetteCrestStrip")
	_ok(gaz != null and gaz.get_child_count() == 3, "helper gazette child_count=3")
	_ok(_route(gaz.find_child("GazetteBanner", true, false) if gaz else null, "gazette_banner"), "helper gazette_banner")
	host.queue_free()
	await _settle(2)


func _assert_city(tag: String) -> void:
	_boot_city()
	var page := _open(CITY_SCN)
	await _settle(12)
	if page.has_method("apply_mobile_layout") and tag.begins_with("mob"):
		page.call("apply_mobile_layout")
		await _settle(8)
	var strip: Node = null
	for n in page.find_children("CityCrestStrip", "", true, false):
		if str(n.get_meta("field_route", "")) == "city_strip":
			strip = n
			break
	if strip == null:
		strip = page.find_child("CityCrestStrip", true, false)
	_ok(_route(strip, "city_strip"), "%s/city city_strip" % tag)
	if strip != null:
		_ok(_route(strip.find_child("CastleArms", true, false), "strip_company"), "%s/city strip_company" % tag)
		_ok(_route(strip.find_child("CityNationArms", true, false), "city_nation"), "%s/city city_nation" % tag)
		_ok(_route(strip.find_child("CityBanner", true, false), "city_banner"), "%s/city city_banner" % tag)
		_ok(strip.get_child_count() == 3, "%s/city child_count=3" % tag)
	page.queue_free()
	await _settle(2)


func _assert_nation(tag: String) -> void:
	_boot_city()
	var nid := World.nation_of("ash_capital")
	if nid == "":
		nid = "ashbanner"
	var page := _open(CODEX_SCN)
	await _settle(12)
	if page.has_method("apply_mobile_layout") and tag.begins_with("mob"):
		page.call("apply_mobile_layout")
		await _settle(8)
	var strip := page.find_child("NationCrestStrip", true, false)
	_ok(_route(strip, "nation_strip"), "%s/nation nation_strip" % tag)
	if strip != null:
		_ok(_route(strip.find_child("CastleArms", true, false), "strip_company"), "%s/nation strip_company" % tag)
		_ok(_route(strip.find_child("CityNationArms", true, false), "nation_arms"), "%s/nation nation_arms" % tag)
		_ok(_route(strip.find_child("NationBanner", true, false), "nation_banner"), "%s/nation nation_banner" % tag)
		var natbn := strip.find_child("NationBanner", true, false)
		_ok(natbn != null and str(natbn.get_meta("arms_kind", "")) == "lb_nation_arms", "%s/nation NationBanner kind" % tag)
		_ok(strip.get_child_count() == 3, "%s/nation child_count=3" % tag)
	page.queue_free()
	await _settle(2)


func _assert_gazette(tag: String) -> void:
	_boot_city()
	_seed_news()
	var page := _open(NEWS_SCN)
	await _settle(12)
	if page.has_method("apply_mobile_layout") and tag.begins_with("mob"):
		page.call("apply_mobile_layout")
		await _settle(8)
	var gaz := page.find_child("GazetteCrestStrip", true, false)
	_ok(_route(gaz, "gazette_strip"), "%s/gazette gazette_strip" % tag)
	if gaz != null:
		_ok(_route(gaz.find_child("CastleArms", true, false), "strip_company"), "%s/gazette strip_company" % tag)
		_ok(_route(gaz.find_child("GazetteNationArms", true, false), "gazette_nation"), "%s/gazette gazette_nation" % tag)
		_ok(_route(gaz.find_child("GazetteBanner", true, false), "gazette_banner"), "%s/gazette gazette_banner" % tag)
		_ok(gaz.get_child_count() == 3, "%s/gazette child_count=3" % tag)
	page.queue_free()
	await _settle(2)


func _run_pass(tag: String) -> void:
	await _assert_city(tag)
	await _assert_nation(tag)
	await _assert_gazette(tag)


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
		"city_strip", "city_nation", "city_banner",
		"nation_strip", "nation_arms", "nation_banner",
		"gazette_strip", "gazette_nation", "gazette_banner",
		"strip_company",
	]:
		var lit := field.find('set_meta("field_route", "%s")' % route) >= 0
		var arg := field.find('"%s"' % route) >= 0
		_ok(lit or arg, "field source route %s" % route)
	var city := FileAccess.get_file_as_string("res://scripts/hub/city.gd")
	_ok(city.find("CKHeraldryField.place_city_crest_strip") >= 0, "city wires Field")
	var codex := FileAccess.get_file_as_string("res://scripts/hub/bloodline_codex.gd")
	_ok(codex.find("CKHeraldryField.place_nation_crest_strip") >= 0, "codex wires Field")
	var news := FileAccess.get_file_as_string("res://scripts/hub/court_news.gd")
	_ok(news.find("CKHeraldryField.place_gazette_crest_strip") >= 0, "court_news wires Field")
	_ok(field.find('"lb_nation_arms"') >= 0, "field lb_nation_arms")
	var loc := FileAccess.get_file_as_string("res://data/locale/lineb.csv")
	_ok(loc.find("lb_nation_arms,") >= 0, "locale lb_nation_arms")
