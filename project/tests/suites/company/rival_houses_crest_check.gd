extends Node
## Fat heraldry E2E: rival_houses list+head RivalArms via Field (desk + mobile).

const SCN := preload("res://scenes/hub/rival_houses.tscn")
var _fails: Array = []


func _ready() -> void:
	await get_tree().process_frame
	await _run_desktop()
	await _run_mobile()
	_run_sources()
	if _fails.is_empty():
		print("RIVAL HOUSES CREST PASS")
		get_tree().quit(0)
	else:
		for f in _fails:
			print("FAIL rival houses crest: ", f)
		get_tree().quit(1)


func _ok(cond: bool, msg: String) -> void:
	print("ROW %s %s" % ["PASS" if cond else "FAIL", msg])
	if not cond:
		_fails.append(msg)


func _settle(n: int = 6) -> void:
	for _i in n:
		await get_tree().process_frame


func _boot() -> void:
	GameState.new_game("敌徽", "灰旗", GameState.crest_color)
	GameState.set_flag("chapter0_done", true)
	UnlockSchedule.install()
	World.events_enabled = false
	World.rivals_enabled = true


func _assert_page(page: Node, where: String) -> void:
	var houses: Array = GameState.data_rivals.get("houses", [])
	_ok(not houses.is_empty(), "%s rival houses exist" % where)
	if houses.is_empty():
		return
	var hid := str(houses[0].get("id", ""))
	var btn := page.find_child("House_%s" % hid, true, false)
	_ok(btn != null, "%s House_%s" % [where, hid])
	if btn != null:
		var ra := btn.find_child("RivalArms", true, false)
		_ok(ra != null and str(ra.get_meta("field_route", "")) == "rival_arms", "%s list RivalArms field_route" % where)
		if ra != null:
			_ok(str(ra.get_meta("arms_kind", "")) == "lb_rv_arms", "%s list RivalArms kind" % where)
			var want := CKHeraldry.core_key(CKHeraldryChrome.rival_spec(houses[0]))
			_ok(str(ra.get_meta("arms_core", "")) == want, "%s list RivalArms core" % where)
			_ok(ra.mouse_filter == Control.MOUSE_FILTER_IGNORE, "%s list RivalArms mouse" % where)
	# Head row RivalArms (may be multiple after select; pick field_route).
	var head_arms: Array = []
	for n in page.find_children("RivalArms", "", true, false):
		if str(n.get_meta("field_route", "")) == "rival_arms" and n.get_parent() != null and str(n.get_parent().name).begins_with("House_") == false:
			# Prefer non-button parent (HBox head).
			if n.get_parent() is HBoxContainer:
				head_arms.append(n)
	_ok(head_arms.size() >= 1, "%s head RivalArms count>=1 got %d" % [where, head_arms.size()])
	for ha in head_arms:
		_ok(str(ha.get_meta("arms_kind", "")) == "lb_rv_arms", "%s head RivalArms kind" % where)


func _run_sources() -> void:
	var src := FileAccess.get_file_as_string("res://scripts/hub/rival_houses.gd")
	_ok(src.find("CKHeraldryField.attach_rival_arms") >= 0, "rival_houses calls Field")
	_ok(src.find("CKHeraldryChrome.make_rival_arms") < 0, "rival_houses no direct Chrome.make_rival")


func _run_desktop() -> void:
	OS.set_environment("CK_FORCE_MOBILE", "0")
	_boot()
	var page: Control = SCN.instantiate()
	get_tree().root.add_child(page)
	await _settle(14)
	_assert_page(page, "desk")
	page.queue_free()
	await _settle(2)


func _run_mobile() -> void:
	OS.set_environment("CK_FORCE_MOBILE", "1")
	_ok(DeviceProfile.is_mobile(), "CK_FORCE_MOBILE flips DeviceProfile")
	_boot()
	var page: Control = SCN.instantiate()
	get_tree().root.add_child(page)
	await _settle(14)
	if page.has_method("apply_mobile_layout"):
		page.call("apply_mobile_layout")
		await _settle(6)
	_assert_page(page, "mob")
	page.queue_free()
	await _settle(2)
	OS.set_environment("CK_FORCE_MOBILE", "")
