class_name BattleRematchJuice
extends RefCounted
## 战棋命中手感 + 再战闭环：加深 settle trauma / 真时 hit-stop / 单位 pop，胜负报告一键再战或回堡。
## 加深 #728/#717 PhaseFeel settle 与 #729 触控契约，不重写绿野；禁 telegraph / EmptyHost / 碎刀。

const META_HIT := "m_hit_juice"
const META_REMATCH := "m_rematch_cta"
const META_ROUND := "battle_rematch_round"
const POP_MSEC := 180


## Hit-stop weight keyed off settle kind.
static func hit_weight(kind: String) -> String:
	match kind:
		"kill":
			return "heavy"
		"crit":
			return "mid"
		"miss":
			return "light"
		_:
			return "mid"


## Punchier trauma than PhaseFeel.settle_shake alone (visual offset on host).
static func trauma_nudge(kind: String) -> float:
	match kind:
		"kill":
			return 1.15
		"crit":
			return 0.95
		"hit":
			return 0.72
		"miss":
			return 0.28
		_:
			return 0.50


## Rematch when not world-enc and not chapter-owned mid-cs (season CTA owns morph).
static func offers_rematch(host, _win: bool = true) -> bool:
	if host == null:
		return false
	if bool(host.get("_world_enc")):
		return false
	if str(GameState.get_meta("battle_return_chapter", "")) != "":
		return false
	return true


static func rematch_locale_key() -> String:
	return "battle_rematch_again"


static func hub_locale_key() -> String:
	return "battle_return_hub"


## After PhaseFeel.note_attack_settle: deepen shake, kick hit-stop, stamp juice meta.
## Layers within ~100ms: trauma camera offset + settle flash (PhaseFeel) + dmg numeral + unit pop + hit-stop.
## A miss in the same exchange must not clobber a fresh hit/crit/kill pop (counters / follow-ups).
static func after_attack_hit(host, kind: String, cell: Vector2i) -> void:
	if host == null:
		return
	host._shake = maxf(float(host._shake), trauma_nudge(kind))
	var stamp := true
	if kind == "miss" and host.has_meta(META_HIT):
		var prev: Dictionary = host.get_meta(META_HIT)
		var prev_kind := str(prev.get("kind", ""))
		var age := Time.get_ticks_msec() - int(prev.get("msec", 0))
		if prev_kind in ["hit", "crit", "kill"] and age >= 0 and age < POP_MSEC:
			stamp = false
	if stamp:
		host.set_meta(
			META_HIT,
			{
				"kind": kind,
				"cell": cell,
				"msec": Time.get_ticks_msec(),
				"weight": hit_weight(kind),
			}
		)
	kick_hit_stop(host, kind)
	if DeviceProfile.is_mobile() and kind != "miss":
		UIFX.haptic(30 if kind == "kill" or kind == "crit" else 18)
	_redraw(host)


static func kick_hit_stop(host, kind: String) -> void:
	if host == null:
		return
	if GameState != null and bool(GameState.settings.get("reduced_motion", false)):
		return
	if Engine.time_scale < 0.99:
		return
	if not host.has_method("get_tree"):
		return
	var tree: SceneTree = host.get_tree()
	if tree == null:
		return
	var weight := hit_weight(kind)
	Engine.time_scale = CutsceneVfx.time_scale_for(weight)
	var dur := CutsceneVfx.hit_stop_seconds(weight)
	var t: SceneTreeTimer = tree.create_timer(dur, true, false, true)
	t.timeout.connect(_restore_time_scale, CONNECT_ONE_SHOT)


static func _restore_time_scale() -> void:
	Engine.time_scale = 1.0


