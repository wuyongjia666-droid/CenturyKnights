extends Node
## Fat heraldry E2E: castle quest cards and the city commission board
## wear CKHeraldryField plates (board_offer / board_row / board_plate).
## Home issuer is 团徽. A foreign issuer is 邦徽, never the company core.
## Desk + mobile. Does not open train, deploy, or the infirmary.

const QUESTS := "res://scenes/hub/quests.tscn"
const CITY := "res://scenes/hub/city.tscn"
var _fails: Array = []


func _ready() -> void:
	await get_tree().process_frame
	await _run_quests_desktop()
	await _run_quests_mobile()
	await _run_city_board()
	_run_api()
	if _fails.is_empty():
		print("BOARD FIELD CREST PASS")
		get_tree().quit(0)
	else:
		for f in _fails:
			print("FAIL board field crest: ", f)
		get_tree().quit(1)


func _ok(cond: bool, msg: String) -> void:
	print("ROW %s %s" % ["PASS" if cond else "FAIL", msg])
	if not cond:
		_fails.append(msg)


func _settle(n: int = 6) -> void:
	for _i in n:
		await get_tree().process_frame


func _boot() -> void:
	GameState.new_game("榜徽", "霜旗", GameState.crest_color)
	GameState.set_flag("chapter0_done", true)
	UnlockSchedule.install()
	World.events_enabled = false
	World.rivals_enabled = false
	World.pos = "ash_capital"
	World.rep_city["ash_capital"] = 80
	if GameState.has_meta("city_id"):
		GameState.remove_meta("city_id")
	if GameState.has_meta("city_tab"):
		GameState.remove_meta("city_tab")


func _collect(n: Node, node_name: String, out: Array) -> void:
	if n.name == node_name:
		out.append(n)
	for c in n.get_children():
		_collect(c, node_name, out)


func _assert_offers(page: Node, where: String) -> void:
	var arms: Array = []
	_collect(page, "BoardCrest", arms)
	_ok(arms.size() >= 1, "%s BoardCrest count=%d" % [where, arms.size()])
	var ban := CKHeraldry.core_key(CKHeraldryChrome.company_spec())
	var saw_offer := false
	for a in arms:
		if str(a.get_meta("field_route", "")) != "board_offer":
			continue
		saw_offer = true
		_ok(str(a.get_meta("arms_kind", "")) == "gen2_36", "%s hq offer is 团徽" % where)
		_ok(str(a.get_meta("arms_core", "")) == ban, "%s hq offer core" % where)
		_ok(str(a.get_meta("issuer_id", "")) == "hq", "%s issuer hq" % where)
	_ok(saw_offer, "%s board_offer route" % where)


func _run_quests_desktop() -> void:
	OS.set_environment("CK_FORCE_MOBILE", "0")
	_boot()
	var page: Control = (load(QUESTS) as PackedScene).instantiate()
	get_tree().root.add_child(page)
	await _settle(10)
	_assert_offers(page, "quests-desk")
	page.queue_free()
	await _settle(2)


func _run_quests_mobile() -> void:
	OS.set_environment("CK_FORCE_MOBILE", "1")
	_ok(DeviceProfile.is_mobile(), "CK_FORCE_MOBILE flips DeviceProfile")
	_boot()
	var page: Control = (load(QUESTS) as PackedScene).instantiate()
	get_tree().root.add_child(page)
	await _settle(8)
	if page.has_method("apply_mobile_layout"):
		page.call("apply_mobile_layout")
		await _settle(8)
	_assert_offers(page, "quests-mob")
	page.queue_free()
	await _settle(2)
	OS.set_environment("CK_FORCE_MOBILE", "")


