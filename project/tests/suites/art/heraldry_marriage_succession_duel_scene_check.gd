extends Node
## Fat heraldry E2E: marriage vow strip + house/vow arms, succession
## heir strip, heir-trial duel strip — strip_company + cloth banner child
## field_route ownership — desk + mobile. Real scenes; no EmptyHost.

const MARRIAGE := "res://scenes/hub/marriage.tscn"
const INHERIT := "res://scenes/hub/inheritance.tscn"
const DUEL := "res://scenes/hub/heir_rivalry.tscn"

var _fails: Array = []


func _ready() -> void:
	await get_tree().process_frame
	await _run_desktop()
	await _run_mobile()
	_source_contracts()
	if _fails.is_empty():
		print("HERALDRY MARRIAGE SUCCESSION DUEL SCENE PASS")
		get_tree().quit(0)
	else:
		for f in _fails:
			print("FAIL heraldry marriage succession duel scene: ", f)
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


func _boot_marriage() -> void:
	GameState.new_game("联姻嗣斗徽", "霜旗", GameState.crest_color)
	GameState.chapter0_flags["chapter0_done"] = true
	GameState.chapter0_flags["ch0_playing"] = false
	GameState.set_flag("chapter0_done", true)
	UnlockSchedule.install()
	World.events_enabled = false
	World.rivals_enabled = false
	GameState.silver = 9000
	GameState.food = 40
	GameState.iron = 40
	GameState.reputation["ashland"] = 90
	var lead: CKCharacter = GameState.get_leader()
	if lead != null:
		lead.rank = "baron"
		lead.gender = "m"
	GameState.refresh_marriage_candidates("", lead)


func _boot_heir(kids: int) -> void:
	GameState.new_game("联姻嗣斗徽", "霜旗", GameState.crest_color)
	GameState.chapter0_flags["chapter0_done"] = true
	GameState.chapter0_flags["ch0_playing"] = false
	GameState.set_flag("chapter0_done", true)
	UnlockSchedule.install()
	World.events_enabled = false
	World.rivals_enabled = false
	GameState.silver = 9000
	var lead: CKCharacter = GameState.get_leader()
	if lead != null:
		lead.rank = "baron"
	for i in kids:
		var kid := CKCharacter.new()
		kid.id = "wave5_kid_%d" % i
		kid.name = "嗣斗子%d" % (i + 1)
		kid.age = 16 - i
		kid.gender = "m"
		kid.family_id = str(lead.family_id) if lead != null else ""
		kid.is_child = true
		kid.alive = true
		kid.in_roster = false
		kid.rank = "knight"
		kid.is_leader = false
		GameState.characters[kid.id] = kid
		GameState.lineage_path[kid.id] = "martial" if i == 0 else "scholar"


func _open(path: String) -> Control:
	var page: Control = (load(path) as PackedScene).instantiate()
	page.set_anchors_preset(Control.PRESET_TOP_LEFT)
	page.position = Vector2.ZERO
	page.size = Vector2(1280, 720)
	get_tree().root.add_child(page)
	return page


func _assert_marriage(tag: String) -> void:
	_boot_marriage()
	var page := _open(MARRIAGE)
	await _settle(14)
	if page.has_method("apply_mobile_layout") and tag.begins_with("mob"):
		page.call("apply_mobile_layout")
		await _settle(8)
	var strip := page.find_child("MarriageCrestStrip", true, false)
	_ok(_route(strip, "marriage_strip"), "%s/marriage marriage_strip" % tag)
	if strip != null:
		_ok(_route(strip.find_child("CastleArms", true, false), "strip_company"), "%s/marriage strip_company" % tag)
		_ok(_route(strip.find_child("LeftArms", true, false), "marriage_left"), "%s/marriage marriage_left" % tag)
		_ok(_route(strip.find_child("RightArms", true, false), "marriage_right"), "%s/marriage marriage_right" % tag)
		_ok(_route(strip.find_child("MarriageBanner", true, false), "marriage_banner"), "%s/marriage marriage_banner" % tag)
		var mbn := strip.find_child("MarriageBanner", true, false)
		_ok(mbn != null and str(mbn.get_meta("arms_kind", "")) == "lb_marriage_arms", "%s/marriage MarriageBanner kind" % tag)
	var houses: Array = []
	for n in page.find_children("HouseArms", "", true, false):
		if str(n.get_meta("field_route", "")) == "house_card":
			houses.append(n)
	_ok(houses.size() >= 1, "%s/marriage house_card count>=1 got %d" % [tag, houses.size()])
	var vow := page.find_child("VowCompanyArms", true, false)
	_ok(_route(vow, "marriage_vow"), "%s/marriage marriage_vow" % tag)
	var vstrip := page.find_child("VowCrestStrip", true, false)
	_ok(_route(vstrip, "vow_strip"), "%s/marriage vow_strip" % tag)
	var vbn := page.find_child("VowBanner", true, false)
	_ok(vbn != null and str(vbn.get_meta("arms_kind", "")) == "lb_vow_arms", "%s/marriage VowBanner kind" % tag)
	page.queue_free()
	await _settle(2)


