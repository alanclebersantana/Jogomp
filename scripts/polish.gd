extends RefCounted
class_name Polish

## true no primeiro desenho depois de um passo da lógica (definido pelo world_dyn)
static var FRESH := true
## Acabamento visual e de "sensação" (pacote de melhorias sem arte nova):
## partículas com tipos (folha, pena, gota, estrela, fumaça, semente, lasca, esporo, tufo, gelo, pétala),
## e os pequenos sistemas de vida do mundo. Tudo desenhado por código, no traço do jogo.
## Chamado por: Game._tick_fx (tick), WorldDyn (draw_back/draw_mid/draw_front), ScreenFx (draw_screen).

static var g: Game

# ---------------------------------------------------------------- partículas com tipo
## cores prontas
const C_LEAF := [Color(.42, .62, .25), Color(.55, .7, .3), Color(.36, .52, .2)]
const C_LEAF_TARDE := [Color(.93, .62, .2), Color(.85, .38, .16), Color(.95, .78, .3)]
const C_LEAF_PANT := [Color(.3, .38, .2), Color(.4, .42, .22)]

## cria uma partícula com tipo (k). Campos extras: g (gravidade), drag, sway (balanço), vr (giro),
## size, col, glow, wind (quanto o vento empurra), gy (chão para quicar), fade
static func part(k: String, x: float, y: float, vx: float, vy: float, life: int, col: Color, extra: Dictionary = {}) -> void:
	if g == null:
		return
	if g.low_fx and g.PARTS.size() > 140:
		return
	if g.PARTS.size() > 420:
		return
	var p := {"k": k, "x": x, "y": y, "vx": vx, "vy": vy, "life": life, "life0": life, "col": col, "rot": randf() * TAU, "ph": randf() * 100.0}
	match k:
		"leaf", "petal":
			p.g = .035
			p.drag = .97
			p.sway = .12
			p.vr = randf_range(-.12, .12)
			p.wind = .05
			p.size = 4.5 if k == "leaf" else 3.0
		"feather":
			p.g = .02
			p.drag = .96
			p.sway = .09
			p.vr = randf_range(-.05, .05)
			p.wind = .04
			p.size = 6.0
		"drop":
			p.g = .25
			p.size = 1.8
		"star":
			p.g = 0.0
			p.vr = .15
			p.size = 6.0
		"puff":
			p.g = -.02
			p.drag = .95
			p.size = 5.0
			p.grow = .25
			p.wind = .03
		"seed":
			p.g = -.004
			p.drag = .985
			p.sway = .05
			p.wind = .09
			p.size = 3.0
		"chip":
			p.g = .22
			p.vr = randf_range(-.3, .3)
			p.size = 2.5
		"spore":
			p.g = -.012
			p.drag = .97
			p.sway = .04
			p.size = 1.6
			p.glow = 1.0
		"tuft":
			p.g = .03
			p.drag = .96
			p.sway = .1
			p.vr = randf_range(-.1, .1)
			p.size = 3.5
		"ice":
			p.g = .26
			p.vr = randf_range(-.3, .3)
			p.size = 2.6
		"snow":
			p.g = .14
			p.drag = .99
			p.size = 2.6
		"bubble":
			p.g = -.06
			p.drag = .96
			p.sway = .05
			p.size = 2.2
		"line":
			p.g = 0.0
			p.size = 18.0
		"ringw":
			p.g = 0.0
			p.size = 30.0
		"spark":
			p.g = .12
			p.size = 1.4
			p.glow = 1.0
		"dust":
			p.g = -.01
			p.drag = .93
			p.size = 3.0
			p.grow = .12
		"ray":
			p.g = 0.0
			p.size = 22.0
		"txt":
			p.g = 0.0
			p.size = 20.0
	for key in extra:
		p[key] = extra[key]
	g.PARTS.append(p)

## avanço das partículas com tipo (as antigas seguem como estavam)
static func tick_part(p: Dictionary, wind: float) -> void:
	p.vy += float(p.get("g", .18))
	if p.has("drag"):
		p.vx *= p.drag
		p.vy *= p.drag
	if p.has("sway"):
		p.vx += sin((p.life + p.ph) * .16) * p.sway
	if p.has("wind"):
		p.vx += wind * p.wind
	p.x += p.vx
	p.y += p.vy
	p.rot += float(p.get("vr", 0.0))
	p.life -= 1
	if p.has("grow"):
		p.size += p.grow
	if p.has("gy") and p.y > p.gy:
		p.y = p.gy
		if p.k in ["leaf", "petal", "feather", "tuft", "seed"]:
			# pousou: fica parado no chão e some aos poucos
			p.vx = 0.0
			p.vy = 0.0
			p.g = 0.0
			p.vr = 0.0
			p.erase("sway")
			p.erase("wind")
			p.life = min(p.life, 40)
		else:
			p.vy *= -.35
			p.vx *= .6
			if abs(p.vy) < .6:
				p.vy = 0.0
				p.g = 0.0

