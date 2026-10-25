extends Node
## Mobile E2E: chain expire → ChainFailModal → ChainReroute.

const PHONE := Vector2i(2400, 1080)
const ATLAS_SCN := preload("res://scenes/hub/atlas_view.tscn")
const CHAIN := "chain_ash"

func _ready() -> void:
	var err := await _run()
	if err != "":
		print("FAIL mobile atlas chain fail: ", err)
		get_tree().quit(1)
	else:
		print("MOBILE ATLAS CHAIN FAIL REROUTE PASS")
		get_tree().quit(0)

func _run() -> String:
	if not DeviceProfile.is_mobile():
		return "DeviceProfile.is_mobile() false — need CK_FORCE_MOBILE=1"
	await _set_phone_window()
	_boot()
	var started: Dictionary = World.start_scripted_chain(CHAIN)
	if not bool(started.get("ok", false)):
		return "start failed"
	var q0: Dictionary = started.get("quest", {})
	var acc: Dictionary = World.accept_quest("ash_capital", str(q0.get("id", "")))
	if not bool(acc.get("ok", false)):
		return "accept failed"
	for q in World.active:
		if str(q.get("id", "")) == str(q0.get("id", "")):
			q["deadline"] = World.days_total - 1
			break
	World.advance_days(1)
	if str(World.chain_status(CHAIN).get("status", "")) != "failed":
		return "not failed after expire"
	World.arrive("ash_capital")
	var page := await _mount_atlas()
	var modal: Node = page.find_child("ChainFailModal", true, false)
	if modal == null and page.has_method("_check_chain_fail"):
		if World.last_chain_fail.is_empty():
			World.last_chain_fail = {
				"chain_id": CHAIN, "step": 0, "quest_id": str(q0.get("id", "")),
				"title": str(q0.get("title", "")), "issuer": "ash_capital", "target": "reed_ford",
				"reason": "expire", "chain_title": "烬纹三程",
			}
		page.call("_check_chain_fail")
		for _j in 8:
			await get_tree().process_frame
		modal = page.find_child("ChainFailModal", true, false)
	if modal == null:
		page.queue_free()
		return "ChainFailModal missing"
	var rr: Button = modal.get_node_or_null("ChainReroute") as Button
	if rr == null:
		page.queue_free()
		return "ChainReroute missing"
	rr.pressed.emit()
	for _k in 12:
		await get_tree().process_frame
	if str(World.chain_status(CHAIN).get("status", "")) != "active":
		page.queue_free()
		return "reroute did not reactivate"
	page.queue_free()
	return ""

func _boot() -> void:
	GameState.new_game("手机链失败", "灰旗", GameState.crest_color)
	GameState.set_flag("chapter0_done", true)
	UnlockSchedule.install()
	World.events_enabled = false
	World.rivals_enabled = false
	for nid in World.nations.keys():
		World.rep_nation[str(nid)] = 50
	GameState.food = 80
	GameState.silver = 12000
	World.pos = "ash_capital"
	World.travel = {}
	World.pending_event = {}
	World.encounter = {}
	World.active.clear()
	World.chain_progress.clear()
	World.last_chain_fail.clear()
	World.last_chain_follow.clear()

func _set_phone_window() -> void:
	DisplayServer.window_set_size(PHONE)
	get_tree().root.content_scale_size = PHONE
	await get_tree().process_frame

func _mount_atlas() -> Control:
	var page: Control = ATLAS_SCN.instantiate()
	get_tree().root.add_child(page)
	for _i in 14:
		await get_tree().process_frame
	return page
