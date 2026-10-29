extends Control
class_name RestScene
## Grande fogueira no fim de cada período: o Tomé se aquece, olha os desenhos que achou
## e, no fundo, em tom de sépia, lembra de um momento com a Isis.
##   1 desenhando na varanda · 2 pega-pega no quintal · 3 pulando nas poças com a lanterna
##   4 o boneco de neve ganhando o gorro verde do Tomé

var n := 1
var t := 0.0
var drawings := 0
var memory: Control

const SEPIA := """
shader_type canvas_item;
uniform float fade = 1.0;
void fragment() {
	vec4 c = COLOR;
	float g = dot(c.rgb, vec3(.3, .59, .11));
	vec3 s = vec3(g) * vec3(1.08, .88, .62) + vec3(.06, .03, .0);
	COLOR = vec4(mix(c.rgb, s, .9), c.a * fade);
}
"""

func setup(period: int, found: int) -> void:
	n = period if period > 10 else clamp(period, 1, 5)
	drawings = found
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	memory = _Memory.new()
	memory.scene = self
	var sh := Shader.new()
	sh.code = SEPIA
	var m := ShaderMaterial.new()
	m.shader = sh
	memory.material = m
	memory.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(memory)

func _process(d: float) -> void:
	t += d * 60.0
	var vs := get_viewport_rect().size
	# em tela baixa (16:9 ou mais larga) a lembrança encolhe para caber acima do Tomé
	var mw: float = min(min(vs.x * .5, 560.0), vs.y * .36 / .44)
	var mh: float = mw * .44
	memory.position = Vector2(vs.x / 2 - mw / 2, vs.y * .04)
	memory.size = Vector2(mw, mh)
	(memory.material as ShaderMaterial).set_shader_parameter("fade", clamp((t - 20) / 70.0, 0.0, 1.0))
	queue_redraw()
	memory.queue_redraw()

func _draw() -> void:
	Spr.begin(self)
	var vs := get_viewport_rect().size
	# noite quente em volta da fogueira
	Spr.vgrad(0, 0, vs.x, vs.y, Color("#120c08"), Color("#2a160a"))
	var fl: float = .85 + sin(t * .31) * .08 + sin(t * .73) * .05
	var fx: float = vs.x * .5 + 40
	var fy: float = fire_y(vs)
	Spr.glow(fx, fy - 40, 420 * fl, Color(1, .55, .2, .32))
	Spr.glow(fx, fy - 30, 180 * fl, Color(1, .75, .35, .45))
	# chão
	Spr.ellipse(fx - 40, fy + 6, 300, 28, Color(.18, .1, .05))
	# tronco de assento, o Tomé sentado esquentando as mãos e o Pipoca deitado ao lado
	Spr.rr(fx - 210, fy - 14, 120, 24, 12, Color("#5a3a20"))
	Spr.rr(fx - 206, fy - 12, 112, 8, 5, Color("#7a5232"))
	Spr.A("pai_crouch", fx - 150, fy - 6, 1.55)
	# luz quente da fogueira batendo no Tomé
	Spr.glow(fx - 120, fy - 50, 70 + sin(t * .2) * 4, Color(1, .6, .25, .22))
	# Pipoca deitado, respirando devagar, de olhos fechados (só quando ele está junto)
	if not show_dog:
		pass
	else:
		_dog(fx, fy)
	# a fogueira grande
	Spr.A("o_fire_on", fx, fy + 4, 1.6)
	_after_fire(fx, fy)

## altura do chão da fogueira: sobra embaixo o espaço da legenda, da lembrança e dos botões
## (antes, em 540 px de altura, "FIM DA … · progresso salvo" ficava por cima do tronco do Tomé)
static func fire_y(vs: Vector2) -> float:
	return min(vs.y * .72, vs.y - 192.0)

