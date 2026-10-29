extends SceneTree
## Quantas chamadas de desenho cada camada gasta em pontos da fase (escondendo uma camada por vez).
## Uso: xvfb-run -a godot --path . --resolution 480x270 -s tests/drawcalls.gd -- x,y x,y ...
var main
var g

func _dc() -> int:
	var tot := 0
	for i in 3:
		await process_frame
	for i in 4:
		await process_frame
		tot += int(RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME))
	return tot / 4

func _initialize() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	for i in 3:
		await process_frame
	var sv = root.get_node("Save")
	for cid in ["cipo", "mergulho", "neve", "pipoca", "picareta", "cavalo", "mina", "toxico", "javali", "gaviao", "bagre", "urso", "vargas", "bola", "aviao", "jangada", "colmeia", "moinho", "telhados", "carrinho"]:
		sv.setv("comic", cid, true)
	main.start_level(false, int(OS.get_environment("LVL")) if OS.get_environment("LVL") != "" else 0)
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
	for a in OS.get_cmdline_user_args():
		var p = a.split(",")
		g.player.x = float(p[0])
		g.player.y = float(p[1]) - 40
		g.player.vx = 0
		g.player.vy = 0
		g.snap_camera()
		for i in 20:
			await process_frame
		var base: int = await _dc()
		var line := "DC x=%s total=%d |" % [p[0], base]
		# camadas: filhos do game (fundo, pedaços do cenário, mundo), camada de brilho, primeiro plano, efeitos, HUD
		var cands: Array = []
		for c in g.get_children():
			if c is CanvasItem:
				cands.append([c.get_script().resource_path.get_file() if c.get_script() else c.get_class(), c])
		for c in main.get_children():
			if c is CanvasLayer:
				for cc in c.get_children():
					if cc is CanvasItem:
						cands.append([("L%d:" % c.layer) + (cc.get_script().resource_path.get_file() if cc.get_script() else cc.get_class()), cc])
		var seen := {}
		for cd in cands:
			var nm: String = cd[0]
			var n: CanvasItem = cd[1]
			if not n.visible:
				continue
			n.visible = false
			var v: int = await _dc()
			n.visible = true
			seen[nm] = seen.get(nm, 0) + (base - v)
		var ks: Array = seen.keys()
		ks.sort_custom(func(a, b): return seen[a] > seen[b])
		for k in ks.slice(0, 10):
			line += " %s=%d" % [k, seen[k]]
		print(line)
	quit()
