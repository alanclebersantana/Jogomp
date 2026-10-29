extends RefCounted
class_name WorldKings
## Desenho do Gavião-Rei e do Bagre-Rei.

static func _crown(x: float, y: float, s: float, rot: float = 0.0) -> void:
	if rot != 0.0:
		Spr.save()
		Spr.translate(x, y)
		Spr.rotate(rot)
		_crown(0, 0, s)
		Spr.restore()
		return
	var gold := Color("#e8b030")
	var pts := PackedVector2Array([Vector2(x - 14 * s, y), Vector2(x - 14 * s, y - 10 * s), Vector2(x - 7 * s, y - 4 * s),
		Vector2(x, y - 14 * s), Vector2(x + 7 * s, y - 4 * s), Vector2(x + 14 * s, y - 10 * s), Vector2(x + 14 * s, y)])
	Spr.poly(pts, gold)
	Spr.ci.draw_polyline(pts + PackedVector2Array([pts[0]]), Color("#5a3a10"), 2, true)
	Spr.circle(x, y - 5 * s, 2.6 * s, Color("#e0463a"))

# ======================================================================
#  COROAS DOS REIS (desenhadas em código, cada uma do jeito do seu rei)
#  javali: folhas e frutinhas · gaviao: penas · bagre: escamas e pérolas · urso: gelo
#  Origem no meio da base (onde assenta na cabeça); sobe uns 30 px (escala 1).
# ======================================================================
const CROWN_IDS := ["javali", "gaviao", "bagre", "urso"]
const CROWN_NAME := {"javali": "Coroa de Folhas", "gaviao": "Coroa de Penas", "bagre": "Coroa de Pérolas", "urso": "Coroa de Gelo"}
const CROWN_KING := {"javali": "Javali-Rei", "gaviao": "Gavião-Rei", "bagre": "Bagre-Rei", "urso": "Urso-Pardo-Rei"}
const _OL := Color("#24160c")

## polígono pintado: preenchimento, uma luz do lado de cima e o contorno escuro
static func _cp(pts: PackedVector2Array, fill: Color, w: float = 1.6, ol: Color = _OL) -> void:
	Spr.poly(pts, fill)
	var c := PackedVector2Array(pts)
	c.push_back(pts[0])
	Spr.line(c, ol, w)

## folha pontuda (base em b, ponta na direção a, comprimento l, largura w)
static func _leaf_pts(b: Vector2, a: float, l: float, w: float) -> PackedVector2Array:
	var d := Vector2(cos(a), sin(a))
	var n := Vector2(-d.y, d.x)
	var pts := PackedVector2Array()
	for i in 7:
		var u: float = i / 6.0
		pts.push_back(b + d * l * u + n * w * sin(u * PI) * (1.0 - u * .25))
	for i in range(5, 0, -1):
		var u2: float = i / 6.0
		pts.push_back(b + d * l * u2 - n * w * sin(u2 * PI) * (1.0 - u2 * .25))
	return pts

static func crown_art(kind: String, x: float, y: float, s: float, rot: float = 0.0, T: int = 0) -> void:
	Spr.save()
	Spr.translate(x, y)
	if rot != 0.0:
		Spr.rotate(rot)
	Spr.scale(s, s)
	match kind:
		"javali":
			_crown_leaf()
		"gaviao":
			_crown_feather()
		"bagre":
			_crown_pearl(T)
		"urso":
			_crown_ice(T)
		_:
			_crown(0, 0, 1.0)
	Spr.restore()

static func _crown_leaf() -> void:
	# fundo de folhas escuras (fecha os vãos entre as folhas da frente)
	Spr.poly(PackedVector2Array([Vector2(-17, -4), Vector2(-17, -15), Vector2(-9, -23), Vector2(0, -27), Vector2(9, -23), Vector2(17, -15), Vector2(17, -4)]), Color("#2f5e22"))
	var cols := [Color("#4f8f30"), Color("#6aaa3c"), Color("#3f7a28"), Color("#7cbc48"), Color("#3f7a28"), Color("#6aaa3c"), Color("#4f8f30")]
	for i in 7:
		var a: float = -PI / 2 + (i - 3) * .36
		var l: float = 20.0 - abs(i - 3) * 1.8
		var b := Vector2((i - 3) * 4.4, -5)
		var pts := _leaf_pts(b, a, l, 6.4)
		_cp(pts, cols[i], 1.3, Color("#1c3812"))
		# nervura e a luz de um lado da folha
		var d := Vector2(cos(a), sin(a))
		Spr.seg(b.x + d.x * 3, b.y + d.y * 3, b.x + d.x * l * .8, b.y + d.y * l * .8, Color("#c8e890", .8), 1.0)
		var n := Vector2(-d.y, d.x)
		Spr.seg(b.x + d.x * l * .3 + n.x * 2.2, b.y + d.y * l * .3 + n.y * 2.2, b.x + d.x * l * .62 + n.x * 2.2, b.y + d.y * l * .62 + n.y * 2.2, Color(1, 1, 1, .28), 1.4)
	# aro de casca trançada
	_cp(PackedVector2Array([Vector2(-18, -8), Vector2(18, -8), Vector2(19, -1), Vector2(14, 1.5), Vector2(-14, 1.5), Vector2(-19, -1)]), Color("#7a5230"))
	for k in 7:
		var tx: float = -15 + k * 5
		Spr.seg(tx - 2, -7, tx + 2.5, 0.5, Color("#4a2e18"), 1.4)
		Spr.seg(tx - 1, -6.5, tx + 1, -3, Color("#b08458", .8), 1.0)
	Spr.seg(-16, -7, 16, -7, Color("#a87a4c", .7), 1.0)
	# frutinhas vermelhas
	for bx in [-10.0, 0.0, 10.0]:
		var by: float = -9.5 - (2.0 if bx == 0.0 else 0.0)
		Spr.circle(bx, by, 3.3, _OL)
		Spr.circle(bx, by, 2.6, Color("#d8402e"))
		Spr.circle(bx - .9, by - .9, .9, Color(1, 1, 1, .8))

