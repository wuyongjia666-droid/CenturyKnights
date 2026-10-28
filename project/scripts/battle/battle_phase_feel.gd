class_name BattlePhaseFeel
extends RefCounted
## Y1-A T-P6 + BoardInset fat: enemy-turn readability + attack settle juice
## + phase/end banners clamped into the shared BoardInset (notch + info + edge)
## — same rect as range keep / confirm / action settle. Pure readable helpers
## stay for algebra suites. Kept out of battle_controller (line gate). Overlay
## draw only — never steals input; player input stays gated on turn_team.

## Longer than the old 0.9s flash so the phase band stays readable on phone landscape.
const TURN_FLASH_SEC := 1.15
const SETTLE_FLASH_MSEC := 420
const ENEMY_ACTOR_MSEC := 700


## Pure: banner type size — mobile landscape needs a larger band.
static func banner_font_px(mobile: bool, landscape: bool) -> int:
	if mobile and landscape:
		return 30
	if mobile:
		return 28
	return 26


## Pure: band height in px.
static func banner_band_h(mobile: bool, landscape: bool) -> float:
	if mobile and landscape:
		return 78.0
	if mobile:
		return 72.0
	return 68.0


## Pure: stage-space band (suite / layout). Overlay draw uses banner_rect_local.
static func banner_rect(stage: Rect2, origin: Vector2, map_px: Vector2, mobile: bool, landscape: bool) -> Rect2:
	var h: float = banner_band_h(mobile, landscape)
	var use_stage: bool = stage.size.x > 64.0 and stage.size.y > 64.0
	if use_stage:
		var y: float = stage.position.y + stage.size.y * 0.42 - h * 0.5
		return Rect2(stage.position.x + 8.0, y, maxf(80.0, stage.size.x - 16.0), h)
	var mid := origin + map_px * 0.5
	return Rect2(origin.x, mid.y - h * 0.5, map_px.x, h)


## Pure: board-local rect so the band stays near stage mid under pan/zoom.
static func banner_rect_local(stage: Rect2, pan: Vector2, zoom: float, mobile: bool, landscape: bool) -> Rect2:
	var z: float = zoom if zoom > 0.001 else 1.0
	var h_s: float = banner_band_h(mobile, landscape)
	var use_stage: bool = stage.size.x > 64.0 and stage.size.y > 64.0
	if not use_stage:
		return Rect2(0.0, 0.0, 200.0, h_s / z)
	var mid_p: Vector2 = stage.position + stage.size * 0.5
	var mid_l: Vector2 = (mid_p - pan) / z
	var w_l: float = maxf(80.0 / z, (stage.size.x - 16.0) / z)
	var h_l: float = h_s / z
	return Rect2(mid_l.x - w_l * 0.5, mid_l.y - h_l * 0.5, w_l, h_l)


## Place a phase/end band inside a precomputed readable inset.
static func banner_rect_in_inset(inset: Rect2, stage: Rect2, mobile: bool, landscape: bool) -> Rect2:
	var h: float = banner_band_h(mobile, landscape)
	if inset.size.x < 72.0 or inset.size.y < h + 8.0:
		return banner_rect(stage, Vector2.ZERO, stage.size, mobile, landscape)
	var y: float = inset.position.y + inset.size.y * 0.42 - h * 0.5
	y = clampf(y, inset.position.y + 4.0, maxf(inset.position.y + 4.0, inset.end.y - h - 4.0))
	var x: float = inset.position.x + 8.0
	var w: float = maxf(80.0, inset.size.x - 16.0)
	return Rect2(x, y, w, h)


## Stage-space phase/end band clamped into a pure readable inset (info + edge).
## Algebra suites without a live host use this; runtime draw goes through
## `banner_rect_for_host` so the notch lip matches BoardInset / confirm settle.
static func banner_rect_readable(
	stage: Rect2, blockers: Array, edge_band: float, mobile: bool, landscape: bool
) -> Rect2:
	var inset: Rect2 = BattleActionSettle.readable_inset(stage, blockers, edge_band)
	return banner_rect_in_inset(inset, stage, mobile, landscape)


