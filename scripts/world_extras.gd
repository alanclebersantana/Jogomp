extends RefCounted
class_name WorldExtras
## Desenho dos sistemas novos que ficam no mundo (escurecem com a noite):
## capim que balança, pegadas, giz da Isis, rochas rachadas, grades, espelhos, cristais,
## plataformas de luz, troncos e o Javali-Rei, e os inimigos novos (morcego, aranha, toupeira).

const WSt = preload("res://scripts/world_static.gd")
const CHALK := Color(.96, .95, .9, .82)

static func h(x: float, k: int = 0) -> float:
	## ruído fixo 0..1 a partir de x
	var v := sin(x * 12.9898 + k * 78.233) * 43758.5453
	return v - floor(v)

# ---------------------------------------------------------------- capim
static var _gspring := {}
static var _gcache := {}
const GRASS_W := [22.0, 30.0, 30.0, 30.0, 28.0]
## dados fixos de um tufo em x: [tem tufo, nome da peça, largura, espelhado, deslocamento x,
## tem orvalho, posição do orvalho, tem joaninha]
static func _tuft(x: float) -> Array:
	var kind: int = int(h(x, 3) * 5)
	var tall: bool = h(x, 7) > .88
	var w: float = GRASS_W[kind] * (.85 + h(x, 4) * .35) * (1.45 if tall else 1.0)
	return [h(x) > .3, "grass%d" % kind, w, h(x, 6) > .5, (h(x, 5) - .5) * 10, h(x, 8) > .55, h(x, 9) - .5, h(x, 10) > .93]
static func grass(g: Game, T: int) -> void:
	## tufos de grama pintados (mesma arte do cenário): balançam com o vento, abrem quando alguém passa
	## (Tomé, bichos, Pipoca, chefes), deitam com o pouso e o mergulho, e o empurrão corre pelos vizinhos
	var x0: float = g.cam - 40
	var x1: float = g.cam + g.W + 40
	var wind: float = g.AMB.get("wind", 0.0)
	var manha: bool = Polish.period() == "manha"
	var bugs: bool = not Polish.period() in ["noite", "tunel"]
	# balanço do vento e onda das rajadas: as partes iguais para todos os tufos, contadas uma vez
	var sw_f: float = .03 + wind * .05
	var sw_a: float = 1.2 + wind * 4.0
	var sw_b: float = wind * 3.0
	var wvw: float = wind + Polish.gust_k() * .8
	var wv: float = wvw * 7.0 if wvw >= .05 else 0.0
	var wv_t: float = g.T * .07
	var has_flat: bool = not Polish.flat_zones.is_empty()
	var has_cut: bool = not Polish.cut.is_empty()
	for s in g.SOL:
		if s.t != "ground" or s.x > x1 or s.x + s.w < x0 or s.get("snow"):
			continue
		if WSt.gt_at(g, s.x + s.w / 2) != "":
			continue   # chão de pedra (mina, rua da vila): sem capim
		# posições presas ao mundo (grade de 34 px): o tufo não muda de lugar quando a câmera anda
		var xa: float = max(s.x + 14, ceil((x0 - 14.0) / 34.0) * 34.0 + 14.0)
		var xb: float = min(s.x + s.w - 14, x1)
		var tc: Color = Polish.grass_tint(WSt.tint_at(g, xa))
		var x: float = xa
		var by: float = s.y + 4
		while x < xb:
			var gkey: int = int(x)
			# o que não muda num tufo (tipo, tamanho, lado, deslocamento, orvalho, joaninha) fica guardado:
			# antes eram ~10 ruídos e uma montagem de nome por tufo a cada quadro
			var tf = _gcache.get(gkey)
			if tf == null:
				tf = _tuft(x)
				_gcache[gkey] = tf
			if tf[0]:
				# o capim abre quando alguém passa e volta balançando como mola; o empurrão passa
				# para os tufos vizinhos (onda no capim)
				# (a mola anda uma vez por passo da lógica: em telas de 90/120 Hz não balança mais rápido)
				var gs: Vector2 = _gspring.get(gkey, Vector2.ZERO)
				if Polish.FRESH:
					var gt: float = Polish.grass_push(x, s.y, 34.0)
					# nada empurrando e nenhuma mola andando: o tufo fica parado (sem conta nenhuma)
					if gt != 0.0 or not _gspring.is_empty():
						var nb: float = 0.0
						var gl = _gspring.get(gkey - 34)
						var gr = _gspring.get(gkey + 34)
						if gl != null:
							nb += gl.x
						if gr != null:
							nb += gr.x
						gs.y += (gt + nb * .22 - gs.x) * .2
						gs.y *= .8
						gs.x += gs.y
						if abs(gs.x) < .02 and abs(gs.y) < .02 and gt == 0.0:
							_gspring.erase(gkey)
						else:
							_gspring[gkey] = gs
				var push: float = gs.x
				var sway: float = sin(T * sw_f + x * .03) * sw_a + sw_b
				if wv > 0.0:
					sway += max(0.0, sin(x * .008 - wv_t)) * wv
				var w: float = tf[2]
				var fl: float = Polish.flat_at(x, s.y) if has_flat else 0.0
				var gh: float = Polish.grass_h(x) if has_cut else 1.0
				var gxp: float = x + tf[4]
				if fl > 0.0 or gh < 1.0:
					# deitado (mergulho) ou cortado (picareta): achata a altura
					Spr.save()
					Spr.translate(gxp, by)
					Spr.scale(1.0, (1.0 - .7 * fl) * gh)
					Spr.P(tf[1], 0, 0, w, tf[3], sway * (1.0 - fl) + push + sign(push) * fl * 20.0, tc)
					Spr.restore()
				else:
					Spr.P(tf[1], gxp, by, w, tf[3], sway + push, tc)
				# orvalho de manhã: gotinhas brilhando na ponta de alguns tufos
				if manha and tf[5]:
					var tw: float = .5 + .5 * sin(T * .05 + x)
					Spr.circle(gxp + sway * .6 + push * .6 + tf[6] * w * .5, by - w * .55, 1.4, Color(1, 1, 1, .55 * tw))
				# joaninha andando numa folha do capim, de vez em quando
				if tf[7] and bugs:
					var lb: float = fposmod(T * .2 + x, 40.0) / 40.0
					var lx: float = gxp + (lb - .5) * w * .5 + push * .3
					var ly: float = by - w * (.15 + .3 * lb)
					Spr.circle(lx, ly, 2.2, Color(.85, .12, .08))
					Spr.circle(lx - .6, ly - .4, .5, Color(0, 0, 0))
					Spr.circle(lx + .7, ly + .3, .5, Color(0, 0, 0))
			x += 34

## flores do chão: balançam com a brisa (cada uma no seu ritmo), deitam quando o Tomé passa
## e voltam com um balanço de mola
static var _fspring := {}
static func flowers(g: Game, T: int) -> void:
	var x0: float = g.cam - 40
	var x1: float = g.cam + g.W + 40
	var p: Dictionary = g.player
	var pcx: float = p.x + p.w / 2
	var wind: float = g.AMB.get("wind", 0.0)
	for s in g.SOL:
		if s.t != "ground" or s.x > x1 or s.x + s.w < x0:
			continue
		var fl: Array = WSt.flowers_of(g, s)
		if fl.is_empty():
			continue
		for f in fl:
			var fx: float = f[0]
			if fx < x0 or fx > x1:
				continue
			var near: float = clamp(1.0 - abs(fx - pcx) / 30.0, 0, 1) if abs(p.y + p.h - s.y) < 40 else 0.0
			# mola: o empurrão decai e a flor volta balançando
			var key: int = int(fx)
			var sp: Vector2 = _fspring.get(key, Vector2.ZERO)
			# mola e pétalas andam uma vez por passo da lógica (mesmo ritmo em qualquer tela)
			if Polish.FRESH:
				var tgt: float = Polish.grass_push(fx, s.y, 30.0) * .85
				# pétalas soltando: correndo por cima ou com vento forte
				if (near > .5 and abs(p.vx) > 2.5 and randf() < .25) or (wind > .6 and randf() < .004):
					Polish.part("petal", fx, s.y - 18, sign(fx - pcx) * randf_range(.5, 1.6) + wind, -randf_range(.6, 1.6), 120, f[4] if f.size() > 4 else Color(1, .8, .9), {"gy": s.y + 2})
				sp.y += (tgt - sp.x) * .18
				sp.y *= .78
				sp.x += sp.y
				if abs(sp.x) < .02 and abs(sp.y) < .02 and near == 0.0:
					_fspring.erase(key)
				else:
					_fspring[key] = sp
			var sway: float = sin(T * (.035 + wind * .05) + fx * .05) * (1.4 + wind * 4.0) + wind * 3.0
			if f.size() < 5:
				f.append(WSt.tint_at(g, fx))
			var fl2: float = Polish.flat_at(fx, s.y)
			if fl2 > 0.0:
				Spr.save()
				Spr.translate(fx, s.y + 2)
				Spr.scale(1.0, 1.0 - .6 * fl2)
				Spr.P(f[1], 0, 0, f[2], f[3], sway + sp.x, f[4])
				Spr.restore()
			else:
				Spr.P(f[1], fx, s.y + 2, f[2], f[3], sway + sp.x, f[4])
			# abelhinha rodeando algumas flores de dia
			if Polish.hh2(fx) > .8 and Polish.period() in ["manha", "tarde"]:
				var bt: float = T * .06 + fx
				var bx: float = fx + cos(bt) * 16 + sin(bt * 2.3) * 4
				var byy: float = s.y - 22 + sin(bt * 1.7) * 7
				Spr.P("bee", bx, byy + 5, 9, cos(bt) > 0)