static func _crown_feather() -> void:
	var angs := [-.62, -.32, 0.0, .32, .62]
	var lens := [20.0, 26.0, 31.0, 26.0, 20.0]
	for j in [0, 4, 1, 3, 2]:
		var a: float = -PI / 2 + angs[j]
		var b := Vector2(angs[j] * 16.0, -6)
		var l: float = lens[j]
		var pts := _leaf_pts(b, a, l, 5.0 if j == 2 else 4.4)
		_cp(pts, Color("#9a6534") if j % 2 == 0 else Color("#b98048"), 1.3, Color("#2a180a"))
		var d := Vector2(cos(a), sin(a))
		var n := Vector2(-d.y, d.x)
		# faixas escuras atravessadas e a ponta creme (pena de gavião)
		for k in 3:
			var u: float = .28 + k * .2
			var c := b + d * l * u
			var ww: float = 4.4 * sin(u * PI) * (1.0 - u * .25)
			Spr.seg(c.x - n.x * ww, c.y - n.y * ww, c.x + n.x * ww + d.x * 1.5, c.y + n.y * ww + d.y * 1.5, Color("#4a2a12"), 1.6)
		var tip := b + d * l * .88
		Spr.ellipse(tip.x, tip.y, 2.6, 1.6, Color("#f4e6c4"), a)
		# haste
		Spr.seg(b.x, b.y, b.x + d.x * l * .92, b.y + d.y * l * .92, Color("#f0dcb0", .9), 1.0)
	# aro de ouro com o rubi âmbar
	_cp(PackedVector2Array([Vector2(-17, -9), Vector2(17, -9), Vector2(18, -1), Vector2(13, 1.5), Vector2(-13, 1.5), Vector2(-18, -1)]), Color("#e8b030"), 1.6, Color("#5a3a10"))
	Spr.rect(-16, -3, 32, 3, Color("#b87a1c"))
	Spr.seg(-15, -7.5, 15, -7.5, Color("#fff0b0", .8), 1.2)
	_cp(PackedVector2Array([Vector2(0, -10), Vector2(3.6, -5), Vector2(0, -.5), Vector2(-3.6, -5)]), Color("#ff8a20"), 1.2, Color("#5a2a08"))
	Spr.circle(-1, -6.5, .9, Color(1, 1, 1, .85))
	for bx in [-10.0, 10.0]:
		Spr.circle(bx, -5, 1.8, Color("#5a3a10"))
		Spr.circle(bx, -5, 1.2, Color("#ffe9a0"))

static func _crown_pearl(T: int) -> void:
	# capa de escamas (fecha os vãos)
	_cp(PackedVector2Array([Vector2(-18, -3), Vector2(-17, -16), Vector2(-9, -22), Vector2(0, -24), Vector2(9, -22), Vector2(17, -16), Vector2(18, -3)]), Color("#2c7480"), 1.6, Color("#0e2e36"))
	for row in 3:
		var yy: float = -8 - row * 5.0
		var half: float = 13.0 - row * 3.5
		var sx: float = -half
		while sx <= half + .1:
			Spr.circle(sx, yy, 3.0, Color("#3f9aa2") if (row + int(sx)) % 2 == 0 else Color("#358c96"))
			Spr.ring(sx, yy - .4, 2.2, Color("#a8f0ec", .7), 1.0, PI * 1.15, PI * 1.7)
			sx += 5.2
	# pontas com pérolas
	var tips := [[-14.0, -19.0], [-7.0, -25.0], [0.0, -31.0], [7.0, -25.0], [14.0, -19.0]]
	for i in tips.size():
		var tx: float = tips[i][0]
		var ty: float = tips[i][1]
		_cp(PackedVector2Array([Vector2(tx - 4, ty + 9), Vector2(tx, ty + 2), Vector2(tx + 4, ty + 9)]), Color("#3a9aa0"), 1.2, Color("#0e2e36"))
		var r: float = 3.9 if i == 2 else 3.2
		Spr.circle(tx, ty, r + .9, Color("#2a2030"))
		Spr.circle(tx, ty, r, Color("#f2eefa"))
		Spr.circle(tx + r * .25, ty + r * .3, r * .55, Color("#d8cce8"))
		Spr.circle(tx - r * .35, ty - r * .35, r * .32, Color(1, 1, 1, .95))
	# aro de escamas
	_cp(PackedVector2Array([Vector2(-18, -9), Vector2(18, -9), Vector2(19, -1), Vector2(14, 1.5), Vector2(-14, 1.5), Vector2(-19, -1)]), Color("#3a9aa0"), 1.6, Color("#0e2e36"))
	var bx := -15.0
	while bx <= 15.1:
		Spr.circle(bx, -3.2, 3.4, Color("#2c8088"))
		Spr.ring(bx, -3.2, 3.4, Color("#0e2e36"), 1.0, PI, TAU)
		Spr.ring(bx, -3.6, 2.4, Color("#a8f0ec", .8), 1.0, PI * 1.15, PI * 1.6)
		bx += 5.0
	# pérola grande no meio, com um brilho que passeia
	Spr.circle(0, -9.5, 5.2, Color("#2a2030"))
	Spr.circle(0, -9.5, 4.4, Color("#f6f2ff"))
	Spr.circle(.9, -8.5, 2.6, Color("#e2d6f0"))
	var sh: float = sin(T * .08) * 1.2
	Spr.circle(-1.5 + sh, -11, 1.3, Color(1, 1, 1, .95))

static func _crown_ice(T: int) -> void:
	# geada de fundo (fecha os vãos entre os cristais)
	_cp(PackedVector2Array([Vector2(-18, -3), Vector2(-19, -14), Vector2(-10, -22), Vector2(0, -25), Vector2(10, -22), Vector2(19, -14), Vector2(18, -3)]), Color("#b8d8f0"), 1.6, Color("#2c5578"))
	var spk := [[-15.0, 16.0, -.28], [-9.5, 22.0, -.14], [-4.0, 27.0, -.05], [1.5, 33.0, 0.0], [6.5, 26.0, .06], [11.5, 21.0, .16], [16.0, 15.0, .3]]
	for i in spk.size():
		var bx: float = spk[i][0]
		var h: float = spk[i][1]
		var a: float = spk[i][2]
		var top := Vector2(bx + sin(a) * h, -6 - cos(a) * h)
		var l := Vector2(bx - 3.6, -5)
		var r := Vector2(bx + 3.6, -5)
		var mid := Vector2(bx + sin(a) * h * .45, -6 - cos(a) * h * .45)
		_cp(PackedVector2Array([l, top, r]), Color(.72, .88, 1.0, .95), 1.3, Color("#2c5578"))
		# faces do cristal: uma clara (luz) e uma azul mais funda
		Spr.poly(PackedVector2Array([l, top, mid]), Color(1, 1, 1, .55))
		Spr.poly(PackedVector2Array([mid, top, r]), Color(.35, .6, .9, .35))
		Spr.seg(top.x, top.y + 2, mid.x, mid.y, Color(1, 1, 1, .7), .9)
	# aro de neve batida com pinguinhos de gelo
	_cp(PackedVector2Array([Vector2(-18, -9), Vector2(-9, -10.5), Vector2(0, -9.5), Vector2(9, -10.5), Vector2(18, -9), Vector2(19, -1), Vector2(14, 1.5), Vector2(-14, 1.5), Vector2(-19, -1)]), Color("#eef6ff"), 1.6, Color("#2c5578"))
	Spr.rect(-16, -3.5, 32, 3.5, Color("#c4dcf2"))
	for k in 5:
		var ix: float = -12 + k * 6
		Spr.poly(PackedVector2Array([Vector2(ix - 1.6, 1), Vector2(ix + 1.6, 1), Vector2(ix, 4.5 + (k % 2) * 1.5)]), Color(.8, .92, 1, .9))
	# cristal azul no meio
	_cp(PackedVector2Array([Vector2(0, -12), Vector2(3.8, -6.5), Vector2(0, -1.5), Vector2(-3.8, -6.5)]), Color("#3aa4ff"), 1.2, Color("#123a66"))
	Spr.poly(PackedVector2Array([Vector2(0, -12), Vector2(-3.8, -6.5), Vector2(0, -6.5)]), Color(1, 1, 1, .45))
	# brilho de gelo piscando na ponta mais alta
	var tw: float = .5 + .5 * sin(T * .13)
	Spr.circle(1.5, -33, 1.6, Color(1, 1, 1, .85 * tw))