## Live host path: same BoardInset as range keep / confirm / action settle.
static func banner_rect_for_host(host, mobile: bool, landscape: bool) -> Rect2:
	var stage: Rect2 = BattlePick._stage_rect(host)
	if stage.size.x < 8.0:
		stage = host.get_meta("m_board_area", host.BOARD_AREA) if host.has_meta("m_board_area") else host.BOARD_AREA
	var inset := BattleBoardInset.for_host(host, 0.0)
	return banner_rect_in_inset(inset, stage, mobile, landscape)


## Board-local band whose stage projection sits inside the readable inset.
static func banner_rect_local_readable(
	stage: Rect2, pan: Vector2, zoom: float, blockers: Array, edge_band: float,
	mobile: bool, landscape: bool
) -> Rect2:
	var z: float = zoom if zoom > 0.001 else 1.0
	var band_s: Rect2 = banner_rect_readable(stage, blockers, edge_band, mobile, landscape)
	var pos_l: Vector2 = (band_s.position - pan) / z
	var size_l: Vector2 = band_s.size / z
	return Rect2(pos_l, size_l)


## True when a stage-space band stays clear of every info/notch blocker.
static func banner_clear_of_info(band: Rect2, blockers: Array) -> bool:
	if band.size.x < 1.0 or band.size.y < 1.0:
		return false
	for b in blockers:
		if b is Rect2 and (b as Rect2).size.x > 1.0 and band.intersects(b):
			return false
	return true


static func _host_blockers(host) -> Array:
	var blockers: Array = []
	if host != null and host.has_meta("m_info_block"):
		var block = host.get_meta("m_info_block")
		if block is Rect2 and (block as Rect2).size.x > 1.0:
			blockers.append(block)
	return blockers


static func _host_edge_band(host) -> float:
	if host != null and host.has_meta("m_edge_band"):
		return float(host.get_meta("m_edge_band"))
	return 0.0


## Pure: settle trauma nudge by outcome kind.
static func settle_shake(kind: String) -> float:
	match kind:
		"kill":
			return 0.85
		"crit":
			return 0.70
		"hit":
			return 0.45
		"miss":
			return 0.22
		_:
			return 0.30


## Pure: float-label key for settle kind (Locale.t in draw / host._log).
static func settle_locale_key(kind: String) -> String:
	match kind:
		"kill":
			return "ux_settle_kill"
		"crit":
			return "ux_settle_crit"
		"miss":
			return "ux_settle_miss"
		_:
			return "ux_settle_hit"


## Phase switch: longer flash, stamp team, drop enemy-actor chrome, soft-focus lead.
static func note_phase_switch(host, team: String) -> void:
	host._turn_flash = TURN_FLASH_SEC
	host.set_meta("m_phase_team", team)
	host.set_meta("m_phase_msec", Time.get_ticks_msec())
	if host.has_meta("m_enemy_actor_cell"):
		host.remove_meta("m_enemy_actor_cell")
	if host.has_meta("m_enemy_actor_msec"):
		host.remove_meta("m_enemy_actor_msec")
	# Don't fight T-P5 select burst on player re-entry — clear stale select lock only
	# when entering enemy phase (player input is gated anyway).
	if team == "enemy" and host.has_meta("m_select_burst_msec"):
		host.remove_meta("m_select_burst_msec")
	focus_phase_lead(host, team)
	_refresh_phase_chrome(host, team)


static func _refresh_phase_chrome(host, team: String) -> void:
	var enemy: bool = team == "enemy"
	if host.get("phase_label") != null:
		host.phase_label.add_theme_color_override("font_color", UIKit.DANGER if enemy else UIKit.TEXT)
	if host.get("_phase_chip") != null:
		host._phase_chip.text = "PHASE 02" if enemy else "PHASE 01"
		host._phase_chip.add_theme_color_override("font_color", UIKit.DANGER if enemy else UIKit.ACCENT)
		# T-P6: keep chip visible on mobile landscape so the phase reads without the board flash alone.
		if DeviceProfile.is_mobile() and host.has_method("_mobile_landscape") and bool(host._mobile_landscape()):
			host._phase_chip.visible = true


## Soft-focus first living unit of the new phase (desktop+mobile via force focus).
static func focus_phase_lead(host, team: String) -> void:
	if host.units == null:
		return
	for u in host.units:
		if str(u.team) == team and int(u.char.hp) > 0:
			focus_actor(host, u.pos, team == "enemy")
			return


