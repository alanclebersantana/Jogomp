extends Control
## Mapa da fase: trechos, chão, fogueiras, pistas, lápis especiais, desenhos e onde o Tomé está.
## O que falta só aparece (como "?") nos trechos por onde você já passou.

var game: Game
const BANDS := {"manha": Color(.36, .55, .3), "tarde": Color(.66, .45, .22), "chuva": Color(.22, .38, .36), "neve": Color(.62, .7, .82), "noite": Color(.16, .19, .36), "perseguicao": Color(.34, .14, .14), "ceu": Color(.45, .62, .82), "rio": Color(.2, .42, .55),
	"mina": Color(.3, .2, .12), "moinho": Color(.72, .55, .25), "vila": Color(.18, .2, .4), "isis": Color(.45, .2, .32)}
const NAMES := {"manha": "Terminal", "tarde": "Segurança", "chuva": "Pátio", "neve": "Pista", "noite": "Noite", "perseguicao": "Fuga", "ceu": "Céu", "rio": "Rio", "mina": "Subsolo", "tunel": "Subsolo", "moinho": "Hangar", "vila": "Terminal", "isis": "Isis"}

func _init() -> void:
	custom_minimum_size = Vector2(500, 250)
	size_flags_horizontal = Control.SIZE_SHRINK_CENTER