static func draw(g: Game, T: int) -> void:
	var K: Kings = g.K
	if K == null:
		return
	_hawk(g, K, T)
	_bear(g, K, T)
	sinking(g, T)
	# colmeias do Sapo-Rei (Ep. 2) atrás do Tomé
	WorldEp2.hives_back(g, T)

## o bagre é desenhado na camada de cima (depois da água), para não sumir no fundo escuro
static func draw_fish(g: Game, T: int) -> void:
	if g.K:
		_fish(g, g.K, T)
		draw_crowns(g, T)

static func _hawk(g: Game, K: Kings, T: int) -> void:
	var h: Dictionary = K.HAWK
	if h.get("skin", "") == "bat":
		# lamparinas da caverna (luta do Morcego-Rei no Ep. 2)
		WorldEp2.lamps(g, h, T)
	if h.is_empty() or h.done or h.st == "wait":
		return
	# sombra do mergulho no chão
	var sh := K.hawk_shadow()
	if sh.x > 0:
		var k: float = sh.y
		var pul: float = .8 + sin(T * .4) * .2
		Spr.ellipse(sh.x, h.gy + 2, 74 * k * pul, 15 * k, Color(0, 0, 0, .6 * k))
		Spr.ellipse(sh.x, h.gy + 2, 40 * k * pul, 8 * k, Color(0, 0, 0, .5 * k))
		Spr.ring(sh.x, h.gy - 1, 60 * k * pul, Color(1, .3, .2, .8 * k), 3, PI, TAU)
	var fr: int = (T / 5) % 3
	var sc := 1.5
	var rot := 0.0
	match h.st:
		"dive":
			fr = 1
			# mergulho de bico para baixo: inclina para o lado em que está olhando
			rot = .5 * (1.0 if h.dir > 0 else -1.0)
		"stuck":
			fr = (T / 3) % 3
		"mark":
			fr = (T / 4) % 3
	var tint := Color(1, .5, .45) if h.red > 0 and (T / 3) % 2 == 0 else Color(1, 1, 1)
	tint = tint * Polish.fury(int(h.hp))   # última vida: pulsa avermelhado
	var stuckish: bool = h.st == "stuck" or (h.st == "down" and h.get("skin", "") == "bat")
	var y: float = h.y - (6 if stuckish else 50)
	# inclinação do mergulho entra e sai aos poucos (no passo da lógica); o corpo sobe a cada batida de asa
	if Polish.FRESH:
		h._rot = lerpf(float(h.get("_rot", 0.0)), rot, .2)
	rot = float(h.get("_rot", rot))
	if h.st in ["circle", "rise", "flee", "mark"] and h.get("skin", "hawk") != "bat":
		y += -sin(T * PI / 7.5) * 4.0
	var hsx := 1.0
	var hsy := 1.0
	var lt: int = int(h.get("landT", 0))
	if lt > 0:
		# cravou no chão: achata com o impacto
		var u: float = lt / 12.0
		hsx = 1.0 + .2 * u
		hsy = 1.0 - .2 * u
	var hfs: float = Spr.eturn(h, .16)
	if h.get("skin", "hawk") == "bat":
		# Morcego-Rei: o morcego pintado bem grande, asas batendo, olhos vermelhos brilhando
		var bf: int = [0, 1, 2, 1][(T / 4) % 4]
		if stuckish:
			bf = 2
		elif h.st in ["dive", "fall"]:
			bf = 0
		# ofuscado: bate as asas rápido e sem rumo
		if h.st == "dazzle":
			bf = [0, 1, 2, 1][(T / 2) % 4]
		# o corpo sobe a cada batida de asa (para baixo) e vira girando no ar
		var flap: float = 0.0 if (stuckish or h.st in ["dive", "fall"]) else -sin(T * PI / 8.0) * 5.0
		var mrt: Texture2D = Spr.opt("morcego_rei")
		# no escuro (longe das lamparinas e da lanterna) ele vira só um vulto
		var bvis: float = float(h.get("vis", 1.0))
		Spr.save()
		# no mergulho desce até as garras tocarem o chão (a caixa de dano acompanha: Kings.bat_drop)
		Spr.translate(h.x, y - 34 + flap + K.bat_drop())
		Spr.rotate(rot * .6)
		Spr.scale(hfs * hsx, hsy * Spr.tsy(h))
		if mrt:
			# arte própria: 0-2 batendo as asas, 3 mergulho, 4 tonto (coroa e olhos já desenhados)
			var mf: int = bf
			if h.st in ["dive", "fall"]:
				mf = 3
			elif stuckish:
				mf = 4
			var MW := 270.0
			var MH := 306.0
			if stuckish:
				# tonto com as garras cravadas no chão: o quadro 4 (pendurado) de cabeça para cima,
				# pés no chão e asas erguidas (a coroa e o rosto ficam do lado certo)
				Spr.save()
				Spr.translate(0, h.gy + 2 - (y - 34))
				Spr.scale(1, -1)
				Spr.ci.draw_texture_rect_region(mrt, Rect2(-.55 * MW, -64 * MH / 340.0, MW, MH), Rect2(mf * 300, 0, 300, 340), Color(tint.r, tint.g, tint.b, Spr.alpha * bvis))
				Spr.restore()
			elif h.st in ["dive", "fall"]:
				Spr.ci.draw_texture_rect_region(mrt, Rect2(-.55 * MW, -62 - .41 * MH, MW, MH), Rect2(mf * 300, 0, 300, 340), Color(tint.r, tint.g, tint.b, Spr.alpha * bvis))
			else:
				Spr.region_mix(mrt, Rect2(-.55 * MW, -62 - .41 * MH, MW, MH), 300, 340, [0, 1, 2, 1], T / 4.0, Color(tint.r, tint.g, tint.b, Spr.alpha * bvis))
			Spr.restore()
			Spr.glow(h.x, y - 92, 40, Color(1, .2, .1, .12 * bvis))
		else:
			var bn: String = "bat%d" % bf
			var bh: float = Spr.PH(bn, 230)
			Spr.PR(bn, -115, -bh / 2, 230, bh, tint)
			Spr.restore()
			for ex in [-12, 12]:
				Spr.glow(h.x + ex, y - 40, 16, Color(1, .2, .1, .55))
				Spr.circle(h.x + ex, y - 40, 3, Color(1, .35, .25))
			_crown(h.x, y - 96, 1.2)
	else:
		Spr.save()
		Spr.translate(h.x, y)
		Spr.rotate(rot)
		Spr.scale(hfs * sc * hsx, sc * hsy * Spr.tsy(h))
		if h.st == "dive":
			Spr.ci.draw_texture_rect_region(Spr.tex.gaviao, Rect2(-66, -96, 132, 124), Rect2(fr * 132, 0, 132, 124), Color(tint.r, tint.g, tint.b, Spr.alpha))
		else:
			# asas: preso no chão bate rápido, mirando bate médio, voando bate devagar
			var hsp: float = 3.0 if h.st == "stuck" else (4.0 if h.st == "mark" else 5.0)
			Spr.region_mix(Spr.tex.gaviao, Rect2(-66, -96, 132, 124), 132, 124, [0, 1, 2], T / hsp, Color(tint.r, tint.g, tint.b, Spr.alpha))
		# coroa presa no alto da cabeça (no mesmo transform do corpo: acompanha o mergulho, a virada e o
		# achatar); balança a cada golpe recebido e cai na derrota
		if h.st != "flee":
			crown_art("gaviao", 26, -49, .62, sin(float(h.red) * .7) * .4 * float(h.red) / 30.0, T)
		Spr.restore()
	if h.st == "stuck":
		# garras presas na madeira
		for i in 3:
			Spr.seg(h.x - 10 + i * 10, h.gy - 4, h.x - 8 + i * 10, h.gy + 6, Color("#3a2414"), 3)
		if (T / 10) % 2 == 0:
			Spr.text("!", h.x, (h.gy - 206) if h.get("skin", "hawk") == "bat" else (y - 150), 30, Color("#ffe27a"), HORIZONTAL_ALIGNMENT_CENTER, Spr.font_b, 5)
	if h.st == "flee" or (stuckish and h.st == "down") or h.st == "dazzle":
		for i in 3:
			var a := T * .15 + TAU * i / 3.0
			Spr.text("★", h.x + cos(a) * 40, y - 120 + sin(a) * 10, 16, Color("#ffe27a"), HORIZONTAL_ALIGNMENT_CENTER, Spr.font_b, 3)