## Camera follow current actor. `mark_enemy` stamps the acting-enemy ring.
## Desktop force-pan only for enemy follow — player phase lead must not move
## `_board_pan` (tactics/full_chain e2e + desktop default framing).
static func focus_actor(host, cell: Vector2i, mark_enemy: bool = true) -> void:
	if mark_enemy:
		host.set_meta("m_enemy_actor_cell", cell)
		host.set_meta("m_enemy_actor_msec", Time.get_ticks_msec())
	BattlePick.focus_cell(host, cell, true, mark_enemy)
	# Mobile: keep the lead body inside the readable inset (info + notch).
	if DeviceProfile.is_mobile():
		BattleActionSettle.apply(host, cell, [])


static func note_enemy_acting(host, unit_idx: int) -> void:
	if unit_idx < 0 or unit_idx >= host.units.size():
		return
	var u = host.units[unit_idx]
	if int(u.char.hp) <= 0:
		return
	focus_actor(host, u.pos, true)


## Attack confirm → hit/miss/kill settle stamp (player + enemy strikes).
static func note_attack_settle(host, kind: String, cell: Vector2i) -> void:
	host.set_meta("m_settle_flash", {"kind": kind, "cell": cell, "msec": Time.get_ticks_msec()})
	host._shake = maxf(float(host._shake), settle_shake(kind))


static func settle_kind_from_result(hit: bool, crit: bool, killed: bool) -> String:
	if not hit:
		return "miss"
	if killed:
		return "kill"
	if crit:
		return "crit"
	return "hit"


static func settle_alpha(host, now_msec: int = -1) -> float:
	if not host.has_meta("m_settle_flash"):
		return 0.0
	var flash: Dictionary = host.get_meta("m_settle_flash")
	var t0: int = int(flash.get("msec", 0))
	var now: int = Time.get_ticks_msec() if now_msec < 0 else now_msec
	var u: float = float(now - t0) / float(SETTLE_FLASH_MSEC)
	if u < 0.0 or u >= 1.0:
		return 0.0
	return 1.0 - u


static func enemy_actor_alpha(host, now_msec: int = -1) -> float:
	if not host.has_meta("m_enemy_actor_msec"):
		return 0.0
	var t0: int = int(host.get_meta("m_enemy_actor_msec"))
	var now: int = Time.get_ticks_msec() if now_msec < 0 else now_msec
	var u: float = float(now - t0) / float(ENEMY_ACTOR_MSEC)
	if u < 0.0 or u >= 1.0:
		return 0.0
	return 1.0 - u


static func draw_turn_banner(host, overlay) -> void:
	if overlay == null or float(host._turn_flash) <= 0.0:
		return
	var a2: float = clampf(float(host._turn_flash) / TURN_FLASH_SEC, 0.0, 1.0)
	var team: String = str(host.turn_team)
	var txt: String = Locale.t("shell_turn_player") if team == "player" else Locale.t("shell_turn_enemy")
	var mobile: bool = DeviceProfile.is_mobile()
	var land: bool = mobile and host.has_method("_mobile_landscape") and bool(host._mobile_landscape())
	var stage: Rect2 = host.get_meta("m_board_area", host.BOARD_AREA) if host.has_meta("m_board_area") else host.BOARD_AREA
	var z: float = float(host._board_zoom) if float(host._board_zoom) > 0.001 else 1.0
	var band_s: Rect2 = banner_rect_for_host(host, mobile, land)
	var band := Rect2((band_s.position - host._board_pan) / z, band_s.size / z)
	var bandc: Color = UIKit.ACCENT if team == "player" else UIKit.DANGER
	overlay.draw_rect(band, Color(0.03, 0.04, 0.06, 0.78 * a2))
	var edge: float = maxf(1.0, 2.0 / z)
	overlay.draw_rect(Rect2(band.position, Vector2(band.size.x, edge)), Color(bandc, 0.75 * a2))
	overlay.draw_rect(Rect2(band.position + Vector2(0.0, band.size.y - edge), Vector2(band.size.x, edge)), Color(bandc, 0.75 * a2))
	var tfi: int = mini(5, int((TURN_FLASH_SEC - float(host._turn_flash)) / 0.18))
	var tfp := "res://assets/art/fx/turn_flash_dense_%d.png" % tfi
	if not ResourceLoader.exists(tfp):
		tfp = "res://assets/art/fx/turn_flash_%d.png" % tfi
	var bc: Vector2 = band.position + band.size * 0.5
	if ResourceLoader.exists(tfp):
		var ts: float = 96.0 / z
		overlay.draw_texture_rect(host._tex(tfp), Rect2(bc - Vector2(ts, ts) * 0.5 - Vector2(54.0 / z, 0), Vector2(ts, ts)), false, Color(1, 1, 1, a2 * 0.9))
	var font_px: int = maxi(14, int(round(float(banner_font_px(mobile, land)) / z)))
	var tf := UIKit.font("regular")
	var tsz := tf.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, font_px)
	overlay.draw_string(tf, bc + Vector2(-tsz.x * 0.5, font_px * 0.35), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, font_px, Color(UIKit.TEXT, a2))


