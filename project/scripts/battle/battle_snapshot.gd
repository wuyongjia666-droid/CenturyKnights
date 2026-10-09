class_name BattleSnapshot
extends RefCounted
## Serializable battle beat: units, buffs, reinforcement marks, and the RNG
## cursor. 回灯 restores one of these so the same action rolls the same dice.

static func rule(difficulty: int) -> Dictionary:
	var table := {0: 3, 1: 2, 2: 1, 3: 0, 4: 0}
	var charges := int(table.get(clampi(difficulty, 0, 4), 1))
	return {"charges": charges, "refill": false}


static func hash_of(snap: Dictionary) -> int:
	return int(snap.hash())


static func capture(host) -> Dictionary:
	var rows: Array = []
	for u in host.units:
		rows.append(_unit(u))
	var done = host.get_meta("reinf_done", {})
	if typeof(done) != TYPE_DICTIONARY:
		done = {}
	return {
		"units": rows,
		"turn_team": str(host.turn_team),
		"round": int(host._round_no),
		"selected": int(host.selected),
		"moved": bool(host.moved_this_select),
		"attack_mode": bool(host.attack_mode),
		"skill_mode": bool(host.skill_mode),
		"active_skill": str(host.active_skill_id),
		"battle_over": bool(host.battle_over),
		"rng_seed": int(host.rng.seed),
		"rng_state": int(host.rng.state),
		"banter_idx": int(host._banter_idx),
		"banter_kill": int(host._banter_kill),
		"banter_played": host._banter_played.duplicate(true),
		"reinf_done": done.duplicate(true),
	}


static func seal_turn(host) -> void:
	host._arm_lamps()
	host._move_undo = {}
	host._lamp_stack.clear()
	if host._lamp_refill:
		host._lamp_charges = host._lamp_max
	host._turn_snap = capture(host)
	RewindBar.refresh(host)


static func push_lamp(host) -> void:
	if host.battle_over or str(host.turn_team) != "player":
		return
	host._lamp_stack.append({
		"snap": capture(host),
		"undo": host._move_undo.duplicate(true),
	})
	host._move_undo = {}
	RewindBar.refresh(host)


static func undo_move(host) -> void:
	if host._move_undo.is_empty() or host.battle_over:
		return
	apply(host, host._move_undo)
	host._move_undo = {}
	after_restore(host)


static func rewind_lamp(host) -> void:
	if int(host._lamp_charges) <= 0 or host.battle_over or str(host.turn_team) != "player":
		return
	var snap: Dictionary = {}
	var undo: Dictionary = {}
	if not host._lamp_stack.is_empty():
		var top: Dictionary = host._lamp_stack.pop_back()
		snap = top.get("snap", {})
		undo = top.get("undo", {})
	else:
		snap = host._turn_snap
		if snap.is_empty():
			return
		if hash_of(snap) == hash_of(capture(host)):
			return
	host._lamp_charges -= 1
	apply(host, snap)
	host._move_undo = undo
	after_restore(host)


static func after_restore(host) -> void:
	var ui := int(host.selected)
	var keep := false
	if ui >= 0 and ui < host.units.size():
		var unit = host.units[ui]
		keep = not unit.done and not host.moved_this_select and str(unit.team) == "player"
	if keep:
		host.move_cells = host._compute_move_cells(ui)
	else:
		host.move_cells.clear()
	host._refresh_info()
	host._update_skill_hint()
	ObjectiveHud.refresh(host)
	ForecastPanel.refresh(host)
	RewindBar.refresh(host)
	if host.map_draw:
		host.map_draw.queue_redraw()
	if host.overlay:
		host.overlay.queue_redraw()


static func apply(host, snap: Dictionary) -> void:
	host.rng.seed = int(snap.get("rng_seed", 1))
	host.rng.state = int(snap.get("rng_state", 1))
	var by_id := {}
	for row in snap.get("units", []):
		by_id[str(row.get("id", ""))] = row
	var kept: Array = []
	for u in host.units:
		var key := str(u.char.id)
		if not by_id.has(key):
			continue
		_restore_unit(u, by_id[key])
		kept.append(u)
	host.units = kept
	host.turn_team = str(snap.get("turn_team", "player"))
	host._round_no = int(snap.get("round", host._round_no))
	host.selected = int(snap.get("selected", -1))
	host.moved_this_select = bool(snap.get("moved", false))
	host.attack_mode = bool(snap.get("attack_mode", false))
	host.skill_mode = bool(snap.get("skill_mode", false))
	host.active_skill_id = str(snap.get("active_skill", ""))
	host.battle_over = bool(snap.get("battle_over", false))
	host._banter_idx = int(snap.get("banter_idx", 0))
	host._banter_kill = int(snap.get("banter_kill", 0))
	host._banter_played = (snap.get("banter_played", {}) as Dictionary).duplicate(true)
	host.set_meta("reinf_done", (snap.get("reinf_done", {}) as Dictionary).duplicate(true))
	if host._round_label:
		host._round_label.text = BattleObjectives.text("obj_round") % int(host._round_no)


static func _unit(u) -> Dictionary:
	var c: CKCharacter = u.char
	return {
		"id": str(c.id),
		"pos": [int(u.pos.x), int(u.pos.y)],
		"done": bool(u.done),
		"hp": int(c.hp),
		"max_hp": int(c.max_hp),
		"injured": bool(c.injured),
		"alive": bool(c.alive),
		"exp": int(c.exp),
		"skill_uses": c.skill_uses.duplicate(true),
		"skill_cd": c.skill_cd.duplicate(true),
		"temp_def_buff": int(c.temp_def_buff),
		"temp_hit_bonus": int(c.temp_hit_bonus),
		"temp_crit_bonus": int(c.temp_crit_bonus),
		"temp_ignore_zoc": bool(c.temp_ignore_zoc),
		"temp_leave_free": bool(c.temp_leave_free),
		"temp_combat_lock": int(c.temp_combat_lock),
		"temp_terrain_ward": bool(c.temp_terrain_ward),
		"temp_zoc_aura": int(c.temp_zoc_aura),
		"temp_exposed": int(c.temp_exposed),
	}


static func _restore_unit(u, row: Dictionary) -> void:
	var pos: Array = row.get("pos", [0, 0])
	u.pos = Vector2i(int(pos[0]), int(pos[1]))
	u.done = bool(row.get("done", false))
	var c: CKCharacter = u.char
	c.hp = int(row.get("hp", c.hp))
	c.max_hp = int(row.get("max_hp", c.max_hp))
	c.injured = bool(row.get("injured", false))
	c.alive = bool(row.get("alive", true))
	c.exp = int(row.get("exp", c.exp))
	c.skill_uses = (row.get("skill_uses", {}) as Dictionary).duplicate(true)
	c.skill_cd = (row.get("skill_cd", {}) as Dictionary).duplicate(true)
	c.temp_def_buff = int(row.get("temp_def_buff", 0))
	c.temp_hit_bonus = int(row.get("temp_hit_bonus", 0))
	c.temp_crit_bonus = int(row.get("temp_crit_bonus", 0))
	c.temp_ignore_zoc = bool(row.get("temp_ignore_zoc", false))
	c.temp_leave_free = bool(row.get("temp_leave_free", false))
	c.temp_combat_lock = int(row.get("temp_combat_lock", 0))
	c.temp_terrain_ward = bool(row.get("temp_terrain_ward", false))
	c.temp_zoc_aura = int(row.get("temp_zoc_aura", 0))
	c.temp_exposed = int(row.get("temp_exposed", 0))
