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
	g.auto_cine = true
	g.player.x = 14826 - 12
	g.player.y = -150 - 34
	g.player.spawnX = g.player.x
	g.player.spawnY = g.player.y
	g.snap_camera()
	var n := 0
	var died := false
	var after := -1
	for f in 3000:
		await physics_frame
		var cap := false
		if f % 150 == 0 and f < 1500:
			cap = true
		if g.player.dyingT > 0 and not died:
			died = true
			print("MORREU f=", f)
			cap = true
		if died and g.player.dyingT == 0 and after < 0:
			after = f
			print("VOLTOU f=", f, " p=", g.player.x, ",", g.player.y, " frog=", g.K.FISH.st)
		if after >= 0 and (f - after) in [5, 60, 200, 400]:
			cap = true
			print("  +", f - after, " frog st=", g.K.FISH.st, " active=", g.K.FISH.active, " x=", g.K.FISH.x, " y=", g.K.FISH.y, " P=", int(g.player.x), ",", int(g.player.y), " swim=", g.player.swim, " hp=", g.player.hp)
		if after >= 0 and f - after > 410:
			break
		if cap:
			await process_frame
			root.get_texture().get_image().save_png("/tmp/fh_shots/q%02d.png" % n)
			n += 1
	quit()
