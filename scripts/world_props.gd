extends RefCounted
class_name WorldProps
## Desenho dos objetos com física (barco e mesa) — vistos de lado, no mesmo traço do cenário.

const WOOD := Color("#7a5232")
const WOOD_D := Color("#4e331d")
const WOOD_L := Color("#a87a4c")
const OUT := Color("#2a1a0e")

static func draw(g: Game, T: int) -> void:
	var PR: Props = g.PR
	if PR == null:
		return
	if not PR.BOAT.is_empty() and PR.BOAT.x + 200 > g.cam and PR.BOAT.x - 200 < g.cam + g.W:
		_boat(PR.BOAT, T)
	if not PR.TABLE.is_empty() and PR.TABLE.x + 200 > g.cam and PR.TABLE.x - 200 < g.cam + g.W:
		_table(PR.TABLE)
	for pp in PR.PAPERS:
		# (só os papéis na tela)
		if pp.x > g.cam - 40 and pp.x < g.cam + g.W + 40:
			_paper(pp)

static func _boat(b: Dictionary, T: int) -> void:
	var x: float = b.x
	var y: float = b.get("vis_y", b.y)
	var w: float = b.w
	var hh: float = Props.BOAT_HULL
	# poste de amarrar e a corda
	var px: float = b.post[0]
	var py: float = b.post[1]
	Spr.rr(px - 5, py - 40, 10, 42, 3, WOOD_D)
	Spr.rect(px - 7, py - 42, 14, 5, WOOD)
	var bow := Vector2(x - 2, y + 5)
	var pts := PackedVector2Array()
	for i in 13:
		var u := i / 12.0
		var a := Vector2(px, py - 30).lerp(bow, u)
		a.y += sin(u * PI) * (18 + sin(T * .04) * 2)
		pts.push_back(a)
	Spr.line(pts, Color("#c9b48a"), 2)
	Spr.save()
	# balança na água (e afunda um pouco com o Tomé em cima)
	var rock: float = sin(T * .045 + x * .01) * .025
	Spr.translate(x + w / 2, y + hh)
	Spr.rotate(b.ang + rock)
	if Spr.has("p_boat"):
		# barquinho pintado (proa para o lado do poste)
		var hp: float = hh * 2.37
		var wp: float = hp * Spr.AR["p_boat"][2] / Spr.AR["p_boat"][3]
		Spr.P("boat", 5, hp * .18, wp, true)
		# reflexo/sombra na água logo abaixo
		Spr.ellipse(0, 2, w * .5, 3, Color(0, .05, .1, .25))
	else:
		Spr.translate(-w / 2, -hh)
		var hull := PackedVector2Array([Vector2(-6, -4), Vector2(4, 6), Vector2(16, hh - 4), Vector2(30, hh), Vector2(w - 30, hh),
			Vector2(w - 14, hh - 5), Vector2(w - 2, 4), Vector2(w + 6, -6), Vector2(w - 4, 2), Vector2(w / 2, 6), Vector2(6, 2)])
		Spr.poly(hull, WOOD)
		Spr.line(hull, OUT, 2)
	Spr.restore()

static func _table(t: Dictionary) -> void:
	var W: float = Props.TABLE_W
	var H: float = Props.TABLE_H
	Spr.save()
	# gira em torno do pé do lado para onde tomba
	var pvx: float = t.x + (W if t.dir > 0 else 0.0)
	var pvy: float = t.y + H
	if t.st == "up":
		Spr.ellipse(t.x + W / 2, t.y + H + 1, W * .55, 4, Color(0, 0, 0, .25))
	Spr.translate(pvx, pvy)
	Spr.rotate(t.ang)
	Spr.translate(-pvx + t.x, -pvy + t.y)
	# pernas e travessa
	Spr.rect(8, 9, 8, H - 9, WOOD_D)
	Spr.rect(W - 16, 9, 8, H - 9, WOOD_D)
	Spr.rect(12, H * .62, W - 24, 5, WOOD_D)
	# tampo
	Spr.rr(-4, 0, W + 8, 11, 3, WOOD)
	Spr.rect(-4, 0, W + 8, 3, WOOD_L)
	Spr.seg(-4, 11, W + 4, 11, OUT, 1.5)
	# toalhinha caída de um lado
	Spr.poly(PackedVector2Array([Vector2(W - 34, 1), Vector2(W + 5, 1), Vector2(W + 6, 26), Vector2(W - 2, 22), Vector2(W - 10, 28), Vector2(W - 18, 9)]), Color("#b5463c"))
	Spr.restore()

static func _paper(pp: Dictionary) -> void:
	var c: Color = [Color("#e8604c"), Color("#3f8fd8"), Color("#f2c33c"), Color("#5cae4a"), Color("#a36ad1"), Color("#e8604c"), Color("#3f8fd8")][int(pp.c) % 7]
	Spr.save()
	Spr.translate(pp.x, pp.y)
	if pp.on == "ground":
		Spr.rotate(pp.r)
		Spr.poly(PackedVector2Array([Vector2(-9, 0), Vector2(9, 0), Vector2(8, -2.5 - pp.get("lift", 0.0) * .4), Vector2(-8, -2)]), Color("#f4eedf"))
		Spr.seg(-6, -1.2, 5, -1.6, c, 1)
	else:
		Spr.rotate(pp.r)
		Spr.rect(-8, -10, 16, 12, Color("#f4eedf"))
		Spr.line(PackedVector2Array([Vector2(-5, -6), Vector2(-1, -2), Vector2(3, -7), Vector2(5, -3)]), c, 1.5)
		Spr.ring(0, -5, 2.5, c, 1)
	Spr.restore()
