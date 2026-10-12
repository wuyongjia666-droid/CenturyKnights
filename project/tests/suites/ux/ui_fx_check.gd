extends Node
## UX-09：转场时长上限，以及触感开关关掉时不震动。

var _fails: Array = []
var _hook_ms: Array = []

func _ready() -> void:
	var saved_motion = GameState.settings.get("reduced_motion", false)
	var saved_haptics = GameState.settings.get("haptics", true)
	UIFX.vibrate_calls = 0
	UIFX.vibrate_hook = Callable(self, "_on_vibrate")
	GameState.settings["reduced_motion"] = false
	var full := UIFX.transition_seconds(0.40)
	_ok(full <= 0.25, "full transition %.3f" % full)
	_ok(full > 0.08, "full transition collapsed")
	GameState.settings["reduced_motion"] = true
	var short := UIFX.transition_seconds(0.40)
	_ok(short <= 0.08, "reduced transition %.3f" % short)
	GameState.settings["haptics"] = false
	var before := UIFX.vibrate_calls
	UIFX.haptic(12)
	_ok(UIFX.vibrate_calls == before and _hook_ms.is_empty(), "haptics off still vibrated")
	GameState.settings["haptics"] = true
	UIFX.haptic(18)
	_ok(UIFX.vibrate_calls == before + 1 and _hook_ms == [18], "haptics on did not stub")
	# P0-FX-01: page transition budget
	GameState.settings["reduced_motion"] = false
	_ok(CKTransition.total_seconds() <= 0.36, "page transition %.3f > 0.36" % CKTransition.total_seconds())
	GameState.settings["reduced_motion"] = true
	_ok(CKTransition.total_seconds() <= 0.1, "reduced page transition %.3f > 0.1" % CKTransition.total_seconds())
	# §6.2 feedback layers
	var b := Button.new()
	b.size = Vector2(120, 40)
	add_child(b)
	UIFX.wire_button(b)
	var n0 := UIFX.vibrate_calls
	b.button_down.emit()
	_ok(UIFX.vibrate_calls == n0, "plain press must not vibrate")
	b.disabled = true
	b.set_meta("deny_reason", "not enough silver")
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = true
	b.gui_input.emit(ev)
	var lab := b.get_node_or_null("DenyReason") as Label
	_ok(lab != null and lab.text == "not enough silver", "disabled press must show its reason")
	_ok(UIFX.vibrate_calls == n0 + 1 and _hook_ms.back() == 8, "deny must buzz 8ms")
	b.gui_input.emit(ev)
	_ok(b.get_children().filter(func(c): return c.name == "DenyReason").size() == 1, "repeat deny stacked labels")
	b.remove_meta("deny_reason")
	b.gui_input.emit(ev)
	_ok(b.get_node_or_null("DenyReason") == null, "no reason must not leave an empty label")
	UIFX.confirm(b)
	_ok(_hook_ms.back() == 12, "confirm must buzz 12ms")
	b.free()
	GameState.settings["reduced_motion"] = saved_motion
	GameState.settings["haptics"] = saved_haptics
	UIFX.vibrate_hook = Callable()
	var tree := Engine.get_main_loop() as SceneTree
	if _fails.is_empty():
		print("UIFX PASS full=%.3f reduced=%.3f" % [full, short])
		tree.quit(0)
	else:
		for f in _fails:
			print("FAIL uifx: ", f)
		tree.quit(1)

func _on_vibrate(ms: int) -> void:
	_hook_ms.append(ms)

func _ok(cond: bool, msg: String) -> void:
	if not cond:
		_fails.append(msg)