static func draw_enemy_actor_ring(host, overlay) -> void:
	var a: float = enemy_actor_alpha(host)
	if a <= 0.0 or overlay == null or not host.has_meta("m_enemy_actor_cell"):
		return
	var cell: Vector2i = host.get_meta("m_enemy_actor_cell")
	var c: Vector2 = host.ORIGIN + Vector2(cell) * float(host.CELL) + Vector2(float(host.CELL), float(host.CELL)) * 0.5
	var r: float = float(host.CELL) * (0.48 + 0.06 * a)
	overlay.draw_circle(c, r, Color(UIKit.DANGER, 0.16 * a))
	overlay.draw_arc(c, r, 0.0, TAU, 40, Color(UIKit.DANGER, 0.95 * a), 3.0)


static func draw_settle_flash(host, overlay) -> void:
	var a: float = settle_alpha(host)
	if a <= 0.0 or overlay == null or not host.has_meta("m_settle_flash"):
		return
	var flash: Dictionary = host.get_meta("m_settle_flash")
	var cell: Vector2i = flash.get("cell", Vector2i(-1, -1))
	if cell.x < 0:
		return
	var kind: String = str(flash.get("kind", "hit"))
	var c: Vector2 = host.ORIGIN + Vector2(cell) * float(host.CELL) + Vector2(float(host.CELL), float(host.CELL)) * 0.5
	var col: Color = UIKit.DANGER
	if kind == "miss":
		col = Color(0.7, 0.75, 0.85)
	elif kind == "kill" or kind == "crit":
		col = Color(1.0, 0.85, 0.35)
	var r: float = float(host.CELL) * (0.42 + 0.10 * a)
	overlay.draw_circle(c, r, Color(col, 0.22 * a))
	overlay.draw_arc(c, r, 0.0, TAU, 36, Color(col, 0.95 * a), 3.5 * a + 1.0)
	var rect := Rect2(host.ORIGIN + Vector2(cell) * float(host.CELL), Vector2(float(host.CELL) - 2.0, float(host.CELL) - 2.0))
	overlay.draw_rect(rect, Color(col, 0.18 * a))
	overlay.draw_rect(rect, Color(col, 0.85 * a), false, 2.5)


## ---- Y1-A T-P9: battle-end win/lose banner + crest pulse ----
const END_FLASH_SEC := 1.65
const END_FLASH_MSEC := 1650


## Pure: locale key for end banner.
static func end_locale_key(win: bool) -> String:
	return "battle_win" if win else "battle_lose"


## Pure: crest modulate for winner/loser side during end flash.
## side: "player" | "enemy". Winner stays bright; loser dims.
static func crest_modulate_for_end(win: bool, side: String, alpha: float = 1.0) -> Color:
	var a: float = clampf(alpha, 0.0, 1.0)
	var player_won: bool = win
	var is_player: bool = side == "player"
	var winner: bool = (player_won and is_player) or (not player_won and not is_player)
	if winner:
		# Gold lift on winner crest
		return Color(1.0, 0.92 + 0.08 * a, 0.55 + 0.20 * a, 1.0)
	# Loser crest dims toward gray
	var g: float = 0.45 + 0.20 * (1.0 - a)
	return Color(g, g, g * 1.05, 0.55 + 0.25 * (1.0 - a))


