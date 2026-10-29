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
	S("milha dourada", walk_to(13385) and g.X.GOLD.get("got", false))
	S("volta à escada", walk_to(13610))
	S("sobe", climb_to("U", func(): return P.ladder == null and P.onGround and P.y < 500, 500))
	S("pista 3", walk_to(14010) and n_clues() == 3)
	S("totem do portão", walk_to(14390))
	walk_to(14820)
	S("Fiscal Falso apareceu", until({}, func(): return g.X.boss_active() and g.X.BOSS.st not in ["wait", "espera"], 400))
	S("vence o Fiscal Falso", luta_fiscal())
	S("pega as milhas", walk_to(15100))
	walk_to(15300)
	S("sobe na cabine", jump_to(15430, true))
	S("porta aberta", walk_to(15560))
	walk_to(15912)
	var r = until({}, func(): return not g.running, 300)
	S("saída", r is String and r == "state")

## espera a tábua idx chegar perto de x e pula nela
func pula_na_tabua(idx: int, x: float, mx: int = 900):
	var o: Dictionary = g.MV.MV[idx]
	var s: Dictionary = o.plats[0]
	var r = until({}, func(): return abs(s.x + s.w / 2 - x) < 14, mx)
	if not (r is bool and r):
		return "a tábua não veio: " + str(r)
	jump_to(s.x + s.w / 2 + s.dx * 20)
	if not (P.onGround and g.MV.on_plat(o)):
		return "não pousou na tábua x=%d y=%d" % [int(px()), int(P.y)]
	return true

## fica no meio da tábua até ela chegar perto de x
func na_tabua_ate(idx: int, x: float, mx: int = 900):
	var o: Dictionary = g.MV.MV[idx]
	var s: Dictionary = o.plats[0]
	for i in mx:
		P = g.player
		if not ok():
			return "state"
		if abs(s.x + s.w / 2 - x) < 12:
			return true
		var cx: float = s.x + s.w / 2
		frame({"R": true} if px() < cx - 10 else ({"L": true} if px() > cx + 10 else {}))
	return "timeout"

## passa pelo vento que empurra para trás: espera desligar e corre
func passa_rajada(o: Dictionary, x_depois: float):
	until({}, func(): return g.TR.gust_state(o) == 2, 400)
	until({}, func(): return g.TR.gust_state(o) == 0, 400)
	return run_to(x_depois)

func fase_1_2() -> void:
	walk_to(1440)
	S("mala", jump_to(1560))
	S("totem", walk_to(1580))
	S("esteira 1", pula_na_tabua(1, 1710))
	S("chega no alto", na_tabua_ate(1, 2110))
	S("esteira 2", pula_na_tabua(2, 2210))
	S("desce com ela", na_tabua_ate(2, 2510))
	S("chão", jump_to(2660))
	walk_to(3540)
	S("piso elétrico", cross_spikes(trap_at("spikes", 3600), 3760))
	walk_to(3830)
	S("em cima da pilha", jump_to(3915, true))
	slam_here()
	S("quebrou a pilha", g.CR.filter(func(c): return c.get("t", "") == "break" and abs(float(c.x) - 3900) < 5 and not c.get("dead", false)).size() == 0)
	walk_to(4428)
	slam_here()
	S("alçapão do subsolo", g.X.broken.has("alc1"))
	walk_to(4430)
	S("desce", climb_to("S", func(): return P.onGround and P.y > 800, 500))
	S("sala secreta", walk_to(4150) and g.X.found.has("s1"))
	S("milha dourada", g.X.GOLD.get("got", false))
	walk_to(4430)
	S("sobe", climb_to("U", func(): return P.ladder == null and P.onGround and P.y < 500, 500))
	S("pista 4", walk_to(4710) and n_clues() == 1)
	S("botão gigante", stake_cross(5100))
	S("totem grande", walk_to(5720))
	S("descansou 1", rests.has(1))
	S("a Bag presa", walk_to(6280))
	use()
	S("Bag solta", g.X.dog_free())
	walk_to(6950)
	hold({}, 20)
	press("D")
	frame()
	S("controla a Bag", g.M.ctrl)
	S("Bag pela portinhola até a placa", walk_to(7185))
	S("portão abriu", until({}, func(): return g.M.GATES.filter(func(gt): return gt.get("id", "") == "bag1")[0].open > .85, 200))
	press("D")
	frame()
	S("de volta ao Milis", not g.M.ctrl)
	S("cartão 1", walk_to(7090) and cartoes() == 1)
	S("elevador", walk_to(8348))
	use()
	var lf: Dictionary = g.MV.MV[3]
	S("sobe de elevador", until({}, func(): return lf.pos == 0.0 and lf.goal == 0.0, 600))
	S("fusível", walk_to(9110) and pegou("fusivel"))
	walk_to(9780)
	S("desce do alto", until({"R": true}, func(): return P.onGround and P.y > 400, 300))
	S("manivela", walk_to(10000))
	for k in 8:
		use()
		hold({}, 6)
	S("porta da manivela abriu", g.CRANKS[0].done)
	walk_to(10600)
	S("duto que sopra", passa_rajada(trap_at("gust", 10700), 10900))
	walk_to(11530)
	S("caixa da armadura", jump_to(11690))
	S("fita", walk_to(11910) and pegou("fita"))
	S("cartão 2", walk_to(12510) and cartoes() == 2)
	S("emenda o fusível", g.try_combine("fusivel", "fita") != "")
	walk_to(12880)
	use()
	S("gerador ligou", g.LOCKS[0].done)
	S("portão abriu", until({}, func(): return g.M.GATES.filter(func(gt): return gt.get("id", "") == "ger1")[0].open >= 1.0, 300))
	S("cartão 3", walk_to(13310) and cartoes() == 3)
	S("pista 5", walk_to(13410) and n_clues() == 2)
	walk_to(13480)
	var r = until({"R": true}, func(): return not g.running, 300)
	S("saída", r is String and r == "state")

