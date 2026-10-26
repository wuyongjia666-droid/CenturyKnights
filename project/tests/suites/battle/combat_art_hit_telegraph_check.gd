extends Node
## Y1-A T-P42: armed art hit_mod telegraph. Real battle E2E.

const PHONE := Vector2i(2400, 1080)
const DESK := Vector2i(1280, 720)

var _battle: Control
var _player_i := -1
var _foe_i := -1


func _ready() -> void:
	var err := await _run()
	if err != "":
		print("FAIL art hit telegraph: ", err)
		get_tree().quit(1)
		return
	print("COMBAT ART HIT TELEGRAPH PASS")
	get_tree().quit(0)


func _run() -> String:
	var err := _source_contracts()
	if err != "":
		return err
	OS.set_environment("CK_FORCE_MOBILE", "1")
	if not DeviceProfile.is_mobile():
		return "CK_FORCE_MOBILE did not flip DeviceProfile"
	err = await _boot(true)
	if err == "":
		err = await _e2e()
	await _free_battle()
	OS.set_environment("CK_FORCE_MOBILE", "0")
	if err != "":
		return err
	err = await _boot(false)
	if err == "":
		err = await _e2e()
	await _free_battle()
	OS.set_environment("CK_FORCE_MOBILE", "0")
	return err


func _source_contracts() -> String:
	var ctrl := FileAccess.get_file_as_string("res://scripts/battle/battle_controller.gd")
	var touch := FileAccess.get_file_as_string("res://scripts/battle/battle_touch_confirm.gd")
	var tele := FileAccess.get_file_as_string("res://scripts/battle/battle_art_hit_telegraph.gd")
	var cast := FileAccess.get_file_as_string("res://scripts/battle/battle_skill_cast.gd")
	if ctrl.find("BattleArtHitTelegraph.draw(self, overlay)") < 0:
		return "controller missing art-hit draw"
	if ctrl.find("BattleArtHitTelegraph.refresh(self)") < 0:
		return "controller missing art-hit refresh"
	if touch.find("BattleArtHitTelegraph.clear(host)") < 0:
		return "touch clear missing art-hit clear"
	if touch.find("BattleArtHitTelegraph.refresh(host)") < 0:
		return "touch missing art-hit refresh"
	if ctrl.find("BattleSkillCast.support") < 0 or ctrl.find("BattleSkillCast.buff") < 0:
		return "controller must delegate support/buff to BattleSkillCast"
	if cast.find("static func support") < 0 or cast.find("static func buff") < 0:
		return "BattleSkillCast missing support/buff"
	if tele.find("shell_art_hit_up_mark") < 0 or tele.find("shell_art_hit_down_mark") < 0:
		return "art-hit mark keys missing"
	if tele.find("Locale.t(key)") < 0:
		return "art-hit mark must be Locale.t"
	if tele.find("EmptyHost") >= 0 or ctrl.find("EmptyHost") >= 0:
		return "EmptyHost theater forbidden"
	if ctrl.split("\n").size() > 3000:
		return "battle_controller over 3000 lines"
	for ch in tele:
		var o := ch.unicode_at(0)
		if o >= 0x4E00 and o <= 0x9FFF:
			return "art-hit telegraph has CJK literal"
	return ""


func _boot(mobile: bool) -> String:
	await _set_window(PHONE if mobile else DESK)
	GameState.new_game("烬行", "灰旗", "#%02x%02x%02x" % [110, 212, 255])
	GameState.set_meta("battle_map", "obj_rout")
	_battle = load("res://scenes/battle/battle.tscn").instantiate()
	get_tree().root.add_child(_battle)
	get_tree().current_scene = _battle
	await _settle(8)
	if not _battle.has_method("_click_cell") or not ("units" in _battle):
		return "battle controller script failed to attach"
	if mobile:
		var insets := {"left": 80.0, "top": 0.0, "right": 0.0, "bottom": 24.0}
		var fitted: Dictionary = MobileLayout.fit(Vector2(PHONE), insets)
		MobileLayout.apply_root(_battle, fitted)
		_battle.set_meta("mobile_insets", insets)
		if _battle.has_method("apply_mobile_layout"):
			_battle.apply_mobile_layout()
		await _settle(8)
	return _arrange()


