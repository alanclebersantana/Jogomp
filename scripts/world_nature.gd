extends RefCounted
class_name WorldNature
## Desenho dos trechos novos: pinheiros, casas da vila com neve, lampião e boneco de neve (fixos);
## lamaçal com sanguessugas, corda esticada, bolhas, capacete, arpão, bolas de neve, buracos de
## água gelada, esquilos, corvos, piranhas, e o cavalo.

const INK := Color("#2a1a0e")
## faixa do pedaço de cenário que está desenhando (peças largas se cortam nela)
static var clip_x0 := -1e9
static var clip_x1 := 1e9

# ---------------------------------------------------------------- cenário fixo (world_static)
static func decor(d: Dictionary) -> void:
	var s: float = d.get("s", 1.0)
	match d.k:
		"pine":
			pine(d.x, d.y, s)
		"house1", "house2":
			var n: String = "v_house1" if d.k == "house1" else "v_house2"
			var w: float = 210 * s
			Spr.ellipse(d.x, d.y + 2, w * .55, 10, Color(0, 0, 0, .25))
			# casas são só cenário (sólidas, sem transparência)
			Spr.ABb(n, d.x, d.y + 6, w)
			# neve de verdade cobrindo o telhado: acompanha o contorno de cima da casa (lido da arte)
			var r = Spr.AR[n]
			var k: float = w / r[2]
			var line: PackedFloat32Array = _roof_line(n)
			var left: float = d.x - w / 2
			var base: float = d.y + 6 - r[3] * k
			var tp := PackedVector2Array()
			var bp := PackedVector2Array()
			for i in line.size():
				var sx: float = left + i * 3 * k
				var ty: float = base + line[i] * k
				var fluff: float = 2.5 + 1.5 * sin(sx * .21) + 1.2 * sin(sx * .07)
				tp.push_back(Vector2(sx, ty - fluff))
				bp.push_back(Vector2(sx, ty + 7 + 2.5 * sin(sx * .13 + 1.0)))
			var sp := PackedVector2Array(tp)
			for i in range(bp.size() - 1, -1, -1):
				sp.push_back(bp[i])
			Spr.poly(sp, Color(.96, .97, 1))
			Spr.line(bp, Color(.72, .8, .92, .8), 2)
			# pingentes nas beiradas mais baixas do telhado
			for side in [0, 1]:
				var lo_i := 0
				var lo_y := -1e9
				var rng: Array = range(0, line.size() / 3) if side == 0 else range(line.size() * 2 / 3, line.size())
				for i in rng:
					if line[i] > lo_y and line[i] < r[3] * .75:
						lo_y = line[i]
						lo_i = i
				for q in 4:
					var qi: int = clamp(lo_i + (q - 2) * 3 * (1 if side == 0 else -1), 0, line.size() - 1)
					var ix: float = left + qi * 3 * k
					var iy: float = base + line[qi] * k + 6
					var ln: float = 8 + (q * 7 % 5) * 3
					Spr.poly(PackedVector2Array([Vector2(ix - 3, iy), Vector2(ix, iy + ln), Vector2(ix + 3, iy)]), Color(.85, .95, 1, .95))
		"lamp":
			Spr.rect(d.x - 3, d.y - 110, 6, 110, Color("#3a2a1a"))
			Spr.rect(d.x - 12, d.y - 6, 24, 6, Color("#3a2a1a"))
			Spr.rr(d.x - 12, d.y - 132, 24, 24, 4, Color("#4a3a2a"))
			Spr.rect(d.x - 8, d.y - 128, 16, 16, Color("#ffd27a"))
			Spr.glow(d.x, d.y - 120, 60, Color(1, .8, .4, .35))
			Spr.ellipse(d.x, d.y - 134, 16, 5, Color(.96, .97, 1))
		"snowman":
			snowman(d.x, d.y, s, false)
		"snowtree":
			prop("arvore_neve", d.x, d.y + 4, 300 * s)
			_roots(d.x, d.y, s)
		"tracks", "paws":
			pass   # desenhado na camada de cima (tracks), por cima do chão
		"bearden":
			# a toca do Urso-Rei: encosta de pedra nevada com a caverna escura (fundo da arena)
			if Spr.has("p_bearden"):
				# cada pedaço do cenário desenha só a sua faixa (senão o pedaço seguinte cobre os blocos de gelo)
				var r: Array = Spr.AR["p_bearden"]
				var w: float = 860 * s
				var hgt: float = w * r[3] / r[2]
				var left: float = d.x - w / 2
				var va: float = max(left, clip_x0)
				var vb: float = min(left + w, clip_x1)
				if vb > va:
					var t: Texture2D = Spr.atlas_tex(r)
					var su: float = (va - left) / w
					var sv: float = (vb - left) / w
					Spr.ci.draw_texture_rect_region(t, Rect2(va, d.y + 8 - hgt, vb - va, hgt), Rect2(r[0] + r[2] * su, r[1], r[2] * (sv - su), r[3]), Color(.82, .85, .92, Spr.alpha))
			else:
				Spr.ellipse(d.x, d.y, 360 * s, 190 * s, Color("#5d6878"))
				Spr.ellipse(d.x, d.y - 150 * s, 300 * s, 60 * s, Color(.93, .95, 1))
				Spr.ellipse(d.x, d.y - 10, 90 * s, 110 * s, Color("#141820"))
		"logpile":
			Spr.ellipse(d.x, d.y + 2, 70 * s, 7, Color(0, 0, 0, .2))
			WorldVehicles._hlog(d.x - 64 * s, d.x + 60 * s, d.y - 18 * s, 18 * s)
			WorldVehicles._hlog(d.x - 40 * s, d.x + 50 * s, d.y - 34 * s, 16 * s)
			Spr.ellipse(d.x - 6, d.y - 36 * s, 40 * s, 5, Color(.95, .97, 1))

