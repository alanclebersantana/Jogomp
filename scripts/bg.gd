extends Node2D
## Fundo em paralaxe: um cenário para cada trecho (manhã, tarde, pântano, noite),
## trocando suavemente conforme o Tomé avança.
## Por cima da pintura: nuvens com o vento, névoa de horizonte na cor do céu, cortinas de chuva
## ao longe, vapor subindo nos vales de manhã, estrelas cadentes à noite e (shader) o ar quente
## tremendo na tarde, o clarão do relâmpago e a perspectiva atmosférica.

const FxClock = preload("res://scripts/fx_clock.gd")

var game: Game
const PX := .35
const GL := 600.0

## cor do céu de cada cenário (névoa de distância, perspectiva atmosférica)
const SKY := {"bosque": Color(.80, .90, .97), "tarde": Color(1, .78, .55), "pantano": Color(.5, .7, .63),
	"noite": Color(.15, .2, .44), "neve": Color(.88, .92, 1), "mina": Color(.3, .19, .09), "moinho": Color(1, .84, .66),
	"vila": Color(.16, .21, .46), "esconderijo": Color(.28, .17, .08)}
## névoa de distância na base do fundo
# (névoas com cor: verde-água no pântano, azul de luar à noite, âmbar de lamparina na mina — cinza
# e marrom-escuro lavavam a cena)
const FOGC := {"bosque": Color(.86, .94, .82), "tarde": Color(1, .78, .5), "pantano": Color(.46, .7, .6),
	"noite": Color(.2, .27, .55), "neve": Color(.92, .95, 1), "mina": Color(.36, .22, .1), "moinho": Color(1, .82, .6),
	"vila": Color(.18, .24, .52), "esconderijo": Color(.32, .19, .09)}
## quanto o fundo puxa para a cor do céu (x) e perde cor (y) com a distância (pouca perda de cor: a
## distância vem da névoa colorida, não de deixar o fundo cinza)
## (metade do que era: o fundo longe ainda some no ar, mas sem lavar as cores)
const HAZE := {"bosque": Vector2(.05, .02), "tarde": Vector2(.04, .01), "pantano": Vector2(.06, .02), "noite": Vector2(.03, .02),
	"neve": Vector2(.05, .02), "mina": Vector2(0, .01), "moinho": Vector2(.04, .01), "vila": Vector2(.03, .02), "esconderijo": Vector2(0, .01)}
## onde está o sol pintado (pixels da pintura) e a força do brilho
const SUN := {"tarde": Vector3(686, 322, 1.0), "moinho": Vector3(900, 224, .6)}

var mat: ShaderMaterial
var add_node: Node2D
var _cloud_off := 0.0
var _rain_off := 0.0
var _w := {}

class _Sub extends Node2D:
	var cb: Callable
	func _draw() -> void:
		cb.call(self)

func _ready() -> void:
	mat = ShaderMaterial.new()
	mat.shader = preload("res://scripts/bg_fx.gdshader")
	# brilho do sol somado (mistura aditiva), por cima da pintura
	add_node = _Sub.new()
	add_node.cb = _draw_add
	var am := CanvasItemMaterial.new()
	am.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	add_node.material = am
	add_child(add_node)

func _process(_d: float) -> void:
	if game and game.L:
		position = Vector2(game.rcam, game.rcam_y)
		FxClock.update(game)
		var wind: float = FxClock.wind(game)
		# nuvens andam com o vento (passo acumulado: o vento mudando não faz as nuvens pularem)
		_cloud_off += FxClock.k * (Engine.physics_ticks_per_second / 60.0) * (1.0 + wind * 2.5)
		_rain_off += FxClock.k * (.35 + wind * 1.2)
		_update_mat()
	queue_redraw()
	if add_node:
		add_node.queue_redraw()

