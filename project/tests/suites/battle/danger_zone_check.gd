extends Node
## BTL-03: danger cells match a hand walk, forecast numbers match preview.

const HAND_STANDS := [
	Vector2i(3, 1), Vector2i(2, 1), Vector2i(4, 1), Vector2i(4, 0), Vector2i(4, 2),
]
const HAND_DANGER := [
	Vector2i(3, 1), Vector2i(2, 1), Vector2i(4, 1), Vector2i(4, 0), Vector2i(4, 2),
	Vector2i(1, 1), Vector2i(2, 0), Vector2i(2, 2), Vector2i(3, 0), Vector2i(3, 2),
]
const HAND_CUT := [Vector2i(1, 0), Vector2i(1, 2), Vector2i(0, 1)]

var _battle


func _ready() -> void:
	await get_tree().process_frame
	var err := _cells()
	if err == "":
		err = _forecasts()
	if err == "":
		err = await _long_press()
	if err == "":
		await _shots()
	if err != "":
		print("FAIL danger zone: ", err)
		get_tree().quit(1)
		return
	print("DANGER ZONE PASS")
	get_tree().quit(0)


func _terrain() -> Array:
	return [
		["plain", "plain", "plain", "water", "plain"],
		["plain", "plain", "plain", "plain", "plain"],
		["plain", "plain", "plain", "water", "plain"],
	]


func _cells() -> String:
	var terrain := _terrain()
	var blocked := [Vector2i(1, 1)]
	var zoc := [Vector2i(1, 1)]
	var stands := DangerZone.reach(terrain, Vector2i(3, 1), 2, blocked, zoc)
	if not _same(stands, HAND_STANDS):
		return "stands %s" % stands.keys()
	var danger := DangerZone.from_stand(terrain, Vector2i(3, 1), 2, blocked, zoc, 1)
	if not _same(danger, HAND_DANGER):
		return "danger %s" % danger.keys()
	for cut in HAND_CUT:
		if danger.has(cut) or stands.has(cut):
			return "ZoC should cut %s" % cut
	if not stands.has(Vector2i(2, 1)):
		return "should still be allowed to step into ZoC"
	return ""


func _same(got: Dictionary, want: Array) -> bool:
	if got.size() != want.size():
		return false
	for cell in want:
		if not got.has(cell):
			return false
	return true


func _forecasts() -> String:
	var rng := RandomNumberGenerator.new()
	rng.seed = 92
	var terrains := ["plain", "forest", "hill", "fort", "water", "bridge"]
	var jobs := ["light_inf", "hunter", "heavy_inf", "apprentice"]
	for n in 50:
		var atk := _fighter(rng, jobs[n % jobs.size()])
		var defender := _fighter(rng, jobs[(n + 1) % jobs.size()])
		var tid: String = terrains[n % terrains.size()]
		var extras := {"flank": n % 4 == 0}
		var atk_pos := Vector2i(1, 1)
		var def_pos := Vector2i(2, 1) if n % 3 != 0 else Vector2i(3, 1)
		var got := ForecastPanel.sides(atk, defender, tid, extras, atk_pos, def_pos, "plain")
		var pv: Dictionary = BattleRules.preview(atk, defender, tid, extras)
		if int(got.hit) != int(pv.hit):
			return "hit %s vs %s" % [got.hit, pv.hit]
		if int(got.dmg_lo) != int(pv.dmg.x) or int(got.dmg_hi) != int(pv.dmg.y):
			return "dmg %s vs %s" % [got, pv.dmg]
		if int(got.crit) != int(pv.crit) or bool(got.follow) != bool(pv.follow_up):
			return "crit/follow %s" % got
		var counter := BattleRules.can_counter(atk, defender, atk_pos, def_pos)
		if bool(got.counter) != counter:
			return "counter flag"
		if counter:
			var back: Dictionary = BattleRules.preview(defender, atk, "plain", {})
			if int(got.counter_hit) != int(back.hit) or int(got.counter_lo) != int(back.dmg.x):
				return "counter numbers %s vs %s" % [got, back]
	return ""


