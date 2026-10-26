extends Node
## Fat heraldry E2E: forge company chrome + ForgeFocusStrip (团徽+选中铁匠) + ForgeSlotArms
## on each smith row. Desktop + mobile. Kin 族徽 and loner 旗徽 both appear.

const SCN := preload("res://scenes/hub/forge.tscn")
var _fails: Array = []

func _ready() -> void:
	await get_tree().process_frame
	await _run_desktop()
	await _run_mobile()
	if _fails.is_empty():
		print("FORGE CREST PASS")
		get_tree().quit(0)
	else:
		for f in _fails:
			print("FAIL forge crest: ", f)
		get_tree().quit(1)

func _ok(cond: bool, msg: String) -> void:
	print("ROW %s %s" % ["PASS" if cond else "FAIL", msg])
	if not cond:
		_fails.append(msg)

func _settle(n: int = 8) -> void:
	for i in n:
		await get_tree().process_frame

func _boot() -> void:
	GameState.new_game("炉火徽", "灰旗", GameState.crest_color)
	GameState.set_flag("chapter0_done", true)
	UnlockSchedule.install()
	World.events_enabled = false
	World.rivals_enabled = false
	GameState.silver = 8000
	GameState.iron = 40
	var lead: CKCharacter = GameState.get_leader()
	# Ensure a familyless smith so 旗徽 appears beside 族徽.
	var loner := CKCharacter.new()
	loner.id = "forge_loner"
	loner.name = "客匠"
	loner.age = 26
	loner.alive = true
	loner.in_roster = true
	loner.family_id = ""
	loner.job_id = "light_inf"
	loner.rank = "knight"
	loner.hp = loner.max_hp
	GameState.characters[loner.id] = loner

func _collect(n: Node, node_name: String, out: Array) -> void:
	if n.name == node_name:
		out.append(n)
	for c in n.get_children():
		_collect(c, node_name, out)

func _assert_page(page: Node, where: String) -> void:
	var lead: CKCharacter = GameState.get_leader()
	var ban := CKHeraldry.core_key(CKHeraldryChrome.company_spec())
	var fam := CKHeraldry.core_key(GameState.arms_for_character(lead))
	_ok(page.find_child("CastleArms", true, false) != null, "%s CastleArms" % where)
	_ok(page.find_child("CastleBannerStrip", true, false) != null or page.find_child("CastleBanner", true, false) != null, "%s banner chrome" % where)
	var strips: Array = []
	_collect(page, "ForgeFocusStrip", strips)
	_ok(not strips.is_empty(), "%s ForgeFocusStrip" % where)
	if not strips.is_empty():
		var strip: Node = strips[0]
		var ca := strip.find_child("CastleArms", true, false)
		var fa := strip.find_child("ForgeFocusArms", true, false)
		_ok(ca != null and str(ca.get_meta("arms_kind", "")) == "gen2_36", "%s strip 团徽" % where)
		_ok(fa != null, "%s ForgeFocusArms present" % where)
		if ca != null and fa != null:
			_ok(str(ca.get_meta("arms_core", "")) == ban, "%s strip company core" % where)
			_ok(str(fa.get_meta("arms_core", "")) != str(ca.get_meta("arms_core", "")) or str(fa.get_meta("arms_kind", "")) == "gen2_35", "%s focus != 团徽 or 旗徽" % where)
		_ok(strip.get_child_count() == 2, "%s strip two shields, no marshalling" % where)
		_ok(strip.mouse_filter == Control.MOUSE_FILTER_IGNORE, "%s strip ignores mouse" % where)
	var slots: Array = []
	_collect(page, "ForgeSlotArms", slots)
	_ok(slots.size() >= 2, "%s ForgeSlotArms on smith rows (>=2)" % where)
	var saw_fam := false
	var saw_flag := false
	for a in slots:
		var k := str(a.get_meta("arms_kind", ""))
		if k == "gen2_06":
			saw_fam = true
		elif k == "gen2_35":
			saw_flag = true
	_ok(saw_fam, "%s slot 族徽 present" % where)
	_ok(saw_flag, "%s slot 旗徽 present" % where)

func _open() -> Control:
	var page: Control = SCN.instantiate()
	page.set_anchors_preset(Control.PRESET_TOP_LEFT)
	page.position = Vector2.ZERO
	page.size = Vector2(1280, 720)
	get_tree().root.add_child(page)
	return page

func _run_desktop() -> void:
	OS.set_environment("CK_FORCE_MOBILE", "0")
	_boot()
	var page := _open()
	await _settle(12)
	_assert_page(page, "desk")
	page.queue_free()
	await _settle(2)

func _run_mobile() -> void:
	OS.set_environment("CK_FORCE_MOBILE", "1")
	_ok(DeviceProfile.is_mobile(), "CK_FORCE_MOBILE flips DeviceProfile")
	_boot()
	var page := _open()
	await _settle(8)
	if page.has_method("apply_mobile_layout"):
		page.apply_mobile_layout()
		await _settle(8)
	_assert_page(page, "mob")
	var bar := page.find_child("MobileTopBar", true, false)
	_ok(bar != null and bar.find_child("ForgeFocusStrip", true, false) != null, "mob strip on top bar")
	page.queue_free()
	await _settle(2)
	OS.set_environment("CK_FORCE_MOBILE", "")
