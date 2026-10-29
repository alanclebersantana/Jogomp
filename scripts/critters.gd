extends RefCounted
class_name Critters
## Bichinhos de ambiente que não atacam: passarinhos que bicam o chão e voam quando o Tomé chega,
## borboletas que pousam nas flores (e às vezes no chapéu do Tomé), coelhos que fogem pulando,
## sapinhos que pulam na água, corujas que viram a cabeça para o Tomé, peixes saltando nos lagos,
## libélulas sobre a água, trilhas de formigas, bandos no céu e pegadas na neve.
## Tudo só visual: nascem em pontos fixos da fase perto da câmera e voltam depois de um tempo.
## O passo vem do relógio dos efeitos (FxClock): parado na pausa, igual em 60/90/120 Hz.

const FxClock = preload("res://scripts/fx_clock.gd")
const WSt = preload("res://scripts/world_static.gd")

static var C := {}
static var TU := {}
static var level_ref = null
static var TRACKS: Array = []     # pegadas na neve: [x, y, ft, lado]
static var _splashed := {}        # saltos de peixe que já espirraram (início/fim)
static var FRONTQ: Array = []     # borboletas no gorro do Tomé (desenhadas por cima dele)
static var k := 1.0               # passo deste quadro (quadros de 60 Hz)

static func hh(x: float, kk: int = 0) -> float:
	var v := sin(x * 12.9898 + kk * 78.233) * 43758.5453
	return v - floor(v)

## o contador t passou por um múltiplo de per neste quadro?
static func _cross(t: float, per: float, off: float = 0.0, dt: float = -1.0) -> bool:
	if dt < 0.0:
		dt = k
	return floor((t - off) / per) != floor((t - dt - off) / per)

static func _ground_y(g: Game, x: float) -> float:
	var best := INF
	for s in g.SOL:
		if s.t in ["ground", "cliff"] and x > s.x + 20 and x < s.x + s.w - 20 and s.y > 0 and s.y < best:
			best = s.y
	return best

static func _theme(g: Game, x: float) -> String:
	var th := "manha"
	for sc in g.L.get("sections", []):
		if sc.x <= x:
			th = "neve" if sc.get("bg", "") == "neve" else sc.get("song", "manha")
	return th

## águas de verdade (lago e brejo; sem os lagos de veneno e sem as de debaixo da terra).
## Brejo é lama verde: sapo e libélula sim, peixe só nos lagos (lakes_only)
static func _waters(g: Game, lakes_only: bool = false) -> Array:
	var out: Array = []
	var ws: Array = []
	if g.X:
		ws.append_array(g.X.WATER)
	if not lakes_only:
		ws.append_array(g.SWAMP)
	for w in ws:
		if w.get("fumes"):
			continue
		if g.L.has("under") and float(w.y) > float(g.L.under):
			continue
		var th := _theme(g, float(w.x) + float(w.w) * .5)
		if th in ["noite", "perseguicao", "tunel"]:
			continue
		out.append(w)
	return out

static func _in_tunnel(g: Game, x: float) -> bool:
	var tn: Array = g.L.get("tunnel", [])
	return tn.size() >= 2 and x > float(tn[0]) and x < float(tn[1])

static func draw(g: Game, T: int) -> void:
	if g.L.get("theme", "") == "aeroporto":
		return
	if level_ref != g.L:
		C = {}
		TU = {}
		TRACKS = []
		_splashed = {}
		level_ref = g.L
	FxClock.update(g)
	k = FxClock.k
	FRONTQ.clear()
	_tracks(g)
	_toucans(g, T)
	_flock(g, T)
	_water_life(g)
	_ants(g)
	g.bird_near = false
	var p: Dictionary = g.player
	var px: float = p.x + p.w / 2
	var py: float = p.y + p.h
	var i0: int = int(floor((g.cam - 200) / 520.0))
	var i1: int = int(floor((g.cam + g.W + 200) / 520.0))
	for i in range(i0, i1 + 1):
		if hh(i, 1) < .45:
			continue
		if not C.has(i):
			C[i] = _make(g, i)
		var c: Dictionary = C[i]
		if c.k == "":
			continue
		c.t += k
		match c.k:
			"bird":
				_bird(g, c, px, py, T)
			"butterfly":
				_butterfly(g, c, T, i)
			"rabbit":
				_rabbit(c, px, py, T)
			"frog":
				_frog(g, c, px, py, T)
			"owl":
				_owl(c, T, i, px)

