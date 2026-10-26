extends Node
## Marriage → pregnancy → birth → genealogy → in-company succession, and a one-way purse.
## Proves a hired mercenary can wed, a real 9–11 month term delivers, the sire stays the parent
## after the spouse dies, familyless kin show the castle banner and family kin show family arms,
## only the successor receives the office title, and field wages cannot be pulled back out of the treasury.

var _merc: CKCharacter
var _mother: CKCharacter
var _sire: CKCharacter
var _kids: Array = []

func _ready() -> void:
	var err := _merc_birth()
	if err == "":
		err = _succession()
	if err == "":
		err = _wallet()
	if err != "":
		print("FAIL dynasty durability: ", err)
		get_tree().quit(1)
	else:
		print("DYNASTY DURABILITY PASS")
		get_tree().quit(0)


func _merc_birth() -> String:
	var err := _wed_merc()
	if err == "":
		err = _term_birth()
	if err == "":
		err = _widow_birth()
	if err == "":
		err = _family_arms()
	return err


func _wed_merc() -> String:
	GameState.new_game("烬行", "灰旗", GameState.crest_color)
	GameState.rng.seed = 20261025
	CKFamilyState.set_fast_family(GameState, false)
	GameState.reputation["ashland"] = 100
	GameState.silver = 800
	GameState.food = 400
	GameState.morale = 80
	for c in GameState.characters.values():
		c.age = 28
	if GameState.tavern_candidates.is_empty():
		return "tavern empty"
	_merc = GameState.tavern_candidates[0]
	_merc.age = 22
	var hired: Dictionary = GameState.recruit(_merc, 0)
	if not bool(hired.get("ok", false)) or not _merc.in_roster:
		return "recruit failed %s" % str(hired.get("msg", ""))
	if not CKFamilyState.is_marriage_suitor(_merc):
		return "hired merc is not a suitor"
	if CKFamilyState.is_hero_party(_merc):
		return "hired merc flagged as hero party"
	var wed: Dictionary = {}
	var bride: CKCharacter = null
	for _i in 6:
		GameState.refresh_marriage_candidates("", _merc)
		if GameState.marriage_candidates.is_empty():
			return "no court posts for merc"
		bride = GameState.marriage_candidates[0]
		bride.age = 22
		wed = Lineage.marry(_merc, bride, 0, null, true)
		if bool(wed.get("ok", false)):
			break
	if not bool(wed.get("ok", false)):
		return "merc marry failed: %s" % str(wed.get("msg", ""))
	if str(_merc.spouse_id) == "" or str(bride.spouse_id) != _merc.id:
		return "spouse link not mutual"
	if GameState.flag("child_born"):
		return "merc wedding set the teaching birth flag"
	_mother = bride if str(bride.gender) == "f" else _merc
	_sire = _merc if _mother == bride else bride
	_mother.family_id = ""
	_sire.family_id = ""
	_mother.age = 22
	_sire.age = 24
	return ""


func _term_birth() -> String:
	var wait := _wait_term(_mother)
	if wait != "":
		return wait
	var sire_id := str(_mother.blood_meta.get("sire_id", ""))
	if sire_id == "" or sire_id != _sire.id:
		return "sire not stamped (%s)" % sire_id
	var term := int(_mother.blood_meta.get("gestation_term", -1))
	var ticks := _deliver(_mother)
	if ticks != term:
		return "birth took %d ticks, term %d" % [ticks, term]
	_kids = _kids_of(_mother)
	if _kids.is_empty():
		return "no child after the term"
	var lead := GameState.get_leader()
	for kid in _kids:
		var bad := _familyless_child(kid, lead)
		if bad != "":
			return bad
	if GameState.flag("child_born"):
		return "mercenary birth tripped chapter0 child_born"
	return ""


func _familyless_child(kid: CKCharacter, lead: CKCharacter) -> String:
	if _sire.id not in kid.parent_ids or _mother.id not in kid.parent_ids:
		return "genealogy parents %s" % str(kid.parent_ids)
	if lead != null and lead.id in kid.parent_ids and lead.id != _sire.id and lead.id != _mother.id:
		return "leader substituted as parent"
	if kid.rank != "knight" or str(kid.blood_meta.get("title", "")) != "" or str(kid.blood_meta.get("title_from", "")) != "":
		return "birth granted a title to %s" % kid.name
	if str(kid.family_id) != "":
		return "familyless parents produced a family id"
	if CKHeraldryChrome.is_family_member(kid) or CKHeraldryChrome.arms_kind_key(kid) != "gen2_35":
		return "familyless child is not on the castle banner"
	if CKHeraldry.core_key(CKHeraldryChrome.person_spec(kid)) != CKHeraldry.core_key(CKHeraldryChrome.company_spec()):
		return "familyless arms drifted off the company banner"
	return ""


