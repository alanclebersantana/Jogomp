extends RefCounted
class_name WorldTraps
## Desenho dos saltos e armadilhas (tudo por código, no mesmo traço de livro ilustrado do cenário).

const OUT := Color("#2a1a0e")
const WOOD := Color("#7a5232")
const WOOD_D := Color("#4e331d")
const STEEL := Color("#b9c2c9")
const STEEL_D := Color("#6c7680")

static func draw(g: Game, T: int) -> void:
	var TR: Traps = g.TR
	if TR == null:
		return
	var c0: float = g.cam - 220
	var c1: float = g.cam + g.W + 220
	for o in TR.T:
		var ox: float = o.get("bx", o.x)
		if ox < c0 - 400 or ox > c1 + 400:
			continue
		# cogumelo gigante (o desenho mais caro): só quando ele aparece de fato na tela
		if o.k == "giant" and (ox + o.w * .8 + 40 < g.cam or ox - o.w * .8 - 40 > g.cam + g.W):
			continue
		match o.k:
			"bounce": _bounce(g, TR, o, T)
			"flower": _flower(g, TR, o, T)
			"wind": _wind(o, T)
			"spikes": _spikes(TR, o, T)
			"roll": _roll(o)
			"axe": _axe(TR, o, T)
			"snap": _snap(o, T)
			"cage": _cage(o, T)
			"net": _net(o, T)
			"swing": _swing(g, TR, o, T)
			"hive": _hive(g, o, T)
			"sand": _sand_back(o, T)
			"web": _web(g, o, T)
			"gust": _gust(TR, o, T)
			"bridge": _bridge(o, T)
			"boulder": _boulder(g, o, T)
			"giant": _giant_cached(g, o, T)
			"icicle": _icicle(g, o, T)
	_bobs(g, T)
	_ice_hits(g, T)
	_tunnel_ceiling(g, T)
	if not TR.PICK.is_empty():
		_pick(TR.PICK)

# ---------- cogumelo saltador ----------
static func _bounce(g: Game, TR: Traps, o: Dictionary, T: int) -> void:
	# o chapéu segue o amassado como uma mola: afunda, estica de volta passando do ponto e assenta
	var sv: Vector2 = o.get("_sqs", Vector2.ZERO)
	if Polish.FRESH:
		sv.y += (float(o.get("squash", 0.0)) - sv.x) * .3
		sv.y *= .74
		sv.x += sv.y
		o._sqs = sv
	var sq: float = clamp(sv.x, -.45, 1.2)
	var x: float = o.x
	var y: float = o.y
	# inclina o chapéu para onde ele vai lançar
	var to = o.get("to")
	var tilt := 0.0
	if to is float or to is int:
		var nx: Dictionary = TR.T[int(to)]
		tilt = clamp((nx.x - x) / 900.0, -.35, .35)
	elif to is Array:
		tilt = clamp((float(to[0]) - x) / 900.0, -.35, .35)
	Spr.glow(x, y - 30, 46, Color(1, .75, .55, .25 + sin(T * .08 + x) * .08))
	Spr.ellipse(x + 3, y + 1, 24, 4.5, Color(0, 0, 0, .28))
	# caule com volume (encurta junto com o chapéu quando amassa)
	var stl: Array = _mstem_lr(x, y - 21 + sq * 6, 13.0, x, y + 1, 18.0, 0.0, 5)
	_mstem(stl[0], stl[1], Color("#efe2c4"), x)
	Spr.save()
	Spr.translate(x, y - 22 + sq * 6)
	Spr.rotate(tilt)
	Spr.scale(1 + sq * .35, 1 - sq * .4)
	var cc := Color("#d8452c") if o.get("c", "") != "azul" else Color("#3f84d0")
	_mcap(0, -24, 66, 24, cc, Color("#fbf3dc"), x, true, Color(0, 0, 0, 0), 5)
	Spr.restore()

# ---------- cogumelos: chapéu e caule com volume (todos os cogumelos das armadilhas usam) ----------
const MU_LIGHT := Vector2(-.55, -.84)   # luz de cima, um pouco à esquerda

static func _mh(a: float, b: float) -> float:
	return fposmod(sin(a * 12.9898 + b * 78.233) * 43758.5453, 1.0)

## chapéu de cogumelo com o topo em (cx, ty), largura w e altura h até a borda: lamelas por baixo,
## cúpula com luz e sombra própria (leque de cores a partir do ponto de luz), lábio grosso na borda,
## pintas em relevo (achatadas perto da borda), brilho molhado e, se frill.a > 0, a saia de babados
static func _mcap(cx: float, ty: float, w: float, h: float, col: Color, spot: Color, sd: float, gills: bool = true, frill: Color = Color(0, 0, 0, 0), nsp: int = 6) -> void:
	var rx: float = w * .5
	var rim: float = ty + h
	if gills:
		# lado de baixo: lamelas saindo do pé até a borda
		Spr.ellipse(cx, rim + 2, rx * .9 + 1.5, h * .26 + 2.0, OUT)
		Spr.ellipse(cx, rim + 2, rx * .9, h * .26, Color("#d2b48c"))
		Spr.ellipse(cx, rim + 1 + h * .05, rx * .42, h * .1, Color("#a2835c"))
		for k in 15:
			var a: float = PI * (k + .5) / 15.0
			Spr.seg(cx + cos(a) * rx * .25, rim + 2 + sin(a) * h * .06, cx + cos(a) * rx * .86, rim + 2 + sin(a) * h * .24, Color(.4, .28, .16, .55), 1.0)
	var N := 22
	var dome := PackedVector2Array()
	var cols := PackedColorArray()
	var hi: Color = col.lightened(.3)
	var lo: Color = col.darkened(.55)
	for i in N + 1:
		var a: float = PI + PI * i / float(N)
		var bul: float = pow(abs(sin(a)), .62)          # cúpula estufada (mais cheia que meia elipse)
		dome.push_back(Vector2(cx + cos(a) * rx, rim - bul * h))
		var d: float = Vector2(cos(a), -bul).normalized().dot(MU_LIGHT)
		cols.push_back(col.lerp(hi, d * .5) if d > 0.0 else col.lerp(lo, -d * .75))
	var lip := PackedVector2Array()
	for i in 9:
		var u: float = i / 8.0
		lip.push_back(Vector2(cx + rx - 2.0 * rx * u, rim + sin(u * PI) * h * .15))
	var ol := dome.duplicate()
	ol.append_array(lip)
	Spr.poly(ol, OUT)
	# cúpula: leque do ponto de luz até a borda
	var hc := Vector2(cx - rx * .26, rim - h * .64)
	var hcol: Color = col.lightened(.32)
	for i in N:
		Spr.ci.draw_polygon(PackedVector2Array([hc, dome[i], dome[i + 1]]), PackedColorArray([Spr.col(hcol), Spr.col(cols[i]), Spr.col(cols[i + 1])]))
	Spr.ci.draw_polygon(PackedVector2Array([hc, dome[N], dome[0]]), PackedColorArray([Spr.col(hcol), Spr.col(cols[N]), Spr.col(cols[0])]))
	# lábio da borda (a espessura do chapéu), mais escuro embaixo
	Spr.poly(lip, col.darkened(.42))
	Spr.seg(cx - rx * .92, rim + 1, cx + rx * .92, rim + 1, Color(1, 1, 1, .12), 1.2)
	# pintas em relevo: sombra embaixo, a pinta e um brilho em cima
	for k in nsp:
		var u2: float = clamp((k + .5) / float(nsp) + (_mh(sd, k) - .5) * .12, .08, .92)
		var v2: float = .28 + _mh(sd + 3.1, k) * .5
		var a2: float = PI + PI * u2
		var bul2: float = pow(abs(sin(a2)), .62)
		var px: float = cx + cos(a2) * rx * .9 * (1.0 - v2 * .25)
		var py: float = rim - bul2 * h * v2 - h * .08
		var sz: float = w * (.045 + _mh(sd + 7.7, k) * .045)
		var sx: float = sz * (.45 + .55 * abs(sin(a2)))
		var sy: float = sz * (.55 + .35 * v2)
		Spr.ellipse(px + .8, py + 1.4, sx + .6, sy + .4, Color(lo.r, lo.g, lo.b, .55))
		Spr.ellipse(px, py, sx, sy, spot)
		Spr.ellipse(px - sx * .3, py - sy * .34, sx * .4, sy * .3, Color(1, 1, 1, .32))
	# brilho molhado: risco de luz curvo no alto e uma gotinha de reflexo
	var shp := PackedVector2Array()
	for i in 7:
		var a3: float = PI * 1.14 + PI * .3 * i / 6.0
		shp.push_back(Vector2(cx + cos(a3) * rx * .78, rim - pow(abs(sin(a3)), .62) * h * .84))
	Spr.line(shp, Color(1, 1, 1, .38), max(1.4, h * .09))
	Spr.circle(cx - rx * .12, rim - h * .9, max(1.1, h * .05), Color(1, 1, 1, .75))
	Spr.line(ol, OUT, 2.2)
	if frill.a > 0.0:
		# saia de babados na borda (os cogumelos-mola)
		var nf: int = int(clamp(w / 9.0, 8.0, 20.0))
		var fr: float = max(3.0, h * .16)
		for pass_ in 2:
			for k in nf:
				var u3: float = k / float(nf - 1)
				var fx: float = cx - rx * .97 + rx * 1.94 * u3
				var fy: float = rim + sin(u3 * PI) * h * .15 + 2.0
				if pass_ == 0:
					Spr.circle(fx, fy, fr + 1.5, OUT)
				else:
					Spr.circle(fx, fy, fr, frill)
					Spr.circle(fx + fr * .25, fy + fr * .3, fr * .6, frill.darkened(.18))
					Spr.circle(fx - fr * .3, fy - fr * .35, fr * .35, Color(1, 1, 1, .7))

