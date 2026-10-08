extends Node
## BTL-02: every objective type reaches a win and a loss. Reinforcements
## arrive on their turn and never on an occupied cell. The objective strip
## stays inside the 1080x2400 safe rect.

const VIEW := Vector2(1080, 2400)
const INSETS := {"left": 0.0, "top": 96.0, "right": 0.0, "bottom": 72.0}

var _battle


func _ready() -> void:
	await get_tree().process_frame
	var err := await _run()
	if err != "":
		print("FAIL objectives: ", err)
		get_tree().quit(1)
		return
	print("OBJECTIVES PASS")
	get_tree().quit(0)


func _run() -> String:
	GameState.new_game("探针", "灰旗", "#" + "6ED4FF")
	var leader: CKCharacter = GameState.get_leader()
	if leader == null or not leader.is_leader:
		return "roster has no leader"
	var old := BattleMaps.get_map("ch0_pass")
	if str(BattleObjectives.spec(old).get("type", "")) != "rout":
		return "ch0_pass is not rout"
	if old.has("objective"):
		return "ch0_pass gained an objective field"
	GameState.set_meta("battle_map", "obj_rout")
	var packed: PackedScene = load("res://scenes/battle/battle.tscn")
	_battle = packed.instantiate()
	add_child(_battle)
	_battle.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_battle.size = Vector2(1280, 720)
	await get_tree().process_frame
	await get_tree().process_frame
	if str(_battle.map_id) != "obj_rout":
		return "did not load obj_rout (%s)" % _battle.map_id
	if _battle.battle_over:
		return "rout ended before anyone fell"
	var hud: Node = _battle.get_node_or_null("ObjectiveHud")
	if hud == null:
		return "missing objective hud"
	var title := hud.get_node_or_null("Row/Title") as Label
	if title == null or title.text != BattleObjectives.text("obj_rout"):
		return "rout title %s" % (title.text if title else "null")

	var err := _expect_win("rout")
	if err != "":
		return err
	_restart("obj_rout")
	err = _expect_loss("wipe")
	if err != "":
		return err

	err = _click_win("obj_seize", Vector2i(1, 3), "seize")
	if err != "":
		return err
	_restart("obj_seize")
	err = _expect_loss("wipe")
	if err != "":
		return err

	err = _defend_win()
	if err != "":
		return err
	err = _defend_timeout()
	if err != "":
		return err

	_restart("obj_survive")
	if _battle.battle_over:
		return "survive won on turn 1"
	_battle._start_player_turn()
	err = _verdict(true, "survive")
	if err != "":
		return err
	_restart("obj_survive")
	err = _expect_loss("wipe")
	if err != "":
		return err

	err = _escort_win()
	if err != "":
		return err
	_restart("obj_escort")
	err = _kill_tag("guide", "vip_down")
	if err != "":
		return err

	err = _boss_win()
	if err != "":
		return err
	_restart("obj_boss")
	err = _expect_loss("wipe")
	if err != "":
		return err

	err = _click_win("obj_escape", Vector2i(1, 3), "escape")
	if err != "":
		return err
	_restart("obj_escape")
	err = _expect_loss("wipe")
	if err != "":
		return err

	err = _protect_win()
	if err != "":
		return err
	_restart("obj_protect")
	err = _kill_tag("vip", "vip_down")
	if err != "":
		return err

	err = _leader_loss()
	if err != "":
		return err
	err = _reinf()
	if err != "":
		return err
	err = _trigger()
	if err != "":
		return err

	_restart("ch0_pass")
	if str(BattleObjectives.spec(BattleMaps.get_map("ch0_pass")).get("type", "")) != "rout":
		return "restarted ch0 is not rout"
	if _battle.battle_over:
		return "ch0 ended at deploy"
	_kill_team("enemy")
	_battle._check_end()
	err = _verdict(true, "rout")
	if err != "":
		return "ch0 " + err

	err = await _safe_hud()
	if err != "":
		return err
	await _save_shot()
	return ""


func _restart(map_id: String) -> void:
	_battle.battle_over = false
	_battle._round_no = 0
	if _battle.has_meta("reinf_done"):
		_battle.remove_meta("reinf_done")
	if _battle.has_meta("battle_verdict"):
		_battle.remove_meta("battle_verdict")
	GameState.set_meta("battle_map", map_id)
	_battle._init_map()
	_battle._deploy()
	_battle._start_player_turn()


func _expect_win(reason: String) -> String:
	_kill_team("enemy")
	_battle._check_end()
	return _verdict(true, reason)


func _expect_loss(reason: String) -> String:
	_kill_team("player")
	_battle._check_end()
	return _verdict(false, reason)


func _kill_team(team: String) -> void:
	for u in _battle.units:
		if str(u.team) == team:
			u.char.hp = 0