func fase_1_3() -> void:
	walk_to(930)
	S("malas empilhadas", jump_to(1090, true))
	for i in 5:
		walk_to(1680 + i * 50)
		jump_to(1725 + i * 50)
	S("topo da escada do avião", jump_to(2000))
	S("asa do avião", walk_to(2660))
	S("cartão 1", cartoes() == 1)
	walk_to(2690)
	S("salta da asa", planar_ate(3080))
	S("totem", walk_to(3110))
	walk_to(3380)
	S("turbina", passa_rajada(trap_at("gust", 3500), 3720))
	S("pneu rolando", dodge_roll(4000, 0))
	walk_to(5120)
	S("caixa do coração", jump_to(5280))
	S("totem", walk_to(5330))
	walk_to(5395)
	S("cabo 1", grab_vine(g.VINES[0]))
	S("cabo 2", vine_hop(g.VINES[1]))
	S("bloco do meio", vine_hop(null) and P.y < 280)
	walk_to(6510)
	S("cabo 3", grab_vine(g.VINES[2]))
	S("chão", vine_hop(null) and P.y > 400)
	walk_to(7920)
	S("gancho 1", cross_swing(trap_at("swing", 8100), 8280))
	S("gancho 2", cross_swing(trap_at("swing", 8450), 8650))
	S("pista 6", walk_to(8910) and n_clues() == 1)
	walk_to(9140)
	S("contêiner", jump_to(9300, true))
	S("cartão 2", walk_to(9300) and cartoes() == 2)
	walk_to(9390)
	S("desce", jump_to(9500))
	S("totem grande", walk_to(9920))
	S("descansou 1", rests.has(1))
	walk_to(10150)
	S("empurra o caixote até a parede", until({"R": true}, func(): return g.M.PUSH[0].x + g.M.PUSH[0].w >= 10495, 900))
	walk_to(10380)
	S("sobe no caixote", jump_to(10450))
	S("sobe na prateleira", jump_to(10620, true))
	walk_to(10890)
	S("desce", until({"R": true}, func(): return P.onGround and P.y > 400, 200))
	walk_to(11328)
	slam_here()
	S("alçapão do hangar", g.X.broken.has("alc1"))
	walk_to(11330)
	S("desce", climb_to("S", func(): return P.onGround and P.y > 800, 500))
	S("sala secreta", walk_to(11050) and g.X.found.has("s1"))
	S("milha dourada", g.X.GOLD.get("got", false))
	walk_to(11330)
	S("sobe", climb_to("U", func(): return P.ladder == null and P.onGround and P.y < 500, 500))
	walk_to(11600)
	use()
	walk_to(11700)
	use()
	S("portão do hangar", until({}, func(): return g.EV.GATE.lift >= g.EV.GATE.h - 8, 400))
	S("cartão 3", walk_to(12310) and cartoes() == 3)
	walk_to(12650)
	var r = until({"R": true}, func(): return not g.running, 300)
	S("saída", r is String and r == "state")

## o Fiscal Falso: pula os lasers do rodapé, abaixa nos altos, fica num vão da grade,
## acerta o painel com o bastão e pisa na cabeça dele quando cai tonto
func luta_fiscal():
	return luta_fiscal_lim(9000)