## caule de cogumelo a partir das bordas esquerda (L) e direita (R): luz na esquerda, sombra na
## direita, a sombra do chapéu lá em cima, fibras e pintinhas
static func _mstem(L: PackedVector2Array, R: PackedVector2Array, col: Color, sd: float) -> void:
	var n: int = min(L.size(), R.size())
	if n < 2:
		return
	var lc: Color = col.lightened(.18)
	var dc: Color = col.darkened(.38)
	for i in n - 1:
		var c0: Vector2 = L[i].lerp(R[i], .38)
		var c1: Vector2 = L[i + 1].lerp(R[i + 1], .38)
		Spr.ci.draw_polygon(PackedVector2Array([L[i], c0, c1, L[i + 1]]), PackedColorArray([Spr.col(lc), Spr.col(col), Spr.col(col), Spr.col(lc)]))
		Spr.ci.draw_polygon(PackedVector2Array([c0, R[i], R[i + 1], c1]), PackedColorArray([Spr.col(col), Spr.col(dc), Spr.col(dc), Spr.col(col)]))
	# sombra do chapéu no alto do caule
	var k1: int = max(1, int(n * .3))
	for i in k1:
		var a0: float = .45 * (1.0 - i / float(k1))
		var a1: float = .45 * (1.0 - (i + 1) / float(k1))
		Spr.ci.draw_polygon(PackedVector2Array([L[i], R[i], R[i + 1], L[i + 1]]), PackedColorArray([Spr.col(Color(0, 0, 0, a0)), Spr.col(Color(0, 0, 0, a0)), Spr.col(Color(0, 0, 0, a1)), Spr.col(Color(0, 0, 0, a1))]))
	# fibras ao comprido e pintinhas
	for f in 3:
		var u: float = .2 + f * .28
		var pts := PackedVector2Array()
		for i in n:
			pts.push_back(L[i].lerp(R[i], u + sin(i * 1.3 + f + sd) * .03))
		Spr.line(pts, Color(.4, .3, .2, .22), 1.1)
	for k in 6:
		var i2: int = int(_mh(sd, k) * (n - 1))
		var q: Vector2 = L[i2].lerp(R[i2], .15 + _mh(sd + 2.0, k) * .7)
		Spr.ellipse(q.x, q.y + 2, 1.4, 1.0, Color(.35, .25, .15, .4))
	Spr.line(L, OUT, 1.8)
	Spr.line(R, OUT, 1.8)

## arco de elipse (para as voltas da mola)
static func _arc_e(cx: float, cy: float, rx: float, ry: float, a0: float, a1: float, c: Color, w: float) -> void:
	var pts := PackedVector2Array()
	for i in 13:
		var a: float = lerpf(a0, a1, i / 12.0)
		pts.push_back(Vector2(cx + cos(a) * rx, cy + sin(a) * ry))
	Spr.line(pts, c, w)

## bordas de um caule reto (afinando para cima) de (xt, yt) até (xb, yb)
static func _mstem_lr(xt: float, yt: float, wt: float, xb: float, yb: float, wb: float, bend: float = 0.0, n: int = 6) -> Array:
	var L := PackedVector2Array()
	var R := PackedVector2Array()
	for i in n + 1:
		var t: float = i / float(n)
		var cx: float = lerpf(xt, xb, t) + bend * sin(t * PI)
		var hw: float = lerpf(wt, wb, t * t) * .5
		var y: float = lerpf(yt, yb, t)
		L.push_back(Vector2(cx - hw, y))
		R.push_back(Vector2(cx + hw, y))
	return [L, R]

# ---------- flor-catapulta ----------
static func _flower(g: Game, TR: Traps, o: Dictionary, T: int) -> void:
	var x: float = o.x
	var y: float = o.y
	var pad: float = o.get("pad", 0.0)
	var py: float = y - 18 + pad * 12
	# flor-catapulta pintada: aberta em repouso; carregando ela se fecha em botão e afunda
	var sq: float = max(0.0, pad)
	if sq > .35:
		var bw: float = 62.0 - sq * 8
		Spr.P("cat_bud", x, y + 3, bw, false, 0.0, Color(1, 1, 1))
	else:
		var ow: float = 76.0 * (1.0 - sq * .4)
		var hgt: float = Spr.PH("cat_open", ow) * (1.0 - sq * .5)
		Spr.PR("cat_open", x - ow / 2, y + 3 - hgt, ow, hgt)
	# enquanto carrega, mostra o arco de para onde vai
	if o.st == "load":
		var tg: Array = o.to
		var v := TR.ballistic(Vector2(x, y - 18), Vector2(float(tg[0]), float(tg[1])), o.get("arc", 1.0))
		var p := Vector2(x, y - 18)
		var vel := Vector2(v.x, v.y)
		var n := int(v.z)
		for i in n:
			vel.y += Game.GRAV
			p += vel
			if i % 5 == 0:
				Spr.circle(p.x, p.y, 2.2, Color(1, .95, .8, .55 * pad))

# ---------- corrente de vento ----------
static func _wind(o: Dictionary, T: int) -> void:
	var x: float = o.x
	var y: float = o.y
	var w: float = o.w
	var h: float = o.h
	if o.get("smoke"):
		# fumaça quente da chaminé subindo (dá para planar em cima dela)
		Spr.vgrad(x, y, w, h, Color(.8, .8, .85, 0), Color(.8, .8, .85, .08))
		for k in 9:
			var u: float = fposmod(T * .006 + k / 9.0, 1.0)
			var sx: float = x + w / 2 + sin(u * 7.0 + k) * (6 + u * 18)
			var sy: float = y + h - u * h
			var r: float = 10 + u * 26
			Spr.circle(sx, sy, r, Color(.72, .72, .78, .32 * (1.0 - u)))
		return
	Spr.vgrad(x, y, w, h, Color(.85, .95, 1, 0), Color(.85, .95, 1, .1))
	for k in 7:
		var lx: float = x + w * (k + .5) / 7.0
		var ph: float = fmod(T * 2.4 + k * 53.0, h)
		var yy: float = y + h - ph
		var pts := PackedVector2Array()
		for j in 6:
			pts.push_back(Vector2(lx + sin(yy * .05 + j * .7 + k) * 8, yy - j * 9))
		Spr.line(pts, Color(1, 1, 1, .32 * (ph / h)), 2)
	# folhinhas subindo
	for k in 4:
		var fx: float = x + fmod(k * 37.0 + T * .3, w)
		var fy: float = y + h - fmod(T * 3.0 + k * 90.0, h)
		Spr.ellipse(fx + sin(T * .1 + k) * 6, fy, 5, 2, Color("#9ec46a"), T * .1 + k)
	# a fenda de onde sai o vento
	Spr.ellipse(x + w / 2, y + h + 2, w * .45, 5, Color(.1, .08, .06, .7))

# ---------- espinhos ----------
static func _spikes(TR: Traps, o: Dictionary, T: int) -> void:
	var h: float = TR.spike_h(o)
	var x: float = o.x
	var y: float = o.y
	var w: float = o.w
	var sh: float = 0.0
	if TR.spike_warn(o) and h < 1:
		sh = sin(T * 1.7) * 1.5
		if Polish.FRESH and T % 6 == 0:
			game_dust(x + randf() * w, y)
	if Spr.has("p_spiketop"):
		# espetos de ferro pintados saindo pelas frestas da tábua (a tábua fica sempre no chão)
		var tw: float = w + 12.0
		var ns: int = max(1, int(round(tw / 110.0)))
		var sgw: float = tw / ns
		var rt: Array = Spr.AR["p_spiketop"]
		var rb: Array = Spr.AR["p_spikebase"]
		var full: float = 30.0
		var f: float = clamp(max(h, 0.0) / 26.0, 0.0, 1.0)
		for i in ns:
			var sx0: float = x - 6 + i * sgw + sh
			if f > .02:
				Spr.PB("spiketop", sx0, y + 1 - full * f, sgw, full * f, 0.0, f)
			var bh: float = sgw * rb[3] / rb[2]
			Spr.PR("spikebase", x - 6 + i * sgw, y - 4, sgw, bh)
		if h > 4:
			Spr.rr(x - 6, y - 2 - h - 3, w + 12, h + 6, 6, Color(1, .3, .2, .06 + .04 * sin(T * .1)))
		return
	Spr.rect(x - 4, y - 4, w + 8, 6, Color("#3a3026"))
	var n := int(w / 16)
	for i in n:
		var sx: float = x + (i + .5) * w / n + sh
		var hh: float = max(h, 3.0)
		Spr.poly(PackedVector2Array([Vector2(sx - 7, y - 2), Vector2(sx, y - 2 - hh), Vector2(sx + 7, y - 2)]), STEEL)
		Spr.poly(PackedVector2Array([Vector2(sx, y - 2), Vector2(sx, y - 2 - hh), Vector2(sx + 7, y - 2)]), STEEL_D)
	Spr.rect(x - 6, y - 2, w + 12, 5, Color("#2a2018"))
	# pontas brilhando de leve (perigo fácil de ver)
	if h > 4:
		var gl: float = .35 + .25 * sin(T * .1 + x)
		for i in n:
			var tx: float = x + (i + .5) * w / n + sh
			Spr.circle(tx, y - 2 - h + 2, 2.0, Color(1, .95, .85, gl))
		Spr.rr(x - 6, y - 2 - h - 3, w + 12, h + 6, 6, Color(1, .3, .2, .06 + .04 * sin(T * .1)))

static func game_dust(_x: float, _y: float) -> void:
	pass

# ---------- pedra rolando ----------
static func _roll(o: Dictionary) -> void:
	if o.get("snow"):
		# bola de neve rolando (fica parada à vista até disparar)
		if o.st == "done":
			return
		var Rs: float = o.get("r", 36.0)
		var bx: float = o.bx if o.has("bx") else float(o.x)
		var c := {"x": bx - Rs, "y": o.y - Rs * 2 + o.get("fy", 0.0), "w": Rs * 2, "h": Rs * 2}
		WorldNature.snowball(c, 0)
		return
	if o.st in ["idle", "done"]:
		return
	var R: float = o.get("r", 40.0)
	var cx: float = o.bx
	var cy: float = o.y - R + o.get("fy", 0.0)
	Spr.ellipse(cx, o.y + 2, R * .9, 6, Color(0, 0, 0, .3))
	Spr.circle(cx, cy, R, Color("#6b6a62"))
	Spr.circle(cx - R * .25, cy - R * .25, R * .55, Color("#7d7c73"))
	Spr.save()
	Spr.translate(cx, cy)
	Spr.rotate(o.rot)
	for k in 5:
		var a: float = k * 1.3
		Spr.seg(cos(a) * R * .2, sin(a) * R * .2, cos(a + .4) * R * .85, sin(a + .4) * R * .85, Color("#4a4943"), 3)
	Spr.ellipse(R * .3, -R * .5, 10, 5, Color(.36, .5, .22, .9))
	Spr.restore()
	Spr.ring(cx, cy, R, OUT, 3)

