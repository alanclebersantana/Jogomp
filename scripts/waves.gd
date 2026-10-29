extends RefCounted
class_name Waves
## Superfície da água com física de molas (no estilo cartoon, mas com movimento de verdade):
## cada corpo d'água (lagos de mergulho, brejo tóxico e os trechos da corredeira) tem colunas a cada
## 16 px que sobem e descem; uma coluna puxa as vizinhas e as ondas se espalham e se acalmam.
## Quem entra, sai, nada perto da superfície ou cai na água empurra as colunas (ondulação e respingo).

const STEP := 16.0
const K := .022          # mola de volta ao nível
const DAMP := .028       # atrito (a água se acalma)
const SPREAD := .24      # quanto cada coluna puxa a vizinha
const MAXH := 9.0

var g
var B := {}              # chave -> {"x0","x1","y","h": PackedFloat32Array, "v": PackedFloat32Array}
var was_swim := false
var was_y := 0.0
## ondinhas em anel na superfície (quem entra, sai ou nada): {key, x, t, life, s}; desenhadas em world_glow
var RINGS: Array = []
const MAX_RINGS := 24
## efeitos de ambiente que avançam no passo de física (AmbientFx, carregado na primeira vez)
static var _afx = null

func _init(game) -> void:
	g = game

func load_level() -> void:
	B = {}
	was_swim = false
	RINGS = []

## colunas do corpo d'água (cria na primeira vez que é desenhado ou tocado)
func body(key: String, x0: float, x1: float, y: float) -> Dictionary:
	if not B.has(key):
		var n: int = int(ceil((x1 - x0) / STEP)) + 1
		var h := PackedFloat32Array()
		var v := PackedFloat32Array()
		h.resize(n)
		v.resize(n)
		B[key] = {"x0": x0, "x1": x1, "y": y, "h": h, "v": v, "act": 0}
	var b: Dictionary = B[key]
	b.y = y
	return b

## altura da onda em x (positivo = para baixo, como o eixo y da tela)
func height(b: Dictionary, x: float) -> float:
	var f: float = (x - b.x0) / STEP
	var i: int = int(floor(f))
	var hh: PackedFloat32Array = b.h
	if i < 0:
		return hh[0] if hh.size() > 0 else 0.0
	if i >= hh.size() - 1:
		return hh[hh.size() - 1]
	var t: float = f - i
	return lerpf(hh[i], hh[i + 1], t)

## empurrão na água em x (força > 0 afunda a superfície ali; respingo opcional)
func splash(x: float, y: float, force: float, drops: bool = true) -> void:
	for k in B:
		var b: Dictionary = B[k]
		if x < b.x0 - 8 or x > b.x1 + 8 or abs(y - b.y) > 60:
			continue
		var i: int = clamp(int(round((x - b.x0) / STEP)), 0, b.v.size() - 1)
		var vv: PackedFloat32Array = b.v
		for d in [-1, 0, 1]:
			var j: int = i + d
			if j >= 0 and j < vv.size():
				vv[j] += force * (1.0 if d == 0 else .6)
		b.v = vv
		b.act = 240
		if abs(force) > .8:
			ring(k, x, clamp(abs(force) / 5.0, .5, 1.6))
		if drops and abs(force) > 1.5:
			var c := Color(.8, .93, 1, .9) if not k.begins_with("s") else Color(.7, 1, .4, .9)
			for n in int(min(14.0, abs(force) * 2.0)):
				Polish.part("drop", x + randf_range(-10, 10), b.y - 2, randf_range(-2.4, 2.4), -randf_range(2.0, 4.0 + abs(force) * .4), int(22 + randf() * 12), c, {"g": .18})
		return

## anel de ondinha na superfície do corpo d'água "key" em x (s = tamanho); lista com limite
func ring(key: String, x: float, s: float = 1.0) -> void:
	if RINGS.size() >= MAX_RINGS:
		RINGS.pop_front()
	RINGS.append({"key": key, "x": x, "t": 0, "life": 46, "s": s})

## física: só os corpos perto da tela (e por alguns segundos depois de mexidos)
func step() -> void:
	# ondinhas em anel: avançam e somem
	for r in RINGS:
		r.t += 1
	RINGS = RINGS.filter(func(r): return r.t < r.life)
	# efeitos de ambiente (esporos, faíscas, galhos, pingos de gelo): uma vez por passo de física
	if _afx == null:
		_afx = load("res://scripts/ambient_fx.gd")
	_afx.tick(g)
	var c0: float = g.cam - 300
	var c1: float = g.cam + g.W + 300
	for k in B:
		var b: Dictionary = B[k]
		if b.x1 < c0 or b.x0 > c1:
			continue
		var hh: PackedFloat32Array = b.h
		var vv: PackedFloat32Array = b.v
		var n: int = hh.size()
		for i in n:
			vv[i] += -K * hh[i] - DAMP * vv[i]
			hh[i] = clamp(hh[i] + vv[i], -MAXH, MAXH)
		# espalha para as vizinhas (duas passadas: a onda anda mais rápido e mais lisa)
		for it in 2:
			for i in range(1, n):
				var d: float = SPREAD * (hh[i - 1] - hh[i])
				vv[i] += d
				vv[i - 1] -= d
		b.h = hh
		b.v = vv
		# vento e chuva mexendo a água o tempo todo (as ondinhas se espalham pela física)
		if n > 2:
			if g.T % 9 == 0:
				var j: int = randi() % n
				vv[j] += randf_range(-.6, .6)
			var rain: float = g.AMB.get("rain", 0.0)
			if rain > .1 and randf() < rain * .5:
				var j2: int = randi() % n
				vv[j2] += randf_range(.4, 1.1)
			b.v = vv
	_player_waves()
	_enemy_waves()

## o Tomé mexendo a água: entrar, sair, nadar na superfície
func _player_waves() -> void:
	var p: Dictionary = g.player
	var pcx: float = p.x + p.w / 2
	var swim: bool = p.get("swim", false)
	if swim and not was_swim:
		splash(pcx, p.y + p.h - 10, clamp(abs(was_y) * .9 + 2.0, 2.5, 9.0))
		Audio.play("splash", -8)
	elif was_swim and not swim:
		splash(pcx, p.y + p.h, -3.5)
	elif swim and abs(p.vx) > .8 and g.T % 6 == 0:
		# nadando perto da superfície deixa um rastro de ondinhas
		splash(pcx - sign(p.vx) * 10, p.y + 10, .9, false)
	was_swim = swim
	was_y = p.vy

## bichos entrando e saindo da água (sapos, javali, cachorro...): respingo e ondinha
func _enemy_waves() -> void:
	if B.is_empty() or g.T % 2 != 0:
		return
	var x0: float = g.cam - 100
	var x1: float = g.cam + g.W + 100
	for e in g.EN:
		if e.get("dead", 0) or e.x < x0 or e.x > x1 or e.get("k", "") in ["piranha", "leech"]:
			continue
		var inw := false
		var key := ""
		for k in B:
			var b: Dictionary = B[k]
			if e.x > b.x0 and e.x < b.x1 and e.y > b.y - 2 and e.y < b.y + 260:
				inw = true
				key = k
				break
		var was = e.get("_inw")
		e._inw = inw
		if was == null or was == inw:
			continue
		if inw:
			splash(e.x, B[key].y, 3.5)
		else:
			splash(e.x, e.y, -2.0, false)
