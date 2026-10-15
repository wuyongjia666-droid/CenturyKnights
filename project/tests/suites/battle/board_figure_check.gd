extends Node
## Board figure P0: colour rules, house_color, enemy coral lock, build smoke.

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
	err = _check_palettes()
	if err != "":
		return err
	err = _check_themes_coral()
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
	var leader = GameState.get_leader()
	if leader == null:
		return "no leader"
	var fill_a: Color = UnitModel.fill_color_for(leader, false, {"cloth": [Color(0.2, 0.2, 0.25)]}, UIKit.OK)
	if absf(fill_a.h - UIKit.ACCENT.h) > 0.12:
		return "ally fill should track house hue, got %s" % fill_a
	var fill_e: Color = UnitModel.fill_color_for(leader, true, {}, Color(0.37, 0.88, 0.71))
	if absf(fill_e.h - UIKit.DANGER.h) > 0.08:
		return "enemy fill must lock to coral, got %s" % fill_e
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

func _check_themes_coral() -> String:
	var themes := _load_themes()
	if themes.is_empty():
		return "no enemy themes loaded"
	var leader = GameState.get_leader()
	var coral: Color = UIKit.DANGER
	var bad := 0
	for tid in themes.keys():
		var row: Dictionary = themes[tid]
		var pal: Dictionary = row.get("palette", {}) if typeof(row.get("palette")) == TYPE_DICTIONARY else {}
		var raw := str(pal.get("trim", row.get("trim", "")))
		if raw == "":
			continue
		var trim := Color(raw if raw.begins_with("#") else ("#" + raw))
		var f: Color = UnitModel.fill_color_for(leader, true, {}, trim)
		if absf(f.h - coral.h) > 0.08:
			bad += 1
	if bad > 0:
		return "%d enemy themes still escape coral lock" % bad
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
	var bad := ""
	if int(spec.get("tris_est", 99999)) > 7000:
		bad = "tris budget"
	elif int(spec.get("textures", 1)) != 0:
		bad = "textures must be 0"
	fig.free()
	if bad != "":
		return bad
	return _check_farm_cast_wiring()

func _check_farm_cast_wiring() -> String:
	var leader = GameState.get_leader()
	var lp := CKBoardFigure._farm_cast_path(leader, false, "")
	if not str(lp).ends_with("leader_m.glb") and not str(lp).ends_with("leader_f.glb"):
		return "leader must map to leader_*.glb, got %s" % lp
	var wantan = null
	for c in GameState.characters.values():
		if str(c.cast_key) == "wantan" or str(c.job_id) == "light_inf":
			wantan = c
			break
	if wantan == null:
		wantan = CharacterFactory.make_shilei_wantan()
	var hp := CKBoardFigure._farm_cast_path(wantan, false, "")
	if not str(hp).contains("hunter_"):
		return "light_inf must remap to hunter_*.glb, got %s" % hp
	var bp := CKBoardFigure._farm_cast_path(leader, true, "bandit")
	if not str(bp).ends_with("bandit.glb"):
		return "enemy bandit path broken: %s" % bp
	var pal: Dictionary = CKBoardFigure.palette_for(leader, "enemy", "bandit")
	var mat: ShaderMaterial = CKBoardFigure._farm_mat(pal, -1.0, true)
	if float(mat.get_shader_parameter("use_bands")) < 0.5:
		return "farm mat must enable height bands"
	if float(mat.get_shader_parameter("board_compact")) < 0.5:
		return "farm mat must set board_compact"
	var coat: Color = mat.get_shader_parameter("coat")
	if CKBoardFigure._in_ally_gamut(coat):
		return "enemy farm coat still ally-gamut"
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
