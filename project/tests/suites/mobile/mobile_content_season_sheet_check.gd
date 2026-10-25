extends Node
## 内容季 sheet：十季芯片在短屏/竖屏下必须可滚动到达 cs08..cs10（禁裁切）。
## Named mobile_* → ci_godot_run.sh 设 CK_FORCE_MOBILE=1。

const EXPECTED := ["cs01_01", "cs02_01", "cs03_01", "cs04_01", "cs05_01", "cs06_01", "cs07_01", "cs08_01", "cs09_01", "cs10_01"]
const HUB_SCENE := preload("res://scenes/hub/castle_hub.tscn")
const PHONE_LAND := Vector2i(1600, 720)
const PHONE_PORT := Vector2i(720, 1280)

func _ready() -> void:
	var err := await _run()
	if err != "":
		print("FAIL mobile_content_season_sheet: ", err)
		get_tree().quit(1)
	else:
		print("MOBILE CONTENT SEASON SHEET PASS")
		get_tree().quit(0)


func _run() -> String:
	if not DeviceProfile.is_mobile():
		return "DeviceProfile.is_mobile() false — need CK_FORCE_MOBILE=1"
	var err := await _probe(PHONE_LAND, "land")
	if err != "":
		return err
	err = await _probe(PHONE_PORT, "port")
	if err != "":
		return err
	return ""


func _probe(win_size: Vector2i, tag: String) -> String:
	var win := get_tree().root
	win.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	win.size = win_size
	await get_tree().process_frame
	await get_tree().process_frame
	GameState.new_game("烬行", "灰旗", GameState.crest_color)
	var hub = HUB_SCENE.instantiate()
	add_child(hub)
	hub.set_anchors_preset(Control.PRESET_TOP_LEFT)
	hub.position = Vector2.ZERO
	hub.size = Vector2(win_size)
	for _i in 4:
		await get_tree().process_frame
	if not hub.has_method("_open_content_season_sheet"):
		hub.queue_free()
		return "%s: open helper missing" % tag
	hub.call("_open_content_season_sheet")
	for _j in 4:
		await get_tree().process_frame
	var sheet := hub.get_node_or_null("ContentSeasonSheet") as Control
	if sheet == null:
		hub.queue_free()
		return "%s: ContentSeasonSheet missing" % tag
	var card := hub.find_child("SheetCard", true, false) as Control
	var scroll := hub.find_child("ContentSeasonScroll", true, false) as ScrollContainer
	var list := hub.find_child("ContentSeasonList", true, false) as Control
	if card == null or scroll == null or list == null:
		hub.queue_free()
		return "%s: card/scroll/list missing" % tag
	if card.size.y > float(win_size.y) + 2.0:
		hub.queue_free()
		return "%s: SheetCard h=%.1f > viewport %d" % [tag, card.size.y, win_size.y]
	for cid in EXPECTED:
		var chip := hub.find_child("Season_%s" % cid, true, false) as BaseButton
		if chip == null:
			hub.queue_free()
			return "%s: chip %s missing" % [tag, cid]
		if not scroll.is_ancestor_of(chip):
			hub.queue_free()
			return "%s: chip %s not under scroll" % [tag, cid]
	# Content taller than viewport → scroll range must open so last chip is reachable.
	if list.get_combined_minimum_size().y > scroll.size.y + 1.0:
		var bar := scroll.get_v_scroll_bar()
		if bar == null or bar.max_value <= bar.min_value + 1.0:
			hub.queue_free()
			return "%s: overflow list but scroll range empty list_h=%.1f scroll_h=%.1f" % [
				tag, list.get_combined_minimum_size().y, scroll.size.y]
		scroll.scroll_vertical = int(bar.max_value)
		await get_tree().process_frame
		await get_tree().process_frame
	var last := hub.find_child("Season_cs10_01", true, false) as Control
	var close_b := hub.find_child("ContentSeasonClose", true, false) as Control
	if last == null or close_b == null:
		hub.queue_free()
		return "%s: last chip or close missing" % tag
	# Close stays outside scroll (always visible); last chip must be in scroll tree.
	if scroll.is_ancestor_of(close_b):
		hub.queue_free()
		return "%s: close wrongly inside scroll" % tag
	print("OK mobile sheet %s card_h=%.0f scroll_h=%.0f list_min=%.0f chips=%d" % [
		tag, card.size.y, scroll.size.y, list.get_combined_minimum_size().y, EXPECTED.size()])
	hub.queue_free()
	await get_tree().process_frame
	return ""
