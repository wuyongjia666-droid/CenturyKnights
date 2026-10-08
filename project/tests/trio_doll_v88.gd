extends Control
## v8.8 2D paper-doll inheritance proof (parents → child via CKGenome.cross + CKPortraitDoll.compose)
var out_path := "/tmp/trio_doll.png"
var seed_used := -1
func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="): out_path = a.substr(6)
	var fam := _family()
	var bg := ColorRect.new(); bg.color = UIKit.BG; bg.set_anchors_preset(Control.PRESET_FULL_RECT); add_child(bg)
	var title := Label.new(); title.text = "血脉遗传 · 2D 纸娃娃（同一基因组 → CKPortraitDoll.compose）"
	title.add_theme_font_size_override("font_size", 22); title.add_theme_color_override("font_color", UIKit.TEXT)
	title.position = Vector2(32, 24); add_child(title)
	var cols := [60.0, 460.0, 860.0]
	for i in 3:
		var c: CKCharacter = fam[i]
		var tex := CKPortraitDoll.compose(c)
		var card := Panel.new(); card.position = Vector2(cols[i], 80); card.size = Vector2(360, 560)
		var sb := StyleBoxFlat.new(); sb.bg_color = Color(UIKit.PANEL, 0.92)
		sb.border_color = UIKit.ACCENT if i == 2 else UIKit.STROKE_HI; sb.set_border_width_all(2 if i == 2 else 1)
		sb.set_corner_radius_all(12); card.add_theme_stylebox_override("panel", sb); add_child(card)
		var tr := TextureRect.new(); tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE; tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		tr.texture = tex; tr.position = Vector2(18, 18); tr.size = Vector2(324, 324); card.add_child(tr)
		if tex == null:
			var miss := Label.new(); miss.text = "(compose failed)"; miss.position = Vector2(80, 160); card.add_child(miss)
		var info := VBoxContainer.new(); info.position = Vector2(18, 360); info.add_theme_constant_override("separation", 4); card.add_child(info)
		info.add_child(_lab("%s  %d岁" % [c.name, c.age], 18, UIKit.TEXT))
		var bl := []
		for k in c.blood_mix.keys(): bl.append("%s %d%%" % [k, int(round(float(c.blood_mix[k]) * 100))])
		info.add_child(_lab(" · ".join(bl), 12, UIKit.TEXT_DIM))
		var ph := CKGenome.phenotype(c)
		info.add_child(_lab("发 %s  瞳 %s  耳 %s  印 %s" % [ph["loci"]["hair"]["id"] if ph.has("loci") else ph["hair"]["id"], ph["loci"]["eyes"]["id"] if ph.has("loci") else ph["eyes"]["id"], ph["loci"]["ears"]["id"] if ph.has("loci") else ph["ears"]["id"], ph["loci"]["mark"]["id"] if ph.has("loci") else ph["mark"]["id"]], 13, UIKit.ACCENT if i == 2 else UIKit.TEXT_DIM))
		var acq := []
		if not c.scars.is_empty(): acq.append("战痕 " + ",".join(c.scars))
		if not c.honors.is_empty(): acq.append("荣誉 " + ",".join(c.honors))
		info.add_child(_lab(" · ".join(acq) if not acq.is_empty() else "无后天印记", 12, UIKit.DANGER if not acq.is_empty() else UIKit.TEXT_FAINT))
	var foot := _lab("Punnett seed %d · CKGenome.cross 实算 · 随机募兵/子嗣走 composited doll" % seed_used, 12, UIKit.TEXT_FAINT)
	foot.position = Vector2(32, 660); add_child(foot)
	# headless-safe capture (process_frame can stall without a presenting swapchain)
	await get_tree().create_timer(0.5).timeout
	RenderingServer.force_draw(true)
	await get_tree().create_timer(0.2).timeout
	get_viewport().get_texture().get_image().save_png(out_path)
	print("DOLL_TRIO_DONE ", out_path, " seed=", seed_used)
	get_tree().quit()

func _lab(t: String, sz: int, col: Color) -> Label:
	var l := Label.new(); l.text = t; l.add_theme_font_size_override("font_size", sz); l.add_theme_color_override("font_color", col); return l

func _mk(id, nm, g, age, job, blood, loci, face) -> CKCharacter:
	var c := CKCharacter.new()
	c.id = id; c.name = nm; c.gender = g; c.age = age; c.job_id = job; c.blood_mix = blood
	c.genome = {"loci": loci, "face": face, "body": {"height": 0.2, "build": 0.1}, "v": 2}
	CKGenome.sync_appearance(c); return c

func _family() -> Array:
	var fa := _mk("trio_father", "烬岚·父", "m", 47, "warrior", {"ember_noble": 0.7, "frost_crown": 0.3},
		{"hair": ["ink_black", "frost_silver"], "eyes": ["amber", "rime"], "brow": ["straight", "soft"], "ears": ["round", "crest"], "mark": ["none", "ember_sigil"]},
		{"width": 0.1, "jaw": 0.35, "cheek": 0.5, "nose": 0.1, "eye_tilt": 0.0, "eye_size": 0.0, "brow_height": -0.3})
	fa.scars = ["cheek_l"]; fa.honors = ["rime_circlet"]
	var mo := _mk("trio_mother", "汀澜·母", "f", 41, "warrior", {"river_ward": 1.0},
		{"hair": ["wheat", "frost_silver"], "eyes": ["river_blue", "rime"], "brow": ["arch", "soft"], "ears": ["round", "crest"], "mark": ["none", "none"]},
		{"width": -0.35, "jaw": -0.1, "cheek": 0.0, "nose": -0.1, "eye_tilt": 0.35, "eye_size": -0.1, "brow_height": 0.0})
	var blood := {"ember_noble": 0.35, "frost_crown": 0.15, "river_ward": 0.5}
	var rng := RandomNumberGenerator.new(); var cg := {}
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
