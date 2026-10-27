class_name BattleFeelLoop
extends RefCounted
## 战棋手感整块：选中 → 移动 → 攻击 → 信息栏 → 镜头 一条可玩闭环。
##
## 玩家看得见的缝：confirm_move 曾在落子窥视（stand+foes）之后，又用
## settle_camera(mover, []) 只框落点，把可打敌人挤出可读区。本刀收口：
## 移动确认 settle 的 also 带上 LandStrike 威胁格；进攻击清窥视；
## 各阶段刷新 m_info_block 并盖 m_feel_loop 戳。禁瞄准预告碎刀与空壳宿主。

const META := "m_feel_loop"


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


## 选中：信息栏现场刷新 + 镜头已由 focus_selected 落可读 inset。
static func after_select(host) -> void:
	if host == null:
		return
	BattleBoardInset.refresh_info_block(host)
	_stamp(host, "select", {"ui": int(host.get("selected"))})


## 移动确认后：落子窥视 → settle 带上可打敌人（不再 mover-only 盖掉 peek）。
static func after_move(host, landed: Vector2i) -> void:
	if host == null or landed.x < 0:
		return
	BattleLandStrike.after_land(host)
	var also: Array = []
	for c in BattleLandStrike.threatened_cells(host):
		also.append(c)
	BattleBoardInset.refresh_info_block(host)
	if BattleConfirmAffordance.yields_post_camera(host):
		BattleConfirmAffordance.settle_camera(host, landed, also)
	else:
		var cells: Array = [landed]
		for c in also:
			cells.append(c)
		BattlePick.focus_cell(host, landed)
		BattleCombatFrame.follow_cells(host, cells, 0.0)
		BattleActionSettle.apply(host, landed, also)
	_stamp(host, "move", {"landed": landed, "foes": also.duplicate()})


## 进攻击：清落子窥视 chrome（attack_mode 已使 LandStrike.active=false，META 仍清）。
## 调用方须先 BattleAttackAim.after_enter。
static func after_attack_enter(host) -> void:
	if host == null:
		return
	BattleLandStrike.clear(host)
	BattleBoardInset.refresh_info_block(host)
	var foes: Array = []
	if host.has_meta(BattleAttackAim.META):
		var aim = host.get_meta(BattleAttackAim.META)
		if aim is Dictionary:
			var raw = (aim as Dictionary).get("foes", [])
			if raw is Array:
				foes = (raw as Array).duplicate()
	_stamp(host, "attack_enter", {"foes": foes})


## 攻击确认后：清瞄准 META，盖闭环戳（镜头已由 confirm_attack settle）。
static func after_attack_confirm(host, actor: Vector2i, also: Array) -> void:
	if host == null:
		return
	BattleAttackAim.clear(host)
	BattleLandStrike.clear(host)
	BattleBoardInset.refresh_info_block(host)
	_stamp(host, "attack", {"actor": actor, "also": also.duplicate()})
