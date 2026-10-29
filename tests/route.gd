extends SceneTree
## Teste automático: joga a Fase 1 inteira, do começo à saída da mina, pegando as 6 pistas,
## os 6 lápis especiais e os 2 desenhos. Uso:
##   godot --headless --path . -s tests/route.gd            (sem inimigos)
##   godot --headless --path . -s tests/route.gd -- inimigos (com inimigos)

var g
var P: Dictionary
var log_lines: Array = []
var fails := 0
var rests: Array = []

func frame(set: Dictionary = {}) -> void:
	for k in ["L", "R", "J", "P", "S", "U", "A"]:
		g.keys[k] = false
	for k in set:
		g.keys[k] = set[k]
	g.step()
	while not g.CINE.is_empty():
		g.step()

func press(k: String) -> void:
	g.keys[k + "p"] = true

## pula e, no alto do pulo, aperta ↓ (mergulho) e espera bater no chão
func slam_here() -> void:
	press("J")
	frame({"J": true})
	for i in 40:
		frame({"J": true})
		if P.vy > -2:
			break
	press("S")
	frame()
	for i in 90:
		frame()
		if P.onGround or P.ladder != null or P.y > 600:
			break

## lago de veneno: sobe na estaca, crava com o mergulho, espera a ponte cair e atravessa
func stake_cross(sx: float):
	var st: Dictionary = {}
	for o in g.SL.STAKES:
		if abs(float(o.x) - sx) < 5:
			st = o
	if st.is_empty():
		return "sem estaca"
	if not st.done:
		if px() < sx - 60:
			walk_to(sx - 60)
		jump_to(sx)
		if not P.onGround or abs(P.y + P.h - (float(st.y) - 44)) > 6:
			return "não subiu na estaca y=%d" % int(P.y + P.h)
		slam_here()
		if not until({}, func(): return st.done and st.lift >= 1.0, 400):
			return "a ponte não caiu"
	return walk_to(float(st.bridge.x) + float(st.bridge.w) + 40)

func px() -> float:
	return P.x + P.w / 2

func ok() -> bool:
	return g.running

func S(name: String, r) -> void:
	P = g.player
	var bad: bool = (r is String and r != "" and not r.begins_with("ok")) or (r is bool and r == false)
	if bad:
		fails += 1
	log_lines.append("%s %s: %s  [x=%d y=%d vidas=%d hp=%d %s]" % ["✗" if bad else "·", name, str(r), int(px()), int(P.y), g.lives, P.hp, P.dieMsg])

func walk_to(x: float, mx: int = 1500):
	var last := px()
	var stuck := 0
	for i in mx:
		P = g.player
		if not ok():
			return "state"
		if abs(px() - x) < 6 and P.onGround:
			for j in 10:
				frame()
			return true
		frame({"R" if x > px() else "L": true})
		P = g.player
		if abs(px() - last) < .05:
			stuck += 1
		else:
			stuck = 0
		last = px()
		if stuck > 50:
			return "stuck@%d,%d" % [int(px()), int(P.y)]
	return "timeout@%d" % int(px())

func wait_ground(set: Dictionary = {}, mx: int = 700):
	for i in mx:
		P = g.player
		if not ok():
			return "state"
		if P.onGround:
			return true
		frame(set)
	return "air"

func hold(set: Dictionary, n: int):
	for i in n:
		if not ok():
			return "state"
		frame(set)
	return true

func until(set: Dictionary, cond: Callable, mx: int = 900):
	for i in mx:
		P = g.player
		if not ok():
			return "state"
		if cond.call():
			return true
		frame(set)
	return "timeout@%d,%d" % [int(px()), int(P.y)]

func hop(dir: String, ndir: int, h: int = 16):
	press("J")
	for i in h:
		frame({"J": true, dir: true} if i < ndir else {"J": true})
	return wait_ground()

func djump(dir: String):
	var d := {dir: true}
	press("J")
	for i in 16:
		frame({"J": true, dir: true})
	for i in 30:
		P = g.player
		if P.vy >= -.5:
			break
		frame(d)
	press("J")
	for i in 16:
		frame({"J": true, dir: true})
	return wait_ground(d)

func jump_to(x: float, dbl: bool = false, mx: int = 200):
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
		if dbl and not used and i > 14 and P.vy > -1:
			press("J")
			used = true
		var s := d.duplicate()
		s["J"] = i < 16 or (dbl and i < 34)
		frame(s)
		P = g.player
		if P.onGround and i > 3:
			return true
	return "air"

func crawl(x: float, mx: int = 600):
	var dir := "R" if x > px() else "L"
	for i in mx:
		if not ok():
			return "state"
		if (px() >= x) if dir == "R" else (px() <= x):
			for j in 4:
				frame()
			return true
		frame({"S": true, dir: true})
	return "timeout@%d,%d" % [int(px()), int(g.player.y)]

func climb_to(dir: String, cond: Callable, mx: int = 600):
	for i in mx:
		P = g.player
		if cond.call():
			return true
		frame({dir: true})
	return "timeout y=%d lad=%s" % [int(g.player.y), str(g.player.ladder != null)]

func use():
	press("A")
	frame()
	hold({}, 6)
	return true

func down():
	press("S")
	frame({"S": true})
	hold({}, 40)
	return true

func jr(n: int, dir: String):
	press("J")
	hold({"J": true, dir: true}, n)
	return wait_ground({dir: true})

func wall_climb():
	var dir := "R"
	press("J")
	hold({"J": true, dir: true}, 10)
	for i in 18:
		P = g.player
		until({dir: true}, func(): return g.player.wsl > 0 or g.player.onGround, 90)
		P = g.player
		if P.onGround:
			return P.y + P.h <= 102
		press("J")
		frame({"J": true})
		dir = "L" if dir == "R" else "R"
		hold({"J": true}, 6)
	return "wall@%d,%d" % [int(px()), int(P.y)]

## sobe a fenda pulando de parede em parede; termina em pé lá em cima
func crevice_climb():
	var dir := "R"
	press("J")
	hold({"J": true, dir: true}, 10)
	for i in 24:
		P = g.player
		until({dir: true}, func(): return g.player.wsl > 0 or g.player.onGround, 90)
		P = g.player
		if P.onGround:
			return P.y + P.h <= -14 or "chão y=%d" % int(P.y + P.h)
		press("J")
		frame({"J": true})
		dir = "L" if dir == "R" else "R"
		hold({"J": true}, 6)
	return "fenda@%d,%d" % [int(px()), int(P.y)]

