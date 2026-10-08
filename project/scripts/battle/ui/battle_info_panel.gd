class_name BattleInfoPanel
extends RefCounted
## Selected-unit intel panel. Extracted from the battle controller in BTL-01.


static func refresh_for(host, ui: int) -> void:
	if ui < 0 or ui >= host.units.size():
		refresh(host)
		return
	var u = host.units[ui]
	var c: CKCharacter = u.char
	host._portrait.texture = UnitArt.portrait(c, 96)
	if host._unit_card:
		host._unit_card.set_unit(c, u.team)
	var _nm := str(c.name)
	if (u.team == "enemy" or c.faction == "enemy") and (_nm.find("匪首") >= 0 or _nm.find("头目") >= 0 or _nm.find("Boss") >= 0):
		if host._portrait:
			UIFX.boss_threat(host._portrait)
	var tid = host.terrain[u.pos.y][u.pos.x]
	var tinfo = BattleRules.terrain_info(tid)
	var role2 = BattleRules.role_label(BattleRules.job_role(c.job_id))
	host.info_label.text = Locale.t("shell_c5c4fa01") % [
		c.name, Locale.t("shell_c832b9ce") if u.team == "player" else Locale.t("shell_f4069c8b"), role2,
		c.hp, c.max_hp, c.derived_atk(), c.derived_def(),
		tinfo["name"], tinfo.get("avo_bonus", 0), tinfo.get("def_bonus", 0),
	]


static func fill_traits(host, c: CKCharacter) -> void:
	if host._info_traits == null:
		return
	for ch in host._info_traits.get_children():
		ch.queue_free()
	if c == null:
		return
	for tr in c.traits:
		var ic = UIKit.trait_icon_rect(str(tr), 26.0)
		var td = GameState.get_trait(str(tr))
		ic.tooltip_text = str(td.get("name", tr))
		host._info_traits.add_child(ic)


static func refresh(host) -> void:
	if host.selected < 0 or host.selected >= host.units.size():
		host.info_label.text = Locale.t("shell_82b986d8")
		if GameState.get_leader():
			host._portrait.texture = UnitArt.portrait(GameState.get_leader(), 96)
			if host._unit_card:
				host._unit_card.set_unit(GameState.get_leader(), "player")
			fill_traits(host, GameState.get_leader())
		else:
			host._portrait.texture = UnitArt.banner(96, 96, false)
			if host._unit_card:
				host._unit_card.set_unit(null)
			fill_traits(host, null)
		return
	var u = host.units[host.selected]
	var c: CKCharacter = u.char
	host._portrait.texture = UnitArt.portrait(c, 96)
	if host._unit_card:
		host._unit_card.set_unit(c, u.team)
	fill_traits(host, c)
	var tid = host.terrain[u.pos.y][u.pos.x]
	var tinfo = BattleRules.terrain_info(tid)
	var mode := ""
	if u.team == "player" and not u.done:
		if host.attack_mode:
			mode = BattleRules._rich(UIKit.DANGER, Locale.t("shell_64295185"))
		elif host.moved_this_select:
			mode = BattleRules._rich(UIKit.ACCENT, Locale.t("shell_8736b101"))
		else:
			mode = BattleRules._rich(UIKit.ACCENT, Locale.t("shell_31067370"))
	var role = BattleRules.role_label(BattleRules.job_role(c.job_id))
	var foes = host._enemy_positions(u.team)
	var engaged = BattleRules.is_engaged(u.pos, foes)
	var locked = int(c.temp_combat_lock) > 0
	var eng := BattleRules.engagement_note(locked, engaged, c.temp_leave_free, c.temp_ignore_zoc)
	var txt = mode + eng + Locale.t("shell_b1a2868a") % [
		c.name, Locale.t("shell_c832b9ce") if u.team == "player" else Locale.t("shell_f4069c8b"), role,
		c.hp, c.max_hp, c.derived_atk(), c.derived_def(), c.derived_hit(), c.derived_avo(), c.derived_move(),
		tinfo["name"], tinfo["avo_bonus"], tinfo.get("def_bonus", 0),
	]
	if BattleRules.preview_enabled and u.team == "player":
		for j in host.units.size():
			var e = host.units[j]
			if e.team == "enemy" and e.char.hp > 0 and host._manhattan(u.pos, e.pos) <= 2:
				var ex = {"flank": BattleRules.has_flank(u.pos, e.pos, host.units, "player", host.selected)}
				var pv = BattleRules.preview(c, e.char, host.terrain[e.pos.y][e.pos.x], ex)
				var tagjoin = "·".join(pv.tags) if pv.tags else ""
				txt += Locale.t("shell_f29bbf0a") % [
					e.char.name, pv.hit, pv.dmg.x, pv.dmg.y, pv.crit,
					(" 〔" + tagjoin + "〕") if tagjoin else "",
				]
	host.info_label.text = txt
