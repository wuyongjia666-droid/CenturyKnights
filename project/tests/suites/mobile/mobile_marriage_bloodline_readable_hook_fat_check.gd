extends Node
## Mobile twin fat #6: BloodKinHook + BannerHandoff ToDeploy under CK_FORCE_MOBILE.

const LINEAGE_SCN := "res://scenes/hub/lineage_view.tscn"
const CASTLE_SCN := "res://scenes/hub/castle_hub.tscn"
const MARKER := "MOBILE MARRIAGE BLOODLINE READABLE HOOK FAT PASS"
const PHONE := Vector2i(2400, 1080)


func _ready() -> void:
	OS.set_environment("CK_FORCE_MOBILE", "1")
	var err := await _run()
	OS.set_environment("CK_FORCE_MOBILE", "")
	if err != "":
		print("FAIL mobile marriage bloodline readable hook fat: ", err)
		get_tree().quit(1)
		return
	print(MARKER)
	get_tree().quit(0)


func _run() -> String:
	if not DeviceProfile.is_mobile():
		return "DeviceProfile.is_mobile() false — need CK_FORCE_MOBILE=1"
	DisplayServer.window_set_size(PHONE)
	await _settle(2)
	var err := await _ui_blood_kin_hook()
	if err != "":
		return err
	err = await _ui_handoff_board()
	if err != "":
		return err
	return ""


func _settle(n: int = 6) -> void:
	for _i in n:
		await get_tree().process_frame


func _boot(tag: String) -> void:
	GameState.new_game(tag, "灰旗", GameState.crest_color)
	GameState.chapter0_flags["chapter0_done"] = true
	GameState.chapter0_flags["ch0_playing"] = false
	GameState.house_mods.erase("month_echo")
	GameState.house_mods.erase("banner_handoff")
	UnlockSchedule.install()
	World.events_enabled = false
	World.rivals_enabled = false
	GameState.silver = maxi(int(GameState.silver), 400)
	GameState.add_rep("ashland", 80)


func _ui_blood_kin_hook() -> String:
	_boot("手游血脉钩")
	CKEconomyState.month_echo_note("pregnancy", Locale.t("lb_echo_pregnancy", ["测妻"]))
	CKEconomyState.month_echo_note("birth", Locale.t("lb_echo_birth", ["测妻", "测嗣"]))
	if not Lineage.is_blood_kin_pending():
		return "blood kin not pending after stamp"
	var page: Control = (load(LINEAGE_SCN) as PackedScene).instantiate()
	page.set_anchors_preset(Control.PRESET_TOP_LEFT)
	page.position = Vector2.ZERO
	page.size = Vector2(PHONE)
	get_tree().root.add_child(page)
	if page.has_method("apply_mobile_layout"):
		page.apply_mobile_layout()
	await _settle(14)
	var panel := page.find_child("BloodKinHookPanel", true, false)
	if panel == null:
		page.queue_free()
		return "mobile genealogy missing BloodKinHookPanel"
	if page.find_child("BloodKinLine_birth", true, false) == null:
		page.queue_free()
		return "mobile missing BloodKinLine_birth"
	page.queue_free()
	await _settle(2)
	print("mobile blood kin hook ok")
	return ""


func _ui_handoff_board() -> String:
	_boot("手游承旗板")
	var lead: CKCharacter = GameState.get_leader()
	lead.age = 48
	var heir := CKCharacter.new()
	heir.id = "m_hook_heir"
	heir.name = "手游承旗嗣"
	heir.age = 19
	heir.gender = "m"
	heir.alive = true
	heir.in_roster = true
	heir.rank = "knight"
	heir.family_id = str(lead.family_id)
	heir.parent_ids = [str(lead.id)]
	GameState.characters[heir.id] = heir
	if not heir.id in lead.children_ids:
		lead.children_ids.append(heir.id)
	var rr: Dictionary = Lineage.transfer_banner("abdicate")
	if not bool(rr.get("ok", false)):
		return "mobile transfer_banner: %s" % str(rr.get("msg", ""))
	var page: Control = (load(CASTLE_SCN) as PackedScene).instantiate()
	page.set_anchors_preset(Control.PRESET_TOP_LEFT)
	page.position = Vector2.ZERO
	page.size = Vector2(PHONE)
	get_tree().root.add_child(page)
	if page.has_method("apply_mobile_layout"):
		page.apply_mobile_layout()
	await _settle(14)
	if page.find_child("BannerHandoffPanel", true, false) == null:
		page.queue_free()
		return "mobile BannerHandoffPanel missing"
	if page.find_child("HandoffHeirName", true, false) == null:
		page.queue_free()
		return "mobile HandoffHeirName missing"
	if page.find_child("ToDeploy", true, false) == null:
		page.queue_free()
		return "mobile ToDeploy missing"
	if page.find_child("ToRoster", true, false) == null:
		page.queue_free()
		return "mobile ToRoster missing"
	page.queue_free()
	await _settle(2)
	print("mobile handoff board ok")
	return ""