# ---------------------------------------------------------------- passagens baixas
static func crawl(g: Game, T: int) -> void:
	var p: Dictionary = g.player
	var pcx: float = p.x + p.w / 2
	for c in g.X.CRAWL:
		if c.x > g.cam + g.W + 50 or c.x + c.w < g.cam - 50:
			continue
		var gap: float = c.y - c.top
		# vão escuro embaixo, com a borda de baixo do obstáculo bem marcada
		Spr.vgrad(c.x - 4, c.top, c.w + 8, gap, Color(0, 0, 0, .65), Color(0, 0, 0, .25))
		Spr.rect(c.x - 4, c.top - 3, c.w + 8, 3, Color(1, .9, .6, .35))
		var near: bool = abs(pcx - (c.x + c.w / 2)) < c.w / 2 + 170 and abs(p.y + p.h - c.y) < 40 and not p.crouch
		if near:
			var b := sin(T * .15) * 4
			var cx: float = c.x + c.w / 2
			var iy: float = min(c.top - 40, c.y - 70) + b
			Spr.circle(cx, iy, 22, Color(0, 0, 0, .35))
			Spr.ci.draw_texture_rect(Spr.tex.pad_S, Rect2(cx - 18, iy - 18, 36, 36), false, Color(1, 1, 1, .95))
			Spr.text("abaixe", cx, iy + 34, 13, Color(1, .93, .7, .9), HORIZONTAL_ALIGNMENT_CENTER, Spr.font_b, 3)

# ---------------------------------------------------------------- pegadas
static func footprints(g: Game) -> void:
	# só as que estão na tela (a trilha inteira de pegadas ficava sendo desenhada fora dela)
	var x0: float = g.cam - 20
	var x1: float = g.cam + g.W + 20
	for f in g.X.FOOT:
		if f.x < x0 or f.x > x1:
			continue
		var a: float = clamp(1.0 - f.t / 900.0, 0, 1) * .5
		var fc := Color(.45, .55, .72, a) if f.get("snow") else Color(.12, .08, .05, a)
		Spr.ellipse(f.x, f.y - (5 if f.get("snow") else 1), 5, 2, fc)
		Spr.ellipse(f.x + f.f * 5, f.y - (5.5 if f.get("snow") else 1.5), 2.2, 1.6, fc)

# ---------------------------------------------------------------- giz da Isis
static func _stroke(pts: PackedVector2Array, w: float = 3.0) -> void:
	# giz de verdade: vários riscos finos e falhados, com grão (falhas onde o giz não pegou na pedra)
	for pass_i in 3:
		var jx: float = (pass_i - 1) * w * .28
		var jy: float = (1 - pass_i) * w * .2 + (pass_i % 2) * .4
		for i in pts.size() - 1:
			var a: Vector2 = pts[i]
			var b: Vector2 = pts[i + 1]
			var n: int = max(1, int(a.distance_to(b) / 3.0))
			for k in n:
				var u0: float = k / float(n)
				var u1: float = (k + 1) / float(n)
				var pa := a.lerp(b, u0)
				var hv: float = h(pa.x * 3.1 + pa.y * 1.7 + pass_i * 13.0, 5)
				if hv < .14:
					continue
				var al: float = CHALK.a * (.45 + hv * .5) * (1.0 if pass_i == 1 else .55)
				Spr.ci.draw_line(pa + Vector2(jx, jy), a.lerp(b, u1) + Vector2(jx, jy), Color(CHALK.r, CHALK.g, CHALK.b, al), w * (.55 if pass_i == 1 else .35), true)
	# pozinho de giz embaixo do traço
	if pts.size() > 0:
		var q: Vector2 = pts[pts.size() / 2]
		Spr.circle(q.x + 2, q.y + 5, 1.2, Color(1, 1, 1, .18))

static func chalk(g: Game, T: int) -> void:
	for c in g.X.CHALK:
		if c.x < g.cam - 80 or c.x > g.cam + g.W + 80:
			continue
		var x: float = c.x
		var y: float = c.y
		match c.k:
			"seta":
				var d: int = int(c.get("d", 1))
				if d == 0:
					_stroke(PackedVector2Array([Vector2(x, y + 22), Vector2(x, y - 20)]))
					_stroke(PackedVector2Array([Vector2(x - 10, y - 8), Vector2(x, y - 21), Vector2(x + 10, y - 8)]))
				else:
					_stroke(PackedVector2Array([Vector2(x - 22 * d, y), Vector2(x + 20 * d, y + 1)]))
					_stroke(PackedVector2Array([Vector2(x + 8 * d, y - 10), Vector2(x + 21 * d, y + 1), Vector2(x + 8 * d, y + 11)]))
				if c.get("q"):
					Spr.text("?", x - 30 * d, y + 8, 20, CHALK, HORIZONTAL_ALIGNMENT_CENTER, Spr.font_b)
			"coracao":
				var pts := PackedVector2Array()
				for i in 25:
					var t := TAU * i / 24.0
					pts.push_back(Vector2(x + 16 * pow(sin(t), 3) * .7, y - (13 * cos(t) - 5 * cos(2 * t) - 2 * cos(3 * t) - cos(4 * t)) * .7))
				_stroke(pts)
			"papai":
				Spr.text("PAPAI", x, y, 18, CHALK, HORIZONTAL_ALIGNMENT_CENTER, Spr.font_b)
				var pts2 := PackedVector2Array()
				for i in 13:
					var t2 := TAU * i / 12.0
					pts2.push_back(Vector2(x + 40 + 7 * pow(sin(t2), 3), y - 8 - (6 * cos(t2) - 2.5 * cos(2 * t2) - cos(3 * t2))))
				_stroke(pts2, 2.0)
			"sol":
				var o := PackedVector2Array()
				for i in 17:
					o.push_back(Vector2(x + cos(TAU * i / 16.0) * 10, y + sin(TAU * i / 16.0) * 10))
				_stroke(o)
				for i in 8:
					var a := TAU * i / 8.0
					_stroke(PackedVector2Array([Vector2(x + cos(a) * 14, y + sin(a) * 14), Vector2(x + cos(a) * 21, y + sin(a) * 21)]), 2.0)
			"estrela":
				var st := PackedVector2Array()
				for i in 11:
					var a2 := -PI / 2 + TAU * i / 10.0
					var rr := 18.0 if i % 2 == 0 else 8.0
					st.push_back(Vector2(x + cos(a2) * rr, y + sin(a2) * rr))
				_stroke(st)
			"flor":
				for i in 5:
					var a3 := TAU * i / 5.0
					var pe := PackedVector2Array()
					for j in 9:
						var b := TAU * j / 8.0
						pe.push_back(Vector2(x + cos(a3) * 9 + cos(b) * 5, y + sin(a3) * 9 + sin(b) * 5))
					_stroke(pe, 2.0)
				_stroke(PackedVector2Array([Vector2(x, y + 14), Vector2(x + 2, y + 34)]), 2.0)
			"x":
				if not g.X.broken.has("slab"):
					_stroke(PackedVector2Array([Vector2(x - 10, y - 7), Vector2(x + 10, y + 7)]), 3.5)
					_stroke(PackedVector2Array([Vector2(x + 10, y - 7), Vector2(x - 10, y + 7)]), 3.5)

# ---------------------------------------------------------------- peças com estado
static func solids(g: Game, T: int) -> void:
	WorldKings.set_view(g)
	for s in g.SOL:
		if s.x > g.cam + g.W + 100 or s.x + s.w < g.cam - 100:
			continue
		match s.t:
			"crack":
				_crack(s, T)
			"bars":
				# grade de ferro forjado, com pontas de lança, presa numa soleira de pedra
				Spr.PR("gate_iron", s.x - 6, s.y - 14, s.w + 12, s.h + 14)
				Spr.PR("wb3", s.x - 10, s.y + s.h - 8, s.w + 20, 14, Color(.85, .82, .78))
			"bossgate":
				WorldKings.gate(s, T)
			"bosslog":
				_log(s.x, s.y)
			"dogdoor":
				Spr.rr(s.x - 2, s.y, s.w + 4, s.h, 3, Color("#3a2414"))
				Spr.rr(s.x, s.y + 2, s.w, s.h - 3, 3, Color("#a8804a"))
				Spr.circle(s.x + s.w / 2, s.y + 15, 3, Color(.3, .2, .1))
				for k in 3:
					Spr.circle(s.x + s.w / 2 - 4 + k * 4, s.y + 9, 1.5, Color(.3, .2, .1))
			"hatchd":
				for i in 4:
					Spr.rect(s.x + 2 + i * 15, s.y, 12, 8, Color("#6b4a2a"))
				Spr.rect(s.x, s.y + 2, s.w, 3, Color("#4a3220"))
			"snowfill", "snowbank", "kinggate":
				WorldNature.solid(s, T)
	# plataformas de luz
	for gp in g.X.GHOST:
		var a: float = gp.a
		var c := Color(.75, .9, 1, .14 + a * .7)
		Spr.rr(gp.x, gp.y, gp.w, 14, 6, Color(.55, .75, 1, .06 + a * .5))
		Spr.ci.draw_rect(Rect2(gp.x, gp.y, gp.w, 14), c, false, 1.5)
		if a > .3:
			for k in 3:
				Spr.circle(gp.x + 10 + k * (gp.w - 20) / 2.0, gp.y + 7, 2, Color(1, 1, 1, a * .8))
	# espelhos
	for m in g.X.MIRRORS:
		var fl: float = m.flash / 14.0
		if m.get("ceil"):
			Spr.rect(m.x - 2, m.y - 30, 4, 18, Color(.35, .3, .25))
		else:
			Spr.rect(m.x - 10, m.y + 10, 20, 14, Color(.35, .3, .25))
		Spr.save()
		Spr.translate(m.x, m.y)
		Spr.rotate(-PI / 4 if int(m.s) == 0 else PI / 4)
		Spr.rr(-18, -5, 36, 10, 3, Color("#5a4a3a"))
		Spr.rect(-15, -3, 30, 6, Color(.75 + fl * .25, .88 + fl * .1, 1))
		Spr.rect(-13, -2, 10, 2, Color(1, 1, 1, .8))
		Spr.restore()
		if g.X.near_floor_mirror() == m:
			Spr.text("✦ GIRAR", m.x, m.y - 30 + sin(T * .15) * 3, 15, Color("#ffecaa"), HORIZONTAL_ALIGNMENT_CENTER, Spr.font_b, 4)
	# cristais
	for c2 in g.X.CRYSTALS:
		var e: float = 1.0 if c2.on else c2.charge / 60.0
		var pts := PackedVector2Array([Vector2(c2.x, c2.y - 15), Vector2(c2.x + 10, c2.y - 2), Vector2(c2.x + 5, c2.y + 14), Vector2(c2.x - 5, c2.y + 14), Vector2(c2.x - 10, c2.y - 2)])
		Spr.poly(pts, Color(.35 + e * .5, .5 + e * .45, .8 + e * .2))
		Spr.ci.draw_polyline(pts + PackedVector2Array([pts[0]]), Color(.15, .2, .35), 2, true)
		Spr.seg(c2.x - 3, c2.y - 9, c2.x - 6, c2.y + 4, Color(1, 1, 1, .6), 2)

