extends Node
## Review 2026-10-17 P1-1 / P1-2: in-house succession (descendant → roster adult → eldest child under
## regency, user ruling 2026-10-17, no outside heir) and a widow may marry again.

func _ready() -> void:
	var err := _descendant_heir()
	if err == "":
		err = _roster_heir()
	if err == "":
		err = _minor_heir_regency()
	if err == "":
		err = _empty_house()
	if err == "":
		err = _legacy_outside_heir()
	if err == "":
		err = _widow()
	if err == "":
		err = _legacy_widow()
	if err != "":
		print("FAIL succession widow: ", err)
		get_tree().quit(1)
	else:
		print("SUCCESSION WIDOW PASS")
		get_tree().quit(0)

## Fresh game with only the captain alive; everyone else from new_game is gone.
func _lone_captain() -> CKCharacter:
	GameState.new_game("烬行", "灰旗", GameState.crest_color)
	var leader := GameState.get_leader()
	for c in GameState.characters.values():
		if c != leader:
			c.alive = false
			c.in_roster = false
	GameState.house_mods.erase("regency")
	return leader

func _add(age: int, parent: CKCharacter, in_roster: bool, rank: String = "knight", level: int = 1) -> CKCharacter:
	var c: CKCharacter = CharacterFactory.make_tavern_candidate(GameState.rng)
	c.age = age
	c.is_child = age < Calendar.ADULT_AGE
	c.in_roster = in_roster and not c.is_child
	c.retired = false
	c.rank = rank
	c.level = level
	c.family_id = ""
	c.parent_ids = [parent.id] if parent != null else []
	c.blood_meta = {}
	GameState.claim_id(c)
	GameState.characters[c.id] = c
	return c

## Rule 1: an adult direct descendant beats a higher-titled roster adult.
func _descendant_heir() -> String:
	var leader := _lone_captain()
	var son := _add(22, leader, false)
	var _baron := _add(40, null, true, "baron", 9)
	leader.alive = false
	var r: Dictionary = Lineage.transfer_banner("death")
	if not bool(r.get("ok", false)) or str(r.get("heir_id", "")) != son.id:
		return "rule 1: heir %s, want descendant %s" % [str(r.get("heir_id", "")), son.id]
	if str(r.get("via", "")) != "descendant" or not son.is_leader or not son.in_roster:
		return "rule 1: descendant not seated (%s)" % str(r)
	if Lineage.is_regency():
		return "rule 1: regency set for an adult heir"
	# Abdication still needs a real descendant.
	var lone := _lone_captain()
	_add(30, null, true)
	if bool(Lineage.transfer_banner("abdicate").get("ok", false)):
		return "abdicate without descendants succeeded"
	if not lone.is_leader:
		return "failed abdication moved the banner"
	return ""

## Rule 2: no adult descendant; roster adults ranked title → merit → age → id; heir joins the house.
func _roster_heir() -> String:
	var leader := _lone_captain()
	var _kid := _add(8, leader, false)
	var old_knight := _add(50, null, true, "knight", 9)
	var baron := _add(25, null, true, "baron", 1)
	var _young_knight := _add(20, null, true, "knight", 9)
	var r: Dictionary = Lineage.transfer_banner("retire")
	if str(r.get("heir_id", "")) != baron.id or str(r.get("via", "")) != "roster":
		return "rule 2: heir %s via %s, want baron %s" % [str(r.get("heir_id", "")), str(r.get("via", "")), baron.id]
	if str(baron.family_id) != str(leader.family_id) or not bool(baron.blood_meta.get("joined_house", false)):
		return "rule 2: roster heir did not join the house"
	if str(r.get("msg", "")).find(baron.name) < 0:
		return "rule 2: event does not name the heir"
	# Same title: merit, then age.
	var l2 := _lone_captain()
	var a := _add(30, null, true, "knight", 3)
	var b := _add(45, null, true, "knight", 3)
	var _c := _add(60, null, true, "knight", 1)
	l2.alive = false
	var r2: Dictionary = Lineage.transfer_banner("death")
	if str(r2.get("heir_id", "")) != b.id:
		return "rule 2 order: heir %s, want older equal-merit knight %s (not %s)" % [str(r2.get("heir_id", "")), b.id, a.id]
	if old_knight.is_leader or a.is_leader:
		return "rule 2: more than one leader"
	if Lineage.has_method("_outside_heir"):
		return "outside-heir path still present"
	return ""

