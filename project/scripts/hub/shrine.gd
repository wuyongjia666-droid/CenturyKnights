extends Control
func _ready() -> void:
	UIKit.make_themed_bg(self, "shrine")
	if not UIKit.RETIRE_CHROME and ResourceLoader.exists("res://assets/art/ui/shrine_banner.png"):
		var _bn := TextureRect.new()
		_bn.texture = load("res://assets/art/ui/shrine_banner.png")
		_bn.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		_bn.stretch_mode = TextureRect.STRETCH_SCALE
		_bn.position = Vector2(0, 0)
		_bn.size = Vector2(1280, 52)
		_bn.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(_bn)
		UIFX.banner_shimmer(_bn, 3.8)
	UIFX.page_enter(self)
	UIFX.wire_tree(self)
	if not UIKit.RETIRE_CHROME and ResourceLoader.exists("res://assets/art/ui/hub_banner_strip.png"):
		var strip := TextureRect.new()
		strip.texture = load("res://assets/art/ui/hub_banner_strip.png")
		strip.position = Vector2(0, 0)
		strip.custom_minimum_size = Vector2(1280, 48)
		strip.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		strip.stretch_mode = TextureRect.STRETCH_SCALE
		strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(strip)

	var lv = GameState.building_level("shrine")
	var t = UIKit.make_label("祠堂", true); t.position = Vector2(40, 16); add_child(t)
	var tip = UIKit.make_dim_label("祠堂等级来自「工事」。丰收产出与祈愈随等级增强；香灰里有旧旗的味。")
	tip.position = Vector2(40, 56); tip.custom_minimum_size = Vector2(1000, 40); tip.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; add_child(tip)
	var msg = UIKit.make_label("当前等级：%d　（工事可升至 3）" % lv); msg.position = Vector2(40, 110); add_child(msg)
	var heal = UIKit.make_accent_button("祈愈（清临时伤）", 220); heal.position = Vector2(40, 170)
	heal.pressed.connect(func(): msg.text = GameState.heal_at_shrine() + "　Lv%d" % GameState.building_level("shrine")); add_child(heal)
	var works = UIKit.make_button("去工事升级祠堂", 200); works.position = Vector2(40, 230)
	works.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/hub/works.tscn")); add_child(works)
	var back = UIKit.make_button(Locale.t("btn_back")); back.position = Vector2(40, 300)
	back.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/hub/castle_hub.tscn")); add_child(back)
