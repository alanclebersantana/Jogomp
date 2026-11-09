extends RefCounted
class_name Gadgets
## Equipamentos do Milis (aeroporto):
##  botas_foguete  no ar, depois do pulo duplo, PULAR de novo dá um impulso para cima (uma vez por pulo)
##  gancho         ✋ USAR dispara o gancho magnético no alvo mais perto à frente:
##                   ímã no teto  -> pendura e balança (como num cabo)
##                   falso segurança -> arranca o escudo (fica sem defesa por um tempo)
##                   drone / mala voadora -> puxa para o chão
##                   mala presa no alto -> derruba (solta um monte de milhas)
## Achar um equipamento abre segredos em trechos que já passaram (vale voltar).

var g
var PICK: Array = []     # equipamentos no chão: {x, y, id, got}
var ANCH: Array = []     # ímãs no teto: {x, y}
var STUCK: Array = []    # malas presas no alto: {x, y, n, st, vy}
var hook := {}           # cabo voando: {t, x, y, kind, tgt}
var rk_used := false
var rk_t := 0

const RANGE := 300.0

func _init(game) -> void:
	g = game

func load_level() -> void:
	PICK = []
	ANCH = []
	STUCK = []
	hook = {}
	for d in g.L.get("gadgets", []):
		PICK.append({"x": float(d.x), "y": float(d.y), "id": str(d.id), "got": g.INV.has(str(d.id))})
	for d in g.L.get("anchors", []):
		ANCH.append({"x": float(d.x), "y": float(d.y)})
	for d in g.L.get("stuck", []):
		STUCK.append({"x": float(d.x), "y": float(d.y), "n": int(d.get("n", 15)), "floor": float(d.get("floor", 500)), "st": 0, "vy": 0.0, "r": 0.0})

func has(id: String) -> bool:
	return g.INV.has(id)

# ---------------------------------------------------------------- botas-foguete
## chamado no pulo: true se usou o impulso
func try_rocket() -> bool:
	var p: Dictionary = g.player
	if not has("botas_foguete") or rk_used or p.onGround or p.get("dog") or p.get("isis"):
		return false
	rk_used = true
	rk_t = 18
	p.vy = -11.5
	p.vx += p.face * 1.5
	p.puff = false
	p.slam = false
	p.squash = -.5
	g.shake = max(g.shake, 2)
	Audio.play("robo_pouso", -6, 1.6)
	Audio.play("slide", -6, 1.5)
	return true

# ---------------------------------------------------------------- alvo do gancho
func _front(dx: float) -> bool:
	return dx * g.player.face > -30.0

func target() -> Dictionary:
	if not has("gancho") or not hook.is_empty() or g.player.vine or g.player.get("bar") or g.player.ladder:
		return {}
	var p: Dictionary = g.player
	var hx: float = p.x + p.w / 2
	var hy: float = p.y + p.h * .3
	var best := {}
	var bd := 1e9
	for s in STUCK:
		if s.st == 0:
			var d: float = Vector2(s.x - hx, s.y - hy).length()
			if d < RANGE + 60 and d < bd and s.y < hy:
				best = {"kind": "stuck", "tgt": s, "x": s.x, "y": s.y}
				bd = d
	if not best.is_empty():
		return best
	for e in g.EN:
		if e.dead:
			continue
		var ex: float = e.x
		var ey: float = e.y - (90.0 if e.k == "boar" else 10.0)
		var d2: float = Vector2(ex - hx, ey - hy).length()
		if d2 > RANGE - 40 or not _front(ex - hx):
			continue
		if e.k == "boar" and SegGuard.is_seg(g, e) and int(e.get("disarm", 0)) == 0:
			if d2 < bd:
				best = {"kind": "escudo", "tgt": e, "x": ex + (-e.dir) * 0.0 + e.dir * 40, "y": ey}
				bd = d2
		elif Game.FLY.has(e.k) or e.k in ["crow", "bat", "fly"]:
			if d2 < bd:
				best = {"kind": "voador", "tgt": e, "x": ex, "y": ey}
				bd = d2
	if not best.is_empty():
		return best
	for a in ANCH:
		var d3: float = Vector2(a.x - hx, a.y - hy).length()
		if d3 < RANGE and a.y < hy - 40 and d3 < bd and _front(a.x - hx):
			best = {"kind": "ima", "tgt": a, "x": a.x, "y": a.y}
			bd = d3
	return best

func fire() -> bool:
	var t := target()
	if t.is_empty():
		return false
	hook = t.duplicate()
	hook.t = 0
	Audio.play("climb", -4, 1.6)
	return true