static func _crack(s: Dictionary, T: int) -> void:
	var ink := Color(.12, .1, .09)
	if s.get("kind") == "slam":
		# chão de terra rachado (a mesma textura do chão), com fendas fundas e um brilho dourado
		var t: Texture2D = Spr.tex.chao
		Spr.ci.draw_texture_rect_region(t, Rect2(s.x - 2, s.y - 28, s.w + 4, 58), Rect2(10, 0, s.w + 4, 58), Color(.92, .88, .82))
		var cxs: float = s.x + s.w / 2
		Spr.ci.draw_polyline(PackedVector2Array([Vector2(s.x + 4, s.y + 6), Vector2(cxs - 8, s.y + 12), Vector2(cxs, s.y + 4), Vector2(cxs + 9, s.y + 15), Vector2(s.x + s.w - 4, s.y + 8)]), ink, 2.6, true)
		Spr.ci.draw_polyline(PackedVector2Array([Vector2(cxs, s.y + 4), Vector2(cxs + 2, s.y + 20)]), ink, 2, true)
		Spr.ci.draw_polyline(PackedVector2Array([Vector2(cxs - 8, s.y + 12), Vector2(cxs - 14, s.y + 22)]), ink, 1.6, true)
		return
	if s.get("kind") == "slab":
		Spr.PR("slab2", s.x - 4, s.y - 3, s.w + 8, s.h + 6, Color(.92, .9, .86))
		Spr.ci.draw_polyline(PackedVector2Array([Vector2(s.x + 8, s.y + 4), Vector2(s.x + 22, s.y + 12), Vector2(s.x + 30, s.y + 6), Vector2(s.x + 44, s.y + 16), Vector2(s.x + 54, s.y + 9)]), ink, 2, true)
		return
	# rocha pintada rachada, assentada no chão com musgo na base
	Spr.ellipse(s.x + s.w / 2, s.y + s.h + 2, s.w * .6, 6, Color(0, 0, 0, .28))
	Spr.PR("rock1", s.x - 8, s.y - 6, s.w + 16, s.h + 10)

static func _log(x: float, y: float) -> void:
	Spr.ellipse(x + 65, y + 32, 60, 5, Color(0, 0, 0, .25))
	Spr.PR("log", x - 4, y - 4, 138, 36, Color.WHITE, true)

# ---------------------------------------------------------------- Javali-Rei
static func boss(g: Game, T: int) -> void:
	var b: Dictionary = g.X.BOSS
	if not b.is_empty() and b.get("skin", "") == "fiscal":
		FiscalBoss.draw(g, b, T)
		return
	if not b.is_empty() and b.get("skin", "") == "dog" and b.has("stake"):
		# Brutus na corrente: estaca, argolas e corrente sempre à vista; o cão de guarda também
		# (antes da luta, parado; depois, deitado do lado da estaca)
		WorldEp2.yard(g, b, T)
		if not b.done or b.get("sulk", false):
			_brutus(b, T, Spr.edist(b))
		return
	if b.is_empty() or b.done or b.st == "wait":
		return
	var fr := 0
	var shake_x := 0.0
	var bd: float = Spr.edist(b)
	match b.st:
		"idle":
			fr = 4
		"paw", "intro":
			fr = 4
		"charge", "flee":
			fr = 5 if int(bd / 16.0) % 2 == 0 else 3
		"stun", "down":
			fr = 6
		"trot":
			fr = int(bd / 16.0) % 4
		_:
			fr = 0
	if b.get("skin", "boar") == "dog":
		_brutus(b, T, bd)
		if Spr.turned_now(b) and b.st != "down":
			turn_dust(g, b.x, 502, b.dir)
		return
	var sc := 1.12
	# corpo vivo: cada estado tem peso (antecipação, esticar, achatar, quicar)
	var sx := 1.0
	var sy := 1.0
	var rot := 0.0
	var dy := 0.0
	var ox := 0.0
	var cyc := -1.0          # posição contínua no ciclo de passos quando anda/corre
	var seq := [0, 1, 2, 3]
	var t: int = int(b.get("t", 0))
	match b.st:
		"intro":
			if b.y < 499.0:
				sx = .95
				sy = 1.07
		"idle":
			var br: float = sin(T * .08)
			sx = 1.0 - br * .008
			sy = 1.0 + br * .016
		"paw":
			# abaixa a cabeça e joga o peso para trás, raspando a pata no ritmo da poeira
			var k: float = clamp(t / 44.0, 0, 1)
			var u: float = (t % 9) / 9.0
			sx = 1.0 + .05 * k
			sy = 1.0 - .08 * k
			rot = b.dir * .05 * k
			ox = -b.dir * (6.0 * k + 3.0 * sin(u * PI))
		"charge":
			var sp: float = clamp(float(b.get("spd", 0.0)) / 8.0, 0, 1)
			# galope: alterna a investida (5) e as patas recolhidas (3), com transição
			cyc = bd / 24.0
			seq = [5, 3]
			sx = 1.0 + .07 * sp
			sy = 1.0 - .05 * sp
			rot = b.dir * (.03 + .05 * sp)
			dy = -abs(sin(bd * PI / 40.0)) * 5.0
		"trot":
			cyc = bd / 16.0
			rot = -b.dir * .02 * (1.0 - clamp(float(b.get("tv", 0.0)) / 3.0, 0, 1))
			dy = -abs(sin(bd * PI / 32.0)) * 2.5
		"stun":
			rot = sin(T * .2) * .05
			sy = 1.0 + sin(T * .2 + 1) * .02
		"down":
			# pula de dor, cai, quica e fica deitado (já é o quadro deitado)
			if t < 24:
				dy = -sin(t / 24.0 * PI) * 26.0
				sy = 1.05
				sx = .96
			elif t < 36:
				dy = -sin((t - 24) / 12.0 * PI) * 7.0
	var ht: int = int(b.get("hitT", 0))
	if ht > 0:
		# batida: achata contra a árvore e volta
		var u2: float = ht / 18.0
		sx *= 1.0 - .22 * u2
		sy *= 1.0 + .12 * u2
	var lt: int = int(b.get("landT", 0))
	if lt > 0:
		var u3: float = lt / 14.0
		sx *= 1.0 + .18 * u3
		sy *= 1.0 - .22 * u3
	# sombra: encolhe e clareia com a altura
	var lift: float = (500.0 - b.y) - dy
	var shk: float = clamp(1.0 - lift / 320.0, .3, 1.0)
	Spr.ellipse(b.x + ox, 502, 90 * shk * sx, 12 * shk, Color(0, 0, 0, .3 * shk))
	Spr.save()
	Spr.translate(b.x + shake_x + ox, b.y + dy)
	Spr.rotate(rot)
	Spr.scale(Spr.eturn(b) * sx, sy * Spr.tsy(b))
	if Spr.turned_now(b):
		turn_dust(g, b.x, 502, b.dir)
	var tint := Color(1, .45, .4, 1) if b.red > 0 and (T / 3) % 2 == 0 else Color(1, 1, 1, 1)
	tint = tint * Polish.fury(int(b.hp))   # última vida: pulsa avermelhado
	if b.st == "down":
		tint.a = clamp(1.0 - (b.t - 90) / 60.0, 0.0, 1.0)
	var dst := Rect2(-105 * sc, -136 * sc + 4, 210 * sc, 140 * sc)
	# ponto do alto da cabeça (entre as orelhas) no quadro desenhado, em pixels da folha (olhando para a
	# direita): é onde a coroa assenta. Deitado (6) a cabeça fica bem mais baixa; na investida, mais à frente
	var head := Vector2(134, 29)
	var bct: Texture2D = Spr.opt("boss_charge") if b.st == "charge" and t < 30 else null
	var ka: float = 1.0 - smoothstep(20.0, 30.0, float(t)) if bct else 0.0
	if ka >= 1.0:
		pass
	elif cyc >= 0.0:
		Spr.region_mix(Spr.tex.javali, dst, 210, 140, seq, cyc, tint)
		if b.st == "charge":
			# galope 5 <-> 3: a cabeça vai e volta junto com a troca dos quadros
			var cu: float = .5 - .5 * cos(fposmod(cyc, 2.0) * PI)
			head = Vector2(142, 30).lerp(Vector2(135, 29), cu)
	else:
		Spr.ci.draw_texture_rect_region(Spr.tex.javali, dst, Rect2(fr * 210, 0, 210, 140), tint)
		if fr == 6:
			head = Vector2(139, 55)
		elif fr == 5:
			head = Vector2(142, 30)
	if bct:
		# arranque da investida: pose própria, bem esticada; nos últimos quadros se desfaz no galope
		# (sem estalo de uma pose para a outra)
		Spr.ci.draw_texture_rect(bct, dst, false, Color(tint.r, tint.g, tint.b, tint.a * ka))
		head = head.lerp(Vector2(157, 35), ka)
	# coroa de folhas do rei do bosque (cada rei tem a sua; ela cai na derrota e vira colecionável)
	var cx: float = (head.x - 105.0) * sc
	var cy: float = -136.0 * sc + 4 + head.y * sc
	# a coroa balança a cada golpe recebido (e some na derrota: ela cai e rola pelo chão)
	if b.st != "down":
		var wob: float = sin(float(b.red) * .7) * .4 * float(b.red) / 30.0
		pass   # (sem coroa: o chefe é o Motoboy Turbo)
	Spr.restore()
	if b.st == "stun":
		for i in 4:
			var a2 := T * .12 + TAU * i / 4.0
			Spr.text("★", b.x + cos(a2) * 34, b.y - 136 + sin(a2) * 10, 16, Color("#ffe27a"), HORIZONTAL_ALIGNMENT_CENTER, Spr.font_b, 3)
	if b.st == "paw" and (T / 8) % 2 == 0:
		Spr.text("!", b.x + b.dir * 30, b.y - 150, 32, Color("#ff6a4a"), HORIZONTAL_ALIGNMENT_CENTER, Spr.font_b, 5)

