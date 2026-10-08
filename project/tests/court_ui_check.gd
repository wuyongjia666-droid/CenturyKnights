extends Node
## Headless load + layout for the v8.9/v9.0 court screens.
## Does not roll genetics, place bids, or promote.

var _fails: Array = []

func _ready() -> void:
	await get_tree().process_frame
	GameState.new_game("烬行", "灰旗", "#c9a227")
	_safe_area()
	await _scene("res://scenes/hub/bloodline_codex.tscn", ["NationRail", "CodexBody", "RoyalSkill", "LineScroll"], ["Nation_ashbanner"])
	await _scene("res://scenes/hub/unit_dossier.tscn", ["PortraitColumn", "AgeStage", "TitleChip", "PurityBar", "TraitList", "FamilyTree", "OpenCodex"], ["OpenCodex"])
	await _scene("res://scenes/hub/blood_test.tscn", ["AssayQueue", "RevealStage", "BeginReveal"], ["BeginReveal"])
	await _scene("res://scenes/hub/marriage.tscn", ["RiteBoard", "PunnettBoard"], [])
	await _scene("res://scenes/hub/court_news.tscn", ["FilterBar", "NewsList", "FilterAll", "FilterBirth", "FilterDeath", "FilterSuccession", "FilterMarriage", "FilterRecall"], ["FilterAll", "FilterBirth", "FilterDeath", "FilterSuccession", "FilterMarriage", "FilterRecall"])
	await _scene("res://scenes/hub/title_promote.tscn", ["Ladder", "PromoteTitle", "ReqMerit"], ["PromoteTitle"])
	_lamp_and_promote()
	if _fails.is_empty():
		print("COURT UI PASS")
		get_tree().quit(0)
	else:
		for f in _fails:
			print("FAIL court ui: ", f)
		get_tree().quit(1)

func _ok(cond: bool, msg: String) -> void:
	if not cond:
		_fails.append(msg)

func _safe_area() -> void:
	var insets := {"left": 0.0, "top": 84.0, "right": 0.0, "bottom": 96.0}
	var fit := MobileLayout.fit(Vector2(1080, 2400), insets)
	var pos: Vector2 = fit.get("position", Vector2(-1, -1))
	var scale := float(fit.get("scale", 0.0))
	_ok(pos.y >= 84.0 - 0.5, "portrait safe top %s" % pos)
	_ok(pos.x >= -0.5, "portrait safe left %s" % pos)
	_ok(scale > 0.2 and scale <= 1.0, "portrait scale %s" % scale)
	_ok(pos.y + 720.0 * scale <= 2400.0 - 96.0 + 1.0, "portrait safe bottom")
	var land := MobileLayout.fit(Vector2(2400, 1080), {"left": 64.0, "top": 0.0, "right": 48.0, "bottom": 24.0})
	var lp: Vector2 = land.get("position", Vector2.ZERO)
	_ok(lp.x >= 64.0 - 0.5, "landscape safe left %s" % lp)
	_ok(lp.y + 720.0 * float(land.get("scale", 1.0)) <= 1080.0 - 24.0 + 1.0, "landscape safe bottom")

func _scene(path: String, names: Array, tall: Array) -> void:
	var packed = load(path)
	_ok(packed != null, "load " + path)
	if packed == null:
		return
	var n: Node = packed.instantiate()
	_ok(n != null, "instantiate " + path)
	if n == null:
		return
	get_tree().root.add_child(n)
	for _i in 4:
		await get_tree().process_frame
	for nm in names:
		_ok(n.find_child(str(nm), true, false) != null or str(n.name) == str(nm), "%s missing %s" % [path, nm])
	for nm2 in tall:
		var b := n.find_child(str(nm2), true, false) as Control
		_ok(b != null, "%s missing target %s" % [path, nm2])
		if b == null:
			continue
		var h := b.custom_minimum_size.y
		if h < 1.0:
			h = b.size.y
		_ok(h >= 44.0, "%s %s target %s < 44" % [path, nm2, h])
	_bounds(n, path)
	_label_overlap(n, path)
	if path.ends_with("bloodline_codex.tscn"):
		_codex_marks(n)
	if path.ends_with("marriage.tscn"):
		_marriage_footer(n)
	if path.ends_with("court_news.tscn"):
		var birth := n.find_child("FilterBirth", true, false) as Button
		if birth:
			birth.pressed.emit()
			await get_tree().process_frame
			_ok(n.find_child("NewsList", true, false) != null, "news list survives filter")
	if path.ends_with("bloodline_codex.tscn"):
		var rail := n.find_child("NationRail", true, false)
		_ok(rail != null and rail.get_child_count() >= 10, "codex nation count")
	var fit := MobileLayout.fit(Vector2(1080, 2400), {"top": 84.0, "bottom": 96.0, "left": 0.0, "right": 0.0})
	if n is Control:
		MobileLayout.apply_root(n, fit)
		_ok((n as Control).position.y >= 84.0 - 0.5, "%s safe-area pin %s" % [path, (n as Control).position])
		await get_tree().process_frame
		_label_overlap(n, path + " @safe")
	n.queue_free()
	await get_tree().process_frame

