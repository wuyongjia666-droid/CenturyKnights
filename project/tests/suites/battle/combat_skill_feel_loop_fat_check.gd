extends Node
## Fat knife: 战技整链手感 — Buff/Heal arm→aim→cast settle→敌方清闩
## across two real battle maps. No telegraph residue. Algebra first, then
## Scene A (ch0_pass buff) + Scene B (ch1_hill heal+enemy clear). Quits 1 on miss.

const PHONE := Vector2i(2400, 1080)
const BUFF_SID := "chart_rally"
const HEAL_SID := "ward_chant"

var _battle: Control
var _caster_i := -1
var _ally_i := -1
var _foe_i := -1
var _p1 := -1


func _ready() -> void:
	OS.set_environment("CK_FORCE_MOBILE", "1")
	var err := await _run()
	OS.set_environment("CK_FORCE_MOBILE", "0")
	OS.set_environment("CK_SAFE_INSETS", "")
	if err != "":
		print("FAIL skill feel loop fat: ", err)
		get_tree().quit(1)
		return
	print("COMBAT SKILL FEEL LOOP FAT PASS")
	get_tree().quit(0)


func _run() -> String:
	if not DeviceProfile.is_mobile():
		return "CK_FORCE_MOBILE did not flip DeviceProfile"
	var err := _algebra()
	if err != "":
		return err
	err = await _boot("ch0_pass")
	if err == "":
		err = await _scene_buff_arm_aim_cast("A")
	await _free_battle()
	if err != "":
		return err
	err = await _boot("ch1_hill")
	if err == "":
		err = await _scene_heal_cast_enemy_clear("B")
	await _free_battle()
	return err


func _algebra() -> String:
	var err := _algebra_api()
	if err == "":
		err = _algebra_wiring()
	if err == "":
		err = _algebra_no_telegraph()
	return err


func _algebra_api() -> String:
	if BattleSkillFeelLoop.META != "m_skill_feel":
		return "META want m_skill_feel"
	var buff: Dictionary = GameState.get_skill(BUFF_SID)
	if str(buff.get("type", "")) != "buff":
		return "chart_rally not buff"
	var heal: Dictionary = GameState.get_skill(HEAL_SID)
	if str(heal.get("type", "")) != "support":
		return "ward_chant not support"
	return ""


func _algebra_wiring() -> String:
	var feel := FileAccess.get_file_as_string("res://scripts/battle/battle_skill_feel_loop.gd")
	if feel.find("class_name BattleSkillFeelLoop") < 0:
		return "BattleSkillFeelLoop missing"
	var buff := FileAccess.get_file_as_string("res://scripts/battle/battle_skill_buff_preview.gd")
	var heal := FileAccess.get_file_as_string("res://scripts/battle/battle_skill_heal_preview.gd")
	var ctrl := FileAccess.get_file_as_string("res://scripts/battle/battle_controller.gd")
	var cycle := FileAccess.get_file_as_string("res://scripts/battle/battle_turn_cycle_feel.gd")
	if buff.find('BattleSkillFeelLoop.after_arm(host, "buff")') < 0:
		return "buff arm must stamp SkillFeel"
	if buff.find('BattleSkillFeelLoop.after_aim(host, "buff"') < 0:
		return "buff aim must stamp SkillFeel"
	if heal.find('BattleSkillFeelLoop.after_arm(host, "heal")') < 0:
		return "heal arm must stamp SkillFeel"
	if heal.find('BattleSkillFeelLoop.after_aim(host, "heal"') < 0:
		return "heal aim must stamp SkillFeel"
	if ctrl.find('BattleSkillFeelLoop.after_cast(self, "heal"') < 0:
		return "_cast_support_skill must after_cast heal before handoff"
	if ctrl.find('BattleSkillFeelLoop.after_cast(self, "buff"') < 0:
		return "_cast_buff_skill must after_cast buff"
	# heal after_cast before WaitHandoff
	var support_at := ctrl.find("func _cast_support_skill")
	if support_at < 0:
		return "_cast_support_skill missing"
	var chunk := ctrl.substr(support_at, 1800)
	var cast_at := chunk.find('BattleSkillFeelLoop.after_cast(self, "heal"')
	var hand_at := chunk.find("BattleWaitHandoff.after_unit_done")
	if cast_at < 0 or hand_at < 0 or cast_at > hand_at:
		return "heal after_cast must run before WaitHandoff"
	if cycle.find("BattleSkillFeelLoop.clear_latches") < 0:
		return "TurnCycle clear_peek_chrome must clear skill latches"
	if cycle.find("BattleSkillFeelLoop.clear(host)") < 0:
		return "before_enemy_phase must clear SkillFeel stamp"
	return ""