## cria o bichinho de um ponto da fase — a escolha depende só do lugar dele (não de onde o Tomé está)
static func _make(g: Game, i: int) -> Dictionary:
	var x: float = i * 520 + 60 + hh(i, 2) * 400
	var gy: float = _ground_y(g, x)
	if gy == INF:
		return {"k": ""}
	var th := _theme(g, x)
	var kk := ""
	match th:
		"manha", "tarde":
			kk = ["bird", "butterfly", "rabbit"][int(hh(i, 3) * 3)]
		"chuva":
			kk = "bird"
		"noite", "perseguicao":
			kk = "owl"
		"neve", "tema":
			kk = "bird" if hh(i, 5) < .5 else "rabbit"
	# debaixo da terra (pelo ponto do bicho) não tem bicho; no túnel da mina só a coruja
	if g.L.has("under") and gy > float(g.L.under):
		kk = ""
	if _in_tunnel(g, x) and kk != "owl":
		kk = ""
	var c := {"k": kk, "x": x, "y": gy, "x0": x, "y0": gy, "st": "idle", "t": 0.0, "vx": 0.0, "vy": 0.0, "f": 1.0 if hh(i, 6) > .5 else -1.0,
		"snow": th in ["neve", "tema"]}
	# no brejo, perto da água: sapinho na margem (pula na água quando o Tomé chega)
	if th == "chuva" and kk != "":
		for w in _waters(g):
			var wx0: float = w.x
			var wx1: float = float(w.x) + float(w.w)
			if x < wx0 - 220 or x > wx1 + 220 or abs(float(w.y) - gy) > 60:
				continue
			var left: bool = abs(x - wx0) < abs(x - wx1)
			var bx: float = wx0 - 22.0 if left else wx1 + 22.0
			var by: float = _ground_y(g, bx)
			if by == INF or abs(by - float(w.y)) > 50:
				continue
			c.k = "frog"
			c.x = bx
			c.x0 = bx
			c.y = by
			c.y0 = by
			c.wf = 1.0 if left else -1.0
			c.f = c.wf
			c.wy = float(w.y)
			c.jd = min(90.0, float(w.w) * .5 + 22.0)
			break
	return c

## bando no céu de vez em quando: o do trecho (parâmetro "flock") ou um conforme o período —
## passarinhos de manhã, gansos em V à tarde, morcegos à noite
static func _flock(g: Game, T: int) -> void:
	if g.indoors():
		return
	var kind = g.sec_param("flock", null)
	var per := 900.0
	var dur := 520.0
	if kind == null:
		if g.AMB.rain > .3:
			return
		match _theme(g, g.cam + g.W * .5):
			"manha":
				kind = "songbirds"
			"tarde":
				kind = "geese"
			"noite", "perseguicao":
				kind = "bats"
		if kind == null:
			return
		per = 1700.0
		dur = 620.0 if kind == "geese" else 480.0
	var ft: float = FxClock.ft
	var ph: float = fposmod(ft, per)
	if ph > dur:
		return
	var cyc: int = int(ft / per)
	if per > 1000.0 and hh(cyc, 7) < .3:
		return
	var dir: float = 1.0 if cyc % 2 == 0 else -1.0
	var u: float = ph / dur
	var x0: float = g.cam - 200 if dir > 0 else g.cam + g.W + 200
	var bx: float = x0 + dir * u * (g.W + 400)
	var by: float = g.cam_y + 70 + hh(cyc, 4) * 90 + sin(u * 6.0) * 10
	var n: int = 5 + int(hh(cyc, 5) * 5)
	# câmera olhando o fundo de um lago: o bando passaria "voando" dentro da água — não aparece
	var mx: float = g.cam + g.W * .5
	for arr in [g.SWAMP, g.X.WATER if g.X else []]:
		for w in arr:
			if mx > float(w.x) - 200.0 and mx < float(w.x) + float(w.w) + 200.0 and float(w.y) < by + 40.0:
				return
	var kd := str(kind)
	if kd == "geese":
		# gansos em V, devagar e longe (pequenos, apagados)
		for q in n:
			var row: int = (q + 1) / 2
			var side: float = 0.0 if q == 0 else (-1.0 if q % 2 == 1 else 1.0)
			var gx: float = bx - dir * row * 26 + sin(ft * .01 + q * 1.7) * 3
			var gy: float = by - 30 + row * 12 * side + sin(ft * .02 + q) * 2
			Spr.P_cycle("goose", ["goose0", "goose1", "goose2", "goose1"], ft / 6.0 + q * 2, gx, gy + 6, 26, dir < 0, Color(.5, .52, .56, .8))
		return
	if kd == "songbirds":
		# passarinhos: bando solto, cada um no seu sobe-e-desce (voo ondulado)
		for q in n + 3:
			var ox: float = (hh(cyc * 13 + q, 8) - .5) * 120
			var oy: float = (hh(cyc * 13 + q, 9) - .5) * 50
			var qx: float = bx + ox + sin(ft * .03 + q) * 8
			var qy: float = by + oy + sin(ft * .09 + q * 2.1) * 4
			var fl: float = sin(ft * .9 + q * 1.3)
			var w: float = 5.0
			var cc := Color(.2, .16, .14, .7)
			Spr.line(PackedVector2Array([Vector2(qx - w, qy - fl * 3), Vector2(qx, qy), Vector2(qx + w, qy - fl * 3)]), cc, 1.6)
		return
	var bat: bool = kd == "bats"
	for q in n:
		var row: int = (q + 1) / 2
		var side: float = -1.0 if q % 2 == 0 else 1.0
		var qx2: float = bx - dir * row * 26
		var qy2: float = by + side * row * 12 * (0.0 if q == 0 else 1.0) + sin(ft * .2 + q) * 2
		var fl2: float = sin(ft * (.45 if bat else .3) + q * 1.3)
		var w2: float = 9.0 if not bat else 8.0
		var c2 := Color(.12, .1, .14, .85) if bat else Color(.18, .14, .12, .75)
		Spr.line(PackedVector2Array([Vector2(qx2 - w2, qy2 - fl2 * 5), Vector2(qx2 - 2, qy2), Vector2(qx2, qy2 + 1), Vector2(qx2 + 2, qy2), Vector2(qx2 + w2, qy2 - fl2 * 5)]), c2, 2.0)
		if bat:
			Spr.circle(qx2, qy2 + 1, 2.2, c2)