func _run_city_board() -> void:
	OS.set_environment("CK_FORCE_MOBILE", "0")
	_boot()
	GameState.set_meta("city_id", "ash_capital")
	GameState.set_meta("city_tab", "board")
	var page: Control = (load(CITY) as PackedScene).instantiate()
	page.size = Vector2(1280, 720)
	get_tree().root.add_child(page)
	await _settle(12)
	var arms: Array = []
	_collect(page, "BoardCrest", arms)
	_ok(arms.size() >= 2, "city board plates=%d" % arms.size())
	var saw_row := false
	var saw_plate := false
	var ban := CKHeraldry.core_key(CKHeraldryChrome.company_spec())
	for a in arms:
		var route := str(a.get_meta("field_route", ""))
		if route == "board_row":
			saw_row = true
			_ok(str(a.get_meta("issuer_id", "")) != "", "city row issuer")
			_ok(str(a.get_meta("arms_core", "")) != "", "city row core")
		elif route == "board_plate":
			saw_plate = true
			_ok(str(a.get_meta("arms_kind", "")) in ["gen2_36", "lb_board_arms"], "city detail kind")
			if str(a.get_meta("issuer_id", "")) != "hq" and str(a.get_meta("issuer_id", "")) != "":
				_ok(str(a.get_meta("arms_core", "")) != ban, "city detail is not 团徽")
	_ok(saw_row, "city board_row route")
	_ok(saw_plate, "city board_plate route")
	var src := FileAccess.get_file_as_string("res://scripts/hub/city.gd")
	_ok(src.find("CKHeraldryField.pin_board_row_arms") >= 0, "city row calls Field")
	_ok(src.find("CKHeraldryField.place_board_crest") >= 0, "city detail calls Field")
	_ok(src.find("make_issuer_arms") < 0, "city row left make_issuer_arms")
	page.queue_free()
	await _settle(2)


func _run_api() -> void:
	var src := FileAccess.get_file_as_string("res://scripts/hub/quests.gd")
	_ok(src.find("CKHeraldryField.attach_board_offer_arms") >= 0, "quests offer calls Field")
	var chrome := FileAccess.get_file_as_string("res://scripts/art/heraldry_chrome.gd")
	_ok(chrome.find("return CKHeraldryField.place_board_crest") >= 0, "chrome board crest is a Field shim")
	var host := HBoxContainer.new()
	get_tree().root.add_child(host)
	var foreign := CKHeraldryField.attach_board_offer_arms(host, "ash_capital", Vector2(36, 44))
	_ok(foreign != null, "api foreign offer")
	if foreign != null:
		_ok(str(foreign.get_meta("field_route", "")) == "board_offer", "api offer route")
		_ok(str(foreign.get_meta("arms_kind", "")) == "lb_board_arms", "api foreign is 邦徽")
		var ban := CKHeraldry.core_key(CKHeraldryChrome.company_spec())
		_ok(str(foreign.get_meta("arms_core", "")) != ban, "api foreign core != 团徽")
	var home := CKHeraldryField.attach_board_offer_arms(host, "hq", Vector2(36, 44))
	_ok(home != null and str(home.get_meta("arms_kind", "")) == "gen2_36", "api hq offer replaces with 团徽")
	_ok(host.find_child("BoardCrest", true, false) == home, "api one BoardCrest")
	var detail_host := Control.new()
	get_tree().root.add_child(detail_host)
	var plate := CKHeraldryField.place_board_crest(detail_host, "ash_capital", Vector2(12, 8), Vector2(44, 52))
	_ok(plate != null and str(plate.get_meta("field_route", "")) == "board_plate", "api detail route")
	_ok(plate != null and plate.position == Vector2(12, 8), "api detail position")
	var row := Control.new()
	row.custom_minimum_size = Vector2(388, 48)
	get_tree().root.add_child(row)
	var pinned := CKHeraldryField.pin_board_row_arms(row, "ash_capital", Vector2(352, 6), Vector2(28, 34))
	_ok(pinned != null and str(pinned.get_meta("field_route", "")) == "board_row", "api row route")
	_ok(pinned != null and pinned.position == Vector2(352, 6), "api row position")
	host.queue_free()
	detail_host.queue_free()
	row.queue_free()
