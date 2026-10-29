extends Node2D
class_name AmbientFx
## Efeitos de ambiente que se mexem, por cima do cenário fixo e por baixo de tudo que se mexe (fica atrás
## do Tomé, dos bichos e das tábuas, e dentro da escuridão): brilho molhado no chão e nas pedras na chuva,
## poças refletindo o céu com pingos, luz quente da tarde e tronco molhado, fumaça das chaminés da vila,
## brilho correndo no gelo e reflexo no chão de gelo, sombra dos galhos no chão.
## O estado (esporos, pingos, galhos balançando, faíscas) só avança no passo de física: tick(). O desenho
## é função do tempo do jogo (T) e da posição no mundo — nada cresce enquanto o jogo está pausado.

const WS = preload("res://scripts/world_static.gd")

var game: Game

func _process(_d: float) -> void:
	queue_redraw()

# ================================================================ estado (passo de física)
static var _last_T := -1
static var _L = null
## cache do nível: listas de troncos, chãos, pedras, poças, casas, gelo e galhos
static var C := {}
## esporos brilhantes subindo dos cogumelos (desenhados em world_glow, acima da escuridão)
static var SPORES: Array = []
## galhos ainda balançando depois que o Tomé saiu
static var _wobs: Array = []
static var _was_g = null

## janelas e lampiões das casas da vila (frações da arte: u, v, largura, altura), chaminé (u, v)
const WIN := {
	0: [[.479, .30, .09, .08], [.238, .55, .1, .085], [.48, .55, .1, .085], [.718, .55, .1, .085], [.264, .843, .09, .09], [.713, .842, .09, .09]],
	1: [[.28, .533, .1, .1], [.756, .532, .1, .1], [.28, .81, .1, .11], [.76, .81, .1, .11]],
	2: [[.566, .452, .09, .11], [.264, .80, .13, .1], [.745, .80, .12, .1]],
}
const LAMP := {0: [.629, .79], 1: [.377, .786], 2: [.39, .774]}
const CHIM := {0: [.75, .02], 1: [.25, .02], 2: [.28, .02]}

## período do trecho onde o Tomé está (como Polish.period, mas com o jogo dado)
static func period(g: Game) -> String:
	if g == null or g.L == null:
		return "manha"
	var s: String = g.AMB.get("song", "manha")
	if g.AMB.get("snow", 0.0) > .3 or s == "tema":
		return "neve"
	if s == "perseguicao":
		return "noite"
	return s

## cor do céu do período (reflexo na água e nas poças)
static func sky_col(per: String) -> Color:
	match per:
		"tarde":
			return Color(1, .72, .45)
		"chuva", "pantano":
			return Color(.62, .7, .7)
		"neve", "tema":
			return Color(.88, .94, 1)
		"noite", "perseguicao", "tunel":
			return Color(.32, .4, .62)
	return Color(.75, .9, 1)

static func _cache(g: Game) -> void:
	if is_same(_L, g.L):
		return
	_L = g.L
	SPORES = []
	_wobs = []
	_was_g = null
	var tr: Array = []
	var gr: Array = []
	var st: Array = []
	var pd: Array = []
	var ho: Array = []
	var ic: Array = []
	for s in g.L.solids:
		var t: String = str(s.get("t", ""))
		match t:
			"trunk":
				tr.append(s)
			"ground":
				if not s.get("snow"):
					gr.append(s)
				for p in WS.puddles_of(g, s):
					pd.append(p)
			"stone":
				if s.get("ice"):
					ic.append(s)
				else:
					st.append(s)
			"ice":
				ic.append(s)
			"house":
				ho.append(s)
	var br: Array = []
	for s in g.SOL:
		if str(s.get("t", "")) == "branch":
			br.append(s)
	C = {"tr": tr, "gr": gr, "st": st, "pd": pd, "ho": ho, "ic": ic, "br": br}

## passo de física (chamado por Waves.step, uma vez por T)
static func tick(g: Game) -> void:
	if g == null or g.L == null or g.player.is_empty():
		return
	if g.T == _last_T:
		return
	_last_T = g.T
	Polish.g = g
	_cache(g)
	_tick_sparkles(g)
	_tick_branches(g)
	_tick_spores(g)
	_tick_drips(g)

