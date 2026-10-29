extends RefCounted
class_name Nature
## Trechos novos de natureza: lamaçal de sanguessugas, corda esticada (andar pendurado),
## bolhas que dão fôlego, capacete de mergulho e arpão, corrente de bolhas, bolas de neve que
## crescem, buracos de água gelada, esquilos que jogam bolotas e o gelo escorregadio.

var g
var BOGS: Array = []
var BARS: Array = []
var VENTS: Array = []
var CURRENTS: Array = []
var GEAR: Array = []
var HOLES: Array = []
var SNOWB: Array = []
var HARP: Array = []
var helmet := false
var harpoon := false
var harp_cd := 0
var bar_cd := 0
var skip_bar = null        # a corda de onde o Tomé acabou de pular (não agarra de novo até pisar no chão)
var told := {}

func _init(game) -> void:
	g = game

func load_level() -> void:
	var L: Dictionary = g.L
	BOGS = L.get("bogs", [])
	BARS = L.get("bars", [])
	VENTS = L.get("vents", [])
	CURRENTS = L.get("currents", [])
	GEAR = []
	for o in L.get("gear", []):
		var d: Dictionary = o.duplicate()
		d.got = false
		GEAR.append(d)
	HOLES = []
	for o in L.get("holes", []):
		var d: Dictionary = o.duplicate()
		d.filled = false
		HOLES.append(d)
	SNOWB = []
	for c in g.CR:
		if c.get("snow"):
			c.lx = c.x
			c.ow = c.w
			c.oh = c.h
			SNOWB.append(c)
	HARP = []
	helmet = false
	harpoon = false
	harp_cd = 0
	bar_cd = 0
	told = {}

# ======================================================================
#  ANTES DA FÍSICA
# ======================================================================
func pre() -> void:
	var p: Dictionary = g.player
	if bar_cd > 0:
		bar_cd -= 1
	if p.onGround or p.ladder or p.vine:
		skip_bar = null
	if harp_cd > 0:
		harp_cd -= 1
	# arpão: GOLPE dentro d'água dispara
	if harpoon and p.swim and not p.get("dog") and g.keys.get("Gp", false) and p.dyingT == 0:
		g.keys["Gp"] = false
		if harp_cd == 0:
			harp_cd = 26
			var hx: float = p.x + p.w / 2 + p.face * 14
			HARP.append({"x": hx, "y": p.y + 14, "vx": p.face * 12.0, "sx": hx, "life": 40, "dead": false})
			p.act = "harpoon"
			p.actT = 12
			Audio.play("slide", -4)
			Audio.vib(15)
	# agarrar a corda esticada
	if not p.get("bar") and bar_cd == 0 and not p.onGround and not p.vine and not p.ladder and not p.swim and not p.get("dog") and p.dyingT == 0:
		var pcx: float = p.x + p.w / 2
		for b in BARS:
			if b == skip_bar:
				continue
			if pcx > b.x0 + 6 and pcx < b.x1 - 6 and p.y > b.y - 16 and p.y < b.y + 18:
				p.bar = b
				# pega a corda sem tranco: guarda o embalo e vai encaixando as mãos aos poucos
				p.vx *= .45
				p.bsw = clamp(p.vx * .05 + p.vy * .012, -.35, .35)
				p.bsv = 0.0
				p.bdist = 0.0
				p.bfr = 0
				p.vy = 0.0
				p.airJumps = 1
				p.puff = false
				p.slam = false
				p.run = 0
				Audio.play("climb", -6)
				g.burst(pcx, b.y, 6, Color("#cdbfa6"))
				if not told.has("bar"):
					told.bar = 1
					g.tip("Na corda: ← → anda pendurado. PULAR dá um impulso para cima; ↓ solta.", 200)
				break

