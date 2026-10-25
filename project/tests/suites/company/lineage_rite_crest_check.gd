extends Node
## Fat heraldry E2E: banner-rite RiteCrestStrip (团徽 + heir 族徽|旗徽) + company header, desktop + mobile.

const RITE_SCN := preload("res://scenes/hub/lineage_rite.tscn")
var _fails: Array = []

func _ready() -> void:
	await get_tree().process_frame
	await _run_desktop()
	await _run_mobile()
	await _run_helpers()
	if _fails.is_empty():
		print("RITE CREST CHROME PASS")
		get_tree().quit(0)
	else:
		for f in _fails:
			print("FAIL rite crest chrome: ", f)
		get_tree().quit(1)

func _ok(cond: bool, msg: String) -> void:
	print("ROW %s %s" % ["PASS" if cond else "FAIL", msg])
	if not cond:
		_fails.append(msg)

func _settle(n: int = 6) -> void:
	for i in n:
		await get_tree().process_frame

func _boot_with_child() -> CKCharacter:
	GameState.new_game("立旗徽", "灰旗", GameState.crest_color)
	GameState.set_flag("chapter0_done", true)
	UnlockSchedule.install()
	World.events_enabled = false
	World.rivals_enabled = false
	var lead: CKCharacter = GameState.get_leader()
	var kid := CKCharacter.new()
	kid.id = "rite_kid_01"
	kid.name = "立旗子"
	kid.age = 16
	kid.gender = "m"
	kid.family_id = str(lead.family_id)
	kid.is_child = true
	kid.alive = true
	kid.in_roster = false
	kid.rank = "knight"
	kid.is_leader = false
	GameState.characters[kid.id] = kid
	return kid

func _assert_empty(page: Node, where: String) -> void:
	var strip := page.find_child("RiteCrestStrip", true, false)
	_ok(strip != null, "%s RiteCrestStrip" % where)
	if strip != null:
		_ok(strip.find_child("CastleArms", true, false) != null, "%s 团徽" % where)
		_ok(strip.find_child("LeaderArms", true, false) == null, "%s no LeaderArms yet" % where)

func _assert_selected(page: Node, where: String, kid: CKCharacter) -> void:
	var strip := page.find_child("RiteCrestStrip", true, false)
	_ok(strip != null, "%s RiteCrestStrip after select" % where)
	if strip != null:
		var ca := strip.find_child("CastleArms", true, false)
		var la := strip.find_child("LeaderArms", true, false)
		_ok(ca != null and str(ca.get_meta("arms_kind", "")) == "gen2_36", "%s 团徽" % where)
		_ok(la != null, "%s LeaderArms" % where)
		_ok(bool(strip.get_meta("has_heir", false)), "%s has_heir" % where)
		if la != null and ca != null:
			_ok(str(la.get_meta("arms_core", "")) != str(ca.get_meta("arms_core", "")), "%s heir!=团徽" % where)
	_ok(page.find_child("CastleArms", true, false) != null, "%s company header present" % where)

func _run_desktop() -> void:
	OS.set_environment("CK_FORCE_MOBILE", "0")
	var kid := _boot_with_child()
	var page: Control = RITE_SCN.instantiate()
	get_tree().root.add_child(page)
	await _settle(12)
	_assert_empty(page, "desk")
	page.call("_select", kid)
	await _settle(8)
	_assert_selected(page, "desk-sel", kid)
	page.queue_free()
	await _settle(2)

func _run_mobile() -> void:
	OS.set_environment("CK_FORCE_MOBILE", "1")
	_ok(DeviceProfile.is_mobile(), "CK_FORCE_MOBILE flips DeviceProfile")
	var kid := _boot_with_child()
	var page: Control = RITE_SCN.instantiate()
	get_tree().root.add_child(page)
	await _settle(12)
	page.call("_select", kid)
	await _settle(8)
	_assert_selected(page, "mob-sel", kid)
	page.queue_free()
	await _settle(2)
	OS.set_environment("CK_FORCE_MOBILE", "")

func _run_helpers() -> void:
	var kid := _boot_with_child()
	var host := Control.new()
	add_child(host)
	var strip := CKHeraldryChrome.place_rite_crest_strip(host, kid, Vector2(10, 10), Vector2(36, 44))
	_ok(strip != null and strip.name == "RiteCrestStrip", "helper RiteCrestStrip")
	_ok(strip.find_child("CastleArms", true, false) != null, "helper CastleArms")
	_ok(strip.find_child("LeaderArms", true, false) != null, "helper LeaderArms")
	var empty := CKHeraldryChrome.place_rite_crest_strip(host, null, Vector2(10, 80), Vector2(36, 44))
	_ok(empty != null and empty.find_child("LeaderArms", true, false) == null, "helper empty no LeaderArms")
	host.queue_free()
