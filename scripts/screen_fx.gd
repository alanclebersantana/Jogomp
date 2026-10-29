extends Node2D
## Efeitos de tela: cor do trecho, chuva, relâmpago e o "íris" ao entrar/sair de esconderijos.
## Também um acerto de cor suave por período (multiplicação, sem ler a tela: barato no celular).

const FxClock = preload("res://scripts/fx_clock.gd")

var game: Game
var rain: Array = []
var grade: Node2D

## acerto de cor por cenário (multiplica a tela; 1 = sem mudança). Bem de leve.
const GRADE := {"bosque": Color(1, .995, .965), "tarde": Color(1, .965, .9), "pantano": Color(.94, .975, .955),
	"noite": Color(.9, .93, 1), "neve": Color(.965, .98, 1), "mina": Color(1, .95, .88), "moinho": Color(1, .965, .9),
	"vila": Color(.9, .93, 1), "esconderijo": Color(1, .95, .88)}

class _Sub extends Node2D:
	var cb: Callable
	func _draw() -> void:
		cb.call(self)

var vign: GradientTexture2D
func _ready() -> void:
	# vinheta: bordas um pouco mais escuras, centro limpo
	var gr := Gradient.new()
	gr.set_color(0, Color(0, 0, 0, 0))
	gr.add_point(.62, Color(0, 0, 0, 0))
	gr.set_color(gr.get_point_count() - 1, Color(0, 0, 0, 1))
	vign = GradientTexture2D.new()
	vign.gradient = gr
	vign.fill = GradientTexture2D.FILL_RADIAL
	vign.fill_from = Vector2(.5, .5)
	vign.fill_to = Vector2(1.08, .5)
	vign.width = 256
	vign.height = 144
	for i in 280:
		rain.append({"x": randf() * 1400, "y": randf() * 540, "v": 12 + randf() * 8})
	# acerto de cor: um retângulo multiplicado, desenhado antes do resto desta camada
	grade = _Sub.new()
	grade.cb = _draw_grade
	grade.show_behind_parent = true
	var m := CanvasItemMaterial.new()
	m.blend_mode = CanvasItemMaterial.BLEND_MODE_MUL
	grade.material = m
	add_child(grade)

func _process(_d: float) -> void:
	if game and game.L:
		FxClock.update(game)
		_sim_rain()
	queue_redraw()
	if grade:
		grade.queue_redraw()

static func css(s: String) -> Color:
	# "rgba(r,g,b,a)" -> Color
	var m := s.replace("rgba(", "").replace("rgb(", "").replace(")", "").split(",")
	if m.size() < 3:
		return Color(0, 0, 0, 0)
	return Color(float(m[0]) / 255.0, float(m[1]) / 255.0, float(m[2]) / 255.0, float(m[3]) if m.size() > 3 else 1.0)

## inclinação da chuva: acompanha o vento (e as rajadas)
func _slant() -> float:
	return .25 + FxClock.wind(game) * .45

## gotas andam pelo relógio dos efeitos (param na pausa; mesma velocidade em qualquer taxa de quadros)
func _sim_rain() -> void:
	var k: float = FxClock.k
	if k <= 0.0 or game.AMB.rain <= .05:
		return
	var vs := get_viewport_rect().size
	var z: float = game.camera.zoom.x if game.camera else 1.0
	var dc: float = FxClock.dcam * z
	var sl: float = _slant()
	var n := int(rain.size() * clamp(game.AMB.rain, 0, 1))
	for i in n:
		var d: Dictionary = rain[i]
		d.y += d.v * k
		d.x -= d.v * sl * k + dc * .8
		if d.y > vs.y:
			d.y = -10
			d.x = randf() * (vs.x + 100 + sl * vs.y) - 20
		if d.x < -20:
			d.x += vs.x + 40
		elif d.x > vs.x + 40:
			d.x -= vs.x + 60

func _draw() -> void:
	var __t := Time.get_ticks_usec()
	__draw_raw()
	Spr.pt("fx", __t)

func _draw_grade(n: CanvasItem) -> void:
	if game == null or not game.L or game.low_fx:
		return
	var c: Color = FxClock.blend(FxClock.nw(game), GRADE, Color(1, 1, 1))
	# a maior parte da cor do trecho entra aqui, multiplicada: tinge sem acinzentar (o véu por cima
	# lavava o pântano, o rio e a noite de cinza)
	var tc: Color = _tint()
	var dk: float = _dark_k(tc)
	if tc.a > .002 and dk > 0.0:
		var m: float = max(tc.r, max(tc.g, tc.b))
		if m > .01:
			var ch := Color(tc.r / m, tc.g / m, tc.b / m)
			c *= Color(1, 1, 1).lerp(ch, clamp(tc.a * TINT_MUL * dk, 0.0, .6))
	if c.r > .995 and c.g > .995 and c.b > .995:
		return
	n.draw_rect(Rect2(Vector2.ZERO, get_viewport_rect().size), Color(c.r, c.g, c.b, 1))

