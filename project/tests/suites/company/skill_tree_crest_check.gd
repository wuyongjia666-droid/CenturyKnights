extends Node
## Fat heraldry E2E: skill tree — SkillCrestStrip + SkillBanner (desk + mobile).

const SCN := preload("res://scenes/hub/skill_tree.tscn")
var _fails: Array = []

func _ready() -> void:
	await get_tree().process_frame
	await _run_desktop()
	await _run_mobile()
	if _fails.is_empty():
		print("SKILL TREE CREST PASS")
		get_tree().quit(0)
	else:
		for f in _fails:
			print("FAIL skill tree: ", f)
		get_tree().quit(1)

func _ok(cond: bool, msg: String) -> void:
	print("ROW %s %s" % ["PASS" if cond else "FAIL", msg])
	if not cond:
		_fails.append(msg)

func _settle(n: int = 6) -> void:
	for i in n:
		await get_tree().process_frame

func _boot() -> void:
	GameState.new_game("市技时城", "灰旗", GameState.crest_color)
	GameState.set_flag("chapter0_done", true)
	UnlockSchedule.install()
	World.events_enabled = false
	World.rivals_enabled = false
	GameState.silver = 8000
	GameState.food = 40
	GameState.iron = 40
	GameState.skill_points = 3

func _assert_page(page: Node, where: String) -> void:
	var strip = page.find_child("SkillCrestStrip", true, false)
	_ok(strip != null, "%s SkillCrestStrip" % where)
	if strip != null:
		var ca = strip.find_child("CastleArms", true, false)
		_ok(ca != null and str(ca.get_meta("arms_kind", "")) == "gen2_36", "%s 团徽" % where)
		var bn = strip.find_child("SkillBanner", true, false)
		_ok(bn != null and str(bn.get_meta("arms_kind", "")) == "lb_skill_arms", "%s SkillBanner" % where)
	if where == "desk" or where == "mob":
		var spa = page.find_child("SkillPersonArms", true, false)
		_ok(spa != null, "%s SkillPersonArms" % where)


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
