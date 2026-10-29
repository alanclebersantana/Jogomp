extends SceneTree
## Teste da fase mínima: abre o jogo inteiro (main + desenho), começa a fase 0 e anda para a direita.
func _initialize() -> void:
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	main.start_level(false, int(OS.get_environment("LVL")) if OS.get_environment("LVL") != "" else 0)
	await process_frame
	for i in 6:
		for c in main.ui_layer.get_children():
			if c.has_method("_end"):
				c._end()
		await process_frame
		if main.panel and is_instance_valid(main.panel) and main.panel.has_meta("ok"):
			main.panel.get_meta("ok").call()
		await process_frame
	main.state = main.S.PLAY
	var g = main.game
	g.level_won.connect(func(): print("SIGNAL level_won T=", g.T, " x=", g.player.x))
	g.results_ready.connect(func(): print("SIGNAL results_ready T=", g.T))
	g.rest_reached.connect(func(n): print("SIGNAL rest ", n))
	g.running = true
	print("START x=", g.player.x, " y=", g.player.y, " state=", main.state)
	var n := int(OS.get_environment("FRAMES")) if OS.get_environment("FRAMES") != "" else 600
	var tp: Array = []
	for v in OS.get_environment("TP").split(",", false):
		tp.append(float(v))
	for i in n:
		g.keys["R"] = true
		if not tp.is_empty() and i % 250 == 0 and i / 250 < tp.size():
			g.player.x = tp[i / 250]
			g.player.y = 420.0
			g.player.vy = 0.0
			g.snap_camera()
			print("TP ", tp[i / 250])
		g.player.hp = 5
		if i % 50 == 10 and g.player.x < 2600:
			g.keys["Jp"] = true
			g.keys["J"] = true
		elif i % 50 == 30:
			g.keys["J"] = false
		if main.state != main.S.PLAY:
			for c in main.ui_layer.get_children():
				if c.has_method("_end"):
					c._end()
			main.state = main.S.PLAY
			g.running = true
		await physics_frame
		if i % 100 == 0:
			print("T=", g.T, " x=", int(g.player.x), " y=", int(g.player.y), " hp=", g.player.hp, " ground=", g.player.onGround)
	print("END T=", g.T, " x=", g.player.x, " y=", g.player.y, " lives=", g.lives)
	quit()
