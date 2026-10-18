extends Node
## Review 2026-10-18 (#319): a century seed must not depend on the runs before it in the same
## process. CharacterFactory's id counter used to carry over (seed 1113: 1467 silver alone,
## 7 after seeds 1107-1112). Also checks that the script weds the leader's siblings/children.

const YEARS := 40

func _ready() -> void:
	await get_tree().process_frame
	var err := _run()
	if err != "":
		print("FAIL sim isolation: ", err)
		get_tree().quit(1)
	else:
		print("SIM ISOLATION PASS")
		get_tree().quit(0)

func _snap(r: Dictionary) -> Dictionary:
	var ids: Array = GameState.characters.keys()
	ids.sort()
	return {
		"silver": int(r.get("silver_end", -1)), "food": int(r.get("food_end", -1)),
		"births": int(r.get("births", -1)), "ids": ",".join(PackedStringArray(ids)),
		"ledger": JSON.stringify(r.get("ledger", {})), "cadets": int(r.get("cadet_weddings", 0)),
	}

func _run() -> String:
	var first := _snap(CKCampaignSim.run(YEARS, 1113))
	CKCampaignSim.run(15, 1112)
	var again := _snap(CKCampaignSim.run(YEARS, 1113))
	for k in first.keys():
		if str(first[k]) != str(again[k]):
			return "seed 1113 drifted after another run on %s: %s vs %s" % [k, str(first[k]).left(80), str(again[k]).left(80)]
	if int(first["cadets"]) <= 0:
		return "no cadet weddings in %d years" % YEARS
	print("SIM ISOLATION silver=%d births=%d cadet_weddings=%d" % [first["silver"], first["births"], first["cadets"]])
	return ""
