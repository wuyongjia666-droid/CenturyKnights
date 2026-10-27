extends Node
## Fat atlas: neutral multi-faction tug → ContestTugModal; seize / watch / resolve E2E.

const ATLAS_SCN := preload("res://scenes/hub/atlas_view.tscn")
const SITE := "t_ash_cinderpit"
var _fails: Array = []

func _ready() -> void:
	await get_tree().process_frame
	_setup()
	_api_start_sets_payload()
	_api_tick_imminent_then_resolve()
	await _ui_contest_modal_watch()
	await _ui_contest_seize_at_anchor()
	if _fails.is_empty():
		print("ATLAS NEUTRAL CONTEST PASS")
		get_tree().quit(0)
	else:
		for f in _fails:
			print("FAIL atlas neutral contest: ", f)
		get_tree().quit(1)

func _ok(cond: bool, msg: String) -> void:
	print("ROW %s %s" % ["PASS" if cond else "FAIL", msg])
	if not cond:
		_fails.append(msg)

func _setup() -> void:
	GameState.new_game("NeutralContest", "AshBanner", GameState.crest_color)
	GameState.set_flag("chapter0_done", true)
	UnlockSchedule.install()
	World.events_enabled = false
	World.rivals_enabled = true
	# Seed two rivals so tug has multiple factions without depending on nation pos.
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
	World.pos = "ash_capital"
	World.travel = {}
	World.pending_event = {}
	World.encounter = {}
	World.active.clear()
	World.cargo.clear()
	World.last_territory_month = {}
	World.last_siege_alert = {}
	World.last_neutral_contest = {}
	World.last_contest_resolve = {}
	CKTerritory.last_month_report = {}

func _reset_site() -> void:
	var st: Dictionary = CKTerritory.state(SITE)
	st.owner = CKTerritory.NEUTRAL
	st.garrison = 0
	st.stockade = false
	st.unrest = 0
	st.threat = {}
	st.contest = {}
	CKTerritory._put(SITE, st)
	World.last_neutral_contest = {}
	World.last_contest_resolve = {}

func _force_factions() -> Array:
	return [
		{"id": "rival:rv_a", "name": "灰烬狼团", "pressure": 3},
		{"id": "rival:rv_b", "name": "盐湾镖旗", "pressure": 2},
	]

func _api_start_sets_payload() -> void:
	_reset_site()
	var c := CKTerritory.start_neutral_contest(SITE, _force_factions())
	_ok(not c.is_empty(), "start_neutral_contest returns contest")
	_ok(not World.last_neutral_contest.is_empty(), "last_neutral_contest set")
	_ok(str(World.last_neutral_contest.get("id", "")) == SITE, "contest site id")
	_ok(str(World.last_neutral_contest.get("phase", "")) == "declared", "phase declared")
	_ok((World.last_neutral_contest.get("factions", []) as Array).size() >= 2, "multi faction")
	var st := CKTerritory.state(SITE)
	_ok(not (st.contest as Dictionary).is_empty(), "state.contest stored")
	var mks: Array = CKTerritory.map_markers(str(CKTerritory.site(SITE).nation))
	var found := false
	for mk in mks:
		if str(mk.get("id", "")) == SITE:
			found = bool(mk.get("contest", false))
	_ok(found, "map_markers contest flag")
	var taken := World.take_neutral_contest()
	_ok(not taken.is_empty(), "take_neutral_contest")
	_ok(World.last_neutral_contest.is_empty(), "cleared after take")

func _api_tick_imminent_then_resolve() -> void:
	_reset_site()
	CKTerritory.start_neutral_contest(SITE, _force_factions())
	World.last_neutral_contest = {}
	CKTerritory.apply_month(0.99)  # force_roll skips new rolls; ticks existing
	var st := CKTerritory.state(SITE)
	_ok(not (st.contest as Dictionary).is_empty(), "contest still open after month 1")
	_ok(int(st.contest.get("months", 0)) == 1, "contest months → 1")
	_ok(not World.last_neutral_contest.is_empty(), "imminent payload set")
	_ok(str(World.last_neutral_contest.get("phase", "")) == "imminent", "phase imminent")
	World.last_neutral_contest = {}
	CKTerritory.apply_month(0.99)
	st = CKTerritory.state(SITE)
	_ok((st.contest as Dictionary).is_empty(), "contest cleared after resolve")
	_ok(str(st.owner).begins_with("rival:"), "rival claimed site")
	_ok(str(st.owner) == "rival:rv_a", "highest pressure wins")

func _ui_contest_modal_watch() -> void:
	_reset_site()
	World.pos = "ash_capital"
	CKTerritory.start_neutral_contest(SITE, _force_factions())
	_ok(not World.last_neutral_contest.is_empty(), "payload primed for modal")
	var page: Node = ATLAS_SCN.instantiate()
	add_child(page)
	for _i in 12:
		await get_tree().process_frame
	var modal: Node = page.find_child("ContestTugModal", true, false)
	if modal == null and page.has_method("_check_neutral_contest"):
		page.call("_check_neutral_contest")
		for _j in 8:
			await get_tree().process_frame
		modal = page.find_child("ContestTugModal", true, false)
	_ok(modal != null, "ContestTugModal shown")
	if modal == null:
		page.queue_free()
		await get_tree().process_frame
		return
	var watch: Button = modal.find_child("ContestWatch", true, false) as Button
	_ok(watch != null, "ContestWatch button")
	if watch != null:
		watch.pressed.emit()
		for _k in 6:
			await get_tree().process_frame
	_ok(page.find_child("ContestTugModal", true, false) == null, "modal closed after watch")
	_ok(World.last_neutral_contest.is_empty(), "payload dismissed on watch")
	_ok(not (CKTerritory.state(SITE).contest as Dictionary).is_empty(), "contest still ticking after watch")
	page.queue_free()
	await get_tree().process_frame

func _ui_contest_seize_at_anchor() -> void:
	_reset_site()
	var anchor := str(CKTerritory.site(SITE).get("anchor", ""))
	World.pos = anchor
	World.arrive(anchor)
	World.encounter = {}
	CKTerritory.start_neutral_contest(SITE, _force_factions())
	var page: Node = ATLAS_SCN.instantiate()
	add_child(page)
	for _i in 12:
		await get_tree().process_frame
	if page.find_child("ContestTugModal", true, false) == null and page.has_method("_check_neutral_contest"):
		if World.last_neutral_contest.is_empty():
			CKTerritory._emit_neutral_contest(SITE)
		page.call("_check_neutral_contest")
		for _j in 8:
			await get_tree().process_frame
	var modal: Node = page.find_child("ContestTugModal", true, false)
	_ok(modal != null, "ContestTugModal at anchor")
	if modal == null:
		page.queue_free()
		await get_tree().process_frame
		return
	var seize: Button = modal.find_child("ContestSeize", true, false) as Button
	_ok(seize != null, "ContestSeize button")
	_ok(seize != null and "强攻" in seize.text, "seize-now label at anchor")
	if seize != null:
		seize.pressed.emit()
		for _k in 10:
			await get_tree().process_frame
	_ok((CKTerritory.state(SITE).contest as Dictionary).is_empty(), "contest cleared on seize")
	_ok(not World.encounter.is_empty() or CKTerritory.owned(SITE), "assault started or captured")
	page.queue_free()
	await get_tree().process_frame
