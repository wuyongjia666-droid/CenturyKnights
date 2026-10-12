class_name CKYanZhan
extends RefCounted
## 验盏特殊职业战斗技（提案开放问题 #2：无血谱杂兵弱命中 +4，伪造 +8）。

const FORGED_HIT := 8
const BLOODLESS_HIT := 4
const SKILL_ID := "yan_zhan"
const META_KEY := "yan_zhan_target"


static func has_forged_mark(c: Object) -> bool:
	if c == null:
		return false
	var meta = c.get("blood_meta") if typeof(c.get("blood_meta")) == TYPE_DICTIONARY else {}
	if typeof(meta) != TYPE_DICTIONARY:
		meta = {}
	var pretend = meta.get("pretend", {})
	if typeof(pretend) == TYPE_DICTIONARY and not pretend.is_empty() and not bool(pretend.get("exposed", false)):
		return true
	var honors = c.get("honors") if typeof(c.get("honors")) == TYPE_ARRAY else []
	if "paper_patent" in honors:
		return true
	return false


static func has_blood_spectrum(c: Object) -> bool:
	if c == null:
		return false
	if has_forged_mark(c):
		return true
	var meta = c.get("blood_meta") if typeof(c.get("blood_meta")) == TYPE_DICTIONARY else {}
	if typeof(meta) == TYPE_DICTIONARY and bool(meta.get("verified", false)):
		return true
	var mix = c.get("blood_mix") if typeof(c.get("blood_mix")) == TYPE_DICTIONARY else {}
	if typeof(mix) != TYPE_DICTIONARY or mix.is_empty():
		return false
	for lid in mix.keys():
		var tier := CKBloodline.tier_of(str(lid))
		if tier in ["royal", "noble"]:
			return true
	return false


static func hit_bonus(target: Object) -> int:
	if target == null:
		return 0
	if has_forged_mark(target):
		return FORGED_HIT
	if not has_blood_spectrum(target):
		return BLOODLESS_HIT
	return 0


static func can_cast(caster: Object) -> bool:
	if caster == null:
		return false
	if str(caster.get("job_id")) != "yan_zhan" and "yan_zhan" not in list_skills(caster):
		# allow if skill known
		if SKILL_ID not in list_skills(caster):
			return false
	var meta = caster.get("blood_meta") if typeof(caster.get("blood_meta")) == TYPE_DICTIONARY else {}
	return not bool(meta.get("yan_zhan_used", false))


static func list_skills(c: Object) -> Array:
	var s = c.get("skills") if c != null else []
	return s if typeof(s) == TYPE_ARRAY else []


static func cast(battle, caster_unit, target_unit) -> Dictionary:
	## battle: battle_controller-like; marks target for the rest of the battle.
	if caster_unit == null or target_unit == null:
		return {"ok": false, "msg": Locale.t("yan_no_target")}
	var caster = _unit_char(caster_unit)
	var target = _unit_char(target_unit)
	if caster == null or target == null:
		return {"ok": false, "msg": Locale.t("yan_no_target")}
	if not can_cast(caster):
		return {"ok": false, "msg": Locale.t("yan_used")}
	var bonus := hit_bonus(target)
	caster.blood_meta["yan_zhan_used"] = true
	if battle != null:
		battle.set_meta(META_KEY, target.id if target.get("id") != null else str(target))
		battle.set_meta(META_KEY + "_bonus", bonus)
	var msg := Locale.t("yan_out") if bonus == 0 else (Locale.t("yan_forged") % bonus if bonus == FORGED_HIT else Locale.t("yan_bloodless") % bonus)
	if bonus == 0:
		msg = Locale.t("yan_true")
	return {"ok": true, "msg": msg, "bonus": bonus, "target_id": str(target.id) if target.get("id") != null else ""}


static func battle_hit_bonus(battle, target: Object) -> int:
	if battle == null or target == null:
		return 0
	if not battle.has_meta(META_KEY):
		return 0
	var tid := str(battle.get_meta(META_KEY))
	var id := str(target.id) if target.get("id") != null else ""
	if id != tid:
		return 0
	return int(battle.get_meta(META_KEY + "_bonus"))


static func reset_battle(caster: Object) -> void:
	if caster == null:
		return
	var meta = caster.get("blood_meta")
	if typeof(meta) == TYPE_DICTIONARY:
		meta["yan_zhan_used"] = false


static func _unit_char(unit):
	if unit == null:
		return null
	if typeof(unit) == TYPE_DICTIONARY:
		return unit.get("char", unit)
	if unit.get("char") != null:
		return unit.char
	return unit
