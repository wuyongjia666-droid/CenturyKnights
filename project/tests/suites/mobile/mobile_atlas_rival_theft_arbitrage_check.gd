extends Node
## Mobile E2E: RivalTheftModal + ArbitrageRun→arrive→ArbitrageSellModal.

const PHONE := Vector2i(2400, 1080)
const ROOT := Vector2(1600, 720)
const ATLAS_SCN := preload("res://scenes/hub/atlas_view.tscn")

func _ready() -> void:
	var err := await _run()
	if err != "":
		print("FAIL mobile atlas rival-theft/arbitrage: ", err)
		get_tree().quit(1)
	else:
		print("MOBILE ATLAS RIVAL THEFT ARBITRAGE PASS")
		get_tree().quit(0)

func _run() -> String:
	if not DeviceProfile.is_mobile():
		return "DeviceProfile.is_mobile() false — need CK_FORCE_MOBILE=1"
	await _set_phone_window()
	GameState.new_game("手机截夺跑单", "灰旗", GameState.crest_color)
	GameState.set_flag("chapter0_done", true)
	UnlockSchedule.install()
	World.events_enabled = false
	World.rivals_enabled = true
	for nid in World.nations.keys():
		World.rep_nation[str(nid)] = 50
	GameState.food = 40
	GameState.silver = 12000
	GameState.morale = 80
	World.hub_tour.clear()
	World.pos = "ash_capital"
	World.travel = {}
	World.pending_event = {}
	World.encounter = {}
	World.active.clear()
	World.cargo.clear()
	World.cargo_basis.clear()
	World.rival_thefts.clear()
	World.arbitrage = {}
	var a := await _check_theft_modal()
	if a != "":
		return "theft: %s" % a
	var b := await _check_arbitrage()
	if b != "":
		return "arb: %s" % b
	return ""

func _set_phone_window() -> void:
	var win := get_tree().root
	win.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	win.size = PHONE
	await get_tree().process_frame
	await get_tree().process_frame

func _mount_atlas() -> Control:
	var page: Control = ATLAS_SCN.instantiate()
	get_tree().root.add_child(page)
	page.set_anchors_preset(Control.PRESET_TOP_LEFT)
	page.position = Vector2.ZERO
	page.size = ROOT
	for _i in 6:
		await get_tree().process_frame
	if page.has_method("apply_mobile_layout"):
		page.apply_mobile_layout()
	for _j in 4:
		await get_tree().process_frame
	return page

func _check_theft_modal() -> String:
	World.pos = "ash_capital"
	World.arrive("ash_capital")
	World.rival_thefts = [{
		"by": "iron_ledger",
		"city": "fog_vale",
		"quest": "q_m",
		"title": "手机截夺",
	}]
	var page := await _mount_atlas()
	if not bool(page.get("_mob")):
		page.queue_free()
		return "_mob false"
	var modal: Node = page.find_child("RivalTheftModal", true, false)
	if modal == null:
		var shown: bool = bool(page.call("_check_rival_thefts"))
		if not shown:
			page.queue_free()
			return "modal not shown"
		modal = page.find_child("RivalTheftModal", true, false)
	if modal == null:
		page.queue_free()
		return "RivalTheftModal missing"
	if modal.get_node_or_null("RivalTheftOk") == null:
		page.queue_free()
		return "RivalTheftOk missing"
	var okb: BaseButton = modal.get_node("RivalTheftOk")
	okb.pressed.emit()
	for _n in 4:
		await get_tree().process_frame
	page.queue_free()
	for _z in 3:
		await get_tree().process_frame
	return ""

func _check_arbitrage() -> String:
	World.pos = "ash_capital"
	World.arrive("ash_capital")
	World.arbitrage = {}
	World.cargo.clear()
	World.cargo_basis.clear()
	World.rival_thefts.clear()
	for cid in ["fog_vale", "reed_ford", "stone_slope", "ash_hq"]:
		World.intel[cid] = World.days_total
		World.visited[cid] = true
	var best: Dictionary = World.best_produce_trade("ash_capital")
	if best.is_empty() or not bool(best.get("known", false)):
		return "no known produce trade"
	var page := await _mount_atlas()
	page.call("_select_node", "ash_capital")
	page.call("_set_sheet_tab", "place")
	for _i in 6:
		await get_tree().process_frame
	var run_btn: Node = page.find_child("ArbitrageRun", true, false)
	if run_btn == null:
		page.queue_free()
		return "ArbitrageRun missing"
	(run_btn as BaseButton).pressed.emit()
	for _j in 6:
		await get_tree().process_frame
	if World.arbitrage.is_empty():
		page.queue_free()
		return "arbitrage not armed"
	var dest := str(World.arbitrage.get("sell_city", ""))
	World.cancel_travel()
	World.travel = {}
	World.pos = dest
	World.arrive(dest)
	page.call("_after_arrival")
	for _k in 8:
		await get_tree().process_frame
	var modal: Node = page.find_child("ArbitrageSellModal", true, false)
	if modal == null:
		page.queue_free()
		return "ArbitrageSellModal missing"
	var sell: Node = modal.get_node_or_null("ArbitrageSell")
	if sell == null:
		page.queue_free()
		return "ArbitrageSell missing"
	(sell as BaseButton).pressed.emit()
	for _m in 6:
		await get_tree().process_frame
	if not World.arbitrage.is_empty():
		page.queue_free()
		return "arbitrage still armed"
	page.queue_free()
	for _z in 3:
		await get_tree().process_frame
	return ""
