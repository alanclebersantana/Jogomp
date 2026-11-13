extends RefCounted
class_name Movers
## Plataformas que se mexem (Episódio 2):
##  wheel  pás do moinho: tábuas presas nas pontas das pás giram em volta do eixo e levam o Tomé
##         lá para cima (só giram depois que as velas novas são postas: "lock" = id da trava)
##  lift   elevador da mina: fique em cima e aperte USAR; ele vai até a outra ponta do poço.
##         Chamado de longe (perto da base ou do alto do poço), ele vem buscar.
##  path   tábua que vai e volta entre dois pontos
## As tábuas entram em g.SOL como "mplat" (de mão única); quem está em cima anda junto.

var g
var MV: Array = []
var told := {}

const LIFT_SPD := 2.6
const HANG := 34.0   # comprimento das cordas das tábuas do moinho

func _init(game) -> void:
	g = game

func load_level() -> void:
	MV = []
	told = {}
	for d in g.L.get("movers", []):
		var o: Dictionary = d.duplicate(true)
		o.plats = []
		o.t = 0.0
		match o.k:
			"wheel":
				o.ang = float(o.get("a0", 0.0))
				o.on = not o.has("lock")
				o.spin = 0.0
				for i in int(o.get("n", 4)):
					o.plats.append(_plat(o, float(o.get("w", 84))))
			"lift":
				o.pos = 1.0 if o.get("start", "bottom") == "bottom" else 0.0   # 0 = no alto, 1 = embaixo
				o.goal = o.pos
				o.plats.append(_plat(o, float(o.w)))
			"path":
				o.plats.append(_plat(o, float(o.w)))
		MV.append(o)
		_place(o)

func _plat(o: Dictionary, w: float) -> Dictionary:
	var s := {"t": "mplat", "x": 0.0, "y": 0.0, "w": w, "h": 16.0, "oneway": 1, "mk": o.k, "dx": 0.0, "dy": 0.0}
	g.SOL.append(s)
	return s

func _lock_done(id: String) -> bool:
	for l in g.LOCKS:
		if str(l.get("id", "")) == id and l.done:
			return true
	return false

## posição de cada tábua neste quadro
func _place(o: Dictionary) -> void:
	match o.k:
		"wheel":
			var n: int = o.plats.size()
			for i in n:
				var a: float = float(o.ang) + TAU * i / n
				var s: Dictionary = o.plats[i]
				# a tábua fica pendurada por cordas na ponta da pá (como a cadeirinha de uma roda-gigante)
				var nx: float = float(o.x) + cos(a) * float(o.r) - s.w / 2
				var ny: float = float(o.y) + sin(a) * float(o.r) + HANG
				_move(s, nx, ny)
		"lift":
			var s2: Dictionary = o.plats[0]
			_move(s2, float(o.x), lerpf(float(o.y0), float(o.y1), float(o.pos)))
		"path":
			var s3: Dictionary = o.plats[0]
			var u: float = .5 - .5 * cos(float(o.t) * TAU / float(o.get("per", 300)))
			_move(s3, lerpf(float(o.x0), float(o.x1), u), lerpf(float(o.y0), float(o.y1), u))

func _move(s: Dictionary, nx: float, ny: float) -> void:
	s.dx = nx - float(s.x)
	s.dy = ny - float(s.y)
	s.x = nx
	s.y = ny

func on_plat(o: Dictionary) -> bool:
	var gs = g.player.get("_g")
	return gs is Dictionary and o.plats.has(gs) and g.player.onGround

