extends RefCounted
class_name Ride
## O cavalo preso no arame farpado: o Tomé solta (✦), uma cena curta, e o cavalo dispara sozinho
## pela trilha da neve (uns 30 s). PULAR salta troncos, pedras e buracos; ↓ abaixa sob galhos e
## cordas (no ar, ↓ desce mais rápido). O galope vai ficando mais rápido e os obstáculos mais
## juntos; no meio, o salto do desfiladeiro (pulando na rampa o cavalo voa por cima da fenda).
## Cada batida custa um coração e o cavalo tropeça; sem corações, volta para o último marco
## (bandeira) da trilha. No fim, a chegada com a nota da cavalgada.

var g
var H := {}            # o cavalo
var OBS: Array = []     # obstáculos da trilha
var riding := false
var hx := 0.0
var hy := 500.0
var vy := 0.0
var spd := 0.0
var duck := false
var stumble := 0
var gallop := 0.0
var done := false
var tries := 0

const BOX_W := 66.0
var jbuf := 0          # PULAR apertado um pouco antes de pousar ainda vale
var hits := 0          # batidas nesta cavalgada (para a nota da chegada)
var cp_i := -1         # último marco (bandeira) da trilha que já passou
var big := false       # no ar num salto grande (rampa do desfiladeiro)
var ff_ok := false     # ↓ no ar desce rápido (só depois de soltar o ↓ que já estava apertado no pulo)
var land_k := 0.0      # amassado do pouso (desenho)
var last_gf := 0       # último quadro do galope (para as patadas na neve)
var leap_fail := false # caiu na beirada do desfiladeiro: o cavalo salta assustado (sem frear no ar)
var perfect := 0       # quadros mostrando o "perfeito!" (pulou bem na marca)
var fin_cheer := false # já passou pelo arco de chegada

## arco de chegada (onde o cavalo começa a diminuir o galope)
func finish_x() -> float:
	return float(H.ride1) - 600.0

func _init(game) -> void:
	g = game

func load_level() -> void:
	H = {}
	OBS = []
	riding = false
	done = false
	if g.L.has("horse"):
		H = g.L.horse.duplicate()
		H.st = "trapped"
		H.t = 0
		H.hx = float(H.x)
	for o in g.L.get("ride", []):
		var d: Dictionary = o.duplicate()
		d.hit = false
		OBS.append(d)

func near_horse() -> bool:
	if H.is_empty() or H.st != "trapped":
		return false
	var p: Dictionary = g.player
	return abs(p.x + p.w / 2 - H.x) < 110 and abs(p.y + p.h - H.y) < 60 and not p.get("dog")

## ✦ USAR perto do cavalo: solta do arame
func use() -> bool:
	if not near_horse():
		return false
	H.st = "free"
	H.t = 0
	Audio.play("unlock")
	Audio.vib(40)
	g.burst(H.x - 40, H.y - 40, 16, Color("#cdbfa6"))
	g.start_cine("cavalo", H.x + 40, H.y - 80, 300,
		[[20, 120, "TOMÉ", "Calma, garoto... pronto, o arame saiu. Você está livre!", "tome"],
		 [130, 240, "TOMÉ", "Me leva até a mina? A Isis está me esperando. Vamos!", "tome"]],
		[])
	return true

func cine_step(c: Dictionary) -> void:
	if c.id != "cavalo":
		return
	H.t = c.t
	if c.t == 100:
		Audio.play("roar", -16)
	if c.t == 250:
		Audio.play("jump", -4)

func cine_end(id: String) -> void:
	if id != "cavalo":
		return
	_start()

func _start() -> void:
	hits = 0
	cp_i = -1
	_begin(float(H.ride0), 1.0)
	g.flash_tut("Segure firme!", "Segure firme! PULAR salta (pule nas marcas de cascos na neve). ↓ abaixa sob galhos e cordas. → acelera, ← segura.", 240)

## marcos da trilha (bandeiras): onde a cavalgada recomeça depois de ficar sem corações
func cps() -> Array:
	return H.get("cps", [])

