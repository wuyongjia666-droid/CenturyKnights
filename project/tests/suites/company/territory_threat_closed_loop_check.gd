extends Node
## Territory fat closed-loop: threat → castle HubTodo → SiegeAlert → bribe/scout
## → hourglass EchoLine + ToSiegeThreat → unanswered settle month_echo.threat_held
## → chip clear. One knife; not chip/echo/modal slices.

const CASTLE_SCN := preload("res://scenes/hub/castle_hub.tscn")
const ATLAS_SCN := preload("res://scenes/hub/atlas_view.tscn")
const HOURGLASS_SCN := preload("res://scenes/hub/hourglass.tscn")
const Todo := preload("res://scripts/ui/widgets/todo_center.gd")
const SITE := "t_ash_cinderpit"
const MARKER := "TERRITORY THREAT CLOSED LOOP PASS"


func _ready() -> void:
	var err := await _run()
	if err != "":
		print("FAIL territory threat closed loop: ", err)
		get_tree().quit(1)
	else:
		print(MARKER)
		get_tree().quit(0)


func _run() -> String:
	await get_tree().process_frame
	var err := _api_settle_echo()
	if err != "":
		return err
	err = await _ui_castle_siege_bribe_hourglass()
	if err != "":
		return err
	err = await _ui_hourglass_to_siege_then_settle()
	if err != "":
		return err
	return ""


func _setup() -> void:
	GameState.new_game("属地威胁整链", "灰旗", GameState.crest_color)
	GameState.chapter0_flags["chapter0_done"] = true
	GameState.chapter0_flags["ch0_playing"] = false
	UnlockSchedule.install()
	World.events_enabled = false
	World.rivals_enabled = false
	for nid in World.nations.keys():
		World.rep_nation[str(nid)] = 50
	GameState.silver = 9000
	GameState.food = 80
	GameState.morale = 80
	World.travel = {}
	World.pending_event = {}
	World.encounter = {}
	World.last_siege_alert = {}
	World.last_threat_resolve = {}
	World.last_siege_loot = {}
	World.last_territory_month = {}
	CKTerritory.last_month_report = {}
	GameState.house_mods.erase("month_echo")
	Todo.reset_for_tests()


func _reset(id: String) -> void:
	var st: Dictionary = CKTerritory.state(id)
	st.owner = CKTerritory.NEUTRAL
	st.garrison = 0
	st.stockade = false
	st.unrest = 0
	st.threat = {}
	st.cache_food = 0
	CKTerritory._put(id, st)


func _own_threatened(id: String) -> void:
	_reset(id)
	var anchor := str(CKTerritory.site(id).get("anchor", ""))
	World.pos = anchor
	World.arrive(anchor)
	CKTerritory.capture(id, "chain")
	var st := CKTerritory.state(id)
	st.garrison = 4
	st.stockade = true
	st.cache_food = 4
	st.threat = {}
	CKTerritory._put(id, st)
	World.last_siege_alert = {}
	CKTerritory.start_threat(id)


func _has_todo_threat() -> bool:
	for item in Todo.snapshot():
		if str(item.get("category", "")) == "territory_threat" and int(item.get("count", 0)) > 0:
			return true
	return false


func _api_settle_echo() -> String:
	_setup()
	_own_threatened(SITE)
	GameState.house_mods.erase("month_echo")
	# force held
	CKTerritory._resolve_unanswered(SITE, 0.0)
	if not (CKTerritory.state(SITE).threat as Dictionary).is_empty():
		return "api held: threat still set"
	var echo := str(CKEconomyState.month_echo_snapshot().get("threat_held", ""))
	if echo == "":
		return "api held: missing month_echo.threat_held"
	if _has_todo_threat():
		return "api held: todo chip still on"
	# lost path
	_setup()
	_own_threatened(SITE)
	GameState.house_mods.erase("month_echo")
	CKTerritory._resolve_unanswered(SITE, 1.0)
	if CKTerritory.owned(SITE):
		return "api lost: still owned"
	var lost := str(CKEconomyState.month_echo_snapshot().get("threat_lost", ""))
	if lost == "":
		return "api lost: missing month_echo.threat_lost"
	print("api settle echo ok held=%s lost=%s" % [echo, lost])
	return ""


