extends Control
## Mapa de destinos: o litoral do Sudeste com os aeroportos do Milis. Cada destino é um alfinete com o
## código do aeroporto e as estrelas do melhor resultado; a rota tracejada liga um ao outro e um aviãozinho
## voa por ela. Destinos ainda trancados aparecem com cadeado; o próximo, com "???".

signal pick(i: int)

## [código, nome, longitude, latitude, episódio (-1 = em breve)]
const DEST := [["GRU", "GUARULHOS", -46.47, -23.43, 0], ["GIG", "GALEÃO", -43.25, -22.81, 1],
	["???", "PRÓXIMO DESTINO", -51.9, -23.4, -1]]
const LON0 := -54.0
const LON1 := -38.5
const LAT0 := -18.5
const LAT1 := -26.5
## litoral (longitude, latitude), de nordeste para sudoeste
const COSTA := [[-38.5, -18.5], [-39.6, -19.4], [-40.2, -20.2], [-40.6, -21.0], [-41.0, -21.6], [-41.8, -22.4],
	[-42.0, -23.0], [-42.8, -22.95], [-43.1, -22.95], [-43.15, -22.7], [-43.3, -22.75], [-43.2, -23.0],
	[-43.6, -23.05], [-44.3, -23.0], [-44.7, -23.35], [-45.4, -23.6], [-45.9, -23.8], [-46.6, -24.05],
	[-47.4, -24.6], [-48.1, -25.3], [-48.6, -25.9], [-48.6, -26.5]]

var eps := 1
var t := 0.0
var sel := -1

func _ready() -> void:
	custom_minimum_size = Vector2(620, 300)
	mouse_filter = Control.MOUSE_FILTER_STOP

func _process(d: float) -> void:
	t += d * 60.0
	queue_redraw()

func _p(lon: float, lat: float) -> Vector2:
	return Vector2((lon - LON0) / (LON1 - LON0) * size.x, (lat - LAT0) / (LAT1 - LAT0) * size.y)

func _gui_input(ev: InputEvent) -> void:
	var press: bool = (ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT) \
		or (ev is InputEventScreenTouch and ev.pressed)
	if not press:
		return
	for i in DEST.size():
		var e: int = int(DEST[i][4])
		if e < 0 or e >= eps:
			continue
		if ev.position.distance_to(_p(DEST[i][2], DEST[i][3])) < 46:
			sel = i
			pick.emit(e)
			accept_event()
			return

