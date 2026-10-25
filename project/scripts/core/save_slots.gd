class_name CKSaveSlots
extends Control
## Load-game list. Continue on the main menu uses the newest slot.

const SCENE := "res://scenes/ui/save_slots.tscn"

static func latest_slot() -> String:
	var best := ""
	var best_time := -1
	for slot in CKSaveService.SLOTS:
		var path := CKSaveService.body_path(slot)
		if not FileAccess.file_exists(path):
			continue
		var modified := int(FileAccess.get_modified_time(path))
		if modified >= best_time:
			best_time = modified
			best = slot
	return best

static func continue_line(slot: String) -> String:
	if slot == "":
		return Locale.t("menu_no_save")
	if not FileAccess.file_exists(CKSaveService.body_path(slot)):
		return Locale.t("menu_slot_empty")
	var meta := CKSaveService.read_meta(slot)
	if meta.is_empty():
		return Locale.t("menu_slot_empty")
	var leader := Locale.latin(str(meta.get("leader", "")), "Leader")
	return Locale.t("menu_continue_summary", [
		leader,
		int(meta.get("year", 1)),
		int(meta.get("month", 1)),
		int(meta.get("chapter", 0)),
	])

static func enter_loaded(tree: SceneTree) -> void:
	UnitArt.clear_cache()
	if GameState.flag("hub_open") or GameState.chapter0_beat >= "0.3":
		CKNav.home()
	else:
		CKNav.replace("res://scenes/story/chapter0.tscn")

func _ready() -> void:
	_build()
	UIFX.fade_in(self, 0.25)
	UIFX.wire_tree(self)

func _build() -> void:
	var bg := ColorRect.new()
	bg.color = UIKit.BG
	bg.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	if DeviceProfile.is_mobile():
		_build_mobile()
		return
	var col := VBoxContainer.new()
	col.name = "SlotColumn"
	col.position = Vector2(96, 96)
	col.custom_minimum_size = Vector2(640, 0)
	col.add_theme_constant_override("separation", 8)
	add_child(col)
	col.add_child(UIKit.title_label(Locale.t("menu_load"), 40))
	_place_shell_crests()
	for slot in CKSaveService.SLOTS:
		col.add_child(_row(slot))
	var back := UIKit.index_button("←", Locale.t("slot_back"), 360)
	back.name = "SlotBack"
	back.pressed.connect(_back)
	col.add_child(back)

func _row(slot: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.name = "SlotRow_%s" % slot
	row.add_theme_constant_override("separation", 16)
	var text := "%s\n%s" % [Locale.t("slot_%s" % slot), continue_line(slot)]
	var label := UIKit.body_label(text, UIKit.TEXT, 16)
	label.custom_minimum_size = Vector2(420, 48)
	row.add_child(label)
	CKHeraldryChrome.attach_save_row_arms(row, Vector2(36, 44))
	var load := UIKit.make_button(Locale.t("menu_load"))
	load.name = "Load_%s" % slot
	load.custom_minimum_size = Vector2(160, maxi(44, int(DeviceProfile.hit_px())))
	load.disabled = not FileAccess.file_exists(CKSaveService.body_path(slot))
	load.pressed.connect(_load.bind(slot))
	row.add_child(load)
	return row

## Phone: Frost cards in two columns (name + summary left, 76px load button right), back on top.
func _build_mobile() -> void:
	var w := maxf(get_viewport().get_visible_rect().size.x, 1280.0)
	var head := HBoxContainer.new()
	head.name = "SlotHead"
	head.position = Vector2(40, 16)
	head.size = Vector2(w - 80, MobilePage.HIT)
	add_child(head)
	var t := MobilePage.label(Locale.t("menu_load"), UIKit.TEXT, 32, false)
	head.add_child(t)
	var back := MobilePage.button(Locale.t("slot_back"), false, _back, 200)
	back.name = "SlotBack"
	back.size_flags_horizontal = Control.SIZE_SHRINK_END
	head.add_child(back)
	_place_shell_crests()
	var scroll := ScrollContainer.new()
	scroll.name = "SlotScroll"
	scroll.position = Vector2(40, 108)
	scroll.size = Vector2(w - 80, 720 - 108 - 20)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	var grid := GridContainer.new()
	grid.name = "SlotColumn"
	grid.columns = 2
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 16)
	grid.add_theme_constant_override("v_separation", 14)
	scroll.add_child(grid)
	for slot in CKSaveService.SLOTS:
		grid.add_child(_card(slot))

func _card(slot: String) -> PanelContainer:
	var has := FileAccess.file_exists(CKSaveService.body_path(slot))
	var card := PanelContainer.new()
	card.name = "SlotRow_%s" % slot
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var sb := UIKit.flat_box(Color(0.055, 0.067, 0.090, 0.92), UIKit.ACCENT_DIM if has else Color(1, 1, 1, 0.08), 10)
	for side in [SIDE_LEFT, SIDE_RIGHT, SIDE_TOP, SIDE_BOTTOM]:
		sb.set_content_margin(side, 16)
	card.add_theme_stylebox_override("panel", sb)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	card.add_child(row)
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(v)
	v.add_child(MobilePage.label(Locale.t("slot_%s" % slot), UIKit.TEXT, 24, false))
	v.add_child(MobilePage.label(continue_line(slot), UIKit.TEXT_DIM if has else UIKit.TEXT_FAINT, 22))
	var load := MobilePage.button(Locale.t("menu_load"), has, _load.bind(slot), 150)
	load.name = "Load_%s" % slot
	load.size_flags_horizontal = Control.SIZE_SHRINK_END
	load.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	load.disabled = not has
	row.add_child(load)
	CKHeraldryChrome.attach_save_row_arms(card, Vector2(40, 48))
	return card


func _place_shell_crests() -> void:
	## Load-list chrome: ShellCrestStrip + company header on the page root.
	var mob := DeviceProfile.is_mobile()
	var hdr := Vector2(44, 52) if not mob else Vector2(40, 48)
	var ban := Vector2(28, 38) if not mob else Vector2(24, 32)
	CKHeraldryChrome.place_shell_crest_strip(self, Vector2(1120, 18) if not mob else Vector2(1120, 8), hdr, ban)
	CKHeraldryChrome.place_company_header(self, Vector2(1180, 18) if not mob else Vector2(1180, 8), hdr)

func _load(slot: String) -> void:
	if GameState.load_from_slot(slot):
		enter_loaded(get_tree())

func _back() -> void:
	CKNav.replace(CKNav.TITLE)
