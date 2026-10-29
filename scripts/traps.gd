extends RefCounted
class_name Traps
## Saltos em cadeia e armadilhas (no espírito do Oddmar):
##  bounce  cogumelo saltador: lança o Tomé na direção do próximo (trajetória calculada para acertar)
##  flower  flor-catapulta: fique em cima, ela encolhe e dispara em arco até o alvo
##  wind    corrente de vento: levanta quem plana por cima dela
##  spikes  espinhos que sobem e descem no ritmo
##  roll    pedra rolando atrás do Tomé (dispara ao passar pelo gatilho)
##  axe     machado-pêndulo
##  snap    galho que estala e cai pouco depois de pisar
##  cage    jaula de caçador: prende o Tomé; o Pipoca solta mordendo a corda
##  net     rede de caçador fechando a passagem; o Pipoca rói a corda
##  icicle  pingente de gelo no teto: treme quando o Tomé chega perto e cai; volta a crescer depois
##  swing   tronco pendurado por duas cordas balançando no caminho
##  hive    colmeia: encostou ou bateu, o enxame persegue até a água ou longe dali
##  sand    areia movediça: parado afunda; atravessa pulando
##  web     teia de aranha gigante: deixa lento; a picareta corta
##  gust    rajadas de vento no alto da montanha (empurram para trás; abaixado aguenta)
##  bridge  ponte de cordas que se solta tábua por tábua atrás do Tomé
##  boulder bola de pedra gigante no túnel: corra, pule os obstáculos e se abaixe no nicho
##  giant   cogumelo gigante (o chapéu é uma plataforma)
## e a picareta arremessada (↑ + GOLPE), que fica cravada na parede e vira degrau.

var g  # Game
var T: Array = []
var PICK := {}               # picareta arremessada
var trapped = null           # jaula que prendeu o Tomé
var bounce_note := 0
## armadilhas que continuam andando longe do Tomé (rolando, caindo, desabando) e os estados parados
const FAR_RUN := {"roll": 1, "boulder": 1, "bridge": 1, "cage": 1, "net": 1}
const FAR_STILL := {"idle": 1, "done": 1, "used": 1}

func _init(game) -> void:
	g = game

func load_level() -> void:
	T = []
	PICK = {}
	trapped = null
	for d in g.L.get("traps", []):
		var o: Dictionary = d.duplicate(true)
		o.t = 0
		o.st = "idle"
		o._cx = float(o.x) + float(o.get("w", 0)) / 2.0
		match o.k:
			"snap":
				o.sol = {"t": "snapb", "x": o.x, "y": o.y, "w": o.w, "h": 16, "oneway": 1, "snap": 1}
				o.ct = 0
				o.fy = 0.0
				g.SOL.append(o.sol)
			"net":
				o.sol = {"t": "net", "x": o.x, "y": o.y, "w": 18, "h": o.h}
				g.SOL.append(o.sol)
			"roll":
				o.bx = float(o.x)
				o.vx = 0.0
				o.rot = 0.0
			"flower":
				o.pad = 0.0
				o.sol = {"t": "flowerpad", "x": o.x - 26, "y": o.y - 18, "w": 52, "h": 10, "oneway": 1}
				g.SOL.append(o.sol)
			"cage":
				o.dy = 0.0
			"icicle":
				o.fy = 0.0
				o.vy = 0.0
				o.grow = 1.0
			"hive":
				o.sx = float(o.x)
				o.sy = float(o.y) - 20.0
				o.cool = 0
			"web":
				o.cut = false
			"bridge":
				_bridge_build(o)
			"boulder":
				o.bx = float(o.x)
				o.by = float(o.y) - o.r
				o.vx = 0.0
				o.vy = 0.0
				o.rot = 0.0
				o.smashed = {}
			"giant":
				o.sol = {"t": "cap", "x": o.x - o.w / 2.0, "y": o.cap, "w": o.w, "h": 16, "oneway": 1}
				g.SOL.append(o.sol)
		T.append(o)

func by_kind(k: String) -> Array:
	return T.filter(func(o): return o.k == k)

# ======================================================================
#  ANTES DA FÍSICA
# ======================================================================
func pre() -> void:
	var p: Dictionary = g.player
	if trapped != null and not p.get("dog"):
		# preso na jaula: não anda nem pula (dá para trocar para o Pipoca)
		for k in ["L", "R", "J", "P", "S", "U"]:
			g.keys[k] = false
		g.keys.Jp = false
		p.vx = 0.0
		p.run = 0
	if p.get("launchT", 0) > 0:
		p.launchT -= 1
	_pick_step()

## ↑ + GOLPE: arremessa a picareta
func want_throw() -> bool:
	var p: Dictionary = g.player
	return g.kd("U") and not p.get("dog") and PICK.is_empty() and not p.ladder and not p.vine and not p.swim and not p.crouch

func throw_pick() -> void:
	var p: Dictionary = g.player
	PICK = {"x": p.x + p.w / 2 + p.face * 14, "y": p.y + 10, "vx": p.face * 10.5, "vy": -1.6, "dir": p.face, "st": "fly", "t": 0, "rot": 0.0, "dist": 0.0}
	p.act = "throw1"
	p.actT = 14
	Audio.play("slide", -4)
	g.tip("O bastão crava em paredes e colunas. GOLPE de novo: ele volta.")

