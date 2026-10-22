extends SceneTree
## Lightweight gesture + phone-fit checks. No display, no scenes.

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var errors: Array = []
	_router(errors)
	_fit(errors)
	_budget(errors)
	if errors.is_empty():
		print("TOUCH ROUTER PASS")
		quit(0)
	else:
		for e in errors:
			push_error(str(e))
			print("FAIL ", e)
		quit(1)

func _router(errors: Array) -> void:
	var r := InputRouter.new()
	var down := InputEventMouseButton.new()
	down.device = 0
	down.button_index = MOUSE_BUTTON_LEFT
	down.pressed = true
	down.position = Vector2(10, 20)
	var tap: Array = r.push(down, 1000)
	if tap.size() != 1 or str(tap[0].get("kind", "")) != "tap":
		errors.append("mouse left press must tap immediately")
	var ghost := down.duplicate() as InputEventMouseButton
	ghost.device = InputEvent.DEVICE_ID_EMULATION
	if not r.push(ghost, 1100).is_empty():
		errors.append("emulated mouse must not double-fire")
	var right := InputEventMouseButton.new()
	right.device = 0
	right.button_index = MOUSE_BUTTON_RIGHT
	right.pressed = true
	right.position = Vector2(3, 4)
	var cancel: Array = r.push(right, 1200)
	if cancel.is_empty() or str(cancel[0].get("kind", "")) != "cancel":
		errors.append("right click must cancel")
	var motion := InputEventMouseMotion.new()
	motion.device = 0
	motion.position = Vector2(8, 9)
	var hover: Array = r.push(motion, 1300)
	if hover.is_empty() or str(hover[0].get("kind", "")) != "hover":
		errors.append("mouse motion must hover")
	var wheel := InputEventMouseButton.new()
	wheel.device = 0
	wheel.button_index = MOUSE_BUTTON_WHEEL_UP
	wheel.pressed = true
	wheel.position = Vector2(12, 12)
	var zoom: Array = r.push(wheel, 1400)
	if zoom.is_empty() or str(zoom[0].get("kind", "")) != "wheel" or float(zoom[0].get("factor", 0)) <= 1.0:
		errors.append("wheel must zoom in")

	r = InputRouter.new()
	var press := _touch(0, true, Vector2(5, 5))
	r.push(press, 2000)
	var release := _touch(0, false, Vector2(8, 7))
	var short: Array = r.push(release, 2200)
	if short.size() != 1 or str(short[0].get("kind", "")) != "tap":
		errors.append("short touch must tap on release")

	r = InputRouter.new()
	r.push(_touch(0, true, Vector2(5, 5)), 3000)
	var held: Array = r.poll(3000 + InputRouter.LONG_MS + 10)
	if held.size() != 1 or str(held[0].get("kind", "")) != "long_press":
		errors.append("hold must long-press")
	var after: Array = r.push(_touch(0, false, Vector2(6, 6)), 3600)
	if after.is_empty() or str(after[0].get("kind", "")) != "swallow":
		errors.append("long-press release must not also tap")

	r = InputRouter.new()
	r.push(_touch(0, true, Vector2(0, 0)), 4000)
	var drag := InputEventScreenDrag.new()
	drag.index = 0
	drag.position = Vector2(48, 6)
	drag.relative = Vector2(48, 6)
	var pan: Array = r.push(drag, 4100)
	if pan.is_empty() or str(pan[0].get("kind", "")) != "pan":
		errors.append("one-finger drag must pan")
	elif (pan[0].get("delta", Vector2.ZERO) as Vector2).x < 40.0:
		errors.append("pan delta too small")
	var pan_up: Array = r.push(_touch(0, false, Vector2(48, 6)), 4200)
	if not pan_up.is_empty() and str(pan_up[0].get("kind", "")) == "tap":
		errors.append("pan release must not tap")
	var kinds := []
	for g in pan_up:
		kinds.append(str(g.get("kind", "")))
	if "drag_end" not in kinds:
		errors.append("pan release must emit drag_end")
	if "swallow" not in kinds:
		errors.append("pan release must still swallow")

	# Y1-A: sticky origin resists micro-wobble even when CK_FORCE_MOBILE raises base slop.
	OS.set_environment("CK_FORCE_MOBILE", "1")
	r = InputRouter.new()
	r.sticky_fn = func(_o: Vector2) -> bool: return true
	var base_slop: float = r._slop()
	r.push(_touch(0, true, Vector2(10, 10)), 6000)
	var micro := InputEventScreenDrag.new()
	micro.index = 0
	micro.position = Vector2(10 + base_slop * 0.8, 10)
	micro.relative = Vector2(base_slop * 0.8, 0)
	var micro_g: Array = r.push(micro, 6050)
	for g2 in micro_g:
		if str(g2.get("kind", "")) == "pan":
			errors.append("sticky micro drag must not pan yet")
	var micro_up: Array = r.push(_touch(0, false, micro.position), 6100)
	if micro_up.is_empty() or str(micro_up[0].get("kind", "")) != "tap":
		errors.append("sticky micro release must tap")
	OS.set_environment("CK_FORCE_MOBILE", "0")

	# Y1-A T-P1-1: raised long_ms keeps a slow release as tap (no long_press / swallow).
	r = InputRouter.new()
	r.long_ms_fn = func() -> int: return InputRouter.LONG_MS_SELECTED
	r.push(_touch(0, true, Vector2(5, 5)), 7000)
	var mid_hold: Array = r.poll(7000 + InputRouter.LONG_MS + 20)
	if not mid_hold.is_empty():
		errors.append("selected long_ms must not fire at default LONG_MS")
	var still: Array = r.poll(7000 + InputRouter.LONG_MS_SELECTED - 20)
	if not still.is_empty():
		errors.append("selected long_ms must not fire before LONG_MS_SELECTED")
	var slow_up: Array = r.push(_touch(0, false, Vector2(6, 6)), 7000 + InputRouter.LONG_MS + 40)
	if slow_up.is_empty() or str(slow_up[0].get("kind", "")) != "tap":
		errors.append("slow release under raised long_ms must tap, got %s" % str(slow_up))

	# Raised threshold still allows intentional long-press after LONG_MS_SELECTED.
	r = InputRouter.new()
	r.long_ms_fn = func() -> int: return InputRouter.LONG_MS_SELECTED
	r.push(_touch(0, true, Vector2(5, 5)), 8000)
	var late: Array = r.poll(8000 + InputRouter.LONG_MS_SELECTED + 10)
	if late.is_empty() or str(late[0].get("kind", "")) != "long_press":
		errors.append("hold past LONG_MS_SELECTED must long-press")

	# Disable long-press entirely when long_ms_fn returns <= 0.
	r = InputRouter.new()
	r.long_ms_fn = func() -> int: return 0
	r.push(_touch(0, true, Vector2(5, 5)), 9000)
	var never: Array = r.poll(9000 + 5000)
	if not never.is_empty():
		errors.append("long_ms_fn<=0 must disable long-press")
	var never_up: Array = r.push(_touch(0, false, Vector2(5, 5)), 14000)
	if never_up.is_empty() or str(never_up[0].get("kind", "")) != "tap":
		errors.append("disabled long-press release must tap")

	r = InputRouter.new()
	r.push(_touch(0, true, Vector2(0, 0)), 5000)
	r.push(_touch(1, true, Vector2(100, 0)), 5010)
	var widen := InputEventScreenDrag.new()
	widen.index = 1
	widen.position = Vector2(180, 0)
	widen.relative = Vector2(80, 0)
	var pinch: Array = r.push(widen, 5100)
	if pinch.is_empty() or str(pinch[0].get("kind", "")) != "pinch":
		errors.append("two-finger drag must pinch")
	elif float(pinch[0].get("factor", 1.0)) < 1.4:
		errors.append("pinch factor expected to grow, got %s" % str(pinch[0].get("factor", "?")))

