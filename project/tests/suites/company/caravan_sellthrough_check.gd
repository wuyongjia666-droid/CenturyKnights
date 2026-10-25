extends Node
## Store/economy: landbridge caravan start → escort → 3-month sell-through payout,
## gates (broke/busy/double-escort), Calendar.advance settle, save/load,
## market UI CaravanStart_/CaravanEscort.

const MARKET_SCN := preload("res://scenes/hub/market.tscn")
const KIND := "grain"
const COST := 35
const ESCORT := 12
const PAYOUT := 59  # int(35 * 1.7)

var _fails: Array = []

func _ready() -> void:
	await get_tree().process_frame
	_setup()
	_api_gates()
	_api_escorted_sellthrough()
	_api_spice_unload()
	_api_calendar_settle()
	_api_save_load()
	await _ui_start_escort_settle()
	if _fails.is_empty():
		print("CARAVAN SELLTHROUGH PASS")
		get_tree().quit(0)
	else:
		for f in _fails:
			print("FAIL caravan sellthrough: ", f)
		get_tree().quit(1)

func _ok(cond: bool, msg: String) -> void:
	print("ROW %s %s" % ["PASS" if cond else "FAIL", msg])
	if not cond:
		_fails.append(msg)

func _setup() -> void:
	GameState.new_game("商队环", "灰旗", GameState.crest_color)
	GameState.set_flag("chapter0_done", true)
	UnlockSchedule.install()
	World.events_enabled = false
	World.rivals_enabled = false
	GameState.silver = 80000
	GameState.food = 10
	GameState.iron = 4
	GameState.herb = 2
	GameState.caravan = {}
	GameState.house_mods.erase("caravan_active")

func _api_gates() -> void:
	var save_s := GameState.silver
	GameState.silver = COST - 1
	var broke: Dictionary = GameState.start_caravan(KIND)
	_ok(not bool(broke.get("ok", false)), "start rejected when silver short")
	GameState.silver = save_s
	var bad: Dictionary = GameState.start_caravan("silk")
	_ok(not bool(bad.get("ok", false)), "bad kind rejected")
	var none: Dictionary = GameState.escort_caravan()
	_ok(not bool(none.get("ok", false)), "escort rejected with no caravan")
	var r: Dictionary = GameState.start_caravan(KIND)
	_ok(bool(r.get("ok", false)), "start grain: %s" % r.get("msg", ""))
	_ok(int(GameState.caravan.get("turns_left", 0)) == 3, "turns_left 3")
	_ok(int(GameState.caravan.get("invested", 0)) == COST, "invested %d" % COST)
	_ok(bool(GameState.house_mods.get("caravan_active", false)), "caravan_active flag")
	var busy: Dictionary = GameState.start_caravan("iron")
	_ok(not bool(busy.get("ok", false)), "second start rejected while busy")
	GameState.silver = ESCORT - 1
	var broke_e: Dictionary = GameState.escort_caravan()
	_ok(not bool(broke_e.get("ok", false)), "escort rejected when silver short")
	GameState.silver = save_s
	var e: Dictionary = GameState.escort_caravan()
	_ok(bool(e.get("ok", false)), "escort ok: %s" % e.get("msg", ""))
	_ok(bool(GameState.caravan.get("escorted", false)), "escorted flag")
	var twice: Dictionary = GameState.escort_caravan()
	_ok(not bool(twice.get("ok", false)), "double escort rejected")
	GameState.caravan = {}
	GameState.house_mods.erase("caravan_active")

func _api_escorted_sellthrough() -> void:
	GameState.silver = 80000
	GameState.food = 10
	var silver0 := GameState.silver
	var food0 := GameState.food
	var r: Dictionary = GameState.start_caravan(KIND)
	_ok(bool(r.get("ok", false)), "sellthrough start")
	var e: Dictionary = GameState.escort_caravan()
	_ok(bool(e.get("ok", false)), "sellthrough escort")
	var spent := COST + ESCORT
	_ok(GameState.silver == silver0 - spent, "spent invest+escort %d" % spent)
	for i in 3:
		var msgs: Array = GameState.tick_caravan_month()
		_ok(msgs.size() >= 1, "month %d tick msgs" % (i + 1))
		var joined := " | ".join(msgs)
		_ok(joined.find("遇劫") < 0, "escorted month %d no raid: %s" % [i + 1, joined])
	_ok(int(GameState.caravan.get("turns_left", 0)) == 0, "caravan cleared after settle")
	_ok(not bool(GameState.house_mods.get("caravan_active", false)), "caravan_active erased")
	var expect := silver0 - spent + PAYOUT
	_ok(GameState.silver == expect, "payout silver %d (got %d)" % [expect, GameState.silver])
	_ok(GameState.food == food0 + 8, "grain unload food +8 (got %d)" % GameState.food)

