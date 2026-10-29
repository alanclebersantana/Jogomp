extends SceneTree
## Capturas das telas: cenas da história, mochila, pista 6, mapa, opções, galeria e placar.
var main

func _snap(n: String, frames: int = 6) -> void:
	for i in frames:
		await process_frame
	root.get_texture().get_image().save_png("/tmp/fh_shots/u_%s.png" % n)

func _cut() -> Node:
	for c in main.ui_layer.get_children():
		if c.has_method("_end") and not c.done:
			return c
	return null

## avança a cena até o quadro i, no ponto k (0..1) do quadro
func _cut_shot(n: String, i: int, k: float) -> void:
	var c = _cut()
	c.idx = i
	c.t = c.shots[i].dur * k
	c.set_process(false)
	c.fade = 0.0
	c.queue_redraw()
	await _snap(n, 3)
	c.set_process(true)

func _initialize() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	for i in 3:
		await process_frame
	await _snap("title")
	main.start_level(false)
	await process_frame
	for i in 4:
		await _cut_shot("cut_ab%d" % i, i, .75)
	_cut()._end()
	await process_frame
	main.panel.get_meta("ok").call()
	var g = main.game
	g.INV = ["corda", "gancho", "engrenagem", "oleo", "picareta"]
	g.CLUEGOT[1] = 1
	g.CLUEGOT[3] = 1
	g.SPECGOT["verde"] = 1
	g.SPECGOT["azul"] = 1
	for c in g.CLUES:
		if int(c.id) in [1, 3]:
			c.got = true
	g.max_x = 6500
	g.player.x = 6200
	main.open_bag()
	await _snap("bag")
	main.show_map(false, true)
	await _snap("map")
	main.close_panel()
	g.CLUEGOT[6] = 1
	main._on_clue(6)
	await process_frame
	await _cut_shot("cut_cr0", 0, .3)
	await _cut_shot("cut_cr1", 1, .8)
	_cut()._end()
	await _snap("clue")
	main.close_panel()
	main.show_options(false)
	await _snap("options")
	for c in ["vermelho", "laranja", "amarelo", "roxo"]:
		g.SPECGOT[c] = 1
	g.STATS.pen = 99
	main._on_level_end()
	await process_frame
	await _cut_shot("cut_mi0", 0, .45)
	await _cut_shot("cut_mi1", 1, .9)
	_cut()._end()
	await _snap("res")
	main.play_cut("posfinal", func(): pass)
	await process_frame
	await _cut_shot("cut_pf0", 0, .7)
	await _cut_shot("cut_pf1", 1, .9)
	await _cut_shot("cut_pf2", 2, .8)
	_cut()._end()
	root.get_node("Save").setv("gallery", "d0", true)
	main.show_gallery()
	await _snap("gallery")
	quit()
