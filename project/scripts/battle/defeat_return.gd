class_name BattleDefeat
extends RefCounted
## WS-D #50 / #5: a lost or abandoned battle always goes back to the castle (never chapter 0),
## and the company gets an injury settlement written to the castle log.
## Chapter-owned mid-cs (`battle_return_chapter`): skip castle log_event — mid_lost owns the trail.

const CASTLE := "res://scenes/hub/castle_hub.tscn"
const META := "defeat_settlement"


static func back_path(win: bool, world_enc: bool, battle_return: String) -> String:
	if win or world_enc:
		return battle_return if battle_return != "" else CASTLE
	# Story-launched fight retry: prologue before hub (A-04), OR mid-cs / era with
	# battle_return_chapter stamped (#442+). Bare story return after hub_open still
	# CASTLE — hub quests and leftover ch0 returns must not bounce into chapter.
	var story := battle_return.begins_with("res://scenes/story/")
	var chapter_back := str(GameState.get_meta("battle_return_chapter", "")) != ""
	if story and (not GameState.flag("hub_open") or chapter_back):
		var map_id := str(GameState.get_meta("battle_map", ""))
		if map_id != "":
			GameState.set_flag(map_id + "_lost")
		# Chapter-authored lose_flags (csXX_mid_lost) — season owns the retry CTA morph.
		for f in GameState.get_meta("battle_lose_flags", []):
			var fs := str(f)
			if fs != "":
				GameState.set_flag(fs)
		if GameState.has_meta("battle_lose_flags"):
			GameState.set_meta("battle_lose_flags", [])
		return battle_return
	return CASTLE


## One line per player unit: name plus wound label (or 疲惫 when only worn down).
static func settlement(units: Array) -> PackedStringArray:
	var rows: PackedStringArray = []
	for u in units:
		if str(u.get("team", "")) != "player":
			continue
		var c: CKCharacter = u.char
		if c == null:
			continue
		if not c.alive:
			rows.append(Locale.t("defeat_row_dead") % c.name)
			continue
		var lab := CKInjury.label(c)
		if lab == "" and c.injured:
			lab = Locale.t("defeat_row_tired")
		if lab != "":
			rows.append("%s · %s" % [c.name, lab])
	return rows


## Chapter-owned mid-cs / era: mid_lost CTA owns the loss trail.
## Castle event_log must not keep permanent「败北」rows for fights later won on retry.
static func suppresses_castle_record() -> bool:
	return str(GameState.get_meta("battle_return_chapter", "")) != ""


## Hub / sortie defeat settlement. Skips chapter-owned mid-cs (see suppresses_castle_record).
static func maybe_record(units: Array, reason: String) -> String:
	if suppresses_castle_record():
		return ""
	return record(units, reason)


static func record(units: Array, reason: String) -> String:
	var rows := settlement(units)
	var head := Locale.t("defeat_retreat_head") if reason == "retreat" else Locale.t("defeat_head")
	var text := head + ("：" + "，".join(rows) if not rows.is_empty() else "")
	GameState.set_meta(META, text)
	GameState.log_event(text)
	return text


## Pause-menu retreat inside a battle: counts as a defeat with reason "retreat".
static func retreat(battle: Node) -> bool:
	if battle == null or not battle.has_method("_finish") or bool(battle.get("battle_over")):
		return false
	battle.set_meta("battle_verdict", {"result": "lose", "reason": "retreat"})
	battle.call("_finish", false)
	return true


static func find_battle(tree: SceneTree) -> Node:
	if tree == null or tree.current_scene == null:
		return null
	var s := tree.current_scene
	if s.has_signal("battle_finished") and s.has_method("_finish"):
		return s
	for n in s.find_children("*", "Control", true, false):
		if n.has_signal("battle_finished") and n.has_method("_finish"):
			return n
	return null
