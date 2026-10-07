class_name CharacterFactory
extends RefCounted

static var _id_seq: int = 0

static func next_id(prefix: String = "c") -> String:
	_id_seq += 1
	return "%s_%d_%d" % [prefix, Time.get_ticks_msec(), _id_seq]

static func make_leader(given: String, surname: String, crest_color: String) -> CKCharacter:
	var c := CKCharacter.new()
	c.id = next_id("leader")
	c.name = surname + given
	c.gender = "m"
	c.age = 22
	c.is_leader = true
	c.job_id = "squire"
	c.rank = "knight"
	c.blood_mix = {"common_ash": 0.6, "river_ward": 0.4}
	c.traits = ["brave", "heir_mark"]
	c.appearance = {"hair": "ash_brown", "eyes": "river_blue", "brow": "thick", "scar": "none"}
	c.birthday_month = 3
	_roll_stats_from_blood(c)
	c.salary = 0
	c.recalc_hp()
	GameState.crest_color = crest_color
	GameState.surname = surname
	return c

static func make_ally_tutor() -> CKCharacter:
	var c := CKCharacter.new()
	c.id = next_id("ally")
	c.name = "苇原·灯影"
	c.gender = "f"
	c.age = 24
	c.job_id = "hunter"
	c.rank = "knight"
	c.blood_mix = {"river_ward": 1.0}
	c.traits = ["keen_eye", "night_owl"]
	c.appearance = {"hair": "wheat", "eyes": "pine", "brow": "arch", "scar": "none"}
	_roll_stats_from_blood(c)
	c.stats["skl"] = maxi(c.stats["skl"], 10)
	c.stats["agi"] = maxi(c.stats["agi"], 10)
	c.recalc_hp()
	c.salary = 6
	return c

static func make_tavern_candidate(rng: RandomNumberGenerator) -> CKCharacter:
	var names = GameState.data_names
	var c := CKCharacter.new()
	c.id = next_id("hire")
	var g = "m" if rng.randf() < 0.55 else "f"
	c.gender = g
	var given_list = names.get("given_m" if g == "m" else "given_f", ["无名"])
	var sur_list = names.get("surnames", ["客"])
	c.name = sur_list[rng.randi() % sur_list.size()] + "·" + given_list[rng.randi() % given_list.size()]
	c.age = rng.randi_range(18, 32)
	var jobs = ["light_inf", "heavy_inf", "hunter", "squire", "apprentice"]
	c.job_id = jobs[rng.randi() % jobs.size()]
	var bl_pool = ["common_ash", "common_ash", "river_ward", "ember_noble"]
	var bl = bl_pool[rng.randi() % bl_pool.size()]
	c.blood_mix = {bl: 1.0}
	# 勋位加权：贵胤更容易男爵
	if bl == "ember_noble":
		c.rank = "baron" if rng.randf() < 0.5 else "knight"
	else:
		c.rank = "knight"
	c.traits = _pick_traits(rng, 2, 3)
	c.appearance = _random_appearance(rng)
	c.birthday_month = rng.randi_range(1, 12)
	_roll_stats_from_blood(c)
	c.salary = 6 + c.rank_index() * 3 + c.level
	c.recalc_hp()
	return c

static func make_marriage_candidate(rng: RandomNumberGenerator, prefer_rank: String = "baron") -> CKCharacter:
	var c := make_tavern_candidate(rng)
	c.gender = "f" if GameState.get_leader() and GameState.get_leader().gender == "m" else "m"
	c.in_roster = false
	c.salary = 0
	# 提高血胤档
	var roll = rng.randf()
	if roll < 0.15:
		c.blood_mix = {"frost_crown": 0.4, "ember_noble": 0.6}
		c.rank = "count"
	elif roll < 0.45:
		c.blood_mix = {"ember_noble": 0.7, "river_ward": 0.3}
		c.rank = prefer_rank if prefer_rank in CKCharacter.RANK_ORDER else "baron"
	else:
		c.blood_mix = {"river_ward": 0.6, "common_ash": 0.4}
		c.rank = "baron" if rng.randf() < 0.5 else "knight"
	_roll_stats_from_blood(c)
	c.recalc_hp()
	var names = GameState.data_names
	var g = c.gender
	var given_list = names.get("given_m" if g == "m" else "given_f", ["无名"])
	var sur_list = names.get("surnames", ["客"])
	c.name = sur_list[rng.randi() % sur_list.size()] + "·" + given_list[rng.randi() % given_list.size()]
	return c

