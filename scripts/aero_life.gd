class_name AeroLife
extends RefCounted
## Vida do aeroporto (só cenário, não machuca): passageiros andando e reagindo ao Milis, papéis
## voando, sombra de avião passando pelas vidraças, lâmpada fluorescente piscando na segurança,
## neon do duty free à noite, painéis de voo trocando e o alto-falante do aeroporto.

static var PAPERS: Array = []
static var _lvl: int = -1

const PAX_H := 118.0     # altura de um adulto (o Milis é baixinho)

static func _reset(g) -> void:
	if _lvl == g.level_idx and g.T > 2:
		return
	_lvl = g.level_idx
	PAPERS = []
	for p in g.L.get("pax", []):
		p.px = float(p.x)
		p.dir = float(p.get("dir", 1))
		p.rt = 0

static func aero(g) -> bool:
	return g.L.get("theme", "") == "aeroporto"

# ---------------------------------------------------------------- atrás do Milis
static func back(g, T: int) -> void:
	if not aero(g):
		return
	_reset(g)
	_snacks(g, T)
	_grilles(g, T)
	_neon_floor(g, T)
	_floor_shine(g, T)
	_boards(g, T)
	_posters(g, T)
	_carts(g, T)
	_pax(g, T)

static func _pax(g, T: int) -> void:
	var pl: Dictionary = g.player
	var pcx: float = pl.x + pl.w / 2
	for p in g.L.get("pax", []):
		if p.get("behind", false):
			continue   # do outro lado do balcão: desenhado junto do cenário, atrás dos blocos
		var n: String = str(p.n)
		var k: String = str(p.get("k", "walk"))
		var fresh: bool = Polish.FRESH
		# anda de um lado para o outro dentro do trecho dele
		# sem ciclo de passos desenhado, ninguém desliza parado: fica em pé olhando o movimento
		if k == "walk" and Spr.opt(n + "_walk") == null:
			k = "stand"
		if k == "walk" and fresh and int(p.rt) <= 0:
			var spd: float = float(p.get("spd", .9))
			p.px += p.dir * spd
			p.wd = float(p.get("wd", 0.0)) + spd
			var r: Array = p.r
			if p.px > float(r[1]):
				p.px = float(r[1])
				p.dir = -1.0
			elif p.px < float(r[0]):
				p.px = float(r[0])
				p.dir = 1.0
		var x: float = p.px
		if x < g.cam - 200 or x > g.cam + g.W + 200:
			continue
		var y: float = float(p.get("y", 500))
		var near: bool = abs(pcx - x) < 95 and abs(pl.y + pl.h - y) < 120
		# reação: assusta (troca de pose e para um pouco), acena ou aponta para o Milis
		if near and p.has("re") and int(p.rt) <= 0 and fresh:
			p.rt = 70
		if int(p.rt) > 0 and fresh:
			p.rt -= 1
		# passageiros em azul de duas cores (versão "de cenário"): ninguém confunde com capanga
		var nm: String = n.replace("pax_", "paxbg_") if Spr.AR.has("p_" + n.replace("pax_", "paxbg_")) else n
		var hop := 0.0
		if int(p.rt) > 0 and p.has("re"):
			# reage sem virar outra pessoa: um pulinho de susto (ou de alegria) e um balão
			hop = -abs(sin(float(p.rt) * .2)) * 7.0
		var r2 = Spr.AR.get("p_" + nm)
		if r2 == null:
			continue
		var hgt: float = PAX_H * float(p.get("sc", 1.0))
		var w: float = hgt * r2[2] / r2[3]
		var face_left: bool = p.dir < 0
		if k != "walk":
			face_left = pcx < x if p.get("look", true) else bool(p.get("flip", false))
		var bob := 0.0
		if k == "walk" and int(p.rt) <= 0:
			bob = -abs(sin(p.px * .09)) * 2.5
		elif k == "sit":
			bob = sin(T * .03 + x) * .8
		Spr.ellipse(x, y + 1, w * .32, 5, Color(0, 0, 0, .22))
		# andando: ciclo de passos desenhado (assets/sprites/pax_<nome>_walk.png, já na versão "de cenário")
		var wt: Texture2D = Spr.opt(n + "_walk") if k == "walk" and int(p.rt) <= 0 else null
		if wt:
			var wm: Dictionary = Spr.walk_meta(n + "_walk")
			var cw: float = float(wm.get("cw", 240))
			var chh: float = float(wm.get("ch", 260))
			var wsc: float = hgt / float(wm.get("hgt", 240))
			Spr.save()
			Spr.translate(x, y + 3 + bob * .4)
			Spr.scale(-wsc if face_left else wsc, wsc)
			Spr.ci.draw_texture_rect_region(wt, Rect2(-float(wm.get("hx", 130)), -float(wm.get("base", 256)), cw, chh), Rect2(Spr.walk_frame(n + "_walk", float(p.get("wd", 0.0)), wsc) * cw, 0, cw, chh), Color(1, 1, 1, .94 * Spr.alpha))
			Spr.restore()
		else:
			Spr.P(nm, x, y + 3 + bob + hop, w, face_left, 0.0, Color(1, 1, 1, .94))
		if int(p.rt) > 20 and p.has("re"):
			var by: float = y - hgt - 18 + hop
			Spr.rr(x - 12, by - 14, 24, 22, 8, Color(1, 1, 1, .95))
			Spr.text(str(p.get("bal", "!")), x, by + 3, 15, Color("#c8302a"), HORIZONTAL_ALIGNMENT_CENTER, Spr.font_b)
		# o turista (e o menino) tiram foto do Milis quando ele passa: celular erguido e um flash
		if k == "stand" and (n.ends_with("turista") or n.ends_with("menino")) and abs(pcx - x) < 260:
			var ph: int = (T + int(x)) % 150
			var hx: float = x + (-1.0 if face_left else 1.0) * w * .28
			var hy: float = y - hgt * .72
			Spr.rr(hx - 4, hy - 7, 8, 13, 2, Color("#1c1f26"))
			Spr.rect(hx - 3, hy - 5, 6, 8, Color("#8fd0ff"))
			if ph < 6:
				Spr.glow(hx, hy, 34, Color(1, 1, 1, .85 * (1.0 - ph / 6.0)))
				Spr.circle(hx, hy, 6, Color(1, 1, 1, .95))
				if ph == 0 and fresh:
					Audio.play("click", -14, 1.4)
		if k == "sit" and str(p.get("z", "")) != "":
			var zt: int = (T + int(x)) % 120
			Spr.text("z", x + 18 + zt * .15, y - hgt * .78 - zt * .3, 12 + zt / 30, Color(1, 1, 1, 1.0 - zt / 120.0), HORIZONTAL_ALIGNMENT_LEFT, Spr.font_b, 3)