## recomeça do x0 (começo da trilha ou um marco), com os obstáculos dali para a frente de volta
func _begin(x0: float, v0: float) -> void:
	var p: Dictionary = g.player
	H.st = "ride"
	riding = true
	endT = -1
	hx = x0
	hy = 500.0
	vy = 0.0
	spd = v0
	duck = false
	stumble = 0
	jbuf = 0
	big = false
	leap_fail = false
	land_k = 0.0
	fin_cheer = x0 > finish_x()
	for o in OBS:
		if float(o.x) > x0 - 40:
			o.hit = false
	for s in g.SOL.duplicate():
		if s.get("id") == "horsebank":
			g.SOL.erase(s)
	p.hp = Game.MAXHP
	p.vine = null
	p.ladder = null
	p.bar = null
	if not g.X.DOG.is_empty() and g.X.dog_free():
		g.X.DOG.st = "ride"
	_place_player()
	g.snap_camera()

func _place_player() -> void:
	var p: Dictionary = g.player
	p.x = hx - p.w / 2 + 6
	p.y = hy - 74 - p.h + (14 if duck else 0)
	p.vx = spd
	p.vy = vy
	p.onGround = hy >= 500.0
	p.face = 1

## caixa do cavalo com o Tomé montado (do tamanho do desenho)
func box() -> Dictionary:
	var top: float = hy - (100 if duck else 124)
	return g.R(hx - BOX_W / 2, top, BOX_W, hy - top)

## pulo sempre igual (preciso): sobe JUMP_V, gravidade JUMP_G
const JUMP_V := 10.5
const JUMP_G := .5
## salto grande da rampa do desfiladeiro: a rampa dá o impulso que faltar para pousar do outro lado
const JUMP_BIG := 13.5
const LEAP_RAMP := 110.0   # a rampa vai de x - LEAP_RAMP até a beirada (x)

## velocidade do galope em cada ponto da trilha: começa no trote rápido (H.spd) e vai acelerando
## até o trecho final (o ritmo cresce)
func spd_at(x: float) -> float:
	var a: float = float(H.ride0) + 1600.0
	var b: float = float(H.ride1) - 1500.0
	return float(H.spd) + float(H.get("ramp", 1.1)) * smoothstep(a, b, x)

## área de batida de cada obstáculo (é a mesma usada no desenho)
static func obs_rect(o: Dictionary) -> Rect2:
	match o.k:
		"log":
			return Rect2(o.x + 10, 478, 44, 22)
		"rock":
			return Rect2(o.x + 12, 464, 36, 36)
		"fence":
			return Rect2(o.x + 12, 462, 36, 38)
		"branch":
			return Rect2(o.x, 368, 90, 28)
		"rope":
			return Rect2(o.x, 378, 84, 18)
		"logs":
			# pilha de toras (mais comprida: pede o pulo bem na marca)
			return Rect2(o.x + 10, 464, 80, 36)
	return Rect2()

## centro do obstáculo de pular (para a marca de cascos no melhor ponto de salto)
static func obs_center(o: Dictionary) -> float:
	match o.k:
		"log":
			return o.x + 32
		"rock":
			return o.x + 30
		"fence":
			return o.x + 30
		"gap", "leap":
			return o.x + o.w / 2.0
		"logs":
			return o.x + 50
	return -1.0

## onde saltar para passar bem no meio (metade do tempo no ar antes do centro)
func takeoff_x(o: Dictionary) -> float:
	var c: float = obs_center(o)
	if o.k == "leap":
		# o salto grande sai do meio da rampa
		return float(o.x) - LEAP_RAMP * .5
	return c - spd_at(c) * (JUMP_V / JUMP_G)

## impulso do salto grande saindo de x: o suficiente para pousar além do desfiladeiro
func leap_vy(o: Dictionary, x: float, v: float) -> float:
	var t: float = (float(o.x) + float(o.w) + 34.0 - x) / max(v, 3.0)
	return clamp(JUMP_G * t * .5, 11.0, 17.0)

## está na rampa de um desfiladeiro (pulo vira salto grande)?
func on_ramp() -> Dictionary:
	for o in OBS:
		if o.k == "leap" and hx > float(o.x) - LEAP_RAMP and hx < float(o.x) + 14.0:
			return o
	return {}