func hawk_fight():
	var h: Dictionary = g.K.HAWK
	var mid: float = (h.x0 + h.x1) / 2.0
	for it in 3080:
		P = g.player
		if not ok():
			return "state"
		if h.done or h.st == "flee":
			hold({}, 60)
			return true
		match h.st:
			"mark", "dive":
				var tx: float = h.tx - 230 if h.tx > mid else h.tx + 230
				frame({"R" if tx > px() else "L": true} if abs(tx - px()) > 10 else {})
			"stuck":
				var side: float = -1.0 if px() < h.x else 1.0
				var tx2: float = h.x + side * 44
				if abs(tx2 - px()) > 6:
					frame({"R" if tx2 > px() else "L": true})
				else:
					P.face = -int(side)
					press("G")
					hold({}, 24)
			_:
				frame()
	return "hp=%d st=%s" % [h.hp, h.st]


## Urso-Rei: perseguição. Corre para a direita pulando os troncos, abaixa embaixo do galho, para quando
## a sombra de um pingente está logo à frente, entra abaixado na fresta e pega a coroa do outro lado.
## Rigoroso: o urso não pode encostar no Tomé (nenhum coração perdido) e não pode passar da rocha.
func bear_fight():
	var K = g.K
	var b: Dictionary = K.BEAR
	var rx: float = float(b.rock.x)
	var rend: float = rx + float(b.rock.w)
	var min_hp: int = P.hp
	var past_rock := false
	var saw := {}
	for it in 3000:
		P = g.player
		if not ok():
			return "state"
		min_hp = min(min_hp, int(P.hp))
		saw[b.st] = 1
		if b.x > rx - 99.0:
			past_rock = true
		if OS.get_environment("BEARDBG") != "" and it % 20 == 0:
			print("bear st=%s t=%d bx=%d px=%d php=%d" % [b.st, b.t, int(b.x), int(px()), P.hp])
		if K.TOOK.has("urso"):
			hold({}, 80)
			break
		var pcx: float = px()
		var feet: float = P.y + P.h
		var d := {"R": true}
		# do outro lado da fresta: espera a coroa rolar e vai pegar
		if P.x > rend + 2:
			var cr = null
			for c in K.CROWNS:
				if c.id == "urso":
					cr = c
			if cr == null or cr.st == "fall" or cr.has("to"):
				frame({})
				continue
			if abs(cr.x - pcx) > 6:
				frame({"R" if cr.x > pcx else "L": true})
			else:
				frame({})
			continue
		# fresta: abaixa e vai
		if pcx > rx - 70:
			frame({"R": true, "S": true})
			continue
		# pingente marcado logo à frente: espera ele cair (se estiver bem em cima, sai de baixo correndo)
		var wait := false
		var under := false
		for c in K.ICI:
			if c.st in ["shake", "fall"]:
				if abs(c.x - pcx) < 26:
					under = true
				elif c.x - pcx > 0 and c.x - pcx < 80:
					wait = true
		if wait and not under and P.onGround:
			frame({})
			continue
		var jumped := false
		for o in K.BOBS:
			if o.get("fallen"):
				continue
			var dist: float = o.x - (P.x + P.w)
			if o.k == "branch":
				if dist < 30 and dist > -o.w - 10 and P.onGround:
					d["S"] = true
			elif P.onGround and dist > 0 and dist < max(16.0, abs(P.vx) * 7.0 + 6.0):
				press("J")
				jumped = true
		if jumped:
			d["J"] = true
			frame(d)
			for k in 14:
				frame({"R": true, "J": true})
			continue
		frame(d)
	if not K.TOOK.has("urso"):
		return "sem coroa st=%s bx=%d px=%d" % [b.st, int(b.x), int(px())]
	if min_hp < g.MAXHP:
		return "levou golpe (coração %d)" % min_hp
	if past_rock:
		return "urso passou da rocha"
	if not (saw.has("crouch") and saw.has("roar") and K.DROPPED.has("urso")):
		return "faltou ataque: %s" % str(saw.keys())
	for o in K.BOBS:
		if not o.get("fallen"):
			return "urso não arrebentou %s" % o.k
	return true

## pula de um cipó para o próximo (solta no auge do balanço para a frente)
func vine_hop(next_vine, mx: int = 600):
	for i in mx:
		P = g.player
		if not ok():
			return "state"
		if P.vine == null:
			break
		var v: Dictionary = P.vine
		frame({"R": true} if v.om > 0 else {"L": true})
		if v.th > .35 and v.om > 0:
			break
	press("J")
	frame()
	if next_vine == null:
		return wait_ground()
	return until({}, func(): return g.player.vine == next_vine or g.player.get("bar") != null or g.player.onGround, 120)

## pula da beirada até agarrar um cipó (com pulo duplo)
func grab_vine(v):
	press("J")
	for i in 120:
		P = g.player
		if P.vine == v:
			return true
		if i == 16:
			press("J")
		frame({"J": i < 40, "R": true})
	return "sem cipó"

func fish_fight():
	var f: Dictionary = g.K.FISH
	for it in 6080:
		P = g.player
		if not ok():
			return "state"
		if f.done or f.st == "down":
			hold({}, 30)
			return true
		var pc := Vector2(px(), P.y + P.h / 2)
		var d := {}
		match f.st:
			"tired":
				var pts: Array = g.K.scale_pts()
				var tgt = null
				for i in 4:
					if f.scales[i]:
						tgt = pts[i]
						break
				if tgt == null:
					frame()
					continue
				var want_x: float = tgt.x - 230 if pc.x < f.x else tgt.x + 230
				want_x = clamp(want_x, f.x0 + 30, f.x1 - 30)
				if abs(want_x - pc.x) > 30:
					d["R" if want_x > pc.x else "L"] = true
				var hy: float = P.y + 14
				if hy > tgt.y + 6:
					d["U"] = true
				elif hy < tgt.y - 6:
					d["S"] = true
				P.face = 1 if tgt.x > pc.x else -1
				if abs(hy - tgt.y) < 22 and g.NT.harp_cd == 0 and abs(tgt.x - pc.x) < 380:
					g.keys["Gp"] = true
			"aim", "charge":
				var midy: float = (f.y0 + f.y1) / 2.0
				if f.y > midy:
					d["U"] = true
				else:
					d["S"] = true
			"suck":
				d["L" if f.x > pc.x else "R"] = true
			_:
				var want: float = f.x - 300 if pc.x < f.x else f.x + 300
				want = clamp(want, f.x0 + 40, f.x1 - 40)
				if abs(want - pc.x) > 20:
					d["R" if want > pc.x else "L"] = true
		frame(d)
	return "hp=%d st=%s" % [f.hp, f.st]

