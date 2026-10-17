extends Node
## User decision 2026-10-17: repeat natural conception after the wedding. A normal marriage
## reaches two children, three or four are common, more are rare but not capped; multiples are
## near-real luck only. Checks the curve on synthetic couples, the litter odds, a real calendar
## family, a forced twin birth and the save round trip.

const COUPLES := 600
const LITTER_ROLLS := 300000

class FakeHost extends RefCounted:
	var characters: Dictionary = {}
	var rng := RandomNumberGenerator.new()
	var house_mods: Dictionary = {}

func _ready() -> void:
	await get_tree().process_frame
	var err := _curve()
	if err == "":
		err = _litters()
	if err == "":
		err = _calendar_family()
	if err == "":
		err = _twins_and_save()
	if err != "":
		print("FAIL multi birth: ", err)
		get_tree().quit(1)
	else:
		print("MULTI BIRTH PASS")
		get_tree().quit(0)

func _person(id: String, gender: String, age: int) -> CKCharacter:
	var c := CKCharacter.new()
	c.id = id
	c.gender = gender
	c.age = age
	c.alive = true
	c.name = id
	return c

## Synthetic couples wed at 18–30 and stay alive to 49: births come only from tick_conception.
func _curve() -> String:
	var host := FakeHost.new()
	host.rng.seed = 20261017
	var wives: Array = []
	for i in COUPLES:
		var age := 18 + i % 13
		var w := _person("w%d" % i, "f", age)
		var h := _person("h%d" % i, "m", age + 2)
		w.spouse_id = h.id
		h.spouse_id = w.id
		w.blood_meta["children_born"] = 0
		host.characters[w.id] = w
		host.characters[h.id] = h
		wives.append(w)
	for m in range(1, 31 * 12 + 1):
		for w in wives:
			if w.pregnant_months >= 0:
				w.pregnant_months -= 1
				if w.pregnant_months < 0:
					w.blood_meta["children_born"] = int(w.blood_meta["children_born"]) + int(w.blood_meta.get("litter", 1))
					w.blood_meta.erase("litter")
					w.blood_meta["last_birth_abs"] = m
			if m % 12 == 0:
				w.age += 1
				host.characters[w.spouse_id].age += 1
		CKFamilyState.tick_conception(host, m)
	var dist := {}
	for w in wives:
		var n := int(w.blood_meta["children_born"])
		dist[n] = int(dist.get(n, 0)) + 1
	var share := func(lo: int, hi: int) -> float:
		var t := 0
		for k in dist.keys():
			if int(k) >= lo and int(k) <= hi:
				t += int(dist[k])
		return float(t) / COUPLES
	print("MULTI BIRTH dist ", dist)
	if share.call(2, 99) < 0.97:
		return "only %.3f of couples reached two children %s" % [share.call(2, 99), str(dist)]
	if share.call(3, 4) < 0.55:
		return "three/four children not common: %.3f %s" % [share.call(3, 4), str(dist)]
	if share.call(5, 99) > 0.15 or share.call(5, 99) <= 0.0:
		return "five+ should be rare but present: %.3f %s" % [share.call(5, 99), str(dist)]
	if CKFamilyState.parity_factor(12) <= 0.0:
		return "parity factor reached zero (cap)"
	return ""

func _litters() -> String:
	var rng := RandomNumberGenerator.new()
	rng.seed = 85
	var n := {1: 0, 2: 0, 3: 0, 4: 0}
	for _i in LITTER_ROLLS:
		var k := CKFamilyState.roll_litter(rng)
		n[k] = int(n.get(k, 0)) + 1
	var twins := float(n[2]) / LITTER_ROLLS
	if absf(twins - 1.0 / 85.0) > 0.0015:
		return "twin rate %.4f, want ~%.4f" % [twins, 1.0 / 85.0]
	if float(n[3]) / LITTER_ROLLS > 0.0006:
		return "triplets too common: %d" % n[3]
	return ""

## Real calendar: a peak-age wedding leads to at least two children within eight years.
func _calendar_family() -> String:
	GameState.new_game("灯影", "灰旗", "frost")
	GameState.rng.seed = 3301
	GameState.add_rep("ashland", 300)
	CKFamilyState.set_fast_family(GameState, false)
	var leader: CKCharacter = GameState.get_leader()
	var bride := _person("bride_mb", "f" if leader.gender == "m" else "m", 21)
	GameState.characters[bride.id] = bride
	if not Lineage.marry(leader, bride, 0, [], true).get("ok", false):
		return "wedding refused"
	var mother: CKCharacter = bride if bride.gender == "f" else leader
	Calendar.advance(96)
	var born := CKFamilyState.born_to(GameState, mother)
	if born < 2:
		return "calendar family has %d children after eight years" % born
	var kids := 0
	for c in GameState.characters.values():
		if mother.id in c.parent_ids:
			kids += 1
	return "" if kids == born else "children_born %d but %d children listed" % [born, kids]

func _twins_and_save() -> String:
	var mother: CKCharacter = null
	for c in GameState.characters.values():
		if c.alive and str(c.gender) == "f" and str(c.spouse_id) != "":
			mother = c
	if mother == null:
		return "no wife for the twin check"
	var before := CKFamilyState.born_to(GameState, mother)
	mother.pregnant_months = 0
	mother.blood_meta["litter"] = 2
	var evs: Array = Calendar.advance(1)
	if CKFamilyState.born_to(GameState, mother) != before + 2:
		return "twin term gave %d children" % (CKFamilyState.born_to(GameState, mother) - before)
	var multi := false
	for e in evs:
		if str(e.get("type", "")) == "birth" and not e.has("cid") and str(e.get("text", "")).begins_with(Locale.t("birth_multi", [mother.name, 2, ""]).rstrip(" ")):
			multi = true
	if not multi:
		return "no multi-birth line in the month report: %s" % str(evs)
	mother.pregnant_months = 4
	mother.blood_meta["litter"] = 3
	var back := CKCharacter.from_dict(mother.to_dict())
	if int(back.blood_meta.get("litter", 0)) != 3 or int(back.blood_meta.get("last_birth_abs", -1)) != int(mother.blood_meta.get("last_birth_abs", -2)):
		return "litter/postpartum lost on save: %s" % str(back.blood_meta)
	if int(back.blood_meta.get("children_born", -1)) != before + 2:
		return "children_born lost on save"
	return ""
