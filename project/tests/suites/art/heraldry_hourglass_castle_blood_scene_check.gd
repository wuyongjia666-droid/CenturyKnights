extends Node
## Fat heraldry wave-12 E2E: HourglassCrestStrip / CastleViewCrestStrip / BloodCrestStrip
## — _cloth_beside Field cloth + arms_kind ownership — desk + mobile.
## Real hourglass / castle_view / blood_test; no EmptyHost.

const HOURGLASS := "res://scenes/hub/hourglass.tscn"
const CASTLE := "res://scenes/hub/castle_view.tscn"
const BLOOD := "res://scenes/hub/blood_test.tscn"

var _fails: Array = []


func _ready() -> void:
	await get_tree().process_frame
	await _run_helpers()
	await _run_desktop()
	await _run_mobile()
	_source_contracts()
	if _fails.is_empty():
		print("HERALDRY HOURGLASS CASTLE BLOOD SCENE PASS")
		get_tree().quit(0)
	else:
		for f in _fails:
			print("FAIL heraldry hourglass castle blood scene: ", f)
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
	GameState.new_game("时漏城堡血验旗学徽", "灰旗", GameState.crest_color)
	GameState.set_flag("chapter0_done", true)
	UnlockSchedule.install()
	World.events_enabled = false
	World.rivals_enabled = false
	GameState.food = 40
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
	var hg := CKHeraldryField.place_hourglass_crest_strip(host, Vector2(8, 8))
	_ok(hg != null and hg.name == "HourglassCrestStrip", "helper HourglassCrestStrip")
	_ok(hg != null and hg.get_child_count() == 2, "helper hourglass child_count=2")
	var hbn := hg.find_child("HourglassBanner", true, false) if hg else null
	_ok(_route(hbn, "hourglass_banner"), "helper hourglass_banner")
	_ok(hbn != null and str(hbn.get_meta("arms_kind", "")) == "lb_hourglass_arms", "helper hourglass kind")
	var cv := CKHeraldryField.place_castle_view_crest_strip(host, Vector2(200, 8))
	_ok(cv != null and cv.name == "CastleViewCrestStrip", "helper CastleViewCrestStrip")
	_ok(cv != null and cv.get_child_count() == 2, "helper castle_view child_count=2")
	var cbn := cv.find_child("CastleViewBanner", true, false) if cv else null
	_ok(_route(cbn, "castle_view_banner"), "helper castle_view_banner")
	_ok(cbn != null and str(cbn.get_meta("arms_kind", "")) == "lb_castle_view_arms", "helper castle_view kind")
	var bd := CKHeraldryField.place_blood_crest_strip(host, Vector2(400, 8))
	_ok(bd != null and bd.name == "BloodCrestStrip", "helper BloodCrestStrip")
	_ok(bd != null and bd.get_child_count() == 2, "helper blood child_count=2")
	var bbn := bd.find_child("BloodBanner", true, false) if bd else null
	_ok(_route(bbn, "blood_banner"), "helper blood_banner")
	_ok(bbn != null and str(bbn.get_meta("arms_kind", "")) == "lb_blood_arms", "helper blood kind")
	host.queue_free()
	await _settle(2)


func _assert_hourglass(tag: String) -> void:
	_boot()
	var page := _open(HOURGLASS)
	await _settle(12)
	if page.has_method("apply_mobile_layout") and tag.begins_with("mob"):
		page.call("apply_mobile_layout")
		await _settle(6)
	var strip := page.find_child("HourglassCrestStrip", true, false)
	_ok(_route(strip, "hourglass_strip"), "%s/hourglass hourglass_strip" % tag)
	if strip != null:
		_ok(_route(strip.find_child("CastleArms", true, false), "strip_company"), "%s/hourglass strip_company" % tag)
		var bn := strip.find_child("HourglassBanner", true, false)
		_ok(_route(bn, "hourglass_banner"), "%s/hourglass hourglass_banner" % tag)
		_ok(bn != null and str(bn.get_meta("arms_kind", "")) == "lb_hourglass_arms", "%s/hourglass HourglassBanner kind" % tag)
		_ok(strip.get_child_count() == 2, "%s/hourglass child_count=2" % tag)
	page.queue_free()
	await _settle(2)