## faíscas das penas especiais, do lápis dourado e dos frascos, e folhinhas das moitas (antes eram
## criadas no desenho: com o jogo pausado nasciam uma por quadro e a lista crescia sem parar)
static func _tick_sparkles(g: Game) -> void:
	var T: int = g.T
	var x0: float = g.cam - 80
	var x1: float = g.cam + g.W + 80
	if T % 10 == 0:
		for s in g.SPECS:
			if s.got or s.x < x0 or s.x > x1:
				continue
			var b4 := sin(T * .09 + s.x) * 4
			var sy: float = s.y + b4 if s.ry < 0 else s.ry - 22 + b4 * .5
			Polish.part("spark", s.x + (randf() - .5) * 20, sy, 0, -.6, 20, GameData.PEN_COL[s.c], {"g": 0.0})
	if g.X and T % 8 == 0 and not g.X.GOLD.is_empty() and not g.X.GOLD.got and g.X.GOLD.x > x0 and g.X.GOLD.x < x1:
		var gy: float = g.X.GOLD.y + sin(T * .07) * 3
		Polish.part("spark", g.X.GOLD.x + (randf() - .5) * 26, gy + (randf() - .5) * 20, 0, -.5, 22, Color("#ffe27a"), {"g": 0.0})
	if T % 16 == 0:
		for c in g.OIL:
			if c.got or c.x < x0 or c.x > x1:
				continue
			var by: float = c.ry if c.ry > 0 else c.y + 16
			Polish.part("spark", c.x + (randf() - .5) * 14, by - 22, 0, -.4, 26, Color(1, .85, .45) if g.lantern_lit else Color(.8, 1, .5), {"g": 0.0})
	var p: Dictionary = g.player
	if T % 6 == 0 and abs(p.vx) > .5:
		for bsh in g.BUSH:
			var near: bool = abs(p.x + p.w / 2 - (bsh.x + bsh.w / 2)) < bsh.w / 2 + 10 and abs(p.y + p.h - (bsh.y + bsh.h)) < bsh.h
			if near:
				Polish.part("leaf", bsh.x + randf() * bsh.w, bsh.y + bsh.h - 60 - randf() * 20, randf_range(-1, 1), -randf_range(.5, 1.5), 60, Polish.leaf_col(), {"gy": bsh.y + bsh.h})

## pouso num galho: folhas (ou neve) caindo; ao sair, o galho fica balançando e se acalma
static func _tick_branches(g: Game) -> void:
	var cur = g.player.get("_g")
	if not is_same(cur, _was_g):
		if cur is Dictionary and str(cur.get("t", "")) == "branch":
			var px: float = clamp(g.player.x + g.player.w * .5, cur.x, cur.x + cur.w)
			var gb: float = _ground_under(g, cur)
			var th: String = cur.get("_th", WS.theme_at(g, cur.x + cur.w * .5))
			if th == "neve":
				if not cur.has("_snow_t") or g.T - int(cur._snow_t) > 900:
					cur._snow_t = g.T
					for i in 12:
						Polish.part("snow", cur.x + randf() * cur.w, cur.y - 2, randf_range(-.4, .4), randf_range(-.6, .3), 90, Color(.97, .98, 1, .95), {"gy": gb, "size": randf_range(1.6, 3.0)})
			else:
				for i in 3 + randi() % 3:
					Polish.part("leaf", px + randf_range(-40, 40), cur.y + randf_range(2, 26), randf_range(-.8, .8), randf_range(-.6, .4), 220, Polish.leaf_col(), {"gy": gb})
		if _was_g is Dictionary and str(_was_g.get("t", "")) == "branch":
			_was_g._wob = 1.0
			if not _wobs.has(_was_g):
				_wobs.append(_was_g)
		_was_g = cur
	var keep: Array = []
	for b in _wobs:
		b._wob = float(b._wob) * .965
		if b._wob > .02 and not is_same(b, cur):
			keep.append(b)
		else:
			b._wob = 0.0
	_wobs = keep

## chão embaixo de um galho (guardado no galho)
static func _ground_under(g: Game, s: Dictionary) -> float:
	if not s.has("_gb"):
		var best := 1e9
		var cx: float = s.x + s.w * .5
		for o in g.L.solids:
			var t: String = str(o.get("t", ""))
			if not t in ["ground", "dirt", "cliff", "stone", "rockw", "hill"] or o.get("ceil"):
				continue
			if cx >= o.x and cx <= o.x + o.get("w", 0) and o.y > s.y + 4 and o.y < best:
				best = o.y
		s._gb = best
	return s._gb

