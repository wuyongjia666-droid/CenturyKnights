extends Node
## Fat heraldry E2E: FieldBook 属事处 — FieldCrestStrip + FieldRowArms (desk + mobile).

const SCN := preload("res://scenes/hub/estates.tscn")
var _fails: Array = []

func _ready() -> void:
	await get_tree().process_frame
	await _run_desktop()
	await _run_mobile()
	if _fails.is_empty():
		print("FIELD BOOK CREST PASS")
		get_tree().quit(0)
	else:
		for f in _fails:
			print("FAIL field book crest: ", f)
		get_tree().quit(1)

func _ok(cond: bool, msg: String) -> void:
	print("ROW %s %s" % ["PASS" if cond else "FAIL", msg])
	if not cond:
		_fails.append(msg)

func _settle(n: int = 6) -> void:
	for i in n:
		await get_tree().process_frame

func _boot() -> void:
	GameState.new_game("属事徽", "灰旗", GameState.crest_color)
	GameState.set_flag("chapter0_done", true)
	UnlockSchedule.install()
	World.events_enabled = false
	World.rivals_enabled = false
	GameState.silver = 8000
	GameState.food = 40
	# unlock one holding so field list has work buttons
	for hid in GameState.HOLDING_DEFS.keys():
		GameState.holdings[str(hid)] = {"level": 1, "steward_id": "", "focus": "cash", "focus_cd": 0}
		break
	var lead := GameState.get_leader()
	if lead != null:
		CKPurse.set_purse(lead, 6)

func _assert_field(book: Node, where: String) -> void:
	var strip = book.find_child("FieldCrestStrip", true, false)
	_ok(strip != null, "%s FieldCrestStrip" % where)
	if strip != null:
		var ca = strip.find_child("CastleArms", true, false)
		_ok(ca != null and str(ca.get_meta("arms_kind", "")) == "gen2_36", "%s 团徽" % where)
		var bn = strip.find_child("FieldBanner", true, false)
		_ok(bn != null and str(bn.get_meta("arms_kind", "")) == "lb_field_arms", "%s FieldBanner" % where)
	var rows: Array = []
	_collect(book, "FieldRowArms", rows)
	_ok(rows.size() >= 1, "%s FieldRowArms count %d" % [where, rows.size()])
	if not rows.is_empty():
		var ra = rows[0]
		_ok(str(ra.get_meta("arms_core", "")) != "", "%s FieldRowArms core" % where)

func _collect(n: Node, name: String, out: Array) -> void:
	if n.name == name:
		out.append(n)
	for ch in n.get_children():
		_collect(ch, name, out)

func _run_desktop() -> void:
	OS.set_environment("CK_FORCE_MOBILE", "0")
	_boot()
	var page: Control = SCN.instantiate()
	get_tree().root.add_child(page)
	await _settle(10)
	page.call("open_field_book")
	await _settle(10)
	var book := page.find_child("FieldBook", true, false)
	_ok(book != null, "desk FieldBook")
	if book:
		_assert_field(book, "desk")
	page.queue_free()
	await _settle(2)

func _run_mobile() -> void:
	OS.set_environment("CK_FORCE_MOBILE", "1")
	_ok(DeviceProfile.is_mobile(), "CK_FORCE_MOBILE flips DeviceProfile")
	_boot()
	var page: Control = SCN.instantiate()
	get_tree().root.add_child(page)
	await _settle(10)
	if page.has_method("apply_mobile_layout"):
		page.call("apply_mobile_layout")
		await _settle(6)
	page.call("open_field_book")
	await _settle(10)
	var book := page.find_child("FieldBook", true, false)
	_ok(book != null, "mob FieldBook")
	if book:
		_assert_field(book, "mob")
	page.queue_free()
	await _settle(2)
	OS.set_environment("CK_FORCE_MOBILE", "")
