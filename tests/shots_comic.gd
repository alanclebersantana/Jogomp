extends SceneTree
## Captura dos quadrinhos novos do aeroporto (seguranca, drone, vento, fiscal).
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
	for id in ["seguranca", "fiscal"]:
		main._show_comic(id)
		for i in 230:
			await process_frame
		root.get_texture().get_image().save_png("/tmp/fh_shots/hq_%s.png" % id)
		for c in main.ui_layer.get_children():
			if c.has_method("skip"):
				c._end()
		await process_frame
	quit()
