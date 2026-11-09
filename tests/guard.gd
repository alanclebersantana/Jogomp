extends "res://tests/route_gru.gd"
## Falso segurança: defende de frente, apanha por trás / depois da investida / tonto, fica furioso
## na 1ª pancada e só cai na 3ª (o escudo voa).
func _guarda(face_dir: int, lado: float) -> Dictionary:
	carregar(0, true)
	g.lives = 99
	var e: Dictionary = g.EN.filter(func(x): return x.k == "boar" and x.x < 2000)[0]
	for o in g.EN:
		if o != e:
			o.dead = 99
	e.dir = face_dir
	e.ccd = 9999   # não investe sozinho durante o teste
	P.x = e.x + lado - P.w / 2
	P.y = e.y - P.h
	P.face = -1 if lado > 0 else 1
	P.iframe = 9999
	wait_ground()
	e.dir = face_dir
	return e

func _golpe(e: Dictionary, lado: float) -> void:
	var st0: int = int(e.stun)
	for i in 30:
		frame()   # o combo anterior acaba
	e.stun = st0
	P.x = e.x + lado - P.w / 2
	P.face = -1 if lado > 0 else 1
	e.hitCd = 0
	press("G")
	frame({"G": true})
	for i in 16:
		frame()


func _initialize() -> void:
	var f := 0
	# 1) de frente: defende (não perde vida, empurra o Milis)
	var e := _guarda(1, 50)
	var x0: float = P.x
	_golpe(e, 50)
	print("de frente: hp=", e.get("hp", 3), " blockT=", e.get("blockT", 0), " Milis recuou=", int(P.x - x0))
	if int(e.get("hp", 3)) != 3:
		f += 1
	# 2) por trás: apanha e fica furioso
	e = _guarda(1, -50)
	_golpe(e, -50)
	print("por trás: hp=", e.get("hp", 3), " furioso=", e.get("mad", false), " virou para o Milis=", e.dir == -1)
	if int(e.get("hp", 3)) != 2 or not e.get("mad", false):
		f += 1
	# 3) logo depois da investida (escudo abaixado): apanha de frente
	e.hitCd = 0
	e.hurtT = 0
	e.open = 40
	e.dir = 1
	_golpe(e, 50)
	print("depois da investida: hp=", e.get("hp", 3))
	if int(e.get("hp", 3)) != 1:
		f += 1
	# 4) de frente de novo (sem abertura): defende
	e.open = 0
	e.hurtT = 0
	e.blockT = 0
	e.dir = 1
	_golpe(e, 50)
	print("de frente outra vez: hp=", e.get("hp", 3))
	if int(e.get("hp", 3)) != 1:
		f += 1
	# 5) tonto (aparo): a 3ª pancada derruba e o escudo voa
	e.stun = 80
	e.blockT = 0
	_golpe(e, 50)
	print("3ª pancada: caiu=", e.dead > 0, " escudo voando=", e.has("shd"))
	if not e.dead or not e.has("shd"):
		f += 1
	# 6) pisão de frente: defende (o Milis quica)
	e = _guarda(1, 30)
	P.y = e.y - 190 - P.h
	P.vy = 4.0
	for i in 40:
		frame()
		if P.vy < 0:
			break
	print("pisão de frente: hp=", e.get("hp", 3), " quicou=", P.vy < 0)
	if int(e.get("hp", 3)) != 3:
		f += 1
	# 7) investida: vê o Milis, prepara (telegrafado) e corre; depois abaixa o escudo
	e = _guarda(1, 200)
	e.ccd = 0
	P.iframe = 9999
	var viu := false
	var correu := false
	var abriu := false
	for i in 260:
		frame()
		viu = viu or int(e.get("wind", 0)) > 0
		correu = correu or bool(e.get("charge", false))
		abriu = abriu or int(e.get("open", 0)) > 0
	print("investida: telegrafou=", viu, " correu=", correu, " abaixou o escudo=", abriu)
	if not (viu and correu and abriu):
		f += 1
	# 8) arena de mini-chefe: com o segurança de pé, não dá para passar (nem pulando); depois que ele cai, passa
	for ix in 3:
		carregar(0, true)
		g.lives = 99
		var gs: Array = g.EN.filter(func(x): return x.k == "boar")
		gs.sort_custom(func(a, b): return a.x < b.x)
		var e2: Dictionary = gs[ix]
		for o in g.EN:
			if o != e2:
				o.dead = 99
		var a0: float = float(e2.arena[0])
		var a1: float = float(e2.arena[1])
		P.x = a0 + 20
		P.y = 380
		P.iframe = 99999
		e2.ccd = 99999
		var maxx := 0.0
		for i in 360:
			P.iframe = 99999
			var d := {"R": true}
			if i % 40 == 0:
				press("J")
				d["J"] = true
			frame(d)
			maxx = max(maxx, P.x + P.w)
		var preso: bool = maxx <= a1 + 2
		e2.hp = 1
		e2.stun = 60
		e2.hitCd = 0
		g.kill_enemy(e2, "hit")
		for i in 200:
			frame({"R": true})
		# (na 2ª arena a saída é por cima: a parede da direita é a porta do despacho, de verdade)
		var livre: bool = P.x > a1 or (ix == 1 and g.ARN.active().is_empty() and P.x + P.w > a1 - 20)
		print("arena %d (%d..%d): preso com ele de pé=%s · passou depois=%s" % [ix + 1, int(a0), int(a1), preso, livre])
		if not preso or not livre:
			f += 1
	print("FALHAS: ", f)
	quit()
