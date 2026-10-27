extends Node
## Fat heraldry E2E: deploy reserve strip (团徽 + appointed 族徽) desktop + mobile.
## Cycling the reserve button drops ReserveArms and keeps the castle banner.
## Fails when ReserveCrestStrip is missing.

const SCN := preload("res://scenes/hub/deploy.tscn")
var _fails: Array = []

func _ready() -> void:
	await get_tree().process_frame
	await _run_desktop()
	await _run_mobile()
	if _fails.is_empty():
		print("DEPLOY RESERVE CREST PASS")
		get_tree().quit(0)
	else:
		for f in _fails:
			print("FAIL deploy reserve crest: ", f)
		get_tree().quit(1)

func _ok(cond: bool, msg: String) -> void:
	print("ROW %s %s" % ["PASS" if cond else "FAIL", msg])
	if not cond:
		_fails.append(msg)

func _settle(n: int = 8) -> void:
	for i in n:
		await get_tree().process_frame

func _boot() -> CKCharacter:
	GameState.new_game("预备徽", "灰旗", GameState.crest_color)
	GameState.chapter0_flags["chapter0_done"] = true
	GameState.chapter0_flags["ch0_playing"] = false
	UnlockSchedule.install()
	World.events_enabled = false
	World.rivals_enabled = false
	var lead: CKCharacter = GameState.get_leader()
	if lead != null and not (lead.id in GameState.deploy_ids):
		GameState.deploy_ids = [lead.id]
	var bench := CKCharacter.new()
	bench.id = "reserve_kin"
	bench.name = "候旗"
	bench.age = 23
	bench.alive = true
	bench.in_roster = true
	bench.is_leader = false
	bench.family_id = str(lead.family_id)
	bench.job_id = "light_inf"
	bench.rank = "knight"
	bench.gender = "m"
	GameState.characters[bench.id] = bench
	GameState.buildings["hall"] = 4
	GameState.house_mods["reserve_id"] = bench.id
	return bench

func _assert_appointed(page: Node, where: String, bench: CKCharacter) -> void:
	var strip := page.find_child("ReserveCrestStrip", true, false)
	_ok(strip != null, "%s ReserveCrestStrip" % where)
	if strip == null:
		return
	var ban := CKHeraldry.core_key(CKHeraldryChrome.company_spec())
	var fam := CKHeraldry.core_key(GameState.arms_for_character(bench))
	var ca := strip.find_child("CastleArms", true, false)
	var ra := strip.find_child("ReserveArms", true, false)
	_ok(ca != null and str(ca.get_meta("arms_kind", "")) == "gen2_36", "%s 团徽" % where)
	_ok(ra != null and str(ra.get_meta("arms_kind", "")) == "gen2_06", "%s ReserveArms 族徽" % where)
	if ca != null and ra != null:
		_ok(str(ca.get_meta("arms_core", "")) == ban, "%s company core" % where)
		_ok(str(ra.get_meta("arms_core", "")) == fam, "%s reserve family core" % where)
		_ok(str(ra.get_meta("arms_core", "")) != ban, "%s 族徽!=团徽" % where)
	_ok(strip.get_child_count() == 3, "%s two shields + cloth banner" % where)
	var rbn := strip.find_child("ReserveBanner", true, false)
	_ok(rbn != null and str(rbn.get_meta("field_route", "")) == "reserve_banner", "%s reserve_banner" % where)
	_ok(strip.mouse_filter == Control.MOUSE_FILTER_IGNORE, "%s ignores mouse" % where)
	_ok(page.find_child("ReserveBtn", true, false) != null, "%s ReserveBtn" % where)

func _assert_cleared(page: Node, where: String) -> void:
	var strip := page.find_child("ReserveCrestStrip", true, false)
	_ok(strip != null, "%s strip remains after cycle" % where)
	if strip == null:
		return
	_ok(strip.find_child("CastleArms", true, false) != null, "%s 团徽 remains" % where)
	_ok(strip.find_child("ReserveArms", true, false) == null, "%s ReserveArms cleared" % where)
	_ok(strip.get_child_count() == 2, "%s company + cloth banner" % where)
	_ok(strip.find_child("ReserveBanner", true, false) != null, "%s ReserveBanner remains" % where)

func _open() -> Control:
	var page: Control = SCN.instantiate()
	page.set_anchors_preset(Control.PRESET_TOP_LEFT)
	page.position = Vector2.ZERO
	page.size = Vector2(1280, 720)
	get_tree().root.add_child(page)
	return page

func _cycle(page: Node) -> void:
	var btn := page.find_child("ReserveBtn", true, false) as BaseButton
	_ok(btn != null, "ReserveBtn to cycle")
	if btn != null:
		btn.pressed.emit()

func _run_desktop() -> void:
	OS.set_environment("CK_FORCE_MOBILE", "0")
	var bench := _boot()
	var page := _open()
	await _settle(12)
	_assert_appointed(page, "desk", bench)
	_cycle(page)
	await _settle(4)
	_assert_cleared(page, "desk-cycle")
	page.queue_free()
	await _settle(2)

func _run_mobile() -> void:
	OS.set_environment("CK_FORCE_MOBILE", "1")
	_ok(DeviceProfile.is_mobile(), "CK_FORCE_MOBILE flips DeviceProfile")
	var bench := _boot()
	var page := _open()
	await _settle(12)
	if page.has_method("apply_mobile_layout"):
		page.apply_mobile_layout()
		await _settle(6)
	_assert_appointed(page, "mob", bench)
	_cycle(page)
	await _settle(4)
	_assert_cleared(page, "mob-cycle")
	page.queue_free()
	await _settle(2)
	OS.set_environment("CK_FORCE_MOBILE", "")