## linha de cima da arte (o contorno do telhado), a cada 3 px, para a neve assentar certinho
static var _roofs := {}
static var _roof_data := {}
static var _roof_data_loaded := false
static func _roof_line(n: String) -> PackedFloat32Array:
	if _roofs.has(n):
		return _roofs[n]
	# medido uma vez da arte (assets/data/roofs.json, feito por tools): ler a imagem da placa de vídeo no
	# celular era lento e segurava a entrada na fase com a tela preta
	var out := PackedFloat32Array()
	if not _roof_data_loaded:
		_roof_data_loaded = true
		var j = JSON.parse_string(FileAccess.get_file_as_string("res://assets/data/roofs.json"))
		if j is Dictionary:
			_roof_data = j
	for v in _roof_data.get(n, []):
		out.push_back(float(v))
	_roofs[n] = out
	return out

## objeto pintado (assets/sprites/p_<nome>.png), com a base no ponto (x, y) e a altura dada
static func prop(n: String, x: float, y: float, h: float, flip: bool = false, a: float = 1.0) -> void:
	var k := "p_" + n
	if not Spr.tex.has(k):
		Spr.late(k)
		Spr.tex[k] = load("res://assets/sprites/%s.png" % k)
	var t: Texture2D = Spr.tex[k]
	var w: float = h * t.get_width() / t.get_height()
	if flip:
		Spr.save()
		Spr.translate(x, y)
		Spr.scale(-1, 1)
		Spr.ci.draw_texture_rect(t, Rect2(-w / 2, -h, w, h), false, Color(1, 1, 1, Spr.alpha * a))
		Spr.restore()
	else:
		Spr.ci.draw_texture_rect(t, Rect2(x - w / 2, y - h, w, h), false, Color(1, 1, 1, Spr.alpha * a))

