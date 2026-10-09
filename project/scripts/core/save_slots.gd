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
		tree.change_scene_to_file("res://scenes/hub/castle_hub.tscn")
	else:
		tree.change_scene_to_file("res://scenes/story/chapter0.tscn")

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
	var col := VBoxContainer.new()
	col.name = "SlotColumn"
	col.position = Vector2(96, 96)
	col.custom_minimum_size = Vector2(640, 0)
	col.add_theme_constant_override("separation", 8)
	add_child(col)
	col.add_child(UIKit.title_label(Locale.t("menu_load"), 40))
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
	var load := UIKit.make_button(Locale.t("menu_load"))
	load.name = "Load_%s" % slot
	load.custom_minimum_size = Vector2(160, maxi(44, int(DeviceProfile.hit_px())))
	load.disabled = not FileAccess.file_exists(CKSaveService.body_path(slot))
	load.pressed.connect(_load.bind(slot))
	row.add_child(load)
	return row

func _load(slot: String) -> void:
	if GameState.load_from_slot(slot):
		enter_loaded(get_tree())

func _back() -> void:
	get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn")
