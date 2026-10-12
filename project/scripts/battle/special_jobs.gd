class_name CKSpecialJobs
extends RefCounted
## v9.2 六门特殊职业战斗规则（验盏见 CKYanZhan）。

const BRIDGE := "bridge_tax"
const LU_WAI := "lu_wai"
const FROST := "frost_wait"
const SALT := "salt_yin"
const BROW := "forge_brow"


static func on_battle_start(battle, units: Array) -> void:
	for u in units:
		var c = _char(u)
		if c == null:
			continue
		match str(c.job_id):
			SALT:
				_salt_aura(battle, u, units)
			LU_WAI:
				c.blood_meta["lu_wai_free"] = true
			BROW:
				c.blood_meta["forge_brow_ready"] = true
			FROST:
				c.blood_meta["frost_wait_armed"] = true
			BRIDGE:
				c.blood_meta["bridge_tax_used"] = false


static func on_turn_start(battle, unit) -> void:
	var c = _char(unit)
	if c == null or str(c.job_id) != FROST:
		return
	if battle == null:
		return
	## 相邻丘/垒敌人防御 −1 直至其移动
	var foes: Array = []
	if battle.has_method("adjacent_enemies"):
		foes = battle.adjacent_enemies(unit)
	elif battle.get("units") != null:
		foes = _adjacent_fallback(battle, unit)
	for foe in foes:
		var fc = _char(foe)
		if fc == null:
			continue
		var terrain := str(foe.get("terrain") if typeof(foe) == TYPE_DICTIONARY else "")
		if battle.has_method("terrain_at") and foe.get("pos") != null:
			terrain = str(battle.terrain_at(foe.pos))
		if terrain not in ["hill", "fort"]:
			continue
		fc.temp_def_buff = mini(int(fc.temp_def_buff) - 1, int(fc.temp_def_buff))  # reduce def via exposed
		fc.temp_exposed = maxi(int(fc.temp_exposed), 1)
		fc.blood_meta["frost_wait_locked"] = true
		break


static func on_skill_used(caster, skill_id: String) -> void:
	var c = _char(caster)
	if c == null:
		return
	if str(c.job_id) == LU_WAI and bool(c.blood_meta.get("lu_wai_free", false)):
		c.blood_meta["lu_wai_free"] = false
		## 调用方应跳过冷却写入
		c.blood_meta["lu_wai_skip_cd"] = true


static func should_skip_cooldown(caster) -> bool:
	var c = _char(caster)
	if c == null:
		return false
	if bool(c.blood_meta.get("lu_wai_skip_cd", false)):
		c.blood_meta["lu_wai_skip_cd"] = false
		return true
	return false


static func on_damaged(battle, victim, attacker, _amount: int) -> Dictionary:
	var c = _char(victim)
	if c == null or str(c.job_id) != BROW:
		return {"ok": false}
	if not bool(c.blood_meta.get("forge_brow_ready", false)):
		return {"ok": false}
	c.blood_meta["forge_brow_ready"] = false
	c.temp_def_buff += 2
	var ac = _char(attacker)
	if ac != null:
		ac.hp = maxi(0, int(ac.hp) - 2)
	return {"ok": true, "msg": Locale.t("skill_forge_brow"), "reflect": 2}


static func cast_bridge_tax(battle, caster_unit, target_unit) -> Dictionary:
	var c = _char(caster_unit)
	var t = _char(target_unit)
	if c == null or t == null:
		return {"ok": false, "msg": Locale.t("yan_no_target")}
	if str(c.job_id) != BRIDGE:
		return {"ok": false, "msg": Locale.t("seal_wrong_job")}
	if bool(c.blood_meta.get("bridge_tax_used", false)):
		return {"ok": false, "msg": Locale.t("yan_used")}
	var on_road := true
	if battle != null and battle.has_method("terrain_at") and caster_unit.get("pos") != null:
		var ter := str(battle.terrain_at(caster_unit.pos))
		on_road = ter in ["road", "bridge", "plain", ""]
	if not on_road:
		return {"ok": false, "msg": Locale.t("bridge_need_road")}
	c.blood_meta["bridge_tax_used"] = true
	t.blood_meta["move_penalty_next"] = 2
	c.temp_move_bonus = int(c.get("temp_move_bonus") if c.get("temp_move_bonus") != null else 0) + 1
	## also store on blood_meta for controllers that read it
	c.blood_meta["bonus_move"] = int(c.blood_meta.get("bonus_move", 0)) + 1
	return {"ok": true, "msg": Locale.t("skill_bridge_tax")}


static func _salt_aura(battle, unit, units: Array) -> void:
	## 粮够当日口粮才开
	var need := maxi(1, units.size() if false else 1)
	if int(GameState.food) < need:
		return
	for u in units:
		if u == unit:
			continue
		if not _is_ally(unit, u):
			continue
		if not _adjacent(unit, u):
			continue
		var c = _char(u)
		if c != null:
			c.temp_def_buff += 1


static func _is_ally(a, b) -> bool:
	var sa = a.get("side") if typeof(a) == TYPE_DICTIONARY else (a.side if a.get("side") != null else "")
	var sb = b.get("side") if typeof(b) == TYPE_DICTIONARY else (b.side if b.get("side") != null else "")
	return str(sa) == str(sb)


static func _adjacent(a, b) -> bool:
	var pa = a.get("pos") if typeof(a) == TYPE_DICTIONARY else a.get("pos")
	var pb = b.get("pos") if typeof(b) == TYPE_DICTIONARY else b.get("pos")
	if pa == null or pb == null:
		return false
	var ax = int(pa.x) if typeof(pa) == TYPE_VECTOR2I or typeof(pa) == TYPE_VECTOR2 else int(pa.get("x", 0))
	var ay = int(pa.y) if typeof(pa) == TYPE_VECTOR2I or typeof(pa) == TYPE_VECTOR2 else int(pa.get("y", 0))
	var bx = int(pb.x) if typeof(pb) == TYPE_VECTOR2I or typeof(pb) == TYPE_VECTOR2 else int(pb.get("x", 0))
	var by = int(pb.y) if typeof(pb) == TYPE_VECTOR2I or typeof(pb) == TYPE_VECTOR2 else int(pb.get("y", 0))
	return abs(ax - bx) + abs(ay - by) == 1


static func _adjacent_fallback(battle, unit) -> Array:
	var out: Array = []
	var units = battle.get("units") if battle.get("units") != null else []
	for u in units:
		if _adjacent(unit, u) and not _is_ally(unit, u):
			out.append(u)
	return out


static func _char(unit):
	if unit == null:
		return null
	if typeof(unit) == TYPE_DICTIONARY:
		return unit.get("char", unit)
	if unit.get("char") != null:
		return unit.char
	return unit
