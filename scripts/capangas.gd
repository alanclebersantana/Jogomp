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
		"porter":
			return _carregador(g, e)
	return false

## falso carregador: anda com o carrinho imaginário; quando vê o Milis na frente, para, pega uma mala
## do chão, ergue acima da cabeça (aviso bem claro) e arremessa em arco. Rebater com o bastão devolve a
## mala nele.
##  thr: 56..37 pegando a mala · 36..17 erguida · 16 solta · 15..7 braços na frente · 6..1 volta
static func _carregador(g, e: Dictionary) -> bool:
	e.tcd = int(e.get("tcd", 90)) - 1
	var p: Dictionary = g.player
	var dx: float = p.x + p.w / 2 - e.x
	var t: int = int(e.get("thr", 0))
	if t == 0 and int(e.tcd) <= 0 and abs(dx) < 430 and abs(dx) > 60 and abs(p.y + p.h - float(e.base)) < 170 and p.dyingT == 0 and e.get("mala") == null:
		e.dir = 1 if dx > 0 else -1
		e.thr = 56
		e.tcd = 200
		Audio.play("robo_bip", -10, .7)
		return true
	if t > 0:
		e.thr = t - 1
		e.y = e.base
		if t > 17:
			e.dir = 1 if dx > 0 else -1
		if t == 16:
			var sx: float = e.x + e.dir * 26.0
			var sy: float = float(e.base) - 120.0
			var tx: float = clamp(p.x + p.w / 2, e.x - 430.0, e.x + 430.0)
			var tt: float = clamp(abs(tx - sx) / 7.0, 22.0, 48.0)
			var ty: float = p.y + p.h * .5
			e.mala = {"x": sx, "y": sy, "vx": (tx - sx) / tt, "vy": (ty - sy - .5 * .4 * tt * tt) / tt, "r": 0.0, "bnc": 0, "back": false}
			Audio.play("slide", -6, 1.2)
		return true
	return false

## a mala no ar (segue mesmo se o carregador cair): bate no Milis, quica no chão e some; rebatida
## pelo bastão volta e derruba o carregador
static func tick_mala(g, e: Dictionary) -> void:
	var m = e.get("mala")
	if m == null:
		return
	m.x += m.vx
	m.y += m.vy
	m.vy += .4
	m.r += .25 * sign(m.vx)
	var p: Dictionary = g.player
	var cx: float = p.x + p.w / 2
	# rebater: golpe do bastão com a mala perto, na frente do Milis
	if not m.back and int(p.get("actT", 0)) > 0 and str(p.get("act", "")) in ["swing", "swing2", "spin"] and abs(m.x - (cx + p.face * 28)) < 46 and abs(m.y - (p.y + p.h * .45)) < 50:
		m.back = true
		m.vx = p.face * 8.0
		m.vy = -5.0
		g.hit_stop = max(int(g.hit_stop), 5)
		Audio.play("clanc", -4, 1.1)
		Polish.impact(m.x, m.y, Color(1, .9, .5), 10, 26.0)
		return
	if m.back:
		if not e.dead and abs(m.x - e.x) < 34 and m.y > float(e.base) - 110 and m.y < float(e.base):
			g.kill_enemy(e, "hit")
			e.erase("mala")
			return
	elif p.iframe == 0 and m.x > p.x - 8 and m.x < p.x + p.w + 8 and m.y > p.y - 8 and m.y < p.y + p.h + 8:
		g.hurt(1, m.x)
		e.erase("mala")
		return
	var fl: float = float(e.base)
	if m.y > fl - 14:
		m.y = fl - 14
		if int(m.bnc) < 1 and m.vy > 2.0:
			m.vy = -m.vy * .35
			m.vx *= .6
			m.bnc = 1
			Audio.play("clanc", -12, .9)
			g.burst(m.x, fl - 4, 5, Color(.6, .6, .65))
		else:
			g.burst(m.x, fl - 4, 8, Color(.35, .5, .75))
			Audio.play("clanc", -10, .7)
			e.erase("mala")
			return
	if g.wall_at(m.x, m.y) or abs(m.x - e.x) > 900:
		g.burst(m.x, m.y, 8, Color(.35, .5, .75))
		e.erase("mala")

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
	# repara no Milis: para, vira para ele com cara de espanto e depois vai na direção dele
	e.wcd = int(e.get("wcd", 0)) - 1
	var w: int = int(e.get("watch", 0))
	if w == 0 and int(e.wcd) <= 0 and _near(g, e, 230):
		var p: Dictionary = g.player
		e.watch = 46
		e.wcd = 420
		e.dir = 1 if p.x + p.w / 2 > e.x else -1
		Audio.play("robo_bip", -14, .7)
		return true
	if w > 0:
		e.watch = w - 1
		e.y = e.base
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


static func draw_mala(e: Dictionary) -> void:
	var m = e.get("mala")
	if m == null:
		return
	var t: Texture2D = Spr.opt("porter_mala")
	Spr.save()
	Spr.translate(m.x, m.y)
	Spr.rotate(m.r)
	if t:
		Spr.trect(t, Rect2(-24, -19, 48, 38))
	else:
		Spr.rr(-22, -16, 44, 32, 4, Color("#35598a"))
	Spr.restore()
	if m.back:
		Spr.glow(m.x, m.y, 26, Color(1, .9, .5, .35))
