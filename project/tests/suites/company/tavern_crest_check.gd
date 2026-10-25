extends Node
## Fat heraldry E2E: tavern hire strip (团徽 + focused 族徽|旗徽) on desktop + mobile.
## Cards keep HireArms. Empty bar still has EmptyHost and a company-only strip.
## Fails when TavernCrestStrip / HireFocusArms / HireArms chrome is missing.

const SCN := preload("res://scenes/hub/tavern.tscn")
var _fails: Array = []

func _ready() -> void:
	await get_tree().process_frame
	await _run_desktop()
	await _run_mobile()
	if _fails.is_empty():
		print("TAVERN CREST PASS")
		get_tree().quit(0)
	else:
		for f in _fails:
			print("FAIL tavern crest: ", f)
		get_tree().quit(1)

func _ok(cond: bool, msg: String) -> void:
	print("ROW %s %s" % ["PASS" if cond else "FAIL", msg])
	if not cond:
		_fails.append(msg)

func _settle(n: int = 8) -> void:
	for i in n:
		await get_tree().process_frame

func _boot() -> void:
	GameState.new_game("酒馆徽", "灰旗", GameState.crest_color)
	GameState.set_flag("chapter0_done", true)
	UnlockSchedule.install()
	World.events_enabled = false
	World.rivals_enabled = false
	var lead: CKCharacter = GameState.get_leader()
	var kin := CKCharacter.new()
	kin.id = "tavern_kin"
	kin.name = "族聘"
	kin.age = 24
	kin.alive = true
	kin.in_roster = false
	kin.family_id = str(lead.family_id)
	kin.job_id = "light_inf"
	kin.rank = "knight"
	var loner := CKCharacter.new()
	loner.id = "tavern_loner"
	loner.name = "客刃"
	loner.age = 22
	loner.alive = true
	loner.in_roster = false
	loner.family_id = ""
	loner.job_id = "hunter"
	loner.rank = "knight"
	GameState.tavern_candidates = [kin, loner]

func _collect(n: Node, node_name: String, out: Array) -> void:
	if n.name == node_name:
		out.append(n)
	for c in n.get_children():
		_collect(c, node_name, out)

func _assert_filled(page: Node, where: String) -> void:
	var lead: CKCharacter = GameState.get_leader()
	var ban := CKHeraldry.core_key(CKHeraldryChrome.company_spec())
	var fam := CKHeraldry.core_key(GameState.arms_for_character(lead))
	var strips: Array = []
	_collect(page, "TavernCrestStrip", strips)
	_ok(not strips.is_empty(), "%s TavernCrestStrip" % where)
	if strips.is_empty():
		return
	var strip: Node = strips[0]
	var ca := strip.find_child("CastleArms", true, false)
	var fa := strip.find_child("HireFocusArms", true, false)
	_ok(ca != null and str(ca.get_meta("arms_kind", "")) == "gen2_36", "%s strip 团徽" % where)
	_ok(fa != null and str(fa.get_meta("arms_kind", "")) == "gen2_06", "%s HireFocusArms 族徽" % where)
	if ca != null and fa != null:
		_ok(str(ca.get_meta("arms_core", "")) == ban, "%s strip company core" % where)
		_ok(str(fa.get_meta("arms_core", "")) == fam, "%s focus family core" % where)
		_ok(str(fa.get_meta("arms_core", "")) != str(ca.get_meta("arms_core", "")), "%s 族徽!=团徽" % where)
	_ok(strip.get_child_count() == 2, "%s strip is two shields, no marshalling" % where)
	_ok(strip.mouse_filter == Control.MOUSE_FILTER_IGNORE, "%s strip ignores mouse" % where)
	var hires: Array = []
	_collect(page, "HireArms", hires)
	_ok(hires.size() >= 2, "%s HireArms on cards" % where)
	var saw_fam := false
	var saw_flag := false
	for a in hires:
		var k := str(a.get_meta("arms_kind", ""))
		if k == "gen2_06":
			saw_fam = true
			_ok(str(a.get_meta("arms_core", "")) == fam, "%s card 族徽 core" % where)
		elif k == "gen2_35":
			saw_flag = true
			_ok(str(a.get_meta("arms_core", "")) == ban, "%s card 旗徽 is castle banner" % where)
		else:
			_ok(false, "%s unexpected HireArms kind %s" % [where, k])
	_ok(saw_fam and saw_flag, "%s both 族徽 and 旗徽 cards" % where)
	_ok(page.find_child("EmptyHost", true, false) == null, "%s filled page has no EmptyHost" % where)

func _assert_empty(page: Node, where: String) -> void:
	var strips: Array = []
	_collect(page, "TavernCrestStrip", strips)
	_ok(not strips.is_empty(), "%s empty TavernCrestStrip" % where)
	if not strips.is_empty():
		var strip: Node = strips[0]
		_ok(strip.find_child("CastleArms", true, false) != null, "%s empty 团徽" % where)
		_ok(strip.find_child("HireFocusArms", true, false) == null, "%s empty has no person arms" % where)
	_ok(page.find_child("EmptyHost", true, false) != null, "%s EmptyHost stays" % where)
	_ok(page.find_child("ToRoster", true, false) != null, "%s ToRoster stays" % where)

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
	_assert_filled(page, "desk")
	GameState.tavern_candidates.clear()
	page._refresh()
	await _settle(4)
	_assert_empty(page, "desk-empty")
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
	_ok(page.find_child("MobileTopBar", true, false) != null, "mob MobileTopBar")
	_assert_filled(page, "mob")
	var bar := page.find_child("MobileTopBar", true, false)
	_ok(bar != null and bar.find_child("TavernCrestStrip", true, false) != null, "mob strip on top bar")
	GameState.tavern_candidates.clear()
	page._refresh()
	await _settle(4)
	_assert_empty(page, "mob-empty")
	page.queue_free()
	await _settle(2)
	OS.set_environment("CK_FORCE_MOBILE", "")
