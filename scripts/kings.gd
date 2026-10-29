extends RefCounted
class_name Kings
## Os outros reis do caminho (o Javali-Rei fica em extras.gd):
##  - GAVIÃO-REI (nas copas, à tarde): avisa o mergulho com a sombra no chão; se errar, as garras
##    ficam presas na madeira e a picareta acerta. O facho da lanterna confunde. 4 golpes;
##    depois de 2, mergulha duas vezes seguidas e chama corvos.
##  - BAGRE-REI (no fundo do lago): investe, revolve a lama e suga. Cansado, mostra as escamas
##    que brilham: é ali que o arpão acerta. 4 acertos. Vencido, abre a corrente de bolhas.
##  - URSO-PARDO-REI (fim da neve): não se luta com ele — é uma perseguição até a fresta da rocha.
##  Cada rei vencido deixa cair a sua COROA (colecionável): ela fica no chão brilhando até o Tomé pegar.

var g
var HAWK := {}
var FISH := {}
var BEAR := {}
var BOBS: Array = []     # troncos e galho no caminho da perseguição do urso (sólidos que ele arrebenta)
var ICI: Array = []      # pingentes da laje da rocha (caem com o rugido)
var CROWNS: Array = []   # coroas caídas esperando o Tomé (e as que ele está erguendo)
var TOOK := {}           # coroas que o Tomé já pegou nesta partida
var DROPPED := {}        # coroas que já saltaram da cabeça do rei nesta partida

func _init(game) -> void:
	g = game

func load_level() -> void:
	HAWK = {}
	FISH = {}
	BEAR = {}
	BOBS = []
	ICI = []
	CROWNS = []
	TOOK = {}
	DROPPED = {}
	var L: Dictionary = g.L
	if L.has("bear"):
		var b: Dictionary = L.bear
		BEAR = {"x0": b.x0, "x1": b.x1, "gy": b.y, "trig": b.trig, "maxhp": b.hp, "hp": b.hp, "st": "wait", "den": b.den,
			"rock": b.rock, "roar": b.roar, "x": float(b.den), "dir": 1, "t": 0, "red": 0, "anim": 0.0, "active": false,
			"done": false, "v": 0.0, "won": false, "crown": true, "rt": -1, "cool": 70}
		var gy: float = b.y
		for i in b.get("obs", []).size():
			var o: Dictionary = b.obs[i]
			var so := {"t": "bearobs", "k": o.k, "x": float(o.x), "y": float(o.y), "w": float(o.w), "h": float(o.h), "id": "bobs%d" % i}
			if float(o.y) + float(o.h) < gy - 15:
				# galho baixo: só passa abaixado (ou por cima)
				so.crawl = {"x": so.x, "w": so.w, "top": so.y + so.h, "y": gy}
				g.X.CRAWL.append(so.crawl)
			g.SOL.append(so)
			BOBS.append(so)
		for ix in b.get("ici", []):
			var iy: float = float(b.get("iciY", 300))
			ICI.append({"x": float(ix), "y0": iy, "y": iy, "len": 34.0 + fmod(float(ix) * 1.7, 14.0), "st": "hang", "t": 0, "vy": 0.0})
	if L.has("hawk"):
		var h: Dictionary = L.hawk
		HAWK = {"x0": h.x0, "x1": h.x1, "gy": h.y, "trig": h.trig, "maxhp": h.hp, "hp": h.hp, "st": "wait",
			"x": (h.x0 + h.x1) / 2.0, "y": h.y - 340.0, "t": 0, "dir": 1, "tx": 0.0, "sx": 0.0, "sy": 0.0,
			"red": 0, "active": false, "done": false, "conf": false, "second": false, "crows": false, "skin": str(h.get("skin", "hawk"))}
		if HAWK.skin == "bat":
			# Morcego-Rei: luta das lamparinas (Ep2Bosses)
			Ep2Bosses.bat_setup(HAWK, L)
	if L.has("fish"):
		var f: Dictionary = L.fish
		FISH = {"x0": f.x0, "x1": f.x1, "y0": f.y0, "y1": f.y1, "trig": f.trig, "maxhp": f.hp, "hp": f.hp,
			"st": "wait", "x": f.x1 - 160.0, "y": (f.y0 + f.y1) / 2.0, "vx": 0.0, "dir": -1, "t": 0, "red": 0,
			"active": false, "done": false, "cyc": 0, "mud": 0.0, "mouth": 0.0, "scales": [true, true, true, true], "al": 1.0,
			"skin": str(f.get("skin", "fish"))}
		if FISH.skin == "frog":
			# Sapo-Rei: luta da língua e das colmeias (Ep2Bosses)
			Ep2Bosses.frog_setup(FISH, L)

func active() -> bool:
	return (not HAWK.is_empty() and HAWK.active and not HAWK.done) or (not FISH.is_empty() and FISH.active and not FISH.done) or bear_on()

func bear_on() -> bool:
	return not BEAR.is_empty() and BEAR.active and not BEAR.done

func fish_done() -> bool:
	return FISH.is_empty() or FISH.done

## muros que estão afundando (o desenho continua um pouco depois de sair dos sólidos)
var SINK: Array = []

func sink_gate(s: Dictionary) -> void:
	var c: Dictionary = s.duplicate()
	c.st0 = g.T
	SINK.append(c)

func _gate(id: String, on: bool, r: Rect2) -> void:
	for s in g.SOL.duplicate():
		if s.get("id") == id:
			g.SOL.erase(s)
			sink_gate(s)
	if on:
		g.SOL.append({"t": "kinggate", "x": r.position.x, "y": r.position.y, "w": r.size.x, "h": r.size.y, "id": id})

func post() -> void:
	_hawk()
	_fish()
	_bear()
	_crowns()

# ======================================================================
#  GAVIÃO-REI
# ======================================================================
func hawk_box() -> Dictionary:
	if HAWK.get("skin", "hawk") == "bat":
		# Morcego-Rei: a caixa acompanha o desenho (ver WorldKings._hawk): no mergulho o corpo desce até
		# as garras tocarem o chão; preso, fica de pé com as garras cravadas e as asas para cima
		var d: float = 1.0 if HAWK.dir > 0 else -1.0
		if HAWK.st == "stuck":
			return g.R(HAWK.x - 13.0 * d - 46, HAWK.gy - 128, 92, 126)
		return g.R(HAWK.x - 26.0 * d - 50, HAWK.y - 200 + bat_drop(), 100, 116)
	return g.R(HAWK.x - 46, HAWK.y - 58, 92, 64)

## quanto o desenho do Morcego-Rei desce durante o mergulho (as garras chegam ao chão no fim)
func bat_drop() -> float:
	if HAWK.is_empty() or HAWK.st != "dive":
		return 0.0
	return 80.0 * min(1.0, HAWK.t / 20.0)

