extends Control
## Desenhos da Isis, feitos "com giz de cera" (traço tremido), para a galeria.
## kind: 0 = "vocês dois embaixo da árvore grande", 1 = "a lanterna espantando o escuro", 2 = "Papai e eu" (final)

var kind := 0
var specs := {}
var locked := false
## revelação (0..1): menos que 1 deixa parte do papel em branco, com a ponta do lápis desenhando
var reveal := 1.0
var rng := RandomNumberGenerator.new()

func _init() -> void:
	custom_minimum_size = Vector2(240, 150)
	size_flags_horizontal = Control.SIZE_SHRINK_CENTER

func _scribble(pts: PackedVector2Array, c: Color, w: float = 3.0) -> void:
	var out := PackedVector2Array()
	for p in pts:
		out.push_back(p + Vector2(rng.randf_range(-1.2, 1.2), rng.randf_range(-1.2, 1.2)))
	draw_polyline(out, c, w, true)

func _circle_scr(c: Vector2, r: float, col: Color, fill: bool = true) -> void:
	if fill:
		var k := 0.0
		while k < r:
			var pts := PackedVector2Array()
			for i in 26:
				var a := TAU * i / 25.0
				pts.push_back(c + Vector2(cos(a), sin(a)) * (r - k))
			_scribble(pts, Color(col.r, col.g, col.b, .8), 3)
			k += 4
	var o := PackedVector2Array()
	for i in 26:
		var a2 := TAU * i / 25.0
		o.push_back(c + Vector2(cos(a2), sin(a2)) * r)
	_scribble(o, Color("#3a2a1a"), 2)

func _fill_scr(r: Rect2, col: Color) -> void:
	var y := r.position.y
	while y < r.end.y:
		_scribble(PackedVector2Array([Vector2(r.position.x, y), Vector2(r.end.x, y + rng.randf_range(-2, 2))]), Color(col.r, col.g, col.b, .75), 4)
		y += 4

func _person(x: float, base: float, s: float, body: Color, hat: Color) -> void:
	var ink := Color("#3a2a1a")
	_circle_scr(Vector2(x, base - 34 * s), 8 * s, Color("#f3c9a0"))
	var b := PackedVector2Array([Vector2(x, base - 26 * s), Vector2(x - 12 * s, base), Vector2(x + 12 * s, base), Vector2(x, base - 26 * s)])
	draw_colored_polygon(b, body)
	_scribble(b, ink, 2)
	if hat.a > 0:
		var h := PackedVector2Array([Vector2(x - 9 * s, base - 38 * s), Vector2(x + 2 * s, base - 56 * s), Vector2(x + 9 * s, base - 38 * s)])
		draw_colored_polygon(h, hat)
		_scribble(h, ink, 2)