# ---------- machado-pêndulo ----------
static func _axe(TR: Traps, o: Dictionary, T: int) -> void:
	var b := TR.axe_blade(o)
	var a: float = o.get("ang", 0.0)
	var w: float = TAU / float(o.per)
	var th: float = w * (T + o.get("ph", 0))
	var dirv: float = cos(th)
	# rastro em arco: a ponta da lâmina nos quadros anteriores (mais forte quando está rápido)
	var spd: float = abs(dirv)
	var trail := PackedVector2Array()
	for k in 10:
		var a2: float = o.amp * sin(th - w * k * 1.6)
		trail.push_back(Vector2(o.x + sin(a2) * (o.len + 18), o.y + cos(a2) * (o.len + 18)))
	for k in range(trail.size() - 1):
		Spr.seg(trail[k].x, trail[k].y, trail[k + 1].x, trail[k + 1].y, Color(1, 1, 1, .22 * spd * (1.0 - k / 10.0)), 10.0 - k * .8)
	# forca de madeira pintada (troncos)
	if o.has("frame"):
		var fx: float = o.frame
		Spr.PR("log", fx - 9, o.y - 18, 18, 520 - o.y, Color(.85, .8, .75), false)
		_beam_log(fx - 12, o.x + 16, o.y - 16, 16)
		Spr.seg(fx + 2, o.y + 36, fx + 38, o.y - 8, Color("#4a3220"), 7)
		Spr.seg(fx + 2, o.y + 36, fx + 38, o.y - 8, Color("#7a5634"), 3)
		Spr.circle(fx, o.y - 10, 4, STEEL)
	# haste de ferro e eixo
	Spr.seg(o.x, o.y, b.x, b.y, Color("#3a3026"), 7)
	Spr.seg(o.x, o.y, b.x, b.y, Color("#6a5a48"), 3)
	Spr.circle(o.x, o.y, 9, Color("#2a221c"))
	Spr.circle(o.x, o.y, 4, STEEL)
	Spr.save()
	Spr.translate(b.x, b.y)
	Spr.rotate(-a)
	# lâmina em meia-lua com fio brilhante e manchas de ferrugem
	var bl := PackedVector2Array()
	for i in 13:
		var t: float = -1.2 + 2.4 * i / 12.0
		bl.push_back(Vector2(sin(t) * 30, cos(t) * 16 + 4))
	for i in range(12, -1, -1):
		var t2: float = -1.2 + 2.4 * i / 12.0
		bl.push_back(Vector2(sin(t2) * 20, cos(t2) * 6 - 2))
	Spr.poly(bl, Color("#8a949e"))
	var edge := PackedVector2Array()
	for i in 13:
		var t3: float = -1.2 + 2.4 * i / 12.0
		edge.push_back(Vector2(sin(t3) * 29, cos(t3) * 15 + 3))
	Spr.line(edge, Color(.92, .96, 1, .9), 2.5)
	Spr.ellipse(-9, 6, 6, 3, Color(.55, .32, .18, .45))
	Spr.ellipse(10, 9, 4, 2, Color(.55, .32, .18, .4))
	Spr.line(bl, Color("#2a3038"), 2)
	Spr.rr(-6, -16, 12, 16, 3, Color("#4a3220"))
	Spr.rect(-6, -10, 12, 3, STEEL)
	Spr.restore()

## viga de tronco pintado deitada (de xa até xb, com altura h)
static func _beam_log(xa: float, xb: float, y: float, h: float) -> void:
	Spr.save()
	Spr.translate(xa, y + h)
	Spr.rotate(-PI / 2)
	Spr.PR("log", 0, 0, h, xb - xa, Color(.9, .85, .8), false)
	Spr.restore()

# ---------- galho que quebra ----------
static func _snap(o: Dictionary, T: int) -> void:
	if o.st == "fall" and o.fy > 500:
		return
	var sh: float = sin(T * 2.1) * 2.0 if o.st == "crack" else 0.0
	var pop: float = float(o.get("pop", 1.0))
	Spr.save()
	Spr.translate(o.x + o.w / 2 + sh, o.y + 8 + o.get("fy", 0.0))
	if pop < 1.0:
		# galho novo brotando no lugar do que caiu
		var k: float = 1.0 - pow(1.0 - pop, 3.0)
		Spr.alpha *= clamp(pop * 2.0, 0.0, 1.0)
		Spr.scale(.6 + .4 * k, k)
	if o.st == "fall":
		Spr.rotate(o.fy * .004)
	var w: float = o.w
	# galho pintado (tora fina com casca)
	WorldVehicles._hlog(-w / 2, w / 2, -8, 15)
	# trinca que aparece quando vai quebrar
	if o.st != "idle":
		Spr.line(PackedVector2Array([Vector2(-4, -8), Vector2(3, -2), Vector2(-3, 3), Vector2(4, 7)]), Color("#1e140a"), 2.5)
	for k in 4:
		Spr.ellipse(-w / 2 + 10 + k * (w - 20) / 3.0, -10, 9, 4, Color("#5c8d38"), (k - 1.5) * .3)
	Spr.restore()

# ---------- jaula de caçador ----------
static func _cage(o: Dictionary, T: int) -> void:
	if o.st == "used":
		return
	var w: float = o.get("w", 64)
	var x: float = o.x
	var y: float = o.y + o.dy
	var top: float = y - 86
	var anchor := Vector2(x + w / 2, o.y - 300)
	# corda: poste → galho → jaula
	if o.has("post"):
		var px: float = o.post[0]
		var py: float = o.post[1]
		Spr.rr(px - 5, py - 46, 10, 48, 3, WOOD_D)
		Spr.rect(px - 7, py - 48, 14, 5, WOOD)
		Spr.seg(px, py - 36, anchor.x, anchor.y, Color("#c9b48a"), 2)
		Spr.circle(px, py - 36, 4, Color("#c9b48a"))
	Spr.seg(anchor.x, anchor.y, x + w / 2, top, Color("#c9b48a"), 2.5)
	Spr.circle(anchor.x, anchor.y, 5, Color("#3a3026"))
	if Spr.has("p_cage"):
		# gaiola de ferro pintada (argola em cima presa na corda)
		Spr.PR("cage", x - 10, top - 30, w + 20, y - top + 34)
		return
	# grades
	Spr.rect(x - 2, top - 6, w + 4, 8, WOOD)
	Spr.rect(x - 2, y - 6, w + 4, 6, WOOD_D)
	for k in 6:
		var bx: float = x + k * w / 5.0
		Spr.rect(bx - 2.5, top, 5, y - top, WOOD_D)
		Spr.rect(bx - 1, top, 2, y - top, WOOD)
	Spr.seg(x, top + 30, x + w, top + 30, WOOD_D, 3)

# ---------- rede de caçador ----------
static func _net(o: Dictionary, T: int) -> void:
	var fy: float = o.get("fy", 0.0)
	if fy > 600:
		return
	var x: float = o.x - 18
	var y: float = o.y + fy
	var w := 54.0
	var h: float = o.h
	var al: float = 1.0 if fy == 0 else clamp(1.0 - fy / 300.0, 0, 1)
	var c := Color(.82, .74, .55, al)
	if o.has("post") and o.st != "down":
		var px: float = o.post[0]
		var py: float = o.post[1]
		Spr.rr(px - 5, py - 46, 10, 48, 3, WOOD_D)
		Spr.seg(px, py - 36, x + w / 2, o.y - 6, Color("#c9b48a"), 2)
	if Spr.has("p_net"):
		Spr.PR("net", x - 10, y - 14, w + 20, h + 14, Color(1, 1, 1, al))
		return
	Spr.rect(x - 4, o.y - 8, w + 8, 6, Color(.35, .25, .15, al))
	for i in 8:
		var u := i / 7.0
		Spr.seg(x + w * u, y, x + w * u + sin(T * .05 + i) * 2, y + h, c, 1.5)
	var rows := int(h / 14)
	for j in rows + 1:
		var yy: float = y + j * h / rows
		var pts := PackedVector2Array()
		for i in 8:
			pts.push_back(Vector2(x + w * i / 7.0 + sin(T * .05 + i) * 2 * (j / float(rows)), yy + (2.0 if i % 2 else -2.0)))
		Spr.line(pts, c, 1.5)

# ---------- picareta arremessada ----------
static func _pick(k: Dictionary) -> void:
	Spr.save()
	Spr.translate(k.x, k.y)
	if k.st == "stuck":
		Spr.scale(-1 if k.dir > 0 else 1, 1)
		# cabo saindo da parede (é o degrau)
		Spr.rr(0, -4, 34, 7, 3, WOOD)
		Spr.rect(0, -4, 34, 2, Color("#a87a4c"))
		Spr.poly(PackedVector2Array([Vector2(-2, -12), Vector2(6, -4), Vector2(6, 4), Vector2(-2, 12)]), STEEL_D)
	else:
		Spr.rotate(k.rot)
		Spr.rr(-3, -2, 6, 30, 3, WOOD)
		var hd := PackedVector2Array([Vector2(-20, 4), Vector2(-8, -3), Vector2(8, -3), Vector2(20, 4), Vector2(8, 1), Vector2(-8, 1)])
		Spr.poly(hd, STEEL)
		Spr.line(hd, STEEL_D, 1.5)
	Spr.restore()

# ---------- planta carnívora (inimigo) ----------
static func plant(e: Dictionary, T: int) -> void:
	# desenhada no referencial do inimigo (origem no chão, virada para e.dir)
	var lx: float = e.get("lx", 0.0)
	var st: int = e.get("st", 0)
	var stun: bool = e.get("stun", 0) > 0 and not e.dead
	var sway: float = sin(T * .06 + e.x) * 3.0
	var hx: float = 18 + lx + sway
	var hy: float = -48.0 + (16.0 if stun else 0.0)
	if Spr.has("p_plant"):
		# planta carnívora pintada: a cabeça avança (bote), abre e fecha esticando a arte
		var opn: float = .25 + sin(T * .08) * .1
		if st == 1:
			opn = 1.0
		elif st == 2 or stun:
			opn = 0.0
		Spr.save()
		Spr.translate(sway * .5, 0)
		if stun:
			Spr.rotate(.25)
		Spr.translate(lx * .5, 0)
		Spr.scale(1.0 + lx * .004, 1.0 + opn * .08)
		Spr.P("plant", 4, 2, 92, true)
		Spr.restore()
		if stun:
			for k in 3:
				var a2 := T * .15 + TAU * k / 3.0
				Spr.text("★", hx + cos(a2) * 14, hy - 20 + sin(a2) * 4, 10, Color("#ffe27a"), HORIZONTAL_ALIGNMENT_CENTER, Spr.font_b, 2)
		return
	# folhas na base
	Spr.ellipse(-16, -4, 16, 6, Color("#3f6a2a"), .5)
	Spr.ellipse(14, -4, 16, 6, Color("#3f6a2a"), -.5)
	# caule em curva
	Spr.line(PackedVector2Array([Vector2(0, 0), Vector2(-6, -18), Vector2(hx * .4, -36 + (10.0 if stun else 0.0)), Vector2(hx - 10, hy + 6)]), Color("#4f7a2c"), 7)
	# boca
	var open: float = .15
	if st == 1:
		open = .9
	elif st == 2:
		open = .05
	elif st == 0:
		open = .25 + sin(T * .08) * .1
	if stun:
		open = .05
	Spr.save()
	Spr.translate(hx, hy)
	Spr.rotate(.6 if stun else 0.0)
	var top := PackedVector2Array()
	var bot := PackedVector2Array()
	for i in 9:
		var a: float = PI * i / 8.0
		top.push_back(Vector2(-cos(a) * 22, -sin(a) * 16 - open * 6))
		bot.push_back(Vector2(-cos(a) * 22, sin(a) * 14 + open * 6))
	Spr.ellipse(0, 0, 20, 4 + open * 10, Color("#b02a2a"))
	Spr.poly(top, Color("#6fae3c"))
	Spr.poly(bot, Color("#5c9a32"))
	# dentes
	for i in 5:
		var tx: float = -14 + i * 7
		Spr.poly(PackedVector2Array([Vector2(tx - 3, -open * 6), Vector2(tx, -open * 6 + 6), Vector2(tx + 3, -open * 6)]), Color("#fbf3dc"))
		Spr.poly(PackedVector2Array([Vector2(tx - 3, open * 6), Vector2(tx, open * 6 - 6), Vector2(tx + 3, open * 6)]), Color("#fbf3dc"))
	# pintinhas e olhos
	for d in [[-10, -10], [4, -13], [10, 9]]:
		Spr.circle(d[0], d[1], 2.5, Color("#e8d25a"))
	if stun:
		Spr.seg(-14, -18, -8, -12, OUT, 2)
		Spr.seg(-14, -12, -8, -18, OUT, 2)
	else:
		Spr.circle(-10, -18, 4, Color("#fbf3dc"))
		Spr.circle(-9, -18, 2, OUT)
	Spr.line(top, OUT, 1.5)
	Spr.line(bot, OUT, 1.5)
	Spr.restore()

