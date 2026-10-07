extends Control

var _msg: Label
var _list: VBoxContainer
var _detail: RichTextLabel
var _selected: CKCharacter

func _ready() -> void:
	UIKit.make_screen_bg(self)
	UIFX.fade_in(self, 0.3)
	Music.play_hub()
	var t = UIKit.make_label("战技树", true)
	t.position = Vector2(40, 16)
	add_child(t)
	var pts = UIKit.make_label("可用战技点：%d（非教程胜仗 +1）" % GameState.skill_points)
	pts.name = "Pts"
	pts.position = Vector2(40, 56)
	pts.add_theme_color_override("font_color", UIKit.ACCENT)
	add_child(pts)
	var tip = UIKit.make_dim_label("一阶随转职自动学会；二阶需前置战技 + 战技点。冷却在战场回合中回复。")
	tip.position = Vector2(40, 88)
	add_child(tip)

	var left = UIKit.make_panel()
	left.position = Vector2(40, 120)
	left.custom_minimum_size = Vector2(420, 440)
	add_child(left)
	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", 8)
	left.add_child(_list)

	var right = UIKit.make_panel()
	right.position = Vector2(480, 120)
	right.custom_minimum_size = Vector2(760, 440)
	add_child(right)
	_detail = RichTextLabel.new()
	_detail.bbcode_enabled = true
	_detail.custom_minimum_size = Vector2(730, 410)
	_detail.add_theme_color_override("default_color", UIKit.TEXT)
	right.add_child(_detail)

	_msg = UIKit.make_label("")
	_msg.position = Vector2(40, 580)
	add_child(_msg)
	var back = UIKit.make_button(Locale.t("btn_back"), 120)
	back.position = Vector2(40, 640)
	back.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/hub/castle_hub.tscn"))
	add_child(back)
	_refresh_list()

func _refresh_list() -> void:
	for c in _list.get_children():
		c.queue_free()
	for ch in GameState.roster():
		var b = UIKit.make_button("%s　%s　已学%d" % [ch.name, GameState.get_job(ch.job_id).get("name",""), ch.skills.size()], 380)
		var captured = ch
		b.pressed.connect(func(): _show(captured))
		_list.add_child(b)
	if GameState.roster().size() > 0:
		_show(GameState.roster()[0])

func _show(c: CKCharacter) -> void:
	_selected = c
	var lines: Array = ["[b]%s[/b]　职业 %s" % [c.name, GameState.get_job(c.job_id).get("name","")], ""]
	for tree in GameState.data_skills.get("trees", []):
		lines.append("[color=#c9a227]%s[/color] — %s" % [tree.get("name"), tree.get("desc","")])
		for sk in GameState.data_skills.get("skills", []):
			if sk.get("tree") != tree.get("id"):
				continue
			if c.job_id not in sk.get("jobs", []):
				continue
			var sid = str(sk.get("id"))
			var owned = sid in c.skills or sid in c.unlocked_skills
			var mark = "✓" if owned else ("T%d" % int(sk.get("tier",1)))
			lines.append("　[%s] %s　冷却%d　%s" % [mark, sk.get("name"), int(sk.get("cooldown",1)), sk.get("desc","")])
	lines.append("")
	lines.append("[color=#c9a227]可解锁二阶：[/color]")
	var any := false
	for sk in GameState.data_skills.get("skills", []):
		if int(sk.get("tier", 1)) < 2:
			continue
		if c.job_id not in sk.get("jobs", []):
			continue
		var sid = str(sk.get("id"))
		var check = GameState.can_unlock_skill(c, sid)
		var tag = "可解锁" if check.get("ok") else str(check.get("msg"))
		lines.append("· %s — %s （%s）" % [sk.get("name"), sk.get("desc"), tag])
		any = true
		if check.get("ok"):
			# add unlock button below via deferred rebuild of action row
			pass
	if not any:
		lines.append("（当前职业暂无二阶，或已全部学会）")
	_detail.text = "\n".join(lines)
	# unlock buttons
	_rebuild_unlock_buttons(c)

func _rebuild_unlock_buttons(c: CKCharacter) -> void:
	# remove old unlock buttons
	for child in get_children():
		if str(child.name).begins_with("Unlock_"):
			child.queue_free()
	var x = 480
	var y = 560
	for sk in GameState.data_skills.get("skills", []):
		if int(sk.get("tier", 1)) < 2:
			continue
		if c.job_id not in sk.get("jobs", []):
			continue
		var sid = str(sk.get("id"))
		var check = GameState.can_unlock_skill(c, sid)
		var b = UIKit.make_accent_button("解锁·" + str(sk.get("name")), 180)
		b.name = "Unlock_" + sid
		b.position = Vector2(x, y)
		b.disabled = not check.get("ok")
		var captured = sid
		b.pressed.connect(func():
			var r = GameState.unlock_skill(_selected, captured)
			_msg.text = str(r.get("msg"))
			get_node("Pts").text = "可用战技点：%d（非教程胜仗 +1）" % GameState.skill_points
			Sfx.confirm()
			_show(_selected)
		)
		add_child(b)
		x += 190
		if x > 1100:
			x = 480
			y += 48
