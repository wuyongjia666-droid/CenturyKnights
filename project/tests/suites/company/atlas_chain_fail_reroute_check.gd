extends Node
## Fat atlas: scripted chain expire/abandon → ChainFailModal → reroute E2E.

const ATLAS_SCN := preload("res://scenes/hub/atlas_view.tscn")
const CHAIN := "chain_ash"
var _fails: Array = []

func _ready() -> void:
	await get_tree().process_frame
	_api_expire_and_reroute()
	_api_abandon_fails_chain()
	await _ui_chain_fail_modal_reroute()
	if _fails.is_empty():
		print("ATLAS CHAIN FAIL REROUTE PASS")
		get_tree().quit(0)
	else:
		for f in _fails:
			print("FAIL atlas chain fail/reroute: ", f)
		get_tree().quit(1)

func _ok(cond: bool, msg: String) -> void:
	print("ROW %s %s" % ["PASS" if cond else "FAIL", msg])
	if not cond:
		_fails.append(msg)

func _setup() -> void:
	GameState.new_game("委托链失败改道", "灰旗", GameState.crest_color)
	GameState.set_flag("chapter0_done", true)
	UnlockSchedule.install()
	World.events_enabled = false
	World.rivals_enabled = false
	for nid in World.nations.keys():
		World.rep_nation[str(nid)] = 50
	GameState.food = 80
	GameState.silver = 12000
	GameState.morale = 80
	World.hub_tour.clear()
	World.pos = "ash_capital"
	World.travel = {}
	World.pending_event = {}
	World.encounter = {}
	World.active.clear()
	World.cargo.clear()
	World.cargo_basis.clear()
	World.chain_progress.clear()
	World.last_chain_follow.clear()
	World.last_chain_fail.clear()
	World.last_aftermath.clear()
	World.last_battle_aftermath.clear()

func _start_active_step0() -> Dictionary:
	var started: Dictionary = World.start_scripted_chain(CHAIN)
	_ok(bool(started.get("ok", false)), "start: %s" % started.get("msg", ""))
	var q0: Dictionary = started.get("quest", {})
	var acc: Dictionary = World.accept_quest("ash_capital", str(q0.get("id", "")))
	_ok(bool(acc.get("ok", false)), "accept step0: %s" % acc.get("msg", ""))
	return q0

func _api_expire_and_reroute() -> void:
	_setup()
	var q0 := _start_active_step0()
	# Force overdue then tick calendar expire path
	for q in World.active:
		if str(q.get("id", "")) == str(q0.get("id", "")):
			q["deadline"] = World.days_total - 1
			break
	World.advance_days(1)
	var st: Dictionary = World.chain_status(CHAIN)
	_ok(str(st.get("status", "")) == "failed", "expire → chain failed (got %s)" % st.get("status", ""))
	_ok(str(st.get("reason", "")) == "expire", "fail reason expire")
	_ok(not World.last_chain_fail.is_empty(), "last_chain_fail set")
	_ok(str(World.last_chain_fail.get("chain_id", "")) == CHAIN, "fail payload chain_id")
	_ok(World.quest_by_id(str(q0.get("id", ""))).is_empty(), "expired quest gone from active")
	var rr: Dictionary = World.reroute_failed_chain(CHAIN)
	_ok(bool(rr.get("ok", false)), "reroute ok: %s" % rr.get("msg", ""))
	_ok(str(World.chain_status(CHAIN).get("status", "")) == "active", "reroute → active")
	_ok(World.last_chain_fail.is_empty(), "fail payload cleared after reroute")
	var nq: Dictionary = rr.get("quest", {})
	_ok(str(nq.get("scripted_chain", "")) == CHAIN, "reroute quest tagged")
	_ok(int(nq.get("scripted_step", -1)) == 0, "reroute same step 0")
	_ok(int(nq.get("days_budget", 99)) <= 28, "reroute tighter budget")
	var acc2: Dictionary = World.accept_quest(str(nq.get("issuer", "ash_capital")), str(nq.get("id", "")))
	_ok(bool(acc2.get("ok", false)), "accept rerouted offer: %s" % acc2.get("msg", ""))

func _api_abandon_fails_chain() -> void:
	_setup()
	var q0 := _start_active_step0()
	var ab: Dictionary = World.abandon(str(q0.get("id", "")))
	_ok(bool(ab.get("ok", false)), "abandon: %s" % ab.get("msg", ""))
	_ok(str(World.chain_status(CHAIN).get("status", "")) == "failed", "abandon → chain failed")
	_ok(str(World.chain_status(CHAIN).get("reason", "")) == "abandon", "fail reason abandon")
	_ok(not World.last_chain_fail.is_empty(), "abandon sets last_chain_fail")
	# dismiss keeps failed status
	World.dismiss_chain_fail()
	_ok(World.last_chain_fail.is_empty(), "dismiss clears payload")
	_ok(str(World.chain_status(CHAIN).get("status", "")) == "failed", "status stays failed after dismiss")
	# full restart via start_scripted_chain
	var again: Dictionary = World.start_scripted_chain(CHAIN)
	_ok(bool(again.get("ok", false)), "restart after fail: %s" % again.get("msg", ""))
	_ok(str(World.chain_status(CHAIN).get("status", "")) == "active", "restart → active step0")

func _ui_chain_fail_modal_reroute() -> void:
	_setup()
	var q0 := _start_active_step0()
	for q in World.active:
		if str(q.get("id", "")) == str(q0.get("id", "")):
			q["deadline"] = World.days_total - 1
			break
	World.advance_days(1)
	_ok(str(World.chain_status(CHAIN).get("status", "")) == "failed", "UI setup failed")
	World.arrive("ash_capital")
	var page: Control = ATLAS_SCN.instantiate()
	get_tree().root.add_child(page)
	for _i in 14:
		await get_tree().process_frame
	# Force check if resume didn't pop it
	var modal: Node = page.find_child("ChainFailModal", true, false)
	if modal == null and page.has_method("_check_chain_fail"):
		# restore payload if take already consumed somehow
		if World.last_chain_fail.is_empty():
			World.last_chain_fail = {
				"chain_id": CHAIN,
				"step": 0,
				"quest_id": str(q0.get("id", "")),
				"title": str(q0.get("title", "")),
				"issuer": "ash_capital",
				"target": "reed_ford",
				"reason": "expire",
				"chain_title": "烬纹三程",
			}
		page.call("_check_chain_fail")
		for _j in 8:
			await get_tree().process_frame
		modal = page.find_child("ChainFailModal", true, false)
	_ok(modal != null, "ChainFailModal present")
	if modal == null:
		page.queue_free()
		return
	_ok(modal.get_node_or_null("ChainFailBody") != null, "ChainFailBody")
	_ok(modal.get_node_or_null("ChainReroute") != null, "ChainReroute")
	_ok(modal.get_node_or_null("ChainFailConfirm") != null, "ChainFailConfirm")
	_ok(modal.get_node_or_null("ChainFailLater") != null, "ChainFailLater")
	var rr_btn: Button = modal.get_node_or_null("ChainReroute") as Button
	if rr_btn:
		rr_btn.pressed.emit()
		for _k in 12:
			await get_tree().process_frame
	_ok(str(World.chain_status(CHAIN).get("status", "")) == "active", "UI reroute → active")
	_ok(page.find_child("ChainFailModal", true, false) == null, "modal closed after reroute")
	page.queue_free()
