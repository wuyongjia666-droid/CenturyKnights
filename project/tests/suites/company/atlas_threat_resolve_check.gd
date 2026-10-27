extends Node
## Fat atlas: unanswered threat settle → ThreatResolveModal (held / lost) E2E.

const ATLAS_SCN := preload("res://scenes/hub/atlas_view.tscn")
const SITE := "t_ash_cinderpit"
var _fails: Array = []

func _ready() -> void:
	await get_tree().process_frame
	_api_held()
	_api_lost()
	_api_start_clears_stale()
	await _ui_resolve_modal_held()
	await _ui_resolve_modal_lost()
	if _fails.is_empty():
		print("ATLAS THREAT RESOLVE PASS")
		get_tree().quit(0)
	else:
		for f in _fails:
			print("FAIL atlas threat resolve: ", f)
		get_tree().quit(1)

func _ok(cond: bool, msg: String) -> void:
	print("ROW %s %s" % ["PASS" if cond else "FAIL", msg])
	if not cond:
		_fails.append(msg)

func _setup() -> void:
	GameState.new_game("ThreatResolve", "AshBanner", GameState.crest_color)
	GameState.set_flag("chapter0_done", true)
	UnlockSchedule.install()
	World.events_enabled = false
	World.rivals_enabled = true
	World.rivals = [
		{"id": "rv_a", "name": "灰烬狼团", "pos": "ash_capital", "home": "ash_capital", "stolen": {}, "price_mul": 1.0},
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
	World.last_siege_loot = {}
	World.last_neutral_contest = {}
	World.last_contest_resolve = {}
	World.last_threat_resolve = {}
	CKTerritory.last_month_report = {}
	CKTerritory.take_news()

func _own(garrison: int = 2) -> void:
	_setup()
	var st: Dictionary = CKTerritory.state(SITE)
	st.owner = CKTerritory.NEUTRAL
	st.garrison = 0
	st.stockade = false
	st.unrest = 0
	st.threat = {}
	st.contest = {}
	st.cache_food = 0
	CKTerritory._put(SITE, st)
	var anchor := str(CKTerritory.site(SITE).get("anchor", ""))
	World.pos = anchor
	World.arrive(anchor)
	CKTerritory.capture(SITE, "chain")
	st = CKTerritory.state(SITE)
	st.garrison = garrison
	st.stockade = false
	st.cache_food = 0
	st.threat = {}
	CKTerritory._put(SITE, st)
	World.last_siege_alert = {}
	World.last_siege_loot = {}
	World.last_threat_resolve = {}
	_ok(CKTerritory.owned(SITE), "owned site ready")

func _arm_threat_months() -> void:
	var th := CKTerritory.start_threat(SITE)
	_ok(not th.is_empty(), "start_threat ok")
	var st := CKTerritory.state(SITE)
	st.threat["months"] = 1
	CKTerritory._put(SITE, st)
	World.last_siege_loot = {}
	World.last_threat_resolve = {}
	World.last_territory_month = {}

func _api_held() -> void:
	_own(2)
	_arm_threat_months()
	var g_before := int(CKTerritory.state(SITE).garrison)
	CKTerritory.apply_month(0.0)
	_ok(CKTerritory.owned(SITE), "held site")
	_ok(str(World.last_threat_resolve.get("outcome", "")) == "held", "outcome held")
	_ok(str(World.last_threat_resolve.get("id", "")) == SITE, "payload site")
	_ok(int(World.last_threat_resolve.get("garrison_before", -1)) == g_before, "garrison_before")
	_ok(int(World.last_threat_resolve.get("garrison_after", -1)) == g_before - 1, "garrison_after -1")
	_ok((CKTerritory.state(SITE).threat as Dictionary).is_empty(), "threat cleared")
	_ok(World.last_siege_loot.is_empty(), "no siege loot without cache")

func _api_lost() -> void:
	_own(0)
	_arm_threat_months()
	CKTerritory.apply_month(0.99)
	_ok(not CKTerritory.owned(SITE), "site lost")
	_ok(str(World.last_threat_resolve.get("outcome", "")) == "lost", "outcome lost")
	_ok(str(World.last_threat_resolve.get("id", "")) == SITE, "lost payload site")
	_ok(World.last_siege_loot.is_empty(), "no siege loot without cache on lose")

func _api_start_clears_stale() -> void:
	_own(2)
	World.mark_threat_resolve({"id": SITE, "name": "x", "outcome": "held"})
	_ok(not World.last_threat_resolve.is_empty(), "stale resolve planted")
	CKTerritory.start_threat(SITE)
	_ok(World.last_threat_resolve.is_empty(), "start_threat clears same-id resolve")

func _clear_overlay_noise() -> void:
	World.last_territory_month = {}
	World.last_siege_alert = {}
	World.last_siege_loot = {}
	World.last_neutral_contest = {}
	World.last_contest_resolve = {}
	CKTerritory.take_news()
	CKTerritory.last_month_report = {}

func _ui_resolve_modal_held() -> void:
	_own(2)
	_arm_threat_months()
	CKTerritory.apply_month(0.0)
	_ok(str(World.last_threat_resolve.get("outcome", "")) == "held", "held payload ready for UI")
	_clear_overlay_noise()
	var atlas: Node = ATLAS_SCN.instantiate()
	add_child(atlas)
	await get_tree().process_frame
	await get_tree().process_frame
	if atlas.has_method("_check_threat_resolve"):
		atlas.call("_check_threat_resolve")
	await get_tree().process_frame
	var panel = atlas.find_child("ThreatResolveModal", true, false)
	_ok(panel != null, "ThreatResolveModal shown (held)")
	if panel != null:
		var body: Label = panel.get_node_or_null("ThreatResolveBody") as Label
		_ok(body != null and body.text != "", "held body non-empty")
		_ok(body != null and ("守" in body.text or "held" in body.text.to_lower() or "garrison" in body.text.to_lower()),
			"held body: %s" % (body.text if body else ""))
		var ok_btn = panel.get_node_or_null("ThreatResolveOk")
		_ok(ok_btn != null, "ThreatResolveOk present")
		if ok_btn != null and ok_btn.has_signal("pressed"):
			ok_btn.emit_signal("pressed")
			await get_tree().process_frame
			_ok(atlas.find_child("ThreatResolveModal", true, false) == null, "modal cleared after OK")
	atlas.queue_free()
	await get_tree().process_frame

func _ui_resolve_modal_lost() -> void:
	_own(0)
	_arm_threat_months()
	CKTerritory.apply_month(0.99)
	_ok(str(World.last_threat_resolve.get("outcome", "")) == "lost", "lost payload ready")
	_clear_overlay_noise()
	var atlas: Node = ATLAS_SCN.instantiate()
	add_child(atlas)
	await get_tree().process_frame
	await get_tree().process_frame
	if atlas.has_method("_check_threat_resolve"):
		atlas.call("_check_threat_resolve")
	await get_tree().process_frame
	var panel = atlas.find_child("ThreatResolveModal", true, false)
	_ok(panel != null, "ThreatResolveModal shown (lost)")
	if panel != null:
		var body: Label = panel.get_node_or_null("ThreatResolveBody") as Label
		_ok(body != null and ("易主" in body.text or "lost" in body.text.to_lower() or "took" in body.text.to_lower()),
			"lost body: %s" % (body.text if body else ""))
		var ok_btn = panel.get_node_or_null("ThreatResolveOk")
		if ok_btn != null and ok_btn.has_signal("pressed"):
			ok_btn.emit_signal("pressed")
			await get_tree().process_frame
	atlas.queue_free()
	await get_tree().process_frame
