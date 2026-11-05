extends Node
## Fat knife: 战棋命中手感 + 再战闭环 — 清匪练习战 hit juice → 胜负再战/回堡。
## 桌面+手游 × quest_bandit 真 E2E。禁 telegraph / EmptyHost / 碎刀。

const PHONE := Vector2i(2400, 1080)
const DESK := Vector2i(1600, 900)
const NOTCH := "400,0,0,48"
const MARKER := "COMBAT REMATCH JUICE FAT PASS"
const MAP_ID := "quest_bandit"
const SHOT_DIR := "user://combat_rematch_juice_shots"
const BATTLE_SCN := preload("res://scenes/battle/battle.tscn")
const HUB_SCN := preload("res://scenes/hub/castle_hub.tscn")

var _battle: Control
var _player_i := -1
var _foe_i := -1
var _surface := "mobile"
var _shot_n := 0


func _ready() -> void:
	var err := await _run()
	OS.set_environment("CK_FORCE_MOBILE", "0")
	OS.set_environment("CK_SAFE_INSETS", "")
	Engine.time_scale = 1.0
	if err != "":
		print("FAIL rematch juice fat: ", err)
		get_tree().quit(1)
		return
	print(MARKER)
	get_tree().quit(0)


func _run() -> String:
	var err := _algebra()
	if err != "":
		return err
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SHOT_DIR))
	for surface in ["mobile", "desktop"]:
		_surface = surface
		err = await _boot(MAP_ID)
		if err == "":
			err = await _scene_hit_juice("hit-%s" % surface)
		if err == "":
			err = await _scene_win_rematch_and_reenter("win-%s" % surface)
		await _free_battle()
		if err != "":
			return err
		err = await _boot(MAP_ID)
		if err == "":
			err = await _scene_lose_then_hub("lose-%s" % surface)
		await _free_battle()
		if err != "":
			return err
	return ""


func _algebra() -> String:
	var err := _algebra_api()
	if err == "":
		err = _algebra_wiring()
	if err == "":
		err = _algebra_report()
	if err == "":
		err = _algebra_locale()
	if err == "":
		err = _algebra_no_telegraph()
	if err == "":
		err = _algebra_offers()
	return err


func _algebra_api() -> String:
	if BattleRematchJuice.META_HIT != "m_hit_juice":
		return "META_HIT want m_hit_juice"
	if BattleRematchJuice.META_REMATCH != "m_rematch_cta":
		return "META_REMATCH want m_rematch_cta"
	if BattleRematchJuice.hit_weight("kill") != "heavy":
		return "kill weight"
	if BattleRematchJuice.trauma_nudge("hit") < BattlePhaseFeel.settle_shake("hit"):
		return "trauma must deepen settle_shake"
	if BattleRematchJuice.trauma_nudge("kill") <= BattlePhaseFeel.settle_shake("kill"):
		return "kill trauma must deepen settle"
	var body := FileAccess.get_file_as_string("res://scripts/battle/battle_rematch_juice.gd")
	for fn in [
		"static func after_attack_hit",
		"static func kick_hit_stop",
		"static func offers_rematch",
		"static func do_rematch",
		"static func do_hub",
		"static func claim_rematch_drill",
		"static func draw_hit_pop",
		"static func pop_alpha",
		"static func handle_result_key",
	]:
		if body.find(fn) < 0:
			return "%s missing" % fn
	if body.find("CutsceneVfx.time_scale_for") < 0:
		return "hit-stop must reuse CutsceneVfx"
	if body.find("create_timer") < 0:
		return "hit-stop must use real-time timer"
	if body.find("randf") >= 0 or body.find("randi") >= 0:
		return "trauma must not use per-frame random"
	return ""


