extends Node
## Fat heraldry wave-14 E2E: WorksCrestStrip / EstatesCrestStrip / AnnexCrestStrip
## — _cloth_beside Field cloth + arms_kind ownership — desk + mobile.
## Real works / estates / annex. Works/annex must not paint EmptyHost; estates may keep Y1-B month-echo EmptyHost.

const WORKS := "res://scenes/hub/works.tscn"
const ESTATES := "res://scenes/hub/estates.tscn"
const ANNEX := "res://scenes/hub/annex.tscn"

var _fails: Array = []


func _ready() -> void:
	await get_tree().process_frame
	await _run_helpers()
	await _run_desktop()
	await _run_mobile()
	_source_contracts()
	if _fails.is_empty():
		print("HERALDRY WORKS ESTATES ANNEX SCENE PASS")
		get_tree().quit(0)
	else:
		for f in _fails:
			print("FAIL heraldry works estates annex scene: ", f)
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
	GameState.new_game("工事属地附楼旗学徽", "灰旗", GameState.crest_color)
	GameState.set_flag("chapter0_done", true)
	UnlockSchedule.install()
	World.events_enabled = false
	World.rivals_enabled = false
	GameState.food = 40
	GameState.iron = 40
	GameState.silver = 8000
	GameState.morale = 80


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
	var wk := CKHeraldryField.place_works_crest_strip(host, Vector2(8, 8))
	_ok(wk != null and wk.name == "WorksCrestStrip", "helper WorksCrestStrip")
	_ok(wk != null and wk.get_child_count() == 2, "helper works child_count=2")
	var wbn := wk.find_child("WorksBanner", true, false) if wk else null
	_ok(_route(wbn, "works_banner"), "helper works_banner")
	_ok(wbn != null and str(wbn.get_meta("arms_kind", "")) == "lb_works_arms", "helper works kind")
	var es := CKHeraldryField.place_estates_crest_strip(host, Vector2(200, 8))
	_ok(es != null and es.name == "EstatesCrestStrip", "helper EstatesCrestStrip")
	_ok(es != null and es.get_child_count() == 2, "helper estates child_count=2")
	var ebn := es.find_child("EstatesBanner", true, false) if es else null
	_ok(_route(ebn, "estates_banner"), "helper estates_banner")
	_ok(ebn != null and str(ebn.get_meta("arms_kind", "")) == "lb_estates_arms", "helper estates kind")
	var ax := CKHeraldryField.place_annex_crest_strip(host, Vector2(400, 8))
	_ok(ax != null and ax.name == "AnnexCrestStrip", "helper AnnexCrestStrip")
	_ok(ax != null and ax.get_child_count() == 2, "helper annex child_count=2")
	var abn := ax.find_child("AnnexBanner", true, false) if ax else null
	_ok(_route(abn, "annex_banner"), "helper annex_banner")
	_ok(abn != null and str(abn.get_meta("arms_kind", "")) == "lb_annex_arms", "helper annex kind")
	host.queue_free()
	await _settle(2)


func _assert_works(tag: String) -> void:
	_boot()
	var page := _open(WORKS)
	await _settle(12)
	if page.has_method("apply_mobile_layout") and tag.begins_with("mob"):
		page.call("apply_mobile_layout")
		await _settle(6)
	var strip := page.find_child("WorksCrestStrip", true, false)
	_ok(_route(strip, "works_strip"), "%s/works works_strip" % tag)
	if strip != null:
		_ok(_route(strip.find_child("CastleArms", true, false), "strip_company"), "%s/works strip_company" % tag)
		var bn := strip.find_child("WorksBanner", true, false)
		_ok(_route(bn, "works_banner"), "%s/works works_banner" % tag)
		_ok(bn != null and str(bn.get_meta("arms_kind", "")) == "lb_works_arms", "%s/works WorksBanner kind" % tag)
		_ok(strip.get_child_count() == 2, "%s/works child_count=2" % tag)
	_ok(page.find_child("EmptyHost", true, false) == null, "%s/works no EmptyHost" % tag)
	page.queue_free()
	await _settle(2)