## é escuro aqui? (esporos e vaga-lumes só aparecem no escuro)
static func is_dark(g: Game) -> bool:
	return g.AMB.get("dark", 0.0) > .3 or period(g) in ["noite", "tunel", "perseguicao"] or g.indoors()

## esporos subindo devagar dos cogumelos que brilham (à noite)
static func _tick_spores(g: Game) -> void:
	for s in SPORES:
		s.l -= 1
		s.vx += sin((s.l + s.ph) * .05) * .01
		s.x += s.vx
		s.y += s.vy
	SPORES = SPORES.filter(func(s): return s.l > 0)
	if not is_dark(g) or g.submerged():
		return
	var cap: int = 14 if g.low_fx else 70
	if SPORES.size() >= cap:
		return
	var x0: float = g.cam - 40
	var x1: float = g.cam + g.W + 40
	if g.T % 14 == 0:
		for s in g.SPR:
			if s.x > x0 and s.x < x1 and randf() < .7:
				_spore(s.x + randf_range(-14, 14), s.y - 26, Color(.55, .85, 1))
	if g.TR and g.T % 9 == 0:
		for o in g.TR.T:
			if o.k == "giant" and o.x > x0 - 100 and o.x < x1 + 100 and randf() < .45:
				var gc := Color(o.get("c", "#6a5acd")).lightened(.35)
				_spore(o.x + randf_range(-.32, .32) * o.w, o.cap + 6, gc)

static func _spore(x: float, y: float, c: Color) -> void:
	var l: int = randi_range(150, 240)
	SPORES.append({"x": x, "y": y, "vx": randf_range(-.15, .15), "vy": -randf_range(.22, .42), "l": l, "l0": l, "ph": randf() * 50.0, "c": c})

## pinguinhos caindo da ponta dos pingentes de gelo de vez em quando
static func _tick_drips(g: Game) -> void:
	if g.low_fx or WS.ICICLES.is_empty() or not is_same(WS._ic_L, g.L):
		return
	var x0: float = g.cam - 20
	var x1: float = g.cam + g.W + 20
	for k in WS.ICICLES:
		var tip: Vector2 = WS.ICICLES[k]
		if tip.x < x0 or tip.x > x1 or tip.y < g.cam_y - 20 or tip.y > g.cam_y + g.H:
			continue
		var per: int = 170 + int(Polish.hh2(tip.x, 3) * 260)
		if (g.T + int(tip.x * 7.0)) % per == 0:
			Polish.part("drop", tip.x, tip.y + 1, 0, .4, 46, Color(.82, .93, 1, .85), {"size": 1.4})

# ================================================================ desenho
func _draw() -> void:
	if game == null or not game.L or game.player.is_empty():
		return
	var __t := Time.get_ticks_usec()
	Spr.begin(self)
	Polish.g = game
	_cache(game)
	var g := game
	var T: int = g.T
	var x0: float = g.cam - 60
	var x1: float = g.cam + g.W + 60
	var rain: float = clamp(float(g.AMB.get("rain", 0.0)), 0.0, 1.0)
	var inside: bool = g.indoors()
	if rain > .12 and not inside:
		_wet(g, T, x0, x1, rain)
	_puddles(g, T, x0, x1, rain)
	_trunks(g, T, x0, x1, rain)
	_branch_shadows(g, x0, x1)
	_chimneys(g, T, x0, x1)
	_ice(g, T, x0, x1)
	Spr.pt("ambient", __t)

## U5 chão e pedras molhados na chuva: faixa clara na beira do chão e brilhos que correm devagar
func _wet(g: Game, T: int, x0: float, x1: float, rain: float) -> void:
	var yv0: float = g.cam_y - 40
	var yv1: float = g.cam_y + g.H + 40
	for s in C.gr:
		if s.x > x1 or s.x + s.w < x0 or s.y < yv0 or s.y > yv1:
			continue
		var a: float = max(s.x, x0)
		var b: float = min(s.x + s.w, x1)
		Spr.vgrad(a, s.y - 3, b - a, 7, Color(.8, .9, 1, .07 * rain), Color(.8, .9, 1, 0))
		var gx: float = floor(a / 64.0) * 64.0
		while gx < b:
			var hx: float = gx + Polish.hh2(gx, 5) * 64.0
			if hx > a and hx < b:
				var k: float = .5 + .5 * sin(T * .045 + gx * .07)
				Spr.ellipse(hx, s.y - 1, 9 + 6 * k, 1.2, Color(.9, .96, 1, .22 * rain * k))
			gx += 64.0
	for s in C.st:
		if s.x > x1 or s.x + s.w < x0:
			continue
		var cx: float = s.x + s.w * .5
		Spr.ellipse(cx - s.w * .1, s.y + 3, s.w * .3, 2.4, Color(.9, .96, 1, .2 * rain))
		Spr.ellipse(cx + s.w * .18, s.y + 6 + sin(T * .03 + s.x) * 1.0, 4, 1.4, Color(1, 1, 1, .3 * rain))