func _arrange() -> String:
	_battle.turn_team = "player"
	_battle.battle_over = false
	_player_i = -1
	_foe_i = -1
	for i in _battle.units.size():
		var u = _battle.units[i]
		if int(u.char.hp) <= 0:
			continue
		if str(u.team) == "player" and _player_i < 0:
			_player_i = i
		elif str(u.team) == "enemy" and _foe_i < 0:
			_foe_i = i
	if _player_i < 0 or _foe_i < 0:
		return "deploy missing"
	var th: int = _battle.terrain.size()
	var tw: int = _battle.terrain[0].size() if th > 0 else 8
	var stand := Vector2i(mini(3, tw - 1), mini(2, th - 1))
	var near := Vector2i(mini(stand.x + 1, tw - 1), stand.y)
	if near == stand:
		near = Vector2i(stand.x, mini(stand.y + 1, th - 1))
	_battle.units[_player_i].pos = stand
	_battle.units[_player_i].done = false
	var pc = _battle.units[_player_i].char
	if not ("rush" in pc.skills):
		pc.skills.append("rush")
	pc.skill_uses["rush"] = 2
	pc.skill_cd["rush"] = 0
	_battle.units[_foe_i].pos = near
	_battle.units[_foe_i].char.hp = maxi(10, int(_battle.units[_foe_i].char.hp))
	_battle.selected = -1
	_battle.preview_move_cell = Vector2i(-1, -1)
	_battle.preview_attack_ui = -1
	_battle.attack_mode = false
	_battle.skill_mode = false
	_battle.active_skill_id = ""
	_battle.moved_this_select = false
	_battle.move_cells = {}
	BattlePick.cancel_focus_tween(_battle)
	return ""


func _e2e() -> String:
	_battle._select_player(_player_i)
	await _settle(3)
	BattleSkillsUi.arm(_battle, "rush")
	await _settle(3)
	if not bool(_battle.skill_mode) or str(_battle.active_skill_id) != "rush":
		return "arm rush failed"
	_battle.preview_attack_ui = _foe_i
	var hit := BattleArtHitTelegraph.refresh(_battle)
	if not hit or not BattleArtHitTelegraph.will_mark(_battle):
		return "expected art-hit telegraph on rush (+hit_mod)"
	if BattleArtHitTelegraph.hit_mod(_battle) <= 0:
		return "rush hit_mod should be > 0"
	if not _battle.has_meta(BattleArtHitTelegraph.META):
		return "art-hit meta missing"
	# switch to a negative hit_mod art
	var pc = _battle.units[_player_i].char
	if not ("power_strike" in pc.skills):
		pc.skills.append("power_strike")
	pc.skill_uses["power_strike"] = 1
	pc.skill_cd["power_strike"] = 0
	_battle.active_skill_id = "power_strike"
	_battle.skill_mode = true
	_battle.attack_mode = true
	_battle.preview_attack_ui = _foe_i
	var down := BattleArtHitTelegraph.refresh(_battle)
	if not down or BattleArtHitTelegraph.hit_mod(_battle) >= 0:
		return "power_strike should telegraph negative hit_mod"
	_battle.active_skill_id = ""
	_battle.skill_mode = false
	var no := BattleArtHitTelegraph.refresh(_battle)
	if no or BattleArtHitTelegraph.will_mark(_battle):
		return "should clear without armed art"
	if _battle.has_meta(BattleArtHitTelegraph.META):
		return "meta should clear"
	_battle.active_skill_id = "rush"
	_battle.skill_mode = true
	_battle.attack_mode = true
	_battle.preview_attack_ui = _foe_i
	BattleArtHitTelegraph.refresh(_battle)
	BattleTouchConfirm.clear(_battle)
	if _battle.has_meta(BattleArtHitTelegraph.META):
		return "touch clear should drop art-hit meta"
	return ""


func _set_window(size: Vector2i) -> void:
	DisplayServer.window_set_size(size)
	await get_tree().process_frame
	await get_tree().process_frame


func _settle(n: int) -> void:
	for _i in n:
		await get_tree().process_frame


func _free_battle() -> void:
	if _battle != null and is_instance_valid(_battle):
		_battle.queue_free()
		_battle = null
		await _settle(2)