func _hawk() -> void:
	if HAWK.get("skin", "") == "bat":
		Ep2Bosses.bat_step(g, self)
		return
	if HAWK.is_empty() or HAWK.done:
		return
	var h: Dictionary = HAWK
	var p: Dictionary = g.player
	var pcx: float = p.x + p.w / 2
	var feet: float = p.y + p.h
	var gy: float = h.gy
	if h.red > 0:
		h.red -= 1
	if h.get("landT", 0) > 0:
		h.landT -= 1
	var enraged: bool = h.hp <= 2
	match h.st:
		"wait":
			if pcx > h.trig and pcx < h.x1 and feet <= gy + 4 and feet > gy - 300 and p.dyingT == 0:
				h.active = true
				h.st = "circle"
				h.t = 0
				h.x = h.x1 - 100.0
				h.y = gy - 420.0
				h.hp = h.maxhp
				_gate("hawkL", true, Rect2(h.x0 - 24, gy - 260, 24, 260))
				_gate("hawkR", true, Rect2(h.x1, gy - 260, 24, 260))
				Audio.play("thunder", -8)
				if h.skin == "bat":
					g.start_cine("morcego", (h.x0 + h.x1) / 2.0, gy - 160, 250,
						[[150, 245, "TOMÉ", "Um morcego gigante! Ele mergulha onde a sombra marca... e a minha lanterna ofusca os olhos dele.", "tome"]],
						[60, 150, "MORCEGO-REI", "o dono das profundezas"])
				else:
					g.start_cine("gaviao", (h.x0 + h.x1) / 2.0, gy - 160, 250,
						[[150, 245, "TOMÉ", "Que gavião enorme! Preciso ficar longe da sombra dele...", "tome"]],
						[60, 150, "GAVIÃO-REI", "o senhor das copas"])
			return
		"circle":
			h.t += 1
			var cx: float = (h.x0 + h.x1) / 2.0 + sin(h.t * .022) * (h.x1 - h.x0) * .38
			h.dir = 1 if cos(h.t * .022) > 0 else -1
			h.x = lerpf(h.x, cx, .06)
			h.y = lerpf(h.y, gy - 165 + sin(h.t * .07) * 12, .05)
			if h.t > (70 if enraged else 110) and p.dyingT == 0:
				_mark(h, pcx)
		"mark":
			h.t += 1
			h.x = lerpf(h.x, h.tx, .08)
			h.y = lerpf(h.y, gy - 160, .08)
			# olha para onde vai mergulhar (para qualquer lado; perto do alvo não fica virando)
			if abs(h.tx - h.x) > 6:
				h.dir = 1 if h.tx > h.x else -1
			# o facho da lanterna confunde: ele mergulha no lugar errado
			if not h.conf and g.X.in_cone(h.x, h.y - 20, 520.0):
				h.conf = true
				var away: float = h.x0 + 80 if pcx > (h.x0 + h.x1) / 2.0 else h.x1 - 80
				h.tx = away
				g.burst(h.x, h.y - 30, 12, Color("#ffe9a0"))
				Audio.play("dj", -6)
				g.note("O facho ofuscou o Morcego-Rei!" if h.skin == "bat" else "O facho ofuscou o Gavião-Rei!")
			# antecipação: nos últimos quadros sobe um pouco e recolhe as asas antes de mergulhar
			var lim: int = 26 if h.second else (40 if enraged else 52)
			if h.t > lim - 12:
				h.y = lerpf(h.y, gy - 195, .18)
			if h.t > lim:
				h.st = "dive"
				h.t = 0
				h.sx = h.x
				h.sy = h.y
				Audio.play("slide", -2)
		"dive":
			h.t += 1
			var u: float = min(1.0, h.t / 20.0)
			h.x = lerpf(h.sx, h.tx, smoothstep(0.0, 1.0, u))
			h.y = lerpf(h.sy, gy, u * u)
			if p.dyingT == 0 and Game.hit(p, hawk_box()):
				g.hurt(1, h.x)
			if u >= 1.0:
				h.landT = 12
				g.shake_dir = Vector2(0, 1)
				Polish.debris(h.x - 120, h.x + 120, gy, 8)
				g.shake = 10
				g.burst(h.x, gy, 14, Color("#cdbfa6"))
				g.fx("fx_pieces", h.x, gy - 8, 16, .3, -.4)
				Audio.play("stomp", -6)
				if enraged and not h.second and not h.conf:
					# primeiro de dois mergulhos: sobe um pouco e vem de novo
					h.second = true
					h.st = "mark"
					h.t = 0
					h.tx = clamp(pcx, h.x0 + 60, h.x1 - 60)
				else:
					h.second = false
					h.conf = false
					h.st = "stuck"
					h.t = 0
					if not g.L.get("_hawk_tip", false):
						g.L["_hawk_tip"] = true
						g.flash_tut("As garras ficaram presas! GOLPE!", "As garras ficaram presas no chão! Corra e acerte com a picareta (GOLPE)!", 180)
		"stuck":
			h.t += 1
			h.y = gy + sin(h.t * .9) * 1.5
			if h.t > (110 if enraged else 150):
				h.st = "rise"
				h.t = 0
				Audio.play("dj", -8)
		"rise":
			h.t += 1
			h.y = lerpf(h.y, gy - 165, .07)
			if h.t > 40:
				h.st = "circle"
				h.t = 0
		"flee":
			h.t += 1
			# arranca devagar e vai ganhando velocidade
			h.x += min(6.0, .5 + h.t * .12)
			h.y -= min(4.5, .3 + h.t * .09)
			if h.t > 120:
				h.done = true
				h.active = false
				Polish.smoke_cloud(h.x, h.y - 40)

func _mark(h: Dictionary, pcx: float) -> void:
	h.st = "mark"
	h.t = 0
	h.conf = false
	h.tx = clamp(pcx, h.x0 + 60, h.x1 - 60)
	Audio.play("roar", -16)
	Polish.roar(h.x, h.y - 50)

## sombra do mergulho (posição e força) para o desenho
func hawk_shadow() -> Vector2:
	if HAWK.is_empty() or HAWK.st not in ["mark", "dive"]:
		return Vector2(-1, 0)
	var k: float = clamp(HAWK.t / 40.0, .2, 1.0) if HAWK.st == "mark" else 1.0
	return Vector2(HAWK.tx, k)

## golpe de picareta (Mech chama com a caixa do golpe)
func swing_hits(hb: Dictionary) -> void:
	if HAWK.is_empty() or HAWK.done or HAWK.st != "stuck" or HAWK.red > 0:
		return
	if not Game.hit(hb, hawk_box()):
		return
	var h: Dictionary = HAWK
	h.hp -= 1
	h.red = 30
	g.hit_stop = 6
	g.shake = 10
	Audio.play("stomp")
	Audio.play("roar", -10)
	Audio.vib(60)
	g.burst(h.x, h.y - 30, 18, Color("#e0c8a0"))
	for i in 6:
		g.PARTS.append({"x": h.x, "y": h.y - 30, "vx": (randf() - .5) * 5, "vy": -randf() * 4, "life": 40, "col": Color("#7a5232")})
	if h.hp <= 0:
		h.st = "flee"
		h.t = 0
		Polish.final_blow()
		if h.get("skin", "hawk") != "bat":
			# a coroa de penas salta da cabeça e cai na arena
			drop_crown("gaviao", h.x + h.dir * 38, h.y - 84, h.dir * 2.2, -6.0)
		Polish.loot_arc(h.x, h.y - 40, 10, h.gy)
		_gate("hawkL", false, Rect2())
		_gate("hawkR", false, Rect2())
		for e in g.EN:
			if e.k == "crow" and e.get("minion") and not e.dead:
				g.kill_enemy(e, "hit")
		for i in 10:
			g.gain_coin(h.x, h.y - 40, true)
		g.player.hp = Game.MAXHP
		Audio.play("door", -4)
		g.flash("O Morcego-Rei fugiu para o fundo da mina! O caminho está livre." if h.skin == "bat" else "O Gavião-Rei fugiu para as nuvens! O caminho está livre.", 240)
		return
	h.st = "rise"
	h.t = 0
	if h.hp == 2 and not h.crows and h.skin == "bat":
		h.crows = true
		g.flash("Acertou! Agora ele mergulha duas vezes seguidas!", 200)
	elif h.hp == 2 and not h.crows:
		h.crows = true
		for k in 1:
			var cx: float = h.x0 + 150 + k * (h.x1 - h.x0 - 300)
			g.EN.append({"k": "crow", "x": cx, "y": h.gy - 260.0, "cy": h.gy - 230.0 - k * 30, "r": [h.x0 + 40, h.x1 - 40],
				"dir": -1, "dead": 0, "base": h.gy - 230.0, "stun": 0, "leap": 0, "x0": cx, "sx": cx, "minion": 1})
		g.flash("Acertou! Ele chamou um corvo — e agora mergulha duas vezes!", 200)
	else:
		g.flash("Acertou! Falta%s %d." % ["m" if h.hp > 1 else "", h.hp], 120)


