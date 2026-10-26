extends Node
## Dynasty fat: holding_upgrade_preview → short/max reject → upgrade → yield bump
## → month_echo.upgrade → UI HoldingUpgrade_ (desktop). Avoids #473 surface.

const HID := "reed_ford"
const MARKER := "HOLDINGS UPGRADE LOOP PASS"

func _ready() -> void:
	var err := await _run()
	if err != "":
		print("FAIL holdings upgrade: ", err)
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

	var err := _api_preview_reject_and_upgrade()
	if err != "":
		return err
	err = _api_yield_bump()
	if err != "":
		return err
	err = await _ui_desktop()
	if err != "":
		return err
	return ""


func _ensure_holding(lv: int = 1) -> void:
	GameState.holdings = {}
	var msg := GameState.unlock_holding(HID)
	if not GameState.holdings.has(HID):
		GameState.holdings[HID] = {"level": 1, "focus": "grain", "steward_id": "", "patrol_boost": 0, "patrol_cd": 0}
		GameState.mark_dirty()
		print("seeded holding (unlock said: %s)" % msg)
	GameState.holdings[HID]["level"] = lv
	GameState.holdings[HID]["focus"] = "grain"
	GameState.mark_dirty()


func _api_preview_reject_and_upgrade() -> String:
	_ensure_holding(1)
	GameState.silver = 5
	GameState.food = 1
	var prev0: Dictionary = GameState.holding_upgrade_preview(HID)
	if not bool(prev0.get("short", false)) or bool(prev0.get("maxed", false)):
		return "expected short at low purse: %s" % str(prev0)
	var bad: Dictionary = GameState.upgrade_holding(HID)
	if bool(bad.get("ok", false)):
		return "short should reject"
	if int(GameState.holding_level(HID)) != 1:
		return "level leaked on short"

	GameState.silver = 200
	GameState.food = 80
	var prev: Dictionary = GameState.holding_upgrade_preview(HID)
	if bool(prev.get("short", false)) or bool(prev.get("maxed", false)):
		return "preview should be clear: %s" % str(prev)
	if int(prev.get("cost_s", 0)) != 40 or int(prev.get("cost_f", 0)) != 8:
		return "lv1 cost expected 40/8: %s" % str(prev)
	var before_s := int(GameState.silver)
	var before_f := int(GameState.food)
	GameState.house_mods.erase("month_echo")
	var ok: Dictionary = GameState.upgrade_holding(HID)
	if not bool(ok.get("ok", false)):
		return "upgrade failed: %s" % str(ok)
	if int(GameState.holding_level(HID)) != 2:
		return "level not 2 after upgrade"
	if int(GameState.silver) != before_s - 40 or int(GameState.food) != before_f - 8:
		return "silver/food delta"
	var snap: Dictionary = CKEconomyState.month_echo_snapshot()
	if str(snap.get("upgrade", "")) == "":
		return "month_echo upgrade empty: %s" % str(snap)
	print("api upgrade ok lv2 echo=%s" % str(snap.get("upgrade", "")))

	# max reject at lv3
	GameState.holdings[HID]["level"] = 3
	GameState.silver = 500
	GameState.food = 200
	var pmax: Dictionary = GameState.holding_upgrade_preview(HID)
	if not bool(pmax.get("maxed", false)):
		return "expected maxed at lv3: %s" % str(pmax)
	var mx: Dictionary = GameState.upgrade_holding(HID)
	if bool(mx.get("ok", false)):
		return "maxed should reject"
	return ""


func _api_yield_bump() -> String:
	_ensure_holding(1)
	GameState.silver = 200
	GameState.food = 80
	var y0: Dictionary = GameState.holding_yield_preview(HID)
	var ok: Dictionary = GameState.upgrade_holding(HID)
	if not bool(ok.get("ok", false)):
		return "yield bump upgrade fail: %s" % str(ok)
	var y1: Dictionary = GameState.holding_yield_preview(HID)
	if int(y1.get("food", 0)) <= int(y0.get("food", 0)) and int(y1.get("silver", 0)) <= int(y0.get("silver", 0)):
		return "upgrade should raise yield %s → %s" % [str(y0), str(y1)]
	print("api yield bump ok y0=%s y1=%s" % [str(y0), str(y1)])
	return ""


func _ui_desktop() -> String:
	_ensure_holding(1)
	GameState.silver = 200
	GameState.food = 80
	GameState.house_mods.erase("month_echo")

	var page: Control = load("res://scenes/hub/estates.tscn").instantiate()
	get_tree().root.add_child(page)
	page.set_anchors_preset(Control.PRESET_TOP_LEFT)
	page.position = Vector2.ZERO
	page.size = Vector2(1280, 720)
	for _i in 10:
		await get_tree().process_frame

	var btn := page.find_child("HoldingUpgrade_%s" % HID, true, false) as Button
	if btn == null:
		page.queue_free()
		return "HoldingUpgrade_%s missing" % HID
	if btn.disabled:
		page.queue_free()
		return "HoldingUpgrade disabled unexpectedly"

	var before_lv := int(GameState.holding_level(HID))
	var before_s := int(GameState.silver)
	btn.pressed.emit()
	for _i in 8:
		await get_tree().process_frame
	if int(GameState.holding_level(HID)) != before_lv + 1:
		page.queue_free()
		return "UI upgrade level %d→%d" % [before_lv, int(GameState.holding_level(HID))]
	if int(GameState.silver) >= before_s:
		page.queue_free()
		return "UI upgrade did not spend silver"
	var snap: Dictionary = CKEconomyState.month_echo_snapshot()
	if str(snap.get("upgrade", "")) == "":
		page.queue_free()
		return "UI missing month_echo.upgrade"

	var echo := page.find_child("EchoLine_upgrade", true, false) as Label
	if echo == null:
		page.queue_free()
		return "EchoLine_upgrade missing on estates"
	print("ui desktop upgrade+echo ok text=%s" % echo.text)
	page.queue_free()
	await get_tree().process_frame
	return ""