static func _fish(g: Game, K: Kings, T: int) -> void:
	var f: Dictionary = K.FISH
	if f.get("skin", "") == "frog" and f.has("hives"):
		# Sapo-Rei na vitória-régia gigante (Ep. 2): colmeias, língua e mira
		WorldEp2.frog(g, K, T)
		return
	if f.is_empty() or f.done and f.st != "down":
		return
	if f.st == "wait":
		return
	# lama revolvida
	if f.mud > .02:
		for i in 9:
			var mx: float = f.x0 + (f.x1 - f.x0) * (i + .5) / 9.0 + sin(T * .02 + i) * 30
			var my: float = f.y1 - 60 - (i % 3) * 70 + cos(T * .03 + i * 2) * 20
			Spr.circle(mx, my, 120 + (i % 2) * 40, Color(.32, .26, .14, .28 * f.mud))
	var fr: int = (T / 7) % 4
	match f.st:
		"suck":
			if f.mouth > .3:
				fr = 4
		"tired":
			fr = 5
		"down":
			fr = 6
	var a: float = f.al * (clamp(1.0 - f.t / 160.0, 0, 1) if f.st == "down" else 1.0)
	var tint := Color(1, .55, .5) if f.red > 0 and (T / 3) % 2 == 0 else Color(1, 1, 1)
	tint = tint * Polish.fury(int(f.hp))   # última vida: pulsa avermelhado
	# nada com o corpo: inclina para onde sobe/desce, estica no bote, encolhe ao mirar e achata ao bater
	# (a inclinação anda no passo da lógica: em telas de 90/120 Hz não fica tremendo)
	if Polish.FRESH:
		var fvy: float = f.y - float(f.get("_py", f.y))
		f._py = f.y
		f._pt = lerpf(float(f.get("_pt", 0.0)), clamp(fvy * .05, -.18, .18), .1)
	var fsx := 1.0
	var fsy := 1.0
	if f.st == "charge":
		var cu: float = clamp(abs(float(f.get("vx", 0.0))) / 9.0, 0, 1)
		fsx = 1.0 + .1 * cu
		fsy = 1.0 - .07 * cu
	elif f.st == "aim" and f.t >= 28:
		var au: float = clamp((f.t - 28) / 16.0, 0, 1)
		fsx = 1.0 - .08 * au
		fsy = 1.0 + .05 * au
	var fh: int = int(f.get("hitT", 0))
	if fh > 0:
		fsx *= 1.0 - .18 * fh / 16.0
		fsy *= 1.0 + .1 * fh / 16.0
	Spr.save()
	Spr.translate(f.x, f.y + (sin(T * .06) * 3.0 if f.st != "down" else 0.0))
	var ffs: float = Spr.eturn(f, .1)
	Spr.rotate(float(f.get("_pt", 0.0)) * sign(ffs) if f.st != "down" else 0.0)
	Spr.scale(ffs * fsx, fsy * Spr.tsy(f))
	if f.get("skin", "fish") == "frog" and Spr.tex.has("en_frog2"):
		# Sapo-Rei nadando: o sapo pintado bem grande, pernas batendo; boca aberta quando suga
		var ff: int = 0 if f.st in ["tired", "down"] else (3 if f.st == "suck" and f.mouth > .3 else [1, 2][(T / 8) % 2])
		var kick: float = sin(T * .25) * .06 if f.st != "tired" else 0.0
		Spr.rotate(kick)
		var srt: Texture2D = Spr.opt("sapo_rei")
		if srt:
			# arte própria do Sapo-Rei (coroa já desenhada); as pernas batem trocando os quadros 1 e 2
			if ff in [1, 2]:
				Spr.region_mix(srt, Rect2(-160, -104, 320, 180), 320, 180, [1, 2], T / 8.0, Color(tint.r, tint.g, tint.b, Spr.alpha * a))
			else:
				Spr.ci.draw_texture_rect_region(srt, Rect2(-160, -104, 320, 180), Rect2(ff * 320, 0, 320, 180), Color(tint.r, tint.g, tint.b, Spr.alpha * a))
		else:
			Spr.ci.draw_texture_rect_region(Spr.tex.en_frog2, Rect2(-150, -95, 300, 162), Rect2(ff * 130, 0, 130, 70), Color(tint.r * .8, tint.g, tint.b * .75, Spr.alpha * a))
			_crown(18, -88, 1.1)
	elif f.st == "charge" and Spr.opt("fish_bite"):
		# bote: boca escancarada, dentes à mostra
		Spr.ci.draw_texture_rect(Spr.opt("fish_bite"), Rect2(-140, -80, 280, 160), false, Color(tint.r, tint.g, tint.b, Spr.alpha * a))
	else:
		if fr < 4 and not f.st in ["suck", "tired", "down"]:
			Spr.region_mix(Spr.tex.bagre, Rect2(-140, -80, 280, 160), 280, 160, [0, 1, 2, 3], T / 7.0, Color(tint.r, tint.g, tint.b, Spr.alpha * a))
		else:
			Spr.ci.draw_texture_rect_region(Spr.tex.bagre, Rect2(-140, -80, 280, 160), Rect2(fr * 280, 0, 280, 160), Color(tint.r, tint.g, tint.b, Spr.alpha * a))
	# coroa de pérolas por cima da coroa pintada (acompanha a troca de quadros, como as escamas)
	if f.get("skin", "fish") != "frog" and f.st != "down" and not K.DROPPED.has("bagre"):
		var ca: Vector2 = K.FISH_CROWN.get(fr, K.FISH_CROWN[0])
		if f.st == "charge" and Spr.opt("fish_bite"):
			ca = K.FISH_CROWN["bite"]
		elif fr < 4 and not f.st in ["suck", "tired", "down"]:
			var cyc2: float = T / 7.0
			var c02: int = int(floor(cyc2))
			var cu3: float = floor((cyc2 - c02) * 4.0) / 4.0
			ca = (K.FISH_CROWN[posmod(c02, 4)] as Vector2).lerp(K.FISH_CROWN[posmod(c02 + 1, 4)], cu3)
		crown_cover("bagre", ca, 0.0, 1.0, T)
	# escamas azuis = pontos fracos: brilham quando ele cansa; as que já caíram viram marca escura.
	# Desenhadas no mesmo transform do corpo, em cima das escamas pintadas do quadro que está na tela
	# (nadando, as posições acompanham a troca de quadros)
	if f.st != "down":
		var lp: Array = K.scale_local(fr)
		if f.get("skin", "fish") != "frog":
			if f.st == "charge" and Spr.opt("fish_bite"):
				lp = K.scale_local("bite")
			elif fr < 4 and not f.st in ["suck", "tired", "down"]:
				var cyc: float = T / 7.0
				var c0: int = int(floor(cyc))
				var la: Array = K.scale_local(posmod(c0, 4))
				var lb: Array = K.scale_local(posmod(c0 + 1, 4))
				# a folha x4 troca em 4 passos por quadro: as escamas andam junto
				var cu: float = floor((cyc - c0) * 4.0) / 4.0
				lp = []
				for i in 4:
					lp.append(la[i].lerp(lb[i], cu))
		for i in 4:
			var p: Vector2 = lp[i]
			if not f.scales[i]:
				Spr.ellipse(p.x, p.y, 7, 6, Color(.24, .22, .12, a))
				Spr.seg(p.x - 4, p.y - 3, p.x + 4, p.y + 3, Color(.08, .06, .03, a), 1.5)
			elif f.st == "tired":
				Spr.glow(p.x, p.y, 24 + sin(T * .3 + i) * 4, Color(.55, 1, 1, .6 * a))
				Spr.ellipse(p.x, p.y, 6, 5, Color(.75, 1, 1, a))
	Spr.restore()
	# sucção: linhas de água entrando na boca
	if f.st == "suck" and f.t > 30:
		var mx2: float = f.x + f.dir * 118
		for i in 6:
			var u: float = fmod(T * .04 + i / 6.0, 1.0)
			var r: float = 160 * (1.0 - u)
			var ang: float = (i - 2.5) * .25
			Spr.seg(mx2 + f.dir * cos(ang) * r, f.y + sin(ang) * r, mx2 + f.dir * cos(ang) * (r - 26), f.y + sin(ang) * (r - 26), Color(.8, .95, 1, .5), 2)
	# aviso da sucção: a boca começa a abrir e a água em volta gira para dentro antes de puxar
	if f.st == "suck" and f.t <= 30:
		var mx3: float = f.x + f.dir * 118
		var k3: float = 1.0 - f.t / 30.0
		Spr.ring(mx3, f.y + 6, 30 + 90 * k3, Color(.8, .95, 1, .55 * (1.0 - k3) + .15), 3)
		Spr.ring(mx3, f.y + 6, 20 + 50 * k3, Color(.8, .95, 1, .4), 2)
		if (T / 6) % 2 == 0:
			Spr.text("!", f.x, f.y - 100, 32, Color("#ff6a4a"), HORIZONTAL_ALIGNMENT_CENTER, Spr.font_b, 5)
	if f.st == "aim" and (T / 6) % 2 == 0:
		Spr.text("!", f.x, f.y - 100, 32, Color("#ff6a4a"), HORIZONTAL_ALIGNMENT_CENTER, Spr.font_b, 5)