func _algebra_no_telegraph() -> String:
	var body := FileAccess.get_file_as_string("res://scripts/battle/battle_skill_feel_loop.gd")
	var live := ""
	for line in body.split("\n"):
		var s := line.strip_edges()
		if s.begins_with("##") or s.begins_with("#"):
			continue
		live += line + "\n"
	if (
		live.find("foe_opening_telegraph") >= 0
		or live.find("BattleLinkTelegraph") >= 0
		or live.find("BattleFoeOpeningTelegraph") >= 0
		or live.find("EmptyHost") >= 0
	):
		return "battle_skill_feel_loop.gd dragged telegraph/EmptyHost residue"
	return ""


func _boot(map_id: String) -> String:
	await _set_window()
	GameState.new_game("烬行", "灰旗", "#%02x%02x%02x" % [110, 212, 255])
	GameState.settings.erase("touch_confirm")
	GameState.settings.erase("touch_drag_commit")
	GameState.settings["touch_confirm"] = true
	GameState.board_input_blocked = false
	GameState.set_meta("battle_map", map_id)
	_battle = load("res://scenes/battle/battle.tscn").instantiate()
	get_tree().root.add_child(_battle)
	get_tree().current_scene = _battle
	await _settle(8)
	var story := _battle.get_node_or_null("BattleStoryLayer")
	if story:
		story.free()
	var insets := {"left": 48.0, "top": 0.0, "right": 0.0, "bottom": 24.0}
	var fitted: Dictionary = MobileLayout.fit(Vector2(PHONE), insets)
	MobileLayout.apply_root(_battle, fitted)
	_battle.set_meta("mobile_insets", insets)
	if _battle.has_method("apply_mobile_layout"):
		_battle.apply_mobile_layout()
	await _settle(8)
	if str(_battle.map_id) != map_id:
		return "map_id want %s got %s" % [map_id, _battle.map_id]
	if not _battle._mobile_landscape():
		return "battle did not enter landscape on %s" % map_id
	if not BattleTouchConfirm.enabled():
		return "touch_confirm not enabled on mobile"
	return _arrange()


