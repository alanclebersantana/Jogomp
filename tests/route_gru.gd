extends "res://tests/route.gd"
## Teste automático das fases de Guarulhos: um robô joga cada fase do começo ao fim, pegando
## pistas, cartões dourados e o segredo. Uso:
##   godot --headless --path . -s tests/route_gru.gd              (todas as fases, sem inimigos)
##   godot --headless --path . -s tests/route_gru.gd -- 1         (só a fase 1-1)
##   godot --headless --path . -s tests/route_gru.gd -- 1 inimigos

var nome_fase := ""

func cartoes() -> int:
	return g.DRWS.filter(func(d): return d.got).size()

func carregar(i: int, com_inimigos: bool) -> void:
	if g:
		g.queue_free()
	g = load("res://scripts/game.gd").new()
	root.add_child(g)
	g.load_level(i)
	g.no_coal = true
	if not com_inimigos:
		for e in g.EN:
			e.dead = 99
	P = g.player
	g.rest_reached.connect(func(n):
		rests.append(n)
		g.running = true)
	nome_fase = str(g.L.name)

## pulo + pulo duplo + asas segurando, indo até x (pousa onde der)
func planar_ate(x: float, mx: int = 500):
	press("J")
	var dj := false
	for i in mx:
		P = g.player
		if not ok():
			return "state"
		var d := {}
		if px() < x - 5:
			d = {"R": true}
		elif px() > x + 5:
			d = {"L": true}
		if not dj and i > 12 and P.vy > -1:
			press("J")
			dj = true
		d["J"] = true
		d["P"] = dj and i > 30
		frame(d)
		P = g.player
		if P.onGround and i > 3:
			return true
	return "air"

## espera a plataforma que anda chegar perto de (x,y) e pula nela; fica em cima até ela chegar
## perto de (x2,y2)
func esteira(idx: int, x_embarque: float, x2: float, y2: float):
	var o: Dictionary = g.MV.MV[idx]
	var s: Dictionary = o.plats[0]
	var r = until({}, func(): return abs(s.x + s.w / 2 - x_embarque) < 30 and s.y > P.y + P.h - 40 and s.y < P.y + P.h + 40, 900)
	if not (r is bool and r):
		return "esteira não veio: " + str(r)
	r = jump_to(s.x + s.w / 2)
	if not (P.onGround and g.MV.on_plat(o)):
		return "não subiu na esteira x=%d y=%d" % [int(px()), int(P.y)]
	r = until({}, func():
		var cx: float = s.x + s.w / 2
		if P.onGround and g.MV.on_plat(o):
			# fica no meio da tábua
			if px() < cx - 10:
				frame({"R": true})
			elif px() > cx + 10:
				frame({"L": true})
		return abs(s.x - x2) < 12 and abs(s.y - y2) < 12, 900)
	return r

## sobe no vento planando e vai para a direita até pousar em x
func vento_ate(x: float, y_alto: float):
	press("J")
	for i in 14:
		frame({"J": true})
	press("J")
	for i in 600:
		P = g.player
		var d := {"J": true, "P": true}
		if P.y < y_alto:
			d["R"] = true
		frame(d)
		P = g.player
		if P.onGround and i > 10:
			if px() >= x - 60:
				return true
			return "pousou em %d,%d" % [int(px()), int(P.y)]
	return "timeout %d,%d" % [int(px()), int(P.y)]

func pegou(id: String) -> bool:
	return g.INV.has(id)

