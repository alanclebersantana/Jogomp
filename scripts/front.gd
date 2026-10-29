extends Node2D
## Camada da frente (entre o mundo e o HUD): silhuetas de capim, samambaias, galhos e pedras
## passando mais rápido que o cenário (paralaxe), folhas voando, sombras de nuvens, riscos e poeira
## de vento nas rajadas e a neblina do clima.
## A simulação anda em _process pelo relógio dos efeitos (FxClock): parada na pausa e igual em
## 60/90/120 Hz. O _draw só desenha.

const FxClock = preload("res://scripts/fx_clock.gd")

var game: Game
var leaves: Array = []
var fog: Array = []
var streaks: Array = []
var drift: Array = []
const PAR := 1.45     # a camada da frente anda 45% mais rápido que o mundo
const NLEAF := 70
## camadas de profundidade das folhas: tamanho, velocidade, paralaxe da câmera
const LZ_S := [.55, 1.0, 1.55]
const LZ_V := [.6, 1.0, 1.35]
const LZ_P := [.18, .35, .9]

## cor das silhuetas da frente em cada cenário (misturada pelos pesos: sem salto na troca)
const SIL := {"bosque": Color(.07, .13, .05), "tarde": Color(.14, .08, .04), "moinho": Color(.13, .09, .04),
	"pantano": Color(.04, .09, .07), "noite": Color(.02, .03, .06), "vila": Color(.02, .03, .06),
	"neve": Color(.55, .62, .78), "mina": Color(.05, .035, .025), "esconderijo": Color(.05, .035, .025)}
## folhas de cada cenário
const LEAF_C := {
	"bosque": [Color(.42, .6, .2), Color(.55, .7, .3), Color(.36, .52, .2), Color(.48, .66, .24), Color(.85, .75, .25)],
	"tarde": [Color(.93, .62, .2), Color(.85, .38, .16), Color(.95, .78, .3), Color(.72, .22, .14), Color(.8, .3, .18)],
	"moinho": [Color(.93, .66, .24), Color(.85, .45, .18), Color(.95, .8, .35), Color(.6, .62, .25)],
	"pantano": [Color(.3, .38, .2), Color(.4, .42, .22), Color(.46, .36, .2)],
	"noite": [Color(.3, .34, .2), Color(.4, .3, .16)], "vila": [Color(.4, .3, .16), Color(.3, .34, .2)],
	"neve": [Color(.55, .42, .28), Color(.62, .5, .32)]}
## quantas folhas de cada cenário (sem vento)
const LEAF_N := {"bosque": 10.0, "tarde": 14.0, "moinho": 12.0, "pantano": 6.0, "noite": 4.0, "vila": 4.0, "neve": 3.0}
const SHADOW_C := {"bosque": Color(0, .02, .08), "tarde": Color(.12, .02, .1), "moinho": Color(.1, .03, .08), "neve": Color(0, .05, .2)}

var _hide := false        # debaixo da terra, dentro da mina/túnel ou com a cabeça na água
var _nf := 0.0            # quantidade de folhas (suave)
var _burst := 0.0         # rajada: folhas extras por um tempo
var _gust_prev := 0.0
var _trees := 1.0
var _trees_T := -999
var _sway_ph := 0.0
var _cs := [0.0, 0.0, 0.0]
var _sky := Color(.8, .85, .9)
var _gl := 9999.0         # linha do chão (pés do Tomé) na tela