## portões de pedra das arenas
static func _hh(x: float, k: int) -> float:
	var v := sin(x * 12.9898 + k * 78.233) * 43758.5453
	return v - floor(v)

## faixa de altura visível na tela (quem desenha os muros acerta antes): as fileiras do muro alto
## do urso que ficam bem acima da tela não são desenhadas (o muro tem 900 px de altura)
static var vy0 := -1e9
static var vy1 := 1e9
static func set_view(g) -> void:
	vy0 = g.cam_y - 150.0
	vy1 = g.cam_y + g.H + 150.0

## muro de pedra pintada que fecha a arena do chefe: sobe do chão fileira por fileira levantando
## poeira, com a base enterrada num monte de terra/neve; quando o chefe perde, afunda de novo
static func gate(s: Dictionary, T: int, sink: float = -1.0) -> void:
	if not s.has("rt0"):
		s.rt0 = T
	var rise: float = clamp((T - int(s.rt0)) / 34.0, 0, 1) if sink < 0 else 1.0 - sink
	var bot: float = s.y + s.h
	var vis_top: float = bot - s.h * rise
	var cx: float = s.x + s.w * .5
	var wx: float = s.x - 14
	var ww: float = s.w + 28
	var snow: bool = s.y + s.h <= 520 and s.x > 32000 and s.x < 56000
	# as pedras de cada fileira são sempre as mesmas: calculadas uma vez e guardadas no muro
	# (antes eram ~4 ruídos e um nome montado por pedra a cada quadro; o muro do urso tem 900 px)
	var rows: Array = s.get("_gc", [])
	if rows.is_empty():
		rows = _gate_rows(s, wx, ww, bot, snow)
		s._gc = rows
	for r in rows:
		var top: float = r[0]
		var yy: float = r[1]
		if top < vis_top - 2 or yy < vy0 or top > vy1:
			continue
		Spr.rr(wx - 3, top - 2, ww + 6, yy - top + 4, 10, Color(.16, .12, .09, .95))
		for st in r[2]:
			Spr.PR(st[0], st[1], st[2], st[3], st[4], st[5], st[6])
		# neve no alto de cada pedra de cima
		if snow and top < vis_top + r[3]:
			Spr.rr(wx - 2, top - 5, ww + 4, 9, 5, Color(.96, .98, 1))
	# poeira subindo enquanto o muro sobe ou afunda
	if (rise > 0 and rise < 1) and T % 2 == 0:
		for k in 2:
			Spr.circle(cx + randf_range(-ww * .7, ww * .7), bot - randf() * 16, 5 + randf() * 8, Color(.75, .68, .58, .45) if not snow else Color(.95, .97, 1, .7))
	# base enterrada: monte de terra (ou neve) cobrindo o pé do muro
	var mc := Color("#5a4028") if not snow else Color(.93, .96, 1)
	Spr.ellipse(cx, bot + 2, ww * .85, 13, mc)
	Spr.ellipse(cx - 6, bot - 2, ww * .55, 8, mc.lightened(.12))
	for k in 3:
		Spr.P("peb%d" % k, cx - ww * .6 + k * ww * .55, bot + 6, 14, k == 1)