## Rule 3, the original stall: captain dies of age, nobody adult anywhere. Eldest child inherits
## under a visible regency, stays off the roster, and gets the banner back on coming of age.
func _minor_heir_regency() -> String:
	var leader := _lone_captain()
	leader.age = Calendar.DEATH_AGE - 1
	var _young := _add(6, null, false)
	var other := _add(11, null, false)
	var heir := _add(11, leader, false)
	other.birthday_month = heir.birthday_month
	var evs: Array = []
	for i in 13:
		evs.append_array(Calendar.advance(1))
	if leader.alive:
		return "rule 3: captain did not die of age"
	if leader.is_leader:
		return "rule 3: dead captain still holds the banner"
	var now := GameState.get_leader()
	if now != heir:
		return "rule 3: leader %s, want eldest child (descendant on tie) %s" % [str(now.id) if now else "null", heir.id]
	if not now.alive or not now.is_child or now.in_roster:
		return "rule 3: minor heir should stay a child off the roster"
	if not Lineage.is_regency() or str(Lineage.regency().get("ward", "")) != heir.id:
		return "rule 3: regency not recorded"
	if Lineage.regency_status().find(heir.name) < 0:
		return "rule 3: regency status not visible"
	var saw := false
	for e in evs:
		if typeof(e) == TYPE_DICTIONARY and str(e.get("type", "")) == "succession":
			saw = true
	if not saw:
		return "rule 3: no succession event"
	# Coming of age hands the banner back.
	heir.age = Calendar.ADULT_AGE - 1
	var back := false
	for i in 13:
		for e in Calendar.advance(1):
			if typeof(e) == TYPE_DICTIONARY and str(e.get("type", "")) == "regency_end":
				back = true
	if not back:
		return "rule 3: no regency_end event at adulthood"
	if Lineage.is_regency() or Lineage.regency_status() != "":
		return "rule 3: regency still active after adulthood"
	if not heir.is_leader or heir.is_child or not heir.in_roster:
		return "rule 3: adult ward not seated on the roster"
	# Age comes first: an older non-descendant child beats a younger descendant.
	var l3 := _lone_captain()
	var _own := _add(9, l3, false)
	var elder := _add(12, null, false)
	l3.alive = false
	var r3: Dictionary = Lineage.transfer_banner("death")
	if str(r3.get("heir_id", "")) != elder.id or not bool(r3.get("regency", false)):
		return "rule 3 order: heir %s, want eldest child %s" % [str(r3.get("heir_id", "")), elder.id]
	return ""

## Not decided yet (reported, not ruled): nobody alive at all. Current behaviour: no transfer.
func _empty_house() -> String:
	var leader := _lone_captain()
	leader.alive = false
	var r: Dictionary = Lineage.transfer_banner("death")
	if bool(r.get("ok", false)):
		return "empty house: transfer succeeded with nobody alive"
	if Lineage.is_regency():
		return "empty house: regency set with no ward"
	return ""

## Saves from main@b40dce66 may hold a captain flagged outside_heir. They load and keep the banner,
## and the flag is plain data; succession from them follows the in-house order.
func _legacy_outside_heir() -> String:
	var leader := _lone_captain()
	leader.blood_meta["outside_heir"] = true
	var son := _add(20, leader, false)
	var data: Dictionary = GameState.build_save_data()
	if not GameState.apply_save_data(data):
		return "legacy outside_heir: reload failed"
	var back := GameState.get_leader()
	if back == null or not bool(back.blood_meta.get("outside_heir", false)):
		return "legacy outside_heir: leader or flag lost on reload"
	back.alive = false
	var r: Dictionary = Lineage.transfer_banner("death")
	if str(r.get("heir_id", "")) != son.id:
		return "legacy outside_heir: heir %s, want descendant %s" % [str(r.get("heir_id", "")), son.id]
	return ""

func _widow() -> String:
	GameState.new_game("烬行", "灰旗", GameState.crest_color)
	var leader := GameState.get_leader()
	GameState.add_rep("ashland", 300)
	var cand := CharacterFactory.make_marriage_candidate(GameState.rng, "baron", "", leader)
	var wed: Dictionary = Lineage.marry(leader, cand, 0)
	if not bool(wed.get("ok", false)):
		return "first wedding failed: %s" % str(wed.get("msg", ""))
	var sp: CKCharacter = GameState.characters.get(leader.spouse_id)
	if sp == null:
		return "spouse missing after wedding"
	sp.age = Calendar.DEATH_AGE - 1
	sp.pregnant_months = -1
	for i in 13:
		Calendar.advance(1)
	if sp.alive:
		return "spouse did not die of age"
	if leader.spouse_id != "":
		return "widow keeps spouse_id %s" % leader.spouse_id
	if sp.id not in (leader.blood_meta.get("late_spouses", []) as Array):
		return "late spouse not recorded"
	var next := CharacterFactory.make_marriage_candidate(GameState.rng, "baron", "", leader)
	GameState.claim_id(next)
	var gate: Dictionary = Lineage.can_propose(leader, next)
	if str(gate.get("msg", "")).find("已有配偶") >= 0:
		return "widow still blocked: %s" % str(gate.get("msg", ""))
	var again: Dictionary = Lineage.marry(leader, next, 0)
	if not bool(again.get("ok", false)) or leader.spouse_id != next.id:
		return "remarriage failed: %s" % str(again.get("msg", ""))
	return ""

## Saves written before this fix: spouse already dead, spouse_id still set.
func _legacy_widow() -> String:
	GameState.new_game("烬行", "灰旗", GameState.crest_color)
	var leader := GameState.get_leader()
	GameState.add_rep("ashland", 300)
	var cand := CharacterFactory.make_marriage_candidate(GameState.rng, "baron", "", leader)
	Lineage.marry(leader, cand, 0)
	var sp: CKCharacter = GameState.characters.get(leader.spouse_id)
	sp.alive = false
	if Lineage.has_living_spouse(leader):
		return "dead spouse counted as living"
	var data: Dictionary = GameState.build_save_data()
	if not GameState.apply_save_data(data):
		return "reload failed"
	var back := GameState.get_leader()
	if back == null or back.spouse_id != "":
		return "reload did not release the widow"
	if sp.id not in (back.blood_meta.get("late_spouses", []) as Array):
		return "reload did not record the late spouse"
	return ""