## S3 poças: refletem a cor do céu, brilho que corre e, na chuva, aneizinhos dos pingos
func _puddles(g: Game, T: int, x0: float, x1: float, rain: float) -> void:
	if C.pd.is_empty():
		return
	var sky := sky_col(period(g))
	for p in C.pd:
		var px: float = p[0]
		if px < x0 or px > x1:
			continue
		var py: float = p[1]
		var w: float = p[2]
		Spr.ellipse(px + w * .1, py + 1, w * .8, 2.2, Color(sky.r, sky.g, sky.b, .3))
		var sh: float = fposmod(T * .006 + Polish.hh2(px, 2), 1.0)
		Spr.ellipse(px - w * .6 + sh * w * 1.2, py + .6, w * .18, .9, Color(1, 1, 1, .35 * sin(sh * PI)))
		if rain > .1:
			for k in 2:
				var ph: float = T * .03 + Polish.hh2(px + k, 7) + k * .5
				var u: float = fposmod(ph, 1.0)
				var rx: float = px + (Polish.hh2(px + k * 13.0 + floor(ph) * 3.1, 8) - .5) * w * 1.3
				_flat_ring(rx, py + 1, 1.5 + u * 7.0, Color(.9, .96, 1, (1.0 - u) * .55 * rain))

## anel achatado (ondinha vista de lado)
func _flat_ring(x: float, y: float, r: float, c: Color, sy: float = .32) -> void:
	Spr.save()
	Spr.translate(x, y)
	Spr.scale(1, sy)
	Spr.ring(0, 0, r, c, 1.3 / sy * .7)
	Spr.restore()

## T6 luz quente da tarde de lado nos troncos (com manchinhas de sol passando pelas folhas);
## T10 na chuva o tronco fica escuro e molhado, com um fio de brilho e gotas escorrendo
func _trunks(g: Game, T: int, x0: float, x1: float, rain: float) -> void:
	for s in C.tr:
		if s.x + s.w * 1.6 < x0 or s.x - s.w > x1:
			continue
		var th: String = s.get("_th", "")
		if th == "":
			th = WS.theme_at(g, s.x + s.w * .5)
			s._th = th
		var cx: float = s.x + s.w * .5
		var hw: float = s.w * .55
		var ya: float = max(s.y, g.cam_y - 40)
		var yb: float = min(s.y + s.h - 12, g.cam_y + g.H + 40)
		if yb <= ya:
			continue
		if th == "tarde":
			Spr.hgrad(cx + hw * .25, ya, hw * .7, yb - ya, Color(1, .7, .35, 0), Color(1, .74, .4, .2))
			for i in 3:
				var dy: float = fposmod(Polish.hh2(s.x + i, 9) * 400.0 + sin(T * .008 + i * 2.0) * 30.0, max(1.0, s.h - 40))
				var fy: float = s.y + 20 + dy
				if fy > ya and fy < yb:
					var fk: float = .5 + .5 * sin(T * .02 + i * 1.7 + s.x)
					Spr.ellipse(cx + (Polish.hh2(s.x - i, 4) - .4) * hw, fy, 5 + fk * 3, 8 + fk * 4, Color(1, .82, .5, .12 + .08 * fk))
		if rain > .15 and th in ["chuva", "noite", "tarde", "manha"]:
			Spr.rect(cx - hw, ya, hw * 2, yb - ya, Color(.05, .07, .1, .14 * rain))
			var sx: float = cx - hw * .35
			Spr.vgrad(sx, ya, 2.5, yb - ya, Color(.85, .95, 1, .18 * rain), Color(.85, .95, 1, .05 * rain))
			for i in 2:
				var dy2: float = fposmod(T * (1.1 + i * .4) + Polish.hh2(s.x + i, 6) * 600.0, max(1.0, yb - ya))
				Spr.ellipse(sx + 1 + i * hw * .5, ya + dy2, 1.4, 2.4, Color(.9, .97, 1, .55 * rain))

