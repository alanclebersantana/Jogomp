extends SceneTree
## Mapeamento do controle: botões padrão, troca de botão, gatilho como eixo, correr segurando,
## tela de mapeamento (captura do botão novo). Uso: godot --headless --path . -s tests/padmap.gd
var f := 0
func ok(nome: String, cond: bool) -> void:
	print(("ok   " if cond else "FALHA ") + nome)
	if not cond:
		f += 1

func btn(main, b: int, down: bool) -> void:
	var e := InputEventJoypadButton.new()
	e.button_index = b
	e.pressed = down
	main._input(e)

func _initialize() -> void:
	var S = root.get_node("Save")
	S.cfg.erase_section("pad") if S.cfg.has_section("pad") else null
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	for i in 3:
		await process_frame
	main.start_level(false, 0)
	await process_frame
	for k in 4:
		if main.panel and main.panel.has_meta("ok"):
			main.panel.get_meta("ok").call()
		for c in main.ui_layer.get_children():
			if c.has_method("_end"):
				c._end()
		await process_frame
	var g = main.game
	g.CINE = {}
	main.state = main.S.PLAY
	# padrão: A pula, X bastão, B chute, R1 defesa
	btn(main, JOY_BUTTON_A, true)
	ok("A = pular", g.keys.get("J", false))
	btn(main, JOY_BUTTON_A, false)
	btn(main, JOY_BUTTON_X, true)
	ok("X = bastão", g.keys.get("G", false))
	btn(main, JOY_BUTTON_X, false)
	btn(main, JOY_BUTTON_B, true)
	ok("B = chute", g.keys.get("K", false))
	btn(main, JOY_BUTTON_B, false)
	btn(main, JOY_BUTTON_RIGHT_SHOULDER, true)
	ok("R1 = defesa", g.keys.get("F", false))
	btn(main, JOY_BUTTON_RIGHT_SHOULDER, false)
	# gatilho R2 como eixo = planar
	var ax := InputEventJoypadMotion.new()
	ax.axis = JOY_AXIS_TRIGGER_RIGHT
	ax.axis_value = .9
	main._input(ax)
	ok("R2 (eixo) = planar", g.keys.get("P", false))
	ax.axis_value = 0.0
	main._input(ax)
	ok("R2 solto", not g.keys.get("P", false))
	# todos os 12 botões com função, nenhum repetido
	var usados := {}
	for fn in PadMap.FUNCS:
		usados[PadMap.btn(fn[0])] = true
	ok("12 funções em 12 botões diferentes", usados.size() == 12)
	# troca: pular no X -> bastão vai para o A
	PadMap.assign("pulo", JOY_BUTTON_X)
	ok("troca pular<->bastão", PadMap.btn("pulo") == JOY_BUTTON_X and PadMap.btn("golpe") == JOY_BUTTON_A)
	btn(main, JOY_BUTTON_X, true)
	ok("X agora pula", g.keys.get("J", false) and not g.keys.get("G", false))
	btn(main, JOY_BUTTON_X, false)
	PadMap.reset()
	# correr segurando L1 + direita
	main.state = main.S.PLAY
	btn(main, JOY_BUTTON_LEFT_SHOULDER, true)
	btn(main, JOY_BUTTON_DPAD_RIGHT, true)
	for i in 6:
		await physics_frame
	ok("L1 + direita = corre", int(g.player.run) == 1)
	btn(main, JOY_BUTTON_LEFT_SHOULDER, false)
	for i in 4:
		await physics_frame
	ok("soltou L1 = para de correr", int(g.player.run) == 0)
	btn(main, JOY_BUTTON_DPAD_RIGHT, false)
	# Start pausa e fecha
	btn(main, JOY_BUTTON_START, true)
	btn(main, JOY_BUTTON_START, false)
	ok("START pausa", main.state == main.S.PAUSE)
	btn(main, JOY_BUTTON_START, true)
	btn(main, JOY_BUTTON_START, false)
	ok("START fecha a pausa", main.state == main.S.PLAY)
	# tela de mapeamento: escolhe "Mochila" e aperta o B
	main.state = main.S.PAUSE
	main.show_pad_map(true)
	await process_frame
	main.pad_capture = "mochila"
	main.pad_capture_t = Time.get_ticks_msec()
	main.show_pad_map(true)
	btn(main, JOY_BUTTON_B, true)
	btn(main, JOY_BUTTON_B, false)
	ok("captura: mochila no B", PadMap.btn("mochila") == JOY_BUTTON_B and PadMap.btn("chute") == PadMap.L2 and main.pad_capture == "")
	await process_frame
	root.get_texture().get_image().save_png("/tmp/fh_shots/padmap.png")
	PadMap.reset()
	print("FALHAS: ", f)
	quit()
