extends RefCounted
class_name SegGuard
## Falso segurança (o "javali" do aeroporto): grandalhão de uniforme azul-marinho com escudo de acrílico.
##  - de frente, defende golpe de bastão, chute e pisão com o escudo ("clanc", empurra o Milis, não conta)
##  - aberturas: atacar por trás, logo depois da investida dele (escudo abaixado, ofegante) ou tonto (aparo)
##  - 1ª pancada de verdade: não cai, fica vermelho de raiva, mais rápido, investe mais
##  - 3ª pancada: tenta se defender, mas o escudo voa longe e ele desaba

const H := 165.0          # altura na tela (os passageiros têm ~118)
const SC := H / 214.0     # escala das poses (quadros 260x230, pés em 130,224; o corpo tem ~214 px)

static func is_seg(g, e: Dictionary) -> bool:
	return e.k == "boar" and g.L.get("theme", "") == "aeroporto"

static func _pc(g) -> float:
	return g.player.x + g.player.w / 2

## anda / investe / ofega. true = já cuidou do movimento neste quadro
static func update(g, e: Dictionary) -> bool:
	e.y = e.base
	_radio(g, e)
	for k in ["hurtT", "blockT", "open", "ccd", "radioT"]:
		if int(e.get(k, 0)) > 0:
			e[k] = int(e[k]) - 1
	var mad: bool = e.get("mad", false)
	# empurrado pela pancada: escorrega para trás freando
	if int(e.get("hurtT", 0)) > 0:
		e.x = clamp(e.x + float(e.get("rv", 0.0)), e.r[0], e.r[1])
		e.rv = float(e.get("rv", 0.0)) * .84
		e.charge = false
		e.wind = 0
		if e.hurtT % 3 == 0:
			_steam(g, e)
		return true
	if int(e.get("blockT", 0)) > 0:
		e.charge = false
		return true
	if int(e.get("disarm", 0)) > 0:
		# sem o escudo (arrancado pelo gancho): procura o escudo, atordoado — sem defesa
		e.charge = false
		e.wind = 0
		return true
	if int(e.get("open", 0)) > 0:
		# depois da investida: escudo abaixado, ofegante (a hora de bater de frente)
		e.charge = false
		if e.open % 14 == 0:
			g.PARTS.append({"x": e.x + e.dir * 22, "y": e.y - 150, "vx": e.dir * .4, "vy": -.4, "life": 26, "col": Color(.75, .9, 1, .8)})
		return true
	var dx: float = _pc(g) - e.x
	var dy: float = g.player.y + g.player.h - e.base
	var near: bool = abs(dy) < 60 and g.player.dyingT == 0
	if mad and near and abs(dx) < 420 and not e.get("charge") and int(e.get("wind", 0)) == 0:
		e.dir = 1 if dx > 0 else -1   # irritado: não perde o Milis de vista
	if mad and int(e.get("hitFx", 0)) == 0 and g.T % 9 == 0:
		_steam(g, e)
	# antecipação (telegrafado): recua, abaixa e brilha antes de investir
	if int(e.get("wind", 0)) > 0:
		e.wind -= 1
		if e.wind > 8:
			e.x = clamp(e.x - e.dir * .6, e.r[0], e.r[1])
		if e.wind % 4 == 0:
			g.PARTS.append({"x": e.x - e.dir * 22, "y": e.base - 2, "vx": -e.dir * randf_range(1.0, 2.2), "vy": -randf_range(.8, 1.8), "life": 16, "col": g._dust_col()})
		if e.wind == 0:
			e.charge = true
			e.chT = 0
			Audio.play("stomp", -10, .7)
		return true
	if e.get("charge"):
		e.chT = int(e.get("chT", 0)) + 1
		var sp: float = 3.9 if mad else 3.1
		e.x += e.dir * sp
		if g.T % 3 == 0:
			g.PARTS.append({"x": e.x - e.dir * 20, "y": e.base - 2, "vx": -e.dir * randf_range(.6, 1.8), "vy": -randf_range(.5, 1.4), "life": 14, "col": g._dust_col()})
		if g.QB:
			g.QB.hit_point(e.x + e.dir * 40, e.y - 40, e.dir * sp)   # a investida derruba o que estiver na frente
		var edge: bool = e.x <= e.r[0] or e.x >= e.r[1]
		e.x = clamp(e.x, e.r[0], e.r[1])
		# passou do Milis, bateu na ponta ou cansou: freia e abaixa o escudo
		if e.chT > (80 if mad else 64) or edge or dx * e.dir < -70:
			e.charge = false
			e.open = 40 if mad else 58
			e.ccd = 40 if mad else 70
			Audio.play("slide", -12, .8)
			for k in 4:
				g.PARTS.append({"x": e.x + e.dir * 12, "y": e.base - 2, "vx": e.dir * randf_range(.6, 2.0), "vy": -randf_range(.5, 1.6), "life": 18, "col": g._dust_col()})
		return true
	# viu o Milis na frente: prepara a investida
	var rng_: float = 300.0 if mad else 230.0
	if near and abs(dx) < rng_ and dx * e.dir > 0 and int(e.get("ccd", 0)) == 0:
		e.wind = 14 if mad else 22
		Audio.play("stomp", -16)
		return true
	# patrulha: anda devagar e vira nas pontas
	var spd: float = 1.5 if mad else 1.0
	var edge2: float = (e.r[1] - e.x) if e.dir > 0 else (e.x - e.r[0])
	spd = min(spd, max(.25, edge2 * .07))
	e.x += e.dir * spd
	if e.x <= e.r[0]:
		e.x = e.r[0]
		e.dir = 1
	elif e.x >= e.r[1]:
		e.x = e.r[1]
		e.dir = -1
	return true

