extends Node
## Fat knife #3: 月循环耐玩一季硬化 —
## 招募|委托 → 一战 → Calendar 月结(沙漏 UI) → hourglass/estates 可读回响 → 下月；
## 欠饷/败战失败出口。真实 Calendar/World/GameState 路径，禁手动 inject month_echo。

const CASTLE_SCN := preload("res://scenes/hub/castle_hub.tscn")
const HOURGLASS_SCN := preload("res://scenes/hub/hourglass.tscn")
const ESTATES_SCN := preload("res://scenes/hub/estates.tscn")
const MARKET_SCN := preload("res://scenes/hub/market.tscn")
const Todo := preload("res://scripts/ui/widgets/todo_center.gd")
const MARKER := "MONTH LOOP PLAYABLE HARDEN FAT PASS"
const SHOT_DIR := "user://month_loop_harden_shots"
const DESK := Vector2i(1600, 900)

var _shot_n := 0


func _ready() -> void:
	var err := await _run()
	if err != "":
		print("FAIL month loop playable harden fat: ", err)
		get_tree().quit(1)
		return
	print(MARKER)
	get_tree().quit(0)


func _run() -> String:
	await get_tree().process_frame
	var err := _algebra()
	if err != "":
		return err
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SHOT_DIR))
	DisplayServer.window_set_size(DESK)
	await _settle(2)
	err = await _happy_month_loop()
	if err != "":
		return err
	err = await _failure_exits()
	if err != "":
		return err
	return ""


func _algebra() -> String:
	var hg := FileAccess.get_file_as_string("res://scripts/hub/hourglass.gd")
	if hg.find("func _paint_echo_board") < 0:
		return "hourglass missing _paint_echo_board"
	if hg.find("_paint_echo_board(_log)") < 0:
		return "hourglass _advance must re-paint echo board"
	if hg.find("func _paint_unpaid_wages_pending") < 0:
		return "hourglass missing unpaid wages pending"
	if hg.find("_paint_unpaid_wages_pending(_forecast)") < 0:
		return "forecast must paint unpaid wages pending"
	var todo := FileAccess.get_file_as_string("res://scripts/ui/widgets/todo_center.gd")
	if todo.find("\"unpaid_wages\"") < 0:
		return "HubTodo missing unpaid_wages"
	if todo.find("CKMorale.unpaid_months") < 0:
		return "HubTodo unpaid must read CKMorale"
	var purse := FileAccess.get_file_as_string("res://scripts/company/purse.gd")
	if purse.find("month_echo_note") < 0 or purse.find("\"unpaid\"") < 0:
		return "purse unpaid must stamp month_echo.unpaid"
	var eco := FileAccess.get_file_as_string("res://scripts/company/economy_state.gd")
	if eco.find("\"unpaid\"") < 0:
		return "month_echo_lines must list unpaid"
	var self_body := FileAccess.get_file_as_string("res://tests/suites/dynasty/month_loop_playable_harden_fat_check.gd")
	var stamp_api := "CKEconomy" + "State.month_echo_note"
	if self_body.find(stamp_api) >= 0:
		return "suite must not call month_echo stamp API (no inject)"
	var assign_echo := "house_mods[" + "\"month_echo\"] ="
	if self_body.find(assign_echo) >= 0:
		return "suite must not inject month_echo dict"
	return ""


func _setup() -> void:
	GameState.new_game("月循环", "灰旗", GameState.crest_color)
	GameState.chapter0_flags["chapter0_done"] = true
	GameState.chapter0_flags["ch0_playing"] = false
	UnlockSchedule.install()
	World.events_enabled = false
	World.rivals_enabled = false
	for nid in World.nations.keys():
		World.rep_nation[str(nid)] = 50
	World.rep_city["ash_capital"] = 80
	World.pos = "ash_capital"
	World.travel = {}
	World.pending_event = {}
	World.encounter = {}
	World.active.clear()
	GameState.silver = 9000
	GameState.food = 120
	GameState.morale = 80
	GameState.house_mods.erase("month_echo")
	GameState.house_mods.erase("unpaid_months")
	Todo.reset_for_tests()