static func make_tutorial_militia(slot: int) -> CKCharacter:
	## 第零章教学临时候补：不上花名册、不占编队栏，仅本场出战。
	var c := CKCharacter.new()
	c.id = next_id("militia")
	c.name = "灰旗民兵·甲" if slot == 0 else "灰旗民兵·乙"
	c.gender = "m"
	c.age = 20
	c.job_id = "light_inf"
	c.rank = "knight"
	c.faction = "player"
	c.in_roster = false
	c.blood_mix = {"common_ash": 1.0}
	c.traits = ["brave"]
	c.appearance = {"hair": "ash_brown" if slot == 0 else "ink_black", "eyes": "slate", "brow": "straight", "scar": "none"}
	c.stats = {"str": 8, "vit": 8, "skl": 6, "agi": 7, "per": 5, "wil": 6}
	c.level = 1
	c.salary = 0
	c.recalc_hp()
	c.hp = c.max_hp
	return c

static func make_enemy(template: String, rng: RandomNumberGenerator) -> CKCharacter:
	var c := CKCharacter.new()
	c.id = next_id("enemy")
	c.faction = "enemy"
	c.in_roster = false
	match template:
		"bandit_weak":
			c.name = "隘口流匪"
			c.job_id = "light_inf"
			c.stats = {"str": 5, "vit": 5, "skl": 4, "agi": 5, "per": 3, "wil": 3}
		"bandit":
			c.name = "隘口匪徒"
			c.job_id = "light_inf"
			c.stats = {"str": 7, "vit": 6, "skl": 5, "agi": 6, "per": 4, "wil": 4}
		"bandit_archer":
			c.name = "匪弓手"
			c.job_id = "hunter"
			c.stats = {"str": 5, "vit": 5, "skl": 8, "agi": 7, "per": 7, "wil": 4}
		"bandit_chief":
			c.name = "匪首"
			c.job_id = "heavy_inf"
			c.stats = {"str": 10, "vit": 9, "skl": 6, "agi": 5, "per": 5, "wil": 6}
		_:
			c.name = "敌军"
			c.job_id = "light_inf"
			c.stats = {"str": 6, "vit": 6, "skl": 6, "agi": 6, "per": 5, "wil": 5}
	c.blood_mix = {"common_ash": 1.0}
	c.level = 1
	c.recalc_hp()
	# slight variance
	c.hp = c.max_hp
	return c

static func _roll_stats_from_blood(c: CKCharacter) -> void:
	var amin := {}
	var amax := {}
	for k in CKCharacter.STAT_KEYS:
		amin[k] = 0.0
		amax[k] = 0.0
	var total_w := 0.0
	for bl_id in c.blood_mix.keys():
		var w = float(c.blood_mix[bl_id])
		total_w += w
		var bl = GameState.get_bloodline(bl_id)
		var smin = bl.get("stat_min", {})
		var smax = bl.get("stat_max", {})
		for k in CKCharacter.STAT_KEYS:
			amin[k] += float(smin.get(k, 4)) * w
			amax[k] += float(smax.get(k, 14)) * w
	if total_w <= 0:
		total_w = 1.0
	c.apt_min = {}
	c.apt_max = {}
	c.stats = {}
	var rng = GameState.rng
	for k in CKCharacter.STAT_KEYS:
		c.apt_min[k] = int(round(amin[k] / total_w))
		c.apt_max[k] = int(round(amax[k] / total_w))
		var lo = c.apt_min[k]
		var hi = mini(c.apt_max[k], lo + 6)
		c.stats[k] = rng.randi_range(lo, maxi(lo, hi))

static func _pick_traits(rng: RandomNumberGenerator, mn: int, mx: int) -> Array:
	var all_traits: Array = GameState.data_traits.get("traits", [])
	var pool: Array = []
	for t in all_traits:
		if t.get("polarity", "pos") == "pos" or rng.randf() < 0.25:
			pool.append(t["id"])
	pool.shuffle()
	var n = rng.randi_range(mn, mx)
	return pool.slice(0, mini(n, pool.size()))

static func _random_appearance(rng: RandomNumberGenerator) -> Dictionary:
	var app = GameState.data_appearance.get("alleles", {})
	var r := {}
	for key in ["hair", "eyes", "brow", "scar"]:
		var arr: Array = app.get(key, [{"id": "none"}])
		r[key] = arr[rng.randi() % arr.size()]["id"]
	if rng.randf() > 0.2:
		r["scar"] = "none"
	return r
