class_name CKSpecialJobs
extends RefCounted
## v9.2 特殊职业战斗规则（提案 §4.2 表）。battle_controller 只接四个钩子：
##   _start_player_turn → on_player_turn；roll_attack 前 → strike_mods；
##   扣血后 → after_strike；_consume_skill → skip_cooldown。
## 本场状态都放在 battle 或角色对象的 meta 上，新开一场自动清空，不进存档。

const BRIDGE_TERRAIN := ["bridge", "road"]
const FROST_TERRAIN := ["hill", "fort"]


static func _job(u) -> String:
	var c = u.get("char") if u != null else null
	return str(c.get("job_id")) if c != null else ""


static func _alive(u) -> bool:
	return u != null and u.get("char") != null and int(u["char"].hp) > 0


static func _adj(a, b) -> bool:
	var pa: Vector2i = a.get("pos", Vector2i(-99, -99))
	var pb: Vector2i = b.get("pos", Vector2i(-99, -99))
	return absi(pa.x - pb.x) + absi(pa.y - pb.y) == 1


static func _tid(battle, pos: Vector2i) -> String:
	var t = battle.get("terrain")
	if typeof(t) != TYPE_ARRAY or pos.y < 0 or pos.y >= t.size() or pos.x < 0 or pos.x >= t[pos.y].size():
		return "plain"
	return str(t[pos.y][pos.x])


static func _say(battle, text: String) -> void:
	if battle.has_method("_log"):
		battle._log(text)


static func _set_move(c, v: int) -> void:
	if v == 0:
		if c.has_meta("battle_move_mod"):
			c.remove_meta("battle_move_mod")
	else:
		c.set_meta("battle_move_mod", v)


## 我方回合开始。第 1 回合做开战结算（盐引）。
static func on_player_turn(battle) -> void:
	var units: Array = battle.get("units")
	var first: bool = not battle.has_meta("sj_started")
	if first:
		battle.set_meta("sj_started", true)
		for u in units:
			if u.get("char") != null:
				_set_move(u["char"], 0)
				for k in ["sj_frost_pos", "sj_brow_used", "sj_brow_def", "sj_toll_spent"]:
					if u["char"].has_meta(k):
						u["char"].remove_meta(k)
		_salt_check(battle)
	else:
		# 上回合桥税骑给的移动增减到这回合为止
		for u in units:
			if u.get("char") != null and u["char"].has_meta("battle_move_mod"):
				if str(u.get("team")) == "player" or u["char"].has_meta("sj_toll_spent"):
					_set_move(u["char"], 0)
					if u["char"].has_meta("sj_toll_spent"):
						u["char"].remove_meta("sj_toll_spent")
	for u in units:
		if str(u.get("team")) != "player" or not _alive(u):
			continue
		match _job(u):
			"bridge_tax":
				_bridge_tax(battle, u, units)
			"frost_wait":
				_frost_wait(battle, u, units)


## 桥税骑：每场一次。站在桥/路上，挨着敌人时自动收税：那名敌人下回合移动 −2，自己这回合移动 +1。
## 偏离提案：提案是手动指定，这里改成回合开始自动挑第一个相邻敌人，省一个按钮、手机上少一次点。
static func _bridge_tax(battle, u, units: Array) -> void:
	var c = u["char"]
	if c.has_meta("sj_toll_used") and int(c.get_meta("sj_toll_used")) == battle.get_instance_id():
		return
	if _tid(battle, u["pos"]) not in BRIDGE_TERRAIN:
		return
	for o in units:
		if str(o.get("team")) == "enemy" and _alive(o) and _adj(u, o):
			c.set_meta("sj_toll_used", battle.get_instance_id())
			_set_move(o["char"], -2)
			o["char"].set_meta("sj_toll_spent", true)
			_set_move(c, 1)
			_say(battle, "【桥税骑】%s 拦下 %s 收过桥税：它下回合少走 2 格，%s 这回合多走 1 格" % [c.name, o["char"].name, c.name])
			return


