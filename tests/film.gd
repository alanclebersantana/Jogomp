extends SceneTree
## Filma o Tomé quadro a quadro (para conferir animação): põe o Tomé em x,y, segue uma sequência de
## teclas e salva recortes em volta dele em /tmp/fh_film/fNNN.png.
## Uso: godot --path . -s tests/film.gd -- x,y[,flags] "R:40,_:10,L:30" de_quadro passo
##   teclas: R, L, J (pulo; "J+Jp" no 1º quadro), S (abaixar), Gp (golpe/arpão); "_" = nada; "R+J" = juntas
##   flags: helmet, fisht, fishs, fishc, lit; env ISO=1 = só o Tomé num fundo liso (sem cenário)
## Cada quadro imprime vx/vy e as molas do desenho (lanterna, pompom, inclinação).
const OUT := "/tmp/fh_film"
func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	for i in 3:
		await process_frame
	var args := OS.get_cmdline_user_args()
	var lvl := int(OS.get_environment("LVL")) if OS.get_environment("LVL") != "" else 0
	main.start_level(false, lvl)
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
	g.lives = 99
	g.clue_opened.disconnect(main._on_clue)
	for cid in ["cipo", "mergulho", "neve", "pipoca", "picareta", "cavalo", "mina", "toxico", "javali", "gaviao", "bagre", "urso", "vargas", "bola", "aviao", "jangada", "colmeia", "moinho", "telhados", "carrinho"]:
		root.get_node("Save").setv("comic", cid, true)
	for e in g.EN:
		e.dead = 99
	var p = args[0].split(",")
	var x := float(p[0])
	var y := float(p[1])
	g.CINE = {}
	g.player.x = x - 12
	g.player.y = y - 34
	g.player.vx = 0
	g.player.vy = 0
	g.player.spawnX = g.player.x
	g.player.spawnY = g.player.y
	if p.size() > 2:
		for k in p[2].split("+"):
			if k == "helmet":
				g.NT.helmet = true
				g.NT.harpoon = true
			elif k == "lit":
				g.lantern_lit = true
			elif k == "fisht" or k == "fishs":
				var f: Dictionary = g.K.FISH
				f.active = true
				f.st = "tired" if k == "fisht" else "suck"
				f.t = 60
				f.x = x + 260
				f.y = y
				f.dir = -1
				g.NT.helmet = true
				g.NT.harpoon = true
			elif k == "fishc":
				var f2: Dictionary = g.K.FISH
				f2.active = true
				f2.st = "charge"
				f2.t = 2
				f2.vx = -6.0
				f2.x = x + 300
				f2.y = y
				f2.dir = -1
				g.NT.helmet = true
				g.NT.harpoon = true
	g.snap_camera()
	if OS.get_environment("ISO") != "":
		# só o Tomé, num fundo liso (para ver a animação sem o cenário)
		RenderingServer.set_default_clear_color(Color(.62, .66, .6))
		for c in g.get_children():
			if c is Camera2D:
				continue
			if c.get_script() and str(c.get_script().resource_path).ends_with("world_dyn.gd"):
				c.self_modulate = Color(1, 1, 1, 0)
				c.en_node.visible = false
				c.front_node.visible = false
			elif c is CanvasItem:
				c.visible = false
		for l in [main.screen_layer, main.hud_layer, main.glow_layer]:
			l.visible = false
		if main.light_map is CanvasItem:
			main.light_map.visible = false
	for i in 30:
		await physics_frame
		g.player.hp = 3
		g.player.iframe = 0
	var seq: Array = []
	for part in args[1].split(","):
		var kv = part.split(":")
		for i in int(kv[1]):
			seq.append(kv[0])
	var from := int(args[2]) if args.size() > 2 else 0
	var stp := int(args[3]) if args.size() > 3 else 1
	var dyn = null
	for c in g.get_children():
		if c.get_script() and str(c.get_script().resource_path).ends_with("world_dyn.gd"):
			dyn = c
	var n := 0
	for i in seq.size():
		g.keys.clear()
		if seq[i] != "_":
			for kk in seq[i].split("+"):
				g.keys[kk] = true
		await physics_frame
		g.player.hp = 3
		g.player.iframe = 0
		if not g.CINE.is_empty():
			g.CINE = {}
		g.player.cheerT = 0
		if i >= from and (i - from) % stp == 0:
			await process_frame
			var img: Image = root.get_texture().get_image()
			var vsz: Vector2 = g.get_viewport().get_visible_rect().size
			var wp := Vector2(g.player.x + g.player.w / 2, g.player.y + g.player.h - 40)
			var sp: Vector2 = (wp - g.camera.position) * g.camera.zoom * (Vector2(img.get_size()) / vsz)
			if i == from:
				print("VP ", vsz, " IMG ", img.get_size(), " CAM ", g.camera.position, " Z ", g.camera.zoom, " SP ", sp)
			var r := Rect2i(int(sp.x) - 110, int(sp.y) - 110, 220, 200)
			r = r.intersection(Rect2i(Vector2i.ZERO, img.get_size()))
			var c: Image = img.get_region(r)
			c.save_png(OUT + "/f%03d.png" % n)
			print("F ", n, " i=", i, " vx=", snapped(g.player.vx, .01), " vy=", snapped(g.player.vy, .01), " face=", g.player.face, " gnd=", g.player.onGround, " swim=", g.player.swim, " act=", g.player.get("act", ""), " fish=", g.K.FISH.get("st", ""), " lan=", snapped(dyn._lan_a, .01), " pom=", dyn._pom.snapped(Vector2(.1, .1)), " lean=", snapped(float(g.player.get("lean", 0.0)), .001))
			n += 1
	print("FILM ", n)
	quit()
