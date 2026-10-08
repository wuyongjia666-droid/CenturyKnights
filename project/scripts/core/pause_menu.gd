class_name CKPauseMenu
extends CanvasLayer
## Continue, save, load, settings, title. Esc and the Android back key toggle it.
## While it is open, board gestures are swallowed so the tactics map does not move.

static var current: CKPauseMenu = null

const BUTTONS := [
	["PauseContinue", "pause_continue"],
	["PauseSave", "pause_save"],
	["PauseLoad", "pause_load"],
	["PauseSettings", "pause_settings"],
	["PauseTitle", "pause_title"],
]

static func toggle() -> void:
	if current != null and is_instance_valid(current):
		current.queue_free()
		return
	var tree := Engine.get_main_loop()
	if not (tree is SceneTree):
		return
	var layer := CKPauseMenu.new()
	(tree as SceneTree).root.add_child(layer)

static func board_events(router: InputRouter, event: InputEvent, now_ms: int) -> Array:
	if GameState.board_input_blocked:
		return []
	return router.push(event, now_ms)

func _ready() -> void:
	current = self
	layer = 100
	GameState.board_input_blocked = true
	var hit := DeviceProfile.hit_px()
	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(UIKit.BG, 0.72)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dim)
	var panel := UIKit.make_glass(16, 0.88)
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.custom_minimum_size = Vector2(360, hit * 5 + 96)
	panel.position = Vector2(460, 80)
	add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	panel.add_child(box)
	var title := UIKit.title_label(Locale.t("pause_heading"), 28)
	box.add_child(title)
	for spec in BUTTONS:
		var b := UIKit.make_button(Locale.t(str(spec[1])), 280)
		b.name = str(spec[0])
		b.custom_minimum_size = Vector2(280, hit)
		b.focus_mode = Control.FOCUS_ALL
		box.add_child(b)
	_wire(box)

func _exit_tree() -> void:
	if current == self:
		current = null
	GameState.board_input_blocked = false

func _wire(box: VBoxContainer) -> void:
	box.get_node("PauseContinue").pressed.connect(toggle)
	box.get_node("PauseSave").pressed.connect(func(): GameState.save_game())
	box.get_node("PauseLoad").pressed.connect(func(): GameState.load_game())
	box.get_node("PauseSettings").pressed.connect(func(): _go("res://scenes/ui/settings.tscn"))
	box.get_node("PauseTitle").pressed.connect(func(): _go("res://scenes/ui/main_menu.tscn"))

func _go(path: String) -> void:
	queue_free()
	var tree := get_tree()
	if tree:
		tree.change_scene_to_file(path)