var endT := -1          # cena de desmontar no fim (-1 = ainda cavalgando)

func step() -> void:
	var p: Dictionary = g.player
	g.T += 1
	g.VH.tick_cheer()
	if perfect > 0:
		perfect -= 1
	land_k = move_toward(land_k, 0.0, .08)
	if endT >= 0:
		# parado: o Pipoca desce, o Tomé passa a perna, desce devagar e faz carinho no cavalo
		endT += 1
		spd = 0.0
		if endT == 20 and g.X.DOG.get("st", "") == "ride":
			# o Pipoca veio correndo pela trilha e já está esperando perto da fogueira
			var fx: float = hx - 80
			for c in g.CHK:
				if float(c.x) > hx - 200 and float(c.x) < hx + 700:
					fx = float(c.x) - 50
					break
			g.X.DOG.st = "follow"
			g.X.DOG.x = fx
			g.X.DOG.y = 500.0
			g.X._resync()
		if endT == 110:
			g.note("Obrigado, amigo. Pode voltar para casa!")
		if endT >= 170:
			_finish()
			return
		_place_player()
		return
	# galope suave: 8 quadros, a cadência acompanha a velocidade
	gallop += spd * .042
	# patadas na neve: a cada batida dos cascos levanta um punhado de neve (e o som dos cascos)
	var gf: int = int(floor(gallop))
	if gf != last_gf:
		last_gf = gf
		if hy >= 500.0 and spd > 1.5 and gf % 4 == 1:
			for k in 3:
				Polish.part("snow", hx - 26 + randf_range(-14, 14), 497, -spd * .35 - randf() * 1.4, -randf_range(1.4, 3.4), 28, Color(.97, .98, 1, .95), {"gy": 500.0, "size": randf_range(1.6, 2.8)})
			Audio.step("snow", -21)
	var want: float = spd_at(hx)
	if g.kd("R"):
		want += .7
	elif g.kd("L"):
		want -= .8
	# marcos da trilha: passou da bandeira, a cavalgada recomeça dali se ficar sem corações
	var C: Array = cps()
	if cp_i + 1 < C.size() and hx > float(C[cp_i + 1]):
		cp_i += 1
		g.VH.cheer("MARCO %d" % (cp_i + 1), "Se o cavalo empacar, recomeça daqui.", 110, true)
		Audio.play("unlock", -8, 1.2)
		Polish.part("ringw", float(C[cp_i]), 440, 0, 0, 22, Color(1, .9, .5, .9), {"size": 60.0})
	# passou pelo arco de chegada: festa e a nota da cavalgada (quantas batidas)
	if not fin_cheer and hx > finish_x():
		fin_cheer = true
		g.VH.cheer("CHEGADA!", _grade(), 190)
		Audio.play("special", -4)
		g.shake = max(g.shake, 2)
		var fx0: float = finish_x()
		for k in 30:
			var an: float = -PI * randf()
			Polish.part("star" if k % 3 == 0 else "spark", fx0 + randf_range(-60, 60), 330, cos(an) * randf_range(1.5, 5.0), sin(an) * randf_range(1.0, 4.0), 60, [Color(1, .86, .4), Color(.6, .9, 1), Color(1, .6, .5)][k % 3], {"g": .08, "drag": .97})
	# chegando no fim: desacelera aos poucos (galope, trote, passo) até parar
	var stop_x: float = float(H.ride1)
	if hx > stop_x - 560:
		want = max(0.0, spd_at(hx) * clamp((stop_x - hx) / 560.0, 0.0, 1.0))
		spd = move_toward(spd, want, .07)
		if spd < .3 and hy >= 500.0:
			spd = 0.0
			endT = 0
			vy = 0.0
			duck = false
			Audio.play("roar", -18)
	if stumble > 0:
		stumble -= 1
		spd = move_toward(spd, 2.0, .3)
	elif leap_fail:
		pass
	else:
		spd = move_toward(spd, want, .04)
	var on_ground: bool = hy >= 500.0
	if g.pressed("J"):
		jbuf = 9
	elif jbuf > 0:
		jbuf -= 1
	if jbuf > 0 and on_ground and stumble < 20:
		jbuf = 0
		var ramp := on_ramp()
		ff_ok = not g.kd("S")
		if not ramp.is_empty():
			# rampa do desfiladeiro: salto grande por cima da fenda
			vy = -leap_vy(ramp, hx, spd)
			big = true
			Audio.play("jump", -2, .8)
			Audio.play("roar", -14, 1.3)
			g.shake = max(g.shake, 3)
			for k in 10:
				Polish.part("snow", hx - 20 + randf_range(-16, 16), 497, -randf_range(1, 4), -randf_range(2, 5), 34, Color(.97, .98, 1), {"gy": 500.0})
		else:
			vy = -JUMP_V
			Audio.play("jump", -6)
			# pulou bem em cima da marca dos cascos: "perfeito!"
			for o in OBS:
				if not o.hit and Ride.obs_center(o) > 0 and o.k != "leap" and abs(hx - takeoff_x(o)) < 9.0:
					perfect = 40
					Polish.part("txt", hx + 10, hy - 150, 0, -.6, 40, Color(1, .92, .55), {"txt": "perfeito!", "size": 18.0})
					break
		g.burst(hx - 30, 500, 8, Color(.95, .97, 1))
	duck = g.kd("S") and on_ground
	if not on_ground and not g.kd("S"):
		ff_ok = true
	# pulo sempre do mesmo tamanho: dá para acertar o ponto (marca dos cascos na neve)
	vy += JUMP_G
	if not on_ground and ff_ok and g.kd("S") and vy > -6.0:
		# ↓ no ar: desce mais rápido (para abaixar logo depois de um pulo)
		vy += .55
	# no alto do salto grande: um instante em câmera lenta
	if big and vy >= 0.0 and vy - JUMP_G < 0.0:
		g.slowmo = max(g.slowmo, 26)
	hy = min(500.0, hy + vy)
	if hy >= 500.0:
		if vy > 6:
			g.fx("fx_dust", hx - 20, 494, 14, .12, -.2)
			land_k = clamp(vy / 14.0, .35, 1.0)
			Polish.land_soft(hx - 10, 500, vy * .5)
			if big or leap_fail:
				# pouso do salto grande: neve para todo lado e tremor
				g.shake = max(g.shake, 6)
				g.shake_dir = Vector2(0, 1) * 4.0
				Polish.impact(hx, 496, Color(.95, .98, 1), 8, 34.0)
				for k in 14:
					Polish.part("snow", hx + randf_range(-30, 30), 496, randf_range(-4, 4), -randf_range(2, 6), 40, Color(.97, .98, 1), {"gy": 500.0, "size": randf_range(1.8, 3.4)})
				Audio.play("stomp", -6, .8)
				if big and not leap_fail:
					g.VH.cheer("QUE SALTO!", "", 60, true)
			else:
				g.shake = max(g.shake, 1.5)
		vy = 0.0
		big = false
		if leap_fail:
			leap_fail = false
			stumble = 30
	hx += spd
	# neve levantada pelos cascos e o bafo do cavalo no frio
	if on_ground and g.T % 4 == 0:
		g.PARTS.append({"x": hx - 30 + randf_range(-10, 10), "y": 498, "vx": -spd * .35 + randf_range(-.3, .3), "vy": -1.2 - randf() * .8, "life": 18, "col": Color(.96, .98, 1, .85)})
	if g.T % 48 == 0:
		for k in 3:
			g.PARTS.append({"x": hx + 66, "y": hy - 98 + (14 if duck else 0), "vx": .9 + spd * .4 + k * .2, "vy": -.25, "life": 30, "col": Color(1, 1, 1, .45)})
	# obstáculos
	var b := box()
	for o in OBS:
		if o.hit or o.x + 260 < hx - 80 or o.x > hx + 80:
			continue
		var bad := false
		# as caixas de batida têm uma folga: raspar de leve não conta
		if o.k == "gap" or o.k == "leap":
			bad = hy >= 498 and hx > o.x + 22 and hx < o.x + o.w - 22
		else:
			var r := obs_rect(o)
			bad = Game.hit(b, g.R(r.position.x, r.position.y, r.size.x, r.size.y))
		if bad:
			o.hit = true
			var t0: int = tries
			_hurt(o)
			if tries != t0:
				# sem corações: já voltou para o marco (não confere mais nada neste passo)
				_place_player()
				return
	# lápis
	for c in g.coins_near(hx - 120, hx + 120):
		if not c.got and abs(c.x - hx) < 70 and Game.hit(b, g.R(c.x - 15, c.y - 15, 30, 30)):
			c.got = true
			g.STATS.pen += 1
			g.gain_coin(c.x, c.y)
	_place_player()
	if p.iframe > 0:
		p.iframe -= 1
	if hx >= float(H.ride1) + 40 and endT < 0:
		endT = 0

