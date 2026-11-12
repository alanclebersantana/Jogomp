extends Control
## Fundo vivo da tela de título do aeroporto: o saguão de Guarulhos com a câmera passeando devagar,
## o Milis correndo pelo terminal, um avião decolando lá fora, painéis piscando e poeira na luz.

var t := 0.0

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _process(d: float) -> void:
	t += d * 60.0
	queue_redraw()

func _draw() -> void:
	Spr.begin(self)
	var vs := get_viewport_rect().size
	var bg: Texture2D = Spr.tex.get("bg_vila")
	if bg == null:
		return
	# saguão pintado passando devagar (a câmera vai e volta)
	var sc: float = vs.y * 1.08 / bg.get_height()
	var tw: float = bg.get_width() * sc
	var pan: float = (sin(t * .0018) * .5 + .5) * max(0.0, tw - vs.x)
	Spr.ci.draw_texture_rect(bg, Rect2(-pan, -vs.y * .04, tw, bg.get_height() * sc), false, Color(.86, .86, .9))
	# avião decolando lá fora (atrás das vidraças, na altura da pista)
	var per := 900.0
	var u: float = fmod(t, per) / per
	if Spr.AR.has("p_ob_aviao"):
		var ax: float = lerpf(-200.0, vs.x + 260.0, u) - pan * .2
		var ay: float = vs.y * .58 - max(0.0, u - .35) * vs.y * .55
		Spr.P("ob_aviao", ax, ay, vs.x * .16, false, -.12 * clamp((u - .35) * 4.0, 0.0, 1.0), Color(1, 1, 1, .55))
	# faixas de luz do sol e poeirinha nelas
	for i in 4:
		var x0: float = fposmod(i * vs.x * .34 - pan * .6, vs.x * 1.36) - vs.x * .18
		Spr.poly(PackedVector2Array([Vector2(x0, 0), Vector2(x0 + vs.x * .08, 0), Vector2(x0 + vs.x * .24, vs.y), Vector2(x0 + vs.x * .13, vs.y)]),
			Color(1, .94, .74, .07))
	for i in 30:
		var fx: float = fposmod(i * 211.0 + t * (.15 + fmod(i * .37, .3)) - pan * .3, vs.x)
		var fy: float = vs.y * .1 + fposmod(i * 97.0 - t * .05, vs.y * .7) + sin(t * .02 + i) * 10.0
		var on: float = .5 + .5 * sin(t * .06 + i * 2.1)
		Spr.circle(fx, fy, 1.5, Color(1, .97, .88, .35 + .4 * on))
	# chão do saguão e o Milis correndo de um lado ao outro (vai e volta), com poeirinha nos pés
	Spr.vgrad(0, vs.y * .7, vs.x, vs.y * .3, Color(0, 0, 0, 0), Color(.04, .05, .08, .4))
	var lap := 520.0
	var k: float = fmod(t, lap * 2.0)
	var right: bool = k < lap
	var v: float = (k if right else lap * 2.0 - k) / lap
	var mx: float = lerpf(-80.0, vs.x + 80.0, v)
	var my: float = vs.y * .87
	var fr: String = "pai_run1" if int(t / 7.0) % 2 == 0 else "pai_run2"
	Spr.A(fr, mx, my - abs(sin(t * .45)) * 4.0, .95 * vs.y / 540.0, not right)
	if int(t) % 6 == 0:
		Spr.circle(mx - (12.0 if right else -12.0), my - 2, 3, Color(1, 1, 1, .25))
	# (o painel do título já escurece por cima)
	pass