static func draw_part(p: Dictionary) -> void:
	var c: Color = p.col
	var l0: float = max(1.0, float(p.get("life0", 24)))
	var a: float = c.a * clamp(p.life / min(24.0, l0 * .5), 0, 1)
	var s: float = p.size
	match p.k:
		"leaf", "petal":
			# folha: elipse que vira (o giro mostra a frente e a borda)
			var flip: float = abs(sin(p.rot))
			var lvt: Texture2D = Spr.opt("leaves") if p.k == "leaf" else null
			if lvt:
				# folha pintada (verde, amarela ou laranja, pela cor pedida), virando no ar
				var hu: float = c.h
				var fi: int = 0 if (hu > .17 and hu < .5) else (1 if hu > .1 and hu <= .17 else 2)
				Spr.save()
				Spr.translate(p.x, p.y)
				Spr.rotate(p.rot * .5)
				Spr.scale(1.0, .35 + .65 * flip)
				var lw: float = s * 2.8
				var lv: float = clamp(c.v / .62, .55, 1.1)   # brejo: folhas mais escuras
				Spr.ci.draw_texture_rect_region(lvt, Rect2(-lw / 2, -lw / 2, lw, lw), Rect2(fi * 64, 0, 64, 64), Color(lv, lv, lv, a * Spr.alpha))
				Spr.restore()
				return
			Spr.save()
			Spr.translate(p.x, p.y)
			Spr.rotate(p.rot * .5)
			Spr.ellipse(0, 0, s, max(.8, s * .45 * (.35 + .65 * flip)), Color(c.r, c.g, c.b, a))
			if p.k == "leaf" and s > 3:
				Spr.seg(-s * .8, 0, s * .8, 0, Color(c.r * .7, c.g * .7, c.b * .6, a * .7), .8)
			Spr.restore()
		"feather":
			Spr.save()
			Spr.translate(p.x, p.y)
			Spr.rotate(p.rot + sin(p.life * .1) * .5)
			Spr.ellipse(0, 0, s, s * .28, Color(c.r, c.g, c.b, a))
			Spr.seg(-s, 0, s * 1.1, 0, Color(c.r * .6, c.g * .6, c.b * .6, a), .8)
			Spr.restore()
		"drop":
			Spr.ellipse(p.x, p.y, s * .8, s * 1.2, Color(c.r, c.g, c.b, a))
			Spr.circle(p.x - s * .3, p.y - s * .4, s * .35, Color(1, 1, 1, a * .6))
		"star":
			Spr.text("★", p.x, p.y + s * .5, int(s * 2.2), Color(c.r, c.g, c.b, a), HORIZONTAL_ALIGNMENT_CENTER, Spr.font_b, 2)
		"puff", "dust":
			Spr.circle(p.x, p.y, s, Color(c.r, c.g, c.b, a * .5))
			Spr.circle(p.x + s * .3, p.y - s * .25, s * .6, Color(c.r, c.g, c.b, a * .35))
		"seed":
			Spr.seg(p.x, p.y, p.x, p.y + s * 1.6, Color(.85, .82, .7, a), .7)
			Spr.circle(p.x, p.y, s * .7, Color(1, 1, 1, a * .55))
			for i in 5:
				var an: float = -PI / 2 + (i - 2) * .45
				Spr.seg(p.x, p.y, p.x + cos(an) * s * 1.2, p.y + sin(an) * s * 1.2, Color(1, 1, 1, a * .7), .5)
		"chip":
			Spr.save()
			Spr.translate(p.x, p.y)
			Spr.rotate(p.rot)
			Spr.rect(-s, -s * .35, s * 2, s * .7, Color(c.r, c.g, c.b, a))
			Spr.restore()
		"spore", "spark":
			Spr.glow(p.x, p.y, s * 5.0, Color(c.r, c.g, c.b, a * .35))
			Spr.circle(p.x, p.y, s, Color(c.r, c.g, c.b, a))
		"tuft":
			Spr.save()
			Spr.translate(p.x, p.y)
			Spr.rotate(p.rot)
			for i in 3:
				Spr.ellipse((i - 1) * s * .5, 0, s * .6, s * .25, Color(c.r, c.g, c.b, a))
			Spr.restore()
		"ice":
			Spr.save()
			Spr.translate(p.x, p.y)
			Spr.rotate(p.rot)
			Spr.ci.draw_colored_polygon(PackedVector2Array([Vector2(0, -s), Vector2(s * .7, s * .6), Vector2(-s * .7, s * .6)]), Spr.col(Color(c.r, c.g, c.b, a)))
			Spr.restore()
		"snow":
			Spr.circle(p.x, p.y, s, Color(c.r, c.g, c.b, a))
		"bubble":
			Spr.ring(p.x, p.y, s, Color(c.r, c.g, c.b, a), 1.0)
			Spr.circle(p.x - s * .35, p.y - s * .35, s * .3, Color(1, 1, 1, a * .7))
		"line":
			# risco de vento / velocidade
			var len: float = s
			var dx: float = p.get("dx", 1.0)
			Spr.seg(p.x, p.y, p.x - dx * len, p.y + sin(p.ph + p.life * .2) * 2.0, Color(c.r, c.g, c.b, a), float(p.get("w", 1.6)))
		"ringw":
			var u: float = 1.0 - p.life / l0
			Spr.ring(p.x, p.y, s * u + 4, Color(c.r, c.g, c.b, a * (1.0 - u)), 2.5)
		"txt":
			Spr.text(str(p.get("txt", "")), p.x, p.y, int(s), Color(c.r, c.g, c.b, a), HORIZONTAL_ALIGNMENT_CENTER, Spr.font_b, 4, Color(.25, .12, 0, a * .9))
		"ray":
			# raio de impacto: sai do centro e some
			var u2: float = 1.0 - p.life / l0
			var an: float = float(p.get("ang", 0.0))
			var dv := Vector2(cos(an), sin(an))
			var r0: float = s * (.25 + u2 * .9)
			var r1: float = s * (.55 + u2 * 1.1)
			Spr.seg(p.x + dv.x * r0, p.y + dv.y * r0, p.x + dv.x * r1, p.y + dv.y * r1, Color(c.r, c.g, c.b, a * (1.0 - u2 * .7)), float(p.get("w", 2.6)) * (1.0 - u2 * .6))
		_:
			Spr.rect(p.x, p.y, 3, 3, Color(c.r, c.g, c.b, a))

