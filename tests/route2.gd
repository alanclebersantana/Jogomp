extends "res://tests/route.gd"
## Teste automático do Episódio 2 (As Profundezas da Mina): joga a fase inteira, da boca da mina
## até a porta do cofre, pegando as 6 pistas, os 6 lápis especiais e os desenhos.
##   godot --headless --path . -s tests/route2.gd

## pula segurando PULAR o tempo todo (pulo duplo e plana até pousar)
func glide_to(x: float, mx: int = 400):
	press("J")
	var used := false
	for i in mx:
		P = g.player
		if not ok():
			return "state"
		var d := {}
		if px() < x - 5:
			d = {"R": true}
		elif px() > x + 5:
			d = {"L": true}
		if not used and i > 14 and P.vy > -1:
			press("J")
			used = true
		d["J"] = true
		frame(d)
		P = g.player
		if P.onGround and i > 3:
			return true
	return "air"

## pulo duplo parado no lugar (para pegar o que está no alto)
func vjump():
	press("J")
	for i in 16:
		frame({"J": true})
	for i in 30:
		P = g.player
		if P.vy >= -.5:
			break
		frame()
	press("J")
	for i in 14:
		frame({"J": i < 10})
	return wait_ground()

## anda no telhado pulando as chaminés (as quentes: espera a labareda baixar, pulo duplo) e as telhas soltas
func roof_walk(x: float, chims: Array):
	for c in chims:
		var cx0: float = float(c.x)
		var cx1: float = float(c.x) + float(c.w)
		if (x > px() and cx0 > px() and cx0 < x) or (x < px() and cx1 < px() and cx1 > x):
			var before: float = cx0 - 24 if x > px() else cx1 + 24
			var r = walk_to(before)
			if not (r is bool and r):
				return "até a chaminé: " + str(r)
			if c.get("hot"):
				var hc: Dictionary = {}
				for h in g.VL.HOT:
					if abs(float(h.x) - cx0) < 3:
						hc = h
				until({}, func(): return g.VL.hot_phase(hc) == 0 and int((g.T + int(hc.get("ph", 0))) % int(hc.per)) < 20, 400)
			r = jump_to(cx1 + 26 if x > px() else cx0 - 26, c.get("hot", 0) == 1 or float(c.get("h", 0)) > 50)
			if not (r is bool and r):
				return "pula a chaminé: " + str(r)
	return walk_to(x)

func lift_ride(top: bool):
	var lf: Dictionary = g.MV.MV[0]
	use()
	return until({}, func(): return lf.pos == lf.goal and (lf.pos == 0.0) == top, 600)

## espera uma tábua do moinho passar embaixo e pula nela; sobe junto e pula para o barranco
func mill_ride(cliff_x: float, cliff_y: float):
	var wh: Dictionary = {}
	for o in g.MV.MV:
		if o.k == "wheel":
			wh = o
	var target = null
	for i in 1500:
		P = g.player
		for s in wh.plats:
			if s.y > 360 and abs(s.x + s.w / 2 - px()) < 140 and s.dx < 0:
				target = s
		if target != null:
			break
		frame()
	if target == null:
		return "nenhuma tábua passou"
	press("J")
	var on := false
	for i in 120:
		var d := {"J": i < 16}
		if px() < target.x + target.w / 2 - 6:
			d["R"] = true
		elif px() > target.x + target.w / 2 + 6:
			d["L"] = true
		frame(d)
		P = g.player
		if P.onGround and P.get("_g") == target:
			on = true
			break
	if not on:
		return "não subiu na tábua"
	# vai junto até o alto, perto do barranco
	for i in 1400:
		frame()
		P = g.player
		if P.get("_g") != target:
			return "caiu da tábua y=%d" % int(P.y)
		if target.y < cliff_y + 40 and target.x + target.w > cliff_x - 260 and target.dx > 0:
			break
	return glide_to(cliff_x + 80)