## carrinho elétrico da limpeza passando devagar no fundo (vai e volta)
static func _carts(g, T: int) -> void:
	for c in g.L.get("carts", []):
		var x0: float = float(c.x0)
		var x1: float = float(c.x1)
		var span: float = x1 - x0
		var ph: float = fposmod(T * .6 + x0, span * 2)
		var x: float = x0 + (ph if ph < span else span * 2 - ph)
		var left: bool = ph >= span
		if x < g.cam - 200 or x > g.cam + g.W + 200:
			continue
		var y: float = float(c.get("y", 500))
		Spr.ellipse(x, y + 1, 62, 6, Color(0, 0, 0, .22))
		var lt: Texture2D = Spr.opt("aero_lavadora")
		if lt != null:
			# lavadora de piso com o funcionário da limpeza sentado pilotando (cores de cenário, sem contorno)
			var lw := 150.0
			var lh: float = lw * lt.get_height() / lt.get_width()
			Spr.save()
			Spr.translate(x, y + 3 + sin(T * .3) * .5)
			Spr.scale(-1.0 if left else 1.0, 1.0)
			Spr.ci.draw_texture_rect(lt, Rect2(-lw / 2, -lh, lw, lh), false, Color(.95, .95, .96, Spr.alpha))
			Spr.restore()
		else:
			Spr.P("ob_limpeza", x, y + 3 + sin(T * .3) * .5, 120, left, 0.0, Color(.95, .95, .97))
		if Polish.FRESH and T % 6 == 0:
			g.PARTS.append({"x": x + (-50.0 if not left else 50.0), "y": y - 2, "vx": randf_range(-.5, .5), "vy": -randf_range(.2, .6), "life": 18, "col": Color(.8, .9, 1, .7)})

