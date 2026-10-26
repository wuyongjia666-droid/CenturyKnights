extends Node
## Dynasty fat: holding_steward_preview → reject → assign → yield bump → month_echo.steward
## → clear → UI HoldingStewardAssign_/StewardPick_/HoldingStewardClear_ (desktop).
## Avoids #473 surface (no calendar/lineage/dynasty.csv/genome edits).

const HID := "reed_ford"
const MARKER := "HOLDINGS STEWARD ASSIGN LOOP PASS"

func _ready() -> void:
	var err := await _run()
	if err != "":
		print("FAIL holdings steward assign: ", err)
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

	var err := _api_preview_reject_and_assign()
	if err != "":
		return err
	err = _api_yield_and_clear()
	if err != "":
		return err
	err = await _ui_desktop()
	if err != "":
		return err
	return ""


func _ensure_holding() -> void:
	GameState.holdings = {}
	var msg := GameState.unlock_holding(HID)
	if not GameState.holdings.has(HID):
		GameState.holdings[HID] = {"level": 1, "focus": "grain", "steward_id": "", "patrol_boost": 0, "patrol_cd": 0}
		GameState.mark_dirty()
		print("seeded holding (unlock said: %s)" % msg)


func _pick_roster_cid() -> String:
	for c in GameState.roster():
		if c == null or not c.alive:
			continue
		return str(c.id)
	return ""


func _api_preview_reject_and_assign() -> String:
	_ensure_holding()
	var prev0: Dictionary = GameState.holding_steward_preview(HID)
	if not bool(prev0.get("ok", false)) or bool(prev0.get("has_steward", true)):
		return "empty preview bad: %s" % str(prev0)
	var bad: Dictionary = GameState.assign_steward(HID, "no_such_cid")
	if bool(bad.get("ok", false)):
		return "ghost cid should reject"
	var cid := _pick_roster_cid()
	if cid == "":
		return "no roster member after new_game"
	GameState.house_mods.erase("month_echo")
	var ok: Dictionary = GameState.assign_steward(HID, cid)
	if not bool(ok.get("ok", false)):
		return "assign failed: %s" % str(ok)
	var st = GameState.steward_of(HID)
	if st == null or str(st.id) != cid:
		return "steward_of mismatch"
	var same: Dictionary = GameState.assign_steward(HID, cid)
	if bool(same.get("ok", false)):
		return "same steward should reject"
	var snap: Dictionary = CKEconomyState.month_echo_snapshot()
	if str(snap.get("steward", "")) == "":
		return "month_echo steward empty after assign: %s" % str(snap)
	var kinds := false
	for row in CKEconomyState.month_echo_lines():
		if str(row.get("kind", "")) == "steward":
			kinds = true
			break
	if not kinds:
		return "month_echo_lines missing steward kind"
	print("api assign ok cid=%s echo=%s" % [cid, str(snap.get("steward", ""))])
	return ""


func _api_yield_and_clear() -> String:
	_ensure_holding()
	var cid := _pick_roster_cid()
	if cid == "":
		return "no roster for yield"
	GameState.holdings[HID]["steward_id"] = ""
	var y0: Dictionary = GameState.holding_yield_preview(HID)
	GameState.assign_steward(HID, cid)
	var y1: Dictionary = GameState.holding_yield_preview(HID)
	if not bool(y1.get("steward", false)):
		return "yield preview steward flag false"
	# mul +1 from steward → food/silver should not shrink
	if int(y1.get("food", 0)) + int(y1.get("silver", 0)) <= int(y0.get("food", 0)) + int(y0.get("silver", 0)):
		return "steward should raise yield %s → %s" % [str(y0), str(y1)]
	GameState.house_mods.erase("month_echo")
	var clr: Dictionary = GameState.clear_steward(HID)
	if not bool(clr.get("ok", false)):
		return "clear failed: %s" % str(clr)
	if GameState.steward_of(HID) != null:
		return "steward still set after clear"
	var snap: Dictionary = CKEconomyState.month_echo_snapshot()
	if str(snap.get("steward", "")) == "":
		return "month_echo steward empty after clear"
	var none: Dictionary = GameState.clear_steward(HID)
	if bool(none.get("ok", false)):
		return "second clear should reject"
	print("api yield+clear ok y0=%s y1=%s" % [str(y0), str(y1)])
	return ""


func _ui_desktop() -> String:
	_ensure_holding()
	GameState.holdings[HID]["steward_id"] = ""
	GameState.house_mods.erase("month_echo")
	var cid := _pick_roster_cid()
	if cid == "":
		return "no roster for ui"

	var page: Control = load("res://scenes/hub/estates.tscn").instantiate()
	get_tree().root.add_child(page)
	page.set_anchors_preset(Control.PRESET_TOP_LEFT)
	page.position = Vector2.ZERO
	page.size = Vector2(1280, 720)
	for _i in 10:
		await get_tree().process_frame

	var assign_btn := page.find_child("HoldingStewardAssign_%s" % HID, true, false) as Button
	if assign_btn == null:
		page.queue_free()
		return "HoldingStewardAssign_%s missing" % HID
	assign_btn.pressed.emit()
	for _i in 8:
		await get_tree().process_frame
	var pick := page.find_child("StewardPick_%s" % cid, true, false) as Button
	if pick == null:
		page.queue_free()
		return "StewardPick_%s missing" % cid
	pick.pressed.emit()
	for _i in 8:
		await get_tree().process_frame
	if GameState.steward_of(HID) == null:
		page.queue_free()
		return "UI assign did not set steward"
	var snap: Dictionary = CKEconomyState.month_echo_snapshot()
	if str(snap.get("steward", "")) == "":
		page.queue_free()
		return "UI assign missing month_echo"

	var clear_btn := page.find_child("HoldingStewardClear_%s" % HID, true, false) as Button
	if clear_btn == null:
		page.queue_free()
		return "HoldingStewardClear_%s missing after assign" % HID
	clear_btn.pressed.emit()
	for _i in 8:
		await get_tree().process_frame
	if GameState.steward_of(HID) != null:
		page.queue_free()
		return "UI clear did not remove steward"
	var echo := page.find_child("EchoLine_steward", true, false) as Label
	if echo == null:
		page.queue_free()
		return "EchoLine_steward missing on estates"
	print("ui desktop steward assign+clear+echo ok text=%s" % echo.text)
	page.queue_free()
	await get_tree().process_frame
	return ""