func _ready() -> void:
	for i in NLEAF:
		var l := {"x": randf() * 1400, "y": randf() * 540, "vx": 0.0, "vy": 0.0, "r": randf() * TAU, "r0": randf() * TAU, "vr": 0.0,
			"s": .7 + randf() * .6, "ph": i * 1.7, "sp": randf() * TAU, "a": 0.0, "st": 0, "lt": 0.0,
			"z": 2 if i % 7 == 3 else (0 if i % 3 == 0 else 1), "dry": i % 9 == 4, "c": Color(.42, .6, .2), "hv": randf()}
		leaves.append(l)
	for i in 7:
		fog.append({"x": randf() * 1600, "y": 150 + randf() * 330, "w": 420 + randf() * 420, "h": 140 + randf() * 120, "v": .15 + randf() * .3, "a": .5 + randf() * .5})
	for i in 7:
		streaks.append({"x": randf() * 1400, "y": randf() * 400, "l": 60 + randf() * 90, "v": 10 + randf() * 8, "a": 0.0})
	for i in 12:
		drift.append({"x": randf() * 1400, "y": 0.0, "dy": randf() * 26, "l": 18 + randf() * 30, "v": 7 + randf() * 6, "ph": randf() * TAU})

func _process(_d: float) -> void:
	if game and game.L and game.player:
		FxClock.update(game)
		_sim()
	queue_redraw()

static func hh(x: float, k: int = 0) -> float:
	var v := sin(x * 12.9898 + k * 78.233) * 43758.5453
	return v - floor(v)

# ================================================================ simulação
func _sim() -> void:
	var g := game
	var k: float = FxClock.k
	var vs := get_viewport_rect().size
	var z: float = g.camera.zoom.x if g.camera else 1.0
	var p: Dictionary = g.player
	_hide = (g.L.has("under") and p.y > g.L.under + 60) or FxClock.hidden_sky(g)
	var nw: Dictionary = FxClock.nw(g)
	_sky = FxClock.blend(nw, preload("res://scripts/bg.gd").SKY, Color(.8, .85, .9))
	if p.get("onGround", false):
		_gl = (p.y + p.h - g.rcam_y) * z
	var wind: float = g.AMB.get("wind", 0.0)
	var gust: float = Polish.gust_k() if Polish.g else 0.0
	var tps: float = Engine.physics_ticks_per_second / 60.0
	_sway_ph += k * tps * (.02 + wind * .04 + gust * .03)
	for i in 3:
		_cs[i] += k * tps * (.35 + i * .12) * (1.0 + wind * 2.5 + gust * 2.0)
	if k <= 0.0:
		return
	# rajada subindo: um punhado de folhas extras entra pelo lado de onde vem o vento
	if gust > .45 and _gust_prev <= .45 and not _hide:
		_burst = 200.0
	_gust_prev = gust
	_burst = max(0.0, _burst - k)
	_nf = lerpf(_nf, _leaf_target(nw), 1.0 - pow(.97, k))
	_sim_leaves(k, vs, z, nw, wind, gust)
	_sim_wind(k, vs, gust, wind)
	var fa: float = g.AMB.get("fog", 0.0)
	if fa > 0:
		var dc: float = FxClock.dcam * z
		for f in fog:
			f.x -= (f.v + wind * .8) * k + dc * .5
			if f.x + f.w < -100:
				f.x = vs.x + 50
			if f.x > vs.x + 400:
				f.x = -f.w

## quantas folhas agora: cenário, vento, árvores por perto e o parâmetro do trecho
func _leaf_target(nw: Dictionary) -> float:
	var g := game
	if _hide:
		return 0.0
	var n := 0.0
	for key in nw:
		n += float(LEAF_N.get(key, 0.0)) * float(nw[key])
	# árvores (troncos, galhos, casa na árvore) perto da câmera: mais folhas
	if g.T - _trees_T > 20 or g.T < _trees_T:
		_trees_T = g.T
		var c := 0
		for s in g.SOL:
			if str(s.get("t", "")) in ["trunk", "treehouse", "deadtree", "branch"] and s.x + s.get("w", 0) > g.cam - g.W * .5 and s.x < g.cam + g.W * 1.5:
				c += 1
		_trees = 1.0 + min(c, 4) * .15
	n *= _trees
	var wind: float = g.AMB.get("wind", 0.0)
	n = lerpf(n, 26.0, clamp(wind, 0, 1))
	var sl = g.sec_param("leaves", null)
	if sl != null:
		n = max(n, float(sl))
	if g.AMB.get("snow", 0.0) > .3:
		n = 26.0 * float(g.AMB.get("snowfall", g.AMB.snow)) + 3.0
	if _burst > 0:
		n += 14.0 * clamp(_burst / 60.0, 0, 1)
	return clamp(n, 0.0, float(NLEAF))

