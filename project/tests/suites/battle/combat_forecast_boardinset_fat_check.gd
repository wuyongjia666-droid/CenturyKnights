extends Node
## Fat knife: ForecastPanel park shares BattleBoardInset (notch + info + edge,
## reserve_top 0) with range keep / confirm settle / focus. Algebra → Scene A
## (ch0_pass) → Scene B (ch1_hill). No telegraph residue.

const PHONE := Vector2i(2400, 1080)
const NOTCH := "400,0,0,48"

var _battle: Control
var _player_i := -1
var _foe_i := -1


func _ready() -> void:
	OS.set_environment("CK_FORCE_MOBILE", "1")
	OS.set_environment("CK_SAFE_INSETS", NOTCH)
	var err := await _run()
	OS.set_environment("CK_FORCE_MOBILE", "0")
	OS.set_environment("CK_SAFE_INSETS", "")
	if err != "":
		print("FAIL forecast BoardInset fat: ", err)
		get_tree().quit(1)
		return
	print("COMBAT FORECAST BOARDINSET FAT PASS")
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
	var err := _algebra_sources()
	if err != "":
		return err
	return _algebra_slot()


func _algebra_sources() -> String:
	var panel_src := FileAccess.get_file_as_string("res://scripts/battle/ui/forecast_panel.gd")
	if panel_src.find("forecast_place_bounds") < 0:
		return "ForecastPanel._place must use forecast_place_bounds"
	if panel_src.find("BattleCombatFrame.forecast_slot(stage") >= 0:
		return "ForecastPanel still parks against raw stage var"
	var place_i := panel_src.find("static func _place")
	if place_i < 0:
		return "ForecastPanel._place missing"
	var place_body := panel_src.substr(place_i, 900)
	if place_body.find("forecast_place_bounds") < 0:
		return "_place body must call forecast_place_bounds"
	if place_body.find("forecast_slot(bounds") < 0:
		return "_place must feed BoardInset bounds into forecast_slot"
	var frame := FileAccess.get_file_as_string("res://scripts/battle/battle_combat_frame.gd")
	if frame.find("static func forecast_place_bounds") < 0:
		return "CombatFrame.forecast_place_bounds missing"
	var bounds_i := frame.find("static func forecast_place_bounds")
	var bounds_body := frame.substr(bounds_i, 500)
	if bounds_body.find("BattleBoardInset.for_host") < 0:
		return "forecast_place_bounds must call BoardInset.for_host"
	if bounds_body.find("0.0") < 0:
		return "forecast_place_bounds must pass reserve_top 0.0"
	var inset := FileAccess.get_file_as_string("res://scripts/battle/battle_board_inset.gd")
	if inset.find("ForecastPanel") < 0:
		return "BoardInset header must mention ForecastPanel park"
	if inset.find("clip_notch") < 0:
		return "BoardInset must still clip_notch"
	for path in [
		"res://scripts/battle/ui/forecast_panel.gd",
		"res://scripts/battle/battle_combat_frame.gd",
		"res://scripts/battle/battle_board_inset.gd",
	]:
		var body := FileAccess.get_file_as_string(path)
		if body.find("foe_opening_telegraph") >= 0 or body.find("BattleLinkTelegraph") >= 0:
			return "%s dragged telegraph residue" % path
	return ""


func _algebra_slot() -> String:
	# Pure algebra: BoardInset-shrunk bounds shift the slot vs raw stage.
	var stage := Rect2(0, 0, 900, 500)
	var bi := Rect2(80, 40, 520, 400)
	var sz := Vector2(300, 140)
	var mid := Vector2(100, 200)
	var slot_raw := BattleCombatFrame.forecast_slot(stage, sz, mid)
	var slot_bi := BattleCombatFrame.forecast_slot(bi, sz, mid)
	if absf(slot_raw.x - slot_bi.x) < 8.0 and absf(slot_raw.y - slot_bi.y) < 8.0:
		return "forecast_slot BoardInset should shift park vs raw stage"
	var panel_rect := Rect2(slot_bi, sz)
	if not bi.encloses(panel_rect.grow(-0.5)):
		return "forecast_slot escaped BoardInset bounds %s in %s" % [panel_rect, bi]
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
			u.pos = Vector2i(4, 3)
			u.done = false
		elif str(u.team) == "enemy" and _foe_i < 0:
			_foe_i = i
			u.pos = Vector2i(6, 3)
			u.char.hp = maxi(int(u.char.hp), 16)
		elif str(u.team) == "player":
			u.done = true
	if _player_i < 0 or _foe_i < 0:
		return "deploy missing player/enemy"
	_plain_box(Vector2i(4, 3), 4)
	_battle.selected = -1
	_battle.turn_team = "player"
	_battle.battle_over = false
	_battle._cut_playing = false
	_battle.attack_mode = false
	_battle.skill_mode = false
	_battle.preview_move_cell = Vector2i(-1, -1)
	_battle.preview_attack_ui = -1
	_battle.moved_this_select = false
	BattlePick.cancel_focus_tween(_battle)
	return ""


