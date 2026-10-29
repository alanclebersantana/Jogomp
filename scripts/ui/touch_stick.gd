extends Control
## Controle de movimento pelo toque, com um dedo só:
## - "dpad": direcional de 8 direções (inclui diagonais: ↘ anda abaixado, ↗ sobe andando)
## - "analog": analógico fixo no canto (inclinar pouco = andar devagar); a base não sai do lugar

signal changed(keys: Dictionary)

var mode := "dpad"
var finger := -1
var center := Vector2.ZERO
var knob := Vector2.ZERO
var radius := 74.0
var dead := 14.0
var state := {"L": false, "R": false, "U": false, "S": false}
var axis := 1.0
var tex := {}
var home := Vector2.ZERO
var ui_scale := 1.0
var opacity := .8
var left_handed := false

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	for k in ["L", "R", "U", "S"]:
		tex[k] = load("res://assets/ui/pad_%s.png" % k)
	# analógico de madeira (base com moldura de latão e pegador de madeira)
	if ResourceLoader.exists("res://assets/ui/stick_base.png"):
		tex["base"] = load("res://assets/ui/stick_base.png")
	if ResourceLoader.exists("res://assets/ui/stick_knob.png"):
		tex["knob"] = load("res://assets/ui/stick_knob.png")

func set_mode(m: String) -> void:
	mode = m
	_release()

func _home() -> Vector2:
	var vs := get_viewport_rect().size
	var x := 150.0 * ui_scale   # longe da borda: deslizar da borda é o gesto de "voltar" do Android
	# longe da borda de baixo também: deslizar dali é o gesto de "início" do Android
	var h := Vector2(vs.x - x if left_handed else x, vs.y - 158 * ui_scale)
	return h + offset

## deslocamento escolhido pelo jogador (opções → posicionar botões)
var offset := Vector2.ZERO

func _in_zone(p: Vector2) -> bool:
	var vs := get_viewport_rect().size
	if mode == "dpad":
		return p.distance_to(_home()) < radius * ui_scale * 1.9
	# analógico: em volta da base (um pouco maior que ela, para o polegar não escapar)
	return p.distance_to(_home()) < radius * ui_scale * 2.1 and p.y > vs.y * .3

func _input(e: InputEvent) -> void:
	if mode == "gamepad" or not is_visible_in_tree():
		return
	if e is InputEventScreenTouch:
		var p := _to_local(e.position)
		if e.pressed and finger == -1 and _in_zone(p):
			finger = e.index
			center = _home()
			_update(p)
		elif not e.pressed and e.index == finger:
			_release()
	elif e is InputEventScreenDrag and e.index == finger:
		_update(_to_local(e.position))

func _to_local(p: Vector2) -> Vector2:
	return get_global_transform_with_canvas().affine_inverse() * p

func _release() -> void:
	finger = -1
	knob = Vector2.ZERO
	axis = 1.0
	_apply({"L": false, "R": false, "U": false, "S": false})

func _update(p: Vector2) -> void:
	var v := p - center
	var rr := radius * ui_scale
	knob = v.limit_length(rr)
	var s := {"L": false, "R": false, "U": false, "S": false}
	axis = 1.0
	if v.length() >= dead * ui_scale:
		if mode == "dpad":
			# 8 setores de 45°: direita, ↘, baixo, ↙, esquerda, ↖, cima, ↗
			var sec := int(round(atan2(v.y, v.x) / (PI / 4))) % 8
			if sec < 0:
				sec += 8
			match sec:
				0: s.R = true
				1: s.R = true; s.S = true
				2: s.S = true
				3: s.S = true; s.L = true
				4: s.L = true
				5: s.L = true; s.U = true
				6: s.U = true
				7: s.U = true; s.R = true
		else:
			var x := v.x / rr
			var y := v.y / rr
			if x > .3:
				s.R = true
			elif x < -.3:
				s.L = true
			if y > .45 and y > abs(x) * .5:
				s.S = true
			elif y < -.45 and -y > abs(x) * .5:
				s.U = true
			axis = clamp(abs(x) * 1.25, .4, 1.0)
	_apply(s)

func _apply(s: Dictionary) -> void:
	if s != state:
		state = s
		changed.emit(s)
	queue_redraw()

func _process(_d: float) -> void:
	queue_redraw()

func _draw() -> void:
	if mode == "gamepad":
		return
	var r := radius * ui_scale
	var al := opacity
	if mode == "dpad":
		var c := _home()
		draw_circle(c, r * 1.18, Color(.1, .08, .05, .18 * al))
		var off := {"L": Vector2(-1, 0), "R": Vector2(1, 0), "U": Vector2(0, -1), "S": Vector2(0, 1)}
		for k in off:
			var t: Texture2D = tex[k]
			var sz := 62.0 * ui_scale
			var pos: Vector2 = c + off[k] * 58 * ui_scale - Vector2(sz, sz) / 2
			var on: bool = state[k]
			draw_texture_rect(t, Rect2(pos, Vector2(sz, sz)), false, Color(1.25, 1.2, 1, min(1, al + .25)) if on else Color(1, 1, 1, al))
		if finger != -1:
			draw_circle(c + knob, 12 * ui_scale, Color(1, .95, .8, .4 * al))
	else:
		var c2 := _home()
		var a := (.7 if finger != -1 else .38) * al
		if tex.has("base") and tex.has("knob"):
			var ab: float = min(1.0, (.95 if finger != -1 else .7) * al + .15)
			var br: float = r * 1.12
			draw_texture_rect(tex.base, Rect2(c2 - Vector2(br, br), Vector2(br, br) * 2), false, Color(1, 1, 1, ab))
			var kr: float = 34 * ui_scale
			draw_texture_rect(tex.knob, Rect2(c2 + knob - Vector2(kr, kr), Vector2(kr, kr) * 2), false, Color(1, 1, 1, min(1.0, ab + .1)))
			return
		draw_circle(c2, r, Color(.1, .08, .05, a * .7))
		draw_arc(c2, r, 0, TAU, 48, Color(.93, .85, .65, a), 3, true)
		draw_circle(c2 + knob, 30 * ui_scale, Color(.93, .85, .65, a + .15))
		draw_arc(c2 + knob, 30 * ui_scale, 0, TAU, 32, Color(.35, .25, .12, a + .15), 2, true)
