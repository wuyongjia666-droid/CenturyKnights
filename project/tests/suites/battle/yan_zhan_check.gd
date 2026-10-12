extends Node

func _ready() -> void:
	await get_tree().process_frame
	var fails: Array = []
	GameState.new_game("灰", "旗", "frost")
	var mook := CKCharacter.new()
	mook.id = "mook"; mook.blood_mix = {}; mook.blood_meta = {}; mook.honors = []
	if CKYanZhan.hit_bonus(mook) != CKYanZhan.BLOODLESS_HIT:
		fails.append("bloodless")
	var fake := CKCharacter.new()
	fake.id = "fake"; fake.blood_meta = {"pretend": {"title": "假爵"}}; fake.honors = []
	if CKYanZhan.hit_bonus(fake) != CKYanZhan.FORGED_HIT:
		fails.append("forged")
	var sk = GameState.get_skill(CKYanZhan.SKILL_ID)
	if sk.is_empty() or str(sk.get("name", "")) != "验盏":
		fails.append("skill missing %s" % str(sk))
	var caster := CKCharacter.new()
	caster.id = "priest"; caster.blood_meta = {}; caster.skills = ["yan_zhan"]
	var battle = Node.new()
	var r = CKYanZhan.cast(battle, {"char": caster}, {"char": fake})
	if not bool(r.get("ok", false)):
		fails.append("cast %s" % str(r))
	if CKYanZhan.battle_hit_bonus(battle, fake) != CKYanZhan.FORGED_HIT:
		fails.append("battle bonus")
	# once per battle
	var r2 = CKYanZhan.cast(battle, {"char": caster}, {"char": mook})
	if bool(r2.get("ok", false)):
		fails.append("double cast")
	# reserve edge
	var cell := CKDeployReserve.pick_entry_cell(8, 6, [Vector2i(3, 3)], {})
	if cell.x < 0 or (cell.x not in [0, 7] and cell.y not in [0, 5]):
		fails.append("edge cell %s" % str(cell))
	if not CKDeployReserve.enters_from_edge():
		fails.append("entry mode")
	if fails.is_empty():
		print("YAN ZHAN PASS")
		get_tree().quit(0)
	else:
		for f in fails:
			print("FAIL yan: ", f)
		get_tree().quit(1)