## folha nova: cor do cenário (sorteio pelos pesos) e camada
func _respawn_leaf(l: Dictionary, vs: Vector2, nw: Dictionary, from_side: bool) -> void:
	if from_side:
		l.x = vs.x + 20 + randf() * 80
		l.y = randf() * vs.y * .75
	else:
		l.x = randf() * (vs.x + 200)
		l.y = -20 - randf() * 40
	l.vx = 0.0
	l.vy = 0.0
	l.st = 0
	l.lt = 0.0
	l.hv = randf()
	var r := randf()
	var key := "bosque"
	for kk in nw:
		r -= float(nw[kk])
		key = kk
		if r <= 0.0:
			break
	var pal: Array = LEAF_C.get(key, LEAF_C.bosque)
	# no bosque, só de vez em quando uma folha amarela
	var ci: int = randi() % pal.size()
	if key == "bosque" and ci == pal.size() - 1 and randf() < .7:
		ci = 0
	l.c = pal[ci]

func _sim_leaves(k: float, vs: Vector2, z: float, nw: Dictionary, wind: float, gust: float) -> void:
	var g := game
	var p: Dictionary = g.player
	var dc: float = FxClock.dcam * z
	var dcy: float = FxClock.dcam_y * z
	var rain: float = g.AMB.rain
	var snowing: bool = g.AMB.get("snow", 0.0) > .3
	var fall: float = g.AMB.get("snowfall", g.AMB.get("snow", 0.0))
	var t := FxClock.ft
	var psx: float = (p.x + p.w / 2 - g.rcam) * z
	var psy: float = (p.y + p.h - g.rcam_y) * z
	var pvx: float = p.vx
	var e6: float = 1.0 - pow(1.0 - .06, k)
	var e8: float = 1.0 - pow(1.0 - .08, k)
	var e10: float = 1.0 - pow(1.0 - .1, k)
	var nf: int = int(round(_nf))
	for i in NLEAF:
		var l: Dictionary = leaves[i]
		var want: bool = i < nf
		if want and l.a <= 0.0:
			# entrando agora: nas rajadas, pelo lado do vento; senão, de cima
			_respawn_leaf(l, vs, nw, _burst > 0.0 and randf() < .7)
		l.a = clamp(l.a + (.04 if want else -.04) * k, 0.0, 1.0)
		if l.a <= 0.0:
			continue
		var zi: int = l.z
		var zv: float = LZ_V[zi]
		var zp: float = LZ_P[zi]
		if snowing and not l.dry:
			# floco de neve: cai devagar, de lado com o vento
			l.ph = float(l.ph) + .03 * k
			l.y += (.5 + l.s * .6 + fall * .6) * zv * k - dcy * zp * .5
			l.x += (sin(l.ph) * .35 - .25 - wind * 2.4 - gust * 1.5) * zv * k - dc * zp
			_wrap(l, vs, nw)
			continue
		if l.st == 1:
			# pousada no chão: anda com a câmera e some aos poucos (ou levanta com o Tomé passando)
			l.x -= dc * zp
			l.y -= dcy * zp
			l.lt += k
			if abs(pvx) > 2.5 and abs(l.x - psx) < 50 and abs(l.y - psy) < 30:
				l.st = 0
				l.vy = -2.2 - randf()
				l.vx = sign(pvx) * (2.0 + randf() * 2.0)
			elif l.lt > 130:
				_respawn_leaf(l, vs, nw, false)
			continue
		# folha caindo de verdade: balança como um pêndulo (desce mais rápido no meio do arco,
		# quase para nas pontas), inclina para o lado do balanço e vira no ar mostrando o avesso
		l.ph = float(l.ph) + (.035 + l.s * .012 + wind * .03) * k
		var sw: float = sin(l.ph)
		var flut: float = 1.0 - clamp(rain, 0, 1) * .5
		l.vx = lerpf(l.vx, (-1.2 - wind * 5.5 - gust * 3.0 + sw * (1.3 - wind * .6) * flut) * zv, e6)
		l.vy = lerpf(l.vy, (.35 + (1.0 - abs(sw)) * .9 * flut + sin(t * .05 + i * 2.0) * .15 + rain * 1.4) * zv, e8)
		l.vr = lerpf(float(l.vr), sw * .5 - wind * .3, e10)
		l.sp = float(l.sp) + (.04 + l.s * .03 + wind * .05 + gust * .05) * k
		# rastro do Tomé correndo: as folhas por perto rodopiam atrás dele
		if zi >= 1 and abs(pvx) > 2.8:
			var dx: float = l.x - psx
			var dy: float = l.y - (psy - 30)
			var d2: float = dx * dx + dy * dy
			if d2 < 120.0 * 120.0:
				var f: float = 1.0 - sqrt(d2) / 120.0
				l.vx += sign(pvx) * f * .55 * k
				l.vy -= f * .35 * k
				l.sp += f * .3 * k
		l.x += l.vx * k - dc * zp
		l.y += l.vy * k - dcy * zp * .5
		l.r = float(l.r0) + l.vr
		l.r0 = float(l.r0) + sin(t * .007 + i) * .004 * k
		# pousa no chão perto do Tomé (só a camada do meio, onde o chão está)
		if zi == 1 and l.vy > 0 and _gl < vs.y and l.y >= _gl - 2 + l.hv * 6 and l.y < _gl + 30 and abs(l.x - psx) < 260:
			var wx: float = l.x / z + g.rcam
			var wy: float = _gl / z + g.rcam_y
			if _has_floor(wx, wy):
				l.st = 1
				l.lt = 0.0
				l.y = _gl - 1 + l.hv * 5
				l.r0 = (l.hv - .5) * .5
				l.r = l.r0
				l.sp = 0.0 if l.hv > .3 else PI
				continue
		_wrap(l, vs, nw)

