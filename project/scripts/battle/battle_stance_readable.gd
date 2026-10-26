class_name BattleStanceReadable
extends RefCounted
## Y1-A fat: mid-action stance chip — moved but not yet done.
## Pure overlay draw; never steals InputRouter taps. Overlay draw only.

const CHIP_H := 0.22
const CHIP_PAD_X := 0.08


## True when selected player has moved this select and can still act.
static func moved_open(host) -> bool:
	if host == null:
		return false
	if str(host.get("turn_team")) != "player":
		return false
	if bool(host.get("battle_over")):
		return false
	var sel := int(host.get("selected"))
	var units = host.get("units")
	if units == null or sel < 0 or sel >= units.size():
		return false
	var u = units[sel]
	if typeof(u) != TYPE_DICTIONARY:
		return false
	if str(u.get("team", "")) != "player":
		return false
	if bool(u.get("done", false)):
		return false
	var ch = u.get("char", null)
	var hp := 0
	if typeof(ch) == TYPE_DICTIONARY:
		hp = int(ch.get("hp", 0))
	elif ch != null and "hp" in ch:
		hp = int(ch.hp)
	if hp <= 0:
		return false
	return bool(host.get("moved_this_select"))


static func chip_text() -> String:
	return BattleObjectives.text("stance_moved")


static func draw_moved_chip(host, overlay: CanvasItem) -> void:
	if overlay == null or not moved_open(host):
		return
	var sel := int(host.selected)
	var u = host.units[sel]
	var cell: Vector2i = u.pos
	var origin: Vector2 = host.ORIGIN
	var cell_px := float(host.CELL)
	var pan: Vector2 = host._board_pan if "_board_pan" in host else Vector2.ZERO
	var zoom := float(host._board_zoom) if "_board_zoom" in host else 1.0
	if zoom < 0.001:
		zoom = 1.0
	var cpx := cell_px * zoom
	var top_left := origin * zoom + Vector2(cell) * cpx + pan
	var mid := top_left + Vector2(cpx * 0.5, cpx * ((BattlePick.FIG_TOP + BattlePick.FIG_FEET) * 0.5))
	var label := chip_text()
	var font := ThemeDB.fallback_font
	var font_px := maxi(11, int(round(cpx * 0.22)))
	var tw := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_px).x
	var pad := cpx * CHIP_PAD_X
	var h := cpx * CHIP_H
	var rect := Rect2(mid.x - tw * 0.5 - pad, mid.y - h * 0.5, tw + pad * 2.0, h)
	overlay.draw_rect(rect, Color(0.08, 0.14, 0.22, 0.78), true)
	overlay.draw_rect(rect, Color(UIKit.ACCENT.r, UIKit.ACCENT.g, UIKit.ACCENT.b, 0.90), false, 1.5)
	var baseline := Vector2(rect.position.x + pad, rect.position.y + h * 0.78)
	overlay.draw_string(font, baseline, label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_px, Color(UIKit.ACCENT.r, UIKit.ACCENT.g, UIKit.ACCENT.b, 0.98))