func _assert_castle(tag: String) -> void:
	_boot()
	var page := _open(CASTLE)
	await _settle(12)
	if page.has_method("apply_mobile_layout") and tag.begins_with("mob"):
		page.call("apply_mobile_layout")
		await _settle(6)
	var strip := page.find_child("CastleViewCrestStrip", true, false)
	_ok(_route(strip, "castle_view_strip"), "%s/castle castle_view_strip" % tag)
	if strip != null:
		_ok(_route(strip.find_child("CastleArms", true, false), "strip_company"), "%s/castle strip_company" % tag)
		var bn := strip.find_child("CastleViewBanner", true, false)
		_ok(_route(bn, "castle_view_banner"), "%s/castle castle_view_banner" % tag)
		_ok(bn != null and str(bn.get_meta("arms_kind", "")) == "lb_castle_view_arms", "%s/castle CastleViewBanner kind" % tag)
		_ok(strip.get_child_count() == 2, "%s/castle child_count=2" % tag)
	page.queue_free()
	await _settle(2)


func _assert_blood(tag: String) -> void:
	_boot()
	var page := _open(BLOOD)
	await _settle(14)
	if page.has_method("apply_mobile_layout") and tag.begins_with("mob"):
		page.call("apply_mobile_layout")
		await _settle(8)
	var strip := page.find_child("BloodCrestStrip", true, false)
	_ok(_route(strip, "blood_strip"), "%s/blood blood_strip" % tag)
	if strip != null:
		_ok(_route(strip.find_child("CastleArms", true, false), "strip_company"), "%s/blood strip_company" % tag)
		var bn := strip.find_child("BloodBanner", true, false)
		_ok(_route(bn, "blood_banner"), "%s/blood blood_banner" % tag)
		_ok(bn != null and str(bn.get_meta("arms_kind", "")) == "lb_blood_arms", "%s/blood BloodBanner kind" % tag)
		_ok(strip.get_child_count() == 2, "%s/blood child_count=2" % tag)
	page.queue_free()
	await _settle(2)


func _run_pass(tag: String) -> void:
	await _assert_hourglass(tag)
	await _assert_castle(tag)
	await _assert_blood(tag)


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
		"hourglass_strip", "hourglass_banner",
		"castle_view_strip", "castle_view_banner",
		"blood_strip", "blood_banner", "blood_queue",
		"strip_company",
	]:
		var lit := field.find('set_meta("field_route", "%s")' % route) >= 0
		var arg := field.find('"%s"' % route) >= 0
		_ok(lit or arg, "field source route %s" % route)
	_ok(field.find('_cloth_beside(host, shield, "HourglassBanner"') >= 0, "field hourglass via _cloth_beside")
	_ok(field.find('_cloth_beside(host, shield, "CastleViewBanner"') >= 0, "field castle_view via _cloth_beside")
	_ok(field.find('_cloth_beside(host, shield, "BloodBanner"') >= 0, "field blood via _cloth_beside")
	_ok(field.find('"lb_hourglass_arms"') >= 0, "field lb_hourglass_arms")
	_ok(field.find('"lb_castle_view_arms"') >= 0, "field lb_castle_view_arms")
	_ok(field.find('"lb_blood_arms"') >= 0, "field lb_blood_arms")
	_ok(field.find('if arms_kind != "":') >= 0, "cloth helper arms_kind gated")
	_ok(field.find('arms_kind: String = ""') >= 0, "cloth helper arms_kind param")
	var hg := FileAccess.get_file_as_string("res://scripts/hub/hourglass.gd")
	_ok(hg.find("CKHeraldryField.place_hourglass_crest_strip") >= 0
			or hg.find("CKHeraldryChrome.place_hourglass_crest_strip") >= 0, "hourglass wires Field")
	var cv := FileAccess.get_file_as_string("res://scripts/hub/castle_view.gd")
	_ok(cv.find("CKHeraldryField.place_castle_view_crest_strip") >= 0
			or cv.find("CKHeraldryChrome.place_castle_view_crest_strip") >= 0, "castle_view wires Field")
	var bd := FileAccess.get_file_as_string("res://scripts/hub/blood_test.gd")
	_ok(bd.find("CKHeraldryField.place_blood_crest_strip") >= 0
			or bd.find("CKHeraldryChrome.place_blood_crest_strip") >= 0, "blood_test wires Field")
	var loc := FileAccess.get_file_as_string("res://data/locale/lineb.csv")
	_ok(loc.find("lb_hourglass_arms,") >= 0, "locale lb_hourglass_arms")
	_ok(loc.find("lb_castle_view_arms,") >= 0, "locale lb_castle_view_arms")
	_ok(loc.find("lb_blood_arms,") >= 0, "locale lb_blood_arms")