## nada até (x, feet_y) até a condição (debaixo d'água: ↓ mergulha, PULAR dá braçada para cima)
func swim_to(x: float, fy: float, cond: Callable, mx: int = 900):
	for i in mx:
		P = g.player
		if not ok():
			return "state"
		if cond.call():
			return true
		var d := {}
		if px() < x - 8:
			d["R"] = true
		elif px() > x + 8:
			d["L"] = true
		var feet: float = P.y + P.h
		if feet < fy - 6:
			d["S"] = true
		elif feet > fy + 30 and i % 10 == 0:
			press("J")
		frame(d)
	return "timeout@%d,%d" % [int(px()), int(P.y)]

## do fundo do lago até em cima de uma vitória-régia (sobe com braçadas e pula para fora da água)
func surface_to_lily(x: float):
	for i in 900:
		P = g.player
		if not ok():
			return "state"
		if P.onGround and P.y + P.h < -100:
			return true
		var d := {}
		if px() < x - 6:
			d["R"] = true
		elif px() > x + 6:
			d["L"] = true
		if i % 6 == 0:
			press("J")
		d["J"] = true
		frame(d)
	return "timeout@%d,%d swim=%s" % [int(px()), int(P.y), str(P.swim)]

## Brutus (o cão do Vargas), preso na corrente: em cima de uma banca, espera o Pipoca provocar;
## quando a corrente estica no chão, MERGULHO na argola que brilha (3 argolas, uma por banca)
func brutus_fight():
	var b: Dictionary = g.X.BOSS
	var stalls: Array = []
	for s in g.SOL:
		if s.t == "plat" and s.get("trestle") and s.x > b.x0 and s.x < b.x1:
			stalls.append(s)
	stalls.sort_custom(func(a, c): return a.x < c.x)
	until({"R": true}, func(): return b.active, 300)
	for it in 14:
		P = g.player
		if OS.get_environment("DBG") != "":
			print("BR it=%d st=%s t=%d hooked=%d bx=%d px=%d py=%d hp=%d" % [it, b.st, b.t, int(b.get("hooked", 0)), int(b.x), int(px()), int(P.y + P.h), P.hp])
		if b.done or b.st == "down":
			hold({}, 170)
			return true
		if not ok():
			return "state"
		var k: int = int(b.hooked)
		var st: Dictionary = stalls[min(k, stalls.size() - 1)]
		var r: Dictionary = b.rings[min(k, b.rings.size() - 1)]
		# provoca do chão, fora do alcance da corrente (à esquerda da banca da vez)
		var reach: float = max(float(b.x0) + 80.0, float(b.stake) - float(b.len)) - 78.0
		var bait: float = min(float(st.x) - 30.0, reach - 40.0)
		until({}, func(): return b.st in ["idle", "trot"], 400)
		if P.y + P.h < 494 or abs(px() - bait) > 10:
			if P.y + P.h < 494:
				walk_to(float(st.x) - 10 if px() < float(st.x) + float(st.w) / 2 else float(st.x) + float(st.w) + 10)
				wait_ground()
			walk_to(bait)
		var w = until({}, func(): return b.st == "taut" or b.done, 900)
		if b.done:
			continue
		if not (w is bool):
			return "a corrente não esticou (st=%s px=%d)" % [b.st, int(px())]
		# sobe na banca (por cima do Brutus esticado) e mergulha na argola do outro lado
		jump_to(float(st.x) + float(st.w) - 24, true)
		var rx: float = float(r.x)
		press("J")
		var slammed := false
		for i in 120:
			P = g.player
			var d := {"J": i < 10}
			if not slammed:
				if px() < rx - 6:
					d["R"] = true
				elif px() > rx + 6:
					d["L"] = true
				if abs(px() - rx) < 12 and i > 6:
					press("S")
					slammed = true
			frame(d)
			P = g.player
			if P.onGround and i > 4:
				break
		hold({}, 6)
	return "hp=%d st=%s hooked=%d" % [b.hp, b.st, int(b.get("hooked", 0))]

