extends Node
## Mobile E2E: SiegeAlertModal + SiegeBribe. Named mobile_* → CK_FORCE_MOBILE=1.

const PHONE := Vector2i(2400, 1080)
const ATLAS_SCN := preload("res://scenes/hub/atlas_view.tscn")
const SITE := "t_ash_cinderpit"

func _ready() -> void:
	var err := await _run()
	if err != "":
		print("FAIL mobile atlas siege alert: ", err)
		get_tree().quit(1)
	else:
		print("MOBILE ATLAS SIEGE ALERT PASS")
		get_tree().quit(0)

func _run() -> String:
	if not DeviceProfile.is_mobile():
		return "DeviceProfile.is_mobile() false — need CK_FORCE_MOBILE=1"
	await _set_phone_window()
	_boot()
	var anchor := str(CKTerritory.site(SITE).get("anchor", ""))
	World.pos = anchor
	World.arrive(anchor)
	CKTerritory.capture(SITE, "chain")
	var st := CKTerritory.state(SITE)
	st.garrison = 2
	st.threat = {}
	CKTerritory._put(SITE, st)
	World.last_siege_alert = {}
	CKTerritory.start_threat(SITE)
	if World.last_siege_alert.is_empty():
		CKTerritory._emit_siege_alert(SITE, "declared")
	var page := await _mount_atlas()
	var modal: Node = page.find_child("SiegeAlertModal", true, false)
	if modal == null and page.has_method("_check_siege_alert"):
		page.call("_check_siege_alert")
		for _j in 8:
			await get_tree().process_frame
		modal = page.find_child("SiegeAlertModal", true, false)
	if modal == null:
		page.queue_free()
		return "SiegeAlertModal missing"
	var bribe: Button = modal.get_node_or_null("SiegeBribe") as Button
	if bribe == null:
		page.queue_free()
		return "SiegeBribe missing"
	bribe.pressed.emit()
	for _k in 8:
		await get_tree().process_frame
	modal = page.find_child("SiegeAlertModal", true, false)
	if modal == null:
		page.queue_free()
		return "modal closed after bribe (want EchoLine)"
	if modal.find_child("EchoLine_bribe", true, false) == null:
		page.queue_free()
		return "EchoLine_bribe missing after bribe"
	if not bool(CKTerritory.state(SITE).threat.get("bribed", false)):
		page.queue_free()
		return "threat not bribed"
	page.queue_free()
	return ""

func _boot() -> void:
	GameState.new_game("SiegeAlertMob", "AshBanner", GameState.crest_color)
	GameState.set_flag("chapter0_done", true)
	UnlockSchedule.install()
	World.events_enabled = false
	World.rivals_enabled = false
	GameState.food = 60
	GameState.silver = 600
	World.pos = "ash_capital"
	World.travel = {}
	World.pending_event = {}
	World.encounter = {}
	World.last_territory_month = {}
	World.last_siege_alert = {}

func _mount_atlas() -> Node:
	var page: Node = ATLAS_SCN.instantiate()
	add_child(page)
	for _i in 12:
		await get_tree().process_frame
	return page

func _set_phone_window() -> void:
	DisplayServer.window_set_size(PHONE)
	await get_tree().process_frame
