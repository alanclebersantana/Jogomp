extends SceneTree
## Teste do controle de toque: diagonal ↘ deve andar abaixado com um dedo só; analógico inclinado pouco anda devagar.
var st_ref

func _touch(idx: int, pos: Vector2, pressed: bool) -> void:
	var e := InputEventScreenTouch.new()
	e.index = idx
	e.position = pos
	e.pressed = pressed
	st_ref._input(e)

func _drag(idx: int, pos: Vector2) -> void:
	var e := InputEventScreenDrag.new()
	e.index = idx
	e.position = pos
	st_ref._input(e)

func _initialize() -> void:
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	for i in 3:
		await process_frame
	main.start_level(false)
	await process_frame
	if main.panel and main.panel.has_meta("ok"):
		main.panel.get_meta("ok").call()
		await process_frame
	for c in main.ui_layer.get_children():
		if c.has_method("_end"):
			c._end()
	await process_frame
	main.panel.get_meta("ok").call()
	var g = main.game
	g.clue_opened.disconnect(main._on_clue)
	var st = main.stick
	st_ref = st
	st.set_mode("dpad")
	await process_frame
	var to_win: Transform2D = st.get_global_transform_with_canvas()
	var home: Vector2 = st._home()
	_touch(0, to_win * home, true)
	_drag(0, to_win * (home + Vector2(45, 45)))
	for i in 40:
		await physics_frame
	print("DPAD ↘ keys=", {"R": g.keys.get("R"), "S": g.keys.get("S")}, " crouch=", g.player.crouch, " x=", g.player.x)
	var ok1: bool = g.player.crouch and g.player.x > 190
	_drag(0, to_win * (home + Vector2(60, 0)))
	for i in 20:
		await physics_frame
	print("DPAD → crouch=", g.player.crouch, " vx=", g.player.vx)
	var ok2: bool = not g.player.crouch and g.player.vx > 3
	_touch(0, to_win * home, false)
	for i in 30:
		await physics_frame
	st.set_mode("analog")
	var p0: Vector2 = to_win * st._home()
	_touch(1, p0, true)
	_drag(1, p0 + to_win.basis_xform(Vector2(30, 0)))
	for i in 60:
		await physics_frame
	var slow: float = g.player.vx
	_drag(1, p0 + to_win.basis_xform(Vector2(80, 0)))
	for i in 60:
		await physics_frame
	var fast: float = g.player.vx
	print("ANALÓGICO devagar vx=", slow, " rápido vx=", fast, " axis=", g.axis_x, " estado=", st.state, " x=", g.player.x)
	var ok3: bool = slow > .5 and slow < 3.2
	_touch(1, p0, false)
	print("TOUCH ", "OK" if ok1 and ok2 and ok3 else "FALHOU")
	quit()
