class_name CKYanZhan
extends RefCounted
## 验盏（特殊职业，P1 落地技能）。Board #2 locked 2026-10-12：
## 伪造目标命中 +8；无血谱杂兵给较弱命中 +4（不再空放）。

const FORGED_HIT := 8
const BLOODLESS_HIT := 4


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
	## 有可读血谱：王/贵胤，或已验过，或身上有伪造纸面。杂兵通常两项都没有。
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
	## 本场对该目标的全队命中加成。无目标则 0。
	if target == null:
		return 0
	if has_forged_mark(target):
		return FORGED_HIT
	if not has_blood_spectrum(target):
		return BLOODLESS_HIT
	## 有真血谱、无伪造：盏亮但不额外加命中（验明而已）
	return 0
