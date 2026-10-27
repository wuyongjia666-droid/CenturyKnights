extends Node
## Fat heraldry E2E: Field SuccessionCrestStrip (团徽+heir) + company header, desktop + mobile.

const SCN := preload("res://scenes/hub/inheritance.tscn")
var _fails: Array = []

func _ready() -> void:
	await get_tree().process_frame
	await _run_desktop()
	await _run_mobile()
	await _run_helpers()
	if _fails.is_empty():
		print("SUCCESSION CREST PASS")
		get_tree().quit(0)
	else:
		for f in _fails:
			print("FAIL succession crest: ", f)
		get_tree().quit(1)

func _ok(cond: bool, msg: String) -> void:
	print("ROW %s %s" % ["PASS" if cond else "FAIL", msg])
	if not cond:
		_fails.append(msg)

func _settle(n: int = 6) -> void:
	for i in n:
		await get_tree().process_frame

func _boot_with_heir() -> CKCharacter:
	GameState.new_game("嗣位徽", "灰旗", GameState.crest_color)
	GameState.set_flag("chapter0_done", true)
	UnlockSchedule.install()
	World.events_enabled = false
	World.rivals_enabled = false
	GameState.silver = 8000
	var lead: CKCharacter = GameState.get_leader()
	var kid := CKCharacter.new()
	kid.id = "succ_kid_01"
	kid.name = "嗣位子"
	kid.age = 14
	kid.gender = "m"
	kid.family_id = str(lead.family_id)
	kid.is_child = true
	kid.alive = true
	kid.in_roster = false
	kid.rank = "knight"
	kid.is_leader = false
	GameState.characters[kid.id] = kid
	GameState.lineage_path[kid.id] = "martial"
	# Avoid ambition offer gate if possible
	return kid

func _assert_page(page: Node, where: String) -> void:
	var strip := page.find_child("SuccessionCrestStrip", true, false)
	_ok(strip != null and str(strip.get_meta("field_route", "")) == "succession_strip", "succession_strip")
	_ok(strip != null, "%s SuccessionCrestStrip" % where)
	if strip != null:
		var ca := strip.find_child("CastleArms", true, false)
		var la := strip.find_child("LeaderArms", true, false)
		_ok(ca != null and str(ca.get_meta("arms_kind", "")) == "gen2_36", "%s 团徽" % where)
		_ok(ca != null and str(ca.get_meta("field_route", "")) == "strip_company", "%s strip_company" % where)
		_ok(la != null and str(la.get_meta("arms_kind", "")) in ["gen2_06", "gen2_35"], "%s LeaderArms" % where)
		_ok(la != null and str(la.get_meta("field_route", "")) == "succession_heir", "%s succession_heir" % where)
		var bn := strip.find_child("SuccessionBanner", true, false)
		_ok(bn != null and str(bn.get_meta("field_route", "")) == "succession_banner", "%s succession_banner" % where)
		if ca != null and la != null:
			_ok(str(ca.get_meta("arms_core", "")) != str(la.get_meta("arms_core", "")), "%s 团徽!=嗣徽" % where)
		_ok(bool(strip.get_meta("has_heir", false)), "%s has_heir" % where)
	_ok(page.find_child("CastleArms", true, false) != null, "%s company header" % where)

func _run_desktop() -> void:
	OS.set_environment("CK_FORCE_MOBILE", "0")
	_boot_with_heir()
	var page: Control = SCN.instantiate()
	get_tree().root.add_child(page)
	await _settle(12)
	_assert_page(page, "desk")
	page.queue_free()
	await _settle(2)

func _run_mobile() -> void:
	OS.set_environment("CK_FORCE_MOBILE", "1")
	_ok(DeviceProfile.is_mobile(), "CK_FORCE_MOBILE flips DeviceProfile")
	_boot_with_heir()
	var page: Control = SCN.instantiate()
	get_tree().root.add_child(page)
	await _settle(12)
	_assert_page(page, "mob")
	page.queue_free()
	await _settle(2)
	OS.set_environment("CK_FORCE_MOBILE", "")

func _run_helpers() -> void:
	var kid := _boot_with_heir()
	var host := Control.new()
	add_child(host)
	var strip := CKHeraldryField.place_succession_crest_strip(host, kid, Vector2(10, 10), Vector2(36, 44))
	_ok(strip != null and strip.name == "SuccessionCrestStrip", "helper SuccessionCrestStrip")
	_ok(strip.find_child("LeaderArms", true, false) != null, "helper LeaderArms")
	host.queue_free()