## árvore do cenário plantada no chão de baixo, na frente de um paredão onde o Tomé anda em cima:
## fica na camada da frente (o Tomé passa por trás dela)
static func is_front(L: Dictionary, d: Dictionary) -> bool:
	if d.has("_front"):
		return d._front
	var f := false
	if d.get("k", "") in ["pine", "snowtree", "tree"]:
		for s in L.solids:
			if s.get("deco") or not str(s.get("t", "")) in ["cliff", "stone", "dirt", "ground"]:
				continue
			if s.x + 10 < d.x and d.x < s.x + s.w - 10 and s.y < d.y - 40 and abs(s.y + s.get("h", 0) - d.y) < 24:
				f = true
	d._front = f
	return f

## árvores da camada da frente (desenhadas depois do Tomé)
static func front_decor(g: Game) -> void:
	for d in g.L.get("decor", []):
		if d.x < g.cam - 300 or d.x > g.cam + g.W + 300:
			continue
		if is_front(g.L, d):
			decor(d)

static func pine(x: float, y: float, s: float) -> void:
	prop("pinheiro", x, y + 4, 330 * s)
	_roots(x, y, s)

## raízes e um montinho de neve na base: a árvore fica plantada no chão (sem parecer flutuar)
static func _roots(x: float, y: float, s: float) -> void:
	for r in [-1.0, -.4, .45, 1.0]:
		Spr.poly(PackedVector2Array([Vector2(x + r * 6 * s, y - 10 * s), Vector2(x + r * 30 * s, y + 3), Vector2(x + r * 6 * s, y + 3)]), Color("#4e331d"))
	Spr.ellipse(x, y + 1, 34 * s, 6, Color(.95, .97, 1))
	Spr.ellipse(x - 8 * s, y - 2, 20 * s, 4, Color(1, 1, 1))

static func snowman(x: float, y: float, s: float, hat: bool) -> void:
	Spr.ellipse(x, y + 2, 40 * s, 8 * s, Color(0, 0, 0, .2))
	prop("boneco", x, y + 4, 150 * s)
	if hat:
		beanie(x - 2 * s, y - 128 * s, s)

## o gorro verde do Tomé (com pompom); (x, y) = meio da aba
static func beanie(x: float, y: float, s: float) -> void:
	prop("gorro", x, y + 12 * s, 40 * s)


## marcas das rodas do carrinho e pegadas na neve (por cima do chão)
static func tracks(d: Dictionary) -> void:
	var w: float = d.get("w", 800)
	for k in 2:
		var ty: float = d.y - 3 + k * 5
		Spr.seg(d.x, ty, d.x + w, ty + 2, Color(.55, .62, .74, .8), 3)
	var fx: float = d.x + 20
	var n := 0
	while fx < d.x + w:
		Spr.ellipse(fx, d.y - 1 + (n % 2) * 4, 6, 2.5, Color(.5, .56, .68, .75))
		fx += 46
		n += 1

## pegadas grandes do urso na neve (almofada + 4 dedos), indo e voltando da toca
static func paws(d: Dictionary) -> void:
	var w: float = d.get("w", 600)
	var fx: float = d.x + 10
	var n := 0
	var c := Color(.48, .54, .66, .7)
	while fx < d.x + w:
		var fy: float = d.y - 2 + (n % 2) * 5
		Spr.ellipse(fx, fy, 9, 3.4, c)
		for t in 4:
			Spr.ellipse(fx - 8 + t * 5.3, fy - 5.5 - abs(t - 1.5) * -.6, 2.4, 1.6, c)
		fx += 64
		n += 1