# ======================================================================
#  URSO-PARDO-REI (fim da neve): PERSEGUIÇÃO
#  O Tomé acorda o urso na toca e precisa fugir pela neve até a fresta da rocha, onde o urso não cabe.
#  No caminho: troncos para pular (o urso arrebenta), gelo liso, um galho baixo (abaixe/deslize) e,
#  embaixo da laje da rocha, pingentes que caem com o rugido (a sombra avisa onde).
#  O urso corre atrás: investida (agacha e cava a neve antes — a seta no chão mostra até onde vai),
#  patada (pata erguida brilhando — a mancha vermelha mostra onde bate) e rugido. Fica mais rápido
#  conforme o Tomé avança. O Tomé ganha ao passar inteiro pela fresta: o urso entala, a coroa cai e
#  rola pela fresta até o lado do Tomé, e o urso volta para a toca com a cabeça cheia de neve.
# ======================================================================
const BEAR_CHASE := ["chase", "rear", "slam", "crouch", "charge", "recover", "roar", "taunt"]

func bear_box() -> Dictionary:
	var b: Dictionary = BEAR
	match b.st:
		"rear", "slam", "roar":
			return g.R(b.x - 60, b.gy - 180, 120, 180)
		"crouch", "charge":
			# investida de cabeça baixa
			return g.R(b.x - 90 + b.dir * 10, b.gy - 96, 180, 96)
		"wait", "jam", "flee", "giveup":
			return g.R(-9999, -9999, 0, 0)
	return g.R(b.x - 90, b.gy - 126, 180, 126)

## a perseguição está acontecendo (para a câmera e a música)
func bear_chase() -> bool:
	return bear_on() and BEAR.st in BEAR_CHASE

## área da patada (à frente do urso)
func bear_paw() -> Rect2:
	var b: Dictionary = BEAR
	var a: float = b.x + b.dir * 25.0
	var c: float = b.x + b.dir * 205.0
	# na fresta a pata só entra um pouquinho
	c = min(c, float(b.rock.x) + 26.0)
	return Rect2(min(a, c), b.gy - 80, abs(c - a), 80)

## até onde a investida chega (para a seta de aviso no chão)
func bear_lunge_end() -> float:
	var b: Dictionary = BEAR
	return clamp(b.x + b.dir * 330.0, b.x0, float(b.rock.x) - 100.0)

## quanto do caminho o Tomé já fez (0 na toca, 1 na fresta): o urso acelera junto
func _bear_u() -> float:
	var b: Dictionary = BEAR
	var p: Dictionary = g.player
	return clamp((p.x + p.w / 2 - float(b.trig)) / max(1.0, float(b.rock.x) - float(b.trig)), 0.0, 1.0)

## o urso machucou o Tomé: tranco para longe do urso, folga de 1,5 s e o urso para e ruge (sem
## acertar duas vezes seguidas)
func _bear_dmg() -> void:
	var b: Dictionary = BEAR
	var p: Dictionary = g.player
	if p.iframe > 0 or p.dyingT > 0:
		return
	g.hurt(1, b.x)
	p.iframe = max(p.iframe, 90)
	if p.dyingT == 0:
		b.st = "taunt"
		b.t = 0

func _bear_obs_reset() -> void:
	for o in BOBS:
		o.erase("fallen")
		if o.has("crawl") and not g.X.CRAWL.has(o.crawl):
			g.X.CRAWL.append(o.crawl)
	for c in ICI:
		c.st = "hang"
		c.t = 0
		c.y = float(c.y0)
		c.vy = 0.0
	g.blockers_dirty()

## o urso arrebenta o tronco ou o galho que estava no caminho
func _bear_smash(o: Dictionary) -> void:
	var b: Dictionary = BEAR
	o.fallen = true
	if o.has("crawl"):
		g.X.CRAWL.erase(o.crawl)
	g.blockers_dirty()
	b.stumble = 12
	b.v = float(b.v) * .55
	g.shake = max(g.shake, 9)
	g.shake_dir = Vector2(b.dir, 0)
	Audio.play("stomp", -2)
	Audio.play("thunder", -16)
	Audio.vib(60)
	var cx: float = o.x + o.w / 2.0
	var cy: float = o.y + o.h / 2.0
	g.fx("fx_pieces", cx, cy, 24, .4, -.4)
	g.burst(cx, cy, 16, Color(.95, .97, 1))
	for i in 9:
		g.PARTS.append({"x": cx + randf_range(-o.w / 2.0, o.w / 2.0), "y": cy, "vx": b.dir * randf_range(1.0, 5.0), "vy": -randf_range(2.0, 6.0), "life": 40, "col": Color("#7a5232") if i % 2 == 0 else Color("#a87a4c")})

## pingentes da laje: tremem (a sombra marca o chão), caem e se quebram no chão
func _ici_tick() -> void:
	var b: Dictionary = BEAR
	var p: Dictionary = g.player
	var gy: float = b.gy
	for c in ICI:
		match c.st:
			"shake":
				c.t += 1
				if c.t > 30:
					c.st = "fall"
					c.t = 0
					c.vy = 1.0
					Audio.play("slide", -10)
			"fall":
				c.t += 1
				c.vy = min(c.vy + .55, 16.0)
				c.y += c.vy
				var tip: float = c.y + float(c.len)
				if p.dyingT == 0 and p.x < c.x + 9 and p.x + p.w > c.x - 9 and p.y < tip and p.y + p.h > c.y + 6:
					g.hurt(1, c.x)
				if tip >= gy - 2:
					c.st = "gone"
					g.shake = max(g.shake, 4)
					Audio.play("stomp", -12)
					g.burst(c.x, gy - 4, 14, Color(.85, .95, 1))
					for i in 7:
						g.PARTS.append({"x": c.x, "y": gy - 6, "vx": randf_range(-3, 3), "vy": -randf_range(2, 5), "life": 26, "col": Color(.8, .93, 1, .95)})

## o rugido solta pingentes onde o Tomé vai passar (o mais perto de onde ele estará daqui a pouco)
func _ici_drop() -> void:
	var p: Dictionary = g.player
	var aim: float = p.x + p.w / 2 + p.vx * 34.0
	var best = null
	var bd := 1e9
	for c in ICI:
		if c.st == "hang" and abs(c.x - aim) < bd:
			bd = abs(c.x - aim)
			best = c
	if best != null and bd < 160:
		best.st = "shake"
		best.t = 0
		Audio.play("unlock", -14)

func _bear_attack_or_chase(u: float) -> void:
	var b: Dictionary = BEAR
	b.st = "chase"
	b.t = 0
	b.cool = int(64 - u * 26)