## neon do duty free refletindo no piso (trechos de noite)
static func _neon_floor(g, T: int) -> void:
	for nz in g.L.get("neon", []):
		var x: float = float(nz.x)
		if x < g.cam - 300 or x > g.cam + g.W + 300:
			continue
		var c: Color = Color(str(nz.get("c", "#ff4fb4")))
		var pu: float = .55 + .25 * sin(T * .07 + x) + (.2 if (T + int(x)) % 170 < 6 else 0.0)
		Spr.glow(x, float(nz.y) - 140, 90, Color(c.r, c.g, c.b, .18 * pu))
		Spr.ellipse(x, float(nz.y) + 2, 70, 7, Color(c.r, c.g, c.b, .22 * pu))
		Spr.ellipse(x, float(nz.y) + 2, 34, 3, Color(1, 1, 1, .15 * pu))

# ---------------------------------------------------------------- na frente do Milis
static func front(g, T: int) -> void:
	if not aero(g):
		return
	_reset(g)
	_icons(g, T)
	_light_dust(g, T)
	_papers(g, T)
	_plane_shadow(g, T)
	_fluor(g, T)
	_foreground(g, T)

static func _section(g) -> Dictionary:
	var px: float = g.player.x
	var cur: Dictionary = {}
	for sc in g.L.get("sections", []):
		if float(sc.x) <= px:
			cur = sc
	return cur

## papéis e folhetos voando: o ar-condicionado sopra alguns, e o Milis correndo levanta outros
static func _papers(g, T: int) -> void:
	var pl: Dictionary = g.player
	if Polish.FRESH:
		if PAPERS.size() < 4 and T % 140 == 0:
			PAPERS.append({"x": g.cam + randf() * g.W, "y": g.cam_y + 40 + randf() * 120, "vx": randf_range(.6, 1.6), "vy": randf_range(.2, .6), "r": randf() * TAU, "life": 520, "c": _paper_col()})
		# folhas secas das plantas do saguão caindo de vez em quando (giram e planam em zigue-zague)
		if PAPERS.size() < 7 and T % 210 == 105:
			var lc := [Color("#7aa83c"), Color("#c9a13a"), Color("#a8642a"), Color("#5f8f34")]
			PAPERS.append({"x": g.cam + randf() * g.W, "y": g.cam_y + 20 + randf() * 80, "vx": randf_range(.3, 1.0), "vy": randf_range(.1, .4), "r": randf() * TAU, "life": 600, "c": lc[randi() % lc.size()], "leaf": true})
		if pl.onGround and abs(pl.vx) > 3.6 and T % 16 == 0 and PAPERS.size() < 8:
			PAPERS.append({"x": pl.x + pl.w / 2 - sign(pl.vx) * 10, "y": pl.y + pl.h - 6, "vx": -sign(pl.vx) * randf_range(.5, 1.5) + pl.vx * .3, "vy": -randf_range(1.5, 3.0), "r": randf() * TAU, "life": 220, "c": _paper_col()})
		var i := PAPERS.size() - 1
		while i >= 0:
			var p: Dictionary = PAPERS[i]
			p.life -= 1
			p.vy = min(p.vy + .035, .9)
			p.vx += sin(T * .05 + p.r) * .03
			p.x += p.vx
			p.y += p.vy + sin(T * .09 + p.r * 3) * .5
			p.r += .07
			if p.life <= 0 or p.y > 520 or p.x < g.cam - 300 or p.x > g.cam + g.W + 300:
				PAPERS.remove_at(i)
			i -= 1
	for p in PAPERS:
		var a: float = clamp(float(p.life) / 40.0, 0, 1)
		Spr.save()
		Spr.translate(p.x, p.y)
		Spr.rotate(sin(p.r) * .8)
		Spr.scale(cos(p.r * 1.3), 1)
		var c: Color = p.c
		if p.get("leaf", false):
			Spr.ellipse(0, 0, 7, 3.2, Color(c.r * .6, c.g * .6, c.b * .6, .9 * a))
			Spr.ellipse(0, 0, 6, 2.4, Color(c.r, c.g, c.b, .95 * a))
			Spr.seg(-6, 0, 6, 0, Color(c.r * .55, c.g * .55, c.b * .5, .8 * a), 1)
		else:
			Spr.rect(-6, -4, 12, 8, Color(c.r, c.g, c.b, .95 * a))
			Spr.rect(-4, -2, 8, 1, Color(0, 0, 0, .25 * a))
			Spr.rect(-4, 1, 6, 1, Color(0, 0, 0, .2 * a))
		Spr.restore()

