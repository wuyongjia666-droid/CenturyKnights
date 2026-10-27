extends Node
## Fat heraldry E2E: 岁课 year-card — CastleArms + CastleBannerStrip + YearArms on seeded rows.

const SCN := preload("res://scenes/hub/sui_yearcard.tscn")
var _fails: Array = []

func _ready() -> void:
	await get_tree().process_frame
	await _run_desktop()
	await _run_mobile()
	if _fails.is_empty():
		print("SUI YEARCARD FIELD CREST PASS")
		print("SUI YEARCARD CREST CHROME PASS")
		get_tree().quit(0)
	else:
		for f in _fails:
			print("FAIL sui yearcard crest chrome: ", f)
		get_tree().quit(1)

func _ok(cond: bool, msg: String) -> void:
	print("ROW %s %s" % ["PASS" if cond else "FAIL", msg])
	if not cond:
		_fails.append(msg)

func _settle(n: int = 6) -> void:
	for i in n:
		await get_tree().process_frame

func _boot() -> void:
	GameState.new_game("岁课徽", "灰旗", GameState.crest_color)
	GameState.set_flag("chapter0_done", true)
	UnlockSchedule.install()
	World.events_enabled = false
	World.rivals_enabled = false
	GameState.silver = 8000
	var lead: CKCharacter = GameState.get_leader()
	var cid := str(lead.id) if lead != null else ""
	if cid == "" and not GameState.characters.is_empty():
		cid = str(GameState.characters.keys()[0])
	GameState.house_mods["sui_inbox"] = [{
		"cid": cid,
		"id": "suite_year_seed",
		"band": "sui",
		"title": "suite seed",
		"body": "crest e2e",
		"side": "left",
		"outcome": "ok",
	}]

func _assert_page(page: Node, where: String) -> void:
	_ok(page.find_child("CastleArms", true, false) != null, "%s CastleArms" % where)
	_ok(page.find_child("CastleBannerStrip", true, false) != null, "%s CastleBannerStrip" % where)
	var yhead = page.find_child("YearArmsHead", true, false)
	_ok(yhead != null and str(yhead.get_meta("field_route", "")) == "yearcard_row", "%s YearArmsHead field_route" % where)
	var ya = page.find_child("YearArms", true, false)
	_ok(ya != null, "%s YearArms" % where)
	if ya != null:
		_ok(str(ya.get_meta("field_route", "")) == "yearcard_arms", "%s YearArms field_route" % where)
	var src := FileAccess.get_file_as_string("res://scripts/hub/sui_yearcard.gd")
	_ok(src.find("CKHeraldryField.attach_yearcard_row_arms") >= 0, "%s hub calls Field" % where)

func _run_desktop() -> void:
	OS.set_environment("CK_FORCE_MOBILE", "0")
	_boot()
	var page: Control = SCN.instantiate()
	get_tree().root.add_child(page)
	await _settle(14)
	_assert_page(page, "desk")
	page.queue_free()
	await _settle(2)

func _run_mobile() -> void:
	OS.set_environment("CK_FORCE_MOBILE", "1")
	_ok(DeviceProfile.is_mobile(), "CK_FORCE_MOBILE flips DeviceProfile")
	_boot()
	var page: Control = SCN.instantiate()
	get_tree().root.add_child(page)
	await _settle(14)
	if page.has_method("apply_mobile_layout"):
		page.call("apply_mobile_layout")
		await _settle(8)
	_assert_page(page, "mob")
	page.queue_free()
	await _settle(2)
	OS.set_environment("CK_FORCE_MOBILE", "")
