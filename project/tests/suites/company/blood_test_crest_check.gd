extends Node
## Fat heraldry E2E: blood assay — BloodCrestStrip + BloodQueueArms (desk + mobile).

const SCN := preload("res://scenes/hub/blood_test.tscn")
var _fails: Array = []

func _ready() -> void:
	await get_tree().process_frame
	await _run_desktop()
	await _run_mobile()
	if _fails.is_empty():
		print("BLOOD CREST PASS")
		get_tree().quit(0)
	else:
		for f in _fails:
			print("FAIL blood crest: ", f)
		get_tree().quit(1)

func _ok(cond: bool, msg: String) -> void:
	print("ROW %s %s" % ["PASS" if cond else "FAIL", msg])
	if not cond:
		_fails.append(msg)

func _settle(n: int = 6) -> void:
	for i in n:
		await get_tree().process_frame

func _boot() -> void:
	GameState.new_game("血验徽", "灰旗", GameState.crest_color)
	GameState.set_flag("chapter0_done", true)
	UnlockSchedule.install()
	World.events_enabled = false
	World.rivals_enabled = false
	GameState.silver = 8000
	# ensure someone needs verify
	for ch in GameState.roster():
		if ch != null and "blood_verified" in ch:
			ch.blood_verified = false
		elif ch != null:
			ch.set("bloodline_verified", false)

func _collect(n: Node, name: String, out: Array) -> void:
	if n.name == name:
		out.append(n)
	for ch in n.get_children():
		_collect(ch, name, out)

func _assert_page(page: Node, where: String) -> void:
	var strip = page.find_child("BloodCrestStrip", true, false)
	_ok(strip != null, "%s BloodCrestStrip" % where)
	if strip != null:
		var ca = strip.find_child("CastleArms", true, false)
		_ok(ca != null and str(ca.get_meta("arms_kind", "")) == "gen2_36", "%s 团徽" % where)
		var bn = strip.find_child("BloodBanner", true, false)
		_ok(bn != null and str(bn.get_meta("arms_kind", "")) == "lb_blood_arms", "%s BloodBanner" % where)
	var rows: Array = []
	_collect(page, "BloodQueueArms", rows)
	# queue may be empty if all verified; strip still required
	if rows.size() >= 1:
		_ok(str(rows[0].get_meta("arms_core", "")) != "", "%s BloodQueueArms core" % where)

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
