extends Control
## Ao pegar um desenho da Isis: o papel aparece grande e o desenho vai surgindo traço por traço,
## como se alguém estivesse colorindo com lápis de cor; depois ele encolhe e voa para o contador.

var kind := 0
var t := 0.0
var kd: Control
const DUR := 3.4

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	kd = preload("res://scripts/ui/kid_drawing.gd").new()
	kd.kind = kind
	kd.custom_minimum_size = Vector2(300, 190)
	kd.size = Vector2(300, 190)
	kd.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(kd)

func _process(d: float) -> void:
	t += d
	if t >= DUR:
		queue_free()
		return
	var vs := get_viewport_rect().size
	var sz := Vector2(300, 190)
	var center := vs / 2 - sz / 2
	# voa até o papelzinho do contador de desenhos (HUD: placa da direita, ícone em W - 180, 24).
	# A escala é em volta do centro (pivot), então o centro do desenho vai parar em cima do ícone
	# (antes terminava fora da tela, à direita e abaixo do contador)
	var dest := Vector2(vs.x - 180, 24) - sz / 2
	var fly: float = clamp((t - 2.6) / .8, 0, 1)
	var e: float = fly * fly * (3 - 2 * fly)
	var sc: float = lerpf(1.0, .1, e)
	kd.position = center.lerp(dest, e)
	kd.scale = Vector2(sc, sc)
	kd.pivot_offset = sz / 2
	kd.rotation = sin(t * 2.0) * .03 * (1.0 - e)
	kd.reveal = clamp((t - .25) / 2.1, 0, 1)
	kd.queue_redraw()
	queue_redraw()

func _draw() -> void:
	var vs := get_viewport_rect().size
	var fade: float = clamp(t / .3, 0, 1) * (1.0 - clamp((t - 2.6) / .8, 0, 1))
	draw_rect(Rect2(Vector2.ZERO, vs), Color(0, 0, 0, .45 * fade))

