extends Node
## Fat heraldry E2E: roster via CKHeraldryField (RosterCrestStrip + RosterRowArms + HireArms), desk + mobile.

const SCN := preload("res://scenes/hub/roster.tscn")
var _fails: Array = []

func _ready() -> void:
	await get_tree().process_frame
	await _run_desktop()
	await _run_mobile()
	if _fails.is_empty():
		print("ROSTER FIELD CREST PASS")
		print("ROSTER CREST PASS")
		get_tree().quit(0)
	else:
		for f in _fails:
			print("FAIL roster crest: ", f)
		get_tree().quit(1)

func _ok(cond: bool, msg: String) -> void:
	print("ROW %s %s" % ["PASS" if cond else "FAIL", msg])
	if not cond:
		_fails.append(msg)

func _settle(n: int = 6) -> void:
	for i in n:
		await get_tree().process_frame

func _boot() -> void:
	GameState.new_game("名册徽", "霜旗", GameState.crest_color)
	GameState.set_flag("chapter0_done", true)
	UnlockSchedule.install()
	World.events_enabled = false
	World.rivals_enabled = false

func _collect(n: Node, name: String, out: Array) -> void:
	if n.name == name:
		out.append(n)
	for c in n.get_children():
		_collect(c, name, out)

func _assert_page(page: Node, where: String) -> void:
	var strip = page.find_child("RosterCrestStrip", true, false)
	_ok(strip != null, "%s RosterCrestStrip" % where)
	if strip != null:
		_ok(str(strip.get_meta("field_route", "")) == "roster_strip", "%s strip field_route" % where)
		_ok(strip.find_child("CastleArms", true, false) != null, "%s strip CastleArms" % where)
		var bn = strip.find_child("RosterBanner", true, false)
		_ok(bn != null and str(bn.get_meta("arms_kind", "")) == "lb_roster_arms", "%s RosterBanner" % where)
		_ok(bn != null and str(bn.get_meta("field_route", "")) == "roster_banner", "%s roster_banner route" % where)
		_ok(strip.get_child_count() == 2, "%s roster child_count=2" % where)
	_ok(page.find_child("CastleArms", true, false) != null, "%s CastleArms header" % where)
	var rows: Array = []
	_collect(page, "RosterRowArms", rows)
	_ok(rows.size() >= 1, "%s RosterRowArms count=%d" % [where, rows.size()])
	for a in rows:
		_ok(str(a.get_meta("arms_kind", "")) in ["gen2_06", "gen2_35"], "%s RosterRowArms kind" % where)
		_ok(str(a.get_meta("field_route", "")) == "roster_row", "%s RosterRowArms field_route" % where)
	## Hire plate Field arms still present after select.
	var hire = page.find_child("HireArms", true, false)
	_ok(hire != null, "%s HireArms dossier" % where)
	if hire != null:
		_ok(str(hire.get_meta("field_route", "")) == "hire_plate", "%s HireArms field_route" % where)

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
		await _settle(8)
	_assert_page(page, "mob")
	page.queue_free()
	await _settle(2)
	OS.set_environment("CK_FORCE_MOBILE", "")