## nota da chegada: estrelas pelas batidas
func _grade() -> String:
	if hits == 0:
		return "Sem nenhuma batida!  ★★★"
	if hits <= 2:
		return "%d batida%s  ★★☆" % [hits, "" if hits == 1 else "s"]
	return "%d batidas  ★☆☆" % hits

func _hurt(o: Dictionary) -> void:
	var p: Dictionary = g.player
	hits += 1
	if o.k == "leap":
		# caiu na beirada do desfiladeiro: o cavalo se assusta e salta para o outro lado
		vy = -leap_vy(o, hx, max(spd, 4.5))
		spd = max(spd, 4.5)
		hy = 499.0
		leap_fail = true
		big = true
	elif o.k == "gap":
		# tropeça na beirada e salta por cima
		vy = -9.0
		hy = 499.0
	if not leap_fail:
		stumble = 40
		spd = 1.5
	g.shake = 4
	g.shake_dir = Vector2(-1, 0) * 5.0
	g.hit_stop = 4
	Audio.play("hurt")
	Audio.play("stomp", -8)
	Audio.vib(60)
	g.burst(hx + 30, hy - 60, 12, Color("#e07a6a"))
	Polish.impact(hx + 30, hy - 50, Color(1, .6, .5), 6, 24.0)
	if p.iframe > 0:
		return
	p.iframe = 50
	p.hp -= 1
	if p.hp <= 0:
		tries += 1
		g.iris_t = 30
		_from_mark()
		g.flash("O cavalo empacou! De volta ao marco — PULAR para saltar, ↓ para abaixar." if cp_i >= 0 else "O cavalo empacou! Vamos de novo — PULAR para saltar, ↓ para abaixar.", 220)

