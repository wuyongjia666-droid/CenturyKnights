extends Node
## CKNav (P0-NAV-01, docs/design/ux-navigation-v1.md §3.4).
## One back action for ESC, Android back, gamepad B and (PC) right click.
## Never traps the player and never quits the app.
##
## Contract:
##   back() -> String   what it did: "focus", "overlay", "menu", "busy", "battle_menu",
##                      "page", "pop", "home", "noop". Always safe to call; never quits.
##   go(path, params)   push current scene, change to path.
##   replace(path, params), home(), params()
##   push_overlay(node) / pop_overlay(node)  modal layers close before any page change.
## Until every page is migrated (P0-NAV-02) the stack also learns legacy
## change_scene_to_file hops by watching current_scene.

const HOME := "res://scenes/hub/castle_hub.tscn"
const TITLE := "res://scenes/ui/main_menu.tscn"
const BATTLE := "res://scenes/battle/battle.tscn"
const MAX_DEPTH := 8
## Scenes that are never returned into (a finished battle, the title, the boot shell).
const NO_RETURN := [BATTLE, TITLE, "res://scenes/ui/boot.tscn"]

var stack: Array = []        # [{"path": String, "params": Dictionary}], oldest first; current scene not included
var overlays: Array = []     # Nodes, top last
var _params: Dictionary = {}
var _cur := ""
var _busy := false
var _via_nav := false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().set_auto_accept_quit(true)

func _process(_dt: float) -> void:
	var sc := get_tree().current_scene
	var path := sc.scene_file_path if sc != null else ""
	if path == _cur:
		return
	_on_scene_changed(_cur, path)
	_cur = path

func _on_scene_changed(old: String, new: String) -> void:
	_busy = false
	overlays = overlays.filter(func(n): return is_instance_valid(n))
	if _via_nav:
		_via_nav = false
		return
	_params = {}
	if new == HOME or new == TITLE:
		stack.clear()
		return
	_note(old)
	_truncate_to(new)

func _note(path: String) -> void:
	if path == "" or path in NO_RETURN:
		return
	if not stack.is_empty() and str(stack[-1].path) == path:
		return
	stack.append({"path": path, "params": _params.duplicate()})
	if stack.size() > MAX_DEPTH:
		stack.remove_at(1)  # keep the bottom, drop the middle

func _truncate_to(path: String) -> void:
	for i in stack.size():
		if str(stack[i].path) == path:
			stack.resize(i)
			return

# ── navigation ────────────────────────────────────────
func params() -> Dictionary:
	return _params

func go(path: String, p: Dictionary = {}) -> bool:
	if _busy or path == "" or not ResourceLoader.exists(path):
		return false
	_note(_cur)
	_truncate_to(path)
	return _change(path, p)

func replace(path: String, p: Dictionary = {}) -> bool:
	if _busy or path == "":
		return false
	return _change(path, p)

func home() -> bool:
	stack.clear()
	return _change(HOME, {})

func _change(path: String, p: Dictionary) -> bool:
	if not ResourceLoader.exists(path):
		push_warning("CKNav: missing scene %s" % path)
		return false
	_busy = true
	_via_nav = true
	_params = p.duplicate()
	get_tree().change_scene_to_file.call_deferred(path)
	return true

# ── overlays ──────────────────────────────────────────
func push_overlay(n: Node) -> void:
	if n != null and not overlays.has(n):
		overlays.append(n)

func pop_overlay(n: Node = null) -> void:
	if n == null:
		if not overlays.is_empty():
			overlays.pop_back()
		return
	overlays.erase(n)

func _close_top_overlay() -> bool:
	while not overlays.is_empty():
		var n = overlays.pop_back()
		if is_instance_valid(n):
			if n.has_method("nav_close"):
				n.nav_close()
			else:
				n.queue_free()
			return true
	return false

func _menu_open() -> bool:
	return CKPauseMenu.current != null and is_instance_valid(CKPauseMenu.current)

# ── the one back action ───────────────────────────────
func back() -> String:
	var vp := get_viewport()
	var focus := vp.gui_get_focus_owner() if vp else null
	if focus is LineEdit or focus is TextEdit:
		focus.release_focus()
		return "focus"
	if _close_top_overlay():
		return "overlay"
	if _menu_open():
		CKPauseMenu.toggle()
		return "menu"
	if _busy:
		return "busy"
	var sc := get_tree().current_scene
	var path := sc.scene_file_path if sc != null else ""
	if path == BATTLE:
		_open_menu()
		return "battle_menu"
	if path == HOME:
		_open_menu()
		return "menu"
	if path == TITLE or path == "":
		return "noop"
	if sc.has_method("nav_back"):
		sc.nav_back()
		return "page"
	if sc.has_method("_back"):
		sc._back()
		return "page"
	if not stack.is_empty():
		var top: Dictionary = stack.pop_back()
		_change(str(top.path), top.get("params", {}))
		return "pop"
	home()
	return "home"

func _open_menu() -> void:
	if not _menu_open():
		CKPauseMenu.toggle()
		var m = CKPauseMenu.current
		if m != null and is_instance_valid(m):
			MobileLayout.place_pause(m, get_viewport().get_visible_rect().size)

func right_click_back_enabled() -> bool:
	return not DeviceProfile.is_mobile() and bool(GameState.settings.get("nav_right_back", true))

func _unhandled_input(e: InputEvent) -> void:
	if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_RIGHT and right_click_back_enabled():
		var sc := get_tree().current_scene
		if sc != null and sc.scene_file_path == BATTLE:
			return  # the board uses right click
		back()
		get_viewport().set_input_as_handled()