## bola de neve rolando na direção do Tomé: anda até disparar e pula por cima quando ela chega
func dodge_roll(x: float, i: int):
	walk_to(x)
	var o: Dictionary = g.TR.by_kind("roll")[i]
	var r = until({}, func(): return o.st == "go" and o.bx - px() < 85, 400)
	if r != true:
		return "não rolou: " + str(r) + " st=" + o.st
	press("J")
	hold({"J": true}, 16)
	wait_ground()
	hold({}, 10)
	return o.bx < px() - 20 or "bola em %d" % int(o.bx)

## corre (dois toques em →) até x
func run_to(x: float):
	frame({"R": true})
	frame({})
	for i in 300:
		P = g.player
		if px() >= x:
			return true
		frame({"R": true})
	return "timeout@%d" % int(px())

func ride():
	var RD = g.RD
	for it in 4080:
		if not RD.riding:
			return RD.done
		var d := {}
		for o in RD.OBS:
			var dx: float = o.x - RD.hx
			if dx < -200 or dx > 260:
				continue
			# pula em cima da marca de cascos (o melhor ponto)
			if o.k in ["log", "rock", "gap", "fence", "logs", "leap"] and not o.hit and RD.hy >= 500:
				var tk: float = RD.takeoff_x(o)
				if RD.hx >= tk - 3 and RD.hx < tk + 6:
					press("J")
					d["J"] = true
			if o.k in ["branch", "rope"] and dx < 110 and dx > -130:
				d["S"] = true
			if dx > -40:
				break
		frame(d)
	return "não terminou x=%d" % int(RD.hx)

func _to_bar():
	for i in 600:
		P = g.player
		if P.vine == null:
			break
		var v: Dictionary = P.vine
		frame({"R": true} if v.om > 0 else {"L": true})
		if v.th > .35 and v.om > 0:
			break
	press("J")
	frame()
	return until({}, func(): return g.player.get("bar") != null, 120)

func on_perch() -> bool:
	return P.onGround and P.y + P.h <= 397

func boss_fight():
	for it in 60:
		P = g.player
		var b: Dictionary = g.X.BOSS
		if b.done or b.st == "down":
			hold({}, 160)
			return true
		if not ok():
			return "state"
		if on_perch():
			# espera ele se afastar e desce de novo
			until({}, func(): return g.X.BOSS.st == "idle" or g.X.BOSS.st == "down", 600)
			if g.X.BOSS.st == "down":
				continue
			walk_to(5005)
			until({}, func(): return P.onGround and P.y + P.h >= 494, 60)
		walk_to(4905)
		# no chão: ele investe; pula para o galho quando chega perto
		until({}, func(): return g.X.BOSS.st == "charge" and abs(g.X.BOSS.x - px()) < 330, 400)
		jump_to(4905, true)
		hold({}, 4)
	return "hp=%d st=%s" % [g.X.BOSS.hp, g.X.BOSS.st]

## pilota o trenó/carrinho até o fim (pula pedras, troncos e rachaduras; abaixa nos galhos)
func sled_drive():
	var VH = g.VH
	for i in 5000:
		if VH.mode == "":
			return true
		if not ok():
			return "state"
		var d := {}
		var ground: bool = VH.hy >= VH.sled_y(VH.su) - 1
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
	return "timeout"

func n_clues() -> int:
	return g.CLUEGOT.size()

func spec(c: String) -> bool:
	return g.SPECGOT.has(c)

## a armadilha do tipo k mais perto de x
func trap_at(k: String, x: float) -> Dictionary:
	var best: Dictionary = {}
	for o in g.TR.T:
		if o.k == k and (best.is_empty() or abs(o.x - x) < abs(best.x - x)):
			best = o
	return best

## espera os espinhos acabarem de descer e atravessa andando
func cross_spikes(o: Dictionary, x_after: float):
	var per: int = o.get("per", 140)
	for i in 400:
		if (g.T + int(o.get("ph", 0))) % per == per / 2 + 8:
			break
		frame()
	return walk_to(x_after)

## tronco-pêndulo: espera ele subir para o lado de lá e passa correndo por baixo
func cross_swing(o: Dictionary, x_after: float):
	for i in 400:
		var th: float = fposmod(TAU * (g.T + o.get("ph", 0)) / float(o.per), TAU)
		if abs(th - deg_to_rad(215)) < .04:
			break
		frame()
	return run_to(x_after)

## corta a teia com a picareta (de frente para ela)
func cut_web(o: Dictionary):
	walk_to(o.x - 22)
	P.face = 1
	press("G")
	hold({}, 24)
	return o.cut or "teia inteira"

## pula num cogumelo saltador e deixa ele lançar até pousar
func bounce_to(bx: float):
	press("J")
	var launched := false
	for i in 300:
		P = g.player
		if not ok():
			return "state"
		if P.get("launchT", 0) > 0:
			launched = true
		var d := {}
		if not launched:
			if px() < bx - 4:
				d = {"R": true}
			elif px() > bx + 4:
				d = {"L": true}
			d["J"] = i < 16
		frame(d)
		P = g.player
		if launched and P.onGround:
			return true
	return "não foi lançado" if not launched else "air"

## corredeira: pula pedras, troncos e quedas; abaixa nos galhos
func ride_raft():
	var VH = g.VH
	for it in 4080:
		if VH.mode != "raft":
			return VH.raft_done
		var d := {}
		var wl: float = VH.water_y(VH.hx)
		for f in VH.RA.falls:
			var df: float = f - VH.hx
			if df > 4 and df < 40 and VH.hy >= wl - 1:
				press("J")
				d["J"] = true
		for o in VH.OBS:
			var dx: float = o.x - VH.hx
			if dx < -240 or dx > 220 or o.k == "rapid":
				continue
			if o.k in ["rock", "log"] and dx < 70 and dx > 26 and VH.hy >= wl - 1:
				press("J")
				d["J"] = true
			var dw: float = g.VH.DUCK_W.get(o.k, 0.0)
			if dw > 0 and dx < 120 and dx > -(dw + 36):
				d["S"] = true
			if dx > -40:
				break
		frame(d)
	return "não terminou x=%d" % int(VH.hx)