func _assert_estates(tag: String) -> void:
	_boot()
	var page := _open(ESTATES)
	await _settle(12)
	if page.has_method("apply_mobile_layout") and tag.begins_with("mob"):
		page.call("apply_mobile_layout")
		await _settle(6)
	var strip := page.find_child("EstatesCrestStrip", true, false)
	_ok(_route(strip, "estates_strip"), "%s/estates estates_strip" % tag)
	if strip != null:
		_ok(_route(strip.find_child("CastleArms", true, false), "strip_company"), "%s/estates strip_company" % tag)
		var bn := strip.find_child("EstatesBanner", true, false)
		_ok(_route(bn, "estates_banner"), "%s/estates estates_banner" % tag)
		_ok(bn != null and str(bn.get_meta("arms_kind", "")) == "lb_estates_arms", "%s/estates EstatesBanner kind" % tag)
		_ok(strip.get_child_count() == 2, "%s/estates child_count=2" % tag)
	page.queue_free()
	await _settle(2)


func _assert_annex(tag: String) -> void:
	_boot()
	var page := _open(ANNEX)
	await _settle(12)
	if page.has_method("apply_mobile_layout") and tag.begins_with("mob"):
		page.call("apply_mobile_layout")
		await _settle(6)
	var strip := page.find_child("AnnexCrestStrip", true, false)
	_ok(_route(strip, "annex_strip"), "%s/annex annex_strip" % tag)
	if strip != null:
		_ok(_route(strip.find_child("CastleArms", true, false), "strip_company"), "%s/annex strip_company" % tag)
		var bn := strip.find_child("AnnexBanner", true, false)
		_ok(_route(bn, "annex_banner"), "%s/annex annex_banner" % tag)
		_ok(bn != null and str(bn.get_meta("arms_kind", "")) == "lb_annex_arms", "%s/annex AnnexBanner kind" % tag)
		_ok(strip.get_child_count() == 2, "%s/annex child_count=2" % tag)
	_ok(page.find_child("EmptyHost", true, false) == null, "%s/annex no EmptyHost" % tag)
	page.queue_free()
	await _settle(2)


func _run_pass(tag: String) -> void:
	await _assert_works(tag)
	await _assert_estates(tag)
	await _assert_annex(tag)


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
		"works_strip", "works_banner",
		"estates_strip", "estates_banner",
		"annex_strip", "annex_banner",
		"strip_company",
	]:
		var lit := field.find('set_meta("field_route", "%s")' % route) >= 0
		var arg := field.find('"%s"' % route) >= 0
		_ok(lit or arg, "field source route %s" % route)
	_ok(field.find('_cloth_beside(host, shield, "WorksBanner"') >= 0, "field works via _cloth_beside")
	_ok(field.find('_cloth_beside(host, shield, "EstatesBanner"') >= 0, "field estates via _cloth_beside")
	_ok(field.find('_cloth_beside(host, shield, "AnnexBanner"') >= 0, "field annex via _cloth_beside")
	_ok(field.find('"lb_works_arms"') >= 0, "field lb_works_arms")
	_ok(field.find('"lb_estates_arms"') >= 0, "field lb_estates_arms")
	_ok(field.find('"lb_annex_arms"') >= 0, "field lb_annex_arms")
	var wk := FileAccess.get_file_as_string("res://scripts/hub/works.gd")
	_ok(wk.find("CKHeraldryField.place_works_crest_strip") >= 0
			or wk.find("CKHeraldryChrome.place_works_crest_strip") >= 0, "works wires Field")
	var es := FileAccess.get_file_as_string("res://scripts/hub/estates.gd")
	_ok(es.find("CKHeraldryField.place_estates_crest_strip") >= 0
			or es.find("CKHeraldryChrome.place_estates_crest_strip") >= 0, "estates wires Field")
	var ax := FileAccess.get_file_as_string("res://scripts/hub/annex.gd")
	_ok(ax.find("CKHeraldryField.place_annex_crest_strip") >= 0
			or ax.find("CKHeraldryChrome.place_annex_crest_strip") >= 0, "annex wires Field")
	var loc := FileAccess.get_file_as_string("res://data/locale/lineb.csv")
	_ok(loc.find("lb_works_arms,") >= 0, "locale lb_works_arms")
	_ok(loc.find("lb_estates_arms,") >= 0, "locale lb_estates_arms")
	_ok(loc.find("lb_annex_arms,") >= 0, "locale lb_annex_arms")
