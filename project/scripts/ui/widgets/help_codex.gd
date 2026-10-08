class_name CKHelpCodex
extends Control
## 系统百科。叙事流用 register_entry 追加条目，UI 壳从设置打开。

static var _extra: Array = []

const ENTRIES: Array = [
	{"id": "board", "title": "ux_codex_board_title", "body": "ux_codex_board_body"},
	{"id": "castle", "title": "ux_codex_castle_title", "body": "ux_codex_castle_body"},
	{"id": "company", "title": "ux_codex_company_title", "body": "ux_codex_company_body"},
	{"id": "marriage", "title": "ux_codex_marriage_title", "body": "ux_codex_marriage_body"},
	{"id": "atlas", "title": "ux_codex_atlas_title", "body": "ux_codex_atlas_body"},
	{"id": "lamp", "title": "ux_codex_lamp_title", "body": "ux_codex_lamp_body"},
]

static func reset_for_tests() -> void:
	_extra.clear()

static func register_entry(entry: Dictionary) -> void:
	var id := str(entry.get("id", ""))
	if id == "":
		return
	for i in _extra.size():
		if str(_extra[i].get("id", "")) == id:
			_extra[i] = entry
			return
	_extra.append(entry)

static func entry_count() -> int:
	return ENTRIES.size() + _extra.size()

static func open(host: Node) -> CKHelpCodex:
	var prev := host.find_child("HelpCodex", true, false)
	if prev:
		prev.queue_free()
	var panel := CKHelpCodex.new()
	panel.name = "HelpCodex"
	host.add_child(panel)
	return panel

func _ready() -> void:
	mouse_filter = MOUSE_FILTER_STOP
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	z_as_relative = false
	z_index = 90
	_build()

func _build() -> void:
	var bg := ColorRect.new()
	bg.color = UIKit.BG
	bg.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	bg.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(bg)
	var veil := ColorRect.new()
	veil.color = Color(UIKit.BG_DEEP.r, UIKit.BG_DEEP.g, UIKit.BG_DEEP.b, 0.55)
	veil.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	veil.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(veil)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 48)
	margin.add_theme_constant_override("margin_right", 48)
	margin.add_theme_constant_override("margin_top", 36)
	margin.add_theme_constant_override("margin_bottom", 28)
	add_child(margin)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 12)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.size_flags_vertical = Control.SIZE_EXPAND_FILL
	margin.add_child(col)

	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 12)
	col.add_child(head)
	var titles := VBoxContainer.new()
	titles.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(titles)
	titles.add_child(UIKit.eyebrow(Locale.t("shell_500dbaa1")))
	var title := UIKit.title_label(_line("ux_codex_title", Locale.t("shell_645c19e1")), UIKit.SZ_TITLE)
	title.name = "CodexTitle"
	titles.add_child(title)
	var close := UIKit.make_button(_line("ux_codex_close", Locale.t("shell_6c14bd7f")), 120)
	close.custom_minimum_size = Vector2(120, 44)
	close.pressed.connect(queue_free)
	head.add_child(close)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	col.add_child(scroll)
	var list := VBoxContainer.new()
	list.name = "CodexList"
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 10)
	scroll.add_child(list)

	for entry in _all():
		list.add_child(_card(entry))

func _all() -> Array:
	var out: Array = []
	for entry in ENTRIES:
		out.append(entry)
	for entry in _extra:
		out.append(entry)
	return out

func _card(entry: Dictionary) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.name = "CodexEntry_" + str(entry.get("id", "x"))
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", UIKit.glass(12, 0.9, true))
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	panel.add_child(box)
	var title := UIKit.make_label(_resolve(str(entry.get("title", "")), str(entry.get("title_text", ""))), true)
	title.add_theme_font_size_override("font_size", UIKit.SZ_HEADLINE)
	title.add_theme_color_override("font_color", UIKit.TEXT)
	box.add_child(title)
	var body := UIKit.body_label(_resolve(str(entry.get("body", "")), str(entry.get("body_text", ""))), UIKit.TEXT_DIM, 15)
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_child(body)
	return panel

func _resolve(key: String, direct: String) -> String:
	if direct != "":
		return direct
	return _line(key, key)

func _line(key: String, fallback: String) -> String:
	var s := Locale.t(key)
	if s == key or s == "":
		return fallback
	return s