## 霜候：每回合一次，挨着的、站在丘或垒上的一名敌人防御 −1，直到它挪窝。
static func _frost_wait(battle, u, units: Array) -> void:
	for o in units:
		if str(o.get("team")) == "enemy" and _alive(o) and _adj(u, o) and _tid(battle, o["pos"]) in FROST_TERRAIN:
			if o["char"].has_meta("sj_frost_pos") and o["char"].get_meta("sj_frost_pos") == o["pos"]:
				continue
			o["char"].set_meta("sj_frost_pos", o["pos"])
			_say(battle, "【霜候】%s 盯住了 %s：它不挪窝就防御 −1" % [u["char"].name, o["char"].name])
			return


## 盐引：开战时粮够当天口粮，挨着盐引的友军防御 +1，整场有效；不够就不开，也不扣士气。
static func _salt_check(battle) -> void:
	var has_salt := false
	for u in battle.get("units"):
		if str(u.get("team")) == "player" and _job(u) == "salt_yin":
			has_salt = true
	if not has_salt:
		return
	var mouths := 0
	for c in GameState.characters.values():
		if c != null and c.alive and (c.in_roster or c.is_child):
			mouths += 1
	var ok := int(GameState.food) >= maxi(1, mouths)
	battle.set_meta("sj_salt_on", ok)
	_say(battle, "【盐引】粮够今天吃，挨着盐引的人防御 +1" if ok else "【盐引】粮不够今天吃，盐引的光环没开")


static func _salt_bonus(battle, def_u) -> int:
	if not bool(battle.get_meta("sj_salt_on", false)) or str(def_u.get("team")) != "player":
		return 0
	for u in battle.get("units"):
		if u != def_u and str(u.get("team")) == "player" and _alive(u) and _job(u) == "salt_yin" and _adj(u, def_u):
			return 1
	return 0


## roll_attack 之前：把命中、防御的增减写进 extras。
static func strike_mods(battle, atk_u, def_u, extras: Dictionary) -> void:
	extras["hit_mod"] = int(extras.get("hit_mod", 0)) + CKYanZhan.strike_bonus(battle, atk_u, def_u)
	var d := 0
	d += _salt_bonus(battle, def_u)
	var dc = def_u.get("char")
	if dc != null:
		if dc.has_meta("sj_frost_pos") and dc.get_meta("sj_frost_pos") == def_u.get("pos"):
			d -= 1
		if dc.has_meta("sj_brow_def"):
			d += int(dc.get_meta("sj_brow_def"))
	if d != 0:
		extras["flat_def"] = int(extras.get("flat_def", 0)) + d


## 扣血之后：锻眉本场第一次挨打，打它的人吃 2 点固定伤害，它自己防御 +2 到打完。
static func after_strike(battle, atk_u, def_u, result: Dictionary) -> void:
	if not bool(result.get("hit", false)) or int(result.get("damage", 0)) <= 0:
		return
	var dc = def_u.get("char")
	if dc == null or str(dc.get("job_id")) != "forge_brow" or dc.has_meta("sj_brow_used"):
		return
	dc.set_meta("sj_brow_used", true)
	dc.set_meta("sj_brow_def", 2)
	var ac = atk_u.get("char")
	if ac != null and int(ac.hp) > 0:
		ac.hp = maxi(0, int(ac.hp) - 2)
	_say(battle, "【锻眉】%s 硬吃一下，反震 %s 2 点，之后防御 +2" % [dc.name, ac.name if ac != null else "对手"])


## 录外生：本场第一次用战技不进冷却。
static func skip_cooldown(c, battle = null) -> bool:
	if c == null or str(c.get("job_id")) != "lu_wai":
		return false
	var tag: int = battle.get_instance_id() if battle != null else 1
	if c.has_meta("sj_luwai_used") and int(c.get_meta("sj_luwai_used")) == tag:
		return false
	c.set_meta("sj_luwai_used", tag)
	return true
