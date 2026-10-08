extends Control
## Debug: parent / child / mother portrait descriptors side by side across 3 generations.
## Open res://scenes/debug/portrait_kinship.tscn. Enter rerolls the household. Esc returns to the menu.

var _seed := 89

func _ready() -> void:
	_rebuild()

func _unhandled_input(e: InputEvent) -> void:
	if e.is_action_pressed("ui_cancel"):
		get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn")
	elif e.is_action_pressed("ui_accept"):
		_seed += 1
		_rebuild()

func _rebuild() -> void:
	for ch in get_children():
		ch.queue_free()
	UIKit.void_bg(self)
	var rows: Array = CKGenomePortrait.demo_lineage(_seed)
	var title := UIKit.title_label("肖像血亲对照", 28)
	title.position = Vector2(40, 22)
	add_child(title)
	var reroll := UIKit.make_button("再摇一户", 140)
	reroll.position = Vector2(1080, 24)
	reroll.pressed.connect(_reroll)
	add_child(reroll)
	var sub := UIKit.body_label("每一代把子嗣的肖像描述词夹在父母中间。薄荷圆点是与父亲或母亲重合的可遗传项（发、瞳、脸型、印记）。种子 %d。" % _seed, UIKit.TEXT_DIM, 14)
	sub.position = Vector2(40, 64)
	sub.size = Vector2(1000, 36)
	add_child(sub)
	var scroll := ScrollContainer.new()
	scroll.position = Vector2(28, 108)
	scroll.size = Vector2(1224, 590)
	add_child(scroll)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	box.custom_minimum_size = Vector2(1200, 0)
	scroll.add_child(box)
	for row in rows:
		box.add_child(_section(row))

func _reroll() -> void:
	_seed += 1
	_rebuild()

func _section(row: Dictionary) -> Control:
	var rep: Dictionary = row["report"]
	var wrap := VBoxContainer.new()
	wrap.add_theme_constant_override("separation", 6)
	var frac := float(rep.get("fraction", 0.0))
	wrap.add_child(UIKit.mono("GEN %d   可遗传重合 %d%%" % [int(row["gen"]), int(round(frac * 100.0))], 13, UIKit.ACCENT, false))
	var shared := {}
	for t in rep.get("shared", []):
		shared[str(t)] = true
	var cols := HBoxContainer.new()
	cols.add_theme_constant_override("separation", 12)
	var heads := [["父本", row["father"], rep["father_tokens"], rep["father_prose"]], ["子嗣", row["child"], rep["child_tokens"], rep["child_prose"]], ["母本", row["mother"], rep["mother_tokens"], rep["mother_prose"]]]
	for col in heads:
		cols.add_child(_column(str(col[0]), col[1], col[2], col[3], shared, str(col[0]) == "子嗣"))
	wrap.add_child(cols)
	return wrap

func _column(title: String, who: CKCharacter, tokens: Array, prose: Array, shared: Dictionary, focus: bool) -> Control:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(388, 0)
	panel.add_theme_stylebox_override("panel", UIKit.flat_box(Color(0.055, 0.067, 0.090, 0.92), Color(UIKit.ACCENT, 0.85) if focus else Color(1, 1, 1, 0.10), 10, 2 if focus else 1))
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 4)
	panel.add_child(v)
	v.add_child(UIKit.body_label("%s  %s" % [title, str(who.name)], UIKit.TEXT, 14))
	var shown := ""
	for t in tokens:
		var on := shared.has(str(t))
		shown += ("● " if on else "· ") + str(t) + "\n"
	var lab := UIKit.mono(shown, 12, UIKit.TEXT, false)
	lab.add_theme_color_override("font_color", UIKit.TEXT)
	v.add_child(lab)
	var phrase := UIKit.body_label(", ".join(prose), UIKit.TEXT_DIM, 12)
	v.add_child(phrase)
	return panel
