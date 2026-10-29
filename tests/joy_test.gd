extends SceneTree
## Teste do controle (gamepad): confirmar telas com qualquer botão, mochila pelo direcional, sem analógico na tela.
var m

func _btn(b: int, down := true) -> void:
	var e := InputEventJoypadButton.new()
	e.button_index = b
	e.pressed = down
	m._input(e)

func _tap(b: int) -> void:
	_btn(b, true)
	_btn(b, false)

func _initialize() -> void:
	m = load("res://scenes/main.tscn").instantiate()
	root.add_child(m)
	for i in 3:
		await process_frame
	var fails := []
	root.get_node("Save").setv("opt", "stick", "gamepad")
	m.apply_controls()
	m.start_level(false)
	await process_frame
	# perguntas/telas iniciais: só botões do controle até chegar no jogo
	for k in 30:
		if m.state == m.S.PLAY and m.panel == null:
			break
		for c in m.ui_layer.get_children():
			if c.has_method("_end") and c is Control:
				var e := InputEventJoypadButton.new()
				e.button_index = JOY_BUTTON_X
				e.pressed = true
				for j in 60:
					if not is_instance_valid(c) or c.is_queued_for_deletion():
						break
					c._unhandled_input(e)
					await process_frame
		_tap(JOY_BUTTON_B if k % 2 else JOY_BUTTON_A)
		for j in 6:
			await process_frame
	printerr("estado após telas: ", m.state, " painel=", m.panel)
	if m.state != m.S.PLAY:
		fails.append("telas iniciais não confirmaram pelo controle")
	var g = m.game
	g.clue_opened.disconnect(m._on_clue)
	await process_frame
	await process_frame
	if m.stick.mode != "gamepad":
		fails.append("modo do controle não ficou gamepad")
	# fala na tela: qualquer botão avança
	g.CINE = {"lines": [["Teste", "oi"]], "i": 0}
	g.keys.erase("Jp")
	_tap(JOY_BUTTON_X)
	if not g.keys.get("Jp", false):
		fails.append("fala não avançou com botão X")
	g.CINE = {}
	_clear(g)
	# mochila: combina dois itens só com o direcional + A
	var rec: Array = load("res://scripts/data.gd").RECIPES[0]
	g.INV.clear()
	g.give_item(rec[0])
	g.give_item(rec[1])
	_tap(JOY_BUTTON_Y)
	await process_frame
	if m.state != m.S.BAG:
		fails.append("Y não abriu a mochila")
	_tap(JOY_BUTTON_A)      # escolhe o 1º
	await process_frame
	_tap(JOY_BUTTON_DPAD_RIGHT)
	await process_frame
	if DisplayServer.get_name() != "headless":
		for j in 20:
			await process_frame
		root.get_viewport().get_texture().get_image().save_png("/tmp/joy_bag.png")
	_tap(JOY_BUTTON_A)      # junta com o 2º
	await process_frame
	printerr("mochila: ", g.INV)
	if not g.INV.has(rec[2]):
		fails.append("não combinou pela mochila com o controle: %s" % [g.INV])
	_tap(JOY_BUTTON_B)
	await process_frame
	if m.state != m.S.PLAY:
		fails.append("B não fechou a mochila")
	print("JOY FALHAS: ", fails.size(), " ", fails)
	quit(1 if fails.size() > 0 else 0)

func _clear(g) -> void:
	g.keys.clear()
