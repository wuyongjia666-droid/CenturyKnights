extends Node
## P0-NAV-01: one back action, never trapped, never quits.

const ROSTER := "res://scenes/hub/roster.tscn"
const VIEW := "res://scenes/hub/castle_view.tscn"

var _fail := ""

func _ready() -> void:
	await get_tree().process_frame
	# keep this runner alive across scene changes: hand "current scene" to a throwaway node
	var dummy := Node.new()
	get_tree().root.add_child(dummy)
	get_tree().current_scene = dummy
	await _run()
	if _fail != "":
		print("FAIL nav stack: ", _fail)
		get_tree().quit(1)
		return
	print("NAV STACK PASS")
	get_tree().quit(0)

func _ok(cond: bool, msg: String) -> void:
	if not cond and _fail == "":
		_fail = msg

func _settle() -> void:
	for i in 6:
		await get_tree().process_frame

func _scene() -> String:
	var sc := get_tree().current_scene
	return sc.scene_file_path if sc != null else ""

func _run() -> void:
	_ok(ProjectSettings.get_setting("application/config/quit_on_go_back", true) == false, "quit_on_go_back must be false")
	_ok(int(ProjectSettings.get_setting("display/window/handheld/orientation", 6)) == 4, "android must lock sensor_landscape")
	GameState.new_game("导航", "灰旗", GameState.crest_color)
	# failure path: back on a scene outside hub/ui with an empty stack must not change scene
	var stray := Node.new()
	stray.scene_file_path = "res://tests/stray_runner.tscn"
	get_tree().root.add_child(stray)
	get_tree().current_scene = stray
	CKNav.stack.clear()
	_ok(CKNav.back() == "menu" and get_tree().current_scene == stray, "back on a non-page scene must open the menu, not go home")
	if CKPauseMenu.current != null and is_instance_valid(CKPauseMenu.current):
		CKPauseMenu.toggle()
	await get_tree().process_frame
	# this test node is not a scene; drive real scenes through CKNav
	CKNav.home()
	_ok(CKNav.go("res://scenes/hub/roster.tscn") == false, "second change in the same frame must be swallowed")
	_ok(CKNav.fx.blocking(), "curtain must block input during the change")
	await _settle()
	_ok(_scene() == CKNav.HOME, "home did not load")
	await get_tree().create_timer(CKTransition.total_seconds() + 0.15).timeout
	_ok(not CKNav.fx.curtain.visible and not CKNav.fx.blocking(), "curtain never lifted")
	# home: back opens then closes the system menu, never leaves
	_ok(CKNav.back() == "menu" and CKPauseMenu.current != null, "back at home must open the system menu")
	_ok(CKNav.back() == "menu", "second back must close the menu")
	await _settle()
	_ok(CKPauseMenu.current == null and _scene() == CKNav.HOME, "menu not closed / left home")
	# push two pages, pop through a page without _back
	_ok(CKNav.go(ROSTER), "go roster")
	_ok(CKNav.back() == "busy", "back during a pending change must be ignored")
	await _settle()
	_ok(CKNav.go(VIEW), "go castle_view")
	await _settle()
	_ok(_scene() == VIEW and CKNav.stack.size() == 2, "stack after two pushes: %s" % str(CKNav.stack))
	# overlay closes first
	var ov := Control.new()
	get_tree().current_scene.add_child(ov)
	CKNav.push_overlay(ov)
	_ok(CKNav.back() == "overlay", "overlay must close before the page")
	await _settle()
	_ok(not is_instance_valid(ov) and _scene() == VIEW, "overlay not freed or page changed")
	# focused text field swallows back
	var le := LineEdit.new()
	get_tree().current_scene.add_child(le)
	le.grab_focus()
	_ok(CKNav.back() == "focus", "focused LineEdit must only lose focus")
	_ok(_scene() == VIEW, "focus back changed page")
	le.queue_free()
	await _settle()
	_ok(CKNav.back() in ["pop", "page"], "page back must pop the stack")
	await _settle()
	_ok(_scene() == ROSTER, "pop did not return to roster (%s)" % _scene())
	# legacy hop is learned
	get_tree().change_scene_to_file(VIEW)
	await _settle()
	_ok(not CKNav.stack.is_empty() and str(CKNav.stack[-1].path) == ROSTER, "legacy hop not recorded")
	CKNav.back()
	await _settle()
	_ok(_scene() == ROSTER, "back after legacy hop")
	# roster has its own _back -> page route returns home
	_ok(CKNav.back() == "page", "roster back must use its page route")
	await _settle()
	_ok(_scene() == CKNav.HOME and CKNav.stack.is_empty(), "roster back did not land home with a clear stack")
	# failure path: missing scene is refused, nothing changes
	_ok(not CKNav.go("res://scenes/hub/nope.tscn"), "missing scene accepted")
	await _settle()
	_ok(_scene() == CKNav.HOME and CKNav.stack.is_empty(), "failed go changed state")
	# never quits: back on the title is a no-op; go-back notification routes to CKNav
	get_tree().change_scene_to_file(CKNav.TITLE)
	await _settle()
	_ok(CKNav.back() == "noop", "title back must be a no-op")
	GameState.notification(NOTIFICATION_WM_GO_BACK_REQUEST)
	await _settle()
	_ok(_scene() == CKNav.TITLE, "go-back request left the title")
	# right click toggle
	GameState.settings["nav_right_back"] = false
	_ok(not CKNav.right_click_back_enabled(), "right click toggle ignored")
	GameState.settings["nav_right_back"] = true
	_ok(CKNav.right_click_back_enabled() != DeviceProfile.is_mobile(), "right click default")