## parâmetros do shader do fundo (desligado na qualidade baixa)
func _update_mat() -> void:
	if game.low_fx:
		if material != null:
			material = null
		return
	if material == null:
		material = mat
	_w = FxClock.nw(game)
	var rain: float = game.AMB.rain
	var hz := Vector2.ZERO
	for k in _w:
		hz += HAZE.get(k, Vector2(.06, .06)) * float(_w[k])
	var sky: Color = FxClock.blend(_w, SKY, Color(.8, .85, .9))
	mat.set_shader_parameter("t", FxClock.ft)
	mat.set_shader_parameter("haze_col", Vector3(sky.r, sky.g, sky.b))
	mat.set_shader_parameter("haze_amt", hz.x + .05 * rain)
	mat.set_shader_parameter("desat", hz.y + .05 * rain)
	var sh: float = FxClock.wsum(_w, ["tarde"]) + .6 * float(_w.get("moinho", 0.0))
	mat.set_shader_parameter("shimmer", sh * clamp(1.0 - rain * 2.0, 0, 1))
	mat.set_shader_parameter("flash", clamp(game.lightning / 12.0, 0.0, 1.0))

func _draw() -> void:
	var __t := Time.get_ticks_usec()
	__draw_raw()
	Spr.pt("bg", __t)

func __draw_raw() -> void:
	if game == null or not game.L:
		return
	Spr.begin(self)
	var w := game.W + 4
	var ox := -game.rcam * PX
	# acima do topo do mapa (descida do trenó) o céu fica parado em cima, sem faixa preta
	var oy: float = min(0.0, -(game.rcam_y - game.L.top) * PX)
	var bh: float = game.H + max(0.0, (game.L.bottom - game.L.top) - game.H) * PX
	var ws := game.section_weights()
	var nw: Dictionary = FxClock.nw(game)
	_w = nw
	var first := true
	# o de maior peso primeiro (opaco), depois o outro por cima com transparência
	var keys := ws.keys()
	keys.sort_custom(func(a, b): return ws[a] > ws[b])
	for k in keys:
		var al: float = 1.0 if first else ws[k]
		first = false
		_layer(k, ox, oy, w, bh, al)
	# o céu vivo: cada trecho com o peso normalizado (o que sai some aos poucos, o que chega aparece)
	for k in keys:
		_sky(k, nw.get(k, 0.0), w, oy)
	_atmos(nw, w, oy, bh)

static func hh(x: float, k: int = 0) -> float:
	var v := sin(x * 12.9898 + k * 78.233) * 43758.5453
	return v - floor(v)

## o céu vivo por cima da pintura: nuvens andando, a tarde caindo, estrelas piscando, a lua com halo
func _sky(k: String, al: float, w: float, oy: float) -> void:
	if al <= .01 or game.L.get("theme", "") == "aeroporto":
		return
	var H: float = game.H
	var t := FxClock.ft
	match k:
		"bosque", "neve", "moinho":
			if game.low_fx:
				return
			# nuvens fofas em duas alturas, cada uma no seu passo (mais rápidas com vento)
			var rain: float = game.AMB.rain
			for i in 5:
				var sp: float = .05 + hh(i, 1) * .06
				var cw: float = 110 + hh(i, 2) * 130
				var span: float = w + cw * 2 + 300
				var cx: float = fposmod(hh(i, 3) * span - _cloud_off * sp - game.rcam * .03, span) - cw
				var cy: float = 26 + hh(i, 4) * H * .1 + oy * .2
				var ca: float = (.42 if k == "bosque" else .5) * al
				# com chuva as nuvens ficam mais cinzentas
				_cloud(cx, cy, cw, Color(1, 1, 1).lerp(Color(.62, .66, .7), clamp(rain, 0, 1)) * Color(1, 1, 1, ca))
			_geese(al, w, oy, Color(.72, .74, .8) if k == "neve" else Color(.6, .64, .66))
		"tarde":
			# o sol vai baixando: o céu esquenta e escurece aos poucos até o pântano
			var u: float = clamp((game.player.x - 3430.0) / (15140.0 - 3430.0), 0, 1)
			Spr.vgrad(0, 0, w, H * .7, Color(.45, .12, .25, .3 * u * al), Color(.9, .35, .15, .12 * u * al))
		"noite", "vila":
			if k == "noite":
				# halo respirando em volta da lua pintada no fundo (a lua fica em 878,90 na pintura)
				var t3: Texture2D = Spr.tex["bg_noite"]
				var bh3: float = H + max(0.0, (game.L.bottom - game.L.top) - H) * PX
				var sc3: float = bh3 / t3.get_height()
				var tw3: float = t3.get_width() * sc3
				var x3: float = fposmod(-game.rcam * PX, tw3 * 2) - tw3 * 2
				var j3 := 0
				while x3 < w:
					var mx: float = 878 * sc3 if j3 % 2 == 0 else tw3 - 878 * sc3
					Spr.glow(x3 + mx, oy + 90 * sc3, 90 + sin(t * .02) * 8, Color(.8, .86, 1, .3 * al))
					x3 += tw3
					j3 += 1
			_shooting_star(al, w, oy)