func _scene(tag: String) -> String:
	var err := _assert_layout(tag)
	if err != "":
		return err
	return await _assert_forecast_shares(tag)


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
	var bounds := BattleCombatFrame.forecast_place_bounds(_battle)
	if (
		absf(bounds.position.x - shared.position.x) > 1.0
		or absf(bounds.size.x - shared.size.x) > 1.0
	):
		return "%s: forecast_place_bounds != BoardInset (%s vs %s)" % [tag, bounds, shared]
	return ""


func _assert_forecast_shares(tag: String) -> String:
	_battle.selected = _player_i
	_battle.preview_attack_ui = _foe_i
	_battle.attack_mode = true
	# Park pair toward the info column / past the notch so a raw-stage park
	# would collide; BoardInset park must stay clear.
	var stage: Rect2 = _stage()
	_battle._board_pan = Vector2(-stage.size.x * 0.45, stage.size.y * 0.15)
	if _battle.has_method("_clamp_board_pan"):
		_battle._clamp_board_pan()
	if _battle.has_method("_apply_board_xform"):
		_battle._apply_board_xform()
	BattlePick.cancel_focus_tween(_battle)
	await _settle(2)
	ForecastPanel.refresh(_battle)
	# Finish any follow_attack tween so the panel re-place is stable.
	_finish_focus_tween()
	ForecastPanel.refresh(_battle)
	await _settle(2)
	var panel := _battle.get_node_or_null("ForecastPanel") as Control
	if panel == null or not panel.visible:
		return "%s: ForecastPanel not visible after attack preview" % tag
	var body := panel.get_node_or_null("Cols/Ours/Body") as Label
	if body == null or body.text.find("%") < 0:
		return "%s: forecast chip missing hit rate" % tag
	var live: Rect2 = BattleBoardInset.for_host(_battle, 0.0)
	var prect := Rect2(panel.position, panel.size)
	# Panel must sit inside BoardInset (small grow for float/rounding).
	var clipped := live.intersection(prect)
	if clipped.size.x < prect.size.x - 2.0 or clipped.size.y < prect.size.y - 2.0:
		return "%s: ForecastPanel outside BoardInset panel=%s inset=%s" % [tag, prect, live]
	var block: Rect2 = _battle.get_meta("m_info_block")
	if block.size.x > 1.0:
		var overlap: Rect2 = prect.intersection(block)
		if overlap.size.x > 8.0 and overlap.size.y > 8.0:
			return "%s: ForecastPanel overlaps info panel=%s block=%s" % [tag, prect, block]
	# Notch: left edge of panel must not sit left of BoardInset lip when lip live.
	if live.position.x > stage.position.x + 24.0 and panel.position.x + 0.5 < live.position.x:
		return "%s: ForecastPanel left of notch lip panel=%s inset=%s" % [tag, prect, live]
	# Must not cover either fighter's figure centre.
	for cell in [_battle.units[_player_i].pos, _battle.units[_foe_i].pos]:
		var fig := BattleCombatFrame.figure_rect(
			_battle.ORIGIN, float(_battle.CELL), cell, _battle._board_pan, _battle._board_zoom
		)
		if prect.grow(-4.0).has_point(fig.get_center()):
			return (
				"%s: ForecastPanel covers fighter at %s fig=%s panel=%s" % [tag, cell, fig, prect]
			)
	# Raw-stage slot would differ when BoardInset cuts — prove live park used inset.
	var raw_slot := BattleCombatFrame.forecast_slot(
		stage, panel.size, BattleCombatFrame.pair_mid_shown(_battle)
	)
	if absf(raw_slot.x - panel.position.x) < 1.0 and absf(raw_slot.y - panel.position.y) < 1.0:
		# Only fail when BoardInset actually differs from stage enough to move the slot.
		var bi_slot := BattleCombatFrame.forecast_slot(
			live, panel.size, BattleCombatFrame.pair_mid_shown(_battle)
		)
		if absf(raw_slot.x - bi_slot.x) > 8.0 or absf(raw_slot.y - bi_slot.y) > 8.0:
			return (
				"%s: ForecastPanel still parked on raw stage pos=%s raw=%s bi=%s"
				% [tag, panel.position, raw_slot, bi_slot]
			)
	_battle.attack_mode = false
	_battle.preview_attack_ui = -1
	ForecastPanel.refresh(_battle)
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
