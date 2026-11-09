extends SceneTree
## Capturas da luta: botões novos, defesa (escudo), giro do combo e voadora.
func _snap(n: String) -> void:
	root.get_texture().get_image().save_png("/tmp/fh_shots/l_%s.png" % n)

func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute("/tmp/fh_shots")
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
	g.TC.CH.clear()
	g.player.x = 4220
	g.player.y = 440
	for i in 30:
		await process_frame
	main._set_key("F", true)
	for i in 8:
		await process_frame
	_snap("defesa")
	main._set_key("F", false)
	await process_frame
	for k in 3:
		main._set_key("G", true)
		await process_frame
		main._set_key("G", false)
		for i in 9:
			await process_frame
	for i in 4:
		await process_frame
	_snap("giro")
	for i in 30:
		await process_frame
	main._set_key("J", true)
	for i in 10:
		await process_frame
	main._set_key("K", true)
	for i in 4:
		await process_frame
	main._set_key("K", false)
	main._set_key("J", false)
	_snap("voadora")
	quit()