func _bear() -> void:
	if BEAR.is_empty() or BEAR.done:
		return
	var b: Dictionary = BEAR
	var p: Dictionary = g.player
	var pcx: float = p.x + p.w / 2
	var feet: float = p.y + p.h
	var gy: float = b.gy
	var rock: Rect2 = Rect2(float(b.rock.x), float(b.rock.y), float(b.rock.w), float(b.rock.h))
	var stop_x: float = rock.position.x - 100.0
	if b.red > 0:
		b.red -= 1
	if b.get("landT", 0) > 0:
		b.landT -= 1
	if b.get("stumble", 0) > 0:
		b.stumble -= 1
	_ici_tick()
	# rugido: os pingentes caem um depois do outro
	var rt: int = int(b.get("rt", -1))
	if rt >= 0:
		b.rt = rt + 1
		if b.rt in [14, 34, 54]:
			_ici_drop()
		if b.rt > 60:
			b.rt = -1
	var u: float = _bear_u()
	var dx: float = pcx - b.x
	# o Tomé passou inteiro pela fresta: venceu
	if not b.won and b.st != "wait" and p.x > rock.end.x + 4 and p.dyingT == 0:
		b.won = true
		b.hp = 0
		b.cool = 0
		if b.st in ["rear", "slam", "crouch", "charge", "recover", "roar", "taunt"]:
			b.st = "chase"
			b.t = 0
		Audio.play("special", -8)
		g.start_cine("urso_fim", float(b.rock.x) + 20.0, gy - 120, 150)
	# rugido quando o Tomé chega perto da laje (interrompe a corrida ou o fôlego depois da investida)
	if not b.won and not b.get("roared", false) and b.st in ["chase", "recover"] and pcx > float(b.roar) and p.dyingT == 0:
		b.roared = true
		b.st = "roar"
		b.t = 0
	match b.st:
		"wait":
			if pcx > b.trig and pcx < rock.position.x and feet <= gy + 4 and feet > gy - 300 and p.dyingT == 0:
				b.active = true
				b.st = "intro"
				b.t = 0
				b.hp = b.maxhp
				# o urso vem correndo pela floresta, de fora da tela (não tem mais a toca)
				b.x = pcx - 640.0
				b.dir = 1
				b.v = 0.0
				b.won = false
				b.roared = false
				b.cool = 70
				b.rt = -1
				b.crown = true
				_bear_obs_reset()
				if b.get("seen", false):
					# já viu a apresentação: o urso já vem correndo e a fuga começa na hora
					b.x = pcx - 560.0
					b.st = "chase"
					b.t = 0
					g.flash("O urso vem aí: CORRA!", 120)
					return
				b.seen = true
				Audio.play("roar", -4)
				g.start_cine("urso", pcx - 140.0, gy - 140, 230,
					[[130, 225, "TOMÉ", "Um urso vem correndo pela floresta! Grande demais para enfrentar... CORRE! Lá na frente, a fresta da rocha: ele não cabe!", "tome"]],
					[50, 130, "URSO-PARDO-REI", "o guardião da neve"])
			return
		"intro":
			# (a cena terminou sem passar pelo cine_end, como nos testes): já sai correndo
			b.st = "chase"
			b.t = 0
		"chase":
			b.t += 1
			if abs(dx) > 40:
				b.dir = 1 if dx > 0 else -1
			var ad: float = abs(dx)
			var spd: float = 5.1 + u * 1.2
			if b.won:
				spd = 9.0
				b.dir = 1
			elif ad > 470:
				spd = 7.8       # ficou muito para trás: dispara (nunca some da tela)
			elif ad > 320:
				spd = 6.1
			if b.get("stumble", 0) > 0:
				spd *= .45
			b.v = move_toward(float(b.v), b.dir * spd, .22)
			_bear_move()
			if b.won and b.x >= stop_x - 2:
				_bear_jam()
				return
			b.cool = int(b.get("cool", 0)) - 1
			if not b.won and p.dyingT == 0:
				if b.cool <= 0 and ad < 170 and abs(feet - gy) < 120:
					b.st = "rear"
					b.t = 0
					Audio.play("roar", -8)
					return
				if b.cool <= 0 and ad > 150 and ad < 320 and b.x < stop_x - 240 and sign(dx) == b.dir:
					b.st = "crouch"
					b.t = 0
					Audio.play("dj", -10)
					return
		"rear":
			# patada: ergue a pata brilhando (aviso) e continua vindo devagar; depois bate na frente
			b.t += 1
			b.v = move_toward(float(b.v), b.dir * 2.0, .3)
			_bear_move()
			if b.t > int(26 - u * 6):
				b.st = "slam"
				b.t = 0
				var paw := bear_paw()
				if p.dyingT == 0 and pcx > paw.position.x - 10 and pcx < paw.end.x + 10 and feet > gy - 84:
					_bear_dmg()
				g.shake = max(g.shake, 12)
				g.shake_dir = Vector2(0, 1)
				Audio.play("stomp")
				Audio.vib(80)
				g.burst(b.x + b.dir * 140, gy, 22, Color(.95, .97, 1))
				g.fx("fx_dust", b.x + b.dir * 140, gy - 10, 20, .4, -.3)
				Polish.debris(b.x - 160, b.x + 220, gy, 8)
		"slam":
			b.t += 1
			b.v = move_toward(float(b.v), 0.0, .4)
			_bear_move()
			if b.t > 16:
				_bear_attack_or_chase(u)
		"crouch":
			# investida: agacha, cava a neve com as patas de trás e mira (a seta no chão mostra até onde)
			b.t += 1
			b.v = move_toward(float(b.v), 0.0, .4)
			_bear_move()
			if b.t % 5 == 0:
				g.PARTS.append({"x": b.x - b.dir * 60, "y": gy - 6, "vx": -b.dir * randf_range(2, 4), "vy": -randf_range(2, 4), "life": 24, "col": Color(.95, .97, 1, .95)})
			if b.t > int(32 - u * 8):
				b.st = "charge"
				b.t = 0
				b.v = b.dir * 12.5
				b.lx = bear_lunge_end()
				Audio.play("roar", -6)
				Polish.roar(b.x + b.dir * 90, gy - 120)
		"charge":
			b.t += 1
			b.v = move_toward(float(b.v), b.dir * 4.0, .32)
			_bear_move()
			if b.t % 3 == 0:
				g.PARTS.append({"x": b.x - b.dir * 70, "y": gy - 4, "vx": -b.dir * 2.0, "vy": -1.5, "life": 18, "col": Color(.97, .98, 1, .9)})
			if b.t > 24 or (b.dir > 0 and b.x >= float(b.lx)) or (b.dir < 0 and b.x <= float(b.lx)):
				b.st = "recover"
				b.t = 0
				g.burst(b.x + b.dir * 80, gy, 12, Color(.95, .97, 1))
		"recover":
			# derrapa e ofega um pouco: é a hora de abrir distância
			b.t += 1
			b.v = move_toward(float(b.v), b.dir * 1.2, .35)
			_bear_move()
			if b.t % 2 == 0 and abs(float(b.v)) > 1.5:
				g.PARTS.append({"x": b.x + b.dir * 70, "y": gy - 4, "vx": b.dir * randf_range(1.0, 2.5), "vy": -randf_range(1.0, 2.2), "life": 18, "col": Color(.97, .98, 1, .9)})
			if b.t > 20:
				_bear_attack_or_chase(u)
		"roar":
			# para, se ergue e ruge: a laje treme e os pingentes começam a cair
			b.t += 1
			b.v = move_toward(float(b.v), 0.0, .4)
			_bear_move()
			if b.t == 8:
				Audio.play("roar", 0)
				Audio.vib(120)
				Polish.roar(b.x + b.dir * 80, gy - 170)
				g.shake = max(g.shake, 12)
				b.rt = 0
				for c in ICI:
					if c.st == "hang":
						c.wob = 30
			if b.t > 38:
				_bear_attack_or_chase(u)
		"taunt":
			# acertou: para um instante e bufa (dá tempo de o Tomé levantar e fugir)
			b.t += 1
			b.v = move_toward(float(b.v), 0.0, .5)
			_bear_move()
			if b.t == 6:
				Audio.play("roar", -12)
			if b.t > 34:
				_bear_attack_or_chase(u)
		"jam":
			# entalou na fresta: empurra, sacode a cabeça, a coroa cai e rola para o lado do Tomé;
			# depois senta tonto, com a cabeça cheia de neve, levanta e desiste
			b.t += 1
			b.v = 0.0
			if b.t < 26:
				b.x = stop_x + 6.0 + sin(b.t * .9) * 3.0 * (1.0 - b.t / 26.0)
			if b.t < 60 and b.t % 4 == 0:
				g.PARTS.append({"x": rock.position.x + randf() * 40, "y": gy - 90 - randf() * 120, "vx": randf_range(-1, 1), "vy": 1.0, "life": 30, "col": Color(.97, .98, 1, .95)})
			if b.t == 18 and b.crown:
				b.crown = false
				b.lump = true
				Audio.play("special", -6)
				drop_crown("urso", rock.position.x - 6, gy - 150, 3.2, -4.0, false, rock.end.x + 70.0)
				g.flash("O Urso-Rei entalou na fresta! A coroa dele caiu e rolou para o seu lado. Pegue!", 260)
				for i in 10:
					g.gain_coin(rock.end.x + 40, gy - 60, true)
				p.hp = Game.MAXHP
			if b.t == 26:
				# senta tonto (afasta um pouco da pedra)
				b.x = stop_x - 20.0
				b.landT = 12
				g.shake = max(g.shake, 6)
				Audio.play("stomp", -8)
			if b.t > 84 and b.t < 110:
				# levanta e recua
				b.dir = 1
				b.x -= 1.4
				b.anim += .08
			if b.t == 96:
				Audio.play("roar", -10)
				Polish.snort(b.x + 110, gy - 150, 1.0)
			if b.t > 110:
				b.st = "flee"
				b.t = 0
		"flee":
			# desiste e volta para a toca, sacudindo a neve da cabeça
			b.t += 1
			b.dir = -1
			b.v = move_toward(float(b.v), -3.4, .12)
			b.x += float(b.v)
			b.anim += abs(float(b.v)) * .05
			if b.t > 260 or b.x < float(b.den):
				b.done = true
				b.active = false
	# encostar no urso machuca
	if b.st in BEAR_CHASE and not b.won and p.dyingT == 0 and Game.hit(p, bear_box()):
		_bear_dmg()