## cor dos bichinhos do cenário: um pouco mais clara e suave
const SOFT := Color(1.08, 1.08, 1.1, .92)

static func _respawn(c: Dictionary) -> void:
	c.x = c.x0
	c.y = c.y0
	c.st = "idle"
	c.t = 0.0
	c.vx = 0.0
	c.vy = 0.0

## pegada na neve (some devagar)
static func _track(c: Dictionary, x: float, y: float) -> void:
	if not c.get("snow", false):
		return
	TRACKS.append([x, y, FxClock.ft, c.f])
	if TRACKS.size() > 48:
		TRACKS.pop_front()

static func _tracks(g: Game) -> void:
	if TRACKS.is_empty():
		return
	var ft: float = FxClock.ft
	while not TRACKS.is_empty() and ft - float(TRACKS[0][2]) > 1100.0:
		TRACKS.pop_front()
	for tr in TRACKS:
		if tr[0] < g.cam - 40 or tr[0] > g.cam + g.W + 40:
			continue
		var a: float = clamp(1.0 - (ft - float(tr[2])) / 1100.0, 0, 1) * .55
		# retângulos pequenos (o motor junta todos numa chamada só)
		Spr.rect(tr[0] - 3, tr[1] - 2, 6, 2.5, Color(.5, .56, .7, a))
		Spr.rect(tr[0] + 5 * tr[3] - 3, tr[1], 6, 2.5, Color(.5, .56, .7, a))

## passarinho: bica o chão, dá pulinhos e voa quando o Tomé chega perto
static func _bird(g: Game, c: Dictionary, px: float, py: float, T: int) -> void:
	if c.st == "idle":
		if abs(px - c.x) < 140 and abs(py - c.y) < 120:
			c.st = "fly"
			c.vx = sign(c.x - px) * 3.0 if c.x != px else 3.0
			c.vy = -3.4
			c.f = sign(c.vx)
		elif fposmod(c.t, 90.0) >= 60 and fposmod(c.t, 90.0) < 68:
			# pulinho: anda 8 px num arco curto (em vez de teletransportar)
			c.x += c.f * 1.0 * k
			if _cross(c.t, 90.0, 67.0):
				_track(c, c.x, c.y)
		elif _cross(c.t, 200.0):
			c.f = -c.f
	elif c.st == "fly":
		c.x += c.vx * k
		c.y += c.vy * k
		c.vy = max(c.vy - .02 * k, -4.0)
		if abs(px - c.x) < 260 and c.y < py - 40:
			g.bird_near = true
		if c.y < c.y0 - 700:
			c.st = "gone"
			c.t = 0
	elif c.st == "gone":
		if c.t > 900 and abs(px - c.x0) > 600:
			_respawn(c)
		return
	var fly: bool = c.st == "fly"
	var pk: float = fposmod(c.t, 50.0)
	# bicada: abaixa e volta suave (curva), não num estalo
	var peck: float = 0.0 if fly else (sin(pk / 8.0 * PI) * 2.0 if pk < 8 else 0.0)
	var hop_ph: float = fposmod(c.t, 90.0) - 60
	var hop: float = sin(hop_ph / 8.0 * PI) * 5.0 if (not fly and hop_ph >= 0 and hop_ph < 8) else 0.0
	Spr.save()
	Spr.translate(c.x, c.y - hop)
	if fly:
		# bate as asas: o corpo sobe na batida para baixo e as asas "fecham" (achata na vertical)
		var fl: float = sin(FxClock.ft * .8 + c.x0)
		Spr.translate(0, 4 - fl * 2)
		Spr.rotate(clamp(c.vy * -.05, -.25, .25) * -c.f)
		Spr.scale(1, .8 + .2 * abs(fl))
		Spr.P("bird_fly", 0, 0, 22, c.f < 0, 0.0, SOFT)
	else:
		Spr.rotate(peck * .12 * c.f)
		Spr.P("bird_sit", 0, 1, 17, c.f < 0, 0.0, SOFT)
	Spr.restore()

## caminho de voo da borboleta em volta do ponto dela
static func _bpath(c: Dictionary, i: int) -> Vector2:
	var t: float = FxClock.ft * .02 + i
	return Vector2(c.x0 + sin(t * 1.3) * 60 + sin(t * 3.1) * 12, c.y0 - 40 - abs(sin(t * 2.0)) * 30 + sin(t * 5.0) * 6)

