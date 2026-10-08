class_name DeviceProfile
extends RefCounted
## Phone vs desktop. Headless CI stays on the desktop path unless CK_FORCE_MOBILE=1.

const DESIGN := Vector2(1280, 720)
const HIT_DP := 44.0

static func is_mobile() -> bool:
	var force := OS.get_environment("CK_FORCE_MOBILE")
	if force == "1":
		return true
	if force == "0":
		return false
	if OS.has_feature("mobile") or OS.has_feature("android") or OS.has_feature("ios"):
		return true
	return OS.get_name() in ["Android", "iOS"]

static func is_low_end() -> bool:
	var force := OS.get_environment("CK_FORCE_LOW_END")
	if force == "1":
		return true
	if force == "0":
		return false
	if not is_mobile():
		return false
	var info := OS.get_memory_info()
	var phys := int(info.get("physical", 0))
	if phys <= 0:
		return false
	return phys <= 4 * 1024 * 1024 * 1024

static func logical_viewport(window: Vector2, design: Vector2 = DESIGN) -> Vector2:
	## Godot canvas_items + expand: base size is the minimum, the other axis grows.
	if window.x <= 1.0 or window.y <= 1.0:
		return design
	var wa := window.x / window.y
	var da := design.x / design.y
	if wa >= da:
		return Vector2(design.y * wa, design.y)
	return Vector2(design.x, design.x / wa)

static func insets_from_safe(viewport: Vector2, window: Vector2, safe: Rect2) -> Dictionary:
	if window.x < 1.0 or window.y < 1.0:
		return {"left": 0.0, "top": 0.0, "right": 0.0, "bottom": 0.0}
	var sx := viewport.x / window.x
	var sy := viewport.y / window.y
	return {
		"left": maxf(0.0, safe.position.x * sx),
		"top": maxf(0.0, safe.position.y * sy),
		"right": maxf(0.0, (window.x - safe.end.x) * sx),
		"bottom": maxf(0.0, (window.y - safe.end.y) * sy),
	}

static func hit_px_for(dpi: float, viewport_w: float, window_w: float) -> float:
	## 44dp converted into viewport pixels. Floor at 44 so a low reported dpi still taps.
	var phys := HIT_DP * maxf(dpi, 1.0) / 160.0
	var logical := phys * (viewport_w / maxf(window_w, 1.0))
	return maxf(44.0, logical)

static func hit_px() -> float:
	var win := Vector2(DisplayServer.window_get_size())
	var dpi := float(DisplayServer.screen_get_dpi())
	if dpi <= 1.0:
		dpi = 160.0
	var vp := win
	var loop := Engine.get_main_loop()
	if loop is SceneTree and (loop as SceneTree).root:
		vp = (loop as SceneTree).root.get_visible_rect().size
	if win.x < 2.0:
		win = vp
	return hit_px_for(dpi, vp.x, win.x)

static func cutscene_budget_for(mobile: bool, low_end: bool) -> Dictionary:
	if low_end:
		return {
			"msaa": Viewport.MSAA_DISABLED,
			"size": Vector2i(854, 480),
			"simple": true,
			"particles": 0.0,
			"shadows": false,
			"glow": false,
			"fog": false,
		}
	if mobile:
		return {
			"msaa": Viewport.MSAA_2X,
			"size": Vector2i(960, 540),
			"simple": false,
			"particles": 0.45,
			"shadows": false,
			"glow": false,
			"fog": true,
		}
	return {
		"msaa": Viewport.MSAA_4X,
		"size": Vector2i(1280, 720),
		"simple": false,
		"particles": 1.0,
		"shadows": true,
		"glow": true,
		"fog": true,
	}

static func cutscene_budget() -> Dictionary:
	var budget := cutscene_budget_for(is_mobile(), is_low_end())
	if OS.get_environment("CK_SIMPLE_TOON") == "1":
		budget["simple"] = true
	elif OS.get_environment("CK_SIMPLE_TOON") == "0":
		budget["simple"] = false
	elif is_mobile() and _setting_bool("simple_toon", bool(budget["simple"])):
		budget["simple"] = true
	return budget

static func _setting_bool(key: String, fallback: bool) -> bool:
	var loop := Engine.get_main_loop()
	if not (loop is SceneTree):
		return fallback
	var root := (loop as SceneTree).root
	if root == null:
		return fallback
	var gs := root.get_node_or_null("GameState")
	if gs == null:
		return fallback
	var settings = gs.get("settings")
	if typeof(settings) != TYPE_DICTIONARY or not (settings as Dictionary).has(key):
		return fallback
	return bool((settings as Dictionary)[key])
