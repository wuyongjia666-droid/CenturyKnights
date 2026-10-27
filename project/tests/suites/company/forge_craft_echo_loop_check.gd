extends Node
## Shop fat: craft_weapon_preview → short/none/same → craft → ash_blade/fine →
## month_echo.forge → forge EchoLine_forge. Avoids thin CTA / month_echo-only knives.

const MARKER := "FORGE CRAFT ECHO LOOP PASS"
const FORGE_SCN := preload("res://scenes/hub/forge.tscn")


func _ready() -> void:
	var err := await _run()
	if err != "":
		print("FAIL forge craft echo: ", err)
		get_tree().quit(1)
	else:
		print(MARKER)
		get_tree().quit(0)


func _run() -> String:
	await get_tree().process_frame
	GameState.new_game("工坊回读", "灰旗", GameState.crest_color)
	GameState.chapter0_flags["chapter0_done"] = true
	GameState.chapter0_flags["ch0_playing"] = false
	UnlockSchedule.install()
	World.events_enabled = false
	World.rivals_enabled = false
	GameState.buildings["forge"] = 1
	GameState.house_mods.erase("sundry_forge_iron")
	GameState.house_mods.erase("month_echo")
	World.armory.clear()
	for c in GameState.roster():
		c.weapon_id = ""

	var err := _api_preview_gates()
	if err != "":
		return err
	err = _api_craft_echo()
	if err != "":
		return err
	err = _api_fine_blade_echo()
	if err != "":
		return err
	err = await _ui_desktop()
	if err != "":
		return err
	return ""


func _leader() -> CKCharacter:
	return GameState.roster()[0] as CKCharacter


func _api_preview_gates() -> String:
	var c := _leader()
	var cost: Dictionary = GameState.forge_craft_cost()
	var need_i := int(cost.iron)
	var need_s := int(cost.silver)
	if need_i < 1 or need_s < 1:
		return "base craft cost odd iron=%s silver=%s" % [need_i, need_s]

	var p_none: Dictionary = GameState.craft_weapon_preview("")
	if not bool(p_none.get("none", false)) or str(p_none.get("reason", "")) != "none":
		return "expected none preview: %s" % str(p_none)
	var bad_none: Dictionary = GameState.craft_weapon("")
	if bool(bad_none.get("ok", false)):
		return "empty cid should reject craft"

	GameState.silver = need_s - 1
	GameState.iron = need_i
	var p_short: Dictionary = GameState.craft_weapon_preview(c.id)
	if not bool(p_short.get("short", false)) or bool(p_short.get("craftable", true)):
		return "expected short preview: %s" % str(p_short)
	var bad_short: Dictionary = GameState.craft_weapon(c.id)
	if bool(bad_short.get("ok", false)):
		return "short should reject craft"

	GameState.silver = 80000
	GameState.iron = 40
	c.weapon_id = ""
	var p_ok: Dictionary = GameState.craft_weapon_preview(c.id)
	if not bool(p_ok.get("craftable", false)) or str(p_ok.get("target", "")) != "ash_blade":
		return "expected craftable ash_blade: %s" % str(p_ok)

	c.weapon_id = "ash_blade"
	var p_same: Dictionary = GameState.craft_weapon_preview(c.id)
	if not bool(p_same.get("same", false)) or str(p_same.get("reason", "")) != "same":
		return "expected same preview: %s" % str(p_same)
	# API still allows re-craft (UI gates same); spend still happens
	var re: Dictionary = GameState.craft_weapon(c.id)
	if not bool(re.get("ok", false)):
		return "API re-craft same tier should still spend: %s" % str(re)
	c.weapon_id = ""
	GameState.house_mods.erase("month_echo")
	print("api preview gates ok")
	return ""


