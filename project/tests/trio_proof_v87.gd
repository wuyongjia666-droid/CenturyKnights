extends Control
## v8.7 inheritance proof: father + mother -> child through the REAL CKGenome.cross, rendered by BOTH renderers
## (2D paper-doll CKPortraitDoll.compose and the 3D modular rig UnitModel.instantiate + genome modules).
## The seed is searched for the skip-generation case (recessive frost-silver hair + crest ears that neither parent
## shows); the Punnett odds are printed so the shot is honest about it.
##   godot --path . res://tests/trio_proof_v87.tscn -- --out=/path/trio.png
var out_path := "/tmp/trio_v87.png"
var seed_used := -1

func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out_path = a.substr(6)
	var fam := _family()
	_build_ui(fam)
	for i in 40:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png(out_path)
	print("TRIO_DONE ", out_path, " seed=", seed_used)
	get_tree().quit()

func _mk(id: String, nm: String, g: String, age: int, job: String, blood: Dictionary, loci: Dictionary, face: Dictionary) -> CKCharacter:
	var c := CKCharacter.new()
	c.id = id; c.name = nm; c.gender = g; c.age = age; c.job_id = job; c.blood_mix = blood
	c.genome = {"loci": loci, "face": face, "body": {"height": 0.2, "build": 0.1}, "v": 2}
	CKGenome.sync_appearance(c)
	return c

func _family() -> Array:
	var fa := _mk("trio_father", "烬岚·父", "m", 47, "warrior", {"ember_noble": 0.7, "frost_crown": 0.3},
		{"hair": ["ink_black", "frost_silver"], "eyes": ["amber", "rime"], "brow": ["straight", "soft"], "ears": ["round", "crest"], "mark": ["none", "ember_sigil"]},
		{"width": 0.1, "jaw": 0.35, "cheek": 0.5, "nose": 0.1, "eye_tilt": 0.0, "eye_size": 0.0, "brow_height": -0.3})
	fa.scars = ["cheek_l"]
	fa.honors = ["rime_circlet"]
	var mo := _mk("trio_mother", "汀澜·母", "f", 41, "warrior", {"river_ward": 1.0},
		{"hair": ["wheat", "frost_silver"], "eyes": ["river_blue", "rime"], "brow": ["arch", "soft"], "ears": ["round", "crest"], "mark": ["none", "none"]},
		{"width": -0.35, "jaw": -0.1, "cheek": 0.0, "nose": -0.1, "eye_tilt": 0.35, "eye_size": -0.1, "brow_height": 0.0})
	var blood := {"ember_noble": 0.35, "frost_crown": 0.15, "river_ward": 0.5}
	var rng := RandomNumberGenerator.new()
	var cg := {}
	for s in range(1, 2000):
		rng.seed = s
		cg = CKGenome.cross(fa.genome, mo.genome, blood, rng)
		var l: Dictionary = cg["loci"]
		if l["hair"] == ["frost_silver", "frost_silver"] and l["ears"] == ["crest", "crest"] and "ember_sigil" in l["mark"]:
			seed_used = s
			break
	var ch := CKCharacter.new()
	ch.id = "trio_child"; ch.name = "霜烬·子"; ch.gender = "m"; ch.age = 19; ch.job_id = "squire"; ch.blood_mix = blood
	ch.genome = cg
	CKGenome.sync_appearance(ch)
	return [fa, mo, ch]

func _label(t: String, size: int, col: Color) -> Label:
	var l := Label.new(); l.text = t
	l.add_theme_font_size_override("font_size", size); l.add_theme_color_override("font_color", col)
	return l

func _geno(c: CKCharacter, locus: String, zh: String) -> String:
	var pair: Array = c.genome["loci"][locus]
	var e := CKGenome.express(c.genome, locus)
	var shown := str(e["id"])
	if float(e["strength"]) < 1.0:
		shown += " %d%%" % int(round(float(e["strength"]) * 100))
	return "%s  %s / %s  →  %s" % [zh, pair[0], pair[1], shown]

