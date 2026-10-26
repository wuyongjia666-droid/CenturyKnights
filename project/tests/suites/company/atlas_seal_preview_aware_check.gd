extends Node
## Fat deepen: recorded seal detour makes HUD/hold_march preview use bypass days/food.

const ORIGIN := "sy_capital"
const DEST := "sy_ridge"

var fails: Array = []

func _ready() -> void:
	if get_parent() != get_tree().root and get_parent() != null:
		return
	await get_tree().process_frame
	await run_all()

func run_all() -> void:
	_api_preview_prefers_bypass()
	_api_hold_march_uses_bypass()
	_api_raw_preview_stays_shortest()
	if fails.is_empty():
		print("SEAL PREVIEW AWARE PASS")
		get_tree().quit(0)
	else:
		for f in fails:
			print("FAIL seal preview-aware: ", f)
		get_tree().quit(1)

func _ok(cond: bool, msg: String) -> void:
	print("ROW %s %s" % ["PASS" if cond else "FAIL", msg])
	if not cond:
		fails.append(msg)

func _setup() -> void:
	GameState.new_game("封路预览", "灰旗", GameState.crest_color)
	GameState.set_flag("chapter0_done", true)
	UnlockSchedule.install()
	World.events_enabled = false
	World.rivals_enabled = false
	for nid in World.nations.keys():
		World.rep_nation[str(nid)] = 40
	GameState.food = 40
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
	World.last_supply_halt = {}

func _api_preview_prefers_bypass() -> void:
	_setup()
	_ok(CKRoadSeal.seal_active(), "winter seals")
	var cmp: Dictionary = CKRoadSeal.compare(DEST)
	_ok(bool(cmp.get("sealed", false)), "direct road sealed")
	var detour: Dictionary = cmp.get("detour", {})
	var path: Array = detour.get("path", [])
	_ok(bool(detour.get("ok", false)) and path.size() >= 3, "detour has >=3 hops (%s)" % path.size())
	if path.size() < 3:
		return
	World.note_seal_detour(DEST, path)
	# Stand at mid hop so remaining is a proper subpath.
	var hop1 := str(path[1])
	World.travel_to(hop1)
	_ok(World.pos == hop1, "mid-detour at %s" % hop1)
	var rem: Array = World.seal_detour_remaining()
	_ok(rem.size() >= 2, "remaining >=2")
	var aware: Dictionary = World.seal_aware_travel_preview(DEST)
	_ok(bool(aware.get("ok", false)), "aware preview ok")
	_ok(bool(aware.get("seal_bypass", false)), "aware marks seal_bypass")
	_ok(aware.get("path", []) == rem, "aware path equals remaining bypass")
	var bare: Dictionary = World.travel_preview(DEST)
	_ok(bool(bare.get("ok", false)), "raw preview ok")
	var mattered: bool = aware.get("path", []) != bare.get("path", []) or int(aware.get("days", 0)) != int(bare.get("days", 0))
	_ok(mattered or aware.get("path", []) == rem, "aware differs from raw or equals rem")
	# Food math: low stores should short against bypass days when bypass is longer.
	var bypass_food := int(aware.get("food", 0))
	_ok(bypass_food == World.food_per_day() * int(aware.get("days", 0)), "aware food = per_day * days")
	_ok(bool(aware.get("short_food", false)) == (GameState.food < bypass_food), "short_food matches stores vs bypass")

func _api_hold_march_uses_bypass() -> void:
	_setup()
	var cmp: Dictionary = CKRoadSeal.compare(DEST)
	var path: Array = cmp.get("detour", {}).get("path", [])
	if path.size() < 3:
		_ok(false, "hold test needs detour")
		return
	World.note_seal_detour(DEST, path)
	World.travel_to(str(path[1]))
	var hold: Dictionary = World.hold_march(DEST)
	_ok(str(hold.get("dest", "")) == DEST, "hold_march keeps dest")
	var aware: Dictionary = World.seal_aware_travel_preview(DEST)
	_ok(int(hold.get("days", -1)) == int(aware.get("days", -2)), "hold days match aware preview")
	_ok(int(hold.get("food_need", -1)) == int(aware.get("food", -2)), "hold food_need match aware")
	var line := World.march_hold_text()
	_ok(line != "", "march_hold_text non-empty")

func _api_raw_preview_stays_shortest() -> void:
	_setup()
	# Without a recorded detour, compare must still see sealed legs on the raw shortpath.
	var cmp: Dictionary = CKRoadSeal.compare(DEST)
	_ok(bool(cmp.get("sealed", false)), "compare still sees sealed direct (travel_preview unchanged)")
	var bare: Dictionary = World.travel_preview(DEST)
	var aware: Dictionary = World.seal_aware_travel_preview(DEST)
	_ok(bare.get("path", []) == aware.get("path", []), "no detour => aware == raw")
	_ok(not bool(aware.get("seal_bypass", false)), "no detour => no seal_bypass flag")