## Brutus, o cão de guarda do Vargas (arte do Gemini: cao.png bem grande, com coleira de pregos)
static func _brutus(b: Dictionary, T: int, bd: float = 0.0) -> void:
	var fr := 4
	match b.st:
		"idle":
			fr = 4 if (T / 40) % 3 != 2 else 5
		"paw":
			fr = 5
		"charge":
			fr = int(bd / 14.0) % 4
		"trot":
			fr = int(bd / 15.0) % 4
		"stun":
			fr = 6
		"down":
			fr = 6
		"intro":
			fr = 7
		"taut":
			# esticado no fim da corrente, latindo
			fr = 5 if b.get("barkT", 0) > 0 else 4
	var tint := Color(1, .45, .4, 1) if b.red > 0 and (T / 3) % 2 == 0 else Color(1, 1, 1, 1)
	tint = tint * Polish.fury(int(b.hp))   # última vida: pulsa avermelhado
	var a: float = 1.0
	var dx: float = 0.0
	if b.st == "down" and not b.get("sulk", false):
		# foge correndo para fora do quintal
		dx = b.dir * -min(float(b.t) * 6.0, 900.0)
		fr = [0, 1, 2, 3][(T / 3) % 4]
		a = clamp(1.0 - (b.t - 90) / 60.0, 0.0, 1.0)
	var flip: bool = b.dir < 0 if b.st != "down" else b.dir > 0
	Spr.ellipse(b.x + dx, 502, 92, 12, Color(0, 0, 0, .3 * a))
	var gb: float = -abs(sin(bd * PI / 28.0)) * (4.0 if b.st == "charge" else 2.5) if b.st in ["charge", "trot"] else 0.0
	# vira girando (estreita e abre) em vez de espelhar num quadro
	var fs: float = Spr.eturn(b, .14)
	var tw: float = abs(fs) if b.st != "down" else 1.0
	if b.st != "down":
		flip = fs < 0
	# batida no muro: achata e volta; raspando a pata: abaixa e joga o peso para trás
	var bsx := 1.0
	var bsy := 1.0
	var bht: int = int(b.get("hitT", 0))
	if bht > 0:
		bsx = 1.0 - .2 * bht / 18.0
		bsy = 1.0 + .1 * bht / 18.0
	var box := 0.0
	if b.st == "paw":
		var pk: float = clamp(b.t / 44.0, 0, 1)
		bsy = 1.0 - .07 * pk
		bsx = 1.0 + .04 * pk
		box = -b.dir * 6.0 * pk
	elif b.st == "idle":
		bsy = 1.0 + sin(T * .09) * .015
	elif b.st == "taut":
		# puxando a corrente: o corpo inclina para a frente e treme
		box = b.dir * 4.0 + sin(T * .9) * 1.5
		bsx = 1.04
		bsy = .96
	elif b.st == "stun":
		Spr.save()
		Spr.translate(b.x, b.y)
		Spr.rotate(sin(T * .2) * .04)
		Spr.translate(-b.x, -b.y)
	Spr.save()
	Spr.translate(b.x + dx + box, b.y + 4 + gb)
	Spr.scale(tw * bsx, bsy * Spr.tsy(b))
	if b.st in ["charge", "trot"]:
		Spr.sheet_cycle("cao", bd / (14.0 if b.st == "charge" else 15.0), 4, 0, 200, 150, 0, 0, 210.0, flip, Color(tint.r, tint.g, tint.b, a))
	elif b.st == "down" and not b.get("sulk", false):
		Spr.sheet_cycle("cao", T / 3.0, 4, 0, 200, 150, 0, 0, 210.0, flip, Color(tint.r, tint.g, tint.b, a))
	else:
		Spr.sheet("cao", fr, 200, 150, 0, 0, 210.0, flip, Color(tint.r, tint.g, tint.b, a))
	Spr.restore()
	if b.st == "stun":
		Spr.restore()
	if b.st == "stun":
		for i in 4:
			var a2 := T * .12 + TAU * i / 4.0
			Spr.text("★", b.x + cos(a2) * 40, b.y - 150 + sin(a2) * 10, 18, Color("#ffe27a"), HORIZONTAL_ALIGNMENT_CENTER, Spr.font_b, 3)
	if b.st == "paw" and (T / 8) % 2 == 0:
		Spr.text("AU!", b.x + b.dir * 60, b.y - 160, 26, Color("#ff6a4a"), HORIZONTAL_ALIGNMENT_CENTER, Spr.font_b, 5)

# ---------------------------------------------------------------- inimigos novos (desenhados por código)
## poeirinha nos pés no instante da virada (o peso trocando de lado)
static func turn_dust(g, x: float, y: float, d: float, col: Color = Color(.62, .55, .42, .5)) -> void:
	if not Polish.FRESH:
		return
	for k in 4:
		g.PARTS.append({"x": x + (k - 1.5) * 6, "y": y - 2, "vx": -d * randf_range(.6, 1.8), "vy": -randf_range(.4, 1.3), "life": 16, "col": col})

static func _pc(n: String, cx: float, cy: float, w: float) -> void:
	## peça pintada centrada em (cx, cy)
	var hgt: float = Spr.PH(n, w)
	Spr.PR(n, cx - w / 2, cy - hgt / 2, w, hgt)

static func bat(e: Dictionary, T: int) -> void:
	if e.dead:
		_pc("bat2", 0, 0, 40)
		return
	if e.get("st", 0) == 0:
		# pendurado de cabeça para baixo, dormindo (as garras encostam no teto: antes ficava
		# 8-10 px abaixo dele, pendurado no nada)
		_pc("bat_hang", 0, 10, 24)
		return
	Spr.P_cycle("bat", ["bat0", "bat1", "bat2", "bat1"], T / 4.0, 0, 0, 50, false, Color.WHITE, true)

static func spider(e: Dictionary, T: int) -> void:
	var st: int = e.get("st", 0)
	if not e.dead and Spr.sil_c.a == 0:
		# fio de teia (fica fora do contorno vermelho: lá ele saía 8 vezes e virava uma corda grossa): curva com o vento e com o balanço da descida; brilha perto da lanterna
		var gg: Game = Polish.g
		var wnd: float = gg.AMB.get("wind", 0.0) if gg else 0.0
		var top: float = e.top - e.y
		var amp: float = 2.0 + wnd * 7.0 + (5.0 if st in [1, 3] else 0.0)
		var lit := 0.0
		if gg and gg.lantern_lit:
			var pp: Dictionary = gg.player
			lit = clamp(1.0 - Vector2(pp.x - e.x, pp.y - e.y).length() / 260.0, 0, 1) * clamp(gg.AMB.dark * 1.6, .3, 1)
		var pts := PackedVector2Array()
		for i in 9:
			var u: float = i / 8.0
			pts.push_back(Vector2(sin(T * .05 + e.x * .01) * amp * u * (1.0 - u) * 4.0 * .5, lerpf(top, -8, u)))
		Spr.ci.draw_polyline(pts, Spr.col(Color(.92, .92, .92, .55 + .4 * lit)), 1.2 + lit * .6, true)
		if lit > .1:
			var gi: int = int(T / 3) % 9
			Spr.glow(pts[gi].x, pts[gi].y, 6, Color(1, .95, .8, .6 * lit))
	if st in [0, 1, 3] and not e.dead:
		# esperando no teto, descendo ou subindo pelo fio: pendurada, balançando de leve
		Spr.save()
		Spr.rotate(sin(T * .08 + e.x) * .12)
		_pc("spider_hang", 0, 10, 30)
		Spr.restore()
	else:
		# embaixo, na ponta do fio: parada e ameaçando (antes as pernas andavam no lugar sem sair dali).
		# Ao chegar as pernas se abrem (quadro 1) e depois ela fica no quadro firme, respirando
		var sf: float = 1.0 if (not e.dead and int(e.get("t", 0)) < 8) else 0.0
		Spr.save()
		if not e.dead:
			Spr.scale(1.0 + sin(T * .12 + e.x) * .015, 1.0 - sin(T * .12 + e.x) * .025)
		Spr.P_cycle("spider", ["spider0", "spider1", "spider2"], sf, 0, 6, 42, false, Color.WHITE, true)
		Spr.restore()

