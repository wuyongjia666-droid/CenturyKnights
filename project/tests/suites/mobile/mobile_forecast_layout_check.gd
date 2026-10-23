extends Node
## Y1-A T-P2-1: phone landscape Forecast + unit info rail stay readable.
## Floored fonts must not be clipped into extreme narrow/short rects (hub city
## squashed-label regression style). Named mobile_* → CK_FORCE_MOBILE=1.

const PHONE := Vector2i(2400, 1080)
const ROOT := Vector2(1600, 720)  # MobileLayout.fit logical size for 2400×1080 landscape
const MIN_LABEL_W := 80.0
const MIN_LABEL_H_RATIO := 0.85  # size.y must be ≥ font × this (not vertically squashed)

var _battle: Control
var _p := -1
var _e := -1

func _ready() -> void:
	var err := await _run()
	if err != "":
		print("FAIL mobile forecast layout: ", err)
		get_tree().quit(1)
		return
	print("MOBILE FORECAST LAYOUT PASS")
	get_tree().quit(0)

func _run() -> String:
	if not DeviceProfile.is_mobile():
		return "DeviceProfile.is_mobile() false — need CK_FORCE_MOBILE=1"
	await _set_phone_window()
	var err := await _setup_battle()
	if err != "":
		return err
	err = await _show_forecast()
	if err != "":
		return err
	err = _audit_forecast()
	if err != "":
		return err
	err = _audit_unit_rail()
	if err != "":
		return err
	if _battle != null and is_instance_valid(_battle):
		_battle.queue_free()
	return ""

func _set_phone_window() -> void:
	var win := get_tree().root
	win.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	win.size = PHONE
	await get_tree().process_frame
	await get_tree().process_frame

func _setup_battle() -> String:
	GameState.new_game("烬行", "灰旗", "#%02x%02x%02x" % [110, 212, 255])
	GameState.settings.erase("touch_confirm")
	GameState.settings.erase("touch_drag_commit")
	OS.set_environment("CK_SAFE_INSETS", "80,0,0,24")
	_battle = load("res://scenes/battle/battle.tscn").instantiate()
	get_tree().root.add_child(_battle)
	get_tree().current_scene = _battle
	await _settle(6)
	# Mirror MobileChrome fit so board stage / side column match a phone root.
	var insets := {"left": 80.0, "top": 0.0, "right": 0.0, "bottom": 24.0}
	var fitted: Dictionary = MobileLayout.fit(Vector2(PHONE), insets)
	MobileLayout.apply_root(_battle, fitted)
	_battle.set_meta("mobile_insets", insets)
	if _battle.has_method("apply_mobile_layout"):
		_battle.apply_mobile_layout()
	await _settle(6)
	MobileLayout.ensure_min_fonts(_battle)
	await _settle(2)
	if not _arrange():
		return "deploy missing player/enemy"
	await _settle(2)
	return ""

func _arrange() -> bool:
	_p = -1
	_e = -1
	for i in _battle.units.size():
		var u = _battle.units[i]
		if u.team == "player" and _p < 0:
			_p = i
			u.pos = Vector2i(3, 3)
			u.done = false
		elif u.team == "enemy" and _e < 0:
			_e = i
			u.pos = Vector2i(5, 3)
		elif u.team == "player":
			u.pos = Vector2i(0, _battle.MAP_H - 1)
			u.done = true
		else:
			u.char.hp = 0
	_battle.selected = -1
	_battle.turn_team = "player"
	_battle.battle_over = false
	_battle._cut_playing = false
	return _p >= 0 and _e >= 0

func _show_forecast() -> String:
	_battle._select_player(_p)
	_battle.attack_mode = true
	_battle._hover_cell = _battle.units[_e].pos
	_battle.preview_attack_ui = _e
	ForecastPanel.refresh(_battle)
	await _settle(4)
	var panel := _battle.get_node_or_null("ForecastPanel") as Control
	if panel == null:
		return "ForecastPanel missing"
	if not panel.visible:
		return "ForecastPanel not visible after attack preview"
	return ""