func _draw() -> void:
	var L := game.L
	var w := size.x
	var h := 200.0
	var top: float = L.top
	var bot: float = L.bottom
	var sx: float = w / L.spanX
	var sy: float = h / (bot - top)
	var P := func(x: float, y: float) -> Vector2:
		return Vector2(x * sx, 26 + (y - top) * sy)
	var secs: Array = L.sections
	var shown := {}
	var lab_end := -999.0     # fim do último nome escrito (trechos curtos: o nome seguinte não encavala)
	for i in secs.size():
		var x0: float = secs[i].x
		var x1: float = secs[i + 1].x if i + 1 < secs.size() else L.spanX
		var song: String = secs[i].get("map", secs[i].get("bg", secs[i].song))
		draw_rect(Rect2(x0 * sx, 26, (x1 - x0) * sx, h), BANDS.get(song, Color(.2, .2, .2)))
		if not shown.has(song):
			shown[song] = 1
			var nm: String = NAMES.get(song, "")
			var lx: float = max(x0 * sx + 6, lab_end + 10)
			var lw: float = Spr.font_b.get_string_size(nm, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x
			lx = min(lx, w - lw)
			draw_string(Spr.font_b, Vector2(lx, 18), nm, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color("#e8dcc0"))
			lab_end = lx + lw
	var visited: float = game.max_x
	draw_rect(Rect2(visited * sx, 26, w - visited * sx, h), Color(0, 0, 0, .45))
	for s in game.SOL:
		var a: Vector2 = P.call(s.x, s.y)
		var hh: float = 3.0 if s.get("oneway") else max(3.0, min(s.h, 200) * sy)
		draw_rect(Rect2(a.x, a.y, max(1.5, s.w * sx), hh), Color("#8a6a42") if s.get("oneway") else Color("#4a3220"))
	for sw in game.SWAMP:
		var a2: Vector2 = P.call(sw.x, sw.y)
		draw_rect(Rect2(a2.x, a2.y, sw.w * sx, 5), Color(.3, .55, .5))
	for wr in game.X.WATER:
		var aw: Vector2 = P.call(wr.x, wr.y)
		draw_rect(Rect2(aw.x, aw.y, max(2.0, wr.w * sx), max(2.0, wr.h * sy)), Color(.35, .65, .85, .8))
	if not game.X.GOLD.is_empty():
		var gq: Vector2 = P.call(game.X.GOLD.x, game.X.GOLD.y)
		if game.X.GOLD.got:
			_icon("pen_gold", gq, 16)
		elif game.X.found.has("s3"):
			draw_string(Spr.font_b, gq + Vector2(-4, 5), "?", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("#ffd76a"))
	if not game.X.BOSS.is_empty() and not game.X.BOSS.done:
		var bq: Vector2 = P.call((game.X.BOSS.x0 + game.X.BOSS.x1) / 2.0, 470)
		draw_string(Spr.font_b, bq + Vector2(-6, 0), "☠", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("#ff9a7a"))
	for kg in [game.K.HAWK, game.K.FISH]:
		if not kg.is_empty() and not kg.done:
			var kq: Vector2 = P.call((kg.x0 + kg.x1) / 2.0, kg.get("gy", kg.get("y1", 500)) - 30)
			draw_string(Spr.font_b, kq + Vector2(-6, 0), "☠", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("#ff9a7a"))
	for c in game.CHK:
		var q: Vector2 = P.call(c.x, c.y)
		var big: bool = c.has("rest")
		draw_circle(q + Vector2(0, -5), 6.5 if big else 4.0, Color("#ff9a3a") if c.on else Color(.5, .45, .4))
		if big:
			draw_arc(q + Vector2(0, -5), 6.5, 0, TAU, 16, Color("#ffe0a0"), 1.5, true)
	for c in game.CLUES:
		var q2: Vector2 = P.call(c.x, c.y)
		if c.got:
			_icon("cl_%d" % int(c.id), q2, 18)
		elif c.x < visited:
			draw_string(Spr.font_b, q2 + Vector2(-4, 5), "?", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color("#bfe0ff"))
	for s2 in game.SPECS:
		var q3: Vector2 = P.call(s2.x, s2.y)
		if s2.got:
			_icon("pen_" + s2.c, q3, 16)
		elif s2.x < visited:
			draw_circle(q3, 4, Color(1, 1, 1, .5))
	for d in game.DRWS:
		var q4: Vector2 = P.call(d.x, d.y)
		if d.got:
			_icon("drawing", q4, 14)
		elif d.x < visited:
			draw_string(Spr.font_b, q4 + Vector2(-4, 5), "?", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color("#f6efdc"))
	var p: Dictionary = game.player
	var pp: Vector2 = P.call(p.x + p.w / 2, p.y + p.h)
	draw_circle(pp + Vector2(0, -6), 7, Color("#e0463a"))
	draw_arc(pp + Vector2(0, -6), 7, 0, TAU, 20, Color.WHITE, 2, true)
	var dp: Vector2 = P.call(game.DOOR.x + 30, game.DOOR.y + 90)
	draw_string(Spr.font_b, dp + Vector2(-20, -16), "MINA", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("#ffd28a"))
	var nc := game.CLUEGOT.size()
	var ns := game.SPECGOT.size()
	var nd := 0
	for d2 in game.DRWS:
		if d2.got:
			nd += 1
	var txt := "Pistas %d/%d · Cartões %d/%d · Segredos %d/%d · " % [nc, game.clue_ids().size(), nd, game.DRWS.size(), game.X.found.size(), game.X.SECRETS.size()]
	draw_string(Spr.font, Vector2(0, h + 50), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("#e8dcc0"))
	# legenda com as cores de verdade (antes os dois "●" saíam da cor do texto)
	var lx2: float = Spr.font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x + 6
	for it in [[Color("#e0463a"), "você"], [Color("#ff9a3a"), "totem"]]:
		draw_circle(Vector2(lx2, h + 45), 5, it[0])
		draw_string(Spr.font, Vector2(lx2 + 9, h + 50), it[1], HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("#e8dcc0"))
		lx2 += 18 + Spr.font.get_string_size(it[1], HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x

func _icon(n: String, c: Vector2, hgt: float) -> void:
	var r = Spr.AR.get(n)
	if r == null:
		return
	var ww: float = hgt * r[2] / r[3]
	draw_texture_rect_region(Spr.atlas_tex(r), Rect2(c.x - ww / 2, c.y - hgt / 2, ww, hgt), Rect2(r[0], r[1], r[2], r[3]))
