extends Control

var _msg: Label
var _char_list: VBoxContainer
var _graph: Control
var _graph_panel: Control
var _detail: RichTextLabel
var _selected: CKCharacter
var _node_btns: Dictionary = {}
var _pts_label: Label
var _zoom: float = 1.0
var _pan: Vector2 = Vector2.ZERO
var _dragging: bool = false
var _drag_last: Vector2 = Vector2.ZERO
var _fx_pulses: Array = []  # {pos, age, life}
var _zoom_label: Label
var _search: LineEdit
var _minimap: Control
var _spark_frames: Array = []

func _ready() -> void:
	UIKit.make_themed_bg(self, "skill")
	UIFX.fade_in(self, 0.3)
	Music.play_hub()
	for i in 4:
		var sp = "res://assets/art/fx/unlock_%d.png" % i
		if ResourceLoader.exists(sp):
			_spark_frames.append(load(sp))
	var t = UIKit.make_label("战技树 · 图谱", true)
	t.position = Vector2(40, 12)
	add_child(t)
	_pts_label = UIKit.make_label("可用战技点：%d（非教程胜仗 +1）" % GameState.skill_points)
	_pts_label.position = Vector2(40, 48)
	_pts_label.add_theme_color_override("font_color", UIKit.ACCENT)
	add_child(_pts_label)
	var tip = UIKit.make_dim_label("拖拽平移 · 滚轮缩放 · 点亮节点解锁。金=已学，青=可解锁。")
	tip.position = Vector2(40, 76)
	add_child(tip)
	_zoom_label = UIKit.make_dim_label("缩放 100%")
	_zoom_label.position = Vector2(700, 76)
	add_child(_zoom_label)
	_search = LineEdit.new()
	_search.placeholder_text = "搜索战技名…"
	_search.custom_minimum_size = Vector2(200, 28)
	_search.position = Vector2(820, 72)
	_search.text_changed.connect(_on_search)
	add_child(_search)

	var left = UIKit.make_panel()
	left.position = Vector2(24, 110)
	left.custom_minimum_size = Vector2(200, 480)
	add_child(left)
	_char_list = VBoxContainer.new()
	_char_list.add_theme_constant_override("separation", 6)
	left.add_child(_char_list)

	_graph_panel = UIKit.make_panel()
	_graph_panel.position = Vector2(240, 110)
	_graph_panel.custom_minimum_size = Vector2(740, 420)
	_graph_panel.clip_contents = true
	_graph_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_graph_panel.gui_input.connect(_on_graph_input)
	add_child(_graph_panel)

	_graph = Control.new()
	_graph.custom_minimum_size = Vector2(1200, 800)
	_graph.draw.connect(_draw_graph)
	_graph_panel.add_child(_graph)

	_minimap = Control.new()
	_minimap.position = Vector2(860, 540)
	_minimap.custom_minimum_size = Vector2(160, 90)
	_minimap.draw.connect(_draw_minimap)
	_minimap.gui_input.connect(_on_minimap_input)
	add_child(_minimap)
	var mm_label = UIKit.make_dim_label("小地图（点击跳转）")
	mm_label.position = Vector2(860, 520)
	add_child(mm_label)

	var right = UIKit.make_panel()
	right.position = Vector2(1000, 110)
	right.custom_minimum_size = Vector2(260, 420)
	add_child(right)
	_detail = RichTextLabel.new()
	_detail.bbcode_enabled = true
	_detail.custom_minimum_size = Vector2(240, 400)
	_detail.add_theme_color_override("default_color", UIKit.TEXT)
	right.add_child(_detail)

	_msg = UIKit.make_label("")
	_msg.position = Vector2(240, 550)
	add_child(_msg)
	var row := HBoxContainer.new()
	row.position = Vector2(40, 640)
	row.add_theme_constant_override("separation", 8)
	add_child(row)
	var back = UIKit.make_button(Locale.t("btn_back"), 120)
	back.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/hub/castle_hub.tscn"))
	row.add_child(back)
	var reset = UIKit.make_button("复位视角", 120)
	reset.pressed.connect(func():
		_zoom = 1.0; _pan = Vector2.ZERO; _apply_view()
	)
	row.add_child(reset)
	_refresh_chars()
	set_process(true)

func _process(delta: float) -> void:
	var dirty := false
	for i in range(_fx_pulses.size() - 1, -1, -1):
		_fx_pulses[i].age += delta
		if _fx_pulses[i].age >= _fx_pulses[i].life:
			_fx_pulses.remove_at(i)
		dirty = true
	if dirty:
		_graph.queue_redraw()

func _apply_view() -> void:
	_graph.scale = Vector2(_zoom, _zoom)
	_graph.position = _pan
	_zoom_label.text = "缩放 %d%%" % int(_zoom * 100)
	_graph.queue_redraw()
	if _minimap: _minimap.queue_redraw()

