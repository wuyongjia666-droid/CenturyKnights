class_name CKTips
extends RefCounted
## 首次提示注册表。每条只触发一次，已见 id 写在 GameState.settings["tips_seen"]，随现有存档往返。
##
## 叙事流写入内容（不要改城堡脚本）：
##   CKTips.register({
##     "id": "story_gate",
##     "scene_tail": "castle_hub.tscn",
##     "anchor": "SomeButtonName",
##     "text": "……",
##   })
## scene_tail 匹配 scene_file_path 后缀；没有 tail 时用 scene_name 匹配节点名。
## tutorial_highlight=false 时 maybe_present 一律不触发。

static var _extra: Array = []

const BUILTIN: Array = [
	{
		"id": "menu_lamp",
		"scene_tail": "main_menu.tscn",
		"anchor": "MenuColumn",
		"text": "灯引只在第一次走进某个地方时点亮。设置里可以关掉新手高亮。",
	},
	{
		"id": "settings_lamp",
		"scene_tail": "settings.tscn",
		"anchor": "",
		"text": "系统百科收着战棋、城堡、联姻和舆图的短说明，随时能翻。",
	},
]

static func reset_for_tests() -> void:
	_extra.clear()

static func register(tip: Dictionary) -> void:
	var id := str(tip.get("id", ""))
	if id == "":
		return
	for i in _extra.size():
		if str(_extra[i].get("id", "")) == id:
			_extra[i] = tip
			return
	_extra.append(tip)

static func all_tips() -> Array:
	var out: Array = []
	for tip in BUILTIN:
		out.append(tip)
	for tip in _extra:
		out.append(tip)
	return out

static func enabled() -> bool:
	return bool(GameState.settings.get("tutorial_highlight", true))

static func seen_map() -> Dictionary:
	var raw = GameState.settings.get("tips_seen", {})
	if typeof(raw) != TYPE_DICTIONARY:
		return {}
	return raw

static func is_seen(id: String) -> bool:
	return bool(seen_map().get(id, false))

static func mark_seen(id: String) -> void:
	var d := seen_map().duplicate()
	d[id] = true
	GameState.settings["tips_seen"] = d

static func clear_seen() -> void:
	GameState.settings["tips_seen"] = {}

static func pending_for(scene: Node) -> Dictionary:
	if not enabled() or scene == null:
		return {}
	var path := str(scene.scene_file_path)
	for tip in all_tips():
		var id := str(tip.get("id", ""))
		if id == "" or is_seen(id):
			continue
		var tail := str(tip.get("scene_tail", ""))
		if tail != "":
			if not path.ends_with(tail):
				continue
		elif str(tip.get("scene_name", "")) != str(scene.name):
			continue
		return tip
	return {}

static func maybe_present(scene: Node) -> bool:
	var tip := pending_for(scene)
	if tip.is_empty():
		return false
	var target := _resolve_anchor(scene, str(tip.get("anchor", "")))
	if target == null:
		return false
	var coach := CKCoach.attach(scene)
	var safe := Rect2()
	if scene is Control:
		var host := scene as Control
		var vp := host.get_viewport_rect().size
		if vp.y >= 2000.0:
			safe = CKCoach.safe_rect(vp, CKCoach.TALL_INSETS)
	coach.present_target(target, str(tip.get("text", "")), safe)
	mark_seen(str(tip.get("id", "")))
	return true

static func _resolve_anchor(scene: Node, anchor: String) -> Control:
	if anchor != "":
		var named := scene.find_child(anchor, true, false)
		if named is Control:
			return named
	var buttons := scene.find_children("*", "Button", true, false)
	if not buttons.is_empty() and buttons[0] is Control:
		return buttons[0]
	if scene is Control:
		return scene
	return null
