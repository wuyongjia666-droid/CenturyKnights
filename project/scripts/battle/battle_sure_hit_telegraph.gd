class_name BattleSureHitTelegraph
extends RefCounted
## Y1-A T-P33: when aimed strike hit chance is near-certain, telegraph
## confidence on the defender so a locked shot is readable before confirm.

const META := "m_sure_hit_telegraph"
const LINE_W := 2.5
const FILL_A := 0.15
const SURE_HIT := 95  ## inclusive: hit% >= this is locked


static func active(host) -> bool:
	if host == null:
		return false
	if str(host.get("turn_team")) != "player" or bool(host.get("battle_over")):
		return false
	if not bool(host.get("attack_mode")):
		return false
	var ui := int(host.get("selected"))
	var units = host.get("units")
	if units == null or ui < 0 or ui >= units.size():
		return false
	var u = units[ui]
	if str(u.team) != "player" or bool(u.done) or int(u.char.hp) <= 0:
		return false
	var foe_i := int(host.get("preview_attack_ui"))
	if foe_i < 0 or foe_i >= units.size():
		return false
	var foe = units[foe_i]
	if str(foe.team) != "enemy" or int(foe.char.hp) <= 0:
		return false
	return true


static func hit_chance(host) -> int:
	if not active(host):
		return 0
	var ai := int(host.selected)
	var di := int(host.preview_attack_ui)
	var atk = host.units[ai]
	var def = host.units[di]
	var tid := "plain"
	if host.terrain != null and def.pos.y < host.terrain.size() and def.pos.x < host.terrain[def.pos.y].size():
		tid = str(host.terrain[def.pos.y][def.pos.x])
	var extras := {}
	if host.has_method("_combat_extras"):
		extras = host._combat_extras(ai, di)
	var pv: Dictionary = BattleRules.preview(atk.char, def.char, tid, extras)
	return int(pv.hit)


static func will_sure(host) -> bool:
	if not active(host):
		return false
	return hit_chance(host) >= SURE_HIT


static func clear(host) -> void:
	if host != null and host.has_meta(META):
		host.remove_meta(META)


static func refresh(host) -> bool:
	if host == null:
		return false
	if not will_sure(host):
		clear(host)
		if host.overlay:
			host.overlay.queue_redraw()
		return false
	var ai := int(host.selected)
	var di := int(host.preview_attack_ui)
	var prev := -1
	if host.has_meta(META):
		prev = int(host.get_meta(META).get("foe", -1))
	var chance := hit_chance(host)
	host.set_meta(META, {
		"foe": di,
		"stand": host.units[ai].pos,
		"foe_pos": host.units[di].pos,
		"hit": chance,
		"msec": Time.get_ticks_msec(),
	})
	if prev != di:
		BattleCombatFrame.follow_cells(
			host,
			[host.units[ai].pos, host.units[di].pos],
			BattleCombatFrame.forecast_band(DeviceProfile.is_mobile())
		)
	if host.overlay:
		host.overlay.queue_redraw()
	return true


static func draw(host, overlay) -> void:
	if overlay == null or host == null:
		return
	if not will_sure(host):
		return
	var di := int(host.preview_attack_ui)
	var origin: Vector2 = host.ORIGIN
	var cell_px := float(host.CELL)
	var pulse := 0.72 + 0.28 * sin(float(host.get("_sel_pulse")) * 5.5)
	var half_w: float = BattlePick.contour_half_w()
	var tone := Color(0.55, 0.92, 0.72)  # cool sure-hit mint
	var marks := BattleSelectChrome.chrome_marks(origin, cell_px, host.units[di].pos, half_w, 1.0)
	var body: Rect2 = marks.body
	overlay.draw_rect(body, Color(tone, FILL_A * pulse))
	# Solid confident ring (vs dashed risk).
	overlay.draw_arc(marks.mid, float(marks.mid_r) * 1.22, 0.0, TAU, 28, Color(tone, 0.92 * pulse), LINE_W)
	# Inner tick marks at cardinals — locked sight.
	var mid: Vector2 = marks.mid
	var r := float(marks.mid_r) * 1.22
	for ang in [0.0, PI * 0.5, PI, PI * 1.5]:
		var outer: Vector2 = mid + Vector2(cos(ang), sin(ang)) * r
		var inner: Vector2 = mid + Vector2(cos(ang), sin(ang)) * (r * 0.72)
		overlay.draw_line(inner, outer, Color(tone, 0.95 * pulse), LINE_W * 0.9)
	var chance := hit_chance(host)
	var label := "%s %d%%" % [Locale.t("shell_sure_hit_mark"), chance]
	var label_pos: Vector2 = mid + Vector2(-22.0, -float(marks.mid_r) - 14.0)
	overlay.draw_string(
		UIKit.font("mono"),
		label_pos,
		label,
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		11,
		Color(tone, 0.98 * pulse)
	)
