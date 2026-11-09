extends "res://tests/route_gru.gd"
## Equipamentos: botas-foguete (duto alto do começo), gancho magnético (mala presa no alto, ímã no
## teto em cima do vão das bandejas, arrancar o escudo do falso segurança).
func _rocket_try(com_botas: bool) -> float:
	carregar(0, false)
	if com_botas:
		g.INV.append("botas_foguete")
	P.x = 330.0
	P.y = 440.0
	wait_ground()
	# pula para a esquerda: pulo, duplo no alto, foguete no alto do duplo
	press("J")
	frame({"J": true, "L": true})
	var st := 0
	for i in 160:
		var d := {"J": true, "L": px() > 230}
		if st == 0 and P.vy > -1:
			press("J")
			st = 1
		elif st == 1 and P.vy > -1 and i > 20:
			press("J")
			st = 2
		frame(d)
		if P.onGround and i > 5:
			break
	return P.y + P.h

func _initialize() -> void:
	var f := 0
	var sem: float = _rocket_try(false)
	var com: float = _rocket_try(true)
	print("duto alto: sem botas pousou y=", int(sem), " · com botas y=", int(com))
	if sem < 400 or com > 215:
		f += 1
	# mala presa no alto do painel
	carregar(0, false)
	g.INV.append("gancho")
	P.x = 1225.0
	P.y = 440.0
	wait_ground()
	var c0: int = g.coins
	press("J")
	frame({"J": true})
	for i in 30:
		frame({"J": true})
		if P.vy > -2:
			break
	g.keys["Ap"] = true
	for i in 120:
		frame()
	print("mala presa: caiu=", g.GD.STUCK[0].st == 2, " milhas +", g.coins - c0)
	if g.GD.STUCK[0].st != 2 or g.coins - c0 < 15:
		f += 1
	# ímã no teto em cima do vão das bandejas
	carregar(0, false)
	g.INV.append("gancho")
	P.x = 8150.0
	P.y = 440.0
	P.face = 1
	wait_ground()
	g.keys["Ap"] = true
	frame()
	for i in 12:
		frame()
	var pendurou: bool = P.vine is Dictionary and P.vine.get("hook", false)
	var solto := false
	var prev: float = px()
	var maxx: float = 0.0
	for i in 600:
		var dxp: float = px() - prev
		prev = px()
		maxx = max(maxx, px())
		if not solto and P.vine and px() > 8400 and dxp > 0 and i > 30:
			press("J")
			frame({"J": true, "R": true})
			solto = true
			continue
		frame({"R": true})
		if solto and P.onGround:
			break
	print("ímã: pendurou=", pendurou, " atravessou=", px() > 8480, " x=", int(px()), " mais longe=", int(maxx), " solto=", solto)
	if not pendurou or px() < 8480:
		f += 1
	# arrancar o escudo do falso segurança e bater de frente
	carregar(0, true)
	g.INV.append("gancho")
	g.lives = 99
	var e: Dictionary = g.EN.filter(func(x): return x.k == "boar" and x.x < 2000)[0]
	for o in g.EN:
		if o != e:
			o.dead = 99
	e.ccd = 9999
	P.x = e.x + 105
	P.y = 440
	P.face = -1
	P.iframe = 9999
	wait_ground()
	e.dir = 1
	P.face = -1
	print("   alvo=", g.GD.target().get("kind", "nenhum"), " base=", g.use_available_base(), " ex=", int(e.x), " px=", int(px()), " dir=", e.dir, " face=", P.face)
	g.keys["Ap"] = true
	for i in 14:
		frame()
	var sem_escudo: bool = int(e.get("disarm", 0)) > 0
	P.x = e.x + 45 - P.w / 2
	P.face = -1
	e.dir = 1
	press("G")
	frame({"G": true})
	for i in 16:
		frame()
	print("escudo arrancado=", sem_escudo, " · golpe de frente hp=", e.get("hp", 3))
	if not sem_escudo or int(e.get("hp", 3)) != 2:
		f += 1
	print("FALHAS: ", f)
	quit()