func _happy_month_loop() -> String:
	_setup()
	var err := _step_recruit()
	if err != "":
		return err
	err = await _step_commission_todos()
	if err != "":
		return err
	err = _step_battle_win()
	if err != "":
		return err
	err = await _step_settle_echo()
	if err != "":
		return err
	err = await _step_estates_echo()
	if err != "":
		return err
	err = await _step_next_month()
	if err != "":
		return err
	print("month-loop happy path ok calendar=%s" % Calendar.label())
	return ""


func _step_recruit() -> String:
	if GameState.tavern_candidates.is_empty():
		GameState.refresh_tavern()
	if GameState.tavern_candidates.is_empty():
		return "no tavern candidates"
	var cand: CKCharacter = GameState.tavern_candidates[0]
	var cname := str(cand.name)
	var rr: Dictionary = GameState.recruit(cand)
	if not bool(rr.get("ok", false)):
		return "recruit fail: %s" % str(rr.get("msg", ""))
	var snap: Dictionary = CKEconomyState.month_echo_snapshot()
	if str(snap.get("recruit", "")).find(cname) < 0:
		return "recruit echo missing after GameState.recruit: %s" % str(snap)
	return ""


func _step_commission_todos() -> String:
	var offer: Dictionary = World.seed_deliver_offer("ash_capital")
	if offer.is_empty():
		return "seed_deliver_offer empty"
	var acc: Dictionary = World.accept_quest("ash_capital", str(offer.get("id", "")))
	if not bool(acc.get("ok", false)):
		return "accept_quest fail: %s" % str(acc)
	if World.active.is_empty():
		return "World.active empty after accept"
	var quest_n := 0
	for item in Todo.snapshot():
		if str(item.get("category", "")) == "quests":
			quest_n = int(item.get("count", 0))
	if quest_n < 1:
		return "HubTodo quests count %d after accept" % quest_n
	var castle: Control = CASTLE_SCN.instantiate()
	get_tree().root.add_child(castle)
	castle.set_anchors_preset(Control.PRESET_TOP_LEFT)
	castle.position = Vector2.ZERO
	castle.size = Vector2(1280, 720)
	await _settle(8)
	var todo_chip := castle.find_child("Todo_quests", true, false)
	if todo_chip == null:
		castle.queue_free()
		return "castle missing Todo_quests chip"
	await _shot("pre-month-todos")
	castle.queue_free()
	await _settle(2)
	return ""


func _step_battle_win() -> String:
	World.encounter = {
		"id": "month_loop_seed",
		"kind": "ambush",
		"node": "ash_capital",
		"from": "ash_capital",
		"quest": "",
		"label": "月循环试战",
		"base": "bandit",
		"nation": "ashland",
		"danger": 2,
		"event": "",
		"rep_win": 0,
	}
	var br: Dictionary = World.on_battle_end(true)
	if not bool(br.get("ok", false)) or not bool(br.get("win", false)):
		return "battle win fail: %s" % str(br)
	var snap: Dictionary = CKEconomyState.month_echo_snapshot()
	if str(snap.get("battle", "")) == "":
		return "battle echo empty after World.on_battle_end: %s" % str(snap)
	return ""


