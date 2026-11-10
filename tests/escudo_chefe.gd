extends "res://tests/route_gru.gd"
## Escudo contra o Fiscal Falso: segura as malas caindo e rolando; sem escudo machuca.
func _prep() -> Dictionary:
	carregar(0, false)
	g.lives = 99
	P.x = 14700.0
	P.y = 400.0
	wait_ground()
	walk_to(14820)
	until({}, func(): return g.X.boss_active() and g.X.BOSS.st not in ["wait", "espera"], 600)
	var b: Dictionary = g.X.BOSS
	b.st = "persegue"
	b.t = 0
	b.y = 500.0
	b.objs = []
	b.cool = 0
	b.x = px() + 200
	P.face = 1
	P.iframe = 0
	return b
func _initialize() -> void:
	var f := 0
	# 1) mala caindo em cima do escudo levantado
	var b := _prep()
	b.st = "lasers"
	b.beams = []
	b.floor = []
	b.x = 15480.0
	b.y = 330.0
	b.objs = [{"k": "cai", "x": px(), "y": 500.0, "t": 30, "hy": -260.0}]
	var hp0: int = P.hp
	for i in 60:
		frame({"F": true})
		P.face = 1
	print("mala caindo no escudo: hp ", hp0, "->", P.hp)
	if P.hp != hp0: f += 1
	# 3) mala rolando no escudo
	b = _prep()
	b.st = "lasers"
	b.beams = []
	b.floor = []
	b.x = 15480.0
	b.objs = [{"k": "rola", "x": px() + 120, "vx": -3.0, "rot": 0.0, "wait": 0}]
	hp0 = P.hp
	for i in 80:
		frame({"F": true})
		P.face = 1
	print("mala rolando: hp ", hp0, "->", P.hp, " objs=", b.objs.size())
	if P.hp != hp0: f += 1
	# 4) sem escudo: a mala rolando machuca
	b = _prep()
	b.st = "lasers"
	b.beams = []
	b.floor = []
	b.x = 15480.0
	b.objs = [{"k": "rola", "x": px() + 120, "vx": -3.0, "rot": 0.0, "wait": 0}]
	hp0 = P.hp
	for i in 80:
		frame()
		P.face = 1
		if P.hp < hp0: break
	print("sem escudo: hp ", hp0, "->", P.hp)
	if P.hp == hp0: f += 1
	print("FALHAS: ", f)
	quit()
