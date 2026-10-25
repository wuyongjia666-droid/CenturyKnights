extends Control
## Desktop and a portrait-phone viewport, under the Windows and Android export
## filters, resolve the same full Qwen plate for one unit id + genome.
## Surfaces: hub, genealogy, tavern, battle select, marriage board, content-season cast.
## Age bands 0-2 / 3-11 / 12-15 / 16+ swap the plate and stay stable inside a band.

const AGES := [0, 2, 3, 11, 12, 15, 16, 40]
const SURFACES := ["resolver", "hub", "genealogy", "tavern", "battle_select", "marriage", "season_cast"]
const SEASON_SPEAKERS := ["barkeep", "sui_clerk", "clerk_seal"]


func _ready() -> void:
	var err := _run()
	CKArtPaths.pack_excluded = Callable()
	OS.set_environment("CK_FORCE_MOBILE", "0")
	if err != "":
		print("FAIL portrait_path_align_e2e: ", err)
		get_tree().quit(1)
		return
	print("PORTRAIT PATH ALIGN E2E PASS")
	get_tree().quit(0)


func _run() -> String:
	var src := _source_gate()
	if src != "":
		return src
	var win := _filters("Windows Desktop")
	var droid := _filters("Android")
	if droid.is_empty():
		return "Android exclude_filter empty"
	GameState.new_game("Ash", "Banner", GameState.crest_color)
	var leader: CKCharacter = GameState.get_leader()
	if leader == null:
		return "no leader"
	var unit := _fresh("path_align_unit", "m", 1101)
	var other := _fresh("path_align_other", "m", 2202)
	var desk = _platform(unit, leader, false, win)
	if typeof(desk) == TYPE_STRING:
		return str(desk)
	var mob = _platform(unit, leader, true, droid)
	if typeof(mob) == TYPE_STRING:
		return str(mob)
	var cross := _cross(desk, mob)
	if cross != "":
		return cross
	if str(other.id) == "":
		return "other unit missing"
	var rows: Dictionary = desk["ages"]
	print("OK path align unit=%s leader=%s" % [rows[16]["resolver"].get_file(), str(desk["leader"]).get_file()])
	return ""


func _cross(desk: Dictionary, mob: Dictionary) -> String:
	var ages := _age_parity(desk, mob)
	if ages != "":
		return ages
	var bands := _band_contract(desk["ages"])
	if bands != "":
		return bands
	return _identity_contract(desk, mob)


func _age_parity(desk: Dictionary, mob: Dictionary) -> String:
	for age in AGES:
		var drow: Dictionary = desk["ages"][int(age)]
		var mrow: Dictionary = mob["ages"][int(age)]
		for surface in SURFACES:
			var dp := str(drow.get(surface, ""))
			var mp := str(mrow.get(surface, ""))
			if dp == "" or mp == "":
				return "empty path age %d %s desk=%s mob=%s" % [age, surface, dp, mp]
			if dp != mp:
				return "age %d %s drift\ndesk %s\nmob  %s" % [age, surface, dp, mp]
			if not dp.ends_with(".medium.webp"):
				return "age %d %s not unit tier %s" % [age, surface, dp]
		var stem_err := _stem_for(int(age), str(drow["resolver"]))
		if stem_err != "":
			return stem_err
	return ""


func _stem_for(age: int, path: String) -> String:
	var stem := CKArtPaths._portrait_stem(path).get_file()
	var band := UnitArt.display_band(age)
	if band == "infant" and not stem.begins_with("infant_"):
		return "age %d want infant stem got %s" % [age, stem]
	if band == "child" and not stem.begins_with("youth_"):
		return "age %d want child/youth stem got %s" % [age, stem]
	if band == "teen" and not stem.begins_with("youth_"):
		return "age %d want teen/youth stem got %s" % [age, stem]
	if band == "adult" and (stem.begins_with("infant_") or stem.begins_with("youth_")):
		return "age %d adult fell back to young stem %s" % [age, stem]
	return ""


