extends Node
## Shop fat: caravan_start/escort_preview → short/busy/kind reject → start/escort →
## settle month_echo.caravan → market EchoLine_caravan. Avoids #473.

const KIND := "grain"
const COST := 35
const ESCORT := 12
const PAYOUT := 59  # int(35 * 1.7)
const MARKER := "CARAVAN ECHO LOOP PASS"
const MARKET_SCN := preload("res://scenes/hub/market.tscn")

func _ready() -> void:
	var err := await _run()
	if err != "":
		print("FAIL caravan echo: ", err)
		get_tree().quit(1)
	else:
		print(MARKER)
		get_tree().quit(0)


func _run() -> String:
	await get_tree().process_frame
	GameState.new_game("商队回读", "灰旗", GameState.crest_color)
	GameState.chapter0_flags["chapter0_done"] = true
	GameState.chapter0_flags["ch0_playing"] = false
	UnlockSchedule.install()
	World.events_enabled = false
	World.rivals_enabled = false
	GameState.caravan = {}
	GameState.house_mods.erase("caravan_active")
	GameState.house_mods.erase("month_echo")

	var err := _api_preview_gates()
	if err != "":
		return err
	err = _api_start_escort_settle_echo()
	if err != "":
		return err
	err = await _ui_desktop()
	if err != "":
		return err
	return ""


func _api_preview_gates() -> String:
	var err := _gate_start_rejects()
	if err != "":
		return err
	err = _gate_busy_and_escort()
	if err != "":
		return err
	GameState.caravan = {}
	GameState.house_mods.erase("caravan_active")
	GameState.house_mods.erase("month_echo")
	print("api preview gates ok")
	return ""


func _gate_start_rejects() -> String:
	GameState.silver = COST - 1
	GameState.caravan = {}
	GameState.house_mods.erase("caravan_active")
	var p_short: Dictionary = GameState.caravan_start_preview(KIND)
	if not bool(p_short.get("short", false)) or bool(p_short.get("startable", true)):
		return "expected start short: %s" % str(p_short)
	var bad_short: Dictionary = GameState.start_caravan(KIND)
	if bool(bad_short.get("ok", false)):
		return "short should reject start"
	var p_kind: Dictionary = GameState.caravan_start_preview("silk")
	if str(p_kind.get("reason", "")) != "kind":
		return "expected kind reason: %s" % str(p_kind)
	var bad_kind: Dictionary = GameState.start_caravan("silk")
	if bool(bad_kind.get("ok", false)):
		return "bad kind should reject"
	return ""


func _gate_busy_and_escort() -> String:
	GameState.silver = 80000
	var ok: Dictionary = GameState.start_caravan(KIND)
	if not bool(ok.get("ok", false)):
		return "start for busy gate failed: %s" % str(ok)
	var p_busy: Dictionary = GameState.caravan_start_preview("iron")
	if str(p_busy.get("reason", "")) != "busy" or bool(p_busy.get("startable", true)):
		return "expected busy: %s" % str(p_busy)
	var bad_busy: Dictionary = GameState.start_caravan("iron")
	if bool(bad_busy.get("ok", false)):
		return "busy should reject"
	GameState.caravan = {}
	GameState.house_mods.erase("caravan_active")
	var p_esc_none: Dictionary = GameState.caravan_escort_preview()
	if str(p_esc_none.get("reason", "")) != "none" or bool(p_esc_none.get("escortable", true)):
		return "expected escort none: %s" % str(p_esc_none)
	GameState.start_caravan(KIND)
	GameState.silver = ESCORT - 1
	var p_esc_short: Dictionary = GameState.caravan_escort_preview()
	if not bool(p_esc_short.get("short", false)):
		return "expected escort short: %s" % str(p_esc_short)
	var bad_esc: Dictionary = GameState.escort_caravan()
	if bool(bad_esc.get("ok", false)):
		return "escort short should reject"
	GameState.silver = 80000
	var esc: Dictionary = GameState.escort_caravan()
	if not bool(esc.get("ok", false)):
		return "escort should pass: %s" % str(esc)
	var p_done: Dictionary = GameState.caravan_escort_preview()
	if str(p_done.get("reason", "")) != "escorted":
		return "expected escorted: %s" % str(p_done)
	var twice: Dictionary = GameState.escort_caravan()
	if bool(twice.get("ok", false)):
		return "double escort should reject"
	return ""