## antes da física: mexe as tábuas e carrega quem está em cima
func pre() -> void:
	var p: Dictionary = g.player
	var gs = p.get("_g")
	for o in MV:
		o.t = float(o.t) + 1.0
		match o.k:
			"wheel":
				if not o.on and o.has("lock") and _lock_done(str(o.lock)):
					o.on = true
				var target: float = float(o.get("spd", .006)) if o.on else 0.0
				o.spin = move_toward(float(o.spin), target, .00012)
				o.ang = float(o.ang) + float(o.spin)
			"lift":
				var pcx: float = p.x + p.w / 2
				var s: Dictionary = o.plats[0]
				var near_lift: bool = pcx > s.x - 30 and pcx < s.x + s.w + 30
				if g.keys.get("Ap", false) and p.dyingT == 0:
					if on_plat(o) and o.goal == o.pos:
						g.keys.Ap = false
						o.goal = 0.0 if float(o.pos) > .5 else 1.0
						Audio.play("door", -8, .7)
					elif near_lift and not on_plat(o) and o.goal == o.pos:
						# chamar o elevador: ele vem até o andar do Tomé
						var feet: float = p.y + p.h
						var want: float = 0.0 if abs(feet - float(o.y0)) < abs(feet - float(o.y1)) else 1.0
						if want != float(o.pos):
							g.keys.Ap = false
							o.goal = want
							Audio.play("door", -8, .7)
							g.flash("O elevador está vindo...", 90)
				var span: float = max(1.0, abs(float(o.y1) - float(o.y0)))
				# arranca e freia com suavidade (antes saía e parava de estalo, com o Tomé em cima)
				var left_px: float = abs(float(o.goal) - float(o.pos)) * span
				var vmax: float = min(LIFT_SPD, sqrt(2.0 * .06 * left_px) + .15)
				var was_moving: bool = left_px > .01
				o.lv = move_toward(float(o.get("lv", 0.0)), vmax if was_moving else 0.0, .06)
				o.pos = move_toward(float(o.pos), float(o.goal), float(o.lv) / span)
				if was_moving and abs(float(o.goal) - float(o.pos)) * span <= .01:
					# chegou: baque leve da gaiola parando
					o.lv = 0.0
					Audio.play("stomp", -16, .8)
					if on_plat(o):
						Audio.vib(20)
					g.shake = max(g.shake, 1.5)
				elif was_moving and int(o.t) % 26 == 0:
					Audio.play("climb", -20, .7)
		_place(o)
	# quem estava em cima anda junto com a tábua
	if gs is Dictionary and str(gs.get("t", "")) == "mplat" and p.onGround:
		p.x += float(gs.dx)
		p.y += float(gs.dy)
	# lista de colisão refeita a cada passo: pedras quebradas, muros de chefe e portas também mudam
	# o cenário sem avisar (guardar entre passos deixava pedra quebrada sólida e o Pipoca atravessando muro)
	g.blockers_dirty()

## o botão USAR aparece em cima (ou perto) do elevador
func near_use() -> bool:
	var p: Dictionary = g.player
	var pcx: float = p.x + p.w / 2
	for o in MV:
		if o.k != "lift" or o.goal != o.pos:
			continue
		if on_plat(o):
			return true
		var s: Dictionary = o.plats[0]
		var feet: float = p.y + p.h
		if p.onGround and pcx > s.x - 30 and pcx < s.x + s.w + 30 and (abs(feet - float(o.y0)) < 20 or abs(feet - float(o.y1)) < 20):
			return true
	return false

func save_data() -> Dictionary:
	var d := {}
	for i in MV.size():
		var o: Dictionary = MV[i]
		if o.k == "lift":
			d[str(i)] = o.pos
	return d

func restore(d: Dictionary) -> void:
	for k in d:
		var i := int(k)
		if i < MV.size() and MV[i].k == "lift":
			MV[i].pos = float(d[k])
			MV[i].goal = MV[i].pos
			_place(MV[i])

# ======================================================================
#  DESENHO (camada que se mexe, atrás do Tomé)
# ======================================================================
func draw(T: int) -> void:
	var cx0: float = g.cam - 600
	var cx1: float = g.cam + g.W + 600
	for o in MV:
		match o.k:
			"wheel":
				if float(o.x) + float(o.r) + 400 < cx0 or float(o.x) - float(o.r) - 400 > cx1:
					continue
				_wheel(o, T)
			"lift":
				if float(o.x) + float(o.w) < cx0 or float(o.x) > cx1:
					continue
				_lift(o, T)
			"path":
				if g.L.get("theme", "") == "aeroporto" and o.get("skin", "") == "bondinho":
					_bond_cable(o)
					for s in o.plats:
						_bondinho(s, T)
				elif g.L.get("theme", "") == "aeroporto":
					_cargo_rail(o)
					for s in o.plats:
						_cargo_plat(s, T)
				else:
					for s in o.plats:
						_plank(s)