static func _icicle(g: Game, o: Dictionary, T: int) -> void:
	var ln: float = o.get("len", 46)
	var fl: float = o.get("floor", o.y + 300)
	var w: float = ln * .55
	# base de gelo presa no teto (fica mesmo quando o pingente cai, e de onde ele volta a crescer)
	Spr.ellipse(o.x, o.y + 2, w * .75, 7, Color("#9cc4e4"))
	Spr.ellipse(o.x, o.y, w * .7, 5, Color("#d8eeff"))
	if o.st == "broken":
		# pingente novo nascendo: um toquinho que vai aparecendo
		var gr: float = clamp(o.t / 150.0, 0, 1)
		if gr > .05:
			Spr.PR("icicle", o.x - w * .5 * gr, o.y, w * gr, ln * gr * .35)
		return
	var gk: float = o.grow if o.st == "idle" else 1.0
	var sx: float = sin(T * 1.9) * 2.5 if o.st == "shake" else 0.0
	var y: float = o.y + o.fy
	# sombra no chão: cresce enquanto ele treme e cai (mostra onde vai acertar)
	if o.st in ["shake", "fall"]:
		var sk: float = clamp(o.t / 60.0, 0, 1) if o.st == "shake" else clamp((y + ln - o.y) / (fl - o.y), 0, 1) * .5 + .5
		Spr.ellipse(o.x, fl + 1, 10 + 16 * sk, 4, Color(0, .05, .15, .25 + .3 * sk))
	# brilho frio em volta: é perigo, diferente dos pingentes do teto
	Spr.glow(o.x, y + ln * gk * .45, 26, Color(.6, .85, 1, .18 + (.2 if o.st == "shake" else 0.0)))
	if o.st == "fall":
		# rastro brilhante da queda
		for k in 4:
			Spr.seg(o.x - 3 + k * 2, y - 8 - k * 10, o.x - 3 + k * 2, y - 30 - k * 14, Color(.85, .95, 1, .35 - k * .07), 2)
	Spr.PR("icicle", o.x - w * .5 * gk + sx, y, w * gk, ln * gk)
	if o.st == "shake":
		# rachando: estalos brancos na base e lasquinhas caindo
		if (T / 4) % 2 == 0:
			Spr.seg(o.x - w * .4, y + 3, o.x - 2, y + 7, Color(1, 1, 1, .8), 1.5)
			Spr.seg(o.x + 2, y + 6, o.x + w * .4, y + 2, Color(1, 1, 1, .8), 1.5)
		if Polish.FRESH and T % 6 == 0:
			g.PARTS.append({"x": o.x + randf_range(-w * .4, w * .4), "y": y + 6, "vx": randf_range(-.4, .4), "vy": 1.5, "life": 24, "col": Color(.85, .95, 1, .9)})

## por cima do Tomé: a superfície da areia movediça (esconde as pernas que afundaram)
static func draw_front(g: Game, T: int) -> void:
	var TR: Traps = g.TR
	if TR == null:
		return
	for o in TR.T:
		if o.k == "sand" and o.x < g.cam + g.W + 100 and o.x + o.w > g.cam - 100:
			_sand_front(o, T)

## sombras no chão das armadilhas que balançam (por cima do capim da frente, que cobre a borda do chão)
static func draw_shadows(g: Game, T: int) -> void:
	var TR: Traps = g.TR
	if TR == null:
		return
	for o in TR.T:
		if o.k != "swing" or not o.has("gy") or o.x < g.cam - 500 or o.x > g.cam + g.W + 500:
			continue
		var e := TR.swing_end(o)
		var gy: float = o.gy
		# sombra da tora: anda junto com o balanço, mais nítida e menor quando ela passa baixinho
		var hgt: float = max(0.0, gy - (e.y + 13))
		var sa: float = .5 * clamp(1.0 - hgt / 260.0, .3, 1.0)
		Spr.ellipse(e.x + hgt * .12, gy - 1, 50 + hgt * .1, 6 + hgt * .012, Color(.12, .05, 0, sa))
		Spr.ellipse(e.x + hgt * .12, gy - 1, 30 + hgt * .05, 3.5, Color(.12, .05, 0, sa * .6))
		# pés do cavalete
		for sd in [-1.0, 1.0]:
			Spr.ellipse(o.x + sd * 238.0 + 8, gy - 1, 22, 4.5, Color(.12, .05, 0, .3))

# ---------- tronco-pêndulo ----------
## tora pesada pendurada por duas cordas grossas num cavalete de troncos: tora redonda com casca,
## musgo, topo cortado com anéis, luz vindo da esquerda e sombra embaixo; a sombra no chão acompanha
## o balanço e, no ponto mais rápido, o ar risca atrás dela. (Mesmo tamanho e mesma área de dano.)
const SW_BARK := Color("#7a5434")
const SW_ROPE := Color("#c9a46a")
static func _swing(g: Game, TR: Traps, o: Dictionary, T: int) -> void:
	var e := TR.swing_end(o)
	var w: float = TAU / float(o.per)
	var th: float = w * (T + o.get("ph", 0))
	var spd: float = abs(cos(th))                  # 1 = passando embaixo, no ponto mais rápido
	var vdir: float = 1.0 if cos(th) >= 0.0 else -1.0
	if not o.has("gy"):
		o.gy = _ground_at(g, float(o.x), float(o.y))
	var gy: float = o.gy
	var px: float = o.x
	var py: float = o.y
	# o cavalete: pernas inclinadas bem por fora do arco do balanço, com mão-francesa até a trave
	var lx: float = 176.0
	for sd in [-1.0, 1.0]:
		var top := Vector2(px + sd * lx, py + 2)
		var foot := Vector2(px + sd * (lx + 62), gy + 6)
		_sw_pole(foot, top, 8.0, .9)
		var kn: Vector2 = top.lerp(foot, .34)
		_sw_pole(kn, Vector2(px + sd * (lx - 66), py + 4), 5.0, .82)
		for bp in [kn, top + Vector2(-sd * 2, 8)]:
			Spr.circle(bp.x, bp.y, 3.0, Color("#3a3632"))
			Spr.circle(bp.x - .8, bp.y - .8, 1.2, Color("#9a948a"))
		# terra amontoada no pé
		Spr.ellipse(foot.x, gy + 1, 14, 5, Color("#5a3d24"))
		Spr.ellipse(foot.x - 3, gy - 1, 8, 2.5, Color("#7a5a36"))
	# a trave de cima: tronco roliço apoiado nas pernas, pontas cortadas
	Spr.save()
	Spr.translate(px - lx - 22, py)
	_sw_log(2.0 * lx + 44, 11.0, 0.0, T, false, Color(.86, .82, .78))
	Spr.restore()
	var hgt: float = max(0.0, gy - (e.y + 13))
	# rastro de ar atrás da tora quando ela passa rápido
	if spd > .35:
		var ta: float = clamp((spd - .35) / .65, 0.0, 1.0)
		for dy in [-9.0, 1.0, 10.0]:
			var tr := PackedVector2Array()
			for k in 9:
				var a2: float = o.amp * sin(th - w * k * 1.4)
				tr.push_back(Vector2(px + sin(a2) * o.len - vdir * 48.0, py + cos(a2) * o.len + dy))
			for k in range(tr.size() - 1):
				var f: float = 1.0 - k / 8.0
				Spr.seg(tr[k].x, tr[k].y, tr[k + 1].x, tr[k + 1].y, Color(1, .97, .9, .32 * ta * f), 2.6 * f + .6)
		# folhas sopradas pelo vento da tora
		for k in 3:
			var a3: float = o.amp * sin(th - w * (3 + k * 2))
			var lq := Vector2(px + sin(a3) * o.len - vdir * (56 + k * 9), py + cos(a3) * o.len - 14 + k * 11 + sin(T * .3 + k) * 4)
			Spr.ellipse(lq.x, lq.y, 4.5, 2.2, Color([Color("#e08a2a"), Color("#c9552a"), Color("#e8b440")][k], .85 * ta), T * .25 * vdir + k)
		# poeira levantada quando ela raspa perto do chão
		if spd > .9 and hgt < 30.0:
			for k in 3:
				var dx: float = -vdir * (30 + k * 16) + sin(T * .5 + k) * 3
				Spr.circle(e.x + dx, gy - 4 - k * 2, 6 - k * 1.2, Color(.85, .74, .55, .3 * ta))
	# a tora inclina um tiquinho para trás na hora que passa rápido (o peso puxando), sem mudar o dano
	var tilt: float = -vdir * spd * .05
	var att: Array = []
	for sx in [-30.0, 30.0]:
		att.append(e + Vector2(sx, -12.0).rotated(tilt))
	# cordas grossas trançadas: dão a volta na trave e descem até a tora
	for i in 2:
		var sx: float = -30.0 if i == 0 else 30.0
		_sw_rope(Vector2(px + sx, py + 6), att[i], T)
		_sw_wrap(px + sx, py, 11.0)
	# a tora
	Spr.save()
	Spr.translate(e.x, e.y)
	Spr.rotate(tilt)
	Spr.translate(-46, 0)
	_sw_log(92.0, 13.0, 1.0, T, true, Color.WHITE)
	# amarração da corda em volta da tora, com o nó em cima e a ponta solta balançando
	for sx in [16.0, 76.0]:
		Spr.rr(sx - 3.8, -14.5, 7.6, 29, 3, OUT)
		Spr.rr(sx - 2.6, -13.5, 5.2, 27, 2.5, SW_ROPE)
		for k in 5:
			Spr.seg(sx - 2.6, -10 + k * 5.4, sx + 2.6, -8 + k * 5.4, Color("#8a6a3a"), 1.1)
		Spr.rect(sx + 1.2, -13, 1.4, 26, Color(0, 0, 0, .22))
		Spr.circle(sx, -14, 4.2, OUT)
		Spr.circle(sx, -14, 3.0, SW_ROPE)
		var sw2: float = sin(T * .2 + sx) * 2.0 - vdir * spd * 4.0
		Spr.seg(sx + 2, -13, sx + 6 + sw2, -4, OUT, 3.2)
		Spr.seg(sx + 2, -13, sx + 6 + sw2, -4, SW_ROPE, 1.8)
	Spr.restore()

