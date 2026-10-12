extends Node
## Playtest: age_stage matches age; portraits non-null; gestation 9–11; hub unlocks.

func _ready() -> void:
	var err := _run()
	if err != "":
		print("FAIL portrait_age_band: ", err)
		get_tree().quit(1)
		return
	print("PORTRAIT AGE BAND PASS")
	get_tree().quit(0)


func _run() -> String:
	CKPortraitBank.clear_cache()
	CKGenomePortrait.clear_mem()
	GameState.new_game("烬行", "灰旗", "frost")
	var cases := [
		[0, "infant"], [2, "infant"], [10, "youth"],
		[19, "young_adult"], [22, "young_adult"], [40, "middle"], [60, "elder"],
	]
	for row in cases:
		var age: int = int(row[0])
		var want: String = str(row[1])
		var c := CKCharacter.new()
		c.id = "age_band_%d" % age
		c.name = "测%d" % age
		c.age = age
		c.gender = "m"
		c.alive = true
		c.ensure_genome()
		var got := CKGenomePortrait.age_stage_of(c)
		if got != want:
			return "stage age %d got %s want %s" % [age, got, want]
		var tex: Texture2D = UnitArt.portrait(c, 128)
		if tex == null:
			return "null portrait age %d" % age
		var bank: Texture2D = CKPortraitBank.try_texture(c, "small")
		if age < 3 and bank == null and CKPortraitBank.has_plates():
			return "infant bank miss age %d" % age
	var mom := GameState.get_leader()
	if mom == null:
		return "no leader"
	mom.gender = "f"
	mom.age = 24
	var terms: Dictionary = {}
	var conceived := 0
	for i in 60:
		mom.pregnant_months = -1
		mom.blood_meta.erase("gestation_term")
		if CKFamilyState.begin_pregnancy(GameState, mom):
			conceived += 1
			var term := int(mom.blood_meta.get("gestation_term", -1))
			terms[term] = true
			if term < CKFamilyState.TERM_MONTHS_MIN or term > CKFamilyState.TERM_MONTHS_MAX:
				return "term out of band %d" % term
	if conceived == 0:
		return "never conceived"
	if conceived >= 60:
		return "always conceived"
	if terms.size() < 2:
		return "term not random %s" % str(terms.keys())
	UnlockSchedule._data = {}
	for entry in ["atlas", "quests", "lineage", "marriage"]:
		if not UnlockSchedule.allows(entry):
			return "year_one locked " + entry
	return ""
