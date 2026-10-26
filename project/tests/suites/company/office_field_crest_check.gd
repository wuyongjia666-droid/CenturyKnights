extends Node
## Headless E2E: estates field-book person plates (属事处) via CKHeraldryField.
## Family → 族徽. Familyless kin → company banner. One shield per row.
## No marriage marshalling, no per-person cadency. Desktop + mobile. Real estates scene.

const SCN := preload("res://scenes/hub/estates.tscn")
var _fails: Array = []

func _ready() -> void:
	await get_tree().process_frame
	await _run_desktop()
	await _run_mobile()
	if _fails.is_empty():
		print("OFFICE FIELD CREST PASS")
		get_tree().quit(0)
	else:
		for f in _fails:
			print("FAIL office field crest: ", f)
		get_tree().quit(1)

func _ok(cond: bool, msg: String) -> void:
	print("ROW %s %s" % ["PASS" if cond else "FAIL", msg])
	if not cond:
		_fails.append(msg)

func _settle(n: int = 8) -> void:
	for i in n:
		await get_tree().process_frame

func _boot() -> CKCharacter:
	GameState.new_game("属事徽", "灰旗", GameState.crest_color)
	GameState.set_flag("chapter0_done", true)
	UnlockSchedule.install()
	World.events_enabled = false
	World.rivals_enabled = false
	GameState.silver = 8000
	GameState.food = 40
	var lead: CKCharacter = GameState.get_leader()
	var loner := CKCharacter.new()
	loner.id = "office_loner"
	loner.name = "散吏"
	loner.age = 26
	loner.alive = true
	loner.in_roster = true
	loner.is_leader = false
	loner.is_child = false
	loner.family_id = ""
	loner.job_id = "light_inf"
	loner.rank = "knight"
	loner.gender = "m"
	if lead != null:
		loner.parent_ids = [lead.id]
	GameState.characters[loner.id] = loner
	return loner

func _collect(n: Node, node_name: String, out: Array) -> void:
	if n.name == node_name:
		out.append(n)
	for c in n.get_children():
		_collect(c, node_name, out)

func _open() -> Control:
	var page: Control = SCN.instantiate()
	page.set_anchors_preset(Control.PRESET_TOP_LEFT)
	page.position = Vector2.ZERO
	page.size = Vector2(1280, 720)
	get_tree().root.add_child(page)
	return page

func _assert_book(page: Node, where: String) -> void:
	page.call("open_field_book")
	var book := page.find_child("FieldBook", true, false)
	_ok(book != null, "%s FieldBook" % where)
	if book != null:
		_ok(book.find_child("EmptyHost", true, false) == null, "%s field book is not an EmptyHost" % where)
	if book == null:
		return
	var strip := book.find_child("FieldCrestStrip", true, false)
	_ok(strip != null, "%s FieldCrestStrip remains" % where)
	var lead: CKCharacter = GameState.get_leader()
	var fam := CKHeraldry.core_key(GameState.arms_for_character(lead))
	var ban := CKHeraldry.core_key(CKHeraldryChrome.company_spec())
	var arms: Array = []
	_collect(book, "FieldRowArms", arms)
	_ok(arms.size() >= 2, "%s FieldRowArms count %d" % [where, arms.size()])
	var saw_fam := false
	var saw_ban := false
	for a in arms:
		_ok(str(a.get_meta("field_route", "")) == "office_field", "%s field_route office_field" % where)
		_ok(a.mouse_filter == Control.MOUSE_FILTER_IGNORE, "%s shield ignores mouse" % where)
		var row: Node = a.get_parent()
		_ok(row != null, "%s shield has a row" % where)
		if row == null:
			continue
		var shields := 0
		var bad := false
		for ch in row.get_children():
			var nm := str(ch.name)
			if nm.ends_with("Arms"):
				shields += 1
			if nm in ["RankBadge", "Cadency", "Impale", "Quartered"]:
				bad = true
		_ok(shields == 1, "%s one shield per person" % where)
		_ok(not bad, "%s no cadency or marshalling" % where)
		var kind := str(a.get_meta("arms_kind", ""))
		var core := str(a.get_meta("arms_core", ""))
		if kind == "gen2_06" and core == fam:
			saw_fam = true
			_ok(core != ban, "%s family shield is not the company core" % where)
		elif kind == "gen2_35" and core == ban:
			saw_ban = true
	_ok(saw_fam, "%s family arms on a field row" % where)
	_ok(saw_ban, "%s familyless row wears company banner" % where)

func _run_desktop() -> void:
	OS.set_environment("CK_FORCE_MOBILE", "0")
	_boot()
	var page := _open()
	await _settle(12)
	_assert_book(page, "desk")
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
		await _settle(6)
	_assert_book(page, "mob")
	page.queue_free()
	await _settle(2)
	OS.set_environment("CK_FORCE_MOBILE", "")