## estrela cadente: rara, um risco fino cruzando o alto do céu
func _shooting_star(al: float, w: float, oy: float) -> void:
	if game.AMB.rain > .3:
		return
	var per := 760.0
	var t: float = FxClock.ft + 333.0
	var cyc: int = int(t / per)
	if hh(cyc, 31) > .42:
		return
	var u: float = (fposmod(t, per) - hh(cyc, 32) * 500.0) / 34.0
	if u < 0.0 or u > 1.0:
		return
	var dir: float = 1.0 if hh(cyc, 33) > .5 else -1.0
	var sx: float = w * (.15 + hh(cyc, 34) * .7)
	var sy: float = 30 + hh(cyc, 35) * game.H * .2 + oy * .2
	var hx: float = sx + dir * u * 260.0
	var hy: float = sy + u * 90.0
	var a: float = sin(u * PI) * .85 * al
	for s in 3:
		var l0: float = s * 18.0
		var l1: float = (s + 1) * 18.0
		Spr.seg(hx - dir * l0 * 2.9, hy - l0, hx - dir * l1 * 2.9, hy - l1, Color(1, 1, .95, a * (1.0 - s * .32)), 1.6 - s * .4)
	Spr.glow(hx, hy, 8, Color(1, 1, 1, a * .7))

## atmosfera de longe (um desenho só, com as cores misturadas entre os trechos — sem saltos):
## faixa de névoa no horizonte, névoa na base, vapor dos vales de manhã e cortinas de chuva
func _atmos(nw: Dictionary, w: float, oy: float, bh: float) -> void:
	var H: float = game.H
	var inside: float = FxClock.wsum(nw, ["mina", "esconderijo"])
	var fc: Color = FxClock.blend(nw, FOGC, Color(.9, .9, .9)).lerp(FxClock.blend(nw, SKY, Color(.9, .9, .9)), .3)
	# névoa de distância na base do fundo
	Spr.vgrad(0, H * .5, w, H * .5, Color(fc.r, fc.g, fc.b, 0), Color(fc.r, fc.g, fc.b, .32))
	if inside > .99:
		return
	var out: float = 1.0 - inside
	# faixa de névoa no horizonte (perspectiva atmosférica)
	var hy: float = oy + bh * .44
	var ha: float = .11 * out
	Spr.vgrad(0, hy - bh * .14, w, bh * .14, Color(fc.r, fc.g, fc.b, 0), Color(fc.r, fc.g, fc.b, ha))
	Spr.vgrad(0, hy, w, bh * .16, Color(fc.r, fc.g, fc.b, ha), Color(fc.r, fc.g, fc.b, 0))
	if game.low_fx:
		return
	var t := FxClock.ft
	var rain: float = game.AMB.rain
	# vapor subindo devagar dos vales (manhã)
	var morn: float = float(nw.get("bosque", 0.0)) * clamp(1.0 - rain * 2.0, 0, 1) * out
	if morn > .02:
		for i in 5:
			var per: float = 900.0 + hh(i, 41) * 500.0
			var u: float = fposmod(t + hh(i, 42) * per, per) / per
			var span: float = w + 600
			var vx: float = fposmod(hh(i, 43) * span - game.rcam * PX * .9 + u * 40.0, span) - 300
			var vy: float = oy + bh * (.5 + hh(i, 44) * .08) - u * 70.0
			var vw: float = 220 + hh(i, 45) * 160
			Spr.ci.draw_texture_rect(Spr.glow_tex, Rect2(vx - vw / 2, vy - vw * .14, vw, vw * .28), false,
				Spr.col(Color(1, 1, 1, .16 * sin(u * PI) * morn)))
	# cortinas de chuva ao longe: lençóis inclinados, macios, andando com o vento
	if rain > .05:
		var wind: float = FxClock.wind(game)
		var slant: float = (.22 + wind * .4) * H * .6
		var rc: Color = fc.darkened(.35).lerp(Color(.5, .55, .6), .4)
		for i in 4:
			var cw: float = 120 + hh(i, 51) * 140
			var span2: float = w + 800
			var cx: float = fposmod(hh(i, 52) * span2 - game.rcam * PX * .8 - _rain_off * (.6 + hh(i, 53) * .5), span2) - 400
			var y0: float = oy + bh * .12
			var y1: float = oy + bh * .62
			var ym: float = (y0 + y1) * .5
			var a: float = (.07 + .05 * hh(i, 54)) * clamp(rain, 0, 1) * out
			var k0: float = 0.0
			var km: float = slant * .5
			var k1: float = slant
			var c0 := Spr.col(Color(rc.r, rc.g, rc.b, 0))
			var cm := Spr.col(Color(rc.r, rc.g, rc.b, a))
			Spr.ci.draw_polygon(PackedVector2Array([Vector2(cx - k0, y0), Vector2(cx + cw - k0, y0), Vector2(cx + cw - km, ym), Vector2(cx - km, ym)]),
				PackedColorArray([c0, c0, cm, cm]))
			Spr.ci.draw_polygon(PackedVector2Array([Vector2(cx - km, ym), Vector2(cx + cw - km, ym), Vector2(cx + cw * 1.2 - k1, y1), Vector2(cx - k1, y1)]),
				PackedColorArray([cm, cm, c0, c0]))