## cor das folhas do trecho
static func leaf_col() -> Color:
	var song: String = g.AMB.get("song", "manha") if g else "manha"
	if song == "tarde":
		return C_LEAF_TARDE[randi() % C_LEAF_TARDE.size()]
	if song in ["chuva", "pantano"]:
		return C_LEAF_PANT[randi() % C_LEAF_PANT.size()]
	return C_LEAF[randi() % C_LEAF.size()]

# ================================================================ passo de simulação
## fase nova: esquece o estado da anterior
static func reset(game: Game) -> void:
	g = game
	_last_T = -1
	blasts = []
	crowns = []
	flat_zones = []
	cut = {}
	flash_white = 0
	_push_T = -1
	_push = []

static var _last_T := -1
static func tick(game: Game) -> void:
	g = game
	if g.L == null or g.player.is_empty():
		return
	if g.T == _last_T:
		return
	_last_T = g.T
	_tick_player()
	_tick_bosses()
	_tick_grass()

## período do trecho (manha, tarde, chuva, neve, noite, tunel...)
static func period() -> String:
	if g == null or g.L == null:
		return "manha"
	var s: String = g.AMB.get("song", "manha")
	if g.AMB.get("snow", 0.0) > .3:
		return "neve"
	if s == "perseguicao":
		return "noite"
	if s == "tema":
		return "neve"
	return s

static func ground_col() -> Color:
	var gk: String = g.ground_kind()
	if gk == "snow":
		return Color(.95, .97, 1, .8)
	if gk == "grass":
		return Color(.55, .62, .4, .55)
	if gk == "mud":
		return Color(.35, .27, .18, .7)
	if gk == "wood":
		return Color(.6, .48, .33, .5)
	return Color(.66, .58, .45, .55)

# ---------------------------------------------------------------- Tomé e companhia
static var _face_hold := 0
static func _tick_player() -> void:
	var p: Dictionary = g.player
	var fx: float = p.x + p.w / 2
	var fy: float = p.y + p.h
	# P1 freada: poeira saindo dos pés a cada passo da derrapagem
	if p.get("skidT", 0) > 0 and p.onGround and g.T % 2 == 0:
		part("dust", fx + sign(p.vx) * 6, fy - 2, sign(p.vx) * randf_range(.6, 1.6), -randf_range(.2, .8), 22, ground_col())
	# P4 encara o perigo: parado um tempinho, vira o corpo para o bicho mais perto
	if p.onGround and abs(p.vx) < .2 and p.get("idleT", 0) > 25 and not g.keys.get("L", false) and not g.keys.get("R", false) and not p.get("dog", false):
		var best := 9999.0
		var bx := 0.0
		for e in g.EN:
			if e.dead:
				continue
			var dx: float = e.x - fx
			if abs(dx) < 240 and abs(e.y - fy) < 110 and abs(dx) < best:
				best = abs(dx)
				bx = dx
		var b: Dictionary = g.X.BOSS if g.X else {}
		if not b.is_empty() and b.get("active", false) and not b.get("done", false):
			var dxb: float = b.x - fx
			if abs(dxb) < 400 and abs(dxb) < best:
				best = abs(dxb)
				bx = dxb
		if best < 9999.0 and abs(bx) > 12:
			_face_hold += 1
			if _face_hold > 8:
				p.face = 1 if bx > 0 else -1
		else:
			_face_hold = 0
	else:
		_face_hold = 0
	# P6 dano: o clarão some aos poucos
	if p.get("hitFx", 0) > 0:
		p.hitFx -= 1
	if p.get("cheerT", 0) > 0:
		p.cheerT -= 1
	if p.dyingT > 0 or p.get("dog", false):
		return
	var T: int = g.T
	# E4 linhas de velocidade correndo no máximo
	if p.onGround and p.get("run", 0) and abs(p.vx) > 4.6 and T % 3 == 0 and not p.swim:
		var d: float = sign(p.vx)
		part("line", fx - d * randf_range(14, 30), p.y + randf_range(4, p.h - 6), 0, 0, 9, Color(1, .98, .9, .42), {"dx": d, "size": randf_range(16, 30), "w": 1.6})
	# E7 rastro do planar: fiapos de ar atrás do guarda-chuva
	if p.puff and T % 4 == 0:
		part("puff", fx - sign(p.vx + .01) * 10 + randf_range(-6, 6), p.y + 4, -p.vx * .2, .25, 22, Color(1, 1, 1, .35), {"size": 3.0, "grow": .15})
	# Z9 de barriga no gelo/neve: brilhinhos
	if p.get("belly", false) and p.get("slideT", 0) and abs(p.vx) > 2.0 and T % 4 == 0:
		part("spark", fx - sign(p.vx) * 8, fy - 3, -p.vx * .2, -randf_range(.4, 1.2), 18, Color(.92, .97, 1), {"g": .06, "size": 1.2})
	# N2 parado há muito tempo (sem perigo perto): olha para os lados de vez em quando
	var it: int = int(p.get("idleT", 0))
	if _face_hold == 0 and it > 420 and not p.get("isis", false):
		var ph: int = (it - 420) % 360
		if ph == 0:
			p._look0 = p.face
		elif ph == 70 and p.has("_look0"):
			p.face = -int(p._look0)
		elif ph == 150 and p.has("_look0"):
			p.face = int(p._look0)
	elif it == 0 and p.has("_look0"):
		p.erase("_look0")

