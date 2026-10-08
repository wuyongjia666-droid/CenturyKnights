class_name CutsceneTimeline
extends RefCounted
## Cutscene timing, playback mode, and budget. Tests read this data; the player
## (combat_cutscene.gd) walks the same segments, so duration does not depend on rendering.
## Budgets are unscaled seconds at 1×. Hold-to-fast-forward is a playback multiplier only.

const MODE_FULL := "full"
const MODE_KEY := "key"
const MODE_OFF := "off"
const FAST_FORWARD := 3.0
const HOLD_MSEC := 180

## Seconds into the attack / skill / crit clip where the hit frame lands.
## Swing segments use this as their duration so damage starts as the frame is reached.
const ACTION_IMPACT := {
	"attack": 0.458,
	"skill": 0.792,
	"crit": 0.5,
}

const BUDGET := {
	"attack": 2.2,
	"dodge": 2.2,
	"crit": 3.0,
	"skill": 3.0,
	"kill": 3.0,
	"first_skill": 4.0,
}

const ACTIONS := ["idle", "advance", "attack", "skill", "hit", "dodge", "crit", "death"]

static var _royal: Dictionary = {}
static var _lines: Dictionary = {}

static func resolve_mode(settings: Dictionary) -> String:
	var raw := str(settings.get("cutscene_mode", "")).strip_edges()
	if raw in [MODE_FULL, MODE_KEY, MODE_OFF]:
		return raw
	if settings.has("cutscenes") and not bool(settings.get("cutscenes", true)):
		return MODE_OFF
	return MODE_FULL

static func effective_speed(base: float, holding: bool) -> float:
	if holding:
		return FAST_FORWARD
	return maxf(0.25, base)

static func action_impact(action: String) -> float:
	return float(ACTION_IMPACT.get(action, ACTION_IMPACT["attack"]))

static func action_for_strike(strike: Dictionary) -> String:
	if str(strike.get("skill", "")) != "":
		return "skill"
	if bool(strike.get("crit", false)):
		return "crit"
	return "attack"

