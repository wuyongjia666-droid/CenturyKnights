extends Node
## 五门特殊职业的战斗钩子 + 盖印门。

class FakeBattle extends Node:
	var units: Array = []
	var terrain: Array = []
	var logs: Array = []
	func _log(t: String) -> void:
		logs.append(t)


func _ready() -> void:
	await get_tree().process_frame
	var err := _run()
	if err != "":
		print("FAIL special_jobs: ", err)
		get_tree().quit(1)
		return
	print("SPECIAL JOBS PASS")
	get_tree().quit(0)


func _ch(id: String, job: String) -> CKCharacter:
	var c := CKCharacter.new()
	c.id = id; c.name = id; c.job_id = job; c.alive = true; c.hp = 20; c.max_hp = 20; c.blood_meta = {}
	return c


func _battle(tiles: Dictionary) -> FakeBattle:
	var b := FakeBattle.new()
	add_child(b)
	for y in 5:
		var row: Array = []
		for x in 5:
			row.append(str(tiles.get(Vector2i(x, y), "plain")))
		b.terrain.append(row)
	return b


func _run() -> String:
	GameState.new_game("烬行", "灰旗", "frost")
	# seals exist for all six, gate blocks without seal
	for jid in ["bridge_tax", "lu_wai", "frost_wait", "salt_yin", "forge_brow", "yan_zhan"]:
		if CKJobSeals.seal_row(jid).is_empty() or GameState.get_job(jid).is_empty():
			return "missing %s" % jid
		var c0 := _ch("g_" + jid, str(CKJobSeals.seal_row(jid).from))
		if bool(CKJobSeals.promote_gate(c0, jid).get("ok", true)):
			return "no gate %s" % jid
	# 桥税骑
	var b := _battle({Vector2i(1, 1): "bridge"})
	var bt := _ch("bt", "bridge_tax")
	var e1 := _ch("e1", "warrior")
	var base_bt := bt.derived_move()
	var base_e := e1.derived_move()
	b.units = [{"char": bt, "pos": Vector2i(1, 1), "team": "player"}, {"char": e1, "pos": Vector2i(2, 1), "team": "enemy"}]
	CKSpecialJobs.on_player_turn(b)
	if bt.derived_move() != base_bt + 1 or e1.derived_move() != maxi(1, base_e - 2):
		return "toll move %d/%d" % [bt.derived_move(), e1.derived_move()]
	CKSpecialJobs.on_player_turn(b)
	if bt.derived_move() != base_bt or e1.derived_move() != base_e:
		return "toll not cleared"
	CKSpecialJobs.on_player_turn(b)
	if bt.derived_move() != base_bt:
		return "toll repeated"
	# off-bridge: nothing
	var b2 := _battle({})
	var bt2 := _ch("bt2", "bridge_tax")
	b2.units = [{"char": bt2, "pos": Vector2i(1, 1), "team": "player"}, {"char": _ch("e2", "warrior"), "pos": Vector2i(2, 1), "team": "enemy"}]
	CKSpecialJobs.on_player_turn(b2)
	if bt2.derived_move() != base_bt:
		return "toll off bridge"
	# 霜候
	var b3 := _battle({Vector2i(2, 2): "hill"})
	var fw := _ch("fw", "frost_wait")
	var e3 := _ch("e3", "warrior")
	var eu := {"char": e3, "pos": Vector2i(2, 2), "team": "enemy"}
	var pu := {"char": _ch("p3", "warrior"), "pos": Vector2i(0, 0), "team": "player"}
	b3.units = [{"char": fw, "pos": Vector2i(1, 2), "team": "player"}, eu, pu]
	CKSpecialJobs.on_player_turn(b3)
	var ex := {}
	CKSpecialJobs.strike_mods(b3, pu, eu, ex)
	if int(ex.get("flat_def", 0)) != -1:
		return "frost def %s" % ex
	eu["pos"] = Vector2i(3, 3)
	ex = {}
	CKSpecialJobs.strike_mods(b3, pu, eu, ex)
	if int(ex.get("flat_def", 0)) != 0:
		return "frost after move"
	# 盐引
	var b4 := _battle({})
	var sy := _ch("sy", "salt_yin")
	var ally := {"char": _ch("al", "warrior"), "pos": Vector2i(1, 2), "team": "player"}
	var far := {"char": _ch("fa", "warrior"), "pos": Vector2i(4, 4), "team": "player"}
	var foe := {"char": _ch("fo", "warrior"), "pos": Vector2i(0, 4), "team": "enemy"}
	b4.units = [{"char": sy, "pos": Vector2i(1, 1), "team": "player"}, ally, far, foe]
	GameState.food = 999
	CKSpecialJobs.on_player_turn(b4)
	ex = {}
	CKSpecialJobs.strike_mods(b4, foe, ally, ex)
	if int(ex.get("flat_def", 0)) != 1:
		return "salt ally %s" % ex
	ex = {}
	CKSpecialJobs.strike_mods(b4, foe, far, ex)
	if int(ex.get("flat_def", 0)) != 0:
		return "salt far"
	var b5 := _battle({})
	b5.units = [{"char": _ch("sy2", "salt_yin"), "pos": Vector2i(1, 1), "team": "player"}, ally, foe]
	GameState.food = 0
	var m0 := int(GameState.morale)
	CKSpecialJobs.on_player_turn(b5)
	ex = {}
	CKSpecialJobs.strike_mods(b5, foe, ally, ex)
	if int(ex.get("flat_def", 0)) != 0 or int(GameState.morale) != m0:
		return "salt hungry"
	# 锻眉
	var b6 := _battle({})
	var fb := {"char": _ch("fb", "forge_brow"), "pos": Vector2i(1, 1), "team": "player"}
	var at := {"char": _ch("at", "warrior"), "pos": Vector2i(2, 1), "team": "enemy"}
	b6.units = [fb, at]
	CKSpecialJobs.on_player_turn(b6)
	CKSpecialJobs.after_strike(b6, at, fb, {"hit": false, "damage": 0})
	if int(at["char"].hp) != 20:
		return "brow on miss"
	CKSpecialJobs.after_strike(b6, at, fb, {"hit": true, "damage": 5})
	if int(at["char"].hp) != 18:
		return "brow reflect %d" % int(at["char"].hp)
	CKSpecialJobs.after_strike(b6, at, fb, {"hit": true, "damage": 5})
	if int(at["char"].hp) != 18:
		return "brow repeat"
	ex = {}
	CKSpecialJobs.strike_mods(b6, at, fb, ex)
	if int(ex.get("flat_def", 0)) != 2:
		return "brow def"
	# 录外生
	var lw := _ch("lw", "lu_wai")
	if not CKSpecialJobs.skip_cooldown(lw, b6) or CKSpecialJobs.skip_cooldown(lw, b6):
		return "lu_wai once"
	if CKSpecialJobs.skip_cooldown(_ch("x", "mage"), b6):
		return "lu_wai other job"
	if not CKSpecialJobs.skip_cooldown(lw, b5):
		return "lu_wai new battle"
	return ""
