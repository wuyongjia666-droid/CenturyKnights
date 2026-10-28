class_name BattleEnemyActFeel
extends RefCounted
## 敌方行动整链手感：开场跟焦 → 移动 → 打击 → 单位收尾 → 玩家回场清戳。
##
## 玩家看得见的缝：note_enemy_acting 只 ActionSettle(mover, [])，落子后可打
## 玩家挤出可读区；敌方移动后信息不刷、镜头不跟新格+威胁格；打击后无整链戳；
## 回场后敌方 act 戳残留。本刀收口：每步刷 BoardInset、settle 带威胁格、盖
## enemy_act 戳；回场 / 进敌方清戳。禁瞄准预告碎刀 / telegraph / EmptyHost /
## BoardInset 单点薄切。

const META := "m_enemy_act_feel"


static func stage_of(host) -> String:
	if host == null or not host.has_meta(META):
		return ""
	var info = host.get_meta(META)
	if not (info is Dictionary):
		return ""
	return str((info as Dictionary).get("stage", ""))


static func clear(host) -> void:
	if host != null and host.has_meta(META):
		host.remove_meta(META)


static func _stamp(host, stage: String, extra: Dictionary = {}) -> void:
	if host == null:
		return
	var d: Dictionary = {"stage": stage, "msec": Time.get_ticks_msec()}
	for k in extra.keys():
		d[k] = extra[k]
	host.set_meta(META, d)


static func _redraw(host) -> void:
	var ov = host.get("overlay")
	if ov != null and ov.has_method("queue_redraw"):
		ov.queue_redraw()
	var md = host.get("map_draw")
	if md != null and md.has_method("queue_redraw"):
		md.queue_redraw()


## 敌方单位从 stand 可打到的玩家格（settle also，禁 mover-only）。
static func threat_cells(host, unit_idx: int, stand: Vector2i) -> Array:
	var out: Array = []
	if host == null or unit_idx < 0:
		return out
	var units = host.get("units")
	if units == null or unit_idx >= units.size():
		return out
	var su = units[unit_idx]
	if int(su.char.hp) <= 0:
		return out
	var tid := "plain"
	var height := 0
	if host.has_method("_in_bounds") and host._in_bounds(stand):
		tid = str(host.terrain[stand.y][stand.x])
	if host.has_method("_height_at"):
		height = int(host._height_at(stand))
	for i in units.size():
		var foe = units[i]
		if str(foe.team) != "player" or int(foe.char.hp) <= 0:
			continue
		var d: int = absi(int(foe.pos.x) - stand.x) + absi(int(foe.pos.y) - stand.y)
		if BattleRules.in_weapon_range(su.char, d, tid, height):
			out.append(foe.pos)
	return out


static func _frame(host, actor: Vector2i, also: Array) -> void:
	BattleBoardInset.refresh_info_block(host)
	var cells: Array = [actor]
	for c in also:
		cells.append(c)
	BattleCombatFrame.follow_cells(host, cells, 0.0)
	BattleActionSettle.apply(host, actor, also)


## 敌方单位开场：跟焦环 + settle 带威胁格（盖掉 note_enemy_acting 的 []）。
static func after_act_start(host, unit_idx: int) -> void:
	if host == null:
		return
	BattlePhaseFeel.note_enemy_acting(host, unit_idx)
	var units = host.get("units")
	if units == null or unit_idx < 0 or unit_idx >= units.size():
		return
	var u = units[unit_idx]
	if int(u.char.hp) <= 0:
		return
	var stand: Vector2i = u.pos
	var also: Array = threat_cells(host, unit_idx, stand)
	_frame(host, stand, also)
	_stamp(host, "act", {"ui": unit_idx, "cell": stand, "foes": also.duplicate()})
	_redraw(host)


## 敌方移动后：settle 落点 + 新威胁格，刷栏，盖 move。
static func after_move(host, landed: Vector2i, unit_idx: int) -> void:
	if host == null or landed.x < 0:
		return
	var also: Array = threat_cells(host, unit_idx, landed)
	_frame(host, landed, also)
	_stamp(host, "move", {"ui": unit_idx, "landed": landed, "foes": also.duplicate()})
	_redraw(host)


## 敌方打击后：settle 攻方+目标，刷栏，盖 strike。
static func after_strike(host, actor: Vector2i, target: Vector2i, unit_idx: int) -> void:
	if host == null or actor.x < 0:
		return
	var also: Array = []
	if target.x >= 0:
		also.append(target)
	_frame(host, actor, also)
	_stamp(host, "strike", {"ui": unit_idx, "actor": actor, "target": target})
	_redraw(host)


## 该敌方单位行动收尾（无打击或打击后）：盖 done。
static func after_unit_done(host, unit_idx: int) -> void:
	if host == null:
		return
	BattleBoardInset.refresh_info_block(host)
	_stamp(host, "done", {"ui": unit_idx})
	_redraw(host)
