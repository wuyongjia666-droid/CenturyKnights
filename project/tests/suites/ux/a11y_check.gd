extends Node
## UX-02：色盲模拟后的 ΔE2000、对比度、140% 缩放下的主菜单版式与文字裁切。

var _fails: Array = []

func _ready() -> void:
	await get_tree().process_frame
	_palettes()
	_toggles()
	await _layout_at_scale()
	await _settings_labels()
	var tree := Engine.get_main_loop() as SceneTree
	if _fails.is_empty():
		print("A11Y PASS")
		tree.quit(0)
	else:
		for f in _fails:
			print("FAIL a11y: ", f)
		tree.quit(1)

func _ok(cond: bool, msg: String) -> void:
	if not cond:
		_fails.append(msg)

func _palettes() -> void:
	for mode in ["deuteranopia", "protanopia", "tritanopia"]:
		var p: Dictionary = Frost.resolved(mode, false)
		var seen_ally := Frost.simulate_cvd(p["ally"], mode)
		var seen_enemy := Frost.simulate_cvd(p["enemy"], mode)
		var d := Frost.delta_e2000(seen_ally, seen_enemy)
		print("CVD %s dE %.2f ally %s enemy %s" % [mode, d, p["ally"].to_html(false), p["enemy"].to_html(false)])
		_ok(d >= 20.0, "%s deltaE %.2f < 20" % [mode, d])
	for mode in Frost.MODES:
		for high in [false, true]:
			var p2: Dictionary = Frost.resolved(mode, high)
			for pair in Frost.text_pairs(p2):
				var ratio := Frost.contrast_ratio(pair[0], pair[1])
				_ok(ratio >= 4.5, "contrast %s high=%s %.2f" % [mode, high, ratio])
	var ally := UIKit.faction_mark("player")
	var enemy := UIKit.faction_mark("enemy")
	_ok(str(ally.get("team")) == "player" and str(enemy.get("team")) == "enemy", "shape marks")
	_ok(ally.get_script() == enemy.get_script(), "shared mark widget")

func _toggles() -> void:
	GameState.settings["screen_shake"] = 0
	_ok(is_zero_approx(UIKit.shake_gain()), "shake 0")
	GameState.settings["screen_shake"] = 40
	_ok(is_equal_approx(UIKit.shake_gain(), 0.4), "shake 40")
	GameState.settings["haptics"] = false
	_ok(not UIKit.haptics_enabled(), "haptics off")
	GameState.settings["haptics"] = true
	_ok(UIKit.haptics_enabled(), "haptics on")
	GameState.settings["screen_shake"] = 100

func _layout_at_scale() -> void:
	GameState.settings["ui_scale"] = 1.4
	GameState.settings["tutorial_highlight"] = false
	var root := get_tree().root
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	root.content_scale_factor = 1.0
	root.size = Vector2i(int(1280.0 * 1.4), int(720.0 * 1.4))
	await get_tree().process_frame
	var scene := (load("res://scenes/ui/main_menu.tscn") as PackedScene).instantiate() as Control
	scene.position = Vector2.ZERO
	scene.size = Vector2(1280, 720)
	scene.scale = Vector2(1.4, 1.4)
	add_child(scene)
	await get_tree().process_frame
	await get_tree().process_frame
	var vp := Vector2(1280.0 * 1.4, 720.0 * 1.4)
	var box := scene.find_child("MenuColumn", false, false) as Control
	_ok(box != null, "MenuColumn")
	if box == null:
		return
	var r := Rect2(box.global_position, Vector2.ZERO)
	for ch in box.get_children():
		if ch is Control and (ch as Control).visible:
			r = r.merge((ch as Control).get_global_rect())
	print("LAYOUT140 viewport=%s col=%s scale=%s" % [vp, r, scene.scale])
	var first_btn: Control = null
	for ch in box.get_children():
		if ch is Button:
			first_btn = ch
			break
	_ok(r.position.x >= 24.0 and r.position.y >= 24.0, "column origin %s" % r)
	_ok(r.end.x <= vp.x * 0.5 + 1.0, "column left half %s vp %s" % [r, vp])
	_ok(first_btn != null and first_btn.global_position.y <= vp.y - 120.0, "first button on screen")
	_scan(box, "menu")

func _settings_labels() -> void:
	GameState.settings["ui_scale"] = 1.4
	var packed := load("res://scenes/ui/settings.tscn")
	var settings := packed.instantiate() as Control
	settings.scale = Vector2(1.4, 1.4)
	var host := Control.new()
	host.size = Vector2(1280, 720)
	add_child(host)
	host.add_child(settings)
	for _i in 3:
		await get_tree().process_frame
	_scan(settings, "settings")
	_ok(settings.find_child("Colorblind", true, false) != null, "colorblind control")
	_ok(settings.find_child("UiScale", true, false) != null, "scale slider")
	_ok(settings.find_child("BattleSwatch", true, false) != null, "battle swatch")
	_ok(settings.find_child("FactionPreview", true, false) != null, "faction preview")

func _scan(root: Node, tag: String) -> void:
	for node in root.find_children("*", "Label", true, false):
		var label := node as Label
		if label == null or label.text.strip_edges() == "":
			continue
		if not label.visible:
			continue
		if label.get_parent() is Button:
			continue
		var font := label.get_theme_font("font")
		if font == null:
			continue
		var fsize := label.get_theme_font_size("font_size")
		if label.autowrap_mode != TextServer.AUTOWRAP_OFF:
			continue
		if label.size.x < 8.0:
			continue
		var width := font.get_string_size(label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, fsize).x
		_ok(width <= label.size.x + 2.0, "%s clip %s w %.0f box %.0f" % [tag, label.text, width, label.size.x])