## E2 impacto: raios saindo do ponto do golpe
static func impact(x: float, y: float, col: Color = Color(1, .96, .82), n: int = 7, size: float = 22.0) -> void:
	if g == null:
		return
	var a0: float = randf() * TAU
	for i in n:
		part("ray", x, y, 0, 0, 10, col, {"ang": a0 + TAU * i / n + randf_range(-.15, .15), "size": size * randf_range(.8, 1.2)})
	part("ringw", x, y, 0, 0, 12, Color(col.r, col.g, col.b, .8), {"size": size * 1.6})

## E3 pouso leve: duas nuvenzinhas para os lados
static func land_soft(x: float, y: float, v: float) -> void:
	var c := ground_col()
	for d in [-1.0, 1.0]:
		part("dust", x + d * 6, y - 2, d * (.6 + v * .12), -.3, 18, c, {"size": 2.4 + v * .2})
	# Z8 pouso na neve/gelo: lasquinhas e pó de neve
	if g.ground_kind() == "snow":
		for i in 5:
			part("snow", x + randf_range(-10, 10), y - 2, randf_range(-1.6, 1.6), -randf_range(.8, 2.2), 30, Color(.97, .98, 1, .9), {"gy": y, "size": randf_range(1.4, 2.4)})
		var gs = g.player.get("_g")
		if gs is Dictionary and (str(gs.get("t", "")) == "ice" or gs.get("ice")):
			for i in 4:
				part("ice", x + randf_range(-8, 8), y - 2, randf_range(-2, 2), -randf_range(1.5, 3.0), 34, Color(.8, .93, 1, .9), {"gy": y})

## E9 onda de choque do mergulho
static func slam_wave(x: float, y: float) -> void:
	part("ringw", x, y - 3, 0, 0, 18, Color(1, .95, .8, .8), {"size": 90.0})
	part("ringw", x, y - 3, 0, 0, 26, Color(1, .9, .7, .4), {"size": 150.0})
	var c := ground_col()
	for i in 10:
		var d: float = -1.0 if i % 2 == 0 else 1.0
		part("dust", x + d * randf_range(6, 20), y - 3, d * randf_range(2.0, 4.5), -randf_range(.2, 1.0), 28, c, {"size": randf_range(3.5, 6.0)})
	for i in 5:
		part("chip", x + randf_range(-14, 14), y - 4, randf_range(-3, 3), -randf_range(2.5, 5.0), 60, Color(.5, .42, .32), {"gy": y})

## E5 pulo duplo: anel de ar debaixo dos pés
static func air_ring(x: float, y: float) -> void:
	part("ringw", x, y + 2, 0, 0, 14, Color(1, 1, 1, .75), {"size": 34.0})

## E8 pegou lápis: anel dourado curto e duas faíscas
static func pickup(x: float, y: float) -> void:
	part("ringw", x, y, 0, 0, 12, Color(1, .88, .45, .8), {"size": 26.0})
	for i in 2:
		part("spark", x, y, randf_range(-1.5, 1.5), -randf_range(1.0, 2.2), 20, Color(1, .9, .5), {"g": .05})

## J6 morte com peso: clarão, raios vermelhos e brancos, um instante de câmera lenta
static func death_fx(x: float, y: float) -> void:
	impact(x, y, Color(1, .55, .45), 9, 30.0)
	impact(x, y, Color(1, 1, 1), 5, 18.0)
	flash_white = max(flash_white, 5)
	g.slowmo = max(g.slowmo, 22)

