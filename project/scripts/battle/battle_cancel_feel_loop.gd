class_name BattleCancelFeelLoop
extends RefCounted
## 取消整链手感：预览取消 → 模式退出 → 全清选中 → 敌方清戳。
##
## 玩家看得见的缝：Esc/板取消后信息栏仍停在战技/攻击预览文案；退出攻击/战技
## 模式后 BoardInset 不刷、侧栏裁切旧；全清选中后 FeelLoop 戳残留；取消戳
## 进敌方阶段仍在。本刀收口：每层取消刷信息栏并盖 cancel_feel 戳；全清时
## 清 FeelLoop；敌方/回合清整链戳。禁瞄准预告碎刀 / telegraph / EmptyHost /
## BoardInset 单点薄切。

const META := "m_cancel_feel"


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


## 预览层取消后：闩/幽灵已由 TouchConfirm.clear 清掉；刷信息栏，盖 preview。
static func after_preview(host) -> void:
	if host == null:
		return
	BattleBoardInset.refresh_info_block(host)
	_stamp(host, "preview", {})
	var ov = host.get("overlay")
	if ov != null and ov.has_method("queue_redraw"):
		ov.queue_redraw()
	var md = host.get("map_draw")
	if md != null and md.has_method("queue_redraw"):
		md.queue_redraw()


## 模式层取消后（退出攻击/战技，保留选中）：刷信息栏，盖 mode。
static func after_mode(host) -> void:
	if host == null:
		return
	BattleBoardInset.refresh_info_block(host)
	_stamp(host, "mode", {"selected": int(host.get("selected"))})
	var ov = host.get("overlay")
	if ov != null and ov.has_method("queue_redraw"):
		ov.queue_redraw()
	var md = host.get("map_draw")
	if md != null and md.has_method("queue_redraw"):
		md.queue_redraw()


## 选中层取消后：清 FeelLoop 残留，刷信息栏，盖 select。
static func after_select(host) -> void:
	if host == null:
		return
	BattleFeelLoop.clear(host)
	BattleBoardInset.refresh_info_block(host)
	_stamp(host, "select", {})
	var ov = host.get("overlay")
	if ov != null and ov.has_method("queue_redraw"):
		ov.queue_redraw()
	var md = host.get("map_draw")
	if md != null and md.has_method("queue_redraw"):
		md.queue_redraw()