## subida da montanha: anda; perto de um precipício espera a rajada passar (abaixado) e pula
func climb_gusts(x_end: float):
	var chasms: Array = g.L.chasms
	for it in 3080:
		P = g.player
		if not ok():
			return "state"
		if px() >= x_end and P.onGround:
			return true
		var gusting := false
		for o in g.TR.T:
			if o.k == "gust" and g.TR.gust_state(o) > 0 and px() > o.x - 220 and px() < o.x + o.w + 40:
				gusting = true
		# degrau à frente?
		var step_up := false
		for s in g.SOL:
			if s.t == "ground" and s.x > px() and s.x - px() < 40 and s.y < P.y + P.h - 4 and P.onGround:
				step_up = true
		var edge := false
		for c in chasms:
			if c[0] - px() > 0 and c[0] - px() < 30 and P.onGround:
				edge = true
		if edge:
			if gusting:
				frame({"S": true})
				continue
			press("J")
			for i in 40:
				frame({"J": i < 18, "R": true})
				P = g.player
				if P.onGround and i > 4:
					break
			continue
		if step_up:
			press("J")
			for i in 30:
				frame({"J": i < 12, "R": true})
				P = g.player
				if P.onGround and i > 4:
					break
			continue
		if gusting and g.TR.T.any(func(o): return o.k == "gust" and g.TR.gust_state(o) == 2 and px() > o.x and px() < o.x + o.w):
			frame({"R": true})
		else:
			frame({"R": true})
	return "timeout@%d,%d" % [int(px()), int(P.y)]

## ponte que se solta: corre e pula os vãos
func bridge_run(o: Dictionary):
	var gaps: Array = []
	for gi in o.get("gaps", []):
		gaps.append(o.x + gi * 40.0)
	frame({"R": true})
	frame({})
	for it in 600:
		P = g.player
		if not ok():
			return "state"
		if px() > o.x + o.w + 40 and P.onGround:
			return true
		var d := {"R": true}
		for gx in gaps:
			if gx - px() > 0 and gx - px() < 34 and P.onGround:
				press("J")
		d["J"] = not P.onGround and P.vy < 0
		frame(d)
	return "timeout@%d,%d" % [int(px()), int(P.y)]

## voo: para cada grupo de obstáculos à frente calcula as alturas livres e vai para a mais perto
func _obs_box(o: Dictionary) -> Array:
	match o.k:
		"flock":
			return [o.x - 30, o.x + 90, o.y - 26, o.y + 64]
		"cloud":
			return [o.x + 10, o.x + o.w - 10, o.y + 8, o.y + o.h - 8]
		"spire":
			return [o.x - 44, o.x + 44, float(o.top) + 6, 2000.0]
		"hawk":
			if o.st == "gone":
				return []
			var ty: float = o.get("ty", o.y)
			if o.st in ["warn", "dive", "sweep"]:
				return [o.x - 400, o.x + 40, ty - 18, ty + 18]
			return []
	return []

func _free_spans(boxes: Array, top: float, low: float) -> Array:
	# alturas (hy) livres: a caixa do avião vai de hy-46 a hy-6
	var spans := [[top, low]]
	for bx in boxes:
		var cut0: float = bx[2] + 6 - 14
		var cut1: float = bx[3] + 46 + 14
		var out := []
		for sp in spans:
			if sp[1] < cut0 or sp[0] > cut1:
				out.append(sp)
			else:
				if sp[0] < cut0:
					out.append([sp[0], cut0])
				if sp[1] > cut1:
					out.append([cut1, sp[1]])
		spans = out
	return spans

func fly_plane():
	var VH = g.VH
	for it in 6080:
		if VH.mode != "plane":
			return VH.plane_done
		if VH.phase != "fly":
			frame()
			continue
		var groups := []
		var list := []
		for o in VH.OBS:
			var bx := _obs_box(o)
			if bx.is_empty() or bx[1] < VH.hx - 60 or bx[0] > VH.hx + 900:
				continue
			list.append(bx)
		list.sort_custom(func(a, b): return a[0] < b[0])
		for bx in list:
			if groups.is_empty() or bx[0] > groups.back()[0][0] + 120:
				groups.append([bx])
			else:
				groups.back().append(bx)
		var target: float = VH.hy
		if not groups.is_empty():
			var spans := _free_spans(groups[0], VH.PL.top + 10, VH.PL.low - 10)
			var nxt := []
			if groups.size() > 1:
				nxt = _free_spans(groups[1], VH.PL.top + 10, VH.PL.low - 10)
			var best := 1e9
			for sp in spans:
				# longe das beiradas da faixa livre (o avião não para na hora: sobra margem)
				var m: float = min(18.0, (sp[1] - sp[0]) * .25)
				for k in 9:
					var y: float = lerpf(sp[0] + m, sp[1] - m, k / 8.0)
					var c: float = abs(y - VH.hy)
					if not nxt.is_empty():
						var dn := 1e9
						for sp2 in nxt:
							dn = min(dn, 0.0 if (y >= sp2[0] and y <= sp2[1]) else min(abs(y - sp2[0]), abs(y - sp2[1])))
						c += dn * 2.0
					if c < best:
						best = c
						target = y
		# onde o avião vai parar se soltar agora (freia com .22 por quadro)
		var pred: float = VH.hy + VH.vy * abs(VH.vy) / .44
		var dd := {}
		if pred > target + 5:
			dd["U"] = true
		elif pred < target - 5:
			dd["S"] = true
		frame(dd)
	return "não terminou x=%d" % int(VH.hx)

## bola gigante: corre pulando os obstáculos e se abaixa no buraco do chão
func boulder_run(o: Dictionary):
	var obs: Array = []
	for sb in g.SOL:
		if sb.get("bob") and sb.bob != "barricade":
			obs.append(float(sb.x))
	for pit in g.L.pits:
		if pit[0] > o.x and pit[0] < o.end:
			obs.append(float(pit[0]))
	var niche: float = (o.niche[0] + o.niche[1]) / 2.0
	frame({})
	frame({"R": true})
	frame({})
	var jt := 0
	for it in 1800:
		P = g.player
		if not ok():
			return "state"
		if px() > niche - 70:
			break
		for ox in obs:
			var ahead: float = ox - (px() + P.w / 2)
			if ahead > 20 and ahead < 64 and P.onGround and jt <= 0:
				press("J")
				jt = 14
		jt -= 1
		frame({"R": true, "J": jt > 0})
	# entra no buraco e se abaixa até a bola passar
	for it in 400:
		P = g.player
		if o.get("passed", false) or o.st in ["break", "done"]:
			break
		if px() > o.niche[0] + 14 and px() < o.niche[1] - 14 and P.onGround:
			frame({"S": true})
		else:
			frame({"R" if niche > px() else "L": true})
	hold({}, 30)
	return o.get("passed", false) or "bola: " + o.st

