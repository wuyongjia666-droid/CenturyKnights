extends Node
## BTL-10: formula matrix, ZoC leave costs, and HUD copy bound to BattleRules constants.

const FIXTURE := "res://tests/suites/battle/fixtures/formula_matrix.json"

func _ready() -> void:
	var err := _run()
	if err != "":
		print("FAIL formula matrix: ", err)
		get_tree().quit(1)
	else:
		print("FORMULA MATRIX PASS")
		get_tree().quit(0)

func _run() -> String:
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(FIXTURE))
	var cases: Array = parsed.get("cases", [])
	if cases.size() < 200:
		return "fixture %d < 200" % cases.size()
	var mismatches := 0
	var sample := ""
	for case in cases:
		var diff := _check_case(case)
		if diff != "":
			mismatches += 1
			if sample == "":
				sample = diff
	if mismatches > 0:
		return "%d / %d differ; first %s" % [mismatches, cases.size(), sample]
	var zerr := _check_zoc()
	if zerr != "":
		return zerr
	var rerr := _check_rules()
	if rerr != "":
		return rerr
	var cerr := _check_copy()
	if cerr != "":
		return cerr
	var terr := _check_tactics()
	if terr != "":
		return terr
	print("formula matrix OK cases=%d" % cases.size())
	return ""

func _unit(job: String, level: int, traits: Array, agi: int = 8) -> CKCharacter:
	var c := CKCharacter.new()
	c.job_id = job
	c.level = level
	c.stats = {"str": 8, "vit": 8, "skl": 8, "agi": agi, "per": 8, "wil": 8}
	c.traits = traits.duplicate()
	c.weapon_id = ""
	c.hp = 40
	c.max_hp = 40
	return c

func _check_case(case: Dictionary) -> String:
	var atk := _unit(str(case.atk_job), int(case.level[0]), case.get("traits_atk", []))
	var def := _unit(str(case.def_job), int(case.level[1]), case.get("traits_def", []))
	var extras := {"flank": bool(case.flank)}
	if case.has("terrain_mul"):
		extras["terrain_mul"] = float(case.terrain_mul)
	if case.has("flat_def"):
		extras["flat_def"] = int(case.flat_def)
	var terrain := str(case.terrain)
	var hit := BattleRules.calc_hit(atk, def, terrain, extras)
	var dmg: Vector2i = BattleRules.calc_damage_range(atk, def, terrain, extras)
	var pv: Dictionary = BattleRules.preview(atk, def, terrain, extras)
	if hit != int(case.hit) or dmg.x != int(case.dmg[0]) or dmg.y != int(case.dmg[1]):
		return "%s>%s %s flank=%s hit %d/%s dmg %s/%s" % [case.atk_job, case.def_job, terrain, case.flank, hit, case.hit, dmg, case.dmg]
	if int(pv.hit) != hit or pv.dmg != dmg:
		return "preview diverges %s" % case.atk_job
	var label := str(BattleRules.role_mods(atk, def).get("label", ""))
	if label != str(case.get("label", "")):
		return "label %s vs %s" % [label, case.get("label")]
	return ""

