extends RefCounted
class_name Capangas
## Capangas espertos do aeroporto (sempre avisam antes de atacar — dá para ler e reagir):
##  robô falsificado (frog): para, carrega (brilho azul e faíscas) e dá um CHOQUE em volta — pule!
##  mala voadora (fly): treme no ar com um brilho laranja (mirando) e MERGULHA no Milis; depois sobe devagar
##  faxineiro (janitor): deixa o piso molhado atrás dele (ele mesmo não escorrega; o Milis sim)

const ZAP_R := 86.0

static func aero(g) -> bool:
	return g.L.get("theme", "") == "aeroporto"

## true = já cuidou do movimento deste quadro
static func update(g, e: Dictionary) -> bool:
	if not aero(g):
		return false
	match e.k:
		"frog":
			return _robo(g, e)
		"fly":
			return _drone(g, e)
		"janitor":
			return _faxineiro(g, e)
	return false

static func _near(g, e: Dictionary, r: float) -> bool:
	var p: Dictionary = g.player
	return abs(p.x + p.w / 2 - e.x) < r and abs(p.y + p.h - float(e.get("base", e.y))) < 120 and p.dyingT == 0

static func _robo(g, e: Dictionary) -> bool:
	e.zcd = int(e.get("zcd", 120)) - 1
	var z: int = int(e.get("zap", 0))
	if z == 0 and int(e.zcd) <= 0 and _near(g, e, 170) and int(e.get("jt", 0)) % 130 < 60 and not e.get("leap", 0):
		e.zap = 70   # 70..19 carregando (aviso), 18..1 choque
		e.zcd = 300
		Audio.play("robo_bip", -6, 1.4)
		return true
	if z > 0:
		e.zap = z - 1
		e.y = e.base
		e.leap = 0
		if z > 18:
			if z % 6 == 0:
				g.PARTS.append({"x": e.x + randf_range(-20, 20), "y": e.y - randf_range(10, 40), "vx": randf_range(-1, 1), "vy": -randf_range(.5, 1.5), "life": 12, "col": Color(.5, .85, 1)})
		else:
			if z == 18:
				Audio.play("fire", -6, 1.8)
				g.shake = max(g.shake, 3)
			var p: Dictionary = g.player
			var d: float = Vector2(p.x + p.w / 2 - e.x, (p.y + p.h) - e.y).length()
			if d < ZAP_R and p.onGround:
				g.hurt(1, e.x)
		return true
	return false

static func _drone(g, e: Dictionary) -> bool:
	var p: Dictionary = g.player
	var pc := Vector2(p.x + p.w / 2, p.y + p.h * .4)
	var st: String = str(e.get("dst", "voa"))
	e.dt = int(e.get("dt", 0)) + 1
	e.dcd = int(e.get("dcd", 90)) - 1
	match st:
		"voa":
			if int(e.dcd) <= 0 and abs(pc.x - e.x) < 230 and pc.y > e.y + 50 and p.dyingT == 0:
				e.dst = "mira"
				e.dt = 0
				e.dir = 1 if pc.x > e.x else -1
				Audio.play("robo_bip", -4, 1.8)
				return true
			return false
		"mira":
			# trava a mira: a mala treme no ar e brilha
			e.x += sin(e.dt * 1.7) * 1.2
			if e.dt >= 30:
				e.dst = "mergulho"
				e.dt = 0
				e.sx = e.x
				e.sy = e.y
				e.tx = pc.x
				e.ty = pc.y
				Audio.play("slide", -6, 1.6)
			return true
		"mergulho":
			var u: float = e.dt / 34.0
			e.x = clamp(lerpf(float(e.sx), float(e.tx) + e.dir * 60.0, u), e.r[0] - 80, e.r[1] + 80)
			e.y = lerpf(float(e.sy), float(e.ty), sin(min(u, 1.0) * PI * .5))
			if e.dt >= 34:
				e.dst = "volta"
				e.dt = 0
			return true
		"volta":
			e.y += (float(e.cy) - e.y) * .04
			e.x += (clamp(e.x, e.r[0], e.r[1]) - e.x) * .05
			if e.dt > 90:
				e.dst = "voa"
				e.dcd = 160
			return true
	return false

static func _faxineiro(g, e: Dictionary) -> bool:
	var s: int = int(e.get("slip", 0))
	if s > 0:
		e.slip = s - 1
		e.y = e.base
		if s > 60:
			e.x = clamp(e.x + e.dir * (s - 60) * .25, e.r[0], e.r[1])
		return true
	# (ele conhece o próprio piso molhado: não escorrega nele — quem escorrega é o Milis)
	return false

## o faxineiro caído está vulnerável (de frente também)
static func down(e: Dictionary) -> bool:
	return int(e.get("slip", 0)) > 0

## avisos por cima do desenho (brilho do choque, mira do drone, faxineiro estatelado)
static func draw_fx(g, e: Dictionary, T: int) -> void:
	if e.dead or not aero(g):
		return
	match e.k:
		"frog":
			var z: int = int(e.get("zap", 0))
			if z > 18:
				var u: float = (70 - z) / 52.0
				Spr.glow(e.x, e.y - 20, 30 + 30 * u, Color(.4, .8, 1, .2 + .25 * u * (.6 + .4 * sin(T * .9))))
				Spr.ring(e.x, e.y - 4, ZAP_R * (1.0 - u * .2), Color(.5, .85, 1, .25 + .2 * u), 1.5, 0, TAU)
			elif z > 0:
				var k: float = z / 18.0
				Spr.ring(e.x, e.y - 6, ZAP_R * (1.15 - k * .3), Color(.7, .95, 1, .9 * k), 4.0, 0, TAU)
				for i in 6:
					var a: float = TAU * i / 6.0 + T * .4
					var r1: float = 18.0
					var r2: float = ZAP_R * (1.1 - k * .25)
					var mx: float = e.x + cos(a + .2) * (r1 + r2) * .5
					var my: float = e.y - 10 + sin(a + .2) * (r1 + r2) * .25
					Spr.seg(e.x + cos(a) * r1, e.y - 10 + sin(a) * r1 * .5, mx, my, Color(.8, .97, 1, k), 2.5)
					Spr.seg(mx, my, e.x + cos(a) * r2, e.y - 10 + sin(a) * r2 * .5, Color(.8, .97, 1, k), 2.0)
		"fly":
			if str(e.get("dst", "")) == "mira":
				# a mala voadora se prepara: brilho laranja em volta dela e a mira no Milis
				var bl: float = .5 + .5 * sin(T * 1.2)
				Spr.glow(e.x, e.y, 34, Color(1, .6, .2, .25 + .35 * bl))
				var p: Dictionary = g.player
				Spr.ring(p.x + p.w / 2, p.y + p.h * .4, 22 - bl * 5, Color(1, .6, .2, .6), 2.0, 0, TAU)