## Morcego-Rei: sobe em cada plataforma e acende a lamparina (✦ USAR)
func bat_fight():
	var h: Dictionary = g.K.HAWK
	var lamps: Array = h.lamps.duplicate()
	lamps.sort_custom(func(a, c): return a.x < c.x)
	for l in lamps:
		P = g.player
		if h.done or h.st in ["dazzle", "fall", "down", "flee"]:
			break
		if l.lit:
			continue
		for tries in 4:
			P = g.player
			if not ok():
				return "state"
			if P.onGround and abs(P.y + P.h - float(l.y)) < 6 and abs(px() - float(l.x)) < 40:
				break
			if P.y + P.h < float(l.y) - 6 or P.y + P.h > 494:
				pass
			walk_to(float(l.x) - 80)
			jump_to(float(l.x), true)
		use()
		if not l.lit:
			return "não acendeu a lamparina em %d (y=%d)" % [int(l.x), int(P.y + P.h)]
	var r = until({}, func(): return h.done or h.st in ["down", "flee"], 600)
	hold({}, 40)
	return r

## pulando de vitória-régia em vitória-régia até a que fica em x
func lily_hop(x: float):
	for n in 12:
		P = g.player
		if not ok():
			return "state"
		if P.swim:
			return "caiu na água"
		if abs(px() - x) < 14 and P.onGround:
			return true
		var dir: float = 1.0 if x > px() else -1.0
		var nx: float = x
		var best := 1e9
		for l in g.LILY:
			var cx: float = float(l.x) + float(l.w) / 2
			var dd: float = (cx - px()) * dir
			if dd > 20 and dd < 230 and dd < best and (cx - x) * dir <= 1:
				best = dd
				nx = cx
		if best >= 1e9:
			nx = x
		jump_to(nx, abs(nx - px()) > 150)
	return abs(px() - x) < 14

## Sapo-Rei: parado na vitória-régia de uma colmeia; quando a mira trava, pula no lugar (a língua
## gruda na colmeia); com o sapo tonto, pula na cabeça dele
func frog_fight():
	var f: Dictionary = g.K.FISH
	for it in 1000:
		P = g.player
		if OS.get_environment("DBG") != "" and it % 5 == 0:
			print("FR it=%d st=%s t=%d hp=%d fx=%d px=%d py=%d swim=%s phl=%d tg=%s" % [it, f.st, f.t, f.hp, int(f.x), int(px()), int(P.y + P.h), str(P.swim), P.hp, str(f.tg.get("st", ""))])
		if f.done or f.st == "down":
			hold({}, 60)
			return true
		if not ok():
			return "state"
		if P.swim:
			# caiu na água: nada até a vitória-régia mais perto e pula para cima dela
			var best: Dictionary = {}
			var bd := 1e9
			for l in g.LILY:
				var dd: float = abs(float(l.x) + float(l.w) / 2 - px())
				if dd < bd and l.st == 0 and not l.get("big"):
					bd = dd
					best = l
			surface_to_lily(float(best.x) + float(best.w) / 2)
			frame()
			continue
		# a colmeia mais perto do sapo que ainda está no cipó
		var hv: Dictionary = {}
		var hd := 1e9
		for h2 in f.hives:
			if h2.st == "hang":
				var dd2: float = abs(float(h2.x) - f.x)
				if dd2 < hd:
					hd = dd2
					hv = h2
		if f.st == "dizzy":
			# vai até a vitória-régia mais perto do sapo e pula na cabeça dele
			var nl: float = 1e9
			var lx := px()
			for l in g.LILY:
				var cx: float = float(l.x) + float(l.w) / 2
				if not l.get("big") and cx < f.x and abs(cx - f.x) < nl:
					nl = abs(cx - f.x)
					lx = cx
			if abs(px() - lx) > 14:
				lily_hop(lx)
				continue
			press("J")
			var used := false
			for i in 140:
				P = g.player
				var d := {"J": i < 16 or (used and i < 40)}
				if px() < f.x - 16:
					d["R"] = true
				elif px() > f.x + 16:
					d["L"] = true
				if not used and i > 12 and P.vy > -1:
					press("J")
					used = true
				frame(d)
				P = g.player
				if f.st in ["hurt", "down"] or (P.onGround and i > 3) or P.swim:
					break
			if f.st in ["hurt", "down"]:
				# quicou na cabeça: volta para as vitórias-régias
				for i in 60:
					frame({"L": true})
					P = g.player
					if P.onGround and i > 4:
						break
			continue
		if hv.is_empty():
			frame()
			continue
		var hx: float = float(hv.x)
		if abs(px() - hx) > 14 or not P.onGround:
			if P.onGround:
				lily_hop(hx)
			else:
				frame({"R": true} if px() < hx else {"L": true})
			continue
		# parado na frente da colmeia: espera a mira travar e pula no lugar
		var aim_t: int = 40 if f.hp <= 1 else 52
		if f.st == "aim" and f.t >= aim_t - 8:
			press("J")
			for i in 14:
				frame({"J": true})
			wait_ground()
			continue
		frame()
	return "hp=%d st=%s" % [f.hp, f.st]