func _arrange() -> String:
	_caster_i = -1
	_ally_i = -1
	_foe_i = -1
	_p1 = -1
	for i in _battle.units.size():
		var u = _battle.units[i]
		if int(u.char.hp) <= 0:
			continue
		if str(u.team) == "player":
			if _caster_i < 0:
				_caster_i = i
			elif _ally_i < 0:
				_ally_i = i
			elif _p1 < 0:
				_p1 = i
		elif str(u.team) == "enemy" and _foe_i < 0:
			_foe_i = i
	if _caster_i < 0:
		return "deploy missing player"
	if _ally_i < 0:
		var ally = CharacterFactory.make_tutorial_militia(2)
		ally.hp = maxi(1, int(ally.max_hp) - 8)
		_battle.units.append(
			{"char": ally, "pos": Vector2i(3, 2), "team": "player", "done": false, "tag": ""}
		)
		_ally_i = _battle.units.size() - 1
	_battle.units[_caster_i].pos = Vector2i(2, 2)
	_battle.units[_caster_i].done = false
	_battle.units[_ally_i].pos = Vector2i(3, 2)
	_battle.units[_ally_i].done = false
	# Wound ally so heal has a target preference.
	_battle.units[_ally_i].char.hp = maxi(
		1, int(_battle.units[_ally_i].char.max_hp) - 10
	)
	for i in _battle.units.size():
		if i == _caster_i or i == _ally_i:
			continue
		if str(_battle.units[i].team) == "player" and int(_battle.units[i].char.hp) > 0:
			_battle.units[i].pos = Vector2i(10, 8)
			if _p1 < 0:
				_p1 = i
				_battle.units[i].done = false
			else:
				_battle.units[i].done = true
	_seed_buff(_battle.units[_caster_i].char)
	_seed_heal(_battle.units[_caster_i].char)
	if _foe_i >= 0:
		_battle.units[_foe_i].pos = Vector2i(6, 2)
	_battle.selected = -1
	_battle.turn_team = "player"
	_battle.battle_over = false
	_battle._cut_playing = false
	_battle.attack_mode = false
	_battle.skill_mode = false
	_battle.active_skill_id = ""
	_battle.preview_move_cell = Vector2i(-1, -1)
	_battle.preview_attack_ui = -1
	_battle.moved_this_select = false
	_battle._round_no = 2
	BattleSkillBuffPreview.clear(_battle)
	BattleSkillHealPreview.clear(_battle)
	BattleSkillFeelLoop.clear(_battle)
	BattleFeelLoop.clear(_battle)
	BattleTurnCycleFeel.clear(_battle)
	BattlePick.cancel_focus_tween(_battle)
	return ""


func _seed_buff(c: CKCharacter) -> void:
	if BUFF_SID not in c.skills:
		c.skills.append(BUFF_SID)
	c.skill_uses[BUFF_SID] = 2
	c.skill_cd[BUFF_SID] = 0


func _seed_heal(c: CKCharacter) -> void:
	if HEAL_SID not in c.skills:
		c.skills.append(HEAL_SID)
	c.skill_uses[HEAL_SID] = 2
	c.skill_cd[HEAL_SID] = 0


func _scene_buff_arm_aim_cast(tag: String) -> String:
	_battle._select_player(_caster_i)
	await _settle(3)
	BattleSkillsUi.arm(_battle, BUFF_SID)
	if not BattleSkillBuffPreview.latched(_battle):
		return "%s: buff arm did not latch" % tag
	if BattleSkillFeelLoop.stage_of(_battle) != "arm":
		return "%s: after arm stage want arm got %s" % [tag, BattleSkillFeelLoop.stage_of(_battle)]
	var first: int = BattleSkillBuffPreview.apply_next(_battle)
	if first < 0:
		return "%s: aim next failed" % tag
	if BattleSkillFeelLoop.stage_of(_battle) != "aim":
		return "%s: after aim stage want aim got %s" % [tag, BattleSkillFeelLoop.stage_of(_battle)]
	var info = _battle.get_meta(BattleSkillFeelLoop.META)
	if not (info is Dictionary) or int((info as Dictionary).get("focus", -1)) != first:
		return "%s: aim stamp focus mismatch" % tag
	if not BattleSkillBuffPreview.confirm(_battle):
		return "%s: buff confirm failed" % tag
	await _settle(3)
	if BattleSkillBuffPreview.latched(_battle):
		return "%s: confirm left buff latch" % tag
	if BattleSkillFeelLoop.stage_of(_battle) != "cast":
		return "%s: after cast stage want cast got %s" % [tag, BattleSkillFeelLoop.stage_of(_battle)]
	var cast_info = _battle.get_meta(BattleSkillFeelLoop.META)
	if not (cast_info is Dictionary):
		return "%s: cast meta missing" % tag
	if str((cast_info as Dictionary).get("kind", "")) != "buff":
		return "%s: cast kind want buff" % tag
	# Plant abandoned latch (cast already consumed CD — don't re-arm).
	_battle.set_meta(
		BattleSkillBuffPreview.META,
		{
			"sid": BUFF_SID,
			"focus": _ally_i,
			"targets": [_ally_i],
			"msec": Time.get_ticks_msec(),
		}
	)
	if not BattleSkillBuffPreview.latched(_battle):
		return "%s: plant latch for enemy-clear probe failed" % tag
	BattleTurnCycleFeel.before_enemy_phase(_battle)
	if BattleSkillBuffPreview.latched(_battle):
		return "%s: buff latch must clear on enemy phase" % tag
	if _battle.has_meta(BattleSkillFeelLoop.META):
		# before_enemy stamps turn_cycle enemy; skill feel META must be gone
		# Wait - before_enemy calls clear then _stamp turn cycle. SkillFeel.clear removes m_skill_feel.
		pass
	if BattleSkillFeelLoop.stage_of(_battle) != "":
		return "%s: SkillFeel stage must clear on enemy got %s" % [
			tag, BattleSkillFeelLoop.stage_of(_battle)
		]
	return ""