## P7 queda alta: anel de poeira maior e tremor leve
static func land_heavy(x: float, y: float, v: float) -> void:
	var k: float = clamp((v - 10.0) / 4.0, 0, 1)
	part("ringw", x, y - 2, 0, 0, 20, Color(1, .95, .82, .7), {"size": 40.0 + 30.0 * k})
	for i in 8:
		var d: float = -1.0 if i % 2 == 0 else 1.0
		part("dust", x + d * randf_range(4, 14), y - 3, d * randf_range(1.2, 3.2), -randf_range(.3, 1.0), 26, ground_col(), {"size": 4.0 + 2.0 * k})
	g.shake = max(g.shake, 3 + 4 * k)

## P9 brilho dourado ao pegar algo; "happy" = pulinho e pose de comemoração (só nas vitórias de
## verdade: pistas e desenhos da Isis não são motivo de festa — o pai está procurando a filha)
static func celebrate(x: float, y: float, happy: bool = true) -> void:
	var p: Dictionary = g.player
	if happy:
		p.cheerT = 50
		if p.onGround and not p.get("dog", false):
			p.vy = -4.6
			p.onGround = false
	for i in 10:
		var an: float = TAU * i / 10.0
		part("spark", x, y, cos(an) * 2.2, sin(an) * 2.2 - 1.0, 30, Color(1, .86, .4), {"g": .04, "drag": .94})
	part("ringw", x, y, 0, 0, 22, Color(1, .9, .5, .9), {"size": 46.0})

## P10/K2 sombra: esticada para o lado oposto ao sol conforme a hora, e colorida (não preta)
static func shadow_col(a: float) -> Color:
	match period():
		"manha":
			return Color(.1, .12, .3, a)
		"tarde":
			return Color(.28, .08, .22, a)
		"chuva":
			return Color(.04, .16, .1, a)
		"neve":
			return Color(.2, .25, .5, a * .8)
	return Color(.02, .02, .08, a)

static func shadow(x: float, y: float, w: float, h: float, a: float) -> void:
	var off := 0.0
	var st := 1.0
	match period():
		"manha":
			off = w * .3
			st = 1.35
		"tarde":
			off = -w * .55
			st = 1.75
	Spr.ellipse(x + off, y, w * st, h, shadow_col(a))
	if off != 0.0:
		Spr.ellipse(x, y, w * .7, h * .9, shadow_col(a * .6))

# ---------------------------------------------------------------- inimigos
## chão logo abaixo de (x, y): topo do sólido mais alto que fica embaixo (para sombras de quem voa)
static func ground_below(x: float, y: float) -> float:
	var best := 1e9
	for s in g.blockers():
		if s.get("oneway") and s.y < y - 2:
			continue
		if x >= s.x and x <= s.x + s.w and s.y >= y - 2 and s.y < best:
			best = s.y
	return best

## I4 sombra de quem voa: encolhe e clareia com a altura
static func flyer_shadow(e: Dictionary, ox: float) -> void:
	if g.T % 10 == 0 or not e.has("_gyb"):
		e._gyb = ground_below(e.x, e.y + 6)
	var gy: float = e._gyb
	if gy > 1e8:
		return
	var h: float = gy - e.y
	if h < 0 or h > 420:
		return
	var k: float = clamp(1.0 - h / 420.0, .15, 1.0)
	Spr.ellipse(e.x + ox, gy + 1, 22 * k + 4, 4 * k + 1, shadow_col(.28 * k))

## I3 derrota: estrelinhas e tufos de pelo/penas
const FUR := {"crow": Color(.12, .12, .16), "owl": Color(.55, .45, .35), "bat": Color(.35, .3, .35), "squirrel": Color(.75, .45, .22),
	"boar": Color(.4, .3, .22), "frog": Color(.4, .7, .3), "spider": Color(.25, .22, .25), "mole": Color(.35, .28, .22), "fly": Color(.3, .3, .3)}
static func ko(e: Dictionary) -> void:
	var c: Color = FUR.get(e.k, Color(.5, .45, .4))
	var feath: bool = e.k in ["crow", "owl"]
	for i in 5:
		part("feather" if feath else "tuft", e.x + randf_range(-10, 10), e.y - 16, randf_range(-2.2, 2.2), -randf_range(1.5, 3.5), 70, c)
	for i in 3:
		part("star", e.x, e.y - 30, cos(TAU * i / 3.0) * 1.6, -1.6 + sin(TAU * i / 3.0), 34, Color(1, .88, .3), {"g": .03})

## I5 bufada: duas nuvenzinhas pelo focinho (vapor branco no frio)
static func snort(x: float, y: float, d: float) -> void:
	var cold: bool = period() == "neve" or g.indoors()
	var c := Color(.97, .98, 1, .75) if cold else Color(.85, .82, .75, .55)
	for i in 2:
		part("puff", x + d * 4, y + i * 3, d * randf_range(1.0, 1.8), -randf_range(.1, .4), 26, c, {"size": 3.5})

## I7 gotinhas de água
static func drops(x: float, y: float, n: int, spread: float = 2.0, col: Color = Color(.6, .8, 1, .85)) -> void:
	for i in n:
		part("drop", x + randf_range(-6, 6), y, randf_range(-spread, spread), -randf_range(1.5, 3.5), 34, col)

