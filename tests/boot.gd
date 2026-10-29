extends SceneTree
## Teste: abre o jogo, começa a fase e roda alguns segundos sem controle.
func _initialize() -> void:
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	main.start_level(false)
	await process_frame
	for c in main.ui_layer.get_children():
		if c.has_method("_end"):
			print("cutscene: ", c.scene_id)
			c._end()
	await process_frame
	main.panel.get_meta("ok").call()
	for i in 120:
		await physics_frame
	var g = main.game
	print("BOOT OK x=", g.player.x, " y=", g.player.y, " onGround=", g.player.onGround, " T=", g.T)
	quit()
