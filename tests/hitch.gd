extends SceneTree
## Caça-travadas: percorre a fase (Ep. LVL) com desenho de verdade, a cada PASSO px, segurando → por alguns
## quadros, e mede o custo de cada quadro (scripts) — mostra os quadros que destoam e o que pesou neles.
## Também liga Spr.trace_late (avisa LOADLATE quando algo carrega no meio do jogo).
## Uso: xvfb-run -a -s "-screen 0 1280x720x24" godot --path . --resolution 480x270 -s tests/hitch.gd
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
	for cid in ["cipo", "mergulho", "neve", "pipoca", "picareta", "cavalo", "mina", "toxico", "javali", "gaviao", "bagre", "urso", "vargas", "bola", "aviao", "jangada", "colmeia", "moinho", "telhados", "carrinho"]:
		sv.setv("comic", cid, true)
	var lvl := int(OS.get_environment("LVL")) if OS.get_environment("LVL") != "" else 0
	var step := float(OS.get_environment("PASSO")) if OS.get_environment("PASSO") != "" else 450.0
	var x0 := float(OS.get_environment("X0")) if OS.get_environment("X0") != "" else 0.0
	var x1 := float(OS.get_environment("X1")) if OS.get_environment("X1") != "" else 1e9
	main.start_level(false, lvl)
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
	if g.clue_opened.is_connected(main._on_clue):
		g.clue_opened.disconnect(main._on_clue)
	# espera o pré-carregamento terminar (como no celular depois da tela de título)
	for i in 600:
		if Spr.warmed:
			break
		await process_frame
	Spr.trace_late = true
	var xend: float = min(x1, float(g.DOOR.x))
	var x: float = max(x0, float(g.player.x))
	var hist: Array = []
	var worst: Array = []
	while x < xend:
		var fy: float = _ground(x)
		if fy < 90000:
			g.CINE = {}
			g.player.x = x - g.player.w / 2
			g.player.y = fy - g.player.h - 1
			g.player.vx = 0
			g.player.vy = 0
			g.player.hp = 5
			g.player.spawnX = g.player.x
			g.player.spawnY = g.player.y
			g.snap_camera()
			var acc := {}
			var nacc := 0
			var cmin := 1e9
			var dcmax := 0
			var best_prof := {}
			for i in 45:
				g.keys["R"] = i > 3
				g.player.hp = 5
				Spr.prof = {}
				Spr.prof_on = true
				var t0 := Time.get_ticks_usec()
				await process_frame
				var wall := (Time.get_ticks_usec() - t0) / 1000.0
				Spr.prof_on = false
				var cpu := 0.0
				var top := []
				for k in Spr.prof:
					# só as camadas e o passo (as partes internas d_*/p_*/s_* já estão dentro delas)
					if not (str(k).begins_with("d_") or str(k).begins_with("p_") or str(k).begins_with("s_")):
						cpu += Spr.prof[k] / 1000.0
					top.append([Spr.prof[k] / 1000.0, k])
				top.sort_custom(func(a, b): return a[0] > b[0])
				hist.append(cpu)
				if i > 6:
					var dc: int = int(RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME))
					dcmax = max(dcmax, dc)
					if cpu < cmin:
						cmin = cpu
						best_prof = Spr.prof.duplicate()
					nacc += 1
					acc["_cpu"] = acc.get("_cpu", 0.0) + cpu
					for k in Spr.prof:
						acc[k] = acc.get(k, 0.0) + Spr.prof[k] / 1000.0
				if i > 1 and (cpu > 18.0):
					worst.append([cpu, wall, int(g.player.x), i, top.slice(0, 4)])
			g.keys.clear()
			if nacc > 0:
				var ks := []
				for k in acc:
					if k != "_cpu":
						ks.append([acc[k] / nacc, k])
				ks.sort_custom(func(a, b): return a[0] > b[0])
				var bl := []
				for k in best_prof:
					bl.append([best_prof[k] / 1000.0, k])
				bl.sort_custom(func(a, b): return a[0] > b[0])
				var s := ""
				for t in bl.slice(0, 7):
					s += " %s=%.1f" % [t[1], t[0]]
				print("MIN x=%d cpu_min=%.1fms media=%.1f draws=%d |%s" % [int(x), cmin, acc["_cpu"] / nacc, dcmax, s])
		x += step
	hist.sort()
	var med: float = hist[hist.size() / 2] if hist.size() > 0 else 0.0
	print("HITCH quadros=%d mediana_cpu=%.1fms p95=%.1fms max=%.1fms" % [hist.size(), med, hist[int(hist.size() * .95)], hist[-1]])
	worst.sort_custom(func(a, b): return a[0] > b[0])
	for w in worst.slice(0, 40):
		var parts := ""
		for t in w[4]:
			parts += " %s=%.1f" % [t[1], t[0]]
		print("PICO cpu=%.1fms parede=%.0fms x=%d q=%d |%s" % [w[0], w[1], w[2], w[3], parts])
	quit()

## chão firme em x (o mais alto que dá para ficar em pé, longe do teto)
func _ground(x: float) -> float:
	var best := 99999.0
	for s in g.SOL:
		if s.get("deco") or s.get("t", "") in ["crack", "bound", "spike"]:
			continue
		if x >= s.x + 4 and x <= s.x + s.w - 4 and s.y < best and s.y > -400:
			# precisa ter espaço livre em cima
			var free := true
			for o in g.SOL:
				if o == s or o.get("deco") or o.get("oneway"):
					continue
				if x + 10 > o.x and x - 10 < o.x + o.w and o.y < s.y and o.y + o.h > s.y - 70:
					free = false
					break
			if free:
				best = s.y
	return best