func _initialize() -> void:
	g = load("res://scripts/game.gd").new()
	root.add_child(g)
	g.load_level(0)
	var with_en := OS.get_cmdline_user_args().has("inimigos")
	if not with_en:
		g.no_coal = true
		for e in g.EN:
			e.dead = 99
	P = g.player
	g.rest_reached.connect(func(n):
		rests.append(n)
		print("REST ", n, " T=", g.T)
		g.running = true)
	S("pista 1", walk_to(600))
	S("pistas=%d" % n_clues(), n_clues() == 1)
	S("abaixa sob as toras", crawl(870))
	walk_to(980)
	S("pedra 1 da escada", jump_to(1060))
	S("pedra 2 da escada", jump_to(1170))
	S("alto da escada de pedras", jump_to(1300))
	walk_to(1570)
	S("chega à ponte", walk_to(2065))
	S("lago de veneno 1: ponte da estaca", stake_cross(2040))
	walk_to(2605)
	S("espinhos da manhã", cross_spikes(trap_at("spikes", 2640), 2780))
	S("vai à escada", walk_to(2835))
	S("sobe a escada", climb_to("U", func(): return P.y + P.h <= 228, 400))
	walk_to(2930)
	S("corda", g.INV.has("corda"))
	S("volta à escada", walk_to(2835))
	S("sobe ao telhado", climb_to("U", func(): return P.ladder == null and P.y < 100, 300))
	hold({}, 10)
	S("laranja", spec("laranja"))
	S("desce", climb_to("S", func(): return P.onGround and P.y > 400, 500))
	walk_to(3200)
	S("caixa ★", hop("R", 5))
	S("empurra a caixa", until({"R": true}, func(): return g.M.PUSH[0].x >= 3529 and g.M.PUSH[0].y >= 449, 700))
	S("portão abriu", until({}, func(): return g.M.GATES[0].open > .85, 200))
	S("pula a caixa", jump_to(3670, true))
	S("sai de trás da paliçada", walk_to(3780))
	S("flor-catapulta", jump_to(3850))
	walk_to(3855)
	S("lançado ao galho alto", until({}, func(): return P.onGround and P.y + P.h <= 232 and P.x > 3990, 400))
	S("corre", walk_to(4185))
	press("J")
	hold({"J": true, "R": true}, 16)
	S("agarra cipó", until({"R": true}, func(): return P.vine != null, 80))
	for i in 500:
		P = g.player
		if P.vine == null:
			break
		var v: Dictionary = P.vine
		frame({"R": true} if v.om > 0 else {"L": true})
		if v.th > .35 and v.om > 0:
			break
	press("J")
	frame()
	S("pousa", wait_ground())
	S("desenho 1", g.DRWS.filter(func(d): return d.got).size() == 1)
	S("chão rachado", walk_to(4685))
	slam_here()
	S("mergulho quebrou o chão", g.X.broken.has("chao1"))
	walk_to(4690)
	S("desce a escada do esconderijo", climb_to("S", func(): return P.onGround and P.y > 800, 500))
	hold({}, 60)
	S("entrou na sala", g.player.y > 800)
	S("gancho", walk_to(4920))
	walk_to(4930)
	jr(16, "R")
	S("vermelho", spec("vermelho"))
	S("parede falsa", walk_to(4420))
	S("sala secreta 1", g.X.found.has("s1"))
	S("volta à escada", walk_to(4690))
	S("sobe com ↑", climb_to("U", func(): return P.ladder == null and P.onGround and P.y < 500, 500))
	S("combina corda+gancho", g.try_combine("corda", "gancho") != "")
	S("arena do javali", walk_to(5090))
	S("javali apareceu", g.X.boss_active())
	S("sobe no galho", jump_to(4905, true))
	S("venceu o javali", boss_fight())
	walk_to(5290)
	S("caixa", jump_to(5345))
	S("vai ao barranco", walk_to(5590))
	use()
	S("corda presa", g.LOCKS[0].done)
	S("vai à corda", walk_to(5618))
	S("sobe a corda", climb_to("U", func(): return P.ladder == null and P.y < 100, 500))
	S("rocha rachada", walk_to(5680))
	press("G")
	hold({}, 26)
	S("golpe quebrou a rocha", g.X.broken.has("rock1"))
	S("cachorro amarrado", walk_to(5780))
	use()
	S("Pipoca solto", g.X.dog_free())
	S("portão alto", walk_to(5860))
	hold({}, 20)
	press("D")
	frame()
	S("controla o Pipoca", g.M.ctrl)
	S("Pipoca pela portinhola até a placa", walk_to(5956))
	S("portão abriu", until({}, func(): return g.M.GATES[1].open > .85, 200))
	press("D")
	frame()
	S("de volta ao Tomé", not g.M.ctrl and g.X.DOG.st == "stay")
	S("toca", walk_to(6020))
	use()
	S("Pipoca buscou o desenho", until({}, func(): return g.DRWS[2].got, 700))
	S("moita: pista 2 e amarelo", walk_to(6210))
	S("pistas=2 amarelo", n_clues() == 2 and spec("amarelo"))
	S("desce do platô", walk_to(6420))
	S("lago de veneno 2: ponte da estaca", stake_cross(6480))
	walk_to(6940)
	S("fogueira grande 1", rests.has(1))
	walk_to(7050)
	S("rasteja para a fenda", crawl(7270))
	S("sobe a fenda pulando nas paredes", crevice_climb())
	S("topo da fenda", walk_to(7390))
	walk_to(8340)
	S("galho 1 das copas", jump_to(8490))
	walk_to(8545)
	S("galho 2", jump_to(8700, true))
	walk_to(8745)
	S("galho rachado 1", jump_to(8875))
	S("galho 3", jump_to(9040, true))
	walk_to(9105)
	S("flor das copas", jump_to(9200))
	walk_to(9220)
	S("lançado ao galho alto", until({}, func(): return P.onGround and P.y + P.h <= -250, 400))
	walk_to(9515)
	S("desce ao galho 4", jump_to(9670))
	walk_to(9730)
	S("galho rachado 2", jump_to(9845))
	S("galho 5", jump_to(10010, true))
	S("desce ao chão", walk_to(10140))
	walk_to(10240)
	S("tronco-pêndulo", cross_swing(trap_at("swing", 10450), 10730))
	S("passou o tronco", P.hp == 5)
	walk_to(10730)
	hold({}, 20)
	press("D")
	frame()
	S("Pipoca no portão da tarde", g.M.ctrl)
	S("Pipoca até a placa", walk_to(10910))
	S("portão 4 abriu", until({}, func(): return g.M.GATES[2].open > .85, 200))
	press("D")
	frame()
	S("Tomé passa o portão 4", walk_to(10980))
	walk_to(11025)
	S("sobe a torre", climb_to("U", func(): return P.ladder == null and P.onGround and P.y + P.h <= 64, 500))
	walk_to(11358)
	S("desce a torre", climb_to("S", func(): return P.onGround and P.y > 400, 500))
	walk_to(11450)
	S("caixa no buraco da placa 5", until({"R": true}, func(): return g.M.PUSH[4].x >= 11789 and g.M.PUSH[4].y >= 449, 900))
	S("portão 5 abriu", until({}, func(): return g.M.GATES[3].open > .85, 200))
	S("pula a caixa 5", jump_to(11825))
	S("passa o portão 5", walk_to(12040))
	walk_to(12350)
	walk_to(12420)
	S("armadura", jump_to(12479))
	S("beira da ilha", walk_to(12575))
	S("vitória-régia 1", jump_to(12676))
	S("vr 2", jump_to(12816))
	S("vr 3", jump_to(12946))
	S("tronco molhado", jump_to(13090))
	S("ponta do tronco", walk_to(13200))
	S("ilha 2", jump_to(13330))
	S("lama até o poço", walk_to(13515))
	S("cai no poço", until({"R": true}, func(): return P.ladder != null or P.y > 700, 200))
	S("desce a escada", climb_to("S", func(): return P.onGround and P.y > 800, 400))
	S("gruta", walk_to(13750))
	S("engrenagem e pista 3", g.INV.has("engrenagem") and n_clues() == 3)
	S("pula na água", until({"L": true}, func(): return P.swim, 400))
	S("mergulha", until({"L": true, "S": true}, func(): return px() < 13240 and P.y > 990, 400))
	S("túnel", until({"L": true}, func(): return px() < 13150, 300))
	S("bolsão de ar", until({"U": true}, func(): return P.y < 962, 300))
	press("J")
	hold({"J": true, "L": true}, 14)
	S("borda", wait_ground({"L": true}))
	S("sala secreta 2", g.X.found.has("s2"))
	hold({"R": true}, 30)
	S("volta mergulhando", until({"R": true, "S": true}, func(): return px() > 13190 and P.y > 1000, 400))
	S("sai do túnel", until({"R": true}, func(): return px() > 13380, 400))
	S("sobe", until({"U": true, "R": true}, func(): return P.y < 912, 300))
	press("J")
	hold({"J": true, "R": true}, 16)
	S("fora da água", wait_ground({"R": true}))
	S("fôlego ok", g.lives >= 3)
	walk_to(13750)
	S("volta à escada", walk_to(13550))
	S("sobe", climb_to("U", func(): return P.y + P.h <= 504, 400))
	S("sai do poço", jump_to(13640))
	walk_to(13690)
	S("pula o brejo", jump_to(13840))
	S("gavião-rei apareceu", until({"R": true}, func(): return g.K.HAWK.active, 300))
	S("venceu o gavião-rei", hawk_fight())
	S("ilha 3", walk_to(15090))
	S("fogueira grande 2", rests.has(2))
	S("sobe a rede", climb_to("U", func(): return P.ladder == null and P.y + P.h <= 152, 400))
	S("galho: manivela + verde", walk_to(15220))
	S("manivela_q", g.INV.has("manivela_q") and spec("verde"))
	walk_to(15110)
	S("desce", climb_to("S", func(): return P.onGround and P.y > 400, 500))
	S("combina engrenagem+manivela", g.try_combine("engrenagem", "manivela_q") != "")
	S("comporta", walk_to(15230))
	S("botão vira manivela na comporta", g.use_mode() == "crank")
	for k in 6:
		use()
		hold({}, 6)
	S("escoa", until({}, func(): return g.SWAMP.filter(func(s): return s.get("id") == "canal")[0].y >= 639, 400))
	S("passa a comporta", walk_to(15318))
	S("pedra 1", jump_to(15410))
	S("pedra 2", jump_to(15550))
	walk_to(15580)
	# anda até a beira e solta: cai no vão (segurando → até o fim, ele agarraria a beirada da outra pedra)
	hold({"R": true}, 9)
	S("pedrinha (pista 4)", until({}, func(): return P.onGround and P.y > 520, 100))
	S("pistas=4", n_clues() >= 4)
	S("pedra 3", jump_to(15690))
	S("margem do pântano", jump_to(15780))
	S("abaixado sob a colmeia 2", crawl(15955))
	S("colmeia 2 quieta", trap_at("hive", 15905).st == "idle")
	walk_to(16035)
	S("mergulha", until({"R": true, "S": true}, func(): return px() > 16190 and P.y > 600, 300))
	S("atravessa o túnel d'água", until({"R": true}, func(): return px() > 17360, 1200))
	S("respirou nas bolhas", g.lives >= 3)
	S("sobe", until({"U": true, "R": true}, func(): return P.y < 515, 300))
	S("sai da água", jump_to(17550))
	walk_to(17720)
	S("régia 1", jump_to(17846))
	S("régia 2", jump_to(17996))
	S("régia 3", jump_to(18146))
	S("tronco boiando", jump_to(18310))
	walk_to(18420)
	S("régia 4", jump_to(18566))
	S("régia 5", jump_to(18716))
	S("régia 6", jump_to(18866))
	S("margem do lamaçal", jump_to(18990))
	walk_to(19070)
	S("cipó 1", grab_vine(g.VINES[1]))
	S("cipó 2", vine_hop(g.VINES[2]))
	S("cipó 3", vine_hop(g.VINES[3]))
	S("outra margem", vine_hop(null))
	S("vivo no lamaçal", g.lives >= 3 and px() > 19990)
	walk_to(20430)
	S("cipó da ribanceira", grab_vine(g.VINES[4]))
	S("agarra a corda", _to_bar())
	S("anda pendurado", until({"R": true}, func(): return px() > 21480, 600))
	press("J")
	frame()
	S("solta na margem", wait_ground())
	walk_to(21590)
	S("abaixado sob a colmeia 1", crawl(21705))
	S("colmeia 1 quieta", trap_at("hive", 21655).st == "idle")
	walk_to(21775)
	S("mergulho 2", until({"R": true, "S": true}, func(): return px() > 22040 and P.y > 600, 300))
	S("túnel d'água 2", until({"R": true}, func(): return px() > 23060, 1200))
	S("sobe do mergulho 2", until({"U": true, "R": true}, func(): return P.y < 515, 300))
	S("sai do mergulho 2", jump_to(23230))
	walk_to(23290)
	S("abaixado sob a colmeia 3", crawl(23408))
	S("colmeia 3 quieta", trap_at("hive", 23358).st == "idle")
	S("lago", walk_to(23460))
	for i in 600:
		P = g.player
		if g.NT.helmet and g.NT.harpoon:
			break
		var tx: float = 23840.0 if not g.NT.harpoon else 23720.0
		frame({"R": px() < tx - 4, "L": px() > tx + 4, "S": P.y < 836, "U": P.y > 846})
	S("capacete e arpão", g.NT.helmet and g.NT.harpoon)
	S("bagre-rei apareceu", until({"R": true}, func(): return g.K.FISH.active, 300))
	S("venceu o bagre-rei", fish_fight())
	S("corrente de bolhas", until({"R": true}, func(): return px() > 25150, 600))
	S("subiu na corrente", until({"R": true}, func(): return P.onGround and P.y < 480, 400))
	S("margem do rio", walk_to(25480))
	use()
	S("subiu na jangada", g.VH.mode == "raft")
	S("corredeira", ride_raft())
	S("jangada sem virar", g.VH.tries == 0)
	S("fogueira grande 3", walk_to(32820) and rests.has(3))
	walk_to(33190)
	S("pula a pedra", jump_to(33320, true))
	S("empurra a bola de neve", until({"R": true}, func(): return g.NT.SNOWB[0].x + g.NT.SNOWB[0].w >= 33687, 900))
	S("bola cresceu", g.NT.SNOWB[0].w > 75)
	S("sobe na bola", jump_to(33610))
	S("paredão", jump_to(33750, true))
	S("gelo", walk_to(34340))
	walk_to(34510)
	S("bola rolando 1", dodge_roll(34770, 0))
	S("bola rolando 2", dodge_roll(35290, 1))
	walk_to(35720)
	S("pula o buraco de gelo", jump_to(36005, true))
	S("pedra da bola 2", jump_to(36115))
	walk_to(36118)
	S("empurra a bola 3", until({"R": true}, func(): return g.NT.SNOWB[2].x + g.NT.SNOWB[2].w >= 36247, 900))
	S("sobe na bola 3", jump_to(36220))
	S("2º paredão", jump_to(36290, true))
	walk_to(36385)
	S("vila", walk_to(37040))
	walk_to(37240)
	S("desce na caverna de gelo", climb_to("S", func(): return P.onGround and P.y > 800, 500))
	walk_to(37650)
	S("bloco de gelo 1", jump_to(37730))
	S("desce do bloco 1", jump_to(37860))
	walk_to(38070)
	S("bloco de gelo 2", jump_to(38150))
	S("desce do bloco 2", jump_to(38280))
	walk_to(38750)
	S("sobe da caverna", climb_to("U", func(): return P.ladder == null and P.onGround and P.y < 480, 500))
	walk_to(38900)
	walk_to(39090)
	S("carroça", jump_to(39245))
	S("empurra a bola 2", until({"R": true}, func(): return g.NT.HOLES[0].filled, 900))
	S("cavalo", walk_to(39900))
	use()
	S("cavalgada começou", until({}, func(): return g.RD.riding, 400))
	S("cavalgada", ride())
	S("sem tropeço", g.RD.tries == 0)
	S("toca do urso", walk_to(50400))
	S("urso acordou", g.K.BEAR.st != "wait")
	S("Urso-Rei: fuga pela fresta e coroa", bear_fight())
	S("urso desistiu", until({}, func(): return g.K.BEAR.done, 600))
	S("coroa do urso na coleção", root.get_node("Save").getv("gallery", "crown_urso", false))
	# o trenó parte sozinho quando o Tomé chega nele
	S("chega no trenó e parte sozinho", until({"R": true}, func(): return g.VH.mode == "sled", 600))
	S("trenó chegou", sled_drive())
	S("fogueira grande 4", walk_to(53090) and rests.has(4))
	S("subida da montanha", climb_gusts(55630))
	S("ponte de cordas", bridge_run(trap_at("bridge", 55660)))
	S("pista do avião: embarca sozinho", until({"R": true}, func(): return g.VH.mode == "plane", 1500))
	S("decolou", g.VH.mode == "plane")
	S("voo", fly_plane())
	S("avião sem rodopiar", g.VH.tries == 0)
	S("fogueira grande 5", walk_to(64280) and rests.has(5))
	S("margem", walk_to(64470))
	var axe: Dictionary = g.TR.by_kind("axe")[0]
	walk_to(64460)
	# pula a lâmina quando ela está indo para o lado de lá
	S("espera o machado", until({}, func(): g.TR.axe_blade(axe); return axe.ang > .35, 300))
	S("pula a lâmina do machado", jump_to(64800, true))
	S("noite", walk_to(64725))
	S("espaço depois do machado", walk_to(64910))
	S("caixa", jump_to(64975))
	if px() < 65000:
		jump_to(65040, true)
	walk_to(65245)
	S("cogumelo saltador 1", bounce_to(65295))
	S("chapéu alto", P.y + P.h <= 232)
	S("cogumelo saltador 2 (gigante laranja)", bounce_to(65755))
	S("chapéu mais alto", P.y + P.h <= 152)
	S("desce de chapéu", jump_to(66265))
	S("fim do bosque", jump_to(66450))
	S("lago de veneno 3: ponte da estaca", stake_cross(67100))
	walk_to(67760)
	S("desce no poço da mina", climb_to("S", func(): return P.onGround and P.y > 820, 500))
	walk_to(67825)
	S("espinhos do poço", cross_spikes(trap_at("spikes", 67850), 67980))
	S("viga do poço", crawl(68120))
	walk_to(68270)
	S("carrinho do poço", jump_to(68460))
	walk_to(68675)
	S("tábua do poço 1", jump_to(68740))
	S("tábua do poço 2", jump_to(68825))
	S("depois das tábuas", jump_to(68920))
	walk_to(69600)
	S("viga 2 do poço", crawl(69750))
	walk_to(69970)
	S("sobe do poço", climb_to("U", func(): return P.ladder == null and P.onGround and P.y < 480, 500))
	walk_to(70120)
	S("porta do galpão", walk_to(70370))
	hold({}, 20)
	press("D")
	frame()
	S("Pipoca", g.M.ctrl)
	S("Pipoca entra pela portinhola", walk_to(70600))
	S("óleo", g.INV.has("oleo"))
	S("Pipoca sai", walk_to(70370))
	press("D")
	frame()
	S("Tomé", not g.M.ctrl)
	S("telhado do galpão", jump_to(70445, true))
	S("desce do telhado", walk_to(70740))
	S("escada da coruja", walk_to(71005))
	S("sobe", climb_to("U", func(): return P.ladder == null and P.onGround and P.y + P.h <= 42, 500))
	S("pavio", walk_to(71040))
	S("azul", walk_to(70910))
	S("pavio+azul", g.INV.has("pavio") and spec("azul"))
	walk_to(71005)
	S("desce", climb_to("S", func(): return P.onGround and P.y > 400, 600))
	S("combina óleo+pavio", g.try_combine("oleo", "pavio") != "")
	S("laje do X", walk_to(70810))
	use()
	S("quebrou a laje", g.X.broken.has("slab"))
	S("desce na câmara", climb_to("S", func(): return P.onGround and P.y > 800, 500))
	var rg = walk_to(70498)
	S("lápis dourado %s" % str(rg), g.X.GOLD.got)
	walk_to(70885)
	S("plataforma 1", jump_to(70895) is bool and P.y + P.h < 850)
	S("pl. 2", jump_to(70960) is bool and P.y + P.h < 795)
	S("pl. 3", jump_to(70888) is bool and P.y + P.h < 740)
	S("sala secreta 3", g.X.found.has("s3"))
	S("desce", until({"L": true}, func(): return P.onGround and P.y > 850, 300))
	S("escada da laje", walk_to(70810))
	S("sobe", climb_to("U", func(): return P.ladder == null and P.onGround and P.y < 480, 500))
	walk_to(71005)
	S("rede de caçador", walk_to(71070))
	press("D")
	frame()
	S("Pipoca (rede)", g.M.ctrl)
	S("Pipoca no poste", walk_to(71065))
	press("A")
	hold({}, 8)
	S("rede caiu", g.TR.by_kind("net")[0].st == "down")
	press("D")
	frame()
	S("Tomé de novo", not g.M.ctrl)
	S("jaula prendeu", until({"R": true}, func(): return g.TR.trapped != null, 300))
	hold({}, 30)
	press("D")
	frame()
	S("Pipoca (jaula)", g.M.ctrl)
	S("Pipoca no poste da jaula", walk_to(71162))
	press("A")
	hold({}, 8)
	S("jaula abriu", g.TR.trapped == null)
	press("D")
	frame()
	S("Tomé livre", not g.M.ctrl)
	S("cogumelo", until({"R": true}, func(): return P.vy < -15, 300))
	var dj := false
	for i in 200:
		P = g.player
		if not dj and P.vy > -1:
			press("J")
			dj = true
		frame({"R": px() < 71370, "J": dj and i < 60})
		P = g.player
		if dj and P.onGround:
			break
	S("quica + pulo duplo", g.player.y < 130)
	S("desenho 2", walk_to(71440))
	walk_to(71540)
	S("desce do galho", until({}, func(): return P.onGround and P.y > 400, 200))
	S("entrada do túnel", walk_to(71550))
	use()
	S("barreira aberta", g.LOCKS[2].done)
	walk_to(71725)
	use()
	walk_to(71785)
	use()
	S("portão das alavancas", until({}, func(): return g.EV.GATE.lift >= g.EV.GATE.h - 8, 200))
	S("passa o portão (sem abaixar)", walk_to(72105))
	S("tábua podre", jump_to(72210))
	S("depois da tábua", jump_to(72360))
	walk_to(72400)
	S("carrinho do túnel", jump_to(72600))
	walk_to(72735)
	S("tábuas 1", jump_to(72810))
	S("tábuas 2", jump_to(72900))
	S("fim das tábuas", jump_to(73000))
	walk_to(73040)
	S("viga 2 do túnel", crawl(73190))
	S("chega na manivela", walk_to(73260))
	for k in 6:
		use()
		hold({}, 6)
	S("porta da manivela abriu", g.CRANKS[0].done)
	S("túnel da pedra", walk_to(73650))
	var bol: Dictionary = trap_at("boulder", 73500)
	S("a pedra caiu", until({"R": true}, func(): return bol.st != "idle", 200))
	S("fuga da pedra", boulder_run(bol))
	S("sem ser atropelado", P.hp == 5)
	until({"S": true}, func(): return bol.st in ["break", "done"], 600)
	S("sai do buraco", jump_to(77140))
	S("túnel", walk_to(77590))
	S("rasteja", crawl(77750))
	S("escada do nicho", walk_to(77950))
	S("desce", climb_to("S", func(): return P.onGround and P.y > 700, 500))
	S("roxo no nicho", walk_to(77760) and spec("roxo"))
	walk_to(77980)
	S("rasteja divisória", crawl(78045))
	S("pistas=6 (crachá)", n_clues() == 6)
	S("vilão ainda não", not g.VIL.go)
	walk_to(78080)
	S("sobe pela saída", climb_to("U", func(): return P.ladder == null and P.onGround and P.y < 480, 500))
	S("vilão foge", walk_to(78300))
	S("perseguição começou", g.VIL.go)
	walk_to(78630)
	S("1º buraco", jump_to(78800))
	walk_to(78920)
	S("desliza sob a viga", crawl(79050))
	walk_to(79285)
	S("2º buraco", jump_to(79490, true))
	walk_to(79550)
	S("pula o carrinho parado", jump_to(79700, true))
	walk_to(79770)
	S("tábua 1", jump_to(79860))
	S("tábua 2", jump_to(79990))
	S("tábua 3", jump_to(80120))
	S("chão", jump_to(80230))
	walk_to(80370)
	S("viga 2", crawl(80500))
	S("vilão entrou na mina", until({"R": true}, func(): return g.VIL.gone or px() > 80800, 900))
	S("vilão entrou", until({}, func(): return g.VIL.gone, 400))
	walk_to(80915)
	var sa = until({}, func(): return not g.running, 300)
	S("saída", sa is String and sa == "state")
	var nd: int = g.DRWS.filter(func(d): return d.got).size()
	S("segredos %d/3 dourado=%s chefe=%s" % [g.X.found.size(), str(g.X.GOLD.got), str(g.X.BOSS.done)], g.X.found.size() == 3 and g.X.GOLD.got and g.X.BOSS.done)
	print("FIM T=", g.T)
	S("final: pistas=%d esp=%d des=%d lápis=%d/%d tempo=%ds" % [n_clues(), g.SPECGOT.size(), nd, g.STATS.pen, g.STATS.penTotal, g.time_left / 60], n_clues() == 6 and g.SPECGOT.size() == 6 and nd == 3)
	for l in log_lines:
		print(l)
	print("FALHAS: %d" % fails)
	quit(1 if fails > 0 else 0)
