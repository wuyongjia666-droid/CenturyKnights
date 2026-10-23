extends Node
## Y1-A #335 gap: nine speakers must resolve a plate path from cast tables
## (supporting + antagonists) even before farm art lands. Texture load is not
## required here — silhouette until ingest is expected.

const GAP := [
	"藤桥·新雨", "渡口·阿禾", "镜湖·护帖", "冷窑·收火",
	"冷湾·折弦", "碧潭·澜芷", "白垣·计勋", "南灯·欠盏", "观象·孤衡",
	"xinyu", "ahe", "hutie", "shouhuo",
	"zhexian", "lanzhi", "jixun", "qianzhan", "guheng",
]

func _ready() -> void:
	var err := _check()
	if err == "":
		print("Y1A GAP SPEAKER ROUTE PASS")
		get_tree().quit(0)
	else:
		print("FAIL ", err)
		get_tree().quit(1)


func _check() -> String:
	for key in GAP:
		var path := UnitArt.speaker_plate_path(key)
		if path == "":
			return "speaker_plate_path empty for %s" % key
		if not str(path).begins_with("res://assets/art/portraits/speakers/"):
			return "unexpected plate path for %s: %s" % [key, path]
		print("route %s -> %s" % [key, path])
	return ""