# ---------------------------------------------------------------- chefes
## lista dos chefes ativos: nome, vida, posição e estado (para barra, fúria, rastros...)
static func bosses() -> Array:
	var out: Array = []
	if g.X and not g.X.BOSS.is_empty():
		var b: Dictionary = g.X.BOSS
		if b.get("active", false) and not b.get("done", false) and b.st != "wait":
			out.append({"name": {"dog": "BRUTUS", "fiscal": "FISCAL FALSO"}.get(b.get("skin", ""), "MOTOBOY TURBO"), "hp": b.hp, "max": b.maxhp, "x": b.x, "y": b.y,
				"ref": b, "kind": "javali", "weak": b.st in ["stun", "tonto", "painel"], "fast": b.st == "charge" and b.get("spd", 0.0) > 4.0, "dir": b.dir, "gy": 500.0})
	if g.K:
		var h: Dictionary = g.K.HAWK
		if not h.is_empty() and h.get("active", false) and not h.get("done", false) and h.st != "wait":
			out.append({"name": "MORCEGO-REI" if h.get("skin", "") == "bat" else "GAVIÃO-REI", "hp": h.hp, "max": h.maxhp, "x": h.x, "y": h.y - 50,
				"ref": h, "kind": "hawk", "weak": h.st == "stuck", "fast": h.st == "dive", "dir": h.dir, "gy": h.gy})
		var be: Dictionary = g.K.BEAR
		if not be.is_empty() and be.get("active", false) and not be.get("done", false) and be.st != "wait":
			out.append({"name": "URSO-PARDO-REI", "hp": be.hp, "max": be.maxhp, "x": be.x, "y": be.gy - 110, "ref": be, "kind": "bear",
				"weak": be.st == "dizzy", "fast": be.st == "charge", "dir": be.dir, "gy": be.gy})
		var f: Dictionary = g.K.FISH
		if not f.is_empty() and f.get("active", false) and not f.get("done", false) and f.st != "wait":
			out.append({"name": "SAPO-REI" if f.get("skin", "") == "frog" else "BAGRE-REI", "hp": f.hp, "max": f.maxhp, "x": f.x, "y": f.y,
				"ref": f, "kind": "fish", "weak": f.st == "tired", "fast": f.st == "charge" and abs(float(f.get("vx", 0.0))) > 5.0, "dir": f.dir, "gy": f.y})
	return out

## C2 fúria na última vida: o chefe pulsa avermelhado
static func fury(hp: int) -> Color:
	if hp != 1:
		return Color(1, 1, 1)
	var s: float = .5 + .5 * sin(g.T * .18)
	return Color(1, .78 + .22 * (1.0 - s), .74 + .26 * (1.0 - s))

## C3 rugido: anel de ar, capim e folhas empurrados para longe, tela treme de leve
static var blasts: Array = []
static func roar(x: float, y: float) -> void:
	if g == null:
		return
	part("ringw", x, y, 0, 0, 26, Color(1, 1, 1, .55), {"size": 220.0})
	part("ringw", x, y, 0, 0, 34, Color(1, .95, .8, .35), {"size": 320.0})
	blasts.append({"x": x, "y": y, "t": 0, "r": 420.0})
	g.shake = max(g.shake, 5)
	scare(x, 600.0)

## C4/G árvores e teto que reagem: folhas, galhinhos e pedrinhas caindo do alto
static func debris(x0: float, x1: float, y: float, n: int = 14) -> void:
	if g == null:
		return
	var top: float = g.cam_y - 20
	for i in n:
		var x: float = randf_range(x0, x1)
		var k: int = randi() % 3
		if k == 0:
			part("leaf", x, top - randf() * 80, randf_range(-.5, .5), randf_range(0, 1), 260, leaf_col(), {"gy": y})
		elif k == 1:
			part("chip", x, top - randf() * 60, randf_range(-.6, .6), randf_range(0, 1.5), 200, Color(.45, .33, .2), {"gy": y})
		else:
			part("chip", x, top - randf() * 60, randf_range(-.6, .6), randf_range(0, 1.5), 200, Color(.55, .52, .48), {"gy": y, "size": 2.0})

## C10 saída de cena: nuvem de fumaça
static func smoke_cloud(x: float, y: float) -> void:
	for i in 14:
		part("puff", x + randf_range(-60, 60), y - randf_range(0, 80), randf_range(-1.2, 1.2), -randf_range(.3, 1.4), 60, Color(.88, .86, .82, .8), {"size": randf_range(10, 22), "grow": .4})

## C10 lápis saltando em arco e quicando
static func loot_arc(x: float, y: float, n: int, gy: float) -> void:
	for i in n:
		var c: Color = [Color("#e0463a"), Color("#f0cd72"), Color("#5aa0e0"), Color("#6ac06a")][i % 4]
		part("chip", x, y, randf_range(-4.5, 4.5), -randf_range(5.0, 9.0), 120, c, {"gy": gy, "size": 4.0, "g": .3})

## C5 coroa que cai e rola
static var crowns: Array = []
static func crown_drop(kind: String, x: float, y: float, d: float, gy: float) -> void:
	crowns.append({"kind": kind, "x": x, "y": y, "vx": d * 2.5, "vy": -6.0, "rot": 0.0, "gy": gy, "t": 0})