## altura da corda em x: barriga entre os postes + a parte que cede onde o jogador segura
func bar_y(b: Dictionary, x: float) -> float:
	var x0: float = float(b.x0) - 8
	var x1: float = float(b.x1) + 12
	var u: float = clamp((x - x0) / (x1 - x0), 0.0, 1.0)
	var y: float = float(b.y) + sin(u * PI) * 10.0
	var p: Dictionary = g.player
	if p.get("bar") == b:
		var pcx: float = p.x + p.w / 2
		y += max(0.0, 1.0 - abs(x - pcx) / 160.0) * 14.0
	return y

## andar pendurado na corda (no lugar da física normal)
func bar_step() -> void:
	var p: Dictionary = g.player
	var b: Dictionary = p.bar
	var want := -1 if (g.kd("L") and not g.kd("R")) else (1 if (g.kd("R") and not g.kd("L")) else 0)
	if want != 0:
		p.face = want
	var ovx: float = p.vx
	# acelera e freia devagar (mão sobre mão), sem trancos
	p.vx += (want * 2.6 - p.vx) * .12
	var nx: float = clamp(p.x + p.vx, b.x0 - p.w / 2, b.x1 - p.w / 2)
	g.move_x(nx - p.x)
	# as mãos seguem a corda (que cede onde ele segura); o corpo encaixa aos poucos
	var hy: float = bar_y(b, p.x + p.w / 2)
	p.y = lerpf(p.y, hy + 6.0, .3)
	p.vy = 0.0
	# balanço do corpo: um pêndulo amortecido que reage a acelerar e frear
	p.bsv = float(p.get("bsv", 0.0)) * .9 - float(p.get("bsw", 0.0)) * .07 - (p.vx - ovx) * .06
	p.bsw = clamp(float(p.get("bsw", 0.0)) + p.bsv, -.4, .4)
	# troca de mão a cada palmo andado (parado, fica com a última)
	p.bdist = float(p.get("bdist", 0.0)) + abs(p.vx)
	if p.bdist > 30.0:
		p.bdist -= 30.0
		p.bfr = 1 - int(p.get("bfr", 0))
		if abs(p.vx) > 1.0:
			Audio.play("climb", -16)
	p.anim += abs(p.vx) * .07
	if g.pressed("J"):
		# PULAR: dá um impulso para cima (alcança o telhado ou a margem logo acima)
		skip_bar = b
		p.bar = null
		bar_cd = 16
		p.vy = Game.JUMP * .85
		p.vx *= .6
		p.onGround = false
		Audio.play("jump", -6)
	elif g.kd("S"):
		p.bar = null
		bar_cd = 16
		p.vy = 0.5
		p.vx *= .6
		Audio.play("jump", -10)

# ======================================================================
#  FÔLEGO
# ======================================================================
## está numa coluna de bolhas?
func in_vent() -> bool:
	var p: Dictionary = g.player
	var cx: float = p.x + p.w / 2
	for v in VENTS:
		if abs(cx - v.x) < 34 and p.y + p.h > v.y - 340 and p.y < v.y:
			return true
	return false

## dentro d'água, o fôlego não acaba?
func air_ok() -> bool:
	return helmet

