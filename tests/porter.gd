extends "res://tests/route_gru.gd"
## Falso carregador: vê o Milis, ergue a mala (aviso) e arremessa; rebatida com o bastão, a mala volta e o derruba.
func _initialize() -> void:
	var f := 0
	carregar(0, true)
	g.lives = 99
	var e: Dictionary = g.EN.filter(func(x): return x.k == "porter")[0]
	for o in g.EN:
		if o != e:
			o.dead = 99
	P.x = e.x - 260
	P.y = e.y - P.h
	P.face = 1
	P.iframe = 0
	P.hp = 5
	e.tcd = 0
	wait_ground()
	var saw_thr := false
	var saw_mala := false
	for i in 120:
		frame()
		if int(e.get("thr", 0)) > 0:
			saw_thr = true
		if e.get("mala") != null:
			saw_mala = true
			break
	print("ergueu a mala=", saw_thr, " arremessou=", saw_mala)
	if not saw_mala:
		f += 1
	# rebater: espera a mala chegar perto e golpeia
	var hit := false
	for i in 80:
		var m = e.get("mala")
		if m == null:
			break
		if abs(m.x - (P.x + P.w / 2 + 28)) < 40 and not hit:
			press("G")
			frame({"G": true})
			hit = true
		else:
			frame()
	for i in 80:
		frame()
		if e.dead:
			break
	print("rebateu=", hit, " carregador caiu=", e.dead > 0, " hp do Milis=", P.hp)
	if not e.dead:
		f += 1
	print("FALHAS: ", f)
	quit()