## sem corações: volta para o último marco (ou para o começo da trilha), com os corações cheios
func _from_mark() -> void:
	g.player.hp = Game.MAXHP
	if cp_i >= 0:
		var x0: float = float(cps()[cp_i]) - 140.0
		_begin(x0, spd_at(x0) * .7)
	else:
		_begin(float(H.ride0), 1.0)

## recomeçar a cavalgada do último marco (pausa → voltar à fogueira)
func restart() -> void:
	if not riding:
		return
	g.iris_t = 30
	endT = -1
	_from_mark()

func _finish() -> void:
	var p: Dictionary = g.player
	riding = false
	done = true
	H.st = "gone"
	H.t = 0
	H.hx = hx
	endT = -1
	p.x = hx - 30
	p.y = 500 - p.h
	p.vx = 0.0
	p.vy = 0.0
	p.face = 1
	p.onGround = true
	p.hp = max(p.hp, 1)
	if g.X.DOG.get("st", "") == "ride":
		g.X.DOG.st = "door"
		g.X.DOG.x = hx - 30
		g.X.DOG.y = 500.0
	g.flash("O cavalo voltou para a vila. A trilha da mina começa aqui.", 200)

## o cavalo indo embora depois da cavalgada
func post() -> void:
	if H.is_empty():
		return
	H.t += 1
	if H.st == "gone":
		# vira e vai embora devagar, pegando velocidade aos poucos
		if H.t > 20:
			H.hx -= min(5.0, (H.t - 20) * .08)
		if H.t > 260:
			H.st = "away"

func save_data() -> Dictionary:
	return {"done": done}

func restore(d: Dictionary) -> void:
	if d.get("done", false) and not H.is_empty():
		done = true
		H.st = "away"
		for s in g.SOL.duplicate():
			if s.get("id") == "horsebank":
				g.SOL.erase(s)
