extends Node
## Fat deepen: camp_readout prefers seal-aware remain when winter bypass is held.

const ORIGIN := "sy_capital"
const DEST := "sy_ridge"

var fails: Array = []

func _ready() -> void:
	if get_parent() != get_tree().root and get_parent() != null:
		return
	await get_tree().process_frame
	await run_all()

func run_all() -> void:
	_api_bypass_prefers_seal_remain()
	_api_short_flags_on_bypass()
	_api_no_bypass_without_detour()
	if fails.is_empty():
		print("CAMP SEAL READOUT PASS")
		get_tree().quit(0)
	else:
		for f in fails:
			print("FAIL camp seal readout: ", f)
		get_tree().quit(1)

func _ok(cond: bool, msg: String) -> void:
	print("ROW %s %s" % ["PASS" if cond else "FAIL", msg])
	if not cond:
		fails.append(msg)

func _setup() -> void:
	GameState.new_game("宿营旁路粮条", "灰旗", GameState.crest_color)
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

func _stage_held_bypass(short_cover: bool) -> int:
	_setup()
	_ok(CKRoadSeal.seal_active(), "winter seals")
	var cmp: Dictionary = CKRoadSeal.compare(DEST)
	var path: Array = cmp.get("detour", {}).get("path", [])
	_ok(bool(cmp.get("sealed", false)) and path.size() >= 3, "detour ready (%s)" % path.size())
	if path.size() < 3:
		return 0
	World.note_seal_detour(DEST, path)
	World.hold_march(DEST)
	var need := World.seal_aware_remain_days(DEST)
	_ok(need > 2, "bypass remain >2 (%d)" % need)
	var per := World.food_per_day()
	if short_cover:
		GameState.food = per * maxi(0, need - 2)
	else:
		GameState.food = per * (need + 2)
	return need

func _api_bypass_prefers_seal_remain() -> void:
	var need := _stage_held_bypass(false)
	if need <= 0:
		return
	var cr: Dictionary = World.camp_readout({"id": "camp_night", "ctx": {"nights": 1}})
	_ok(bool(cr.get("seal_bypass", false)), "seal_bypass set")
	_ok(int(cr.get("seal_need", 0)) == need, "seal_need matches")
	_ok(int(cr.get("remain_days", 0)) == need, "remain_days uses seal (%d)" % int(cr.get("remain_days", 0)))
	_ok(int(cr.get("remain_food", 0)) == World.food_per_day() * need, "remain_food = per*need")
	_ok(not bool(cr.get("short", false)), "stocked: not short")

func _api_short_flags_on_bypass() -> void:
	var need := _stage_held_bypass(true)
	if need <= 0:
		return
	var cr: Dictionary = World.camp_readout({"id": "camp_night", "ctx": {"nights": 1}})
	_ok(bool(cr.get("seal_bypass", false)), "short: seal_bypass")
	_ok(int(cr.get("remain_days", 0)) == need, "short: remain = seal need")
	_ok(bool(cr.get("short", false)), "short: short flag")

func _api_no_bypass_without_detour() -> void:
	_setup()
	GameState.food = World.food_per_day() * 10
	var cr: Dictionary = World.camp_readout({"id": "camp_night", "ctx": {"nights": 1}})
	_ok(not bool(cr.get("seal_bypass", false)), "no detour: no seal_bypass")
	_ok(int(cr.get("seal_need", 0)) == 0, "no detour: seal_need 0")
