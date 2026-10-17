extends Node
## Review 2026-10-17 P1-1 / P1-2: the century must not stall on an empty line, and a widow may marry again.

func _ready() -> void:
	var err := _no_heir()
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

## The original stall: captain aged 69, nobody else in the roster, run a year.
func _no_heir() -> String:
	GameState.new_game("烬行", "灰旗", GameState.crest_color)
	var leader := GameState.get_leader()
	for c in GameState.characters.values():
		if c != leader:
			c.in_roster = false
	leader.age = Calendar.DEATH_AGE - 1
	var evs: Array = []
	for i in 13:
		evs.append_array(Calendar.advance(1))
	if leader.alive:
		return "captain did not die of age"
	if leader.is_leader:
		return "dead captain still holds the banner"
	var now := GameState.get_leader()
	if now == null or not now.alive or not now.in_roster:
		return "no living leader after the death"
	if int(now.age) < Calendar.ADULT_AGE:
		return "outside heir is a minor"
	if not bool(now.blood_meta.get("outside_heir", false)):
		return "heir not flagged outside_heir"
	if str(now.family_id) != str(leader.family_id):
		return "outside heir not under the house family"
	if not GameState.characters.has(now.id) or GameState.characters[now.id] != now:
		return "outside heir not stored in characters"
	if GameState.roster().size() < 1:
		return "roster empty after succession"
	var saw := false
	for e in evs:
		if typeof(e) == TYPE_DICTIONARY and str(e.get("type", "")) == "succession":
			saw = true
	if not saw:
		return "no succession event"
	# Abdication still needs a real descendant.
	var r: Dictionary = Lineage.transfer_banner("abdicate")
	if bool(r.get("ok", false)):
		return "abdicate without descendants succeeded"
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