func _touch(index: int, pressed: bool, pos: Vector2) -> InputEventScreenTouch:
	var e := InputEventScreenTouch.new()
	e.index = index
	e.pressed = pressed
	e.position = pos
	return e

func _fit(errors: Array) -> void:
	var phones := [Vector2(1080, 1920), Vector2(1080, 2400), Vector2(1920, 1080), Vector2(2400, 1080)]
	var notch := {"left": 0.0, "top": 48.0, "right": 0.0, "bottom": 24.0}
	for window in phones:
		var vp: Vector2 = DeviceProfile.logical_viewport(window)
		if window.x < window.y and (vp.x < 1279.0 or vp.y <= 720.0):
			errors.append("portrait logical viewport should grow height: %s -> %s" % [window, vp])
		if window == Vector2(1080, 2400) and vp.y <= DeviceProfile.logical_viewport(Vector2(1080, 1920)).y:
			errors.append("20:9 portrait should be taller than 16:9")
		if window == Vector2(1920, 1080) and vp.distance_to(Vector2(1280, 720)) > 1.0:
			errors.append("16:9 landscape should stay 1280x720, got %s" % vp)
		if window == Vector2(2400, 1080) and vp.x <= 1280.0:
			errors.append("20:9 landscape should grow width")
		var fitted := MobileLayout.fit(vp, notch if window.x < window.y else {"left": 64.0, "top": 0.0, "right": 48.0, "bottom": 0.0})
		var s := float(fitted.get("scale", 0.0))
		var pos: Vector2 = fitted.get("position", Vector2(-1, -1))
		if s <= 0.0 or s > 1.001:
			errors.append("scale out of range for %s: %s" % [window, s])
		var design := Vector2(1280, 720) * s
		var insets: Dictionary = notch if window.x < window.y else {"left": 64.0, "top": 0.0, "right": 48.0, "bottom": 0.0}
		if pos.x < float(insets.left) - 0.2 or pos.y < float(insets.top) - 0.2:
			errors.append("fit origin outside safe area %s" % window)
		if pos.x + design.x > vp.x - float(insets.right) + 0.6:
			errors.append("fit overflows right %s" % window)
		if pos.y + design.y > vp.y - float(insets.bottom) + 0.6:
			errors.append("fit overflows bottom %s" % window)
		if window.x < window.y:
			# Portrait top-aligns into the safe area (no centered letterbox).
			if absf(pos.y - float(insets.top)) > 1.0:
				errors.append("portrait root should pin to safe top, got %s" % pos)
	var hit := DeviceProfile.hit_px_for(480.0, 1280.0, 1080.0)
	if hit < 48.0 or hit < 160.0:
		errors.append("48dp at xxhdpi should exceed 160 logical px, got %s" % hit)

func _budget(errors: Array) -> void:
	var desk := DeviceProfile.cutscene_budget_for(false, false)
	if int(desk.msaa) != Viewport.MSAA_4X or bool(desk.simple) or float(desk.particles) < 0.99:
		errors.append("desktop cutscene budget changed")
	var phone := DeviceProfile.cutscene_budget_for(true, false)
	if int(phone.msaa) != Viewport.MSAA_2X or bool(phone.shadows):
		errors.append("mobile cutscene should drop MSAA and shadows")
	var low := DeviceProfile.cutscene_budget_for(true, true)
	if int(low.msaa) != Viewport.MSAA_DISABLED or not bool(low.simple) or float(low.particles) > 0.0:
		errors.append("low-end should disable MSAA, use simple shading, and pause particles")