func _band_contract(rows: Dictionary) -> String:
	if rows[0]["resolver"] != rows[2]["resolver"]:
		return "0 and 2 diverged"
	if rows[3]["resolver"] != rows[11]["resolver"]:
		return "3 and 11 diverged"
	if rows[12]["resolver"] != rows[15]["resolver"]:
		return "12 and 15 diverged"
	if rows[2]["resolver"] == rows[3]["resolver"]:
		return "2->3 did not swap"
	if rows[11]["resolver"] == rows[12]["resolver"]:
		return "11->12 did not swap"
	if rows[15]["resolver"] == rows[16]["resolver"]:
		return "15->16 did not swap"
	if rows[16]["resolver"] == rows[40]["resolver"]:
		return "16 and 40 share a plate; adult life stage did not advance"
	return ""


func _identity_contract(desk: Dictionary, mob: Dictionary) -> String:
	var a := str(desk["genomes"]["a"])
	var b := str(desk["genomes"]["b"])
	if a == "" or a == b:
		return "two genomes collapsed infant plate %s" % a
	if str(mob["genomes"]["a"]) != a or str(mob["genomes"]["b"]) != b:
		return "genome plates drifted across platforms"
	for sp in SEASON_SPEAKERS:
		var sw := str(desk["speakers"][sp])
		var sm := str(mob["speakers"][sp])
		if sw == "" or sw != sm:
			return "season speaker %s drift desk=%s mob=%s" % [sp, sw, sm]
		if not sw.ends_with(".medium.webp"):
			return "season speaker %s not medium %s" % [sp, sw]
	var lead_d := str(desk["leader"])
	var lead_m := str(mob["leader"])
	if lead_d == "" or lead_d != lead_m:
		return "leader drift desk=%s mob=%s" % [lead_d, lead_m]
	return ""


func _platform(unit: CKCharacter, leader: CKCharacter, mobile: bool, filters: PackedStringArray):
	OS.set_environment("CK_FORCE_MOBILE", "1" if mobile else "0")
	var vp := Vector2i(720, 1280) if mobile else Vector2i(1280, 720)
	DisplayServer.window_set_size(vp)
	get_window().size = vp
	if DeviceProfile.is_mobile() != mobile:
		return "viewport profile mobile=%s want %s" % [DeviceProfile.is_mobile(), mobile]
	CKArtPaths.pack_excluded = func(p: String) -> bool: return _excluded(p, filters)
	UnitArt.clear_cache()
	CKGenomePortrait.clear_mem()
	var ages := {}
	for age in AGES:
		unit.age = int(age)
		UnitArt.clear_cache()
		CKGenomePortrait.clear_mem()
		var row := _surfaces(unit)
		var err := _same_row(row, "age %d" % age)
		if err != "":
			return err
		ages[int(age)] = row
	unit.age = 1
	var other := _fresh("path_align_other", "m", 3303)
	other.age = 1
	UnitArt.clear_cache()
	CKGenomePortrait.clear_mem()
	var ga := str(UnitArt.resolved_portrait(unit).get("path", ""))
	UnitArt.clear_cache()
	CKGenomePortrait.clear_mem()
	var gb := str(UnitArt.resolved_portrait(other).get("path", ""))
	var speakers := {}
	for sp in SEASON_SPEAKERS:
		UnitArt.clear_cache()
		CKArtPaths.last_loaded = ""
		var tex: Texture2D = UnitArt.dialogue_portrait(sp, "", null, 420 if not mobile else 180)
		if tex == null:
			return "season cast %s null (mobile=%s)" % [sp, mobile]
		speakers[sp] = CKArtPaths.last_loaded
	leader.age = 24
	UnitArt.clear_cache()
	CKGenomePortrait.clear_mem()
	var lead := str(UnitArt.resolved_portrait(leader).get("path", ""))
	_wipe()
	return {"ages": ages, "genomes": {"a": ga, "b": gb}, "speakers": speakers, "leader": lead}


