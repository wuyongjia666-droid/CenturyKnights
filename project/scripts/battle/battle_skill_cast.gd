class_name BattleSkillCast
extends RefCounted
## Offense-adjacent support/buff cast bodies lifted from battle_controller
## so telegraph wires stay under the 3000-line gate.


static func support(host, ui: int, sid: String) -> void:
	host._push_lamp()
	Sfx.skill()
	if Sfx.has_method("heal"):
		Sfx.heal()
	var sk = GameState.get_skill(sid)
	var u = host.units[ui]
	var healed = 0
	for j in host.units.size():
		var o = host.units[j]
		if o.team != "player" or o.char.hp <= 0:
			continue
		if host._manhattan(u.pos, o.pos) <= 1:
			var amt = host.rng.randi_range(int(sk.get("heal_min", 8)), int(sk.get("heal_max", 12)))
			amt = int(BattleRules.apply_class_heal(u.char, o.char, amt).get("healed", amt))
			healed += 1
			host._spawn_dmg(o.pos, "+%d" % amt, Color(0.4, 0.9, 0.5))
			host._spawn_slash(o.pos, "heal")
	if sk.get("party_def_buff"):
		var add = int(sk.get("party_def_buff"))
		for ou in host.units:
			if ou.team == "player" and ou.char.hp > 0:
				ou.char.temp_def_buff = maxi(ou.char.temp_def_buff, add)
		host._spawn_dmg(u.pos, "圣域", Color(0.7, 0.85, 1.0))
	host._consume_skill(u.char, sid)
	u.done = true
	host.selected = -1
	Sfx.confirm()
	host._log("%s 释放「%s」，治疗 %d 人" % [u.char.name, sk.get("name", ""), healed])
	host.map_draw.queue_redraw()
	host._refresh_info()
	host._check_end()


static func buff(host, ui: int, sid: String) -> void:
	host._push_lamp()
	var sk = GameState.get_skill(sid)
	var u = host.units[ui]
	if sk.get("def_buff"):
		u.char.temp_def_buff = int(sk.get("def_buff"))
	if sk.get("next_hit_bonus"):
		u.char.temp_hit_bonus = int(sk.get("next_hit_bonus"))
	if sk.get("next_crit_bonus"):
		u.char.temp_crit_bonus = int(sk.get("next_crit_bonus"))
	if sk.get("zoc_aura"):
		u.char.temp_zoc_aura = int(sk.get("zoc_aura"))
	if sk.get("ignore_zoc"):
		u.char.temp_ignore_zoc = true
	if sk.get("leave_free"):
		u.char.temp_leave_free = true
	if sk.get("clear_combat_lock"):
		u.char.temp_combat_lock = 0
		host._spawn_dmg(u.pos, "拆锁", Color(0.5, 0.85, 1.0))
		host._spawn_slash(u.pos, "spark")
	if sk.get("terrain_ward"):
		u.char.temp_terrain_ward = true
		host._spawn_dmg(u.pos, "地利", Color(0.55, 0.9, 0.55))
		host._spawn_slash(u.pos, "shield")
	if sk.get("leave_free") or sk.get("clear_combat_lock") or sk.get("ignore_zoc"):
		if ui == host.selected:
			host.move_cells = host._compute_move_cells(ui)
			host.attack_mode = false
	if sk.get("party_def_buff"):
		var add = int(sk.get("party_def_buff"))
		for ou in host.units:
			if ou.team == "player" and ou.char.hp > 0:
				ou.char.temp_def_buff = maxi(ou.char.temp_def_buff, add)
	if sk.get("self_def_penalty"):
		u.char.temp_def_buff = maxi(-99, u.char.temp_def_buff - int(sk.get("self_def_penalty")))
	host._consume_skill(u.char, sid)
	var note = ""
	if sk.get("zoc_aura"):
		note = "（控带强化）"
	host._log("%s 释放「%s」%s" % [u.char.name, sk.get("name", ""), note])
	Sfx.confirm()
	Sfx.skill()
	host._refresh_info()
	host.map_draw.queue_redraw()
	host.overlay.queue_redraw()
