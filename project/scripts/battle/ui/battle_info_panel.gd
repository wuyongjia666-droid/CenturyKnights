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
	host.info_label.text = "[b]%s[/b]（%s·%s） HP %d/%d\n攻 %d 防 %d\n地形：%s（回避+%d 防+%d）\n（仍选中我军，可继续移动/攻击）" % [
		c.name, "我军" if u.team == "player" else "敌军", role2,
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
		host.info_label.text = "[b]选择己方单位开始行动[/b]\n目标：歼灭全部敌人。\n蓝格可移动 · 红格为可攻目标 · 攻击模式后点敌。"
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
			mode = "[color=#e07070]【攻击模式】点击红格敌人[/color]\n"
		elif host.moved_this_select:
			mode = "[color=#c9a227]【已移动】可攻击 / 待命[/color]\n"
		else:
			mode = "[color=#6db0e0]【已选中】点击蓝格移动，或开攻击模式[/color]\n"
	var role = BattleRules.role_label(BattleRules.job_role(c.job_id))
	var foes = host._enemy_positions(u.team)
	var engaged = BattleRules.is_engaged(u.pos, foes)
	var locked = int(c.temp_combat_lock) > 0
	var eng := BattleRules.engagement_note(locked, engaged, c.temp_leave_free, c.temp_ignore_zoc)
	var txt = mode + eng + "[b]%s[/b]（%s·%s） HP %d/%d\n攻 %d 防 %d 命中 %d 回避 %d 移动 %d\n地形：%s（回避+%d 防+%d）\n" % [
		c.name, "我军" if u.team == "player" else "敌军", role,
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
				txt += "透视→%s：命中 %d%% 伤害 %d–%d 暴%d%%%s\n" % [
					e.char.name, pv.hit, pv.dmg.x, pv.dmg.y, pv.crit,
					(" 〔" + tagjoin + "〕") if tagjoin else "",
				]
	host.info_label.text = txt