static func mole(e: Dictionary, T: int) -> void:
	var st: int = e.get("st", 0)
	var dirt := Color("#6b4a2a")
	var fur := Color("#6e6070")
	var helm: bool = e.get("helm", false) and not e.get("helm_off", false)
	var nn := "toupeira_capacete" if helm else "toupeira"
	if not e.dead and Spr.novos.has(nn):
		var f := 0
		match st:
			1: f = 1 + (T / 6) % 2
			2: f = 4 if (e.t > 8 and e.t < 20) else 3
			3: f = 2
			5: f = 5
		Spr.novo(nn, f, 56 if st in [2, 5] else 40, e.dir < 0)
		if st == 5:
			for k in 3:
				var a := T * .15 + TAU * k / 3.0
				Spr.text("★", cos(a) * 18, -36 + sin(a) * 5, 11, Color("#ffe27a"), HORIZONTAL_ALIGNMENT_CENTER, Spr.font_b, 2)
		return
	if e.dead:
		Spr.ellipse(0, -8, 16, 9, fur)
		return
	if st == 0 or st == 6:
		var sh: float = sin(T * 1.4) * 2.0 if st == 6 else 0.0
		Spr.ellipse(sh, 0, 22, 9, dirt)
		Spr.ellipse(-4 + sh, -3, 10, 4, Color("#8a6a42"))
		if helm:
			Spr.ci.draw_arc(Vector2(sh + 4, -6), 6, PI, TAU, 10, Color("#e8b030"), 3, true)
		if T % 10 < 5:
			Spr.circle(10, -4, 2, Color("#4a3220"))
		return
	if st == 5:
		# de barriga para cima, tonta
		Spr.ellipse(0, 2, 24, 6, dirt)
		Spr.ellipse(0, -10, 17, 11, fur)
		Spr.ellipse(0, -12, 10, 7, Color("#9a8ca0"))
		for k in 4:
			var lx := -10.0 + k * 7
			Spr.seg(lx, -18, lx + sin(T * .4 + k) * 2, -24, Color("#f2a0b0"), 2)
		Spr.circle(16, -8, 4, Color("#f2a0b0"))
		for k in 3:
			var a := T * .15 + TAU * k / 3.0
			Spr.text("★", cos(a) * 18, -30 + sin(a) * 5, 11, Color("#ffe27a"), HORIZONTAL_ALIGNMENT_CENTER, Spr.font_b, 2)
		return
	var up: float = 1.0
	if st == 1:
		up = .25 + sin(T * 1.2) * .08
	elif st == 3:
		up = clamp(1.0 - e.t / 14.0, 0, 1)
	var yy: float = -30 * up
	Spr.ellipse(0, 2, 24, 8, dirt)
	if up > .1:
		Spr.ellipse(0, yy + 14, 15, 15 * up, fur)
		Spr.ellipse(0, yy + 18, 9, 9 * up, Color("#8e8090"))
		Spr.circle(10, yy + 9, 4, Color("#f2a0b0"))
		Spr.circle(-1, yy + 5, 1.8, Color.BLACK)
		Spr.circle(5, yy + 5, 1.8, Color.BLACK)
		var arm: float = -8.0 if (st == 2 and e.t > 8 and e.t < 18) else 0.0
		for k in 3:
			Spr.seg(-14 + k * 3, yy + 22 + arm, -16 + k * 3, yy + 27 + arm, Color("#f2a0b0"), 2)
			Spr.seg(10 + k * 3, yy + 22 + arm, 12 + k * 3, yy + 27 + arm, Color("#f2a0b0"), 2)
		if helm:
			Spr.ci.draw_arc(Vector2(2, yy + 4), 11, PI, TAU, 16, Color("#e8b030"), 5, true)
			Spr.circle(2, yy - 6, 3, Color("#fff4b0"))
		if st == 2 and e.t < 16:
			Spr.circle(e.dir * 14, yy + 2, 6, Color("#7a5a3a"))
	Spr.ellipse(0, 4, 26, 5, dirt)

# ---------------------------------------------------------------- Pipoca e as tocas
static func tocas(g: Game, T: int) -> void:
	var p: Dictionary = g.player
	for tc in g.X.TOCAS:
		if tc.x < g.cam - 100 or tc.x > g.cam + g.W + 100:
			continue
		Spr.ellipse(tc.x, tc.y - 10, 34, 18, Color("#6a5e52"))
		Spr.ellipse(tc.x - 10, tc.y - 18, 16, 9, Color("#857868"))
		Spr.ellipse(tc.x + 2, tc.y - 4, 14, 10, Color("#120c08"))
		for k in 3:
			Spr.circle(tc.x - 26 + k * 24, tc.y - 2, 5, Color("#4a3f36"))
		var near: bool = abs(p.x + p.w / 2 - tc.x) < 80 and abs(p.y + p.h - tc.y) < 50
		if not tc.done and near:
			var lbl := "✦ VAI, BAG!" if g.X.dog_free() else "?"
			Spr.text(lbl, tc.x, tc.y - 46 + sin(T * .15) * 3, 15, Color("#ffecaa"), HORIZONTAL_ALIGNMENT_CENTER, Spr.font_b, 4)

static func dog(g: Game, T: int) -> void:
	var d: Dictionary = g.X.DOG
	if d.is_empty() or d.st == "in_toca":
		return
	var x: float = d.x
	var y: float = d.y + d.hy
	# o jogador está controlando o Pipoca: desenha "entre" dois passos (sem tremer em telas rápidas)
	# e guarda se ele está no ar (pose de salto) ou acabou de pousar (achata um pouquinho)
	var cb: Dictionary = g.player if (d.st in ["ctrl", "dig"] and g.M and g.M.ctrl and g.player.get("dog", false)) else {}
	var dog_air := false
	if not cb.is_empty():
		# (o deslocamento "entre passos" já vem do world_dyn: Spr.translate(g.ip_off()) em volta desta função)
		dog_air = not cb.onGround and not cb.swim
		if Polish.FRESH:
			if d.get("_air", false) and not dog_air:
				d._land = clamp(float(cb.get("landV", 6.0)) / 12.0, .25, .6)
			d._land = float(d.get("_land", 0.0)) * .8
			# (lido e gravado só no passo da lógica: um desenho extra não "engole" o pouso)
			d._air = dog_air
	if d.st == "tied":
		# estaca e corda
		Spr.rect(d.x0 - 64, d.y - 34, 6, 36, Color("#5a3e24"))
		Spr.ci.draw_polyline(PackedVector2Array([Vector2(d.x0 - 61, d.y - 24), Vector2((d.x0 - 61 + x) / 2, d.y - 12), Vector2(x - d.face * 6, d.y - 30)]), Color("#c9a26a"), 2.5, true)
	var sh_k: float = clamp(1.0 - abs(float(cb.vy)) / 16.0, .35, 1.0) if dog_air else 1.0
	Polish.shadow(x, y + 1 - d.hy, 20 * sh_k, 4 * sh_k, .25 * sh_k)
	var fr := "dog0"
	if d.moving:
		fr = "dog%d" % (int(d.anim) % 4)
	var sc := .4
	var bob: float = 0.0 if d.moving else sin(T * .1) * .015
	if d.st == "sit":
		bob = -.06
	Spr.save()
	Spr.translate(x, y)
	var nf := 6 + (T / 20) % 2
	if d.moving:
		nf = int(d.anim) % 6
	if d.bark > 0:
		nf = 8 + (T / 6) % 2
	if d.st == "dig":
		nf = 10 + (T / 6) % 2
	if d.carry:
		nf = 12
	if d.st == "tied" and not d.moving:
		nf = 13
	# corpo vivo: inclina para a frente na corrida (suave), respira parado, vira girando
	# (só no 1º desenho depois de cada passo: a 90/120 Hz a inclinação não muda de ritmo nem treme)
	if Polish.FRESH or not d.has("_lean"):
		var dvx: float = d.x - float(d.get("_lx", d.x))
		d._lx = d.x
		d._lean = lerp(float(d.get("_lean", 0.0)), clamp(dvx / 5.0, -1, 1) * .07, .15)
	var ns: float = Spr.turn_face(d, float(d.face))
	if Spr.turned_now(d) and d.moving:
		turn_dust(g, x, d.y, d.face)
	var breath: float = 0.0 if d.moving else sin(T * .09) * .018
	var gal: float = abs(sin(d.anim * PI / 3.0)) * 1.4 if d.moving else 0.0
	Spr.save()
	Spr.translate(0, -gal)
	Spr.rotate(float(d.get("_lean", 0.0)))
	Spr.scale(abs(ns), (1.0 + breath) * Spr.tsy(d))
	var drew: bool = Spr.novo("pipoca", nf, 54, ns < 0)
	Spr.restore()
	# poses pintadas extras: cavando, farejando, comemorando
	var ov: Texture2D = null
	if not drew and not dog_air:
		if d.st == "dig":
			ov = Spr.opt("dog_dig")
		elif d.get("joyT", 0) > 0:
			ov = Spr.opt("dog_joy")
		elif d.st == "sit" and (int(d.t) + 140) % 520 < 80:
			ov = Spr.opt("dog_sniff")
	if ov != null:
		var hop: float = -abs(sin(T * .35)) * 10.0 if d.get("joyT", 0) > 0 else 0.0
		Spr.translate(0, hop)
		Spr.scale(sc if d.face > 0 else -sc, sc * (1.0 + bob))
		var ow: float = ov.get_width()
		var oh: float = ov.get_height()
		Spr.trect(ov, Rect2(-ow * .55, -oh + 2, ow, oh))
	elif not drew:
		if d.st == "dig":
			Spr.rotate(d.face * .25)
		# parado: de vez em quando fareja o chão ou coça a orelha
		var wag_k := .14
		if d.st == "sit":
			var ct: int = (int(d.t) + 140) % 520
			wag_k = .32
			if ct < 80:
				var u: float = sin(clamp(ct / 80.0, 0, 1) * PI)
				Spr.rotate(d.face * .16 * u)
				if Polish.FRESH and ct % 12 == 0 and ct > 10 and ct < 70:
					g.PARTS.append({"x": x + d.face * 34, "y": y - 8, "vx": d.face * .4, "vy": -.3, "life": 14, "col": Color(.85, .8, .7, .7)})
			elif ct > 300 and ct < 360:
				Spr.rotate(-d.face * .08)
				Spr.translate(0, -abs(sin(T * .9)) * 2.0)
				wag_k = .05
		var ld: float = float(d.get("_land", 0.0)) if not cb.is_empty() else 0.0
		if dog_air:
			# no ar: corpo esticado do galope, nariz para cima subindo e para baixo caindo
			Spr.rotate(d.face * clamp(float(cb.vy) / 12.0, -1, 1) * .3)
		Spr.scale((sc if d.face > 0 else -sc) * (1.0 + ld * .25), sc * (1.0 + bob) * (1.0 - ld * .3))
		if dog_air:
			_dog_frame("dog2" if cb.vy < 3.0 else "dog3", -.3 if cb.vy < 0 else .15)
		elif d.moving and not Spr.x4("A:dog").is_empty():
			# correndo: quadros intermediários (x4) com o rabo junto do corpo
			Spr.A_cycle("dog", ["dog0", "dog1", "dog2", "dog3"], d.anim, 0, 0, 1.0)
		else:
			_dog_frame(fr, sin(T * (.45 if d.st == "sit" else .3)) * wag_k)
	Spr.restore()
	if d.carry:
		Spr.save()
		Spr.translate(x + d.face * 26, y - 30)
		Spr.rotate(.3 * d.face)
		Spr.A("drawing", 0, 0, .35)
		Spr.restore()
	_dog_guide(g, d, x, y, T)
	if d.bark > 0:
		var k: float = d.bark / 30.0
		Spr.text("AU!", x + d.face * 28, y - 58 - (1.0 - k) * 8, 16, Color(1, 1, 1, k), HORIZONTAL_ALIGNMENT_CENTER, Spr.font_b, 4)
	if d.st == "tied":
		var p: Dictionary = g.player
		if abs(p.x + p.w / 2 - d.x) < 70 and abs(p.y + p.h - d.y) < 50:
			Spr.text("✦ SOLTAR", x, y - 70 + sin(T * .15) * 3, 16, Color("#ffecaa"), HORIZONTAL_ALIGNMENT_CENTER, Spr.font_b, 4)

