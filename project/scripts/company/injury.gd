class_name CKInjury
extends RefCounted
## CMP-01 casualty table. Classic can kill; casual only retreats with a wound.
## The century sim leaves casualty_mode unset, so it stays on casual and seed 91 does not move.
## Battle UI wires deploy_block_reason / combat_mods. Dynasty UI reads blood_meta.stele.

const DATA_PATH := "res://data/injuries.json"
const MODE_KEY := "casualty_mode"
const MODE_CLASSIC := "classic"
const MODE_CASUAL := "casual"

static var _table: Dictionary = {}


static func table() -> Dictionary:
	if not _table.is_empty():
		return _table
	if not FileAccess.file_exists(DATA_PATH):
		return {}
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(DATA_PATH))
	_table = parsed if typeof(parsed) == TYPE_DICTIONARY else {}
	return _table


static func set_mode(mode: String) -> void:
	GameState.settings[MODE_KEY] = MODE_CLASSIC if mode == MODE_CLASSIC else MODE_CASUAL


static func mode() -> String:
	var raw := str(GameState.settings.get(MODE_KEY, table().get("default_mode", MODE_CASUAL)))
	return MODE_CLASSIC if raw == MODE_CLASSIC else MODE_CASUAL


static func death_chance(difficulty: int, overflow: int) -> float:
	var spec := table()
	var bases: Array = spec.get("death_base", [0.05, 0.10, 0.18, 0.28, 0.40])
	var idx := clampi(difficulty, 0, bases.size() - 1)
	var step := float(spec.get("overflow_step", 0.04))
	var extra := minf(float(spec.get("overflow_cap", 0.45)), maxf(0.0, float(overflow)) * step)
	return minf(float(spec.get("death_cap", 0.85)), float(bases[idx]) + extra)


static func record(c: CKCharacter) -> Dictionary:
	if c == null or typeof(c.blood_meta) != TYPE_DICTIONARY:
		return {}
	var raw = c.blood_meta.get("injury", {})
	return raw.duplicate(true) if typeof(raw) == TYPE_DICTIONARY else {}


static func deploy_block_reason(c: CKCharacter) -> String:
	if c == null:
		return ""
	if not c.alive:
		return Locale.t("已阵亡")
	var rec := record(c)
	if str(rec.get("tier", "")) == "grave" and int(rec.get("months_left", 0)) > 0:
		return Locale.t("injury.grave_months") % int(rec.get("months_left", 0))
	return ""


static func combat_mods(c: CKCharacter) -> Dictionary:
	var rec := record(c)
	return {
		"skl": -int(rec.get("skl_applied", 0)),
		"move": int(rec.get("move", 0)),
	}


static func move_mod(c: CKCharacter) -> int:
	return int(combat_mods(c).get("move", 0))


static func label(c: CKCharacter) -> String:
	var rec := record(c)
	if rec.is_empty():
		return ""
	var name := str(rec.get("name", Locale.t("负伤")))
	var left := int(rec.get("months_left", 0))
	if str(rec.get("tier", "")) == "lasting":
		return name
	if left > 0:
		return Locale.t("injury.wound_label") % [name, left]
	return name


static func resolve(c: CKCharacter, difficulty: int, overflow: int, seed_i: int, killer: String = "") -> Dictionary:
	if c == null or not c.alive:
		return {"ok": false, "outcome": "skip"}
	if str(c.faction) == "enemy":
		return {"ok": false, "outcome": "skip"}
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_i
	var ticket := rng.randf()
	if mode() == MODE_CLASSIC and ticket < death_chance(difficulty, overflow):
		_kill(c, rng, killer)
		return {"ok": true, "outcome": "death", "seed": seed_i}
	var wound := _wound(c, difficulty, rng)
	wound["seed"] = seed_i
	return wound


static func tick_month(host) -> String:
	var notes: PackedStringArray = []
	for c in host.roster():
		var rec := record(c)
		if rec.is_empty() or str(rec.get("tier", "")) == "lasting":
			continue
		var left := int(rec.get("months_left", 0)) - 1
		if left <= 0:
			_clear(c)
			notes.append(Locale.t("injury.healed") % c.name)
		else:
			rec["months_left"] = left
			_write(c, rec)
	return "；".join(notes)


