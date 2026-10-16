extends Node
## P0: try_texture returns the plate stem actually loaded (hit and fallback paths).

func _ready() -> void:
	var err := _run()
	if err != "":
		print("FAIL plate stem: ", err)
		get_tree().quit(1)
	else:
		get_tree().quit(0)


func _run() -> String:
	if not CKPortraitBank.has_plates():
		print("PLATE STEM SKIP no plates")
		return ""
	CKPortraitBank.clear_cache()
	var c := CKCharacter.new()
	c.id = "stem_check_1"
	c.gender = "m"
	c.age = 28
	c.ensure_genome()
	var pack: Dictionary = CKPortraitBank.try_texture(c, "small")
	if typeof(pack) != TYPE_DICTIONARY:
		return "try_texture must return Dictionary"
	var tex: Texture2D = pack.get("texture") as Texture2D
	var stem := str(pack.get("stem", ""))
	if tex == null:
		return "texture null with plates present"
	if stem == "":
		return "stem empty"
	# Stem must be a bank key (stage_hex form).
	if not stem.contains("_"):
		return "stem shape %s" % stem
	# Reloading the same stem via _load_plate must succeed.
	var again: Texture2D = CKPortraitBank.try_texture_only(c, "small")
	if again == null:
		return "try_texture_only null"
	# stage_plate also returns stem
	var stage := CKGenomePortrait.age_stage_of(c)
	var pack2: Dictionary = CKPortraitBank.stage_plate(c, stage, "small")
	if str(pack2.get("stem", "")) == "":
		return "stage_plate stem empty"
	# Board figure palette table must resolve when plate_palettes.json is packed.
	if ResourceLoader.exists("res://data/plate_palettes.json"):
		var row: Dictionary = CKBoardFigure.palette_row_for_stem(stem)
		if row.is_empty():
			# Fallback: table must still load; try a known key from disk index.
			var any_stem := _first_bank_stem()
			if any_stem == "":
				return "no bank stems"
			var any_row: Dictionary = CKBoardFigure.palette_row_for_stem(any_stem)
			if any_row.is_empty():
				return "plate_palettes empty or missing stem %s" % any_stem
		else:
			for k in ["hair", "skin", "coat", "style"]:
				if not row.has(k) or str(row.get(k)) == "":
					return "palette row missing %s" % k
	print("PLATE STEM PASS stem=%s stage_stem=%s" % [stem, str(pack2.get("stem", ""))])
	return ""


func _first_bank_stem() -> String:
	var dir := CKPortraitBank.bank_dir()
	var da := DirAccess.open(dir)
	if da == null:
		return ""
	for fn in da.get_files():
		var low := str(fn).to_lower()
		if low.ends_with(".medium.webp") or low.ends_with(".small.webp"):
			continue
		if low.ends_with(".webp") or low.ends_with(".png"):
			var base := str(fn).get_basename()
			# strip .medium/.small already handled; basename of x.webp is x
			return base
	return ""
