extends Control

func _ready() -> void:
	UIKit.make_themed_bg(self, "roster")
	if ResourceLoader.exists("res://assets/art/ui/roster_banner.png"):
		var _bn := TextureRect.new()
		_bn.texture = load("res://assets/art/ui/roster_banner.png")
		_bn.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		_bn.stretch_mode = TextureRect.STRETCH_SCALE
		_bn.position = Vector2(0, 0)
		_bn.size = Vector2(1280, 52)
		_bn.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(_bn)
		UIFX.banner_shimmer(_bn, 3.8)
	UIFX.page_enter(self)
	var t = UIKit.make_label("花名册", true)
	t.position = Vector2(40, 16)
	add_child(t)
	var tip = UIKit.make_dim_label("每一位都有立绘。伤者标红，子嗣与联姻在族谱另页。")
	tip.position = Vector2(40, 56)
	add_child(tip)

	var scroll := ScrollContainer.new()
	scroll.position = Vector2(40, 90)
	scroll.custom_minimum_size = Vector2(1200, 520)
	add_child(scroll)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 10)
	scroll.add_child(vb)

	var roster = GameState.roster()
	if roster.is_empty():
		vb.add_child(UIKit.empty_state("花名册空空如也。去烽火酒馆看看。"))
	for c in roster:
		var card = UIKit.make_panel()
		card.custom_minimum_size = Vector2(1160, 100)
		vb.add_child(card)
		var hb := HBoxContainer.new()
		hb.add_theme_constant_override("separation", 14)
		card.add_child(hb)
		hb.add_child(UIKit.make_portrait_rect(c, 80))
		var lv := VBoxContainer.new()
		lv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		hb.add_child(lv)
		var job = GameState.get_job(c.job_id)
		var injury = "〔伤〕" if c.injured else ""
		var title = UIKit.make_label("%s | %s | Lv%d | 月薪%d | HP%d/%d %s" % [
			c.name, job.get("name", ""), c.level, c.salary, c.hp, c.max_hp, injury
		])
		if c.injured:
			title.add_theme_color_override("font_color", UIKit.DANGER)
		lv.add_child(title)
		lv.add_child(UIKit.make_dim_label("力%d 体%d 技%d 敏%d 感%d 意%d　·　%s" % [
			c.stats["str"], c.stats["vit"], c.stats["skl"], c.stats["agi"], c.stats["per"], c.stats["wil"],
			c.bloodline_display()
		]))
		var chips := HBoxContainer.new()
		chips.add_theme_constant_override("separation", 4)
		for tr in c.traits:
			var ic = UIKit.trait_icon_rect(str(tr), 28.0)
			var td = GameState.get_trait(str(tr))
			ic.tooltip_text = str(td.get("name", tr))
			chips.add_child(ic)
		if c.traits.is_empty():
			chips.add_child(UIKit.make_dim_label("（无禀性）"))
		lv.add_child(chips)
		# mini token
		var token := TextureRect.new()
		token.custom_minimum_size = Vector2(56, 56)
		token.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		token.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		token.texture = UnitArt.token(c, "player", 56, false)
		hb.add_child(token)

	var back = UIKit.make_button(Locale.t("btn_back"))
	back.position = Vector2(40, 640)
	back.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/hub/castle_hub.tscn"))
	add_child(back)
	UIFX.stagger_children(vb, 0.04, 0.24)
	UIFX.wire_tree(self)