func _wrap(l: Dictionary, vs: Vector2, nw: Dictionary) -> void:
	if l.x < -40:
		l.x = vs.x + 30
		l.y = randf() * vs.y * .7
	elif l.x > vs.x + 60:
		l.x = -30
	if l.y > vs.y + 20:
		_respawn_leaf(l, vs, nw, false)
	elif l.y < -80:
		l.y = vs.y + 10

## tem chão (topo de um sólido) perto deste ponto do mundo?
func _has_floor(wx: float, wy: float) -> bool:
	for s in game.SOL:
		if wx > s.x and wx < s.x + s.get("w", 0) and abs(s.y - wy) < 16:
			return true
	return false

## riscos de vento e poeira/neve rasteira nas rajadas fortes
func _sim_wind(k: float, vs: Vector2, gust: float, wind: float) -> void:
	var strong: float = clamp((gust - .3) / .5, 0, 1)
	for s in streaks:
		s.x -= s.v * (.6 + wind * .6) * k
		s.a = lerpf(s.a, strong, 1.0 - pow(.95, k))
		if s.x + s.l < -20:
			s.x = vs.x + randf() * 300
			s.y = 40 + randf() * vs.y * .7
	var low: float = clamp((gust - .45) / .4, 0, 1)
	for d in drift:
		d.x -= d.v * (.7 + wind * .5) * k
		d.ph = float(d.ph) + .15 * k
		if d.x + d.l < -20:
			d.x = vs.x + randf() * 200
			d.dy = randf() * 26

# ================================================================ desenho
func _draw() -> void:
	var __t := Time.get_ticks_usec()
	__draw_raw()
	Spr.pt("front", __t)

