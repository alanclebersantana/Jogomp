extends CanvasLayer
class_name LightMap
const FxClock = preload("res://scripts/fx_clock.gd")
## Escuridão e luzes num mapa de luz pequeno (1/4 da tela) multiplicado por cima do mundo.
## Substitui CanvasModulate + PointLight2D: no modo de compatibilidade cada PointLight2D redesenhava
## o cenário inteiro outra vez, e com 6–10 luzes o celular caía de quadros (o pulo ficava lento).

## uma luz: os mesmos campos que o código usava no PointLight2D
class Dot:
	var position := Vector2()
	var energy := 0.0
	var color := Color.WHITE
	var texture_scale := 1.0
	var rotation := 0.0
	var offset := Vector2()
	var texture: Texture2D
	var visible := true

const DIV := 4.0
var game: Game
var ambient := Color.WHITE
var dots: Array = []
var vp: SubViewport
var painter: Node2D
var show: TextureRect

func _init() -> void:
	layer = 1

func _ready() -> void:
	vp = SubViewport.new()
	vp.disable_3d = true
	vp.transparent_bg = false
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vp.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_LINEAR
	add_child(vp)
	painter = _Painter.new()
	painter.lm = self
	var am := CanvasItemMaterial.new()
	am.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	painter.material = am
	vp.add_child(painter)
	show = TextureRect.new()
	show.texture = vp.get_texture()
	show.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	show.stretch_mode = TextureRect.STRETCH_SCALE
	show.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mm := CanvasItemMaterial.new()
	mm.blend_mode = CanvasItemMaterial.BLEND_MODE_MUL
	show.material = mm
	add_child(show)

func dot(c: Color, r: float, tex: Texture2D) -> Dot:
	var d := Dot.new()
	d.color = c
	d.texture = tex
	d.texture_scale = r * 2 / 256.0
	dots.append(d)
	return d

## escuridão com cor: a penumbra de dia (chuva do pântano, rio) escurece menos e não acinzenta;
## a noite puxa para o azul do luar e a mina para o âmbar das lamparinas (sem mudar o quanto escurece)
func tinted(g: Game) -> Color:
	var a := ambient
	if g == null or not g.L or (a.r > .995 and a.g > .995 and a.b > .995):
		return a
	# tudo por pesos contínuos (noite e cenário de fundo já vêm misturados entre os trechos): a cor
	# da escuridão nunca troca num estalo na passagem de um trecho para outro
	var night: float = clamp(float(g.AMB.get("night", 0.0)), 0.0, 1.0)
	var w: Dictionary = FxClock.nw(g)
	var blue: float = FxClock.wsum(w, ["noite", "vila"]) * night
	var amber: float = FxClock.wsum(w, ["mina", "esconderijo"]) * night
	var lift: float = .38 * (1.0 - night) * clamp((a.r - .4) / .15, 0.0, 1.0)
	a = a.lerp(Color(.97, 1.0, .98), lift)
	a = a.lerp(Color(a.r * .97, a.g, min(1.0, a.b * 1.14 + .03)), blue)
	a = a.lerp(Color(min(1.0, a.r * 1.1 + .02), a.g, a.b * .86), amber)
	return a

## textura do clarão largo da lanterna (feita uma vez): cai devagar até a borda
var _wide: Texture2D
func wide_tex() -> Texture2D:
	if _wide:
		return _wide
	var gr := Gradient.new()
	gr.set_color(0, Color(1, 1, 1, 1))
	gr.add_point(.45, Color(1, 1, 1, .6))
	gr.set_color(gr.get_point_count() - 1, Color(1, 1, 1, 0))
	var t := GradientTexture2D.new()
	t.gradient = gr
	t.fill = GradientTexture2D.FILL_RADIAL
	t.fill_from = Vector2(.5, .5)
	t.fill_to = Vector2(1, .5)
	t.width = 128
	t.height = 128
	_wide = t
	return t

func clear() -> void:
	dots.clear()

func _process(_d: float) -> void:
	var vs := get_viewport().get_visible_rect().size
	# de dia não há o que escurecer: nem desenha (economiza a passada)
	var on: bool = ambient.r < .995 or ambient.g < .995 or ambient.b < .995
	show.visible = on
	if not on:
		vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
		return
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	var sz := Vector2i(int(ceil(vs.x / DIV)), int(ceil(vs.y / DIV)))
	if vp.size != sz:
		vp.size = sz
	show.position = Vector2.ZERO
	show.size = vs
	painter.queue_redraw()

class _Painter extends Node2D:
	var lm
	func _draw() -> void:
		var g: Game = lm.game
		var sz: Vector2 = Vector2(lm.vp.size)
		draw_rect(Rect2(Vector2.ZERO, sz), lm.tinted(g))
		if g == null or g.camera == null:
			return
		var z: float = g.camera.zoom.x
		var cp: Vector2 = g.camera.position
		var k: float = z / DIV
		for d in lm.dots:
			if not d.visible or d.energy <= .01 or d.texture == null:
				continue
			var tw: float = d.texture.get_width() * d.texture_scale
			var th: float = d.texture.get_height() * d.texture_scale
			var sp: Vector2 = (d.position - cp) * k
			var rad: float = max(tw, th) * k
			if sp.x < -rad - abs(d.offset.x) * k or sp.y < -rad or sp.x > sz.x + rad + abs(d.offset.x) * k or sp.y > sz.y + rad:
				continue
			# luzes mais coloridas (lanterna dourada, fogo laranja, cristal azul) e um pouco mais fortes
			var dc: Color = d.color
			var gl: float = (dc.r + dc.g + dc.b) / 3.0
			dc = Color(gl + (dc.r - gl) * 1.22, gl + (dc.g - gl) * 1.22, gl + (dc.b - gl) * 1.22)
			var c: Color = dc * d.energy * 1.3
			c.a = 1.0
			draw_set_transform(sp, d.rotation, Vector2(k * d.texture_scale, k * d.texture_scale))
			var w: float = d.texture.get_width()
			var h: float = d.texture.get_height()
			draw_texture_rect(d.texture, Rect2(d.offset / d.texture_scale - Vector2(w, h) / 2, Vector2(w, h)), false, c)
		draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)
		# lanterna acesa no escuro: um clarão largo e fraco em volta do Tomé, para o chão, as tábuas e
		# os perigos por perto ficarem legíveis (longe continua escuro; o óleo ainda manda no tamanho)
		var amb: float = lm.ambient.r
		if g.lantern_lit and g.running and g.player and amb < .7 and not g.submerged():
			var p: Dictionary = g.player
			var pc: Vector2 = Vector2(p.x + p.w / 2, p.y + p.h / 2)
			var fv: float = clamp(g.fuel_vis, 0.0, 1.0)
			var rw: float = lerpf(420.0, 680.0, fv) * k
			var e: float = (.7 - amb) / .7 * lerpf(.4, .62, fv) * (.25 + .75 * float(p.get("wal", 1.0)))
			var c2 := Color(1, .9, .74) * e
			c2.a = 1.0
			draw_texture_rect(lm.wide_tex(), Rect2((pc - cp) * k - Vector2(rw, rw * .8), Vector2(rw * 2, rw * 1.6)), false, c2)
