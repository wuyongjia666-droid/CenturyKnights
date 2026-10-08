class_name InputRouter
extends RefCounted
## Shared pointer router for the tactics board and overworld atlas.
## Mouse (device >= 0): left press = tap, right press = cancel, motion = hover,
## wheel = zoom, middle-drag = pan. Touch: release = tap, hold = long-press,
## one-finger drag = pan, two-finger = pinch.
## Emulated mouse events (device -1) are ignored so a touch is not also a click.

const LONG_MS := 480
const SLOP := 22.0
const WHEEL_FACTOR := 1.12

var _pts: Dictionary = {}
var _pinch_dist := -1.0

func pointer_count() -> int:
	return _pts.size()

func has_pointers() -> bool:
	return not _pts.is_empty()

func gesture_locked() -> bool:
	if _pts.size() >= 2:
		return true
	for k in _pts.keys():
		var p: Dictionary = _pts[k]
		if bool(p.get("moved", false)) or bool(p.get("long", false)):
			return true
	return false

func push(event: InputEvent, now_ms: int) -> Array:
	if event is InputEventMouse and int(event.device) == InputEvent.DEVICE_ID_EMULATION:
		return []
	if event is InputEventScreenTouch:
		return _screen_touch(event as InputEventScreenTouch, now_ms)
	if event is InputEventScreenDrag:
		return _screen_drag(event as InputEventScreenDrag, now_ms)
	if event is InputEventMouseButton:
		return _mouse_button(event as InputEventMouseButton, now_ms)
	if event is InputEventMouseMotion:
		return _mouse_motion(event as InputEventMouseMotion)
	return []

func poll(now_ms: int) -> Array:
	if _pts.size() != 1:
		return []
	var out: Array = []
	for k in _pts.keys():
		if int(k) == -100:
			continue
		var p: Dictionary = _pts[k]
		if bool(p.get("moved", false)) or bool(p.get("long", false)):
			continue
		if now_ms - int(p.get("time", now_ms)) >= LONG_MS:
			p["long"] = true
			_pts[k] = p
			out.append({"kind": "long_press", "pos": p.get("pos", Vector2.ZERO)})
	return out

func _screen_touch(e: InputEventScreenTouch, now_ms: int) -> Array:
	var out: Array = []
	if e.pressed:
		_pts[e.index] = {"origin": e.position, "pos": e.position, "time": now_ms, "moved": false, "long": false}
		if _pts.size() >= 2:
			for k in _pts.keys():
				var p: Dictionary = _pts[k]
				p["moved"] = true
				_pts[k] = p
			_pinch_dist = _span()
		return out
	if not _pts.has(e.index):
		return out
	var p: Dictionary = _pts[e.index]
	var moved := bool(p.get("moved", false))
	var held := bool(p.get("long", false))
	_pts.erase(e.index)
	if _pts.size() < 2:
		_pinch_dist = -1.0
	if moved or held:
		out.append({"kind": "swallow", "pos": e.position})
	elif _pts.is_empty():
		out.append({"kind": "tap", "pos": p.get("pos", e.position)})
	return out

func _screen_drag(e: InputEventScreenDrag, now_ms: int) -> Array:
	if not _pts.has(e.index):
		_pts[e.index] = {"origin": e.position, "pos": e.position, "time": now_ms, "moved": false, "long": false}
	var p: Dictionary = _pts[e.index]
	var prev: Vector2 = p.get("pos", e.position)
	p["pos"] = e.position
	var origin: Vector2 = p.get("origin", e.position)
	if origin.distance_to(e.position) > SLOP:
		p["moved"] = true
	_pts[e.index] = p
	if _pts.size() >= 2:
		var dist := _span()
		var out: Array = []
		if _pinch_dist > 1.0 and dist > 1.0:
			var factor := dist / _pinch_dist
			if absf(factor - 1.0) >= 0.02:
				out.append({"kind": "pinch", "factor": factor, "pos": _centroid()})
		_pinch_dist = dist
		return out
	if bool(p.get("moved", false)):
		return [{"kind": "pan", "delta": e.position - prev, "pos": e.position}]
	return []

func _mouse_button(e: InputEventMouseButton, now_ms: int) -> Array:
	if e.button_index == MOUSE_BUTTON_WHEEL_UP and e.pressed:
		return [{"kind": "wheel", "factor": WHEEL_FACTOR, "pos": e.position}]
	if e.button_index == MOUSE_BUTTON_WHEEL_DOWN and e.pressed:
		return [{"kind": "wheel", "factor": 1.0 / WHEEL_FACTOR, "pos": e.position}]
	if e.button_index == MOUSE_BUTTON_RIGHT and e.pressed:
		return [{"kind": "cancel", "pos": e.position}]
	if e.button_index == MOUSE_BUTTON_LEFT and e.pressed:
		return [{"kind": "tap", "pos": e.position}]
	if e.button_index == MOUSE_BUTTON_MIDDLE:
		if e.pressed:
			_pts[-100] = {"origin": e.position, "pos": e.position, "time": now_ms, "moved": true, "long": true}
		else:
			_pts.erase(-100)
			return [{"kind": "swallow", "pos": e.position}]
	return []

func _mouse_motion(e: InputEventMouseMotion) -> Array:
	if _pts.has(-100):
		var p: Dictionary = _pts[-100]
		var prev: Vector2 = p.get("pos", e.position)
		p["pos"] = e.position
		_pts[-100] = p
		return [{"kind": "pan", "delta": e.position - prev, "pos": e.position}]
	return [{"kind": "hover", "pos": e.position}]

func _span() -> float:
	var keys: Array = _pts.keys()
	if keys.size() < 2:
		return -1.0
	keys.sort()
	var a: Vector2 = _pts[keys[0]].get("pos", Vector2.ZERO)
	var b: Vector2 = _pts[keys[1]].get("pos", Vector2.ZERO)
	return a.distance_to(b)

func _centroid() -> Vector2:
	var keys: Array = _pts.keys()
	keys.sort()
	var a: Vector2 = _pts[keys[0]].get("pos", Vector2.ZERO)
	var b: Vector2 = _pts[keys[1]].get("pos", Vector2.ZERO)
	return (a + b) * 0.5