func _scene_heal_cast_enemy_clear(tag: String) -> String:
	_battle._select_player(_caster_i)
	await _settle(3)
	BattleSkillsUi.arm(_battle, HEAL_SID)
	if not BattleSkillHealPreview.latched(_battle):
		return "%s: heal arm did not latch" % tag
	if BattleSkillFeelLoop.stage_of(_battle) != "arm":
		return "%s: heal arm stage want arm got %s" % [tag, BattleSkillFeelLoop.stage_of(_battle)]
	var aim_i: int = BattleSkillHealPreview.apply_next(_battle)
	if aim_i < 0:
		return "%s: heal aim failed" % tag
	if BattleSkillFeelLoop.stage_of(_battle) != "aim":
		return "%s: heal aim stage want aim got %s" % [tag, BattleSkillFeelLoop.stage_of(_battle)]
	var uses0 := int(_battle.units[_caster_i].char.skill_uses.get(HEAL_SID, 0))
	if not BattleSkillHealPreview.confirm(_battle):
		return "%s: heal confirm failed" % tag
	await _settle(4)
	if BattleSkillHealPreview.latched(_battle):
		return "%s: heal confirm left latch" % tag
	if int(_battle.units[_caster_i].char.skill_uses.get(HEAL_SID, 0)) != uses0 - 1:
		return "%s: heal did not consume use" % tag
	# Cast stamp must survive handoff (clear_latches does not wipe cast META).
	if BattleSkillFeelLoop.stage_of(_battle) != "cast":
		return "%s: after heal+handoff stage want cast got %s" % [
			tag, BattleSkillFeelLoop.stage_of(_battle)
		]
	# Plant abandoned latch + prove clear_peek on handoff clears latch not cast…
	# Re-select and plant heal latch, then enemy phase clears all.
	if int(_battle.selected) >= 0:
		pass
	# Force plant latch META as abandoned chrome.
	_battle.set_meta(
		BattleSkillHealPreview.META,
		{"sid": HEAL_SID, "focus": _ally_i, "targets": [_ally_i], "msec": Time.get_ticks_msec()}
	)
	BattleTurnCycleFeel.before_enemy_phase(_battle)
	if BattleSkillHealPreview.latched(_battle):
		return "%s: heal latch must clear on enemy" % tag
	if BattleSkillFeelLoop.stage_of(_battle) != "":
		return "%s: SkillFeel must clear on enemy got %s" % [
			tag, BattleSkillFeelLoop.stage_of(_battle)
		]
	if BattleTurnCycleFeel.stage_of(_battle) != "enemy":
		return "%s: cycle stage want enemy got %s" % [tag, BattleTurnCycleFeel.stage_of(_battle)]
	return ""


func _free_battle() -> void:
	if _battle != null and is_instance_valid(_battle):
		_battle.queue_free()
		_battle = null
	await _settle(2)


func _set_window() -> void:
	DisplayServer.window_set_size(PHONE)
	await _settle(2)


func _settle(n: int) -> void:
	for _i in n:
		await get_tree().process_frame