## anda com a velocidade atual: arrebenta troncos e galho no caminho e nunca passa da rocha
func _bear_move() -> void:
	var b: Dictionary = BEAR
	var nx: float = b.x + float(b.v)
	nx = clamp(nx, float(b.x0), float(b.rock.x) - 100.0)
	var front: float = nx + b.dir * 86.0
	for o in BOBS:
		if o.get("fallen") or abs(o.x + o.w / 2.0 - b.x) > 400:
			continue
		if front > o.x - 4 and front < o.x + o.w + 4 or (nx - 70 < o.x + o.w and nx + 70 > o.x):
			_bear_smash(o)
	b.x = nx
	b.anim += abs(float(b.v)) * .05

## a coroa saltou: o urso empurra mais um pouco e desiste
func _bear_jam() -> void:
	var b: Dictionary = BEAR
	b.st = "jam"
	b.t = 0
	b.v = 0.0
	b.hp = 0
	g.shake = 20
	g.shake_dir = Vector2(1, 0)
	g.hit_stop = 6
	Audio.play("stomp")
	Audio.play("thunder", -8)
	Audio.vib(140)
	Polish.final_blow()
	var rx: float = float(b.rock.x)
	Polish.debris(rx - 60, rx + 160, b.gy, 18)
	g.burst(rx, b.gy - 100, 26, Color(.95, .97, 1))
	g.fx("fx_pieces", rx + 4, b.gy - 120, 20, .4, -.3)

# ======================================================================
#  BAGRE-REI
# ======================================================================
func fish_box() -> Dictionary:
	return g.R(FISH.x - 120, FISH.y - 46, 240, 92)

## as 4 escamas azuis pintadas em cada quadro do bagre.png (em relação ao centro do bagre, olhando
## para a direita): 0-3 nadando, 4 sugando, 5 cansado; "bite" = fish_bite.png (o bote)
const FISH_SC := {
	0: [Vector2(-1, 7.5), Vector2(22.8, 8.4), Vector2(33.6, -5.5), Vector2(44.4, 3.4)],
	1: [Vector2(-6.4, -0.8), Vector2(16.4, 2), Vector2(27.8, -11), Vector2(36.6, -0.8)],
	2: [Vector2(-1.5, 3), Vector2(21.2, 5.5), Vector2(32.4, -7.6), Vector2(41.4, 2.8)],
	3: [Vector2(0.1, 6.9), Vector2(23.4, 8), Vector2(34.1, -5.6), Vector2(44.5, 3.5)],
	4: [Vector2(-21.4, 2.7), Vector2(-5, 5), Vector2(1.6, -11.6), Vector2(8.7, -0.8)],
	5: [Vector2(-10.6, 5.2), Vector2(12.3, 6.5), Vector2(22.3, -6.9), Vector2(31.6, 2.7)],
	"bite": [Vector2(-6.7, 7.2), Vector2(17, 7.4), Vector2(24.8, -7.4), Vector2(36.7, 1.4)],
}
## centro da coroa pintada em cada quadro do bagre.png (em relação ao centro, olhando para a direita):
## a coroa de pérolas é desenhada por cima dela ("bite" = fish_bite.png). O quadro 6 (vencido) já não tem coroa
const FISH_CROWN := {0: Vector2(79, -28), 1: Vector2(75, -29), 2: Vector2(80, -26), 3: Vector2(79, -27), 4: Vector2(54, -37),
	5: Vector2(72, -27), "bite": Vector2(72, -33.5)}
## pintas do Sapo-Rei (o desenho não tem pintas próprias: são desenhadas por cima, no peito)
const FROG_SC := [Vector2(-1, 7), Vector2(23, 8), Vector2(34, -6), Vector2(44, 3)]

## posição das escamas no desenho do quadro k (olhando para a direita)
func scale_local(k) -> Array:
	if FISH.get("skin", "fish") == "frog":
		return FROG_SC
	return FISH_SC.get(k, FISH_SC[0])

## escamas que brilham (pontos fracos), em coordenadas do mundo
func scale_pts() -> Array:
	var out := []
	var f: Dictionary = FISH
	# cansado o desenho é o quadro 5 (as escamas ficam mais para trás que nadando)
	for p in scale_local(5 if f.st == "tired" else 0):
		out.append(Vector2(f.x + p.x * f.dir, f.y + p.y))
	return out

func fish_weak() -> bool:
	return not FISH.is_empty() and FISH.st == "tired"