static func royal_table() -> Dictionary:
	if not _royal.is_empty():
		return _royal
	var f := FileAccess.open("res://data/skills.json", FileAccess.READ)
	if f == null:
		return {}
	var parsed = JSON.parse_string(f.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		return {}
	var out := {}
	for s in parsed.get("skills", []):
		if typeof(s) != TYPE_DICTIONARY:
			continue
		var sig := str(s.get("blood_sig", ""))
		if sig == "":
			continue
		var id := str(s.get("id", ""))
		if id == "":
			continue
		out[id] = {"name": str(s.get("name", id)), "blood_sig": sig}
	_royal = out
	return _royal

static func is_royal_skill(label: String) -> bool:
	var key := label.strip_edges()
	if key == "":
		return false
	var table := royal_table()
	if table.has(key):
		return true
	for id in table.keys():
		if str(table[id].get("name", "")) == key:
			return true
	return false

static func record_is_boss(record: Dictionary) -> bool:
	if bool(record.get("boss", false)):
		return true
	for side in ["left", "right"]:
		var pack = record.get(side, {})
		if typeof(pack) != TYPE_DICTIONARY:
			continue
		if bool(pack.get("boss", false)):
			return true
		if _template_is_boss(str(pack.get("template", ""))):
			return true
	return false

static func _template_is_boss(tmpl: String) -> bool:
	var t := tmpl.strip_edges()
	return t.ends_with("_boss") or t.ends_with("_chief") or t.ends_with("_elite")

static func is_key_strike(strike: Dictionary, record: Dictionary = {}) -> bool:
	if record_is_boss(record):
		return true
	if bool(strike.get("crit", false)) or bool(strike.get("killed", false)):
		return true
	if is_royal_skill(str(strike.get("skill", ""))):
		return true
	if is_royal_skill(str(strike.get("skill_id", ""))):
		return true
	return false

static func playback_strikes(record: Dictionary, mode: String) -> Array:
	var strikes: Array = record.get("strikes", [])
	if mode != MODE_KEY:
		return strikes
	if record_is_boss(record):
		return strikes
	var out: Array = []
	for s in strikes:
		if typeof(s) == TYPE_DICTIONARY and is_key_strike(s, record):
			out.append(s)
	return out

static func should_instantiate(record: Dictionary, mode: String) -> bool:
	var strikes: Array = record.get("strikes", [])
	if strikes.is_empty():
		return false
	if mode == MODE_OFF:
		return false
	if mode == MODE_KEY:
		return not playback_strikes(record, MODE_KEY).is_empty()
	return true

static func kind_of(strike: Dictionary, ctx: Dictionary) -> String:
	var skill := str(strike.get("skill", ""))
	var seen: Dictionary = ctx.get("seen_skills", {})
	var first := skill != "" and not bool(seen.get(skill, false))
	if bool(strike.get("killed", false)):
		return "kill"
	if skill != "" and first:
		return "first_skill"
	if skill != "":
		return "skill"
	if bool(strike.get("crit", false)):
		return "crit"
	if not bool(strike.get("hit", false)):
		return "dodge"
	return "attack"

static func hit_stop_duration(strike: Dictionary) -> float:
	if not bool(strike.get("hit", false)):
		return 0.0
	var weight := str(strike.get("weight", ""))
	if weight == "":
		weight = CutsceneVfx.weight_of_job(str(strike.get("job_id", "")))
	return CutsceneVfx.hit_stop_seconds(weight)

static func segments_for(kind: String, strike: Dictionary, ranged: bool) -> Array:
	var action := action_for_strike(strike)
	var swing := action_impact(action)
	var approach := 0.16 if ranged else 0.22
	var approach_id := "aim" if ranged else "approach"
	var skill := str(strike.get("skill", ""))
	var segs: Array = []
	segs.append(_seg("intro", 0.10))
	if kind == "first_skill":
		segs.append(_seg("name", 0.40))
		segs.append(_seg(approach_id, 0.22))
	elif kind in ["skill", "kill"] and skill != "":
		segs.append(_seg("name", 0.18))
		segs.append(_seg(approach_id, approach))
	else:
		segs.append(_seg(approach_id, approach))
	segs.append(_seg("swing", swing, {"impact_at": 1.0}))
	var stop := hit_stop_duration(strike)
	if stop > 0.0 and kind != "dodge":
		segs.append(_seg("hitstop", stop))
	if kind == "dodge" or not bool(strike.get("hit", false)):
		segs.append(_seg("whiff", 0.22))
	else:
		var react := 0.30 if kind in ["crit", "first_skill"] else 0.24
		segs.append(_seg("react", react))
	if kind == "crit":
		segs.append(_seg("hold", 0.22))
	if kind == "first_skill":
		segs.append(_seg("signature", 0.48))
	if kind == "kill":
		segs.append(_seg("death", 0.62))
	else:
		segs.append(_seg("recover", 0.20 if kind == "first_skill" else 0.16))
	var outro := 0.14 if kind in ["crit", "kill", "first_skill"] else 0.12
	segs.append(_seg("outro", outro))
	return segs

static func _seg(id: String, dur: float, extra: Dictionary = {}) -> Dictionary:
	var s := {"id": id, "dur": dur}
	for k in extra.keys():
		s[k] = extra[k]
	return s

static func sum_duration(segs: Array) -> float:
	var t := 0.0
	for s in segs:
		t += float(s.get("dur", 0.0))
	return t

static func impact_time(segs: Array) -> float:
	var t := 0.0
	for s in segs:
		if str(s.get("id", "")) == "swing":
			return t + float(s.get("dur", 0.0)) * float(s.get("impact_at", 1.0))
		t += float(s.get("dur", 0.0))
	return t

static func build_strike(strike: Dictionary, ctx: Dictionary = {}) -> Dictionary:
	var kind := kind_of(strike, ctx)
	var ranged := bool(ctx.get("ranged", strike.get("ranged", false)))
	var segs := segments_for(kind, strike, ranged)
	var total := sum_duration(segs)
	return {
		"kind": kind,
		"action": action_for_strike(strike),
		"segments": segs,
		"total": total,
		"impact": impact_time(segs),
		"budget": float(BUDGET.get(kind, 2.2)),
		"strike": strike,
		"ranged": ranged,
	}

static func for_record(record: Dictionary, mode: String) -> Dictionary:
	var seen := {}
	var built: Array = []
	var index := 0
	for s in playback_strikes(record, mode):
		if typeof(s) != TYPE_DICTIONARY:
			continue
		var ctx := {
			"seen_skills": seen,
			"ranged": bool(s.get("ranged", false)),
			"index": index,
		}
		var one := build_strike(s, ctx)
		built.append(one)
		var skill := str(s.get("skill", ""))
		if skill != "":
			seen[skill] = true
		index += 1
	var total := 0.0
	for one in built:
		total += float(one.get("total", 0.0))
	return {"strikes": built, "total": total, "mode": mode}

static func within_budget(built: Dictionary) -> bool:
	return float(built.get("total", 99.0)) <= float(built.get("budget", 0.0)) + 0.0001

static func line(key: String) -> String:
	if _lines.is_empty():
		_load_lines()
	return str(_lines.get(key, key))

static func _load_lines() -> void:
	_lines["_"] = ""
	var f := FileAccess.open("res://data/locale/cutscene.csv", FileAccess.READ)
	if f == null:
		return
	var first := true
	while not f.eof_reached():
		var line := f.get_line().strip_edges()
		if line == "" or line.begins_with("#"):
			continue
		if first:
			first = false
			continue
		var parts := line.split(",", true, 2)
		if parts.size() < 2:
			continue
		_lines[parts[0].strip_edges()] = parts[1].strip_edges()
