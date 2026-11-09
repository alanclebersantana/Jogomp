extends SceneTree
## Capturas da luta com o Fiscal: começo, piso eletrificado, malas e a 3ª fase (perseguição).
func _snap(n: String) -> void:
	root.get_texture().get_image().save_png("/tmp/fh_shots/b_%s.png" % n)

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
	g.player.hp = 99
	g.player.x = 14820
	g.player.y = 440
	var b: Dictionary = g.X.BOSS
	for i in 90:
		await process_frame
	g.CINE.clear()
	if b.get("st", "") in ["wait", "espera", "intro"]:
		b.st = "idle"
	for i in 900:
		await process_frame
		g.CINE.clear()
		g.player.hp = 99
		if b.get("st", "") == "lasers" and str(b.get("beam_k", "")) == "piso" and int(b.get("bt", 0)) > int(b.get("warn", 50)) + 4:
			_snap("piso")
			break
	for i in 400:
		await process_frame
		g.player.hp = 99
		if str(b.get("beam_k", "")) == "rola" and int(b.get("bt", 0)) > 50:
			_snap("rola")
			break
	b.hp = 1
	b.st = "lasers"
	b.queue = ["persegue"]
	b.bt = 999
	for i in 120:
		await process_frame
		g.player.hp = 99
	_snap("persegue")
	quit()