## C6 câmera lenta no golpe final
static func final_blow() -> void:
	g.slowmo = 70
	g.shake = max(g.shake, 10)
	flash_white = 10

static var flash_white := 0

static func _tick_bosses() -> void:
	for b in blasts:
		b.t += 1
	blasts = blasts.filter(func(b): return b.t < 40)
	for c in crowns:
		c.t += 1
		c.vy += .35
		c.x += c.vx
		c.y += c.vy
		if c.y > c.gy:
			c.y = c.gy
			c.vy *= -.35
			c.vx *= .82
		c.rot += c.vx * .08
	crowns = crowns.filter(func(c): return c.t < 900)
	if flash_white > 0:
		flash_white -= 1
	for b in bosses():
		var r: Dictionary = b.ref
		# C2 fúria: vapor saindo do corpo na última vida
		if b.hp == 1 and g.T % 9 == 0:
			part("puff", b.x + randf_range(-40, 40), b.y - randf_range(0, 50), randf_range(-.4, .4), -randf_range(.6, 1.2), 40, Color(1, .9, .88, .45), {"size": 6.0})
		# C7 linhas de velocidade na investida e no mergulho
		if b.fast and g.T % 2 == 0:
			var d: float = float(b.dir)
			part("line", b.x - d * randf_range(40, 90), b.y + randf_range(-40, 20), 0, 0, 10, Color(1, 1, 1, .55), {"dx": d, "size": randf_range(30, 60), "w": 2.0})
		# C8 respiração pesada: vapor pelo focinho nos intervalos (frio, mina) / bolhas na água
		var calm: bool = (b.kind == "javali" and r.st == "idle") or (b.kind == "bear" and r.st in ["walk", "back"]) or (b.kind == "fish" and r.st == "idle")
		if calm and g.T % 70 == 0:
			if b.kind == "fish":
				for i in 3:
					part("bubble", b.x + d_of(b) * 110, b.y + randf_range(-6, 6), randf_range(-.3, .3), -randf_range(.5, 1.0), 70, Color(.8, .95, 1, .8))
			elif period() in ["neve", "noite", "tunel"] or g.indoors():
				snort(b.x + d_of(b) * (110 if b.kind == "bear" else 70), b.gy - (150 if b.kind == "bear" else 40), d_of(b))

static func d_of(b: Dictionary) -> float:
	return 1.0 if float(b.dir) > 0 else -1.0

## C9 brilho dourado de "agora é a hora" (atrás do chefe vulnerável)
static func draw_boss_glow() -> void:
	for b in bosses():
		if not b.weak:
			continue
		var s: float = .6 + .4 * sin(g.T * .2)
		var cy: float = b.y - (60 if b.kind in ["javali", "bear"] else 0)
		Spr.glow(b.x, cy, 140, Color(1, .82, .3, .28 * s))
		Spr.glow(b.x, cy, 80, Color(1, .9, .5, .25 * s))
		if FRESH and g.T % 6 == 0:
			part("spark", b.x + randf_range(-70, 70), cy + randf_range(-50, 50), 0, -.6, 30, Color(1, .88, .4), {"g": 0.0})

## C5 desenho das coroas caídas
static func draw_crowns() -> void:
	for c in crowns:
		var a: float = clamp(1.0 - (c.t - 780) / 120.0, 0, 1)
		Spr.save()
		Spr.translate(c.x, c.y - 6)
		Spr.rotate(c.rot)
		Spr.alpha *= a
		if c.kind == "leaf":
			for i in 5:
				var an := -PI / 2 + (i - 2) * .38
				Spr.ellipse(cos(an) * 16, sin(an) * 10 + 4, 7, 4, Color("#4f8a2a"), an)
			Spr.circle(0, 6, 4, Color("#e0463a"))
		else:
			WorldKings._crown(0, 6, 1.2)
		Spr.restore()

# ================================================================ desenho (camadas)
## mundo, atrás dos bichos e chefes
static func draw_back(game: Game, T: int) -> void:
	g = game
	draw_boss_glow()
	draw_crowns()

## mundo, na frente de tudo (antes das partículas)
static func draw_front(game: Game, T: int) -> void:
	g = game

## tela inteira (por cima do mundo, abaixo do HUD)
static func draw_screen(n: CanvasItem, vs: Vector2) -> void:
	if g == null:
		return
	if flash_white > 0:
		n.draw_rect(Rect2(Vector2.ZERO, vs), Color(1, 1, 1, flash_white / 14.0))

## A7 susto geral: barulho forte espanta passarinhos, coelhos e sapinhos por perto
static func scare(x: float, r: float) -> void:
	for k in Critters.C:
		var c: Dictionary = Critters.C[k]
		if c.get("k", "") == "" or c.get("st", "") != "idle" or abs(c.x - x) > r:
			continue
		var away: float = 1.0 if c.x > x else -1.0
		match c.k:
			"bird":
				c.st = "fly"
				c.vx = away * 3.4
				c.vy = -3.6
				c.f = away
			"rabbit":
				c.st = "run"
				c.f = away
				c.t = 0
			"frog":
				c.st = "jump"
				c.f = away
				c.t = 0

