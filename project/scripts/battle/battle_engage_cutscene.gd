class_name BattleEngageCutscene
extends RefCounted
## Y1-A T-P7 + phase/end/notch fat: FE-style 3D engage cutscene hook + board
## engage bridge. Pure record builder (player-right FE sides) + short board
## bridge juice that does not steal input. Mobile settle keeps the attacker
## inside the readable inset. Desktop never force-pans (tactics/full_chain).

const BRIDGE_MSEC := 520


## FE convention: our (player) side stands on the right of the duel stage.
static func fe_sides(atk_team: String) -> Dictionary:
	var a_side := "right" if str(atk_team) == "player" else "left"
	var d_side := "left" if a_side == "right" else "right"
	return {"atk": a_side, "def": d_side}


## Pure: whether a cutscene overlay should run for this display / settings.
static func should_play(display_name: String, cutscenes_meta_on: bool, settings_on: bool) -> bool:
	if str(display_name) == "headless":
		return false
	return bool(cutscenes_meta_on) and bool(settings_on)


## Stamp board bridge (atk↔def line + rings). Mobile soft-focus then settle
## the attacker into the readable inset (info column + notch lip cut out),
## framing the defender only when the attacker still fits.
static func note_engage_bridge(host, atk_cell: Vector2i, def_cell: Vector2i) -> void:
	host.set_meta("m_engage_bridge", {
		"atk": atk_cell,
		"def": def_cell,
		"msec": Time.get_ticks_msec(),
	})
	if DeviceProfile.is_mobile():
		var mid := Vector2i(
			int(round(float(atk_cell.x + def_cell.x) * 0.5)),
			int(round(float(atk_cell.y + def_cell.y) * 0.5)),
		)
		BattlePick.focus_cell(host, mid, true, false)
		BattleActionSettle.apply(host, atk_cell, [def_cell])


static func clear_bridge(host) -> void:
	if host.has_meta("m_engage_bridge"):
		host.remove_meta("m_engage_bridge")


static func bridge_alpha(host, now_msec: int = -1) -> float:
	if not host.has_meta("m_engage_bridge"):
		return 0.0
	var flash: Dictionary = host.get_meta("m_engage_bridge")
	var t0: int = int(flash.get("msec", 0))
	var now: int = Time.get_ticks_msec() if now_msec < 0 else now_msec
	var u: float = float(now - t0) / float(BRIDGE_MSEC)
	if u < 0.0 or u >= 1.0:
		return 0.0
	return 1.0 - u


## Build FE duel record from combat_rec rows. Empty rec → {}.
static func build_record(
	host,
	ai: int,
	di: int,
	hp0a: int,
	hp0d: int,
	combat_rec: Array,
	links: Array,
	backdrop: String = "",
	ground: String = "plain",
	grade: Color = Color(0.35, 0.4, 0.32),
	tile: String = "plain",
	title: String = "",
) -> Dictionary:
	if combat_rec.is_empty():
		return {}
	if ai < 0 or di < 0 or ai >= host.units.size() or di >= host.units.size():
		return {}
	var atk = host.units[ai]
	var def = host.units[di]
	var sides: Dictionary = fe_sides(str(atk.team))
	var a_side: String = str(sides["atk"])
	var d_side: String = str(sides["def"])
	var strikes: Array = []
	var fc := {a_side: {}, d_side: {}}
	for r in combat_rec:
		var from: String = a_side if int(r.get("a", -1)) == ai else d_side
		strikes.append({
			"from": from,
			"hit": bool(r.get("hit", false)),
			"crit": bool(r.get("crit", false)),
			"dmg": int(r.get("dmg", 0)),
			"killed": bool(r.get("killed", false)),
			"skill": str(r.get("skill", "")),
			"hp_after": int(r.get("hp_after", 0)),
		})
		if fc[from].is_empty():
			var dmg_v = r.get("dmg", 0) if bool(r.get("hit", false)) else "—"
			fc[from] = {"hit": r.get("hit_chance", "—"), "dmg": dmg_v}
	var ttl: String = title
	if ttl == "":
		ttl = "%s · %s" % [str(host.map_name), tile]
	return {
		a_side: {
			"char": atk.char,
			"team": atk.team,
			"template": str(atk.get("template", "")),
			"hp0": hp0a,
			"hit": fc[a_side].get("hit", "—"),
			"dmg": fc[a_side].get("dmg", "—"),
			"crit": atk.char.derived_crit() if atk.char != null and atk.char.has_method("derived_crit") else 0,
		},
		d_side: {
			"char": def.char,
			"team": def.team,
			"template": str(def.get("template", "")),
			"hp0": hp0d,
			"hit": fc[d_side].get("hit", "—"),
			"dmg": fc[d_side].get("dmg", "—"),
			"crit": def.char.derived_crit() if def.char != null and def.char.has_method("derived_crit") else 0,
		},
		"strikes": strikes,
		"ground": ground,
		"grade": grade,
		"tile": tile,
		"backdrop": backdrop,
		"title": ttl,
		"links": links,
	}


static func draw_engage_bridge(host, overlay: CanvasItem) -> void:
	var a: float = bridge_alpha(host)
	if a <= 0.001:
		return
	var flash: Dictionary = host.get_meta("m_engage_bridge")
	var atk_c: Vector2i = flash.get("atk", Vector2i(-1, -1))
	var def_c: Vector2i = flash.get("def", Vector2i(-1, -1))
	if atk_c.x < 0 or def_c.x < 0:
		return
	var cell: float = float(host.CELL)
	var origin: Vector2 = host.ORIGIN
	var p0: Vector2 = origin + Vector2(atk_c) * cell + Vector2(cell, cell) * 0.5
	var p1: Vector2 = origin + Vector2(def_c) * cell + Vector2(cell, cell) * 0.5
	var col := Color(UIKit.ACCENT.r, UIKit.ACCENT.g, UIKit.ACCENT.b, 0.55 * a)
	var col_e := Color(UIKit.DANGER.r, UIKit.DANGER.g, UIKit.DANGER.b, 0.5 * a)
	overlay.draw_line(p0, p1, Color(1, 1, 1, 0.35 * a), 3.0)
	overlay.draw_line(p0, p1, col, 1.6)
	overlay.draw_circle(p0, cell * 0.22, Color(col.r, col.g, col.b, 0.4 * a))
	overlay.draw_circle(p1, cell * 0.22, Color(col_e.r, col_e.g, col_e.b, 0.4 * a))