# ---------------------------------------------------------------- dinâmico (world_dyn)
static func draw(g: Game, T: int) -> void:
	var NT: Nature = g.NT
	if NT == null:
		return
	var x0: float = g.cam - 120
	var x1: float = g.cam + g.W + 120
	for d in g.L.get("decor", []):
		if d.k == "tracks" and d.x < x1 and d.x + d.get("w", 800) > x0:
			tracks(d)
		elif d.k == "paws" and d.x < x1 and d.x + d.get("w", 600) > x0:
			paws(d)
	# corda esticada entre dois postes
	for b in NT.BARS:
		if b.x0 > x1 or b.x1 < x0:
			continue
		for px in ([] if b.get("clothes") else [b.x0 - 14, b.x1 + 6]):
			Spr.rect(px, b.y - 30, 12, 1150 - b.y, Color("#5a3d22"))
			Spr.rect(px + 2, b.y - 30, 3, 1150 - b.y, Color(1, 1, 1, .08))
			Spr.ellipse(px + 6, b.y - 30, 9, 4, Color("#7a5532"))
		var pts := PackedVector2Array()
		var p: Dictionary = g.player
		var pcx: float = p.x + p.w / 2 if p.get("bar") == b else -9999.0
		for k in 41:
			var u := k / 40.0
			var xx: float = lerpf(b.x0 - 8, b.x1 + 12, u)
			pts.push_back(Vector2(xx, NT.bar_y(b, xx)))
		Spr.ci.draw_polyline(pts, Color("#3a2414"), 6, true)
		Spr.ci.draw_polyline(pts, Color("#c9a26a"), 3.5, true)
		if b.get("clothes"):
			# varal da vila: roupas penduradas balançando (onde o Tomé segura, elas saem do caminho)
			var cols := [Color("#c94a3a"), Color("#e8e0c8"), Color("#4a7ab0"), Color("#d8a83a"), Color("#6a9a4a")]
			for k in range(2, 40, 5):
				var q: Vector2 = pts[k]
				if abs(q.x - pcx) < 40:
					continue
				var sw: float = sin(g.T * .05 + q.x * .1) * .12
				var c: Color = cols[int(abs(q.x)) % cols.size()]
				Spr.save()
				Spr.translate(q.x, q.y + 1)
				Spr.rotate(sw)
				if int(abs(q.x) / 3.0) % 2 == 0:
					# camisa
					Spr.poly(PackedVector2Array([Vector2(-12, 0), Vector2(12, 0), Vector2(16, 10), Vector2(10, 10), Vector2(10, 28), Vector2(-10, 28), Vector2(-10, 10), Vector2(-16, 10)]), c)
				else:
					# meia ou pano
					Spr.rect(-6, 0, 12, 22, c)
				Spr.rect(-2, -2, 4, 4, Color("#8a6a42"))
				Spr.restore()
	# buracos de água gelada
	for h in NT.HOLES:
		if h.x > x1 or h.x + h.w < x0:
			continue
		if not h.filled:
			# água gelada mortal: paredes de gelo irregulares, água escura ondulando e margens de neve fofa
			var wpts := PackedVector2Array()
			var wx: float = h.x + 4
			while wx <= h.x + h.w - 4:
				wpts.push_back(Vector2(wx, h.y + 8 + sin(T * .05 + wx * .05) * 1.6 + sin(T * .031 - wx * .09) * 1.0))
				wx += 8
			var surf := PackedVector2Array(wpts)
			wpts.push_back(Vector2(h.x + h.w - 4, h.y + 140))
			wpts.push_back(Vector2(h.x + 4, h.y + 140))
			var wcols := PackedColorArray()
			for i in wpts.size():
				wcols.push_back(Color(.07, .12, .17) if i < surf.size() else Color(.01, .02, .04))
			Spr.ci.draw_polygon(wpts, wcols)
			Spr.line(surf, Color(.55, .68, .8, .6), 2)
			for side in [0, 1]:
				var e: float = h.x if side == 0 else h.x + h.w
				var dir: float = 1.0 if side == 0 else -1.0
				var wp := PackedVector2Array([Vector2(e - dir * 2, h.y)])
				var wy: float = h.y
				while wy <= h.y + 140:
					wp.push_back(Vector2(e + dir * (16 + 10 * sin(wy * .09 + e) + 6 * sin(wy * .27 + e) + max(0.0, 18.0 - (wy - h.y) * .3)), wy))
					wy += 10
				wp.push_back(Vector2(e - dir * 2, h.y + 140))
				Spr.poly(wp, Color(.3, .42, .58))
				# gelo claro na parte de cima da parede
				var wp2 := PackedVector2Array([Vector2(e - dir * 2, h.y)])
				for q in 6:
					var qy: float = h.y + q * 6
					wp2.push_back(Vector2(e + dir * (22 - q * 2.5 + 4 * sin(qy * .3 + e)), qy))
				wp2.push_back(Vector2(e - dir * 2, h.y + 30))
				Spr.poly(wp2, Color(.7, .85, .97))
			var k := 0
			var px: float = h.x + 10
			while px < h.x + h.w - 30:
				var pw: float = 26 + fmod(px * .73, 22.0)
				var bob: float = sin(T * .04 + px) * 1.2
				var pts := PackedVector2Array([Vector2(px, h.y + 8 + bob), Vector2(px + pw * .4, h.y + 5 + bob), Vector2(px + pw, h.y + 8 + bob),
					Vector2(px + pw * .8, h.y + 13 + bob), Vector2(px + pw * .2, h.y + 13 + bob)])
				Spr.poly(pts, Color(.82, .92, 1, .92))
				Spr.seg(px + pw * .3, h.y + 7 + bob, px + pw * .55, h.y + 12 + bob, Color(.45, .58, .72), 1.2)
				px += pw + 14 + fmod(px * 1.3, 12.0)
				k += 1
			# margens de neve arredondadas cobrindo a quina do buraco
			for side in [0, 1]:
				var ex: float = h.x if side == 0 else h.x + h.w
				Spr.ellipse(ex, h.y + 2, 26, 11, Color(.8, .87, .97))
				Spr.ellipse(ex - (2 if side == 0 else -2), h.y - 1, 22, 8, Color(.97, .98, 1))
			for v in 3:
				var vx: float = h.x + h.w * (.2 + v * .3) + sin(T * .02 + v) * 10
				var vy: float = h.y - fmod(T * .5 + v * 30.0, 50.0)
				Spr.ellipse(vx, vy, 16, 6, Color(.9, .95, 1, .18 * (1.0 - fmod(T * .5 + v * 30.0, 50.0) / 50.0)))
	# capacete e arpão
	for o in NT.GEAR:
		if o.got:
			continue
		var by: float = o.y + sin(T * .08) * 2
		Spr.glow(o.x, by - 16, 34, Color(1, .95, .7, .45))
		if o.id == "capacete":
			helmet(o.x, by, 1.0)
		else:
			Spr.A("crate_harpoon", o.x, by - 18, .62)
	# arpões
	for h in NT.HARP:
		var tail: float = h.x - sign(h.vx) * 26
		Spr.seg(tail, h.y, h.x, h.y, Color("#6b4a2a"), 3)
		Spr.poly(PackedVector2Array([Vector2(h.x + sign(h.vx) * 10, h.y), Vector2(h.x, h.y - 5), Vector2(h.x, h.y + 5)]), Color(.75, .78, .82))
		Spr.seg(h.sx, h.y + 2, tail, h.y, Color(.85, .8, .7, .35), 1)
	# corrente de bolhas (aberta depois do Bagre-Rei)
	if g.K and g.K.fish_done():
		for c in NT.CURRENTS:
			if c.x > x1 or c.x + c.w < x0:
				continue
			Spr.rect(c.x, c.y0, c.w, c.y1 - c.y0, Color(.7, .9, 1, .08 + sin(T * .1) * .03))
			for k in 10:
				var yy: float = c.y1 - fmod(T * 4.0 + k * 61.0, c.y1 - c.y0)
				Spr.ring(c.x + c.w * (.2 + (k % 5) * .15), yy, 4 + (k % 3) * 2, Color(.85, .95, 1, .7), 1.5)