## o Pipoca guia: quando fareja algo escondido por perto (desenho da Isis, segredo, lápis dourado),
## para, aponta o focinho, mostra um "!" e late uma vez só
static var _barked := {}
static func _dog_guide(g: Game, d: Dictionary, x: float, y: float, T: int) -> void:
	if not d.st in ["follow", "sit"]:
		return
	var best = null
	var bd := 330.0
	var bkey := ""
	for dr in g.DRWS:
		if not dr.get("got", false):
			var dd: float = Vector2(dr.x - x, (dr.y - y) * .6).length()
			if dd < bd:
				bd = dd
				best = Vector2(dr.x, dr.y)
				bkey = "d%d_%d" % [int(dr.x), int(dr.y)]
	for sc in g.L.get("secrets", []):
		if g.X.found.has(sc.id):
			continue
		var cx: float = sc.x + sc.w / 2.0
		var dd2: float = abs(cx - x)
		if dd2 < bd and abs(sc.y - y) < 500:
			bd = dd2
			best = Vector2(cx, sc.y)
			bkey = "s" + str(sc.id)
	if not g.X.GOLD.is_empty() and not g.X.GOLD.got:
		var dd3: float = Vector2(g.X.GOLD.x - x, g.X.GOLD.y - y).length()
		if dd3 < bd:
			best = Vector2(g.X.GOLD.x, g.X.GOLD.y)
			bkey = "gold"
	if best == null:
		return
	if not _barked.has(bkey):
		_barked[bkey] = true
		Audio.play("bark", -10)
		d.bark = 30
	# focinho apontando e um "!" piscando sobre a cabeça
	var bv: Vector2 = best
	var dir: Vector2 = (bv - Vector2(x, y - 20)).normalized()
	var a: float = .6 + .4 * sin(T * .2)
	for k in 3:
		var q: Vector2 = Vector2(x, y - 22) + dir * (30 + k * 14 + fmod(T * .8, 14.0))
		Spr.circle(q.x, q.y, 2.6 - k * .6, Color(1, .95, .7, a * (1.0 - k * .28)))
	Spr.text("!", x, y - 70 + sin(T * .2) * 3, 24, Color(1, .9, .4, a), HORIZONTAL_ALIGNMENT_CENTER, Spr.font_b, 4, Color(.3, .15, 0, .9))

## o Pipoca desenhado em dois pedaços: o corpo e o rabo (que abana girando na base)
static func _dog_frame(fr: String, wag: float) -> void:
	var r = Spr.AR.get(fr)
	if r == null:
		return
	var t: Texture2D = Spr.atlas_tex(r)
	var c := Color(1, 1, 1, Spr.alpha)
	var ax: float = r[4]
	var ay: float = r[5]
	const TX := 25.0     # o rabo fica à esquerda desta coluna...
	const TY := 74.0     # ...e acima desta linha (no quadro virado para a direita)
	# corpo: tudo à direita do rabo + a parte de baixo da coluna do rabo (a pata de trás)
	Spr.ci.draw_texture_rect_region(t, Rect2(-ax + TX, -ay, r[2] - TX, r[3]), Rect2(r[0] + TX, r[1], r[2] - TX, r[3]), c)
	Spr.ci.draw_texture_rect_region(t, Rect2(-ax, -ay + TY, TX, r[3] - TY), Rect2(r[0], r[1] + TY, TX, r[3] - TY), c)
	# rabo girando em volta da base (onde encosta no corpo)
	var piv := Vector2(-ax + TX, -ay + TY - 8)
	Spr.save()
	Spr.translate(piv.x, piv.y)
	Spr.rotate(wag)
	Spr.ci.draw_texture_rect_region(t, Rect2(-TX, -(TY - 8), TX + 1, TY), Rect2(r[0], r[1], TX + 1, TY), c)
	Spr.restore()

# ---------------------------------------------------------------- golpe, defesa e parede
static func tool_fx(g: Game, T: int) -> void:
	var p: Dictionary = g.player
	var cx: float = p.x + p.w / 2
	var f: float = p.face
	if p.get("act", "") == "swing" and p.actT > 0:
		# arco do golpe da picareta
		var k: float = 1.0 - (p.actT - 0.0) / 22.0
		if p.actT <= 17 and p.actT >= 6:
			var a0: float = -1.9
			var a1: float = lerpf(-1.6, 1.1, clamp((17 - p.actT) / 9.0, 0, 1))
			var pts := PackedVector2Array()
			var steps := 10
			for i in steps + 1:
				var a: float = lerpf(a0, a1, i / float(steps))
				pts.push_back(Vector2(cx + f * cos(a) * 42, p.y + 14 + sin(a) * 34))
			Spr.ci.draw_polyline(pts, Color(1, .95, .8, .55 * (1.0 - k * .6)), 7, true)
			Spr.ci.draw_polyline(pts, Color(1, 1, 1, .9 * (1.0 - k * .5)), 2.5, true)
			var tip: Vector2 = pts[pts.size() - 1]
			if Rig.ready("tome"):
				return
			Spr.save()
			Spr.translate(tip.x, tip.y)
			Spr.rotate(a1 * f + (0.0 if f > 0 else PI))
			Spr.A("it_picareta", 0, 0, .3, f < 0)
			Spr.restore()
	if p.get("guard", false):
		var lx: float = cx + f * 18
		var ly: float = p.y + 12
		Spr.glow(lx, ly, 46 + sin(T * .4) * 3, Color(1, .9, .55, .45))
		Spr.ci.draw_arc(Vector2(lx, ly), 28, -1.1 if f > 0 else PI - 1.1, 1.1 if f > 0 else PI + 1.1, 18, Color(1, .95, .7, .75), 3, true)
	if p.get("wslide", false):
		Spr.rect(cx + f * (p.w / 2) - 1, p.y + 4, 3, p.h - 6, Color(1, 1, 1, .12))