## tronco roliço deitado de 0 a ln (eixo em y = 0, raio r): contorno, volume com luz de cima à
## esquerda, casca com sulcos e nós, musgo (moss 0..1) e o topo cortado com anéis na ponta direita
static func _sw_log(ln: float, r: float, moss: float, T: int, ends: bool, tint: Color) -> void:
	var base := Color(SW_BARK.r * tint.r, SW_BARK.g * tint.g, SW_BARK.b * tint.b)
	# ponta de trás (esquerda): a casca dobrando, mostra que é redondo
	Spr.ellipse(1.0, 0, r * .42 + 1.5, r + 1.5, OUT)
	Spr.ellipse(1.0, 0, r * .42, r, base.darkened(.35))
	Spr.rr(0, -r - 1.5, ln, 2 * r + 3, 2, OUT)
	# corpo em faixas: brilho em cima, tom médio, sombra própria embaixo
	var ys := [-r, -r * .55, -r * .1, r * .45, r]
	var cs := [base.lightened(.12), base.lightened(.3), base, base.darkened(.32), base.darkened(.55)]
	for i in 4:
		Spr.ci.draw_polygon(PackedVector2Array([Vector2(1, ys[i]), Vector2(ln - 1, ys[i]), Vector2(ln - 1, ys[i + 1]), Vector2(1, ys[i + 1])]),
			PackedColorArray([Spr.col(cs[i]), Spr.col(cs[i]), Spr.col(cs[i + 1]), Spr.col(cs[i + 1])]))
	# casca: textura do tronco deitada (sulcos ao comprido), clara em cima e escura embaixo
	var tt: Texture2D = Spr.tex.get("tronco")
	if tt:
		# (a textura é de tronco em pé: cada pedaço é desenhado girado de 90°)
		var seg: float = 2.0 * r * tt.get_height() / (tt.get_width() * .44)
		var x: float = 1.0
		while x < ln - 1:
			var sl: float = min(seg, ln - 1 - x)
			Spr.save()
			Spr.translate(x, r)
			Spr.rotate(-PI / 2)
			Spr.ci.draw_texture_rect_region(tt, Rect2(0, -.5, 2 * r, sl + 1), Rect2(tt.get_width() * .28, 0, tt.get_width() * .44, tt.get_height() * sl / seg), Color(1, 1, 1, .45 * Spr.alpha))
			Spr.restore()
			x += sl
	# sulcos fundos da casca com a borda de cima pegando luz
	for k in 5:
		var yy: float = -r * .7 + k * r * .36
		var pts := PackedVector2Array()
		var x2: float = 4.0 + fposmod(k * 13.0, 9.0)
		var x3: float = min(ln - 4.0, x2 + ln * (.5 + fposmod(k * .37, .45)))
		var xx: float = x2
		while xx <= x3:
			pts.push_back(Vector2(xx, yy + sin(xx * .19 + k * 1.7) * 1.4))
			xx += 6.0
		if pts.size() >= 2:
			Spr.line(pts, Color(.12, .07, .03, .5), 1.4)
			if yy < 0:
				var hi := PackedVector2Array()
				for p2 in pts:
					hi.push_back(p2 + Vector2(0, -1.4))
				Spr.line(hi, Color(1, .9, .7, .14), 1.0)
	# nós da madeira
	for k in 2:
		var kx: float = ln * (.3 + k * .36)
		var ky: float = r * .25 - k * 3
		Spr.ellipse(kx, ky, 5.5, 2.6, Color("#4a2e18"))
		Spr.ellipse(kx + .5, ky + .4, 3.2, 1.3, Color("#24140a"))
		Spr.ring(kx, ky - .6, 5.0, Color(1, .88, .6, .22), 1.0, PI * 1.1, PI * 1.9)
	# brilho da luz e sombra mais forte bem embaixo (volume)
	Spr.rr(ln * .08, -r * .78, ln * .78, r * .28, r * .14, Color(1, .95, .82, .16))
	Spr.rect(1, r * .62, ln - 2, r * .38, Color(0, 0, 0, .18))
	# musgo por cima, com tufos claros e fiapos pendurados
	if moss > 0.0:
		for k in 5:
			var mx: float = ln * (.1 + k * .2) + sin(k * 2.3) * 4.0
			var mw: float = 7.0 + fposmod(k * 5.3, 6.0)
			Spr.ellipse(mx, -r + 1.5, mw + 1.2, 4.2, OUT)
			Spr.ellipse(mx, -r + 1.5, mw, 3.4, Color("#4d7a2c"))
			Spr.ellipse(mx - 1.5, -r + .5, mw * .6, 1.8, Color("#86b048"))
			if k % 2 == 0:
				var sw: float = sin(T * .08 + k) * 1.2
				Spr.seg(mx + 3, -r + 4, mx + 4 + sw, -r + 10 + k, Color(.3, .5, .2, .8), 1.2)
	# topo cortado na ponta direita: anéis da madeira, rachadura e a casca em volta
	if ends:
		Spr.ellipse(ln, 0, r * .48 + 1.6, r + 1.6, OUT)
		Spr.ellipse(ln, 0, r * .48, r, Color("#5a3a20"))
		Spr.ellipse(ln + .8, 0, r * .4, r * .86, Color("#d9b47a"))
		for k in 3:
			var f: float = .7 - k * .2
			Spr.ellipse(ln + .8, 0, r * .4 * f, r * .86 * f, Color("#b98a52") if k % 2 == 0 else Color("#e2c48e"))
		Spr.circle(ln + .8, 0, 1.4, Color("#7a5230"))
		Spr.seg(ln + .8, 0, ln + r * .3, -r * .6, Color("#6a4424"), 1.1)
		Spr.ellipse(ln - .6, -r * .3, r * .14, r * .4, Color(1, .95, .8, .25))
	else:
		Spr.ellipse(ln, 0, r * .42 + 1.5, r + 1.5, OUT)
		Spr.ellipse(ln, 0, r * .42, r, Color("#c9a06a"))
		Spr.ellipse(ln, 0, r * .25, r * .6, Color("#a87c4a"))
		Spr.circle(ln, 0, 1.2, Color("#6a4424"))

## pau roliço (perna do cavalete) de a até b, raio r, com luz de um lado e sombra do outro
static func _sw_pole(a: Vector2, b: Vector2, r: float, shade: float) -> void:
	var d: Vector2 = (b - a).normalized()
	var n := Vector2(-d.y, d.x)
	if n.x > 0:
		n = -n          # n aponta para a esquerda (lado da luz)
	var base := Color(SW_BARK.r * shade, SW_BARK.g * shade, SW_BARK.b * shade)
	Spr.poly(PackedVector2Array([a + n * (r + 1.5), b + n * (r + 1.5) + d * 1.5, b - n * (r + 1.5) + d * 1.5, a - n * (r + 1.5)]), OUT)
	var lc: Color = base.lightened(.25)
	var dc: Color = base.darkened(.45)
	Spr.ci.draw_polygon(PackedVector2Array([a + n * r, b + n * r, b, a]), PackedColorArray([Spr.col(lc), Spr.col(lc), Spr.col(base), Spr.col(base)]))
	Spr.ci.draw_polygon(PackedVector2Array([a, b, b - n * r, a - n * r]), PackedColorArray([Spr.col(base), Spr.col(base), Spr.col(dc), Spr.col(dc)]))
	# sulcos da casca ao comprido
	var L: float = a.distance_to(b)
	for k in 3:
		var off: float = (k - 1) * r * .5
		var s0: float = fposmod(k * 17.0, 20.0)
		var s1: float = L - fposmod(k * 23.0, 30.0)
		Spr.seg((a + d * s0 + n * off).x, (a + d * s0 + n * off).y, (a + d * s1 + n * off).x, (a + d * s1 + n * off).y, Color(.1, .06, .03, .4), 1.2)
	# topo cortado da perna
	Spr.ellipse(b.x, b.y, r, r * .45, Color("#c9a06a"), d.angle() + PI / 2)

## corda grossa e trançada de a até b
static func _sw_rope(a: Vector2, b: Vector2, T: int) -> void:
	Spr.seg(a.x, a.y, b.x, b.y, OUT, 6.0)
	Spr.seg(a.x, a.y, b.x, b.y, SW_ROPE, 4.0)
	var d: Vector2 = b - a
	var L: float = d.length()
	if L < 2.0:
		return
	var u: Vector2 = d / L
	var n := Vector2(-u.y, u.x)
	Spr.seg(a.x - n.x * 1.1, a.y - n.y * 1.1, b.x - n.x * 1.1, b.y - n.y * 1.1, Color(1, .95, .8, .35), 1.0)
	# fios trançados (riscos em diagonal ao longo da corda)
	var t: float = 3.0
	while t < L - 2.0:
		var c: Vector2 = a + u * t
		var p0: Vector2 = c - n * 2.0 - u * 1.6
		var p1: Vector2 = c + n * 2.0 + u * 1.6
		Spr.seg(p0.x, p0.y, p1.x, p1.y, Color("#7a5a32"), 1.1)
		t += 5.0

## laço da corda dando a volta na trave (cobre a trave de cima a baixo, com o nó por cima)
static func _sw_wrap(x: float, y: float, r: float) -> void:
	for dx in [-3.0, 3.0]:
		Spr.rr(x + dx - 3, y - r - 1.5, 6, 2 * r + 3, 3, OUT)
		Spr.rr(x + dx - 2, y - r - .5, 4, 2 * r + 1, 2, SW_ROPE)
		Spr.rect(x + dx + .8, y - r, 1.2, 2 * r, Color(0, 0, 0, .25))
	Spr.circle(x, y - r - 1, 4.5, OUT)
	Spr.circle(x, y - r - 1, 3.2, SW_ROPE)
	Spr.circle(x - 1, y - r - 2, 1.2, Color(1, .95, .8, .5))