## lamaçal (na camada da frente: o Tomé afunda nele)
static func draw_bogs(g: Game, T: int) -> void:
	var NT: Nature = g.NT
	if NT == null:
		return
	var x0: float = g.cam - 120
	var x1: float = g.cam + g.W + 120
	for b in NT.BOGS:
		if b.x > x1 or b.x + b.w < x0:
			continue
		# lamaçal: superfície mole ondulando devagar, pontas arredondadas entrando no barranco
		var top := PackedVector2Array()
		var xx: float = b.x
		while xx <= b.x + b.w + .1:
			var u: float = (xx - b.x) / b.w
			var endk: float = pow(abs(u - .5) * 2.0, 6.0)
			top.push_back(Vector2(xx, b.y - 4 + sin(xx * .04 + T * .02) * 2.0 + sin(xx * .11 - T * .03) * 1.2 + endk * 8))
			xx += 12
		var body := PackedVector2Array(top)
		body.push_back(Vector2(b.x + b.w, b.y + 140))
		body.push_back(Vector2(b.x, b.y + 140))
		var cols := PackedColorArray()
		for q in body:
			cols.push_back(Color("#6a5230").lerp(Color("#2a1e10"), clamp((q.y - b.y + 4) / 60.0, 0, 1)))
		Spr.ci.draw_polygon(body, cols)
		Spr.line(top, Color(.85, .74, .5, .45), 2.5)
		# brilho molhado e manchas mais escuras
		for k in int(b.w / 70.0):
			var mx: float = b.x + 30 + fmod(k * 83.0, b.w - 60)
			Spr.ellipse(mx, b.y + 4, 18 + (k % 3) * 6, 2.2, Color(1, .95, .8, .16))
			Spr.ellipse(mx + 30, b.y + 16, 26, 4, Color(0, 0, 0, .14))
		var x: float = b.x + 24
		var i := 0
		while x < b.x + b.w - 10:
			var t: float = fmod(T * .018 + i * .37, 1.0)
			if i % 3 == 0:
				# sanguessuga se contorcendo para fora da lama
				var hgt: float = sin(t * PI) * 30
				var sw: float = sin(T * .2 + i) * 5
				if hgt < 10:
					# entrando/saindo da lama: só a pontinha (o polígono baixo demais se cruzava e
					# não desenhava — dava erro de triangulação a cada quadro)
					Spr.ellipse(x + sw * .3, b.y - hgt * .3, 6, 2.0 + hgt * .3, Color("#1e1610"))
				else:
					var pts := PackedVector2Array([Vector2(x - 6, b.y), Vector2(x - 4 + sw * .5, b.y - hgt * .5), Vector2(x + sw, b.y - hgt), Vector2(x + 6 + sw, b.y - hgt + 4), Vector2(x + 4 + sw * .5, b.y - hgt * .5 + 4), Vector2(x + 6, b.y)])
					Spr.poly(pts, Color("#1e1610"))
					Spr.ci.draw_polyline(pts, Color("#5a3a2a"), 1.5, true)
					Spr.circle(x + sw + 2, b.y - hgt + 2, 1.8, Color(1, .35, .25))
			else:
				Spr.ring(x, b.y - 2, 4 + t * 12, Color(.9, .78, .5, .6 * (1.0 - t)), 1.5)
				Spr.circle(x + 8, b.y - 3 - sin(t * PI) * 4, 3 * (1.0 - t), Color("#5a4428"))
			x += 34 + (i % 4) * 8
			i += 1

