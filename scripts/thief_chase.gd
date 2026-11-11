extends RefCounted
class_name ThiefChase
## Mini-perseguições do vulto de capuz (aeroporto): ao passar do gatilho, o vulto aparece logo à
## frente com a mala brilhando e foge correndo até um esconderijo. Alcançou (encostou ou pulou nele)?
## Ele larga a mala: milhas extras e uma pista a mais. Não alcançou? Some e o jogo segue.
## Dados da fase: "chases": [{"trig", "x0", "x1", "y", "spd", "bonus", "pista"}]

var g
var CH: Array = []
const VCW := 280.0
const VCH := 360.0
const VH := 112.0     # altura na tela (px do mundo): um adulto, bem mais alto que o Milis
## corrida: passada, passagem, passada, passagem... (quadros da folha na ordem do movimento)
const RUN_SEQ := [0, 1, 2, 5, 4, 6]

func _init(game) -> void:
	g = game

func load_level() -> void:
	CH = []
	for c in g.L.get("chases", []):
		var o: Dictionary = c.duplicate()
		o.st = 0      # 0 esperando, 1 fugindo, 2 pego, 3 escapou
		o.x = float(c.x0)
		o.t = 0
		o.vx = 0.0
		CH.append(o)

func step() -> void:
	if CH.is_empty() or not g.running or not g.CINE.is_empty():
		return
	var p: Dictionary = g.player
	var pcx: float = p.x + p.w / 2
	for c in CH:
		match int(c.st):
			0:
				if pcx > float(c.trig) and pcx < float(c.x0):
					c.st = 1
					c.t = 0
					Audio.play("slide", -8, 1.3)
					g.flash("O vulto de capuz! Corra atrás dele (dois toques na direção para correr)!")
			1:
				c.t += 1
				var top: float = float(c.get("spd", 3.9))
				c.vx = min(top, float(c.vx) + .18)
				c.x += c.vx
				if Polish.FRESH and c.t % 6 == 0:
					g.PARTS.append({"x": c.x - 10, "y": float(c.y) - 2, "vx": -.8, "vy": -randf_range(.2, .7), "life": 16, "col": Color(.8, .82, .86, .6)})
				var tr: Dictionary = g.R(c.x - 20, float(c.y) - 104, 40, 104)
				if g.hit(p, tr) and p.dyingT <= 0:
					_caught(c)
				elif c.x >= float(c.x1):
					c.st = 3
					c.t = 0
					g.burst(c.x, float(c.y) - 24, 12, Color(.35, .25, .45))
					g.flash("O vulto sumiu... Da próxima vez, corra mais rápido!")
			2, 3:
				c.t += 1

func _caught(c: Dictionary) -> void:
	c.st = 2
	c.t = 0
	var n: int = int(c.get("bonus", 15))
	g.STATS.pen += n
	for i in n:
		g.gain_coin(c.x + randf_range(-20, 20), float(c.y) - 30 - randf() * 30, i > 0)
	g.burst(c.x, float(c.y) - 30, 24, Color("#ffd76a"))
	g.shake = max(g.shake, 6)
	Audio.play("clue", -4)
	g.flash("Pegou! O vulto largou a mala: +%d milhas. %s" % [n, str(c.get("pista", ""))], 330)

# ---------------------------------------------------------------- desenho
func draw(T: int) -> void:
	for c in CH:
		var st: int = int(c.st)
		if st == 0:
			continue
		var x: float = c.x
		var y: float = float(c.y)
		if st == 3:
			# fumacinha onde ele sumiu
			if c.t < 40:
				var u: float = c.t / 40.0
				for k in 5:
					Spr.circle(x + sin(k * 1.7) * 18 * u, y - 24 - u * 30 - k * 4, 10 * (1.0 - u) + 3, Color(.3, .24, .38, .5 * (1.0 - u)))
			continue
		if st == 2:
			# o vulto cai sentado com o tranco, levanta e foge sem a mala
			var tx: Texture2D = Spr.opt("vulto")
			if tx and tx.get_width() >= VCW * 13:
				var ct: int = int(c.t)
				if ct < 40:
					_frame(x + 6, y, 9 if ct > 6 else 8, false, 1.0)
				elif ct < 130:
					var fx: float = x + 6 + (ct - 40) * 4.0 + max(0, ct - 60) * 1.2
					_frame(fx, y + (-abs(sin(ct * PI / 15.0)) * 2.0), 10 + (ct / 5) % 3, false, clamp((130 - ct) / 30.0, 0, 1))
			# a mala largada no chão, ainda brilhando um pouco
			if c.t < 240:
				var a: float = 1.0 - c.t / 240.0
				Spr.glow(x, y - 12, 40, Color(1, .85, .3, .35 * a))
				Spr.rr(x - 13, y - 22, 26, 20, 3, Color(1, .78, .2, a))
				Spr.rr(x - 5, y - 26, 10, 5, 2, Color(.4, .3, .1, a))
			continue
		# um adulto de capuz: bem mais alto que o Milis (~92 px); quadros desenhados (assets/sprites/vulto.png)
		var tv: Texture2D = Spr.opt("vulto")
		if tv:
			var nfr: int = int(tv.get_width() / VCW)
			var ph: float = float(c.x) / 16.0
			var fr: int = RUN_SEQ[int(ph) % RUN_SEQ.size()]
			if int(c.t) < 10 and nfr >= 9:
				fr = 8   # o susto quando o Milis aparece (depois dispara)
			var bob: float = -abs(sin(ph * PI / 3.0)) * 2.0
			Polish.shadow(x, y + 1, 18, 4, .22)
			_frame(x, y + bob, fr, false, 1.0)
			# a mala brilha (por cima do desenho)
			Spr.glow(x - 27, y - 39, 30, Color(1, .85, .3, .22 + .08 * sin(T * .3)))
			if T % 10 < 5:
				Spr.circle(x - 36 + sin(T * .3) * 4, y - 48, 1.6, Color(1, 1, .8))
			continue
		Spr.save()
		Spr.translate(x, y)
		Spr.scale(1.75, 1.75)
		_hood(0.0, 0.0, T, float(c.vx))
		Spr.restore()

