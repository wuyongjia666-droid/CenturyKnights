extends Node
## DYN-05: gestation is 9–11 month-ticks (random), fast family is 1, fertility falls with age.

func _ready() -> void:
	await get_tree().process_frame
	var fails: Array = []
	_curve(fails)
	_term(fails)
	_late(fails)
	if fails.is_empty():
		print("FERTILITY PASS")
		get_tree().quit(0)
		return
	for f in fails:
		print("FAIL fertility: ", f)
	get_tree().quit(1)


func _curve(fails: Array) -> void:
	if CKFamilyState.fertility_of(15) != 0.0 or CKFamilyState.fertility_of(49) != 0.0:
		fails.append("edges should be infertile")
	if CKFamilyState.fertility_of(22) != 1.0:
		fails.append("peak fertility drifted")
	if not is_equal_approx(CKFamilyState.fertility_of(36), 0.55):
		fails.append("mid fertility drifted")
	if not is_equal_approx(CKFamilyState.fertility_of(44), 0.20):
		fails.append("late fertility drifted")
	GameState.rng.seed = 4401
	var mother := CKCharacter.new()
	mother.age = 36
	mother.gender = "f"
	var hits := 0
	for _i in 400:
		if CKFamilyState.begin_pregnancy(GameState, mother):
			hits += 1
		mother.pregnant_months = -1
	var rate := float(hits) / 400.0
	if absf(rate - 0.55) > 0.08:
		fails.append("age 36 conception %.3f off 0.55" % rate)


func _term(fails: Array) -> void:
	GameState.new_game("灯影", "灰旗", "frost")
	GameState.add_rep("ashland", 80)
	CKFamilyState.set_fast_family(GameState, false)
	var slow := _couple("slow", 22)
	var wed: Dictionary = Lineage.marry(slow[0], slow[1], 0, [], true)
	if not wed.get("ok", false):
		fails.append("young wedding refused")
		return
	if slow[1].pregnant_months < 0:
		# Peak chance is not 100%; force one conception for term band check.
		if not CKFamilyState.begin_pregnancy(GameState, slow[1]):
			GameState.rng.seed = 7
			CKFamilyState.begin_pregnancy(GameState, slow[1])
	var term := int(slow[1].blood_meta.get("gestation_term", -1))
	if term < CKFamilyState.TERM_MONTHS_MIN or term > CKFamilyState.TERM_MONTHS_MAX:
		fails.append("term %d out of 9–11" % term)
	if slow[1].pregnant_months != term - 1:
		fails.append("countdown %d want %d" % [slow[1].pregnant_months, term - 1])
	var born := _ticks_until_birth(slow[1])
	if born != term:
		fails.append("birth took %d ticks, want %d" % [born, term])
	CKFamilyState.set_fast_family(GameState, true)
	var fast := _couple("fast", 24)
	if not Lineage.marry(fast[0], fast[1], 0, [], true).get("ok", false):
		fails.append("fast wedding refused")
		return
	if fast[1].pregnant_months < 0:
		CKFamilyState.begin_pregnancy(GameState, fast[1])
	if _ticks_until_birth(fast[1]) != 1:
		fails.append("fast family did not deliver on the next month")


func _late(fails: Array) -> void:
	var late := _couple("late", 55)
	var res: Dictionary = Lineage.marry(late[0], late[1], 0, [], true)
	if not res.get("ok", false):
		fails.append("late wedding should still bind: %s" % str(res.get("msg", "")))
		return
	if late[1].pregnant_months >= 0:
		fails.append("age 55 conceived")
	Calendar.advance(4)
	if late[1].children_ids.size() > 0:
		fails.append("age 55 produced a child")


func _couple(tag: String, age: int) -> Array:
	var fa := CKCharacter.new()
	fa.id = tag + "_m"
	fa.name = tag
	fa.gender = "m"
	fa.age = age
	fa.rank = "knight"
	fa.blood_mix = {"common_ash": 1.0}
	var mo := CKCharacter.new()
	mo.id = tag + "_f"
	mo.name = tag + "氏"
	mo.gender = "f"
	mo.age = age
	mo.rank = "knight"
	mo.blood_mix = {"common_ash": 1.0}
	GameState.characters[fa.id] = fa
	GameState.characters[mo.id] = mo
	return [fa, mo]


func _ticks_until_birth(mother: CKCharacter) -> int:
	var before := mother.children_ids.size()
	for n in range(1, 14):
		Calendar.advance(1)
		if mother.children_ids.size() > before:
			return n
	return -1