static func helmet(x: float, y: float, s: float) -> void:
	prop("capacete", x, y + 2 * s, 48 * s)

static func snowball(c: Dictionary, T: int) -> void:
	var r: float = c.w / 2
	var cx: float = c.x + r
	var cy: float = c.y + r
	Spr.ellipse(cx, c.y + c.h + 1, r * .9, 4, Color(0, 0, 0, .2))
	# gira enquanto rola
	Spr.save()
	Spr.translate(cx, cy)
	Spr.rotate(c.x / max(8.0, r))
	prop("bola_neve", 0, r * 1.02, r * 2.04)
	Spr.restore()

## pedaços sólidos que aparecem durante o jogo
static func solid(s: Dictionary, T: int) -> void:
	match s.t:
		"snowfill":
			Spr.rr(s.x - 4, s.y - 4, s.w + 8, 22, 8, Color(.92, .96, 1))
			Spr.rect(s.x, s.y + 12, s.w, 18, Color(.7, .82, .95))
			for k in 5:
				Spr.seg(s.x + 20 + k * 50, s.y + 4, s.x + 34 + k * 50, s.y + 14, Color(.6, .72, .88), 1.5)
		"snowbank":
			var pts := PackedVector2Array([Vector2(s.x - 40, s.y + s.h), Vector2(s.x - 20, s.y + 40), Vector2(s.x + 6, s.y), Vector2(s.x + s.w + 10, s.y + 30), Vector2(s.x + s.w + 40, s.y + s.h)])
			if Spr.has("p_snowpile"):
				# monte de neve pintado (esticado na altura do barranco)
				Spr.PR("snowpile", s.x - 52, s.y - 14, s.w + 104, s.h + 18)
			else:
				Spr.poly(pts, Color(.93, .95, 1))
				Spr.ci.draw_polyline(pts, Color(.6, .68, .82), 2, true)
			# arame farpado
			for k in 3:
				var yy: float = s.y + 90 + k * 46
				Spr.seg(s.x - 70, yy, s.x + s.w + 10, yy + 6, Color(.35, .35, .38), 2)
				var xx: float = s.x - 66
				while xx < s.x + s.w:
					Spr.seg(xx - 4, yy - 4, xx + 4, yy + 4 + 1, Color(.3, .3, .32), 1.5)
					Spr.seg(xx - 4, yy + 4, xx + 4, yy - 4 + 1, Color(.3, .3, .32), 1.5)
					xx += 18
		"kinggate":
			WorldKings.gate(s, T)