func _draw() -> void:
	rng.seed = 7 + kind
	var w := size.x
	var h := size.y
	draw_rect(Rect2(-4, -4, w + 8, h + 8), Color("#6b4a2a"))
	draw_rect(Rect2(0, 0, w, h), Color("#f6efdc"))
	if locked:
		draw_rect(Rect2(0, 0, w, h), Color(.15, .12, .1))
		draw_string(Spr.font_title, Vector2(w / 2 - 12, h / 2 + 14), "?", HORIZONTAL_ALIGNMENT_LEFT, -1, 40, Color(.5, .45, .38))
		return
	if kind == 0:
		_fill_scr(Rect2(0, h * .72, w, h * .28), Color("#59a83c"))
		_circle_scr(Vector2(w * .85, h * .18), 16, Color("#f2cc2e"))
		draw_rect(Rect2(w * .28, h * .35, 22, h * .4), Color("#7a4a26"))
		_scribble(PackedVector2Array([Vector2(w * .28, h * .35), Vector2(w * .28, h * .75), Vector2(w * .28 + 22, h * .75), Vector2(w * .28 + 22, h * .35)]), Color("#3a2a1a"), 2)
		for c in [Vector2(w * .2, h * .3), Vector2(w * .33, h * .18), Vector2(w * .45, h * .3), Vector2(w * .32, h * .36)]:
			_circle_scr(c, 26, Color("#3f8a2a"))
		_person(w * .55, h * .8, 1.15, Color("#7a4a2a"), Color("#3f8a2a"))
		_person(w * .66, h * .8, .8, Color("#e86aa0"), Color(0, 0, 0, 0))
		_scribble(PackedVector2Array([Vector2(w * .57, h * .62), Vector2(w * .64, h * .66)]), Color("#3a2a1a"), 2)
	elif kind == 1:
		_fill_scr(Rect2(0, 0, w, h), Color("#24305a"))
		for i in 7:
			var a := TAU * i / 7.0
			_scribble(PackedVector2Array([Vector2(w * .5, h * .5), Vector2(w * .5 + cos(a) * 70, h * .5 + sin(a) * 50)]), Color("#f2cc2e"), 4)
		_circle_scr(Vector2(w * .5, h * .5), 30, Color("#ffe48a"))
		draw_rect(Rect2(w * .5 - 9, h * .5 - 14, 18, 26), Color("#f08c2a"))
		_scribble(PackedVector2Array([Vector2(w * .5 - 9, h * .5 - 14), Vector2(w * .5 + 9, h * .5 - 14), Vector2(w * .5 + 9, h * .5 + 12), Vector2(w * .5 - 9, h * .5 + 12), Vector2(w * .5 - 9, h * .5 - 14)]), Color("#3a2a1a"), 2)
		for m in [Vector2(w * .1, h * .3), Vector2(w * .88, h * .7), Vector2(w * .12, h * .8)]:
			_circle_scr(m, 14, Color("#111018"))
			draw_circle(m + Vector2(-4, -3), 2.5, Color.WHITE)
			draw_circle(m + Vector2(4, -3), 2.5, Color.WHITE)
	elif kind == 3:
		_fill_scr(Rect2(0, h * .7, w, h * .3), Color("#59a83c"))
		_circle_scr(Vector2(w * .14, h * .2), 15, Color("#f2cc2e"))
		_person(w * .38, h * .82, 1.1, Color("#e86aa0"), Color(0, 0, 0, 0))
		# o Pipoca
		var dx := w * .62
		var dy := h * .72
		var body := PackedVector2Array([Vector2(dx - 26, dy - 18), Vector2(dx + 22, dy - 20), Vector2(dx + 26, dy), Vector2(dx - 24, dy + 2)])
		draw_colored_polygon(body, Color("#b08a5a"))
		_scribble(body + PackedVector2Array([body[0]]), Color("#3a2a1a"), 2)
		_circle_scr(Vector2(dx + 30, dy - 26), 13, Color("#b08a5a"))
		for lg in [-18, -6, 10, 20]:
			_scribble(PackedVector2Array([Vector2(dx + lg, dy), Vector2(dx + lg, dy + 14)]), Color("#3a2a1a"), 3)
		_scribble(PackedVector2Array([Vector2(dx - 26, dy - 14), Vector2(dx - 40, dy - 30)]), Color("#3a2a1a"), 3)
		_scribble(PackedVector2Array([Vector2(dx + 24, dy - 36), Vector2(dx + 20, dy - 46), Vector2(dx + 30, dy - 38)]), Color("#3a2a1a"), 2)
		draw_circle(Vector2(dx + 34, dy - 28), 2, Color("#3a2a1a"))
		_scribble(PackedVector2Array([Vector2(w * .42, h * .62), Vector2(dx - 20, dy - 12)]), Color("#3a2a1a"), 2)
		var hx := w * .5
		var hy := h * .25
		var hp := PackedVector2Array()
		for i in 25:
			var t2 := TAU * i / 24.0
			hp.push_back(Vector2(hx + 11 * pow(sin(t2), 3), hy - (9 * cos(t2) - 3.5 * cos(2 * t2) - 1.4 * cos(3 * t2) - .7 * cos(4 * t2))))
		draw_colored_polygon(hp, Color("#e0463a"))
	elif kind == 4:
		# bônus: soltando pipa no morro
		_fill_scr(Rect2(0, 0, w, h * .62), Color("#7ec8f0"))
		_fill_scr(Rect2(0, h * .62, w, h * .38), Color("#59a83c"))
		_circle_scr(Vector2(w * .12, h * .18), 14, Color("#f2cc2e"))
		var kx := w * .72
		var ky := h * .2
		var kite := PackedVector2Array([Vector2(kx, ky - 22), Vector2(kx + 16, ky), Vector2(kx, ky + 24), Vector2(kx - 16, ky), Vector2(kx, ky - 22)])
		draw_colored_polygon(kite, Color("#e0463a"))
		_scribble(kite, Color("#3a2a1a"), 2)
		_scribble(PackedVector2Array([Vector2(kx, ky + 24), Vector2(kx - 10, ky + 40), Vector2(kx + 4, ky + 54), Vector2(kx - 8, ky + 70)]), Color("#3a2a1a"), 2)
		_person(w * .32, h * .84, 1.15, Color("#7a4a2a"), Color("#3f8a2a"))
		_person(w * .44, h * .84, .8, Color("#e86aa0"), Color(0, 0, 0, 0))
		_scribble(PackedVector2Array([Vector2(w * .46, h * .6), Vector2(kx, ky + 24)]), Color("#3a2a1a"), 1.5)
	else:
		var col := func(c: String) -> Color:
			return GameData.PEN_COL[c] if specs.has(c) else Color("#f6efdc")
		_fill_scr(Rect2(0, 0, w, h * .6), col.call("azul"))
		_fill_scr(Rect2(0, h * .6, w, h * .4), col.call("verde"))
		_circle_scr(Vector2(w * .82, h * .2), 18, col.call("amarelo"))
		draw_rect(Rect2(w * .1, h * .38, 56, 42), col.call("laranja"))
		var roof := PackedVector2Array([Vector2(w * .1 - 6, h * .38), Vector2(w * .1 + 28, h * .24), Vector2(w * .1 + 62, h * .38)])
		draw_colored_polygon(roof, col.call("vermelho"))
		_scribble(roof, Color("#3a2a1a"), 2)
		_person(w * .58, h * .78, 1.1, col.call("roxo"), Color(0, 0, 0, 0))
		_person(w * .68, h * .78, .8, col.call("vermelho"), Color(0, 0, 0, 0))
	if reveal < 1.0:
		# papel ainda em branco nas faixas que o lápis não passou (de cima para baixo, em zigue-zague)
		var rows := 7
		var rh: float = h / rows
		var done: float = reveal * rows
		for r in rows:
			var y0: float = r * rh
			var fr: float = clamp(done - r, 0.0, 1.0)
			var ltr: bool = r % 2 == 0
			var cov: float = w * (1.0 - fr)
			if cov <= 0:
				continue
			var rx: float = (w - cov) if ltr else 0.0
			draw_rect(Rect2(rx, y0, cov, rh + 1), Color("#f6efdc"))
			if fr > 0 and fr < 1:
				var px: float = (w * fr) if ltr else (w * (1.0 - fr))
				var py: float = y0 + rh * .5
				# lápis de cor desenhando
				draw_line(Vector2(px, py), Vector2(px + 26, py - 34), Color("#e0463a"), 7)
				draw_line(Vector2(px + 20, py - 26), Vector2(px + 26, py - 34), Color("#f3d29a"), 7)
				draw_circle(Vector2(px, py), 2.5, Color("#3a2a1a"))
	var cap: String = ["\"Eu e o papai\"", "\"A lanterna do papai\"", "\"Papai e eu\"", "\"Eu e o Pipoca\"", "\"A nossa pipa\""][kind]
	draw_string(Spr.font_i, Vector2(8, h - 6), cap + " — Isis", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("#3a2a1a"))
