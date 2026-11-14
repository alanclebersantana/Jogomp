extends "res://tests/route_gru.gd"
## Modo ação (fase de teste): um robô simples joga a fase inteira — anda para a direita, bate em quem
## chega perto, usa o dash quando um capanga avisa o bote, sobe no bondinho e vai até a saída.
func alvo():
	var best = null
	var bd := 1e9
	var zid = null
	for z in g.AC.Z:
		if z.a.on and not z.a.done:
			zid = z.id
	if int(g.AC.RIDE.get("st", 0)) == 1:
		zid = "ride"
	for e in g.EN:
		if e.dead or (zid != null and str(e.get("zid", "")) != str(zid)):
			continue
		var d: float = abs(e.x - px())
		if d < bd and d < 900:
			bd = d
			best = e
	return best

func vao(x: float) -> bool:
	for q in g.L.get("pits", []):
		if x > float(q[0]) and x < float(q[1]):
			return true
	return false

func luta(lim: int) -> String:
	var n := 0
	while n < lim:
		n += 1
		P = g.player
		if not g.running:
			return "state"
		var e = alvo()
		var d := {}
		if e != null:
			var dx: float = e.x - px()
			var aereo: bool = e.k in ["fly", "crow"]
			var perigo: bool = str(e.get("gs", "")) in ["wind", "strike"] and abs(dx) < 90
			if perigo and g.AC.dash_cd == 0:
				# dash para longe do bote
				d = {"L": true} if dx > 0 else {"R": true}
				press("F")
			elif aereo:
				if abs(dx) > 40:
					d = {"R": true} if dx > 0 else {"L": true}
				if abs(dx) < 70 and P.onGround and n % 20 == 0:
					press("J")
				if abs(dx) < 80 and n % 6 == 0:
					press("G")
			else:
				var alto: bool = float(e.base) < P.y + P.h - 60
				if abs(dx) > 44:
					d = {"R": true} if dx > 0 else {"L": true}
				elif n % 5 == 0 and not alto:
					P.face = 1 if dx > 0 else -1
					press("G")
				# capanga no andar de cima: sobe na passarela (pulo e pulo duplo) e luta lá
				if alto:
					d = {"R": true} if dx > 0 else {"L": true}
					if abs(dx) < 16:
						d = {}
					if P.onGround and abs(dx) < 150:
						jump_to(clamp(e.x, float(e.r[0]) + 10, float(e.r[1]) - 10), true)
						P = g.player
				# vão no caminho (zona 3): pula
				if P.onGround and vao(px() + (40 if dx > 0 else -40)) and abs(dx) > 44:
					jump_to(px() + (190 if dx > 0 else -190))
					P = g.player
			if g.AC.sp_full() and abs(dx) < 200:
				press("K")
		else:
			return "ok"
		frame(d)
	return "timeout"

func _initialize() -> void:
	var f := 0
	Engine.physics_ticks_per_second = 60
	carregar(2, true)
	g.lives = 99
	var ac = g.AC
	print("fase: ", g.L.name, " zonas=", ac.Z.size(), " passeio=", not ac.RIDE.is_empty())
	# aquecimento: os dois capangas soltos
	walk_to(500)
	print("aquecimento: ", luta(1500), " kos=", ac.kos, " combo max=", ac.best)
	for zi in 2:
		var z = ac.Z[zi]
		var r = walk_to(float(z.a.x0) + 120, 2500)
		var t := 0
		while not z.a.done and t < 6000:
			var lr = luta(40)
			if lr == "ok":
				frame({})
			t += 1
			P = g.player
			P.hp = max(P.hp, 3)
		print("zona ", zi, ": limpa=", z.a.done, " ondas=", z.wi, " kos=", ac.kos, " dano=", ac.hits, " combo max=", ac.best, " x=", int(px()))
		if not z.a.done:
			f += 1
			for e in g.EN:
				if not e.dead:
					print("   vivo: ", e.k, " x=", int(e.x), " y=", int(e.y), " zid=", e.get("zid", "-"), " st=", e.get("gs", ""), " | Milis x=", int(px()), " y=", int(P.y), " on=", z.a.on, " wt=", z.wt)
		for i in 120:
			frame({})
		luta(600)
	# bondinho
	var mv: Dictionary = ac.RIDE.mv
	print("anda até o bondinho: ", walk_to(3860, 3000))
	jump_to(float(mv.plats[0].x) + 120)
	for i in 30:
		frame({})
	print("no bondinho: ", g.MV.on_plat(mv), " st=", ac.RIDE.st)
	var t2 := 0
	while int(ac.RIDE.st) != 2 and t2 < 2400:
		t2 += 1
		P = g.player
		P.hp = max(P.hp, 3)
		var s: Dictionary = mv.plats[0]
		var cxp: float = s.x + s.w / 2
		var e = alvo()
		var d := {}
		if px() < cxp - 60:
			d = {"R": true}
		elif px() > cxp + 60:
			d = {"L": true}
		if e != null and abs(e.x - px()) < 90 and abs(e.y - (P.y + 20)) < 110 and t2 % 6 == 0:
			P.face = 1 if e.x > px() else -1
			press("G")
		frame(d)
	print("vidas antes do passeio=", g.lives) if false else null
	print("passeio: st=", ac.RIDE.st, " quadros=", t2, " x=", int(px()), " y=", int(P.y), " vidas=", g.lives, " kos=", ac.kos)
	if int(ac.RIDE.st) != 2:
		f += 1
	print("desce: ", jump_to(5480), " ", walk_to(5540, 800))
	var z3 = ac.Z[2]
	walk_to(float(z3.a.x0) + 120, 2500)
	var t3 := 0
	while not z3.a.done and t3 < 9000:
		if not z3.a.on:
			walk_to(float(z3.a.x0) + 120, 600)
		luta(40)
		frame({})
		t3 += 1
		P = g.player
		P.hp = max(P.hp, 3)
		if t3 % 400 == 0 and OS.get_environment("DBG") != "":
			var al := []
			for e in g.EN:
				if not e.dead and str(e.get("zid", "")) == "z2":
					al.append("%s/%s@%d,%d %s" % [e.k, e.get("tp", ""), e.x, e.y, e.get("gs", "")])
			print("   t3=", t3, " on=", z3.a.on, " wi=", z3.wi, " P=", int(px()), ",", int(P.y), " vidas=", g.lives, " ", al)
	print("zona final: limpa=", z3.a.done, " ondas=", z3.wi, " kos=", ac.kos, " dano=", ac.hits, " combo max=", ac.best)
	if not z3.a.done:
		f += 1
	for i in 140:
		frame({})
	walk_to(6812, 2500)
	var r2 = until({}, func(): return not g.running, 400)
	print("saída: ", r2, " nota=", ac.rank())
	if not (r2 is String and r2 == "state"):
		f += 1
	print("FALHAS: ", f)
	quit()