static func _steam(g, e: Dictionary) -> void:
	# fumacinha saindo pelas orelhas (raiva)
	for s in [-1.0, 1.0]:
		g.PARTS.append({"x": e.x + s * 16 + e.dir * 6, "y": e.y - 150, "vx": s * randf_range(.3, .9), "vy": -randf_range(.6, 1.2), "life": 22, "col": Color(.95, .95, .95, .7)})

## golpe do Milis (bastão, chute ou pisão). true = absorveu (não morre agora)
static func on_hit(g, e: Dictionary, how: String) -> bool:
	if int(e.get("hitCd", 0)) > 0:
		return true
	var pc: float = _pc(g)
	var front: bool = (pc - e.x) * e.dir > -6.0
	var opening: bool = e.stun > 0 or int(e.get("open", 0)) > 0 or int(e.get("disarm", 0)) > 0 or not front
	if not opening:
		_block(g, e, how)
		return true
	e.hp = int(e.get("hp", 3)) - 1
	var kd: float = 1.0 if e.x > pc else -1.0
	if e.hp > 0:
		# pancada de verdade: não cai — fica furioso (vermelho, mais rápido, investe mais)
		e.mad = true
		e.hitCd = 30
		e.hitFx = 12
		e.hurtT = 24
		e.rv = kd * 6.0
		e.dir = -int(kd)
		e.stun = 0
		e.dizzyT = 0
		e.open = 0
		e.wind = 0
		e.ccd = 26
		e.charge = false
		g.burst(e.x, e.y - 90, 12, Color("#ffd76a"))
		Polish.impact(e.x, e.y - (140.0 if how == "stomp" else 90.0))
		g.shake = max(g.shake, 6)
		g.hit_stop = max(int(g.hit_stop), 5)
		Audio.play("stomp", -2, .75)
		Audio.play("roar", -10, 1.3)
		Audio.vib(22)
		# o do rádio, na última pancada antes de cair, chama reforço: um drone entra voando na arena
		if e.hp == 1 and e.get("radio") and not e.get("called"):
			e.called = 1
			e.radioT = 70
			Audio.play("robo_bip", -4, .6)
			g.flash("O segurança chamou reforço no rádio!", 110)
			var ar: Array = e.get("arena", e.get("r", [e.x - 200, e.x + 200]))
			var from_r: bool = g.player.x < e.x
			var dx: float = float(ar[1]) + 120.0 if from_r else float(ar[0]) - 120.0
			g.EN.append({"k": "crow", "x": dx, "y": float(e.base) - 330.0, "cy": float(e.base) - 220.0,
				"r": [float(ar[0]) + 40.0, float(ar[1]) - 40.0], "dir": -1 if from_r else 1, "dead": 0,
				"base": float(e.base) - 220.0, "stun": 0, "leap": 0, "x0": dx, "sx": dx, "minion": 1})
		return true
	# 3ª pancada: ele ainda levanta o escudo, mas o escudo voa longe
	e.shd = {"x": e.x + e.dir * 40.0, "y": e.y - 100.0, "vx": kd * 5.0, "vy": -9.0, "r": 0.0, "vr": .32 * kd, "t": 0}
	Audio.play("clanc", -2, .8)
	Audio.play("escudo_voa", -3)
	g.slowmo = max(g.slowmo, 26)   # câmera lenta e zoom no golpe final
	return false

