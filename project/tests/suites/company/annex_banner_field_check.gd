extends Node
## Fat heraldry E2E: castle annex cloth plate is CKHeraldryField.place_banner_plate.
## Treasury keeps the company serve row. The annex scene file is not retargeted
## (infirmary / deploy / train stay on their own branches); Chrome is the shim.
## Desk + mobile.

const SCN := preload("res://scenes/hub/annex.tscn")
var _fails: Array = []


func _ready() -> void:
	await get_tree().process_frame
	await _run_desktop()
	await _run_mobile()
	_run_sources()
	if _fails.is_empty():
		print("ANNEX BANNER FIELD PASS")
		get_tree().quit(0)
	else:
		for f in _fails:
			print("FAIL annex banner field: ", f)
		get_tree().quit(1)


func _ok(cond: bool, msg: String) -> void:
	print("ROW %s %s" % ["PASS" if cond else "FAIL", msg])
	if not cond:
		_fails.append(msg)


func _settle(n: int = 6) -> void:
	for _i in n:
		await get_tree().process_frame


func _boot() -> void:
	GameState.new_game("附楼旗", "灰旗", GameState.crest_color)
	GameState.set_flag("chapter0_done", true)
	UnlockSchedule.install()
	World.events_enabled = false
	World.rivals_enabled = false


func _open(annex_id: String) -> Control:
	var page: Control = SCN.instantiate()
	page.set_meta("annex", annex_id)
	page.set_anchors_preset(Control.PRESET_TOP_LEFT)
	page.position = Vector2.ZERO
	page.size = Vector2(1280, 720)
	get_tree().root.add_child(page)
	return page


func _collect(n: Node, node_name: String, out: Array) -> void:
	if n.name == node_name:
		out.append(n)
	for c in n.get_children():
		_collect(c, node_name, out)


func _assert_page(page: Node, where: String) -> void:
	var strip := page.find_child("CastleBannerStrip", true, false) as Control
	_ok(strip != null, "%s CastleBannerStrip" % where)
	if strip != null:
		_ok(str(strip.get_meta("field_route", "")) == "banner_plate", "%s banner field_route" % where)
		_ok(strip.mouse_filter == Control.MOUSE_FILTER_IGNORE, "%s banner ignores taps" % where)
		var co := strip.find_child("CastleArms", true, false)
		var bn := strip.find_child("CastleBanner", true, false)
		_ok(co != null and str(co.get_meta("arms_kind", "")) == "gen2_36", "%s banner 团徽" % where)
		_ok(bn != null and str(bn.get_meta("arms_kind", "")) == "gen2_36", "%s banner cloth" % where)
		if co != null and bn != null:
			_ok(str(co.get_meta("arms_core", "")) == str(bn.get_meta("arms_core", "")), "%s shield matches cloth" % where)
	var rows: Array = []
	_collect(page, "AnnexRowArms", rows)
	_ok(not rows.is_empty(), "%s treasury AnnexRowArms" % where)
	for a in rows:
		_ok(str(a.get_meta("arms_kind", "")) == "gen2_36", "%s treasury row is 团徽" % where)


func _run_desktop() -> void:
	OS.set_environment("CK_FORCE_MOBILE", "0")
	_boot()
	var page := _open("treasury")
	await _settle(10)
	_assert_page(page, "desk")
	page.queue_free()
	await _settle(2)


func _run_mobile() -> void:
	OS.set_environment("CK_FORCE_MOBILE", "1")
	_ok(DeviceProfile.is_mobile(), "CK_FORCE_MOBILE flips DeviceProfile")
	_boot()
	var page := _open("treasury")
	await _settle(8)
	if page.has_method("apply_mobile_layout"):
		page.call("apply_mobile_layout")
		await _settle(8)
	_assert_page(page, "mob")
	page.queue_free()
	await _settle(2)
	OS.set_environment("CK_FORCE_MOBILE", "")


func _run_sources() -> void:
	var chrome := FileAccess.get_file_as_string("res://scripts/art/heraldry_chrome.gd")
	_ok(chrome.find("return CKHeraldryField.place_banner_plate") >= 0, "chrome banner shim")
	var annex := FileAccess.get_file_as_string("res://scripts/hub/annex.gd")
	_ok(annex.find("place_castle_banner_strip") >= 0, "annex still uses the banner helper")
	_ok(annex.find("CKHeraldryField.attach_annex_row_arms") >= 0, "annex rows stay on Field")
	var train := FileAccess.get_file_as_string("res://scripts/hub/train.gd")
	_ok(train.find("place_banner_plate") < 0, "train scene not retargeted")
	var deploy := FileAccess.get_file_as_string("res://scripts/hub/deploy.gd")
	_ok(deploy.find("place_banner_plate") < 0, "deploy scene not retargeted")
	var host := Control.new()
	get_tree().root.add_child(host)
	var plate := CKHeraldryField.place_banner_plate(host, Vector2(20, 12), Vector2(36, 44), Vector2(24, 34))
	_ok(plate != null and plate.name == "CastleBannerStrip", "api banner name")
	_ok(plate != null and str(plate.get_meta("field_route", "")) == "banner_plate", "api banner route")
	_ok(plate != null and plate.position == Vector2(20, 12), "api banner position")
	var again := CKHeraldryField.place_banner_plate(host, Vector2(4, 4), Vector2(36, 44), Vector2(24, 34))
	_ok(again != null and again != plate, "api replace retires the previous plate")
	_ok(host.get_node_or_null("CastleBannerStrip") == again, "api one live strip")
	host.queue_free()