func pick_out() -> bool:
	return not PICK.is_empty()

func recall_pick() -> void:
	if PICK.is_empty():
		return
	_unpeg()
	PICK.st = "back"

func _unpeg() -> void:
	if PICK.has("peg"):
		g.SOL.erase(PICK.peg)
		PICK.erase("peg")

func _pick_step() -> void:
	if PICK.is_empty():
		return
	var k: Dictionary = PICK
	k.t += 1
	match k.st:
		"fly":
			k.vy += .14
			var nx: float = k.x + k.vx
			var ny: float = k.y + k.vy
			k.rot += .5 * k.dir
			k.dist += abs(k.vx)
			# acerta inimigos no caminho
			for e in g.EN:
				if not e.dead and Game.hit(g.R(nx - 10, ny - 10, 20, 20), g.ebox(e)):
					g.kill_enemy(e, "hit")
			var cands: Array = g.SOL.duplicate()
			for s2 in g.L.solids:
				if s2.get("deco") and s2.t in ["trunk", "deadtree"]:
					cands.append(s2)
			for s in cands:
				if s.get("oneway") or (s.get("deco") and not s.t in ["trunk", "deadtree"]) or s.get("boat") or s.get("fallen") or s.get("open", 0.0) > .85:
					continue
				if s.get("ghost") and not s.get("on"):
					continue
				if nx > s.x and nx < s.x + s.w and ny > s.y and ny < s.y + s.h:
					# cravou: o cabo fica para fora da parede e vira degrau
					var face_x: float = s.x if k.dir > 0 else s.x + s.w
					k.x = face_x
					k.y = clamp(ny, s.y + 8, s.y + s.h - 4)
					k.st = "stuck"
					k.t = 0
					k.peg = {"t": "peg", "x": face_x - (34 if k.dir > 0 else 0), "y": k.y - 4, "w": 34, "h": 8, "oneway": 1, "peg": 1}
					g.SOL.append(k.peg)
					g.shake = max(g.shake, 3)
					Audio.play("unlock", -6)
					g.burst(face_x, k.y, 8, Color("#d9c290"))
					return
			k.x = nx
			k.y = ny
			if k.dist > 300 or k.y > g.L.bottom:
				k.st = "back"
		"stuck":
			if k.t > 480:
				recall_pick()
		"back":
			var p: Dictionary = g.player
			var to := Vector2(p.x + p.w / 2, p.y + 14)
			var d: Vector2 = to - Vector2(k.x, k.y)
			k.rot -= .45 * k.dir
			if d.length() < 18:
				PICK = {}
				Audio.play("item", -12)
				return
			var v: Vector2 = d.normalized() * min(14.0, 4.0 + k.t * .4)
			k.x += v.x
			k.y += v.y

# ======================================================================
#  DEPOIS DA FÍSICA
# ======================================================================
func post() -> void:
	var p: Dictionary = g.player
	if p.dyingT > 0:
		return
	var pcx: float = p.x + p.w / 2
	var feet: float = p.y + p.h
	for o in T:
		# longe do Tomé e sem nada acontecendo: pula (a fase tem muitas armadilhas)
		# (o centro de cada armadilha é guardado na carga; antes cada teste criava listas novas)
		if abs(float(o._cx) - pcx) > 1800 and (not FAR_RUN.has(o.k) or FAR_STILL.has(o.st) or (o.k == "bridge" and o.st == "gone" and o.t > 300)) and not (o.k == "hive" and o.st != "idle"):
			continue
		o.t += 1
		match o.k:
			"bounce":
				if o.get("cool", 0) > 0:
					o.cool -= 1
				o.squash = max(0.0, o.get("squash", 0.0) - .08)
				var top: float = o.y - 30
				if p.vy >= 0 and not p.vine and not p.ladder and o.get("cool", 0) == 0 and abs(pcx - o.x) < 30 and feet >= top - 2 and feet <= top + 26:
					_launch_from(o, top)
			"giant":
				# cogumelo gigante saltador (laranja, com mola): pisou no chapéu, lança para o próximo
				if o.has("to"):
					if o.get("cool", 0) > 0:
						o.cool -= 1
					o.squash = max(0.0, o.get("squash", 0.0) - .06)
					var hw: float = o.w * .5 - 6
					if p.vy >= 0 and not p.vine and not p.ladder and o.get("cool", 0) == 0 and abs(pcx - o.x) < hw and feet >= o.cap - 4 and feet <= o.cap + 18:
						_launch_from(o, float(o.cap))
						o.cool = 24
			"flower":
				_flower(o, p, pcx, feet)
			"wind":
				if pcx > o.x and pcx < o.x + o.w and p.y + p.h > o.y and p.y < o.y + o.h and not p.vine and not p.ladder:
					if p.puff:
						p.vy = max(p.vy - o.pow, -6.5)
					elif not p.onGround:
						p.vy -= o.pow * .3
			"spikes":
				var h := spike_h(o)
				if h > 8 and p.iframe == 0 and pcx > o.x - 4 and pcx < o.x + o.w + 4 and feet > o.y - h and p.y < o.y:
					g.hurt(1, pcx - p.face * 10)
					p.vy = -8
			"roll":
				_roll(o, p, pcx)
			"icicle":
				_icicle(o, p, pcx)
			"axe":
				var b := axe_blade(o)
				if p.iframe == 0 and axe_hits(o, p):
					g.hurt(1, b.x)
			"snap":
				_snap(o, p)
			"cage":
				_cage(o, p, pcx)
			"net":
				if o.st == "down":
					o.fy = o.get("fy", 0.0) + 7.0
			"swing":
				var e := swing_end(o)
				var pe: Vector2 = o.get("pe", e)
				o.pe = e
				# a área de dano é o tronco desenhado, varrendo do quadro anterior até o atual
				var hb: Dictionary = g.R(min(e.x, pe.x) - 46, min(e.y, pe.y) - 13, abs(e.x - pe.x) + 92, abs(e.y - pe.y) + 26)
				if p.iframe == 0 and Game.hit(p, hb):
					g.hurt(1, e.x - swing_dir(o) * 60.0)
			"hive":
				_hive(o, p, pcx)
			"sand":
				_sand(o, p, pcx, feet)
			"web":
				if not o.cut and not p.get("dog") and Game.hit(p, g.R(o.x + 6, o.y, o.w - 12, o.h)):
					if p.get("webT", 0) == 0:
						Audio.play("climb", -6)
						g.tip("Fita adesiva! Ela te deixa lento. GOLPE com o bastão corta a fita.")
					p.webT = 40
			"gust":
				_gust(o, p, pcx)
			"bridge":
				_bridge(o, p)
			"boulder":
				_boulder(o, p, pcx)
	if p.get("webT", 0) > 0:
		p.webT -= 1
		p.vx *= .45
		if p.vy < -6.0:
			p.vy = -6.0