func _check_zoc() -> String:
	# Hand walk, orthogonal only. 3×3 plain, enemy on (1,0) blocks that cell.
	# Start (1,1) is in that ZoC. Its four neighbors are (0,1) (2,1) (1,2) (1,0).
	# (1,0) is blocked. The other three leave ZoC, so each costs 1 + LEAVE_COST_ENGAGED.
	# Diagonals are not one step, and a second step would exceed 3 move.
	var terrain := [
		["plain", "plain", "plain"],
		["plain", "plain", "plain"],
		["plain", "plain", "plain"],
	]
	var enemy := Vector2i(1, 0)
	var got: Dictionary = BattleRules.move_costs(terrain, Vector2i(1, 1), 3, [enemy], [enemy], false, 0, BattleRules.LEAVE_COST_ENGAGED, false)
	var want := {
		Vector2i(1, 1): 0,
		Vector2i(0, 1): 3,
		Vector2i(2, 1): 3,
		Vector2i(1, 2): 3,
	}
	if not _same_costs(got, want):
		return "engaged leave costs %s" % got
	# Start (0,2) is outside ZoC. Entering (1,1) or (0,0) costs plain 1, not the leave penalty.
	var enter: Dictionary = BattleRules.move_costs(terrain, Vector2i(0, 2), 3, [enemy], [enemy], false, 0, BattleRules.LEAVE_COST_ENGAGED, false)
	var enter_want := {
		Vector2i(0, 2): 0,
		Vector2i(1, 2): 1,
		Vector2i(0, 1): 1,
		Vector2i(2, 2): 2,
		Vector2i(1, 1): 2,
		Vector2i(0, 0): 2,
		Vector2i(2, 1): 3,
	}
	if not _same_costs(enter, enter_want):
		return "enter zoc %s" % enter
	var open: Dictionary = BattleRules.move_costs(terrain, Vector2i(1, 1), 2, [], [], false, 0, BattleRules.LEAVE_COST_DEFAULT, false)
	var open_want := {
		Vector2i(1, 1): 0,
		Vector2i(0, 1): 1, Vector2i(2, 1): 1, Vector2i(1, 0): 1, Vector2i(1, 2): 1,
		Vector2i(0, 0): 2, Vector2i(2, 0): 2, Vector2i(0, 2): 2, Vector2i(2, 2): 2,
	}
	if not _same_costs(open, open_want):
		return "open move %s" % open
	var wet := [
		["plain", "plain"],
		["water", "water"],
	]
	var wet_got: Dictionary = BattleRules.move_costs(wet, Vector2i(0, 0), 3, [], [], false, 0, 1, false)
	var wet_want := {Vector2i(0, 0): 0, Vector2i(1, 0): 1, Vector2i(0, 1): 3}
	if not _same_costs(wet_got, wet_want):
		return "water move %s" % wet_got
	# Lock uses the higher leave constant and must be strictly costlier than engagement on the same step.
	var lock_got: Dictionary = BattleRules.move_costs(terrain, Vector2i(1, 1), 4, [enemy], [enemy], false, 0, BattleRules.LEAVE_COST_LOCK, false)
	if int(lock_got.get(Vector2i(1, 2), -1)) != 1 + BattleRules.LEAVE_COST_LOCK:
		return "lock leave %s" % lock_got.get(Vector2i(1, 2))
	if BattleRules.LEAVE_COST_LOCK <= BattleRules.LEAVE_COST_ENGAGED:
		return "lock leave not above engaged"
	return ""

func _same_costs(got: Dictionary, want: Dictionary) -> bool:
	if got.size() != want.size():
		return false
	for k in want.keys():
		if not got.has(k) or int(got[k]) != int(want[k]):
			return false
	return true

func _check_rules() -> String:
	var fast := _unit("light_inf", 1, [], 12)
	var slow := _unit("light_inf", 1, [], 8)
	var mid := _unit("light_inf", 1, [], 11)
	if not BattleRules.can_follow_up(fast, slow):
		return "follow-up 12 vs 8"
	if BattleRules.can_follow_up(mid, slow):
		return "follow-up 11 vs 8 should fail"
	if BattleRules.can_follow_up(slow, slow):
		return "follow-up equal agi"
	var melee := _unit("light_inf", 1, [])
	var bow := _unit("hunter", 1, [])
	if not BattleRules.can_counter(melee, melee, Vector2i(0, 0), Vector2i(1, 0)):
		return "melee counter dist 1"
	if BattleRules.can_counter(melee, melee, Vector2i(0, 0), Vector2i(2, 0)):
		return "melee counter dist 2"
	if not BattleRules.can_counter(bow, bow, Vector2i(0, 0), Vector2i(2, 0)):
		return "bow counter dist 2"
	if BattleRules.can_counter(bow, bow, Vector2i(0, 0), Vector2i(0, 3)):
		return "bow counter dist 3"
	melee.hp = 0
	if BattleRules.can_counter(bow, melee, Vector2i(0, 0), Vector2i(1, 0)):
		return "downed counter"
	var err := _check_crit()
	if err != "":
		return err
	return ""

