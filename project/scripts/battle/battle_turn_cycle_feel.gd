class_name BattleTurnCycleFeel
extends RefCounted
## 回合整链手感：待命交接 → 结束回合 → 敌方阶段 → 玩家回场。
##
## 玩家看得见的缝：落子窥视（LandStrike）在待命交下一人后仍画在棋盘上；
## FeelLoop / AttackAim META 进敌方阶段不清；回场自动选中后信息栏可能仍
## 停在上一人收尾态；战技 Buff/Heal 闩进敌方仍画。本刀收口：交接前清窥视
## 与瞄准与战技闩；结束回合清 FeelLoop / 交接 META / 战技闩；回场盖 cycle
## 戳并刷信息栏。禁瞄准预告碎刀 / telegraph / EmptyHost / BoardInset 单点薄切。

const META := "m_turn_cycle"


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


## 清跨单位 / 跨阶段会漏的窥视 / 瞄准 / 战技闩 chrome。
static func clear_peek_chrome(host) -> void:
	if host == null:
		return
	BattleLandStrike.clear(host)
	BattleAttackAim.clear(host)
	BattleSkillFeelLoop.clear_latches(host)


## 待命 / 打击 / 技能收尾交接前：先清上一人窥视，再让 WaitHandoff 选下一人。
static func before_handoff(host) -> void:
	clear_peek_chrome(host)


## 交接完成后：信息栏跟新选中；盖 handoff 戳（FeelLoop 已由 _select_player 盖 select）。
static func after_handoff(host, from_i: int, to_i: int) -> void:
	if host == null:
		return
	BattleBoardInset.refresh_info_block(host)
	_stamp(host, "handoff", {"from": from_i, "to": to_i})
	var ov = host.get("overlay")
	if ov != null and ov.has_method("queue_redraw"):
		ov.queue_redraw()
	var md = host.get("map_draw")
	if md != null and md.has_method("queue_redraw"):
		md.queue_redraw()


## 结束玩家回合进敌方：清闭环 / 窥视 / 交接 META，盖 enemy 戳。
static func before_enemy_phase(host) -> void:
	if host == null:
		return
	clear_peek_chrome(host)
	BattleFeelLoop.clear(host)
	BattleSkillFeelLoop.clear(host)
	if host.has_meta(BattleWaitHandoff.META):
		host.remove_meta(BattleWaitHandoff.META)
	_stamp(host, "enemy", {})
	var ov = host.get("overlay")
	if ov != null and ov.has_method("queue_redraw"):
		ov.queue_redraw()


## 玩家回场（TurnBridge.note_player_return 之后）：再清一次窥视，刷信息栏，盖 return。
static func after_player_return(host) -> void:
	if host == null:
		return
	clear_peek_chrome(host)
	BattleBoardInset.refresh_info_block(host)
	_stamp(host, "return", {"selected": int(host.get("selected"))})
