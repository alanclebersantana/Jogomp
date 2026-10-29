extends SceneTree
## Mede quanto cada efeito de tela custa no quadro (desliga um por vez).
## Uso: xvfb-run godot --path . -s tests/bench_fx.gd
var main
var g
func _initialize() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	for i in 3:
		await process_frame
	var sv = root.get_node("Save")
	for cid in ["cipo", "mergulho", "neve", "pipoca", "cavalo", "mina", "toxico", "javali", "gaviao", "bagre", "urso", "vargas", "bola", "aviao", "jangada", "colmeia"]:
		sv.setv("comic", cid, true)
	main.start_level(false)
	await process_frame
	if main.panel and main.panel.has_meta("ok"):
		main.panel.get_meta("ok").call()
		await process_frame
	for c in main.ui_layer.get_children():
		if c.has_method("_end"):
			c._end()
	await process_frame
	if main.panel and main.panel.has_meta("ok"):
		main.panel.get_meta("ok").call()
	g = main.game
	g.lives = 99
	g.clue_opened.disconnect(main._on_clue)
	var spots := [["tarde", 8300, 500], ["pântano", 17500, 500], ["noite", 65000, 230]]
	for sp in spots:
		g.player.x = sp[1] - 12
		g.player.y = sp[2] - 34
		g.player.spawnX = g.player.x
		g.player.spawnY = g.player.y
		g.snap_camera()
		for i in 20:
			await process_frame
		var line: String = "%-8s" % sp[0]
		for mode in ["base", "luzes", "sky", "tela", "glow", "front", "hud", "tudo"]:
			_tog(mode, false)
			for i in 5:
				await process_frame
			var t0 := Time.get_ticks_usec()
			for i in 40:
				g.player.hp = 5
				await process_frame
			line += " %s=%5.1fms" % [mode, (Time.get_ticks_usec() - t0) / 40000.0]
			_tog(mode, true)
		print(line)
	quit()

func _tog(mode: String, on: bool) -> void:
	for c in g.get_children():
		if mode in ["tudo"] and c.get_script() and str(c.get_script().resource_path).ends_with("bg.gd"):
			if on:
				var bm := ShaderMaterial.new()
				bm.shader = load("res://scripts/blur.gdshader")
				c.material = bm
			else:
				c.material = null
		if mode in ["luzes", "tudo"] and c is PointLight2D:
			c.visible = on
	for c in main.screen_layer.get_children():
		var p: String = str(c.get_script().resource_path) if c.get_script() else ""
		if (mode in ["sky", "tudo"] and p.ends_with("sky_fx.gd")) or (mode in ["tela", "tudo"] and p.ends_with("screen_fx.gd")) or (mode in ["front", "tudo"] and p.ends_with("front.gd")):
			c.visible = on
	if mode in ["glow", "tudo"]:
		main.glow_layer.visible = on
	if mode in ["hud", "tudo"]:
		main.hud_layer.visible = on