func __draw_raw() -> void:
	var g := game
	if g == null or not g.L or not g.running and g.T == 0:
		return
	var vs := get_viewport_rect().size
	var cam: float = g.rcam * PAR
	var under: bool = _hide
	var nw: Dictionary = FxClock.nw(g)
	var dark: float = g.AMB.dark
	var snow: float = g.AMB.get("snow", 0.0)
	var col: Color = FxClock.blend(nw, SIL, Color(.07, .13, .05))
	col = col.lerp(Color(0, 0, 0), dark * .5)
	var wind: float = g.AMB.get("wind", 0.0)
	var gust: float = Polish.gust_k() if Polish.g else 0.0
	var low: bool = g.low_fx
	# sombras de nuvens passando devagar pelo chão (de dia, ao ar livre; somem com chuva e à noite)
	if not under and not low:
		var day: float = FxClock.wsum(nw, ["bosque", "tarde", "moinho"]) + float(nw.get("neve", 0.0)) * .6
		day *= clamp(1.0 - g.AMB.rain * 4.0, 0, 1) * clamp(1.0 - dark * 6.0, 0, 1)
		if day > .02:
			var sc: Color = FxClock.blend(nw, SHADOW_C, Color(0, .02, .08))
			for i in 3:
				var cw: float = 700 + hh(i * 1.0, 6) * 500
				var span: float = vs.x + cw * 2
				var cx: float = fposmod(hh(i * 1.0, 7) * span - _cs[i] - g.rcam * .9, span) - cw
				draw_texture_rect(Spr.glow_tex, Rect2(cx, vs.y * .25 + hh(i * 1.0, 8) * vs.y * .3, cw, vs.y * .8), false, Color(sc.r, sc.g, sc.b, .13 * day))
	# silhuetas só na borda de baixo: capim e samambaias, translúcidos e "desfocados" (várias cópias suaves)
	# na neve somem aos poucos: o capim claro parecia cristais de gelo dentro da terra
	var sil_a: float = clamp(1.0 - snow * 6.0, 0, 1)
	if not under and sil_a > .01 and not (g.VH and g.VH.mode == "sled"):
		var step := 300.0
		var i0 := int(floor(cam / step)) - 2
		var i1 := int(floor((cam + vs.x) / step)) + 2
		for i in range(i0, i1):
			var r := hh(i * 1.0, 1)
			if r < .62:
				continue
			var x: float = i * step + hh(i * 1.0, 2) * 120 - cam
			var kind := int(hh(i * 1.0, 3) * 2)
			# balanço com o vento + as rajadas deitam o capim para o lado do vento
			var sway: float = sin(_sway_ph + i) * (2 + wind * 8) - gust * 14.0 - wind * 4.0
			# a forma é montada uma vez só; as cópias só mudam de lugar (transformação)
			var polys: Array = _grass(sway, i) if kind == 0 else _fern(sway, i)
			if low:
				var c1 := col
				c1.a = .5 * sil_a
				_polys(polys, Vector2(x, vs.y), c1, kind == 1)
				continue
			# desfoque: cópias suaves deslocadas em volta do contorno central
			for b in 4:
				var cb := col
				cb.a = [.12, .12, .14, .3][b] * sil_a
				var off: Vector2 = [Vector2(4, 3), Vector2(-4, 3), Vector2(0, -3), Vector2.ZERO][b]
				_polys(polys, Vector2(x, vs.y) + off, cb, kind == 1)
		_bflush()
	if under:
		return
	# riscos de vento nas rajadas
	if not low:
		for s in streaks:
			if s.a < .02:
				continue
			var sa: float = .1 * s.a
			draw_line(Vector2(s.x, s.y), Vector2(s.x + s.l * .5, s.y + 1), Color(1, 1, 1, sa), 1.2)
			draw_line(Vector2(s.x + s.l * .5, s.y + 1), Vector2(s.x + s.l, s.y + 3), Color(1, 1, 1, sa * .45), 1.0)
		# poeira (ou neve) rasteira levada pelo vento forte
		var lowk: float = clamp((gust - .45) / .4, 0, 1)
		if lowk > .02 and _gl < vs.y + 20:
			var dcol := Color(.98, .99, 1) if snow > .3 else Color(.82, .74, .6)
			for d in drift:
				var dy: float = _gl - 4 - d.dy + sin(d.ph) * 3
				draw_texture_rect(Spr.glow_tex, Rect2(d.x, dy - 3, d.l, 7), false, Color(dcol.r, dcol.g, dcol.b, .35 * lowk))
	# folhas (e flocos de neve) — longe, meio e perto
	var snowing: bool = snow > .3
	var fall: float = g.AMB.get("snowfall", snow)
	var night: float = FxClock.wsum(nw, ["noite", "vila"])
	var rain: float = clamp(g.AMB.rain, 0, 1)
	for zi in 3:
		for l in leaves:
			if l.a <= 0.0 or l.z != zi:
				continue
			var s: float = l.s * LZ_S[zi]
			if snowing and not l.dry:
				var fs: float = (2.0 + l.s * 2.4) * LZ_S[zi]
				var fa: float = .85 * fall * l.a * (.7 if zi == 0 else 1.0)
				_bdisc(Vector2(l.x, l.y), fs, Color(1, 1, 1, fa))
				if zi == 2 and not low:
					_bdisc(Vector2(l.x, l.y), fs * 1.7, Color(1, 1, 1, fa * .25))
				elif zi == 1:
					# um floco "gêmeo" longe deste (mais flocos com o mesmo custo de simulação)
					_bdisc(Vector2(fposmod(l.x + 517.0, vs.x), fposmod(l.y + 233.0, vs.y)), fs * .7, Color(1, 1, 1, fa * .7))
				continue
			var lc: Color = l.c
			lc = lc.darkened(.65 * night + .22 * rain)
			if zi == 0:
				lc = lc.lerp(_sky, .35)
			elif zi == 2:
				lc = lc.darkened(.3)
			var a: float = l.a
			if l.st == 1:
				a *= clamp(1.0 - (l.lt - 70.0) / 60.0, 0, 1)
			lc.a = a * (.8 if zi == 0 else 1.0)
			var flip: float = cos(l.sp)
			var fx: float = sign(flip) * max(abs(flip), .16)
			if zi == 2 and not low:
				# perto da câmera: um pouco fora de foco
				var lb := lc
				lb.a *= .3
				_leaf(l.x, l.y, l.r, s * 1.25, lb, fx)
			_leaf(l.x, l.y, l.r, s, lc if flip > 0 else lc.darkened(.22), fx)
	_bflush()
	# borboleta pousada no gorro do Tomé (no mundo, por cima dele)
	if not Critters.FRONTQ.is_empty():
		Spr.begin(self)
		Spr.M = get_viewport().canvas_transform
		draw_set_transform_matrix(Spr.M)
		Critters.draw_front(g)
		Spr.begin(self)
	# neblina
	var fa2: float = g.AMB.get("fog", 0.0)
	if fa2 > 0:
		var fc := Color(.85, .88, .9).lerp(Color(.35, .4, .55), dark)
		fc = fc.lerp(_sky, .25)
		draw_rect(Rect2(Vector2.ZERO, vs), Color(fc.r, fc.g, fc.b, .2 * fa2))
		if not low:
			for f in fog:
				draw_texture_rect(Spr.glow_tex, Rect2(f.x, f.y - g.rcam_y * .05, f.w, f.h), false, Color(fc.r, fc.g, fc.b, .6 * f.a * fa2))