## onde pousar: uma flor perto (topo da flor) ou, raramente, o chapéu do Tomé parado
static func _bfly_target(g: Game, c: Dictionary, i: int) -> Dictionary:
	var p: Dictionary = g.player
	var pcx: float = p.x + p.w / 2
	var idle: bool = p.get("onGround", false) and abs(p.vx) < .2 and not p.get("swim", false) and not p.get("isis", false)
	if idle and abs(pcx - c.x0) < 220 and abs(p.y + p.h - c.y0) < 80 and hh(i + floor(FxClock.ft / 600.0), 27) < .22:
		return {"hat": true}
	var best = null
	var bd := 1e9
	for s in g.SOL:
		if s.t != "ground" or s.x > c.x0 + 160 or s.x + s.w < c.x0 - 160:
			continue
		for f in WSt.flowers_of(g, s):
			var d: float = abs(float(f[0]) - c.x0)
			if d < 160 and d < bd:
				bd = d
				var r = Spr.AR.get("p_" + str(f[1]))
				var fh: float = float(f[2]) * (float(r[3]) / float(r[2]) if r != null else 1.2)
				best = {"x": float(f[0]), "y": s.y + 2 - fh * .82}
	return best if best != null else {}

static func _hat_pos(g: Game) -> Vector2:
	var p: Dictionary = g.player
	var off := g.ip_off()
	# topo do gorro (o desenho do Tomé é mais alto que a caixa de colisão)
	return Vector2(p.x + p.w / 2 + off.x - p.face * 3.0, p.y + p.h + off.y - 59)

## borboleta: voa em volta de um ponto, batendo as asas; de vez em quando pousa numa flor (ou no
## chapéu do Tomé), fecha as asas e sai voando se ele chega perto ou se mexe
static func _butterfly(g: Game, c: Dictionary, T: int, i: int) -> void:
	var p: Dictionary = g.player
	var pcx: float = p.x + p.w / 2
	var path := _bpath(c, i)
	var pos := path
	var sit := false
	if not c.has("bs"):
		c.bs = "fly"
		c.bt = -hh(i, 25) * 300.0
	c.bt += k
	match c.bs:
		"fly":
			if c.bt > 360.0 + hh(i, 26) * 300.0:
				var tg := _bfly_target(g, c, i)
				c.bt = 0.0
				if not tg.is_empty():
					c.tg = tg
					c.bs = "go"
					c.from = path
		"go", "sit", "leave":
			var tp: Vector2 = _hat_pos(g) if c.tg.has("hat") else Vector2(c.tg.x, c.tg.y)
			var near_p: bool = abs(pcx - tp.x) < 70 and abs(p.y + p.h - tp.y) < 90 and abs(p.vx) > 1.0
			var hat_moved: bool = c.tg.has("hat") and (abs(p.vx) > .4 or not p.get("onGround", false) or p.get("crouch", false))
			if c.bs == "go":
				var u: float = clamp(c.bt / 70.0, 0, 1)
				var e: float = u * u * (3.0 - 2.0 * u)
				pos = c.from.lerp(tp, e) + Vector2(0, -sin(u * PI) * 18 + sin(c.bt * .4) * 3 * (1.0 - u))
				if u >= 1.0:
					c.bs = "sit"
					c.bt = 0.0
				elif hat_moved:
					c.bs = "leave"
					c.bt = 0.0
					c.from = pos
			elif c.bs == "sit":
				pos = tp
				sit = true
				if near_p or hat_moved or c.bt > 260.0 + hh(i, 28) * 260.0:
					c.bs = "leave"
					c.bt = 0.0
					c.from = tp
			else:
				var u2: float = clamp(c.bt / 50.0, 0, 1)
				pos = c.from.lerp(path, u2 * u2) + Vector2(0, -sin(u2 * PI) * 24)
				if u2 >= 1.0:
					c.bs = "fly"
					c.bt = 0.0
	if c.bs != "fly" and c.has("tg") and c.tg.has("hat"):
		# indo/saindo/pousada no gorro: desenhada depois do Tomé (camada da frente)
		FRONTQ.append([c, i, pos, sit])
		return
	_bfly_draw(c, i, pos, sit)

## borboletas que estão no gorro do Tomé: desenhadas pela camada da frente (front.gd), por cima
## do Tomé, com a transformação do mundo
static func draw_front(g: Game) -> void:
	# (a fila é refeita a cada quadro em draw(); não limpa aqui, a ordem de desenho dos nós pode variar)
	for q in FRONTQ:
		_bfly_draw(q[0], q[1], q[2], q[3])

