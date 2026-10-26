extends Node
## Fat deepen: mid-bypass food halt payload carries seal_bypass + seal_need.

const ORIGIN := "sy_capital"
const DEST := "sy_ridge"

var fails: Array = []

func _ready() -> void:
	if get_parent() != get_tree().root and get_parent() != null:
		return
	await get_tree().process_frame
	await run_all()

func run_all() -> void:
	_api_halt_marks_seal()
	_api_halt_no_seal_without_detour()
	if fails.is_empty():
		print("SUPPLY HALT SEAL PASS")
		get_tree().quit(0)
	else:
		for f in fails:
			print("FAIL supply halt seal: ", f)
		get_tree().quit(1)

func _ok(cond: bool, msg: String) -> void:
	print("ROW %s %s" % ["PASS" if cond else "FAIL", msg])
	if not cond:
		fails.append(msg)

func _setup() -> void:
	GameState.new_game("断粮旁路标", "灰旗", GameState.crest_color)
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

func _api_halt_marks_seal() -> void:
	_setup()
	_ok(CKRoadSeal.seal_active(), "winter seals")
	var cmp: Dictionary = CKRoadSeal.compare(DEST)
	var path: Array = cmp.get("detour", {}).get("path", [])
	_ok(bool(cmp.get("sealed", false)) and path.size() >= 3, "detour ready (%s)" % path.size())
	if path.size() < 3:
		return
	World.note_seal_detour(DEST, path)
	World.travel_to(str(path[1]))
	World.hold_march(DEST)
	var need := World.seal_aware_remain_days(DEST)
	_ok(need > 0, "seal need >0 (%d)" % need)
	GameState.food = 0
	World._mark_supply_halt(2)
	var halt: Dictionary = World.last_supply_halt
	_ok(not halt.is_empty(), "halt payload set")
	_ok(bool(halt.get("seal_bypass", false)), "seal_bypass on halt")
	_ok(int(halt.get("seal_need", 0)) == need, "seal_need on halt (%d)" % int(halt.get("seal_need", 0)))
	_ok(str(halt.get("held", "")) == DEST, "held dest")
	var taken: Dictionary = World.take_supply_halt()
	_ok(bool(taken.get("seal_bypass", false)), "take keeps seal_bypass")
	_ok(World.last_supply_halt.is_empty(), "take clears")

func _api_halt_no_seal_without_detour() -> void:
	_setup()
	World.travel_to(DEST)
	GameState.food = 0
	World._mark_supply_halt(1)
	var halt: Dictionary = World.last_supply_halt
	_ok(not bool(halt.get("seal_bypass", false)), "no detour: no seal_bypass")
	_ok(int(halt.get("seal_need", 0)) == 0, "no detour: seal_need 0")