## folha: elipse pontuda girando no plano (r) e virando de lado (fx = cos do giro: mostra a borda e o avesso)
func _leaf(x: float, y: float, r: float, s: float, c: Color, fx: float = 1.0) -> void:
	var o := Vector2(x, y)
	var b: int = _bp.size()
	_bp.push_back(o)
	_bc.push_back(c)
	for i in 8:
		var a := TAU * i / 8.0
		_bp.push_back(o + Vector2(cos(a) * 7 * s * fx, sin(a) * 3 * s * (1.0 + .4 * cos(a))).rotated(r))
		_bc.push_back(c)
	for i in 8:
		_bi.append_array([b, b + 1 + i, b + 1 + (i + 1) % 8])
	# nervura: um traço fininho
	var vc := c.darkened(.4)
	var d := Vector2(7 * s * fx, 0).rotated(r)
	var n := Vector2(0, .5).rotated(r)
	_bquad(o - d - n, o + d - n, o + d + n, o - d + n, vc)

# ---------------------------------------------------------------- lote de triângulos
# capim, samambaias, folhas e flocos vão juntos numa chamada de desenho só (barato no celular)
var _bp := PackedVector2Array()
var _bc := PackedColorArray()
var _bi := PackedInt32Array()

func _bquad(a: Vector2, b: Vector2, c: Vector2, d: Vector2, col: Color) -> void:
	var i: int = _bp.size()
	_bp.append_array([a, b, c, d])
	_bc.append_array([col, col, col, col])
	_bi.append_array([i, i + 1, i + 2, i, i + 2, i + 3])