## dicas sem texto: um balão com o gesto (↑↑ pulo duplo, ↓ abaixar, » correr, ✋ usar) em cima do
## lugar, enquanto o Milis está no trecho
static func _icons(g, T: int) -> void:
	var px: float = g.player.x + g.player.w / 2
	for ic in g.L.get("icons", []):
		var a0: float = float(ic.a)
		var b0: float = float(ic.b)
		var d: float = max(a0 - px, px - b0, 0.0)
		var al: float = clamp(1.0 - d / 80.0, 0.0, 1.0)
		if al <= 0.0:
			continue
		var x: float = float(ic.x)
		var y: float = float(ic.y) + sin(T * .09) * 4.0
		var gtxt: String = str(ic.g)
		var w: float = max(48.0, 22.0 + gtxt.length() * 13.0)
		var pulse: float = 1.0 + .06 * sin(T * .2)
		Spr.save()
		Spr.translate(x, y)
		Spr.scale(pulse, pulse)
		Spr.poly(PackedVector2Array([Vector2(-7, 18), Vector2(7, 18), Vector2(0, 30)]), Color(1, 1, 1, .92 * al))
		Spr.rr(-w / 2 - 2, -22, w + 4, 44, 22, Color(.1, .16, .28, .9 * al))
		Spr.rr(-w / 2, -20, w, 40, 20, Color(1, 1, 1, .94 * al))
		Spr.text(gtxt, 0, 8, 22, Color(.12, .2, .36, al), HORIZONTAL_ALIGNMENT_CENTER, Spr.font_b, 0)
		Spr.restore()

## petisco típico (Galeão: saquinho de biscoito de polvilho, branco e laranja, com as rodelinhas)
static func _snacks(g, T: int) -> void:
	for sn in g.SNACKS:
		if sn.got or sn.x < g.cam - 60 or sn.x > g.cam + g.W + 60:
			continue
		var y: float = sn.y + sin(T * .07 + sn.x) * 3.0
		Spr.glow(sn.x, y, 26, Color(1, .85, .45, .3 + .1 * sin(T * .15)))
		Spr.save()
		Spr.translate(sn.x, y)
		Spr.rotate(sin(T * .05 + sn.x) * .12)
		Spr.rr(-13, -18, 26, 34, 4, Color("#2a1d14"))
		Spr.rr(-11, -16, 22, 30, 3, Color("#fbf6ec"))
		Spr.rect(-11, -16, 22, 6, Color("#f08a2a"))
		Spr.rect(-11, 8, 22, 6, Color("#f08a2a"))
		for k in 3:
			Spr.ring(-5 + k * 5, -1 + (k % 2) * 4, 3.2, Color("#d9a85a"), 2)
		Spr.restore()