func _kill_tag(tag: String, reason: String) -> String:
	var found := false
	for u in _battle.units:
		if str(u.get("tag", "")) == tag:
			u.char.hp = 0
			found = true
	if not found:
		return "no tag %s" % tag
	_battle._check_end()
	return _verdict(false, reason)


func _verdict(win: bool, reason: String) -> String:
	if bool(_battle.battle_over) != true:
		return "battle still running want %s/%s" % [win, reason]
	var got = _battle.get_meta("battle_verdict", {})
	if bool(got.get("result", "") == "win") != win:
		return "result %s want win=%s" % [got, win]
	if str(got.get("reason", "")) != reason:
		return "reason %s want %s" % [got.get("reason", ""), reason]
	return ""


func _click_win(map_id: String, tile: Vector2i, reason: String) -> String:
	_restart(map_id)
	if _battle.battle_over:
		return "%s already over" % map_id
	var ui := _player_index()
	if ui < 0:
		return "%s has no player" % map_id
	_battle._select_player(ui)
	if not _battle.move_cells.has(tile):
		return "%s cannot reach %s" % [map_id, tile]
	_battle._click_cell(tile)
	if _battle.units[ui].pos != tile:
		return "%s did not step to %s" % [map_id, tile]
	return _verdict(true, reason)


func _defend_win() -> String:
	_restart("obj_defend")
	for u in _battle.units:
		if str(u.team) == "player":
			u.pos = Vector2i(0, 2)
	_battle._start_player_turn()
	return _verdict(true, "defend")


func _defend_timeout() -> String:
	_restart("obj_defend")
	for _i in 6:
		if _battle.battle_over:
			break
		_battle._start_player_turn()
	return _verdict(false, "turn_limit")


func _escort_win() -> String:
	_restart("obj_escort")
	var moved := false
	for u in _battle.units:
		if str(u.get("tag", "")) == "guide":
			u.pos = Vector2i(5, 2)
			moved = true
	if not moved:
		return "escort npc missing"
	_battle._check_end()
	var err := _verdict(true, "escort")
	if err != "":
		return err
	if _count("enemy") < 1:
		return "escort required the enemy to die"
	return ""


func _boss_win() -> String:
	_restart("obj_boss")
	var found := false
	for u in _battle.units:
		if str(u.get("tag", "")) == "chief":
			u.char.hp = 0
			found = true
	if not found:
		return "boss tag missing"
	_battle._check_end()
	var err := _verdict(true, "boss")
	if err != "":
		return err
	if _count("enemy") < 1:
		return "boss win cleared the other enemy"
	return ""


func _protect_win() -> String:
	_restart("obj_protect")
	if _count("ally") < 1:
		return "protect vip was not deployed"
	_kill_team("enemy")
	_battle._check_end()
	return _verdict(true, "protect")


func _leader_loss() -> String:
	_restart("obj_leader")
	var buddy := CKCharacter.new()
	buddy.id = "obj_buddy"
	buddy.name = "灯侧"
	buddy.job_id = "light_inf"
	buddy.is_leader = false
	buddy.stats = {"str": 5, "vit": 5, "skl": 5, "agi": 5, "per": 5, "wil": 5}
	buddy.recalc_hp()
	buddy.hp = buddy.max_hp
	_battle.units.append({"char": buddy, "pos": Vector2i(2, 3), "team": "player", "done": false, "tag": ""})
	var cut := false
	for u in _battle.units:
		if str(u.team) == "player" and u.char.is_leader:
			u.char.hp = 0
			cut = true
	if not cut:
		return "leader was not deployed"
	_battle._check_end()
	var err := _verdict(false, "leader_down")
	if err != "":
		return err
	if buddy.hp <= 0:
		return "buddy died with the leader"
	return ""


func _reinf() -> String:
	_restart("obj_reinf")
	var before := _count("enemy")
	if before != 1:
		return "reinf start enemies %d" % before
	var occupied := Vector2i(0, 3)
	var blocked := false
	for u in _battle.units:
		if str(u.team) == "player" and u.pos == occupied and u.char.hp > 0:
			blocked = true
	if not blocked:
		return "player is not standing on the reinforcement tile"
	_battle._start_player_turn()
	if _battle.battle_over:
		return "reinf battle ended on the reinforcement turn"
	if _count("enemy") != before + 2:
		return "reinf count %d from %d" % [_count("enemy"), before]
	var saw_open := false
	var saw_shifted := false
	for u in _battle.units:
		if str(u.team) != "enemy" or u.char.hp <= 0:
			continue
		if u.pos == occupied:
			return "reinforcement spawned on the occupied cell"
		if u.pos == Vector2i(5, 1):
			saw_open = true
		elif u.pos != Vector2i(5, 0):
			var dist := absi(u.pos.x - occupied.x) + absi(u.pos.y - occupied.y)
			if dist < 1 or dist > 3:
				return "shifted reinforcement distance %d at %s" % [dist, u.pos]
			saw_shifted = true
	if not saw_open or not saw_shifted:
		return "reinf placement open=%s shifted=%s" % [saw_open, saw_shifted]
	_battle._start_player_turn()
	if _count("enemy") != before + 2:
		return "reinf spawned twice"
	return ""