static func _block(g, e: Dictionary, how: String) -> void:
	var pc: float = _pc(g)
	var sgn: float = 1.0 if pc > e.x else -1.0
	e.dir = int(sgn)
	e.blockT = 16
	e.hitCd = 10
	e.wind = 0
	e.charge = false
	var p: Dictionary = g.player
	p.vx = sgn * 6.5
	p.wlock = 14
	if how == "stomp":
		p.vy = -9.5
	var sx: float = e.x + sgn * 44.0
	var sy: float = e.y - (130.0 if how == "stomp" else 80.0)
	g.burst(sx, sy, 10, Color(.75, .95, 1))
	Polish.impact(sx, sy, Color(.8, .97, 1), 6, 18.0)
	g.shake = max(g.shake, 3)
	g.hit_stop = max(int(g.hit_stop), 3)
	Audio.play("clanc", -3)
	Audio.vib(14)

## derrubado: o escudo voa girando e cai no chão
static func tick_dead(g, e: Dictionary) -> void:
	var s = e.get("shd")
	if s == null:
		return
	s.t += 1
	if s.vy != 0.0 or s.y < e.base - 12:
		if g.wall_at(s.x + s.vx + sign(s.vx) * 16, s.y):
			s.vx = -s.vx * .3
			s.vr = -s.vr * .5
		s.x += s.vx
		s.y += s.vy
		s.vy += .5
		s.r += s.vr
		if s.y >= e.base - 12 and s.vy > 0:
			s.y = e.base - 12
			if abs(s.vy) > 3:
				s.vy = -s.vy * .35
				s.vx *= .6
				s.vr *= .5
				Audio.play("clanc", -14, 1.3)
			else:
				s.vy = 0.0
				s.vr = 0.0
				s.r = round(s.r / PI) * PI + PI / 2

## desenho (chamado com a origem nos pés e o espelho já aplicado pela direção)
static func draw(g, e: Dictionary, dist: float, T: int) -> void:
	var n: String
	var rot := 0.0
	var dy := 0.0
	if e.dead:
		n = "seg_caido"
	elif int(e.get("blockT", 0)) > 0 or int(e.get("thr", 0)) > 0:
		n = "seg_firme"
	elif int(e.get("hurtT", 0)) > 0:
		n = "seg_bravo"
		rot = -.08
	elif e.stun > 0 or int(e.get("disarm", 0)) > 0:
		n = "seg_tonto"   # (a única pose sem o escudo na mão)
	elif int(e.get("open", 0)) > 0:
		n = "seg_guarda"
		rot = .07 + sin(T * .25) * .02   # curvado, recuperando o fôlego
		dy = abs(sin(T * .25)) * 2.0
	elif int(e.get("wind", 0)) > 0:
		n = "seg_bravo" if e.get("mad", false) else "seg_firme"
	elif e.get("charge"):
		n = "seg_investe"
		dy = -abs(sin(dist * .2)) * 3.0
	elif abs(float(e.get("_bvx", 0.0))) > .15:
		# ciclo de andar desenhado (8 quadros: joelhos dobrando, braço balançando); sem ele, as 2 poses antigas
		var wk: Texture2D = Spr.opt("seg_walk")
		if wk:
			var wf: int = Spr.walk_frame("seg_walk", dist, SC)
			Spr.frame(wk, wf, 260, 230, 130, 224, 0, dy, SC)
			return
		n = ["seg_andaA", "seg_parado", "seg_andaB", "seg_parado"][int(dist / 16.0) % 4]
	else:
		n = "seg_bravo" if e.get("mad", false) and (T / 40) % 3 == 0 else "seg_parado"
	var t: Texture2D = Spr.opt(n)
	if t == null:
		return
	Spr.save()
	Spr.translate(0, dy)
	Spr.rotate(rot)
	Spr.trect(t, Rect2(-130 * SC, -224 * SC, 260 * SC, 230 * SC))
	Spr.restore()

## brilho de aviso (antes da investida) e reflexo no escudo quando defende — por cima do desenho
static func draw_fx(g, e: Dictionary, T: int) -> void:
	draw_radio(e, T)
	if e.dead:
		return
	var w: int = int(e.get("wind", 0))
	if w > 0:
		var u: float = .5 + .5 * sin(T * .8)
		Spr.glow(e.x, e.y - 80, 70, Color(1, .3, .2, .18 + .14 * u))
	var b: int = int(e.get("blockT", 0))
	if b > 0:
		var k: float = b / 16.0
		Spr.glow(e.x + e.dir * 46, e.y - 85, 46, Color(.75, .97, 1, .45 * k))

