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
	# Chapter-authored win_flags (mid-cs skirmish) stamped on battle leave — shared maps
	# like quest_bandit stay clean; each season owns csXX_mid_fought.
	for f in GameState.get_meta("battle_win_flags", []):
		var s2 := str(f)
		if s2 != "" and not flags.has(s2):
			flags.append(s2)
	# Pre-BTL-01 also forced battle_done for quest-prefixed ids after the ladder.
	if map_id.begins_with("quest") and not flags.has("battle_done"):
		flags.append("battle_done")
	var actions: Array = []
	for a in ov.get("actions", []):
		actions.append(str(a))
	return {
		"flags": flags,
		"actions": actions,
		"tutorial": bool(m.get("tutorial_militia", false)) or bool(m.get("tutorial", false)),
	}


## Audit P1-3: the castle "出战" sortie pays once a calendar month. Repeats are drills: no silver,
## reputation, exp or skill point. Returns true when this win is a drill (and claims the month otherwise).
static func sortie_is_drill(host) -> bool:
	if not host.has_meta("battle_sortie") or not bool(host.get_meta("battle_sortie", false)):
		return false
	host.set_meta("battle_sortie", false)
	var now := Calendar.year * 12 + Calendar.month
	if int(host.sortie_month) == now:
		return true
	host.sortie_month = now
	return false


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
	# Win clears chapter-authored lose_flags residue (csXX_mid_lost). A prior
	# defeat stamped them on GameState; emptying the meta alone left loss-state
	# alive so when/payoffs keyed only on mid_lost could resurrect after a win.
	for lf in GameState.get_meta("battle_lose_flags", []):
		var ls := str(lf)
		if ls != "":
			GameState.set_flag(ls, false)
	# Same residue class for the shared-map flag Defeat stamps (quest_bandit_lost).
	# Mid-cs loss→retry→win left map_id+"_lost" lit forever; clear it on win.
	if map_id != "":
		GameState.set_flag(map_id + "_lost", false)
	# Chapter-authored season_ledger on mid-cs skirmish win (not month_echo).
	var led = GameState.get_meta("battle_win_ledger", {})
	if typeof(led) == TYPE_DICTIONARY and not led.is_empty():
		var chapter_id := str(led.get("chapter", ""))
		var choice := str(led.get("choice", ""))
		var title := str(led.get("title", ""))
		var outcome := str(led.get("outcome", ""))
		if chapter_id != "" and choice != "" and outcome != "":
			CKSuiKe.season_ledger_append(
				chapter_id, choice, title, outcome,
				str(led.get("who", "")), bool(led.get("yeartrace", true)))
	# Consume chapter stamps so a later hub fight on the same map does not re-apply.
	if GameState.has_meta("battle_win_flags"):
		GameState.set_meta("battle_win_flags", [])
	if GameState.has_meta("battle_lose_flags"):
		GameState.set_meta("battle_lose_flags", [])
	if GameState.has_meta("battle_win_ledger"):
		GameState.set_meta("battle_win_ledger", {})
	return sp


## Chapter-owned mid-cs / era skirmish: season_ledger + yeartrace own the trail.
## month_echo.battle would phantom-pollute with shared-map rows (quest_bandit).
static func suppresses_month_echo_battle() -> bool:
	if str(GameState.get_meta("battle_return_chapter", "")) != "":
		return true
	var led = GameState.get_meta("battle_win_ledger", {})
	return typeof(led) == TYPE_DICTIONARY and not led.is_empty()


## Map-fight month_echo.battle note (hub/sortie). Skips chapter-owned mid-cs.
## Returns true when a line was written.
static func maybe_note_month_echo_battle(
		win: bool, map_name: String, purse: int = 0,
		drill: bool = false, tutorial: bool = false) -> bool:
	if suppresses_month_echo_battle():
		return false
	if win:
		if drill or tutorial:
			return false
		CKEconomyState.month_echo_note(
			"battle", Locale.t("lb_echo_battle_map_win", [map_name, purse]))
	else:
		CKEconomyState.month_echo_note(
			"battle", Locale.t("lb_echo_battle_map_lose", [map_name]))
	return true


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
