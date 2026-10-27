extends Node
## Fat heraldry wave-6 E2E: forge focus strip, shrine heal strip, train focus
## strip — strip_company + cloth banner child field_route ownership —
## desk + mobile. Real scenes; no EmptyHost.

const FORGE := "res://scenes/hub/forge.tscn"
const SHRINE := "res://scenes/hub/shrine.tscn"
const TRAIN := "res://scenes/hub/train.tscn"

var _fails: Array = []


func _ready() -> void:
	await get_tree().process_frame
	await _run_desktop()
	await _run_mobile()
	_source_contracts()
	if _fails.is_empty():
		print("HERALDRY FORGE SHRINE TRAIN SCENE PASS")
		get_tree().quit(0)
	else:
		for f in _fails:
			print("FAIL heraldry forge shrine train scene: ", f)
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


func _boot_forge() -> void:
	GameState.new_game("炉殿旗学徽", "灰旗", GameState.crest_color)
	GameState.chapter0_flags["chapter0_done"] = true
	GameState.chapter0_flags["ch0_playing"] = false
	GameState.set_flag("chapter0_done", true)
	UnlockSchedule.install()
	World.events_enabled = false
	World.rivals_enabled = false
	GameState.silver = 8000
	GameState.iron = 40
	var loner := CKCharacter.new()
	loner.id = "wave6_forge_loner"
	loner.name = "客匠"
	loner.age = 26
	loner.alive = true
	loner.in_roster = true
	loner.family_id = ""
	loner.job_id = "light_inf"
	loner.rank = "knight"
	loner.hp = loner.max_hp
	GameState.characters[loner.id] = loner


func _boot_shrine() -> void:
	GameState.new_game("炉殿旗学徽", "灰旗", GameState.crest_color)
	GameState.chapter0_flags["chapter0_done"] = true
	GameState.chapter0_flags["ch0_playing"] = false
	GameState.set_flag("chapter0_done", true)
	UnlockSchedule.install()
	World.events_enabled = false
	World.rivals_enabled = false
	World.pos = "ash_capital"
	World.arrive("ash_capital")
	var lead: CKCharacter = GameState.get_leader()
	if lead != null:
		lead.hp = maxi(1, int(lead.max_hp / 2))
		lead.injured = true


func _boot_train() -> void:
	GameState.new_game("炉殿旗学徽", "霜旗", GameState.crest_color)
	GameState.chapter0_flags["chapter0_done"] = true
	GameState.chapter0_flags["ch0_playing"] = false
	GameState.set_flag("chapter0_done", true)
	UnlockSchedule.install()
	World.events_enabled = false
	World.rivals_enabled = false
	var lead: CKCharacter = GameState.get_leader()
	var kid := CKCharacter.new()
	kid.id = "wave6_banner_pupil"
	kid.name = "旗童"
	kid.age = 9
	kid.alive = true
	kid.in_roster = false
	kid.is_child = true
	kid.family_id = lead.family_id if lead else ""
	kid.parent_ids = [lead.id] if lead else []
	kid.hp = kid.max_hp
	GameState.characters[kid.id] = kid
	var loner := CKCharacter.new()
	loner.id = "wave6_banner_tutor"
	loner.name = "客傅"
	loner.age = 32
	loner.alive = true
	loner.in_roster = true
	loner.family_id = ""
	loner.job_id = "soldier"
	loner.rank = "knight"
	loner.hp = loner.max_hp
	GameState.characters[loner.id] = loner


func _open(path: String) -> Control:
	var page: Control = (load(path) as PackedScene).instantiate()
	page.set_anchors_preset(Control.PRESET_TOP_LEFT)
	page.position = Vector2.ZERO
	page.size = Vector2(1280, 720)
	get_tree().root.add_child(page)
	return page


func _assert_forge(tag: String) -> void:
	_boot_forge()
	var page := _open(FORGE)
	await _settle(14)
	if page.has_method("apply_mobile_layout") and tag.begins_with("mob"):
		page.call("apply_mobile_layout")
		await _settle(8)
	var strip := page.find_child("ForgeFocusStrip", true, false)
	_ok(_route(strip, "forge_focus"), "%s/forge forge_focus" % tag)
	if strip != null:
		_ok(_route(strip.find_child("CastleArms", true, false), "strip_company"), "%s/forge strip_company" % tag)
		_ok(_route(strip.find_child("ForgeFocusArms", true, false), "forge_focus_arms"), "%s/forge forge_focus_arms" % tag)
		_ok(_route(strip.find_child("ForgeBanner", true, false), "forge_banner"), "%s/forge forge_banner" % tag)
	page.queue_free()
	await _settle(2)


func _assert_shrine(tag: String) -> void:
	_boot_shrine()
	var page := _open(SHRINE)
	await _settle(14)
	if page.has_method("apply_mobile_layout") and tag.begins_with("mob"):
		page.call("apply_mobile_layout")
		await _settle(8)
	var strip := page.find_child("ShrineHealStrip", true, false)
	_ok(_route(strip, "shrine_heal"), "%s/shrine shrine_heal" % tag)
	if strip != null:
		_ok(_route(strip.find_child("CastleArms", true, false), "strip_company"), "%s/shrine strip_company" % tag)
		_ok(_route(strip.find_child("HealFocusArms", true, false), "shrine_heal_focus"), "%s/shrine shrine_heal_focus" % tag)
		_ok(_route(strip.find_child("ShrineBanner", true, false), "shrine_banner"), "%s/shrine shrine_banner" % tag)
	page.queue_free()
	await _settle(2)


func _assert_train(tag: String) -> void:
	_boot_train()
	var page := _open(TRAIN)
	await _settle(14)
	if page.has_method("apply_mobile_layout") and tag.begins_with("mob"):
		page.call("apply_mobile_layout")
		await _settle(8)
	var strip := page.find_child("TrainFocusStrip", true, false)
	_ok(_route(strip, "train_focus"), "%s/train train_focus" % tag)
	if strip != null:
		_ok(_route(strip.find_child("CastleArms", true, false), "strip_company"), "%s/train strip_company" % tag)
		_ok(_route(strip.find_child("TrainFocusArms", true, false), "train_focus_arms"), "%s/train train_focus_arms" % tag)
		_ok(_route(strip.find_child("TrainBanner", true, false), "train_banner"), "%s/train train_banner" % tag)
	page.queue_free()
	await _settle(2)


func _run_pass(tag: String) -> void:
	await _assert_forge(tag)
	await _assert_shrine(tag)
	await _assert_train(tag)


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
		"forge_focus", "forge_focus_arms", "forge_banner",
		"shrine_heal", "shrine_heal_focus", "shrine_banner",
		"train_focus", "train_focus_arms", "train_banner",
		"strip_company",
	]:
		var lit := field.find('set_meta("field_route", "%s")' % route) >= 0
		var arg := field.find('"%s"' % route) >= 0
		_ok(lit or arg, "field source route %s" % route)
	var hubs := {
		"forge": "res://scripts/hub/forge.gd",
		"shrine": "res://scripts/hub/shrine.gd",
		"train": "res://scripts/hub/train.gd",
	}
	for hub in hubs.keys():
		var src := FileAccess.get_file_as_string(hubs[hub])
		_ok(src.find("CKHeraldryField.") >= 0, "%s wires Field" % hub)