func _build_ui(fam: Array) -> void:
	var bg := ColorRect.new(); bg.color = UIKit.BG; bg.set_anchors_preset(Control.PRESET_FULL_RECT); add_child(bg)
	# 3D stage (full frame, behind the overlays)
	var svc := SubViewportContainer.new(); svc.stretch = true; svc.set_anchors_preset(Control.PRESET_FULL_RECT); add_child(svc)
	var sv := SubViewport.new(); sv.size = Vector2i(1280, 720); sv.transparent_bg = true; sv.msaa_3d = Viewport.MSAA_4X; svc.add_child(sv)
	var root := Node3D.new(); sv.add_child(root)
	var env := WorldEnvironment.new(); var e := Environment.new()
	e.background_mode = Environment.BG_CLEAR_COLOR; e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color("#8AA2BC"); e.ambient_light_energy = 0.32; e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.environment = e; root.add_child(env)
	var key := DirectionalLight3D.new(); key.light_energy = 0.8; key.shadow_enabled = true
	key.look_at_from_position(Vector3(-0.55, 0.65, 0.52) * 5.0, Vector3.ZERO, Vector3.UP); root.add_child(key)
	var rim := DirectionalLight3D.new(); rim.light_color = Color("#6ED4FF"); rim.light_energy = 0.45
	rim.look_at_from_position(Vector3(0.6, 0.5, -0.8) * 5.0, Vector3.ZERO, Vector3.UP); root.add_child(rim)
	var floor := MeshInstance3D.new(); var pm := PlaneMesh.new(); pm.size = Vector2(12, 6); floor.mesh = pm
	var fm := StandardMaterial3D.new(); fm.albedo_color = Color("#0B0E14"); fm.roughness = 0.9; floor.material_override = fm; root.add_child(floor)
	var cam := Camera3D.new(); cam.fov = 30.0; root.add_child(cam)
	cam.look_at_from_position(Vector3(0, 1.8, 7.4), Vector3(0, 1.68, 0), Vector3.UP)
	var xs := [-2.25, 0.0, 2.25]
	for i in 3:
		var m := UnitModel.instantiate(fam[i], "ally")
		if m:
			root.add_child(m)
			m.position = Vector3(xs[i], 0, 0)
			m.rotation.y = deg_to_rad(-12.0)
			var ap := UnitModel.find_anim(m)
			if ap and ap.has_animation("idle"):
				ap.play("idle")
	# overlays: title, three columns of doll + genotype
	var title := _label("血脉遗传 · 父母 → 子（2D 纸娃娃 + 3D 模块化，同一基因组）", 22, UIKit.TEXT)
	title.position = Vector2(32, 18); add_child(title)
	var sub := _label("隐性隔代：霜银发 / 冠耳 双亲均不表现 · 余烬印不完全显性 · 年龄灰发 · 战痕与荣誉终身保留（不遗传）", 14, UIKit.TEXT_DIM)
	sub.position = Vector2(32, 50); add_child(sub)
	var cols := [22.0, 437.0, 852.0]
	for i in 3:
		var c: CKCharacter = fam[i]
		var tex := CKPortraitDoll.compose(c)
		var card := Panel.new(); card.position = Vector2(cols[i], 82); card.size = Vector2(406, 206)
		var sb := StyleBoxFlat.new(); sb.bg_color = Color(UIKit.PANEL, 0.88); sb.border_color = UIKit.ACCENT if i == 2 else UIKit.STROKE_HI
		sb.set_border_width_all(2 if i == 2 else 1); sb.set_corner_radius_all(10); card.add_theme_stylebox_override("panel", sb); add_child(card)
		var tr := TextureRect.new(); tr.texture = tex; tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE; tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		tr.position = Vector2(8, 8); tr.size = Vector2(190, 190); card.add_child(tr)
		if tex == null:
			var miss := _label("(doll parts pending)", 12, UIKit.TEXT_FAINT); miss.position = Vector2(40, 92); card.add_child(miss)
		var info := VBoxContainer.new(); info.position = Vector2(208, 10); info.add_theme_constant_override("separation", 3); card.add_child(info)
		info.add_child(_label("%s  %d岁" % [c.name, c.age], 16, UIKit.TEXT))
		var bl := []
		for k in c.blood_mix.keys():
			bl.append("%s %d%%" % [k, int(round(float(c.blood_mix[k]) * 100))])
		var bll := _label(" · ".join(bl), 10, UIKit.TEXT_DIM); bll.autowrap_mode = TextServer.AUTOWRAP_WORD; bll.custom_minimum_size = Vector2(190, 0); info.add_child(bll)
		for pr in [["hair", "发"], ["eyes", "瞳"], ["ears", "耳"], ["mark", "印"]]:
			info.add_child(_label(_geno(c, pr[0], pr[1]), 11, UIKit.ACCENT if i == 2 else UIKit.TEXT_DIM))
		var acq := []
		if not c.scars.is_empty(): acq.append("战痕 " + ",".join(c.scars))
		if not c.honors.is_empty(): acq.append("荣誉 " + ",".join(c.honors))
		info.add_child(_label(" · ".join(acq) if not acq.is_empty() else "无后天印记", 11, UIKit.DANGER if not acq.is_empty() else UIKit.TEXT_FAINT))
	var odds := []
	for locus in ["hair", "ears"]:
		for p in CKGenome.punnett(fam[0].genome, fam[1].genome, locus):
			if str(p["id"]) in ["frost_silver", "crest"]:
				odds.append("%s %d%%" % [p["id"], int(round(float(p["prob"]) * 100))])
	var ol := _label("Punnett 子代表现概率：" + " · ".join(odds) + "    (seed %d，CKGenome.cross 实算)" % seed_used, 12, UIKit.TEXT_FAINT)
	ol.position = Vector2(32, 690); add_child(ol)