func _bounds(scene: Node, path: String) -> void:
	for c in scene.find_children("*", "Control", true, false):
		if _in_scroll(c) or not (c as CanvasItem).visible:
			continue
		var ctrl := c as Control
		if ctrl.size.x < 8.0 or ctrl.size.y < 8.0:
			continue
		var gp := ctrl.global_position
		if gp.x < -24.0 or gp.y < -24.0 or gp.x > 1304.0 or gp.y > 744.0:
			_fails.append("%s off canvas %s at %s" % [path, ctrl.name, gp])

func _codex_marks(scene: Node) -> void:
	var glyphs := ["功", "剂", "槛", "显", "隐", "父", "女", "六", "合", "母", "龄", "纯"]
	var rail := scene.find_child("NationRail", true, false)
	_ok(rail != null, "codex rail")
	if rail == null:
		return
	var emblems := rail.find_children("NationEmblem", "", true, false)
	_ok(emblems.size() >= 10, "nation emblems %d" % emblems.size())
	for b in rail.get_children():
		if not (b is Button):
			continue
		_ok(str((b as Button).text).strip_edges() == "", "nation button keeps a law glyph in its caption")
		for lab in b.find_children("*", "Label", true, false):
			if str(lab.name) == "NationName":
				_ok(str(lab.text).strip_edges().length() >= 2, "nation name")
				continue
			_ok(not glyphs.has(str(lab.text).strip_edges()), "nation list uses law glyph %s" % lab.text)
	var sils := scene.find_children("TraitSilhouette", "", true, false)
	_ok(not sils.is_empty(), "unknown traits are silhouettes")
	for sil in sils:
		var leaked := false
		for lab in sil.find_children("*", "Label", true, false):
			var tx := str(lab.text).strip_edges()
			if tx == "未识征" or (tx != "" and not glyphs.has(tx)):
				leaked = true
		_ok(not leaked, "silhouette shows a trait name")
	for known in scene.find_children("TraitKnown", "", true, false):
		var named := false
		for lab2 in known.find_children("*", "Label", true, false):
			var tx2 := str(lab2.text).strip_edges()
			if tx2.length() > 1 and not glyphs.has(tx2):
				named = true
		_ok(named, "known trait has no name")

func _marriage_footer(scene: Node) -> void:
	var ages := scene.find_children("AgeLine", "", true, false)
	var caps := scene.find_children("PedigreeCaption", "", true, false)
	_ok(ages.size() >= 2 and caps.size() >= 2, "marriage cards name the age and the pedigree")
	for age in ages:
		var ar := _visual_rect(age as Label)
		for cap in caps:
			var cr := _visual_rect(cap as Label)
			if not ar.intersects(cr):
				continue
			var hit := ar.intersection(cr)
			_ok(hit.size.x <= 2.0 or hit.size.y <= 2.0, "age overlaps pedigree %s" % hit)

func _label_overlap(scene: Node, path: String) -> void:
	var labels: Array = []
	for n in scene.find_children("*", "Label", true, false):
		var l := n as Label
		if l == null or not l.is_visible_in_tree():
			continue
		if str(l.text).strip_edges() == "":
			continue
		labels.append(l)
	for i in labels.size():
		var a: Label = labels[i]
		var ra := _visual_rect(a)
		if ra.size.x < 2.0 or ra.size.y < 2.0:
			continue
		_clipped(a, path)
		for j in range(i + 1, labels.size()):
			var b: Label = labels[j]
			if _ancestor(a, b) or _ancestor(b, a):
				continue
			var rb := _visual_rect(b)
			if rb.size.x < 2.0 or rb.size.y < 2.0:
				continue
			if not ra.intersects(rb):
				continue
			var hit := ra.intersection(rb)
			if hit.size.x <= 2.0 or hit.size.y <= 2.0:
				continue
			_fails.append("%s label overlap «%s» × «%s»" % [path, _snip(a), _snip(b)])

