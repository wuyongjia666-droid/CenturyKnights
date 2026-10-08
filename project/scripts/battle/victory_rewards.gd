class_name BattleVictory
extends RefCounted
## BTL-01: one place for victory flags, purse, and the heir-clash restore.
## Map-specific flags and actions live on each map's on_victory field.


static func spec(map_id: String) -> Dictionary:
	var m := BattleMaps.get_map(map_id)
	var ov: Dictionary = {}
	var raw = m.get("on_victory", {})
	if typeof(raw) == TYPE_DICTIONARY:
		ov = raw
	var flags: Array = ["battle_done"]
	for f in ov.get("flags", []):
		var s := str(f)
		if s != "" and not flags.has(s):
			flags.append(s)
	# Pre-BTL-01 also forced battle_done for quest-prefixed ids after the ladder.
	if map_id.begins_with("quest") and not flags.has("battle_done"):
		flags.append("battle_done")
	var actions: Array = []
	for a in ov.get("actions", []):
		actions.append(str(a))
	return {
		"flags": flags,
		"actions": actions,
		"tutorial": bool(m.get("tutorial_militia", false)),
	}


static func base_purse(mods: Dictionary) -> int:
	var purse := 35
	if bool(mods.get("warlord_purse", false)):
		purse += 10
	if bool(mods.get("warlord_purse2", false)):
		purse += 10
	return purse


static func memory_bonus(mods: Dictionary) -> int:
	var memory := int(mods.get("war_memory", 0))
	if memory <= 0:
		return 0
	return mini(10, memory * 2)


static func silver_total(mods: Dictionary) -> int:
	return base_purse(mods) + memory_bonus(mods)


static func skill_points(tutorial: bool) -> int:
	return 0 if tutorial else 1


static func describe(map_id: String, mods: Dictionary = {}) -> Dictionary:
	var sp := spec(map_id)
	return {
		"flags": sp.flags.duplicate(),
		"silver": silver_total(mods),
		"skill_points": skill_points(bool(sp.tutorial)),
		"rep": {"ashland": 8},
		"actions": sp.actions.duplicate(),
		"unlocks": [],
	}


static func apply(map_id: String) -> Dictionary:
	var sp := spec(map_id)
	for f in sp.flags:
		GameState.set_flag(str(f))
	for act in sp.actions:
		if str(act) == "heir_clash_restore":
			restore_heir_clash()
	return sp


static func restore_heir_clash() -> void:
	for key in ["heir_clash_a", "heir_clash_b"]:
		var cid := str(GameState.get_meta(key, ""))
		if cid == "":
			continue
		var c: CKCharacter = GameState.characters.get(cid)
		if c:
			c.hp = c.max_hp
			c.alive = true
	GameState.add_lineage_event("双嗣校场终了：双方回堡养伤，名册旁注已更新。")
	GameState.remove_meta("heir_clash_a")
	GameState.remove_meta("heir_clash_b")
