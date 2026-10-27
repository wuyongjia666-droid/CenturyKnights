extends Node
## Mobile twin: ContestTugModal seize-now on phone profile.

const ATLAS_SCN := preload("res://scenes/hub/atlas_view.tscn")
const SITE := "t_ash_cinderpit"
var _fails: Array = []

func _ready() -> void:
	await get_tree().process_frame
	_setup()
	await _ui_seize_at_anchor()
	if _fails.is_empty():
		print("MOBILE ATLAS NEUTRAL CONTEST PASS")
		get_tree().quit(0)
	else:
		for f in _fails:
			print("FAIL mobile atlas neutral contest: ", f)
		get_tree().quit(1)

func _ok(cond: bool, msg: String) -> void:
	print("ROW %s %s" % ["PASS" if cond else "FAIL", msg])
	if not cond:
		_fails.append(msg)

func _setup() -> void:
	GameState.new_game("MobileNeutralContest", "AshBanner", GameState.crest_color)
	GameState.set_flag("chapter0_done", true)
	UnlockSchedule.install()
	World.events_enabled = false
	World.rivals_enabled = true
	World.rivals = [
		{"id": "rv_a", "name": "灰烬狼团", "pos": "ash_capital", "home": "ash_capital", "stolen": {}, "price_mul": 1.0},
		{"id": "rv_b", "name": "盐湾镖旗", "pos": "ash_capital", "home": "ash_capital", "stolen": {}, "price_mul": 1.0},
	]
	for nid in World.nations.keys():
		World.rep_nation[str(nid)] = 50
	GameState.food = 80
	GameState.silver = 800
	GameState.morale = 80
	World.hub_tour.clear()
	World.pending_event = {}
	World.encounter = {}
	World.travel = {}
	World.last_neutral_contest = {}
	World.last_contest_resolve = {}
	var st: Dictionary = CKTerritory.state(SITE)
	st.owner = CKTerritory.NEUTRAL
	st.garrison = 0
	st.unrest = 0
	st.threat = {}
	st.contest = {}
	CKTerritory._put(SITE, st)
	var anchor := str(CKTerritory.site(SITE).get("anchor", ""))
	World.pos = anchor
	World.arrive(anchor)

func _ui_seize_at_anchor() -> void:
	CKTerritory.start_neutral_contest(SITE, [
		{"id": "rival:rv_a", "name": "灰烬狼团", "pressure": 3},
		{"id": "rival:rv_b", "name": "盐湾镖旗", "pressure": 2},
	])
	var page: Node = ATLAS_SCN.instantiate()
	add_child(page)
	for _i in 14:
		await get_tree().process_frame
	if page.find_child("ContestTugModal", true, false) == null and page.has_method("_check_neutral_contest"):
		page.call("_check_neutral_contest")
		for _j in 8:
			await get_tree().process_frame
	var modal: Node = page.find_child("ContestTugModal", true, false)
	_ok(modal != null, "ContestTugModal on mobile")
	if modal == null:
		page.queue_free()
		return
	var seize: Button = modal.find_child("ContestSeize", true, false) as Button
	_ok(seize != null, "ContestSeize")
	if seize != null:
		seize.pressed.emit()
		for _k in 10:
			await get_tree().process_frame
	_ok((CKTerritory.state(SITE).contest as Dictionary).is_empty(), "contest cleared")
	_ok(not World.encounter.is_empty() or CKTerritory.owned(SITE), "assault or owned")
	page.queue_free()
