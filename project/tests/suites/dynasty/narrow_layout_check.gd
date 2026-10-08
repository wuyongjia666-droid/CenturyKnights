extends Node
## Narrow viewports: dynasty hub controls stay inside the window and do not cover each other.

const SIZES := [
	Vector2i(1280, 720),
	Vector2i(960, 540),
	Vector2i(2400, 1080),
]
const SCENES := [
	"res://scenes/hub/bloodline_codex.tscn",
	"res://scenes/hub/marriage.tscn",
	"res://scenes/hub/rival_houses.tscn",
]

var _fails: Array = []

func _ready() -> void:
	await get_tree().process_frame
	GameState.new_game("烬行", "灰旗", "frost")
	var win := get_tree().root
	win.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	for size in SIZES:
		win.size = size
		await get_tree().process_frame
		for path in SCENES:
			await _scene(path, size)
	if _fails.is_empty():
		print("NARROW LAYOUT PASS")
		get_tree().quit(0)
		return
	for f in _fails:
		print("FAIL narrow: ", f)
	get_tree().quit(1)

func _scene(path: String, size: Vector2i) -> void:
	var packed = load(path)
	if packed == null:
		_fails.append("load %s" % path)
		return
	var n: Control = packed.instantiate()
	get_tree().root.add_child(n)
	n.set_anchors_preset(Control.PRESET_TOP_LEFT)
	n.position = Vector2.ZERO
	n.size = Vector2(size)
	for _i in 3:
		await get_tree().process_frame
	if n.has_method("apply_mobile_layout"):
		n.apply_mobile_layout()
	for _j in 2:
		await get_tree().process_frame
	_audit(path.get_file(), size, n)
	_named(path.get_file(), size, n)
	n.queue_free()
	await get_tree().process_frame

func _audit(tag: String, size: Vector2i, scene: Control) -> void:
	var vp := Rect2(Vector2.ZERO, Vector2(size)).grow(1.0)
	var nodes: Array = []
	for c in scene.find_children("*", "Control", true, false):
		var ctrl := c as Control
		if not _counts(ctrl):
			continue
		nodes.append(ctrl)
	for i in nodes.size():
		var a: Control = nodes[i]
		var ra := _vis(a)
		if ra.size.x < 2.0 or ra.size.y < 2.0:
			continue
		if not vp.encloses(ra):
			_fails.append("%s @%s overflow %s %s" % [tag, size, a.name, ra])
		for j in range(i + 1, nodes.size()):
			var b: Control = nodes[j]
			if _anc(a, b) or _anc(b, a):
				continue
			var rb := _vis(b)
			if rb.size.x < 2.0 or rb.size.y < 2.0:
				continue
			if not ra.intersects(rb):
				continue
			var hit := ra.intersection(rb)
			if hit.size.x <= 2.0 or hit.size.y <= 2.0:
				continue
			_fails.append("%s @%s overlap %s x %s %s" % [tag, size, a.name, b.name, hit.size])

func _named(tag: String, size: Vector2i, scene: Control) -> void:
	if tag.begins_with("bloodline"):
		var rail := scene.find_child("NationRailPanel", true, false) as Control
		var body := scene.find_child("CodexBody", true, false) as Control
		_apart(tag, size, rail, body)
		for nm in scene.find_children("NationName", "Label", true, false):
			var lab := nm as Label
			if lab.text_overrun_behavior != TextServer.OVERRUN_TRIM_ELLIPSIS:
				_fails.append("%s nation name missing ellipsis" % tag)
			if rail and _vis(lab).size.x > 1.0 and not _vis(rail).grow(1.0).encloses(_vis(lab)):
				_fails.append("%s nation name leaves the rail %s" % [tag, lab.text])
	elif tag.begins_with("marriage"):
		_apart(tag, size, scene.find_child("HeirPreview", true, false) as Control, scene.find_child("RiteExplain", true, false) as Control)
	elif tag.begins_with("rival"):
		var detail := scene.find_child("RivalDetail", true, false) as Control
		_apart(tag, size, scene.find_child("RivalList", true, false) as Control, detail)
		if detail == null or detail.mouse_filter != Control.MOUSE_FILTER_STOP:
			_fails.append("%s detail does not swallow input" % tag)
		var fill := scene.find_child("FrostFill", true, false) as ColorRect
		if fill == null or fill.color.a < 0.9:
			_fails.append("%s frost fill is not opaque" % tag)

func _apart(tag: String, size: Vector2i, a: Control, b: Control) -> void:
	if a == null or b == null:
		_fails.append("%s @%s missing pair" % [tag, size])
		return
	var ra := _vis(a)
	var rb := _vis(b)
	if ra.intersects(rb):
		var hit := ra.intersection(rb)
		if hit.size.x > 2.0 and hit.size.y > 2.0:
			_fails.append("%s @%s %s covers %s" % [tag, size, a.name, b.name])

func _counts(ctrl: Control) -> bool:
	if ctrl == null or not ctrl.is_visible_in_tree():
		return false
	if ctrl.size.x < 8.0 or ctrl.size.y < 8.0:
		return false
	if ctrl.mouse_filter == Control.MOUSE_FILTER_IGNORE:
		return false
	if ctrl is ColorRect or ctrl is TextureRect:
		return false
	return true

func _vis(c: Control) -> Rect2:
	var r := c.get_global_rect()
	var p := c.get_parent()
	while p:
		if p is ScrollContainer or (p is Control and (p as Control).clip_contents):
			r = r.intersection((p as Control).get_global_rect())
		p = p.get_parent()
	return r

func _anc(a: Node, b: Node) -> bool:
	var p := b.get_parent()
	while p:
		if p == a:
			return true
		p = p.get_parent()
	return false
