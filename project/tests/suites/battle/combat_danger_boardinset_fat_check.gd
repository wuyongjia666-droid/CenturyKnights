extends Node
## Fat knife: danger focus settle refreshes m_info_block then shares
## BattleBoardInset (notch + info + edge, reserve_top 0) — no stale side-col.
## Algebra → Scene A (ch0_pass) → Scene B (ch1_hill). No telegraph residue.

const PHONE := Vector2i(2400, 1080)
const NOTCH := "400,0,0,48"

var _battle: Control
var _player_i := -1
var _foe_i := -1
var _stand := Vector2i(-1, -1)
var _near := Vector2i(-1, -1)


func _ready() -> void:
	OS.set_environment("CK_FORCE_MOBILE", "1")
	OS.set_environment("CK_SAFE_INSETS", NOTCH)
	var err := await _run()
	OS.set_environment("CK_FORCE_MOBILE", "0")
	OS.set_environment("CK_SAFE_INSETS", "")
	if err != "":
		print("FAIL danger BoardInset fat: ", err)
		get_tree().quit(1)
		return
	print("COMBAT DANGER BOARDINSET FAT PASS")
	get_tree().quit(0)


func _run() -> String:
	if not DeviceProfile.is_mobile():
		return "CK_FORCE_MOBILE did not flip DeviceProfile"
	var err := _algebra()
	if err != "":
		return err
	err = await _boot("ch0_pass")
	if err == "":
		err = await _scene("A")
	await _free_battle()
	if err != "":
		return err
	err = await _boot("ch1_hill")
	if err == "":
		err = await _scene("B")
	await _free_battle()
	return err


func _algebra() -> String:
	var path := "res://scripts/battle/ui/battle_danger_feel.gd"
	var body := FileAccess.get_file_as_string(path)
	if body.find("BattleBoardInset.refresh_info_block") < 0:
		return "%s missing BattleBoardInset.refresh_info_block" % path
	if body.find("m_info_block") < 0 or body.find("follow_cells") < 0:
		return "%s missing m_info_block refresh or follow_cells" % path
	var i := 0
	while true:
		var hit := body.find("follow_cells(", i)
		if hit < 0:
			break
		var slice := body.substr(hit, 120)
		if slice.find("0.0") < 0:
			return "%s follow_cells must pass reserve_top 0.0 got %s" % [path, slice]
		i = hit + 12
	var ref_i := body.find("BattleBoardInset.refresh_info_block(host)")
	var fol_i := body.find("follow_cells(host, cells, 0.0)")
	if ref_i < 0 or fol_i < 0 or ref_i > fol_i:
		return "%s must refresh m_info_block before follow_cells" % path
	if (
		body.find("foe_opening_telegraph") >= 0
		or body.find("BattleLinkTelegraph") >= 0
		or body.find("telegraph") >= 0
		or body.find("Telegraph") >= 0
	):
		return "%s dragged telegraph residue" % path
	var inset := FileAccess.get_file_as_string("res://scripts/battle/battle_board_inset.gd")
	if inset.find("Danger focus") < 0 and inset.find("danger focus") < 0:
		return "BoardInset header must mention danger focus settle refresh"
	if inset.find("clip_notch") < 0:
		return "BoardInset must still clip_notch"
	if inset.find("foe_opening_telegraph") >= 0 or inset.find("BattleLinkTelegraph") >= 0:
		return "BoardInset dragged telegraph residue"
	var ctrl := FileAccess.get_file_as_string("res://scripts/battle/battle_controller.gd")
	if ctrl.find("BattleDangerFeel.after_set(self)") < 0:
		return "controller must settle danger via BattleDangerFeel.after_set"
	if ctrl.find("EmptyHost") >= 0 or body.find("EmptyHost") >= 0:
		return "EmptyHost theater forbidden"
	return ""