func _fighter(rng: RandomNumberGenerator, job: String) -> CKCharacter:
	var c := CKCharacter.new()
	c.id = "f%d" % rng.randi()
	c.job_id = job
	c.level = rng.randi_range(1, 6)
	c.stats = {
		"str": rng.randi_range(3, 14),
		"vit": rng.randi_range(3, 14),
		"skl": rng.randi_range(3, 14),
		"agi": rng.randi_range(3, 14),
		"per": rng.randi_range(3, 14),
		"wil": rng.randi_range(3, 14),
	}
	c.recalc_hp()
	c.hp = c.max_hp
	return c


func _long_press() -> String:
	var src := FileAccess.get_file_as_string("res://scripts/battle/battle_controller.gd")
	var arm := src.split('"long_press":')[1].split("\n")[1]
	if arm.find("_click_cell") >= 0 or arm.find("_on_long_press_cell") < 0:
		return "long_press arm moved or dropped: %s" % arm.strip_edges()
	GameState.new_game("探针", "灰旗", "#" + "6ED4FF")
	GameState.set_meta("battle_map", "obj_rout")
	_battle = load("res://scenes/battle/battle.tscn").instantiate()
	add_child(_battle)
	await get_tree().process_frame
	await get_tree().process_frame
	var before := {}
	var enemy_i := -1
	for i in _battle.units.size():
		before[i] = _battle.units[i].pos
		if str(_battle.units[i].team) == "enemy":
			enemy_i = i
	if enemy_i < 0:
		return "no enemy to long-press"
	_battle._on_long_press_cell(_battle.units[enemy_i].pos)
	for i in _battle.units.size():
		if _battle.units[i].pos != before[i]:
			return "long press moved %s" % _battle.units[i].pos
	if not _battle.danger_on or int(_battle.danger_focus) != enemy_i:
		return "long press did not focus that enemy"
	var one := DangerZone.collect(_battle)
	_battle._on_long_press_cell(Vector2i(0, 0))
	if _battle.units[enemy_i].pos != before[enemy_i]:
		return "terrain long press moved the enemy"
	_battle.danger_focus = -1
	_battle.danger_on = true
	var all := DangerZone.collect(_battle)
	if all.size() < one.size():
		return "full danger smaller than one enemy"
	return ""


func _shots() -> void:
	if _battle == null:
		return
	_battle.danger_on = true
	_battle.danger_focus = -1
	var ui := -1
	var foe := -1
	for i in _battle.units.size():
		if str(_battle.units[i].team) == "player" and ui < 0:
			ui = i
		if str(_battle.units[i].team) == "enemy" and foe < 0:
			foe = i
	if ui >= 0 and foe >= 0:
		_battle._select_player(ui)
		_battle.attack_mode = true
		_battle._hover_cell = _battle.units[foe].pos
		ForecastPanel.refresh(_battle)
	GameState.settings["colorblind"] = true
	if _battle.overlay:
		_battle.overlay.queue_redraw()
	await get_tree().process_frame
	await _grab(_battle, Vector2i(1280, 720), "/opt/cursor/artifacts/btl03_danger_forecast_desktop.png")
	var fitted: Dictionary = MobileLayout.fit(Vector2(1080, 2400), {"left": 0.0, "top": 96.0, "right": 0.0, "bottom": 72.0})
	_battle.set_meta("mobile_insets", {"left": 0.0, "top": 96.0, "right": 0.0, "bottom": 72.0})
	_battle.set_meta("mobile_origin", fitted.get("position", Vector2.ZERO))
	_battle.scale = Vector2(float(fitted.scale), float(fitted.scale))
	await get_tree().process_frame
	await _grab(_battle, Vector2i(1080, 2400), "/opt/cursor/artifacts/btl03_danger_forecast_phone.png")


func _grab(node: Node, size: Vector2i, path: String) -> void:
	var vp := SubViewport.new()
	vp.size = size
	vp.disable_3d = true
	vp.transparent_bg = false
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(vp)
	var bg := ColorRect.new()
	bg.color = UIKit.BG
	bg.size = Vector2(size)
	vp.add_child(bg)
	var parent := node.get_parent()
	node.reparent(vp)
	for _i in 3:
		await get_tree().process_frame
	var img := vp.get_texture().get_image()
	if parent:
		node.reparent(parent)
	vp.queue_free()
	if img == null:
		print("shot skipped ", path)
		return
	DirAccess.make_dir_recursive_absolute("/opt/cursor/artifacts")
	print("shot %s %s err=%s" % [path, img.get_size(), img.save_png(path)])