func house_list() -> Array:
	var out: Array = []
	for s in g.L.solids:
		if s.t == "house":
			var parts: Array = []
			var chims: Array = []
			for r in g.L.solids:
				if r.x < s.x - 2 or r.x + r.w > s.x + s.w + 2:
					continue
				if r.t == "roof" and r.get("chim"):
					chims.append(r)
				elif r.t == "roof" and r.get("walk"):
					parts.append(r)
				elif r.t == "plat" and r.get("roofhole"):
					chims.append({"x": r.x, "w": r.w, "h": 0})
			var x0: float = 1e9
			var x1: float = -1e9
			for r in parts:
				x0 = min(x0, float(r.x))
				x1 = max(x1, float(r.x) + float(r.w))
			# telhas soltas viram um obstáculo só (pula por cima de todas)
			var obs: Array = []
			var loose: Array = chims.filter(func(c): return not c.has("t"))
			if not loose.is_empty():
				var lx0: float = loose.map(func(c): return float(c.x)).min()
				var lx1: float = loose.map(func(c): return float(c.x) + float(c.w)).max()
				obs.append({"x": lx0, "w": lx1 - lx0, "h": 0})
			for c in chims:
				if c.has("t"):
					obs.append(c)
			obs.sort_custom(func(a, b): return float(a.x) < float(b.x))
			out.append({"h": s, "walk": {"x": x0, "w": x1 - x0, "y": float(parts[0].y)}, "chims": obs})
	return out

