extends Node
## Fat knife #2：战棋反馈音层整链 — 选中→确认→命中/暴击/击破→胜负 事件钩与 #736 juice 同拍。
## 对齐 #732 pcm_v1（samples+rms，禁 OGG 字节比对）。禁换 BGM / 无钩堆 wav / telegraph。

const PHONE := Vector2i(2400, 1080)
const DESK := Vector2i(1600, 900)
const NOTCH := "400,0,0,48"
const MARKER := "COMBAT SFX LAYER FAT PASS"
const MAP_ID := "quest_bandit"
const SHOT_DIR := "user://combat_sfx_layer_shots"
const BATTLE_SCN := preload("res://scenes/battle/battle.tscn")
const NEED_EVENTS := ["select", "confirm_move", "confirm_attack", "hit", "crit", "kill", "win", "lose"]

var _battle: Control
var _player_i := -1
var _foe_i := -1
var _surface := "desktop"
var _shot_n := 0


func _ready() -> void:
	var err := await _run()
	OS.set_environment("CK_FORCE_MOBILE", "0")
	OS.set_environment("CK_SAFE_INSETS", "")
	Engine.time_scale = 1.0
	if err != "":
		print("FAIL combat sfx layer fat: ", err)
		get_tree().quit(1)
		return
	print(MARKER)
	get_tree().quit(0)


func _run() -> String:
	var err := _algebra()
	if err != "":
		return err
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SHOT_DIR))
	for surface in ["desktop", "mobile"]:
		_surface = surface
		err = await _boot(MAP_ID)
		if err == "":
			err = await _scene_attack_chain("chain-%s" % surface)
		await _free_battle()
		if err != "":
			return err
	return ""


func _algebra() -> String:
	var err := _algebra_api()
	if err == "":
		err = _algebra_wiring()
	if err == "":
		err = _algebra_pcm_v1()
	if err == "":
		err = _algebra_no_surface()
	if err == "":
		err = _algebra_emit_unit()
	return err


func _algebra_api() -> String:
	if BattleCombatSfx.META_LAST != "m_combat_sfx":
		return "META_LAST"
	if BattleCombatSfx.HALF_BEAT_MSEC > 250:
		return "half-beat window too loose"
	var layer_err := BattleCombatSfx.assert_layers_ordered()
	if layer_err != "":
		return layer_err
	for ev in NEED_EVENTS:
		if BattleCombatSfx.sfx_id_for(ev) == "":
			return "sfx id empty for %s" % ev
		if BattleCombatSfx.volume_for(ev) > 0.0:
			return "volumes should be attenuations for %s" % ev
	if BattleCombatSfx.layer_for("select") != "ui":
		return "select layer"
	if BattleCombatSfx.layer_for("hit") != "hit":
		return "hit layer"
	if BattleCombatSfx.layer_for("win") != "settle":
		return "win layer"
	if BattleCombatSfx.bus_for_event("select") != "UI":
		return "select must route UI bus"
	if BattleCombatSfx.bus_for_event("hit") != "SFX":
		return "hit must route SFX bus"
	if BattleCombatSfx.bus_for_event("win") != "SFX":
		return "win must route SFX bus"
	var body := FileAccess.get_file_as_string("res://scripts/battle/battle_combat_sfx.gd")
	for fn in [
		"static func emit",
		"static func on_select",
		"static func on_confirm",
		"static func on_settle",
		"static func on_result",
		"static func within_half_beat",
		"static func play_log",
	]:
		if body.find(fn) < 0:
			return "%s missing" % fn
	if body.find("Music.play") >= 0 or body.find("play_battle") >= 0:
		return "CombatSfx must not swap BGM"
	return ""


