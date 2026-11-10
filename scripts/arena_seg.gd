extends RefCounted
class_name ArenaSeg
## Arena de mini-chefe do falso segurança: quando o Milis entra no trecho dele, descem grades de aço dos
## dois lados (até o teto — não dá para pular por cima nem voltar) e a música muda. As grades só sobem
## quando o segurança cai. Se o Milis perder uma vida lá dentro, volta para fora e a arena reabre, com o
## segurança inteiro de novo.

var g
var A: Array = []   # {e, x0, x1, on, done, h (0 aberta .. 1 fechada), t}

const GW := 22.0

func _init(game) -> void:
	g = game

func load_level() -> void:
	A = []
	for e in g.EN:
		if e.has("arena"):
			A.append({"e": e, "x0": float(e.arena[0]), "x1": float(e.arena[1]), "on": false, "done": false, "h": 0.0, "t": 0})

func is_on(e: Dictionary) -> bool:
	for a in A:
		if a.e == e and a.on:
			return true
	return false

func active() -> Dictionary:
	for a in A:
		if a.on:
			return a
	return {}

func step() -> void:
	var p: Dictionary = g.player
	var cx: float = p.x + p.w / 2
	for a in A:
		var e: Dictionary = a.e
		if a.done:
			# depois que o segurança termina de cair, as grades sobem
			a.wait = int(a.get("wait", 0)) - 1
			if a.wait == 0:
				Audio.play("door", -4, .8)
				g.flash("Caminho livre!", 90)
			if a.wait <= 0:
				a.on = false
				a.h = max(0.0, a.h - .04)
			elif a.on:
				_clamp(a, p)   # as grades ainda estão fechadas
			continue
		if e.dead:
			a.done = true
			a.wait = 70
			continue
		if not a.on:
			a.h = max(0.0, a.h - .05)
			if cx > a.x0 + 6 and cx < a.x1 - 6 and p.dyingT == 0:
				a.on = true
				a.t = 0
				Audio.play("door", -2, .6)
				Audio.play("clanc", -6, .6)
				g.shake = max(g.shake, 4)
				# o segurança fica de frente para o Milis e com fôlego todo
				e.dir = 1 if cx > e.x else -1
				e.ccd = 50
			continue
		a.t += 1
		a.h = min(1.0, a.h + .06)
		if a.t == 2:
			g.en_seen["boar"] = true   # (a explicação vem só daqui, uma vez)
		if a.t == 30:
			g.want_comic("seguranca")
			if not g.has_meta("seg_dica"):
				g.set_meta("seg_dica", true)
				g.flash("O falso segurança fechou a passagem! De frente ele defende com o escudo: bata por trás ou logo depois da investida.", 230)
			else:
				g.flash("Outro falso segurança fechou a passagem: derrube ele para seguir!", 150)
		# perdeu uma vida lá dentro (voltou para o último check-in): reabre e o segurança se recompõe
		if p.dyingT > 0 or cx < a.x0 - 40 or cx > a.x1 + 40:
			a.on = false
			e.hp = 3
			e.mad = false
			e.hurtT = 0
			e.open = 0
			e.disarm = 0
			e.charge = false
			e.wind = 0
			e.blockT = 0
			e.stun = 0
			e.hitCd = 0
			e.ccd = 60
			e.thr = 0
			e.camp = 0
			e.erase("proj")
			e.x = (float(e.r[0]) + float(e.r[1])) / 2.0
			continue
		_clamp(a, p)

## paredes invisíveis do chão até o teto (onde estão as grades)
func _clamp(a: Dictionary, p: Dictionary) -> void:
	var lo: float = a.x0 + GW / 2
	var hi: float = a.x1 - GW / 2 - p.w
	if p.x < lo:
		p.x = lo
		p.vx = max(p.vx, 0.0)
	elif p.x > hi:
		p.x = hi
		p.vx = min(p.vx, 0.0)

## no aeroporto a música de luta toca enquanto a arena está fechada
func song() -> String:
	return "seg_luta" if not active().is_empty() else ""

func draw(T: int) -> void:
	for a in A:
		if a.h <= .01:
			continue
		if a.x1 < g.cam - 60 or a.x0 > g.cam + g.W + 60:
			continue
		var top: float = float(g.L.get("top", -620))
		var bot: float = 500.0
		var yb: float = lerpf(top, bot, a.h)
		for gx in [a.x0, a.x1]:
			_grade(gx, top, yb, T)

## grade de enrolar de aço (portas de segurança de loja de aeroporto) com a faixa amarela e preta embaixo
func _grade(x: float, top: float, yb: float, T: int) -> void:
	var w := GW
	Spr.rect(x - w / 2 - 4, top, 4, 500.0 - top, Color("#3a3f47"))
	Spr.rect(x + w / 2, top, 4, 500.0 - top, Color("#3a3f47"))
	Spr.rect(x - w / 2, top, w, yb - top, Color(.35, .38, .43, .55))
	var yy: float = top + 6
	while yy < yb - 4:
		Spr.rect(x - w / 2, yy, w, 3, Color("#8d97a3"))
		yy += 9
	var xx: float = x - w / 2 + 3
	while xx < x + w / 2:
		Spr.rect(xx, top, 2, yb - top, Color(.2, .22, .26, .8))
		xx += 6
	Spr.rect(x - w / 2 - 4, yb - 10, w + 8, 10, Color("#f2c230"))
	var k := 0
	while k * 8 < w + 8:
		Spr.rect(x - w / 2 - 4 + k * 8, yb - 10, 4, 10, Color("#1b1d22"))
		k += 1
	if yb >= 495.0:
		Spr.ellipse(x, 501, w * .8, 4, Color(0, 0, 0, .3))