func _widow_birth() -> String:
	## Widow the sire mid-term. The next child still names that sire, not the captain.
	_mother.pregnant_months = -1
	var conceived := false
	for _j in 40:
		if CKFamilyState.begin_pregnancy(GameState, _mother):
			conceived = true
			break
	if not conceived:
		return "second conception never landed"
	if str(_mother.blood_meta.get("sire_id", "")) != _sire.id:
		return "second term replaced the sire"
	_sire.alive = false
	Lineage.widow_partner(_sire)
	if str(_mother.spouse_id) != "":
		return "widow still holds spouse_id"
	if str(_mother.blood_meta.get("sire_id", "")) != _sire.id:
		return "widowhood cleared the sire"
	var term2 := int(_mother.blood_meta.get("gestation_term", -1))
	var ticks2 := _deliver(_mother)
	if ticks2 != term2:
		return "widow term took %d, want %d" % [ticks2, term2]
	var seen := {}
	for old in _kids:
		seen[old.id] = true
	var born_now: Array = []
	for kid2 in _kids_of(_mother):
		if not seen.has(kid2.id):
			born_now.append(kid2)
	if born_now.is_empty():
		return "widow term produced no child"
	var lead := GameState.get_leader()
	for newborn in born_now:
		if _sire.id not in newborn.parent_ids:
			return "widow birth lost the sire"
		if lead != null and lead.id in newborn.parent_ids:
			return "widow birth parented the captain"
	return ""


func _wait_term(mother: CKCharacter) -> String:
	var guard := 0
	while int(mother.pregnant_months) < 0 and guard < 80:
		Calendar.advance(1)
		guard += 1
	if int(mother.pregnant_months) < 0:
		return "no conception in %d months" % guard
	var term := int(mother.blood_meta.get("gestation_term", -1))
	if term < CKFamilyState.TERM_MONTHS_MIN or term > CKFamilyState.TERM_MONTHS_MAX:
		return "term %d not in 9-11" % term
	if int(mother.pregnant_months) != term - 1:
		return "countdown %d want %d" % [int(mother.pregnant_months), term - 1]
	return ""


func _deliver(mother: CKCharacter) -> int:
	var before := _kids_of(mother).size()
	var term := int(mother.blood_meta.get("gestation_term", int(mother.pregnant_months) + 1))
	for n in range(1, term + 2):
		Calendar.advance(1)
		if _kids_of(mother).size() > before:
			return n
	return -1


func _kids_of(mother: CKCharacter) -> Array:
	var out: Array = []
	for c in GameState.characters.values():
		if c != null and mother.id in c.parent_ids:
			out.append(c)
	out.sort_custom(func(a, b): return str(a.id) < str(b.id))
	return out


func _family_arms() -> String:
	var leader := GameState.get_leader()
	if leader == null or str(leader.family_id) == "":
		return "leader has no family"
	leader.rank = "count"
	leader.blood_meta["title"] = "count"
	GameState.silver = 400
	var spouse := CharacterFactory.make_marriage_candidate(GameState.rng, "knight", "", leader)
	spouse.age = 24
	spouse.family_id = ""
	var wed: Dictionary = Lineage.marry(leader, spouse, 0)
	if not bool(wed.get("ok", false)):
		return "leader wedding failed: %s" % str(wed.get("msg", ""))
	var mother: CKCharacter = spouse if str(spouse.gender) == "f" else leader
	var father: CKCharacter = leader if mother == spouse else spouse
	if father != leader:
		father.family_id = ""
	if mother != leader:
		mother.family_id = ""
	if _deliver(mother) < 0:
		return "leader line did not deliver"
	if not GameState.flag("child_born"):
		return "leader birth did not set the teaching flag"
	var kid: CKCharacter = _kids_of(mother).back()
	if kid == null:
		return "leader child missing"
	if kid.rank != "knight" or str(kid.blood_meta.get("title_from", "")) != "":
		return "leader child inherited the count title at birth"
	if str(kid.family_id) != str(leader.family_id):
		return "child family %s" % kid.family_id
	if not CKHeraldryChrome.is_family_member(kid) or CKHeraldryChrome.arms_kind_key(kid) != "gen2_06":
		return "family child is not on family arms"
	var fam: Dictionary = GameState.families.get(leader.family_id, {})
	var shown := GameState.arms_for_character(kid)
	var expect := CKHeraldry.family_display_arms(fam.get("core", {}), GameState.banner_spec, GameState.family_tier(str(leader.family_id)))
	if CKHeraldry.core_key(shown) != CKHeraldry.core_key(expect):
		return "family arms core drifted"
	if CKHeraldry.core_key(shown) == CKHeraldry.core_key(GameState.banner_spec):
		return "family arms collapsed into the castle banner"
	return ""


