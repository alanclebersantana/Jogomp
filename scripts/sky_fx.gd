extends Node2D
## Luz do sol (mistura somada, por cima do cenário e abaixo do HUD): fachos inclinados entre as
## árvores de manhã e à tarde, com poeirinha dourada flutuando dentro da luz.

const FxClock = preload("res://scripts/fx_clock.gd")

var game: Game
var motes: Array = []

func _ready() -> void:
	var m := CanvasItemMaterial.new()
	m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	material = m
	for i in 40:
		motes.append({"x": randf() * 1400, "y": randf() * 700, "p": randf() * TAU, "s": .6 + randf()})

func _process(_d: float) -> void:
	if game and game.L:
		FxClock.update(game)
		_sim()
	queue_redraw()

static func hh(x: float, k: int = 0) -> float:
	var v := sin(x * 12.9898 + k * 78.233) * 43758.5453
	return v - floor(v)

## poeirinha: anda pelo relógio dos efeitos (parada na pausa, mesma velocidade em 60/90/120 Hz)
func _sim() -> void:
	var k: float = FxClock.k
	if k <= 0.0:
		return
	var vs := get_viewport_rect().size
	var z: float = game.camera.zoom.x if game.camera else 1.0
	var dc: float = FxClock.dcam * z
	var wind: float = FxClock.wind(game)
	for m in motes:
		m.p += .01 * k
		m.x += (sin(m.p) * .25 - .12 - wind * .4) * k - dc * .4
		m.y += (cos(m.p * .7) * .2 - .05) * k
		if m.x < -10: m.x += vs.x + 20
		if m.x > vs.x + 10: m.x -= vs.x + 20
		if m.y < -10: m.y += vs.y * .8

## força dos fachos: manhã (bosque), tarde e o moinho (a tarde do Episódio 2), somando no máximo 1
func _sun_k(g: Game) -> float:
	var ws: Dictionary = FxClock.nw(g)
	var k: float = FxClock.wsum(ws, ["bosque", "tarde"]) + float(ws.get("moinho", 0.0)) * .7
	return clamp(k, 0.0, 1.0) * clamp(1.0 - g.AMB.dark * 3.0, 0, 1) * clamp(1.0 - g.AMB.rain * 2.0, 0, 1)

func _draw() -> void:
	var g := game
	if g == null or not g.L or not g.running and g.T == 0:
		return
	if g.low_fx or FxClock.hidden_sky(g):
		return
	var song: String = g.AMB.get("song", "manha")
	var ws: Dictionary = FxClock.nw(g)
	var k: float = _sun_k(g)
	if k <= .01 or song in ["noite", "perseguicao", "tunel"]:
		return
	var vs := get_viewport_rect().size
	var t := FxClock.ft
	var warm := Color(1, .93, .7).lerp(Color(1, .7, .4), FxClock.wsum(ws, ["tarde", "moinho"]))
	# fachos: faixas inclinadas que andam devagar com a câmera (paralaxe do fundo) e respiram
	var step := 420.0
	var cam: float = g.rcam * .25
	var i0 := int(floor((cam - 300) / step))
	var i1 := int(floor((cam + vs.x + 300) / step))
	for i in range(i0, i1 + 1):
		if hh(i, 1) < .35:
			continue
		var x: float = i * step + hh(i, 2) * 200 - cam
		var bw: float = 40 + hh(i, 3) * 90
		var a: float = (.11 + .06 * sin(t * .012 + i * 1.7)) * k
		var sl: float = vs.y * .55
		var pts := PackedVector2Array([Vector2(x, -10), Vector2(x + bw, -10), Vector2(x + bw * 1.9 - sl, vs.y), Vector2(x - sl, vs.y)])
		var cols := PackedColorArray([Color(warm, a), Color(warm, a), Color(warm, 0), Color(warm, 0)])
		draw_polygon(pts, cols)
	# poeirinha brilhando na luz
	for m in motes:
		var tw: float = .5 + .5 * sin(t * .05 + m.p * 3.0)
		draw_circle(Vector2(m.x, m.y), 1.2 * m.s, Color(warm, .5 * tw * k))