## aeroporto: a esteira de despacho que sobe e desce é uma plataforma de carga de metal, inteira,
## correndo num trilho inclinado (o trilho mostra o caminho todo, com pés até o chão)
func _cargo_rail(o: Dictionary) -> void:
	var w: float = float(o.w)
	var a := Vector2(float(o.x0) + w / 2, float(o.y0) + 22)
	var b := Vector2(float(o.x1) + w / 2, float(o.y1) + 22)
	var steel := Color("#4a5560")
	# pés do trilho (até o chão)
	for q in [a, b, (a + b) * .5]:
		Spr.rect(q.x - 4, q.y, 8, 500.0 - q.y, Color("#3a434c"))
		Spr.rect(q.x - 12, 494.0, 24, 6, Color("#2c333a"))
	Spr.seg(a.x, a.y, b.x, b.y, Color(0, 0, 0, .35), 12)
	Spr.seg(a.x, a.y, b.x, b.y, steel, 8)
	Spr.seg(a.x, a.y - 2, b.x, b.y - 2, Color("#8a96a2"), 2)

## Galeão: bondinho (como o do Pão de Açúcar) correndo num cabo de aço preso no teto, de um lado do
## átrio ao outro. O piso da cabine é onde o Milis fica; as paredes são de vidro (dá para ver ele dentro)
func _bond_cable(o: Dictionary) -> void:
	var w: float = float(o.w)
	var a := Vector2(float(o.x0) + w / 2, float(o.y0) - 150)
	var b := Vector2(float(o.x1) + w / 2, float(o.y1) - 150)
	# torres nas pontas e o cabo levemente caído no meio
	for q in [a, b]:
		Spr.rect(q.x - 6, q.y - 40, 12, 46, Color("#4a5560"))
		Spr.circle(q.x, q.y, 9, Color("#2c333a"))
		Spr.circle(q.x, q.y, 4, Color("#c2ccd6"))
	var n := 16
	var prev := a
	for i in range(1, n + 1):
		var u: float = float(i) / n
		var p: Vector2 = a.lerp(b, u) + Vector2(0, sin(u * PI) * 14.0)
		Spr.seg(prev.x, prev.y, p.x, p.y, Color(0, 0, 0, .35), 5)
		Spr.seg(prev.x, prev.y, p.x, p.y, Color("#7f8b97"), 2.5)
		prev = p

func _bondinho(s: Dictionary, T: int) -> void:
	var x: float = s.x
	var y: float = s.y
	var w: float = s.w
	var cx: float = x + w / 2
	var top: float = y - 128
	# braço e roldana até o cabo
	Spr.rect(cx - 3, top - 24, 6, 26, Color("#3a434c"))
	Spr.circle(cx, top - 26, 7, Color("#2c333a"))
	Spr.circle(cx, top - 26, 3, Color("#c2ccd6"))
	# cabine: teto vermelho, colunas, vidro azulado translúcido, faixa e piso
	Spr.rr(x - 6, top - 6, w + 12, 16, 6, Color("#a3261f"))
	Spr.rect(x - 4, top + 8, w + 8, 4, Color("#6e1712"))
	Spr.rect(x + 2, top + 10, w - 4, 112, Color(.62, .82, .95, .22))
	for k in [x, x + w - 6, x + w / 2 - 3]:
		Spr.rect(k, top + 10, 6, 112, Color("#c83a2c"))
	Spr.rect(x, top + 62, w, 5, Color("#f2f2f2", .8))
	Spr.seg(x + 10, top + 18, x + 26, top + 48, Color(1, 1, 1, .35), 3)
	# piso (onde se pisa)
	Spr.rr(x - 4, y - 2, w + 8, 18, 4, Color("#1c2228"))
	Spr.rr(x - 2, y, w + 4, 14, 3, Color("#c83a2c"))
	Spr.rect(x, y + 1, w, 3, Color("#ff7a6a"))
	Spr.circle(cx, y + 8, 2.4, Color(1, .9, .4, .6 + .4 * sin(T * .2)))

func _cargo_plat(s: Dictionary, T: int) -> void:
	var x: float = s.x
	var y: float = s.y
	var w: float = s.w
	# braço que liga a plataforma ao trilho
	Spr.rect(x + w / 2 - 5, y + 14, 10, 10, Color("#3a434c"))
	# tampo de metal inteiro, com borda listrada (amarelo e preto) e rebites
	Spr.rr(x - 2, y - 2, w + 4, 20, 4, Color("#1c2228"))
	Spr.rr(x, y, w, 16, 3, Color("#8c98a4"))
	Spr.rect(x + 2, y + 1, w - 4, 3, Color("#c2ccd6"))
	var k := 0.0
	while k < w - 4:
		var c := Color("#f2c230") if int(k / 12.0) % 2 == 0 else Color("#22262b")
		Spr.rect(x + 2 + k, y + 10, min(12.0, w - 4 - k), 5, c)
		k += 12.0
	for rx in [x + 6, x + w - 6]:
		Spr.circle(rx, y + 6, 1.8, Color("#3a434c"))
	# luzinha de aviso piscando (ela se mexe)
	Spr.circle(x + w / 2, y + 4, 2.4, Color(1, .6, .1, .6 + .4 * sin(T * .2)))