func _bdisc(o: Vector2, r: float, c: Color) -> void:
	var b: int = _bp.size()
	_bp.push_back(o)
	_bc.push_back(c)
	for i in 8:
		var a := TAU * i / 8.0
		_bp.push_back(o + Vector2(cos(a), sin(a)) * r)
		_bc.push_back(c)
	for i in 8:
		_bi.append_array([b, b + 1 + i, b + 1 + (i + 1) % 8])

func _bflush() -> void:
	if _bi.size() > 0:
		RenderingServer.canvas_item_add_triangle_array(get_canvas_item(), _bi, _bp, _bc)
	_bp = PackedVector2Array()
	_bc = PackedColorArray()
	_bi = PackedInt32Array()

## formas da silhueta deslocadas para "at": capim = quadriláteros; samambaia = faixa de 16 pontos
func _polys(polys: Array, at: Vector2, c: Color, strip: bool) -> void:
	for pts in polys:
		if not strip:
			_bquad(pts[0] + at, pts[1] + at, pts[2] + at, pts[3] + at, c)
			continue
		var b: int = _bp.size()
		for q in pts:
			_bp.push_back(q + at)
			_bc.push_back(c)
		for j in 7:
			_bi.append_array([b + j, b + j + 1, b + 14 - j, b + j, b + 14 - j, b + 15 - j])

## capim (base em 0,0)
func _grass(sway: float, seed_i: int) -> Array:
	var out: Array = []
	for k in 9:
		var bx: float = k * 9 - 40
		var h: float = 36 + hh(seed_i * 10.0 + k, 4) * 58
		var lean: float = sway * (h / 100.0) + (k - 4) * 3
		out.append(PackedVector2Array([Vector2(bx - 5, 4), Vector2(bx + lean * .5, -h * .55), Vector2(bx + lean, -h), Vector2(bx + 5, 4)]))
	return out

## samambaia (base em 0,0)
func _fern(sway: float, seed_i: int) -> Array:
	var out: Array = []
	for k in 5:
		var a: float = -PI / 2 + (k - 2) * .42 + sway * .01
		var L: float = 55 + hh(seed_i * 3.0 + k, 5) * 50
		var pts := PackedVector2Array()
		var tip := Vector2(cos(a), sin(a)) * L
		var nrm := Vector2(-sin(a), cos(a))
		# a ponta da folha verga mais com o vento que a base
		var bend := Vector2(sway * .35, 0)
		pts.resize(16)
		for j in 8:
			var u := j / 7.0
			var p := tip * u + bend * u * u
			var n := nrm * (1.0 - u) * 16 * sin(u * PI + .3)
			pts[j] = p + n
			pts[15 - j] = p - n
		out.append(pts)
	return out