## grade de ventilação torta na parede: pista de que tem segredo lá em cima (brilha de vez em quando)
static func _grilles(g, T: int) -> void:
	for gr in g.L.get("grilles", []):
		var x: float = float(gr.x)
		var y: float = float(gr.y)
		if x < g.cam - 100 or x > g.cam + g.W + 100:
			continue
		Spr.save()
		Spr.translate(x, y)
		Spr.rotate(.22)
		Spr.rr(-22, -14, 44, 28, 3, Color("#2a3140"))
		Spr.rr(-20, -12, 40, 24, 2, Color("#8a94a6"))
		for i in 5:
			Spr.rect(-17, -9 + i * 4.4, 34, 2, Color("#3a4252"))
		Spr.circle(-17, -9, 1.4, Color("#cfd6e2"))
		Spr.circle(17, 9, 1.4, Color("#cfd6e2"))
		Spr.restore()
		# um parafuso caído embaixo e um brilho que sobe (aponta o caminho para o alto)
		Spr.circle(x + 14, y + 26, 1.6, Color("#9aa3b2"))
		var k: int = T % 150
		if k < 30:
			var u: float = k / 30.0
			Spr.glow(x, y - 20 - u * 60, 10, Color(1, .95, .6, .5 * (1.0 - u)))

static func hh(x: float, k: int = 0) -> float:
	var v := sin(x * 12.9898 + k * 78.233) * 43758.5453
	return v - floor(v)

## luz do sol entrando pelas vidraças (de dia): faixas de luz inclinadas e poeirinha brilhando nelas
static func _light_dust(g, T: int) -> void:
	var sc := _section(g)
	var bg: String = str(sc.get("bg", ""))
	if not bg in ["vila", "tarde"]:
		return
	var warm := Color(1, .93, .72) if bg == "vila" else Color(1, .72, .45)
	var W: float = g.W
	var H: float = g.H
	var top: float = g.cam_y
	# faixas de luz (paralaxe leve, andam um pouco mais devagar que o cenário)
	var per := 520.0
	var off: float = fposmod(-g.cam * .85, per)
	var xx: float = g.cam - per + off
	while xx < g.cam + W + per:
		var a: float = .075 + .02 * sin(T * .01 + xx * .01)
		Spr.poly(PackedVector2Array([Vector2(xx, top), Vector2(xx + 110, top), Vector2(xx + 330, top + H), Vector2(xx + 170, top + H)]), Color(warm.r, warm.g, warm.b, a))
		# o Milis passando dentro da faixa de luz fica iluminado
		var pl: Dictionary = g.player
		var pcx: float = pl.x + pl.w / 2
		var pcy: float = pl.y + pl.h * .45
		var v: float = clamp((pcy - top) / H, 0.0, 1.0)
		var l0: float = xx + 170.0 * v
		var l1: float = xx + 110.0 + 220.0 * v
		if pcx > l0 and pcx < l1:
			var edge: float = clamp(min(pcx - l0, l1 - pcx) / 30.0, 0.0, 1.0)
			Spr.glow(pcx, pcy, 46, Color(warm.r, warm.g, warm.b, .22 * edge))
		xx += per

## poeira suspensa: pontinhos de luz que flutuam e cintilam. Desenhada na camada de brilho (por cima do
## mundo): na camada do mundo o contorno de tinta dava um anel preto em volta de cada pontinho
static func motes(g, T: int) -> void:
	if g.L.get("theme", "") != "aeroporto" or g.low_fx:
		return
	var bg: String = str(_section(g).get("bg", ""))
	if not bg in ["vila", "tarde"]:
		return
	var W: float = g.W
	var H: float = g.H
	var top: float = g.cam_y
	for i in 34:
		var sp: float = .12 + hh(i, 1) * .25
		var x: float = g.cam + fposmod(hh(i, 2) * W * 1.2 + T * sp, W * 1.2) - W * .1
		var y: float = top + H * .12 + fposmod(hh(i, 3) * H * .7 + sin(T * .013 + i) * 18.0 - T * .04 * hh(i, 4), H * .7)
		var tw: float = .5 + .5 * sin(T * (.05 + hh(i, 5) * .05) + i * 2.1)
		var r: float = .9 + hh(i, 6) * 1.1
		Spr.glow(x, y, r * 2.2, Color(1, .98, .9, .4 + .45 * tw))
		if tw > .85:
			Spr.glow(x, y, 6, Color(1, .95, .8, .25))