func _launch_from(o: Dictionary, top: float) -> void:
	var p: Dictionary = g.player
	var tx: float
	var ty: float
	var to = o.get("to")
	if to is float or to is int:
		var nxt: Dictionary = T[int(to)]
		tx = nxt.x
		ty = nxt.y - 30
	elif to is Array:
		tx = float(to[0])
		ty = float(to[1])
	else:
		tx = o.x + sin(deg_to_rad(o.get("ang", 0.0))) * 200
		ty = top - 260
	var v := ballistic(Vector2(o.x, top), Vector2(tx, ty), o.get("arc", 1.0))
	p.y = top - p.h
	p.x = o.x - p.w / 2
	p.vx = v.x
	p.vy = v.y
	p.launchT = int(v.z)
	p.onGround = false
	p.airJumps = 0 if (p.get("dog") or p.get("isis")) else 1
	p.cutOk = false
	p.coyote = 0
	p.jbuf = 0
	p.slam = false
	p.puff = false
	p.run = 0
	p.face = 1 if v.x >= 0 else -1
	o.cool = 10
	o.squash = 1.0
	Audio.play("spring")
	Audio.vib(15)
	g.burst(o.x, top, 12, Color(1, .6, .7) if o.get("c", "") == "rosa" else Color("#ffd27a"))
	if bounce_note < 1:
		bounce_note = 1
		g.tip("Cogumelo saltador! Ele te lança direto para o próximo.")

## velocidade inicial para ir de a até b em um arco (mesma física do jogo: gravidade a cada quadro)
## devolve (vx, vy, quadros)
func ballistic(a: Vector2, b: Vector2, arc: float = 1.0) -> Vector3:
	var dx: float = b.x - a.x
	var dy: float = b.y - a.y
	var n: float = clamp(abs(dx) / 4.4, 30.0, 72.0) * arc
	# sobe pelo menos o bastante para passar por cima do alvo
	var up_needed: float = max(0.0, -dy) + 60.0
	var n_min: float = sqrt(2.0 * up_needed / Game.GRAV) * 1.15
	n = max(n, n_min)
	var vy: float = (dy - Game.GRAV * n * (n + 1) / 2.0) / n
	return Vector3(dx / n, vy, n)

func _flower(o: Dictionary, p: Dictionary, pcx: float, feet: float) -> void:
	var on: bool = p.onGround and p._g == o.get("sol") and not p.get("dog")
	match o.st:
		"idle":
			o.pad = 0.0
			if on:
				o.st = "load"
				o.t = 0
				Audio.play("climb", -6)
		"load":
			o.pad = min(1.0, o.t / 34.0)
			if not on:
				o.st = "idle"
			elif o.t >= 36:
				o.st = "fire"
				o.t = 0
				var tg: Array = o.to
				var v := ballistic(Vector2(o.x, o.y - 18), Vector2(float(tg[0]), float(tg[1])), o.get("arc", 1.0))
				p.vx = v.x
				p.vy = v.y
				p.launchT = int(v.z)
				p.onGround = false
				p.y -= 2
				p.airJumps = 1
				p.cutOk = false
				p.face = 1 if v.x >= 0 else -1
				Audio.play("spring")
				g.burst(o.x, o.y - 30, 16, Color("#ffb3d1"))
				g.shake = max(g.shake, 3)
		"fire":
			o.pad = max(-0.6, 1.0 - o.t / 4.0) if o.t < 10 else lerpf(o.get("pad", 0.0), 0.0, .2)
			if o.t > 50:
				o.st = "idle"
	# a plataforma da flor (para pisar)
	o.sol.y = o.y - 18 + o.get("pad", 0.0) * 12