static func _bfly_draw(c: Dictionary, i: int, pos: Vector2, sit: bool) -> void:
	var col: Color = [Color(1, 1, 1), Color(.7, .85, 1.2), Color(1.1, .75, .95), Color(1.1, 1.05, .6)][i % 4]
	if sit:
		# pousada: asas fechadas para cima, abrindo devagar de vez em quando
		var op: float = max(0.0, sin(c.bt * .05)) if fposmod(c.bt, 250.0) > 180.0 else 0.0
		if op > .5:
			Spr.PR("bfly_open", pos.x - 7, pos.y - 9, 14, 10 * op + 2, col)
		else:
			Spr.P("bfly_side", pos.x, pos.y + 1, 10, c.f < 0, 0.0, col)
		return
	var flap: float = abs(sin(FxClock.ft * .35 + i))
	if c.bs == "go" or c.bs == "leave":
		c.f = -1.0 if c.get("_px", pos.x) > pos.x else 1.0
	c._px = pos.x
	# asas abrindo e fechando: alterna a borboleta aberta (achatando) e de lado
	if flap > .45:
		Spr.PR("bfly_open", pos.x - 8, pos.y - 6, 16, 12 * flap + 2, col)
	else:
		Spr.P("bfly_side", pos.x, pos.y + 6, 11, sin(FxClock.ft * .02 + i) < 0, 0.0, col)

## coelho: vida parada (mastiga, mexe as orelhas, se coça, olha em volta) e foge pulando
## quando o Tomé chega
static func _rabbit(c: Dictionary, px: float, py: float, T: int) -> void:
	if c.st == "idle" and abs(px - c.x) < 170 and abs(py - c.y) < 120:
		c.st = "run"
		c.f = 1.0 if c.x > px else -1.0
		c.t = 0
	var hop: float = 0.0
	if c.st == "run":
		c.x += c.f * 4.2 * k
		hop = abs(sin(c.t * .25)) * 14
		# cada pouso de pulo deixa pegadas na neve
		if _cross(c.t, 4.0 * PI):
			_track(c, c.x, c.y)
		if c.t > 120:
			c.st = "gone"
			c.t = 0
	elif c.st == "gone":
		if c.t > 900 and abs(px - c.x0) > 600:
			_respawn(c)
		return
	Spr.ellipse(c.x, c.y + 1, 11, 2.5, Color(0, 0, 0, .2))
	var n := "rab_sit"
	var ox := 0.0
	var oy := 0.0
	var rot := 0.0
	if c.st == "run":
		n = "rab_jump" if hop > 5 else "rab_land"
	else:
		var near: bool = abs(px - c.x) < 300 and abs(py - c.y) < 160
		var cyc: float = fposmod(c.t + hh(c.x0, 3) * 300.0, 320.0)
		if near:
			# Tomé chegando: fica em pé de orelha em pé, olhando para ele
			n = "rab_alert"
			c.f = 1.0 if px > c.x else -1.0
		elif cyc < 100:
			# mastigando: a cabeça desce e sobe de leve
			oy = max(0.0, sin(cyc * .3)) * 1.2
			rot = .05 * c.f * max(0.0, sin(cyc * .3))
		elif cyc < 130:
			# orelhas tremendo (duas piscadas da pose de alerta)
			n = "rab_alert" if int(cyc / 5.0) % 2 == 0 else "rab_sit"
		elif cyc > 180 and cyc < 215:
			# coçando: tremidinha rápida
			ox = sin(cyc * 2.6) * .9
			rot = -.06 * c.f
		elif cyc > 250 and cyc < 280:
			n = "rab_alert"
		if _cross(c.t + hh(c.x0, 3) * 300.0, 320.0, 285.0) and not near:
			c.f = -c.f
	if rot != 0.0:
		Spr.save()
		Spr.translate(c.x + ox, c.y + 1 + oy)
		Spr.rotate(rot)
		Spr.P(n, 0, 0, 22, c.f < 0, 0.0, SOFT)
		Spr.restore()
	else:
		Spr.P(n, c.x + ox, c.y + 1 - hop + oy, 30 if c.st == "run" else 22, c.f < 0, 0.0, SOFT)

## sapinho do brejo: coaxa (papo inflando) e pula na água quando o Tomé chega
static func _frog(g: Game, c: Dictionary, px: float, py: float, T: int) -> void:
	if c.st == "idle" and abs(px - c.x) < 150 and abs(py - c.y) < 120:
		c.st = "jump"
		c.t = 0
	var jy: float = 0.0
	if c.st == "jump":
		# pula sempre para o lado da água (mesmo quando foi um susto)
		c.f = float(c.get("wf", c.f))
		var u: float = min(c.t / 30.0, 1.0)
		c.x = c.x0 + c.f * float(c.get("jd", 90.0)) * u
		var wy: float = float(c.get("wy", c.y0))
		c.y = lerpf(c.y0, wy, u)
		jy = sin(u * PI) * 40
		if c.t >= 30.0:
			if g.WV:
				g.WV.splash(c.x, wy, 2.5)
			Polish.part("ringw", c.x, wy, 0, 0, 24, Color(.85, .95, 1, .6), {"size": 26.0})
			Polish.drops(c.x, wy - 2, 4, 1.5)
			c.st = "gone"
			c.t = 0
	elif c.st == "gone":
		if c.t > 700 and abs(px - c.x0) > 600:
			_respawn(c)
		return
	var croak: float = 0.0
	if c.st == "idle":
		var cy: float = fposmod(c.t + hh(c.x0, 4) * 200.0, 200.0)
		if cy < 24:
			croak = sin(cy / 24.0 * PI)
	Spr.save()
	Spr.translate(c.x, c.y + 1 - jy)
	Spr.scale(1.0 + croak * .06, 1.0 - croak * .04)
	Spr.P("frog_jump" if c.st == "jump" else "frog_sit", 0, 0, 26 if c.st == "jump" else 20, c.f < 0)
	Spr.restore()
	if croak > .1:
		# papo inflando
		Spr.circle(c.x + c.f * 6, c.y - 3, 2.5 + croak * 3.0, Color(.9, .88, .6, .8))