## piso encerado refletindo as vidraças (de dia): faixas claras que deslizam ao contrário da câmera
static func _floor_shine(g, T: int) -> void:
	var sc := _section(g)
	if not str(sc.get("bg", "")) in ["vila", "tarde"]:
		return
	var per := 300.0
	var off: float = fposmod(g.cam * .35, per)
	var xx: float = g.cam - per + off
	var pits: Array = g.L.get("pits", [])
	while xx < g.cam + g.W + per:
		var over := false
		for pt in pits:
			if xx + 106 > float(pt[0]) and xx < float(pt[1]):
				over = true
		if over:
			xx += per
			continue
		Spr.vgrad(xx, 500, 70, 28, Color(1, 1, 1, .1), Color(1, 1, 1, 0))
		Spr.vgrad(xx + 84, 500, 22, 20, Color(1, 1, 1, .07), Color(1, 1, 1, 0))
		xx += per

static func _paper_col() -> Color:
	var cs := [Color(1, 1, 1), Color(.98, .96, .88), Color(1, .9, .55), Color(.75, .88, 1)]
	return cs[randi() % cs.size()]

## de tempos em tempos a sombra de um avião passa pelas vidraças (só de dia, no saguão e check-in)
static func _plane_shadow(g, T: int) -> void:
	var sc := _section(g)
	if not str(sc.get("bg", "")) in ["vila"]:
		return
	var per := 1500
	var u: int = (T + 400) % per
	var dur := 260
	if u > dur:
		return
	var k: float = u / float(dur)
	var cx: float = g.cam - 500 + (g.W + 1000) * k
	var cy: float = g.cam_y + g.H * .35 + k * 40
	var a: float = .07 * sin(k * PI)
	var col := Color(0, 0, .05, a)
	# fuselagem, asas e cauda (silhueta grande e borrada)
	Spr.ellipse(cx, cy, 300, 36, col)
	Spr.poly(PackedVector2Array([Vector2(cx - 40, cy), Vector2(cx + 60, cy), Vector2(cx - 80, cy + 190), Vector2(cx - 150, cy + 190)]), col)
	Spr.poly(PackedVector2Array([Vector2(cx - 40, cy), Vector2(cx + 60, cy), Vector2(cx - 80, cy - 170), Vector2(cx - 150, cy - 170)]), col)
	Spr.poly(PackedVector2Array([Vector2(cx - 260, cy), Vector2(cx - 220, cy), Vector2(cx - 300, cy - 90), Vector2(cx - 330, cy - 90)]), col)

## objetos bem na frente da câmera, escuros e desfocados, passando mais rápido que o cenário
## (coluna, vaso de planta, poste de fila, lixeira): dão profundidade. Poucos, longe da ação, e
## ficam quase transparentes quando passam na frente do Milis.
const FG_ART := {"coluna": ["pc_coluna", 150.0], "lixeira": ["ob_lixeiras", 200.0], "fila": ["ob_fila", 170.0], "bancos": ["pc_bancos", 330.0]}
static func _foreground(g, T: int) -> void:
	var list: Array = g.L.get("fg", [])
	if list.is_empty():
		return
	var cx: float = g.cam + g.W / 2
	var pl: Dictionary = g.player
	var pcx: float = pl.x + pl.w / 2
	for f in list:
		var x: float = float(f.x)
		# paralaxe: anda 1,45x mais rápido que o mundo
		var wx: float = cx + (x - cx) * 1.45
		var art: Array = FG_ART.get(str(f.k), FG_ART["coluna"])
		var w: float = art[1]
		if wx + w < g.cam - 20 or wx - w > g.cam + g.W + 20:
			continue
		var by: float = g.cam_y + g.H + float(f.get("dy", 30))
		var a: float = .9
		var d: float = abs(wx - pcx)
		if d < w * .5 + 90:
			a = lerpf(.18, .9, clamp((d - w * .5) / 90.0, 0.0, 1.0))
		var c := Color(.05, .06, .09, a * .5)
		# desfoque: três cópias deslocadas, translúcidas
		for o in [-5.0, 0.0, 5.0]:
			Spr.P(str(art[0]), wx + o, by + abs(o) * .4, w, bool(f.get("flip", false)), 0.0, c)