# ---------------------------------------------------------------- placas, portões, caixas e tábuas que caem
static func mech(g: Game, T: int) -> void:
	var M: Mech = g.M
	if M == null:
		return
	var c0: float = g.cam - 150
	var c1: float = g.cam + g.W + 150
	for pl in M.PLATES:
		if pl.x + pl.w < c0 or pl.x > c1:
			continue
		var dd: float = pl.d * 4
		# placa de pedra entalhada, afundando quando tem peso; a moldura de pedra fica fixa
		Spr.rr(pl.x - 6, pl.y - 3, pl.w + 12, 11, 5, Color(.16, .13, .1))
		Spr.PR("plate", pl.x - 2, pl.y - 11 + dd, pl.w + 4, 15, Color(1, 1, 1) if not pl.on else Color(1.25, 1.1, .7))
		if pl.on:
			Spr.glow(pl.x + pl.w / 2, pl.y - 4, 30, Color(1, .85, .4, .35))
	for gt in M.GATES:
		if gt.x + gt.w < c0 or gt.x > c1:
			continue
		if not gt.get("crank") and float(gt.h) > 200.0:
			_palisade_gate(g, gt)
			continue
		var lift: float = gt.open * (gt.h - 18)
		var y0: float = gt.y - lift
		var hh: float = gt.h
		# batentes de madeira dos lados e o portão de tábuas com ferragens subindo entre eles
		# (portões altos: vão até bem acima da tela, em gomos do tamanho normal, sem esticar a pintura)
		# portões baixos (porta de manivela): um gomo só, do tamanho do vão
		var seg: float = min(260.0, hh)
		var nseg: int = int(ceil(hh / seg))
		var bot: float = gt.y + gt.h
		for k in nseg:
			var sy: float = bot - (k + 1) * seg
			if sy + seg < g.cam_y - 100 or sy > g.cam_y + g.H + 100:
				continue
			Spr.PR("stake", gt.x - 13, sy - 14, 12, seg + 22, Color(.8, .76, .72))
			Spr.PR("stake", gt.x + gt.w + 1, sy - 14, 12, seg + 22, Color(.8, .76, .72), true)
		for k in nseg:
			var py: float = y0 + hh - (k + 1) * seg
			if py + seg < g.cam_y - 100 or py > g.cam_y + g.H + 100:
				continue
			Spr.PR("gate_wood", gt.x - 6, py - 4, gt.w + 12, seg + 4)
		if gt.get("dogpass"):
			# portinhola para o cachorro, embaixo
			var fy: float = gt.y + gt.h - 24
			if gt.open < .3:
				Spr.rr(gt.x - 3, fy, gt.w + 6, 24, 4, Color("#3a2414"))
				Spr.rr(gt.x - 1, fy + 3, gt.w + 2, 19, 3, Color("#a8804a"))
				var px: float = gt.x + gt.w / 2
				Spr.circle(px, fy + 15, 3.2, Color(.3, .2, .1))
				for k in 3:
					Spr.circle(px - 4 + k * 4, fy + 9, 1.6, Color(.3, .2, .1))
	for c in M.PUSH:
		if c.dead or c.x + c.w < c0 or c.x > c1:
			continue
		if c.get("snow"):
			WorldNature.snowball(c, T)
			continue
		Spr.ellipse(c.x + c.w / 2, c.y + c.h + 1, c.w * .55, 4, Color(0, 0, 0, .25))
		Spr.PR("crate", c.x - 2, c.y - 2, c.w + 4, c.h + 4)
		if g.player.get("pushT", 0) > 0 and Game.hit(g.R(g.player.x - 6, g.player.y, g.player.w + 12, g.player.h), c):
			Spr.text("⇆", c.x + c.w / 2, c.y - 10, 16, Color("#ffecaa"), HORIZONTAL_ALIGNMENT_CENTER, Spr.font_b, 3)
	var a_crumb: float = Spr.alpha
	for s in M.CRUMB:
		if s.x + s.w < c0 or s.x > c1:
			continue
		# tábua/telha que voltou: aparece aos poucos em vez de surgir num estalo
		Spr.alpha = a_crumb * clamp(float(s.get("pop", 1.0)), 0.0, 1.0)
		var shake: float = (sin(T * 1.7) * 2.0) if (s.ct > 0 and not s.fallen) else 0.0
		var yy: float = s.y + s.fy
		if s.fallen and s.fy > 400:
			continue
		var a: float = 1.0 if not s.fallen else clamp(1.0 - s.fy / 400.0, 0, 1)
		var wood := Color(.42, .29, .17, a) if not s.get("icy") else Color(.72, .86, 1, a * .9)
		if s.get("trestle") and not s.fallen:
			for lx in [s.x + 8, s.x + s.w - 16]:
				Spr.rect(lx, s.y + 10, 8, WSt.leg_floor(s, lx + 4) - s.y - 6, Color("#4a3220"))
		if s.get("tile") and not s.get("roofhole"):
			# sarrafos finos esticados entre os telhados (as telhas ficam soltas em cima deles)
			Spr.seg(s.x - 4, s.y + 12, s.x + s.w + 4, s.y + 12, Color("#3a2414"), 3)
			Spr.seg(s.x - 4, s.y + 12, s.x + s.w + 4, s.y + 12, Color("#8a6a42"), 1.2)
		if s.fallen and s.get("roofhole"):
			# buraco no telhado: dá para ver os caibros e o escuro lá dentro
			Spr.rect(s.x, s.y - 4, s.w, 22, Color("#120a06"))
			for kx in [s.x + 6, s.x + s.w - 12]:
				Spr.rect(kx, s.y - 4, 6, 22, Color("#5a3a1e"))
		if s.fallen:
			# quebrou: três pedaços caindo e girando cada um para um lado
			for i in 3:
				var pw: float = s.w / 3.0
				var px0: float = s.x + i * pw + (i - 1) * s.fy * .18
				var py0: float = yy + s.fy * i * .12
				Spr.save()
				Spr.translate(px0 + pw / 2, py0 + 8)
				Spr.rotate((i - 1) * s.fy * .012 + (s.fy * .004 if i == 1 else 0.0))
				if s.get("tile"):
					Spr.rr(-pw / 2, -7, pw, 14, 4, Color(.7, .32, .18, a))
				else:
					Spr.PRs("seesaw_plank", -pw / 2, -9, pw, 18, i / 3.0, (i + 1) / 3.0, Color(.85, .8, .75, a) if not s.get("icy") else Color(.8, .92, 1.1, a))
				Spr.restore()
			continue
		if s.get("tile") and s.get("roofhole"):
			# telhas soltas no meio do telhado: tortas, com frestas escuras entre elas
			Spr.rect(s.x, yy - 2, s.w, 14, Color(.07, .04, .03, .9))
			var k2 := 0
			var tx2: float = s.x + 2
			while tx2 < s.x + s.w - 4:
				Spr.save()
				Spr.translate(tx2 + 9 + shake, yy + 3 + (k2 % 2) * 2.0)
				Spr.rotate((.16 if k2 % 2 == 0 else -.12) + (sin(T * 1.9 + k2) * .08 if s.ct > 0 else 0.0))
				Spr.rr(-10, -6, 20, 12, 3, Color("#c0603a"))
				Spr.rr(-10, -6, 20, 4, 2, Color("#e08058"))
				Spr.restore()
				tx2 += 22
				k2 += 1
			Spr.text("!", s.x + s.w / 2, yy - 16 + sin(T * .12) * 2, 14, Color(1, .8, .4, .85), HORIZONTAL_ALIGNMENT_CENTER, Spr.font_b, 3)
			if Polish.FRESH and s.ct > 0 and T % 4 == 0:
				g.PARTS.append({"x": s.x + randf() * s.w, "y": yy + 10, "vx": randf_range(-.5, .5), "vy": .6, "life": 18, "col": Color(.75, .35, .2, .9)})
			continue
		if s.get("tile"):
			# telhas soltas na beira do telhado: tremem e despencam logo depois de pisar
			var tc := Color("#b4502e")
			var tw: float = 24.0
			var tx: float = s.x
			var k := 0
			while tx < s.x + s.w - 2:
				var jy: float = (sin(T * 1.9 + k) * 1.5 if s.ct > 0 else 0.0) + (k % 2) * 1.5
				Spr.rr(tx + shake, yy - 4 + jy, min(tw + 2, s.x + s.w - tx), 14, 4, tc)
				Spr.rr(tx + shake, yy - 4 + jy, min(tw + 2, s.x + s.w - tx), 5, 3, Color("#d8704a"))
				Spr.seg(tx + tw * .6 + shake, yy + jy, tx + tw * .4 + shake, yy + 9 + jy, Color(0, 0, 0, .35), 1.2)
				tx += tw
				k += 1
			Spr.rr(s.x - 2 + shake, yy - 6, s.w + 4, 18, 7, Color(1, .7, .4, (.1 + .08 * sin(T * .1 + s.x)) * a))
			if Polish.FRESH and s.ct > 0 and T % 4 == 0:
				g.PARTS.append({"x": s.x + randf() * s.w, "y": yy + 10, "vx": randf_range(-.5, .5), "vy": .6, "life": 18, "col": Color(.75, .35, .2, .9)})
			continue
		# tábua podre: rachaduras à mostra e um contorno pálido pulsando (dá para ver que é perigosa)
		var pulse: float = .18 + .12 * sin(T * .08 + s.x)
		Spr.rr(s.x - 2 + shake, yy - 2, s.w + 4, 20, 8, Color(1, .85, .55, pulse * a))
		Spr.PR("seesaw_plank", s.x + shake - 2, yy - 1, s.w + 4, 19, Color(.85, .8, .75, a) if not s.get("icy") else Color(.8, .92, 1.1, a))
		Spr.seg(s.x + 12 + shake, yy + 4, s.x + 30 + shake, yy + 12, Color(0, 0, 0, .45 * a), 1.5)
		Spr.seg(s.x + s.w - 20 + shake, yy + 3, s.x + s.w - 34 + shake, yy + 13, Color(0, 0, 0, .45 * a), 1.5)
		Spr.seg(s.x + s.w * .5 + shake, yy + 2, s.x + s.w * .45 + shake, yy + 14, Color(0, 0, 0, .35 * a), 1.2)
		if Polish.FRESH and s.ct > 0 and T % 3 == 0:
			# serragem caindo antes de quebrar
			g.PARTS.append({"x": s.x + randf() * s.w, "y": yy + 15, "vx": randf_range(-.4, .4), "vy": .5, "life": 22,
				"col": Color(.85, .7, .45, .9) if not s.get("icy") else Color(.9, .97, 1, .9)})
	Spr.alpha = a_crumb