func spike_h(o: Dictionary) -> float:
	var per: int = o.get("per", 140)
	var u: int = (g.T + int(o.get("ph", 0))) % per
	var up: int = per / 2
	if u < 8:
		return u / 8.0 * 26.0
	if u < up:
		return 26.0
	if u < up + 8:
		return (1.0 - (u - up) / 8.0) * 26.0
	return 0.0

## aviso: tremidinha antes de subir
func spike_warn(o: Dictionary) -> bool:
	var per: int = o.get("per", 140)
	var u: int = (g.T + int(o.get("ph", 0))) % per
	return u > per - 22

## pontos da lâmina em meia-lua (contorno de fora e de dentro) e do cabo, no mundo
func axe_points(o: Dictionary, a: float) -> PackedVector2Array:
	var bp := Vector2(o.x + sin(a) * o.len, o.y + cos(a) * o.len)
	var out := PackedVector2Array()
	for i in 9:
		var t: float = -1.2 + 2.4 * i / 8.0
		out.push_back(bp + Vector2(sin(t) * 30, cos(t) * 16 + 4).rotated(-a))
		out.push_back(bp + Vector2(sin(t) * 22, cos(t) * 8).rotated(-a))
	# a haste e a forca não machucam: só a lâmina
	return out

## o machado acerta se qualquer ponto da lâmina (agora ou no meio do caminho desde o quadro
## anterior) estiver dentro do Tomé
func axe_hits(o: Dictionary, p: Dictionary) -> bool:
	var a1: float = o.get("ang", 0.0)
	var a0: float = o.get("pang", a1)
	o.pang = a1
	var box := Rect2(p.x - 2, p.y - 2, p.w + 4, p.h + 4)
	for a in [a1, (a0 + a1) * .5]:
		for q in axe_points(o, a):
			if box.has_point(q):
				return true
	return false

func axe_blade(o: Dictionary) -> Vector2:
	var a: float = o.amp * sin(TAU * (g.T + o.get("ph", 0)) / float(o.per))
	o.ang = a
	return Vector2(o.x + sin(a) * o.len, o.y + cos(a) * o.len)

func _roll(o: Dictionary, p: Dictionary, pcx: float) -> void:
	var R: float = o.get("r", 40.0)
	match o.st:
		"idle":
			if not p.get("dog") and pcx > o.trig and pcx < o.trig + 300 and abs(p.y + p.h - o.y) < 120:
				o.st = "go"
				o.bx = float(o.x)
				o.vx = 0.0
				Audio.play("stomp", -2)
				g.shake = max(g.shake, 8)
				g.flash_tut("CORRA!", "CORRA! (toque duas vezes → para correr)", 140)
		"go":
			o.vx = move_toward(o.vx, o.vmax * o.dir, .09)
			o.bx += o.vx
			o.rot += o.vx / R
			if g.T % 6 == 0:
				g.fx("fx_dust", o.bx - o.dir * R * .6, o.y - 8, 16, .14, -.3)
				g.shake = max(g.shake, 2.5)
			if Vector2(pcx, p.y + p.h / 2).distance_to(Vector2(o.bx, o.y - R)) < R + 14 and p.iframe == 0:
				g.hurt(1, o.bx)
				p.vx = o.dir * 7
			if (o.bx - o.end) * o.dir >= 0:
				o.st = "fall"
				o.t = 0
				o.vy = 0.0
				Audio.play("stomp")
				g.shake = max(g.shake, 10)
		"fall":
			o.vy = o.get("vy", 0.0) + .6
			o.fy = o.get("fy", 0.0) + o.vy
			o.bx += o.vx * .6
			if o.t == 20:
				g.fx("fx_pieces", o.bx, o.y + 40, 24, .5, -.4)
				Audio.play("stomp", -4)
			if o.t > 60:
				o.st = "done"

## pingente de gelo: treme ~0,7 s quando o Tomé passa embaixo, despenca e se quebra no chão
func _icicle(o: Dictionary, p: Dictionary, pcx: float) -> void:
	var ln: float = o.get("len", 46)
	match o.st:
		"idle":
			o.grow = min(1.0, o.grow + .02)
			if o.grow >= 1.0 and abs(pcx - o.x) < o.get("reach", 70) and p.y > o.y and p.y < o.get("floor", o.y + 300) and not p.get("dog"):
				o.st = "shake"
				o.t = 0
				Audio.play("climb", -4)
		"shake":
			if o.t % 8 == 0:
				g.PARTS.append({"x": o.x + randf_range(-6, 6), "y": o.y + 4, "vx": 0.0, "vy": 1.0, "life": 20, "col": Color(.85, .95, 1, .9)})
			if o.t > 60:
				o.st = "fall"
				o.t = 0
				o.vy = 0.0
				o.fy = 0.0
		"fall":
			o.vy = min(o.vy + .7, 14.0)
			o.fy += o.vy
			var tip: float = o.y + o.fy + ln
			if p.dyingT == 0 and abs(pcx - o.x) < 16 and tip > p.y + 4 and o.y + o.fy < p.y + p.h:
				g.hurt(1, o.x)
				_shatter(o)
			elif tip >= o.get("floor", o.y + 300):
				_shatter(o)
			else:
				# pingente derrubado pelo mergulho acerta o bicho que estiver embaixo
				for e in g.EN:
					if not e.dead and abs(e.x - o.x) < 22 and tip > e.y - 30 and o.y + o.fy < e.y:
						g.kill_enemy(e, "stomp")
						_shatter(o)
						break
		"broken":
			if o.t > 150:
				o.st = "idle"
				o.grow = 0.0
				o.fy = 0.0