func _algebra_wiring() -> String:
	var ctrl := FileAccess.get_file_as_string("res://scripts/battle/battle_controller.gd")
	var atk_i := ctrl.find("func _resolve_strike(")
	if atk_i < 0:
		atk_i = ctrl.find("func _do_attack(")
	if atk_i < 0:
		return "_resolve_strike/_do_attack missing"
	var nxt := ctrl.find("\nfunc ", atk_i + 8)
	if nxt < 0:
		nxt = atk_i + 3500
	var body := ctrl.substr(atk_i, nxt - atk_i)
	if body.find("BattlePhaseFeel.note_attack_settle") < 0:
		return "strike must note_attack_settle"
	if body.find("BattleRematchJuice.after_attack_hit") < 0:
		return "strike must deepen via RematchJuice.after_attack_hit"
	if body.find("_shake = maxf(_shake, 0.28 if result.crit else 0.12)") >= 0:
		return "weak pre-settle shake must be removed"
	if ctrl.find("BattleRematchJuice.draw_hit_pop") < 0:
		return "overlay must draw_hit_pop"
	if ctrl.find("BattleRematchJuice.handle_result_key") < 0:
		return "keys must route handle_result_key"
	# Trauma decay on camera offset (not rigid/logic coords).
	if ctrl.find("_trauma = maxf(0.0, _trauma - delta") < 0:
		return "controller must decay trauma"
	if ctrl.find("sin(_shake_t") < 0:
		return "shake must use decaying sin trauma, not random offset"
	var fin_i := ctrl.find("func _finish(")
	if fin_i < 0:
		return "_finish missing"
	var fnxt := ctrl.find("\nfunc ", fin_i + 8)
	if fnxt < 0:
		fnxt = fin_i + 2000
	var fin := ctrl.substr(fin_i, fnxt - fin_i)
	if fin.find("BattleRematchJuice.claim_rematch_drill") < 0:
		return "_finish must claim rematch drill (no double purse)"
	return ""


func _algebra_report() -> String:
	var rep := FileAccess.get_file_as_string("res://scripts/battle/ui/battle_report.gd")
	if rep.find("BattleRematchJuice.offers_rematch") < 0:
		return "report must gate rematch CTA"
	if rep.find("BattleRematchJuice.do_rematch") < 0:
		return "report must wire do_rematch"
	if rep.find("BattleRematchJuice.do_hub") < 0:
		return "report must wire do_hub"
	if rep.find("RematchCta") < 0:
		return "report must name RematchCta"
	if rep.find("HubCta") < 0:
		return "report must name HubCta"
	return ""


func _algebra_locale() -> String:
	var csv := FileAccess.get_file_as_string("res://data/locale/battle.csv")
	if csv.find("battle_rematch_again") < 0:
		return "locale battle_rematch_again missing"
	if csv.find("再战一场") < 0:
		return "zh rematch copy missing"
	if csv.find("battle_return_hub") < 0:
		return "locale battle_return_hub missing"
	if csv.find("返回枢纽") < 0:
		return "zh hub copy missing"
	if Locale.t("battle_rematch_again") == "battle_rematch_again":
		return "Locale.t rematch unresolved"
	if Locale.t("battle_return_hub") == "battle_return_hub":
		return "Locale.t hub unresolved"
	return ""


func _algebra_no_telegraph() -> String:
	for path in [
		"res://scripts/battle/battle_rematch_juice.gd",
		"res://scripts/battle/ui/battle_report.gd",
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
			or live.find("BattleFoeOpeningTelegraph") >= 0
			or live.find("EmptyHost") >= 0
		):
			return "%s dragged telegraph/EmptyHost residue" % path
	return ""


func _algebra_offers() -> String:
	var host := _FakeHost.new()
	host._world_enc = false
	if GameState.has_meta("battle_return_chapter"):
		GameState.remove_meta("battle_return_chapter")
	if not BattleRematchJuice.offers_rematch(host, true):
		return "practice host should offer rematch"
	host._world_enc = true
	if BattleRematchJuice.offers_rematch(host, true):
		return "world_enc must not offer rematch"
	host._world_enc = false
	GameState.set_meta("battle_return_chapter", "cs01")
	if BattleRematchJuice.offers_rematch(host, false):
		return "chapter-owned must not offer rematch"
	GameState.remove_meta("battle_return_chapter")
	GameState.set_meta(BattleRematchJuice.META_ROUND, true)
	if not BattleRematchJuice.claim_rematch_drill():
		return "claim_rematch_drill should consume round"
	if BattleRematchJuice.claim_rematch_drill():
		return "claim_rematch_drill must be one-shot"
	return ""


func _boot(map_id: String) -> String:
	if _surface == "mobile":
		OS.set_environment("CK_FORCE_MOBILE", "1")
		OS.set_environment("CK_SAFE_INSETS", NOTCH)
	else:
		OS.set_environment("CK_FORCE_MOBILE", "0")
		OS.set_environment("CK_SAFE_INSETS", "")
	await _set_window()
	if _surface == "mobile" and not DeviceProfile.is_mobile():
		return "CK_FORCE_MOBILE did not flip DeviceProfile"
	if _surface == "desktop" and DeviceProfile.is_mobile():
		return "desktop surface still mobile"
	GameState.new_game("烬行", "灰旗", "#%02x%02x%02x" % [110, 212, 255])
	GameState.settings.erase("touch_confirm")
	GameState.settings.erase("touch_drag_commit")
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
	_battle = BATTLE_SCN.instantiate()
	get_tree().root.add_child(_battle)
	get_tree().current_scene = _battle
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
			return "battle did not enter landscape on %s" % map_id
	else:
		await _settle(4)
	if str(_battle.map_id) != map_id:
		return "map_id want %s got %s" % [map_id, _battle.map_id]
	return _arrange()



