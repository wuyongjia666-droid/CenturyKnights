extends Node
## UX-04：NotoSansSC-*-ck.otf 必须覆盖数据与脚本字面量里的字符。
## 缺字时打印缺失字符，并给出 python3 tools/fonts/subset_fonts_v86.py。
## Noto CJK 源字库本身没有的符号记在 SOURCE_GAP，不把现有 hub 文案卡死。

const REBUILD := "python3 tools/fonts/subset_fonts_v86.py"
const FONTS := [
	"res://assets/fonts/NotoSansSC-Regular-ck.otf",
	"res://assets/fonts/NotoSansSC-Bold-ck.otf",
]
## 这些码位不在 Noto Sans CJK SC 里，子集脚本无法补上。新汉字不在此列。
const SOURCE_GAP := {
	0x2009: "细空格，Noto CJK SC 无此字",
	0x21BB: "顺时针箭头，Noto CJK SC 无此字",
	0x21E2: "虚线箭头，Noto CJK SC 无此字",
	0x25AE: "黑竖矩形，Noto CJK SC 无此字",
	0x25AF: "白竖矩形，Noto CJK SC 无此字",
	0x25C8: "双钻石，Noto CJK SC 无此字",
	0x2694: "交叉剑，Noto CJK SC 无此字",
	0x26D3: "锁链，Noto CJK SC 无此字",
	0x26F5: "帆船，Noto CJK SC 无此字",
	0x1F512: "锁形表情，超出 CJK 子集 cmap",
}
const PROBE := 0x3400

var _fails: Array = []

func _ready() -> void:
	var covered := _intersection()
	if covered.is_empty():
		_fails.append("cmap empty")
	var found := _scan_project(covered)
	var probe_on := OS.get_environment("CK_GLYPH_PROBE") == "1"
	if probe_on:
		found[PROBE] = ["res://data/probe.json"]
	if probe_on or not found.is_empty():
		for line in _report(found):
			print(line)
		print(REBUILD)
		print("GLYPH FAIL")
		_quit(1)
		return
	var injected := {PROBE: ["res://data/probe.json"]}
	var report := "\n".join(_report(injected))
	var probe_ch := String.chr(PROBE)
	if not report.contains(probe_ch) or not report.contains("U+3400") or not REBUILD.contains("subset_fonts_v86.py"):
		_fails.append("negative path did not name the missing glyph")
	else:
		print("GLYPH NEGATIVE PASS U+3400")
	if _fails.is_empty():
		print("GLYPH PASS")
		_quit(0)
	else:
		for f in _fails:
			print("FAIL glyph: ", f)
		_quit(1)

func _quit(code: int) -> void:
	var tree := Engine.get_main_loop() as SceneTree
	tree.quit(code)

func _scan_project(covered: Dictionary) -> Dictionary:
	var missing := {}
	var jsons: Array = []
	_walk("res://data", ".json", jsons)
	for path in jsons:
		_consider(_read(path), path, covered, missing, false)
	var dir := DirAccess.open("res://data/locale")
	if dir:
		dir.list_dir_begin()
		var name := dir.get_next()
		while name != "":
			if name.ends_with(".csv"):
				var path := "res://data/locale".path_join(name)
				_consider(_read(path), path, covered, missing, false)
			name = dir.get_next()
		dir.list_dir_end()
	var scripts: Array = []
	_walk("res://", ".gd", scripts)
	for path in scripts:
		if ".godot" in path:
			continue
		for lit in _literals(_read(path)):
			_consider(lit, path, covered, missing, true)
	return missing

func _consider(text: String, path: String, covered: Dictionary, missing: Dictionary, _literal: bool) -> void:
	for i in text.length():
		var cp := text.unicode_at(i)
		if cp < 32:
			continue
		if covered.has(cp) or SOURCE_GAP.has(cp):
			continue
		if not missing.has(cp):
			missing[cp] = []
		var locs: Array = missing[cp]
		if locs.size() < 4 and not locs.has(path):
			locs.append(path)
			missing[cp] = locs