# ---------------------------------------------------------------- bichos
static func squirrel(e: Dictionary, T: int) -> void:
	# arte: 0-3 correndo, 4 bote, 5 nocauteado (olhando para a direita; o chamador já espelha)
	if not Spr.tex.has("esquilo"):
		Spr.tex["esquilo"] = load("res://assets/sprites/esquilo.png")
	var fr: int = int(e.get("run", 0.0)) % 4
	var running: bool = not e.dead and e.get("st", 0) == 0
	if running:
		Spr.frame_mix(Spr.tex.esquilo, e.get("run", 0.0), 4, 0, 130, 110, 65, 108, 0, 0, .6)
		return
	if e.dead:
		fr = 5
	elif e.get("st", 0) == 2:
		fr = 4
	elif e.get("st", 0) == 1:
		fr = 3
	# maior e de cor forte (inimigo), diferente dos bichinhos do cenário
	Spr.frame(Spr.tex.esquilo, fr, 130, 110, 65, 108, 0, 0, .6)

static func crow(e: Dictionary, T: int) -> void:
	if e.dead:
		var ck: Texture2D = Spr.opt("crow_ko")
		if ck:
			Spr.save()
			Spr.scale(.74, .74)
			Spr.trect(ck, Rect2(-ck.get_width() * .5, -ck.get_height() * .5, ck.get_width(), ck.get_height()))
			Spr.restore()
		else:
			Spr.A("crow_dead", 0, 0, .5)
		return
	# mergulho (descendo): pose pintada de asas recolhidas
	var cd: Texture2D = Spr.opt("crow_dive")
	if cd and e.get("st", 0) == 1 and e.get("t", 0) < 28:
		Spr.save()
		Spr.scale(.74, .74)
		Spr.trect(cd, Rect2(-cd.get_width() * .5, -cd.get_height() * .5 - 10, cd.get_width(), cd.get_height()))
		Spr.restore()
		return
	# corvo grande (bem maior que os tucanos do cenário); batendo asas rápido antes do mergulho
	var fs: int = 3 if e.get("st", 0) == 5 else 5
	if Spr.tex.has("en_crow2"):
		# (a fase de cada corvo é fixa: antes dependia do x e as asas aceleravam ou travavam conforme ele voava)
		Spr.frame_mix(Spr.tex.en_crow2, T / float(fs) + float(int(e.get("x0", 0.0) * .37) % 4), 4, 0, 170, 130, 85, 65, 0, -8, .74)
	else:
		Spr.A_cycle("crow", ["crow0", "crow1", "crow2"], T / 4.0, 0, -8, .74)