## portão de placa alto: uma paliçada de toras pontudas vista de frente, com a porta na ponta esquerda.
## A porta de tábuas sobe para dentro da paliçada (some atrás das toras de cima). O Tomé entra pela
## porta, anda POR TRÁS da paliçada (as toras da frente são desenhadas por cima dele, em
## palisade_front, e ficam translúcidas enquanto alguém está atrás) e sai pela ponta direita, que
## fica aberta. A paliçada tem altura fixa (~3 Tomés); acima dela a colisão continua invisível como antes.
const GATE_DOOR := 150.0
const PAL_LW := 30.0      # largura de uma tora
const PAL_EXT := 2        # toras da frente à direita da porta (o trecho por onde ele passa escondido)
static func palisade_top(_g: Game, gt: Dictionary) -> float:
	# uma paliçada de verdade: ~3 Tomés de altura (acima dela a colisão do portão continua invisível)
	return max(float(gt.y), float(gt.y) + float(gt.h) - 320.0)

## geometria comum: [d0 = começo da porta, dw = largura da porta, x1 = fim das toras da frente]
static func _pal_geo(gt: Dictionary) -> Array:
	var cx: float = float(gt.x) + float(gt.w) / 2
	var dw := 66.0
	var d0: float = cx - dw / 2
	var x1: float = d0 + dw - 4.0 + PAL_EXT * (PAL_LW - 5.0) + 5.0
	return [d0, dw, x1]

static func _pal_log_top(lx: float, top: float) -> float:
	return top - 10.0 + float((int(lx * 7.3) % 5) * 7)

## parte de trás: chão de dentro, o vão escuro, a porta subindo e o batente esquerdo (o Tomé passa na frente deles)
static func _palisade_gate(g: Game, gt: Dictionary) -> void:
	var bot: float = float(gt.y) + float(gt.h)
	var top: float = palisade_top(g, gt)
	var geo: Array = _pal_geo(gt)
	var d0: float = geo[0]
	var dw: float = geo[1]
	var x1: float = geo[2]
	var cx: float = d0 + dw / 2
	var lin: float = bot - GATE_DOOR - 14.0
	var lift: float = clamp(float(gt.open), 0.0, 1.0) * (GATE_DOOR + 6.0)
	# sombra da paliçada no chão (de ponta a ponta)
	Spr.ellipse((d0 - PAL_LW + x1) / 2, bot + 3, (x1 - d0 + PAL_LW) * .62, 9, Color(0, 0, 0, .3))
	# lado de dentro: escuro (aparece no vão e quando as toras da frente ficam translúcidas)
	Spr.rect(d0 + 2, top + 30, x1 - d0 - 2, bot - top - 30, Color(.1, .07, .05, .5))
	Spr.rect(d0 + 2, lin + 8, dw - 4, bot - lin - 8, Color(.08, .06, .04, .45))
	# a porta de tábuas (sobe para trás das toras de cima)
	Spr.PR("gate_wood", d0, bot - GATE_DOOR - lift, dw, GATE_DOOR + 2)
	# portinhola do Pipoca, embaixo da porta fechada
	if gt.get("dogpass") and gt.open < .3:
		var fy: float = bot - 24
		Spr.rr(cx - 14, fy, 28, 24, 4, Color("#3a2414"))
		Spr.rr(cx - 12, fy + 3, 24, 19, 3, Color("#a8804a"))
		Spr.circle(cx, fy + 15, 3.2, Color(.3, .2, .1))
	# batente esquerdo: a tora da quina, um pouco mais grossa, e uma escora de lado (a paliçada fica de pé)
	var jx: float = d0 - PAL_LW + 6.0
	Spr.seg(jx - 26, bot + 2, jx + 8, top + 140, Color("#2e1c10"), 9.0)
	Spr.seg(jx - 26, bot + 2, jx + 8, top + 140, Color("#7a5434"), 5.0)
	_palisade_log(jx, _pal_log_top(jx, top) - 8.0, bot + 8.0, PAL_LW + 2.0, Color(.92, .88, .84), int(jx))

## parte da frente (desenhada por cima do Tomé e do Pipoca): toras em cima da porta, a viga e as toras
## à direita da porta. Enquanto alguém está atrás, ficam translúcidas para dar para ver quem passa.
static func palisade_front(g: Game) -> void:
	var M: Mech = g.M
	if M == null:
		return
	var c0: float = g.cam - 150
	var c1: float = g.cam + g.W + 150
	for gt in M.GATES:
		if gt.get("crank") or float(gt.h) <= 200.0 or gt.x + 200 < c0 or gt.x - 100 > c1:
			continue
		var bot: float = float(gt.y) + float(gt.h)
		var top: float = palisade_top(g, gt)
		var geo: Array = _pal_geo(gt)
		var d0: float = geo[0]
		var dw: float = geo[1]
		var x1: float = geo[2]
		var lin: float = bot - GATE_DOOR - 14.0
		# alguém atrás? (Tomé ou Pipoca entre a porta e a ponta direita)
		var behind := false
		var P = g.player
		if P and P.x + P.w > d0 + 6 and P.x < x1 - 4 and P.y + P.h > top and P.y < bot + 4:
			behind = true
		var D: Dictionary = g.X.DOG if g.X else {}
		if not D.is_empty() and float(D.x) + 18 > d0 + 6 and float(D.x) - 18 < x1 - 4 and abs(float(D.y) - bot) < 60:
			behind = true
		var fa: float = float(gt.get("_fa", 1.0))
		fa = move_toward(fa, .42 if behind else 1.0, .08)
		gt._fa = fa
		var tint := Color(.92, .88, .84, fa)
		var x: float = d0 - 4.0
		while x < x1 - 6.0:
			var over: bool = x < d0 + dw - 8.0
			var ty: float = _pal_log_top(x, top)
			var by: float = lin + 6.0 if over else bot + 8.0
			if by - ty >= 30.0:
				_palisade_log(x, ty, by, PAL_LW, Color(tint.r * (.86 if over else 1.0), tint.g * (.86 if over else 1.0), tint.b * (.86 if over else 1.0), fa), int(x))
			x += PAL_LW - 5.0
		# ponta direita: a última tora um pouco mais escura, virando para dentro (a quina da paliçada)
		Spr.rect(x1 - 7, top + 40, 7, bot - top - 32, Color(0, 0, 0, .22 * fa))
		# viga atravessada em cima da porta, amarrada nas toras
		Spr.rect(d0 - 14, lin - 2, dw + 28, 16, Color(Color("#3a2414"), fa))
		Spr.rect(d0 - 12, lin, dw + 24, 12, Color(Color("#7a5434"), fa))
		Spr.rect(d0 - 12, lin, dw + 24, 3, Color(1, .9, .7, .25 * fa))
		for k in [d0 - 4, d0 + dw - 2]:
			Spr.rect(k, lin - 4, 6, 20, Color(Color("#a0502e"), fa))

## uma tora da paliçada: corpo roliço (contorno, luz de um lado, sombra do outro, casca) e ponta afiada
static func _palisade_log(lx: float, ty: float, by: float, w: float, tint: Color, seed: int) -> void:
	var tip := 34.0
	var ol := Color("#2e1c10")
	var fa: float = tint.a
	ol.a = fa
	var base := Color("#8a5a34") * tint
	base.a = fa
	Spr.rect(lx + 1, ty + tip - 2, w - 2, by - ty - tip + 2, ol)
	Spr.rect(lx + 3, ty + tip - 2, w - 6, by - ty - tip + 2, base)
	Spr.rect(lx + 5, ty + tip, 4, by - ty - tip, Color(1, .9, .7, .2 * fa))
	Spr.rect(lx + w - 11, ty + tip, 6, by - ty - tip, Color(0, 0, 0, .2 * fa))
	# casca: risquinhos verticais e um nó
	var k := 0
	var yy: float = ty + tip + 20.0 + float(seed % 23)
	while yy < by - 16.0:
		var xx: float = lx + 8.0 + float((seed + k * 7) % int(max(1.0, w - 16.0)))
		Spr.seg(xx, yy, xx + 1, yy + 14 + (k % 3) * 6, Color(.25, .15, .08, .45 * fa), 1.4)
		yy += 34.0 + float((seed + k * 13) % 21)
		k += 1
	Spr.circle(lx + w * .5, ty + tip + 40 + float(seed % 37), 3.0, Color(.3, .18, .1, .7 * fa))
	# ponta afiada (madeira clara do corte)
	Spr.poly(PackedVector2Array([Vector2(lx + 1, ty + tip), Vector2(lx + w * .5, ty - 2), Vector2(lx + w - 1, ty + tip)]), ol)
	Spr.poly(PackedVector2Array([Vector2(lx + 4, ty + tip - 1), Vector2(lx + w * .5, ty + 3), Vector2(lx + w - 4, ty + tip - 1)]), Color(Color("#c79a62") * tint, fa))
	Spr.poly(PackedVector2Array([Vector2(lx + w * .5, ty + 3), Vector2(lx + w - 4, ty + tip - 1), Vector2(lx + w * .5 + 2, ty + tip - 1)]), Color(0, 0, 0, .18 * fa))
	# amarração de corda perto do pé e perto do topo
	for ry in [ty + tip + 26.0, by - 70.0]:
		if ry > ty + tip + 10.0 and ry < by - 10.0:
			Spr.rect(lx + 1, ry, w - 2, 7, Color(Color("#5a3a1c"), fa))
			Spr.rect(lx + 1, ry + 1, w - 2, 2, Color(1, .85, .6, .3 * fa))