func _fish() -> void:
	if FISH.get("skin", "") == "frog":
		Ep2Bosses.frog_step(g, self)
		return
	if FISH.is_empty() or FISH.done:
		return
	var f: Dictionary = FISH
	var p: Dictionary = g.player
	var pc := Vector2(p.x + p.w / 2, p.y + p.h / 2)
	if f.red > 0:
		f.red -= 1
	if f.get("hitT", 0) > 0:
		f.hitT -= 1
	f.mud = max(0.0, f.mud - .004)
	f.al = move_toward(f.al, .25 if f.mud > .45 and f.st in ["mud", "lurk"] else 1.0, .03)
	var mid: float = (f.y0 + f.y1) / 2.0
	match f.st:
		"wait":
			if pc.x > f.trig and pc.x < f.x1 and pc.y > f.y0 and p.swim and p.dyingT == 0:
				if not g.NT.helmet:
					if not g.L.get("_fish_air", false):
						g.L["_fish_air"] = true
						g.flash("Algo enorme se mexe no escuro... Sem ar de sobra não dá para ficar aqui!", 200)
					return
				f.active = true
				f.st = "intro"
				f.t = 0
				f.x = f.x1 + 120.0
				f.y = mid
				f.hp = f.maxhp
				f.scales = [true, true, true, true]
				_gate("fishL", true, Rect2(f.x0 - 24, f.y0, 24, f.y1 - f.y0))
				_gate("fishR", true, Rect2(f.x1, f.y0, 24, f.y1 - f.y0))
				Audio.play("thunder", -8)
				if f.skin == "frog":
					g.start_cine("sapo", (f.x0 + f.x1) / 2.0 + 120, mid, 250,
						[[150, 245, "TOMÉ", "Um sapo do tamanho de uma carroça! As pintas que brilham devem ser o ponto fraco.", "tome"]],
						[60, 150, "SAPO-REI", "o dono do lago do moinho"])
				else:
					g.start_cine("bagre", (f.x0 + f.x1) / 2.0 + 120, mid, 250,
						[[150, 245, "TOMÉ", "Um bagre do tamanho de um barco! As escamas que brilham devem ser o ponto fraco.", "tome"]],
						[60, 150, "BAGRE-REI", "o rei do lago escuro"])
			return
		"intro":
			f.t += 1
			f.dir = -1
			f.x = lerpf(f.x, f.x1 - 170, .04)
			if f.t > 60:
				f.st = "idle"
				f.t = 0
		"idle":
			f.t += 1
			# só vira quando o Tomé passa bem do outro lado (sem ficar tremendo de um lado para o outro)
			if abs(pc.x - f.x) > 60:
				f.dir = 1 if pc.x > f.x else -1
			f.y = lerpf(f.y, clamp(pc.y, f.y0 + 70, f.y1 - 70), .02)
			f.vx = move_toward(float(f.get("vx", 0.0)), f.dir * .5, .05)
			f.x += f.vx
			f.x = clamp(f.x, f.x0 + 130, f.x1 - 130)
			if f.t > 70:
				f.t = 0
				var att: Array = ["charge", "suck", "mud"]
				f.st = att[f.cyc % 3]
				f.cyc += 1
				if f.st == "charge":
					f.st = "aim"
		"aim":
			f.t += 1
			if abs(pc.x - f.x) > 40:
				f.dir = 1 if pc.x > f.x else -1
			if f.t < 28:
				f.y = lerpf(f.y, clamp(pc.y, f.y0 + 60, f.y1 - 60), .08)
			else:
				# antecipação: recua um pouco, encolhido, antes do bote
				f.x = clamp(f.x - f.dir * .9, f.x0 + 130, f.x1 - 130)
			if f.t > 44:
				f.st = "charge"
				f.t = 0
				f.vx = 0.0
				Audio.play("roar", -12)
				Polish.roar(f.x + f.dir * 110, f.y)
		"charge":
			f.t += 1
			f.vx = move_toward(f.vx, f.dir * 9.0, .7)
			f.x += f.vx
			if p.dyingT == 0 and Game.hit(p, fish_box()):
				g.hurt(1, f.x)
			if f.x - 120 < f.x0 or f.x + 120 > f.x1:
				f.x = clamp(f.x, f.x0 + 120, f.x1 - 120)
				g.shake = 12
				Audio.play("stomp", -4)
				g.burst(f.x + f.dir * 120, f.y, 16, Color(.6, .7, .7))
				f.hitT = 16
				f.kb = 4.0
				_tired(f, 170)
		"suck":
			f.t += 1
			f.dir = 1 if pc.x > f.x else -1
			f.mouth = min(1.0, f.mouth + .05)
			var mouth := Vector2(f.x + f.dir * 118, f.y + 6)
			if f.t > 30 and f.t < 190 and p.swim:
				var d: Vector2 = mouth - pc
				var k: float = clamp(1.0 - d.length() / 700.0, 0.0, 1.0)
				p.vx += sign(d.x) * .42 * k
				p.vy += sign(d.y) * .12 * k
				if g.T % 4 == 0:
					g.X.BUB.append({"x": pc.x + (randf() - .5) * 120, "y": pc.y + (randf() - .5) * 80, "t": 0, "top": f.y0})
				if d.length() < 46 and p.dyingT == 0:
					g.hurt(1, mouth.x)
					p.vx = -f.dir * 7.0
					p.vy = -2.0
			if f.t > 190:
				f.mouth = 0.0
				_tired(f, 150)
		"mud":
			f.t += 1
			f.y = lerpf(f.y, f.y1 - 60, .06)
			if f.t % 6 == 0:
				f.mud = min(1.0, f.mud + .08)
			if f.t > 90:
				f.st = "lurk"
				f.t = 0
		"lurk":
			# escondido na lama, sobe de surpresa por baixo do Tomé
			f.t += 1
			f.x = clamp(lerpf(f.x, pc.x, .03), f.x0 + 130, f.x1 - 130)
			if f.t > 60:
				f.st = "aim"
				f.t = 20
		"tired":
			f.t += 1
			var kb: float = f.get("kb", 0.0)
			if kb > .1:
				f.x = clamp(f.x - f.dir * kb, f.x0 + 120, f.x1 - 120)
				f.kb = kb * .88
			f.y = lerpf(f.y, mid + sin(f.t * .05) * 30, .03)
			if f.t > f.get("tired_t", 150):
				f.st = "idle"
				f.t = 0
		"hurt":
			f.t += 1
			f.x = clamp(f.x - f.dir * 3.0 * (1.0 - f.t / 30.0), f.x0 + 120, f.x1 - 120)
			if f.t > 30:
				f.st = "idle"
				f.t = 0
		"down":
			f.t += 1
			f.y = lerpf(f.y, f.y0 + 30, .02)
			if f.t > 160:
				f.done = true
				f.active = false
				Polish.smoke_cloud(f.x, f.y)
	f.x = clamp(f.x, f.x0 - 200, f.x1 + 200)

func _tired(f: Dictionary, n: int) -> void:
	f.st = "tired"
	f.t = 0
	f.tired_t = n
	f.vx = 0.0
	if not g.L.get("_fish_tip", false):
		g.L["_fish_tip"] = true
		g.flash_tut("Agora: arpão nas escamas!", "Ele cansou! As escamas brilhando são o ponto fraco: mire e aperte GOLPE para o arpão.", 200)

## o arpão acertou alguma coisa do bagre?
func harpoon_hit(hp: Dictionary) -> bool:
	if FISH.is_empty() or FISH.done or not FISH.active or FISH.st == "down" or FISH.get("skin", "") == "frog":
		return false
	var f: Dictionary = FISH
	var tip := Vector2(hp.x, hp.y)
	if f.st == "tired":
		var pts := scale_pts()
		# acerta a escama mais perto do arpão quando ele chega à fileira de escamas
		var best := -1
		var bd := 99999.0
		var inside: bool = Game.hit(g.R(tip.x - 6, tip.y - 4, 12, 8), fish_box())
		for i in 4:
			var dd: float = tip.distance_to(pts[i])
			if f.scales[i] and dd < bd and (dd < 34 or (inside and abs(tip.y - pts[i].y) < 30)):
				bd = dd
				best = i
		for i in ([best] if best >= 0 else []):
			if true:
				f.scales[i] = false
				f.hp -= 1
				f.red = 30
				g.hit_stop = 6
				g.shake = 10
				Audio.play("stomp")
				Audio.play("roar", -10)
				Audio.vib(70)
				g.burst(pts[i].x, pts[i].y, 20, Color("#9ff0ff"))
				if f.hp <= 0:
					f.st = "down"
					f.t = 0
					Polish.final_blow()
					if f.get("skin", "fish") != "frog":
						# a coroa de pérolas escorrega da cabeça e afunda até o fundo do lago
						var ca: Vector2 = FISH_CROWN[5]
						drop_crown("bagre", f.x + ca.x * f.dir, f.y + ca.y + 8, f.dir * .6, .4, true)
					_gate("fishR", false, Rect2())
					_gate("fishL", false, Rect2())
					for k in 10:
						g.gain_coin(f.x, f.y, true)
					g.player.hp = Game.MAXHP
					Audio.play("door", -4)
					g.flash(("O Sapo-Rei" if f.skin == "frog" else "O Bagre-Rei") + " foi vencido! Uma corrente de bolhas se abriu à direita: entre nela para subir.", 280)
				else:
					f.st = "hurt"
					f.t = 0
					g.flash(("Acertou a pinta! " if f.skin == "frog" else "Acertou a escama! ") + "Falta%s %d." % ["m" if f.hp > 1 else "", f.hp], 120)
				return true
	if Game.hit(g.R(tip.x - 6, tip.y - 4, 12, 8), fish_box()):
		Audio.play("unlock", -10)
		g.burst(tip.x, tip.y, 6, Color(.8, .85, .9))
		if not g.L.get("_fish_clank", false):
			g.L["_fish_clank"] = true
			g.note("Clanc! O couro é duro. Espere ele cansar e mire nas escamas que brilham.")
		return true
	return false

