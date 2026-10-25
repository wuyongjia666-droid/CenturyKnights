extends Node
## Fat atlas: scripted multi-city deliver chain → TurnIn → ChainAdvanceModal → accept/march E2E.

const ATLAS_SCN := preload("res://scenes/hub/atlas_view.tscn")
const CHAIN := "chain_ash"
var _fails: Array = []

func _ready() -> void:
	await get_tree().process_frame
	_setup()
	_api_chain_two_hops()
	await _ui_chain_start_turnin_advance()
	if _fails.is_empty():
		print("ATLAS CHAIN MULTICITY DELIVER PASS")
		get_tree().quit(0)
	else:
		for f in _fails:
			print("FAIL atlas chain multicity: ", f)
		get_tree().quit(1)

func _ok(cond: bool, msg: String) -> void:
	print("ROW %s %s" % ["PASS" if cond else "FAIL", msg])
	if not cond:
		_fails.append(msg)

func _setup() -> void:
	GameState.new_game("多城委托链", "灰旗", GameState.crest_color)
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
	World.last_aftermath.clear()
	World.last_battle_aftermath.clear()

func _api_chain_two_hops() -> void:
	_setup()
	var started: Dictionary = World.start_scripted_chain(CHAIN)
	_ok(bool(started.get("ok", false)), "start chain_ash: %s" % started.get("msg", ""))
	var q0: Dictionary = started.get("quest", {})
	_ok(str(q0.get("scripted_chain", "")) == CHAIN, "quest tagged scripted_chain")
	_ok(str(q0.get("issuer", "")) == "ash_capital", "step0 issuer ash_capital")
	_ok(str(q0.get("target", "")) == "reed_ford", "step0 target reed_ford")
	var acc: Dictionary = World.accept_quest("ash_capital", str(q0.get("id", "")))
	_ok(bool(acc.get("ok", false)), "accept step0: %s" % acc.get("msg", ""))
	var trip: Dictionary = World.travel_to("reed_ford")
	_ok(World.pos == "reed_ford", "arrived reed_ford (%s)" % trip)
	var q := World.quest_by_id(str(q0.get("id", "")))
	_ok(str(q.get("state", "")) == "ready", "step0 ready at target")
	var turned: Dictionary = World.turn_in(str(q0.get("id", "")))
	_ok(bool(turned.get("ok", false)), "turn_in step0: %s" % turned.get("msg", ""))
	_ok(turned.has("follow") and not turned.follow.is_empty(), "turn_in returns follow")
	_ok(not World.last_chain_follow.is_empty(), "last_chain_follow set")
	var follow: Dictionary = turned.get("follow", {})
	_ok(str(follow.get("scripted_chain", "")) == CHAIN, "follow is same chain")
	_ok(int(follow.get("scripted_step", -1)) == 1, "follow is step 1")
	_ok(str(follow.get("issuer", "")) == "reed_ford", "step1 issuer reed_ford")
	_ok(str(follow.get("target", "")) == "stone_slope", "step1 target stone_slope")
	var st: Dictionary = World.chain_status(CHAIN)
	_ok(str(st.get("status", "")) == "active", "chain still active")
	_ok(int(st.get("step", -1)) == 1, "chain_progress step 1")
	var acc1: Dictionary = World.accept_quest("reed_ford", str(follow.get("id", "")))
	_ok(bool(acc1.get("ok", false)), "accept step1: %s" % acc1.get("msg", ""))
	World.travel_to("stone_slope")
	_ok(World.pos == "stone_slope", "arrived stone_slope")
	var q1 := World.quest_by_id(str(follow.get("id", "")))
	_ok(str(q1.get("state", "")) == "ready", "step1 ready")
	var turned1: Dictionary = World.turn_in(str(follow.get("id", "")))
	_ok(bool(turned1.get("ok", false)), "turn_in step1")
	_ok(int(World.chain_status(CHAIN).get("step", -1)) == 2, "advanced to step 2")

func _ui_chain_start_turnin_advance() -> void:
	_setup()
	World.pos = "ash_capital"
	World.arrive("ash_capital")
	var page: Control = ATLAS_SCN.instantiate()
	get_tree().root.add_child(page)
	for _i in 12:
		await get_tree().process_frame
	# Force select current city so ChainStart appears
	if page.has_method("_select_node"):
		page.call("_select_node", "ash_capital")
	for _j in 6:
		await get_tree().process_frame
	var start_btn: Button = page.find_child("ChainStart", true, false) as Button
	_ok(start_btn != null, "ChainStart on ash_capital")
	if start_btn:
		start_btn.pressed.emit()
		for _k in 10:
			await get_tree().process_frame
	_ok(str(World.chain_status(CHAIN).get("status", "")) == "active", "UI start → chain active")
	var qlive: Dictionary = {}
	for q in World.active:
		if str(q.get("scripted_chain", "")) == CHAIN:
			qlive = q
			break
	_ok(not qlive.is_empty(), "chain quest active after ChainStart")
	page.queue_free()
	for _z in 3:
		await get_tree().process_frame
	# Headless march + reopen atlas on turn-in city
	if not qlive.is_empty():
		World.travel_to(str(qlive.get("target", "reed_ford")))
	_ok(World.pos == "reed_ford", "UI path at reed_ford")
	_ok(World.ready_turn_ins_here().size() >= 1, "ready turn-in at reed_ford")
	page = ATLAS_SCN.instantiate()
	get_tree().root.add_child(page)
	for _i2 in 10:
		await get_tree().process_frame
	# Arrival may auto-open TurnInReadyModal; else open via helper
	var tim: Node = page.find_child("TurnInReadyModal", true, false)
	if tim == null and page.has_method("_show_turnin_modal"):
		page.call("_show_turnin_modal", World.ready_turn_ins_here().size())
		for _j2 in 6:
			await get_tree().process_frame
		tim = page.find_child("TurnInReadyModal", true, false)
	_ok(tim != null, "TurnInReadyModal present")
	if tim != null:
		var now: Button = tim.get_node_or_null("TurnInNow") as Button
		_ok(now != null, "TurnInNow")
		if now:
			now.pressed.emit()
			for _m in 12:
				await get_tree().process_frame
	var cam: Node = page.find_child("ChainAdvanceModal", true, false)
	_ok(cam != null, "ChainAdvanceModal after turn-in")
	if cam == null:
		page.queue_free()
		return
	_ok(cam.get_node_or_null("ChainAdvanceBody") != null, "ChainAdvanceBody")
	_ok(cam.get_node_or_null("ChainAccept") != null, "ChainAccept")
	_ok(cam.get_node_or_null("ChainMarch") != null, "ChainMarch")
	_ok(cam.get_node_or_null("ChainLater") != null, "ChainLater")
	var acc: Button = cam.get_node_or_null("ChainAccept") as Button
	if acc:
		acc.pressed.emit()
		for _n in 10:
			await get_tree().process_frame
	_ok(page.find_child("ChainAdvanceModal", true, false) == null, "modal closed after accept")
	var step1_active := false
	for q2 in World.active:
		if str(q2.get("scripted_chain", "")) == CHAIN and int(q2.get("scripted_step", -1)) == 1:
			step1_active = true
	_ok(step1_active, "step1 accepted via ChainAccept")
	page.queue_free()
	for _z2 in 3:
		await get_tree().process_frame
