class_name BattleSkillFeelLoop
extends RefCounted
## 战技整链手感：Buff/Heal 预览 → Tab 瞄准 → 确认施放 → 信息栏/镜头落定 → 交接/敌方清闩。
##
## 玩家看得见的缝：战技闩预览进敌方阶段仍画在棋盘；治疗施放后 WaitHandoff
## 前镜头停在预览跟焦；鼓舞施放无落定戳、信息栏可能仍停在预览态。本刀收口：
## arm/aim 盖 skill_feel 戳；cast 后 settle 框施法者+目标并刷信息栏；
## 交接/结束回合清 Buff/Heal 闩。禁瞄准预告碎刀 / telegraph / EmptyHost /
## BoardInset 单点薄切。

const META := "m_skill_feel"


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


## 清未确认的战技闩（Buff + Heal）。不碰 cast 戳——交接只清预览闩，
## 施放落定戳留到敌方阶段 / 取消再清。
static func clear_latches(host) -> void:
	if host == null:
		return
	BattleSkillBuffPreview.clear(host)
	BattleSkillHealPreview.clear(host)


## 敌方阶段 / 取消：清闩 + 清整链戳。
static func clear_all(host) -> void:
	clear_latches(host)
	clear(host)


## 闩预览武装后：信息栏已由 Preview.arm 刷新；盖 arm 戳。
static func after_arm(host, kind: String) -> void:
	if host == null:
		return
	BattleBoardInset.refresh_info_block(host)
	_stamp(host, "arm", {"kind": kind, "sid": str(host.get("active_skill_id"))})


## Tab 换焦后：盖 aim 戳（跟焦已由 Preview._aim 完成）。
static func after_aim(host, kind: String, focus: int) -> void:
	if host == null:
		return
	BattleBoardInset.refresh_info_block(host)
	_stamp(host, "aim", {"kind": kind, "focus": focus})


## 确认施放后：settle 框施法者 + 目标格，刷信息栏，盖 cast 戳。
## 治疗路径须在 WaitHandoff 之前调用，免得交接镜头盖掉施放落定。
static func after_cast(host, kind: String, caster: Vector2i, targets: Array) -> void:
	if host == null or caster.x < 0:
		return
	var also: Array = []
	for c in targets:
		if c is Vector2i and (c as Vector2i) != caster:
			also.append(c)
	BattleBoardInset.refresh_info_block(host)
	if BattleConfirmAffordance.yields_post_camera(host):
		BattleConfirmAffordance.settle_camera(host, caster, also)
	else:
		var cells: Array = [caster]
		for c in also:
			cells.append(c)
		BattlePick.focus_cell(host, caster)
		BattleCombatFrame.follow_cells(host, cells, 0.0)
		BattleActionSettle.apply(host, caster, also)
	_stamp(host, "cast", {"kind": kind, "caster": caster, "targets": also.duplicate()})
	var ov = host.get("overlay")
	if ov != null and ov.has_method("queue_redraw"):
		ov.queue_redraw()
	var md = host.get("map_draw")
	if md != null and md.has_method("queue_redraw"):
		md.queue_redraw()