func _audit_forecast() -> String:
	var panel := _battle.get_node_or_null("ForecastPanel") as Control
	var floor_px := MobileLayout.FONT_FLOOR
	if panel.size.x + 0.5 < ForecastPanel.MOBILE_PANEL_MIN.x:
		return "forecast width %.1f < min %.1f" % [panel.size.x, ForecastPanel.MOBILE_PANEL_MIN.x]
	if panel.size.y + 0.5 < ForecastPanel.MOBILE_PANEL_MIN.y:
		return "forecast height %.1f < min %.1f (floored type would squash)" % [panel.size.y, ForecastPanel.MOBILE_PANEL_MIN.y]
	if panel.clip_contents:
		return "forecast still clip_contents on mobile"
	var root_r := _battle.get_global_rect().grow(4.0)
	var pr := panel.get_global_rect()
	if not root_r.intersects(pr):
		return "forecast outside battle root: panel=%s root=%s" % [str(pr), str(root_r)]
	for nm in ["Ours", "Theirs"]:
		var title := panel.get_node_or_null("Cols/%s/Title" % nm) as Label
		var body := panel.get_node_or_null("Cols/%s/Body" % nm) as Label
		if title == null or body == null:
			return "forecast %s Title/Body missing" % nm
		var err := _not_squashed(title, floor_px, "forecast/%s/Title" % nm)
		if err != "":
			return err
		err = _not_squashed(body, floor_px, "forecast/%s/Body" % nm)
		if err != "":
			return err
		if body.get_theme_font_size("font_size") < floor_px:
			return "forecast %s Body font %d < %d" % [nm, body.get_theme_font_size("font_size"), floor_px]
	print("forecast ok size=", panel.size, " pos=", panel.position)
	return ""

func _audit_unit_rail() -> String:
	var floor_px := MobileLayout.FONT_FLOOR
	var side := _battle.get_node_or_null("MobileSideCol") as Control
	if side == null:
		return "MobileSideCol missing — landscape side rail not attached"
	if side.size.x < 120.0 or side.size.y < 200.0:
		return "MobileSideCol degenerate size %s" % str(side.size)
	# Unit card HP / name are the "血量/射程/敌我差" surface called out in the audit.
	if _battle._unit_card != null:
		for child in _battle._unit_card.find_children("*", "Label", true, false):
			var l := child as Label
			if l == null or not l.is_visible_in_tree():
				continue
			if l.text.strip_edges() == "":
				continue
			var err := _not_squashed(l, floor_px, "unit_card/%s" % l.name)
			if err != "":
				return err
	if _battle.info_label != null and _battle.info_label.is_visible_in_tree():
		var fs: int = _battle.info_label.get_theme_font_size("normal_font_size")
		if fs < floor_px:
			return "info_label font %d < %d" % [fs, floor_px]
		var ir: Rect2 = _battle.info_label.get_global_rect()
		if ir.size.y + 0.5 < float(floor_px) * MIN_LABEL_H_RATIO:
			return "info_label squashed h=%.1f font=%d" % [ir.size.y, fs]
	print("unit rail ok side=", side.size)
	return ""

func _not_squashed(l: Label, floor_px: int, tag: String) -> String:
	var fs: int = l.get_theme_font_size("font_size")
	if fs < floor_px:
		return "%s font %d < %d" % [tag, fs, floor_px]
	var r: Rect2 = l.get_global_rect()
	if r.size.x + 0.5 < MIN_LABEL_W:
		return "%s extreme narrow %.1f×%.1f (font %d)" % [tag, r.size.x, r.size.y, fs]
	if r.size.y + 0.5 < float(fs) * MIN_LABEL_H_RATIO:
		return "%s squashed %.1f×%.1f (font %d)" % [tag, r.size.x, r.size.y, fs]
	return ""

func _settle(n: int = 3) -> void:
	for _i in n:
		await get_tree().process_frame
