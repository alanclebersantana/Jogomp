extends SceneTree
## Prints da fase: teleporta o Milis para os pontos e salva PNG em $PASTA (padrão /tmp/cade_fotos).
## Uso: LVL=0 godot --path . -s tests/foto.gd -- 900,500 3150,180 ...
func _initialize() -> void:
	var pasta := OS.get_environment("PASTA") if OS.get_environment("PASTA") != "" else "/tmp/cade_fotos"
	DirAccess.make_dir_recursive_absolute(pasta)
	root.get_node("Save").setv("opt", "tut_asked", true)
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	var args := OS.get_cmdline_user_args()
	if args.size() > 0 and args[0] == "titulo":
		for i in 20:
			await process_frame
		root.get_texture().get_image().save_png(pasta.path_join("titulo.png"))
		quit()
		return
	var lvl := int(OS.get_environment("LVL")) if OS.get_environment("LVL") != "" else 0
	main.start_level(false, lvl)
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
	g.running = true
	g.lives = 99
	for e in g.EN:
		e.dead = 99 if OS.get_environment("SEM_INIMIGOS") != "" else e.dead
	var n := 0
	for a in args:
		var p = a.split(",")
		g.player.x = float(p[0]) - 12
		g.player.y = float(p[1]) - 34
		g.player.vx = 0
		g.player.vy = 0
		g.player.spawnX = g.player.x
		g.player.spawnY = g.player.y
		g.snap_camera()
		for i in 50:
			g.player.hp = 5
			if main.state != main.S.PLAY:
				for c in main.ui_layer.get_children():
					if c.has_method("_end"):
						c._end()
				main.state = main.S.PLAY
				g.running = true
			await process_frame
		root.get_texture().get_image().save_png(pasta.path_join("f%02d.png" % n))
		n += 1
	quit()