func _frame(x: float, y: float, fr: int, flip: bool, a: float) -> void:
	var t: Texture2D = Spr.opt("vulto")
	var sc: float = VH / 330.0
	Spr.save()
	Spr.translate(x, y)
	Spr.scale(-sc if flip else sc, sc)
	Spr.ci.draw_texture_rect_region(t, Rect2(-VCW * .54, -352, VCW, VCH), Rect2(fr * VCW, 0, VCW, VCH), Color(1, 1, 1, a * Spr.alpha))
	Spr.restore()

## o vulto (desenho antigo, se faltar a folha): capa roxa-escura com capuz, dois olhos acesos e a mala brilhando na mão
func _hood(x: float, y: float, T: int, vx: float) -> void:
	var ph: float = T * .45
	var run: float = clamp(vx / 3.9, 0.0, 1.0)
	var bob: float = abs(sin(ph)) * 3.0 * run
	var by: float = y - bob
	var dark := Color("#2a1f3a")
	var mid := Color("#3d2d55")
	Polish.shadow(x, y + 1, 16, 4, .25)
	# pernas correndo
	for k in [0.0, PI]:
		var a: float = sin(ph + k) * .9 * run
		var kx: float = x + sin(a) * 10
		Spr.seg(x, by - 18, kx, by - 8, dark, 6)
		Spr.seg(kx, by - 8, kx + sin(a) * 6 + 3, y - 1, dark, 5)
	# capa (inclinada para a frente correndo)
	var lean: float = 8.0 * run
	Spr.poly(PackedVector2Array([Vector2(x - 12, by - 16), Vector2(x - 6 + lean * .4, by - 46), Vector2(x + 8 + lean * .5, by - 46), Vector2(x + 14, by - 16), Vector2(x - 16 - 6 * run, by - 12)]), mid)
	# capuz
	Spr.circle(x + 2 + lean * .6, by - 50, 11, dark)
	Spr.poly(PackedVector2Array([Vector2(x - 8 + lean * .6, by - 52), Vector2(x - 16 + lean * .2, by - 40), Vector2(x - 4 + lean * .5, by - 44)]), dark)
	Spr.ellipse(x + 6 + lean * .6, by - 49, 6, 7, Color("#0c0910"))
	# olhos acesos
	Spr.circle(x + 4 + lean * .6, by - 50, 1.4, Color(1, .95, .6))
	Spr.circle(x + 9 + lean * .6, by - 50, 1.4, Color(1, .95, .6))
	# braço com a mala brilhando (balança na corrida)
	var sw: float = sin(ph + PI) * 6 * run
	var hx: float = x + 12 + sw
	var hy: float = by - 26
	Spr.seg(x + 4 + lean * .4, by - 38, hx, hy, dark, 5)
	Spr.glow(hx + 4, hy + 10, 34, Color(1, .85, .3, .3))
	Spr.rr(hx - 6, hy + 2, 22, 17, 3, Color("#ffcc33"))
	Spr.rr(hx - 6, hy + 2, 22, 4, 2, Color("#fff0a0"))
	Spr.rr(hx, hy - 2, 9, 5, 2, Color("#6a4a10"))
	if T % 10 < 5:
		Spr.circle(hx + 16 + sin(T * .3) * 3, hy + 4, 1.6, Color(1, 1, .8))