func _api_spice_unload() -> void:
	GameState.silver = 80000
	GameState.herb = 2
	var herb0 := GameState.herb
	var r: Dictionary = GameState.start_caravan("spice")
	_ok(bool(r.get("ok", false)), "spice start")
	GameState.escort_caravan()
	for _i in 3:
		GameState.tick_caravan_month()
	_ok(GameState.herb == herb0 + 3, "spice unload herb +3 (got %d)" % GameState.herb)
	_ok(GameState.caravan.is_empty(), "spice caravan cleared")

func _api_calendar_settle() -> void:
	# Month bus (doctrine) must clear an escorted caravan over 3 advances.
	GameState.silver = 80000
	GameState.food = 200
	GameState.caravan = {}
	GameState.house_mods.erase("caravan_active")
	GameState.start_caravan(KIND)
	GameState.escort_caravan()
	_ok(int(GameState.caravan.get("turns_left", 0)) == 3, "calendar path armed")
	Calendar.advance(3)
	_ok(GameState.caravan.is_empty() or int(GameState.caravan.get("turns_left", 0)) == 0, "Calendar.advance settles caravan")
	_ok(not bool(GameState.house_mods.get("caravan_active", false)), "calendar erased caravan_active")

func _api_save_load() -> void:
	GameState.silver = 80000
	GameState.caravan = {}
	GameState.house_mods.erase("caravan_active")
	GameState.start_caravan("iron")
	GameState.escort_caravan()
	_ok(GameState.save_game(), "save_game with caravan")
	var snap_kind := str(GameState.caravan.get("kind", ""))
	var snap_left := int(GameState.caravan.get("turns_left", 0))
	GameState.caravan = {}
	GameState.house_mods.erase("caravan_active")
	_ok(GameState.load_game(), "load_game")
	_ok(str(GameState.caravan.get("kind", "")) == snap_kind, "caravan kind round-trip")
	_ok(int(GameState.caravan.get("turns_left", 0)) == snap_left, "turns_left round-trip")
	_ok(bool(GameState.caravan.get("escorted", false)), "escorted round-trip")
	GameState.caravan = {}
	GameState.house_mods.erase("caravan_active")

func _ui_start_escort_settle() -> void:
	_setup()
	GameState.silver = 80000
	GameState.food = 10
	var silver0 := GameState.silver
	var food0 := GameState.food
	var mkt: Control = MARKET_SCN.instantiate()
	add_child(mkt)
	for _i in 8:
		await get_tree().process_frame
	var start_btn := mkt.find_child("CaravanStart_" + KIND, true, false) as Button
	_ok(start_btn != null and not start_btn.disabled, "UI CaravanStart_grain ready")
	if start_btn and not start_btn.disabled:
		start_btn.pressed.emit()
		for _j in 5:
			await get_tree().process_frame
	_ok(int(GameState.caravan.get("turns_left", 0)) == 3, "UI start set turns_left")
	var status := mkt.find_child("CaravanStatus", true, false)
	_ok(status != null, "UI CaravanStatus")
	var esc := mkt.find_child("CaravanEscort", true, false) as Button
	_ok(esc != null and not esc.disabled, "UI CaravanEscort ready")
	if esc and not esc.disabled:
		esc.pressed.emit()
		for _k in 5:
			await get_tree().process_frame
	_ok(bool(GameState.caravan.get("escorted", false)), "UI escort applied")
	# Direct ticks keep sell-through deterministic (Calendar covered in _api_calendar_settle).
	for _n in 3:
		GameState.tick_caravan_month()
		await get_tree().process_frame
	_ok(int(GameState.caravan.get("turns_left", 0)) == 0, "UI settle cleared caravan")
	_ok(GameState.food == food0 + 8, "UI grain unload food +8 (got %d)" % GameState.food)
	_ok(GameState.silver == silver0 - COST - ESCORT + PAYOUT, "UI payout silver exact (got %d)" % GameState.silver)
	if mkt.has_method("_render"):
		mkt.call("_render")
	for _p in 4:
		await get_tree().process_frame
	var again := mkt.find_child("CaravanStart_iron", true, false) as Button
	_ok(again != null and not again.disabled, "UI CaravanStart_iron re-enabled after settle")
	mkt.queue_free()
	await get_tree().process_frame