func _assert_succession(tag: String) -> void:
	_boot_heir(1)
	var page := _open(INHERIT)
	await _settle(14)
	if page.has_method("apply_mobile_layout") and tag.begins_with("mob"):
		page.call("apply_mobile_layout")
		await _settle(8)
	var strip := page.find_child("SuccessionCrestStrip", true, false)
	_ok(_route(strip, "succession_strip"), "%s/succession succession_strip" % tag)
	if strip != null:
		_ok(_route(strip.find_child("CastleArms", true, false), "strip_company"), "%s/succession strip_company" % tag)
		_ok(_route(strip.find_child("LeaderArms", true, false), "succession_heir"), "%s/succession succession_heir" % tag)
		_ok(_route(strip.find_child("SuccessionBanner", true, false), "succession_banner"), "%s/succession succession_banner" % tag)
		var sbn := strip.find_child("SuccessionBanner", true, false)
		_ok(sbn != null and str(sbn.get_meta("arms_kind", "")) == "lb_succession_arms", "%s/succession SuccessionBanner kind" % tag)
	page.queue_free()
	await _settle(2)


func _assert_duel(tag: String) -> void:
	_boot_heir(2)
	var page := _open(DUEL)
	await _settle(14)
	if page.has_method("apply_mobile_layout") and tag.begins_with("mob"):
		page.call("apply_mobile_layout")
		await _settle(8)
	var strip := page.find_child("DuelCrestStrip", true, false)
	_ok(_route(strip, "duel_strip"), "%s/duel duel_strip" % tag)
	if strip != null:
		_ok(_route(strip.find_child("CastleArms", true, false), "strip_company"), "%s/duel strip_company" % tag)
		_ok(_route(strip.find_child("LeftArms", true, false), "duel_left"), "%s/duel duel_left" % tag)
		_ok(_route(strip.find_child("RightArms", true, false), "duel_right"), "%s/duel duel_right" % tag)
		_ok(_route(strip.find_child("DuelBanner", true, false), "duel_banner"), "%s/duel duel_banner" % tag)
		var dbn := strip.find_child("DuelBanner", true, false)
		_ok(dbn != null and str(dbn.get_meta("arms_kind", "")) == "lb_duel_arms", "%s/duel DuelBanner kind" % tag)
	page.queue_free()
	await _settle(2)


func _run_pass(tag: String) -> void:
	await _assert_marriage(tag)
	await _assert_succession(tag)
	await _assert_duel(tag)


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
		"marriage_strip", "marriage_left", "marriage_right", "marriage_banner",
		"marriage_vow", "house_card",
		"succession_strip", "succession_heir", "succession_banner",
		"duel_strip", "duel_left", "duel_right", "duel_banner",
		"strip_company",
	]:
		var lit := field.find('set_meta("field_route", "%s")' % route) >= 0
		var arg := field.find('"%s"' % route) >= 0
		_ok(lit or arg, "field source route %s" % route)
	var hubs := {
		"marriage": "res://scripts/hub/marriage.gd",
		"inheritance": "res://scripts/hub/inheritance.gd",
		"heir_rivalry": "res://scripts/hub/heir_rivalry.gd",
	}
	for hub in hubs.keys():
		var src := FileAccess.get_file_as_string(hubs[hub])
		_ok(src.find("CKHeraldryField.") >= 0, "%s wires Field" % hub)
	_ok(field.find('"lb_marriage_arms"') >= 0, "field lb_marriage_arms")
	_ok(field.find('"lb_succession_arms"') >= 0, "field lb_succession_arms")
	_ok(field.find('"lb_duel_arms"') >= 0, "field lb_duel_arms")
	var loc := FileAccess.get_file_as_string("res://data/locale/lineb.csv")
	_ok(loc.find("lb_marriage_arms,") >= 0, "locale lb_marriage_arms")
	_ok(loc.find("lb_succession_arms,") >= 0, "locale lb_succession_arms")
	_ok(loc.find("lb_duel_arms,") >= 0, "locale lb_duel_arms")