func _shatter(o: Dictionary) -> void:
	o.st = "broken"
	o.t = 0
	var by: float = min(o.y + o.fy + o.get("len", 46), o.get("floor", o.y + 300))
	g.burst(o.x, by, 14, Color(.85, .95, 1))
	g.fx("fx_pieces", o.x, by - 6, 14, .25, -.3)
	Audio.play("stomp", -10)

func _snap(o: Dictionary, p: Dictionary) -> void:
	match o.st:
		"idle":
			o.pop = min(1.0, float(o.get("pop", 1.0)) + .04)
			if p._g == o.sol:
				o.st = "crack"
				o.ct = 0
				Audio.play("climb", -2)
		"crack":
			o.ct += 1
			if o.ct % 6 == 0:
				g.burst(o.x + randf() * o.w, o.y + 6, 3, Color("#8a6a42"))
			if o.ct >= o.get("time", 20):
				o.st = "fall"
				o.sol.fallen = true
				o.fy = 0.0
				o.vy = 0.0
				Audio.play("stomp", -6)
				g.burst(o.x + o.w / 2, o.y + 6, 14, Color("#8a6a42"))
		"fall":
			o.vy = o.get("vy", 0.0) + .55
			o.fy += o.vy
			o.ct += 1
			if o.ct > 320 and abs(p.x - o.x) > 300:
				_snap_reset(o)

## galho novo no lugar (brota aos poucos: o desenho usa o.pop)
func _snap_reset(o: Dictionary) -> void:
	o.st = "idle"
	o.sol.erase("fallen")
	o.fy = 0.0
	o.vy = 0.0
	o.ct = 0
	o.pop = 0.0

func _cage(o: Dictionary, p: Dictionary, pcx: float) -> void:
	var w: float = o.get("w", 64)
	match o.st:
		"idle":
			o.dy = -170.0
			if not p.get("dog") and p.onGround and pcx > o.x + 10 and pcx < o.x + w - 10 and abs(p.y + p.h - o.y) < 8:
				o.st = "drop"
				o.t = 0
				Audio.play("slide")
		"drop":
			o.dy = min(0.0, o.dy + 4.0 + o.t * 1.4)
			if o.dy >= 0.0:
				o.st = "shut"
				o.hits = 0
				trapped = o
				g.shake = max(g.shake, 8)
				Audio.play("stomp")
				g.burst(o.x + w / 2, o.y - 4, 16, Color("#b7a77f"))
				if g.X.dog_free():
					g.flash_tut("Preso numa jaula de caçador!", "Preso na jaula! Use a BAG: solte a corda do poste (✦).", 300)
				else:
					g.flash("Preso! Bata com o bastão nas grades para quebrar.", 300)
		"shut":
			var b = g.M.tome if g.M.ctrl else p
			b.x = clamp(b.x, o.x + 6, o.x + w - 6 - b.w)
		"open":
			o.dy = max(-170.0, o.dy - 5.0)
			if o.dy <= -170:
				o.st = "used"

## Pipoca rói a corda (✦ perto do poste)
func dog_bite(d: Dictionary) -> bool:
	var dcx: float = d.x + d.w / 2
	for o in T:
		if not o.k in ["cage", "net"] or not o.has("post"):
			continue
		var ok: bool = (o.k == "cage" and o.st == "shut") or (o.k == "net" and o.st == "idle")
		if ok and abs(dcx - float(o.post[0])) < 46 and abs(d.y + d.h - float(o.post[1])) < 50:
			Audio.play("bark", -4)
			g.burst(float(o.post[0]), float(o.post[1]) - 30, 12, Color("#c9b48a"))
			if o.k == "cage":
				o.st = "open"
				trapped = null
				g.flash("A jaula subiu! Volte para o Milis.", 200)
			else:
				o.st = "down"
				g.SOL.erase(o.sol)
				g.flash("A Bag soltou a corda: a rede caiu!", 180)
			return true
	return false

## a picareta nas grades (sem o Pipoca por perto)
func swing_hits(hb: Dictionary) -> void:
	# (a janela do golpe dura vários passos: cada picaretada conta uma vez só nas grades)
	if trapped != null and not g.M.swing_hit.has("cage"):
		g.M.swing_hit["cage"] = 1
		var o: Dictionary = trapped
		o.hits = o.get("hits", 0) + 1
		Audio.play("unlock", -8)
		g.burst(o.x + o.get("w", 64) / 2, o.y - 30, 6, Color("#c8d0dc"))
		if o.hits >= 6:
			o.st = "open"
			trapped = null
			g.note("As grades cederam!")
	for o in T:
		if o.k == "net" and o.st == "idle" and Game.hit(hb, o.sol):
			g.tip("A rede é grossa demais para o bastão. O zíper da Bag soltaria a corda...")
		if o.k == "web" and not o.cut and Game.hit(hb, g.R(o.x, o.y, o.w, o.h)):
			o.cut = true
			o.t = 0
			g.player.webT = 0
			Audio.play("slide", -4)
			g.burst(o.x + o.w / 2.0, o.y + o.h / 2.0, 18, Color(.92, .92, .95))
		if o.k == "hive" and o.st == "idle" and Game.hit(hb, hive_box(o)):
			_hive_wake(o)