## fileiras do muro: [topo, base, pedras [nome, x, y, w, h, cor, espelhada], altura da fileira]
static func _gate_rows(s: Dictionary, wx: float, ww: float, bot: float, snow: bool) -> Array:
	var rows: Array = []
	var yy: float = bot - 4
	var row := 0
	while yy > s.y + 2:
		var bh: float = 28.0 + _hh(s.x + row, 33) * 16.0
		var top: float = max(s.y, yy - bh)
		var u: float = clamp((bot - yy) / max(1.0, s.h), 0, 1)
		var stones: Array = []
		var x: float = wx
		var i := 0
		while x < wx + ww - 8:
			var bw: float = (yy - top) * (1.0 + _hh(s.x + row * 13 + i, 34) * .7)
			if wx + ww - (x + bw) < 14:
				bw = wx + ww - x
			var m: float = .95 - u * .12 + (_hh(s.x + row * 3 + i, 36) - .5) * .12
			var col := Color(m, m * .97, m * .93) if not snow else Color(m * .92, m * .96, m * 1.06)
			stones.append(["wb%d" % int(_hh(s.x + row * 5 + i * 11, 37) * 6), x - 3, top - 3, bw + 6, yy - top + 6, col, _hh(s.x + i + row, 38) > .5])
			x += bw
			i += 1
		rows.append([top, yy, stones, bh])
		yy -= bh
		row += 1
	return rows

## muros que afundam depois da luta
static func sinking(g: Game, T: int) -> void:
	var K = g.K
	if K == null:
		return
	set_view(g)
	var keep: Array = []
	for s in K.SINK:
		var u: float = (T - int(s.st0)) / 40.0
		if u < 1.0:
			keep.append(s)
			if s.x > g.cam - 100 and s.x < g.cam + g.W + 100:
				gate(s, T, u)
				if T % 2 == 0:
					Spr.circle(s.x + s.w * .5 + randf_range(-30, 30), s.y + s.h - randf() * 14, 6 + randf() * 8, Color(.8, .74, .64, .5))
	K.SINK = keep

## centro da coroa pintada em cada quadro do urso.png (x, y em relação aos pés, olhando para a direita, e
## a inclinação): a coroa de gelo (ou o monte de neve, depois que ela cai) é desenhada por cima
const BEAR_CROWN := [Vector3(81, -131, .05), Vector3(82, -129, .05), Vector3(-6, -195, 0), Vector3(55, -131, .35), Vector3(20, -137, 0), Vector3(105, -57, .6)]

## coroa por cima da coroa pintada (cv = centro da pintada, rotação, escala): um fundo largo na cor da coroa
## cobre as pontas douradas e a coroa nova vem por cima
static func crown_cover(kind: String, cv: Vector2, rot: float, s: float, T: int, wob: float = 0.0) -> void:
	var base: Vector2 = cv + Vector2(0, 12.0 * s / 1.3).rotated(rot)
	Spr.save()
	Spr.translate(base.x, base.y)
	Spr.rotate(rot + wob)
	Spr.scale(s, s)
	var bc := Color("#b8d8f0") if kind == "urso" else Color("#2c7480")
	var oc := Color("#2c5578") if kind == "urso" else Color("#0e2e36")
	Spr.ellipse(0, -14, 24.2, 18.2, oc)
	Spr.ellipse(0, -14, 23, 17, bc)
	Spr.restore()
	crown_art(kind, base.x, base.y, s, rot + wob, T)

## monte de neve na cabeça do urso (caiu da rocha quando ele entalou)
static func snow_lump(cv: Vector2, rot: float, T: int) -> void:
	Spr.save()
	Spr.translate(cv.x, cv.y)
	Spr.rotate(rot)
	var ol := Color("#5a7898")
	Spr.ellipse(0, 2, 27, 15, ol)
	Spr.ellipse(-8, -8, 17, 14, ol)
	Spr.ellipse(9, -6, 16, 13, ol)
	Spr.ellipse(0, 2, 25.5, 13.5, Color("#dce8f6"))
	Spr.ellipse(-8, -8, 15.5, 12.5, Color("#f4f8ff"))
	Spr.ellipse(9, -6, 14.5, 11.5, Color("#eef4fc"))
	Spr.ellipse(-11, -12, 6, 4, Color(1, 1, 1, .9))
	Spr.ellipse(5, 8, 16, 4, Color(.62, .74, .9, .5))
	# floquinhos caindo da cabeça
	for k in 2:
		var u: float = fmod(T * .02 + k * .5, 1.0)
		Spr.circle(-18 + k * 34, 6 + u * 40, 1.6, Color(1, 1, 1, .8 * (1.0 - u)))
	Spr.restore()

## Urso-Pardo-Rei (arte em assets/sprites/urso.png: 0-1 andando, 2 em pé, 3 patada, 4 tonto, 5 derrotado)
static func _bear(g: Game, K: Kings, T: int) -> void:
	var b: Dictionary = K.BEAR
	if b.is_empty():
		return
	var cx0: float = g.cam - 400
	var cx1: float = g.cam + g.W + 400
	var rk: Dictionary = b.rock
	if float(rk.x) + 400 < cx0 or float(b.den) - 300 > cx1:
		return
	_bear_obs(g, K, T)
	if not (b.done or b.st == "wait"):
		_bear_body(g, K, T)
	_bear_rock(g, K, T)

## troncos e galho do caminho (arrebentados somem: os pedaços voam no passo da lógica)
static func _bear_obs(g: Game, K: Kings, T: int) -> void:
	for o in K.BOBS:
		if o.x > g.cam + g.W + 200 or o.x + o.w < g.cam - 200:
			continue
		var fallen: bool = o.get("fallen", false)
		match o.k:
			"log":
				if not fallen:
					Spr.ellipse(o.x + o.w / 2.0, o.y + o.h + 2, o.w * .62, 6, Color(0, 0, 0, .22))
					WorldNature.prop("tora_neve", o.x + o.w / 2.0, o.y + o.h + 5, o.h + 18)
				else:
					_splinters(o.x + o.w / 2.0, o.y + o.h)
			"logs":
				if not fallen:
					Spr.ellipse(o.x + o.w / 2.0, o.y + o.h + 2, o.w * .7, 6, Color(0, 0, 0, .22))
					WorldNature.prop("tora_neve", o.x + o.w / 2.0, o.y + o.h + 5, 44, false)
					WorldNature.prop("tora_neve", o.x + o.w / 2.0 + 4, o.y + 32, 40, true)
				else:
					_splinters(o.x + o.w / 2.0, o.y + o.h)
			"branch":
				# tronco atravessado em cima de duas pedras (as pedras ficam atrás, do lado do caminho):
				# só passa abaixado por baixo, ou pulando por cima
				var pt: Texture2D = Spr.opt("p_pedra_neve")
				var lt: Texture2D = Spr.opt("p_tora_neve")
				if pt:
					for sd in [-1.0, 1.0]:
						var rx2: float = o.x + o.w / 2.0 + sd * (o.w / 2.0 + 8.0)
						Spr.ci.draw_texture_rect(pt, Rect2(rx2 - 34, o.y + o.h + 6 - 62, 68, 62), sd > 0, Color(.72, .78, .9, Spr.alpha))
				if not fallen:
					Spr.ellipse(o.x + o.w / 2.0, o.y + o.h + 26, o.w * .6, 4, Color(0, 0, 0, .18))
					if lt:
						Spr.ci.draw_texture_rect(lt, Rect2(o.x - 34, o.y + o.h + 4 - 66, o.w + 68, 66), false, Color(1, 1, 1, Spr.alpha))
				else:
					_splinters(o.x + o.w / 2.0, o.y + o.h + 26)
		if not fallen and o.has("crawl"):
			_duck_hint(g, o.x + o.w / 2.0, o.y - 40, abs(g.player.x + g.player.w / 2 - (o.x + o.w / 2.0)) < o.w / 2.0 + 170, T)

