extends "res://tests/route_gru.gd"
## Teste dos botões de luta (1-1): combo do bastão, rasteira, voadora, esquiva e aparo.
func _perto_do_cambista() -> Dictionary:
	carregar(0, true)
	g.lives = 99
	var e: Dictionary = g.EN.filter(func(x): return x.k == "boar" and x.x > 3000)[0]
	P.x = e.x + 60
	P.y = e.y - P.h
	P.face = -1
	e.stun = 400   # parado para o teste (tonto ainda apanha)
	wait_ground()
	return e

func _initialize() -> void:
	var f := 0
	# combo: 3 toques seguidos no golpe
	var e := _perto_do_cambista()
	P.x = e.x + 50
	var acts := []
	for k in 3:
		press("G")
		frame({"G": true})
		acts.append(P.act)
		for i in 11:
			frame()
	print("combo: ", acts, " hp do cambista=", e.get("hp", 3), " morto=", e.dead > 0)
	if acts[0] != "swing" or acts[2] != "spin":
		f += 1
	# rasteira
	e = _perto_do_cambista()
	P.x = e.x + 60
	P.face = -1
	press("K")
	frame({"K": true})
	var a1: String = P.act
	for i in 20:
		frame()
	print("rasteira: act=", a1, " hp=", e.get("hp", 3))
	if a1 != "sweep" or int(e.get("hp", 3)) >= 3:
		f += 1
	# voadora
	e = _perto_do_cambista()
	P.x = e.x + 130
	press("J")
	frame({"J": true})
	var ur = until({"J": true}, func(): return not P.onGround and P.vy > -6, 40)
	P.face = -1
	print("antes da voadora: chão=", P.onGround, " vy=", P.vy, " y=", int(P.y), " until=", ur)
	press("K")
	frame({"K": true})
	var a2: String = P.act
	for i in 40:
		frame()
	print("voadora: act=", a2, " hp=", e.get("hp", 3))
	if a2 != "flykick":
		f += 1
	# esquiva (num lugar aberto do saguão)
	carregar(0, false)
	P.x = 500
	wait_ground()
	var x0: float = P.x
	press("F")
	frame({"F": true, "R": true})
	print("esquiva: act=", P.act, " iframe=", P.iframe)
	for i in 12:
		frame({"R": true})
	print("esquiva andou ", int(P.x - x0))
	if P.x - x0 < 60:
		f += 1
	# defesa segurando
	e = _perto_do_cambista()
	for i in 10:
		frame({"F": true})
	print("defesa: guard=", P.guard)
	if not P.guard:
		f += 1
	print("FALHAS: %d" % f)
	quit()
