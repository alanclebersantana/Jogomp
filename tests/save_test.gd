extends SceneTree
## Teste: salvar na fogueira e continuar mantém picareta, laje quebrada, grades abertas, lápis dourado e chefe vencido.
func _initialize() -> void:
	var save = root.get_node("Save")
	var g = load("res://scripts/game.gd").new()
	root.add_child(g)
	g.load_level(0)
	g.INV.append("picareta")
	g.X.boss_finish_silent()
	for it in g.ITEMS:
		if it.id == "picareta":
			it.got = true
	g.X.BOSS.done = true
	for c in g.X.CRACKS:
		g.X.break_crack(c, false)
	g.X.GOLD.got = true
	g.X.found["s1"] = true
	g.X.DOG.st = "follow"
	g.X.TOCAS[0].done = true
	g.save_checkpoint(6)
	var run: Dictionary = save.load_run()
	var g2 = load("res://scripts/game.gd").new()
	root.add_child(g2)
	g2.restore_run(run)
	var ok: bool = g2.X.BOSS.done and g2.INV.has("picareta") and g2.X.broken.size() == 3 and g2.X.GOLD.got and g2.X.found.has("s1") and g2.X.dog_free() and g2.X.TOCAS[0].done
	var no_bars := true
	for s in g2.SOL:
		if s.get("id") == "cdoor" or s.t == "crack":
			no_bars = false
	print("SAVE ", "OK" if ok and no_bars else "FALHOU", " ", g2.X.save_data())
	save.clear_run()
	quit()
