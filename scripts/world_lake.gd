extends RefCounted
class_name WorldLake
## Fundo dos lagos: areia, pedras, conchas e galhos; algas pintadas que balançam em gomos (a base fica
## presa) e se afastam quando o Tomé ou um peixe passa; uma camada atrás do Tomé e outra na frente.

static var PUSH := {}

static func _h(x: float, k: int) -> float:
	var v := sin(x * 12.9898 + k * 78.233) * 43758.5453
	return v - floor(v)

## algas do lago w: [x, tipo, altura, frente?]
static func _algae(w: Dictionary) -> Array:
	if w.has("_alg"):
		return w._alg
	var out: Array = []
	var x: float = w.x + 40
	while x < w.x + w.w - 40:
		var hgt: float = min(w.h - 30.0, 70.0 + _h(x, 3) * 90.0)
		if hgt > 40:
			out.append([x, int(_h(x, 1) * 6), hgt, _h(x, 2) < .28])
		x += 60 + _h(x, 4) * 70
	w._alg = out
	return out

## quanto a superfície sobe/desce em xx (balanço constante + ondas de mola). Usado pela água e pelo
## fundo da gruta, para os dois acompanharem exatamente a mesma ondulação
static func wave_off(g: Game, wb: Dictionary, xx: float, T: int, calm: bool) -> float:
	var oy: float = sin(xx * .028 + T * .055) * 3.0 + sin(xx * .071 - T * .043) * 1.6 + sin(xx * .16 + T * .1) * .6
	if calm:
		oy *= .7
	if not wb.is_empty():
		oy += g.WV.height(wb, xx)
	return oy

## o fundo escuro da gruta logo abaixo da superfície, seguindo as ondas (o resto do fundo é estático
## e começa abaixo do vale mais fundo das ondas)
static func _cave_top(g: Game, w: Dictionary, T: int) -> void:
	var cave_c := Color("#2a5a66")
	var has_cave := false
	for c in g.L.get("caves", []):
		if c.get("wet") and c.x <= w.x + 2 and c.x + c.w >= w.x + w.w - 2:
			has_cave = true
	if not has_cave:
		return
	var a: float = max(w.x, g.cam - 40)
	var b: float = min(w.x + w.w, g.cam + g.W + 40)
	var wb: Dictionary = g.WV.body("w%d" % g.X.WATER.find(w), w.x, w.x + w.w, w.y) if g.WV else {}
	var pts := PackedVector2Array()
	var x: float = floor(a / 8.0) * 8.0
	while x <= b + 8.1:
		var xx: float = clamp(x, a, b)
		pts.push_back(Vector2(xx, w.y + wave_off(g, wb, xx, T, false)))
		x += 8
	pts.push_back(Vector2(b, w.y + 34))
	pts.push_back(Vector2(a, w.y + 34))
	Spr.poly(pts, cave_c)

static func back(g: Game, T: int) -> void:
	if g.X == null:
		return
	for w in g.X.WATER:
		if w.x <= g.cam + g.W + 60 and w.x + w.w >= g.cam - 60:
			_cave_top(g, w, T)
	for w in g.X.WATER:
		if w.h < 60 or w.x > g.cam + g.W + 60 or w.x + w.w < g.cam - 60:
			continue
		_floor(g, w, T)
		_draw_algae(g, w, T, false)

static func front(g: Game, T: int) -> void:
	if g.X == null:
		return
	for w in g.X.WATER:
		if w.h < 60 or w.x > g.cam + g.W + 60 or w.x + w.w < g.cam - 60:
			continue
		_draw_algae(g, w, T, true)