func _lone() -> CKCharacter:
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
	c.alive = true
	GameState.claim_id(c)
	GameState.characters[c.id] = c
	return c


func _succession() -> String:
	var err := _successor_descendant()
	if err == "":
		err = _successor_roster()
	if err == "":
		err = _successor_regency()
	return err


func _successor_descendant() -> String:
	var leader := _lone()
	leader.rank = "count"
	leader.blood_meta["title"] = "count"
	var son := _add(22, leader, false)
	var sib := _add(18, leader, false)
	var _baron := _add(40, null, true, "baron", 9)
	var before := GameState.characters.size()
	leader.alive = false
	var r: Dictionary = Lineage.transfer_banner("death")
	if str(r.get("heir_id", "")) != son.id or str(r.get("via", "")) != "descendant":
		return "descendant heir %s via %s" % [str(r.get("heir_id", "")), str(r.get("via", ""))]
	if CKCourt.current_title(son) != "count" or str(son.blood_meta.get("title_from", "")) != leader.id:
		return "successor missed the count title"
	if CKCourt.current_title(sib) != "knight" or str(sib.blood_meta.get("title_from", "")) != "":
		return "sibling inherited the title"
	if GameState.characters.size() != before or Lineage.has_method("_outside_heir"):
		return "succession invented an outside heir"
	return ""


func _successor_roster() -> String:
	## No adult descendant: the company adult joins the house and takes the office. The child does not.
	var leader := _lone()
	leader.rank = "viscount"
	leader.blood_meta["title"] = "viscount"
	var baby := _add(8, leader, false)
	var _knight := _add(30, null, true, "knight", 3)
	var baron := _add(28, null, true, "baron", 1)
	leader.alive = false
	var r2: Dictionary = Lineage.transfer_banner("death")
	if str(r2.get("heir_id", "")) != baron.id or str(r2.get("via", "")) != "roster":
		return "roster heir %s via %s" % [str(r2.get("heir_id", "")), str(r2.get("via", ""))]
	if str(baron.family_id) != str(leader.family_id) or not bool(baron.blood_meta.get("joined_house", false)):
		return "roster heir did not join the family"
	if CKCourt.current_title(baron) != "viscount" or str(baron.blood_meta.get("title_from", "")) != leader.id:
		return "roster heir missed the office"
	if str(baby.blood_meta.get("title_from", "")) != "" or CKCourt.current_title(baby) == "viscount":
		return "minor sibling took the office"
	return ""


func _successor_regency() -> String:
	## No adult who can take the banner: eldest child, elder regents, title stays with the child.
	var leader := _lone()
	leader.rank = "baron"
	leader.blood_meta["title"] = "baron"
	var ward := _add(10, leader, false)
	var elder := _add(62, null, false)
	elder.retired = true
	var mid := _add(48, null, false)
	mid.retired = true
	var young := _add(40, null, false)
	young.retired = true
	leader.alive = false
	var r3: Dictionary = Lineage.transfer_banner("death")
	if str(r3.get("heir_id", "")) != ward.id or not bool(r3.get("regency", false)):
		return "minor heir %s" % str(r3)
	var elders: Array = Lineage.regency().get("elders", [])
	if elders.size() != 2 or str(elders[0]) != elder.id or str(elders[1]) != mid.id:
		return "regents %s" % str(elders)
	if young.id in elders or elder.is_leader or str(elder.blood_meta.get("title_from", "")) != "":
		return "a regent took the banner or the title"
	if CKCourt.current_title(ward) != "baron" or str(ward.blood_meta.get("title_from", "")) != leader.id:
		return "ward missed the title"
	if CKCourt.current_title(elder) != "knight":
		return "regent rank changed"
	if Lineage.regency_status().find(ward.name) < 0 or Lineage.regency_status().find(elder.name) < 0:
		return "regency status missing ward or elder"
	if ward.in_roster or not ward.is_child:
		return "minor ward was enlisted"
	return ""


func _wallet() -> String:
	var err := _wallet_post()
	if err == "":
		err = _wallet_move()
	return err


