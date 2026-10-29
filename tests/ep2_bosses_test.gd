extends "res://tests/route2.gd"
## Os três chefes do Episódio 2 (Brutus na corrente, Morcego-Rei das lamparinas, Sapo-Rei das colmeias):
## teleporta para perto de cada arena e joga a luta inteira.
##   godot --headless --path . -s tests/ep2_bosses_test.gd

func _at(x: float, y: float) -> void:
	g.CINE = {}
	P = g.player
	P.x = x - P.w / 2
	P.y = y - P.h
	P.vx = 0.0
	P.vy = 0.0
	P.spawnX = P.x
	P.spawnY = P.y
	P.hp = 5
	g.snap_camera()
	frame()

func _initialize() -> void:
	g = load("res://scripts/game.gd").new()
	root.add_child(g)
	g.load_level(1)
	g.no_coal = true
	g.lives = 99
	for e in g.EN:
		e.dead = 99
	P = g.player
	var only: String = OS.get_environment("CHEFE")
	# ---- Brutus (no Ep. 2 o Pipoca não vem junto: o Tomé provoca do chão)
	if only == "" or only == "brutus":
		_at(22980, 500)
		S("Brutus", brutus_fight())
		S("Brutus desistiu", g.X.BOSS.done or g.X.BOSS.st == "down")
		S("portão do quintal aberto", walk_to(float(g.X.BOSS.x1) + 60))
	# ---- Morcego-Rei
	if only == "" or only == "morcego":
		g.lantern_lit = true
		_at(25300, 500)
		S("entra na caverna", until({"R": true}, func(): return g.K.HAWK.active, 400))
		S("vence o Morcego-Rei", bat_fight())
	# ---- Sapo-Rei
	if only == "" or only == "sapo":
		_at(14680, -150)
		S("primeira vitória-régia", jump_to(14826))
		S("entra na arena do Sapo-Rei", until({}, func(): return g.K.FISH.active, 200))
		S("vence o Sapo-Rei", frog_fight())
	for l in log_lines:
		print(l)
	print("FALHAS: ", fails)
	quit()