## durante a cena de apresentação o chefe entra em cena (senão ficava parado fora da tela)
func cine_step(c: Dictionary) -> void:
	match c.id:
		"gaviao", "morcego":
			# desce das copas (ou do teto da mina) e fica rondando à vista, do lado direito da arena
			var h: Dictionary = HAWK
			if h.is_empty():
				return
			h.x = lerpf(h.x, h.x1 - 200.0, .03)
			# (o morcego é desenhado mais acima do ponto de apoio: desce um pouco mais)
			var hy: float = h.gy - (165.0 if h.get("skin", "hawk") == "bat" else 200.0)
			h.y = lerpf(h.y, hy + sin(c.t * .07) * 10.0, .035)
			h.dir = -1
		"bagre", "sapo":
			# sai de trás do muro nadando devagar até o meio da arena (a cena "intro" continua depois)
			var f: Dictionary = FISH
			if f.is_empty() or f.get("skin", "") == "frog":
				return
			f.dir = -1
			f.x = lerpf(f.x, f.x1 - 170.0, .035)
		"urso":
			# o urso chega correndo de fora da tela, se ergue e ruge; a câmera mostra o urso e o Tomé
			var b: Dictionary = BEAR
			if b.is_empty():
				return
			b.dir = 1
			if c.t < 60:
				b.x = lerpf(b.x, g.player.x - 300.0, .07)
				b.anim += .06
				b.st = "intro"
			elif c.t < 110:
				b.st = "roar"
				b.t = c.t - 60
				if c.t == 68:
					Audio.play("roar", 0)
					Polish.roar(b.x + 80, b.gy - 170)
					g.shake = max(g.shake, 10)
			else:
				b.st = "intro"
		"urso_fim":
			# o Tomé passou pela fresta: a cena mostra o urso chegando, entalando e perdendo a coroa
			_bear()
			_crowns()

func cine_end(id: String) -> void:
	match id:
		"gaviao":
			g.tip("Fuja da sombra! Se ele errar, acerte com a picareta. O facho (segure ✦) ofusca o gavião.", 220)
		"urso":
			if not BEAR.is_empty() and BEAR.st in ["intro", "roar"]:
				BEAR.st = "chase"
				BEAR.t = 0
			g.flash_tut("CORRA até a fresta da rocha!", "Fuja! Pule os troncos, abaixe (↓) sob o tronco atravessado, fuja da sombra dos pingentes e entre abaixado na fresta da rocha: o urso não cabe!", 240)
		"bagre":
			g.tip("Com o capacete você não perde fôlego. Fuja das investidas e use o arpão (GOLPE) nas escamas brilhantes.", 220)
		"sapo":
			g.flash_tut("Faça a língua grudar nas colmeias!", "Quando a mira brilhar em você, fique na frente de uma colmeia e desvie no último instante (pule!): a língua gruda na colmeia, as abelhas atacam o Sapo-Rei e ele fica tonto. Aí, pule na cabeça dele! 3 colmeias.", 300)
		"morcego":
			g.flash_tut("Acenda as 3 lamparinas!", "No escuro o Morcego-Rei some e ataca (o chiado e os olhos vermelhos avisam o rasante). Suba nas plataformas e acenda as 3 lamparinas com ✦ USAR: na luz ele não chega perto.", 300)

func reset_on_respawn() -> void:
	# já vencido (fugindo ou caído): não revive — conta como derrotado
	for B in [HAWK, BEAR, FISH]:
		if not B.is_empty() and not B.done and B.active and (B.hp <= 0 or B.st in ["flee", "down"]):
			B.done = true
			B.active = false
			B.waves = []
	if not HAWK.is_empty() and HAWK.active and not HAWK.done:
		HAWK.active = false
		HAWK.st = "wait"
		HAWK.hp = HAWK.maxhp
		HAWK.crows = false
		HAWK.second = false
		HAWK.conf = false
		HAWK.red = 0
		HAWK.t = 0
		HAWK.x = (HAWK.x0 + HAWK.x1) / 2.0
		HAWK.y = HAWK.gy - 340.0
		_zero(HAWK)
		_gate("hawkL", false, Rect2())
		_gate("hawkR", false, Rect2())
		for e in g.EN:
			if e.get("minion"):
				e.dead = 99
	if bear_on():
		BEAR.active = false
		BEAR.st = "wait"
		BEAR.hp = BEAR.maxhp
		BEAR.red = 0
		BEAR.t = 0
		BEAR.dir = 1
		BEAR.v = 0.0
		BEAR.rt = -1
		BEAR.won = false
		BEAR.x = float(BEAR.den)
		_zero(BEAR)
		_bear_obs_reset()
	# rei vencido que não chegou a soltar a coroa (o Tomé caiu no meio da cena): ela fica no lugar
	_crown_fallback()
	if not FISH.is_empty() and FISH.active and not FISH.done:
		FISH.active = false
		FISH.st = "wait"
		FISH.hp = FISH.maxhp
		FISH.mud = 0.0
		FISH.red = 0
		FISH.t = 0
		FISH.dir = -1
		FISH.x = FISH.x1 - 160.0
		FISH.y = (FISH.y0 + FISH.y1) / 2.0
		FISH.scales = [true, true, true, true]
		_zero(FISH)
		_gate("fishL", false, Rect2())
		_gate("fishR", false, Rect2())
	# Ep. 2: lamparinas apagam, colmeias voltam, o sapo volta para a vitória-régia
	Ep2Bosses.on_respawn(g, self)

## zera velocidades e estados de movimento que ficaram da luta anterior
func _zero(B: Dictionary) -> void:
	for k in ["vx", "vy", "mouth", "wv", "cv", "hy", "hcr", "tv", "kb", "hitT", "landT", "anim", "skid"]:
		if B.has(k):
			B[k] = 0.0 if typeof(B[k]) == TYPE_FLOAT else 0
	if B.has("waves"):
		B.waves = []

func save_data() -> Dictionary:
	var cr: Array = []
	for c in CROWNS:
		if c.st in ["fall", "rest"]:
			cr.append({"id": c.id, "x": c.get("to", c.x) if c.has("to") else c.x, "y": c.fy if c.st == "fall" else c.y, "water": c.water})
	return {"hawk": _beaten(HAWK), "fish": _beaten(FISH), "bear": _beaten(BEAR), "crowns": cr, "took": TOOK.keys()}

## vencido conta mesmo se ainda estiver fugindo/caindo no instante do salvamento
func _beaten(B: Dictionary) -> bool:
	if B.is_empty():
		return false
	return B.get("done", false) or (B.get("active", false) and (int(B.get("hp", 1)) <= 0 or B.get("st", "") in ["flee", "down"]))