func _algebra_wiring() -> String:
	var juice := FileAccess.get_file_as_string("res://scripts/battle/battle_rematch_juice.gd")
	if juice.find("BattleCombatSfx.on_settle") < 0:
		return "RematchJuice.after_attack_hit must call CombatSfx.on_settle (same event)"
	var feel := FileAccess.get_file_as_string("res://scripts/battle/battle_feel_loop.gd")
	if feel.find("BattleCombatSfx.on_select") < 0:
		return "FeelLoop.after_select must emit select SFX"
	var touch := FileAccess.get_file_as_string("res://scripts/battle/battle_touch_confirm.gd")
	if touch.find("BattleCombatSfx.on_confirm(host, \"move\")") < 0:
		return "confirm_move must emit confirm SFX"
	if touch.find("BattleCombatSfx.on_confirm(host, \"attack\")") < 0:
		return "confirm_attack must emit confirm SFX"
	var ctrl := FileAccess.get_file_as_string("res://scripts/battle/battle_controller.gd")
	if ctrl.find("BattleCombatSfx.on_result(self, true)") < 0:
		return "_finish win must go through CombatSfx"
	if ctrl.find("BattleCombatSfx.on_result(self, false)") < 0:
		return "_finish lose must go through CombatSfx"
	# Strike SFX owned by settle hook — no pre-juice duplicates.
	var atk_i := ctrl.find("func _resolve_strike(")
	if atk_i < 0:
		atk_i = ctrl.find("func _do_attack(")
	if atk_i < 0:
		return "strike fn missing"
	var nxt := ctrl.find("\nfunc ", atk_i + 8)
	if nxt < 0:
		nxt = atk_i + 4000
	var body := ctrl.substr(atk_i, nxt - atk_i)
	if body.find("Sfx.play_weapon(") >= 0:
		return "strike must not pre-play weapon before juice settle SFX"
	if body.find("Sfx.crit()") >= 0:
		return "strike must not pre-play crit before juice settle SFX"
	if body.find("Sfx.miss()") >= 0:
		return "strike must not pre-play miss before juice settle SFX"
	if body.find("BattleRematchJuice.after_attack_hit") < 0:
		return "strike must still deepen via RematchJuice"
	return ""


func _algebra_pcm_v1() -> String:
	## Align #732: catalog verify=pcm_v1; engine gate is samples+rms, never OGG bytes.
	var cat_path := "res://assets/sfx/catalog_v92.json"
	if not FileAccess.file_exists(cat_path):
		return "sfx catalog missing"
	var cat: Variant = JSON.parse_string(FileAccess.get_file_as_string(cat_path))
	if typeof(cat) != TYPE_DICTIONARY:
		return "sfx catalog parse"
	if str((cat as Dictionary).get("verify", "")) != "pcm_v1":
		return "catalog verify must stay pcm_v1 (#732)"
	var project_root := ProjectSettings.globalize_path("res://").rstrip("/")
	var repo := project_root.get_base_dir()
	var eng_abs := repo.path_join("tools/audio/engine.py")
	var sfx_abs := repo.path_join("tools/audio/sfx_v92.py")
	if not FileAccess.file_exists(eng_abs):
		return "audio engine.py missing at %s" % eng_abs
	if not FileAccess.file_exists(sfx_abs):
		return "sfx_v92.py missing at %s" % sfx_abs
	var engine := FileAccess.get_file_as_string(eng_abs)
	if engine.find("fingerprints_match") < 0:
		return "audio engine missing fingerprints_match"
	if engine.find("samples") < 0 or engine.find("rms_db") < 0:
		return "engine must compare samples+rms_db"
	var sfx_py := FileAccess.get_file_as_string(sfx_abs)
	if sfx_py.find("pcm_v1") < 0:
		return "sfx_v92 must declare pcm_v1"
	var combat := FileAccess.get_file_as_string("res://scripts/battle/battle_combat_sfx.gd")
	if combat.find("sha256") >= 0 or combat.find("byte_equal") >= 0:
		return "CombatSfx must not OGG-byte-compare"
	var out: Array = []
	var code := OS.execute("python3", [sfx_abs, "--verify"], out, true)
	var text := ""
	for line in out:
		text += str(line) + "\n"
	if code != 0 or text.find("SFX VERIFY PASS") < 0:
		return "sfx_v92 --verify failed (#732) code=%s %s" % [code, text.right(400)]
	return ""


