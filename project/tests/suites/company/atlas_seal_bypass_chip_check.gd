extends Node
## Fat deepen: seal_bypass_chip exposes winter remain for top-bar.

const ORIGIN := "sy_capital"
const DEST := "sy_ridge"

var fails: Array = []

func _ready() -> void:
	if get_parent() != get_tree().root and get_parent() != null:
		return
	await get_tree().process_frame
	await run_all()

func run_all() -> void:
	_api_chip_when_held()
	_api_chip_short()
	_api_chip_hidden_without_detour()
	if fails.is_empty():
		print("SEAL BYPASS CHIP PASS")
		get_tree().quit(0)
	else:
		for f in fails:
			print("FAIL seal bypass chip: ", f)
		get_tree().quit(1)

func _ok(cond: bool, msg: String) -> void:
	print("ROW %s %s" % ["PASS" if cond else "FAIL", msg])
	if not cond:
		fails.append(msg)

func _setup() -> void:
	GameState.new_game("旁路顶栏", "灰旗", GameState.crest_color)
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

func _stage(short_cover: bool) -> int:
	_setup()
	_ok(CKRoadSeal.seal_active(), "winter seals")
	var cmp: Dictionary = CKRoadSeal.compare(DEST)
	var path: Array = cmp.get("detour", {}).get("path", [])
	_ok(bool(cmp.get("sealed", false)) and path.size() >= 3, "detour ready")
	if path.size() < 3:
		return 0
	World.note_seal_detour(DEST, path)
	World.hold_march(DEST)
	var need := World.seal_aware_remain_days(DEST)
	_ok(need > 0, "need >0 (%d)" % need)
	var per := World.food_per_day()
	if short_cover:
		GameState.food = per * maxi(0, need - 2)
	else:
		GameState.food = per * (need + 3)
	return need

func _api_chip_when_held() -> void:
	var need := _stage(false)
	if need <= 0:
		return
	var c: Dictionary = World.seal_bypass_chip()
	_ok(bool(c.get("show", false)), "chip show")
	_ok(int(c.get("seal_need", 0)) == need, "chip seal_need")
	_ok(not bool(c.get("short", false)), "stocked: not short")

func _api_chip_short() -> void:
	var need := _stage(true)
	if need <= 0:
		return
	var c: Dictionary = World.seal_bypass_chip()
	_ok(bool(c.get("show", false)), "short: show")
	_ok(bool(c.get("short", false)), "short: short flag")

func _api_chip_hidden_without_detour() -> void:
	_setup()
	var c: Dictionary = World.seal_bypass_chip()
	_ok(not bool(c.get("show", false)), "no detour: hidden")