var show_dog := true
func _dog(fx: float, fy: float) -> void:
	Spr.save()
	Spr.translate(fx - 265, fy + 8)
	Spr.rotate(.08)
	Spr.scale(.8, .8 * (.5 + sin(t * .04) * .015))
	Spr.A("dog0", 0, 0, 1.0)
	Spr.restore()
	Spr.text("z", fx - 250 + sin(t * .03) * 4, fy - 70 - fmod(t * .3, 30.0), 18, Color(1, .95, .8, .6), HORIZONTAL_ALIGNMENT_CENTER, Spr.font_i)

func _after_fire(fx: float, fy: float) -> void:
	for i in 6:
		var u: float = fmod(t * .012 + i / 6.0, 1.0)
		Spr.circle(fx + sin(i * 2.1 + t * .05) * 30 * u, fy - 40 - u * 220, 3 * (1.0 - u) + .5, Color(1, .7, .3, 1.0 - u))
	# os desenhos achados, apoiados no chão ao lado
	for i in drawings:
		Spr.save()
		Spr.translate(fx + 150 + i * 46, fy - 26 - (i % 2) * 6)
		Spr.rotate(-.18 + i * .16)
		Spr.A("drawing", 0, 0, 1.0)
		Spr.restore()
	# a fumaça sobe da fogueira e forma a moldura da lembrança
	var r := Rect2(memory.position, memory.size)
	var a: float = clamp((t - 20) / 70.0, 0.0, 1.0)
	for i in 14:
		var u2: float = fmod(t * .004 + i / 14.0, 1.0)
		var sx: float = lerpf(fx, r.position.x + r.size.x / 2 + sin(i * 1.7) * r.size.x * .4, u2) + sin(t * .02 + i) * 20
		var sy: float = lerpf(fy - 60, r.position.y + r.size.y + 10, u2)
		Spr.circle(sx, sy, 14 + u2 * 30, Color(.8, .75, .7, .07 * (1.0 - abs(u2 - .5) * 2.0)))
	for i in 16:
		var ang: float = TAU * i / 16.0 + t * .003
		var ex: float = r.position.x + r.size.x / 2 + cos(ang) * (r.size.x * .55 + sin(t * .02 + i) * 8)
		var ey: float = r.position.y + r.size.y / 2 + sin(ang) * (r.size.y * .62 + sin(t * .03 + i) * 6)
		Spr.circle(ex, ey, 26, Color(.75, .7, .66, .1 * a))
	Spr.rr(r.position.x - 10, r.position.y - 10, r.size.x + 20, r.size.y + 20, 22, Color(.92, .8, .58, .16 * a))
	Spr.glow(r.position.x + r.size.x / 2, r.position.y + r.size.y / 2, r.size.x * .7, Color(1, .85, .6, .1 * a))

