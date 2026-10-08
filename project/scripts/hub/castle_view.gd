extends Control
## CMP-03. Nine buildings, three silhouette tiers. Frost palette only.
## Hub embedding stays with the UX stream; works opens this scene.

const SLOTS := ["hall", "barracks", "market", "forge", "shrine", "infirmary", "academy", "treasury", "embassy"]

var _layer: Node2D
var _msg: Label

func _ready() -> void:
	UIKit.void_bg(self)
	_layer = Node2D.new()
	_layer.name = "Silhouettes"
	add_child(_layer)
	_build()
	refresh()
	var back := UIKit.ghost_button(Locale.t("castle_view_back"), 140, 36)
	back.position = Vector2(24, 24)
	back.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/hub/works.tscn"))
	add_child(back)
	_msg = UIKit.body_label("", UIKit.TEXT_DIM, 12)
	_msg.position = Vector2(180, 28)
	_msg.size = Vector2(700, 28)
	add_child(_msg)
	_annex_buttons()

func _annex_buttons() -> void:
	var x := 48.0
	for id in CKCastleServices.ANNEX.keys():
		var annex_id := str(id)
		var b := UIKit.ghost_button(Locale.t(str(CKCastleServices.ANNEX[annex_id])), 140, 36)
		b.position = Vector2(x, 520)
		b.pressed.connect(func():
			var r: Dictionary = CKCastleServices.upgrade_annex(GameState, annex_id)
			_msg.text = str(r.get("msg", ""))
			refresh())
		add_child(b)
		x += 152.0

func _build() -> void:
	for i in SLOTS.size():
		var id := str(SLOTS[i])
		for tier in [1, 2, 3]:
			var poly := Polygon2D.new()
			poly.name = "sil_%s_%d" % [id, tier]
			poly.color = _frost(id)
			poly.polygon = _shape(i, tier)
			poly.visible = false
			_layer.add_child(poly)

func _frost(id: String) -> Color:
	match id:
		"hall":
			return UIKit.ACCENT
		"barracks":
			return UIKit.TEXT
		"market":
			return UIKit.OK
		"forge":
			return UIKit.TEXT_DIM
		"shrine":
			return UIKit.ACCENT_DIM
		"infirmary":
			return UIKit.OK
		"academy":
			return UIKit.TEXT
		"treasury":
			return UIKit.ACCENT
		_:
			return UIKit.STONE

func _shape(slot: int, tier: int) -> PackedVector2Array:
	var x := 48.0 + float(slot) * 96.0
	var base_y := 460.0
	var h := 36.0 + float(tier) * 38.0
	var w := 28.0 + float(tier) * 8.0
	return PackedVector2Array([
		Vector2(x, base_y),
		Vector2(x + w * 0.35, base_y - h),
		Vector2(x + w * 0.7, base_y - h * 0.62),
		Vector2(x + w, base_y),
	])

func level_of(id: String) -> int:
	if CKCastleServices.ANNEX.has(id):
		return CKCastleServices.annex_level(GameState, id)
	return GameState.building_level(id)

func refresh() -> void:
	for id in SLOTS:
		var show_tier := CKCastleServices.tier_of(level_of(str(id)))
		for tier in [1, 2, 3]:
			var node := _layer.get_node_or_null("sil_%s_%d" % [id, tier]) as Polygon2D
			if node:
				node.visible = tier == show_tier

func layer_visible(id: String, tier: int) -> bool:
	var node := _layer.get_node_or_null("sil_%s_%d" % [id, tier]) as Polygon2D
	return node != null and node.visible

func _unhandled_input(e: InputEvent) -> void:
	if e.is_action_pressed("ui_cancel"):
		get_tree().change_scene_to_file("res://scenes/hub/works.tscn")