# ---------------------------------------------------------------- capim e flores
## quem mexe no capim: Tomé, inimigos, Pipoca, chefes e coelhos (x, pés, força)
static var _push_T := -1
static var _push: Array = []
static func pushers() -> Array:
	if _push_T == g.T:
		return _push
	_push_T = g.T
	_push = []
	var p: Dictionary = g.player
	_push.append([p.x + p.w / 2, p.y + p.h, 7.0 + abs(p.vx), p.vx])
	for e in g.EN:
		if e.dead or Game.FLY.has(e.k) or e.k in ["leech", "plant", "mole", "spider"]:
			continue
		if e.x < g.cam - 60 or e.x > g.cam + g.W + 60:
			continue
		_push.append([e.x, e.y, 9.0, float(e.dir) * 1.5])
	if g.X and not g.X.DOG.is_empty() and g.X.DOG.get("st", "") != "in_toca":
		var d: Dictionary = g.X.DOG
		_push.append([d.x, d.y, 6.0, float(d.face) * (2.0 if d.get("moving") else 0.0)])
	for b in bosses():
		if b.kind in ["javali", "bear"]:
			_push.append([b.x, b.gy, 16.0, float(b.dir) * 3.0])
	for k in Critters.C:
		var c: Dictionary = Critters.C[k]
		if c.get("k", "") == "rabbit" and c.get("st", "") == "run":
			_push.append([c.x, c.y, 5.0, c.f * 4.0])
	return _push

## alvo de empurrão do tufo em x (chão em gy): soma de quem está perto + rajadas (pouso, rugido)
static func grass_push(x: float, gy: float, reach: float) -> float:
	var t := 0.0
	for q in pushers():
		if abs(q[1] - gy) > 40:
			continue
		var d: float = x - q[0]
		var near: float = clamp(1.0 - abs(d) / reach, 0, 1)
		if near > 0:
			t += sign(d) * near * q[2]
	for b in blasts:
		var d2: float = x - b.x
		if abs(d2) < b.r and abs(b.y - gy) < 200:
			var u: float = 1.0 - b.t / 40.0
			t += sign(d2) * (1.0 - abs(d2) / b.r) * float(b.get("f", 26.0)) * u
	return t

## Q4 capim deitado onde o mergulho caiu / Q7 capim cortado pela picareta
static var flat_zones: Array = []
static var cut := {}
static func flatten(x: float, y: float, r: float, frames: int) -> void:
	flat_zones.append({"x": x, "y": y, "r": r, "t": 0, "n": frames})

static func flat_at(x: float, gy: float) -> float:
	var f := 0.0
	for z in flat_zones:
		if abs(z.y - gy) < 40 and abs(x - z.x) < z.r:
			var u: float = 1.0 - float(z.t) / z.n
			f = max(f, clamp(u * 1.6, 0, 1) * (1.0 - abs(x - z.x) / z.r * .5))
	return f

static func cut_grass(x0: float, x1: float, gy: float) -> void:
	var x: float = floor(x0 / 34.0) * 34.0
	while x <= x1:
		cut[int(x)] = g.T
		for i in 3:
			part("chip", x + randf_range(-6, 6), gy - 8, randf_range(-1.5, 1.5), -randf_range(1.5, 3.0), 50, Color(.45, .62, .28), {"gy": gy, "size": 2.0})
		x += 34.0

## altura do tufo (1 = normal): cortado cresce de volta em ~10 s
static func grass_h(x: float) -> float:
	var c = cut.get(int(x))
	if c == null:
		return 1.0
	var u: float = (g.T - int(c)) / 600.0
	if u >= 1.0:
		cut.erase(int(x))
		return 1.0
	return .35 + .65 * u * u

## Q5 tom do capim por trecho
static func grass_tint(tc: Color) -> Color:
	match period():
		"tarde":
			return Color(tc.r * 1.08, tc.g * .98, tc.b * .78, tc.a)
		"chuva":
			return Color(tc.r * .82, tc.g * .92, tc.b * .8, tc.a)
		"noite", "tunel":
			return Color(tc.r * .82, tc.g * .88, tc.b * 1.08, tc.a)
	return tc

## Q3 ondas de vento correndo pelo campo
static func wind_wave(x: float) -> float:
	var w: float = g.AMB.get("wind", 0.0) + gust_k() * .8
	if w < .05:
		return 0.0
	return max(0.0, sin(x * .008 - g.T * .07)) * w * 7.0

static func _tick_grass() -> void:
	for z in flat_zones:
		z.t += 1
	flat_zones = flat_zones.filter(func(z): return z.t < z.n)

static func hh2(x: float, k: int = 0) -> float:
	var v := sin(x * 12.9898 + k * 78.233 + 3.1) * 43758.5453
	return v - floor(v)

## força extra das rajadas (vento que vem e vai)
static func gust_k() -> float:
	var w: float = g.AMB.get("wind", 0.0)
	if w <= 0.0:
		return 0.0
	return clamp(sin(g.T * .011) * .5 + sin(g.T * .037) * .3, 0.0, 1.0) * w