func reset_on_respawn() -> void:
	trapped = null
	for o in T:
		if o.k == "roll" and o.st in ["go", "fall"]:
			o.st = "idle"
			o.bx = float(o.x)
			o.vx = 0.0
			o.fy = 0.0
		if o.k == "cage" and o.st in ["drop", "shut"]:
			o.st = "idle"
		if o.k == "hive" and o.st != "idle":
			o.st = "idle"
			o.sx = float(o.x)
			o.sy = float(o.y) - 20.0
		if o.k == "bridge" and o.st != "idle" and g.player.x < o.x + o.w:
			_bridge_build(o)
		if o.k == "boulder" and o.st != "done":
			_boulder_reset(o)
		# galho que quebrou: volta inteiro (sem isso, renascendo perto, o caminho ficava sem ele)
		if o.k == "snap" and o.st != "idle":
			_snap_reset(o)
	g.player.sink = 0.0
	g.player.webT = 0
	if not PICK.is_empty():
		_unpeg()
		PICK = {}

func save_data() -> Dictionary:
	var d := {}
	for i in T.size():
		var o: Dictionary = T[i]
		if (o.k == "net" and o.st == "down") or (o.k == "cage" and o.st == "used") or (o.k in ["roll", "boulder"] and o.st == "done") or (o.k == "web" and o.cut):
			d[str(i)] = o.st
	return d

func restore(d: Dictionary) -> void:
	for k in d:
		var i := int(k)
		if i < T.size():
			var o: Dictionary = T[i]
			o.st = d[k]
			if o.k == "net" and o.st == "down":
				g.SOL.erase(o.sol)
				o.fy = 999.0
			if o.k == "cage":
				o.dy = -170.0
			if o.k == "web":
				o.cut = true
				o.st = "idle"
			if o.k == "boulder":
				for sb in g.SOL.duplicate():
					if sb.get("bob") and o.smash.has(sb.get("id", "")):
						g.SOL.erase(sb)

# ======================================================================
#  PLANTA CARNÍVORA (é um inimigo: a picareta derruba, o latido atordoa)
# ======================================================================
func plant_update(e: Dictionary) -> void:
	var p: Dictionary = g.player
	var pcx: float = p.x + p.w / 2
	var dx: float = pcx - e.x
	e.pt = e.get("pt", 0) + 1
	var st: int = e.get("st", 0)
	match st:
		0:
			e.lx = lerpf(e.get("lx", 0.0), 0.0, .2)
			if abs(dx) < 220:
				e.dir = 1 if dx > 0 else -1
			if abs(dx) < 92 and abs(p.y + p.h - e.base) < 60 and p.dyingT == 0:
				e.st = 1
				e.pt = 0
		1:
			# prepara (recua a cabeça) — dá tempo de reagir
			e.lx = -12.0 * min(1.0, e.pt / 10.0)
			if e.pt >= 20:
				e.st = 2
				e.pt = 0
				Audio.play("stomp", -10)
		2:
			e.lx = lerpf(e.lx, 56.0, .5)
			if e.pt >= 12:
				e.st = 3
				e.pt = 0
		3:
			e.lx = lerpf(e.lx, 0.0, .1)
			if e.pt >= 46:
				e.st = 0
				e.pt = 0
	e.y = e.base

func plant_box(e: Dictionary) -> Dictionary:
	var hx: float = e.x + e.dir * (18 + e.get("lx", 0.0))
	return g.R(hx - 20, e.base - 64, 40, 34)

# ======================================================================
#  ARMADILHAS NOVAS (tronco-pêndulo, colmeia, areia movediça, vento, ponte, bola gigante)
# ======================================================================
## ponta do tronco pendurado: as duas cordas balançam juntas, o tronco fica sempre deitado
func swing_end(o: Dictionary) -> Vector2:
	var a: float = o.amp * sin(TAU * (g.T + o.get("ph", 0)) / float(o.per))
	o.ang = a
	return Vector2(o.x + sin(a) * o.len, o.y + cos(a) * o.len)

func swing_dir(o: Dictionary) -> float:
	return 1.0 if cos(TAU * (g.T + o.get("ph", 0)) / float(o.per)) >= 0 else -1.0

# ---------- colmeia ----------
func hive_box(o: Dictionary) -> Dictionary:
	return g.R(o.x - 22, o.y - 50, 44, 50)

func _hive_wake(o: Dictionary) -> void:
	if o.cool > 0:
		return
	o.st = "angry"
	o.t = 0
	o.sx = float(o.x)
	o.sy = float(o.y) - 20.0
	Audio.play("roar", -14)
	g.shake = max(g.shake, 4)
	g.flash_tut("Abelhas!", "Abelhas! Mergulhe na água (↓) para despistar o enxame!", 180)

