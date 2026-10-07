extends Control
var _msg: Label
func _ready() -> void:
	UIKit.make_themed_bg(self, "forge")
	if ResourceLoader.exists("res://assets/art/ui/forge_banner.png"):
		var _bn := TextureRect.new()
		_bn.texture = load("res://assets/art/ui/forge_banner.png")
		_bn.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		_bn.stretch_mode = TextureRect.STRETCH_SCALE
		_bn.position = Vector2(0, 0)
		_bn.size = Vector2(1280, 52)
		_bn.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(_bn)
		UIFX.banner_shimmer(_bn, 3.8)
	UIFX.page_enter(self)
	UIFX.wire_tree(self)
	var t = UIKit.make_label("炉火工坊", true); t.position = Vector2(40, 16); add_child(t)
	var tip = UIKit.make_dim_label("打造灰刃：需 2 铁 + 20 银，装备后攻击 +2。炉火映着旗色。")
	tip.position = Vector2(40, 56); add_child(tip)
	var vb := VBoxContainer.new(); vb.position = Vector2(40, 100); vb.add_theme_constant_override("separation", 8); add_child(vb)
	for c in GameState.roster():
		var row := HBoxContainer.new(); row.add_theme_constant_override("separation", 10); vb.add_child(row)
		row.add_child(UIKit.make_portrait_rect(c, 48))
		var b = UIKit.make_button("为 %s 打造" % c.name, 280)
		var cid = c.id
		b.pressed.connect(func():
			var r = GameState.craft_weapon(cid)
			_msg.text = str(r.get("msg"))
		)
		row.add_child(b)
	_msg = UIKit.make_label(""); _msg.position = Vector2(40, 500); add_child(_msg)
	var heir = UIKit.make_dim_label(Locale.t("heirloom_preview")); heir.position = Vector2(40, 560); add_child(heir)
	var back = UIKit.make_button(Locale.t("btn_back")); back.position = Vector2(40, 620)
	back.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/hub/castle_hub.tscn")); add_child(back)
