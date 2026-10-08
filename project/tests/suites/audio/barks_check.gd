extends Node
## AUD-04：按性别和年龄段选呼喊；缺文件时静默。

func _ready() -> void:
	var err := _run()
	if err != "":
		print("FAIL barks: ", err)
		get_tree().quit(1)
	else:
		print("BARKS PASS")
		get_tree().quit(0)

func _run() -> String:
	if Sfx == null:
		return "autoloads not ready"
	var rule := _check_rules()
	if rule != "":
		return rule
	return _verify()

func _check_rules() -> String:
	if Sfx.bark_id("m", 14, "shout") != "bark_m_child_shout":
		return "child edge"
	if Sfx.bark_id("m", 15, "shout") != "bark_m_youth_shout":
		return "youth edge"
	if Sfx.bark_id("f", 29, "breath") != "bark_f_youth_breath":
		return "youth top"
	if Sfx.bark_id("f", 30, "breath") != "bark_f_adult_breath":
		return "adult edge"
	if Sfx.bark_id("m", 54, "shout") != "bark_m_adult_shout":
		return "adult top"
	if Sfx.bark_id("f", 55, "breath") != "bark_f_elder_breath":
		return "elder edge"
	if Sfx.bark_id("x", 40, "shout") != "":
		return "bad gender"
	if Sfx.bark_id("m", 40, "sing") != "":
		return "bad kind"
	if Sfx.play_bark_id("bark_not_in_the_set"):
		return "missing file should stay silent"
	var played := Sfx.play_bark_id("bark_m_adult_shout")
	if not played:
		return "adult shout missing"
	var player := Sfx.get_node_or_null("bark_m_adult_shout") as AudioStreamPlayer
	if player == null or not player.playing or player.bus != "SFX":
		return "shout player"
	Sfx.play_bark("f", 10, "breath")
	var breath := Sfx.get_node_or_null("bark_f_child_breath") as AudioStreamPlayer
	if breath == null or not breath.playing:
		return "child breath"
	if not Sfx.has_method("hit") or Sfx.get_node_or_null("hit") == null:
		return "old api"
	Sfx.hit()
	return ""

func _verify() -> String:
	var project := ProjectSettings.globalize_path("res://")
	var script := project.path_join("../tools/audio/barks_v92.py")
	var output: Array = []
	var code := OS.execute("python3", [script, "--verify"], output, true)
	var text := ""
	for line in output:
		text += str(line)
	if code != 0 or text.find("BARK VERIFY PASS") < 0:
		return "verify failed (%d) %s" % [code, text.right(400)]
	output = []
	var loud := project.path_join("../tools/audio/loudness_check.py")
	code = OS.execute("python3", [loud], output, true)
	text = ""
	for line in output:
		text += str(line)
	if code != 0 or text.find("LOUDNESS PASS") < 0:
		return "loudness failed (%d) %s" % [code, text.right(400)]
	return ""