func _boot(map_id: String) -> String:
	await _set_window()
	OS.set_environment("CK_FORCE_MOBILE", "1")
	OS.set_environment("CK_SAFE_INSETS", NOTCH)
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
	var insets := {"left": 400.0, "top": 0.0, "right": 0.0, "bottom": 48.0}
	var fitted: Dictionary = MobileLayout.fit(Vector2(PHONE), insets)
	_battle.set_meta("mobile_origin", fitted.get("position", Vector2.ZERO))
	_battle.set_meta("mobile_insets", insets)
	MobileLayout.apply_root(_battle, fitted)
	if _battle.has_method("apply_mobile_layout"):
		_battle.apply_mobile_layout()
	await _settle(8)
	if _battle.has_method("apply_mobile_layout"):
		_battle.apply_mobile_layout()
	await _settle(4)
	BattleEdgePick.note_layout(_battle)
	await _settle(2)
	if str(_battle.map_id) != map_id:
		return "map_id want %s got %s" % [map_id, _battle.map_id]
	if not _battle._mobile_landscape():
		return "battle did not enter landscape on %s" % map_id
	return _arrange()


func _arrange() -> String:
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
		return "deploy missing player/enemy"
	var th: int = _battle.terrain.size()
	var tw: int = _battle.terrain[0].size() if th > 0 else 8
	_stand = Vector2i(mini(3, tw - 1), mini(2, th - 1))
	_near = Vector2i(mini(_stand.x + 1, tw - 1), _stand.y)
	if _near == _stand:
		_near = Vector2i(_stand.x, mini(_stand.y + 1, th - 1))
	# Foe stands; player sits in melee reach so danger cells include an ally.
	_battle.units[_foe_i].pos = _stand
	_battle.units[_foe_i].char.job_id = "light_inf"
	_battle.units[_foe_i].char.recalc_hp()
	_battle.units[_foe_i].char.hp = _battle.units[_foe_i].char.max_hp
	_battle.units[_player_i].pos = _near
	_battle.units[_player_i].done = false
	_battle.units[_player_i].char.hp = maxi(int(_battle.units[_player_i].char.hp), 10)
	for i in _battle.units.size():
		if i == _player_i or i == _foe_i:
			continue
		if str(_battle.units[i].team) == "player" and int(_battle.units[i].char.hp) > 0:
			_battle.units[i].pos = Vector2i(10, 8)
			_battle.units[i].done = true
		elif str(_battle.units[i].team) == "enemy" and int(_battle.units[i].char.hp) > 0:
			_battle.units[i].pos = Vector2i(11, 8)
	_plain_box(_stand, 3)
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
	_battle.move_cells = {}
	_battle.danger_on = false
	_battle.danger_focus = -1
	BattlePick.cancel_focus_tween(_battle)
	return ""


func _scene(tag: String) -> String:
	var err := _assert_layout(tag)
	if err != "":
		return err
	return await _assert_danger_follow(tag)


func _assert_layout(tag: String) -> String:
	if not _battle.has_meta("m_info_block"):
		return "%s: m_info_block missing" % tag
	var block: Rect2 = _battle.get_meta("m_info_block")
	if block.size.x < 40.0:
		return "%s: info block too thin %s" % [tag, block]
	if not _battle.has_meta("m_edge_band"):
		return "%s: m_edge_band missing" % tag
	var shared: Rect2 = BattleBoardInset.for_host(_battle, 0.0)
	if shared.size.x < 72.0:
		return "%s: BoardInset too small %s" % [tag, shared]
	var stage: Rect2 = _stage()
	var raw := BattleCombatFrame.play_inset(stage, 0.0, 0.0)
	if shared.position.x <= raw.position.x + 4.0 and shared.size.x >= raw.size.x - 4.0:
		if shared.end.x >= raw.end.x - 4.0:
			return "%s: BoardInset did not cut notch/info vs raw (%s vs %s)" % [tag, shared, raw]
	var banded := BattleBoardInset.for_host(
		_battle, BattleCombatFrame.forecast_band(DeviceProfile.is_mobile())
	)
	if banded.size.y >= shared.size.y - 1.0:
		return (
			"%s: forecast_band reserve should shrink BoardInset (%s vs %s)" % [tag, banded, shared]
		)
	return ""