static func _splinters(x: float, y: float) -> void:
	for k in 4:
		var sx: float = x - 30 + k * 20
		Spr.poly(PackedVector2Array([Vector2(sx - 6, y + 2), Vector2(sx + 7, y + 2), Vector2(sx + 2, y - 6 - (k % 2) * 4)]), Color("#6a4528"))
	Spr.ellipse(x, y + 1, 40, 5, Color(.95, .97, 1))

## ícone de "abaixe" (o desenho da passagem cobre o ícone comum)
static func _duck_hint(g: Game, cx: float, iy: float, near: bool, T: int) -> void:
	if not near or g.player.crouch:
		return
	var by: float = iy + sin(T * .15) * 4
	Spr.circle(cx, by, 22, Color(0, 0, 0, .35))
	Spr.ci.draw_texture_rect(Spr.tex.pad_S, Rect2(cx - 18, by - 18, 36, 36), false, Color(1, 1, 1, .95))
	Spr.text("abaixe", cx, by + 34, 13, Color(1, .93, .7, .9), HORIZONTAL_ALIGNMENT_CENTER, Spr.font_b, 3)

## a rocha com a fresta embaixo (o urso não cabe), a laje com os pingentes e os avisos
static func _bear_rock(g: Game, K: Kings, T: int) -> void:
	var b: Dictionary = K.BEAR
	var rx: float = float(b.rock.x)
	var rw: float = float(b.rock.w)
	var gy: float = b.gy
	if rx - 420 > g.cam + g.W + 100 or rx + rw + 160 < g.cam - 100:
		return
	var ry: float = float(b.rock.y) + float(b.rock.h)   # teto da fresta
	var pk := "pedra_neve"
	# pés da rocha (encostados atrás, dos dois lados da fresta)
	WorldNature.prop(pk, rx - 26, gy + 6, 58, false, 1.0)
	WorldNature.prop(pk, rx + rw + 30, gy + 6, 64, true, 1.0)
	# coluna de pedras empilhadas, de cima para baixo (a de baixo por último: o teto da fresta)
	WorldNature.prop(pk, rx + rw * .5 + 6, 150, 230, true)
	WorldNature.prop(pk, rx + rw * .5 - 4, 330, 210, false)
	# laje para a esquerda, de onde pendem os pingentes
	var iy: float = float(b.get("iciY", 300))
	WorldNature.prop(pk, rx - 150, iy + 14, 150, true)
	WorldNature.prop(pk, rx - 26, iy + 30, 170, false)
	# a pedra de baixo: o fundo arredondado dela é o teto da fresta
	WorldNature.prop(pk, rx + rw * .5, ry + 10, 200, true)
	# pingentes (tremem antes de cair; a sombra no chão mostra onde)
	for c in K.ICI:
		if c.st == "gone":
			continue
		var wob: float = 0.0
		if c.st == "shake":
			wob = sin(T * 1.7) * 2.0
		elif int(c.get("wob", 0)) > 0:
			wob = sin(T * 1.3) * 1.2
			if Polish.FRESH:
				c.wob = int(c.wob) - 1
		var tip: float = c.y + float(c.len)
		if c.st in ["shake", "fall"]:
			var k: float = clamp((tip - float(c.y0)) / max(1.0, gy - float(c.y0)), 0.0, 1.0) if c.st == "fall" else clamp(c.t / 30.0, .2, .6)
			var pul: float = .8 + .2 * sin(T * .5)
			Spr.ellipse(c.x, gy + 1, 22 * (.6 + k * .6) * pul, 5, Color(0, 0, 0, .25 + .35 * k))
			Spr.ring(c.x, gy - 1, 20 * (.6 + k * .6) * pul, Color(1, .3, .2, .5 + .4 * k), 2.5, PI, TAU)
		var x: float = c.x + wob
		Spr.poly(PackedVector2Array([Vector2(x - 8, c.y - 4), Vector2(x + 8, c.y - 4), Vector2(x + 1.5, tip), Vector2(x - 1.5, tip)]), Color("#2c5578"))
		Spr.poly(PackedVector2Array([Vector2(x - 6.5, c.y - 3), Vector2(x + 6.5, c.y - 3), Vector2(x + .8, tip - 2), Vector2(x - .8, tip - 2)]), Color(.78, .9, 1, .95))
		Spr.poly(PackedVector2Array([Vector2(x - 5, c.y - 2), Vector2(x - 1, c.y - 2), Vector2(x, tip - 6)]), Color(1, 1, 1, .7))
	# a fresta: sombra funda e um brilho na borda (o ícone de abaixar fica por cima de tudo)
	var p: Dictionary = g.player
	var pcx: float = p.x + p.w / 2
	_duck_hint(g, rx + rw * .5, ry - 70, pcx < rx + rw and pcx > rx - 220 and abs(p.y + p.h - gy) < 40, T)