func _check_crit() -> String:
	var atk := _unit("light_inf", 1, [])
	atk.temp_hit_bonus = 80
	atk.stats["str"] = 18
	var low_def := _unit("light_inf", 1, [])
	var high_def := _unit("light_inf", 1, [])
	low_def.hp = 80
	high_def.hp = 80
	atk.temp_crit_bonus = -100
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	var low: Dictionary = BattleRules.roll_attack(atk, low_def, "plain", rng, {})
	atk.temp_crit_bonus = 100
	rng.seed = 42
	var high: Dictionary = BattleRules.roll_attack(atk, high_def, "plain", rng, {})
	if not bool(low.hit) or not bool(high.hit) or bool(low.crit) or not bool(high.crit):
		return "crit setup %s / %s" % [low, high]
	if int(high.damage) != int(int(low.damage) * BattleRules.CRIT_MULT):
		return "crit mult %s vs %s * %s" % [high.damage, low.damage, BattleRules.CRIT_MULT]
	return ""

func _check_copy() -> String:
	var locked := BattleRules.engagement_note(true, true, false, false)
	var engaged := BattleRules.engagement_note(false, true, false, false)
	var free := BattleRules.engagement_note(true, true, true, false)
	if locked.find(str(BattleRules.LEAVE_COST_LOCK)) < 0:
		return "lock copy missing %d" % BattleRules.LEAVE_COST_LOCK
	if engaged.find(str(BattleRules.LEAVE_COST_ENGAGED)) < 0:
		return "engaged copy missing %d" % BattleRules.LEAVE_COST_ENGAGED
	if locked.find("脱离+%d移" % BattleRules.LEAVE_COST_LOCK) < 0:
		return "lock template"
	if engaged.find("脱离+%d移" % BattleRules.LEAVE_COST_ENGAGED) < 0:
		return "engaged template"
	if free.find("脱离不耗") < 0:
		return "leave free copy"
	# Hardcoded digits in the panel would not follow a constant edit.
	var panel := FileAccess.get_file_as_string("res://scripts/battle/ui/battle_info_panel.gd")
	if panel.find("engagement_note") < 0:
		return "info panel does not call engagement_note"
	if panel.find("脱离+1") >= 0 or panel.find("脱离+2") >= 0 or panel.find("脱离+3") >= 0:
		return "info panel still hardcodes a leave digit"
	var ctrl := FileAccess.get_file_as_string("res://scripts/battle/battle_controller.gd")
	if ctrl.find("leave_cost_for") < 0:
		return "controller leave cost not from BattleRules"
	if BattleRules.leave_cost_for(true, true) != BattleRules.LEAVE_COST_LOCK:
		return "lock helper"
	if BattleRules.leave_cost_for(false, true) != BattleRules.LEAVE_COST_ENGAGED:
		return "engaged helper"
	if BattleRules.leave_cost_for(false, false) != BattleRules.LEAVE_COST_DEFAULT:
		return "default helper"
	return ""


func _shown(locus: String, allele: String, copies: int) -> CKCharacter:
	var c := _unit("light_inf", 1, [])
	var pair := [allele, allele if copies >= 2 else "none"]
	c.genome = {"sig": {locus: pair, "pen": {}}, "loci": {"mark": ["none", "none"]}}
	c.age = 30
	return c


