extends Control

var _msg: Label
var _char_list: VBoxContainer
var _graph: Control
var _detail: RichTextLabel
var _selected: CKCharacter
var _node_btns: Dictionary = {}  # sid -> Button
var _pts_label: Label

func _ready() -> void:
	UIKit.make_screen_bg(self)
	UIFX.fade_in(self, 0.3)
	Music.play_hub()
	var t = UIKit.make_label("战技树 · 图谱", true)
	t.position = Vector2(40, 12)
	add_child(t)
	_pts_label = UIKit.make_label("可用战技点：%d（非教程胜仗 +1）" % GameState.skill_points)
	_pts_label.position = Vector2(40, 48)
	_pts_label.add_theme_color_override("font_color", UIKit.ACCENT)
	add_child(_pts_label)
	var tip = UIKit.make_dim_label("节点=战技。实线=前置依赖。金边=已学，灰=可点解锁，暗=未满足。")
	tip.position = Vector2(40, 76)
	add_child(tip)

	var left = UIKit.make_panel()
	left.position = Vector2(24, 110)
	left.custom_minimum_size = Vector2(220, 480)
	add_child(left)
	_char_list = VBoxContainer.new()
	_char_list.add_theme_constant_override("separation", 6)
	left.add_child(_char_list)

	var graph_panel = UIKit.make_panel()
	graph_panel.position = Vector2(260, 110)
	graph_panel.custom_minimum_size = Vector2(720, 400)
	add_child(graph_panel)
	_graph = Control.new()
	_graph.custom_minimum_size = Vector2(700, 380)
	_graph.draw.connect(_draw_edges)
	graph_panel.add_child(_graph)

	var right = UIKit.make_panel()
	right.position = Vector2(1000, 110)
	right.custom_minimum_size = Vector2(260, 400)
	add_child(right)
	_detail = RichTextLabel.new()
	_detail.bbcode_enabled = true
	_detail.custom_minimum_size = Vector2(240, 380)
	_detail.add_theme_color_override("default_color", UIKit.TEXT)
	right.add_child(_detail)

	_msg = UIKit.make_label("")
	_msg.position = Vector2(260, 530)
	add_child(_msg)
	var back = UIKit.make_button(Locale.t("btn_back"), 120)
	back.position = Vector2(40, 640)
	back.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/hub/castle_hub.tscn"))
	add_child(back)
	_refresh_chars()

func _refresh_chars() -> void:
	for c in _char_list.get_children():
		c.queue_free()
	for ch in GameState.roster():
		var b = UIKit.make_button("%s" % ch.name, 190)
		var captured = ch
		b.pressed.connect(func(): _show(captured))
		_char_list.add_child(b)
	if GameState.roster().size() > 0:
		_show(GameState.roster()[0])

func _node_pos(tree_idx: int, tier: int, slot: int) -> Vector2:
	var x = 40.0 + tree_idx * 175.0 + slot * 18.0
	var y = 40.0 + (tier - 1) * 140.0
	return Vector2(x, y)