## quanto da cor do trecho vira véu por cima e quanto vira filtro multiplicado
const TINT_VEIL := .25
const TINT_MUL := .7

func _tint() -> Color:
	var tc = game.AMB.get("tint_c")
	if not (tc is Color):
		var tint = game.AMB.get("tint", "")
		tc = css(str(tint)) if tint != null and str(tint) != "" else Color(0, 0, 0, 0)
	return tc

## cor escura (pântano, rio, noite, mina): essa acinzenta como véu, então vira filtro. As claras
## (tarde, neve) continuam como véu, que dá o brilho quente/frio por cima
## (de 0 a 1, aos poucos: a cor do trecho vem misturada na passagem e não pode estalar no meio)
static func _dark_k(c: Color) -> float:
	return clamp((.55 - c.get_luminance()) / .2, 0.0, 1.0)

func __draw_raw() -> void:
	if game == null or not game.L:
		return
	var vs := get_viewport_rect().size
	# cor do trecho: já vem misturada entre um trecho e o outro (sem salto na troca). Com o acerto
	# de cor ligado, só um pouco dela vira véu (o resto é multiplicado em _draw_grade)
	var tc: Color = _tint()
	if not game.low_fx:
		tc.a *= lerpf(1.0, TINT_VEIL, _dark_k(tc))
	if tc.a > .002:
		draw_rect(Rect2(Vector2.ZERO, vs), tc)
	var r: float = game.AMB.rain
	if FxClock.hidden_sky(game):
		r = 0.0
	if r > .05 and game.running:
		# chuva tira um pouco da cor da cena (véu cinza-azulado bem leve)
		draw_rect(Rect2(Vector2.ZERO, vs), Color(.55, .6, .63, .07 * clamp(r, 0, 1)))
		var n := int(rain.size() * clamp(r, 0, 1))
		var sl: float = _slant()
		var rc := Color(.78, .84, .9, .45)
		for i in n:
			var d: Dictionary = rain[i]
			draw_line(Vector2(d.x, d.y), Vector2(d.x + 14 * sl, d.y - 14), rc, 1.3)
	if not game.low_fx:
		_vignette(vs)
	Polish.draw_screen(self, vs)
	if game.lightning > 0:
		draw_rect(Rect2(Vector2.ZERO, vs), Color(.9, .94, 1, game.lightning / 14.0))
	# transição em círculo (íris), como nos desenhos antigos: fecha no Tomé quando ele cai e abre de novo
	var p: Dictionary = game.player
	var z: float = game.camera.zoom.x if game.camera else 1.0
	var pc := Vector2((p.x + p.w / 2 - game.rcam) * z, (p.y + p.h / 2 - game.rcam_y) * z)
	var maxr: float = vs.length()
	var ir := -1.0
	if p.dyingT > 0:
		var u: float = clamp((p.dyingT - 4) / 40.0, 0.0, 1.0)
		ir = maxr * u * u
	elif game.iris_t > 0:
		var u2: float = 1.0 - game.iris_t / 30.0
		ir = maxr * u2 * u2
	elif game.VH and game.VH.mode == "sled" and (game.VH.sboard > 0 and game.VH.sboard < 26 or game.VH.sfin > 0):
		# fechando antes de trocar de lugar (subindo no trenó / chegando lá embaixo)
		var u3: float = (game.VH.sboard / 26.0) if game.VH.sboard > 0 else (game.VH.sfin / 30.0)
		ir = maxr * u3 * u3
	if ir >= 0 and ir < maxr:
		var wide: float = maxr * 2.0
		draw_arc(pc, ir + wide / 2.0, 0, TAU, 72, Color(0, 0, 0), wide, true)
		if ir > 2:
			draw_arc(pc, ir + 2, 0, TAU, 72, Color(.1, .07, .04, .6), 4, true)

## vinheta só nas bordas: um anel de elipses (o centro não é desenhado, sai bem mais barato que
## uma imagem por cima da tela inteira)
func _vignette(vs: Vector2) -> void:
	var c := vs / 2
	var n := 40
	var ri := c * .7
	var ro := c * 1.5
	var a0 := Color(0, 0, 0, 0)
	var a1 := Color(0, 0, 0, .32)
	for i in n:
		var t0: float = TAU * i / n
		var t1: float = TAU * (i + 1) / n
		var d0 := Vector2(cos(t0), sin(t0))
		var d1 := Vector2(cos(t1), sin(t1))
		draw_polygon(PackedVector2Array([c + d0 * ri, c + d1 * ri, c + d1 * ro, c + d0 * ro]),
			PackedColorArray([a0, a0, a1, a1]))