func _ui_castle_siege_bribe_hourglass() -> String:
	_setup()
	_own_threatened(SITE)
	World.take_siege_alert()
	# castle chip
	var castle: Node = CASTLE_SCN.instantiate()
	add_child(castle)
	for _i in 16:
		await get_tree().process_frame
	var chip: Node = castle.find_child("Todo_territory_threat", true, false)
	if chip == null:
		castle.queue_free()
		return "castle Todo_territory_threat missing"
	var snap_ok := false
	for item in Todo.snapshot():
		if str(item.get("category", "")) == "territory_threat":
			if str(item.get("severity", "")) != "block":
				castle.queue_free()
				return "territory_threat severity want block"
			snap_ok = true
			Todo.prepare_nav(item)
			break
	if not snap_ok:
		castle.queue_free()
		return "snapshot missing territory_threat"
	castle.queue_free()
	for _j in 4:
		await get_tree().process_frame
	# siege bribe
	var atlas: Control = ATLAS_SCN.instantiate()
	get_tree().root.add_child(atlas)
	for _i in 8:
		await get_tree().process_frame
	if atlas.has_method("_check_siege_alert"):
		atlas.call("_check_siege_alert")
	for _j in 8:
		await get_tree().process_frame
	var panel := atlas.find_child("SiegeAlertModal", true, false) as Control
	if panel == null:
		atlas.queue_free()
		return "SiegeAlertModal missing after chip"
	var bribe := panel.find_child("SiegeBribe", true, false) as Button
	if bribe == null or bribe.disabled:
		atlas.queue_free()
		return "SiegeBribe missing"
	bribe.pressed.emit()
	for _k in 10:
		await get_tree().process_frame
	if str(CKEconomyState.month_echo_snapshot().get("bribe", "")) == "":
		atlas.queue_free()
		return "bribe echo missing"
	if panel.find_child("EchoLine_bribe", true, false) == null:
		atlas.queue_free()
		return "EchoLine_bribe missing on modal"
	atlas.queue_free()
	await get_tree().process_frame
	# hourglass: EchoLine_bribe + ThreatPending (threat still on after bribe)
	var hg: Control = HOURGLASS_SCN.instantiate()
	get_tree().root.add_child(hg)
	for _i in 12:
		await get_tree().process_frame
	if hg.find_child("EchoLine_bribe", true, false) == null:
		hg.queue_free()
		return "hourglass EchoLine_bribe missing"
	if hg.find_child("ThreatPending", true, false) == null:
		hg.queue_free()
		return "hourglass ThreatPending missing after bribe"
	if hg.find_child("ToSiegeThreat", true, false) == null:
		hg.queue_free()
		return "hourglass ToSiegeThreat missing"
	if not _has_todo_threat():
		hg.queue_free()
		return "todo should remain after bribe (delay only)"
	hg.queue_free()
	await get_tree().process_frame
	print("ui castle→siege→bribe→hourglass ok")
	return ""


func _ui_hourglass_to_siege_then_settle() -> String:
	_setup()
	_own_threatened(SITE)
	World.take_siege_alert()
	GameState.house_mods.erase("month_echo")
	var hg: Control = HOURGLASS_SCN.instantiate()
	get_tree().root.add_child(hg)
	for _i in 12:
		await get_tree().process_frame
	var go := hg.find_child("ToSiegeThreat", true, false) as BaseButton
	if go == null:
		hg.queue_free()
		return "ToSiegeThreat missing on fresh threat"
	# prepare alert then open atlas (button also does this; call API to assert)
	if CKTerritory.hub_requeue_siege_alert() != SITE:
		hg.queue_free()
		return "hub_requeue from hourglass path failed"
	hg.queue_free()
	await get_tree().process_frame
	var atlas: Control = ATLAS_SCN.instantiate()
	get_tree().root.add_child(atlas)
	for _i in 8:
		await get_tree().process_frame
	if atlas.has_method("_check_siege_alert"):
		atlas.call("_check_siege_alert")
	for _j in 8:
		await get_tree().process_frame
	if atlas.find_child("SiegeAlertModal", true, false) == null:
		atlas.queue_free()
		return "SiegeAlertModal missing from hourglass deep-link"
	atlas.queue_free()
	await get_tree().process_frame
	# settle held → echo + chip clear + hourglass EchoLine_threat_held, no ThreatPending
	CKTerritory._resolve_unanswered(SITE, 0.0)
	if _has_todo_threat():
		return "todo still on after settle"
	if str(CKEconomyState.month_echo_snapshot().get("threat_held", "")) == "":
		return "settle missing threat_held echo"
	hg = HOURGLASS_SCN.instantiate()
	get_tree().root.add_child(hg)
	for _i in 12:
		await get_tree().process_frame
	if hg.find_child("EchoLine_threat_held", true, false) == null:
		hg.queue_free()
		return "hourglass EchoLine_threat_held missing"
	if hg.find_child("ThreatPending", true, false) != null:
		hg.queue_free()
		return "ThreatPending should clear after settle"
	hg.queue_free()
	print("ui hourglass→siege→settle→echo ok")
	return ""