## coruja num mourão de madeira fincado no chão: pisca devagar e vira a cabeça para o Tomé
static func _owl(c: Dictionary, T: int, i: int, px: float) -> void:
	var x: float = c.x0
	var gy: float = c.y0
	var ph: float = 70 + hh(i, 7) * 30
	Spr.ellipse(x, gy + 2, 12, 3, Color(0, 0, 0, .25))
	Spr.PR("stake", x - 8, gy - ph, 16, ph + 10, Color(.75, .7, .66))
	var blink: bool = fposmod(FxClock.ft + i * 37, 180.0) < 8
	# olha para o Tomé quando ele está por perto; senão, olha em volta devagar
	var want: float = (1.0 if px > x else -1.0) if abs(px - x) < 520 else (1.0 if sin(FxClock.ft * .004 + i) >= 0 else -1.0)
	var fs: float = c.get("fs", want)
	fs = move_toward(fs, want, .12 * k)
	c.fs = fs
	Spr.save()
	Spr.translate(x, gy - ph + 6)
	# virando: a cabeça "gira" (achata no meio da virada)
	Spr.scale(max(abs(fs), .3), 1)
	Spr.P("owl1" if blink else "owl0", 0, 0, 28, fs < 0)
	Spr.restore()

## vida na água: peixes saltando (arco + espirro) e libélulas pairando e dando tiros curtos
static func _water_life(g: Game) -> void:
	if g.indoors():
		return
	var x0: float = g.cam - 60
	var x1: float = g.cam + g.W + 60
	var ft: float = FxClock.ft
	var day: bool = not (Polish.period() in ["noite", "tunel"]) and g.AMB.dark < .4
	var wi := 0
	for w in _waters(g):
		wi += 1
		var lake: bool = g.X != null and g.X.WATER.has(w)
		var wx0: float = w.x
		var wx1: float = float(w.x) + float(w.w)
		var wy: float = w.y
		if wx1 < x0 or wx0 > x1 or float(w.w) < 120 or wy < g.cam_y - 40 or wy > g.cam_y + g.H + 40:
			continue
		var sd: int = int(wx0)
		# peixe: de vez em quando um salto em arco
		var per := 420.0
		var cyc: int = int((ft + hh(sd, 1) * per) / per)
		if lake and hh(sd + cyc, 2) < .55:
			var u: float = (fposmod(ft + hh(sd, 1) * per, per) - hh(sd + cyc, 3) * 300.0) / 44.0
			var fx: float = wx0 + 40 + hh(sd + cyc, 4) * (float(w.w) - 80)
			var dir: float = 1.0 if hh(sd + cyc, 5) > .5 else -1.0
			var span: float = 46 + hh(sd + cyc, 6) * 30
			var key: int = sd * 1000 + cyc
			if u >= 0.0 and u <= 1.0:
				var ax: float = fx + dir * span * u
				var ay: float = wy - sin(u * PI) * (34 + hh(sd + cyc, 7) * 24)
				if _splashed.get(key, 0) == 0:
					_splashed[key] = 1
					_splash(g, fx, wy, 1.6)
				var vy: float = -cos(u * PI) * PI
				var ang: float = atan2(vy * .9, dir * 1.2)
				_fish(ax, ay, ang, dir, Color(.62, .66, .58) if Polish.period() == "chuva" else Color(.72, .74, .7))
			elif u > 1.0 and _splashed.get(key, 0) == 1:
				_splashed[key] = 2
				_splash(g, fx + dir * span, wy, 2.0)
				if _splashed.size() > 40:
					_splashed.clear()
		# libélulas (de dia, sem chuva forte)
		if day and g.AMB.rain < .5:
			var nd: int = min(2, int(float(w.w) / 400.0) + 1)
			for d in nd:
				_dragonfly(sd * 7 + d, wx0, wx1, wy, ft)

static func _splash(g: Game, x: float, y: float, f: float) -> void:
	if g.WV:
		g.WV.splash(x, y, f, false)
	Polish.part("ringw", x, y, 0, 0, 22, Color(.85, .95, 1, .55), {"size": 20.0 + f * 6.0})
	Polish.drops(x, y - 2, 3 + int(f), 1.4)

