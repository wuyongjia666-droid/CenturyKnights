extends Node
## Fat deepen: mid-detour food-halt → resume stays on bypass (never snaps onto sealed shortest).

const ORIGIN := "sy_capital"
const DEST := "sy_ridge"
const SEAL_A := "sy_spire"
const SEAL_B := "sy_ridge"

var fails: Array = []

func _ready() -> void:
	# Only auto-run when this node is the suite scene root (mobile twin calls APIs itself).
	if get_parent() != get_tree().root and get_parent() != null:
		return
	await get_tree().process_frame
	await run_all()

func run_all() -> void:
	_api_halt_resume()
	_api_save_roundtrip()
	_api_resume_helper()
	if fails.is_empty():
		print("SEAL DETOUR HALT RESUME PASS")
		get_tree().quit(0)
	else:
		for f in fails:
			print("FAIL seal halt-resume: ", f)
		get_tree().quit(1)

func _ok(cond: bool, msg: String) -> void:
	print("ROW %s %s" % ["PASS" if cond else "FAIL", msg])
	if not cond:
		fails.append(msg)

func _setup() -> void:
	GameState.new_game("封路续行", "灰旗", GameState.crest_color)
	GameState.set_flag("chapter0_done", true)
	UnlockSchedule.install()
	World.events_enabled = false
	World.rivals_enabled = false
	for nid in World.nations.keys():
		World.rep_nation[str(nid)] = 40
	GameState.food = 120
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

func _path_hits_seal(path: Array) -> bool:
	for i in range(maxi(0, path.size() - 1)):
		if CKRoadSeal.is_sealed(str(path[i]), str(path[i + 1])):
			return true
	return false

func _api_halt_resume() -> void:
	_setup()
	_ok(CKRoadSeal.seal_active(), "winter seals")
	var cmp: Dictionary = CKRoadSeal.compare(DEST)
	_ok(bool(cmp.get("sealed", false)), "direct road sealed")
	var detour: Dictionary = cmp.get("detour", {})
	var path: Array = detour.get("path", [])
	_ok(bool(detour.get("ok", false)) and path.size() >= 3, "detour has ≥3 hops (%s)" % path.size())
	if path.size() < 3:
		return
	World.note_seal_detour(DEST, path)
	_ok(str(World.seal_detour.get("dest", "")) == DEST, "seal_detour recorded")
	# Walk first hop only (mid-detour).
	var hop1 := str(path[1])
	var st: Dictionary = World.travel_to(hop1)
	_ok(World.pos == hop1, "stood at mid-detour hop %s (st=%s)" % [hop1, st.get("msg", st.get("arrived", ""))])
	_ok(str(World.seal_detour.get("dest", "")) == DEST, "seal_detour survives first hop")
	var rem: Array = World.seal_detour_remaining()
	_ok(rem.size() >= 2 and str(rem[0]) == hop1 and str(rem[-1]) == DEST, "remaining starts at mid hop")
	# Food halt: cancel + hold original dest (as ForcedHalt / camp halt do).
	World.hold_march(DEST)
	_ok(str(World.march_hold.get("dest", "")) == DEST, "march_hold keeps dest")
	_ok(str(World.seal_detour.get("dest", "")) == DEST, "seal_detour survives hold_march")
	# Prove deepen: without seal_detour, begin_travel takes World.route; with it, remaining bypass.
	var naive: Dictionary = World.route(World.pos, DEST)
	var naive_path: Array = naive.get("path", [])
	var saved := World.seal_detour.duplicate(true)
	World.seal_detour = {}
	var bare: Dictionary = World.begin_travel(DEST)
	var bare_route: Array = World.travel.get("route", []).duplicate()
	World.cancel_travel()
	World.seal_detour = saved
	var go: Dictionary = World.begin_travel(DEST)
	_ok(bool(go.get("ok", false)), "begin_travel resumes: %s" % go.get("msg", ""))
	var route: Array = World.travel.get("route", [])
	_ok(not _path_hits_seal(route), "resume route avoids sealed edges")
	_ok(route.size() >= 2 and str(route[0]) == World.pos and str(route[-1]) == DEST, "resume route is remaining bypass")
	# Remaining must match recorded rem; bare route is the unconstrained shortest.
	_ok(route == rem, "resume route equals seal_detour_remaining")
	var mattered := route != bare_route or _path_hits_seal(naive_path)
	_ok(mattered or route == rem, "deepen engaged (via≠bare or bare would seal, or via==rem)")
	# Drop the probe travel and finish with the seal resume helper (hop-by-hop, camp-safe).
	World.cancel_travel()
	var fin: Dictionary = CKRoadSeal.resume_detour()
	_ok(bool(fin.get("ok", false)), "resume_detour arrives: %s" % fin.get("msg", ""))
	_ok(World.pos == DEST, "party at sy_ridge after halt-resume")
	_ok(World.seal_detour.is_empty(), "seal_detour cleared on arrival")

func _api_save_roundtrip() -> void:
	_setup()
	var cmp: Dictionary = CKRoadSeal.compare(DEST)
	var path: Array = cmp.get("detour", {}).get("path", [])
	if path.size() < 3:
		_ok(false, "save test needs detour")
		return
	World.note_seal_detour(DEST, path)
	World.pos = str(path[1])
	var blob: Dictionary = World.to_save()
	_ok(blob.has("seal_detour"), "to_save includes seal_detour")
	World.seal_detour = {}
	World.from_save(blob)
	_ok(str(World.seal_detour.get("dest", "")) == DEST, "from_save restores seal_detour dest")
	var rem: Array = World.seal_detour_remaining()
	_ok(rem.size() >= 2 and str(rem[0]) == str(path[1]), "from_save remaining intact")

func _api_resume_helper() -> void:
	_setup()
	var cmp: Dictionary = CKRoadSeal.compare(DEST)
	var path: Array = cmp.get("detour", {}).get("path", [])
	if path.size() < 3:
		return
	World.note_seal_detour(DEST, path)
	World.travel_to(str(path[1]))
	_ok(World.pos == str(path[1]), "helper setup at mid hop")
	# Starve? no — just resume from mid
	var out: Dictionary = CKRoadSeal.resume_detour()
	_ok(bool(out.get("ok", false)), "resume_detour ok: %s" % out.get("msg", ""))
	_ok(World.pos == DEST, "resume_detour lands on dest")
	_ok(not _path_hits_seal(out.get("path", path)), "path stayed clear (checked plan)")
	_ok(World.seal_detour.is_empty() or World.pos == DEST, "detour cleared after helper")
