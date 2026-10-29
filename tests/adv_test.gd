extends "res://tests/route.gd"
## Testa os trechos novos sozinhos (teleporta o Tomé para o começo de cada um):
##   godot --headless --path . -s tests/adv_test.gd -- [raft] [ceu] [voo] [cogumelos] [pedra] [armadilhas]

func put(x: float, y: float) -> void:
	g.CINE = {}
	g.VH.mode = ""
	g.player.x = x - 12
	g.player.y = y - 34
	g.player.vx = 0
	g.player.vy = 0
	g.player.vine = null
	g.player.ladder = null
	g.player.spawnX = g.player.x
	g.player.spawnY = g.player.y
	g.player.hp = 5
	g.lives = 9
	g.snap_camera()
	for i in 10:
		frame()
	P = g.player

func _initialize() -> void:
	g = load("res://scripts/game.gd").new()
	root.add_child(g)
	g.load_level(0)
	g.no_coal = true
	for e in g.EN:
		e.dead = 99
	g.lives = 9
	P = g.player
	g.rest_reached.connect(func(n):
		rests.append(n)
		g.running = true)
	var args := OS.get_cmdline_user_args()
	var all := args.is_empty()
	if all or args.has("armadilhas"):
		put(2605, 500)
		S("espinhos da manhã", cross_spikes(trap_at("spikes", 2640), 2780))
		S("sem dano (espinhos)", P.hp == 5)
		put(10240, 500)
		S("tronco-pêndulo", cross_swing(trap_at("swing", 10450), 10730))
		S("sem dano (tronco)", P.hp == 5)
		for hx in [21655.0, 15905.0, 23358.0]:
			# espaço de chão antes (para pousar e abaixar) e depois (para levantar)
			var ga: float = hx
			var gb: float = hx
			for k in 40:
				for so in g.L.solids:
					if so.t == "ground" and so.y == 500 and so.x <= ga - 1 and so.x + so.w >= ga - 1:
						ga = so.x
					if so.t == "ground" and so.y == 500 and so.x <= gb + 1 and so.x + so.w >= gb + 1:
						gb = so.x + so.w
			S("chão antes da colmeia %d >= 140 (%d)" % [int(hx), int(hx - 22 - ga)], hx - 22 - ga >= 140)
			S("chão depois da colmeia %d >= 110 (%d)" % [int(hx), int(gb - hx - 22)], gb - hx - 22 >= 108)
			put(hx - 70, 500)
			hold({}, 10)
			S("em pé toca a colmeia %d" % int(hx), g.hit(P, g.R(hx - 22, 0, 44, 2000)) == false and (P.y < 474))
			S("abaixado passa sob a colmeia %d" % int(hx), crawl(hx + 48))
			S("colmeia %d quieta" % int(hx), trap_at("hive", hx).st == "idle")
			put(hx - 70, 500)
			hold({}, 10)
			walk_to(hx + 48)
			S("andando em pé acorda a colmeia %d" % int(hx), trap_at("hive", hx).st == "angry")
			var hv0: Dictionary = trap_at("hive", hx)
			hv0.st = "idle"
			hv0.cool = 0
			hv0.sx = hv0.x
			hv0.sy = hv0.y - 20
			P.hp = 5
			P.iframe = 0
		put(15810, 500)
		S("sob a colmeia", crawl(15970))
		S("colmeia quieta", trap_at("hive", 15905).st == "idle")
		# cutucou a colmeia: só mergulhando no lago o enxame desiste
		var hv: Dictionary = trap_at("hive", 15905)
		g.TR._hive_wake(hv)
		S("enxame acordou", hv.st == "angry")
		S("pula no lago", walk_to(16140))
		hold({"S": true}, 50)
		S("mergulhou e despistou", until({"S": true}, func(): return hv.st != "angry", 200))
		hold({"J": true}, 60)
		put(20105, 500)
		S("areia movediça", walk_to(20430))
		S("vivo na areia", g.lives >= 9)
		put(20200, 500)
		hold({}, 200)
		S("parado afunda", g.lives == 8)
		g.lives = 9
	if all or args.has("tronco"):
		put(4685, 500)
		use()
		S("picareta não quebra (é do mergulho)", not g.X.broken.has("chao1"))
		slam_here()
		S("quebrou o chão", g.X.broken.has("chao1"))
		walk_to(4690)
		S("desceu", climb_to("S", func(): return P.onGround and P.y > 800, 500))
		# solto lá embaixo (e com ↓ ainda apertado) ele não sobe sozinho
		hold({"S": true}, 40)
		hold({}, 120)
		S("continua no esconderijo", g.player.y > 800)
		S("sobe com ↑", climb_to("U", func(): return P.ladder == null and P.onGround and P.y < 500, 500))
	if all or args.has("raft"):
		put(25450, 500)
		walk_to(25490)
		jump_to(25605)
		S("pulou na jangada e embarcou", g.VH.mode == "raft")
		g.VH.mode = ""
		g.load_level(0)
		for e in g.EN:
			e.dead = 99
		put(25450, 500)
		walk_to(25480)
		use()
		S("subiu na jangada", g.VH.mode == "raft")
		S("corredeira", ride_raft())
		S("jangada inteira", g.VH.tries == 0 and P.hp == 5)
		# não dá para voltar para a água depois do fim (cerca na margem)
		hold({"L": true}, 120)
		S("cerca segura na margem final", px() > float(g.VH.RA.x1) - 4 and g.VH.mode == "")
		var jj := 0
		for i in 6:
			press("J")
			hold({"L": true, "J": true}, 40)
		S("nem pulando volta para a água", px() > float(g.VH.RA.x1) - 4)
	if all or args.has("rio"):
		# pular no rio de vários pontos do barranco: sempre cai na jangada, sem morrer
		for k in 5:
			g.load_level(0)
			for e in g.EN:
				e.dead = 99
			put(25450, 500)
			walk_to(25480 + k * 6)
			var lv: int = g.lives
			press("J")
			hold({"R": true, "J": true}, 8 + k * 6)
			var ok := false
			for i in 120:
				frame({"R": true} if i < 20 + k * 8 else {})
				if g.VH.mode == "raft":
					ok = true
					break
			S("pulo %d no rio caiu na jangada" % k, ok and g.lives == lv)
		# morreu no meio da corredeira: volta e a jangada está no cais
		g.VH.mode = ""
		g.load_level(0)
		for e in g.EN:
			e.dead = 99
		put(25450, 500)
		walk_to(25480)
		use()
		hold({}, 200)
		S("no meio da corredeira", g.VH.mode == "raft")
		g.player.spawnX = 25440
		g.player.spawnY = 466
		g.die("teste")
		hold({}, 200)
		S("voltou da morte a pé", g.VH.mode == "")
		S("jangada de volta ao cais", abs(g.VH.RA.px - float(g.VH.RA.x)) < 1 and g.SOL.has(g.VH.RAFT_SOL))
		walk_to(25480)
		use()
		S("embarca de novo", g.VH.mode == "raft")
	if all or args.has("ceu"):
		g.load_level(0)
		P = g.player
		for e in g.EN:
			e.dead = 99
		put(53240, 500)
		S("subida", climb_gusts(55630))
		S("ponte", bridge_run(trap_at("bridge", 55660)))
		S("vivo na ponte", g.lives >= 9)
	if all or args.has("voo"):
		# espaço entre os obstáculos do voo: ondas com trechos calmos para aproveitar o céu
		var xs: Array = g.L.plane.obs.map(func(o): return float(o.x))
		xs.sort()
		var mind := 1e9
		var calm := 0
		var prev: float = float(g.L.plane.edge)
		for x in xs:
			mind = min(mind, x - prev) if prev > float(g.L.plane.edge) else mind
			if x - prev >= 900:
				calm += 1
			prev = x
		S("obstáculos do voo espaçados (>= 400)", mind >= 400)
		S("trechos calmos no voo (>= 3)", calm >= 3)
		put(57040, 190)
		g.comic_req = ""
		var cams: Array = []
		var boarded = until({"R": true}, func(): return g.VH.mode == "plane", 900)
		S("chegou no avião: embarca sozinho", boarded)
		S("chegou no avião: quadrinho", g.comic_req == "aviao" or g.auto_cine)
		S("embarque: Tomé sobe na cabine", g.VH.phase == "board")
		var pc: float = g.cam
		var pcy: float = g.cam_y
		var jump_cam := 0.0
		for i in 260:
			frame()
			jump_cam = max(jump_cam, abs(g.cam - pc) + abs(g.cam_y - pcy))
			pc = g.cam
			pcy = g.cam_y
			if g.VH.phase == "fly" and i > 200:
				break
		S("decolou sozinho (sem botão)", g.VH.phase == "fly")
		S("câmera sem pulo no embarque/decolagem (< 30)", jump_cam < 30.0)
		S("decolou", g.VH.mode == "plane")
		S("voo", fly_plane())
		S("voo sem batidas", P.hp == 5)
	if all or args.has("transicoes"):
		# a câmera não pula ao subir/descer dos veículos (só com a tela fechada, na troca de lugar do trenó)
		var meas := func(n: int, set: Dictionary) -> float:
			var mx := 0.0
			var c0: float = g.cam
			var c1: float = g.cam_y
			for i in n:
				var covered: bool = g.VH.mode == "sled" and (g.VH.sboard == 1 or g.VH.sfin == 1)
				frame(set)
				var dj: float = abs(g.cam - c0) + abs(g.cam_y - c1)
				if not covered and g.iris_t < 29:
					mx = max(mx, dj)
				c0 = g.cam
				c1 = g.cam_y
			return mx
		# jangada: pula do barranco direto no rio
		g.load_level(0)
		P = g.player
		for e in g.EN:
			e.dead = 99
		put(25440, 500)
		hold({}, 30)
		var jr1: float = meas.call(10, {"R": true})
		press("J")
		var jr2: float = meas.call(140, {"R": true})
		S("pulou no rio: caiu na jangada", g.VH.mode == "raft")
		S("jangada: câmera suave (< 30)", max(jr1, jr2) < 30.0)
		# fim da jangada: vai devagar até a margem
		g.VH.hx = float(g.VH.RA.x1) - 600.0
		for o in g.VH.OBS:
			o.hit = true
		hold({}, 20)
		var sl_end := false
		var fin_cam: float = meas.call(200, {})
		for i in 200:
			if g.VH.mode != "raft":
				break
			if g.VH.hx > float(g.VH.RA.x1) - 120 and g.VH.spd < float(g.VH.RA.spd) * .75:
				sl_end = true
			frame()
		S("jangada: desacelera antes da margem", sl_end or g.VH.raft_done)
		S("jangada: desembarque sem pulo de câmera (< 30)", fin_cam < 30.0)
		# trenó: senta, escorrega, a tela fecha e abre lá no morro
		g.load_level(0)
		P = g.player
		put(52460, 500)
		until({"R": true}, func(): return g.VH.mode == "sled", 300)
		S("trenó: embarque com animação", g.VH.mode == "sled" and g.VH.sboard > 0)
		var sc: float = meas.call(80, {})
		S("trenó: chegou na descida", g.VH.sboard == 0 and g.VH.su > 30)
		S("trenó: câmera só troca com a tela fechada (< 40)", sc < 40.0)
		# cavalo: começa e termina sem pulo de câmera
		g.load_level(0)
		P = g.player
		put(39820, 500)
		for h in g.NT.HOLES:
			h.filled = true
		walk_to(39880)
		use()
		var hc: float = meas.call(120, {})
		S("cavalo: câmera suave na partida (< 30)", hc < 30.0)
		g.load_level(0)
		P = g.player
	if all or args.has("cogumelos"):
		put(64840, 500)
		walk_to(64910)
		S("pula a caixa de coração", jump_to(65050, true))
		walk_to(65245)
		S("saltador 1", bounce_to(65295))
		S("chapéu alto", P.y + P.h <= 232)
		S("saltador 2: o gigante laranja lança sozinho", bounce_to(65755))
		S("chapéu mais alto", P.y + P.h <= 152)
		S("desce", jump_to(66265))
		S("fim", jump_to(66450))
		S("vivo", g.lives >= 9)
		# sem cogumelinho em cima dos gigantes; todo saltador é um gigante laranja
		var small_on_top := false
		for o in g.TR.T:
			if o.k == "bounce" and o.x > 64440 and o.x < 67800:
				small_on_top = true
		S("sem cogumelo pequeno em cima dos gigantes", not small_on_top)
		# o buraco embaixo dos cogumelos tem água verde de veneno (e os outros buracos da noite também)
		var all_filled := true
		for pt in g.L.pits:
			if float(pt[0]) < 65340:
				continue
			var f := false
			for sw in g.SWAMP:
				if float(sw.x) <= float(pt[0]) + 1 and float(sw.x) + float(sw.w) >= float(pt[1]) - 1:
					f = true
			if not f:
				all_filled = false
		S("buracos da noite com água venenosa", all_filled)
		# cair no buraco: afunda na água verde
		g.load_level(0)
		P = g.player
		for e in g.EN:
			e.dead = 99
		put(65440, 300)
		var drown := false
		for i in 200:
			frame()
			if P.dyingT > 0 and str(P.dieMsg).contains("brejo"):
				drown = true
				break
		S("caiu no buraco: água venenosa mata", drown)
		# o Pipoca vem junto pelos saltadores
		g.load_level(0)
		P = g.player
		for e in g.EN:
			e.dead = 99
		put(65140, 500)
		g.X.DOG.st = "follow"
		g.X.DOG.x = 65090.0
		g.X.DOG.y = 500.0
		hold({}, 30)
		walk_to(65245)
		bounce_to(65295)
		bounce_to(65755)
		jump_to(66265)
		jump_to(66450)
		hold({}, 240)
		S("Pipoca acompanha pelos cogumelos", abs(float(g.X.DOG.x) - px()) < 300)
	if all or args.has("pedra"):
		put(73500, 500)
		S("túnel da pedra", walk_to(73650))
		var bol: Dictionary = trap_at("boulder", 73500)
		S("a pedra caiu", until({"R": true}, func(): return bol.st != "idle", 200))
		S("fuga da pedra", boulder_run(bol))
		S("sem ser atropelado", P.hp == 5)
		until({"S": true}, func(): return bol.st in ["break", "done"], 600)
		S("sai do buraco", jump_to(77140))
		S("barricada quebrada", walk_to(77500))
	if all or args.has("lagos"):
		# lagos de veneno com ponte de estaca: só passa baixando a ponte
		for sx in [2040.0, 6480.0, 67100.0]:
			var crossed := false
			var died := 0
			for mode in ["pulo", "duplo", "planar", "nadar", "alto"]:
				g.load_level(0)
				P = g.player
				for e in g.EN:
					e.dead = 99
				g.died_log = []
				var st: Dictionary = {}
				for o in g.SL.STAKES:
					if abs(float(o.x) - sx) < 5:
						st = o
				var far: float = float(st.bridge.x) + float(st.bridge.w)
				if mode == "alto" and sx == 6480.0:
					put(6300.0, 100)   # do alto do platô, correndo e planando
				elif mode == "alto":
					continue
				else:
					put(sx - (12.0 if sx < 2100 else 200.0), 500)
				hold({"R": true}, 40 if sx > 2100 else 2)
				press("J")
				for i in 16:
					frame({"J": true, "R": true})
				if mode != "pulo" and mode != "nadar":
					for i in 40:
						if P.vy >= -.5:
							break
						frame({"R": true})
					press("J")
					for i in 16:
						frame({"J": true, "R": true})
				for i in 300:
					frame({"R": true, "P": mode in ["planar", "alto"]})
					if px() > far + 10 and P.onGround:
						crossed = true
					if P.dyingT > 0:
						break
				if P.dyingT > 0 or not g.died_log.is_empty():
					died += 1
				hold({}, 80)
			S("lago %d: não passa pulando, planando nem nadando" % int(sx), not crossed)
			S("lago %d: cair é morte (veneno)" % int(sx), died >= 3)
			g.load_level(0)
			P = g.player
			for e in g.EN:
				e.dead = 99
			put(sx - (12.0 if sx < 2100 else 120.0), 500)
			S("lago %d: estaca baixa a ponte e atravessa" % int(sx), stake_cross(sx))
			S("lago %d: vivo" % int(sx), g.lives >= 9)
	if all or args.has("mochila"):
		# perto da trava com as peças soltas: botão da mochila → junta → ✔ → usa
		var wanted := []
		g.bag_wanted.connect(func(l): wanted.append(l.kind))
		for kd in ["hook", "dam", "dark"]:
			g.load_level(0)
			P = g.player
			for e in g.EN:
				e.dead = 99
			var lk: Dictionary = {}
			for l in g.LOCKS:
				if l.kind == kd:
					lk = l
			if not g.X.BOSS.is_empty():
				g.X.BOSS.done = true
			put(float(lk.x) - 20.0, float(lk.y) + float(lk.h))
			for pt in lk.parts:
				if not g.INV.has(pt):
					g.INV.append(pt)
			hold({}, 3)
			S("%s: botão vira mochila" % kd, g.use_mode() == "bag")
			press("A")
			hold({}, 2)
			S("%s: toque abre a mochila" % kd, wanted.has(kd))
			S("%s: junta as peças" % kd, g.try_combine(lk.parts[0], lk.parts[1]) != "")
			var want_m: String = "crank" if lk.get("crank") else "check"
			S("%s: botão vira %s" % [kd, want_m], g.use_mode() == want_m)
			press("A")
			hold({}, 2)
			if lk.get("crank"):
				S("%s: um toque só não abre" % kd, not lk.done)
				for k in 6:
					press("A")
					hold({}, 6)
			S("%s: trava aberta" % kd, lk.done)
			S("%s: botão volta a ser a mão" % kd, g.use_mode() == "hand")
	if all or args.has("manivela"):
		g.load_level(0)
		P = g.player
		for e in g.EN:
			e.dead = 99
		var ck: Dictionary = g.CRANKS[0]
		var gt = g.crank_gate(ck)
		put(float(ck.x) - 10.0, 500)
		hold({}, 3)
		S("manivela: botão vira manivela", g.use_mode() == "crank")
		# sem girar não passa (nem pulando)
		var esc := false
		for k in 3:
			put(float(gt.x) - 80.0, 500)
			djump("R")
			hold({"R": true}, 30)
			if px() > float(gt.x) + float(gt.w) + 6:
				esc = true
		S("manivela: porta fechada não deixa passar", not esc)
		put(float(ck.x) - 10.0, 500)
		press("A")
		hold({}, 6)
		S("manivela: um toque não abre", not ck.done and float(ck.turn) > 0.1)
		press("A")
		hold({}, 6)
		press("A")
		hold({}, 300)
		S("manivela: largou no meio, a porta desce", float(ck.turn) < .3)
		for k in 6:
			press("A")
			hold({}, 8)
		S("manivela: 6 toques abrem", ck.done)
		S("manivela: passa pela porta", walk_to(float(gt.x) + 120.0) == true)
	if all or args.has("portas"):
		# portas de caixa no botão: sem a caixa no botão não dá para passar (nem pulando da caixa)
		for gid in ["g1", "g5", "g2", "g4"]:
			g.load_level(0)
			P = g.player
			for e in g.EN:
				e.dead = 99
			var gt: Dictionary = {}
			for s2 in g.M.GATES:
				if s2.id == gid:
					gt = s2
			var gy: float = float(gt.y) + float(gt.h)
			if gid in ["g2", "g4"]:
				gy = 500.0 if gid == "g4" else 100.0
			var passed := false
			for tryk in 4:
				put(float(gt.x) - 60.0 - tryk * 40.0, gy)
				# caixa encostada na porta (fora do botão)
				if tryk >= 2 and not g.M.PUSH.is_empty():
					var bx: Dictionary = g.M.PUSH[0]
					var best := 1e9
					for c in g.M.PUSH:
						if abs(float(c.x) - float(gt.x)) < best:
							best = abs(float(c.x) - float(gt.x))
							bx = c
					if best < 1500:
						bx.x = float(gt.x) - bx.w - 2
						bx.y = gy - bx.h
						bx.vy = 0.0
						P.x = bx.x + 10
						P.y = bx.y - P.h - 1
						hold({}, 5)
				for k in 3:
					djump("R")
					hold({"R": true}, 20)
					if px() > float(gt.x) + float(gt.w) + 8:
						passed = true
			S("porta %s: não passa sem a caixa no botão" % gid, not passed)
	if all or args.has("vargas"):
		# trecho da pedra gigante ~2x mais comprido
		var bo: Dictionary = trap_at("boulder", 73500)
		S("pedra gigante: trecho comprido (>= 3280)", float(bo.end) - float(bo.trig) >= 3280)
		# perseguição do Vargas: sem óleo, sem pedra rolando, lanterna cheia e sem medidor
		var vt: float = float(g.L.villain.trig)
		var oil_in := 0
		for c in g.OIL:
			if float(c.x) > vt - 100:
				oil_in += 1
		S("perseguição sem potes de óleo", oil_in == 0)
		var roll_in := false
		for o in g.TR.T:
			if o.k == "roll" and float(o.x) > vt - 300:
				roll_in = true
		S("perseguição sem pedra rolando", not roll_in)
		g.FUEL = .2
		put(vt + 150, 500)
		hold({"R": true}, 60)
		S("lanterna cheia na perseguição", g.FUEL >= 1.0)
		S("medidor escondido na perseguição", g.chase_on())
	if all or args.has("enchente"):
		g.load_level(0)
		for e in g.EN:
			e.dead = 99
		g.INV.append("engrenagem")
		put(13550, 900)
		g.lives = 9
		S("chegou na escada", climb_to("U", func(): return g.EV.FL.st != "idle", 120))
		S("enchente começou", g.EV.FL.st in ["warn", "rise"])
		S("subiu antes da água", climb_to("U", func(): return P.ladder == null and P.onGround and P.y < 500, 500))
		S("vivo na enchente", g.lives >= 9)
	if all or args.has("alavancas"):
		put(71710, 500)
		S("portão fechado", g.EV.GATE.lift < 1)
		walk_to(71725)
		use()
		walk_to(71785)
		use()
		S("portão abriu", until({}, func(): return g.EV.GATE.lift >= g.EV.GATE.h - 8, 200))
		S("passa o portão", walk_to(71870))
	if all or args.has("mergulho"):
		# estaca: subir nela e mergulhar baixa a ponte do riacho
		put(2040, 456)
		var stk: Dictionary = g.SL.STAKES.filter(func(o): return abs(float(o.x) - 2040.0) < 5)[0]
		S("ponte em pé", not g.SOL.has(stk.sol))
		S("em cima da estaca", P.onGround and P.y + P.h < 470)
		slam_here()
		S("estaca cravada", stk.done)
		hold({}, 120)
		S("ponte deitou", g.SOL.has(stk.sol))
		S("atravessa a ponte", walk_to(2460))
		S("seco (não caiu na água)", not P.swim)
		# gangorra: mergulho na ponta de cá lança a pedra e caem lápis e uma fruta
		put(63925, 456)
		var sw: Dictionary = g.SL.SAWS[0]
		var c0: int = g.coin_life
		S("na ponta de cá", P.onGround and P.y + P.h < 470)
		slam_here()
		S("gangorra lançou", sw.done)
		hold({}, 150)
		S("caiu coisa da árvore", g.SL.DROPS.size() >= 5)
		for d in g.SL.DROPS:
			if not d.got:
				walk_to(d.x)
		S("pegou os lápis", g.coin_life > c0)
		# arbusto de frutas: o mergulho perto derruba as frutas; cada uma devolve um coração
		put(66660, 500)
		P.hp = 3
		slam_here()
		hold({}, 60)
		S("frutas caíram", g.SL.FRUIT[1].left == 0)
		walk_to(66770)
		walk_to(66710)
		S("comeu fruta (+coração)", P.hp >= 4)
		# onda de choque: um bicho do chão por perto fica tonto
		put(34560, 500)
		var en: Dictionary = {}
		for e in g.EN:
			if e.k == "squirrel":
				en = e
				break
		en.dead = 0
		en.x = 34650.0
		en.y = 500.0
		en.base = 500.0
		en.r = [34670, 34700]
		slam_here()
		S("bicho ficou tonto", en.stun > 0)
		en.dead = 99
	if all or args.has("treno"):
		put(52460, 500)
		until({"R": true}, func(): return g.VH.mode == "sled", 300)
		S("subiu no trenó", g.VH.mode == "sled")
		var VH = g.VH
		S("descida comprida (>= 4080)", float(VH.SL.len) >= 4080)
		var ok_sled = "timeout"
		var top_spd := 0.0
		for i in 3080:
			if g.VH.mode == "":
				ok_sled = true
				break
			top_spd = max(top_spd, VH.spd)
			var d := {}
			var gy: float = VH.sled_y(VH.su)
			var ground: bool = VH.hy >= gy - 1
			for o in VH.OBS:
				var dx: float = o.x - VH.hx
				if o.hit or o.k == "bump" or o.k == "kick" or dx < -140 or dx > 300:
					continue
				if o.k in ["rock", "log"] and ground and dx < VH.spd * 9.0 + 24 and dx > 30:
					press("J")
				if o.k == "crack" and ground and dx < 40 and dx > -5:
					press("J")
				if o.k == "branch" and dx < 110 and dx > -100:
					d["S"] = true
				break
			frame(d)
		S("desceu de trenó", ok_sled)
		S("velocidade cresce na descida (> 6.5)", top_spd > 6.5)
		S("velocidade máxima menor (<= 8)", top_spd <= 8.01)
		var hitk := []
		for o in VH.OBS:
			if o.hit:
				hitk.append(o.k + "@" + str(o.u))
		S("trenó sem batidas " + str(hitk), P.hp == 5 and VH.tries == 0)
		# obstáculos bem espaçados (dá para pousar de um pulo antes do próximo; rampas e lombadas
		# não machucam e ficam fora da conta)
		var us: Array = []
		for o in VH.SL.obs:
			if not o.k in ["kick", "bump"]:
				us.append(float(o.u))
		us.sort()
		var gap_ok := true
		for i in us.size() - 1:
			if us[i + 1] - us[i] < 240:
				gap_ok = false
		S("obstáculos do trenó espaçados (>= 240)", gap_ok)
		S("trenó tem rampas de salto (>= 2)", VH.SL.obs.filter(func(o): return o.k == "kick").size() >= 2)
		S("trenó tem marcos (>= 2)", VH.SL.get("cps", []).size() >= 2)
		# batidas de propósito nas duas primeiras: perde 1 coração cada e segue (sem voltar)
		g.load_level(0)
		P = g.player
		put(52460, 500)
		until({"R": true}, func(): return g.VH.mode == "sled", 300)
		VH = g.VH
		var back := false
		var last_u := 0.0
		var hits := 0
		ok_sled = "timeout"
		for i in 3080:
			if g.VH.mode == "":
				ok_sled = true
				break
			if VH.su < last_u - .5:
				back = true
			last_u = VH.su
			var d := {}
			var ground: bool = VH.hy >= VH.sled_y(VH.su) - 1
			var nhit := 0
			for o in VH.OBS:
				if o.hit:
					nhit += 1
			hits = nhit
			for o in VH.OBS:
				var dx: float = o.x - VH.hx
				if o.hit or o.k == "bump" or o.k == "kick" or dx < -140 or dx > 300:
					continue
				if float(o.u) < 1800:
					break   # bate de propósito nas duas primeiras
				if o.k in ["rock", "log"] and ground and dx < VH.spd * 9.0 + 24 and dx > 30:
					press("J")
				if o.k == "crack" and ground and dx < 40 and dx > -5:
					press("J")
				if o.k == "branch" and dx < 110 and dx > -100:
					d["S"] = true
				break
			frame(d)
		S("batidas: segue descendo sem recomeçar", ok_sled == true and not back)
		S("batidas: perdeu 2 corações", P.hp == 3 and hits == 2)
		S("batidas: Tomé vivo no fim", g.lives >= 9 and P.dyingT == 0)
		# batendo em tudo: sem corações, o trenó volta para o último marco (sem morrer) e chega lá embaixo
		g.load_level(0)
		P = g.player
		put(52460, 500)
		until({"R": true}, func(): return g.VH.mode == "sled", 300)
		VH = g.VH
		var lv0: int = g.lives
		var died := false
		var back_cp := false
		var last_su := 0.0
		for i in 6000:
			if P.dyingT > 0:
				died = true
			if VH.mode == "":
				break
			if VH.su < last_su - 50.0:
				back_cp = VH.cp_i >= 0 and abs(VH.su - (float(VH.SL.cps[VH.cp_i]) - 160.0)) < 20.0
			last_su = VH.su
			frame({})
		hold({}, 40)
		S("bateu em tudo: não morreu", not died and g.lives == lv0)
		S("bateu em tudo: recomeçou do marco", back_cp and VH.tries >= 1)
		S("bateu em tudo: chegou lá embaixo", VH.sled_done and VH.mode == "")
	if all or args.has("urso"):
		# perseguição inteira: troncos, galho, pingentes, fresta e a coroa
		put(50300, 500)
		walk_to(50400)
		S("Urso-Rei", bear_fight())
		S("urso: Tomé vivo", g.lives >= 9)
		# parado não tem esconderijo: em cima do tronco o urso arrebenta o tronco e pega o Tomé
		g.load_level(0)
		for e in g.EN:
			e.dead = 99
		P = g.player
		put(50300, 500)
		walk_to(50400)
		var bb: Dictionary = g.K.BEAR
		walk_to(50560)
		jump_to(50637)
		var hp0: int = P.hp
		until({}, func(): return g.player.hp < hp0, 400)
		S("urso pega quem fica parado (até em cima do tronco)", g.player.hp < hp0)
		S("urso arrebenta o tronco", g.K.BOBS[0].get("fallen", false))
		# a rocha é alta demais: nem com pulo duplo dá para passar por cima (só pela fresta)
		g.load_level(0)
		for e in g.EN:
			e.dead = 99
		P = g.player
		var rx: float = float(g.K.BEAR.rock.x)
		put(rx - 60, 500)
		djump("R")
		hold({"R": true}, 60)
		S("não passa por cima da rocha", px() < rx)
		put(rx - 40, 500)
		S("passa abaixado pela fresta", crawl(rx + 150) == true and px() > rx + 140)
		# o Tomé cai depois que a coroa saltou: ela continua lá, esperando
		g.load_level(0)
		for e in g.EN:
			e.dead = 99
		P = g.player
		put(rx + 262, 500)
		g.K.BEAR.active = true
		g.K.BEAR.won = true
		g.K.BEAR.st = "chase"
		g.K.BEAR.x = rx - 300.0
		until({}, func(): return g.K.DROPPED.has("urso"), 400)
		g.die("teste")
		until({}, func(): return P.dyingT == 0 and g.player.hp == 5, 400)
		hold({}, 120)
		P = g.player
		var cr = null
		for c in g.K.CROWNS:
			if c.id == "urso":
				cr = c
		S("coroa continua no chão depois de cair", true if (cr != null and cr.st == "rest") else str(cr))
		if cr != null:
			walk_to(cr.x)
			hold({}, 30)
		S("pegou a coroa depois de voltar", g.K.TOOK.has("urso"))
	if all or args.has("cavalo"):
		put(39820, 500)
		for h in g.NT.HOLES:
			h.filled = true
		S("cavalo preso", g.RD.H.st == "trapped")
		walk_to(39880)
		use()
		S("cavalgada começou", until({}, func(): return g.RD.riding, 500))
		# obstáculos espaçados: depois de um pulo dá para pousar e ainda reagir ao próximo
		# (pulo: metade do voo depois do centro + 20 quadros; abaixar/pular de novo: + 12 quadros)
		var spacing_ok := true
		var RDo = g.RD
		for i in range(1, RDo.OBS.size()):
			var a: Dictionary = RDo.OBS[i - 1]
			var b: Dictionary = RDo.OBS[i]
			var v: float = RDo.spd_at(float(b.x))
			var end_a: float = float(a.x) + 90.0
			if RDo.obs_center(a) > 0:
				var jv: float = 17.0 if a.k == "leap" else RDo.JUMP_V
				end_a = RDo.obs_center(a) + v * jv / RDo.JUMP_G + (float(a.get("w", 0)) * .5 if a.k == "leap" else 0.0)
			var start_b: float = RDo.takeoff_x(b) if RDo.obs_center(b) > 0 else float(b.x) - 40.0
			if start_b - end_a < v * 12.0:
				spacing_ok = false
				print("  perto demais: ", a.k, "@", a.x, " -> ", b.k, "@", b.x)
		S("obstáculos da cavalgada espaçados (dá para pousar e reagir)", spacing_ok)
		S("tem o salto do desfiladeiro", RDo.OBS.any(func(o): return o.k == "leap"))
		S("marcos na trilha (>= 2)", RDo.cps().size() >= 2)
		S("velocidade do cavalo 5.2", abs(float(g.RD.H.spd) - 5.2) < .01)
		S("cavalgada", ride())
		S("cavalgada sem batidas", P.hp == 5 and g.RD.tries == 0)
		# desfiladeiro sem pular: perde um coração, mas o cavalo salta assustado e passa (não cai)
		g.load_level(0)
		P = g.player
		for e in g.EN:
			e.dead = 99
		put(39820, 500)
		for h in g.NT.HOLES:
			h.filled = true
		walk_to(39880)
		use()
		until({}, func(): return g.RD.riding, 500)
		var lp: Dictionary = {}
		for o in g.RD.OBS:
			if o.k == "leap":
				lp = o
			else:
				o.hit = true
		g.RD.hx = float(lp.x) - 400.0
		g.RD.cp_i = g.RD.cps().size() - 1
		g.RD.spd = g.RD.spd_at(g.RD.hx)
		hold({}, 160)
		S("desfiladeiro sem pular: 1 coração a menos", P.hp == 4 and lp.hit)
		S("desfiladeiro sem pular: passou para o outro lado", g.RD.hx > float(lp.x) + float(lp.w) + 40 and g.RD.hy >= 500.0)
		# sem corações: volta para o último marco (não para o começo), com os corações cheios
		P.hp = 1
		P.iframe = 0
		var mk: float = float(g.RD.cps()[g.RD.cp_i])
		for o in g.RD.OBS:
			if float(o.x) > g.RD.hx:
				o.hit = false
		var tries0: int = g.RD.tries
		for i in 600:
			frame()
			if g.RD.tries > tries0:
				break
		S("sem corações: recomeça no marco", g.RD.tries == tries0 + 1 and abs(g.RD.hx - mk) < 200 and P.hp == 5 and g.RD.riding)
		# o fim: o cavalo vai parando, o Tomé desce com calma, faz carinho e o cavalo vai embora trotando
		g.load_level(0)
		P = g.player
		for e in g.EN:
			e.dead = 99
		put(39820, 500)
		for h in g.NT.HOLES:
			h.filled = true
		walk_to(39880)
		use()
		until({}, func(): return g.RD.riding, 500)
		for o in g.RD.OBS:
			o.hit = true
		g.RD.hx = float(g.RD.H.ride1) - 900.0
		var max_end := -1
		var slowed := false
		var gone_t := 0
		for i in 900:
			frame()
			max_end = max(max_end, g.RD.endT)
			if g.RD.riding and g.RD.endT < 0 and g.RD.spd < 2.0:
				slowed = true
			if not g.RD.riding and g.RD.H.st in ["gone", "away"]:
				gone_t += 1
			if g.RD.H.st == "away":
				break
		S("fim: cavalo desacelera até parar", slowed)
		S("fim: cena de desmontar (>= 160 quadros)", max_end >= 160)
		S("fim: Tomé no chão depois de descer", P.onGround and not g.RD.riding)
		S("fim: cavalo vai embora devagar", gone_t > 60)
	if all or args.has("machado"):
		var ax: Dictionary = g.TR.by_kind("axe")[0]
		var bad := 0
		for k in 8:
			put(64450, 500)
			for e in g.EN:
				e.dead = 99
			hold({}, k * 16)
			walk_to(64460)
			until({}, func(): g.TR.axe_blade(ax); return ax.ang > .35, 300)
			var hp0: int = P.hp
			jump_to(64800, true)
			if P.hp < hp0:
				bad += 1
		S("pulos bem feitos sobre a lâmina sem dano (%d batidas)" % bad, bad == 0)
		put(64640, 500)
		var hp1: int = P.hp
		hold({}, 140)
		S("parado no caminho da lâmina leva dano", P.hp < hp1)
		# em cima da haste/forca não machuca
		var pts: PackedVector2Array = g.TR.axe_points(ax, 0.0)
		S("haste não está na área de dano", pts.size() == 18)
	if all or args.has("gelo"):
		put(35640, 500)
		for e in g.EN:
			e.dead = 99
		for o in g.TR.T:
			if o.k == "roll":
				o.st = "done"
		walk_to(35720)
		S("pula o buraco de gelo aberto", jump_to(36005, true))
		S("passou vivo", g.lives >= 9 and px() > 35950)
	if all or args.has("pingentes"):
		var ic: Dictionary = trap_at("icicle", 37890)
		put(37740, 868)
		S("pingente pronto", ic.st == "idle" and ic.grow >= 1.0)
		put(37892, 868)
		S("pingente tremendo", until({}, func(): return ic.st == "shake", 60))
		var t0: int = g.T
		S("treme ~1 s antes de cair", until({}, func(): return ic.st == "fall", 120) and g.T - t0 >= 50)
		S("cai e acerta quem fica parado", until({}, func(): return ic.st == "broken", 120) and P.hp == 4)
		S("volta a crescer", until({}, func(): return ic.st == "shake" or (ic.st == "idle" and ic.grow >= 1.0), 400))
		var ic2: Dictionary = trap_at("icicle", 37520)
		put(37390, 868)
		S("pingente 2 tremendo", until({"R": true}, func(): return ic2.st == "shake", 120))
		S("dá tempo de fugir", walk_to(37400) and until({}, func(): return ic2.st == "broken", 200) and P.hp == 5)
	for l in log_lines:
		print(l)
	print("FALHAS: ", fails)
	quit()