static func on_harvest(c: CKCharacter) -> bool:
	## Legacy injured flags still clear at harvest. Structured light wounds do too.
	## Grave and lasting wounds stay, so a harvest cannot erase a broken bone.
	var rec := record(c)
	if rec.is_empty():
		return c.injured
	if str(rec.get("tier", "")) == "light":
		_clear(c)
		return true
	return false


static func ease_at_shrine(c: CKCharacter, shrine_level: int) -> void:
	var rec := record(c)
	var tier := str(rec.get("tier", ""))
	if tier == "light":
		_clear(c)
		c.injured = false
	elif tier == "grave":
		var cut := maxi(1, shrine_level)
		rec["months_left"] = maxi(0, int(rec.get("months_left", 0)) - cut)
		if int(rec["months_left"]) <= 0:
			_clear(c)
			c.injured = false
		else:
			_write(c, rec)
			c.injured = true
	elif tier == "":
		c.injured = false


static func mitigate(c: CKCharacter, source: String) -> Dictionary:
	var rec := record(c)
	if str(rec.get("tier", "")) != "lasting":
		return {"ok": false, "msg": Locale.t("没有永久伤")}
	if source == "clinic":
		if GameState.herb < 1:
			return {"ok": false, "msg": Locale.t("药材不够")}
		GameState.herb -= 1
	elif source == "heirloom":
		if str(c.weapon_id) == "":
			return {"ok": false, "msg": Locale.t("没有可依的传家兵器")}
	else:
		return {"ok": false, "msg": Locale.t("未知的缓解")}
	var back := int(rec.get("skl_applied", 0))
	if back != 0:
		c.stats["skl"] = int(c.stats.get("skl", 0)) + back
	_clear(c)
	c.injured = false
	GameState.log_event(Locale.t("injury.eased") % [c.name, Locale.t("药材") if source == "clinic" else Locale.t("传家兵器")])
	return {"ok": true, "msg": Locale.t("永久伤缓解了")}


static func attach(battle: Node) -> void:
	if battle == null or not is_instance_valid(battle):
		return
	if battle.has_meta("_ck_injury"):
		return
	if not battle.has_signal("unit_downed") or not battle.has_signal("battle_finished"):
		return
	battle.set_meta("_ck_injury", true)
	battle.set_meta("_ck_downs", [])
	battle.connect("unit_downed", func(who, info): _note(battle, who, info))
	battle.connect("battle_finished", func(_result): _settle(battle))


static func _note(battle: Node, who, info: Dictionary) -> void:
	if who == null or str(info.get("team", "")) != "player":
		return
	var map_id := str(info.get("map_id", ""))
	var row := {
		"id": str(who.id),
		"map_id": map_id,
		"killer": str(info.get("killer", "")),
		"overflow": int(info.get("overflow", _overflow(battle))),
		"seed": int(info.get("seed", hash("%s|%s|%d" % [str(who.id), map_id, int(who.hp)]))),
	}
	var downs: Array = battle.get_meta("_ck_downs", [])
	downs.append(row)
	battle.set_meta("_ck_downs", downs)


static func _settle(battle: Node) -> void:
	var downs: Array = battle.get_meta("_ck_downs", [])
	battle.set_meta("_ck_downs", [])
	for row in downs:
		var c: CKCharacter = GameState.characters.get(str(row.get("id", "")))
		if c == null:
			continue
		var map_id := str(row.get("map_id", ""))
		resolve(c, GameState.battle_difficulty_from_map(map_id), int(row.get("overflow", 0)), int(row.get("seed", 1)), str(row.get("killer", "")))


static func _overflow(battle: Node) -> int:
	if battle == null:
		return 0
	var rows = battle.get("_combat_rec")
	if typeof(rows) != TYPE_ARRAY or rows.is_empty():
		return 0
	var last: Dictionary = rows[rows.size() - 1]
	if not bool(last.get("killed", false)):
		return 0
	return maxi(0, int(last.get("dmg", 0)) - int(last.get("hp_before", 0)))