# ---------------------------------------------------------------- passo
func step() -> void:
	var p: Dictionary = g.player
	if p.onGround:
		rk_used = false
	if rk_t > 0:
		rk_t -= 1
		for k in 2:
			g.PARTS.append({"x": p.x + p.w / 2 + randf_range(-6, 6), "y": p.y + p.h, "vx": randf_range(-.6, .6), "vy": randf_range(2.0, 4.0), "life": 14,
				"col": Color(1, .55 + randf() * .35, .15)})
	# equipamentos no chão
	for it in PICK:
		if it.got:
			continue
		if abs(p.x + p.w / 2 - it.x) < 34 and abs(p.y + p.h - it.y) < 50:
			it.got = true
			g.give_item(it.id)
			g.burst(it.x, it.y - 20, 22, Color("#ffd76a"))
			Polish.celebrate(it.x, it.y - 20, false)
			if it.id == "botas_foguete":
				g.flash_tut("Botas-foguete", "No ar, depois do pulo duplo, aperte PULAR de novo: um impulso das botas para cima. Lugares altos que você já viu agora estão ao seu alcance!", 320)
			elif it.id == "gancho":
				g.flash_tut("Gancho magnético", "Toque em ✋ perto de um ímã no teto para se pendurar, de um capanga para puxar (arranca o escudo do falso segurança) ou de uma mala presa no alto. Volte para pegar o que ficou para trás!", 360)
	# cabo voando até o alvo
	if not hook.is_empty():
		hook.t += 1
		if hook.t >= 7:
			_hit(hook)
			hook = {}
	# o cabo do ímã some quando o Milis solta
	var i: int = g.VINES.size() - 1
	while i >= 0:
		var v: Dictionary = g.VINES[i]
		if v.get("hook") and p.vine != v:
			g.VINES.remove_at(i)
		i -= 1
	# malas presas caindo
	for s in STUCK:
		if s.st == 1:
			s.vy += .5
			s.y += s.vy
			s.r += .12
			if s.y >= s.floor - 12:
				s.y = s.floor - 12
				s.st = 2
				g.shake = max(g.shake, 5)
				Audio.play("stomp", -2, .9)
				g.burst(s.x, s.y, 18, Color("#ffd76a"))
				for k in int(s.n):
					g.gain_coin(s.x, s.y - 20, k > 0)
				g.flash("A mala presa caiu: +%d milhas!" % int(s.n), 120)
	# segurança sem escudo: conta o tempo até pegar de volta
	for e in g.EN:
		if int(e.get("disarm", 0)) > 0:
			e.disarm -= 1
			if e.disarm == 0:
				Audio.play("clanc", -10, 1.2)

func _hit(h: Dictionary) -> void:
	var p: Dictionary = g.player
	match h.kind:
		"stuck":
			var s: Dictionary = h.tgt
			s.st = 1
			s.vy = -2.0
			Audio.play("clanc", -6, 1.4)
		"voador":
			var e: Dictionary = h.tgt
			if not e.dead:
				g.kill_enemy(e, "hit")
				e.dvx = (1.0 if p.x > e.x else -1.0) * 4.0
				e.dvy = 2.0
		"escudo":
			var e2: Dictionary = h.tgt
			if not e2.dead:
				# arrancou o escudo: ele cambaleia para perto do Milis, sem defesa por um tempo
				e2.disarm = 200
				e2.blockT = 0
				e2.charge = false
				e2.wind = 0
				e2.open = 0
				e2.x += (1.0 if p.x > e2.x else -1.0) * 30.0
				e2.dir = 1 if p.x > e2.x else -1
				e2.stun = 50
				Audio.play("escudo_voa", -4)
				Audio.play("clanc", -4)
				g.hit_stop = max(int(g.hit_stop), 4)
				g.shake = max(g.shake, 4)
				e2.lshd = {"x": e2.x, "y": e2.y - 100.0, "vx": (1.0 if p.x > e2.x else -1.0) * 4.0, "vy": -6.0, "r": 0.0, "vr": .3, "t": 0}
		"ima":
			var a: Dictionary = h.tgt
			var hx: float = p.x + p.w / 2
			var hy: float = p.y + 6
			var dx: float = hx - a.x
			var dy: float = hy - a.y
			var ln: float = clamp(Vector2(dx, dy).length(), 60.0, RANGE)
			var th: float = atan2(dx, dy)
			var v := {"x": a.x, "y": a.y, "len": ln + 10.0, "th": th, "om": 0.0, "bend": 0.0, "hook": true}
			g.VINES.append(v)
			p.vine = v
			p.erase("voff")
			p.vr = ln
			v.om = clamp((p.vx * cos(th) - p.vy * sin(th)) / ln * .7, -.035, .035)
			if abs(v.om) < .01:
				v.om = .02 * p.face
			p.vang = th * .4
			p.slam = false
			p.puff = false
			p.airJumps = 1
			p.run = 0
			Audio.play("clanc", -10, 1.6)

