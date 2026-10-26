extends Node
## Castle forge workshop: craft_weapon iron+silver sink → ash_blade / ash_blade_fine,
## same-tier ForgeCraft gate, world-weapon armory return, sundry oil discount,
## ForgeUpgrade, ForgeKnight_ select, save/load, named ForgeCraft UI.

const FORGE_SCN := preload("res://scenes/hub/forge.tscn")
const WORLD_WEP := "ashbanner_sword_1"

var _fails: Array = []


func _ready() -> void:
	await get_tree().process_frame
	_setup()
	_api_gates_and_craft()
	_api_world_weapon_return()
	_api_oil_discount()
	_api_fine_blade_lv4()
	_api_save_load()
	await _ui_forge_craft()
	if _fails.is_empty():
		print("FORGE WORKSHOP CRAFT PASS")
		get_tree().quit(0)
	else:
		for f in _fails:
			print("FAIL forge workshop craft: ", f)
		get_tree().quit(1)


func _ok(cond: bool, msg: String) -> void:
	print("ROW %s %s" % ["PASS" if cond else "FAIL", msg])
	if not cond:
		_fails.append(msg)


func _setup() -> void:
	GameState.new_game("工坊铸", "灰旗", GameState.crest_color)
	GameState.set_flag("chapter0_done", true)
	UnlockSchedule.install()
	World.events_enabled = false
	World.rivals_enabled = false
	GameState.silver = 80000
	GameState.iron = 40
	GameState.food = 40
	GameState.buildings["forge"] = 1
	GameState.house_mods.erase("sundry_forge_iron")
	World.armory.clear()
	for c in GameState.roster():
		c.weapon_id = ""


func _leader() -> CKCharacter:
	return GameState.roster()[0] as CKCharacter


func _api_gates_and_craft() -> void:
	var c := _leader()
	var cost: Dictionary = GameState.forge_craft_cost()
	_ok(int(cost.iron) >= 1 and int(cost.silver) >= 8, "base craft cost iron=%s silver=%s" % [cost.iron, cost.silver])
	GameState.silver = 0
	GameState.iron = 0
	_ok(not bool(GameState.craft_weapon(c.id).get("ok", false)), "craft rejected when broke")
	GameState.silver = 80000
	GameState.iron = 40
	var atk0 := c.derived_atk()
	var sil0 := GameState.silver
	var ir0 := GameState.iron
	var r: Dictionary = GameState.craft_weapon(c.id)
	_ok(bool(r.get("ok", false)), "craft ash_blade ok: %s" % r.get("msg", ""))
	_ok(c.weapon_id == "ash_blade", "weapon_id ash_blade got %s" % c.weapon_id)
	_ok(c.derived_atk() == atk0 + 2, "atk +2 after ash_blade %d→%d" % [atk0, c.derived_atk()])
	_ok(GameState.silver == sil0 - int(cost.silver), "silver sunk")
	_ok(GameState.iron == ir0 - int(cost.iron), "iron sunk")
	# API allows re-craft (same weapon) — UI gates same-tier; still spends
	var r2: Dictionary = GameState.craft_weapon(c.id)
	_ok(bool(r2.get("ok", false)), "API re-craft same tier still spends")
	_ok(c.weapon_id == "ash_blade", "still ash_blade after re-craft")


func _api_world_weapon_return() -> void:
	_ok(World.is_world_item(WORLD_WEP), "world item %s known" % WORLD_WEP)
	var c := _leader()
	c.weapon_id = WORLD_WEP
	World.armory.erase(WORLD_WEP)
	GameState.silver = 80000
	GameState.iron = 40
	var before := int(World.armory.get(WORLD_WEP, 0))
	var r: Dictionary = GameState.craft_weapon(c.id)
	_ok(bool(r.get("ok", false)), "craft with world weapon equipped")
	_ok(c.weapon_id == "ash_blade", "replaced world weapon with ash_blade")
	_ok(int(World.armory.get(WORLD_WEP, 0)) == before + 1, "world weapon returned to armory")


func _api_oil_discount() -> void:
	GameState.buildings["forge"] = 1
	GameState.house_mods.erase("sundry_forge_iron")
	var base: Dictionary = GameState.forge_craft_cost()
	GameState.house_mods["sundry_forge_iron"] = 1
	var oiled: Dictionary = GameState.forge_craft_cost()
	_ok(int(oiled.iron) == maxi(1, int(base.iron) - 1), "oil drops iron %s→%s" % [base.iron, oiled.iron])
	var c := _leader()
	c.weapon_id = ""
	GameState.silver = 80000
	GameState.iron = 40
	var ir0 := GameState.iron
	var r: Dictionary = GameState.craft_weapon(c.id)
	_ok(bool(r.get("ok", false)), "craft with oil")
	_ok(GameState.iron == ir0 - int(oiled.iron), "oil iron consumed")
	_ok(not GameState.house_mods.has("sundry_forge_iron"), "oil flag consumed")


