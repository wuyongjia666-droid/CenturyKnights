extends Node
## Fat deepen: leaving a city mid-winter-bypass warns when cover < seal-aware remain.

const ORIGIN := "sy_capital"
const DEST := "sy_ridge"

var fails: Array = []

func _ready() -> void:
	if get_parent() != get_tree().root and get_parent() != null:
		return
	await get_tree().process_frame
	await run_all()

func run_all() -> void:
	_api_gate_seal_short()
	_api_gate_thin_still_warns()
	_api_gate_ok_when_stocked()
	if fails.is_empty():
		print("GATE SEAL COVER PASS")
		get_tree().quit(0)
	else:
		for f in fails:
			print("FAIL gate seal cover: ", f)
		get_tree().quit(1)

func _ok(cond: bool, msg: String) -> void:
	print("ROW %s %s" % ["PASS" if cond else "FAIL", msg])
	if not cond:
		fails.append(msg)

func _setup() -> void:
	GameState.new_game("城门旁路", "灰旗", GameState.crest_color)
	GameState.set_flag("chapter0_done", true)
	UnlockSchedule.install()
	World.events_enabled = false
	World.rivals_enabled = false
	for nid in World.nations.keys():
		World.rep_nation[str(nid)] = 40
	GameState.silver = 800
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

func _api_gate_seal_short() -> void:
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
	# Low stores: enough for flat 7-day habit but short of bypass remain.
	var need := World.seal_aware_remain_days(DEST)
	_ok(need > 2, "bypass remain >2 (%d)" % need)
	var per := World.food_per_day()
	# cover exactly need-1 when possible; else cover=1 (still seal_short, may also thin-warn).
	var target_cover := need - 1 if need > 1 else 0
	GameState.food = per * target_cover
	var cover := 0 if per <= 0 else int(GameState.food / per)
	_ok(cover < need, "cover %d < need %d" % [cover, need])
	var g: Dictionary = World.note_city_gate("out")
	_ok(bool(g.get("seal_short", false)), "seal_short flagged")
	_ok(bool(g.get("warn", false)), "warn flagged")
	_ok(int(g.get("seal_need", 0)) == need, "seal_need stored")
	var text := World.city_gate_text()
	_ok(text.find(Locale.t("atlas_gate_seal_warn") % need) >= 0, "gate text names seal warn")
	_ok(text.find(Locale.t("atlas_gate_warn")) < 0, "thin-ration warn not preferred over seal")

func _api_gate_thin_still_warns() -> void:
	_setup()
	World.seal_detour = {}
	World.march_hold = {}
	GameState.food = World.food_per_day()  # cover == 1
	var g: Dictionary = World.note_city_gate("out")
	_ok(bool(g.get("warn", false)), "thin cover warns")
	_ok(not bool(g.get("seal_short", false)), "no seal_short without held dest")
	_ok(World.city_gate_text().find(Locale.t("atlas_gate_warn")) >= 0, "thin warn text")

func _api_gate_ok_when_stocked() -> void:
	_setup()
	var cmp: Dictionary = CKRoadSeal.compare(DEST)
	var path: Array = cmp.get("detour", {}).get("path", [])
	if path.size() < 3:
		_ok(false, "stocked test needs detour")
		return
	World.note_seal_detour(DEST, path)
	World.travel_to(str(path[1]))
	World.hold_march(DEST)
	var need := World.seal_aware_remain_days(DEST)
	GameState.food = World.food_per_day() * (need + 2)
	var g: Dictionary = World.note_city_gate("out")
	_ok(not bool(g.get("seal_short", false)), "stocked: no seal_short")
	_ok(not bool(g.get("warn", false)), "stocked: no warn")
	_ok(World.city_gate_text().find(Locale.t("atlas_gate_seal_warn") % need) < 0, "stocked: no seal warn text")