func _on_graph_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			_zoom = clampf(_zoom * 1.1, 0.55, 1.8)
			_apply_view()
			accept_event()
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			_zoom = clampf(_zoom / 1.1, 0.55, 1.8)
			_apply_view()
			accept_event()
		elif event.button_index == MOUSE_BUTTON_MIDDLE or event.button_index == MOUSE_BUTTON_RIGHT:
			_dragging = event.pressed
			_drag_last = event.position
			accept_event()
		elif event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			# allow drag with left if holding shift-less empty area — use middle/right primarily
			pass
	elif event is InputEventMouseMotion:
		if _dragging:
			var d = event.position - _drag_last
			_drag_last = event.position
			_pan += d
			_apply_view()
			accept_event()

func _refresh_chars() -> void:
	for c in _char_list.get_children():
		c.queue_free()
	for ch in GameState.roster():
		var b = UIKit.make_button("%s" % ch.name, 170)
		var captured = ch
		b.pressed.connect(func(): _show(captured))
		_char_list.add_child(b)
	if GameState.roster().size() > 0:
		_show(GameState.roster()[0])

func _node_pos(tree_idx: int, tier: int, slot: int) -> Vector2:
	var x = 60.0 + tree_idx * 200.0 + slot * 20.0
	var y = 60.0 + (tier - 1) * 150.0
	return Vector2(x, y)

func _show(c: CKCharacter) -> void:
	_selected = c
	for k in _node_btns.keys():
		if is_instance_valid(_node_btns[k]):
			_node_btns[k].queue_free()
	_node_btns.clear()
	for child in _graph.get_children():
		if str(child.name).begins_with("TreeTitle_") or str(child.name).begins_with("Node_"):
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
		label.position = _node_pos(ti, 0, 0) + Vector2(0, -30)
		label.add_theme_color_override("font_color", UIKit.ACCENT)
		label.name = "TreeTitle_%s" % tid
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
			b.custom_minimum_size = Vector2(150, 56)
			b.position = _node_pos(ti, tier, slot)
			b.text = "%s\nT%d · CD%d" % [sk.get("name"), tier, int(sk.get("cooldown", 1))]
			b.name = "Node_%s" % sid
			if owned:
				b.modulate = Color(1.0, 0.92, 0.55)
			elif check.get("ok"):
				b.modulate = Color(0.85, 0.95, 1.0)
			else:
				b.modulate = Color(0.55, 0.55, 0.58)
				if int(sk.get("tier", 1)) >= 2 and not owned:
					b.disabled = not check.get("ok")
			var cap_sid = sid
			var cap_sk = sk
			b.pressed.connect(func(): _on_node(cap_sid, cap_sk))
			_graph.add_child(b)
			_node_btns[sid] = b
	_graph.queue_redraw()
	if _minimap: _minimap.queue_redraw()
	_detail.text = "[b]%s[/b]\n职业 %s\n已学 %d\n\n拖拽/滚轮浏览图谱。\n点青节点解锁。" % [
		c.name, GameState.get_job(c.job_id).get("name", ""), c.skills.size()
	]

func _draw_graph() -> void:
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
		_graph.draw_line(p0, p1, col, 2.5)
		var dir = (p1 - p0).normalized()
		_graph.draw_circle(p1 - dir * 14.0, 3.5, col)
	for fx in _fx_pulses:
		var a2 = clampf(1.0 - fx.age / fx.life, 0.0, 1.0)
		var r = 18.0 + fx.age * 40.0
		_graph.draw_arc(fx.pos, r, 0, TAU, 40, Color(1.0, 0.85, 0.35, a2), 2.5)
		_graph.draw_circle(fx.pos, 6.0 * a2, Color(1.0, 0.9, 0.5, a2 * 0.8))
		if fx.get("spark", false) and _spark_frames.size() > 0:
			var fi = mini(_spark_frames.size() - 1, int(fx.age / 0.12))
			var tex: Texture2D = _spark_frames[fi]
			_graph.draw_texture(tex, fx.pos - Vector2(32, 32))

func _spawn_unlock_fx(sid: String) -> void:
	if not _node_btns.has(sid):
		return
	var b: Button = _node_btns[sid]
	if not is_instance_valid(b):
		return
	_fx_pulses.append({"pos": b.position + b.size * 0.5, "age": 0.0, "life": 0.75, "spark": true})
	_graph.queue_redraw()
	if _minimap:
		_minimap.queue_redraw()

func _on_search(q: String) -> void:
	var qq = q.strip_edges()
	for sid in _node_btns.keys():
		var b: Button = _node_btns[sid]
		if not is_instance_valid(b):
			continue
		var sk = GameState.get_skill(sid)
		var name = str(sk.get("name", sid))
		if qq == "" or qq in name or qq.to_lower() in sid:
			b.modulate.a = 1.0
			if qq != "" and (qq in name or qq.to_lower() in sid):
				# focus first match
				var target = -(b.position * _zoom) + Vector2(200, 120)
				_pan = target
				_apply_view()
				_detail.text = "[b]定位[/b] %s\n%s" % [name, sk.get("desc", "")]
				break
		else:
			b.modulate.a = 0.25