# ---------- colmeia e enxame ----------
static func _ground_at(g: Game, x: float, y: float) -> float:
	var best := 99999.0
	for so in g.SOL:
		if str(so.get("t", "")) in ["ground", "dirt", "cliff"] and x >= so.x and x <= so.x + so.w and so.y >= y and so.y < best:
			best = so.y
	return best if best < 99999.0 else y + 80.0

static func _hive(g: Game, o: Dictionary, T: int) -> void:
	var x: float = o.x
	var y: float = o.y
	var sh: float = sin(T * .9) * 2.0 if o.st == "angry" and o.t < 40 else 0.0
	# árvore de verdade: tronco no chão à esquerda e um galho comprido por cima do caminho
	var tx: float = o.get("tx", x - 72)
	var tw: float = o.get("tw", 92)
	if not o.has("gy"):
		o.gy = _ground_at(g, tx, y)
	var by: float = y - 72
	Spr.img(Spr.tex.tronco, tx - tw / 2, by - 150, tw, o.gy - by + 160)
	Spr.img(Spr.tex.galho, tx - 10, by - 22, 200, 50)
	# cordinha e a colmeia pintada (racha e escorre mel quando o enxame sai)
	Spr.seg(x, by + 14, x + sh, y - 52, Color("#5a4632"), 2.5)
	Spr.P("hive_broken" if o.st != "idle" else "hive", x + sh, y + 2, 46)
	if o.st == "idle":
		for k in 3:
			var a: float = T * .07 + k * 2.1
			_bee(x + cos(a) * 30, y - 26 + sin(a * 1.3) * 16, T + k * 7, -sin(a) > 0.0)
	else:
		# o enxame: uma nuvem escura zunindo com abelhas em volta
		Spr.circle(o.sx, o.sy, 30 + sin(T * .3) * 3, Color(.15, .1, 0, .18))
		for k in 16:
			var a2: float = T * .23 + k * .9
			var r: float = 10 + (k % 5) * 6
			_bee(o.sx + cos(a2) * r, o.sy + sin(a2 * 1.4) * r * .7, T + k * 5, -sin(a2) > 0.0)

## abelha (a arte olha para a esquerda): vira para o lado em que está voando (antes trocava de lado
## a cada 9 quadros, sem motivo, e o enxame parecia tremer)
static func _bee(x: float, y: float, t: int, right: bool) -> void:
	Spr.P("bee", x, y + 5 + (1.0 if (t / 2) % 2 == 0 else 0.0), 13, right)

# ---------- areia movediça ----------
static func _sand_back(o: Dictionary, T: int) -> void:
	# fundo da cova (atrás do Tomé): a mesma bacia da frente, mais escura
	Spr.ci.draw_polygon(_sand_bowl(o, 0.0, 6.0), _sand_cols(_sand_bowl(o, 0.0, 6.0), o.y, Color("#7a643c"), Color("#3e301a")))

## contorno da areia movediça: borda de cima ondulando e o fundo em bacia (fundo no meio, raso nas
## beiradas) para se misturar com a terra em vez de parecer um caixote recortado no chão
static func _sand_bowl(o: Dictionary, T: float, top_off: float) -> PackedVector2Array:
	var x: float = o.x
	var y: float = o.y
	var w: float = o.w
	var pts := PackedVector2Array()
	for i in 17:
		pts.push_back(Vector2(x + w * i / 16.0, y - 2 + top_off + sin(T * .05 + i * .9) * 1.5))
	for i in 17:
		var u: float = i / 16.0
		pts.push_back(Vector2(x + w * (1.0 - u) + (6.0 if i == 0 else (-6.0 if i == 16 else 0.0)), y + 6 + sin(u * PI) * 34.0))
	return pts

static func _sand_cols(pts: PackedVector2Array, y: float, c0: Color, c1: Color) -> PackedColorArray:
	var cols := PackedColorArray()
	for q in pts:
		cols.push_back(Spr.col(c0.lerp(c1, clamp((q.y - y) / 40.0, 0.0, 1.0))))
	return cols

static func _sand_front(o: Dictionary, T: int) -> void:
	var x: float = o.x
	var y: float = o.y
	var w: float = o.w
	var cx: float = x + w / 2
	# corpo da areia em bacia: mais clara e seca na superfície, escura e molhada no fundo
	var body := _sand_bowl(o, T, 0.0)
	Spr.ci.draw_polygon(body, _sand_cols(body, y, Color("#a8895a"), Color("#5e4626")))
	# superfície ondulando devagar (uma faixa clara por cima)
	var pts := PackedVector2Array()
	for i in 17:
		var px: float = x + w * i / 16.0
		pts.push_back(Vector2(px, y - 2 + sin(T * .05 + i * .9) * 1.5))
	for i in range(16, -1, -1):
		var px2: float = x + w * i / 16.0
		pts.push_back(Vector2(px2, y + 6 + sin(T * .05 + i * .9 + 1.3) * 1.2))
	Spr.poly(pts, Color("#c2a46c"))
	# redemoinho: anéis achatados girando devagar para o meio (é ele que puxa para baixo)
	for k in 3:
		var rx: float = w * (.42 - k * .13)
		var ry: float = 4.0 - k * 1.1
		var ph: float = T * (.02 + k * .012) + k * 1.7
		for sg in 3:
			var arc := PackedVector2Array()
			for j in 7:
				var a: float = ph + sg * TAU / 3.0 + j * .16
				arc.push_back(Vector2(cx + cos(a) * rx, y + 3 + sin(a) * ry))
			Spr.line(arc, Color(.45, .34, .18, .55 - k * .1), 1.6)
	# grãos (escuros e claros) e uma bolha que estoura de vez em quando
	for k in 9:
		var gx: float = x + 10 + fmod(k * 37.0, w - 20)
		var gy: float = y + 10 + fmod(k * 13.0, 26)
		Spr.circle(gx, gy, 1.4, Color(.36, .27, .14, .7) if k % 2 == 0 else Color(.8, .68, .45, .6))
	var bu: float = fposmod(T * .012, 1.0)
	if bu < .25:
		var bx: float = x + w * (.3 + .4 * fposmod(floor(T * .012) * .618, 1.0))
		Spr.ring(bx, y + 2, 2.0 + bu * 14.0, Color(.92, .82, .6, .6 * (1.0 - bu * 4.0)), 1.2)
	# beiradas de terra molhada encostando no chão dos dois lados
	Spr.ellipse(x + 4, y + 2, 10, 5, Color("#6e5430"))
	Spr.ellipse(x + w - 4, y + 2, 10, 5, Color("#6e5430"))
	Spr.seg(x + 8, y - 1, x + w - 8, y - 1, Color(.37, .29, .16, .8), 1.5)

# ---------- teia de aranha ----------
static func _web(g: Game, o: Dictionary, T: int) -> void:
	var x: float = o.x
	var y: float = o.y
	var w: float = o.w
	var h: float = o.h
	var c := Color(.94, .94, .97, .8)
	# a teia fica presa entre dois troncos firmes, um de cada lado
	if not o.has("gy"):
		o.gy = _ground_at(g, x + w / 2, y + h - 10)
	var gy: float = o.gy
	Spr.img(Spr.tex.tronco, x - 42, y - 60, 52, gy - y + 70)
	Spr.img(Spr.tex.tronco, x + w - 8, y - 80, 46, gy - y + 90)
	if o.cut:
		# fiapos pendurados balançando
		if o.t < 200:
			for k in 4:
				var fx: float = x + 8 + k * (w - 16) / 3.0
				Spr.seg(fx, y, fx + sin(T * .05 + k) * 4, y + 26 + k % 2 * 10, Color(c.r, c.g, c.b, .5), 1)
		return
	# fios de ancoragem até o tronco, a pedra e o chão
	Spr.seg(x - 8, y - 6, x + 6, y + 8, c, 1.2)
	Spr.seg(x + w + 8, y + h - 14, x + w - 6, y + h - 22, c, 1.2)
	Spr.PR("web", x - 4, y - 4, w + 8, h + 8, Color(1, 1, 1, .92))
	# gotinhas brilhando
	for k in 3:
		Spr.circle(x + w * (.3 + k * .2), y + h * (.35 + (k % 2) * .25), 1.6, Color(.85, .95, 1, .5 + .4 * sin(T * .05 + k)))
	# a aranha pequena no canto, que sobe e desce um pouco
	var sy: float = y + 10 + (1.0 + sin(T * .03)) * 10
	Spr.seg(x + w - 14, y, x + w - 14, sy, Color(1, 1, 1, .5), 1)
	WorldExtras._pc("spider_hang", x + w - 14, sy + 8, 16)

# ---------- rajadas de vento ----------
static func _gust(TR: Traps, o: Dictionary, T: int) -> void:
	var st: int = TR.gust_state(o)
	if st == 0:
		return
	var a: float = .2 if st == 1 else .55
	var n: int = 6 if st == 1 else 16
	for k in n:
		var sp: float = 9.0 if st == 2 else 5.0
		var lx: float = o.x + o.w - fmod(T * sp + k * 97.0, o.w + 120)
		var ly: float = o.y + fmod(k * 53.0, o.h)
		Spr.seg(lx, ly, lx + 40 + (k % 3) * 18, ly + 1, Color(1, 1, 1, a), 2)
		if k % 3 == 0:
			Spr.circle(lx - 6, ly + sin(T * .3 + k) * 4, 2.5, Color(1, 1, 1, a + .2))

# ---------- ponte de cordas ----------
static func _bridge(o: Dictionary, T: int) -> void:
	var y: float = o.y
	var x0: float = o.x
	var x1: float = o.x + o.w
	# postes nas duas pontas (estacas pintadas)
	for px in [x0 - 10, x1 + 4]:
		Spr.PR("stake", px - 2, y - 64, 12, 80)
	# corrimão de corda (some atrás da frente que desabou)
	var ca: float = max(x0, o.get("front", x0)) if o.st != "idle" else x0
	if ca < x1:
		var pts := PackedVector2Array()
		var steps := 24
		for i in steps + 1:
			var xx: float = lerpf(ca, x1, i / float(steps))
			var sag: float = sin(PI * (xx - x0) / (x1 - x0)) * 14
			pts.push_back(Vector2(xx, y - 40 + sag))
		Spr.line(pts, Color("#c9a26a"), 3)
	if o.st != "idle" and o.get("front", x0) > x0:
		var fx: float = o.front
		Spr.seg(fx, y - 30, fx - 20, y + 60, Color("#c9a26a"), 2)
	for pl in o.planks:
		if pl.down and pl.fy > 600:
			continue
		var sh: float = 0.0
		if o.st == "go" and not pl.down and pl.x - o.front < 90:
			sh = sin(T * 1.3 + pl.x) * 1.5
		var py: float = y + pl.fy + sh + sin(PI * (pl.x + 20 - x0) / (x1 - x0)) * 6
		Spr.save()
		Spr.translate(pl.x + 20, py + 6)
		if pl.down:
			Spr.rotate(pl.fy * .01)
		if Spr.has("p_plank"):
			Spr.PR("plank", -21, -7, 42, 14)
		else:
			Spr.rr(-19, -6, 38, 12, 3, Color("#8a5e34"))
			Spr.rect(-19, -6, 38, 3, Color("#a87a48"))
			Spr.seg(-12, -6, -12, 6, Color("#4e331d"), 1.5)
			Spr.seg(12, -6, 12, 6, Color("#4e331d"), 1.5)
		Spr.restore()

