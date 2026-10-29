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
				for s in o.plats:
					_plank(s)

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
