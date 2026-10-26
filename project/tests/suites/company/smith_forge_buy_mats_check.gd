extends Node
## Fat E2E: smith forge with market mat top-up —
## preview cost, unstocked/short-silver reject, buy_mats forge, city ForgeBuyMats UI.

const CITY_SCN := preload("res://scenes/hub/city.tscn")
const CAP := "ash_capital"
const REGIONAL := "ashbanner_sword_1"

var _fails: Array = []
var _mobile := false


func _ready() -> void:
	await get_tree().process_frame
	_mobile = DeviceProfile.is_mobile()
	if _mobile:
		var win := get_tree().root
		win.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
		win.size = Vector2i(2400, 1080)
		await get_tree().process_frame
		await get_tree().process_frame
	_setup()
	_api_preview_and_gates()
	_setup()
	_api_buy_mats_forge_loop()
	_setup()
	await _ui_forge_buy_mats()
	if _fails.is_empty():
		print("SMITH FORGE BUY MATS PASS")
		get_tree().quit(0)
	else:
		for f in _fails:
			print("FAIL smith forge buy-mats: ", f)
		get_tree().quit(1)


func _ok(cond: bool, msg: String) -> void:
	print("ROW %s %s" % ["PASS" if cond else "FAIL", msg])
	if not cond:
		_fails.append(msg)


func _setup() -> void:
	GameState.new_game("购料打造", "灰旗", GameState.crest_color)
	GameState.set_flag("chapter0_done", true)
	UnlockSchedule.install()
	World.events_enabled = false
	World.rivals_enabled = false
	for nid in World.nations.keys():
		World.rep_nation[str(nid)] = 50
	GameState.silver = 50000
	World.armory.clear()
	World.gear.clear()
	World.cargo.clear()
	World.pos = CAP
	World.arrive(CAP)
	World.rep_city[CAP] = 20
	World.done_sig.clear()
	GameState.settings.erase("smith_revealed")
	# drain cargo iron so forge needs market
	while World.have_good("iron") > 0:
		World._add_good("iron", -1)
	# ensure market has iron
	if not World.market.has(CAP):
		World._init_market(CAP)
	World.market[CAP]["iron"] = maxi(int(World.market[CAP].get("iron", 0)), 8)


func _api_preview_and_gates() -> void:
	_ok(World.have_good("iron") == 0, "cargo iron drained")
	var prev: Dictionary = World.forge_mats_preview(CAP, REGIONAL)
	_ok(bool(prev.get("ok", false)), "preview ok")
	_ok(not (prev.get("miss", {}) as Dictionary).is_empty(), "miss iron")
	_ok(int(prev.get("mat_silver", 0)) > 0, "mat_silver>0")
	_ok(int(prev.get("forge_silver", 0)) > 0, "forge_silver>0")
	_ok(bool(prev.get("can_buy", false)), "can_buy from market")
	var soft: Dictionary = World.forge_item(CAP, REGIONAL, false)
	_ok(not bool(soft.get("ok", false)), "forge without mats rejected")
	_ok(str(soft.get("msg", "")).find("铁") >= 0 or str(soft.get("msg", "")).find("材料") >= 0, "short-mats msg")
	# short silver
	var need := int(prev.get("total", 1))
	GameState.silver = maxi(0, need - 1)
	var broke: Dictionary = World.forge_item(CAP, REGIONAL, true)
	_ok(not bool(broke.get("ok", false)), "buy_mats rejected when short silver")
	GameState.silver = 50000
	# unstocked
	World.market[CAP]["iron"] = 0
	var prev2: Dictionary = World.forge_mats_preview(CAP, REGIONAL)
	_ok(not bool(prev2.get("can_buy", true)), "cannot buy when unstocked")
	var nostock: Dictionary = World.forge_item(CAP, REGIONAL, true)
	_ok(not bool(nostock.get("ok", false)), "buy_mats rejected when unstocked")
	World.market[CAP]["iron"] = 8


func _api_buy_mats_forge_loop() -> void:
	while World.have_good("iron") > 0:
		World._add_good("iron", -1)
	World.armory.erase(REGIONAL)
	World.market[CAP]["iron"] = 8
	GameState.silver = 50000
	var silver0 := GameState.silver
	var prev: Dictionary = World.forge_mats_preview(CAP, REGIONAL)
	var r: Dictionary = World.forge_item(CAP, REGIONAL, true)
	_ok(bool(r.get("ok", false)), "buy_mats forge: %s" % r.get("msg", ""))
	_ok(int(World.armory.get(REGIONAL, 0)) >= 1, "armory filled")
	_ok(int(r.get("mat_silver", 0)) == int(prev.get("mat_silver", -1)), "mat_silver reported")
	_ok(int(r.get("forge_silver", 0)) == int(prev.get("forge_silver", -1)), "forge_silver reported")
	_ok(GameState.silver == silver0 - int(prev.get("total", 0)), "silver = mats+labor")
	_ok(World.have_good("iron") == 0, "forge consumed bought iron")


func _ui_forge_buy_mats() -> void:
	while World.have_good("iron") > 0:
		World._add_good("iron", -1)
	World.armory.erase(REGIONAL)
	World.market[CAP]["iron"] = 8
	GameState.silver = 50000
	for e in World.smith_stock(CAP):
		if int(e.get("signature", 0)) >= 1:
			World.mark_smith_revealed(str(e.item.id))
	var city: Control = CITY_SCN.instantiate()
	add_child(city)
	for _i in 8:
		await get_tree().process_frame
	if not city.has_method("_set_tab"):
		_ok(false, "city missing _set_tab")
		city.queue_free()
		return
	city.call("_set_tab", "smith")
	for _j in 6:
		await get_tree().process_frame
	var skip := city.find_child("SmithRevealSkip", true, false) as Button
	if skip:
		skip.pressed.emit()
		await get_tree().process_frame
	var row := city.find_child("Item_" + REGIONAL, true, false) as Button
	_ok(row != null, "UI Item_%s" % REGIONAL)
	if row:
		row.pressed.emit()
		for _k in 4:
			await get_tree().process_frame
	var bm := city.find_child("ForgeBuyMats", true, false) as Button
	_ok(bm != null and not bm.disabled, "UI ForgeBuyMats ready")
	var arm0 := int(World.armory.get(REGIONAL, 0))
	if bm and not bm.disabled:
		bm.pressed.emit()
		for _m in 6:
			await get_tree().process_frame
	_ok(int(World.armory.get(REGIONAL, 0)) == arm0 + 1, "UI buy-mats forge fills armory")
	_ok(World.have_good("iron") == 0, "UI forge consumed mats")
	city.queue_free()
	await get_tree().process_frame