func _step_settle_echo() -> String:
	var y0 := int(Calendar.year)
	var m0 := int(Calendar.month)
	var hg: Control = HOURGLASS_SCN.instantiate()
	get_tree().root.add_child(hg)
	hg.set_anchors_preset(Control.PRESET_TOP_LEFT)
	hg.position = Vector2.ZERO
	hg.size = Vector2(1280, 720)
	await _settle(8)
	var adv := hg.find_child("AdvanceMonth", true, false) as BaseButton
	if adv == null:
		hg.queue_free()
		return "hourglass missing AdvanceMonth"
	adv.pressed.emit()
	await _settle(12)
	if int(Calendar.year) * 12 + int(Calendar.month) <= y0 * 12 + m0:
		hg.queue_free()
		return "Calendar did not advance after AdvanceMonth"
	if hg.find_child("EchoLine_recruit", true, false) == null:
		hg.queue_free()
		return "after advance missing EchoLine_recruit (settle board)"
	if hg.find_child("EchoLine_battle", true, false) == null:
		hg.queue_free()
		return "after advance missing EchoLine_battle (settle board)"
	if hg.find_child("ToEstates", true, false) == null:
		hg.queue_free()
		return "after advance missing ToEstates"
	await _shot("settle-hourglass-echo")
	hg.queue_free()
	await _settle(2)
	return ""


func _step_estates_echo() -> String:
	var est: Control = ESTATES_SCN.instantiate()
	get_tree().root.add_child(est)
	est.set_anchors_preset(Control.PRESET_TOP_LEFT)
	est.position = Vector2.ZERO
	est.size = Vector2(1280, 720)
	await _settle(8)
	if est.find_child("MonthEchoPanel", true, false) == null:
		est.queue_free()
		return "estates missing MonthEchoPanel"
	if est.find_child("EchoLine_recruit", true, false) == null:
		est.queue_free()
		return "estates missing EchoLine_recruit"
	if est.find_child("EchoLine_battle", true, false) == null:
		est.queue_free()
		return "estates missing EchoLine_battle"
	est.queue_free()
	await _settle(2)
	return ""


func _step_next_month() -> String:
	var y1 := int(Calendar.year)
	var m1 := int(Calendar.month)
	var hg: Control = HOURGLASS_SCN.instantiate()
	get_tree().root.add_child(hg)
	hg.set_anchors_preset(Control.PRESET_TOP_LEFT)
	hg.position = Vector2.ZERO
	hg.size = Vector2(1280, 720)
	await _settle(8)
	var adv := hg.find_child("AdvanceMonth", true, false) as BaseButton
	if adv == null or adv.disabled:
		hg.queue_free()
		return "next-month AdvanceMonth missing/disabled"
	adv.pressed.emit()
	await _settle(12)
	if int(Calendar.year) * 12 + int(Calendar.month) <= y1 * 12 + m1:
		hg.queue_free()
		return "second advance did not move calendar"
	adv = hg.find_child("AdvanceMonth", true, false) as BaseButton
	if adv == null or adv.disabled:
		hg.queue_free()
		return "下月初态 AdvanceMonth frozen"
	await _shot("next-month-start")
	hg.queue_free()
	await _settle(2)
	return ""


func _failure_exits() -> String:
	var err := await _fail_battle_lose()
	if err != "":
		return err
	err = await _fail_unpaid_exit()
	if err != "":
		return err
	print("month-loop failure exits ok")
	return ""


func _fail_battle_lose() -> String:
	_setup()
	World.encounter = {
		"id": "month_loop_lose",
		"kind": "ambush",
		"node": "ash_capital",
		"from": "ash_capital",
		"quest": "",
		"label": "月循环败战",
		"base": "bandit",
		"nation": "ashland",
		"danger": 1,
		"event": "",
		"rep_win": 0,
	}
	GameState.morale = 40
	var lr: Dictionary = World.on_battle_end(false)
	if not bool(lr.get("ok", false)) or bool(lr.get("win", true)):
		return "battle lose fail: %s" % str(lr)
	var snap: Dictionary = CKEconomyState.month_echo_snapshot()
	var btx := str(snap.get("battle", ""))
	if btx == "":
		return "lose battle echo empty"
	if btx.find("败") < 0 and btx.find("lost") < 0 and btx.find("Defeated") < 0 and btx.find("Battle") < 0:
		return "lose battle wording: %s" % btx
	var hg: Control = HOURGLASS_SCN.instantiate()
	get_tree().root.add_child(hg)
	hg.set_anchors_preset(Control.PRESET_TOP_LEFT)
	hg.position = Vector2.ZERO
	hg.size = Vector2(1280, 720)
	await _settle(8)
	if hg.find_child("EchoLine_battle", true, false) == null:
		hg.queue_free()
		return "lose path hourglass missing EchoLine_battle"
	if hg.find_child("AdvanceMonth", true, false) == null:
		hg.queue_free()
		return "lose path missing AdvanceMonth exit"
	hg.queue_free()
	await _settle(2)
	return ""