static func _bear_body(g: Game, K: Kings, T: int) -> void:
	var b: Dictionary = K.BEAR
	var fr: int = int(b.anim * 2.0) % 2
	var rot := 0.0
	var dy := 0.0
	var warn := false
	var walk := false
	var bsx := 1.0
	var bsy := 1.0
	match b.st:
		"rear", "roar":
			fr = 2
			warn = b.st == "rear"
		"slam":
			fr = 3
		"taunt":
			fr = 2 if b.t > 6 and b.t < 28 else 0
		"crouch":
			fr = 0
			rot = .14
			dy = 10
			var cu: float = clamp(b.t / 12.0, 0, 1)
			bsx = 1.0 + .07 * cu
			bsy = 1.0 - .1 * cu
			warn = true
		"charge":
			walk = true
			rot = .17
			dy = 8
			bsx = 1.06
			bsy = .95
		"jam":
			if b.t < 26:
				fr = 0
				rot = .22
				dy = 6
				bsx = 1.0 - .08 * sin(b.t * .9)
			elif b.t <= 84:
				fr = 4
			else:
				walk = true
		"intro", "chase", "recover", "flee":
			walk = true
	var tint := Color(1, .55, .5) if b.red > 0 and (T / 3) % 2 == 0 else Color(1, 1, 1)
	var k: float = .35 + .25 * sin(T * .5)
	# avisos no chão: a mancha da patada, a seta da investida
	if b.st == "rear":
		var paw: Rect2 = K.bear_paw()
		Spr.ellipse(paw.position.x + paw.size.x / 2, b.gy + 1, paw.size.x / 2, 9, Color(1, .25, .15, k))
	if b.st == "crouch":
		var lx: float = K.bear_lunge_end()
		var x0: float = b.x + b.dir * 100
		Spr.seg(x0, b.gy - 3, lx, b.gy - 3, Color(1, .3, .15, k), 6)
		Spr.poly(PackedVector2Array([Vector2(lx + b.dir * 16, b.gy - 3), Vector2(lx - b.dir * 4, b.gy - 14), Vector2(lx - b.dir * 4, b.gy + 8)]), Color(1, .3, .15, k + .2))
	Spr.ellipse(b.x, b.gy + 2, 100, 12, Color(0, 0, 0, .28))
	# inclinação e agachar com peso (sem estalar de uma pose para a outra)
	if Polish.FRESH:
		b._rot = lerpf(float(b.get("_rot", 0.0)), rot, .2)
		b._dy = lerpf(float(b.get("_dy", 0.0)), dy, .22)
	rot = float(b.get("_rot", rot))
	dy = float(b.get("_dy", dy))
	if walk:
		# galope pesado: o corpo sobe e desce a cada passada
		dy -= abs(sin(b.anim * PI)) * (5.0 if b.st == "charge" else 3.0)
	var blt: int = int(b.get("landT", 0))
	if blt > 0:
		bsx *= 1.0 + .12 * blt / 12.0
		bsy *= 1.0 - .14 * blt / 12.0
	var shake_x: float = sin(T * 1.6) * 2.0 if b.st == "crouch" else 0.0
	Spr.save()
	Spr.translate(b.x + shake_x, b.gy + 2 + dy)
	if b.st in ["rear", "roar"]:
		Spr.translate(0, -sin(min(1.0, b.t / 16.0) * PI * .5) * 6)
	var fs: float = Spr.eturn(b, .15)
	Spr.scale(fs * bsx, bsy * Spr.tsy(b))
	if Spr.turned_now(b):
		WorldExtras.turn_dust(g, b.x, b.gy, b.dir, Color(.95, .97, 1, .8))
	Spr.rotate(rot)
	var mod := Color(tint.r, tint.g, tint.b, Spr.alpha)
	var ut: Texture2D = Spr.opt("urso")
	var cv: Vector3
	if walk:
		var ph: float = b.anim * 2.0
		Spr.region_mix(ut, Rect2(-140, -228, 280, 230), 280, 230, [0, 1], ph, mod)
		var f0: int = posmod(int(floor(ph)), 2)
		var cu2: float = floor((ph - floor(ph)) * 4.0) / 4.0
		var a0: Vector3 = BEAR_CROWN[f0]
		var a1: Vector3 = BEAR_CROWN[1 - f0]
		cv = a0.lerp(a1, cu2)
	else:
		Spr.ci.draw_texture_rect_region(ut, Rect2(-140, -228, 280, 230), Rect2(fr * 280, 0, 280, 230), mod)
		cv = BEAR_CROWN[fr]
	# a coroa de gelo (ou o monte de neve, depois que ela caiu)
	if b.get("crown", true):
		crown_cover("urso", Vector2(cv.x, cv.y), cv.z, 1.3, T)
	elif b.get("lump", false):
		snow_lump(Vector2(cv.x, cv.y - 2), cv.z, T)
	Spr.restore()
	if b.st == "jam" and b.t < 26:
		# neve caindo da rocha em cima dele
		for i in 3:
			Spr.circle(float(b.rock.x) - 10 + i * 14, b.gy - 160 + fmod(T * 3.0 + i * 40, 120.0), 3, Color(1, 1, 1, .85))
	if b.st == "rear":
		Spr.glow(b.x + b.dir * 62, b.gy - 176, 34 + 6 * k, Color(1, .45, .2, .55 + .3 * k))
	if b.st == "charge":
		for i in 4:
			var ly: float = b.gy - 30 - i * 22
			Spr.seg(b.x - b.dir * (110 + i * 6), ly, b.x - b.dir * (170 + i * 10), ly, Color(1, 1, 1, .55), 3)
	if b.st == "jam" and b.t > 26 and b.t <= 84:
		for i in 3:
			var a := T * .12 + TAU * i / 3.0
			Spr.text("★", b.x + 10 + cos(a) * 34, b.gy - 160 + sin(a) * 8, 16, Color("#ffe27a"), HORIZONTAL_ALIGNMENT_CENTER, Spr.font_b, 3)
	if warn and (T / 6) % 2 == 0:
		Spr.text("!", b.x, b.gy - 240, 34, Color("#ff6a4a"), HORIZONTAL_ALIGNMENT_CENTER, Spr.font_b, 5)

## coroas caídas (brilhando no chão) e a que o Tomé está erguendo
static func draw_crowns(g: Game, T: int) -> void:
	var K: Kings = g.K
	if K == null or K.CROWNS.is_empty():
		return
	for c in K.CROWNS:
		if c.x < g.cam - 120 or c.x > g.cam + g.W + 120:
			continue
		var x: float = c.x
		var y: float = c.y
		var s := 1.25
		Spr.save()
		if c.st == "rest":
			y -= 4.0 + sin(T * .08) * 3.0
			var pul: float = .7 + .3 * sin(T * .12)
			Spr.ellipse(c.x, c.y + 1, 26, 5, Color(0, 0, 0, .25))
			Spr.glow(x, y - 16, 64 * pul, Color(1, .85, .4, .35))
			Spr.glow(x, y - 16, 34, Color(1, .95, .7, .4))
			# raios girando atrás
			for i in 6:
				var a: float = T * .02 + TAU * i / 6.0
				Spr.seg(x + cos(a) * 18, y - 16 + sin(a) * 18, x + cos(a) * (40 + 6 * pul), y - 16 + sin(a) * (40 + 6 * pul), Color(1, .92, .6, .35), 3)
			if Polish.FRESH and T % 9 == 0:
				Polish.part("spark", x + randf_range(-24, 24), y - randf_range(0, 36), 0, -.5, 30, Color(1, .9, .5), {"g": 0.0})
		elif c.st == "lift":
			var u: float = clamp(c.t / 16.0, 0, 1)
			s = 1.25 + .35 * u + (sin(c.t * .25) * .06 if u >= 1.0 else 0.0)
			Spr.glow(x, y - 18, 70, Color(1, .88, .45, .5 * u))
			if c.t > 60:
				Spr.alpha *= clamp(1.0 - (c.t - 60) / 14.0, 0, 1)
		elif c.water:
			Spr.glow(x, y - 14, 40, Color(.7, 1, 1, .3))
		crown_art(str(c.id), x, y, s, c.rot, T)
		Spr.restore()