# ---------- bola de pedra gigante ----------
static func _boulder(g: Game, o: Dictionary, T: int) -> void:
	# buraco no teto de onde ela cai
	Spr.ellipse(o.x, o.y - 120, o.r * 1.1, 10, Color(.05, .04, .03))
	if o.st in ["idle", "done"]:
		if o.st == "done":
			for k in 6:
				Spr.P("peb%d" % (k % 3), o.end - 40 + k * 22, o.y + 2, 24 + (k % 2) * 10)
		return
	var R: float = o.r
	var cx: float = o.bx
	var cy: float = o.by
	if o.st == "break":
		var k2: float = o.t / 30.0
		for i in 8:
			var a: float = i * TAU / 8.0
			var rs: float = R * .7 * (1.0 - k2 * .5)
			Spr.PR("rock2", cx + cos(a) * R * k2 * 1.5 - rs / 2, cy + sin(a) * R * .6 * k2 + k2 * k2 * 40 - rs / 2, rs, rs)
		return
	Spr.ellipse(cx, o.y + 2, R * .95, 7, Color(0, 0, 0, .35))
	# rocha pintada girando (a mesma arte das pedras do jogo), com a luz sempre por cima
	Spr.save()
	Spr.translate(cx, cy)
	Spr.rotate(o.rot)
	Spr.PR("rock0", -R * 1.08, -R * 1.08, R * 2.16, R * 2.16)
	Spr.restore()
	Spr.glow(cx - R * .3, cy - R * .45, R * .7, Color(1, .95, .85, .08))

## caixas, carrinho e barricada do trecho da bola (somem quando ela passa)
static var _bob_key := ""
static var _bob_list: Array = []
static var _bob_L = null
static func _bobs(g: Game, T: int) -> void:
	var c0: float = g.cam - 200
	var c1: float = g.cam + g.W + 200
	# (a lista dos objetos do trecho da bola é refeita só quando g.SOL muda; antes percorria todos
	# os sólidos da fase a cada quadro)
	var key := "%d:%d" % [g.level_idx, g.SOL.size()]
	if key != _bob_key or not is_same(_bob_L, g.L):
		_bob_key = key
		_bob_L = g.L
		_bob_list = g.SOL.filter(func(o): return o.get("bob"))
	for s in _bob_list:
		if s.x > c1 or s.x + s.w < c0:
			continue
		match s.bob:
			"crate":
				_box(s.x, s.y, s.w, s.h)
			"crate2":
				_box(s.x, s.y + s.h / 2, s.w, s.h / 2)
				_box(s.x + 4, s.y, s.w - 8, s.h / 2)
			"cart":
				Spr.AB("mi_cart", s.x - 8, s.y + s.h - 70, s.w + 16, 70)
			"barricade":
				for k in 4:
					Spr.rr(s.x - 6, s.y + 6 + k * 28, s.w + 12, 20, 3, Color("#7a5232").darkened(k * .05))
					Spr.rect(s.x - 6, s.y + 6 + k * 28, s.w + 12, 4, Color("#9a7044"))
				Spr.seg(s.x - 4, s.y + 8, s.x + s.w + 4, s.y + s.h - 8, Color("#4e331d"), 4)
				Spr.text("PERIGO", s.x + s.w / 2, s.y + 60, 11, Color("#f0d070"), HORIZONTAL_ALIGNMENT_CENTER, Spr.font_b, 3, Color(0, 0, 0, .8))

static func _box(x: float, y: float, w: float, h: float) -> void:
	Spr.rect(x, y, w, h, Color("#8a5e34"))
	Spr.rect(x + 3, y + 3, w - 6, h - 6, Color("#a07040"))
	Spr.seg(x + 3, y + 3, x + w - 3, y + h - 3, Color("#6b4626"), 3)
	Spr.seg(x + w - 3, y + 3, x + 3, y + h - 3, Color("#6b4626"), 3)
	Spr.ci.draw_rect(Rect2(x, y, w, h), OUT, false, 2.0)

# ---------- cogumelo gigante ----------
## altura da arte do saltador para a largura w (proporção da pintura)
static func _salt_h(w: float) -> float:
	var r: Array = Spr.AR["p_saltador0"]
	return w * r[3] / r[2]

## Cogumelo gigante desenhado UMA vez num nó próprio (era o desenho mais caro do trecho dos cogumelos,
## refeito inteiro a cada quadro): o nó só é redesenhado quando a mola amassa. O que se mexe sempre
## (brilho pulsando, setinhas, névoa do buraco) continua aqui, barato.
class _GiantNode extends Node2D:
	var o: Dictionary
	var last := -99.0
	func _draw() -> void:
		Spr.begin(self)
		WorldTraps._giant(o, 0)

static func _giant_cached(g: Game, o: Dictionary, T: int) -> void:
	var n = o.get("_node")
	if n == null or not is_instance_valid(n) or not n.is_inside_tree():
		if n == null or not is_instance_valid(n):
			var wp: Node = g.world_parent
			var dyn: CanvasItem = Spr.ci
			if wp == null or dyn == null or dyn.get_parent() != wp:
				_giant(o, T)
				_giant_anim(o, T)
				return
			var gn := _GiantNode.new()
			gn.o = o
			o._node = gn
			# entra logo antes do mundo que se mexe (atrás de bichos, do Tomé e das armadilhas)
			(func():
				if is_instance_valid(wp) and is_instance_valid(dyn) and dyn.get_parent() == wp:
					wp.add_child(gn)
					wp.move_child(gn, dyn.get_index())
				).call_deferred()
		# ainda não entrou na árvore: desenha direto neste quadro
		_giant(o, T)
		_giant_anim(o, T)
		return
	var sq: float = snappedf(float(o.get("squash", 0.0)), .02)
	if sq != n.last:
		n.last = sq
		n.queue_redraw()
	_giant_anim(o, T)

## partes animadas do cogumelo gigante (desenhadas a cada quadro)
static func _giant_anim(o: Dictionary, T: int) -> void:
	var x: float = o.x
	if o.has("to") and Spr.has("p_saltador0"):
		var aw: float = o.w * 1.12
		var ah: float = _salt_h(aw)
		var atop: float = float(o.cap) - ah * .05
		# brilho pulsando em volta do chapéu
		Spr.glow(x, float(o.cap) + 10, aw * .75, Color(1, .6, .2, .22 + .08 * sin(T * .1 + x)))
		# setinhas subindo em cima do chapéu ("pule aqui!")
		for k in 2:
			var u: float = fposmod(T * .02 + k * .5, 1.0)
			var ay: float = atop - 14 - u * 34
			var al: float = sin(u * PI) * .9
			Spr.line(PackedVector2Array([Vector2(x - 11, ay + 8), Vector2(x, ay), Vector2(x + 11, ay + 8)]), Color(1, .92, .4, al), 4)
	elif float(o.y) > 560:
		# névoa passando no fundo escuro do buraco
		var top: float = o.cap
		var sw: float = 16.0 + float(o.w) * .08
		var fy: float = max(top + 60, 560.0)
		for k in 3:
			var mx: float = x + sin(T * .01 + k * 2.0 + x) * 18
			Spr.ellipse(mx, fy + 60 + k * 18, sw * 2.2, 10, Color(.55, .65, .85, .1))

static func _giant(o: Dictionary, T: int) -> void:
	var x: float = o.x
	var base: float = o.y
	var top: float = o.cap
	var w: float = o.w
	var bouncy: bool = o.has("to")
	if bouncy and Spr.has("p_saltador0"):
		_giant_spring(o, T)
		return
	# (o cogumelo gigante não se mexe: o contorno do caule, as fibras e o chapéu são calculados uma
	# vez só e guardados em o._gc, em vez de refazer as contas a cada quadro)
	if not o.has("_gc"):
		o._gc = _giant_geom(o)
	var gc: Dictionary = o._gc
	var c: Color = gc.c
	var sw: float = gc.sw
	var deep: bool = gc.deep
	var bend: float = gc.bend
	var L: PackedVector2Array = gc.L
	var Rr: PackedVector2Array = gc.R
	# caule com volume (luz na esquerda, sombra na direita, a sombra do chapéu em cima e fibras)
	_mstem(L, Rr, Color("#ddcfb2"), x)
	# anel (saia) logo abaixo do chapéu: babado com volume
	var ax: float = x + bend * .1
	Spr.ellipse(ax, top + 23, sw * 1.05 + 1.5, 6.5, OUT)
	Spr.ellipse(ax, top + 23, sw * 1.05, 5, Color("#e4d6b8"))
	Spr.ellipse(ax + sw * .25, top + 25, sw * .7, 2.6, Color(.45, .35, .22, .45))
	Spr.ellipse(ax - sw * .4, top + 21.5, sw * .4, 1.6, Color(1, 1, 1, .45))
	if deep:
		# some no fundo escuro do buraco com névoa
		var fy: float = max(top + 60, 560.0)
		Spr.vgrad(x - sw * 1.6, fy, sw * 3.2, base - fy + 4, Color(.04, .05, .1, 0), Color(.04, .05, .1, 1))
	else:
		# bulbo com raízes no chão
		Spr.ellipse(x, base - 3, sw * 1.3, 7, Color("#cbbd9f"))
		for r in [-1.0, -.4, .5, 1.0]:
			Spr.seg(x + r * sw * .7, base - 4, x + r * sw * 1.6, base + 3, Color("#8a7458"), 2.2)
		Spr.ellipse(x, base + 1, sw * 1.5, 4, Color(.2, .3, .12, .6))
	# chapéu com volume (mesmo tamanho de antes: borda em top + 8, largura 1,12 w, altura 0,3 w)
	_mcap(x, top + 8 - w * .3, w * 1.12, w * .3, c, c.lightened(.55), x, true, Color(0, 0, 0, 0), 7)