func _api_craft_echo() -> String:
	var c := _leader()
	c.weapon_id = ""
	GameState.buildings["forge"] = 1
	GameState.house_mods.erase("sundry_forge_iron")
	GameState.house_mods.erase("month_echo")
	GameState.silver = 80000
	GameState.iron = 40
	var cost: Dictionary = GameState.forge_craft_cost()
	var sil0 := int(GameState.silver)
	var ir0 := int(GameState.iron)
	var atk0 := c.derived_atk()
	var r: Dictionary = GameState.craft_weapon(c.id)
	if not bool(r.get("ok", false)):
		return "craft fail: %s" % str(r)
	if c.weapon_id != "ash_blade":
		return "weapon want ash_blade got %s" % c.weapon_id
	if c.derived_atk() != atk0 + 2:
		return "atk +2 want %d got %d" % [atk0 + 2, c.derived_atk()]
	if int(GameState.silver) != sil0 - int(cost.silver):
		return "silver sink fail"
	if int(GameState.iron) != ir0 - int(cost.iron):
		return "iron sink fail"
	var snap: Dictionary = CKEconomyState.month_echo_snapshot()
	var echo := str(snap.get("forge", ""))
	if echo.find("铸") < 0 and echo.find("forged") < 0:
		return "month_echo.forge missing craft: %s" % echo
	if echo.find(c.name) < 0:
		return "month_echo.forge missing name: %s" % echo
	var found := false
	for row in CKEconomyState.month_echo_lines():
		if str(row.get("kind", "")) == "forge":
			found = true
			break
	if not found:
		return "month_echo_lines missing forge kind"
	print("api craft echo ok text=%s" % echo)
	return ""


func _api_fine_blade_echo() -> String:
	var c := _leader()
	c.weapon_id = ""
	GameState.buildings["forge"] = 4
	GameState.house_mods.erase("sundry_forge_iron")
	GameState.house_mods.erase("month_echo")
	GameState.silver = 80000
	GameState.iron = 40
	var prev: Dictionary = GameState.craft_weapon_preview(c.id)
	if str(prev.get("target", "")) != "ash_blade_fine" or not bool(prev.get("craftable", false)):
		return "lv4 preview want fine: %s" % str(prev)
	var r: Dictionary = GameState.craft_weapon(c.id)
	if not bool(r.get("ok", false)):
		return "lv4 craft fail: %s" % str(r)
	if c.weapon_id != "ash_blade_fine":
		return "lv4 weapon want fine got %s" % c.weapon_id
	var snap: Dictionary = CKEconomyState.month_echo_snapshot()
	var echo := str(snap.get("forge", ""))
	if echo.find("精") < 0 and echo.find("Fine") < 0 and echo.find("fine") < 0:
		# zh name is 灰刃·精 via forge_weapon_fine
		if echo.find("灰刃") < 0:
			return "lv4 month_echo.forge odd: %s" % echo
	print("api fine echo ok text=%s" % echo)
	return ""


func _ui_desktop() -> String:
	GameState.buildings["forge"] = 1
	GameState.house_mods.erase("sundry_forge_iron")
	GameState.house_mods.erase("month_echo")
	GameState.silver = 80000
	GameState.iron = 40
	for c in GameState.roster():
		c.weapon_id = ""

	var forge: Control = FORGE_SCN.instantiate()
	get_tree().root.add_child(forge)
	forge.set_anchors_preset(Control.PRESET_TOP_LEFT)
	forge.position = Vector2.ZERO
	forge.size = Vector2(1280, 720)
	for _i in 10:
		await get_tree().process_frame

	var lead := _leader()
	var craft := forge.find_child("ForgeCraft", true, false) as Button
	if craft == null or craft.disabled:
		forge.queue_free()
		return "UI ForgeCraft missing/disabled bare"
	craft.pressed.emit()
	for _j in 8:
		await get_tree().process_frame
	if lead.weapon_id != "ash_blade":
		forge.queue_free()
		return "UI craft not ash_blade got %s" % lead.weapon_id
	var snap: Dictionary = CKEconomyState.month_echo_snapshot()
	if str(snap.get("forge", "")) == "":
		forge.queue_free()
		return "UI missing month_echo.forge after craft"
	# re-render surfaces EchoLine_forge
	if forge.has_method("_render_all"):
		forge.call("_render_all")
	for _k in 6:
		await get_tree().process_frame
	var echo := forge.find_child("EchoLine_forge", true, false) as Label
	if echo == null:
		forge.queue_free()
		return "EchoLine_forge missing on forge"
	if str(echo.text).find("铸") < 0 and str(echo.text).find("forged") < 0:
		forge.queue_free()
		return "EchoLine_forge text odd: %s" % echo.text
	craft = forge.find_child("ForgeCraft", true, false) as Button
	if craft == null or not craft.disabled:
		forge.queue_free()
		return "UI ForgeCraft should disable same-tier after craft"
	print("ui desktop forge+echo ok text=%s" % echo.text)
	forge.queue_free()
	await get_tree().process_frame
	return ""