## segurança: luz fria fluorescente com uma lâmpada falhando
static func _fluor(g, T: int) -> void:
	var sc := _section(g)
	if not str(sc.get("song", "")).contains("seguranca"):
		return
	# (sem o véu frio na tela inteira: um retângulo do tamanho da tela no mundo fazia o contorno
	# trabalhar na tela toda e, antes, a lâmpada piscando escurecia tudo)
	pass


## painéis de voos pendurados no teto (com cabos), as linhas trocando
static func _boards(g, T: int) -> void:
	var i := 0
	for b in g.L.get("boards", []):
		i += 1
		var x: float = float(b.x)
		if x < g.cam - 300 or x > g.cam + g.W + 300:
			continue
		var y: float = float(b.y)
		var w: float = float(b.get("w", 150))
		var h: float = float(b.get("h", 64))
		# balança de leve nos cabos (o ar-condicionado e o vai e vem do saguão)
		Spr.save()
		Spr.translate(x + w / 2, y - 260)
		Spr.rotate(sin(T * .021 + i * 1.7) * .006 + sin(T * .053 + i) * .002)
		Spr.translate(-(x + w / 2), -(y - 260))
		Spr.seg(x + 16, y, x + 16, y - 260, Color("#3a414c"), 2)
		Spr.seg(x + w - 16, y, x + w - 16, y - 260, Color("#3a414c"), 2)
		Spr.rr(x - 5, y - 5, w + 10, h + 10, 4, Color("#1b1e24"))
		Spr.rr(x - 3, y - 3, w + 6, 12, 3, Color("#2b4f96"))
		Spr.text("PARTIDAS" if i % 2 == 1 else "CHEGADAS", x + 6, y + 6, 8, Color.WHITE, HORIZONTAL_ALIGNMENT_LEFT, Spr.font_b)
		board(x, y + 10, w, h - 10, T, i)
		Spr.glow(x + w / 2, y + h / 2, w * .6, Color(1, .85, .4, .06))
		# LED de "embarque" piscando no canto
		if ((T + i * 23) / 24) % 2 == 0:
			Spr.circle(x + w - 8, y + 2, 2.2, Color(.3, 1, .45, .95))
			Spr.glow(x + w - 8, y + 2, 9, Color(.3, 1, .45, .35))
		Spr.restore()

# ---------------------------------------------------------------- painel de voos girando
## em cima da arte do painel (colunas do cenário): as linhas de voos trocam de vez em quando
static func board(x: float, y: float, w: float, h: float, T: int, seed_v: int) -> void:
	Spr.rect(x, y, w, h, Color("#0d1420"))
	var rows: int = max(3, int(h / 7))
	for i in rows:
		var ry: float = y + 2 + i * (h - 3) / rows
		var flip: bool = ((T / 6 + seed_v * 13 + i * 7) % 180) < 10
		var c: Color = Color("#ffcf3a") if (i + seed_v) % 3 != 0 else Color("#7fd0ff")
		if flip:
			Spr.rect(x + 3, ry, w - 6, 3, Color(1, 1, 1, .6))
			continue
		var ww: float = (w - 10) * (.35 + .5 * fposmod(sin(float(i * 31 + seed_v * 7 + (T / 400))) * 43758.5, 1.0))
		Spr.rect(x + 3, ry, ww, 2.5, c)
		Spr.rect(x + w - 14, ry, 10, 2.5, Color("#5cff8a") if (i + seed_v) % 4 == 0 else c)

# ---------------------------------------------------------------- alto-falante (texto no rodapé)
const AVISOS := [
	"Última chamada para o voo LA 3410 com destino a Curitiba, portão 12.",
	"Atenção, senhores passageiros: não deixem bagagens desacompanhadas.",
	"Passageiro Seu Barros, favor comparecer ao balcão de informações.",
	"O voo LA 8072 para Salvador está atrasado. Previsão: 18h40.",
	"Lembramos que é proibido fumar em todas as áreas do aeroporto.",
	"Atenção: piso molhado próximo ao check-in. Cuidado ao caminhar.",
	"Embarque imediato do voo LA 3302 para Brasília, portão 8.",
]