func _api_start_escort_settle_echo() -> String:
	GameState.silver = 80000
	GameState.food = 10
	GameState.caravan = {}
	GameState.house_mods.erase("caravan_active")
	GameState.house_mods.erase("month_echo")
	var silver0 := int(GameState.silver)
	var food0 := int(GameState.food)
	var st: Dictionary = GameState.start_caravan(KIND)
	if not bool(st.get("ok", false)):
		return "echo start fail: %s" % str(st)
	var snap0: Dictionary = CKEconomyState.month_echo_snapshot()
	if str(snap0.get("caravan", "")).find("上路") < 0:
		return "month_echo caravan missing start: %s" % str(snap0)
	var es: Dictionary = GameState.escort_caravan()
	if not bool(es.get("ok", false)):
		return "echo escort fail: %s" % str(es)
	var snap1: Dictionary = CKEconomyState.month_echo_snapshot()
	if str(snap1.get("caravan", "")).find("护运") < 0:
		return "month_echo caravan missing escort: %s" % str(snap1)
	for i in 3:
		var msgs: Array = GameState.tick_caravan_month()
		var joined := " | ".join(msgs)
		if joined.find("遇劫") >= 0:
			return "escorted month %d raided: %s" % [i + 1, joined]
	if not GameState.caravan.is_empty() and int(GameState.caravan.get("turns_left", 0)) != 0:
		return "caravan not cleared after settle"
	var snap2: Dictionary = CKEconomyState.month_echo_snapshot()
	if str(snap2.get("caravan", "")).find("交割") < 0:
		return "month_echo caravan missing settle: %s" % str(snap2)
	var expect := silver0 - COST - ESCORT + PAYOUT
	if int(GameState.silver) != expect:
		return "payout silver want %d got %d" % [expect, int(GameState.silver)]
	if int(GameState.food) != food0 + 8:
		return "grain unload food want %d got %d" % [food0 + 8, int(GameState.food)]
	var lines := CKEconomyState.month_echo_lines()
	var found := false
	for row in lines:
		if str(row.get("kind", "")) == "caravan":
			found = true
			break
	if not found:
		return "month_echo_lines missing caravan kind"
	print("api settle echo ok text=%s" % str(snap2.get("caravan", "")))
	return ""


func _ui_desktop() -> String:
	GameState.silver = 80000
	GameState.food = 10
	GameState.caravan = {}
	GameState.house_mods.erase("caravan_active")
	GameState.house_mods.erase("month_echo")

	var mkt: Control = MARKET_SCN.instantiate()
	get_tree().root.add_child(mkt)
	mkt.set_anchors_preset(Control.PRESET_TOP_LEFT)
	mkt.position = Vector2.ZERO
	mkt.size = Vector2(1280, 720)
	for _i in 10:
		await get_tree().process_frame

	var start_btn := mkt.find_child("CaravanStart_" + KIND, true, false) as Button
	if start_btn == null or start_btn.disabled:
		mkt.queue_free()
		return "CaravanStart_grain missing/disabled"
	start_btn.pressed.emit()
	for _j in 8:
		await get_tree().process_frame
	if int(GameState.caravan.get("turns_left", 0)) != 3:
		mkt.queue_free()
		return "UI start turns_left != 3"
	var snap_s: Dictionary = CKEconomyState.month_echo_snapshot()
	if str(snap_s.get("caravan", "")) == "":
		mkt.queue_free()
		return "UI missing month_echo.caravan after start"

	var esc := mkt.find_child("CaravanEscort", true, false) as Button
	if esc == null or esc.disabled:
		mkt.queue_free()
		return "CaravanEscort missing/disabled"
	esc.pressed.emit()
	for _k in 8:
		await get_tree().process_frame
	if not bool(GameState.caravan.get("escorted", false)):
		mkt.queue_free()
		return "UI escort not applied"

	for _n in 3:
		GameState.tick_caravan_month()
		await get_tree().process_frame
	if mkt.has_method("_render"):
		mkt.call("_render")
	for _p in 6:
		await get_tree().process_frame

	var echo := mkt.find_child("EchoLine_caravan", true, false) as Label
	if echo == null:
		mkt.queue_free()
		return "EchoLine_caravan missing on market"
	if str(echo.text).find("交割") < 0 and str(echo.text).find("护运") < 0 and str(echo.text).find("上路") < 0:
		mkt.queue_free()
		return "EchoLine_caravan text odd: %s" % echo.text
	print("ui desktop caravan+echo ok text=%s" % echo.text)
	mkt.queue_free()
	await get_tree().process_frame
	return ""