func _algebra_no_surface() -> String:
	for path in [
		"res://scripts/battle/battle_combat_sfx.gd",
		"res://scripts/battle/battle_rematch_juice.gd",
	]:
		var body := FileAccess.get_file_as_string(path)
		var live := ""
		for line in body.split("\n"):
			var s := line.strip_edges()
			if s.begins_with("#"):
				continue
			live += line + "\n"
		if (
			live.find("foe_opening_telegraph") >= 0
			or live.find("BattleLinkTelegraph") >= 0
			or live.find("EmptyHost") >= 0
		):
			return "%s dragged telegraph/EmptyHost" % path
	return ""


func _algebra_emit_unit() -> String:
	BattleCombatSfx.clear_log()
	var host := Node.new()
	host.name = "CombatSfxUnitHost"
	add_child(host)
	BattleCombatSfx.on_select(host)
	BattleCombatSfx.on_confirm(host, "move")
	BattleCombatSfx.on_confirm(host, "attack")
	# Simulate juice stamp then settle (same-event contract).
	host.set_meta(
		BattleRematchJuice.META_HIT,
		{"kind": "hit", "cell": Vector2i(1, 1), "msec": Time.get_ticks_msec(), "weight": "mid"}
	)
	var hit_row := BattleCombatSfx.on_settle(host, "hit")
	if not BattleCombatSfx.within_half_beat(int(hit_row.get("msec", 0)), int(hit_row.get("juice_msec", -99999))):
		host.queue_free()
		return "unit hit desync beyond half-beat"
	host.set_meta(
		BattleRematchJuice.META_HIT,
		{"kind": "crit", "cell": Vector2i(1, 1), "msec": Time.get_ticks_msec(), "weight": "mid"}
	)
	BattleCombatSfx.on_settle(host, "crit")
	host.set_meta(
		BattleRematchJuice.META_HIT,
		{"kind": "kill", "cell": Vector2i(1, 1), "msec": Time.get_ticks_msec(), "weight": "heavy"}
	)
	BattleCombatSfx.on_settle(host, "kill")
	BattleCombatSfx.on_result(host, true)
	BattleCombatSfx.on_result(host, false)
	var seen := BattleCombatSfx.events_seen()
	for ev in NEED_EVENTS:
		if not Array(seen).has(ev):
			host.queue_free()
			return "unit emit missing event %s in %s" % [ev, seen]
	# Volumes layered: last select quieter than last hit quieter than last kill/win
	var sel := BattleCombatSfx.last_for("select")
	var hit := BattleCombatSfx.last_for("hit")
	var kill := BattleCombatSfx.last_for("kill")
	var win := BattleCombatSfx.last_for("win")
	if float(sel.get("vol", 0)) >= float(hit.get("vol", 0)):
		host.queue_free()
		return "select vol must be quieter than hit"
	if float(hit.get("vol", 0)) >= float(kill.get("vol", 0)):
		host.queue_free()
		return "hit vol must be quieter than kill"
	if float(kill.get("vol", 0)) > float(win.get("vol", 0)):
		host.queue_free()
		return "kill should not dwarf win settle"
	BattleCombatSfx.clear_log()
	host.queue_free()
	return ""


