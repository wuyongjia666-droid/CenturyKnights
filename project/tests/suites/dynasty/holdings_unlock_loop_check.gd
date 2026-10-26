extends Node
## Dynasty fat: holding_unlock_preview → quest/short reject → claim → owned
## → month_echo.unlock → UI HoldingUnlock_ (desktop). Avoids #473 surface.

const HID := "stone_slope"
const QID := "q_bandit"
const MARKER := "HOLDINGS UNLOCK LOOP PASS"

func _ready() -> void:
	var err := await _run()
	if err != "":
		print("FAIL holdings unlock: ", err)
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
	# strip target holding; keep reed_ford from new_game if present
	GameState.holdings.erase(HID)
	GameState.quest_done.erase(QID)
	GameState.mark_dirty()

	var err := _api_preview_reject_and_claim()
	if err != "":
		return err
	err = await _ui_desktop()
	if err != "":
		return err
	return ""


func _api_preview_reject_and_claim() -> String:
	GameState.holdings.erase(HID)
	GameState.quest_done.erase(QID)
	GameState.silver = 200
	GameState.food = 80
	var err := _api_quest_gate()
	if err != "":
		return err
	err = _api_short_gate()
	if err != "":
		return err
	err = _api_claim_ok()
	if err != "":
		return err
	return ""


func _api_quest_gate() -> String:
	var prev_q: Dictionary = GameState.holding_unlock_preview(HID)
	if bool(prev_q.get("quest_ready", false)) or bool(prev_q.get("claimable", false)):
		return "expected quest gate: %s" % str(prev_q)
	var bad_q: Dictionary = GameState.claim_holding(HID)
	if bool(bad_q.get("ok", false)) or GameState.holdings.has(HID):
		return "quest gate should reject (ok=%s has=%s)" % [str(bad_q.get("ok")), str(GameState.holdings.has(HID))]
	return ""


func _api_short_gate() -> String:
	GameState.quest_done[QID] = true
	GameState.silver = 5
	GameState.food = 1
	var prev_s: Dictionary = GameState.holding_unlock_preview(HID)
	if not bool(prev_s.get("quest_ready", false)) or not bool(prev_s.get("short", false)):
		return "expected short after quest: %s" % str(prev_s)
	var bad_s: Dictionary = GameState.claim_holding(HID)
	if bool(bad_s.get("ok", false)) or GameState.holdings.has(HID):
		return "short should reject (ok=%s has=%s)" % [str(bad_s.get("ok")), str(GameState.holdings.has(HID))]
	return ""


func _api_claim_ok() -> String:
	GameState.silver = 200
	GameState.food = 80
	var prev: Dictionary = GameState.holding_unlock_preview(HID)
	if not bool(prev.get("claimable", false)):
		return "preview should be claimable: %s" % str(prev)
	if int(prev.get("cost_s", 0)) != 25 or int(prev.get("cost_f", 0)) != 5:
		return "cost expected 25/5: %s" % str(prev)
	var before_s := int(GameState.silver)
	var before_f := int(GameState.food)
	GameState.house_mods.erase("month_echo")
	var ok: Dictionary = GameState.claim_holding(HID)
	if not bool(ok.get("ok", false)):
		return "claim failed: %s" % str(ok)
	if not GameState.holdings.has(HID) or int(GameState.holding_level(HID)) != 1:
		return "holding not owned lv1 after claim"
	if int(GameState.silver) != before_s - 25 or int(GameState.food) != before_f - 5:
		return "silver/food delta"
	var snap: Dictionary = CKEconomyState.month_echo_snapshot()
	if str(snap.get("unlock", "")) == "":
		return "month_echo unlock empty: %s" % str(snap)
	var again: Dictionary = GameState.claim_holding(HID)
	if bool(again.get("ok", false)):
		return "owned should reject"
	print("api claim ok echo=%s" % str(snap.get("unlock", "")))
	return ""


func _ui_desktop() -> String:
	GameState.holdings.erase(HID)
	GameState.quest_done[QID] = true
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

	var btn := page.find_child("HoldingUnlock_%s" % HID, true, false) as Button
	if btn == null:
		page.queue_free()
		return "HoldingUnlock_%s missing" % HID
	if btn.disabled:
		page.queue_free()
		return "HoldingUnlock disabled unexpectedly"

	btn.pressed.emit()
	for _i in 8:
		await get_tree().process_frame
	if not GameState.holdings.has(HID):
		page.queue_free()
		return "UI claim did not unlock"
	var snap: Dictionary = CKEconomyState.month_echo_snapshot()
	if str(snap.get("unlock", "")) == "":
		page.queue_free()
		return "UI missing month_echo.unlock"

	var echo := page.find_child("EchoLine_unlock", true, false) as Label
	if echo == null:
		page.queue_free()
		return "EchoLine_unlock missing on estates"
	print("ui desktop unlock+echo ok text=%s" % echo.text)
	page.queue_free()
	await get_tree().process_frame
	return ""