func restore(d: Dictionary) -> void:
	if d.get("hawk", false) and not HAWK.is_empty():
		HAWK.done = true
	if d.get("fish", false) and not FISH.is_empty():
		FISH.done = true
	if d.get("bear", false) and not BEAR.is_empty():
		BEAR.done = true
		BEAR.crown = false
	for k in d.get("took", []):
		TOOK[str(k)] = true
	CROWNS = []
	for c in d.get("crowns", []):
		_put_crown(str(c.id), float(c.x), float(c.y), bool(c.get("water", false)))
	if not d.has("crowns"):
		# jogo salvo de antes das coroas: o rei vencido deixa a coroa no meio da arena
		_crown_fallback()

# ======================================================================
#  COROAS DOS REIS (colecionáveis)
# ======================================================================
## a coroa de um rei saltou da cabeça: cai (ou afunda, na água), quica, para no chão e fica
## brilhando até o Tomé pegar. "to": desliza pelo chão até ali (a do urso rola pela fresta)
func drop_crown(id: String, x: float, y: float, vx: float, vy: float, water: bool = false, to: float = -1.0) -> void:
	for c in CROWNS:
		if c.id == id:
			return
	DROPPED[id] = true
	var c := {"id": id, "x": x, "y": y, "vx": vx, "vy": vy, "rot": 0.0, "vr": vx * .06, "st": "fall", "t": 0, "water": water}
	c.fy = _crown_floor(x, y)
	if to > 0:
		c.to = to
	CROWNS.append(c)

## coroa já parada no chão (jogo salvo)
func _put_crown(id: String, x: float, y: float, water: bool) -> void:
	if TOOK.has(id):
		return
	DROPPED[id] = true
	for c in CROWNS:
		if c.id == id:
			return
	CROWNS.append({"id": id, "x": x, "y": y, "vx": 0.0, "vy": 0.0, "rot": 0.0, "vr": 0.0, "st": "rest", "t": 0, "water": water, "fy": y})

## chão embaixo da coroa (o primeiro sólido de cima para baixo; troncos arrebentados não contam)
func _crown_floor(x: float, y: float) -> float:
	var best := INF
	for s in g.SOL:
		if s.get("fallen") or s.get("ghost") or s.t in ["kinggate", "bossgate"]:
			continue
		if x >= s.x and x <= s.x + s.w and s.y >= y - 2 and s.y < best:
			best = s.y
	return best if best < INF else y + 300.0

## reis vencidos sem coroa no mundo e não pegos: a coroa aparece parada no meio da arena
func _crown_fallback() -> void:
	var have: Dictionary = DROPPED.duplicate()
	for k in TOOK:
		have[k] = true
	var X = g.X
	if X and not X.BOSS.is_empty() and X.BOSS.get("skin", "boar") == "boar" and (X.BOSS.done or X.BOSS.get("st", "") == "down") and not have.has("javali"):
		_put_crown("javali", float(X.BOSS.item[0]), 500.0, false)
	if not HAWK.is_empty() and HAWK.get("skin", "hawk") == "hawk" and _beaten(HAWK) and not have.has("gaviao"):
		_put_crown("gaviao", (HAWK.x0 + HAWK.x1) / 2.0, HAWK.gy, false)
	if not FISH.is_empty() and FISH.get("skin", "fish") == "fish" and _beaten(FISH) and not have.has("bagre"):
		var fx: float = (FISH.x0 + FISH.x1) / 2.0
		_put_crown("bagre", fx, _crown_floor(fx, FISH.y0), true)
	if not BEAR.is_empty() and _beaten(BEAR) and not have.has("urso"):
		BEAR.crown = false
		BEAR.lump = true
		_put_crown("urso", float(BEAR.rock.x) + float(BEAR.rock.w) + 70.0, BEAR.gy, false)

func _crowns() -> void:
	if CROWNS.is_empty():
		return
	var p: Dictionary = g.player
	var pcx: float = p.x + p.w / 2
	for c in CROWNS:
		c.t += 1
		match c.st:
			"fall":
				if c.water:
					# afunda devagar, balançando como uma folha
					c.vy = min(c.vy + .05, 1.5)
					c.vx *= .96
					c.x += c.vx + sin(c.t * .07) * .7
					c.rot = sin(c.t * .06) * .45
				else:
					c.vy = min(c.vy + .42, 12.0)
					c.x += c.vx
					c.rot += c.vr
				c.y += c.vy
				if c.t % 4 == 0:
					c.fy = _crown_floor(c.x, c.y - 30)
				if c.y >= c.fy:
					c.y = c.fy
					if not c.water and c.vy > 3.6:
						# quica e perde força
						c.vy = -c.vy * .38
						c.vx *= .6
						c.vr = -c.vr * .5
						Audio.play("stomp", -18)
						g.burst(c.x, c.y - 2, 5, Color(1, .9, .5))
					else:
						c.st = "rest"
						c.t = 0
						c.vy = 0.0
						Audio.play("pen", -6)
						g.burst(c.x, c.y - 10, 10, Color(1, .9, .5))
						if c.water:
							for i in 5:
								g.X.BUB.append({"x": c.x + randf_range(-14, 14), "y": c.y - 8, "t": 0, "top": c.y - 400})
			"rest":
				# rolando pela fresta até o lado do Tomé
				if c.has("to"):
					c.x = move_toward(c.x, float(c.to), max(.6, abs(float(c.to) - c.x) * .07))
					c.rot = lerpf(c.rot, sin(c.x * .12) * .25 if abs(float(c.to) - c.x) > 2 else 0.0, .3)
					if abs(float(c.to) - c.x) < .5:
						c.erase("to")
				else:
					c.rot = lerpf(c.rot, 0.0, .15)
				if p.dyingT == 0 and not p.get("dog") and Game.hit(p, g.R(c.x - 24, c.y - 40, 48, 44)):
					_take_crown(c)
			"lift":
				# o Tomé pega e ergue a coroa bem alto, comemorando
				var u: float = clamp(c.t / 16.0, 0.0, 1.0)
				var hx: float = p.x + p.w / 2
				var hy: float = p.y - 18.0 - 6.0 * sin(c.t * .2)
				c.x = lerpf(c.x0, hx, smoothstep(0.0, 1.0, u))
				c.y = lerpf(c.y0, hy, smoothstep(0.0, 1.0, u)) - sin(u * PI) * 30.0
				c.rot = sin(c.t * .3) * .12 * (1.0 - u)
				if c.t == 16:
					Polish.celebrate(pcx, p.y + 10)
					Audio.play("clue")
				if c.t > 74:
					c.st = "got"
					g.burst(c.x, c.y - 10, 22, Color(1, .88, .4))
					Audio.play("pen", -4)
	CROWNS = CROWNS.filter(func(c): return c.st != "got")

func _take_crown(c: Dictionary) -> void:
	var p: Dictionary = g.player
	c.st = "lift"
	c.t = 0
	c.x0 = c.x
	c.y0 = c.y
	c.erase("to")
	TOOK[c.id] = true
	var first: bool = not Save.getv("gallery", "crown_" + str(c.id), false)
	Save.setv("gallery", "crown_" + str(c.id), true)
	Audio.play("special")
	Audio.vib(90)
	p.cheerT = 74
	g.burst(c.x, c.y - 12, 20, Color(1, .9, .5))
	var nm: String = WorldKings.CROWN_NAME.get(c.id, "Coroa")
	var kg: String = WorldKings.CROWN_KING.get(c.id, "rei")
	g.flash(("%s do %s! Uma nova coroa na sua coleção (veja na Galeria)." if first else "%s do %s! Ela já estava na sua coleção.") % [nm, kg], 240)