## Overlay unit pop (visual only — never moves logic coords / rigid body).
static func pop_alpha(host, now_msec: int = -1) -> float:
	if host == null or not host.has_meta(META_HIT):
		return 0.0
	var juice: Dictionary = host.get_meta(META_HIT)
	if str(juice.get("kind", "")) == "miss":
		return 0.0
	var t0: int = int(juice.get("msec", 0))
	var now: int = Time.get_ticks_msec() if now_msec < 0 else now_msec
	var u: float = float(now - t0) / float(POP_MSEC)
	if u < 0.0 or u >= 1.0:
		return 0.0
	return 1.0 - u


static func draw_hit_pop(host, overlay) -> void:
	var a: float = pop_alpha(host)
	if a <= 0.0 or overlay == null or not host.has_meta(META_HIT):
		return
	var juice: Dictionary = host.get_meta(META_HIT)
	var cell: Vector2i = juice.get("cell", Vector2i(-1, -1))
	if cell.x < 0:
		return
	var kind: String = str(juice.get("kind", "hit"))
	var origin: Vector2 = host.ORIGIN
	var cell_sz: float = float(host.CELL)
	var c: Vector2 = origin + Vector2(cell) * cell_sz + Vector2(cell_sz, cell_sz) * 0.5
	var col := Color(1.0, 0.85, 0.35) if kind == "kill" or kind == "crit" else UIKit.DANGER
	# Overshoot then settle: r grows then eases — visual pop, not logic transform.
	var ease: float = 1.0 - (1.0 - a) * (1.0 - a)
	var r: float = cell_sz * (0.34 + 0.22 * ease)
	overlay.draw_circle(c, r, Color(col, 0.18 * a))
	overlay.draw_arc(c, r, 0.0, TAU, 40, Color(col, 0.95 * a), 2.5 + 2.0 * a)
	var rect := Rect2(c - Vector2(r, r) * 0.72, Vector2(r, r) * 1.44)
	overlay.draw_rect(rect, Color(col, 0.12 * a))
	overlay.draw_rect(rect, Color(col, 0.75 * a), false, 2.0)


## Rematch win must not double-pay silver / rep / exp.
static func claim_rematch_drill() -> bool:
	if not GameState.has_meta(META_ROUND):
		return false
	var on := bool(GameState.get_meta(META_ROUND))
	GameState.remove_meta(META_ROUND)
	return on


static func do_rematch(host) -> void:
	if host == null:
		return
	host.set_meta(META_REMATCH, {"action": "rematch", "msec": Time.get_ticks_msec()})
	GameState.set_meta(META_ROUND, true)
	# Keep sortie marker so practice rematch stays in the drill lane after first claim.
	if not GameState.has_meta("battle_sortie"):
		GameState.set_meta("battle_sortie", true)
	var tree: SceneTree = host.get_tree()
	if tree != null:
		tree.reload_current_scene()


static func do_hub(host, back_path: String) -> void:
	if host == null:
		return
	host.set_meta(META_REMATCH, {"action": "hub", "msec": Time.get_ticks_msec()})
	var path := back_path
	if path == "":
		path = BattleDefeat.CASTLE
	CKNav.replace(path)


## Desktop A/Esc after report: A rematch, Esc hub (practice rematchable only).
static func handle_result_key(host, event: InputEvent) -> bool:
	if host == null or not bool(host.get("battle_over")):
		return false
	if not offers_rematch(host, true):
		return false
	if not (event is InputEventKey and event.pressed and not event.echo):
		return false
	var key: InputEventKey = event
	if key.keycode == KEY_ESCAPE:
		var back := str(host.get_meta("result_back", BattleDefeat.CASTLE))
		do_hub(host, back)
		return true
	if key.keycode == KEY_A or key.keycode == KEY_ENTER:
		do_rematch(host)
		return true
	return false


static func clear_hit(host) -> void:
	if host != null and host.has_meta(META_HIT):
		host.remove_meta(META_HIT)


static func _redraw(host) -> void:
	var ov = host.get("overlay")
	if ov != null and ov.has_method("queue_redraw"):
		ov.queue_redraw()