func _wallet_post() -> String:
	GameState.new_game("灰", "旗", "frost")
	GameState.food = 80
	GameState.morale = 80
	var leader := GameState.get_leader()
	var hid := ""
	for k in GameState.HOLDING_DEFS.keys():
		hid = str(k)
		break
	if hid == "":
		return "no holding"
	GameState.holdings[hid] = {"level": 2, "steward_id": "", "focus": "cash", "focus_cd": 0}
	GameState.house_mods["holding_silver_%s" % hid] = 10
	GameState.house_mods["follow_banner_manual"] = true
	GameState.house_mods["follow_banner"] = []
	var kin := CKCharacter.new()
	kin.id = "kin_field"
	kin.name = "田亲"
	kin.age = 30
	kin.alive = true
	kin.is_child = false
	kin.in_roster = false
	kin.family_id = leader.family_id
	kin.parent_ids = []
	kin.spouse_id = ""
	kin.blood_meta = {}
	GameState.characters[kin.id] = kin
	var child := CKCharacter.new()
	child.id = "kin_child"
	child.name = "田童"
	child.age = 10
	child.alive = true
	child.is_child = true
	child.in_roster = false
	child.parent_ids = [leader.id]
	child.blood_meta = {}
	GameState.characters[child.id] = child
	var merc := CKCharacter.new()
	merc.id = "hire_sword"
	merc.name = "雇兵"
	merc.age = 24
	merc.alive = true
	merc.in_roster = true
	merc.family_id = ""
	merc.parent_ids = []
	merc.spouse_id = ""
	merc.blood_meta = {}
	GameState.characters[merc.id] = merc
	for c in GameState.characters.values():
		if c != leader and c != kin and c != child and c != merc:
			c.in_roster = false
	if CKPurse._is_hireling(kin) or not CKPurse.is_field_kin(kin):
		return "family kin treated as a hireling"
	if not CKPurse._is_hireling(merc):
		return "hired sword treated as kin"
	var blocked: Dictionary = CKPurse.assign_field(merc, hid)
	if bool(blocked.get("ok", false)):
		return "hireling was allowed onto the field"
	var posted: Dictionary = CKPurse.assign_field(kin, hid)
	if not bool(posted.get("ok", false)):
		return "kin assign failed: %s" % str(posted.get("msg", ""))
	var posted_child: Dictionary = CKPurse.assign_field(child, hid)
	if not bool(posted_child.get("ok", false)):
		return "child assign failed: %s" % str(posted_child.get("msg", ""))
	merc.in_roster = false
	merc.blood_meta["estate_job"] = hid
	CKPurse.set_purse(kin, 0)
	CKPurse.set_purse(child, 0)
	CKPurse.set_purse(merc, 0)
	CKPurse.set_purse(leader, 0)
	return ""


func _wallet_move() -> String:
	var kin: CKCharacter = GameState.characters["kin_field"]
	var child: CKCharacter = GameState.characters["kin_child"]
	var merc: CKCharacter = GameState.characters["hire_sword"]
	var hid := ""
	for k in GameState.HOLDING_DEFS.keys():
		hid = str(k)
		break
	var s0 := int(GameState.silver)
	CKPurse.apply_monthly_wages(GameState)
	if CKPurse.get_purse(kin) != CKPurse.FIELD_WAGE:
		return "kin field purse %d" % CKPurse.get_purse(kin)
	if CKPurse.get_purse(child) != CKPurse.CHILD_WAGE:
		return "child field purse %d" % CKPurse.get_purse(child)
	if CKPurse.get_purse(merc) != 0:
		return "hireling drew a field purse %d" % CKPurse.get_purse(merc)
	if int(GameState.house_mods.get("holding_silver_%s" % hid, -1)) != 0:
		return "holding ledger not cleared into the treasury"
	var spent := CKPurse.FIELD_WAGE + CKPurse.CHILD_WAGE
	if int(GameState.silver) != s0 + (10 - spent):
		return "field remainder silver %d" % (int(GameState.silver) - s0)
	var s1 := int(GameState.silver)
	var remit: Dictionary = CKPurse.remit_to_flag(kin)
	if not bool(remit.get("ok", false)) or str(remit.get("dir", "")) != "to_flag":
		return "remit failed %s" % str(remit)
	if CKPurse.get_purse(kin) != 0 or int(GameState.silver) != s1 + CKPurse.FIELD_WAGE:
		return "remit did not empty the purse into the treasury"
	var back: Dictionary = CKPurse.pull_from_flag(kin, CKPurse.FIELD_WAGE)
	if bool(back.get("ok", false)) or str(back.get("dir", "")) != "to_purse":
		return "treasury drew back into the purse"
	if CKPurse.get_purse(kin) != 0 or int(GameState.silver) != s1 + CKPurse.FIELD_WAGE:
		return "pull_from_flag moved silver"
	var again: Dictionary = CKPurse.remit_to_flag(kin)
	if bool(again.get("ok", false)) or int(GameState.silver) != s1 + CKPurse.FIELD_WAGE:
		return "empty purse remitted again"
	var s2 := int(GameState.silver)
	var pay: Dictionary = CKPurse.pay_for_child(child, 4)
	if bool(pay.get("ok", false)) or int(GameState.silver) != s2:
		return "flag treasury paid a private due"
	return ""
