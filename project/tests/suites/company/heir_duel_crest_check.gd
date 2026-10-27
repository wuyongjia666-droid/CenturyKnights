extends Node
## Fat heraldry E2E: Field heir-trial DuelCrestStrip (团徽+A+B) + company header, desktop + mobile.
## Does not alter EmptyHost empty-state copy — only asserts crest chrome.

const SCN := preload("res://scenes/hub/heir_rivalry.tscn")
var _fails: Array = []

func _ready() -> void:
	await get_tree().process_frame
	await _run_desktop()
	await _run_mobile()
	await _run_helpers()
	if _fails.is_empty():
		print("DUEL CREST PASS")
		get_tree().quit(0)
	else:
		for f in _fails:
			print("FAIL duel crest: ", f)
		get_tree().quit(1)

func _ok(cond: bool, msg: String) -> void:
	print("ROW %s %s" % ["PASS" if cond else "FAIL", msg])
	if not cond:
		_fails.append(msg)

func _settle(n: int = 6) -> void:
	for i in n:
		await get_tree().process_frame

func _boot_two() -> void:
	GameState.new_game("夺嫡徽", "灰旗", GameState.crest_color)
	GameState.set_flag("chapter0_done", true)
	UnlockSchedule.install()
	World.events_enabled = false
	World.rivals_enabled = false
	var lead: CKCharacter = GameState.get_leader()
	for i in 2:
		var kid := CKCharacter.new()
		kid.id = "duel_kid_%d" % i
		kid.name = "夺嫡子%d" % (i + 1)
		kid.age = 16 - i
		kid.gender = "m"
		kid.family_id = str(lead.family_id)
		kid.is_child = true
		kid.alive = true
		kid.in_roster = false
		kid.rank = "knight"
		kid.is_leader = false
		GameState.characters[kid.id] = kid
		GameState.lineage_path[kid.id] = "martial" if i == 0 else "scholar"

func _assert_page(page: Node, where: String) -> void:
	var strip := page.find_child("DuelCrestStrip", true, false)
	_ok(strip != null and str(strip.get_meta("field_route", "")) == "duel_strip", "duel_strip")
	_ok(strip != null, "%s DuelCrestStrip" % where)
	if strip != null:
		var ca := strip.find_child("CastleArms", true, false)
		var la := strip.find_child("LeftArms", true, false)
		var ra := strip.find_child("RightArms", true, false)
		_ok(ca != null and str(ca.get_meta("arms_kind", "")) == "gen2_36", "%s 团徽" % where)
		_ok(ca != null and str(ca.get_meta("field_route", "")) == "strip_company", "%s strip_company" % where)
		_ok(la != null and str(la.get_meta("arms_kind", "")) in ["gen2_06", "gen2_35"], "%s LeftArms" % where)
		_ok(la != null and str(la.get_meta("field_route", "")) == "duel_left", "%s duel_left" % where)
		_ok(ra != null and str(ra.get_meta("arms_kind", "")) in ["gen2_06", "gen2_35"], "%s RightArms" % where)
		_ok(ra != null and str(ra.get_meta("field_route", "")) == "duel_right", "%s duel_right" % where)
		var bn := strip.find_child("DuelBanner", true, false)
		_ok(bn != null and str(bn.get_meta("field_route", "")) == "duel_banner", "%s duel_banner" % where)
		if ca != null and la != null:
			_ok(str(ca.get_meta("arms_core", "")) != str(la.get_meta("arms_core", "")), "%s 团徽!=A" % where)
		if ca != null and ra != null:
			_ok(str(ca.get_meta("arms_core", "")) != str(ra.get_meta("arms_core", "")), "%s 团徽!=B" % where)
		_ok(bool(strip.get_meta("has_left", false)) and bool(strip.get_meta("has_right", false)), "%s metas" % where)
	_ok(page.find_child("CastleArms", true, false) != null, "%s company header" % where)

func _run_desktop() -> void:
	OS.set_environment("CK_FORCE_MOBILE", "0")
	_boot_two()
	var page: Control = SCN.instantiate()
	get_tree().root.add_child(page)
	await _settle(12)
	_assert_page(page, "desk")
	page.queue_free()
	await _settle(2)

func _run_mobile() -> void:
	OS.set_environment("CK_FORCE_MOBILE", "1")
	_ok(DeviceProfile.is_mobile(), "CK_FORCE_MOBILE flips DeviceProfile")
	_boot_two()
	var page: Control = SCN.instantiate()
	get_tree().root.add_child(page)
	await _settle(12)
	_assert_page(page, "mob")
	page.queue_free()
	await _settle(2)
	OS.set_environment("CK_FORCE_MOBILE", "")

func _run_helpers() -> void:
	_boot_two()
	var a = GameState.characters["duel_kid_0"]
	var b = GameState.characters["duel_kid_1"]
	var host := Control.new()
	add_child(host)
	var strip := CKHeraldryField.place_duel_crest_strip(host, a, b, Vector2(10, 10), Vector2(36, 44))
	_ok(strip != null and strip.name == "DuelCrestStrip", "helper DuelCrestStrip")
	_ok(strip.find_child("LeftArms", true, false) != null and strip.find_child("RightArms", true, false) != null, "helper both arms")
	host.queue_free()
