extends Node
## Fat atlas: neutral contest settle → ContestResolveModal (won / lost / miss) E2E.

const ATLAS_SCN := preload("res://scenes/hub/atlas_view.tscn")
const SITE := "t_ash_cinderpit"
var _fails: Array = []

func _ready() -> void:
	await get_tree().process_frame
	_api_rival_lost()
	_api_company_won()
	_api_bandit_miss()
	await _ui_resolve_modal_lost()
	await _ui_resolve_modal_won()
	if _fails.is_empty():
		print("ATLAS CONTEST RESOLVE PASS")
		get_tree().quit(0)
	else:
		for f in _fails:
			print("FAIL atlas contest resolve: ", f)
		get_tree().quit(1)

func _ok(cond: bool, msg: String) -> void:
	print("ROW %s %s" % ["PASS" if cond else "FAIL", msg])
	if not cond:
		_fails.append(msg)

func _setup() -> void:
	GameState.new_game("ContestResolve", "AshBanner", GameState.crest_color)
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
	World.pos = "ash_capital"
	World.travel = {}
	World.pending_event = {}
	World.encounter = {}
	World.active.clear()
	World.cargo.clear()
	World.last_territory_month = {}
	World.last_neutral_contest = {}
	World.last_contest_resolve = {}
	CKTerritory.last_month_report = {}
	var st: Dictionary = CKTerritory.state(SITE)
	st.owner = CKTerritory.NEUTRAL
	st.garrison = 0
	st.unrest = 0
	st.threat = {}
	st.contest = {}
	st.stockade = false
	st.cache_food = 0
	CKTerritory._put(SITE, st)

func _force_factions(top_id: String = "rival:rv_a") -> Array:
	if top_id == "company":
		return [
			{"id": "company", "name": "本团", "pressure": 5},
			{"id": "rival:rv_a", "name": "灰烬狼团", "pressure": 3},
		]
	if top_id == "bandit":
		return [
			{"id": "bandit", "name": "流寇", "pressure": 4},
			{"id": "rival:rv_b", "name": "盐湾镖旗", "pressure": 2},
		]
	return [
		{"id": "rival:rv_a", "name": "灰烬狼团", "pressure": 3},
		{"id": "rival:rv_b", "name": "盐湾镖旗", "pressure": 2},
	]

func _api_rival_lost() -> void:
	_setup()
	CKTerritory.start_neutral_contest(SITE, _force_factions("rival:rv_a"))
	World.last_neutral_contest = {"id": SITE, "name": "x"}
	World.last_contest_resolve = {}
	var resolved: Array = CKTerritory.tick_neutral_contests(true)
	_ok(not resolved.is_empty(), "rival resolve non-empty")
	_ok(str(resolved[0].get("winner", "")) == "rival:rv_a", "winner rival")
	_ok(str(World.last_contest_resolve.get("outcome", "")) == "lost", "outcome lost")
	_ok(str(World.last_contest_resolve.get("id", "")) == SITE, "payload site")
	_ok(World.last_neutral_contest.is_empty(), "tug cleared on resolve")
	_ok(str(CKTerritory.owner(SITE)).begins_with("rival:"), "site owned by rival")

func _api_company_won() -> void:
	_setup()
	CKTerritory.start_neutral_contest(SITE, _force_factions("company"))
	World.last_contest_resolve = {}
	var resolved: Array = CKTerritory.tick_neutral_contests(true)
	_ok(not resolved.is_empty(), "company resolve non-empty")
	_ok(bool(resolved[0].get("company_won", false)), "company_won flag")
	_ok(str(World.last_contest_resolve.get("outcome", "")) == "won", "outcome won")
	_ok(CKTerritory.owned(SITE), "site owned by company")
	_ok(int(World.last_contest_resolve.get("garrison", 0)) >= 1, "garrison >= 1")

func _api_bandit_miss() -> void:
	_setup()
	CKTerritory.start_neutral_contest(SITE, _force_factions("bandit"))
	World.last_contest_resolve = {}
	var resolved: Array = CKTerritory.tick_neutral_contests(true)
	_ok(not resolved.is_empty(), "bandit resolve non-empty")
	_ok(str(World.last_contest_resolve.get("outcome", "")) == "miss", "outcome miss")
	_ok(CKTerritory.owner(SITE) == CKTerritory.NEUTRAL, "site still neutral")

func _ui_resolve_modal_lost() -> void:
	_setup()
	CKTerritory.start_neutral_contest(SITE, _force_factions("rival:rv_a"))
	World.last_contest_resolve = {}
	World.last_territory_month = {}
	World.last_siege_loot = {}
	World.last_siege_alert = {}
	World.last_neutral_contest = {}
	CKTerritory.tick_neutral_contests(true)
	_ok(not World.last_contest_resolve.is_empty(), "lost payload ready for UI")
	var atlas: Node = ATLAS_SCN.instantiate()
	add_child(atlas)
	await get_tree().process_frame
	await get_tree().process_frame
	if atlas.has_method("_check_contest_resolve"):
		atlas.call("_check_contest_resolve")
	await get_tree().process_frame
	var panel = atlas.find_child("ContestResolveModal", true, false)
	_ok(panel != null, "ContestResolveModal shown (lost)")
	if panel != null:
		var body: Label = panel.get_node_or_null("ContestResolveBody") as Label
		_ok(body != null and body.text != "", "resolve body non-empty")
		_ok(body != null and ("旁落" in body.text or "lost" in body.text.to_lower() or "灰烬" in body.text),
			"lost body mentions rival: %s" % (body.text if body else ""))
		var ok_btn = panel.get_node_or_null("ContestResolveOk")
		_ok(ok_btn != null, "ContestResolveOk present")
		if ok_btn != null and ok_btn.has_signal("pressed"):
			ok_btn.emit_signal("pressed")
			await get_tree().process_frame
			_ok(atlas.find_child("ContestResolveModal", true, false) == null, "modal cleared after OK")
	atlas.queue_free()
	await get_tree().process_frame

func _ui_resolve_modal_won() -> void:
	_setup()
	CKTerritory.start_neutral_contest(SITE, _force_factions("company"))
	World.last_contest_resolve = {}
	World.last_territory_month = {}
	World.last_siege_loot = {}
	World.last_siege_alert = {}
	World.last_neutral_contest = {}
	CKTerritory.tick_neutral_contests(true)
	_ok(str(World.last_contest_resolve.get("outcome", "")) == "won", "won payload ready")
	var atlas: Node = ATLAS_SCN.instantiate()
	add_child(atlas)
	await get_tree().process_frame
	await get_tree().process_frame
	if atlas.has_method("_check_contest_resolve"):
		atlas.call("_check_contest_resolve")
	await get_tree().process_frame
	var panel = atlas.find_child("ContestResolveModal", true, false)
	_ok(panel != null, "ContestResolveModal shown (won)")
	if panel != null:
		var body: Label = panel.get_node_or_null("ContestResolveBody") as Label
		_ok(body != null and ("得手" in body.text or "won" in body.text.to_lower()),
			"won body: %s" % (body.text if body else ""))
		var ok_btn = panel.get_node_or_null("ContestResolveOk")
		if ok_btn != null and ok_btn.has_signal("pressed"):
			ok_btn.emit_signal("pressed")
			await get_tree().process_frame
	atlas.queue_free()
	await get_tree().process_frame
