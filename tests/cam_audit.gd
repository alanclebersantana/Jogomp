extends SceneTree
## Auditoria da câmera: põe o Tomé em pé em cada superfície da fase (a cada PASSO px) e confere o
## enquadramento que a câmera quer (zoom e altura): Tomé inteiro na tela, com folga em cima e embaixo.
## Uso: godot --headless --path . -s tests/cam_audit.gd   (LVL=1 para o Ep. 2)
func _initialize() -> void:
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	main.set_process(false)   # (sem o mundo montado: a tela principal não precisa rodar)
	var g = main.game
	var lvl := int(OS.get_environment("LVL")) if OS.get_environment("LVL") != "" else 0
	g.load_level(lvl)
	var p: Dictionary = g.player
	var bad := 0
	var n := 0
	var zs := {}
	var x := 100.0
	while x < float(g.L.spanX) - 100.0:
		var tops: Array = []
		for s in g.SOL:
			if s.get("deco") or str(s.get("t", "")) in ["pgate", "gate", "crack", "damwall"]:
				continue
			if x > float(s.x) and x < float(s.x) + float(s.w) and float(s.get("h", 1)) > 0:
				tops.append(float(s.y))
		for l in g.L.get("lily", []):
			if x > float(l.x) and x < float(l.x) + float(l.w):
				tops.append(float(l.y))
		for ty0 in tops:
			if ty0 <= float(g.L.top) + 60.0:
				continue   # topo do paredão no teto da fase (não dá para ficar ali)
			# a superfície precisa estar livre por cima (cabe o Tomé)
			var free := true
			for s in g.SOL:
				if s.get("deco") or str(s.get("t", "")) in ["pgate", "gate", "crack"]:
					continue
				if x > float(s.x) and x < float(s.x) + float(s.w) and float(s.y) < ty0 - 2 and float(s.y) + float(s.get("h", 0)) > ty0 - p.h:
					free = false
			if not free:
				continue
			p.x = x - p.w / 2
			p.y = ty0 - p.h
			g.cam_focus = p.y
			g._tall_cache = {}
			g._base_cache = {}
			g.W = 960.0
			g.H = 540.0
			var z: float = g.tall_zoom(540.0)
			g.W = 960.0 / z
			g.H = 540.0 / z
			g._base_cache = {}
			var t: float = g.cam_ty(x, p.y)
			var cb: Rect2 = g.cam_bounds()
			t = clamp(t, cb.position.y, max(cb.position.y, cb.end.y - g.H))
			var head: float = (p.y - t) / g.H
			var feet: float = (ty0 - t) / g.H
			n += 1
			zs[snappedf(z, .05)] = zs.get(snappedf(z, .05), 0) + 1
			if head < .06 or feet > .95:
				bad += 1
				if bad < 60:
					print("RUIM x=%d y=%d zoom=%.2f cabeça=%.2f pés=%.2f" % [x, ty0, z, head, feet])
		x += 40.0
	print("posições=", n, " ruins=", bad, " zooms=", zs)
	quit()