func _draw() -> void:
	var W := size.x
	var H := size.y
	var f: Font = Spr.font_b if Spr.font_b else ThemeDB.fallback_font
	var ft: Font = Spr.font_title if Spr.font_title else f
	# moldura e mar
	draw_rect(Rect2(-6, -6, W + 12, H + 12), Color("#2a1d14"))
	draw_rect(Rect2(0, 0, W, H), Color("#2f6f9a"))
	for k in 14:
		var y: float = H * (k + .5) / 14.0
		var ph: float = t * .02 + k
		var pts := PackedVector2Array()
		for j in 25:
			var x: float = W * j / 24.0
			pts.append(Vector2(x, y + sin(x * .03 + ph) * 2.0))
		draw_polyline(pts, Color(1, 1, 1, .06), 1.5)
	# terra (litoral + borda de cima e da esquerda)
	var land := PackedVector2Array()
	land.append(Vector2(0, 0))
	for c in COSTA:
		land.append(_p(c[0], c[1]))
	land.append(Vector2(0, H))
	var areia := PackedVector2Array()
	for c in COSTA:
		areia.append(_p(c[0], c[1]))
	draw_colored_polygon(land, Color("#d9c590"))
	# relevo: serras (manchas verdes) por cima da terra
	for s in [[-45.0, -22.6, 70, 22], [-49.5, -22.0, 120, 40], [-43.5, -21.6, 80, 26], [-51.5, -24.5, 90, 34], [-47.5, -20.5, 110, 30]]:
		var c0: Vector2 = _p(s[0], s[1])
		draw_set_transform(c0, 0, Vector2(1, float(s[3]) / float(s[2])))
		draw_circle(Vector2.ZERO, float(s[2]), Color("#9fb36a", .55))
		draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)
	draw_polyline(areia, Color("#f5e6b8"), 5.0)
	draw_polyline(areia, Color("#2a1d14"), 2.0)
	# divisas dos estados (tracejado bem leve)
	_dash(_p(-44.8, -18.5), _p(-44.6, -22.9), Color(.3, .2, .1, .35))
	_dash(_p(-50.0, -22.6), _p(-46.2, -21.3), Color(.3, .2, .1, .35))
	_dash(_p(-46.2, -21.3), _p(-44.6, -22.9), Color(.3, .2, .1, .35))
	_dash(_p(-53.5, -22.6), _p(-48.2, -25.1), Color(.3, .2, .1, .35))
	draw_string(f, _p(-49.6, -21.9), "SÃO PAULO", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(.35, .25, .12, .8))
	draw_string(f, _p(-42.4, -21.2), "RIO DE JANEIRO", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(.35, .25, .12, .8))
	draw_string(f, _p(-43.6, -20.0), "MINAS GERAIS", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(.35, .25, .12, .8))
	draw_string(f, _p(-53.6, -25.6), "PARANÁ", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(.35, .25, .12, .8))
	draw_string(ft, _p(-45.0, -25.4), "OCEANO ATLÂNTICO", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(1, 1, 1, .45))
	# rosa dos ventos
	var rv: Vector2 = Vector2(W - 44, H - 44)
	draw_circle(rv, 20, Color(1, 1, 1, .12))
	draw_colored_polygon(PackedVector2Array([rv + Vector2(0, -24), rv + Vector2(5, 0), rv + Vector2(-5, 0)]), Color("#e8dcc0"))
	draw_colored_polygon(PackedVector2Array([rv + Vector2(0, 24), rv + Vector2(5, 0), rv + Vector2(-5, 0)]), Color(1, 1, 1, .35))
	draw_string(f, rv + Vector2(-4, -27), "N", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color("#e8dcc0"))
	# rotas: GRU → GIG (liberada ou não) e GIG → ??? (pontilhada clarinha)
	var a: Vector2 = _p(DEST[0][2], DEST[0][3])
	var b: Vector2 = _p(DEST[1][2], DEST[1][3])
	var c: Vector2 = _p(DEST[2][2], DEST[2][3])
	var rota1: PackedVector2Array = _arc(a, b, -70)
	_dash_poly(rota1, Color("#fff3c4") if eps >= 2 else Color(1, 1, 1, .4), 3.0)
	var rota2: PackedVector2Array = _arc(b, c, -110)
	_dash_poly(rota2, Color(1, 1, 1, .22), 2.0)
	# aviãozinho voando pela rota liberada mais recente
	var rota: PackedVector2Array = rota1
	var u: float = fmod(t, 260.0) / 260.0
	var k: int = int(u * (rota.size() - 1))
	var pa: Vector2 = rota[k]
	var pb: Vector2 = rota[min(k + 1, rota.size() - 1)]
	_plane(pa.lerp(pb, u * (rota.size() - 1) - k), (pb - pa).angle())
	# alfinetes
	for i in DEST.size():
		var d: Array = DEST[i]
		var p: Vector2 = _p(d[2], d[3])
		var e: int = int(d[4])
		var aberto: bool = e >= 0 and e < eps
		var pul: float = 1.0 + (.08 * sin(t * .12) if aberto else 0.0)
		var col: Color = Color("#e0463a") if aberto else (Color("#7d7468") if e >= 0 else Color("#4d4a52"))
		draw_circle(p + Vector2(2, 3), 5, Color(0, 0, 0, .3))
		draw_line(p, p + Vector2(0, -22 * pul), Color("#2a1d14"), 3)
		var top: Vector2 = p + Vector2(0, -30 * pul)
		draw_circle(top, 13 * pul, Color("#2a1d14"))
		draw_circle(top, 11 * pul, col)
		draw_circle(top + Vector2(-3, -3), 3.5, Color(1, 1, 1, .5))
		if aberto and i == sel:
			draw_arc(top, 18, 0, TAU, 32, Color("#ffd76a"), 3)
		# etiqueta
		var lab: String = str(d[0])
		var lw: float = ft.get_string_size(lab, HORIZONTAL_ALIGNMENT_LEFT, -1, 18).x
		var bx: Vector2 = top + Vector2(-lw / 2 - 8, -46)
		draw_rect(Rect2(bx, Vector2(lw + 16, 26)), Color("#2a1d14", .85))
		draw_string(ft, bx + Vector2(8, 20), lab, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color("#ffd76a") if aberto else Color(.75, .7, .62))
		var nm: String = str(d[1])
		var nw: float = f.get_string_size(nm, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x
		draw_string(f, p + Vector2(-nw / 2, 18), nm, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("#2a1d14"))
		if aberto:
			var b2 := Save.best(e)
			var st: int = int(b2.get("stars", 0)) if not b2.is_empty() else 0
			var s2: String = "★".repeat(st) + "☆".repeat(3 - st)
			var sw: float = f.get_string_size(s2, HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x
			draw_rect(Rect2(p + Vector2(-sw / 2 - 5, 21), Vector2(sw + 10, 18)), Color("#2a1d14", .8))
			draw_string(f, p + Vector2(-sw / 2, 35), s2, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color("#ffd76a"))
		elif e >= 0:
			_cadeado(top)
		else:
			draw_string(ft, top + Vector2(-5, 6), "?", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color("#e8dcc0"))

func _arc(a: Vector2, b: Vector2, h: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	var n := (b - a).orthogonal().normalized()
	for i in 41:
		var u: float = i / 40.0
		out.append(a.lerp(b, u) + n * h * 4.0 * u * (1.0 - u) * signf(-(b - a).x + .001))
	return out

func _dash_poly(pts: PackedVector2Array, col: Color, w: float) -> void:
	for i in range(0, pts.size() - 1, 2):
		draw_line(pts[i], pts[i + 1], col, w)

func _dash(a: Vector2, b: Vector2, col: Color) -> void:
	var n: int = int(a.distance_to(b) / 8.0)
	for i in range(0, n, 2):
		draw_line(a.lerp(b, float(i) / n), a.lerp(b, float(i + 1) / n), col, 1.5)

func _plane(p: Vector2, ang: float) -> void:
	draw_set_transform(p, ang, Vector2.ONE)
	var ink := Color("#2a1d14")
	draw_colored_polygon(PackedVector2Array([Vector2(16, 0), Vector2(8, -3), Vector2(-12, -3), Vector2(-14, 0), Vector2(-12, 3), Vector2(8, 3)]), Color.WHITE)
	draw_colored_polygon(PackedVector2Array([Vector2(4, -2), Vector2(-4, -14), Vector2(-8, -14), Vector2(-4, -2)]), Color("#e0463a"))
	draw_colored_polygon(PackedVector2Array([Vector2(4, 2), Vector2(-4, 14), Vector2(-8, 14), Vector2(-4, 2)]), Color("#e0463a"))
	draw_colored_polygon(PackedVector2Array([Vector2(-10, -2), Vector2(-15, -7), Vector2(-17, -7), Vector2(-14, 0)]), Color("#e0463a"))
	draw_polyline(PackedVector2Array([Vector2(16, 0), Vector2(8, -3), Vector2(-12, -3), Vector2(-14, 0), Vector2(-12, 3), Vector2(8, 3), Vector2(16, 0)]), ink, 1.5)
	draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)

func _cadeado(c: Vector2) -> void:
	draw_arc(c + Vector2(0, -2), 5, PI, TAU, 12, Color("#e8dcc0"), 2)
	draw_rect(Rect2(c + Vector2(-6, -2), Vector2(12, 9)), Color("#e8dcc0"))
