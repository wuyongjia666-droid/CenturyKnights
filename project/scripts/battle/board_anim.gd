class_name CKBoardAnim
extends RefCounted
## Board piece motion on top of CKBoardFigures strips: idle breathe, walk between
## cells, attack lunge+swing toward the target, hit flinch, death fade, facing.

var _st: Dictionary = {}
const DEATH_S := 0.7

static func now() -> float:
	return Time.get_ticks_msec() / 1000.0

func _s(u, center: Vector2) -> Dictionary:
	var id := str(u.char.id)
	if not _st.has(id):
		_st[id] = {"from": center, "to": center, "t0": 0.0, "dur": 0.0, "face": 1.0 if str(u.team) != "enemy" else -1.0,
			"act": "", "act_t": -99.0, "dir": Vector2.ZERO, "dead_t": -1.0}
	return _st[id]

func note_attack(u, target_px: Vector2, from_px: Vector2) -> void:
	var s := _s(u, from_px)
	s.act = "attack"; s.act_t = now(); s.dir = (target_px - from_px).normalized()
	if absf(s.dir.x) > 0.01:
		s.face = signf(s.dir.x)

func note_hit(u, from_dir: Vector2, at_px: Vector2) -> void:
	var s := _s(u, at_px)
	s.act = "hit"; s.act_t = now(); s.dir = from_dir.normalized()
	if absf(from_dir.x) > 0.01:
		s.face = -signf(from_dir.x)

func busy() -> bool:
	var t := now()
	for s in _st.values():
		if t - float(s.t0) < float(s.dur) or t - float(s.act_t) < 0.6 or (float(s.dead_t) > 0.0 and t - float(s.dead_t) < DEATH_S):
			return true
	return false

## Draws the animated piece. Returns its visual centre (for HP bar etc.), or Vector2.INF when
## no figure is ready (caller falls back to the procedural token).
func draw(ci: CanvasItem, figs: CKBoardFigures, u, center: Vector2, r: float, cell: float, done: bool, selected: bool) -> Vector2:
	var tmpl := str(u.get("template", ""))
	if figs == null or figs.figure(u.char, str(u.team), tmpl) == null:
		return Vector2.INF
	var s := _s(u, center)
	var t := now()
	if s.to != center:  # cell changed → walk there
		var cur := _pix(s, t)
		s.from = cur; s.to = center; s.t0 = t
		s.dur = clampf(cur.distance_to(center) / maxf(cell, 1.0) * 0.16, 0.12, 0.7)
		if absf(center.x - cur.x) > 1.0:
			s.face = signf(center.x - cur.x)
	var pos := _pix(s, t)
	var clip := "idle"
	var ct := t
	var once := false
	var off := Vector2.ZERO
	var flash := 0.0
	var since := t - float(s.act_t)
	if s.act == "attack" and since < 0.55:
		clip = "attack"; ct = since; once = true
		off = s.dir * cell * 0.22 * sin(clampf(since / 0.55, 0.0, 1.0) * PI)
	elif s.act == "hit" and since < 0.35:
		clip = "hit"; ct = since; once = true
		off = s.dir * cell * 0.08 * sin(clampf(since / 0.35, 0.0, 1.0) * PI)
		flash = 1.0 - since / 0.35
	elif t - float(s.t0) < float(s.dur):
		clip = "advance"; ct = t - float(s.t0)
	pos += off
	_draw_piece(ci, figs.frame(u.char, str(u.team), tmpl, clip, ct, once), pos, r, float(s.face), str(u.team), done, selected, flash, 1.0)
	return pos

## Fading corpse for a unit that just died; false once the fade is over.
func draw_dead(ci: CanvasItem, figs: CKBoardFigures, u, center: Vector2, r: float) -> bool:
	var id := str(u.char.id)
	if figs == null or not _st.has(id):
		return false
	var s: Dictionary = _st[id]
	var t := now()
	if float(s.dead_t) < 0.0:
		s.dead_t = t
	var k := (t - float(s.dead_t)) / DEATH_S
	if k >= 1.0:
		return false
	var tex := figs.frame(u.char, str(u.team), str(u.get("template", "")), "hit", 0.2, true)
	if tex == null:
		return false
	_draw_piece(ci, tex, _pix(s, t) + Vector2(0, r * 0.25 * k), r, float(s.face), str(u.team), true, false, 0.0, 1.0 - k)
	return true

func _pix(s: Dictionary, t: float) -> Vector2:
	if float(s.dur) <= 0.0:
		return s.to
	var k := clampf((t - float(s.t0)) / float(s.dur), 0.0, 1.0)
	return (s.from as Vector2).lerp(s.to, k)

static func _draw_piece(ci: CanvasItem, tex: Texture2D, center: Vector2, r: float, face: float, team: String, done: bool, selected: bool, flash: float, alpha: float) -> void:
	if tex == null:
		return
	var side := Color(0.36, 0.90, 0.78) if team != "enemy" else Color(0.95, 0.36, 0.32)
	var feet := center + Vector2(0, r * 0.95)
	# soft drop shadow, offset away from the key light
	for i in 3:
		var sp := _ell(feet + Vector2(r * 0.18, r * 0.06), r * (0.9 + 0.18 * i), r * (0.30 + 0.06 * i))
		ci.draw_colored_polygon(sp, Color(0, 0, 0, (0.22 - 0.06 * i) * alpha))
	var base := _ell(feet, r * 0.95, r * 0.34)
	if selected:
		var pulse := 0.5 + 0.5 * sin(now() * 5.0)
		ci.draw_colored_polygon(_ell(feet, r * 1.25, r * 0.48), Color(UIKit.ACCENT, 0.18 + 0.12 * pulse))
		ci.draw_polyline(_ell(feet, r * 1.18, r * 0.44), Color(UIKit.ACCENT, 0.9), maxf(2.0, r * 0.1), true)
	ci.draw_colored_polygon(base, Color(side, (0.28 if not done else 0.12) * alpha))
	ci.draw_polyline(base, Color(side, (0.95 if not done else 0.45) * alpha), maxf(1.5, r * 0.09), true)
	var h := r * (3.9 if selected else 3.7)
	var w := h * float(tex.get_width()) / float(tex.get_height())
	var mod := Color(0.62, 0.62, 0.66) if done else (Color(1.12, 1.12, 1.12) if selected else Color.WHITE)
	if flash > 0.0:
		mod = mod.lerp(Color(2.2, 1.4, 1.3), flash * 0.7)
	mod.a = alpha
	var rect := Rect2(Vector2(center.x - w * 0.5, feet.y - h * 0.97), Vector2(w, h))
	if face < 0.0:  # mirror about the piece's centre line
		ci.draw_set_transform_matrix(Transform2D(Vector2(-1, 0), Vector2(0, 1), Vector2(center.x * 2.0, 0)))
	ci.draw_texture_rect(tex, rect, false, mod)
	if face < 0.0:
		ci.draw_set_transform_matrix(Transform2D.IDENTITY)

static func _ell(c: Vector2, rx: float, ry: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in 29:
		var a := TAU * i / 28.0
		pts.append(c + Vector2(cos(a) * rx, sin(a) * ry))
	return pts
