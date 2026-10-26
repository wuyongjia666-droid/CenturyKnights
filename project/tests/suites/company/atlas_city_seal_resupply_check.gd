extends Node
## Fat deepen: mid-bypass city offers one-tap seal-aware grain buy; clears seal_short.

const ORIGIN := "sy_capital"
const DEST := "sy_ridge"

var fails: Array = []

func _ready() -> void:
	if get_parent() != get_tree().root and get_parent() != null:
		return
	await get_tree().process_frame
	await run_all()

func run_all() -> void:
	_api_offer_when_short()
	_api_buy_clears_short()
	_api_none_when_stocked()
	_api_no_offer_without_hold()
	if fails.is_empty():
		print("CITY SEAL RESUPPLY PASS")
		get_tree().quit(0)
	else:
		for f in fails:
			print("FAIL city seal resupply: ", f)
		get_tree().quit(1)

func _ok(cond: bool, msg: String) -> void:
	print("ROW %s %s" % ["PASS" if cond else "FAIL", msg])
	if not cond:
		fails.append(msg)

func _setup() -> void:
	GameState.new_game("城内旁路补粮", "灰旗", GameState.crest_color)
	GameState.set_flag("chapter0_done", true)
	UnlockSchedule.install()
	World.events_enabled = false
	World.rivals_enabled = false
	for nid in World.nations.keys():
		World.rep_nation[str(nid)] = 40
	GameState.silver = 5000
	GameState.morale = 80
	Calendar.year = 1
	Calendar.month = 1
	World.day = 1
	World.days_total = 0
	World.pos = ORIGIN
	World.travel = {}
	World.pending_event = {}
	World.encounter = {}
	World.active.clear()
	World.road_flags.clear()
	World.march_hold = {}
	World.seal_detour = {}
	World.city_gate = {}
	World.last_supply_halt = {}

func _stage_mid_bypass(short_cover: bool) -> int:
	_setup()
	_ok(CKRoadSeal.seal_active(), "winter seals")
	var cmp: Dictionary = CKRoadSeal.compare(DEST)
	var path: Array = cmp.get("detour", {}).get("path", [])
	_ok(bool(cmp.get("sealed", false)) and path.size() >= 3, "detour ready (%s)" % path.size())
	if path.size() < 3:
		return 0
	World.note_seal_detour(DEST, path)
	World.travel_to(str(path[1]))
	World.hold_march(DEST)
	var need := World.seal_aware_remain_days(DEST)
	_ok(need > 2, "bypass remain >2 (%d)" % need)
	var per := World.food_per_day()
	if short_cover:
		var target_cover := need - 1 if need > 1 else 0
		GameState.food = per * target_cover
	else:
		GameState.food = per * (need + 2)
	World.note_city_gate("in")
	return need

func _api_offer_when_short() -> void:
	var need := _stage_mid_bypass(true)
	if need <= 0:
		return
	var offer: Dictionary = World.city_seal_resupply_offer()
	_ok(bool(offer.get("needed", false)), "offer needed when short")
	_ok(bool(offer.get("ok", false)), "offer quotable")
	_ok(int(offer.get("seal_need", 0)) == need, "offer seal_need")
	_ok(int(offer.get("days", 0)) >= need, "buy days >= seal need (%d >= %d)" % [int(offer.get("days", 0)), need])
	_ok(World.held_march_dest() == DEST, "held_march_dest")

func _api_buy_clears_short() -> void:
	var need := _stage_mid_bypass(true)
	if need <= 0:
		return
	var before := GameState.food
	var r: Dictionary = World.city_seal_resupply()
	_ok(bool(r.get("ok", false)), "resupply ok: %s" % r.get("msg", ""))
	_ok(GameState.food > before, "food rose %d -> %d" % [before, GameState.food])
	var g: Dictionary = r.get("gate", {})
	_ok(not bool(g.get("seal_short", false)), "gate seal_short cleared")
	_ok(not bool(g.get("warn", false)), "gate warn cleared")
	var offer2: Dictionary = World.city_seal_resupply_offer()
	_ok(not bool(offer2.get("needed", false)), "no further offer")
	var none: Dictionary = World.city_seal_resupply()
	_ok(not bool(none.get("ok", false)), "second buy refused")
	_ok(str(none.get("msg", "")).find(Locale.t("atlas_city_seal_resupply_none")) >= 0, "none msg")

func _api_none_when_stocked() -> void:
	var need := _stage_mid_bypass(false)
	if need <= 0:
		return
	var offer: Dictionary = World.city_seal_resupply_offer()
	_ok(not bool(offer.get("needed", false)), "stocked: no offer")

func _api_no_offer_without_hold() -> void:
	_setup()
	GameState.food = World.food_per_day()
	World.note_city_gate("in")
	var offer: Dictionary = World.city_seal_resupply_offer()
	_ok(not bool(offer.get("needed", false)), "no hold: no offer")
