extends Node
## Fat heraldry E2E: lineage dossier info plate owns LineageInfoArms via CKHeraldryField.
## Real lineage_view + select(); desk + mobile. Asserts field_route and arms_kind.

const OVERVIEW := "res://scenes/hub/lineage_view.tscn"
const INFO_SRC := "res://scripts/hub/lineage_info.gd"

var _fails: Array = []

func _ready() -> void:
	await get_tree().process_frame
	var dummy := Node.new()
	get_tree().root.add_child(dummy)
	get_tree().current_scene = dummy
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

func _await_scene(path: String) -> Node:
	for _i in 40:
		await get_tree().process_frame
		var sc := get_tree().current_scene
		if sc != null and sc.scene_file_path == path:
			await _settle(3)
			return sc
	return null

func _assert_info(page: Node, leader: CKCharacter, where: String) -> void:
	var src := FileAccess.get_file_as_string(INFO_SRC)
	_ok(src.find("CKHeraldryField.attach_lineage_info_arms") >= 0, "%s info calls CKHeraldryField" % where)
	_ok(page.has_method("select"), "%s select API" % where)
	page.call("select", leader)
	await _settle(8)
	var arms := page.find_child("LineageInfoArms", true, false)
	_ok(arms != null, "%s LineageInfoArms" % where)
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
	CKNav.home()
	await _settle()
	_ok(CKNav.go(OVERVIEW), "desk go overview")
	var page := await _await_scene(OVERVIEW)
	_ok(page != null, "desk overview loaded")
	if page != null:
		await _assert_info(page, leader, "desk")
	CKNav.home()
	await _settle(4)

func _run_mobile() -> void:
	OS.set_environment("CK_FORCE_MOBILE", "1")
	_ok(DeviceProfile.is_mobile(), "CK_FORCE_MOBILE flips DeviceProfile")
	var leader := _boot()
	CKNav.home()
	await _settle()
	_ok(CKNav.go(OVERVIEW), "mob go overview")
	var page := await _await_scene(OVERVIEW)
	_ok(page != null, "mob overview loaded")
	if page != null:
		if page.has_method("apply_mobile_layout"):
			page.call("apply_mobile_layout")
			await _settle(6)
		await _assert_info(page, leader, "mob")
	CKNav.home()
	await _settle(4)
	OS.set_environment("CK_FORCE_MOBILE", "")
