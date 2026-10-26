extends Node
## Shop fat: building_upgrade_preview → short/max reject → market upgrade →
## buy-price improve → month_echo.works → UI WorksUpgrade_market. Avoids #473.

const BID := "market"
const MARKER := "WORKS UPGRADE LOOP PASS"

func _ready() -> void:
	var err := await _run()
	if err != "":
		print("FAIL works upgrade: ", err)
		get_tree().quit(1)
	else:
		print(MARKER)
		get_tree().quit(0)


func _run() -> String:
	await get_tree().process_frame
	GameState.new_game("烬行", "灰旗", GameState.crest_color)
	GameState.chapter0_flags["chapter0_done"] = true
	GameState.chapter0_flags["ch0_playing"] = false
	World.events_enabled = false
	World.rivals_enabled = false
	GameState.house_mods.erase("month_echo")
	GameState.buildings[BID] = 1
	GameState.mark_dirty()

	var err := _api_gates_and_upgrade()
	if err != "":
		return err
	err = _api_price_bump()
	if err != "":
		return err
	err = await _ui_desktop()
	if err != "":
		return err
	return ""


func _api_gates_and_upgrade() -> String:
	GameState.buildings[BID] = 1
	GameState.silver = 5
	GameState.iron = 0
	GameState.food = 1
	var prev0: Dictionary = GameState.building_upgrade_preview(BID)
	if not bool(prev0.get("short", false)) or bool(prev0.get("maxed", false)):
		return "expected short: %s" % str(prev0)
	var bad: Dictionary = GameState.upgrade_building(BID)
	if bool(bad.get("ok", false)):
		return "short should reject"
	if int(GameState.building_level(BID)) != 1:
		return "level leaked on short"

	var cost: Dictionary = CKEconomyState.building_cost(GameState, BID, 2)
	GameState.silver = int(cost.silver) + 10
	GameState.iron = int(cost.iron) + 2
	GameState.food = int(cost.food) + 5
	var prev: Dictionary = GameState.building_upgrade_preview(BID)
	if bool(prev.get("short", false)) or bool(prev.get("maxed", false)):
		return "preview should clear: %s" % str(prev)
	var before_s := int(GameState.silver)
	GameState.house_mods.erase("month_echo")
	var ok: Dictionary = GameState.upgrade_building(BID)
	if not bool(ok.get("ok", false)):
		return "upgrade failed: %s" % str(ok)
	if int(GameState.building_level(BID)) != 2:
		return "level not 2"
	if int(GameState.silver) >= before_s:
		return "silver not spent"
	var snap: Dictionary = CKEconomyState.month_echo_snapshot()
	if str(snap.get("works", "")) == "":
		return "month_echo works empty: %s" % str(snap)

	GameState.buildings[BID] = 5
	GameState.silver = 9999
	GameState.iron = 99
	GameState.food = 999
	var pmax: Dictionary = GameState.building_upgrade_preview(BID)
	if not bool(pmax.get("maxed", false)):
		return "expected maxed: %s" % str(pmax)
	var mx: Dictionary = GameState.upgrade_building(BID)
	if bool(mx.get("ok", false)):
		return "maxed should reject"
	print("api works upgrade ok echo=%s" % str(snap.get("works", "")))
	return ""


func _api_price_bump() -> String:
	GameState.buildings[BID] = 1
	GameState.house_mods.erase("trade_route")
	GameState.house_mods.erase("market_edge")
	var p0: Dictionary = GameState.market_buy_prices()
	var cost: Dictionary = CKEconomyState.building_cost(GameState, BID, 2)
	GameState.silver = int(cost.silver) + 20
	GameState.iron = int(cost.iron) + 5
	GameState.food = int(cost.food) + 10
	var ok: Dictionary = GameState.upgrade_building(BID)
	if not bool(ok.get("ok", false)):
		return "price bump upgrade fail: %s" % str(ok)
	var p1: Dictionary = GameState.market_buy_prices()
	# higher market lv → lower buy price (cut = lv-1)
	if int(p1.get("iron", 99)) >= int(p0.get("iron", 0)):
		return "market upgrade should cut buy iron %s → %s" % [str(p0), str(p1)]
	print("api price bump ok p0=%s p1=%s" % [str(p0), str(p1)])
	return ""


func _ui_desktop() -> String:
	GameState.buildings[BID] = 1
	var cost: Dictionary = CKEconomyState.building_cost(GameState, BID, 2)
	GameState.silver = int(cost.silver) + 50
	GameState.iron = int(cost.iron) + 10
	GameState.food = int(cost.food) + 20
	GameState.house_mods.erase("month_echo")

	var page: Control = load("res://scenes/hub/works.tscn").instantiate()
	get_tree().root.add_child(page)
	page.set_anchors_preset(Control.PRESET_TOP_LEFT)
	page.position = Vector2.ZERO
	page.size = Vector2(1280, 720)
	for _i in 10:
		await get_tree().process_frame

	var btn := page.find_child("WorksUpgrade_%s" % BID, true, false) as Button
	if btn == null:
		page.queue_free()
		return "WorksUpgrade_%s missing" % BID
	if btn.disabled:
		page.queue_free()
		return "WorksUpgrade disabled unexpectedly"

	var before_lv := int(GameState.building_level(BID))
	btn.pressed.emit()
	for _i in 10:
		await get_tree().process_frame
	if int(GameState.building_level(BID)) != before_lv + 1:
		page.queue_free()
		return "UI upgrade level stuck %d" % int(GameState.building_level(BID))
	var snap: Dictionary = CKEconomyState.month_echo_snapshot()
	if str(snap.get("works", "")) == "":
		page.queue_free()
		return "UI missing month_echo.works"
	# re-render should show EchoLine_works
	var echo := page.find_child("EchoLine_works", true, false) as Label
	if echo == null:
		page.queue_free()
		return "EchoLine_works missing on works"
	print("ui desktop works+echo ok text=%s" % echo.text)
	page.queue_free()
	await get_tree().process_frame
	return ""
