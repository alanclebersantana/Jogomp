extends SceneTree
## Capturas do falso segurança: parado, defendendo (clanc), furioso, investindo, ofegante e caído.
func _snap(n: String) -> void:
	root.get_texture().get_image().save_png("/tmp/fh_shots/seg_%s.png" % n)

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
	var e: Dictionary = g.EN.filter(func(x): return x.k == "boar" and x.x < 2000)[0]
	e.ccd = 9999
	g.player.x = e.x + 110
	g.player.y = 440
	g.player.iframe = 9999
	for i in 40:
		await process_frame
	e.dir = 1
	_snap("parado")
	e.blockT = 14
	await process_frame
	await process_frame
	_snap("defende")
	e.blockT = 0
	e.mad = true
	e.hurtT = 18
	for i in 4:
		await process_frame
	_snap("furioso")
	e.hurtT = 0
	e.wind = 10
	for i in 3:
		await process_frame
	_snap("telegrafa")
	for i in 14:
		await process_frame
	_snap("investe")
	e.charge = false
	e.open = 50
	for i in 6:
		await process_frame
	_snap("ofegante")
	e.open = 0
	e.stun = 60
	e.hp = 1
	e.hitCd = 0
	g.player.x = e.x + 30
	g.kill_enemy(e, "hit")
	for i in 10:
		await process_frame
	_snap("cai")
	for i in 50:
		await process_frame
	_snap("caido")
	quit()
