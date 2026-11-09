extends SceneTree
## Procura quadros escuros (tela piscando preto): anda pela fase e mede o brilho médio de cada quadro.
## Uso: SKIP_PROLOGO=1 xvfb-run godot --rendering-driver opengl3 --path . -s tests/flicker.gd
func _initialize() -> void:
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	for i in 3:
		await process_frame
	main.start_level(false, 0)
	await process_frame
	for k in 3:
		if main.panel and main.panel.has_meta("ok"):
			main.panel.get_meta("ok").call()
		await process_frame
	for c in main.ui_layer.get_children():
		if c.has_method("_end"):
			c._end()
	var g = main.game
	g.lives = 99
	var prev := -1.0
	var worst := 1.0
	var bad := 0
	var x := 200.0
	for f in 2600:
		if f % 100 == 0:
			x += 560.0
			if x > 15000:
				break
			g.player.x = x
			g.player.y = 300
			g.player.vx = 0
			g.player.vy = 0
		main._set_key("R", (f % 100) < 70)
		await process_frame
		var im: Image = root.get_texture().get_image()
		im.resize(32, 18, Image.INTERPOLATE_BILINEAR)
		var s := 0.0
		for yy in 18:
			for xx in 32:
				s += im.get_pixel(xx, yy).get_luminance()
		s /= 576.0
		if prev > 0 and s < prev * .6:
			bad += 1
			print("QUADRO ESCURO f=%d x=%d lum=%.3f antes=%.3f" % [f, int(g.player.x), s, prev])
			root.get_texture().get_image().save_png("/tmp/fh_shots/escuro_%d.png" % f)
		worst = min(worst, s)
		prev = s
	print("FIM quadros escuros=%d pior=%.3f" % [bad, worst])
	quit()