func _fail_unpaid_exit() -> String:
	_setup()
	GameState.silver = 0
	GameState.food = 200
	var before_unpaid := CKMorale.unpaid_months(GameState)
	Calendar.advance(1)
	await _settle(2)
	var unpaid_n := CKMorale.unpaid_months(GameState)
	if unpaid_n < 1:
		return "unpaid_months still %d after zero-silver advance (before=%d)" % [unpaid_n, before_unpaid]
	var snap: Dictionary = CKEconomyState.month_echo_snapshot()
	if str(snap.get("unpaid", "")) == "":
		return "unpaid month_echo empty after payday: %s" % str(snap)
	var found_todo := false
	for item in Todo.snapshot():
		if str(item.get("category", "")) == "unpaid_wages" and int(item.get("count", 0)) >= 1:
			found_todo = true
			if str(item.get("link", "")).find("market") < 0:
				return "unpaid_wages link want market got %s" % str(item.get("link", ""))
	if not found_todo:
		return "HubTodo missing unpaid_wages after payday"
	var err := await _fail_unpaid_ui(unpaid_n)
	if err != "":
		return err
	return ""


func _fail_unpaid_ui(unpaid_n: int) -> String:
	var castle: Control = CASTLE_SCN.instantiate()
	get_tree().root.add_child(castle)
	castle.set_anchors_preset(Control.PRESET_TOP_LEFT)
	castle.position = Vector2.ZERO
	castle.size = Vector2(1280, 720)
	await _settle(8)
	if castle.find_child("Todo_unpaid_wages", true, false) == null:
		castle.queue_free()
		return "castle missing Todo_unpaid_wages"
	var market: Control = MARKET_SCN.instantiate()
	get_tree().root.add_child(market)
	market.set_anchors_preset(Control.PRESET_TOP_LEFT)
	market.position = Vector2.ZERO
	market.size = Vector2(1280, 720)
	await _settle(6)
	if not is_instance_valid(market):
		castle.queue_free()
		return "market CTA exit failed to instantiate"
	market.queue_free()
	castle.queue_free()
	await _settle(2)
	var hg: Control = HOURGLASS_SCN.instantiate()
	get_tree().root.add_child(hg)
	hg.set_anchors_preset(Control.PRESET_TOP_LEFT)
	hg.position = Vector2.ZERO
	hg.size = Vector2(1280, 720)
	await _settle(8)
	if hg.find_child("UnpaidWagesPending", true, false) == null:
		hg.queue_free()
		return "hourglass missing UnpaidWagesPending"
	if hg.find_child("ToMarket", true, false) == null:
		hg.queue_free()
		return "hourglass missing ToMarket CTA"
	if hg.find_child("EchoLine_unpaid", true, false) == null:
		hg.queue_free()
		return "hourglass missing EchoLine_unpaid after unpaid settle"
	hg.queue_free()
	await _settle(2)
	print("month-loop unpaid ui ok n=%d" % unpaid_n)
	return ""


func _shot(tag: String) -> void:
	_shot_n += 1
	var vp := get_viewport()
	if vp == null:
		return
	await get_tree().process_frame
	var img: Image = vp.get_texture().get_image()
	if img == null:
		return
	var path := "%s/%02d_%s.png" % [SHOT_DIR, _shot_n, tag]
	var err := img.save_png(path)
	print("shot %s err=%s size=%s" % [path, err, img.get_size()])


func _settle(frames: int) -> void:
	for _i in frames:
		await get_tree().process_frame