func _assert_danger_follow(tag: String) -> String:
	# Stale the info block so refresh must rewrite it from MobileSideCol.
	_battle.set_meta("m_info_block", Rect2(0, 0, 8, 8))
	_battle._set_danger(true, _foe_i)
	_finish_focus_tween()
	await _settle(2)
	if not bool(_battle.danger_on) or int(_battle.danger_focus) != _foe_i:
		return "%s: danger not armed focus=%s on=%s" % [tag, _battle.danger_focus, _battle.danger_on]
	var block: Rect2 = _battle.get_meta("m_info_block")
	if block.size.x < 40.0:
		return "%s: danger follow left stale m_info_block %s" % [tag, block]
	var err := _assert_frame_meta("%s danger" % tag)
	_battle._set_danger(false, -1)
	BattlePick.cancel_focus_tween(_battle)
	return err


func _assert_frame_meta(tag: String) -> String:
	if not _battle.has_meta("m_combat_frame"):
		return "%s: m_combat_frame missing after follow" % tag
	var info = _battle.get_meta("m_combat_frame")
	if not info is Dictionary:
		return "%s: m_combat_frame not dict" % tag
	var reserve := float(info.get("reserve_top", -1.0))
	if absf(reserve) > 0.01:
		return "%s: reserve_top want 0 got %s" % [tag, reserve]
	var inset: Rect2 = info.get("inset", Rect2())
	var shared: Rect2 = BattleBoardInset.for_host(_battle, 0.0)
	if (
		absf(inset.position.x - shared.position.x) > 1.0
		or absf(inset.position.y - shared.position.y) > 1.0
		or absf(inset.size.x - shared.size.x) > 1.0
		or absf(inset.size.y - shared.size.y) > 1.0
	):
		return "%s: follow inset != BoardInset@0 (%s vs %s)" % [tag, inset, shared]
	var banded: Rect2 = BattleBoardInset.for_host(
		_battle, BattleCombatFrame.forecast_band(DeviceProfile.is_mobile())
	)
	if (
		absf(inset.size.y - banded.size.y) < 4.0
		and absf(inset.position.y - banded.position.y) < 4.0
	):
		return "%s: follow still looks like forecast-band inset %s" % [tag, inset]
	return ""


func _finish_focus_tween() -> void:
	if not _battle.has_meta("_ck_focus_tw"):
		return
	var tw = _battle.get_meta("_ck_focus_tw")
	if tw is Tween and is_instance_valid(tw):
		tw.custom_step(2.0)
	BattlePick.cancel_focus_tween(_battle)


func _stage() -> Rect2:
	if _battle.has_meta("m_board_area"):
		return _battle.get_meta("m_board_area")
	return _battle.BOARD_AREA


func _plain_box(center: Vector2i, rad: int) -> void:
	for y in range(center.y - rad, center.y + rad + 1):
		for x in range(center.x - rad, center.x + rad + 1):
			var cell := Vector2i(x, y)
			if not _battle._in_bounds(cell):
				continue
			_battle.terrain[cell.y][cell.x] = "plain"
			if cell.y >= 0 and cell.y < _battle.height_grid.size():
				var row: Array = _battle.height_grid[cell.y]
				if cell.x >= 0 and cell.x < row.size():
					row[cell.x] = 0


func _set_window() -> void:
	var win := get_tree().root
	win.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	win.size = PHONE
	DisplayServer.window_set_size(PHONE)
	await get_tree().process_frame
	await get_tree().process_frame


func _settle(n: int = 3) -> void:
	for i in n:
		await get_tree().process_frame


func _free_battle() -> void:
	if _battle != null and is_instance_valid(_battle):
		_battle.queue_free()
		_battle = null
	await _settle(4)
