extends Node
## Fat heraldry wave-7 E2E: city 本城之事 AffairCrestStrip, lineage_rite RiteCrestStrip,
## title_promote MusterCrestStrip — strip_company + cloth banner child field_route ownership —
## desk + mobile. Real scenes; no EmptyHost.

const CITY_SCN := "res://scenes/hub/city.tscn"
const RITE_SCN := "res://scenes/hub/lineage_rite.tscn"
const TITLE_SCN := "res://scenes/hub/title_promote.tscn"
const CITY := "lt_capital"

var _fails: Array = []


func _ready() -> void:
	await get_tree().process_frame
	await _run_desktop()
	await _run_mobile()
	_source_contracts()
	if _fails.is_empty():
		print("HERALDRY AFFAIRS RITE MUSTER SCENE PASS")
		get_tree().quit(0)
	else:
		for f in _fails:
			print("FAIL heraldry affairs rite muster scene: ", f)
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


func _boot_affairs() -> void:
	GameState.new_game("本城旗学徽", "灰旗", GameState.crest_color)
	GameState.set_flag("chapter0_done", true)
	UnlockSchedule.install()
	World.events_enabled = false
	World.rivals_enabled = false
	for nid in World.nations.keys():
		World.rep_nation[str(nid)] = 50
	GameState.silver = 8000
	GameState.food = 40
	World.pos = CITY
	World.arrive(CITY)
	GameState.set_meta("city_id", CITY)
	var lead: CKCharacter = GameState.get_leader()
	if lead != null:
		lead.job_id = "priest"


func _boot_rite() -> CKCharacter:
	GameState.new_game("继位旗学徽", "霜旗", GameState.crest_color)
	GameState.set_flag("chapter0_done", true)
	UnlockSchedule.install()
	World.events_enabled = false
	World.rivals_enabled = false
	var lead: CKCharacter = GameState.get_leader()
	var kid := CKCharacter.new()
	kid.id = "wave7_rite_heir"
	kid.name = "继童"
	kid.age = 14
	kid.alive = true
	kid.in_roster = false
	kid.is_child = true
	kid.family_id = lead.family_id if lead else ""
	kid.parent_ids = [lead.id] if lead else []
	kid.job_id = "light_inf"
	kid.rank = "knight"
	kid.is_leader = false
	kid.hp = kid.max_hp
	GameState.characters[kid.id] = kid
	return kid


func _boot_title() -> void:
	GameState.new_game("晋爵旗学徽", "灰旗", GameState.crest_color)
	GameState.set_flag("chapter0_done", true)
	UnlockSchedule.install()
	World.events_enabled = false
	World.rivals_enabled = false
	GameState.silver = 8000


func _open(path: String) -> Control:
	var page: Control = (load(path) as PackedScene).instantiate()
	page.set_anchors_preset(Control.PRESET_TOP_LEFT)
	page.position = Vector2.ZERO
	page.size = Vector2(1280, 720)
	get_tree().root.add_child(page)
	return page


func _assert_affairs(tag: String) -> void:
	_boot_affairs()
	var page := _open(CITY_SCN)
	page.set_meta("city_id", CITY)
	await _settle(14)
	if page.has_method("apply_mobile_layout") and tag.begins_with("mob"):
		page.call("apply_mobile_layout")
		await _settle(8)
	if page.has_method("open_affairs"):
		page.open_affairs()
		await _settle(10)
	var ov := page.find_child("AffairOverlay", true, false)
	_ok(ov != null, "%s/affairs AffairOverlay" % tag)
	var strip: Node = null
	if ov != null:
		strip = ov.find_child("AffairCrestStrip", true, false)
	_ok(_route(strip, "affairs_strip"), "%s/affairs affairs_strip" % tag)
	if strip != null:
		_ok(_route(strip.find_child("CastleArms", true, false), "strip_company"), "%s/affairs strip_company" % tag)
		_ok(_route(strip.find_child("CityNationArms", true, false), "affairs_nation"), "%s/affairs affairs_nation" % tag)
		_ok(_route(strip.find_child("AffairsBanner", true, false), "affairs_banner"), "%s/affairs affairs_banner" % tag)
	page.queue_free()
	await _settle(2)


func _assert_rite(tag: String) -> void:
	var kid := _boot_rite()
	var page := _open(RITE_SCN)
	await _settle(14)
	if page.has_method("apply_mobile_layout") and tag.begins_with("mob"):
		page.call("apply_mobile_layout")
		await _settle(8)
	if page.has_method("_select"):
		page.call("_select", kid)
		await _settle(8)
	var strip := page.find_child("RiteCrestStrip", true, false)
	_ok(_route(strip, "rite_strip"), "%s/rite rite_strip" % tag)
	if strip != null:
		_ok(_route(strip.find_child("CastleArms", true, false), "strip_company"), "%s/rite strip_company" % tag)
		_ok(_route(strip.find_child("LeaderArms", true, false), "rite_leader"), "%s/rite rite_leader" % tag)
		_ok(_route(strip.find_child("RiteBanner", true, false), "rite_banner"), "%s/rite rite_banner" % tag)
	page.queue_free()
	await _settle(2)


func _assert_muster(tag: String) -> void:
	_boot_title()
	var page := _open(TITLE_SCN)
	await _settle(14)
	if page.has_method("apply_mobile_layout") and tag.begins_with("mob"):
		page.call("apply_mobile_layout")
		await _settle(8)
	var strip := page.find_child("MusterCrestStrip", true, false)
	_ok(_route(strip, "muster_strip"), "%s/title muster_strip" % tag)
	if strip != null:
		_ok(_route(strip.find_child("CastleArms", true, false), "strip_company"), "%s/title strip_company" % tag)
		_ok(_route(strip.find_child("LeaderArms", true, false), "muster_leader"), "%s/title muster_leader" % tag)
		_ok(_route(strip.find_child("MusterBanner", true, false), "muster_banner"), "%s/title muster_banner" % tag)
	page.queue_free()
	await _settle(2)


func _run_pass(tag: String) -> void:
	await _assert_affairs(tag)
	await _assert_rite(tag)
	await _assert_muster(tag)


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
		"affairs_strip", "affairs_nation", "affairs_banner",
		"rite_strip", "rite_leader", "rite_banner",
		"muster_strip", "muster_leader", "muster_banner",
		"strip_company",
	]:
		var lit := field.find('set_meta("field_route", "%s")' % route) >= 0
		var arg := field.find('"%s"' % route) >= 0
		_ok(lit or arg, "field source route %s" % route)
	var hubs := {
		"city": "res://scripts/hub/city.gd",
		"lineage_rite": "res://scripts/hub/lineage_rite.gd",
		"title_promote": "res://scripts/hub/title_promote.gd",
	}
	for hub in hubs.keys():
		var src := FileAccess.get_file_as_string(hubs[hub])
		_ok(src.find("CKHeraldryField.") >= 0, "%s wires Field" % hub)