func _report(missing: Dictionary) -> PackedStringArray:
	var lines: PackedStringArray = []
	var keys: Array = missing.keys()
	keys.sort()
	for cp in keys:
		var ch := String.chr(int(cp))
		lines.append("MISSING U+%04X %s" % [int(cp), ch])
		for path in missing[cp]:
			lines.append("  %s" % path)
	return lines

func _intersection() -> Dictionary:
	var shared: Dictionary = {}
	var first := true
	for path in FONTS:
		var one := _cmap(path)
		if first:
			shared = one
			first = false
		else:
			var next := {}
			for cp in shared.keys():
				if one.has(cp):
					next[cp] = true
			shared = next
	print("GLYPH cmap %d" % shared.size())
	return shared

func _cmap(path: String) -> Dictionary:
	var out := {}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		_fails.append("open " + path)
		return out
	var data := file.get_buffer(file.get_length())
	file.close()
	var num := _u16(data, 4)
	var cmap_off := -1
	for i in num:
		var off := 12 + i * 16
		var tag := data.slice(off, off + 4).get_string_from_ascii()
		if tag == "cmap":
			cmap_off = _u32(data, off + 8)
	if cmap_off < 0:
		_fails.append("no cmap " + path)
		return out
	var nsub := _u16(data, cmap_off + 2)
	for i in nsub:
		var rec := cmap_off + 4 + i * 8
		var sub := cmap_off + _u32(data, rec + 4)
		if _u16(data, sub) != 4:
			continue
		var seg := int(_u16(data, sub + 6) / 2)
		var end := sub + 14
		for s in seg:
			var end_cp := _u16(data, end + s * 2)
			var start_cp := _u16(data, end + seg * 2 + 2 + s * 2)
			var delta_raw := _u16(data, end + seg * 4 + 2 + s * 2)
			var delta := delta_raw if delta_raw < 32768 else delta_raw - 65536
			var range_off := _u16(data, end + seg * 6 + 2 + s * 2)
			var range_pos := end + seg * 6 + 2
			for cp in range(start_cp, end_cp + 1):
				if cp == 0xFFFF:
					continue
				var gid := 0
				if range_off == 0:
					gid = (cp + delta) & 0xFFFF
				else:
					var glyph_off := range_pos + s * 2 + range_off + (cp - start_cp) * 2
					if glyph_off + 1 < data.size():
						gid = _u16(data, glyph_off)
						if gid != 0:
							gid = (gid + delta) & 0xFFFF
				if gid != 0:
					out[cp] = true
	return out

func _literals(src: String) -> PackedStringArray:
	var out: PackedStringArray = []
	var i := 0
	var n := src.length()
	while i < n:
		var c := src.substr(i, 1)
		if c == "#":
			while i < n and src.substr(i, 1) != "\n":
				i += 1
			continue
		if c == "\"" or c == "'":
			var q := c
			i += 1
			var buf := ""
			while i < n:
				var d := src.substr(i, 1)
				if d == "\\":
					if i + 1 < n:
						var e := src.substr(i + 1, 1)
						if e == "u" and i + 5 < n:
							var hex := src.substr(i + 2, 4)
							if hex.is_valid_hex_number():
								buf += String.chr(hex.hex_to_int())
								i += 6
								continue
						buf += e
						i += 2
						continue
				if d == q:
					i += 1
					break
				if d == "\n":
					break
				buf += d
				i += 1
			out.append(buf)
			continue
		i += 1
	return out

func _walk(dir_path: String, suffix: String, into: Array) -> void:
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return
	dir.list_dir_begin()
	var name := dir.get_next()
	while name != "":
		if not name.begins_with("."):
			var full := dir_path.path_join(name)
			if dir.current_is_dir():
				if name != ".godot":
					_walk(full, suffix, into)
			elif name.ends_with(suffix):
				into.append(full)
		name = dir.get_next()
	dir.list_dir_end()

func _read(path: String) -> String:
	var text := FileAccess.get_file_as_string(path)
	if text == null:
		return ""
	return text

func _u16(data: PackedByteArray, off: int) -> int:
	return (data[off] << 8) | data[off + 1]

func _u32(data: PackedByteArray, off: int) -> int:
	return (data[off] << 24) | (data[off + 1] << 16) | (data[off + 2] << 8) | data[off + 3]
