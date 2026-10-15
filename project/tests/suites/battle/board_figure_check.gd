extends Node
## Board figure P1: kit mapping, palette guards, assemble smoke (no farm_cast formal path).

func _ready() -> void:
	await get_tree().process_frame
	var err := _run()
	if err != "":
		print("FAIL board figure: ", err)
		get_tree().quit(1)
		return
	print("BOARD FIGURE PASS")
	get_tree().quit(0)

func _run() -> String:
	var err := _check_house_and_fill()
	if err != "":
		return err
	err = _check_map()
	if err != "":
		return err
	err = _check_palettes()
	if err != "":
		return err
	err = _check_themes_and_banner_swatches()
	if err != "":
		return err
	return _check_build()

func _check_house_and_fill() -> String:
	GameState.new_game("棋子", "霜旗", UIKit.ACCENT.to_html(false))
	var ash := CKHeraldry.tincture_hex("ash")
	var charge := "#" + UIKit.ACCENT.to_html(false)
	GameState.banner_spec = {
		"field_a": ash,
		"charge_color": charge,
		"ordinary_tincture": charge,
		"emblem_color": charge,
	}
	var house: Color = UnitArt.house_color()
	if absf(house.h - UIKit.ACCENT.h) > 0.08:
		return "house_color should follow charge, got %s" % house
	return ""

func _check_map() -> String:
	var f := FileAccess.open("res://data/board_figures.json", FileAccess.READ)
	if f == null:
		return "missing board_figures.json"
	var parsed = JSON.parse_string(f.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		return "board_figures.json invalid"
	var root: Dictionary = parsed
	var jobs: Dictionary = root.get("jobs", {})
	for jid in ["captain", "hunter", "squire", "light_inf", "apprentice"]:
		if not jobs.has(jid):
			return "jobs missing %s" % jid
	var et: Dictionary = root.get("enemy_templates", {})
	for t in ["bandit_weak", "bandit", "bandit_archer", "bandit_chief"]:
		if not et.has(t):
			return "enemy_templates missing %s" % t
	if not ResourceLoader.exists(str(root.get("kit_glb", ""))):
		return "kit glb missing"
	return ""

func _check_palettes() -> String:
	var leader = GameState.get_leader()
	var pal_a: Dictionary = CKBoardFigure.palette_for(leader, "player")
	var err := CKBoardFigure.assert_palette_rules(pal_a, false)
	if err != "":
		return err
	var pal_e: Dictionary = CKBoardFigure.palette_for(leader, "enemy", "bandit")
	err = CKBoardFigure.assert_palette_rules(pal_e, true)
	if err != "":
		return err
	if CKBoardFigure._in_ally_gamut(pal_e["coat"]):
		return "enemy coat still in ally gamut"
	return ""

func _check_themes_and_banner_swatches() -> String:
	var themes := _load_themes()
	if themes.is_empty():
		return "no enemy themes loaded"
	var leader = GameState.get_leader()
	var bad := 0
	for tid in themes.keys():
		for tmpl in ["bandit_weak", "bandit", "bandit_archer", "bandit_chief"]:
			var pal: Dictionary = CKBoardFigure.palette_for(leader, "enemy", tmpl)
			var err := CKBoardFigure.assert_palette_rules(pal, true)
			if err != "":
				bad += 1
	if bad > 0:
		return "%d enemy theme×template palette violations" % bad
	# Banner swatches (24): house must not enter enemy gamut after protect
	var swatches := [
		"#6ED4FF", "#5EE0B5", "#FF7A70", "#FF8A80", "#C9D3DE", "#9AA4B2",
		"#7A8CA0", "#4A5568", "#E8D5B7", "#B8A090", "#6E7276", "#2A2F38",
		"#88C0D0", "#A3BE8C", "#D08770", "#B48EAD", "#EBCB8B", "#BF616A",
		"#81A1C1", "#8FBCBB", "#5E81AC", "#ECEFF4", "#D8DEE9", "#4C566A",
	]
	for hx in swatches:
		GameState.banner_spec = {
			"field_a": CKHeraldry.tincture_hex("ash"),
			"charge_color": hx,
			"ordinary_tincture": hx,
			"emblem_color": hx,
		}
		CKBoardFigure._pal_cache.clear()
		var pal2: Dictionary = CKBoardFigure.palette_for(leader, "player")
		var e2 := CKBoardFigure.assert_palette_rules(pal2, false)
		if e2 != "":
			return "banner swatch %s: %s" % [hx, e2]
	return ""

func _check_build() -> String:
	var leader = GameState.get_leader()
	var fig := CKBoardFigure.build(leader, "player")
	if fig == null:
		return "build returned null"
	var ap := CKBoardFigure.find_anim(fig)
	if ap == null or not ap.has_animation("idle") or not ap.has_animation("attack"):
		fig.free()
		return "missing AnimationPlayer clips"
	var spec: Dictionary = CKBoardFigure.spec_for(leader, "player")
	if int(spec.get("tris_est", 99999)) > 7000:
		fig.free()
		return "tris budget %s" % spec.get("tris_est")
	if int(spec.get("textures", 1)) != 0:
		fig.free()
		return "textures must be 0"
	if str(spec.get("appearance_hash", "")) == "":
		fig.free()
		return "appearance_hash empty"
	# Priority kits
	for tmpl in ["bandit_weak", "bandit", "bandit_archer", "bandit_chief"]:
		var ef := CKBoardFigure.build(leader, "enemy", tmpl)
		if ef == null:
			fig.free()
			return "enemy build null %s" % tmpl
		var es: Dictionary = CKBoardFigure.spec_for(leader, "enemy", tmpl)
		if int(es.get("tris_est", 99999)) > 7000:
			ef.free()
			fig.free()
			return "enemy tris %s" % tmpl
		ef.free()
	# Hunter mapping via temporary job_id on leader clone fields
	var saved_job := str(leader.job_id)
	var saved_lead := bool(leader.is_leader)
	leader.job_id = "hunter"
	leader.is_leader = false
	CKBoardFigure._pal_cache.clear()
	var hs: Dictionary = CKBoardFigure.spec_for(leader, "player")
	leader.job_id = saved_job
	leader.is_leader = saved_lead
	var parts: Dictionary = hs.get("parts", {})
	var hunter_ok := str(parts.get("compose", "")).find("hunter") >= 0 or str(parts.get("outfit", "")).find("hunter") >= 0
	if not hunter_ok:
		fig.free()
		return "hunter outfit/compose wrong: %s" % parts
	if str(parts.get("weapon", "")).find("bow") < 0:
		fig.free()
		return "hunter weapon wrong: %s" % parts
	fig.free()
	# Stand-in replaces capsule path
	var st: Texture2D = CKBoardFigure.standin_texture(leader, "player")
	if st == null:
		return "standin null"
	return ""

func _load_themes() -> Dictionary:
	var f := FileAccess.open("res://data/enemy_themes.json", FileAccess.READ)
	if f == null:
		return {}
	var parsed = JSON.parse_string(f.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		return {}
	var root: Dictionary = parsed
	if typeof(root.get("themes")) == TYPE_DICTIONARY:
		return root["themes"]
	return {}