const WS = preload("res://scripts/world_static.gd")
## tábua desenhada na origem (o veio da madeira não "pisca" enquanto ela anda)
func _plank(s: Dictionary) -> void:
	Spr.save()
	Spr.translate(s.x, s.y)
	WS.plat({"x": 0.0, "y": 0.0, "w": s.w, "h": 16.0, "hatch": 1})
	Spr.restore()

func _wheel(o: Dictionary, T: int) -> void:
	var cx: float = float(o.x)
	var cy: float = float(o.y)
	var r: float = float(o.r)
	# a torre do moinho (o eixo das pás fica no círculo de cima da pintura)
	if o.has("tower"):
		var tw: float = float(o.tower)
		Spr.P("moinho", cx, float(o.get("gy", 500)) + 6, tw)
	# as pás giram (velas rasgadas até o Tomé consertar)
	var nm: String = "p_moinho_pas" if o.on else "p_moinho_pasr"
	var rr = Spr.AR.get(nm)
	if rr != null:
		var sz: float = r * 2.0 * 1.12
		Spr.save()
		Spr.translate(cx, cy)
		Spr.rotate(float(o.ang))
		Spr.ci.draw_texture_rect_region(Spr.atlas_tex(rr), Rect2(-sz / 2, -sz / 2, sz, sz), Rect2(rr[0], rr[1], rr[2], rr[3]), Color(1, 1, 1, Spr.alpha))
		Spr.restore()
	# tábuas penduradas nas pontas (ficam sempre na horizontal)
	for i in o.plats.size():
		var s: Dictionary = o.plats[i]
		var a: float = float(o.ang) + TAU * i / o.plats.size()
		var tx: float = cx + cos(a) * r
		var ty: float = cy + sin(a) * r
		var px: float = s.x + s.w / 2
		# cordas da ponta da pá até as duas pontas da tábua
		Spr.seg(tx, ty, px - s.w * .4, s.y + 2, Color("#3a2414"), 3)
		Spr.seg(tx, ty, px + s.w * .4, s.y + 2, Color("#3a2414"), 3)
		Spr.seg(tx, ty, px - s.w * .4, s.y + 2, Color("#c9a26a"), 1.4)
		Spr.seg(tx, ty, px + s.w * .4, s.y + 2, Color("#c9a26a"), 1.4)
		# argola presa na ponta da pá
		Spr.circle(tx, ty, 6, Color("#2a1a0c"))
		Spr.circle(tx, ty, 4, Color("#8a8e96"))
		_plank(s)

func _lift(o: Dictionary, T: int) -> void:
	if o.get("skin", "") == "vidro":
		_lift_glass(o, T)
		return
	var s: Dictionary = o.plats[0]
	var x: float = s.x
	var w: float = s.w
	var top: float = float(o.y0) - 150.0
	# poço: trilhos de madeira dos dois lados e a roldana lá em cima
	for sx in [x - 6, x + w - 2]:
		Spr.rect(sx, top, 8, float(o.y1) - top + 8, Color("#3a2614"))
		Spr.rect(sx + 2, top, 2, float(o.y1) - top + 8, Color("#5a3e22"))
	Spr.rect(x - 18, top - 10, w + 36, 14, Color("#4a3018"))
	var pul: float = float(o.pos) * 30.0
	Spr.circle(x + w / 2, top - 3, 15, Color("#2a1a0c"))
	Spr.circle(x + w / 2, top - 3, 11, Color("#7a5a32"))
	for k in 4:
		var a: float = pul * .2 + k * PI / 2
		Spr.seg(x + w / 2, top - 3, x + w / 2 + cos(a) * 11, top - 3 + sin(a) * 11, Color("#2a1a0c"), 2)
	# cabos até a gaiola
	Spr.seg(x + w / 2 - 4, top - 3, x + 6, s.y - 70, Color(.75, .7, .6), 1.5)
	Spr.seg(x + w / 2 + 4, top - 3, x + w - 6, s.y - 70, Color(.75, .7, .6), 1.5)
	# gaiola: armação de ferro e piso de tábuas
	var c := Color("#5a5a60")
	Spr.rect(x, s.y - 72, w, 5, c)
	Spr.rect(x, s.y - 72, 5, 72, c)
	Spr.rect(x + w - 5, s.y - 72, 5, 72, c)
	for k in 3:
		Spr.rect(x + w * (k + 1) / 4.0 - 1, s.y - 72, 2, 72, Color(c.r, c.g, c.b, .55))
	_plank(s)
	# aviso: USAR
	if g.player and on_plat(o) and o.goal == o.pos:
		var a2: float = .6 + .4 * sin(T * .12)
		Spr.text("✦ USAR", x + w / 2, s.y - 84, 13, Color(1, .9, .6, a2), HORIZONTAL_ALIGNMENT_CENTER, Spr.font_b, 3, Color(0, 0, 0, .8))