## G8 sombra macia do galho no chão (mais fraca e larga quanto mais alto o galho)
func _branch_shadows(g: Game, x0: float, x1: float) -> void:
	for s in C.br:
		if s.x > x1 or s.x + s.w < x0:
			continue
		var gb: float = _ground_under(g, s)
		var hgt: float = gb - s.y
		if hgt > 420 or hgt < 10:
			continue
		var k: float = clamp(1.0 - hgt / 420.0, .2, 1.0)
		Polish.shadow(s.x + s.w * .5, gb + 1, s.w * .42 * (1.6 - k * .6), 3 + k * 2, .14 * k)

## S7 fumaça das chaminés das casas da vila, inclinando com o vento
func _chimneys(g: Game, T: int, x0: float, x1: float) -> void:
	if C.ho.is_empty():
		return
	var wind: float = float(g.AMB.get("wind", 0.0)) + Polish.gust_k() * .6
	var n: int = 4 if g.low_fx else 11
	for s in C.ho:
		if s.x > x1 + 200 or s.x + s.w < x0 - 200:
			continue
		var v: int = int(s.get("v", 0))
		var r = Spr.AR.get("p_casa%d" % v)
		if r == null or not CHIM.has(v):
			continue
		var h: float = s.w * r[3] / r[2]
		var u: float = CHIM[v][0]
		if s.get("flip", false):
			u = 1.0 - u
		var hx: float = s.x + s.w * u
		var hy: float = s.y + 3 - h + h * CHIM[v][1]
		for i in n:
			var age: float = fposmod(T * .45 + i * (196.0 / n) + hx * .37, 196.0) / 196.0
			var sx: float = hx + age * (14.0 + wind * 110.0) + sin(age * 4.0 + i * 1.7 + hx) * (4.0 + age * 10.0)
			var sy: float = hy - age * 150.0 * (1.0 - wind * .35)
			var sa: float = .5 * (1.0 - age) * min(1.0, age * 7.0)
			# fumaça macia (brilho radial: sem borda dura) crescendo e se desfazendo
			Spr.glow(sx, sy, 9 + age * 34, Color(.84, .84, .88, sa))

## Z1 brilho que atravessa o gelo de vez em quando; Z7 reflexo fraco do Tomé no chão de gelo
func _ice(g: Game, T: int, x0: float, x1: float) -> void:
	if C.ic.is_empty():
		return
	var p: Dictionary = g.player
	for s in C.ic:
		if s.x > x1 or s.x + s.w < x0:
			continue
		var per := 300.0
		var ph: float = fposmod(T + Polish.hh2(s.x, 11) * per, per) / 80.0
		if ph < 1.0:
			var ia: float = s.x + 4
			var ib: float = s.x + s.w - 4
			var bx: float = ia - 16 + ph * (ib - ia + 32)
			var top: float = s.y + 2
			var bot: float = s.y + s.h - 2
			var sl: float = (bot - top) * .45
			var qa: float = clamp(bx, ia, ib)
			var qb: float = clamp(bx + 9, ia, ib)
			var qc: float = clamp(bx + 9 - sl, ia, ib)
			var qd: float = clamp(bx - sl, ia, ib)
			var al: float = .32 * sin(ph * PI)
			if qb - qa > .5 or qc - qd > .5:
				Spr.poly(PackedVector2Array([Vector2(qa, top), Vector2(qb, top), Vector2(qc, bot), Vector2(qd, bot)]), Color(1, 1, 1, al))
		# reflexo: o Tomé em pé no gelo (placa sobre a água ou bloco)
		if is_same(p.get("_g"), s) and not g.low_fx:
			var fx: float = p.x + p.w * .5
			var fy: float = s.y + 2
			Spr.ellipse(fx, fy + 7, 7, 5, Color(.45, .2, .14, .16))
			Spr.ellipse(fx, fy + 15, 5, 4, Color(.2, .4, .2, .12))
			Spr.ellipse(fx, fy + 2, 11, 1.5, Color(1, 1, 1, .18))