## brilho do sol (mistura somada): halo grande e respirando + reflexo horizontal fininho
func _draw_add(n: CanvasItem) -> void:
	if game == null or not game.L or game.low_fx:
		return
	var rain: float = game.AMB.rain
	if rain > .5:
		return
	var w := game.W + 4
	var oy: float = min(0.0, -(game.rcam_y - game.L.top) * PX)
	var bh: float = game.H + max(0.0, (game.L.bottom - game.L.top) - game.H) * PX
	var t := FxClock.ft
	for k in SUN:
		if game.L.get("theme", "") == "aeroporto":
			break
		var al: float = float(_w.get(k, 0.0)) * clamp(1.0 - rain * 2.0, 0, 1)
		if al < .02 or not Spr.tex.has("bg_" + k):
			continue
		var s: Vector3 = SUN[k]
		var tx: Texture2D = Spr.tex["bg_" + k]
		var sc: float = bh / tx.get_height()
		var tw: float = tx.get_width() * sc
		var x: float = fposmod(-game.rcam * PX, tw * 2) - tw * 2
		var j := 0
		while x < w + 300:
			var sx: float = x + (s.x * sc if j % 2 == 0 else tw - s.x * sc)
			var sy: float = oy + s.y * sc
			if sx > -400 and sx < w + 400:
				var br: float = 1.0 + .06 * sin(t * .025)
				var a: float = al * s.z
				n.draw_texture_rect(Spr.glow_tex, Rect2(sx - 260 * br, sy - 200 * br, 520 * br, 400 * br), false, Color(1, .62, .3, .10 * a))
				n.draw_texture_rect(Spr.glow_tex, Rect2(sx - 80, sy - 70, 160, 140), false, Color(1, .85, .55, .16 * a))
				n.draw_texture_rect(Spr.glow_tex, Rect2(sx - 330, sy - 10, 660, 20), false, Color(1, .8, .5, .08 * a))
			x += tw
			j += 1

## aves migratórias em V cruzando o céu de vez em quando (longe: pequenas e apagadas pela distância)
func _geese(al: float, w: float, oy: float, tint: Color) -> void:
	var per := 2600
	var t: int = game.T + 900
	var cyc: int = t / per
	var u: int = t % per
	var dur := 1100
	if u > dur or hh(cyc, 9) < .25:
		return
	var n: int = 5 + int(hh(cyc, 10) * 5)
	var dir: float = 1.0 if hh(cyc, 11) > .4 else -1.0
	var lx: float = -260 + (w + 520) * (u / float(dur))
	if dir < 0:
		lx = w - lx
	var ly: float = 50 + hh(cyc, 12) * game.H * .16 + oy * .15
	var c := Color(tint.r, tint.g, tint.b, .85 * al)
	for k in n:
		var row: int = (k + 1) / 2
		var side: float = -1.0 if k % 2 == 1 else 1.0
		if k == 0:
			side = 0.0
		var gx: float = lx - dir * row * 24
		var gy: float = ly + row * 11 * side + sin(game.T * .02 + k) * 2
		# o líder troca de vez em quando: a formação "respira"
		gx += sin(game.T * .01 + k * 1.7) * 3
		Spr.P_cycle("goose", ["goose0", "goose1", "goose2", "goose1"], game.T / 6.0 + k * 2, gx, gy + 6, 24, dir < 0, c)