## areia ondulada, pedras, conchas e galhos no fundo; manchas de luz suaves dançando
static func _floor(g: Game, w: Dictionary, T: int) -> void:
	var a: float = max(w.x, g.cam - 40)
	var b: float = min(w.x + w.w, g.cam + g.W + 40)
	var fy: float = w.y + w.h
	var pts := PackedVector2Array()
	var x: float = floor(a / 10.0) * 10.0
	while x <= b + 10:
		pts.push_back(Vector2(clamp(x, a, b), fy - 10 - 4 * sin(x * .03) - 2 * sin(x * .11)))
		x += 10
	pts.push_back(Vector2(b, fy + 4))
	pts.push_back(Vector2(a, fy + 4))
	Spr.poly(pts, Color("#8a7a58"))
	Spr.line(pts.slice(0, pts.size() - 2), Color("#b5a47a"), 2)
	var sx: float = floor(a / 37.0) * 37.0
	while sx < b:
		var hv: float = _h(sx, 7)
		if sx > a + 8 and sx < b - 8:
			var sy: float = fy - 6
			if hv < .2:
				Spr.P("peb%d" % int(_h(sx, 8) * 3), sx, sy + 3, 14 + hv * 40, hv < .1, 0.0, Color(.7, .78, .8))
			elif hv < .3:
				# concha em leque
				for i in 5:
					var an: float = PI + PI * (i + .5) / 5.0
					Spr.seg(sx, sy, sx + cos(an) * 7, sy + sin(an) * 7, Color(.95, .85, .78), 2)
				Spr.circle(sx, sy, 2, Color(.85, .7, .65))
			elif hv < .36:
				Spr.save()
				Spr.translate(sx, sy)
				Spr.rotate(-1.4 + _h(sx, 9) * .3)
				Spr.PR("log", -4, -50, 8, 50, Color(.55, .5, .45))
				Spr.restore()
			elif hv < .42:
				Spr.P("mossrock_s", sx, sy + 6, 34, hv < .39, 0.0, Color(.65, .78, .8))
		sx += 37
	# luz dançando no fundo: manchas claras irregulares (presas ao lago, não à câmera)
	for k in int(w.w / 70.0) + 1:
		var cx: float = w.x + fposmod(k * 71.0 + sin(T * .013 + k) * 30.0, w.w + 1)
		if cx < a - 30 or cx > b + 30:
			continue
		var al: float = .05 + .04 * sin(T * .04 + k * 1.7)
		Spr.ellipse(cx, fy - 12 - (k % 3) * 4, 18 + 10 * sin(T * .02 + k), 4 + (k % 2) * 2, Color(.9, 1, 1, al))

static func _draw_algae(g: Game, w: Dictionary, T: int, fr: bool) -> void:
	var fy: float = w.y + w.h - 4
	var p: Dictionary = g.player
	var pc := Vector2(p.x + p.w / 2, p.y + p.h / 2)
	for al in _algae(w):
		if al[3] != fr:
			continue
		var x: float = al[0]
		if x < g.cam - 120 or x > g.cam + g.W + 120:
			continue
		var hgt: float = al[2] * (1.15 if fr else 1.0)
		# empurrão: o Tomé (ou um peixe) passando por perto afasta a alga, que volta devagar
		var key: String = "%d" % int(x)
		var pv: float = PUSH.get(key, 0.0)
		var want := 0.0
		var dx: float = x - pc.x
		if abs(dx) < 60 and pc.y > fy - hgt - 20 and pc.y < fy + 10:
			want = sign(dx) * (60.0 - abs(dx)) * .8
		for e in g.EN:
			if e.k == "piranha" and not e.dead and abs(x - e.x) < 50 and e.y > fy - hgt:
				want += sign(x - e.x) * (50.0 - abs(x - e.x)) * .6
		pv = lerpf(pv, want, .08)
		PUSH[key] = pv
		var sway: float = sin(T * .03 + x * .05) * 8.0 + sin(T * .051 + x * .13) * 3.0 + pv
		var n := 7
		var wdt: float = hgt * .32
		var col := Color(.75, .9, .85, .9) if not fr else Color(.45, .6, .58, .95)
		for k in n:
			var v0: float = float(k) / n
			var v1: float = float(k + 1) / n
			var off: float = sway * pow((v0 + v1) * .5, 1.6)
			Spr.PB("alga%d" % al[1], x - wdt / 2 + off, fy - hgt * v1, wdt, hgt / n + 1.5, 1.0 - v1, 1.0 - v0, col)