# ======================================================================
#  DEPOIS DA FÍSICA
# ======================================================================
func post() -> void:
	var p: Dictionary = g.player
	var pcx: float = p.x + p.w / 2
	var feet: float = p.y + p.h
	# lamaçal: sanguessugas não deixam passar
	for b in BOGS:
		if pcx > b.x and pcx < b.x + b.w and feet > b.y + 8 and p.dyingT == 0 and not p.get("dog"):
			g.burst(pcx, b.y, 18, Color("#4a3a22"))
			Audio.play("splash", -4)
			g.die("As sanguessugas do lamaçal te pegaram! Vá de cipó em cipó.")
			return
	# água gelada
	for h in HOLES:
		if not h.filled and pcx > h.x and pcx < h.x + h.w and feet > h.y + 10 and p.dyingT == 0:
			g.burst(pcx, h.y, 18, Color(.8, .9, 1))
			Audio.play("splash", -2)
			g.die("Água gelada! Tampe o buraco com uma bola de neve.")
			return
	# corrente de bolhas: leva para cima
	for c in CURRENTS:
		if pcx > c.x and pcx < c.x + c.w and p.y + p.h > c.y0 and p.y < c.y1 and g.K.fish_done():
			p.vy = max(-7.5, p.vy - 1.1)
			p.vx += (c.x + c.w / 2 - pcx) * .01
			if p.y < c.y0 + 20:
				p.vy = Game.JUMP * .95
				p.vx = 3.4
				p.cutOk = false
				p.jbuf = 0
			if g.T % 3 == 0:
				g.X.BUB.append({"x": c.x + randf() * c.w, "y": c.y1 - 10, "t": 0, "top": c.y0})
	# bolhas das fontes
	if g.T % 5 == 0:
		for v in VENTS:
			if abs(v.x - g.cam - g.W / 2) < g.W:
				g.X.BUB.append({"x": v.x + (randf() - .5) * 26, "y": v.y - 4, "t": 0, "top": v.y - 600})
	# capacete e arpão
	for o in GEAR:
		if not o.got and Game.hit(p, g.R(o.x - 32, o.y - 54, 64, 62)) and not p.get("dog"):
			o.got = true
			Audio.play("item")
			Audio.vib(50)
			g.burst(o.x, o.y - 14, 18, Color("#ffe9a0"))
			if o.id == "capacete":
				helmet = true
				g.X.breath = g.X.BREATH
				g.flash("Um capacete de mergulho! Agora o Tomé respira debaixo d'água.", 240)
			else:
				harpoon = true
				g.flash_tut("Um arpão!", "Um arpão! Debaixo d'água, GOLPE dispara.", 220)
	# arpões
	for h in HARP:
		if h.dead:
			continue
		h.x += h.vx
		h.life -= 1
		if h.life <= 0:
			h.dead = true
			continue
		if g.K.harpoon_hit(h):
			h.dead = true
			continue
		for e in g.EN:
			if not e.dead and Game.hit(g.R(h.x - 8, h.y - 4, 16, 8), g.ebox(e)):
				g.kill_enemy(e, "hit")
				h.dead = true
				break
		for s in g.SOL:
			if not s.get("oneway") and h.x > s.x and h.x < s.x + s.w and h.y > s.y and h.y < s.y + s.h:
				h.dead = true
				g.burst(h.x, h.y, 5, Color(.7, .8, .9))
				break
	HARP = HARP.filter(func(h): return not h.dead)
	_snowballs()

# ---------- bolas de neve ----------
func _snowballs() -> void:
	for c in SNOWB:
		if c.dead:
			continue
		var mv: float = c.x - c.lx
		var dx: float = abs(mv)
		c.lx = c.x
		if dx > 0.0 and dx < 10.0 and c.w < 92:
			# rolando ela junta neve: cresce mantendo a base no chão
			var nw: float = min(92.0, c.w + dx * .16)
			var grow: float = nw - c.w
			# cresce para a frente (para o lado em que está rolando), sem empurrar o Tomé
			var gx: float = 0.0 if mv > 0 else grow
			var r: Dictionary = g.R(c.x - gx, c.y - grow, nw, nw - 2)
			var free := true
			for s in g.blockers():
				if s != c and not s.get("oneway") and Game.hit(r, s):
					free = false
					break
			if free:
				c.x -= gx
				c.lx = c.x
				c.y -= grow
				c.w = nw
				c.h = nw
		# caiu num buraco de água gelada: vira ponte de gelo
		for h in HOLES:
			if not h.filled and c.x + c.w / 2 > h.x and c.x + c.w / 2 < h.x + h.w and c.y > h.y - c.h + 12:
				h.filled = true
				c.dead = true
				g.SOL.append({"t": "snowfill", "x": h.x, "y": h.y, "w": h.w, "h": 30})
				g.shake = 8
				Audio.play("splash")
				Audio.play("stomp", -6)
				g.burst(h.x + h.w / 2, h.y, 26, Color(.9, .95, 1))
				g.flash("A bola de neve afundou e a água congelou: virou ponte!", 200)