func _boot_rematch(map_id: String) -> String:
	# Same path as do_rematch → reload_current_scene: keep GameState, restamp sortie map.
	if _surface == "mobile":
		OS.set_environment("CK_FORCE_MOBILE", "1")
		OS.set_environment("CK_SAFE_INSETS", NOTCH)
	else:
		OS.set_environment("CK_FORCE_MOBILE", "0")
		OS.set_environment("CK_SAFE_INSETS", "")
	await _set_window()
	GameState.settings["touch_confirm"] = true
	GameState.settings["reduced_motion"] = false
	GameState.settings["cutscenes"] = false
	GameState.set_meta("cutscenes_on", false)
	GameState.board_input_blocked = false
	GameState.set_meta("battle_map", map_id)
	GameState.set_meta("battle_return", "res://scenes/hub/castle_hub.tscn")
	if not GameState.has_meta("battle_sortie"):
		GameState.set_meta("battle_sortie", true)
	_battle = BATTLE_SCN.instantiate()
	get_tree().root.add_child(_battle)
	get_tree().current_scene = _battle
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
			return "rematch battle did not enter landscape"
	else:
		await _settle(4)
	if str(_battle.map_id) != map_id:
		return "rematch map_id want %s got %s" % [map_id, _battle.map_id]
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
		return "deploy need player+foe on %s" % MAP_ID
	_battle.selected = _player_i
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
	_battle._shake = 0.0
	BattleFeelLoop.clear(_battle)
	BattleCancelFeelLoop.clear(_battle)
	BattleFeelCloseout.clear(_battle)
	BattleRematchJuice.clear_hit(_battle)
	if _battle.has_meta("m_settle_flash"):
		_battle.remove_meta("m_settle_flash")
	BattlePick.cancel_focus_tween(_battle)
	return ""


func _scene_hit_juice(tag: String) -> String:
	var atk = _battle.units[_player_i]
	var def = _battle.units[_foe_i]
	atk.char.temp_hit_bonus = 100
	def.char.hp = maxi(def.char.hp, 8)
	var hp_before := int(def.char.hp)
	# Single strike — full _do_attack can counter/follow-up and stamp a later miss over the hit pop.
	_battle._resolve_strike(_player_i, _foe_i, false, false)
	await _settle(3)
	# Layer 1: PhaseFeel settle flash
	if not _battle.has_meta("m_settle_flash"):
		return "%s missing settle flash after attack" % tag
	# Layer 2: RematchJuice meta (trauma + hit-stop stamped)
	if not _battle.has_meta(BattleRematchJuice.META_HIT):
		return "%s missing hit juice meta" % tag
	var juice: Dictionary = _battle.get_meta(BattleRematchJuice.META_HIT)
	var kind := str(juice.get("kind", ""))
	if kind != "hit" and kind != "crit" and kind != "kill":
		return "%s juice kind want hit/crit/kill got %s (hp %d→%d)" % [tag, kind, hp_before, int(def.char.hp)]
	var want := BattleRematchJuice.trauma_nudge(kind)
	var punch := maxf(float(_battle._shake), float(_battle._trauma) * 8.0)
	if punch + 0.001 < want * 0.35:
		return "%s trauma too weak punch=%.3f want~%.3f kind=%s" % [tag, punch, want, kind]
	# Layer 3: unit pop alpha live within POP_MSEC
	if BattleRematchJuice.pop_alpha(_battle) <= 0.0 and kind != "miss":
		return "%s hit pop alpha dead (want live pop)" % tag
	# Layer 4: damage numeral OR equivalent readable feedback (hp drop)
	var has_dmg := false
	for fx in _battle._dmg_fx:
		if float(fx.age) >= 0.0:
			has_dmg = true
			break
	var hp_dropped := int(def.char.hp) < hp_before
	if not has_dmg and not hp_dropped:
		return "%s missing damage numeral / hp feedback after hit" % tag
	if int(atk.char.hp) <= 0:
		return "%s attacker unexpectedly down" % tag
	# #729 touch confirm still on — contract not rolled back
	if not bool(GameState.settings.get("touch_confirm", false)):
		return "%s touch_confirm rolled back" % tag
	await _shot("%s-hit" % tag)
	Engine.time_scale = 1.0
	return ""


