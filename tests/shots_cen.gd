extends SceneTree
## Capturas: cenário que reage (máquina de lanche, vaso, carrinho) e cartaz de PROCURADO.
func _snap(n: String) -> void:
	root.get_texture().get_image().save_png("/tmp/fh_shots/cen_%s.png" % n)

func _go(g, x: float) -> void:
	g.player.x = x
	g.player.y = 440
	g.player.vx = 0
	g.player.spawnX = x

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
	g.lives = 99
	g.TC.CH.clear()
	for n in g.L.get("npcs", []):
		n.seen = true
	for e in g.EN:
		e.dead = 99
	g.CLUEGOT[1] = 1
	g.CLUEGOT[2] = 1
	_go(g, 3000)
	for i in 40:
		await process_frame
	_snap("cartaz")
	_go(g, 1180)
	for i in 30:
		await process_frame
	g.player.face = -1
	main._set_key("G", true)
	await process_frame
	main._set_key("G", false)
	for i in 6:
		await process_frame
	_snap("lanche")
	_go(g, 9760)
	for i in 30:
		await process_frame
	g.player.face = 1
	main._set_key("K", true)
	await process_frame
	main._set_key("K", false)
	for i in 14:
		await process_frame
	_snap("carrinho")
	_go(g, 2780)
	for i in 30:
		await process_frame
	main._set_key("G", true)
	await process_frame
	main._set_key("G", false)
	for i in 12:
		await process_frame
	_snap("placa")
	quit()