func _boot(map_id: String) -> String:
	if _surface == "mobile":
		OS.set_environment("CK_FORCE_MOBILE", "1")
		OS.set_environment("CK_SAFE_INSETS", NOTCH)
	else:
		OS.set_environment("CK_FORCE_MOBILE", "0")
		OS.set_environment("CK_SAFE_INSETS", "")
	await _set_window()
	GameState.new_game("音层", "灰旗", "#" + "6ED4FF")
	GameState.settings["touch_confirm"] = true
	GameState.settings["reduced_motion"] = false
	GameState.settings["cutscenes"] = false
	GameState.set_meta("cutscenes_on", false)
	GameState.board_input_blocked = false
	GameState.set_meta("battle_map", map_id)
	GameState.set_meta("battle_return", "res://scenes/hub/castle_hub.tscn")
	GameState.set_meta("battle_sortie", true)
	if GameState.has_meta("battle_return_chapter"):
		GameState.remove_meta("battle_return_chapter")
	if GameState.has_meta(BattleRematchJuice.META_ROUND):
		GameState.remove_meta(BattleRematchJuice.META_ROUND)
	_battle = BATTLE_SCN.instantiate()
	add_child(_battle)
	await _settle(8)
	var story := _battle.get_node_or_null("BattleStoryLayer")
	if story:
		story.free()
	if _surface == "mobile":
		var insets := {"left": 48.0, "top": 0.0, "right": 0.0, "bottom": 24.0}
		var fitted: Dictionary = MobileLayout.fit(Vector2(PHONE), insets)
		MobileLayout.apply_root(_battle, fitted)
		_battle.set_meta("mobile_insets", insets)
		if _battle.has_method("apply_mobile_layout"):
			_battle.apply_mobile_layout()
		await _settle(8)
		if not _battle._mobile_landscape():
			return "battle did not enter landscape"
	else:
		await _settle(4)
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
			u.pos = Vector2i(3, 3)
			u.done = false
			u.has_struck = false
		elif str(u.team) == "enemy" and _foe_i < 0:
			_foe_i = i
			u.pos = Vector2i(4, 3)
			u.done = false
		elif str(u.team) == "player":
			u.done = true
	if _player_i < 0 or _foe_i < 0:
		return "deploy need player+foe"
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
	_battle.danger_on = false
	_battle.danger_focus = -1
	_battle._round_no = 2
	_battle._world_enc = false
	BattleFeelLoop.clear(_battle)
	BattleRematchJuice.clear_hit(_battle)
	BattleCombatSfx.clear_log()
	BattlePick.cancel_focus_tween(_battle)
	return ""