# ---------------------------------------------------------------- desenho
func draw(T: int) -> void:
	var x0: float = g.cam - 200
	var x1: float = g.cam + g.W + 200
	var p: Dictionary = g.player
	for it in PICK:
		if it.got or it.x < x0 or it.x > x1:
			continue
		var by: float = it.y - 26 + sin(T * .08) * 4
		Spr.glow(it.x, by, 40, Color(1, .85, .4, .35 + .1 * sin(T * .15)))
		Spr.rr(it.x - 18, it.y - 6, 36, 8, 3, Color("#5b6470"))
		if it.id == "botas_foguete":
			_boots(it.x, by, 1.0)
		else:
			_magnet(it.x, by, 1.0, T)
	var tg := target()
	for a in ANCH:
		if a.x < x0 or a.x > x1:
			continue
		Spr.rect(a.x - 2, a.y - 40, 4, 34, Color("#3a3f47"))
		Spr.rect(a.x - 14, a.y - 44, 28, 6, Color("#5b6470"))
		_magnet(a.x, a.y, .8, T)
		if not tg.is_empty() and tg.get("tgt") == a:
			Spr.ring(a.x, a.y + 4, 22 + sin(T * .3) * 3, Color(1, .9, .4, .8), 2.0, 0, TAU)
	for s in STUCK:
		if s.x < x0 or s.x > x1 or (s.st == 2 and false):
			continue
		Spr.save()
		Spr.translate(s.x, s.y)
		Spr.rotate(s.r if s.st == 1 else (0.0 if s.st == 2 else sin(T * .05) * .04))
		Spr.rr(-22, -30, 44, 30, 4, Color(.08, .06, .05))
		Spr.rr(-20, -28, 40, 26, 3, Color("#7a4ab0"))
		Spr.rect(-6, -36, 12, 6, Color(.1, .1, .1))
		Spr.rect(-20, -18, 40, 3, Color(.95, .85, .4))
		Spr.restore()
		if s.st == 0:
			Spr.glow(s.x, s.y - 14, 30, Color(1, .85, .3, .2 + .1 * sin(T * .12)))
			if not tg.is_empty() and tg.get("tgt") == s:
				Spr.ring(s.x, s.y - 14, 30 + sin(T * .3) * 3, Color(1, .9, .4, .8), 2.0, 0, TAU)
	# escudo arrancado voando / no chão
	for e in g.EN:
		var ls = e.get("lshd")
		if ls == null:
			continue
		if int(e.get("disarm", 0)) <= 0 and not e.dead:
			e.erase("lshd")
			continue
		if Polish.FRESH:
			if ls.vy != 0.0:
				ls.x += ls.vx
				ls.y += ls.vy
				ls.vy += .45
				ls.r += ls.vr
				if ls.y >= float(e.base) - 12:
					ls.y = float(e.base) - 12
					ls.vy = 0.0
					ls.r = PI / 2
					Audio.play("clanc", -14, 1.3)
		var t2: Texture2D = Spr.opt("seg_escudo")
		if t2:
			Spr.save()
			Spr.translate(ls.x, ls.y)
			Spr.rotate(ls.r)
			var k: float = SegGuard.SC
			Spr.trect(t2, Rect2(-60 * k, -60 * k, 120 * k, 120 * k))
			Spr.restore()
	# cabo do gancho (voando ou preso no ímã)
	var hx: float = p.x + p.w / 2 + p.face * 10
	var hy: float = p.y + p.h * .35
	if not hook.is_empty():
		var u: float = clamp(hook.t / 7.0, 0, 1)
		var tx: float = lerp(hx, float(hook.x), u)
		var ty: float = lerp(hy, float(hook.y), u)
		Spr.seg(hx, hy, tx, ty, Color(.15, .15, .18), 3)
		Spr.seg(hx, hy, tx, ty, Color(.75, .78, .82), 1.2)
		_magnet(tx, ty, .5, T)
	var v = p.get("vine")
	if v is Dictionary and v.get("hook"):
		Spr.seg(hx, hy, v.x, v.y + 6, Color(.15, .15, .18), 3)
		Spr.seg(hx, hy, v.x, v.y + 6, Color(.75, .78, .82), 1.2)
	elif not tg.is_empty() and tg.kind != "ima" and tg.kind != "stuck":
		var e3: Dictionary = tg.tgt
		Spr.ring(e3.x, e3.y - (90.0 if e3.k == "boar" else 10.0), 26 + sin(T * .3) * 3, Color(1, .9, .4, .7), 2.0, 0, TAU)

func _magnet(x: float, y: float, k: float, T: int) -> void:
	# ímã em U (vermelho e azul) com as pontas prateadas
	Spr.save()
	Spr.translate(x, y)
	Spr.scale(k, k)
	Spr.ring(0, 0, 11, Color(.1, .1, .12), 9.0, 0, PI)
	Spr.ring(0, 0, 11, Color("#d8302a"), 6.0, 0, PI / 2)
	Spr.ring(0, 0, 11, Color("#2f6fd0"), 6.0, PI / 2, PI)
	Spr.rect(-15, -6, 8, 7, Color("#c9ced6"))
	Spr.rect(7, -6, 8, 7, Color("#c9ced6"))
	Spr.restore()

func _boots(x: float, y: float, k: float) -> void:
	for s in [-1.0, 1.0]:
		var bx: float = x + s * 9
		Spr.rr(bx - 7, y - 16, 14, 18, 3, Color(.1, .1, .12))
		Spr.rr(bx - 6, y - 15, 12, 16, 3, Color("#e2e6ec"))
		Spr.rect(bx - 6, y - 2, 12, 3, Color("#d8302a"))
		Spr.poly(PackedVector2Array([Vector2(bx - 4, y + 2), Vector2(bx + 4, y + 2), Vector2(bx, y + 9)]), Color(1, .6, .2, .9))