func _show(c: CKCharacter) -> void:
	_selected = c
	for k in _node_btns.keys():
		if is_instance_valid(_node_btns[k]):
			_node_btns[k].queue_free()
	_node_btns.clear()
	# clear titles
	for child in _graph.get_children():
		if str(child.name).begins_with("TreeTitle_"):
			child.queue_free()
	var trees: Array = GameState.data_skills.get("trees", [])
	var by_tree: Dictionary = {}
	for sk in GameState.data_skills.get("skills", []):
		if c.job_id not in sk.get("jobs", []):
			continue
		var tid = str(sk.get("tree", "melee"))
		if not by_tree.has(tid):
			by_tree[tid] = []
		by_tree[tid].append(sk)
	for ti in trees.size():
		var tree = trees[ti]
		var tid = str(tree.get("id"))
		var label = Label.new()
		label.text = str(tree.get("name", tid))
		label.position = _node_pos(ti, 0, 0) + Vector2(0, -28)
		label.add_theme_color_override("font_color", UIKit.ACCENT)
		label.name = "TreeTitle_%s" % tid
		# remove old titles
		var old = _graph.get_node_or_null(label.name)
		if old:
			old.queue_free()
		_graph.add_child(label)
		var skills: Array = by_tree.get(tid, [])
		var tier_slots := {}
		for sk in skills:
			var tier = int(sk.get("tier", 1))
			if not tier_slots.has(tier):
				tier_slots[tier] = 0
			var slot = int(tier_slots[tier])
			tier_slots[tier] = slot + 1
			var sid = str(sk.get("id"))
			var owned = sid in c.skills or sid in c.unlocked_skills
			var check = GameState.can_unlock_skill(c, sid)
			var b = Button.new()
			b.custom_minimum_size = Vector2(140, 52)
			b.position = _node_pos(ti, tier, slot)
			b.text = "%s\nT%d CD%d" % [sk.get("name"), tier, int(sk.get("cooldown", 1))]
			b.name = "Node_%s" % sid
			if owned:
				b.modulate = Color(1.0, 0.92, 0.55)
			elif check.get("ok"):
				b.modulate = Color(0.85, 0.95, 1.0)
			else:
				b.modulate = Color(0.55, 0.55, 0.58)
				b.disabled = int(sk.get("tier", 1)) >= 2 and not owned
			var cap_sid = sid
			var cap_sk = sk
			b.pressed.connect(func(): _on_node(cap_sid, cap_sk))
			_graph.add_child(b)
			_node_btns[sid] = b
	_graph.queue_redraw()
	_detail.text = "[b]%s[/b]\n职业 %s\n已学 %d　解锁备用 %d\n\n点选节点查看详情与解锁。" % [
		c.name, GameState.get_job(c.job_id).get("name", ""), c.skills.size(), c.unlocked_skills.size()
	]

func _draw_edges() -> void:
	if _selected == null:
		return
	for sk in GameState.data_skills.get("skills", []):
		var req = str(sk.get("req_skill", ""))
		if req == "":
			continue
		var sid = str(sk.get("id"))
		if not _node_btns.has(sid) or not _node_btns.has(req):
			continue
		var a: Button = _node_btns[req]
		var b: Button = _node_btns[sid]
		if not is_instance_valid(a) or not is_instance_valid(b):
			continue
		var p0 = a.position + a.size * 0.5
		var p1 = b.position + b.size * 0.5
		var col = Color(0.78, 0.64, 0.22, 0.85)
		_graph.draw_line(p0, p1, col, 2.0)
		# arrow tip
		var dir = (p1 - p0).normalized()
		var tip = p1 - dir * 12.0
		_graph.draw_circle(tip, 3.0, col)

func _on_node(sid: String, sk: Dictionary) -> void:
	var owned = sid in _selected.skills or sid in _selected.unlocked_skills
	var check = GameState.can_unlock_skill(_selected, sid)
	var lines = [
		"[b]%s[/b]" % sk.get("name"),
		"途径：%s　阶：T%d　冷却：%d　次数：%d" % [sk.get("tree"), int(sk.get("tier",1)), int(sk.get("cooldown",1)), int(sk.get("uses",1))],
		str(sk.get("desc", "")),
		""
	]
	if owned:
		lines.append("[color=#c9a227]已掌握[/color]")
	elif check.get("ok"):
		lines.append("[color=#8ecae6]可花费 1 战技点解锁[/color]")
		var r = GameState.unlock_skill(_selected, sid)
		_msg.text = str(r.get("msg"))
		_pts_label.text = "可用战技点：%d（非教程胜仗 +1）" % GameState.skill_points
		Sfx.confirm()
		_show(_selected)
		return
	else:
		lines.append("[color=#888]%s[/color]" % check.get("msg", "不可解锁"))
	_detail.text = "\n".join(lines)