func _api_fine_blade_lv4() -> void:
	GameState.buildings["forge"] = 4
	GameState.house_mods.erase("sundry_forge_iron")
	var c := _leader()
	c.weapon_id = ""
	var atk0 := c.derived_atk()
	GameState.silver = 80000
	GameState.iron = 40
	var r: Dictionary = GameState.craft_weapon(c.id)
	_ok(bool(r.get("ok", false)), "craft fine at lv4: %s" % r.get("msg", ""))
	_ok(c.weapon_id == "ash_blade_fine", "weapon_id ash_blade_fine got %s" % c.weapon_id)
	_ok(c.derived_atk() == atk0 + 3, "atk +3 fine %d→%d" % [atk0, c.derived_atk()])
	GameState.buildings["forge"] = 1


func _api_save_load() -> void:
	var c := _leader()
	c.weapon_id = "ash_blade"
	_ok(GameState.save_game(), "save_game")
	c.weapon_id = ""
	_ok(GameState.load_game(), "load_game")
	var c2: CKCharacter = GameState.characters.get(c.id)
	_ok(c2 != null and c2.weapon_id == "ash_blade", "weapon restored after load")


func _ui_forge_craft() -> void:
	GameState.buildings["forge"] = 1
	GameState.house_mods.erase("sundry_forge_iron")
	GameState.silver = 80000
	GameState.iron = 40
	for c in GameState.roster():
		c.weapon_id = ""
	var forge: Control = FORGE_SCN.instantiate()
	add_child(forge)
	forge.set_anchors_preset(Control.PRESET_TOP_LEFT)
	forge.position = Vector2.ZERO
	forge.size = Vector2(1280, 720)
	for _i in 10:
		await get_tree().process_frame
	var lead := _leader()
	var slot := forge.find_child("ForgeKnight_" + lead.id, true, false) as Button
	_ok(slot != null, "UI ForgeKnight_%s" % lead.id)
	var craft := forge.find_child("ForgeCraft", true, false) as Button
	_ok(craft != null and not craft.disabled, "UI ForgeCraft enabled bare")
	var up := forge.find_child("ForgeUpgrade", true, false) as Button
	_ok(up != null, "UI ForgeUpgrade present")
	var atk0 := lead.derived_atk()
	var ir0 := GameState.iron
	var sil0 := GameState.silver
	if craft:
		craft.emit_signal("pressed")
		for _k in 8:
			await get_tree().process_frame
	_ok(lead.weapon_id == "ash_blade", "UI craft → ash_blade")
	_ok(lead.derived_atk() == atk0 + 2, "UI atk +2")
	_ok(GameState.iron < ir0 and GameState.silver < sil0, "UI sank mats")
	# same-tier: ForgeCraft should disable after refresh
	craft = forge.find_child("ForgeCraft", true, false) as Button
	_ok(craft != null and craft.disabled, "UI ForgeCraft disabled same-tier")
	# switch knight via named slot
	var other: CKCharacter = null
	for c in GameState.roster():
		if c.id != lead.id:
			other = c
			break
	_ok(other != null, "second knight in roster")
	if other:
		var slot2 := forge.find_child("ForgeKnight_" + other.id, true, false) as Button
		_ok(slot2 != null, "UI ForgeKnight_%s" % other.id)
		if slot2:
			slot2.emit_signal("pressed")
			for _m in 6:
				await get_tree().process_frame
		craft = forge.find_child("ForgeCraft", true, false) as Button
		_ok(craft != null and not craft.disabled, "UI ForgeCraft enabled for bare second knight")
		if craft:
			craft.emit_signal("pressed")
			for _n in 8:
				await get_tree().process_frame
		_ok(other.weapon_id == "ash_blade", "UI craft second knight")
	# empty roster → ForgeEmpty (smoke: clear selection path by rendering empty)
	forge.queue_free()
	await get_tree().process_frame
	# Lv4 fine via UI
	GameState.buildings["forge"] = 4
	for c in GameState.roster():
		c.weapon_id = ""
	GameState.silver = 80000
	GameState.iron = 40
	var forge2: Control = FORGE_SCN.instantiate()
	add_child(forge2)
	forge2.set_anchors_preset(Control.PRESET_TOP_LEFT)
	forge2.position = Vector2.ZERO
	forge2.size = Vector2(1280, 720)
	for _p in 10:
		await get_tree().process_frame
	craft = forge2.find_child("ForgeCraft", true, false) as Button
	_ok(craft != null and not craft.disabled, "UI ForgeCraft at lv4")
	if craft:
		craft.emit_signal("pressed")
		for _q in 8:
			await get_tree().process_frame
	_ok(_leader().weapon_id == "ash_blade_fine", "UI craft → ash_blade_fine at lv4")
	forge2.queue_free()
	await get_tree().process_frame