func _scene_attack_chain(tag: String) -> String:
	# 1) select
	_battle._select_player(_player_i)
	await _settle(2)
	if BattleCombatSfx.last_for("select").is_empty():
		return "%s select SFX event missing" % tag
	if not _battle.has_meta(BattleCombatSfx.META_LAST):
		return "%s select meta missing" % tag
	# 2) confirm move (preview → commit). Stay put so attack range to foe is preserved.
	var mover = _battle.units[_player_i]
	var dest: Vector2i = mover.pos
	_battle.preview_move_cell = dest
	_battle.move_cells.clear()
	_battle.move_cells[dest] = 1
	BattleTouchConfirm.confirm_move(_battle)
	await _settle(2)
	if BattleCombatSfx.last_for("confirm_move").is_empty():
		return "%s confirm_move SFX missing" % tag
	# 3) confirm attack → resolve strike (juice + settle SFX same event)
	_battle.selected = _player_i
	_battle.units[_player_i].done = false
	_battle.units[_player_i].has_struck = false
	_battle.preview_attack_ui = _foe_i
	_battle.units[_player_i].char.temp_hit_bonus = 100
	# Keep foe alive for a hit event first.
	_battle.units[_foe_i].char.hp = maxi(12, int(_battle.units[_foe_i].char.hp))
	BattleTouchConfirm.confirm_attack(_battle)
	await _settle(3)
	if BattleCombatSfx.last_for("confirm_attack").is_empty():
		return "%s confirm_attack SFX missing" % tag
	var hit_row := BattleCombatSfx.last_for("hit")
	var crit_row := BattleCombatSfx.last_for("crit")
	var kill_row := BattleCombatSfx.last_for("kill")
	if hit_row.is_empty() and crit_row.is_empty() and kill_row.is_empty():
		return "%s settle hit/crit/kill SFX missing after confirm_attack" % tag
	var settle_row: Dictionary = hit_row if not hit_row.is_empty() else (crit_row if not crit_row.is_empty() else kill_row)
	if not _battle.has_meta(BattleRematchJuice.META_HIT):
		return "%s juice meta missing — SFX must share juice event" % tag
	var juice: Dictionary = _battle.get_meta(BattleRematchJuice.META_HIT)
	var juice_msec := int(juice.get("msec", -1))
	var sfx_msec := int(settle_row.get("msec", -1))
	if not BattleCombatSfx.within_half_beat(sfx_msec, juice_msec):
		return "%s SFX desync %dms > half-beat (sfx=%d juice=%d)" % [tag, absi(sfx_msec - juice_msec), sfx_msec, juice_msec]
	await _shot("%s-hit" % tag)
	# Force crit settle path (algebra already covered emit; runtime force via on_settle after juice stamp).
	BattleRematchJuice.after_attack_hit(_battle, "crit", _battle.units[_foe_i].pos)
	await _settle(1)
	if BattleCombatSfx.last_for("crit").is_empty():
		return "%s crit settle SFX missing" % tag
	var crit2 := BattleCombatSfx.last_for("crit")
	if not BattleCombatSfx.within_half_beat(int(crit2.get("msec", 0)), int(crit2.get("juice_msec", -99999))):
		return "%s crit desync" % tag
	# Force kill / 击破
	BattleRematchJuice.after_attack_hit(_battle, "kill", _battle.units[_foe_i].pos)
	await _settle(1)
	if BattleCombatSfx.last_for("kill").is_empty():
		return "%s kill/break settle SFX missing" % tag
	# 4) win
	_battle.battle_over = false
	for u in _battle.units:
		if str(u.team) == "enemy":
			u.char.hp = 0
	_battle._finish(true)
	await _settle(4)
	if BattleCombatSfx.last_for("win").is_empty():
		return "%s win SFX missing" % tag
	await _shot("%s-win" % tag)
	# 5) lose on fresh finish path
	_battle.battle_over = false
	BattleCombatSfx.clear_log()  # keep lose assert clean; prior events already proven
	# Re-seed required earlier events for full-chain log on this surface? Spec: full attack chain asserts key hooks — already asserted above. Lose separately:
	_battle._finish(false)
	await _settle(3)
	if BattleCombatSfx.last_for("lose").is_empty():
		return "%s lose SFX missing" % tag
	await _shot("%s-lose" % tag)
	# Playing players exist for key ids (event→play call)
	for pair in [["select", "ui_click"], ["hit", "hit"], ["crit", "crit"], ["kill", "drum_thump"], ["win", "win"], ["lose", "lose"]]:
		var id := str(pair[1])
		var p: AudioStreamPlayer = Sfx.get_node_or_null(id) as AudioStreamPlayer
		if p == null or p.stream == null:
			return "%s missing stream for %s" % [tag, id]
		var want_bus := "UI" if id.begins_with("ui_") else "SFX"
		if p.bus != want_bus:
			return "%s bus for %s want %s got %s" % [tag, id, want_bus, p.bus]
	Engine.time_scale = 1.0
	return ""


func _set_window() -> void:
	var sz := PHONE if _surface == "mobile" else DESK
	DisplayServer.window_set_size(sz)
	await _settle(2)


func _settle(frames: int) -> void:
	for _i in frames:
		await get_tree().process_frame


func _free_battle() -> void:
	if _battle != null and is_instance_valid(_battle):
		_battle.queue_free()
		_battle = null
	await _settle(2)


func _shot(tag: String) -> void:
	_shot_n += 1
	var path := "%s/%02d-%s.png" % [SHOT_DIR, _shot_n, tag]
	await get_tree().process_frame
	var img: Image = get_viewport().get_texture().get_image()
	if img != null:
		img.save_png(path)
		print("shot %s size=%s" % [path, img.get_size()])
