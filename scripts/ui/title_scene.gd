extends Control
## Fundo vivo da tela de título: noite no bosque com a câmera passeando devagar, o Tomé sentado
## na fogueira, o Pipoca dormindo, fagulhas subindo e vagalumes.

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
	var bg: Texture2D = Spr.tex["bg_noite"]
	# fundo pintado passando devagar (a câmera passeia de um lado para o outro)
	var sc: float = vs.y * 1.15 / bg.get_height()
	var tw: float = bg.get_width() * sc
	var pan: float = (sin(t * .0016) * .5 + .5) * max(0.0, tw - vs.x)
	Spr.ci.draw_texture_rect(bg, Rect2(-pan, -vs.y * .1, tw, bg.get_height() * sc), false, Color(.75, .72, .8))
	Spr.vgrad(0, vs.y * .55, vs.x, vs.y * .45, Color(0, 0, 0, 0), Color(.03, .02, .02, .85))
	# vagalumes
	for i in 22:
		var fx: float = fposmod(i * 173.0 + sin(t * .01 + i) * 40 - pan * .3, vs.x)
		var fy: float = vs.y * .25 + fposmod(i * 97.0, vs.y * .5) + sin(t * .02 + i * 1.3) * 14
		var on: float = .5 + .5 * sin(t * .07 + i * 2.1)
		Spr.glow(fx, fy, 12, Color(.75, 1, .4, .3 * on))
		Spr.circle(fx, fy, 1.8, Color(.9, 1, .6, .9 * on))
	# fogueira com o Tomé e o Pipoca, no canto de baixo
	var cx: float = vs.x * .2
	var cy: float = vs.y * .9
	var fl: float = .85 + sin(t * .31) * .08 + sin(t * .73) * .05
	Spr.glow(cx, cy - 40, 300 * fl, Color(1, .55, .2, .28))
	Spr.glow(cx, cy - 30, 120 * fl, Color(1, .75, .35, .45))
	Spr.ellipse(cx - 30, cy + 6, 220, 20, Color(.12, .07, .04, .9))
	Spr.rr(cx - 170, cy - 14, 100, 22, 11, Color("#4a2e18"))
	Spr.A("pai_crouch", cx - 115, cy - 6, 1.3)
	Spr.glow(cx - 90, cy - 45, 60, Color(1, .6, .25, .2))
	Spr.save()
	Spr.translate(cx + 120, cy + 6)
	Spr.scale(-.7, .7 * (.5 + sin(t * .04) * .015))
	Spr.A("dog0", 0, 0, 1.0)
	Spr.restore()
	Spr.text("z", cx + 110 + sin(t * .03) * 4, cy - 50 - fmod(t * .3, 30.0), 16, Color(1, .95, .8, .55), HORIZONTAL_ALIGNMENT_CENTER, Spr.font_i)
	Spr.A("o_fire_on", cx, cy + 4, 1.3)
	for i in 10:
		var u: float = fmod(t * .01 + i / 10.0, 1.0)
		Spr.circle(cx + sin(i * 2.1 + t * .05) * 30 * u, cy - 40 - u * 260, 3 * (1.0 - u) + .5, Color(1, .7, .3, 1.0 - u))
