extends SceneTree
## Mede o custo por quadro (em µs) de cada parte do desenho e da lógica, em vários pontos da fase.
## Uso: xvfb-run godot --path . -s tests/bench.gd
var main
var g
func _initialize() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	for i in 3:
		await process_frame
	var sv = root.get_node("Save")
	for cid in ["cipo", "mergulho", "neve", "pipoca", "cavalo", "mina", "toxico", "javali", "gaviao", "bagre", "urso", "vargas", "bola", "aviao", "jangada"]:
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
	var spots := [["tarde copas", 8300, -10], ["pântano", 17500, 500], ["corredeira", 26500, 500], ["neve", 33500, 500], ["urso", 50400, 500], ["céu", 54000, 190], ["cogumelos", 65000, 230], ["mina", 72900, 500]]
	var Spr = root.get_node("Spr")
	for sp in spots:
		g.CINE = {}
		g.VH.mode = ""
		g.player.x = sp[1] - 12
		g.player.y = sp[2] - 34
		g.player.vx = 0
		g.player.vy = 0
		g.player.spawnX = g.player.x
		g.player.spawnY = g.player.y
		g.snap_camera()
		for i in 20:
			await process_frame
		Spr.prof = {}
		Spr.prof_on = true
		var t0 := Time.get_ticks_usec()
		var n := 90
		for i in n:
			g.keys["R"] = i % 60 < 40
			g.player.hp = 5
			await process_frame
		var wall: float = (Time.get_ticks_usec() - t0) / float(n)
		Spr.prof_on = false
		var line := "%-12s quadro=%5.0f µs " % [sp[0], wall]
		var ks: Array = Spr.prof.keys()
		ks.sort()
		for k in ks:
			line += " %s=%4.0f" % [k, Spr.prof[k] / float(n)]
		print(line)
	quit()