func _trigger() -> String:
	_restart("obj_trigger")
	var before := _count("enemy")
	_battle._start_player_turn()
	if _count("enemy") != before:
		return "trigger wave arrived without the tile"
	var ui := _player_index()
	_battle._select_player(ui)
	var tile := Vector2i(1, 3)
	if not _battle.move_cells.has(tile):
		return "trigger tile not reachable"
	_battle._click_cell(tile)
	if _count("enemy") != before + 1:
		return "trigger wave size %d" % _count("enemy")
	for u in _battle.units:
		if str(u.team) == "enemy" and u.pos == tile:
			return "trigger reinforcement used the player's cell"
	_battle._sync_objectives()
	if _count("enemy") != before + 1:
		return "trigger wave repeated"
	return ""


func _safe_hud() -> String:
	_restart("obj_seize")
	var fitted: Dictionary = MobileLayout.fit(VIEW, INSETS)
	var scale := float(fitted.get("scale", 1.0))
	var pos: Vector2 = fitted.get("position", Vector2.ZERO)
	_battle.set_meta("mobile_insets", INSETS)
	_battle.set_meta("mobile_origin", pos)
	_battle.scale = Vector2(scale, scale)
	await get_tree().process_frame
	ObjectiveHud.place(_battle)
	await get_tree().process_frame
	var hud := _battle.get_node("ObjectiveHud") as Control
	var rect := hud.get_global_rect()
	var safe := Rect2(float(INSETS.left), float(INSETS.top), VIEW.x - float(INSETS.left) - float(INSETS.right), VIEW.y - float(INSETS.top) - float(INSETS.bottom))
	if rect.size.y < 8.0:
		return "hud has no size"
	if not safe.encloses(rect):
		return "hud %s outside safe %s (root %s scale %s)" % [rect, safe, _battle.global_position, _battle.scale]
	_battle.set_meta("mobile_origin", Vector2.ZERO)
	_battle.scale = Vector2.ONE
	await get_tree().process_frame
	ObjectiveHud.place(_battle)
	await get_tree().process_frame
	rect = hud.get_global_rect()
	if rect.position.y + 0.5 < float(INSETS.top) + 8.0:
		return "uninset hud y %s under the notch" % rect.position.y
	return ""


func _save_shot() -> void:
	var vp := SubViewport.new()
	vp.name = "ObjectiveShot"
	vp.size = Vector2i(int(VIEW.x), int(VIEW.y))
	vp.disable_3d = true
	vp.transparent_bg = false
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(vp)
	var bg := ColorRect.new()
	bg.color = UIKit.BG
	bg.size = VIEW
	vp.add_child(bg)
	var fitted: Dictionary = MobileLayout.fit(VIEW, INSETS)
	var pos: Vector2 = fitted.get("position", Vector2.ZERO)
	var shot_scale := float(fitted.get("scale", 1.0))
	GameState.set_meta("battle_map", "obj_seize")
	var shot = load("res://scenes/battle/battle.tscn").instantiate()
	shot.anchor_left = 0.0
	shot.anchor_top = 0.0
	shot.anchor_right = 0.0
	shot.anchor_bottom = 0.0
	shot.set_meta("mobile_insets", INSETS)
	shot.set_meta("mobile_origin", pos)
	shot.scale = Vector2(shot_scale, shot_scale)
	vp.add_child(shot)
	await get_tree().process_frame
	ObjectiveHud.refresh(shot)
	var notch := ColorRect.new()
	notch.color = Color(UIKit.DANGER, 0.45)
	notch.position = Vector2.ZERO
	notch.size = Vector2(VIEW.x, float(INSETS.top))
	notch.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vp.add_child(notch)
	var chin := ColorRect.new()
	chin.color = Color(UIKit.DANGER, 0.45)
	chin.position = Vector2(0, VIEW.y - float(INSETS.bottom))
	chin.size = Vector2(VIEW.x, float(INSETS.bottom))
	chin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vp.add_child(chin)
	for _frame in 4:
		await get_tree().process_frame
	var img := vp.get_texture().get_image()
	DirAccess.make_dir_recursive_absolute("/opt/cursor/artifacts")
	var path := "/opt/cursor/artifacts/btl02_objective_hud_1080x2400.png"
	if img == null:
		print("objective hud shot skipped: no image")
		return
	var save_err := img.save_png(path)
	print("objective hud shot %s size=%s err=%s" % [path, img.get_size(), save_err])


func _player_index() -> int:
	for i in _battle.units.size():
		if str(_battle.units[i].team) == "player" and _battle.units[i].char.hp > 0:
			return i
	return -1


func _count(team: String) -> int:
	var n := 0
	for u in _battle.units:
		if str(u.team) == team and u.char.hp > 0:
			n += 1
	return n