func _hive(o: Dictionary, p: Dictionary, pcx: float) -> void:
	if o.cool > 0:
		o.cool -= 1
	match o.st:
		"idle":
			if not p.get("dog") and p.dyingT == 0 and Game.hit(p, hive_box(o)):
				_hive_wake(o)
		"angry":
			var tx: float = pcx
			var ty: float = p.y + 10
			var d := Vector2(tx - o.sx, ty - o.sy)
			# o enxame é mais rápido que andar e mais lento que correr
			var v: Vector2 = d.normalized() * min(d.length(), 4.7)
			o.sx += v.x
			o.sy += v.y + sin(o.t * .2) * .8
			if o.t % 20 == 0:
				Audio.play("climb", -18)
			if d.length() < 26 and p.iframe == 0 and p.dyingT == 0:
				g.hurt(1, o.sx)
			# só despista mergulhando de verdade (o Tomé inteiro embaixo d'água); boiando não adianta.
			# Muito longe da colmeia ou depois de bastante tempo, o enxame também desiste
			var under: bool = p.swim and p.get("water") != null and p.y > p.water.y + 2
			if under or abs(pcx - o.x) > 1500 or o.t > 1200:
				o.st = "home"
				o.t = 0
		"home":
			var d2 := Vector2(o.x - o.sx, o.y - 20 - o.sy)
			if d2.length() < 6:
				o.st = "idle"
				o.cool = 150
			else:
				var v2: Vector2 = d2.normalized() * min(d2.length(), 3.0)
				o.sx += v2.x
				o.sy += v2.y

func _over_water(x: float, feet: float) -> bool:
	for sw in g.SWAMP:
		if x > sw.x and x < sw.x + sw.w and feet > sw.y - 30:
			return true
	for w in g.X.WATER:
		if x > w.x and x < w.x + w.w and feet > w.y - 10:
			return true
	return false

# ---------- areia movediça ----------
func _sand(o: Dictionary, p: Dictionary, pcx: float, feet: float) -> void:
	var inside: bool = pcx > o.x and pcx < o.x + o.w and abs(feet - o.y) < 6 and p.onGround and not p.get("dog") and p.dyingT == 0
	if inside:
		if not o.get("was", false):
			Audio.play("splash", -10)
			g.tip("Areia movediça! Parado você afunda: atravesse pulando.")
		var still: bool = abs(p.vx) < .6
		p.sink = min(36.0, p.get("sink", 0.0) + (.4 if still else .16))
		p.vx = clamp(p.vx, -1.6, 1.6)
		if g.T % 9 == 0:
			g.burst(pcx + randf_range(-10, 10), o.y, 2, Color("#b59a62"))
		if p.sink >= 34.0:
			p.sink = 0.0
			g.die("Você afundou na areia movediça.")
		o.was = true
	elif o.get("was", false):
		o.was = false
		# pulo de dentro da areia sai mais baixo
		if p.vy < 0 and not p.onGround:
			p.vy = max(p.vy, Game.JUMP * (.82 - p.get("sink", 0.0) / 120.0))
		p.sink = 0.0

# ---------- rajadas de vento ----------
## 0 = calmo, 1 = aviso (folhas e neve começam a voar), 2 = rajada
func gust_state(o: Dictionary) -> int:
	var per: int = o.get("per", 260)
	var on: int = o.get("on", 110)
	var u: int = (g.T + int(o.get("ph", 0))) % per
	if u >= per - on:
		return 2
	if u >= per - on - 45:
		return 1
	return 0

func _gust(o: Dictionary, p: Dictionary, pcx: float) -> void:
	if gust_state(o) != 2 or p.dyingT > 0 or p.get("dog"):
		return
	if pcx < o.x or pcx > o.x + o.w or p.y + p.h < o.y or p.y > o.y + o.h or p.ladder:
		return
	var push: float = .25 if p.crouch else (2.9 if p.onGround else 3.3)
	g.move_x(-push)
	if g.T % 30 == 0 and not p.crouch:
		g.tip("Rajada de vento! Segure ↓ para se abaixar e aguentar firme.")

# ---------- ponte de cordas ----------
func _bridge_build(o: Dictionary) -> void:
	for pl in o.get("planks", []):
		g.SOL.erase(pl.sol)
	o.planks = []
	var n: int = int(o.w / 40)
	var gaps: Array = o.get("gaps", [])
	for i in n:
		if gaps.has(i):
			continue
		var sol := {"t": "bplank", "x": o.x + i * 40.0, "y": float(o.y), "w": 40.0, "h": 12.0, "oneway": 1, "bridge": 1}
		g.SOL.append(sol)
		o.planks.append({"x": o.x + i * 40.0, "sol": sol, "fy": 0.0, "vy": 0.0, "down": false})
	o.st = "idle"
	o.front = float(o.x) - 20.0
	o.t = 0

