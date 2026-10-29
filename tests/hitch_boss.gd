extends SceneTree
## Mede o quadro mais pesado ao entrar nas arenas dos chefes (cena, quadrinho, música, chefe aparecendo).
## Uso: xvfb-run -a godot --path . --resolution 480x270 -s tests/hitch_boss.gd -- x,y x,y ...
var main
var g
var Spr

func _initialize() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	for i in 3:
		await process_frame
	Spr = root.get_node("Spr")
	var sv = root.get_node("Save")
	for cid in ["cipo", "mergulho", "pipoca", "picareta", "toxico", "colmeia"]:
		sv.setv("comic", cid, true)
	for cid in ["javali", "gaviao", "bagre", "urso", "neve", "bola", "cavalo", "aviao", "jangada", "mina"]:
		sv.setv("comic", cid, false)
	main.start_level(false, 0)
	await process_frame
	for k in 3:
		if main.panel and main.panel.has_meta("ok"):
			main.panel.get_meta("ok").call()
		for c in main.ui_layer.get_children():
			if c.has_method("_end"):
				c._end()
		await process_frame
	g = main.game
	g.lives = 99
	for i in 600:
		if Spr.warmed:
			break
		await process_frame
	Spr.trace_late = true
	for a in OS.get_cmdline_user_args():
		var p = a.split(",")
		g.player.x = float(p[0])
		g.player.y = float(p[1]) - 40
		g.player.vx = 0
		g.player.vy = 0
		g.snap_camera()
		var worst := []
		for i in 400:
			g.keys["R"] = true
			g.player.hp = 5
			# quadrinho aberto: fecha sozinho depois de um tempo (como o jogador tocando)
			for c in main.ui_layer.get_children():
				if c.has_method("_end") and c.get("t") != null and c.t > 1.5:
					c._end()
			Spr.prof = {}
			Spr.prof_on = true
			var t0 := Time.get_ticks_usec()
			await process_frame
			var wall := (Time.get_ticks_usec() - t0) / 1000.0
			Spr.prof_on = false
			var cpu := 0.0
			for k in Spr.prof:
				if not (str(k).begins_with("d_") or str(k).begins_with("p_") or str(k).begins_with("s_")):
					cpu += Spr.prof[k] / 1000.0
			worst.append([wall, cpu, i, int(g.player.x), str(main.state), g.CINE.get("id", "")])
		worst.sort_custom(func(a, b): return a[0] > b[0])
		print("BOSS em %s:" % a)
		for w in worst.slice(0, 6):
			print("  parede=%.0fms cpu=%.1fms q=%d x=%d estado=%s cena=%s" % w)
	quit()
