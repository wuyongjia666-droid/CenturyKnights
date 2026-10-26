extends Node
## Fat heraldry E2E: dossier 岁课年迹 YeartraceArms + 私囊 PursePlate (desk + mobile).

const SCN := preload("res://scenes/hub/unit_dossier.tscn")
var _fails: Array = []

func _ready() -> void:
	await get_tree().process_frame
	await _run_desktop()
	await _run_mobile()
	if _fails.is_empty():
		print("YEARTRACE PURSE FIELD CREST PASS")
		print("YEARTRACE PURSE CREST PASS")
		get_tree().quit(0)
	else:
		for f in _fails:
			print("FAIL yeartrace/purse crest: ", f)
		get_tree().quit(1)

func _ok(cond: bool, msg: String) -> void:
	print("ROW %s %s" % ["PASS" if cond else "FAIL", msg])
	if not cond:
		_fails.append(msg)

func _settle(n: int = 6) -> void:
	for i in n:
		await get_tree().process_frame

func _boot() -> void:
	GameState.new_game("岁课私囊", "灰旗", GameState.crest_color)
	GameState.set_flag("chapter0_done", true)
	UnlockSchedule.install()
	World.events_enabled = false
	World.rivals_enabled = false
	var lead := GameState.get_leader()
	_ok(lead != null, "leader present")
	if lead != null:
		CKPurse.set_purse(lead, 9)
		GameState.set_meta("dossier_id", lead.id)
	GameState.set_meta("dossier_back", "res://scenes/hub/estates.tscn")

func _assert_page(page: Node, where: String) -> void:
	var yt = page.find_child("YeartracePanel", true, false)
	_ok(yt != null, "%s YeartracePanel" % where)
	if yt != null:
		var ya = yt.find_child("YeartraceArms", true, false)
		_ok(ya != null, "%s YeartraceArms" % where)
		if ya != null:
			_ok(str(ya.get_meta("arms_core", "")) != "", "%s YeartraceArms core" % where)
			_ok(str(ya.get_meta("field_route", "")) == "yeartrace", "%s YeartraceArms field_route" % where)
	var purse = page.find_child("PursePlate", true, false)
	_ok(purse != null, "%s PursePlate" % where)
	if purse != null:
		_ok(str(purse.get_meta("field_route", "")) == "purse", "%s PursePlate field_route" % where)
		var pa = purse.find_child("PurseArms", true, false)
		_ok(pa != null, "%s PurseArms" % where)
		_ok(int(purse.get_meta("purse_silver", -1)) == 9, "%s purse silver meta" % where)
		var lab = purse.find_child("PurseSilver", true, false)
		_ok(lab != null, "%s PurseSilver label" % where)
	var dos := FileAccess.get_file_as_string("res://scripts/hub/unit_dossier.gd")
	_ok(dos.find("CKHeraldryField.place_purse_plate") >= 0, "%s dossier calls Field purse" % where)
	var yt_src := FileAccess.get_file_as_string("res://scripts/hub/sui_yeartrace_ui.gd")
	_ok(yt_src.find("CKHeraldryField.attach_yeartrace_arms") >= 0, "%s yeartrace calls Field" % where)

func _run_desktop() -> void:
	OS.set_environment("CK_FORCE_MOBILE", "0")
	_boot()
	var page: Control = SCN.instantiate()
	get_tree().root.add_child(page)
	await _settle(12)
	_assert_page(page, "desk")
	page.queue_free()
	await _settle(2)

func _run_mobile() -> void:
	OS.set_environment("CK_FORCE_MOBILE", "1")
	_ok(DeviceProfile.is_mobile(), "CK_FORCE_MOBILE flips DeviceProfile")
	_boot()
	var page: Control = SCN.instantiate()
	get_tree().root.add_child(page)
	await _settle(12)
	if page.has_method("apply_mobile_layout"):
		page.call("apply_mobile_layout")
		await _settle(6)
	_assert_page(page, "mob")
	page.queue_free()
	await _settle(2)
	OS.set_environment("CK_FORCE_MOBILE", "")
