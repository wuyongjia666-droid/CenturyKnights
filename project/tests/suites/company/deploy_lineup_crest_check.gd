extends Node
## Headless E2E: deploy 出征编队 strip + slot/focus person shields via CKHeraldryField.
## Muster strip is 团徽 + one leader shield. Cards and focus are one shield per person.
## Family → 族徽. No family → company banner. No marshalling, no cadency.
## Reserve strip stays Field. Desktop + mobile. Real deploy scene.

const SCN := preload("res://scenes/hub/deploy.tscn")
var _fails: Array = []

func _ready() -> void:
	await get_tree().process_frame
	await _run_desktop()
	await _run_mobile()
	if _fails.is_empty():
		print("DEPLOY LINEUP CREST PASS")
		get_tree().quit(0)
	else:
		for f in _fails:
			print("FAIL deploy lineup crest: ", f)
		get_tree().quit(1)

func _ok(cond: bool, msg: String) -> void:
	print("ROW %s %s" % ["PASS" if cond else "FAIL", msg])
	if not cond:
		_fails.append(msg)

func _settle(n: int = 8) -> void:
	for i in n:
		await get_tree().process_frame

func _boot() -> void:
	GameState.new_game("出征徽", "灰旗", GameState.crest_color)
	GameState.chapter0_flags["chapter0_done"] = true
	GameState.chapter0_flags["ch0_playing"] = false
	UnlockSchedule.install()
	World.events_enabled = false
	World.rivals_enabled = false
	var lead: CKCharacter = GameState.get_leader()
	if lead != null and not (lead.id in GameState.deploy_ids):
		GameState.deploy_ids = [lead.id]
	var loner := CKCharacter.new()
	loner.id = "deploy_loner"
	loner.name = "散卒"
	loner.age = 22
	loner.alive = true
	loner.in_roster = true
	loner.is_leader = false
	loner.family_id = ""
	loner.job_id = "light_inf"
	loner.rank = "knight"
	loner.gender = "m"
	GameState.characters[loner.id] = loner

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

func _no_marks(node: Node, where: String) -> void:
	var bad := false
	var marks: Array = []
	_collect(node, "RankBadge", marks)
	_collect(node, "Cadency", marks)
	_collect(node, "Impale", marks)
	_collect(node, "Quartered", marks)
	bad = not marks.is_empty()
	_ok(not bad, "%s no cadency or marshalling" % where)

func _assert_strip(page: Node, where: String, expect_family: bool) -> void:
	_ok(page.find_child("EmptyHost", true, false) == null, "%s no EmptyHost" % where)
	var strip := page.find_child("MusterCrestStrip", true, false)
	_ok(strip != null, "%s MusterCrestStrip" % where)
	if strip == null:
		return
	_ok(str(strip.get_meta("field_route", "")) == "deploy_muster", "%s strip field_route" % where)
	_ok(strip.mouse_filter == Control.MOUSE_FILTER_IGNORE, "%s strip ignores mouse" % where)
	var ca := strip.find_child("CastleArms", true, false)
	var la := strip.find_child("LeaderArms", true, false)
	var ban := CKHeraldry.core_key(CKHeraldryChrome.company_spec())
	var lead: CKCharacter = GameState.get_leader()
	var fam := CKHeraldry.core_key(GameState.arms_for_character(lead))
	_ok(ca != null and str(ca.get_meta("arms_kind", "")) == "gen2_36", "%s strip 团徽" % where)
	_ok(la != null, "%s LeaderArms" % where)
	if ca != null:
		_ok(str(ca.get_meta("arms_core", "")) == ban, "%s strip company core" % where)
	if la != null:
		if expect_family:
			_ok(str(la.get_meta("arms_kind", "")) == "gen2_06", "%s leader 族徽" % where)
			_ok(str(la.get_meta("arms_core", "")) == fam, "%s leader family core" % where)
			_ok(str(la.get_meta("arms_core", "")) != ban, "%s leader shield != 团徽" % where)
		else:
			_ok(str(la.get_meta("arms_kind", "")) == "gen2_35", "%s familyless leader 旗徽" % where)
			_ok(str(la.get_meta("arms_core", "")) == ban, "%s familyless leader is company banner" % where)
	var shields := 0
	for ch in strip.get_children():
		if str(ch.name).ends_with("Arms"):
			shields += 1
	_ok(shields == 2, "%s strip is 团徽 + one person shield" % where)
	_no_marks(strip, where + " strip")

func _assert_slots(page: Node, where: String) -> void:
	var ban := CKHeraldry.core_key(CKHeraldryChrome.company_spec())
	var lead: CKCharacter = GameState.get_leader()
	var fam := CKHeraldry.core_key(GameState.arms_for_character(lead))
	var slots: Array = []
	_collect(page, "DeployArms", slots)
	_ok(slots.size() >= 2, "%s DeployArms count %d" % [where, slots.size()])
	var saw_fam := false
	var saw_ban := false
	for a in slots:
		_ok(str(a.get_meta("field_route", "")) == "deploy_slot", "%s slot field_route" % where)
		_ok(a.mouse_filter == Control.MOUSE_FILTER_IGNORE, "%s slot ignores mouse" % where)
		var parent: Node = a.get_parent()
		var n := 0
		if parent != null:
			for ch in parent.get_children():
				if str(ch.name) == "DeployArms":
					n += 1
		_ok(n == 1, "%s one DeployArms per card" % where)
		var kind := str(a.get_meta("arms_kind", ""))
		var core := str(a.get_meta("arms_core", ""))
		if kind == "gen2_06" and core == fam:
			saw_fam = true
		elif kind == "gen2_35" and core == ban:
			saw_ban = true
	_ok(saw_fam, "%s a slotted family shield" % where)
	_ok(saw_ban, "%s a slotted company banner" % where)
	var foci: Array = []
	_collect(page, "FocusArms", foci)
	_ok(foci.size() == 1, "%s one FocusArms" % where)
	if foci.size() == 1:
		var fa: Node = foci[0]
		_ok(str(fa.get_meta("field_route", "")) == "deploy_focus", "%s focus field_route" % where)
		var focus = page.get("_focus")
		if focus != null:
			var want := CKHeraldry.core_key(GameState.arms_for_character(focus))
			_ok(str(fa.get_meta("arms_core", "")) == want, "%s focus matches the selected person" % where)

func _run_desktop() -> void:
	OS.set_environment("CK_FORCE_MOBILE", "0")
	_boot()
	var page := _open()
	await _settle(12)
	_assert_strip(page, "desk", true)
	_assert_slots(page, "desk")
	page.queue_free()
	await _settle(2)
	var lead: CKCharacter = GameState.get_leader()
	lead.family_id = ""
	var bare := _open()
	await _settle(10)
	_assert_strip(bare, "desk-bare", false)
	bare.queue_free()
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
	_assert_strip(page, "mob", true)
	_assert_slots(page, "mob")
	page.queue_free()
	await _settle(2)
	OS.set_environment("CK_FORCE_MOBILE", "")
