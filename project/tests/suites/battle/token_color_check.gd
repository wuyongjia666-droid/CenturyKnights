extends Node
## BTL-13: battle log and forecast colors follow the UX-02 colorblind palette.


func _ready() -> void:
	if not _palette_moves_the_log():
		_fail("log color ignored colorblind")
		return
	if not _forecast_title_follows():
		_fail("forecast title ignored colorblind")
		return
	print("TOKEN PASS")
	get_tree().quit(0)


func _palette_moves_the_log() -> bool:
	GameState.settings["colorblind"] = "none"
	var plain := Frost.swatch("enemy").to_html(false)
	GameState.settings["colorblind"] = "deuteranopia"
	var shifted := Frost.swatch("enemy").to_html(false)
	if plain == shifted:
		return false
	var note := BattleRules.engagement_note(true, false, false, false)
	if not note.contains(shifted):
		return false
	if note.contains(plain):
		return false
	GameState.settings["colorblind"] = "none"
	var ally := Frost.swatch("ally").to_html(false)
	var free_note := BattleRules.engagement_note(false, false, true, false)
	return free_note.contains(ally)


func _forecast_title_follows() -> bool:
	GameState.settings["colorblind"] = "deuteranopia"
	var box := VBoxContainer.new()
	var title := Label.new()
	title.name = "Title"
	var body := Label.new()
	body.name = "Body"
	box.add_child(title)
	box.add_child(body)
	add_child(box)
	var info := {"counter": false}
	ForecastPanel._fill(box, "theirs", info, true)
	var got: Color = title.get_theme_color("font_color")
	return got.to_html(false) == Frost.swatch("enemy").to_html(false)


func _fail(msg: String) -> void:
	push_error(msg)
	print("TOKEN FAIL %s" % msg)
	get_tree().quit(1)
