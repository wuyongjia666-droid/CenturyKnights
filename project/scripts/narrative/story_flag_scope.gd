extends RefCounted
## 内容季中途战旗按章隔离。
## cs01_01 与 cs01_02 的 JSON 都挂季级 cs01_mid_fought / cs01_mid_lost。
## 同一存档里打完第一章后，裸旗会把第二章的「先试一锋」藏掉，胜后台词还会提前出现。
## 裸旗仍写入 story.flags（既有协议测试读裸旗）；章节播放器只认「章 id#旗」这一份。

const _FOUGHT := "_mid_fought"
const _LOST := "_mid_lost"


static func is_chapter_battle_flag(flag: String) -> bool:
	var tail := ""
	if flag.ends_with(_FOUGHT):
		tail = _FOUGHT
	elif flag.ends_with(_LOST):
		tail = _LOST
	else:
		return false
	var head := flag.substr(0, flag.length() - tail.length())
	if not head.begins_with("cs"):
		return false
	var digits := head.substr(2)
	return digits != "" and digits.is_valid_int()


static func scoped_key(chapter_id: String, flag: String) -> String:
	return "%s#%s" % [chapter_id, flag]


## 本章打过才记。章 id 不是内容季、或旗不是中途战旗时不动。
static func note(chapter_id: String, flag: String, val: bool) -> void:
	if not StoryCatalog.is_content_season_id(chapter_id):
		return
	if not is_chapter_battle_flag(flag):
		return
	GameState.set_flag(scoped_key(chapter_id, flag), val)


## 播放器里的 when。本章有记录用本章；别章写过则本章视为未打；都没有才回退裸旗。
static func seen(flag: String) -> bool:
	if not is_chapter_battle_flag(flag):
		return GameState.flag(flag)
	var chapter_id := str(GameState.get_meta("story_flag_chapter", ""))
	if not StoryCatalog.is_content_season_id(chapter_id):
		return GameState.flag(flag)
	var key := scoped_key(chapter_id, flag)
	if GameState.story.flags.has(key):
		return bool(GameState.story.flags[key])
	if _sibling_wrote(chapter_id, flag):
		return false
	return GameState.flag(flag)


static func _sibling_wrote(chapter_id: String, flag: String) -> bool:
	var mine := scoped_key(chapter_id, flag)
	var suffix := "#" + flag
	for k in GameState.story.flags.keys():
		var ks := str(k)
		if ks == mine:
			continue
		if ks.ends_with(suffix):
			return true
	return false