static func piranha(e: Dictionary, T: int) -> void:
	WorldExtras._pc("piranha%d" % (1 if (not e.dead and (T / 10) % 3 == 0) else 0), 0, 0, 46)

# ---------------------------------------------------------------- cavalo
## cavalo desenhado: corpo, pescoço, cabeça e quatro pernas num galope (g = fase do galope)
## cavalo desenhado (arte em assets/sprites/cavalo.png; âncoras em assets/data/art_meta.json)
static var HM: Dictionary = {}
const HORSE_SC := .8

static func _hm() -> Dictionary:
	if HM.is_empty():
		var f := FileAccess.open("res://assets/data/art_meta.json", FileAccess.READ)
		HM = JSON.parse_string(f.get_as_text()).cavalo
		if not Spr.tex.has("cavalo"):
			Spr.tex["cavalo"] = load("res://assets/sprites/cavalo.png")
	return HM

## quadro do cavalo: 0-3 galope, 4 pulo, 5 parado
static func horse_frame(g: float, run: float, st: String) -> int:
	# galope em 6 quadros (0-5), pulo (6) e parado (7)
	if st == "jump":
		return 6
	if run <= .05:
		return 7
	return int(floor(g * 6.0)) % 6

## altura da sela acima do chão (negativa), para pôr o Tomé montado
static func horse_seat(fr: int) -> float:
	var m := _hm()
	return (float(m.seat[fr][1]) - float(m.ay)) * HORSE_SC

static func horse(x: float, y: float, g: float, run: float, st: String, T: int) -> void:
	var m := _hm()
	var fr := horse_frame(g, run, st)
	var s := HORSE_SC
	var cw: float = m.w
	var ch: float = m.h
	Spr.ellipse(x, y + 2, 64, 8, Color(0, 0, 0, .25 if st != "jump" else .12))
	var hdst := Rect2(x - float(m.ax) * s, y - float(m.ay) * s, cw * s, ch * s)
	if fr < 6:
		# galope com quadros intermediários (x4)
		Spr.region_mix(Spr.tex.cavalo, hdst, cw, ch, [0, 1, 2, 3, 4, 5], g * 6.0, Color(1, 1, 1, Spr.alpha))
	else:
		Spr.ci.draw_texture_rect_region(Spr.tex.cavalo, hdst, Rect2(fr * cw, 0, cw, ch), Color(1, 1, 1, Spr.alpha))
	if st == "trapped":
		# arame farpado enrolado nas patas
		for k in 3:
			var wy: float = y - 14 - k * 9
			Spr.seg(x - 50, wy, x + 40, wy + 4, Color(.55, .55, .58), 1.6)
			for j in 6:
				var bx: float = x - 44 + j * 15
				Spr.seg(bx - 3, wy - 3, bx + 3, wy + 4, Color(.4, .4, .44), 1.4)
		Spr.text("!", x + 50, y - 150 + sin(T * .2) * 3, 26, Color("#ffecaa"), HORIZONTAL_ALIGNMENT_CENTER, Spr.font_b, 4)