func _bridge(o: Dictionary, p: Dictionary) -> void:
	match o.st:
		"idle":
			if p.onGround and p._g != null and p._g.get("bridge") and not p.get("dog"):
				o.st = "go"
				o.t = 0
				Audio.play("climb")
				g.shake = max(g.shake, 3)
				g.flash_tut("CORRA!", "A ponte está se soltando! CORRA! (toque duas vezes → para correr)", 160)
		"go":
			if o.t > o.get("delay", 24):
				o.front += o.get("spd", 5.0)
			if o.front > o.x + o.w + 40:
				o.st = "gone"
				o.t = 0
	if o.st == "idle" or (o.st == "gone" and o.t > 300):
		return   # parada (ou já toda lá embaixo, fora da tela): nada para mexer nas tábuas
	for pl in o.planks:
		if o.st != "idle" and not pl.down and pl.x + 40 < o.front:
			pl.down = true
			g.SOL.erase(pl.sol)
			Audio.play("stomp", -16)
			g.burst(pl.x + 20, o.y + 6, 3, Color("#8a6a42"))
		if pl.down:
			pl.vy += .5
			pl.fy += pl.vy

# ---------- bola de pedra gigante ----------
func _boulder_reset(o: Dictionary) -> void:
	o.st = "idle"
	o.bx = float(o.x)
	o.by = float(o.y) - o.r
	o.vx = 0.0
	o.vy = 0.0
	o.smashed = {}
	for s in g.SOL:
		if s.get("bob"):
			s.erase("gone")
	for s in g.L.solids:
		if s.get("bob") and o.smash.has(s.id):
			var have := false
			for s2 in g.SOL:
				if s2.get("id", "") == s.id:
					have = true
			if not have:
				g.SOL.append(s.duplicate())

func _boulder(o: Dictionary, p: Dictionary, pcx: float) -> void:
	var R: float = o.r
	match o.st:
		"idle":
			if not p.get("dog") and pcx > o.trig and pcx < o.trig + 500 and abs(p.y + p.h - o.y) < 60 and p.dyingT == 0:
				o.st = "drop"
				o.t = 0
				o.bx = float(o.x)
				o.by = float(o.y) - R - 170.0
				o.vy = 0.0
				o.vx = 0.0
				Audio.play("stomp", -2)
				g.shake = max(g.shake, 10)
				g.want_comic("bola")
				g.flash_tut("Fuja!", "Uma pedra gigante! Fuja para a frente, pule os obstáculos e se abaixe (↓) no buraco do chão lá na frente!", 260)
		"drop":
			o.vy += .9
			o.by += o.vy
			if g.T % 3 == 0:
				g.burst(o.bx + randf_range(-R, R), o.y - 120, 2, Color("#8a7a62"))
			if o.by >= o.y - R:
				o.by = float(o.y) - R
				o.st = "roll"
				o.t = 0
				Audio.play("stomp")
				g.shake = max(g.shake, 12)
				g.fx("fx_dust", o.bx, o.y - 8, 24, .3, -.3)
		"roll":
			# rola um pouco mais devagar que o passo normal do Tomé (dá para fugir andando, contando
			# o tempo dos pulos); começa devagar e só depois embala
			o.vx = move_toward(o.vx, o.vmax, .035)
			o.bx += o.vx
			o.rot += o.vx / R
			if g.T % 5 == 0:
				g.fx("fx_dust", o.bx - R * .7, o.y - 8, 18, .16, -.3)
				g.shake = max(g.shake, 3.0)
			if g.T % 16 == 0:
				Audio.play("stomp", -14)
			# esmaga caixas, carrinho e a barricada
			for s in g.SOL.duplicate():
				if s.get("bob") and o.smash.has(s.get("id", "")) and o.bx + R > s.x + 8:
					g.SOL.erase(s)
					o.vx *= .55
					o.smashed[s.id] = 1
					Audio.play("stomp", -4)
					g.shake = max(g.shake, 8)
					g.fx("fx_pieces", s.x + s.w / 2, s.y + s.h / 2, 26, .5, -.4)
					g.burst(s.x + s.w / 2, s.y + s.h / 2, 18, Color("#9a7448"))
			# encostou no Tomé (abaixado no buraco do chão a bola passa por cima)
			var cx: float = clamp(o.bx, p.x + 3, p.x + p.w - 3)
			var cy: float = clamp(o.by, p.y + 3, p.y + p.h - 2)
			if p.dyingT == 0 and Vector2(o.bx, o.by).distance_to(Vector2(cx, cy)) < R and not p.get("dog"):
				_boulder_hit(o)
			elif not o.get("passed", false) and o.bx > pcx + R:
				o.passed = true
				g.note("Ufa! A pedra passou por cima!")
			if o.bx >= o.end:
				o.st = "break"
				o.t = 0
				Audio.play("stomp")
				g.shake = max(g.shake, 14)
				g.fx("fx_pieces", o.bx, o.by, 40, .8, -.6)
				g.burst(o.bx, o.by, 30, Color("#8a8070"))
		"break":
			if o.t > 30:
				o.st = "done"

func _boulder_hit(o: Dictionary) -> void:
	var p: Dictionary = g.player
	if p.iframe > 0:
		return
	g.hurt(1, o.bx)
	if p.dyingT > 0 or not g.running:
		return
	# volta para o começo do trecho e a bola volta para o teto
	g.iris_t = 30
	p.x = float(o.back) - p.w / 2
	p.y = float(o.y) - p.h
	p.vx = 0.0
	p.vy = 0.0
	p.run = 0
	_boulder_reset(o)
	g.snap_camera()
	g.flash("A pedra te alcançou! De novo: corra e se abaixe no buraco do chão.", 200)