func _initialize() -> void:
	g = load("res://scripts/game.gd").new()
	root.add_child(g)
	g.load_level(1)
	g.no_coal = true
	for e in g.EN:
		e.dead = 99
	P = g.player
	g.rest_reached.connect(func(n):
		rests.append(n)
		print("REST ", n, " T=", g.T)
		g.running = true)
	var L: Dictionary = g.L
	# ---------------- A · BOCA DA MINA
	walk_to(600)
	S("pula a caixa", jump_to(720))
	S("pista 7", walk_to(1230) and n_clues() == 1)
	walk_to(1385)
	S("cavalete 1", jump_to(1498))
	S("cavalete 2", jump_to(1648))
	hop("R", 0)
	S("vermelho", spec("vermelho"))
	S("cavalete 3", jump_to(1808))
	S("chão depois do poço", jump_to(1960))
	S("chega na manivela", walk_to(3020))
	for i in 8:
		if not g.CRANKS[0].done:
			use()
	S("porta da manivela abriu", g.CRANKS[0].done)
	S("passa a porta", walk_to(3300))
	walk_to(3420)
	S("caixa no buraco da placa", until({"R": true}, func(): return g.M.PUSH[0].x >= 3719 and g.M.PUSH[0].y >= 449, 900))
	S("portão g1 abriu", until({}, func(): return g.M.GATES[1].open > .85 if g.M.GATES.size() > 1 else g.M.GATES[0].open > .85, 200))
	S("pula a caixa", jump_to(3840, true))
	S("vai ao elevador", walk_to(4328))
	S("sobe de elevador", lift_ride(true))
	S("galeria de cima", walk_to(4450))
	S("corda", walk_to(4780) and g.INV.has("corda"))
	walk_to(5250)
	hop("R", 0)
	S("laranja", spec("laranja"))
	S("desenho 1", walk_to(5580))
	S("desce da galeria", walk_to(5760))
	S("lago tóxico: estaca", stake_cross(5800))
	walk_to(6460)
	S("carrinho 1", jump_to(6560))
	S("espinhos", jump_to(6800, true))
	walk_to(6860)
	S("tábua do desenho", jump_to(7000, true))
	S("desenho 2", walk_to(7040))
	S("desce", walk_to(7300))
	S("degrau 1", jump_to(7540))
	S("degrau 2", jump_to(7700))
	S("degrau 3", jump_to(7850))
	S("degrau 4", jump_to(8000))
	S("alto", jump_to(8120))
	walk_to(8650)
	S("chão", until({}, func(): return P.onGround and P.y > 400, 200))
	walk_to(8860)
	use()
	walk_to(8930)
	use()
	S("portão das alavancas", until({}, func(): return g.EV.GATE.lift >= g.EV.GATE.h - 8, 200))
	S("fogueira 1", walk_to(9460))
	S("descansou 1", rests.has(1))
	# ---------------- B · VALE DO MOINHO
	S("vale", walk_to(10900))
	S("flor", jump_to(10950))
	S("lançado para a pedra", until({}, func(): return P.onGround and P.y < 250, 300))
	walk_to(11235)
	hop("R", 0)
	S("amarelo", spec("amarelo"))
	S("desce da pedra", walk_to(11420))
	S("entra no celeiro", crawl(11660))
	S("lona", g.INV.has("lona"))
	S("sai do celeiro", crawl(11840))
	S("pista 8", walk_to(12110) and n_clues() == 2)
	walk_to(12640)
	S("pedra 1", jump_to(12760))
	S("pedra 2", jump_to(12910))
	S("margem", jump_to(13110))
	S("combina lona+corda", g.try_combine("lona", "corda") != "")
	S("porta do moinho", walk_to(13620))
	use()
	S("moinho girando", g.LOCKS[0].done)
	walk_to(13600)
	S("sobe pelas pás", mill_ride(14000, -150))
	S("alto do barranco", P.onGround and P.y < -150)
	# o caixote na placa abre a cancela
	var cr: Dictionary = {}
	for c in g.M.PUSH:
		if absf(float(c.x) - 14220) < 5:
			cr = c
	walk_to(float(cr.x) - 22)
	S("empurra o caixote para a placa", until({"R": true}, func(): return float(cr.y) > -150 - 60 + 10, 600))
	hold({}, 30)
	walk_to(float(cr.x) - 30)
	jump_to(float(cr.x) + 30)
	S("a cancela abriu", walk_to(14680))
	# o lago: mergulha, pega o capacete e o arpão na prateleira
	S("cai no lago", until({"R": true}, func(): return P.swim, 200))
	S("desce até a prateleira", swim_to(14775, 292, func(): return g.NT.helmet))
	S("pega o arpão", swim_to(14860, 292, func(): return g.NT.harpoon))
	S("capacete e arpão", g.NT.helmet and g.NT.harpoon)
	# volta para a superfície e sobe na primeira vitória-régia: a luta do Sapo-Rei
	S("sobe para a vitória-régia", surface_to_lily(14826))
	S("entra na arena do Sapo-Rei", until({"R": true}, func(): return g.K.FISH.active, 200) if not g.K.FISH.active else true)
	S("vence o Sapo-Rei", frog_fight())
	# o lápis verde no fundo e a corrente de bolhas
	var vx: float = 15440.0
	if not P.swim:
		# da vitória-régia: cai no lago
		walk_to(px() + 60)
	S("verde", swim_to(vx, 430, func(): return g.SPECGOT.has("verde"), 900))
	S("corrente de bolhas", until({"R": true}, func(): return P.onGround and px() > 16000 and P.y < -100, 700))
	S("desenho 3", walk_to(16120))
	S("fogueira 2", walk_to(16300))
	S("descansou 2", rests.has(2))
	# ---------------- C · TELHADOS
	S("beira do barranco", walk_to(16700))
	S("pilar", walk_to(16880))
	var HS := house_list()
	S("%d casas" % HS.size(), HS.size() == 12)
	var w0: Dictionary = HS[0].walk
	S("primeiro telhado", walk_to(w0.x + 40) if true else true)
	S("no telhado", until({}, func(): return P.onGround and P.y + P.h < 300, 200))
	for i in HS.size():
		var hs: Dictionary = HS[i]
		var w: Dictionary = hs.walk
		# o que tem neste telhado (lápis especial e desenho no alto: pulo no lugar)
		for o in g.SPECS + g.DRWS + g.ITEMS + g.CLUES:
			if not o.got and o.x > w.x and o.x < w.x + w.w:
				var smoke = null
				for c in hs.chims:
					if c.has("t") and o.x > float(c.x) - 30 and o.x < float(c.x) + float(c.w) + 30:
						smoke = c
				if smoke != null and o.y < w.y - 100:
					# lá no alto da fumaça: sobe na chaminé e plana na fumaça
					roof_walk(float(smoke.x) - 30, hs.chims)
					jump_to(float(smoke.x) + float(smoke.w) / 2, true)
					until({"J": true}, func(): return o.got, 160)
					wait_ground()
				else:
					roof_walk(o.x, hs.chims)
					if o.y < w.y - 60:
						hop("R", 0)
		if i == 2:
			S("metade A", g.INV.has("chave_a"))
		if i == 9:
			S("metade B", g.INV.has("chave_b"))
		var endx: float = w.x + w.w - 14
		for c in hs.chims:
			if float(c.x) + float(c.w) > endx - 40:
				endx = float(c.x) - 24
		var r = roof_walk(endx, hs.chims)
		S("telhado %d" % i, r)
		if i + 1 < HS.size():
			var nw: Dictionary = HS[i + 1].walk
			var gap: float = nw.x - px()
			var r2
			if float(nw.y) < float(w.y) - 150:
				# sobrado alto demais: desce no toldo, ele joga para cima, e pulo duplo no alto
				var aw: Dictionary = g.L.awnings[0]
				var amid: float = float(aw.x) + float(aw.w) / 2
				press("J")
				var launched = "timeout"
				for k in 300:
					P = g.player
					if P.vy < -12.0 and not P.onGround and P.y + P.h > float(w.y):
						launched = true
						break
					var d := {"J": k < 14}
					if px() < amid - 8:
						d["R"] = true
					elif px() > amid + 8:
						d["L"] = true
					frame(d)
				var dj := false
				for k in 200:
					P = g.player
					var d := {"J": true}
					if px() < nw.x + 60:
						d["R"] = true
					if not dj and P.vy > -2.0:
						press("J")
						dj = true
					frame(d)
					P = g.player
					if P.onGround and k > 5:
						break
				r2 = launched
			else:
				var land: float = nw.x + 40
				for c in HS[i + 1].chims:
					if float(c.x) < land + 30 and float(c.x) + float(c.w) > nw.x:
						land = float(c.x) + float(c.w) + 30
				r2 = jump_to(land, true) if gap < 250 else glide_to(land + 20)
			P = g.player
			if P.get("bar") != null:
				# pendurado no varal: anda até a ponta e pula para o telhado
				var bb: Dictionary = P.bar
				until({"R": true}, func(): return px() > float(bb.x1) - 40, 400)
				press("J")
				r2 = jump_to(nw.x + 50)
			var gs = P.get("_g")
			if gs is Dictionary and gs.get("tile"):
				# pousou nas telhas soltas: corre antes que caiam
				r2 = jump_to(nw.x + 40)
			var hn: Dictionary = HS[i + 1].h
			S("pula para o telhado %d (vão %d)" % [i + 1, int(gap)], r2 is bool and r2 and P.onGround and px() > hn.x and px() < hn.x + hn.w and P.y + P.h < 400)
	S("pistas na vila (9 e 10)", n_clues() == 4)
	S("azul", spec("azul"))
	S("desce para o quintal", until({"R": true}, func(): return P.onGround and P.y > 400, 300))
	S("Brutus", brutus_fight())
	S("portão do quintal abriu", walk_to(float(g.X.BOSS.x1) + 60))
	S("fogueira 3", walk_to(float(g.CHK.filter(func(c): return c.has("rest") and c.rest == 3)[0].x) + 10))
	S("descansou 3", rests.has(3))
	S("combina a chave", g.try_combine("chave_a", "chave_b") != "")
	var lk: Dictionary = g.LOCKS[1]
	walk_to(float(lk.x) + 40)
	use()
	S("porteira aberta", lk.done)
	S("porteira sobe (animação)", until({}, func(): return g.M.GATES.filter(func(gt): return gt.get("id", "") == "vgate")[0].open >= 1.0, 300))
	# ---------------- D · PROFUNDEZAS
	var D0: float = float(L.sections[3].x) - 420.0
	S("pista 11", walk_to(D0 + 610) and n_clues() == 5)
	g.lantern_lit = true
	S("entra na caverna", until({"R": true}, func(): return g.K.HAWK.active, 400))
	S("vence o Morcego-Rei", bat_fight())
	walk_to(D0 + 1260)
	S("tábua do roxo", jump_to(D0 + 1360))
	hop("R", 0)
	S("roxo", spec("roxo"))
	var SLd: Dictionary = L.sled
	S("chega no carrinho e parte sozinho", until({"R": true} if px() < float(SLd.x) else {"L": true}, func(): return g.VH.mode == "sled", 600))
	S("subiu no carrinho", g.VH.mode == "sled")
	var VH = g.VH
	var done_cart = "timeout"
	for i in 4000:
		if VH.mode == "":
			done_cart = true
			break
		var d := {}
		var ground: bool = VH.hy >= VH.sled_y(VH.su) - 1
		for o in VH.OBS:
			var dx: float = o.x - VH.hx
			if o.hit or o.k == "bump" or dx < -140 or dx > 300:
				continue
			if o.k in ["rock", "log"] and ground and dx < VH.spd * 9.0 + 24 and dx > 30:
				press("J")
			if o.k == "crack" and ground and dx < 40 and dx > -5:
				press("J")
			if o.k == "branch" and dx < 110 and dx > -100:
				d["S"] = true
			break
		frame(d)
	S("carrinho chegou", done_cart)
	var hk := []
	for o in VH.OBS:
		if o.hit:
			hk.append(o.k + "@" + str(o.u))
	S("carrinho sem batidas " + str(hk), P.hp == 5 and VH.tries == 0)
	S("pista 12", walk_to(float(L.door.x) - 300) and n_clues() == 6)
	walk_to(float(L.door.x) + 30)
	var sa = until({}, func(): return not g.running, 300)
	S("porta do cofre (fim)", sa is String and sa == "state")
	var nd: int = g.DRWS.filter(func(d): return d.got).size()
	print("desenhos: ", g.DRWS.map(func(d): return [int(d.x), int(d.y), d.got]))
	S("final: pistas=%d esp=%d des=%d lápis=%d/%d" % [n_clues(), g.SPECGOT.size(), nd, g.STATS.pen, g.STATS.penTotal], n_clues() == 6 and g.SPECGOT.size() == 6 and nd == g.DRWS.size())
	for l in log_lines:
		print(l)
	print("FALHAS: %d" % fails)
	quit(1 if fails > 0 else 0)
