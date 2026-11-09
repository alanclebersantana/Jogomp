extends "res://tests/route_gru.gd"
## Teste do carrinho de bagagem (1-1): sobe, pula as malas, abaixa nas placas e chega no fim.
## Também confere que, sem pular, ele bate e cai do carrinho. Uso: godot --headless -s tests/cart.gd [-- inimigos]

func _go(com: bool, smart: bool) -> String:
	carregar(0, com)
	g.lives = 99
	var C: Dictionary = g.L.cartRide
	P.x = float(C.x0) - 60
	P.y = float(C.y) - P.h
	P.spawnX = P.x
	P.spawnY = P.y
	wait_ground()
	walk_to(float(C.x0))
	until({}, func(): return P.onGround, 60)
	press("A")
	frame()
	if not g.CART.on:
		return "não subiu (near=%s x=%d)" % [g.CART.near(), int(px())]
	var hurt0: int = g.lives
	var jh := 0
	for i in 1200:
		var d := {}
		if jh > 0:
			jh -= 1
			d["J"] = true
		if smart:
			for o in C.obs:
				var ahead: float = float(o.x) - (P.x + P.w)
				if o.k == "pile" and ahead > 0 and ahead < 40 and P.onGround:
					press("J")
					d["J"] = true
					jh = 14
				if o.k == "low" and ahead > -float(o.w) - 10 and ahead < 46:
					d["S"] = true
		frame(d)
		if not g.CART.on:
			break
	if g.CART.done:
		return "chegou" + (" (bateu %d)" % (hurt0 - g.lives) if g.lives < hurt0 else "")
	return "bateu em x=%d" % int(px())

func _initialize() -> void:
	var r1 := _go(false, true)
	print("esperto: ", r1)
	var r2 := _go(false, false)
	print("sem pular: ", r2)
	var r3 := _go(true, true)
	print("com inimigos: ", r3)
	var ok1: bool = r1 == "chegou"
	var ok2: bool = r2.begins_with("bateu")
	print("FALHAS: %d" % [(0 if ok1 else 1) + (0 if ok2 else 1)])
	quit()
