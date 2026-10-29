extends RefCounted
## Relógio dos efeitos visuais (fundo, céu, camada da frente, tela e bichinhos).
## Nada de simulação "por quadro desenhado": cada efeito anda pelo passo deste relógio, que vale
## 1.0 num quadro de 60 Hz (0.5 em 120 Hz) e fica parado quando o jogo para (pausa, quadrinho,
## menus, fim de fase). Também guarda quanto a câmera andou neste quadro (paralaxe sem depender do FPS).
## Uso: const FxClock = preload("res://scripts/fx_clock.gd"); FxClock.update(game) no começo do quadro.

static var k := 0.0          # passo deste quadro em "quadros de 60 Hz" (0 = parado)
static var ft := 0.0         # tempo suave em passos do jogo (acompanha game.T, sem degraus)
static var dcam := 0.0       # quanto a câmera andou neste quadro (unidades do mundo)
static var dcam_y := 0.0
static var live := false     # o jogo está andando?
static var _T := -1
static var _idle := 0.0
static var _us := 0
static var _frame := -1
static var _rcam := 0.0
static var _rcam_y := 0.0
static var _L = null

static func update(g) -> void:
	var f := Engine.get_process_frames()
	if f == _frame or g == null or not g.L:
		return
	_frame = f
	var now := Time.get_ticks_usec()
	var d: float = 0.0 if _us == 0 else clamp((now - _us) / 1000000.0, 0.0, .05)
	_us = now
	if g.T != _T:
		# jogo andou: o tempo suave alcança o contador (sem pular para trás)
		if _T < 0 or abs(g.T - ft) > 3.0 or _L != g.L:
			ft = float(g.T)
		_T = g.T
		_idle = 0.0
	else:
		_idle += d
	live = g.running and _idle < .12
	k = d * 60.0 if live else 0.0
	if live:
		var tps: float = Engine.physics_ticks_per_second
		ft = clamp(ft + d * tps, float(g.T) - 1.0, float(g.T) + 1.0)
	# câmera: o quanto andou neste quadro (teleporte/troca de fase não conta)
	var dc: float = g.rcam - _rcam
	var dcy: float = g.rcam_y - _rcam_y
	if _L != g.L or abs(dc) > 160 or abs(dcy) > 160:
		dc = 0.0
		dcy = 0.0
	_L = g.L
	_rcam = g.rcam
	_rcam_y = g.rcam_y
	dcam = dc
	dcam_y = dcy

## pesos dos cenários normalizados (somam 1): o que está saindo perde o que o que chega ganha
static func nw(g) -> Dictionary:
	var ws: Dictionary = g.section_weights()
	if ws.size() < 2:
		return ws
	var keys := ws.keys()
	var out := {}
	var tot := 0.0
	for key in keys:
		tot += float(ws[key])
	# o de peso 1 é o trecho atual; o outro é o que vem chegando (peso t)
	var cur = keys[0] if float(ws[keys[0]]) >= float(ws[keys[1]]) else keys[1]
	var nxt = keys[1] if cur == keys[0] else keys[0]
	out[cur] = 1.0 - float(ws[nxt])
	out[nxt] = float(ws[nxt])
	return out

## mistura de uma tabela de cores pelos pesos dos cenários (sem saltos na troca de trecho)
static func blend(w: Dictionary, table: Dictionary, def: Color) -> Color:
	var c := Color(0, 0, 0, 0)
	var tot := 0.0
	for key in w:
		var cc: Color = table.get(key, def)
		var a: float = w[key]
		c = Color(c.r + cc.r * a, c.g + cc.g * a, c.b + cc.b * a, c.a + cc.a * a)
		tot += a
	if tot <= 0.0:
		return def
	return Color(c.r / tot, c.g / tot, c.b / tot, c.a / tot)

## soma dos pesos de alguns cenários (0..1)
static func wsum(w: Dictionary, keys: Array) -> float:
	var s := 0.0
	for key in keys:
		s += float(w.get(key, 0.0))
	return clamp(s, 0.0, 1.0)

## vento "visual": vento do trecho + rajadas (contínuo, sem saltos)
static func wind(g) -> float:
	return float(g.AMB.get("wind", 0.0)) + Polish.gust_k() * .8 if Polish.g else float(g.AMB.get("wind", 0.0))

## o Tomé está num lugar fechado (debaixo da terra, mina, túnel) ou com a cabeça debaixo d'água?
static func hidden_sky(g) -> bool:
	if g.indoors():
		return true
	if g.has_method("submerged") and g.submerged():
		return true
	return false
