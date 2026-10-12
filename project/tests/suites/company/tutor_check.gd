extends Node
## v9.2 旗塾：专师名额、传习不耗银、师性带徒上限。

func _ready() -> void:
	await get_tree().process_frame
	var err := _run()
	if err != "":
		print("FAIL tutor: ", err)
		get_tree().quit(1)
		return
	print("TUTOR PASS")
	get_tree().quit(0)


func _run() -> String:
	GameState.new_game("灰", "旗", "frost")
	if CKTutor.pair_cap() != 1:
		return "base pairs %s" % CKTutor.pair_cap()
	GameState.buildings["academy"] = 2
	if CKTutor.pair_cap() != 3:
		return "academy pairs %s" % CKTutor.pair_cap()
	var leader := GameState.get_leader()
	leader.age = 30
	leader.stats["str"] = 14
	var kid := CKCharacter.new()
	kid.id = "pupil_a"; kid.name = "pupil"; kid.alive = true; kid.is_child = true; kid.in_roster = false; kid.age = 10
	kid.parent_ids = [leader.id]
	kid.apt_max = {"str": 20, "vit": 20, "skl": 20, "agi": 20, "per": 20, "wil": 20}
	kid.stats = {"str": 8, "vit": 8, "skl": 8, "agi": 8, "per": 8, "wil": 8}
	kid.blood_meta = {}
	GameState.characters[kid.id] = kid
	var cost := GameState.train_cost()
	var silver := GameState.silver
	var r := CKTutor.assign(kid.id, leader.id)
	if not bool(r.get("ok", false)):
		return "assign %s" % r.get("msg")
	var before := int(kid.stats.get(CKTutor.peak_stat(leader), 8))
	var tr := CKTutor.teach(kid.id)
	if not bool(tr.get("ok", false)):
		return "teach %s" % tr.get("msg")
	# Month advance may pay wages; must not charge the old drill fee.
	if silver - GameState.silver == cost:
		return "charged old drill fee"
	if int(kid.stats.get(CKTutor.peak_stat(leader), 8)) <= before:
		return "no gain"
	# 师性 → 可带 2
	GameState.house_mods["shi_xing"] = {leader.id: "shoulder"}
	if CKTutor.tutor_pupil_cap(leader) != 2:
		return "shi cap"
	return ""