## elevador panorâmico (aeroporto): coluna de aço com trilho, cabine de vidro com moldura cromada,
## luz no teto e o painel de botões; ✋ USAR aparece quando o Milis está dentro
func _lift_glass(o: Dictionary, T: int) -> void:
	var s: Dictionary = o.plats[0]
	var x: float = s.x
	var w: float = s.w
	var top: float = float(o.y0) - 150.0
	var bot: float = float(o.y1)
	# coluna/trilho atrás da cabine (vidro escuro com estrutura de aço)
	Spr.rect(x + 6, top, w - 12, bot - top, Color(.55, .75, .9, .12))
	for sx in [x + 4, x + w - 10]:
		Spr.rect(sx, top, 6, bot - top, Color("#7d8794"))
		Spr.rect(sx + 1, top, 2, bot - top, Color(1, 1, 1, .25))
	var yy: float = top + 40
	while yy < bot:
		Spr.seg(x + 8, yy, x + w - 8, yy + 30, Color(.45, .5, .58, .35), 1.5)
		yy += 70
	Spr.rect(x - 10, top - 12, w + 20, 14, Color("#5b6470"))
	# cabos
	Spr.seg(x + w / 2 - 3, top, x + w / 2 - 3, s.y - 112, Color(.15, .15, .17), 2)
	Spr.seg(x + w / 2 + 3, top, x + w / 2 + 3, s.y - 112, Color(.15, .15, .17), 2)
	# cabine
	var ch := 112.0
	var cy: float = s.y - ch
	Spr.rect(x, cy, w, ch, Color(.7, .9, 1, .18))
	Spr.poly(PackedVector2Array([Vector2(x + 8, cy + 8), Vector2(x + 22, cy + 8), Vector2(x + 8, cy + 40)]), Color(1, 1, 1, .25))
	Spr.rect(x, cy, w, 8, Color("#c9ced6"))
	Spr.rect(x, cy, 4, ch, Color("#c9ced6"))
	Spr.rect(x + w - 4, cy, 4, ch, Color("#c9ced6"))
	Spr.rect(x, cy + ch * .55, w, 3, Color(.85, .9, .95, .6))   # barra de apoio
	# luz do teto
	var lit: float = .7 + .3 * sin(T * .05)
	Spr.rect(x + 10, cy + 8, w - 20, 3, Color(1, .97, .8, lit))
	Spr.glow(x + w / 2, cy + 14, 30, Color(1, .95, .7, .18))
	# piso da cabine
	Spr.rect(x - 2, s.y, w + 4, 10, Color("#3a3f47"))
	Spr.rect(x - 2, s.y, w + 4, 2, Color("#9aa3ad"))
	# painel de botões e setinha do andar
	Spr.rr(x + w - 18, cy + 46, 10, 22, 2, Color("#2a2e35"))
	var going: float = float(o.goal) - float(o.pos)
	Spr.circle(x + w - 13, cy + 52, 2.5, Color(1, .8, .3) if going < 0 else Color(.5, .5, .5))
	Spr.circle(x + w - 13, cy + 62, 2.5, Color(1, .8, .3) if going > 0 else Color(.5, .5, .5))
	if g.player and on_plat(o) and o.goal == o.pos:
		var a2: float = .6 + .4 * sin(T * .12)
		Spr.text("✋ USAR", x + w / 2, cy - 10, 13, Color(1, .9, .6, a2), HORIZONTAL_ALIGNMENT_CENTER, Spr.font_b, 3, Color(0, 0, 0, .8))
