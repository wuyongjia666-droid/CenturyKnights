class_name CKTacticsAI
extends RefCounted
## Shared tactics policy for the enemy brain and the headless campaign sim.
## Theme weights live in enemy_themes.json. Royal skills are scored by the situation, not by a fixed list.

const BEHAVIOR_KEYS := ["aggression", "hold", "flank", "protect", "skirmish", "skill"]
const DEFAULT_BEHAVIOR := {
	"aggression": 0.5, "hold": 0.4, "flank": 0.4, "protect": 0.4, "skirmish": 0.4, "skill": 0.5,
}
## Elite enemies of a theme carry that nation's royal skill, so the brain has a real choice.
const THEME_SKILL := {
	"bandit": "gorge_breaker", "escort": "eclipse_gaze", "fisher": "tide_edict", "paper": "jade_clarity",
	"copper": "kiln_reforge", "lamp": "lamp_feint", "grain": "chart_rally", "snow": "bell_hush",
	"bamboo": "firefly_ferry", "relay": "eclipse_gaze", "bell": "dipper_fix", "rain": "dipper_fix",
	"ink": "jade_clarity", "hive": "bell_hush", "flute": "lamp_feint", "shadow": "eclipse_gaze",
	"salt": "tide_edict", "dye": "gorge_breaker", "drum": "gorge_breaker", "incense": "kiln_reforge",
	"tide": "tide_edict", "porcelain": "kiln_reforge",
}

static func behavior_for(theme_id: String) -> Dictionary:
	var themes: Dictionary = UnitModel.enemy_themes().get("themes", {})
	var raw: Dictionary = themes.get(theme_id, {}).get("behavior", {})
	var out := DEFAULT_BEHAVIOR.duplicate()
	for k in BEHAVIOR_KEYS:
		if raw.has(k):
			out[k] = clampf(float(raw[k]), 0.0, 1.0)
	return out

static func behavior_distance(a: Dictionary, b: Dictionary) -> float:
	var d := 0.0
	for k in BEHAVIOR_KEYS:
		d += absf(float(a.get(k, 0.0)) - float(b.get(k, 0.0)))
	return d

static func theme_skill(theme_id: String) -> String:
	return str(THEME_SKILL.get(theme_id, ""))

static func themes_are_distinct() -> String:
	var themes: Dictionary = UnitModel.enemy_themes().get("themes", {})
	var ids: Array = themes.keys()
	ids.sort()
	if ids.size() < 22:
		return "theme count %d" % ids.size()
	for i in ids.size():
		var ba := behavior_for(str(ids[i]))
		for k in BEHAVIOR_KEYS:
			if not (themes[ids[i]] as Dictionary).get("behavior", {}).has(k):
				return "%s missing %s" % [ids[i], k]
		for j in range(i + 1, ids.size()):
			var bb := behavior_for(str(ids[j]))
			if behavior_distance(ba, bb) < 0.35:
				return "%s ~ %s (%.2f)" % [ids[i], ids[j], behavior_distance(ba, bb)]
	return ""

## situation: hp_frac, locked, on_ground, ally_hurt, allies_near, foe_near, foe_hp_frac, foe_on_cover
static func score_skill(sid: String, sit: Dictionary) -> float:
	var gs = Engine.get_main_loop().root.get_node_or_null("GameState") if Engine.get_main_loop() else null
	if gs == null:
		return -1.0
	var sk: Dictionary = gs.get_skill(sid)
	if sk.is_empty():
		return -1.0
	var typ := str(sk.get("type", ""))
	var hp := float(sit.get("hp_frac", 1.0))
	var locked := bool(sit.get("locked", false))
	var ground := bool(sit.get("on_ground", false))
	var ally_hurt := bool(sit.get("ally_hurt", false))
	var allies := int(sit.get("allies_near", 0))
	var foe := bool(sit.get("foe_near", false))
	var foe_hp := float(sit.get("foe_hp_frac", 1.0))
	var cover := bool(sit.get("foe_on_cover", false))
	var blood := str(sk.get("blood_sig", "")) != ""
	var s := 0.0
	if typ == "offense":
		if not foe:
			return -1.0
		s = float(sk.get("dmg_mul", 1.0)) + float(sk.get("hit_mod", 0)) * 0.03
		if foe_hp < 0.5:
			s += 1.5
		if cover and bool(sk.get("ignore_terrain_avo", false)):
			s += 1.3
		if int(sk.get("expose", 0)) > 0:
			s += 0.45
		if float(sk.get("cleave_pct", 0.0)) > 0.0:
			s += 0.35
		if blood:
			s += 0.55
		return s
	if typ == "support":
		if not ally_hurt:
			return -1.0
		s = 2.1 + float(sk.get("heal_max", 8)) * 0.06
		if int(sk.get("party_def_buff", 0)) > 0:
			s += 0.7 + allies * 0.15
		if blood:
			s += 0.45
		return s
	var emergency := locked and hp < 0.8
	if bool(sk.get("clear_combat_lock", false)) or bool(sk.get("leave_free", false)):
		if emergency:
			s = 4.2 + (0.8 - hp) * 3.0
		elif foe and blood:
			s = 1.15
	if bool(sk.get("terrain_ward", false)):
		s = maxf(s, 3.4 if ground else (0.6 if foe else 0.0))
	if int(sk.get("party_def_buff", 0)) > 0 and allies >= 1 and foe:
		s = maxf(s, 2.2 + allies * 0.4 + float(sk.get("party_def_buff", 0)) * 0.25)
	if bool(sk.get("ignore_zoc", false)) and foe:
		s += 0.55
	if int(sk.get("def_buff", 0)) > 0 and foe:
		s = maxf(s, 1.15 if hp < 0.75 else 0.85)
	if int(sk.get("next_crit_bonus", 0)) > 0 and foe and not emergency:
		s += 0.4
	if blood and s > 0.0:
		s += 0.4
	return s

static func best_skill(known: Array, ready: Callable, sit: Dictionary, want_type: String, min_score: float = 0.9) -> String:
	var best := ""
	var best_s := min_score
	var gs = Engine.get_main_loop().root.get_node_or_null("GameState") if Engine.get_main_loop() else null
	if gs == null:
		return ""
	for sid in known:
		var id := str(sid)
		var sk: Dictionary = gs.get_skill(id)
		var typ := str(sk.get("type", ""))
		if want_type == "offense" and typ != "offense":
			continue
		if want_type == "prep" and typ == "offense":
			continue
		if ready.is_valid() and not bool(ready.call(id)):
			continue
		var sc := score_skill(id, sit)
		if sc > best_s:
			best_s = sc
			best = id
	return best

static func cast_gate(skill_weight: float) -> float:
	return clampf(0.28 + 0.68 * skill_weight, 0.2, 0.96)
