extends "res://tests/route.gd"
## Teste automático do último trecho do Episódio 2 (a fuga da Isis): sai do quarto pela fresta,
## passa escondida pelo lampião do Vargas, empurra o caixote, atravessa os poços (tábuas podres,
## tábua que vai e vem, corda), engatinha no túnel, vai pelas prateleiras e chega à saída.
##   godot --headless --path . -s tests/isis_test.gd

var ended := false
var IX := 0.0

## anda atrás do Vargas (sem passar na frente dele) até x
func follow_behind(w: Dictionary, x: float, mx: int = 1500):
	for i in mx:
		P = g.player
		if not ok():
			return "state"
		if px() >= x - 4:
			return true
		frame({"R": true} if px() < float(w.x) - 90 or float(w.dir) < 0 and px() < float(w.x) - 300 else {"S": true})
	return "timeout@%d" % int(px())

## espera escondida (abaixada) até a condição
func hide_until(cond: Callable, mx: int = 2400):
	for i in 30:
		if absf(g.player.vx) < .1:
			break
		frame()
	for i in mx:
		P = g.player
		if not ok():
			return "state"
		if cond.call():
			return true
		frame({"S": true})
		if OS.has_environment("VL_DEBUG") and i % 20 == 0:
			print("HIDE i=%d px=%d crouch=%s vx=%.1f slide=%s hid=%s" % [i, int(px() - IX), str(P.crouch), P.vx, str(P.slideT), str(g.VL.hidden(P))])
	return "timeout"

func _initialize() -> void:
	g = load("res://scripts/game.gd").new()
	root.add_child(g)
	g.load_level(1)
	g.results_ready.connect(func(): ended = true)
	g.begin_isis()
	IX = float(g.L.isisPart.spawn[0]) - 170.0
	P = g.player
	S("é a Isis (h=%d)" % int(P.h), P.get("isis") == true and P.h == 26)
	wait_ground()
	for i in 5:
		frame()
	var y0: float = g.player.y
	press("J")
	var top: float = P.y
	for i in 60:
		frame({"J": true})
		top = min(top, g.player.y)
	S("pulo baixo (%d px)" % int(y0 - top), y0 - top < 85 and y0 - top > 55)
	wait_ground()
	# E1: a fresta
	S("passa pela fresta em pé", walk_to(IX + 650))
	S("lápis 1", g.VL.DROPS[0].done)
	# E2: o lampião do Vargas
	var W1: Dictionary = g.VL.WATCH[3]
	S("vigia 1 é o do depósito (subornado)", W1.get("bribed") and absf(float(W1.x0) - (IX + 980)) < 2)
	S("caixote 1", walk_to(IX + 793))
	S("espera escondida ele ir para a direita", hide_until(func(): return float(W1.dir) > 0 and float(W1.x) > IX + 1100 and W1.wait == 0))
	S("vai atrás dele até o caixote", follow_behind(W1, IX + 1350))
	walk_to(IX + 1365)
	S("escondida até ele passar", hide_until(func(): return float(W1.dir) < 0 and float(W1.x) < px() - 60 and W1.wait == 0))
	S("não foi vista", g.VL.caught_n == 0)
	# o caixote até a parede alta
	var cr: Dictionary = {}
	for c in g.M.PUSH:
		if absf(float(c.x) - (IX + 1640)) < 5:
			cr = c
	S("achou o caixote", not cr.is_empty())
	walk_to(float(cr.x) - 20)
	S("empurra até a parede", until({"R": true}, func(): return float(cr.x) + float(cr.w) >= IX + 1818, 700))
	walk_to(float(cr.x) - 30)
	S("sobe no caixote", jump_to(float(cr.x) + 28))
	S("sobe na parede", jump_to(IX + 1885))
	S("em cima da parede", P.y + P.h < 420)
	S("lápis 2", walk_to(IX + 2120) and g.VL.DROPS[1].done)
	# tábuas podres sobre o poço
	walk_to(IX + 2140)
	S("tábua 1", jump_to(IX + 2216))
	S("tábua 2", jump_to(IX + 2336))
	S("tábua 3", jump_to(IX + 2456))
	S("outro lado do poço", jump_to(IX + 2610))
	S("vivo no poço 1", P.y < 500 and px() > IX + 2560)
	# tábua que vai e vem
	walk_to(IX + 2785)
	var mv: Dictionary = {}
	for o in g.MV.MV:
		if o.k == "path" and absf(float(o.x0) - (IX + 2815)) < 3:
			mv = o
	var pl: Dictionary = mv.plats[0]
	S("espera a tábua", until({}, func(): return float(pl.x) < IX + 2830 and float(pl.dx) >= 0, 900))
	S("pula na tábua", jump_to(float(pl.x) + 50))
	S("em cima da tábua", P.get("_g") == pl)
	S("vai junto", until({}, func(): return float(pl.x) + float(pl.w) > IX + 3240, 600))
	S("pula para o chão", jump_to(IX + 3400))
	# a corda
	walk_to(IX + 3488)
	press("J")
	S("agarra a corda", until({"J": true}, func(): return P.get("bar") != null, 60))
	var bb = P.get("bar")
	if bb != null:
		until({"R": true}, func(): return px() > float(bb.x1) - 40, 500)
		press("J")
		S("solta no fim da corda", jump_to(IX + 3960))
	S("lápis 3", walk_to(IX + 4020) and g.VL.DROPS[2].done)
	# E4: o túnel baixo
	walk_to(IX + 4280)
	S("engatinha no túnel", crawl(IX + 4820))
	# E5: prateleiras
	var W2: Dictionary = g.VL.WATCH[4]
	walk_to(IX + 4930)
	S("espera o Vargas ir para a direita", until({}, func(): return float(W2.dir) > 0 and float(W2.x) > IX + 5450 and W2.wait == 0, 2400))
	S("prateleira 1", jump_to(IX + 5040))
	walk_to(IX + 5080)
	S("prateleira 2", jump_to(IX + 5140))
	walk_to(IX + 5175)
	S("prateleira alta", jump_to(IX + 5240))
	walk_to(IX + 5450)
	S("pula a prateleira podre", jump_to(IX + 5590))
	S("até a escada", walk_to(IX + 5785))
	S("sobe a escada", climb_to("U", func(): return P.ladder == null and P.onGround and P.y + P.h <= 262, 400))
	S("lápis 4", walk_to(IX + 6080) and g.VL.DROPS[3].done)
	S("desce os degraus", walk_to(IX + 6420))
	S("não foi vista (2)", g.VL.caught_n == 0)
	# E6: o último lampião
	var W3: Dictionary = g.VL.WATCH[5]
	S("caixote da saída", walk_to(IX + 6633))
	S("espera ele ir para a direita", hide_until(func(): return float(W3.dir) > 0 and float(W3.x) > IX + 6960 and W3.wait == 0))
	S("até o barril", walk_to(IX + 6903))
	S("escondida até ele virar", hide_until(func(): return float(W3.dir) < 0 and float(W3.x) < px() - 60 and W3.wait == 0))
	S("não foi vista (3)", g.VL.caught_n == 0)
	until({"R": true}, func(): return int(g.VL.CATCH.get("t", -1)) >= 0, 600)
	S("o Vargas aparece na saída", int(g.VL.CATCH.t) >= 0)
	for i in 300:
		if ended:
			break
		g.step()
	S("fim (pegou a Isis)", ended)
	S("lápis no caminho: %d/%d" % [g.STATS.pen, g.STATS.penTotal], g.STATS.pen > 0)
	for l in log_lines:
		print(l)
	print("FALHAS: %d" % fails)
	quit(1 if fails > 0 else 0)