func luta_fiscal_lim(lim: int):
	var golpeou := 0
	var hp_ant: int = g.player.hp
	for it in lim:
		P = g.player
		if not ok():
			return "state"
		var b: Dictionary = g.X.BOSS
		if b.done or b.st == "down":
			hold({}, 170)
			return true
		var set := {}
		var cx: float = px()
		match str(b.st):
			"lasers":
				var bt: int = int(b.get("bt", 0))
				var warn: int = int(b.get("warn", 50))
				var on: int = int(b.get("on", 34))
				var k: String = str(b.get("beam_k", ""))
				var alvo: float = float(b.x0) + 300.0
				if k == "grade":
					# o vão mais perto do meio
					var xs: Array = []
					for bm in b.beams:
						xs.append(float(bm.x))
					xs.sort()
					var melhor := alvo
					var dmin := 1e9
					var cand: Array = [float(b.x0) + 30.0]
					for i in xs.size() - 1:
						cand.append((xs[i] + xs[i + 1]) / 2.0)
					for c in cand:
						var livre := true
						for x in xs:
							if absf(x - c) < 40.0:
								livre = false
						if livre and absf(c - cx) < dmin:
							dmin = absf(c - cx)
							melhor = c
					alvo = melhor
				if absf(cx - alvo) > 8.0 and P.onGround and not (k == "alto" and bt > warn - 10):
					set = {"R": true} if alvo > cx else {"L": true}
				if k == "rasteiro" and bt == warn - 6 and P.onGround:
					press("J")
					set["J"] = true
				elif k == "rasteiro" and bt > warn - 6 and bt < warn + 10:
					set["J"] = true
				if k == "alto" and bt > warn - 12 and bt < warn + on + 6:
					set = {"S": true}
			"painel":
				var pan: float = float(b.pan_x) + 46.0
				if absf(cx - pan) > 6.0:
					set = {"R": true} if pan > cx else {"L": true}
				elif P.face > 0:
					set = {"L": true}
				elif golpeou <= 0:
					press("G")
					golpeou = 30
			"tonto":
				if P.onGround and absf(cx - float(b.x)) < 70.0:
					press("J")
					set = {"J": true, ("R" if b.x > cx else "L"): true}
				elif P.onGround:
					set = {"R": true} if b.x > cx else {"L": true}
				else:
					set = {"J": true, ("R" if b.x > cx else "L"): true} if absf(cx - float(b.x)) > 6.0 else {"J": true}
		golpeou -= 1
		frame(set)
		if P.hp < hp_ant:
			print("  machucou: st=%s k=%s bt=%s x=%d y=%d h=%d crouch=%s" % [g.X.BOSS.st, g.X.BOSS.get("beam_k", ""), g.X.BOSS.get("bt", 0), int(px()), int(P.y), int(P.h), P.crouch])
		hp_ant = P.hp
	return "hp=%d st=%s" % [g.X.BOSS.hp, g.X.BOSS.st]

func luta_motoboy(x_poleiro: float, x_chao: float):
	for it in 60:
		P = g.player
		var b: Dictionary = g.X.BOSS
		if b.done or b.st == "down":
			hold({}, 160)
			return true
		if not ok():
			return "state"
		if P.onGround and P.y + P.h <= 397:
			until({}, func(): return g.X.BOSS.st == "idle" or g.X.BOSS.st == "down", 600)
			if g.X.BOSS.st == "down":
				continue
			walk_to(x_chao)
			until({}, func(): return P.onGround and P.y + P.h >= 494, 60)
		walk_to(x_chao)
		until({}, func(): return g.X.BOSS.st == "charge" and abs(g.X.BOSS.x - px()) < 330, 400)
		jump_to(x_poleiro, true)
		hold({}, 4)
	return "hp=%d st=%s" % [g.X.BOSS.hp, g.X.BOSS.st]

func fase_chefe() -> void:
	S("totem", walk_to(530))
	walk_to(700)
	S("caixa do coração", jump_to(860))
	walk_to(1180)
	S("placa 1", jump_to(1300))
	S("placa 2", jump_to(1430))
	S("passa a vala", jump_to(1560))
	walk_to(1580)
	S("turbina", passa_rajada(trap_at("gust", 1700), 1900))
	S("pneu", dodge_roll(1960, 0))
	S("totem", walk_to(2610))
	S("entra na pista", walk_to(3120))
	S("motoboy apareceu", until({}, func(): return g.X.boss_active(), 200))
	S("vence o Motoboy Turbo", luta_motoboy(3005, 3100))
	S("pega as milhas", walk_to(3400))
	walk_to(4450)
	var r = until({"R": true}, func(): return not g.running, 300)
	S("saída", r is String and r == "state")

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var com := args.has("inimigos")
	var fases := []
	for a in args:
		if a.is_valid_int():
			fases.append(int(a))
	if fases.is_empty():
		fases = [1, 2, 3, 4]
	for f in fases:
		carregar(f - 1, com)
		log_lines.append("== " + nome_fase)
		match f:
			1:
				fase_1_1()
			2:
				fase_1_2()
			3:
				fase_1_3()
			4:
				fase_chefe()
		S("fim: milhas %d/%d pistas %d cartões %d/%d segredos %d" % [g.STATS.pen, g.STATS.penTotal, n_clues(), cartoes(), g.DRWS.size(), g.X.found.size()], true)
	for l in log_lines:
		print(l)
	print("FALHAS: %d" % fails)
	quit(1 if fails > 0 else 0)
