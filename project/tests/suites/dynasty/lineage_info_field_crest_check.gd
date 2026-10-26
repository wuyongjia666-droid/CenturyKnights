extends Node
## Fat heraldry E2E: lineage dossier info plate owns PersonArms via CKHeraldryField.
## Instantiates lineage_view (desk + mobile). Asserts field_route and arms_kind.

const SCN := preload("res://scenes/hub/lineage_view.tscn")
const INFO_SRC := "res://scripts/hub/lineage_info.gd"

var _fails: Array = []

func _ready() -> void:
	await get_tree().process_frame
	await _run_desktop()
	await _run_mobile()
	if _fails.is_empty():
		print("LINEAGE INFO FIELD CREST PASS")
		get_tree().quit(0)
	else:
		for f in _fails:
			print("FAIL lineage info field: ", f)
		get_tree().quit(1)

func _ok(cond: bool, msg: String) -> void:
	print("ROW %s %s" % ["PASS" if cond else "FAIL", msg])
	if not cond:
		_fails.append(msg)

func _settle(n: int = 6) -> void:
	for _i in n:
		await get_tree().process_frame

func _boot() -> CKCharacter:
	GameState.new_game("谱徽", "灰旗", GameState.crest_color)
	GameState.set_flag("chapter0_done", true)
	UnlockSchedule.install()
	World.events_enabled = false
	World.rivals_enabled = false
	var leader: CKCharacter = GameState.get_leader()
	leader.age = 34
	leader.rank = "count"
	return leader

func _assert_info(page: Node, leader: CKCharacter, where: String) -> void:
	var src := FileAccess.get_file_as_string(INFO_SRC)
	_ok(src.find("CKHeraldryField.attach_lineage_info_arms") >= 0, "%s info calls CKHeraldryField" % where)
	_ok(page.has_method("select"), "%s select API" % where)
	page.call("select", leader)
	await _settle(8)
	var arms := page.find_child("PersonArms", true, false)
	_ok(arms != null, "%s PersonArms" % where)
	if arms == null:
		return
	_ok(str(arms.get_meta("field_route", "")) == "lineage_info", "%s field_route" % where)
	var kind := str(arms.get_meta("arms_kind", ""))
	_ok(kind == "gen2_06" or kind == "gen2_35", "%s person arms_kind=%s" % [where, kind])
	var core := str(arms.get_meta("arms_core", ""))
	var expect := CKHeraldry.core_key(GameState.arms_for_character(leader))
	_ok(core != "" and core == expect, "%s arms_core matches leader" % where)
	_ok(arms.get_child_count() == 0, "%s not marshalled" % where)
	var nm := page.find_child("InfoName", true, false)
	_ok(nm != null, "%s InfoName stays" % where)

func _run_desktop() -> void:
	OS.set_environment("CK_FORCE_MOBILE", "0")
	var leader := _boot()
	var page: Control = SCN.instantiate()
	get_tree().root.add_child(page)
	await _settle(12)
	await _assert_info(page, leader, "desk")
	page.queue_free()
	await _settle(2)

func _run_mobile() -> void:
	OS.set_environment("CK_FORCE_MOBILE", "1")
	_ok(DeviceProfile.is_mobile(), "CK_FORCE_MOBILE flips DeviceProfile")
	var leader := _boot()
	var page: Control = SCN.instantiate()
	get_tree().root.add_child(page)
	await _settle(12)
	if page.has_method("apply_mobile_layout"):
		page.call("apply_mobile_layout")
		await _settle(6)
	await _assert_info(page, leader, "mob")
	page.queue_free()
	await _settle(2)
	OS.set_environment("CK_FORCE_MOBILE", "")