static func _fish(x: float, y: float, ang: float, dir: float, c: Color) -> void:
	Spr.save()
	Spr.translate(x, y)
	Spr.rotate(ang)
	Spr.ellipse(0, 0, 9, 3.6, c)
	Spr.ellipse(1, -1.2, 6, 1.2, Color(1, 1, 1, .35))
	Spr.poly(PackedVector2Array([Vector2(-7, 0), Vector2(-14, -4.5), Vector2(-12.5, 0), Vector2(-14, 4.5)]), c.darkened(.15))
	Spr.circle(5.5, -.8, .9, Color(.1, .1, .1))
	Spr.restore()

static func _dragonfly(sd: int, wx0: float, wx1: float, wy: float, ft: float) -> void:
	var per: float = 110.0 + hh(sd, 1) * 70.0
	var tt: float = ft + hh(sd, 2) * per
	var n: int = int(tt / per)
	var ph: float = fposmod(tt, per)
	var a := Vector2(lerpf(wx0 + 30, wx1 - 30, hh(sd + n - 1, 3)), wy - 26 - hh(sd + n - 1, 4) * 40)
	var b := Vector2(lerpf(wx0 + 30, wx1 - 30, hh(sd + n, 3)), wy - 26 - hh(sd + n, 4) * 40)
	# tiro curto até o próximo ponto e depois paira tremendo
	var u: float = clamp(ph / 9.0, 0, 1)
	var pos := a.lerp(b, u * (2.0 - u)) + Vector2(sin(ft * .31 + sd) * 1.5, sin(ft * .47 + sd) * 1.2)
	var dir: float = 1.0 if b.x >= a.x else -1.0
	var dft: Texture2D = Spr.opt("dragonfly")
	if dft:
		# libélula pintada (vista de cima, de cabeça para a frente), achatada como vista de lado
		var fl2: float = .5 + .5 * sin(ft * 2.3 + sd)
		Spr.save()
		Spr.translate(pos.x, pos.y)
		Spr.scale(1.0, .42 + .08 * fl2)
		Spr.rotate(dir * PI / 2)
		Spr.ci.draw_texture_rect(dft, Rect2(-15, -9, 30, 18), false, Color(1, 1, 1, .95 * Spr.alpha))
		Spr.restore()
		return
	var bc := Color(.12, .45, .55, .95)
	Spr.seg(pos.x - dir * 9, pos.y + 1, pos.x + dir * 4, pos.y, bc, 1.8)
	Spr.circle(pos.x + dir * 5, pos.y, 1.6, Color(.1, .3, .35))
	var fl: float = .5 + .5 * sin(ft * 2.3 + sd)
	var wc := Color(.85, .95, 1, .32 + .2 * fl)
	Spr.ellipse(pos.x - dir * 1, pos.y - 2.5 - fl * 1.5, 6, 1.4, wc, -.35 * dir)
	Spr.ellipse(pos.x - dir * 3, pos.y - 2 - fl * 1.2, 5.5, 1.3, wc, .3 * dir)

## trilhas de formigas no chão (manhã e tarde), só perto da câmera
static func _ants(g: Game) -> void:
	var per: String = Polish.period()
	if not per in ["manha", "tarde"] or g.indoors() or g.AMB.rain > .2:
		return
	var p: Dictionary = g.player
	var pcx: float = p.x + p.w / 2
	var i0: int = int(floor((g.cam - 100) / 640.0))
	var i1: int = int(floor((g.cam + g.W + 100) / 640.0))
	var ft: float = FxClock.ft
	for i in range(i0, i1 + 1):
		if hh(i, 61) < .45:
			continue
		var ax: float = i * 640 + 100 + hh(i, 62) * 440
		if abs(ax - pcx) > 520:
			continue
		var key: int = 100000 + i
		if not C.has(key):
			var gy: float = _ground_y(g, ax)
			var ok: bool = gy != INF and not (g.L.has("under") and gy > float(g.L.under)) and not WSt.covered(g, ax, gy)
			ok = ok and WSt.gt_at(g, ax) == "" and _theme(g, ax) in ["manha", "tarde"]
			C[key] = {"k": "", "ants": ok, "y": gy}
		var a: Dictionary = C[key]
		if not a.ants:
			continue
		var gy2: float = a.y
		var dir: float = 1.0 if hh(i, 63) > .5 else -1.0
		for j in 9:
			var s: float = fposmod(ft * .22 + j * 10.0 + hh(i * 9 + j, 64) * 4.0, 92.0)
			var fade: float = clamp(min(s, 92.0 - s) / 10.0, 0, 1)
			var x: float = ax + dir * (s - 46.0)
			var y: float = gy2 + 1.5 + sin(s * .2 + i) * .8
			var cc := Color(.12, .08, .06, .85 * fade)
			Spr.rect(x - 1.8 + (dir - 1.0) * .2, y - .9, 3.2, 1.6, cc)
			if j == 4:
				# uma carregando um pedacinho de folha
				Spr.rect(x - .8, y - 3.0, 2.2, 1.8, Color(.45, .65, .25, .9 * fade))