class _Memory extends Control:
	var scene
	func _draw() -> void:
		Spr.begin(self)
		var w: float = size.x
		var h: float = size.y
		var t: float = scene.t
		clip_contents = true
		# céu e chão da lembrança
		Spr.vgrad(0, 0, w, h, Color("#cfe3f2"), Color("#f2ead8"))
		match scene.n:
			1: _porch(w, h, t)
			2: _tag(w, h, t)
			3: _puddles(w, h, t)
			4: _snowman(w, h, t)
			5: _kite(w, h, t)
			11: _bedroom(w, h, t)
			12: _mill(w, h, t)
			13: _stars(w, h, t)
		# bordas esfumaçadas
		for i in 6:
			var k: float = i / 6.0
			Spr.ci.draw_rect(Rect2(i * 4, i * 4, w - i * 8, h - i * 8), Color(.1, .06, .03, .18 * (1.0 - k)), false, 4)

	## o pai é bem mais alto: a Isis (6 anos) tem uns 60% da altura dele
	func _dad(h: float) -> float:
		return h * .54 / 150.0

	func _kid(h: float) -> float:
		return h * .54 * .6

	func _lia(fr: int, x: float, by: float, hgt: float, flip: bool = false) -> void:
		var t2: Texture2D = Spr.tex.filha
		var fw: float = t2.get_width() / 4.0
		var fh: float = t2.get_height()
		var s: float = hgt / fh
		Spr.save()
		Spr.translate(x, by)
		Spr.scale(-s if flip else s, s)
		Spr.ci.draw_texture_rect_region(t2, Rect2(-fw / 2, -fh, fw, fh), Rect2(fr * fw, 0, fw, fh))
		Spr.restore()

	func _ground(w: float, h: float, c: Color) -> void:
		Spr.rect(0, h * .78, w, h * .22, c)

	func _porch(w: float, h: float, t: float) -> void:
		Spr.circle(w * .85, h * .2, 26, Color(1, .95, .7))
		_ground(w, h, Color("#9bb36a"))
		Spr.AB("o_cabin", w * .08, h * .08, w * .62, h * .78)
		# a Isis (6 anos) sentada no chão da varanda: pequena perto da porta da casa
		var lx: float = w * .53
		var ly: float = h * .735
		Spr.A("lia_draw", lx, ly, .42)
		# rabiscos aparecendo no papel
		var k: int = int(t / 20) % 6
		for i in k:
			Spr.seg(lx + 3 + i * 2, ly - 6, lx + 5 + i * 2, ly - 7, Color(.8, .2, .2), 1.2)
		Spr.text("♥", lx + 10, ly - 40 - fmod(t * .3, 24), 12, Color(.9, .3, .3, 1.0 - fmod(t * .3, 24) / 24.0), HORIZONTAL_ALIGNMENT_CENTER)

	func _tag(w: float, h: float, t: float) -> void:
		_ground(w, h, Color("#9bb36a"))
		Spr.img(Spr.tex.tronco, w * .78, h * .05, 70, h * .76)
		Spr.ellipse(w * .82, h * .08, 110, 60, Color("#6f9a4a"))
		var lx: float = w * .5 + sin(t * .03) * w * .3
		var dir: float = cos(t * .03)
		var tx: float = lx - sign(dir) * 90
		_lia(2 if int(t / 12) % 2 == 0 else 1, lx, h * .84 - abs(sin(t * .2)) * 8, _kid(h), dir < 0)
		Spr.frame_seq(Spr.tex.pai, [1, 2, 3, 2], t / 8.0, 170, 160, 85, 156, tx, h * .84, _dad(h), dir < 0)
		Spr.text("hihi!", lx, h * .3, 15, Color(.4, .25, .2), HORIZONTAL_ALIGNMENT_CENTER)

	func _puddles(w: float, h: float, t: float) -> void:
		Spr.vgrad(0, 0, w, h * .8, Color("#8fa3b5"), Color("#c9d3dc"))
		_ground(w, h, Color("#7d8a6a"))
		for i in 3:
			Spr.ellipse(w * (.25 + i * .25), h * .86, 52, 9, Color(.55, .7, .85))
		for i in 30:
			var rx: float = fmod(i * 97.0 + t * 2.0, w)
			var ry: float = fmod(i * 53.0 + t * 7.0, h * .8)
			Spr.seg(rx, ry, rx - 3, ry + 12, Color(.35, .45, .6, .6), 1.5)
		var j: float = abs(sin(t * .07))
		var lx: float = w * .5
		_lia(2, lx, h * .86 - j * 34, _kid(h))
		if j < .15:
			for k in 6:
				Spr.circle(lx + (k - 2.5) * 12, h * .84 - k % 3 * 6, 4, Color(.6, .75, .9))
		# o pai com a lanterna acesa
		Spr.frame(Spr.tex.pai, 0, 170, 160, 85, 156, w * .22, h * .86, _dad(h), false)
		Spr.glow(w * .22 + 160 * _dad(h) * .36, h * .86 - 160 * _dad(h) * .45, 60, Color(1, .85, .5, .5))

	func _snowman(w: float, h: float, t: float) -> void:
		Spr.vgrad(0, 0, w, h * .8, Color("#c6d6e6"), Color("#eef2f6"))
		Spr.rect(0, h * .78, w, h * .22, Color(.95, .96, 1))
		var sx: float = w * .58
		var hat: bool = t > 150
		WorldNature.snowman(sx, h * .86, h / 300.0, hat)
		if not hat:
			# o gorro voando das mãos dela até a cabeça do boneco
			var u: float = clamp((t - 90) / 60.0, 0.0, 1.0)
			var bx: float = lerpf(w * .36, sx, u)
			var by: float = lerpf(h * .5, h * .86 - 130 * h / 300.0, u) - sin(u * PI) * 30
			WorldNature.beanie(bx, by, h / 300.0)
		_lia(3, w * .34, h * .84, _kid(h))
		for i in 24:
			var fx: float = fmod(i * 71.0 + sin(t * .02 + i) * 20, w)
			var fy: float = fmod(i * 43.0 + t * 1.2, h)
			Spr.circle(fx, fy, 2.2, Color(1, 1, 1, .9))

	func _kite(w: float, h: float, t: float) -> void:
		Spr.vgrad(0, 0, w, h * .8, Color("#9cc8ec"), Color("#e6f2fa"))
		# morro verde e nuvens
		Spr.ellipse(w * .5, h * 1.02, w * .75, h * .3, Color("#8fb35e"))
		for i in 3:
			var cx: float = fmod(i * 170.0 + t * .3, w + 120) - 60
			Spr.ellipse(cx, h * (.18 + i * .07), 46, 14, Color(1, 1, 1, .9))
		# a pipa subindo e balançando
		var kx: float = w * .72 + sin(t * .03) * 22
		var ky: float = h * .22 + cos(t * .04) * 10
		var lx: float = w * .4
		var ly: float = h * .78
		Spr.seg(lx + 6, ly - 34, kx, ky + 18, Color(.3, .3, .3, .7), 1.2)
		Spr.poly(PackedVector2Array([Vector2(kx, ky - 22), Vector2(kx + 16, ky), Vector2(kx, ky + 18), Vector2(kx - 16, ky)]), Color("#e0463a"))
		Spr.seg(kx, ky - 22, kx, ky + 18, Color("#f0c040"), 1.5)
		Spr.seg(kx - 16, ky, kx + 16, ky, Color("#f0c040"), 1.5)
		for i in 4:
			var tx: float = kx - 4 - i * 9 + sin(t * .1 + i) * 4
			Spr.ellipse(tx, ky + 24 + i * 9, 4, 2, [Color("#3a8ad0"), Color("#5ab04a"), Color("#f0c040"), Color("#e0463a")][i])
		# um aviãozinho passando lá no alto
		var ax: float = fmod(t * 1.2, w + 80) - 40
		Spr.rect(ax - 10, h * .1, 20, 4, Color(.5, .3, .25))
		Spr.rect(ax - 3, h * .1 - 5, 6, 14, Color(.6, .35, .3))
		_lia(2, lx, ly, _kid(h))
		Spr.frame(Spr.tex.pai, 0, 170, 160, 85, 156, w * .24, h * .8, _dad(h), false)


	## Episódio 2, lembrança 1: a lanterna acesa na porta do quarto dela
	func _bedroom(w: float, h: float, t: float) -> void:
		Spr.vgrad(0, 0, w, h, Color("#2a2440"), Color("#3a3050"))
		Spr.rect(0, h * .8, w, h * .2, Color("#4a3a2a"))
		# janela com a lua
		Spr.rect(w * .12, h * .14, w * .16, h * .3, Color("#1a2a4a"))
		Spr.circle(w * .2, h * .24, 10, Color(1, .96, .8))
		Spr.ci.draw_rect(Rect2(w * .12, h * .14, w * .16, h * .3), Color("#6b4a2a"), false, 4)
		# a caminha com a Isis dormindo
		Spr.rr(w * .38, h * .62, w * .3, h * .14, 6, Color("#8a5a3a"))
		Spr.rr(w * .4, h * .58, w * .26, h * .08, 8, Color("#e8a0b0"))
		Spr.circle(w * .43, h * .58, 9, Color("#f2c9a8"))
		Spr.circle(w * .43, h * .55, 8, Color("#d0582a"))
		# a lanterna na porta, a luz respirando
		var lx: float = w * .84
		var ly: float = h * .5
		Spr.glow(lx, ly, 90 + sin(t * .05) * 8, Color(1, .8, .4, .55))
		Spr.rect(lx - 6, ly - 12, 12, 20, Color("#b08a3a"))
		Spr.circle(lx, ly - 2, 5, Color(1, .95, .7))
		Spr.text("z", w * .48 + sin(t * .03) * 3, h * .45 - fmod(t * .3, 20.0), 14, Color(1, 1, 1, .6), HORIZONTAL_ALIGNMENT_CENTER)

	## lembrança 2: o domingo vendo o moinho girar
	func _mill(w: float, h: float, t: float) -> void:
		Spr.vgrad(0, 0, w, h * .8, Color("#f4b878"), Color("#f8e2b8"))
		Spr.ellipse(w * .66, h * 1.0, w * .5, h * .34, Color("#d8b25a"))
		_ground(w, h, Color("#c8a048"))
		var mx: float = w * .7
		var mb: float = h * .74
		Spr.poly(PackedVector2Array([Vector2(mx - 22, mb), Vector2(mx - 14, mb - 70), Vector2(mx + 14, mb - 70), Vector2(mx + 22, mb)]), Color("#8a5a32"))
		Spr.poly(PackedVector2Array([Vector2(mx - 18, mb - 70), Vector2(mx, mb - 86), Vector2(mx + 18, mb - 70)]), Color("#6b4224"))
		for k in 4:
			var a: float = t * .02 + k * PI / 2
			Spr.seg(mx, mb - 72, mx + cos(a) * 52, mb - 72 + sin(a) * 52, Color("#5a3a20"), 4)
			Spr.circle(mx + cos(a) * 40, mb - 72 + sin(a) * 40, 9, Color(.96, .9, .78, .9))
		Spr.circle(mx, mb - 72, 5, Color("#3a2614"))
		# os dois sentados vendo
		Spr.frame(Spr.tex.pai, 0, 170, 160, 85, 156, w * .26, h * .86, _dad(h), false)
		_lia(0, w * .36, h * .86, _kid(h))
		var c: int = int(t / 50.0) % 9 + 1
		Spr.text(str(c), w * .36, h * .3, 16, Color(.45, .25, .15), HORIZONTAL_ALIGNMENT_CENTER)

	## lembrança 3: no telhado do galpão vendo as estrelas
	func _stars(w: float, h: float, t: float) -> void:
		Spr.vgrad(0, 0, w, h, Color("#101838"), Color("#2a3a6a"))
		for i in 34:
			var sx: float = fmod(i * 83.0, w)
			var sy: float = fmod(i * 37.0, h * .6)
			var tw: float = .5 + .5 * sin(t * .06 + i)
			Spr.circle(sx, sy, 1.2 + tw, Color(1, 1, .9, .5 + .5 * tw))
		# estrela cadente
		var u: float = fmod(t * .01, 1.0)
		if u < .3:
			var k: float = u / .3
			Spr.seg(w * (.2 + k * .5), h * (.1 + k * .2), w * (.2 + k * .5) - 30, h * (.1 + k * .2) - 12, Color(1, 1, 1, 1.0 - k), 2)
		# o telhado do galpão e os dois deitados olhando para cima
		Spr.poly(PackedVector2Array([Vector2(0, h), Vector2(0, h * .78), Vector2(w * .5, h * .66), Vector2(w, h * .78), Vector2(w, h)]), Color("#5a3a24"))
		Spr.save()
		Spr.translate(w * .4, h * .7)
		Spr.rotate(-1.4)
		_lia(0, 0, 0, _kid(h))
		Spr.restore()
		Spr.save()
		Spr.translate(w * .58, h * .7)
		Spr.rotate(-1.45)
		Spr.frame(Spr.tex.pai, 0, 170, 160, 85, 156, 0, 0, _dad(h), false)
		Spr.restore()
