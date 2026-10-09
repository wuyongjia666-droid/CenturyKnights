class_name BattleStages
extends RefCounted
## BTL-11: carry living allies into the next stage, and undo arena injuries.


static func advance(host) -> bool:
	var cur := BattleMaps.get_map(host.map_id)
	var nxt := BattleObjectives.next_stage(cur)
	if nxt == "":
		return false
	var nxt_map := BattleMaps.get_map(nxt)
	if str(nxt_map.get("id", "")) != nxt:
		return false
	var kept := {}
	for u in host.units:
		var side := str(u.get("team", ""))
		if side != "player" and side != "ally":
			continue
		if int(u.char.hp) <= 0:
			continue
		kept[str(u.char.id)] = {
			"hp": int(u.char.hp),
			"lock": int(u.char.temp_combat_lock),
			"def": int(u.char.temp_def_buff),
			"hit": int(u.char.temp_hit_bonus),
			"ward": bool(u.char.temp_terrain_ward),
		}
	GameState.set_meta("battle_map", nxt)
	host._init_map()
	host._deploy()
	var live: Array = []
	for u in host.units:
		var row: Dictionary = kept.get(str(u.char.id), {})
		if row.is_empty():
			if str(u.get("team", "")) == "player" or str(u.get("team", "")) == "ally":
				continue
			live.append(u)
			continue
		u.char.hp = int(row["hp"])
		u.char.temp_combat_lock = int(row["lock"])
		u.char.temp_def_buff = int(row["def"])
		u.char.temp_hit_bonus = int(row["hit"])
		u.char.temp_terrain_ward = bool(row["ward"])
		live.append(u)
	host.units = live
	host.battle_over = false
	host.turn_team = "player"
	host._log(BattleObjectives.text("stage_next") % host.map_name)
	host._refresh_info()
	ObjectiveHud.refresh(host)
	if host.map_draw:
		host.map_draw.queue_redraw()
	return true


static func snap_arena(host) -> void:
	if not BattleObjectives.is_arena(BattleMaps.get_map(host.map_id)):
		return
	if not host._arena_snap.is_empty():
		return
	for c in GameState.roster():
		host._arena_snap[str(c.id)] = {
			"hp": int(c.hp),
			"injured": bool(c.injured),
			"down": c.has_meta("classic_down"),
		}


static func restore_arena(host) -> void:
	for c in GameState.roster():
		var row: Dictionary = host._arena_snap.get(str(c.id), {})
		if row.is_empty():
			continue
		c.hp = int(row["hp"])
		c.injured = bool(row["injured"])
		if bool(row["down"]):
			c.set_meta("classic_down", true)
		elif c.has_meta("classic_down"):
			c.remove_meta("classic_down")