static func _wound(c: CKCharacter, difficulty: int, rng: RandomNumberGenerator) -> Dictionary:
	var spec := table()
	var grave_p := float(spec.get("grave_base", 0.12)) + float(difficulty) * float(spec.get("grave_per_diff", 0.06))
	var lasting_p := float(spec.get("lasting_base", 0.10)) + float(difficulty) * float(spec.get("lasting_per_diff", 0.04))
	var roll := rng.randf()
	var tier := "light"
	if roll < grave_p:
		tier = "grave"
	elif roll < grave_p + lasting_p:
		tier = "lasting"
	_replace_weaker(c)
	var rec := {"tier": tier, "months_left": 0, "skl_applied": 0, "move": 0, "id": "", "name": ""}
	if tier == "lasting":
		var kinds: Array = spec.get("lasting", [])
		var kind: Dictionary = kinds[rng.randi() % kinds.size()] if not kinds.is_empty() else {"id": "limp", "name": Locale.t("跛足"), "skl": 0, "move": -1}
		rec["id"] = str(kind.get("id", "limp"))
		rec["name"] = str(kind.get("name", Locale.t("永久伤")))
		var skl_delta := int(kind.get("skl", 0))
		if skl_delta < 0:
			c.stats["skl"] = maxi(1, int(c.stats.get("skl", 1)) + skl_delta)
			rec["skl_applied"] = -skl_delta
		rec["move"] = int(kind.get("move", 0))
	elif tier == "grave":
		var span: Array = spec.get("grave_months", [3, 6])
		var lo := int(span[0])
		var hi := int(span[1]) if span.size() > 1 else lo
		rec["months_left"] = lo + rng.randi_range(0, maxi(0, hi - lo))
		rec["id"] = "fracture"
		rec["name"] = Locale.t("重伤")
	else:
		var span2: Array = spec.get("light_months", [1, 2])
		var lo2 := int(span2[0])
		var hi2 := int(span2[1]) if span2.size() > 1 else lo2
		rec["months_left"] = lo2 + rng.randi_range(0, maxi(0, hi2 - lo2))
		rec["id"] = "bruise"
		rec["name"] = Locale.t("轻伤")
	_write(c, rec)
	c.injured = true
	return {"ok": true, "outcome": tier, "months": int(rec["months_left"]), "id": str(rec["id"])}


static func _replace_weaker(c: CKCharacter) -> void:
	var prev := record(c)
	if int(prev.get("skl_applied", 0)) > 0:
		c.stats["skl"] = int(c.stats.get("skl", 0)) + int(prev.get("skl_applied", 0))


static func _kill(c: CKCharacter, rng: RandomNumberGenerator, killer: String) -> void:
	_replace_weaker(c)
	_clear(c)
	c.alive = false
	c.in_roster = false
	c.injured = false
	c.hp = 0
	var words: Array = table().get("words", [])
	var line := str(words[rng.randi() % words.size()]) if not words.is_empty() else Locale.t("旗还在。")
	if typeof(c.blood_meta) != TYPE_DICTIONARY:
		c.blood_meta = {}
	c.blood_meta["stele"] = {
		"cause": "battle",
		"words": line,
		"when": Calendar.label() if Calendar else "",
		"killer": killer,
		"name": c.name,
	}
	var text := Locale.t("injury.death_last_words") % [c.name, line]
	GameState.add_lineage_event(text)
	GameState.log_event(text)
	var kept: Array = []
	for id in GameState.deploy_ids:
		if str(id) != c.id:
			kept.append(id)
	GameState.deploy_ids = kept
	if c.is_leader:
		Lineage.transfer_banner("death")


static func _write(c: CKCharacter, rec: Dictionary) -> void:
	if typeof(c.blood_meta) != TYPE_DICTIONARY:
		c.blood_meta = {}
	c.blood_meta["injury"] = rec


static func _clear(c: CKCharacter) -> void:
	if typeof(c.blood_meta) == TYPE_DICTIONARY:
		c.blood_meta.erase("injury")
	c.injured = false