static func draw_shield(e: Dictionary) -> void:
	var s = e.get("shd")
	if s == null:
		return
	var t: Texture2D = Spr.opt("seg_escudo")
	if t == null:
		return
	var al: float = clamp(1.0 - (float(e.dead) - 300.0) / 60.0, 0, 1)
	Spr.save()
	Spr.alpha = al
	Spr.translate(s.x, s.y)
	Spr.rotate(s.r)
	var k: float = SC * 1.0
	Spr.trect(t, Rect2(-60 * k, -60 * k, 120 * k, 120 * k))
	Spr.restore()

## arena fechada e o Milis "acampado" lá em cima (na esteira de despacho, numa plataforma): depois de um
## tempo o segurança arremessa o rádio nele (aviso: para, mira e brilha antes de jogar)
## o rádio voando segue sozinho (mesmo com o segurança tonto ou já caído)
static func tick_proj(g, e: Dictionary) -> void:
	var pr = e.get("proj")
	if pr != null:
		pr.x += pr.vx
		pr.y += pr.vy
		pr.vy += .35
		pr.r += .4
		var p: Dictionary = g.player
		if p.iframe == 0 and pr.x > p.x - 6 and pr.x < p.x + p.w + 6 and pr.y > p.y - 6 and pr.y < p.y + p.h + 6:
			g.hurt(1, pr.x)
			e.erase("proj")
		elif pr.y > e.base or g.wall_at(pr.x, pr.y):
			g.burst(pr.x, min(pr.y, e.base - 4), 6, Color(.6, .6, .65))
			Audio.play("clanc", -12, 1.6)
			e.erase("proj")

static func _radio(g, e: Dictionary) -> void:
	if g.ARN == null or not g.ARN.is_on(e) or e.dead:
		e.camp = 0
		return
	var p2: Dictionary = g.player
	var dy: float = p2.y + p2.h - e.base
	var dx: float = p2.x + p2.w / 2 - e.x
	if int(e.get("thr", 0)) > 0:
		e.thr = int(e.thr) - 1
		e.dir = 1 if dx > 0 else -1
		if e.thr == 0:
			# arremesso em arco até onde o Milis está
			var t := 40.0
			var sx: float = e.x + e.dir * 30.0
			var sy: float = e.base - 140.0
			var ty: float = p2.y + p2.h * .5
			e.proj = {"x": sx, "y": sy, "vx": (p2.x + p2.w / 2 - sx) / t, "vy": (ty - sy - .5 * .35 * t * t) / t, "r": 0.0}
			Audio.play("slide", -6, 1.5)
		return
	if dy < -60 and abs(dx) < 340 and e.get("proj") == null:
		e.camp = int(e.get("camp", 0)) + 1
		if e.camp > 100:
			e.camp = 0
			e.thr = 28
			e.charge = false
			e.wind = 0
			Audio.play("robo_bip", -8, .8)
	else:
		e.camp = max(0, int(e.get("camp", 0)) - 2)

static func draw_radio(e: Dictionary, T: int) -> void:
	if int(e.get("radioT", 0)) > 0 and not e.dead:
		# falando no rádio: o aparelho perto da boca e ondas saindo dele
		var rx: float = e.x + e.dir * 22
		var ry: float = e.y - 150
		Spr.rr(rx - 5, ry - 10, 10, 18, 2, Color("#1b1d22"))
		Spr.rect(rx - 3, ry - 7, 6, 4, Color("#6fd06a") if (T / 6) % 2 == 0 else Color("#2a5a2a"))
		Spr.rect(rx + 1, ry - 18, 2, 8, Color("#1b1d22"))
		for k in 3:
			var u: float = fposmod(T * .05 + k / 3.0, 1.0)
			Spr.ring(rx, ry - 4, 8 + u * 26, Color(.6, 1, .6, .55 * (1.0 - u)), 2)
	if int(e.get("thr", 0)) > 0 and not e.dead:
		var u: float = .5 + .5 * sin(T * .9)
		Spr.glow(e.x + e.dir * 30, e.y - 140, 26, Color(1, .3, .2, .25 + .3 * u))
	var pr = e.get("proj")
	if pr == null:
		return
	Spr.save()
	Spr.translate(pr.x, pr.y)
	Spr.rotate(pr.r)
	Spr.rr(-6, -10, 12, 20, 2, Color("#1b1d22"))
	Spr.rect(-4, -7, 8, 5, Color("#6fd06a"))
	Spr.rect(2, -18, 2, 8, Color("#1b1d22"))
	Spr.restore()