func _clipped(l: Label, path: String) -> void:
	if l.clip_text and l.autowrap_mode == TextServer.AUTOWRAP_OFF:
		var need_w := l.get_minimum_size().x
		if l.size.x > 8.0 and need_w > l.size.x + 8.0:
			_fails.append("%s clipped «%s»" % [path, _snip(l)])

func _visual_rect(l: Label) -> Rect2:
	## Painted glyphs inside the label. Noto's line box is 3em and only the middle em is ink,
	## so empty leading above and below a control is not treated as a collision. Horizontal
	## overflow is included when the label does not clip. Checked on the 1280x720 design
	## and again after the mobile safe-area scale.
	var r := l.get_global_rect()
	var fs := float(l.get_theme_font_size("font_size"))
	if fs < 1.0:
		fs = 15.0
	var sc := l.get_global_transform().get_scale().abs()
	var em := fs * sc.y
	var line := em * 3.0
	var lines := 1
	if l.autowrap_mode != TextServer.AUTOWRAP_OFF and r.size.y > line * 1.2:
		lines = maxi(1, int(round(r.size.y / line)))
	var block := line * float(lines)
	var top := r.position.y
	if l.vertical_alignment == VERTICAL_ALIGNMENT_CENTER:
		top += maxf(0.0, (r.size.y - block) * 0.5)
	elif l.vertical_alignment == VERTICAL_ALIGNMENT_BOTTOM:
		top += maxf(0.0, r.size.y - block)
	var ink := Rect2(r.position.x, top + em, r.size.x, em * float(lines))
	if not l.clip_text and l.autowrap_mode == TextServer.AUTOWRAP_OFF:
		var need_w := l.get_minimum_size().x * sc.x
		if need_w > ink.size.x + 1.0:
			var extra := need_w - ink.size.x
			if l.horizontal_alignment == HORIZONTAL_ALIGNMENT_CENTER:
				ink.position.x -= extra * 0.5
			elif l.horizontal_alignment == HORIZONTAL_ALIGNMENT_RIGHT:
				ink.position.x -= extra
			ink.size.x = need_w
	if l.clip_text:
		ink = ink.intersection(r)
		if ink.size.x < 0.0:
			ink.size = Vector2.ZERO
	return ink

func _card_of(n: Node) -> Node:
	var p := n.get_parent()
	while p:
		if p is Panel or p is PanelContainer:
			return p
		p = p.get_parent()
	var scene := n
	while scene.get_parent() and scene.get_parent() != n.get_tree().root:
		scene = scene.get_parent()
	return scene

func _ancestor(a: Node, b: Node) -> bool:
	var p := b.get_parent()
	while p:
		if p == a:
			return true
		p = p.get_parent()
	return false

func _snip(l: Label) -> String:
	var t := str(l.text).replace("\n", " ")
	if t.length() > 18:
		t = t.substr(0, 18)
	return t

func _in_scroll(n: Node) -> bool:
	var p := n.get_parent()
	while p:
		if p is ScrollContainer:
			return true
		p = p.get_parent()
	return false

func _lamp_and_promote() -> void:
	var host := Control.new()
	get_tree().root.add_child(host)
	var who := CKCharacter.new()
	who.blood_mix = {"common_ash": 1.0}
	who.rank = "knight"
	var board := CKCourt.lamp_board(who, 40, 2)
	CKCourt.build_lamp_ui(host, board, func(_amount: int) -> void: pass)
	var timeline := host.find_child("BidTimeline", true, false)
	_ok(timeline != null, "lamp bid timeline")
	var baron := host.find_child("LampBidBaron", true, false) as Button
	var count := host.find_child("LampBidCount", true, false) as Button
	_ok(baron != null and baron.custom_minimum_size.y >= 44.0, "baron bid target")
	_ok(count != null and count.custom_minimum_size.y >= 44.0, "count bid target")
	CKCourt.build_promote_ui(host, who, {"merit": 1, "fiefs": 0, "married": false, "rep": 2}, func() -> void: pass)
	var req := host.find_child("ReqMerit", true, false)
	_ok(req != null, "promote progress row")
	var btn := host.find_child("PromoteTitle", true, false) as Button
	_ok(btn != null and btn.disabled, "short ladder stays shut")
	host.queue_free()
