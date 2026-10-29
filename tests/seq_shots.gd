extends SceneTree
## Sequência contínua de capturas (para conferir animações):
## godot -s tests/seq_shots.gd -- x,y "Sp@0;R@5-40;Jp@60" "10,20,30" [setup]
## - Xp@n  aperta a tecla X no quadro n (um toque)
## - X@a-b segura a tecla X do quadro a ao b
## setup: palavras separadas por + (drain, dog, noen, lit, tower)
func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute("/tmp/fh_shots")
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	for i in 3:
		await process_frame
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
	for cid in ["cipo", "mergulho", "neve", "pipoca", "picareta", "cavalo", "mina", "toxico", "javali", "gaviao", "bagre", "urso", "vargas", "bola", "aviao", "jangada", "colmeia", "moinho", "telhados", "carrinho", "sapo", "morcego", "brutus", "vigia"]:
		root.get_node("Save").setv("comic", cid, true)
	var args := OS.get_cmdline_user_args()
	var pos = args[0].split(",")
	var acts: Array = []
	if args.size() > 1 and args[1] != "":
		for a in args[1].split(";"):
			var kv = a.split("@")
			var k: String = kv[0]
			var fr = kv[1].split("-")
			acts.append({"k": k, "a": int(fr[0]), "b": int(fr[1]) if fr.size() > 1 else int(fr[0])})
	var caps: Array = []
	for c in args[2].split(","):
		caps.append(int(c))
	var setup: String = args[3] if args.size() > 3 else ""
	for k in setup.split("+"):
		match k:
			"drain":
				for sw in g.SWAMP:
					if sw.get("id") == "canal":
						sw.y = 640
						sw.drain = true
			"noen":
				for e in g.EN:
					e.dead = 99
			"dog":
				g.X.DOG.st = "follow"
				g.X.DOG.x = float(pos[0]) - 50
				g.X.DOG.y = float(pos[1])
				g.X.TRAIL = [Vector2(float(pos[0]) - 50, float(pos[1]))]
	if "isis" in setup:
		g.begin_isis()
		for e in g.EN:
			e.dead = 99
	if "nocatch" in setup:
		g.VL.no_catch = true
	g.player.x = float(pos[0]) - 12
	g.player.y = float(pos[1]) - (26 if "isis" in setup else 34)
	if "vine" in setup:
		g.player.vine = g.VINES[0]
		g.player.vr = 150.0
		g.VINES[0].om = .02
	g.player.spawnX = g.player.x
	g.player.spawnY = g.player.y
	g.snap_camera()
	var last: int = caps.max()
	var n := 0
	for f in last + 1:
		for a in acts:
			if a.k.ends_with("p") and a.k.length() == 2:
				if f == a.a:
					g.keys[a.k] = true
			else:
				g.keys[a.k] = f >= a.a and f <= a.b
		await physics_frame
		g.player.hp = 3
		if f in caps:
			await process_frame
			root.get_texture().get_image().save_png("/tmp/fh_shots/q%02d.png" % n)
			var k: float = root.get_texture().get_size().y / root.get_visible_rect().size.y
			var sp: Vector2 = root.get_final_transform() * g.get_global_transform_with_canvas() * Vector2(g.player.x + g.player.w / 2, g.player.y + g.player.h)
			print("POS %d %d %d" % [n, int(sp.x), int(sp.y)])
			n += 1
	print("SEQ ", n)
	quit()
