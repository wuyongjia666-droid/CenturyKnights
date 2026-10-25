extends Node
## Mobile E2E: ChainStart → march → TurnInNow → ChainAdvanceModal.

const PHONE := Vector2i(2400, 1080)
const ATLAS_SCN := preload("res://scenes/hub/atlas_view.tscn")
const CHAIN := "chain_ash"

func _ready() -> void:
	var err := await _run()
	if err != "":
		print("FAIL mobile atlas chain: ", err)
		get_tree().quit(1)
	else:
		print("MOBILE ATLAS CHAIN MULTICITY DELIVER PASS")
		get_tree().quit(0)

func _run() -> String:
	if not DeviceProfile.is_mobile():
		return "DeviceProfile.is_mobile() false — need CK_FORCE_MOBILE=1"
	await _set_phone_window()
	_boot()
	var page := await _mount_atlas()
	if page.has_method("_select_node"):
		page.call("_select_node", "ash_capital")
	if page.has_method("_m_actions"):
		page.call("_m_actions")
	for _j in 6:
		await get_tree().process_frame
	var start_btn: Button = page.find_child("ChainStart", true, false) as Button
	if start_btn == null:
		page.queue_free()
		return "ChainStart missing"
	start_btn.pressed.emit()
	for _k in 10:
		await get_tree().process_frame
	if str(World.chain_status(CHAIN).get("status", "")) != "active":
		page.queue_free()
		return "chain not active after ChainStart"
	var target := "reed_ford"
	for q in World.active:
		if str(q.get("scripted_chain", "")) == CHAIN:
			target = str(q.get("target", "reed_ford"))
			break
	page.queue_free()
	for _z in 3:
		await get_tree().process_frame
	World.travel_to(target)
	if World.pos != target:
		return "travel stopped at %s" % World.pos
	if World.ready_turn_ins_here().is_empty():
		return "no ready turn-in at %s" % target
	page = await _mount_atlas()
	var tim: Node = page.find_child("TurnInReadyModal", true, false)
	if tim == null and page.has_method("_show_turnin_modal"):
		page.call("_show_turnin_modal", World.ready_turn_ins_here().size())
		for _j2 in 6:
			await get_tree().process_frame
		tim = page.find_child("TurnInReadyModal", true, false)
	if tim == null:
		page.queue_free()
		return "TurnInReadyModal missing"
	var now: Button = tim.get_node_or_null("TurnInNow") as Button
	if now == null:
		page.queue_free()
		return "TurnInNow missing"
	now.pressed.emit()
	for _m in 14:
		await get_tree().process_frame
	var cam: Node = page.find_child("ChainAdvanceModal", true, false)
	if cam == null:
		page.queue_free()
		return "ChainAdvanceModal missing"
	if cam.get_node_or_null("ChainAccept") == null:
		page.queue_free()
		return "ChainAccept missing"
	var later: Button = cam.get_node_or_null("ChainLater") as Button
	if later == null:
		page.queue_free()
		return "ChainLater missing"
	later.pressed.emit()
	for _n in 6:
		await get_tree().process_frame
	if page.find_child("ChainAdvanceModal", true, false) != null:
		page.queue_free()
		return "ChainAdvanceModal still open"
	page.queue_free()
	for _z2 in 3:
		await get_tree().process_frame
	return ""

func _boot() -> void:
	GameState.new_game("手机多城链", "灰旗", GameState.crest_color)
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

func _set_phone_window() -> void:
	DisplayServer.window_set_size(PHONE)
	for _i in 4:
		await get_tree().process_frame

func _mount_atlas() -> Control:
	var page: Control = ATLAS_SCN.instantiate()
	get_tree().root.add_child(page)
	for _i in 12:
		await get_tree().process_frame
	if page.has_method("apply_mobile_layout"):
		page.call("apply_mobile_layout")
		for _j in 4:
			await get_tree().process_frame
	return page