## esquilo: corre de um lado para o outro no seu trecho e, com o Tomé perto, dá um bote
## (como o sapo e o javali: pisar em cima ou a picareta derrubam; encostar de lado machuca)
func squirrel(e: Dictionary) -> void:
	var p: Dictionary = g.player
	var dx: float = p.x + p.w / 2 - e.x
	e.st = e.get("st", 0)
	e.t = e.get("t", int(e.x) % 60) + 1
	var r0: float = float(e.r[0]) - 40.0
	var r1: float = float(e.r[1]) + 40.0
	match e.st:
		0:
			# corre no seu trecho
			e.leap = 0
			e.y = e.base
			if not e.has("dir") or e.dir == 0:
				e.dir = 1
			# na ponta do trecho para, olha em volta e só então vira e volta a correr
			if e.get("pz", 0) > 0:
				e.pz -= 1
				if e.pz == 6:
					e.dir = -e.dir
				e.sv = 0.0
			else:
				e.sv = move_toward(float(e.get("sv", 1.3)), 1.3, .12)
				e.x += e.dir * e.sv
				if e.x < r0 or e.x > r1:
					e.x = clamp(e.x, r0, r1)
					e.pz = 18
				e.run = e.get("run", 0.0) + .2 * e.sv / 1.3
			if abs(dx) < 230 and abs(p.y + p.h - e.base) < 70 and e.t > 70 and p.dyingT == 0:
				e.st = 1
				e.t = 0
				e.dir = 1 if dx > 0 else -1
				Audio.play("jump", -12)
		1:
			# prepara (agacha) e dá o bote na direção do Tomé — antes leva um sustinho (pulinho)
			e.y = e.base - (sin(e.t / 10.0 * PI) * 9.0 if e.t < 10 else 0.0)
			if e.t > 28:
				e.st = 2
				e.t = 0
		2:
			var u: float = e.t / 34.0
			e.leap = 1
			e.x = clamp(e.x + e.dir * 4.2, r0, r1)
			e.y = e.base - sin(min(u, 1.0) * PI) * 46
			if u >= 1.0:
				e.y = e.base
				e.leap = 0
				e.st = 0
				e.t = 0

# ======================================================================
#  SALVAR
# ======================================================================
func save_data() -> Dictionary:
	var sb := []
	for c in SNOWB:
		sb.append([c.x, c.y, c.w, c.dead])
	return {"helmet": helmet, "harpoon": harpoon, "gear": GEAR.map(func(o): return o.got),
		"holes": HOLES.map(func(h): return h.filled), "snow": sb}

func restore(d: Dictionary) -> void:
	helmet = d.get("helmet", false)
	harpoon = d.get("harpoon", false)
	var gg: Array = d.get("gear", [])
	for i in min(gg.size(), GEAR.size()):
		GEAR[i].got = gg[i]
	var hh: Array = d.get("holes", [])
	for i in min(hh.size(), HOLES.size()):
		if hh[i] and not HOLES[i].filled:
			HOLES[i].filled = true
			g.SOL.append({"t": "snowfill", "x": HOLES[i].x, "y": HOLES[i].y, "w": HOLES[i].w, "h": 30})
	var sb: Array = d.get("snow", [])
	for i in min(sb.size(), SNOWB.size()):
		var c: Dictionary = SNOWB[i]
		c.x = float(sb[i][0])
		c.y = float(sb[i][1])
		c.w = float(sb[i][2])
		c.h = c.w
		c.lx = c.x
		c.dead = bool(sb[i][3])