## Stamp end flash; clear settle/enemy actor chrome so the banner owns the stage.
## FeelCloseout then drops whole-chain feel stamps / peeks under the banner.
static func note_battle_end(host, win: bool) -> void:
	host.set_meta("m_end_flash", {"win": win, "msec": Time.get_ticks_msec()})
	host._turn_flash = maxf(float(host._turn_flash), END_FLASH_SEC * 0.35)
	host._shake = maxf(float(host._shake), 0.55 if win else 0.40)
	if host.has_meta("m_settle_flash"):
		host.remove_meta("m_settle_flash")
	if host.has_meta("m_enemy_actor_cell"):
		host.remove_meta("m_enemy_actor_cell")
	if host.has_meta("m_enemy_actor_msec"):
		host.remove_meta("m_enemy_actor_msec")
	apply_end_crest_pulse(host, win)
	BattleFeelCloseout.after_battle_end(host, win)


static func end_alpha(host, now_msec: int = -1) -> float:
	if not host.has_meta("m_end_flash"):
		return 0.0
	var flash: Dictionary = host.get_meta("m_end_flash")
	var t0: int = int(flash.get("msec", 0))
	var now: int = Time.get_ticks_msec() if now_msec < 0 else now_msec
	var u: float = float(now - t0) / float(END_FLASH_MSEC)
	if u < 0.0 or u >= 1.0:
		return 0.0
	# Hold bright then ease out
	if u < 0.35:
		return 1.0
	return 1.0 - ((u - 0.35) / 0.65)


static func draw_end_banner(host, overlay) -> void:
	var a: float = end_alpha(host)
	if a <= 0.0 or overlay == null or not host.has_meta("m_end_flash"):
		return
	var flash: Dictionary = host.get_meta("m_end_flash")
	var win: bool = bool(flash.get("win", false))
	var txt: String = Locale.t(end_locale_key(win))
	if win:
		txt = "★ " + txt + " ★"
	var mobile: bool = DeviceProfile.is_mobile()
	var land: bool = mobile and host.has_method("_mobile_landscape") and bool(host._mobile_landscape())
	var stage: Rect2 = host.get_meta("m_board_area", host.BOARD_AREA) if host.has_meta("m_board_area") else host.BOARD_AREA
	var z: float = float(host._board_zoom) if float(host._board_zoom) > 0.001 else 1.0
	var band_s: Rect2 = banner_rect_for_host(host, mobile, land)
	var band := Rect2((band_s.position - host._board_pan) / z, band_s.size / z)
	# Slightly taller end band, still from the readable inset mid.
	band.size.y *= 1.12
	band.position.y -= band.size.y * 0.06
	var bandc: Color = UIKit.ACCENT if win else UIKit.DANGER
	overlay.draw_rect(band, Color(0.02, 0.03, 0.05, 0.82 * a))
	var edge: float = maxf(1.5, 2.5 / z)
	overlay.draw_rect(Rect2(band.position, Vector2(band.size.x, edge)), Color(bandc, 0.90 * a))
	overlay.draw_rect(Rect2(band.position + Vector2(0.0, band.size.y - edge), Vector2(band.size.x, edge)), Color(bandc, 0.90 * a))
	# Soft fill pulse
	overlay.draw_rect(
		Rect2(band.position + Vector2(0.0, edge), Vector2(band.size.x, band.size.y - edge * 2.0)),
		Color(bandc, 0.10 * a)
	)
	var bc: Vector2 = band.position + band.size * 0.5
	var font_px: int = maxi(16, int(round(float(banner_font_px(mobile, land) + 2) / z)))
	var tf := UIKit.font("regular")
	var tsz := tf.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, font_px)
	overlay.draw_string(tf, bc + Vector2(-tsz.x * 0.5, font_px * 0.35), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, font_px, Color(UIKit.TEXT, a))


## Apply winner lift / loser dim on BattleHudCrestStrip. Lives here (not heraldry_chrome)
## so heraldry hub PRs do not conflict with battle-end feel. Never steals taps.
static func apply_end_crest_pulse(host, win: bool, alpha: float = 1.0) -> void:
	if host == null:
		return
	var strip = host.get_node_or_null("BattleHudCrestStrip")
	if strip == null:
		return
	var a: float = clampf(alpha, 0.05, 1.0)
	var pa = strip.find_child("PlayerArms", true, false)
	var ea = strip.find_child("EnemyArms", true, false)
	if pa != null and pa is CanvasItem:
		(pa as CanvasItem).modulate = crest_modulate_for_end(win, "player", a)
	if ea != null and ea is CanvasItem:
		(ea as CanvasItem).modulate = crest_modulate_for_end(win, "enemy", a)
	strip.set_meta("end_pulse_win", win)
	if strip is Control:
		(strip as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE

