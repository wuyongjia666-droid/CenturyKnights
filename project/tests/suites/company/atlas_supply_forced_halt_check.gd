extends Node
## Fat atlas: mid-march food=0 → SupplyHaltModal forage / press / forced-stop E2E.

const ATLAS_SCN := preload("res://scenes/hub/atlas_view.tscn")
var _fails: Array = []

func _ready() -> void:
	await get_tree().process_frame
	_api_starve_marks_halt()
	_api_forage_clears()
	_api_press_and_forced_stop()
	await _ui_supply_halt_forage()
	await _ui_supply_halt_forced_stopover()
	if _fails.is_empty():
		print("ATLAS SUPPLY FORCED HALT PASS")
		get_tree().quit(0)
	else:
		for f in _fails:
			print("FAIL atlas supply halt: ", f)
		get_tree().quit(1)

func _ok(cond: bool, msg: String) -> void:
	print("ROW %s %s" % ["PASS" if cond else "FAIL", msg])
	if not cond:
		_fails.append(msg)

func _setup() -> void:
	GameState.new_game("断粮停靠", "灰旗", GameState.crest_color)
	GameState.set_flag("chapter0_done", true)
	UnlockSchedule.install()
	World.events_enabled = false
	World.rivals_enabled = false
	for nid in World.nations.keys():
		World.rep_nation[str(nid)] = 50
	GameState.food = 2
	GameState.silver = 8000
	GameState.morale = 70
	World.hub_tour.clear()
	World.pos = "ash_capital"
	World.travel = {}
	World.pending_event = {}
	World.encounter = {}
	World.last_supply_halt.clear()
	World.last_aftermath.clear()

func _api_starve_marks_halt() -> void:
	_setup()
	GameState.food = 1
	var st: Dictionary = World.begin_travel("stone_slope")
	_ok(bool(st.get("ok", false)), "begin_travel: %s" % st.get("msg", ""))
	if not bool(st.get("ok", false)):
		return
	# Burn through rations via multi-day advance while traveling
	var need := World.food_per_day()
	GameState.food = maxi(0, need - 1)
	World.advance_days(maxi(need, 2))
	_ok(GameState.food == 0, "food drained to 0")
	_ok(not World.last_supply_halt.is_empty(), "last_supply_halt set while traveling")
	_ok(str(World.last_supply_halt.get("dest", "")) == "stone_slope", "halt dest stone_slope")
	_ok(int(World.last_supply_halt.get("starved_days", 0)) >= 1, "starved_days >= 1")

func _api_forage_clears() -> void:
	_setup()
	GameState.food = 0
	World.begin_travel("stone_slope")
	World._mark_supply_halt(2)
	_ok(not World.last_supply_halt.is_empty(), "halt seeded")
	var before := GameState.food
	var morale0 := GameState.morale
	var r: Dictionary = World.forage_supply()
	_ok(bool(r.get("ok", false)), "forage ok: %s" % r.get("msg", ""))
	_ok(GameState.food > before, "forage raised food %d → %d" % [before, GameState.food])
	_ok(int(r.get("food_gained", 0)) >= 2, "food_gained >= 2")
	_ok(World.last_supply_halt.is_empty(), "halt cleared after forage")
	_ok(GameState.morale == morale0 - 1 or GameState.morale < morale0, "forage morale cost")

func _api_press_and_forced_stop() -> void:
	_setup()
	GameState.food = 0
	World.begin_travel("stone_slope")
	World._mark_supply_halt(1)
	var m0 := GameState.morale
	var pr: Dictionary = World.press_on_starving()
	_ok(bool(pr.get("ok", false)), "press ok")
	_ok(World.last_supply_halt.is_empty(), "press clears halt")
	_ok(GameState.morale < m0, "press morale drop")
	_ok(World.is_traveling(), "still traveling after press")
	# Forced stop
	World._mark_supply_halt(1)
	var dest := str(World.travel.get("dest", ""))
	var fr: Dictionary = World.forced_halt_march()
	_ok(bool(fr.get("ok", false)), "forced stop ok: %s" % fr.get("msg", ""))
	_ok(not World.is_traveling(), "travel cancelled")
	_ok(str(fr.get("dest", "")) == dest, "forced stop returns dest")
	_ok(World.last_supply_halt.is_empty(), "halt cleared on forced stop")

func _ui_supply_halt_forage() -> void:
	_setup()
	GameState.food = 0
	World.begin_travel("stone_slope")
	World._mark_supply_halt(2)
	# Cancel march so forage CTA does not immediately resume+drain rations before assert.
	World.cancel_travel()
	var page: Control = ATLAS_SCN.instantiate()
	get_tree().root.add_child(page)
	for _i in 14:
		await get_tree().process_frame
	var modal: Node = page.find_child("SupplyHaltModal", true, false)
	if modal == null and page.has_method("_check_supply_halt"):
		if World.last_supply_halt.is_empty():
			World.last_supply_halt = {
				"pos": World.pos, "dest": "stone_slope", "morale": GameState.morale,
				"starved_days": 2, "food": 0,
			}
		page.call("_check_supply_halt")
		for _j in 8:
			await get_tree().process_frame
		modal = page.find_child("SupplyHaltModal", true, false)
	_ok(modal != null, "SupplyHaltModal present")
	if modal == null:
		page.queue_free()
		return
	_ok(modal.get_node_or_null("SupplyHaltBody") != null, "SupplyHaltBody")
	_ok(modal.get_node_or_null("SupplyForage") != null, "SupplyForage")
	_ok(modal.get_node_or_null("SupplyPressOn") != null, "SupplyPressOn")
	_ok(modal.get_node_or_null("SupplyForcedStop") != null, "SupplyForcedStop")
	_ok(modal.get_node_or_null("SupplyHaltLater") != null, "SupplyHaltLater")
	var food0 := GameState.food
	var btn: Button = modal.get_node_or_null("SupplyForage") as Button
	if btn:
		btn.pressed.emit()
		for _k in 12:
			await get_tree().process_frame
	_ok(GameState.food > food0, "UI forage raised food")
	_ok(page.find_child("SupplyHaltModal", true, false) == null, "modal closed after forage")
	page.queue_free()

func _ui_supply_halt_forced_stopover() -> void:
	_setup()
	GameState.food = 0
	World.begin_travel("stone_slope")
	World._mark_supply_halt(1)
	var page: Control = ATLAS_SCN.instantiate()
	get_tree().root.add_child(page)
	for _i in 14:
		await get_tree().process_frame
	if page.find_child("SupplyHaltModal", true, false) == null and page.has_method("_check_supply_halt"):
		if World.last_supply_halt.is_empty():
			World.last_supply_halt = {
				"pos": World.pos, "dest": "stone_slope", "morale": GameState.morale,
				"starved_days": 1, "food": 0,
			}
		page.call("_check_supply_halt")
		for _j in 8:
			await get_tree().process_frame
	var modal: Node = page.find_child("SupplyHaltModal", true, false)
	_ok(modal != null, "SupplyHaltModal for forced stop")
	if modal == null:
		page.queue_free()
		return
	var stop: Button = modal.get_node_or_null("SupplyForcedStop") as Button
	if stop:
		stop.pressed.emit()
		for _k in 14:
			await get_tree().process_frame
	_ok(not World.is_traveling(), "UI forced stop cancelled travel")
	_ok(page.find_child("StopoverModal", true, false) != null, "StopoverModal after forced stop")
	var resume := page.find_child("StopoverResume", true, false) as Button
	_ok(resume != null, "StopoverResume after supply forced stop")
	page.queue_free()
