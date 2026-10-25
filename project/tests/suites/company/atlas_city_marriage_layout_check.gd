extends Node
## Desktop shot-gate layout: produce quotes, city action row, and marriage forecast
## stay inside the 1280×720 viewport without clipped lines or text overlap.
## Embedded by atlas_e2e (set embedded before add_child).

const ATLAS := preload("res://scenes/hub/atlas_view.tscn")
const CITY := preload("res://scenes/hub/city.tscn")
const MARRIAGE := preload("res://scenes/hub/marriage.tscn")
const FONT_FLOOR := 12

var embedded := false
var fails: Array = []


func _ready() -> void:
	if embedded:
		return
	await get_tree().process_frame
	await run_checks()
	if fails.is_empty():
		print("ATLAS CITY MARRIAGE LAYOUT PASS")
		get_tree().quit(0)
	else:
		for f in fails:
			print("FAIL layout: ", f)
		get_tree().quit(1)


func run_checks() -> void:
	fails = []
	_setup()
	await _check_atlas("hq")
	_setup()
	World.pos = "ash_capital"
	World.visited["ash_capital"] = true
	await _check_atlas("ash_capital")
	_setup()
	await _check_city("hq")
	_setup()
	World.pos = "ash_capital"
	World.visited["ash_capital"] = true
	await _check_city("ash_capital")
	_setup()
	World.pos = "ash_capital"
	World.visited["ash_capital"] = true
	GameState.set_meta("city_tab", "market")
	await _check_market()
	_setup()
	await _check_marriage()


func _ok(cond: bool, msg: String) -> void:
	print("ROW %s %s" % ["PASS" if cond else "FAIL", msg])
	if not cond:
		fails.append(msg)


func _setup() -> void:
	GameState.new_game("布局", "灰旗", GameState.crest_color)
	if GameState.has_meta("city_id"):
		GameState.remove_meta("city_id")
	if GameState.has_meta("city_tab"):
		GameState.remove_meta("city_tab")
	World.events_enabled = false
	World.rivals_enabled = false
	World.hub_tour.clear()
	World.travel = {}
	World.pending_event = {}
	World.encounter = {}


func _mount(packed: PackedScene) -> Node:
	var node := packed.instantiate()
	if node is Control:
		var page := node as Control
		page.set_anchors_preset(Control.PRESET_TOP_LEFT)
		page.position = Vector2.ZERO
		page.size = Vector2(1280, 720)
	add_child(node)
	await get_tree().process_frame
	await get_tree().process_frame
	return node


func _check_atlas(where: String) -> void:
	var page := await _mount(ATLAS)
	var lore := _find_text(page, "议事厅" if where == "hq" else "浇筑")
	_ok(lore != null, "atlas %s lore" % where)
	if where == "hq":
		var trade_btn := _find_button(page, "去市集贩运")
		_ok(trade_btn != null, "atlas hq trade button")
		if trade_btn != null and lore != null:
			_ok(_below(trade_btn, lore), "atlas hq lore sits under 去市集贩运")
			_ok(not _hits(trade_btn, lore), "atlas hq 去市集贩运 overlaps lore")
	else:
		var quote := _find_text(page, "铁料")
		_ok(quote != null, "atlas capital iron quote")
		if quote != null and lore != null:
			_ok(_below(quote, lore), "atlas capital lore sits under iron quote")
			_ok(not _hits(quote, lore), "atlas capital quote overlaps lore")
		var glyph := _find_exact(page, "都")
		var star := _nearest(page, glyph, "★")
		_ok(glyph != null and star != null, "atlas capital 都 and ★")
		if glyph != null and star != null:
			_ok(not _hits(glyph, star), "atlas capital 都 overlaps ★")
			var flag := _find_exact(page, "旗")
			if flag != null:
				_ok(not _hits(star, flag), "atlas capital ★ overlaps party token")
	for lab in _texts(page):
		if lab is Label and str(lab.text).contains("本地买"):
			_ok(_text_fits(lab as Label), "atlas %s quote fits: %s" % [where, str(lab.text).left(24)])
	page.queue_free()
	await get_tree().process_frame


func _check_city(where: String) -> void:
	var page := await _mount(CITY)
	var vp := get_viewport().get_visible_rect()
	var affair := page.find_child("AffairBtn", true, false) as Button
	_ok(affair != null, "city %s AffairBtn" % where)
	if affair != null:
		_ok(_inside(affair, vp), "city %s AffairBtn inside viewport %s" % [where, affair.get_global_rect()])
		var foot := _find_text(page, "SETTLEMENT")
		if foot != null:
			_ok(not _hits(affair, foot), "city %s AffairBtn overlaps footer")
	if where == "ash_capital":
		var main := page.find_child("MainlineBtn", true, false) as Button
		_ok(main != null, "city capital mainline button")
		if main != null:
			_ok(_inside(main, vp), "city capital mainline inside viewport %s" % main.get_global_rect())
			var foot2 := _find_text(page, "SETTLEMENT")
			if foot2 != null:
				_ok(not _hits(main, foot2), "city capital mainline overlaps footer")
	page.queue_free()
	await get_tree().process_frame


