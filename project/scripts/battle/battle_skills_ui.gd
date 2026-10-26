class_name BattleSkillsUi
extends RefCounted
## Skill arming / hint text. Kept out of battle_controller (≤3000 line gate).


static func player_skills(host, ui: int) -> Array:
	if ui < 0 or ui >= host.units.size():
		return []
	if not BattleObjectives.skills_allowed(BattleMaps.get_map(host.map_id)):
		return []
	var c: CKCharacter = host.units[ui].char
	var out: Array = []
	for sid in c.skills:
		var left = int(c.skill_uses.get(sid, 0))
		var cd = int(c.skill_cd.get(sid, 0))
		if left > 0 and cd <= 0:
			out.append(sid)
	return out


static func cycle(host) -> void:
	if host.selected < 0 or host.selected >= host.units.size():
		host._log(Locale.t("ux_skill_need_select"))
		return
	var avail: Array = player_skills(host, host.selected)
	if avail.is_empty():
		_reject_empty(host)
		return
	var next := ""
	if host.active_skill_id == "" or host.active_skill_id not in avail:
		next = str(avail[0])
	else:
		var idx: int = avail.find(host.active_skill_id)
		next = str(avail[(idx + 1) % avail.size()])
	arm(host, next)


static func arm(host, sid: String) -> void:
	if host.selected < 0 or host.selected >= host.units.size():
		host._log(Locale.t("ux_skill_need_select"))
		return
	var su = host.units[host.selected]
	if su.team != "player" or su.done:
		host._log(Locale.t("ux_skill_cant_use"))
		return
	var avail: Array = player_skills(host, host.selected)
	if sid == "" or sid not in avail:
		_reject_empty(host)
		return
	host.active_skill_id = sid
	var sk: Dictionary = GameState.get_skill(sid)
	var typ := str(sk.get("type", "offense"))
	if typ == "support":
		if BattleSkillHealPreview.arm(host, sid):
			return
		host._cast_support_skill(host.selected, sid)
		return
	if typ == "buff":
		host._cast_buff_skill(host.selected, sid)
		return
	host.skill_mode = true
	host.attack_mode = true
	if sk.get("ignore_zoc"):
		su.char.temp_ignore_zoc = true
		if not host.moved_this_select:
			host.move_cells = host._compute_move_cells(host.selected)
			host.attack_mode = false
			host._log(Locale.t("ux_skill_break_zoc") % str(sk.get("desc", "")))
		else:
			host.move_cells.clear()
			host._log(Locale.t("ux_skill_ready") % [str(sk.get("name", "")), str(sk.get("desc", ""))])
	else:
		host.move_cells.clear()
		host._log(Locale.t("ux_skill_ready") % [str(sk.get("name", "")), str(sk.get("desc", ""))])
	update_hint(host)
	host.overlay.queue_redraw()
	host._refresh_info()
	if DeviceProfile.is_mobile():
		BattleMobileBar.rebuild(host)


static func _reject_empty(host) -> void:
	host._log(Locale.t("ux_skill_exhausted"))
	host.skill_mode = false
	host.active_skill_id = ""
	update_hint(host)


static func update_hint(host) -> void:
	if host._skill_hint == null:
		return
	if host.selected >= 0 and host.selected < host.units.size() and host.units[host.selected].team == "player":
		var parts: Array = []
		for sid in host.units[host.selected].char.skills:
			var sk: Dictionary = GameState.get_skill(sid)
			var left := int(host.units[host.selected].char.skill_uses.get(sid, 0))
			var cd := int(host.units[host.selected].char.skill_cd.get(sid, 0))
			if cd > 0:
				parts.append(Locale.t("ux_skill_cd") % [str(sk.get("name", sid)), cd])
			else:
				parts.append(Locale.t("ux_skill_uses") % [str(sk.get("name", sid)), left])
		var armed := ""
		if host.active_skill_id != "":
			armed = Locale.t("ux_skill_armed") % str(GameState.get_skill(host.active_skill_id).get("name", host.active_skill_id))
		var body := Locale.t("ux_skill_list") % (" · ".join(parts) if parts else Locale.t("ux_skill_none"))
		host._skill_hint.text = body + armed
	else:
		host._skill_hint.text = Locale.t("shell_94db6f97")