func _cloud(x: float, y: float, cw: float, c: Color) -> void:
	# contorno único (sem sobreposição de transparências): bolotas em cima, base reta e arredondada
	var pts := PackedVector2Array()
	var base: float = y + cw * .07
	var n := 26
	for i in n + 1:
		var u := float(i) / n
		var top := 0.0
		for j in 5:
			var cu: float = .12 + j * .19
			var r: float = .13 + .1 * sin((j / 4.0) * PI)
			var d: float = (u - cu) / r
			if abs(d) < 1:
				top = max(top, r * sqrt(1 - d * d) + .02 * (j % 2))
		var end: float = sin(u * PI)
		pts.push_back(Vector2(x + u * cw, base - cw * top * .9 * (.4 + .6 * sqrt(end))))
	for i in range(n - 1, 0, -1):
		var u2 := float(i) / n
		pts.push_back(Vector2(x + u2 * cw, base + cw * .03 * sin(u2 * PI)))
	Spr.poly(pts, c)
	# sombrinha azulada na base
	Spr.ellipse(x + cw * .5, base, cw * .42, cw * .03, Color(.7, .78, .92, c.a * .5))


const LAYER_PX := [.04, .16, .3, .48]
## brilho de cada camada: a mais perto fica mais escura para o Tomé e os objetos se destacarem
const LAYER_SH := [1.0, .96, .86, .58]

## cenário em camadas (quando as artes novas existem): cada camada anda numa velocidade
func _layers(k: String, w: float, al: float) -> void:
	var ls: Array = Spr.tex["bgl_" + k]
	var H: float = game.H
	for i in ls.size():
		var t: Texture2D = ls[i]
		var f: float = LAYER_PX[min(i, 3)]
		var lh: float = H * (1.12 + i * .04)
		var sc: float = lh / t.get_height()
		var tw: float = t.get_width() * sc
		var y: float = H - lh + clamp(-(game.rcam_y - 140.0) * f * .35, -60.0, 140.0)
		var x: float = fposmod(-game.rcam * f, tw - 1) - (tw - 1)
		var m: float = LAYER_SH[min(i, 3)]
		var mc := Color(m, m, m * 1.04, Spr.alpha * al)
		while x < w:
			Spr.ci.draw_texture_rect(t, Rect2(x, y, tw, lh), false, mc)
			x += tw - 1

func _layer(k: String, ox: float, oy: float, w: float, bh: float, al: float) -> void:
	if Spr.tex.has("bgl_" + k):
		_layers(k, w, al)
		return
	var t: Texture2D = Spr.tex["bg_" + k]
	# a pintura cobre a tela inteira (do topo até embaixo, com o zoom aberto também); as cópias lado a
	# lado alternam espelhadas, então a emenda entre uma e outra nunca aparece
	var sc := bh / t.get_height()
	var tw := t.get_width() * sc
	var x := fposmod(ox, tw * 2) - tw * 2
	var i := 0
	while x < w:
		if i % 2 == 0:
			Spr.img(t, x, oy, tw, bh, Rect2(), al)
		else:
			var cc := Color(1, 1, 1, Spr.alpha * al)
			Spr.ci.draw_polygon(PackedVector2Array([Vector2(x, oy), Vector2(x + tw, oy), Vector2(x + tw, oy + bh), Vector2(x, oy + bh)]),
				PackedColorArray([cc, cc, cc, cc]), PackedVector2Array([Vector2(1, 0), Vector2(0, 0), Vector2(0, 1), Vector2(1, 1)]), t)
		x += tw
		i += 1
