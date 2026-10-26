extends Node
## Dynasty fat: holding_patrol_preview → short reject → patrol_one → month_echo patrol
## → focus cash shifts yield → UI HoldingPatrol_/HoldingFocus_ named buttons (desktop).
## Avoids #473 surface (no calendar/lineage/dynasty.csv/genome edits).

const HID := "reed_ford"
const MARKER := "HOLDINGS PATROL FOCUS LOOP PASS"

func _ready() -> void:
	var err := await _run()
	if err != "":
		print("FAIL holdings patrol focus: ", err)
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

	var err := _api_preview_short_and_ok()
	if err != "":
		return err
	err = _api_focus_yield()
	if err != "":
		return err
	err = await _ui_desktop()
	if err != "":
		return err
	return ""


func _ensure_holding() -> String:
	GameState.holdings = {}
	var msg := GameState.unlock_holding(HID)
	if not GameState.holdings.has(HID):
		# unlock may gate on quest — force-seed for E2E
		GameState.holdings[HID] = {"level": 1, "focus": "grain", "patrol_boost": 0, "patrol_cd": 0}
		GameState.mark_dirty()
		print("seeded holding (unlock said: %s)" % msg)
	return ""


func _api_preview_short_and_ok() -> String:
	_ensure_holding()
	GameState.silver = 5
	GameState.food = 1
	var prev: Dictionary = GameState.holding_patrol_preview(HID)
	if not bool(prev.get("short", false)):
		return "expected short at low purse: %s" % str(prev)
	var bad: Dictionary = GameState.patrol_holding(HID)
	if bool(bad.get("ok", false)):
		return "short should reject patrol"
	if int(GameState.holding_patrol_boost(HID)) != 0:
		return "boost leaked on short reject"

	GameState.silver = 200
	GameState.food = 80
	prev = GameState.holding_patrol_preview(HID)
	if bool(prev.get("short", false)) or bool(prev.get("blocked", false)):
		return "preview should be clear: %s" % str(prev)
	var cost_s := int(prev.get("cost_s", 0))
	var cost_f := int(prev.get("cost_f", 0))
	if cost_s < 18 or cost_f < 3:
		return "cost too low: %s" % str(prev)
	var before_s := int(GameState.silver)
	var before_f := int(GameState.food)
	GameState.house_mods.erase("month_echo")
	var ok: Dictionary = GameState.patrol_holding(HID)
	if not bool(ok.get("ok", false)):
		return "patrol failed: %s" % str(ok)
	if int(GameState.silver) != before_s - cost_s:
		return "silver delta"
	if int(GameState.food) != before_f - cost_f:
		return "food delta"
	if int(GameState.holding_patrol_boost(HID)) < 1:
		return "boost not set"
	if int(GameState.holding_patrol_cd(HID)) < 1:
		return "cd not set"
	var snap: Dictionary = CKEconomyState.month_echo_snapshot()
	var pe := str(snap.get("patrol", ""))
	if pe == "":
		return "month_echo patrol empty after patrol_holding: %s" % str(snap)
	print("api patrol ok cost=%d/%d echo=%s" % [cost_s, cost_f, pe])

	# cooldown reject
	var again: Dictionary = GameState.patrol_holding(HID)
	if bool(again.get("ok", false)):
		return "cd should block second patrol"

	# month tick drains cd/boost (via economy tick; avoid calendar.gd / family_state #473 surface)
	GameState.tick_patrol_month()
	GameState.tick_patrol_month()
	if int(GameState.holding_patrol_cd(HID)) != 0:
		return "cd should clear after 2 ticks: %d" % int(GameState.holding_patrol_cd(HID))
	print("api cd cleared after 2 ticks")
	return ""


func _api_focus_yield() -> String:
	_ensure_holding()
	GameState.holdings[HID]["focus"] = "grain"
	GameState.holdings[HID]["focus_cd"] = 0
	GameState.silver = 100
	var yg: Dictionary = GameState.holding_yield_preview(HID)
	var food_g := int(yg.get("food", 0))
	var sil_g := int(yg.get("silver", 0))
	var rr: Dictionary = GameState.set_holding_focus(HID, "cash")
	if not bool(rr.get("ok", false)):
		return "set focus cash failed: %s" % str(rr)
	if str(GameState.holding_focus(HID)) != "cash":
		return "focus not cash"
	var yc: Dictionary = GameState.holding_yield_preview(HID)
	if int(yc.get("silver", 0)) <= sil_g:
		return "cash focus should raise silver %d→%d" % [sil_g, int(yc.get("silver", 0))]
	if int(yc.get("food", 0)) >= food_g:
		return "cash focus should cut food %d→%d" % [food_g, int(yc.get("food", 0))]
	print("api focus cash yield ok grain=%s cash=%s" % [str(yg), str(yc)])
	return ""


func _ui_desktop() -> String:
	_ensure_holding()
	GameState.holdings[HID]["patrol_boost"] = 0
	GameState.holdings[HID]["patrol_cd"] = 0
	GameState.holdings[HID]["focus"] = "grain"
	GameState.holdings[HID]["focus_cd"] = 0
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

	var all_btn := page.find_child("HoldingPatrolAll", true, false) as Button
	if all_btn == null:
		page.queue_free()
		return "HoldingPatrolAll missing"
	var one := page.find_child("HoldingPatrol_%s" % HID, true, false) as Button
	if one == null:
		page.queue_free()
		return "HoldingPatrol_%s missing" % HID
	var focus_cash := page.find_child("HoldingFocus_%s_cash" % HID, true, false) as Button
	if focus_cash == null:
		page.queue_free()
		return "HoldingFocus_%s_cash missing" % HID

	var before_s := int(GameState.silver)
	one.pressed.emit()
	for _i in 6:
		await get_tree().process_frame
	if int(GameState.holding_patrol_boost(HID)) < 1:
		page.queue_free()
		return "UI patrol did not boost"
	if int(GameState.silver) >= before_s:
		page.queue_free()
		return "UI patrol did not spend silver"
	var snap: Dictionary = CKEconomyState.month_echo_snapshot()
	if str(snap.get("patrol", "")) == "":
		page.queue_free()
		return "UI patrol missing month_echo"

	# rebuild after change may free buttons — re-find focus
	focus_cash = page.find_child("HoldingFocus_%s_cash" % HID, true, false) as Button
	if focus_cash == null:
		page.queue_free()
		return "HoldingFocus cash missing after patrol refresh"
	focus_cash.pressed.emit()
	for _i in 6:
		await get_tree().process_frame
	if str(GameState.holding_focus(HID)) != "cash":
		page.queue_free()
		return "UI focus cash not applied: %s" % str(GameState.holding_focus(HID))

	# EchoLine_patrol should surface via month_echo_lines
	var echo := page.find_child("EchoLine_patrol", true, false) as Label
	if echo == null:
		page.queue_free()
		return "EchoLine_patrol missing on estates"
	print("ui desktop patrol+focus+echo ok text=%s" % echo.text)
	page.queue_free()
	await get_tree().process_frame
	return ""
