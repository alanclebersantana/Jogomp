extends SceneTree
## Poses de luta do Milis num lugar aberto do saguão: defesa, rasteira, voadora, esquiva.
func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute("/tmp/fh_shots")
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	for i in 3:
		await process_frame
	for cid in ["seguranca", "drone", "vento", "fiscal"]:
		root.get_node("Save").setv("comic", cid, true)
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
	g.TC.CH.clear()
	for e in g.EN:
		e.dead = 99
	var shots := []
	for nm in ["guard", "sweep", "flykick", "dodge"]:
		g.player.x = 620
		g.player.y = 440
		g.player.vx = 0
		for i in 20:
			await process_frame
		if nm == "guard":
			main._set_key("F", true)
			for i in 6:
				await process_frame
		else:
			g.player.act = nm
			g.player.actT = 20
			await process_frame
			await process_frame
		var im: Image = root.get_texture().get_image()
		shots.append(im)
		main._set_key("F", false)
	var W: int = shots[0].get_width()
	var out := Image.create(4 * 240, 200, false, Image.FORMAT_RGBA8)
	for i in 4:
		var px: int = int((g.player.x - g.cam) * 0) # (só recorta o meio da tela)
		out.blit_rect(shots[i], Rect2i(W / 2 - 220, 240, 240, 200), Vector2i(i * 240, 0))
	out.save_png("/tmp/fh_shots/poses.png")
	for i in 4:
		shots[i].save_png("/tmp/fh_shots/pose%d.png" % i)
	quit()
