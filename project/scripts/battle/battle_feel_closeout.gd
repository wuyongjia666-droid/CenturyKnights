class_name BattleFeelCloseout
extends RefCounted
## 战棋手感收口：终局清全戳 + 桌面/手游 BoardInset 整链闭环。
##
## 玩家看得见的缝：胜/负横幅升起后，选中/移动/攻击/战技/取消/敌方行动/
## 落子窥视/幽灵窥视/瞄准/危险区/回场脉冲等 chrome 仍叠在棋盘上，信息栏
## 也不刷，横幅与侧栏抢可读区。本刀收口：终局一次清全链戳与窥视，刷
## BoardInset，盖 closeout 戳，让终局横幅独占舞台。禁瞄准预告碎刀 /
## telegraph / EmptyHost / BoardInset 单点薄切。

const META := "m_feel_closeout"


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


static func _drop_meta(host, key: String) -> void:
	if host != null and host.has_meta(key):
		host.remove_meta(key)


## 清跨阶段会漏到终局横幅下的整链戳 / 窥视 / 危险 / 回场脉冲。
static func clear_all_chrome(host) -> void:
	if host == null:
		return
	BattleFeelLoop.clear(host)
	BattleCancelFeelLoop.clear(host)
	BattleEnemyActFeel.clear(host)
	BattleTurnCycleFeel.clear(host)
	BattleSkillFeelLoop.clear_all(host)
	BattleLandStrike.clear(host)
	BattleAttackAim.clear(host)
	_drop_meta(host, BattleGhostStrike.META)
	_drop_meta(host, BattleWaitHandoff.META)
	_drop_meta(host, BattleTurnBridge.META_PULSE)
	# danger_on / danger_focus：代数宿主可能没有这两个字段。
	if typeof(host.get("danger_on")) == TYPE_BOOL:
		host.set("danger_on", false)
	if typeof(host.get("danger_focus")) == TYPE_INT:
		host.set("danger_focus", -1)


## 胜/负终局：先清全链 chrome，再刷 BoardInset，盖 end 戳。
## 由 PhaseFeel.note_battle_end 调用（横幅/crest 已 stamp 之后）。
static func after_battle_end(host, win: bool) -> void:
	if host == null:
		return
	clear_all_chrome(host)
	BattleBoardInset.refresh_info_block(host)
	_stamp(host, "end", {"win": win})
	_redraw(host)
