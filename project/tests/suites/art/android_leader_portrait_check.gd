extends Node
## P0 Android: the leader and the marriage candidates must have a face from the packed bank
## stem index (no res:// directory listing), and marriage never waits on art.

func _ready() -> void:
	var err := _run()
	if err != "":
		print("FAIL android leader portrait: ", err)
		get_tree().quit(1)
	else:
		print("ANDROID LEADER PORTRAIT PASS")
		get_tree().quit(0)

func _live_stems() -> Dictionary:
	var out: Dictionary = {}
	var da := DirAccess.open(CKPortraitBank.bank_dir())
	if da == null:
		return out
	for fn0 in da.get_files():
		var fn := CKPortraitBank._strip_export_suffix(str(fn0))
		var low := fn.to_lower()
		if low.find(".small.") >= 0 or low.find(".medium.") >= 0 or low.find(".large.") >= 0:
			continue
		if not (low.ends_with(".webp") or low.ends_with(".png")):
			continue
		var stem := fn.get_basename()
		for st in CKGenomePortrait.STAGES:
			if stem.begins_with(str(st) + "_"):
				if not out.has(str(st)):
					out[str(st)] = {}
				out[str(st)][stem] = true
				break
	return out

func _run() -> String:
	# 1) Packed index matches the bank on disk (rerun tools/art/write_bank_stems.py after ingest).
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(CKPortraitBank.STEMS_INDEX))
	if typeof(parsed) != TYPE_DICTIONARY:
		return "missing %s" % CKPortraitBank.STEMS_INDEX
	var packed: Dictionary = parsed.get("stems", {})
	var live := _live_stems()
	for st in live.keys():
		var want: Array = (live[st] as Dictionary).keys()
		want.sort()
		var have: Array = packed.get(st, [])
		if want != have:
			return "stale stem index for %s (%d live vs %d packed); run tools/art/write_bank_stems.py" % [st, want.size(), have.size()]
	# 2) Index path: no directory listing, every founding face and every candidate has a plate.
	CKPortraitBank.dir_override = ""
	CKGenomePortrait.clear_mem()
	CKPortraitBank.clear_cache()
	if not CKPortraitBank._load_stems_index() or not CKPortraitBank.has_plates():
		return "stem index did not load"
	for g in ["m", "f"]:
		GameState.new_game("烬行", "灰旗", GameState.crest_color)
		var lead: CKCharacter = GameState.get_leader()
		lead.gender = g
		CKGenomePortrait.clear_mem()
		UnitArt.clear_cache()
		GameState.refresh_marriage_candidates()
		if UnitArt.portrait(lead, 280, CKArtPaths.TIER_MEDIUM) == null:
			return "leader (%s) has no portrait" % g
		for cand in GameState.marriage_candidates:
			if UnitArt.portrait(cand, 132) == null:
				return "candidate %s has no portrait" % cand.id
	# 3) No bank at all: the leader still gets a fallback face and the vow still goes through.
	CKPortraitBank.dir_override = "/nonexistent_ck_bank"
	CKGenomePortrait.dir_override = "/nonexistent_ck_bank" if "dir_override" in CKGenomePortrait else ""
	CKPortraitBank.clear_cache()
	CKGenomePortrait.clear_mem()
	UnitArt.clear_cache()
	GameState.new_game("烬行", "灰旗", GameState.crest_color)
	GameState.silver = 999
	GameState.add_rep("ashland", 40)  # the art-free path, not the reputation gate, is under test
	var l2: CKCharacter = GameState.get_leader()
	if UnitArt.portrait(l2, 280, CKArtPaths.TIER_MEDIUM) == null:
		return "leader has no fallback face without the bank"
	var cand2: CKCharacter = GameState.marriage_candidates[0]
	var r = Lineage.marry(l2, cand2, 40, [], true)
	if not bool(r.get("ok", false)) or str(l2.spouse_id) != str(cand2.id):
		return "marriage blocked without art: %s" % str(r.get("msg", ""))
	CKPortraitBank.dir_override = ""
	CKGenomePortrait.dir_override = ""
	CKPortraitBank.clear_cache()
	CKGenomePortrait.clear_mem()
	return ""