func fase_1_1() -> void:
	walk_to(760)
	S("caixa de milhas", jump_to(900))
	S("cambista", walk_to(1460))
	walk_to(1470)
	S("bancos", jump_to(1580))
	walk_to(1690)
	S("coluna do painel (pulo duplo)", jump_to(1960, true))
	walk_to(2030)
	S("desce", jump_to(2200))
	walk_to(2640)
	S("caixa do coração", jump_to(2760))
	S("degrau 1", jump_to(2840, true))
	S("degrau 2", jump_to(3020, true))
	S("degrau 3", jump_to(3200, true))
	S("cartão 1", cartoes() == 1)
	walk_to(3255)
	S("desce do alto", jump_to(3420))
	# check-in
	walk_to(3560)
	S("balcão 1", jump_to(3670))
	walk_to(3730)
	S("caixa no chão", jump_to(3870))
	walk_to(3860)
	S("balcão 2", jump_to(3970))
	walk_to(4030)
	S("balcão 3", jump_to(4270))
	walk_to(4330)
	S("esteira de despacho", esteira(0, 4455, 4680, 230))
	S("sobe nas balanças", jump_to(4860))
	S("pista 1", walk_to(5060) and n_clues() == 1)
	walk_to(5090)
	S("plana por cima da fila", planar_ate(5560))
	walk_to(5610)
	S("ilha 2", jump_to(5960, true))
	walk_to(5915)
	S("desce atrás do caixote", until({"L": true}, func(): return P.onGround and P.y > 400, 200))
	walk_to(5990)
	S("empurra o caixote", until({"R": true}, func(): return g.M.PUSH[0].x >= 6299 and g.M.PUSH[0].y >= 449, 900))
	S("catraca abriu", until({}, func(): return g.M.GATES[0].open > .85, 300))
	walk_to(6280)
	S("pula o caixote", jump_to(6420, true))
	S("totem grande", walk_to(6620))
	S("descansou 1", rests.has(1))
	walk_to(6990)
	S("caixa", jump_to(7140))
	# segurança
	walk_to(7540)
	S("choque 1", cross_spikes(trap_at("spikes", 7600), 7760))
	S("choque 2", cross_spikes(trap_at("spikes", 7820), 7990))
	walk_to(8180)
	S("bandeja 1", jump_to(8300))
	S("bandeja 2", jump_to(8420))
	S("passa o vão", jump_to(8540))
	S("cordão", walk_to(8640) and pegou("cordao"))
	walk_to(9060)
	S("sobe no vento", vento_ate(9230, -120))
	S("cartão de acesso", walk_to(9510) and pegou("cartao_acesso"))
	S("cartão 2", walk_to(9860) and cartoes() == 2)
	S("desce do mezanino", jump_to(10000))
	S("combina o crachá", g.try_combine("cartao_acesso", "cordao") != "")
	walk_to(10380)
	use()
	S("porta da área restrita", g.LOCKS[0].done)
	S("porta subiu", until({}, func(): return g.M.GATES.filter(func(gt): return gt.get("id", "") == "seg1")[0].open >= 1.0, 300))
	# mezanino
	S("escada de serviço", walk_to(10915))
	S("sobe", climb_to("U", func(): return P.ladder == null and P.onGround and P.y < 160, 500))
	S("passarela", walk_to(11585))
	press("J")
	hold({"J": true, "R": true}, 14)
	S("agarra o cabo", until({"R": true}, func(): return g.player.get("bar") != null, 80))
	S("atravessa pendurado", until({"R": true}, func(): return px() > 12120, 900))
	press("J")
	S("pula para a passarela 2", jump_to(12230))
	walk_to(12480)
	S("desce", jump_to(12560))
	for i in 6:
		walk_to(12590 + i * 60)
		jump_to(12630 + i * 60)
	S("topo da escada rolante", jump_to(13040))
	walk_to(13225)
	wait_ground()
	jump_to(13285)
	S("mola lança até a plataforma alta", until({}, func(): return P.onGround and P.y < 160, 300))
	S("cartão 3", walk_to(13340) and cartoes() == 3)
	walk_to(13400)
	S("desce", jump_to(13520))
	walk_to(13608)
	slam_here()
	S("alçapão abriu", g.X.broken.has("alc1"))
	walk_to(13610)
	S("desce a escada", climb_to("S", func(): return P.onGround and P.y > 800, 500))
	S("parede falsa", walk_to(13330))
	S("sala secreta", g.X.found.has("s1"))
	S("pista 2", n_clues() == 2)
	S("volta à escada", walk_to(13610))
	S("sobe", climb_to("U", func(): return P.ladder == null and P.onGround and P.y < 500, 500))
	S("pista 3", walk_to(14010) and n_clues() == 3)
	walk_to(14130)
	var r = until({}, func(): return not g.running, 300)
	S("saída", r is String and r == "state")

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var com := args.has("inimigos")
	var fases := []
	for a in args:
		if a.is_valid_int():
			fases.append(int(a))
	if fases.is_empty():
		fases = [1]
	for f in fases:
		carregar(f - 1, com)
		log_lines.append("== " + nome_fase)
		match f:
			1:
				fase_1_1()
		S("fim: milhas %d/%d pistas %d cartões %d/%d segredos %d" % [g.STATS.pen, g.STATS.penTotal, n_clues(), cartoes(), g.DRWS.size(), g.X.found.size()], true)
	for l in log_lines:
		print(l)
	print("FALHAS: %d" % fails)
	quit(1 if fails > 0 else 0)