## geometria fixa do cogumelo gigante comum (caule curvo, sombra, fibras e chapéu)
static func _giant_geom(o: Dictionary) -> Dictionary:
	var x: float = o.x
	var base: float = o.y
	var top: float = o.cap
	var w: float = o.w
	var c: Color = Color(o.get("c", "#6a5acd"))
	if not o.has("to"):
		# os gigantes comuns ficam apagados: só os laranjas com mola chamam atenção
		c = c.darkened(.35)
	var sw: float = 16.0 + w * .08
	# caule: levemente curvo, com fibras, anel debaixo do chapéu; nos buracos ele nasce
	# de um bulbo com raízes e some numa névoa escura (não desce reto e liso)
	var deep: bool = base > 560
	var bend: float = (1.0 if sin(x * .37) > 0 else -1.0) * sw * (.9 + .5 * abs(sin(x * .013)))
	var L := PackedVector2Array()
	var Rr := PackedVector2Array()
	var n := 12
	for i in n + 1:
		var t: float = i / float(n)
		var yy: float = lerpf(top + 10, base, t)
		var cx: float = x + bend * sin(t * PI)
		var hw: float = sw * lerpf(.5, .8, t) + (sw * .45 * pow(t, 6.0) if not deep else 0.0)
		L.push_back(Vector2(cx - hw, yy))
		Rr.push_back(Vector2(cx + hw, yy))
	var body := L.duplicate()
	var rv := Rr.duplicate()
	rv.reverse()
	body.append_array(rv)
	var sh := PackedVector2Array()
	for i in n + 1:
		sh.push_back(L[i].lerp(Rr[i], .62))
	sh.append_array(rv)
	var fib: Array = []
	for f in 5:
		var u: float = .18 + f * .16
		var pts := PackedVector2Array()
		for i in n + 1:
			pts.push_back(L[i].lerp(Rr[i], u + sin(i * 1.3 + f) * .02))
		fib.append(pts)
	var cap := PackedVector2Array()
	for i in 21:
		var a := PI + PI * i / 20.0
		cap.push_back(Vector2(x + cos(a) * w * .56, top + 8 + sin(a) * w * .3))
	return {"c": c, "sw": sw, "deep": deep, "bend": bend, "L": L, "R": Rr, "body": body, "sh": sh, "fib": fib, "cap": cap}

## cogumelo gigante saltador: chapéu laranja com pintas amarelas, mola no caule, brilho, setas
## e o arco a lápis mostrando para onde ele lança
static func _giant_spring(o: Dictionary, T: int) -> void:
	var x: float = o.x
	var base: float = o.y
	var cap: float = o.cap
	var aw: float = o.w * 1.12
	var ah: float = _salt_h(aw)
	var sq: float = o.get("squash", 0.0)
	var atop: float = cap - ah * .05
	var abot: float = min(atop + ah, base + 4.0)
	# caule de baixo (nos cogumelos altos) até onde começa a mola
	if base > abot + 4:
		var sw: float = 14.0
		Spr.poly(PackedVector2Array([Vector2(x - sw, abot - 4), Vector2(x + sw, abot - 4), Vector2(x + sw * 1.3, base), Vector2(x - sw * 1.3, base)]), Color("#e2d4b8"))
		Spr.poly(PackedVector2Array([Vector2(x + 2, abot - 4), Vector2(x + sw, abot - 4), Vector2(x + sw * 1.3, base), Vector2(x + 4, base)]), Color("#bfae8e"))
		Spr.line(PackedVector2Array([Vector2(x - sw, abot - 4), Vector2(x - sw * 1.3, base)]), Color(.25, .18, .12, .55), 1.6)
		Spr.line(PackedVector2Array([Vector2(x + sw, abot - 4), Vector2(x + sw * 1.3, base)]), Color(.25, .18, .12, .55), 1.6)
		if base > 560:
			var fy: float = max(abot + 40, 560.0)
			Spr.vgrad(x - 30, fy, 60, base - fy + 4, Color(.04, .05, .1, 0), Color(.04, .05, .1, 1))
	else:
		Spr.ellipse(x, base + 1, aw * .32, 5, Color(0, 0, 0, .3))
	# mola de arame embaixo do chapéu: amassa quando lança e volta esticando (o chapéu desce junto)
	var c0: float = atop + ah * .44
	var capdy: float = sq * (abot - c0) * .5
	var top_c: float = c0 + capdy
	var nco := 6
	var crx: float = aw * .2
	for pass_ in 2:
		for k in nco:
			var cy: float = lerpf(top_c + 4.0, abot - 5.0, k / float(nco - 1))
			var cry: float = crx * .3
			if pass_ == 0:
				# metade de trás de cada volta (mais escura)
				_arc_e(x, cy, crx, cry, PI, TAU, OUT, 5.0)
				_arc_e(x, cy, crx, cry, PI, TAU, Color("#8f8a80"), 2.6)
			else:
				# metade da frente, com luz em cima
				_arc_e(x, cy, crx, cry, 0.0, PI, OUT, 6.0)
				_arc_e(x, cy, crx, cry, 0.0, PI, Color("#e9e4da"), 3.4)
				_arc_e(x, cy - .8, crx, cry, PI * .18, PI * .55, Color(1, 1, 1, .65), 1.2)
	# chapéu laranja com pintas amarelas e a saia de babados
	var cw: float = aw * .96 * (1.0 + sq * .08)
	var chh: float = ah * .36 * (1.0 - sq * .15)
	_mcap(x, atop + ah * .44 - chh + capdy, cw, chh, Color("#f2681a"), Color("#ffd23a"), x, false, Color("#f3ece0"), 7)

## arco a lápis até o próximo cogumelo (desenhado na camada de brilho: aparece no escuro da noite)
static func giant_arc(o: Dictionary, T: int) -> void:
	var x: float = o.x
	var cap: float = o.cap
	var to = o.get("to")
	if to is Array:
		var tx: float = float(to[0])
		var ty: float = float(to[1])
		var dx: float = tx - x
		var dy: float = ty - cap
		var nn: float = clamp(abs(dx) / 4.4, 30.0, 72.0) * float(o.get("arc", 1.0))
		nn = max(nn, sqrt(2.0 * (max(0.0, -dy) + 60.0) / Game.GRAV) * 1.15)
		var vy0: float = (dy - Game.GRAV * nn * (nn + 1) / 2.0) / nn
		# pontinhos de lápis ao longo do caminho (correndo devagar, mostrando a direção)
		var i: float = 3.0 + fposmod(T * .12, 4.0)
		while i <= nn:
			var fx: float = x + dx / nn * i
			var fy: float = cap + vy0 * i + Game.GRAV * i * (i + 1) / 2.0
			var a: float = .95 - .4 * i / nn
			Spr.circle(fx, fy - 22, 4.6, Color(.2, .15, .1, a * .5))
			Spr.circle(fx, fy - 22, 3.4, Color(1, .95, .75, a))
			i += 4.0
		# setinha no fim, apontando para o próximo cogumelo
		var ex: float = x + dx / nn * (nn - 3.0)
		var ey: float = cap + vy0 * (nn - 3.0) + Game.GRAV * (nn - 3.0) * (nn - 2.0) / 2.0 - 22
		var dv := Vector2(dx / nn, vy0 + Game.GRAV * (nn - 3.0)).normalized()
		var nv := Vector2(-dv.y, dv.x)
		var tip := Vector2(ex, ey) + dv * 8.0
		Spr.poly(PackedVector2Array([tip, Vector2(ex, ey) - dv * 4.0 + nv * 7.0, Vector2(ex, ey) - dv * 4.0 - nv * 7.0]), Color(1, .93, .7, .6))

## bloco de gelo que levou a patada: brilha e treme um instante
static func _ice_hits(g: Game, T: int) -> void:
	# (só os sólidos perto da tela: a lista de colisão já vem filtrada e guardada a cada passo)
	for s in g.blockers():
		if s.get("shk", 0) > 0:
			if Polish.FRESH:
				s.shk -= 1
			var d: float = sin(T * 2.3) * s.shk * .25
			Spr.rr(s.x + d, s.y, s.w, s.h + 4, 5, Color(.85, .95, 1, .55 * s.shk / 18.0))

static var _PROP_OK := {}
## teto de rocha com escoras e lampiões apagados ao longo de todo o túnel da mina
static func _tunnel_ceiling(g: Game, T: int) -> void:
	var tn: Array = g.L.get("tunnel", [])
	if tn.size() < 2:
		return
	var ca: float = max(float(tn[0]), g.cam - 40)
	var cb: float = min(float(tn[1]), g.cam + g.W + 40)
	if ca >= cb:
		return
	var y0: float = 350.0
	# teto de rocha com a borda de baixo irregular e pontas (estalactites), sem régua
	var top := PackedVector2Array([Vector2(ca - 10, y0 - 400)])
	var bot := PackedVector2Array()
	var xx: float = floor(ca / 14.0) * 14.0 - 14
	while xx <= cb + 14:
		var d: float = 26 + 5 * sin(xx * .05) + 3 * sin(xx * .13 + 1.0)
		var r: float = fposmod(xx * .37, 1.0)
		if fposmod(xx, 98.0) < 14 and r > .3:
			d += 12 + r * 14
		bot.push_back(Vector2(xx, y0 + d))
		xx += 14
	for p in bot:
		top.push_back(p)
	top.push_back(Vector2(cb + 10, y0 - 400))
	Spr.poly(top, Color("#3a2c20"))
	Spr.line(bot, Color("#5a4632"), 3)
	var bx0: float = floor(ca / 260.0) * 260.0
	while bx0 < cb:
		# só escora onde há chão firme embaixo (não em cima de buracos); a resposta de cada escora
		# fica guardada (o chão do túnel não muda), em vez de percorrer todos os sólidos a cada quadro
		var key := "%d:%d" % [g.level_idx, int(bx0)]
		if not _PROP_OK.has(key):
			var found := false
			for s in g.SOL:
				if s.t == "ground" and abs(s.y - 500) < 2 and s.x <= bx0 and s.x + s.w >= bx0 + 12:
					found = true
					break
			_PROP_OK[key] = found
		var ok: bool = _PROP_OK[key]
		if ok:
			Spr.rect(bx0, y0 + 30, 12, 120, Color("#4e331d"))
			Spr.rect(bx0 - 14, y0 + 26, 40, 10, Color("#6b4626"))
			if int(bx0 / 260.0) % 2 == 0:
				# lampião apagado pendurado
				Spr.seg(bx0 + 22, y0 + 36, bx0 + 22, y0 + 50, Color("#2a2018"), 2)
				Spr.rr(bx0 + 16, y0 + 50, 12, 16, 3, Color("#5a5048"))
				Spr.rect(bx0 + 18, y0 + 54, 8, 8, Color(.25, .22, .18))
		bx0 += 260.0