func _check_tactics() -> String:
	var keys := {
		"range_high": _shown("tr_ash_wire", "ash_wire", 1),
		"counter": _shown("tr_fc_storm", "fc_storm", 2),
		"night_hit": _shown("tr_sy_geom", "sy_geom", 2),
		"first_hit": _shown("tr_sy_sclera", "sy_sclera", 1),
		"forest_avo": _shown("tr_qh_smooth", "qh_smooth", 1),
		"zoc_ignore": _shown("tr_lt_asym", "lt_asym", 2),
		"fort_def": _shown("tr_fc_temple", "fc_temple", 1),
		"push": _shown("tr_eo_sweep", "eo_sweep", 1),
		"heal_pulse": _shown("tr_sr_fleck", "sr_fleck", 2),
	}
	var want := {
		"range_high": 1, "counter": 3, "night_hit": 8, "first_hit": 5,
		"forest_avo": 6, "zoc_ignore": 1, "fort_def": 2, "push": 1, "heal_pulse": 2,
	}
	for key in want.keys():
		var got := int(keys[key].tactical_amount(key))
		if got != int(want[key]):
			return "%s amount %s" % [key, got]
	var plain := _unit("light_inf", 1, [])
	var hill: CKCharacter = keys["range_high"]
	if BattleRules.attack_reach(plain, "hill") != 1 or BattleRules.attack_reach(hill, "hill") != 2:
		return "range_high reach"
	if BattleRules.attack_reach(hill, "plain") != 1:
		return "range_high off hill"
	var night_base := BattleRules.calc_hit(plain, plain, "plain", {})
	var night_hit := BattleRules.calc_hit(keys["night_hit"], plain, "plain", {"night": true})
	if night_hit != night_base + 8:
		return "night_hit %s vs %s" % [night_hit, night_base]
	var open_hit := BattleRules.calc_hit(keys["first_hit"], plain, "plain", {"opening": true})
	if open_hit != night_base + 5:
		return "first_hit %s" % open_hit
	var forest_base := BattleRules.calc_hit(plain, plain, "forest", {})
	var forest_hit := BattleRules.calc_hit(plain, keys["forest_avo"], "forest", {})
	if forest_hit != forest_base - 6:
		return "forest_avo %s vs %s" % [forest_hit, forest_base]
	var fort_base: Vector2i = BattleRules.calc_damage_range(plain, plain, "fort", {})
	var fort_dmg: Vector2i = BattleRules.calc_damage_range(plain, keys["fort_def"], "fort", {})
	if fort_dmg.x >= fort_base.x and fort_dmg.y >= fort_base.y:
		return "fort_def %s vs %s" % [fort_dmg, fort_base]
	var counter_base: Vector2i = BattleRules.calc_damage_range(plain, plain, "plain", {})
	var counter_dmg: Vector2i = BattleRules.calc_damage_range(keys["counter"], plain, "plain", {"counter": true})
	if counter_dmg.x != counter_base.x + 3 or counter_dmg.y != counter_base.y + 3:
		return "counter %s vs %s" % [counter_dmg, counter_base]
	if BattleRules.zoc_charges(keys["zoc_ignore"]) != 1 or BattleRules.push_tiles(keys["push"], 0) != 1:
		return "zoc or push"
	if BattleRules.heal_pulse(keys["heal_pulse"]) != 2:
		return "heal_pulse"
	var crowned := _unit("light_inf", 1, [])
	crowned.age = 30
	crowned.rank = "count"
	crowned.blood_mix = {"ash_chart": 0.2}
	crowned.genome = {"sig": {"sig_ashbanner": ["river_chart", "none"], "pen": {}}, "loci": {"mark": ["none", "none"]}}
	if not is_equal_approx(crowned.royal_skill_scale("ashbanner"), 0.6):
		return "echo scale %s" % crowned.royal_skill_scale("ashbanner")
	if BattleRules.royal_damage(crowned, "ashbanner", 10) != 6:
		return "echo damage"
	var full := _unit("light_inf", 1, [])
	full.age = 30
	full.blood_mix = {"sy_eclipse": 1.0}
	full.genome = {"sig": {"sig_shuoying": ["eclipse", "eclipse"], "pen": {}}, "loci": {"mark": ["none", "none"]}}
	if not is_equal_approx(full.royal_skill_scale("shuoying"), 1.35):
		return "full scale %s" % full.royal_skill_scale("shuoying")
	if BattleRules.royal_damage(full, "shuoying", 20) != 27:
		return "full damage"
	if BattleRules.royal_damage(plain, "shuoying", 20) != 20:
		return "empty genome scaled"
	return ""
