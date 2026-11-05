extends Node
## Mobile twin fat #5: CityPlayableSurface / CommissionMarchStrip / reward card under CK_FORCE_MOBILE.

const CITY_SCN := preload("res://scenes/hub/city.tscn")
const ATLAS_SCN := preload("res://scenes/hub/atlas_view.tscn")
const HOME := "ash_capital"
const MARKER := "MOBILE ATLAS CITY COMMISSION SUPPLY FAT PASS"
const PHONE := Vector2i(2400, 1080)


func _ready() -> void:
	OS.set_environment("CK_FORCE_MOBILE", "1")
	var err := await _run()
	OS.set_environment("CK_FORCE_MOBILE", "")
	if err != "":
		print("FAIL mobile atlas city commission supply fat: ", err)
		get_tree().quit(1)
		return
	print(MARKER)
	get_tree().quit(0)


func _run() -> String:
	if not DeviceProfile.is_mobile():
		return "DeviceProfile.is_mobile() false — need CK_FORCE_MOBILE=1"
	await _set_phone_window()
	_boot()
	var err := await _ui_city_playable_and_reward()
	if err != "":
		return err
	err = await _ui_atlas_march_strip()
	if err != "":
		return err
	return ""


func _boot() -> void:
	GameState.new_game("手游城委托", "灰旗", GameState.crest_color)
	GameState.set_flag("chapter0_done", true)
	UnlockSchedule.install()
	World.events_enabled = false
	World.rivals_enabled = false
	World.active.clear()
	World.cargo.clear()
	World.travel = {}
	World.pending_event = {}
	World.encounter = {}
	World.last_commission_reward = {}
	World.pos = HOME
	World.visited[HOME] = true
	World.rep_city[HOME] = 40
	for nid in World.nations.keys():
		World.rep_nation[str(nid)] = 40
	GameState.silver = 5000
	GameState.food = 200


func _make_gather() -> Dictionary:
	var r := RandomNumberGenerator.new()
	r.seed = hash("mobile-atlas-city-commission-supply-fat")
	var q: Dictionary = {}
	for _i in 40:
		q = World._make_quest(HOME, "gather", 1, r)
		if q.is_empty():
			continue
		var supply := str(q.get("supply_city", ""))
		if supply != "" and supply != HOME and World.nodes.has(supply):
			return q
	return q


func _post(q: Dictionary) -> void:
	World._ensure_board(HOME)
	World.boards[HOME].offers.append(q)


func _go(dest: String) -> void:
	for _i in 24:
		if not World.encounter.is_empty():
			World.on_battle_end(true)
			continue
		if World.pos == dest and not World.is_traveling():
			break
		World.travel_to(dest)
	if not World.encounter.is_empty():
		World.on_battle_end(true)


func _ui_city_playable_and_reward() -> String:
	var q := _make_gather()
	if q.is_empty():
		return "mobile make gather fail"
	_post(q)
	var qid := str(q.id)
	var good := str(q.good)
	var qty := int(q.qty)
	var supply := World.gather_supply_city(q)
	GameState.set_meta("city_id", HOME)
	GameState.set_meta("city_tab", "overview")
	var page = CITY_SCN.instantiate()
	page.position = Vector2.ZERO
	page.size = Vector2(1280, 720)
	get_tree().root.add_child(page)
	await _settle(12)
	var surf := page.find_child("CityPlayableSurface", true, false)
	if surf == null:
		page.queue_free()
		await _settle(2)
		return "mobile CityPlayableSurface missing"
	var acc: Dictionary = World.accept_quest(HOME, qid)
	if not bool(acc.get("ok", false)):
		page.queue_free()
		await _settle(2)
		return "mobile accept fail"
	_go(supply)
	World.visited[supply] = true
	if not World.market.has(supply):
		World._init_market(supply)
	World.market[supply][good] = maxi(qty, int(World.market[supply].get(good, 0)))
	var buy: Dictionary = World.gather_buy_here()
	if not bool(buy.get("ok", false)):
		page.queue_free()
		await _settle(2)
		return "mobile buy fail: %s" % buy.get("msg", "")
	_go(HOME)
	if page.has_method("_do"):
		page.call("_do", World.turn_in(qid))
	else:
		World.turn_in(qid)
	await _settle(10)
	var card := page.find_child("CommissionRewardCard", true, false)
	var ok_btn := page.find_child("CommissionRewardOk", true, false) as Button
	var err := ""
	if card == null:
		err = "mobile CommissionRewardCard missing"
	elif ok_btn == null:
		err = "mobile CommissionRewardOk missing"
	elif ok_btn.size.x < 40 or ok_btn.size.y < 20:
		err = "mobile CommissionRewardOk clipped"
	else:
		ok_btn.pressed.emit()
		await _settle(4)
		if not World.last_commission_reward.is_empty():
			err = "mobile dismiss left reward"
	page.queue_free()
	await _settle(2)
	return err


func _ui_atlas_march_strip() -> String:
	_boot()
	var q := _make_gather()
	if q.is_empty():
		return "mobile atlas make fail"
	_post(q)
	var supply := World.gather_supply_city(q)
	var acc: Dictionary = World.accept_quest(HOME, str(q.id))
	if not bool(acc.get("ok", false)):
		return "mobile atlas accept fail"
	var atlas: Control = ATLAS_SCN.instantiate()
	get_tree().root.add_child(atlas)
	await _settle(12)
	if atlas.has_method("_select_node"):
		atlas.call("_select_node", supply)
	await _settle(8)
	var note := atlas.find_child("CommissionMarchNote", true, false)
	var strip := atlas.find_child("CommissionMarchStrip", true, false)
	var err := ""
	if note == null and strip == null:
		err = "mobile atlas missing march note/strip"
	atlas.queue_free()
	await _settle(2)
	return err


func _set_phone_window() -> void:
	var win := get_tree().root
	win.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	win.size = PHONE
	DisplayServer.window_set_size(PHONE)
	await _settle(4)


func _settle(frames: int) -> void:
	for _i in frames:
		await get_tree().process_frame