func _surfaces(c: CKCharacter) -> Dictionary:
	var out := {}
	var rec: Dictionary = UnitArt.resolved_portrait(c)
	out["resolver"] = str(rec.get("path", ""))
	UIKit.portrait_plate(self, Rect2(16, 44, 200, 250), c, "ACTIVE GUARD")
	out["hub"] = str(c.get_meta("ck_portrait_path", ""))
	var gene := CKLineageInfo.portrait_rect(c, Vector2(66, 76) if DeviceProfile.is_mobile() else Vector2(84, 96))
	gene.free()
	out["genealogy"] = str(c.get_meta("ck_portrait_path", ""))
	UIKit.portrait_plate(self, Rect2(18, 54, 120, 150), c, "")
	out["tavern"] = str(c.get_meta("ck_portrait_path", ""))
	var dep := UIKit.make_portrait_rect(c, 160 if not DeviceProfile.is_mobile() else 220)
	dep.free()
	out["battle_select"] = str(c.get_meta("ck_portrait_path", ""))
	var mar := UIKit.make_portrait_rect(c, 132)
	mar.free()
	out["marriage"] = str(c.get_meta("ck_portrait_path", ""))
	var cast := UnitArt.dialogue_portrait(str(c.name), "", c, 420 if not DeviceProfile.is_mobile() else 180)
	out["season_cast"] = "" if cast == null else str(c.get_meta("ck_portrait_path", ""))
	return out


func _same_row(row: Dictionary, tag: String) -> String:
	var want := str(row.get("resolver", ""))
	for surface in SURFACES:
		if str(row.get(surface, "")) != want:
			return "%s %s=%s resolver=%s" % [tag, surface, row.get(surface, ""), want]
	return ""


func _fresh(id: String, gender: String, face_v: int) -> CKCharacter:
	var c := CKCharacter.new()
	c.id = id
	c.name = id
	c.gender = gender
	c.age = 0
	c.alive = true
	c.faction = "player"
	c.job_id = "light_inf"
	c.ensure_genome()
	if typeof(c.genome) == TYPE_DICTIONARY:
		var g: Dictionary = c.genome
		var face: Dictionary = g.get("face", {})
		for k in face.keys():
			face[k] = float(face_v % 17) / 17.0
		g["face"] = face
		c.genome = g
	return c


func _wipe() -> void:
	for n in get_children():
		remove_child(n)
		n.free()


func _source_gate() -> String:
	var ua := FileAccess.get_file_as_string("res://scripts/art/unit_art.gd")
	if ua.find("canonical_unit_tier") < 0:
		return "portrait() left the shared tier"
	if ua.find("size <= 240") >= 0:
		return "thumb size fork still in unit_art"
	if ua.find("_fingerprint_portrait") >= 0:
		return "hireface collage fork still in unit_art"
	if ua.find("play_band") < 0 and ua.find("display_band") < 0:
		return "unit_art lost play band"
	var paths := FileAccess.get_file_as_string("res://scripts/art/art_paths.gd")
	if paths.find("canonical_unit_tier") < 0 or paths.find("resolve_unit_plate") < 0:
		return "CKArtPaths missing unit tier"
	var gp := FileAccess.get_file_as_string("res://scripts/art/genome_portrait.gd")
	if gp.find("static func play_band") < 0 or gp.find("static func plate_record") < 0:
		return "genome portrait lost the shared record"
	var bank := FileAccess.get_file_as_string("res://scripts/art/portrait_bank.gd")
	if bank.find("static func plate_for_band") < 0:
		return "bank lost plate_for_band"
	var fig := FileAccess.get_file_as_string("res://scripts/art/board_figure.gd")
	var decal_at := fig.find("static func decal_portrait_image")
	if decal_at < 0:
		return "decal missing"
	var decal := fig.substr(decal_at, 700)
	if decal.find("v8_bust_") >= 0 or decal.find("ResourceLoader.exists") >= 0:
		return "decal still forks off the unit resolver"
	if decal.find("UnitArt.unit_portrait") < 0:
		return "decal does not use unit_portrait"
	var cp := FileAccess.get_file_as_string("res://scripts/story/chapter_player.gd")
	if cp.find("UnitArt.dialogue_portrait") < 0:
		return "chapter cast left dialogue_portrait"
	return ""


func _filters(preset: String) -> PackedStringArray:
	var cf := ConfigFile.new()
	if cf.load("res://export_presets.cfg") != OK:
		return PackedStringArray()
	for sec in cf.get_sections():
		if str(cf.get_value(sec, "name", "")) == preset:
			return str(cf.get_value(sec, "exclude_filter", "")).split(",", false)
	return PackedStringArray()


static func _excluded(path: String, filters: PackedStringArray) -> bool:
	var rel := path.trim_prefix("res://")
	for f in filters:
		var ff := str(f).strip_edges()
		if ff != "" and (rel.matchn(ff) or ("res://" + rel).matchn("res://" + ff)):
			return true
	return false