func _check_market() -> void:
	var page := await _mount(CITY)
	var loop := _find_text(page, "PRODUCE LOOP")
	_ok(loop != null, "market PRODUCE LOOP")
	var title: Label = null
	for c in _texts(page):
		if c is Label and str(c.text) == "市集":
			title = c
			break
	_ok(title != null, "market title label")
	if title != null and loop != null:
		var gap := loop.get_global_rect().position.y - title.get_global_rect().end.y
		_ok(gap >= 8.0 and not _hits(title, loop), "market 市集 clears PRODUCE LOOP (gap %.0f)" % gap)
	page.queue_free()
	await get_tree().process_frame


func _check_marriage() -> void:
	var page := await _mount(MARRIAGE)
	var cast := page.find_child("CombatForecast", true, false) as Label
	_ok(cast != null, "marriage CombatForecast")
	if cast != null:
		var fs := cast.get_theme_font_size("font_size")
		_ok(fs >= FONT_FLOOR, "marriage forecast font %d >= %d" % [fs, FONT_FLOOR])
		_ok(_text_fits(cast), "marriage forecast box holds the line (h=%.0f)" % cast.size.y)
		_ok(_inside(cast, get_viewport().get_visible_rect()), "marriage forecast inside viewport")
	page.queue_free()
	await get_tree().process_frame


func _texts(root: Node) -> Array:
	var out: Array = []
	_walk(root, out)
	return out


func _walk(n: Node, out: Array) -> void:
	if n is Label or n is Button:
		var c := n as Control
		if c.is_visible_in_tree() and c.size.x > 1.0 and c.size.y > 1.0 and str(c.get("text")).strip_edges() != "":
			out.append(c)
	for ch in n.get_children():
		_walk(ch, out)


func _find_text(root: Node, needle: String) -> Control:
	for c in _texts(root):
		if str(c.get("text")).contains(needle):
			return c
	return null


func _find_exact(root: Node, text: String) -> Control:
	for c in _texts(root):
		if str(c.get("text")) == text:
			return c
	return null


func _find_button(root: Node, text: String) -> Button:
	for c in _texts(root):
		if c is Button and str(c.text) == text:
			return c
	return null


func _nearest(root: Node, anchor: Control, text: String) -> Control:
	if anchor == null:
		return null
	var best: Control = null
	var best_d := 100000.0
	var origin := anchor.get_global_rect().get_center()
	for c in _texts(root):
		if str(c.get("text")) != text:
			continue
		var d: float = c.get_global_rect().get_center().distance_to(origin)
		if d < best_d:
			best_d = d
			best = c
	return best


func _below(upper: Control, lower: Control) -> bool:
	return lower.get_global_rect().position.y + 1.0 >= upper.get_global_rect().end.y


func _inside(c: Control, vp: Rect2) -> bool:
	var r := c.get_global_rect()
	return r.position.x >= -2.0 and r.position.y >= -2.0 and r.end.x <= vp.size.x + 2.0 and r.end.y <= vp.size.y + 2.0


func _ink(c: Control) -> Rect2:
	var r := c.get_global_rect()
	if c is Label:
		var lines := str(c.text).count("\n") + 1
		var ink := minf(r.size.y, float(c.get_theme_font_size("font_size")) * 1.4 * float(lines))
		return Rect2(r.position.x, r.position.y + (r.size.y - ink) * 0.5, r.size.x, ink)
	return r


func _hits(a: Control, b: Control) -> bool:
	if a == null or b == null or a == b:
		return false
	var pa := str(a.get_path())
	var pb := str(b.get_path())
	if pa.begins_with(pb) or pb.begins_with(pa):
		return false
	var ra := _ink(a)
	var rb := _ink(b)
	var ix := minf(ra.end.x, rb.end.x) - maxf(ra.position.x, rb.position.x)
	var iy := minf(ra.end.y, rb.end.y) - maxf(ra.position.y, rb.position.y)
	return ix > 4.0 and iy > 4.0


func _text_fits(l: Label) -> bool:
	var f: Font = l.get_theme_font("font")
	if f == null:
		return false
	var fs := l.get_theme_font_size("font_size")
	var width := maxf(l.size.x, l.custom_minimum_size.x)
	if width < 8.0:
		return false
	if l.autowrap_mode == TextServer.AUTOWRAP_OFF and l.text_overrun_behavior == TextServer.OVERRUN_NO_TRIMMING:
		var need := f.get_string_size(l.text.split("\n")[0], HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		return need <= width + 4.0
	var need_h := f.get_multiline_string_size(l.text, HORIZONTAL_ALIGNMENT_LEFT, width, fs).y
	var box_h := maxf(l.size.y, l.get_combined_minimum_size().y)
	return box_h + 1.0 >= need_h
