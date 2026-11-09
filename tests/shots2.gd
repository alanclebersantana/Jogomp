extends SceneTree
## Capturas das novidades da 1-1: perseguição do vulto, esteira, carrinho, objetos da frente e expressões.
func _snap(n: String) -> void:
	root.get_texture().get_image().save_png("/tmp/fh_shots/n_%s.png" % n)

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
	g.flash("", 1)
	# 1) perseguição 1 logo no começo
	g.player.x = 200
	main._set_key("R", true)
	for i in 40:
		await process_frame
	_snap("vulto1")
	for i in 60:
		await process_frame
	_snap("vulto2")
	main._set_key("R", false)
	# 2) esteira do check-in + perseguição 2
	g.player.x = 3160
	g.player.y = 460
	main._set_key("R", true)
	for i in 30:
		await process_frame
	_snap("esteira")
	main._set_key("R", false)
	# 3) carrinho
	g.player.x = 13360
	g.player.y = 460
	for i in 20:
		await process_frame
	_snap("carrinho_parado")
	g.CART.start()
	for i in 14:
		await process_frame
	_snap("carrinho_andando")
	main._set_key("S", true)
	for i in 6:
		await process_frame
	_snap("carrinho_abaixado")
	main._set_key("S", false)
	# 4) objeto da frente
	g.CART.on = false
	g.player.x = 10700
	g.player.y = 460
	for i in 25:
		await process_frame
	_snap("frente")
	quit()
