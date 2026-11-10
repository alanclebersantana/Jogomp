extends "res://tests/route_gru.gd"
## Escudo contra o Fiscal Falso: segura o encontrão (aparo deixa tonto), arrebenta mala rolando; sem escudo machuca.
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
	# 1) segurando o escudo: não perde vida, ele quica
	var b := _prep()
	var hp0: int = P.hp
	for i in 120:
		frame({"F": true})
		P.face = 1
		if int(b.get("cool", 0)) > 0:
			break
	print("escudo segurou: hp ", hp0, "->", P.hp, " cool=", int(b.get("cool", 0)), " st=", b.st)
	if P.hp != hp0 or int(b.get("cool", 0)) == 0: f += 1
	# 2) aparo: aperta a defesa quando ele está chegando
	b = _prep()
	for i in 200:
		var d := {}
		if absf(b.x - px()) < 70 and not g.keys.get("F", false):
			press("F")
			d["F"] = true
		elif g.keys.get("F", false):
			d["F"] = true
		frame(d)
		P.face = 1
		if b.st == "tonto" or int(b.get("cool", 0)) > 0:
			break
	print("aparo: st=", b.st)
	if b.st != "tonto": f += 1
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
	# 4) sem escudo: machuca
	b = _prep()
	hp0 = P.hp
	for i in 120:
		frame()
		P.face = 1
		if P.hp < hp0: break
	print("sem escudo: hp ", hp0, "->", P.hp)
	if P.hp == hp0: f += 1
	print("FALHAS: ", f)
	quit()