func _draw_minimap() -> void:
	var r = Rect2(Vector2.ZERO, _minimap.size)
	_minimap.draw_rect(r, Color(0.08, 0.09, 0.12, 0.92))
	_minimap.draw_rect(r, Color(0.78, 0.64, 0.22, 0.6), false, 1.0)
	if _node_btns.is_empty():
		return
	var min_p = Vector2(9999, 9999)
	var max_p = Vector2(-9999, -9999)
	for sid in _node_btns.keys():
		var b: Button = _node_btns[sid]
		if not is_instance_valid(b):
			continue
		var c = b.position + b.size * 0.5
		min_p = Vector2(minf(min_p.x, c.x), minf(min_p.y, c.y))
		max_p = Vector2(maxf(max_p.x, c.x), maxf(max_p.y, c.y))
	var span = (max_p - min_p)
	if span.x < 1: span.x = 1
	if span.y < 1: span.y = 1
	for sid in _node_btns.keys():
		var b2: Button = _node_btns[sid]
		if not is_instance_valid(b2):
			continue
		var c2 = b2.position + b2.size * 0.5
		var np = Vector2(
			((c2.x - min_p.x) / span.x) * (r.size.x - 8) + 4,
			((c2.y - min_p.y) / span.y) * (r.size.y - 8) + 4
		)
		var owned = _selected != null and (sid in _selected.skills or sid in _selected.unlocked_skills)
		var col = Color(1.0, 0.85, 0.35) if owned else Color(0.55, 0.7, 0.9)
		_minimap.draw_circle(np, 3.0, col)
	# viewport rect approx
	var vp0 = (-_pan) / _zoom
	var vp1 = vp0 + _graph_panel.size / _zoom
	var a = Vector2(((vp0.x - min_p.x) / span.x) * (r.size.x - 8) + 4, ((vp0.y - min_p.y) / span.y) * (r.size.y - 8) + 4)
	var b3 = Vector2(((vp1.x - min_p.x) / span.x) * (r.size.x - 8) + 4, ((vp1.y - min_p.y) / span.y) * (r.size.y - 8) + 4)
	_minimap.draw_rect(Rect2(a, b3 - a), Color(1, 1, 1, 0.25), false, 1.0)

func _on_minimap_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if _node_btns.is_empty():
			return
		var min_p = Vector2(9999, 9999)
		var max_p = Vector2(-9999, -9999)
		for sid in _node_btns.keys():
			var b: Button = _node_btns[sid]
			if not is_instance_valid(b):
				continue
			var c = b.position + b.size * 0.5
			min_p = Vector2(minf(min_p.x, c.x), minf(min_p.y, c.y))
			max_p = Vector2(maxf(max_p.x, c.x), maxf(max_p.y, c.y))
		var span = max_p - min_p
		if span.x < 1: span.x = 1
		if span.y < 1: span.y = 1
		var local = event.position
		var gx = min_p.x + ((local.x - 4) / maxf(1.0, _minimap.size.x - 8)) * span.x
		var gy = min_p.y + ((local.y - 4) / maxf(1.0, _minimap.size.y - 8)) * span.y
		_pan = -Vector2(gx, gy) * _zoom + _graph_panel.size * 0.5
		_apply_view()

func _on_node(sid: String, sk: Dictionary) -> void:
	var owned = sid in _selected.skills or sid in _selected.unlocked_skills
	var check = GameState.can_unlock_skill(_selected, sid)
	var lines = [
		"[b]%s[/b]" % sk.get("name"),
		"途径：%s　T%d　冷却%d　次数%d" % [sk.get("tree"), int(sk.get("tier",1)), int(sk.get("cooldown",1)), int(sk.get("uses",1))],
		str(sk.get("desc", "")),
		""
	]
	if owned:
		lines.append("[color=#c9a227]已掌握[/color]")
	elif check.get("ok"):
		lines.append("[color=#8ecae6]解锁中…[/color]")
		var r = GameState.unlock_skill(_selected, sid)
		_msg.text = str(r.get("msg"))
		_pts_label.text = "可用战技点：%d（非教程胜仗 +1）" % GameState.skill_points
		Sfx.confirm()
		Sfx.fanfare()
		_spawn_unlock_fx(sid)
		# brief delay then refresh so FX visible
		await get_tree().create_timer(0.35).timeout
		_show(_selected)
		return
	else:
		lines.append("[color=#888]%s[/color]" % check.get("msg", "不可解锁"))
	_detail.text = "\n".join(lines)