## tucanos: chegam voando, pousam num galho, ficam olhando em volta e abrindo o bico;
## se o Tomé chega perto, levantam voo. Onde não há galho, só atravessam o céu de vez em quando.
static func _toucans(g: Game, T: int) -> void:
	if g.indoors():
		return
	var p: Dictionary = g.player
	var px: float = p.x + p.w / 2
	var py: float = p.y + p.h
	var i0: int = int(floor((g.cam - 300) / 900.0))
	var i1: int = int(floor((g.cam + g.W + 300) / 900.0))
	for i in range(i0, i1 + 1):
		if not TU.has(i):
			var cx: float = i * 900 + 450
			var th := _theme(g, cx)
			var many: bool = g.sec_param("toucans", 0) != 0
			if not th in ["manha", "tarde", "chuva"] or hh(i, 21) < (0.0 if many else .35):
				TU[i] = {"k": ""}
				continue
			var perch = null
			for so in g.SOL:
				# tucano só lá no alto (galhos altos), longe do caminho do Tomé
				if str(so.get("t", "")) == "branch" and so.y < 300 and so.x + so.w > i * 900 and so.x < i * 900 + 900:
					perch = so
					break
			var gy: float = _ground_y(g, cx)
			if perch == null and gy == INF:
				TU[i] = {"k": ""}
				continue
			var t := {"k": "tu", "st": "away", "t": -int(hh(i, 22) * 400), "f": 1.0, "x": 0.0, "y": 0.0, "fr": 0}
			if perch != null:
				t.px = perch.x + perch.w * (.3 + hh(i, 23) * .4)
				t.py = perch.y + 2 + perch.get("dip", 0.0)
				t.perch = perch
			else:
				t.px = cx
				t.py = gy - 380
			TU[i] = t
		var u: Dictionary = TU[i]
		if u.k == "":
			continue
		u.t += k
		var has_perch: bool = u.has("perch")
		if has_perch:
			u.py = u.perch.y + 2 + u.perch.get("dip", 0.0)
		match u.st:
			"away":
				if u.t > 0 and abs(px - u.px) > 260:
					u.st = "in"
					u.f = 1.0 if hh(i + int(u.t), 24) > .5 else -1.0
					u.x = u.px - u.f * (g.W * .7 + 100)
					u.y = u.py - 240
					u.t = 0
			"in":
				var tx: float = u.px
				var ty: float = u.py
				if not has_perch:
					tx = u.px + u.f * (g.W + 600)
				var dx: float = tx - u.x
				var spd: float = 4.2 * k
				u.x += sign(dx) * min(abs(dx), spd)
				if has_perch:
					var kk: float = clamp(abs(dx) / (g.W * .7 + 100), 0, 1)
					u.y = ty - 240 * kk * kk - sin(kk * PI) * 30
					if abs(dx) < 40:
						u.st = "land"
						u.t = 0
				else:
					u.y = ty + sin(u.t * .03) * 20
					if abs(dx) < 5:
						u.st = "away"
						u.t = -1600
			"land":
				u.x = lerpf(u.x, u.px, 1.0 - pow(.8, k))
				u.y = lerpf(u.y, u.py, 1.0 - pow(.75, k))
				if u.t > 14:
					u.st = "sit"
					u.t = 0
			"sit":
				u.x = u.px
				u.y = u.py
				if abs(px - u.px) < 170 and abs(py - u.py) < 220:
					u.st = "off"
					u.f = 1.0 if u.px > px else -1.0
					u.t = 0
			"off":
				u.x += u.f * 4.5 * k
				u.y -= 3.2 * k
				if u.t > 140:
					u.st = "away"
					u.t = -1400
		if u.st == "away":
			continue
		if u.x < g.cam - 120 or u.x > g.cam + g.W + 120:
			continue
		var n := "tuc_sit0"
		var fl := [0, 1, 2, 1]
		var ft: float = FxClock.ft
		match u.st:
			"in", "off":
				if u.st == "in" and has_perch and fposmod(u.t, 90.0) > 60:
					n = "tuc_glide"
				else:
					n = "tuc_f%d" % fl[int(ft / 5) % 4]
					u._fly = true
			"land":
				n = "tuc_land"
			"sit":
				var cyc: float = fposmod(u.t + i * 53, 400.0)
				n = "tuc_sit2" if cyc > 330 and cyc < 370 else ("tuc_sit1" if cyc > 200 and cyc < 230 else "tuc_sit0")
				if _cross(u.t + i * 53, 400.0, 260.0):
					u.f = -u.f
		# bichos do cenário: menores e de cor suave (os inimigos são grandes, fortes e com contorno vermelho)
		var w: float = 36.0 if u.st == "sit" else 42.0
		if u.get("_fly", false) and n.begins_with("tuc_f"):
			# batendo asas: quadros intermediários (x4)
			Spr.P_cycle("tuc_f", ["tuc_f0", "tuc_f1", "tuc_f2", "tuc_f1"], ft / 5.0, u.x, u.y + 16.0, w, u.f < 0, SOFT)
		else:
			Spr.P(n, u.x, u.y + (0.0 if u.st == "sit" else 16.0), w, u.f < 0, 0.0, SOFT)
		u._fly = false
