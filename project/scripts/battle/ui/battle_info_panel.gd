class_name BattleInfoPanel
extends RefCounted
## Selected-unit intel panel. Extracted from the battle controller in BTL-01.


static func refresh_for(host, ui: int) -> void:
	if ui < 0 or ui >= host.units.size():
		refresh(host)
		return
	var u = host.units[ui]
	var c: CKCharacter = u.char
	host._portrait.texture = UnitArt.unit_portrait(c)
	_sync_status(host, c)
	_sync_card(host, c, str(u.team))
	fill_traits(host, c)
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
		host.info_label.text = _idle_objective(host)
		if GameState.get_leader():
			host._portrait.texture = UnitArt.unit_portrait(GameState.get_leader())
			_sync_status(host, GameState.get_leader())
			_sync_card(host, GameState.get_leader(), "player")
			fill_traits(host, GameState.get_leader())
		else:
			host._portrait.texture = CKHeraldryChrome.company_banner(96, 96)
			_sync_status(host, null)
			_sync_card(host, null, "player")
			fill_traits(host, null)
		BattleSelectChrome.reveal_landscape(host)
		return
	var u = host.units[host.selected]
	var c: CKCharacter = u.char
	host._portrait.texture = UnitArt.unit_portrait(c)
	_sync_status(host, c)
	_sync_card(host, c, str(u.team))
	fill_traits(host, c)
	var tid = host.terrain[u.pos.y][u.pos.x]
	var tinfo = BattleRules.terrain_info(tid)
	var mode := ""
	if u.team == "player" and not u.done:
		var atk_ui := int(host.preview_attack_ui)
		var move_cell: Vector2i = host.preview_move_cell
		if atk_ui >= 0 and atk_ui < host.units.size():
			var foe_name := str(host.units[atk_ui].char.name)
			mode = BattleRules._rich(Frost.swatch("enemy"), Locale.t("ux_confirm_dest_attack") % foe_name)
		elif move_cell.x >= 0:
			mode = BattleRules._rich(Frost.swatch("ally"), Locale.t("ux_confirm_dest_move") % [move_cell.x, move_cell.y])
		elif host.attack_mode:
			mode = BattleRules._rich(Frost.swatch("enemy"), Locale.t("shell_64295185"))
		elif host.moved_this_select:
			mode = BattleRules._rich(Frost.swatch("ally"), Locale.t("shell_8736b101"))
		else:
			mode = BattleRules._rich(Frost.swatch("ally"), Locale.t("shell_31067370"))
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
	BattleSelectChrome.reveal_landscape(host)



static func _idle_objective(host) -> String:
	## E-03: blank-state goal line follows BattleObjectives, not a hard-coded rout string.
	var map_id := str(host.get("map_id") if host.get("map_id") != null else "")
	var units = host.get("units") if host.get("units") != null else []
	var round_no := int(host.get("_round_no") if host.get("_round_no") != null else 1)
	var info := BattleObjectives.summary(BattleMaps.get_map(map_id), units, maxi(1, round_no))
	var goal := str(info.get("title", BattleObjectives.text("obj_rout")))
	var remain := str(info.get("remain", ""))
	var body := Locale.t("shell_obj_idle") % goal
	if remain != "":
		body += "\n" + remain
	return body


static func _sync_card(host, c, team: String) -> void:
	if host._unit_card == null:
		return
	host._unit_card.set_meta("foe_nation", CKHeraldryChrome.battle_foe_nation_for(host))
	if c == null:
		host._unit_card.set_unit(null, team)
	else:
		host._unit_card.set_unit(c, team)


static func _sync_status(host, c) -> void:
	if host._portrait == null:
		return
	var parent := host._portrait.get_parent() as Control
	if parent != null:
		CKPortraitStatus.attach(parent, c, host._portrait.size)