func _scene_win_rematch_and_reenter(tag: String) -> String:
	_battle.battle_over = false
	for u in _battle.units:
		if str(u.team) == "enemy":
			u.char.hp = 0
	_battle._finish(true)
	await _settle(6)
	var err := _assert_report_ctas(tag, true)
	if err != "":
		return err
	await _shot("%s-settle" % tag)
	# Rematch: stamp round, free, re-load battle scene — same as do_rematch (no title / no new_game).
	GameState.set_meta(BattleRematchJuice.META_ROUND, true)
	if not GameState.has_meta("battle_sortie"):
		GameState.set_meta("battle_sortie", true)
	GameState.set_meta("battle_map", MAP_ID)
	if str(GameState.get_meta("battle_map", "")) != MAP_ID:
		return "%s rematch must keep battle_map" % tag
	await _free_battle()
	err = await _boot_rematch(MAP_ID)
	if err != "":
		return "%s rematch reenter boot: %s" % [tag, err]
	err = _assert_rematch_board(tag)
	if err != "":
		return err
	if not BattleRematchJuice.claim_rematch_drill():
		return "%s rematch drill claim failed after reenter" % tag
	await _shot("%s-rematch-board" % tag)
	return ""


func _assert_report_ctas(tag: String, win: bool) -> String:
	if not BattleRematchJuice.offers_rematch(_battle, win):
		return "%s should offer rematch on practice" % tag
	var layer := _find_report()
	if layer == null:
		return "%s ResultReport missing" % tag
	var rematch := layer.find_child("RematchCta", true, false)
	var hub := layer.find_child("HubCta", true, false)
	if rematch == null:
		return "%s RematchCta missing" % tag
	if hub == null:
		return "%s HubCta missing" % tag
	if win and str(rematch.text).find("再战") < 0:
		return "%s rematch label want 再战一场 got %s" % [tag, rematch.text]
	if win and str(hub.text).find("枢纽") < 0 and str(hub.text).find("堡") < 0:
		return "%s hub label want 返回枢纽 got %s" % [tag, hub.text]
	return ""


func _assert_rematch_board(tag: String) -> String:
	if str(_battle.map_id) != MAP_ID:
		return "%s rematch board map want %s" % [tag, MAP_ID]
	if _battle.battle_over:
		return "%s rematch board should be live (not over)" % tag
	if _player_i < 0 or _foe_i < 0:
		return "%s rematch board missing units" % tag
	if not GameState.has_meta(BattleRematchJuice.META_ROUND):
		return "%s META_ROUND must survive rematch reload" % tag
	return ""



func _scene_lose_then_hub(tag: String) -> String:
	_battle.battle_over = false
	for u in _battle.units:
		if str(u.team) == "player":
			u.char.hp = 0
	_battle.set_meta("battle_verdict", {"result": "lose", "reason": "rout"})
	_battle._finish(false)
	await _settle(6)
	var err := _assert_report_ctas(tag, false)
	if err != "":
		return err
	await _shot("%s-lose-settle" % tag)
	var back := str(_battle.get_meta("result_back", ""))
	if back != BattleDefeat.CASTLE and back.find("castle_hub") < 0:
		return "%s hub path want castle_hub got %s" % [tag, back]
	_battle.set_meta(BattleRematchJuice.META_REMATCH, {"action": "hub", "msec": Time.get_ticks_msec()})
	await _free_battle()
	var hub_node = HUB_SCN.instantiate()
	if hub_node == null:
		return "%s castle_hub failed to instantiate" % tag
	get_tree().root.add_child(hub_node)
	await _settle(6)
	if not is_instance_valid(hub_node):
		return "%s hub node invalid after load" % tag
	await _shot("%s-hub" % tag)
	hub_node.queue_free()
	await _settle(2)
	return ""



func _find_report() -> Node:
	var layer := _battle.get_node_or_null("ResultReport")
	if layer != null:
		return layer
	for c in _battle.get_children():
		if str(c.name) == "ResultReport":
			return c
	return null


func _shot(tag: String) -> void:
	_shot_n += 1
	var vp := get_viewport()
	if vp == null:
		return
	await get_tree().process_frame
	var img: Image = vp.get_texture().get_image()
	if img == null:
		return
	var path := "%s/%02d_%s_%s.png" % [SHOT_DIR, _shot_n, _surface, tag]
	var err := img.save_png(path)
	print("shot %s err=%s size=%s" % [path, err, img.get_size()])


func _free_battle() -> void:
	Engine.time_scale = 1.0
	if _battle != null and is_instance_valid(_battle):
		_battle.queue_free()
		_battle = null
	await _settle(2)


func _set_window() -> void:
	var sz := PHONE if _surface == "mobile" else DESK
	DisplayServer.window_set_size(sz)
	await _settle(2)


func _settle(frames: int) -> void:
	for _i in frames:
		await get_tree().process_frame


class _FakeHost:
	var _world_enc := false