static func aviso(T: int) -> String:
	var per := 2400
	var u: int = T % per
	if u > 520 or T < 600:
		return ""
	return AVISOS[(T / per) % AVISOS.size()]

## cartazes de PROCURADO do vulto: aparecem depois da 1ª pista e revelam mais a cada pista
## (1: o vulto de capuz; 2: o B dourado no peito; 3: a sombra da cartola e do bigode)
static func _posters(g, T: int) -> void:
	var n: int = g.CLUEGOT.size()
	if n <= 0:
		return
	for ps in g.L.get("posters", []):
		var x: float = float(ps.x)
		if x < g.cam - 120 or x > g.cam + g.W + 120:
			continue
		var y: float = float(ps.get("y", 300))
		var rot: float = float(ps.get("rot", -.04))
		var fresh_t: int = T - int(g.get_meta("poster_t", -999))
		var pop: float = clamp(fresh_t / 20.0, 0.0, 1.0)
		Spr.save()
		Spr.translate(x, y)
		Spr.rotate(rot + (1.0 - pop) * .3)
		Spr.scale(.6 + .4 * pop, .6 + .4 * pop)
		var w := 70.0
		var h := 96.0
		Spr.rect(-w / 2 + 3, -h / 2 + 4, w, h, Color(0, 0, 0, .25))
		Spr.rect(-w / 2, -h / 2, w, h, Color("#efe6cf"))
		Spr.rect(-w / 2, -h / 2, w, 17, Color("#b3261e"))
		Spr.text("PROCURADO", 0, -h / 2 + 13, 11, Color(1, .95, .85), HORIZONTAL_ALIGNMENT_CENTER, Spr.font_b)
		# o vulto
		var dk := Color("#1d1b22")
		Spr.poly(PackedVector2Array([Vector2(-26, 32), Vector2(-20, 6), Vector2(-9, -4), Vector2(9, -4), Vector2(20, 6), Vector2(26, 32)]), dk)
		Spr.poly(PackedVector2Array([Vector2(-15, 2), Vector2(-14, -18), Vector2(0, -30), Vector2(14, -18), Vector2(15, 2)]), dk)
		Spr.circle(-5, -10, 2.2, Color(1, .85, .3))
		Spr.circle(5, -10, 2.2, Color(1, .85, .3))
		if n >= 2:
			# o B dourado bordado (do lenço e do bilhete)
			Spr.text("B", 0, 24, 16, Color("#e8b830"), HORIZONTAL_ALIGNMENT_CENTER, Spr.font_title)
		if n >= 3:
			# por baixo do capuz: a sombra de uma cartola e de um bigode de barão
			Spr.rect(-11, -42, 22, 13, Color(.12, .1, .14, .85))
			Spr.rect(-17, -30, 34, 3, Color(.12, .1, .14, .85))
			Spr.poly(PackedVector2Array([Vector2(-10, -3), Vector2(0, -6), Vector2(10, -3), Vector2(4, -2), Vector2(0, -3), Vector2(-4, -2)]), Color(.85, .8, .7, .9))
		else:
			Spr.text("?", 0, -34, 14, Color(.85, .2, .15), HORIZONTAL_ALIGNMENT_CENTER, Spr.font_b)
		Spr.text("RECOMPENSA", 0, h / 2 - 12, 8, Color(.25, .2, .15), HORIZONTAL_ALIGNMENT_CENTER, Spr.font_b)
		Spr.text("%d/3 pistas" % n, 0, h / 2 - 3, 7, Color(.45, .35, .25), HORIZONTAL_ALIGNMENT_CENTER, Spr.font_b)
		# fita adesiva nos cantos
		for cx in [-w / 2 + 4, w / 2 - 4]:
			Spr.save()
			Spr.translate(cx, -h / 2 + 2)
			Spr.rotate(.6 if cx < 0 else -.6)
			Spr.rect(-9, -3, 18, 6, Color(.95, .93, .8, .75))
			Spr.restore()
		Spr.restore()
