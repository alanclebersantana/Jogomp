extends RefCounted
class_name Vehicles
## Os dois passeios automáticos novos (no mesmo espírito da cavalgada):
##  JANGADA  na corredeira entre o pântano e a neve: a correnteza leva sozinha; PULAR salta pedras,
##           troncos e as quedas-d'água (na beirada); ↓ abaixa sob os galhos.
##  BIPLANO  no período do Céu: o Tomé acha o avião na pista antes do precipício, decola e voa sobre
##           o vale; ↑ sobe, ↓ desce, desviando dos bandos de pássaros, gaviões e nuvens de tempestade.
## Cada batida custa um coração; sem corações, o passeio recomeça do começo.

var g
var RA := {}            # dados da jangada (L.raft)
var SL := {}            # dados do trenó (L.sled)
var sled_done := false
var PL := {}            # dados do biplano (L.plane)
var mode := ""          # "" | "raft" | "plane"
var hx := 0.0
var hy := 0.0
var vy := 0.0
var spd := 0.0
var duck := false
var stumble := 0
var jbuf := 0
var tries := 0
var raft_done := false
var plane_done := false
var phase := ""         # avião: "taxi", "fly", "land", "stop"
var tilt := 0.0
var OBS: Array = []
var RAFT_SOL := {}

func _init(game) -> void:
	g = game

func load_level() -> void:
	mode = ""
	raft_done = false
	plane_done = false
	RA = g.L.get("raft", {}).duplicate(true)
	SL = g.L.get("sled", {}).duplicate(true)
	sled_done = false
	PL = g.L.get("plane", {}).duplicate(true)
	RAFT_SOL = {}
	if not RA.is_empty():
		_dock_raft()
	if not PL.is_empty():
		PL.px = float(PL.x)
		PL.py = float(PL.y)

func active() -> bool:
	return mode != ""

## qual sequência especial está rolando agora (para música, câmera e efeitos):
## "ride" (cavalgada), "raft", "sled", "cart", "plane" ou "" (nenhuma)
func seq() -> String:
	if g.RD and g.RD.riding:
		return "ride"
	if mode == "sled" and is_cart():
		return "cart"
	return mode

## faixa grande no alto da tela: chegada (com a nota), marcos e momentos "uau" (desenhada em
## WorldVehicles.front; o tempo anda no desenho, só no 1º quadro depois de cada passo)
var CH := {"t": 0, "t0": 1, "title": "", "sub": "", "small": false}
func cheer(title: String, sub: String = "", t: int = 120, small: bool = false) -> void:
	CH = {"t": t, "t0": t, "title": title, "sub": sub, "small": small}

## o tempo da faixa anda com a lógica (chamado pelo passo da cavalgada e dos veículos)
func tick_cheer() -> void:
	if int(CH.t) > 0:
		CH.t = int(CH.t) - 1

## zoom da câmera nas sequências: abre um pouco com a velocidade (vê mais o que vem) e mais ainda
## nos saltos grandes; fecha de leve no fim
func zoom_want() -> float:
	var z := .88
	var RD = g.RD
	if RD and RD.riding:
		if RD.endT >= 0:
			return .96
		z = .9 - clamp((RD.spd - 5.0) / 1.5, 0.0, 1.0) * .05
		if RD.big:
			z -= .07
		return z
	match mode:
		"sled":
			if sboard > 0 or sfin > 0:
				return .94
			z = .9 - clamp((spd - 4.0) / 4.0, 0.0, 1.0) * .08
			if hy < sled_y(su) - 40.0:
				z -= .05
		"raft":
			z = .88 - (.04 if hy < water_y(hx) - 30.0 else 0.0)
		"plane":
			z = .84 if phase == "fly" else .9
	return z

## a jangada volta para o cais (chão de verdade: pular nela também embarca)
func _dock_raft() -> void:
	RA.px = float(RA.x)
	if RAFT_SOL.is_empty():
		RAFT_SOL = {"t": "raftsol", "x": 0.0, "y": 0.0, "w": 76.0, "h": 12.0, "oneway": 1, "raft": 1}
		g.SOL.append(RAFT_SOL)
	RAFT_SOL.x = RA.px - 38.0
	RAFT_SOL.y = water_y(RA.px) - 8.0

## cerca na margem do fim do rio: depois da corredeira não dá para voltar para a água
func _end_fence() -> void:
	for s in g.SOL:
		if s.get("id") == "raftfence":
			return
	g.SOL.append({"t": "raftfence", "x": float(RA.x1) - 8.0, "y": -400.0, "w": 16.0, "h": 900.0, "id": "raftfence"})

## voltou da morte (ou da fogueira): passeio interrompido é cancelado e o veículo volta ao ponto de saída
func on_respawn() -> void:
	var was: String = mode
	auto_cd = 120
	if mode != "":
		mode = ""
		stumble = 0
		duck = false
		vy = 0.0
		crashT = 0
	# voltou para uma fogueira de ANTES do passeio (ele terminou o passeio mas não chegou a acender a
	# fogueira seguinte): o passeio volta a valer. Antes a jangada ficava lá no fim do rio, a margem
	# de cá ficava sem jangada e o Tomé só morria na correnteza (o mesmo valia para o avião e o trenó)
	var sx: float = float(g.player.x) + float(g.player.w) / 2.0
	if raft_done and not RA.is_empty() and sx < float(RA.x0):
		raft_done = false
		g.SOL = g.SOL.filter(func(s): return s.get("id") != "raftfence")
	if plane_done and not PL.is_empty() and sx < float(PL.x) - 40.0:
		plane_done = false
	if sled_done and not SL.is_empty() and sx < float(SL.x) - 40.0:
		sled_done = false
	if not RA.is_empty():
		if raft_done:
			_drop_raft_sol()
			RA.px = float(RA.x1) - 90
			_end_fence()
		else:
			_dock_raft()
	if not PL.is_empty() and not plane_done:
		PL.px = float(PL.x)
		PL.py = float(PL.y)
	if was == "sled" or was == "plane" or was == "raft":
		if g.X.DOG.get("st", "") == "ride":
			g.X.DOG.st = "follow"

# ======================================================================
#  ÁGUA DA CORREDEIRA
# ======================================================================
## nível da água em x (cada queda-d'água desce 40 px)
func water_y(x: float) -> float:
	var y: float = RA.y
	for f in RA.get("falls", []):
		if x >= f:
			y += 40.0
	return y

## chegou do lado do avião: abre o quadrinho (só na primeira vez) e, depois do toque, embarca sozinho
func check_plane() -> void:
	if near_plane() and g.player.onGround and g.player.dyingT == 0:
		g.want_comic("aviao")
		_start_plane()

## chegou no trenó / carrinho: abre o quadrinho (só na primeira vez) e já parte, sem botão
var auto_cd := 0
func check_sled() -> void:
	if auto_cd > 0:
		auto_cd -= 1
		return
	# só quando ele anda até o trenó (voltando da fogueira parado ao lado, não parte sozinho)
	if near_sled() and g.player.onGround and g.player.dyingT == 0 and abs(g.player.vx) > .5 and (g.kd("R") or g.kd("L")) \
			and abs(float(g.player.x + g.player.w / 2) - float(SL.x)) < 40:
		if is_cart():
			g.want_comic("carrinho")
		_start_sled()

## caiu no rio sem estar na jangada: a correnteza leva
func check_river() -> void:
	if RA.is_empty() or mode == "raft":
		return
	var p: Dictionary = g.player
	var pcx0: float = p.x + p.w / 2
	# pulou do barranco para o rio: a jangada desliza até onde ele vai cair (sempre cai em cima dela)
	if not raft_done and not RAFT_SOL.is_empty() and p.dyingT == 0 and not p.get("dog"):
		var zone_a: float = float(RA.x0)
		var zone_b: float = float(RA.x0) + 440.0
		if not p.onGround and pcx0 > zone_a - 10 and pcx0 < zone_b and p.vy > -3.0:
			var tx: float = clamp(pcx0 + p.vx * 6.0, zone_a + 46.0, zone_b - 50.0)
			RA.px = move_toward(RA.px, tx, 18.0)
			RAFT_SOL.x = RA.px - 38.0
			RAFT_SOL.y = water_y(RA.px) - 8.0
		# já caiu na água dessa área (andou para fora do barranco, por exemplo): a jangada pega ele
		if pcx0 > zone_a and pcx0 < zone_b and p.y + p.h > water_y(pcx0) - 10:
			RA.px = clamp(pcx0, zone_a + 46.0, zone_b - 50.0)
			p.y = water_y(RA.px) - 8.0 - p.h
			p.vy = 0.0
			g.want_comic("jangada")
			_start_raft()
			return
	# pousou em cima da jangada: embarca e a corredeira começa
	if not RAFT_SOL.is_empty() and p.onGround and p._g == RAFT_SOL and not p.get("dog") and p.dyingT == 0:
		g.want_comic("jangada")
		_start_raft()
		return
	var pcx: float = p.x + p.w / 2
	if pcx > RA.x0 and pcx < RA.x1 and p.y + p.h > water_y(pcx) + 12 and p.dyingT == 0:
		g.die("A correnteza te levou! Suba na jangada (✦).")
	# o precipício do Céu
	for c in g.L.get("chasms", []):
		if pcx > c[0] and pcx < c[1] and p.y > c[2] and p.dyingT == 0:
			g.die("Você caiu no precipício.")

# ======================================================================
#  USAR
# ======================================================================
func near_raft() -> bool:
	if RA.is_empty() or raft_done or mode != "":
		return false
	var p: Dictionary = g.player
	return abs(p.x + p.w / 2 - RA.px) < 120 and abs(p.y + p.h - 500) < 60 and not p.get("dog")

func near_plane() -> bool:
	if PL.is_empty() or plane_done or mode != "":
		return false
	var p: Dictionary = g.player
	return abs(p.x + p.w / 2 - PL.px) < 150 and abs(p.y + p.h - PL.y) < 70 and not p.get("dog")

func near_sled() -> bool:
	if SL.is_empty() or sled_done or mode != "":
		return false
	var p: Dictionary = g.player
	return abs(p.x + p.w / 2 - float(SL.x)) < 90 and abs(p.y + p.h - float(SL.y)) < 50 and not p.get("dog")

func use() -> bool:
	if near_sled():
		if is_cart():
			g.want_comic("carrinho")
		_start_sled()
		return true
	if near_raft():
		g.want_comic("jangada")
		_start_raft()
		return true
	if near_plane():
		g.want_comic("aviao")
		_start_plane()
		return true
	return false

func _common_start() -> void:
	var p: Dictionary = g.player
	p.hp = Game.MAXHP
	p.vine = null
	p.ladder = null
	p.bar = null
	p.crouch = false
	p.h = 34
	p.sink = 0.0
	stumble = 0
	jbuf = 0
	duck = false
	vy = 0.0
	if not g.X.DOG.is_empty() and g.X.dog_free():
		g.X.DOG.st = "ride"

func _start_raft() -> void:
	mode = "raft"
	_drop_raft_sol()
	_common_start()
	OBS = []
	for o in RA.get("obs", []):
		var d: Dictionary = o.duplicate()
		d.hit = false
		OBS.append(d)
	hx = max(float(RA.x), float(RA.get("px", RA.x)))
	hy = water_y(hx)
	spd = .6
	hits = 0
	cp_i = -1
	fin_cheer = false
	big = false
	land_k = 0.0
	_place_player()
	Audio.play("splash", -4)
	g.flash_tut("Segure firme!", "Corredeira! PULAR salta pedras e troncos boiando (e as quedas, na beirada). ↓ abaixa sob galhos, troncos caídos, pontes e redes.", 260)

## TRENÓ: descida comprida num morro de neve (trilha própria, longe do mapa). A velocidade segue a
## descida; PULAR salta pedras, troncos e rachaduras; ↓ abaixa sob galhos; ← freia; → inclina e acelera.
## Batida: perde um coração e segue descendo (sem coração nenhum: volta para a fogueira).
var su := 0.0          # posição na trilha
var sdv := 0.0         # quanto o chão desce por quadro (para decolar das rampas)
var sang := 0.0        # inclinação do trenó
var crashT := 0
var srest := 0.0       # onde recomeça depois de bater
var lean := false
var brake := false
var sboard := 0        # embarcando no trenó: empurra, senta e escorrega (a tela fecha e abre lá no morro)
var sfin := 0          # chegou no monte de neve: a tela fecha antes de voltar para o mapa
var vg_t0 := -1        # carrinho: quadro em que o Vargas parou no fim dos trilhos e saltou com a Isis
const VG_STOP := 850.0  # o Vargas chega ao fim dos trilhos quando o Tomé ainda está esta distância atrás
const SBOARD := 40
const KICK_LEN := 80.0  # comprimento da rampa de neve (kick) antes da beirada
var hits := 0          # batidas neste passeio (para a nota da chegada)
var cp_i := -1         # último marco do passeio que já passou
var fin_cheer := false # já mostrou a faixa de chegada
var big := false       # no ar num salto grande (rampa)
var ff_ok := false     # ↓ no ar desce rápido (depois de soltar o ↓ que estava apertado no pulo)
var land_k := 0.0      # amassado do pouso (desenho)

func sled_y(u: float) -> float:
	var pts: Array = SL.get("pts", [])
	for i in pts.size() - 1:
		var a: Array = pts[i]
		var b: Array = pts[i + 1]
		if u >= a[0] and u <= b[0]:
			var t: float = (u - float(a[0])) / (float(b[0]) - float(a[0]))
			t = (1.0 - cos(t * PI)) * .5
			return lerpf(float(a[1]), float(b[1]), t)
	if pts.is_empty():
		return float(SL.y)
	return float(pts[-1][1]) if u > float(pts[-1][0]) else float(pts[0][1])

## o mesmo passeio do trenó, nos trilhos da mina (Episódio 2): carrinho em vez de trenó
func is_cart() -> bool:
	return str(SL.get("skin", "")) == "cart"

func sled_tx0() -> float:
	return float(SL.get("tx0", 82000))

func _start_sled() -> void:
	mode = "sled"
	_common_start()
	OBS = []
	for o in SL.get("obs", []):
		var d: Dictionary = o.duplicate()
		d.hit = false
		d.x = sled_tx0() + float(d.u)
		OBS.append(d)
	srest = 40.0
	sboard = SBOARD
	sfin = 0
	hits = 0
	cp_i = -1
	fin_cheer = false
	vg_t0 = -1
	su = 0.0
	hx = float(SL.x)
	hy = float(SL.y)
	spd = 0.0
	vy = 0.0
	sang = 0.0
	crashT = 0
	_place_player()
	Audio.play("slide", -6)

func _sled_go() -> void:
	_sled_place(40.0, 3.0)
	g.snap_camera()
	g.set_cam(hx - g.W * .26, hy * .6 + sled_y(su + 300.0) * .4 - g.H * .56)
	g.iris_t = 30
	Audio.play("slide")
	if is_cart():
		g.flash_tut("Carrinho!", "Nos trilhos! PULAR salta pedras e buracos nos trilhos. ↓ abaixa sob as vigas. ← freia, → acelera.", 240)
	else:
		g.flash_tut("Trenó!", "Descendo o morro! PULAR salta pedras, troncos e rachaduras. ↓ abaixa sob galhos. ← freia, → acelera.", 240)

func _sled_place(u: float, v: float) -> void:
	su = u
	hx = sled_tx0() + su
	hy = sled_y(su)
	vy = 0.0
	spd = v
	sdv = 0.0
	sang = 0.0
	crashT = 0
	duck = false
	big = false
	land_k = 0.0
	_place_player()

func _sled_step() -> void:
	var p: Dictionary = g.player
	if sboard > 0:
		# senta no trenó e começa a escorregar devagar; a tela fecha e abre já na descida
		sboard -= 1
		if sboard < SBOARD - 12:
			spd = move_toward(spd, 2.4, .1)
		hx += spd
		hy = float(SL.y)
		if sboard == 0:
			_sled_go()
		return
	if sfin > 0:
		sfin -= 1
		if sfin == 0:
			_finish_sled()
		return
	if crashT > 0:
		# bateu: o trenó balança um pouco, mas segue descendo
		crashT -= 1
	land_k = move_toward(land_k, 0.0, .08)
	# o que foi atingido: pedra quebra, tora sai rolando, galho cai
	for o in OBS:
		if o.hit and o.get("ft", -1) >= 0 and o.ft < 90:
			o.ft += 1
	var ln: float = float(SL.get("len", 4650))
	# marcos da descida: passou da bandeira, recomeça dali se ficar sem corações
	var C: Array = SL.get("cps", [])
	if cp_i + 1 < C.size() and su > float(C[cp_i + 1]):
		cp_i += 1
		cheer("MARCO %d" % (cp_i + 1), "Se o trenó capotar, recomeça daqui.", 110, true)
		Audio.play("unlock", -8, 1.2)
	# chegada (trenó): a faixa com a nota da descida
	if not is_cart() and not fin_cheer and su > ln - 520.0:
		fin_cheer = true
		cheer("CHEGADA!", _grade(), 190)
		Audio.play("special", -4)
	var gy: float = sled_y(su)
	var on_ground: bool = hy >= gy - 1.0
	lean = g.kd("R")
	brake = g.kd("L")
	# a velocidade acompanha a descida (e as subidinhas seguram)
	var slope: float = (sled_y(su + 4.0) - sled_y(su - 4.0)) / 8.0
	if on_ground:
		spd += .3 * sin(atan(slope)) - .004 * spd
		if lean:
			spd += .045
		if brake:
			spd -= .11
		spd = clamp(spd, 2.2 if su < ln - 200 else 0.0, 8.0)
	# rampa de neve (kick) à frente: PULAR em cima dela guarda o pulo até a beirada (salto grande)
	var ramp := _kick_at(su)
	if g.pressed("J"):
		jbuf = 9
	elif jbuf > 0 and ramp.is_empty():
		jbuf -= 1
	if jbuf > 0 and on_ground and ramp.is_empty():
		jbuf = 0
		vy = sdv - 8.2
		ff_ok = not g.kd("S")
		on_ground = false
		Audio.play("jump", -6)
		g.burst(hx - 20, hy, 8, Color(.97, .98, 1))
	duck = g.kd("S") and on_ground
	if not on_ground and not g.kd("S"):
		ff_ok = true
	var nu: float = su + spd
	var ngy: float = sled_y(nu)
	# passou pela beirada da rampa: decola (grande se PULAR foi apertado na rampa, senão um pulinho)
	if on_ground and not ramp.is_empty() and nu >= float(ramp.u):
		var go_big: bool = jbuf > 0 or g.kd("J")
		jbuf = 0
		vy = sdv - ((6.8 + spd * .55) if go_big else 4.2)
		big = go_big
		ff_ok = not g.kd("S")
		hy = gy - 2.0
		on_ground = false
		if go_big:
			Audio.play("jump", -2, .85)
			g.shake = max(g.shake, 3)
			for k in 12:
				Polish.part("snow", hx + randf_range(-12, 12), hy - 4, randf_range(-1, 3) + spd * .3, -randf_range(2, 6), 34, Color(.97, .98, 1), {"size": randf_range(1.6, 3.0)})
		else:
			Audio.play("slide", -12, 1.3)
	if on_ground:
		var dv: float = ngy - gy
		# o chão "some" embaixo (fim de rampa): decola com a velocidade de subida que tinha
		if dv - sdv > .9 and sdv < 0:
			vy = sdv
			hy = gy
			on_ground = false
		else:
			sdv = dv
			hy = ngy
			vy = 0.0
	if not on_ground:
		vy += .45
		if ff_ok and g.kd("S") and vy > -5.0:
			# ↓ no ar: desce mais rápido
			vy += .5
		hy += vy
		if hy >= ngy:
			if vy > 5:
				g.burst(hx, ngy, 14, Color(.97, .98, 1))
				Audio.step("stone" if is_cart() else "snow", -6)
				g.shake = max(g.shake, 3)
				land_k = clamp(vy / 12.0, .35, 1.0)
				if not is_cart():
					for k in 10:
						Polish.part("snow", hx + randf_range(-26, 26), ngy - 2, randf_range(-2, 2) + spd * .25, -randf_range(1.5, 4.5), 34, Color(.97, .98, 1), {"size": randf_range(1.6, 3.2)})
				if big:
					g.shake = max(g.shake, 5)
					Polish.impact(hx, ngy - 4, Color(.95, .98, 1), 7, 30.0)
					if crashT == 0:
						cheer("QUE SALTO!", "", 55, true)
			big = false
			hy = ngy
			vy = 0.0
			sdv = ngy - gy
	su = nu
	hx = sled_tx0() + su
	var want: float = atan(sdv / max(spd, .1)) if hy >= ngy - 1 else atan(vy / max(spd, .1)) * .7
	sang = lerpf(sang, want, .25)
	# neve espirrando dos esquis (no carrinho: faíscas das rodas)
	if hy >= ngy - 1 and g.T % 2 == 0:
		for k in 2:
			if is_cart():
				if spd > 5.5 and randf() < .5:
					g.PARTS.append({"x": hx - 24 + k * 40, "y": hy - 2, "vx": -spd * .3 - randf() * 2.0, "vy": -randf_range(.5, 2.5), "life": 12, "col": Color(1, .75 + randf() * .2, .3, 1)})
			else:
				g.PARTS.append({"x": hx - 28, "y": hy - 2, "vx": -spd * .35 - randf() * 1.5, "vy": -randf_range(1.0, 3.0) - spd * .1, "life": 22, "col": Color(.97, .98, 1, .95)})
		# rápido: rabo de neve fofa levantando atrás dos esquis
		if not is_cart() and spd > 5.0:
			Polish.part("snow", hx - 30 + randf_range(-4, 4), hy - 3, -spd * .45 - randf() * 1.5, -randf_range(1.5, 3.5) - (spd - 5.0) * .5, 26, Color(.97, .98, 1, .9), {"size": randf_range(1.8, 3.4), "drag": .97})
	if brake and hy >= ngy - 1 and g.T % 3 == 0:
		g.PARTS.append({"x": hx + 20, "y": hy - 3, "vx": spd * .2, "vy": -2.0, "life": 18, "col": Color(.9, .95, 1, .9)})
		if not is_cart():
			Polish.part("snow", hx + 24, hy - 3, spd * .3 + randf(), -randf_range(2, 4), 24, Color(.95, .97, 1), {"size": 2.6})
	# obstáculos
	var b := box()
	for o in OBS:
		if o.hit or o.x + 120 < hx - 80 or o.x - 60 > hx + 80:
			continue
		var oy: float = sled_y(float(o.u))
		var bad := false
		match o.k:
			"rock":
				bad = Game.hit(b, g.R(o.x - 18, oy - 26, 36, 26))
			"log":
				bad = Game.hit(b, g.R(o.x - 30, oy - 20, 60, 20))
			"branch":
				bad = Game.hit(b, g.R(o.x - 40, oy - 72, 90, 26))
			"crack":
				bad = hy >= sled_y(su) - 1 and hx > o.x + 14 and hx < o.x + float(o.w) - 14
			"bump":
				if hy >= sled_y(su) - 1 and abs(hx - o.x) < 6 and spd > 4:
					vy = -3.5
					hy -= 2
					g.shake = max(g.shake, 2)
		if bad:
			o.hit = true
			var t1: int = tries
			_hurt_sled(o)
			if tries != t1:
				return
	_coins(b)
	if SL.get("vargas") and vg_t0 < 0 and su >= ln - VG_STOP:
		vg_t0 = g.T
	if su >= ln - 200:
		# freia sozinho no fim e para no monte de neve
		spd = move_toward(spd, 0.0, .18)
		if spd <= .3:
			sfin = 30
			if not is_cart():
				# afunda no monte de neve: neve para todo lado
				g.shake = max(g.shake, 4)
				Polish.impact(hx + 20, hy - 20, Color(.95, .98, 1), 8, 40.0)
				for k in 24:
					Polish.part("snow", hx + 20 + randf_range(-20, 20), hy - 20, randf_range(-3, 4), -randf_range(2, 7), 44, Color(.97, .98, 1), {"size": randf_range(2.0, 4.0)})
				Audio.play("splash", -10, .7)

## rampa de neve (kick) em que o trenó está (até 80 px antes da beirada)
func _kick_at(u: float) -> Dictionary:
	for o in OBS:
		if o.k == "kick" and u > float(o.u) - KICK_LEN and u < float(o.u):
			return o
	return {}

## nota da chegada: estrelas pelas batidas
func _grade() -> String:
	if hits == 0:
		return "Sem nenhuma batida!  ★★★"
	if hits <= 2:
		return "%d batida%s  ★★☆" % [hits, "" if hits == 1 else "s"]
	return "%d batidas  ★☆☆" % hits

func _hurt_sled(o: Dictionary = {}) -> void:
	var p: Dictionary = g.player
	hits += 1
	o.ft = 0
	crashT = 30
	g.shake = 7
	g.shake_dir = Vector2(-1, 0) * 5.0
	g.hit_stop = 4
	Audio.play("hurt")
	Audio.vib(70)
	g.burst(hx + 10, hy - 20, 20, Color(.97, .98, 1))
	Polish.impact(hx + 20, hy - 24, Color(1, .65, .55), 6, 24.0)
	match o.get("k", ""):
		"rock":
			# a pedra se parte em pedaços
			spd *= .6
			vy = -3.5
			Audio.play("stomp", -4)
			for k in 10:
				g.PARTS.append({"x": o.x, "y": sled_y(float(o.u)) - 14, "vx": randf_range(-1.0, 5.0), "vy": randf_range(-6.0, -2.0), "life": 40, "col": Color("#7d7a74")})
		"log":
			# a tora sai rolando morro abaixo, na frente
			spd *= .65
			vy = -3.0
		"crack":
			# caiu na rachadura e sai pulando do outro lado
			spd *= .7
			vy = -7.5
			hy -= 2
		"branch":
			# bateu a cabeça no galho: o galho quebra e cai
			spd *= .7
			Audio.play("stomp", -4)
	if p.iframe > 0:
		return
	p.iframe = 70
	p.hp -= 1
	if p.hp <= 0:
		tries += 1
		var C: Array = SL.get("cps", [])
		if C.is_empty():
			g.die("O carrinho descarrilou! PULAR salta, ↓ abaixa, ← freia." if is_cart() else "O trenó capotou! Volta da fogueira — PULAR salta, ↓ abaixa, ← freia.")
			return
		# capotou: volta para o último marco da descida (ou para o alto), com os corações cheios
		var u0: float = float(C[cp_i]) - 160.0 if cp_i >= 0 else 40.0
		for ob in OBS:
			if float(ob.u) > u0 - 20.0:
				ob.hit = false
				ob.erase("ft")
		p.hp = Game.MAXHP
		p.iframe = 40
		_sled_place(u0, 4.0)
		g.iris_t = 30
		g.snap_camera()
		g.set_cam(hx - g.W * .26, hy * .6 + sled_y(su + 300.0) * .4 - g.H * .56)
		g.flash("O trenó capotou! De volta ao marco — PULAR salta, ↓ abaixa, ← freia." if cp_i >= 0 else "O trenó capotou! De novo do alto — PULAR salta, ↓ abaixa, ← freia.", 220)

func _finish_sled() -> void:
	var p: Dictionary = g.player
	mode = ""
	sled_done = true
	p.x = float(SL.x1) + 6
	p.y = float(SL.y) - p.h - 2
	p.vx = 3.0
	p.vy = -5.0
	p.onGround = false
	p.hp = max(p.hp, 1)
	if g.X.DOG.get("st", "") == "ride":
		g.X.DOG.st = "follow"
		g.X.DOG.x = p.x - 40
		g.X.DOG.y = float(SL.y)
	g.burst(p.x, float(SL.y) - 10, 24, Color(.97, .98, 1))
	Audio.play("splash", -10)
	g.iris_t = 30
	g.snap_camera()
	if is_cart():
		g.flash(str(SL.get("endMsg", "O carrinho parou no fim dos trilhos.")), 200)
	else:
		g.flash("Que descida! O trenó parou no monte de neve, lá embaixo do morro.", 180)

var pb := 0              # avião: quadros do embarque
var bx0 := 0.0
var by0 := 0.0
const PBOARD := 70

func _start_plane() -> void:
	mode = "plane"
	_common_start()
	OBS = []
	for o in PL.get("obs", []):
		var d: Dictionary = o.duplicate()
		d.hit = false
		d.t = 0
		d.st = "wait"
		d.ox = float(d.x)
		d.oy = float(d.get("y", d.get("top", 0.0)))
		if not d.has("y"):
			d.y = d.oy
		OBS.append(d)
	hx = float(PL.x)
	hy = float(PL.y)
	spd = 0.0
	hits = 0
	cp_i = -1
	fin_cheer = false
	phase = "board"
	pb = 0
	var p: Dictionary = g.player
	bx0 = p.x + p.w / 2
	by0 = p.y + p.h
	tilt = 0.0
	_place_player()

## o Tomé acompanha o veículo (para câmera, lápis e o resto do jogo)
func _place_player() -> void:
	var p: Dictionary = g.player
	if mode == "raft":
		p.x = hx - p.w / 2
		p.y = hy - 8 - p.h + (12 if duck else 0)
	elif mode == "sled":
		p.x = hx - p.w / 2
		p.y = hy - 10 - p.h
	else:
		p.x = hx - p.w / 2 - 10
		p.y = hy - 40 - p.h
	p.vx = spd
	p.vy = vy
	p.onGround = (mode == "raft" and hy >= water_y(hx) - 1) or (mode == "sled" and hy >= sled_y(su) - 1)
	p.face = 1

# ======================================================================
#  PASSO
# ======================================================================
func step() -> void:
	g.T += 1
	tick_cheer()
	if mode == "raft":
		_raft_step()
	elif mode == "sled":
		_sled_step()
	elif mode == "plane":
		_plane_step()
	var p: Dictionary = g.player
	if p.iframe > 0:
		p.iframe -= 1
	if mode != "":
		_place_player()

func box() -> Dictionary:
	if mode == "sled":
		var st: float = hy - (30 if duck else 52)
		return g.R(hx - 28, st, 56, hy - st)
	if mode == "raft":
		var top: float = hy - (34 if duck else 50)
		return g.R(hx - 30, top, 60, hy - top)
	return g.R(hx - 50, hy - 46, 100, 40)

## velocidade da correnteza em x: depois de cada queda-d'água o rio corre um pouco mais
func raft_spd_at(x: float) -> float:
	var v: float = float(RA.spd)
	for f in RA.get("falls", []):
		if x >= float(f):
			v += .4
	return v

func _raft_step() -> void:
	land_k = move_toward(land_k, 0.0, .08)
	# marcos da corredeira: passou da bandeira, recomeça dali se a jangada virar
	var C: Array = RA.get("cps", [])
	if cp_i + 1 < C.size() and hx > float(C[cp_i + 1]):
		cp_i += 1
		cheer("MARCO %d" % (cp_i + 1), "Se a jangada virar, recomeça daqui.", 110, true)
		Audio.play("unlock", -8, 1.2)
	if stumble > 0:
		stumble -= 1
		spd = move_toward(spd, 2.0, .4)
	else:
		# chegando na margem do fim: a jangada vai perdendo a velocidade até encostar
		# (só depois do último obstáculo, para os pulos continuarem com a mesma velocidade)
		var last_o: float = 0.0
		for o in OBS:
			last_o = max(last_o, float(o.x))
		var slow0: float = max(last_o + 140.0, float(RA.x1) - 70.0 - 420.0)
		var want_s: float = raft_spd_at(hx) * clamp(1.0 - (hx - slow0) / max(60.0, float(RA.x1) - 70.0 - slow0) * .7, .3, 1.0)
		spd = move_toward(spd, want_s, .08 if want_s >= spd else .12)
	var wl: float = water_y(hx)
	var on_water: bool = hy >= wl - 1
	if g.pressed("J"):
		jbuf = 9
	elif jbuf > 0:
		jbuf -= 1
	if jbuf > 0 and on_water and stumble < 20:
		jbuf = 0
		vy = -10.5
		ff_ok = not g.kd("S")
		Audio.play("jump", -4)
		g.burst(hx - 20, wl, 10, Color(.8, .9, 1))
		g.WV.splash(hx, wl, 3.5)
		# pulou bem na beirada de uma queda-d'água: salto grande, câmera lenta no alto
		for f in RA.get("falls", []):
			if float(f) - hx > 0 and float(f) - hx < 90:
				big = true
	duck = g.kd("S") and on_water
	if not on_water and not g.kd("S"):
		ff_ok = true
	# queda-d'água logo à frente: se não pulou, a jangada despenca e bate
	var nxt: float = hx + spd
	var t0: int = tries
	for f in RA.get("falls", []):
		if hx < f and nxt >= f and on_water:
			_hurt_raft("queda")
			if tries != t0:
				# virou na queda: já recomeçou no marco (antes seguia dali, da beirada da queda)
				return
	var g0: float = .42 if (vy < 0 and g.kd("J")) else .6
	vy += g0
	if not on_water and ff_ok and g.kd("S") and vy > -5.0:
		# ↓ no ar: desce mais rápido
		vy += .5
	if big and vy >= 0.0 and vy - g0 < 0.0:
		g.slowmo = max(g.slowmo, 20)
	hy += vy
	hx = nxt
	wl = water_y(hx)
	if hy >= wl:
		if vy > 4:
			Audio.play("splash", -8)
			g.burst(hx, wl, 12, Color(.85, .93, 1))
			g.WV.splash(hx, wl, min(9.0, vy * .9))
			land_k = clamp(vy / 12.0, .35, 1.0)
			g.shake = max(g.shake, 2)
			# respingos para os dois lados da jangada
			for k in 10:
				var d: float = -1.0 if k % 2 == 0 else 1.0
				Polish.part("drop", hx + d * randf_range(20, 44), wl - 2, d * randf_range(1.0, 3.0), -randf_range(2.5, 5.0), 30, Color(.82, .93, 1, .9), {"g": .2})
			if big:
				g.shake = max(g.shake, 5)
				Polish.impact(hx, wl - 6, Color(.85, .95, 1), 7, 32.0)
				Audio.play("splash", -2, .8)
				if stumble == 0:
					cheer("QUE QUEDA!", "", 60, true)
		big = false
		hy = wl
		vy = 0.0
	# rastro da jangada na água
	if hy >= wl - 1 and g.T % 5 == 0:
		g.WV.splash(hx - 36, wl, 1.2, false)
	# balanço da água e espuma na proa
	if hy >= wl - 1 and g.T % 4 == 0:
		g.PARTS.append({"x": hx - 34, "y": wl + 2, "vx": -spd * .4, "vy": -1.2, "life": 16, "col": Color(.9, .96, 1, .8)})
		Polish.part("drop", hx + 40 + randf_range(-4, 4), wl - 2, spd * .25 + randf(), -randf_range(1.2, 2.6), 20, Color(.88, .96, 1, .85), {"g": .2, "size": 1.5})
	# remada: a pá do remo entra na água e espirra
	if hy >= wl - 1 and not duck and int(g.T) % 52 == 13:
		Polish.part("drop", hx - 30, wl - 2, -1.5, -2.5, 22, Color(.88, .96, 1, .9), {"g": .2})
		Polish.part("drop", hx - 26, wl - 2, -.5, -3.2, 22, Color(.88, .96, 1, .9), {"g": .2})
		g.WV.splash(hx - 30, wl, 1.6, false)
	var b := box()
	for o in OBS:
		if o.hit or o.x + 220 < hx - 80 or o.x > hx + 80:
			continue
		var oy: float = water_y(o.x)
		var bad := false
		match o.k:
			"rock":
				bad = Game.hit(b, g.R(o.x + 8, oy - 34, 44, 40))
			"log":
				bad = Game.hit(b, g.R(o.x + 6, oy - 18, 70, 20))
			"branch":
				bad = Game.hit(b, g.R(o.x + 4, oy - 104, 90, 18))
			"rapid":
				# corredeira de água branca: a jangada sacode e dá pulinhos (não machuca)
				if hy >= wl - 1 and hx > o.x and hx < o.x + float(o.get("w", 200)) and g.T % 12 == 0:
					vy = -2.4
					hy -= 1
					g.shake = max(g.shake, 1.5)
					g.WV.splash(hx, wl, 3.0)
			# obstáculos de abaixar (↓): passam na altura do Tomé em pé; abaixado ele passa por baixo
			"lowbranch", "trunk", "bridge", "net", "vinebranch":
				var dw: float = DUCK_W.get(o.k, 110)
				bad = Game.hit(b, g.R(o.x, oy - 96, dw, 53))
		if bad:
			o.hit = true
			var t2: int = tries
			_hurt_raft(o.k)
			if tries != t2:
				return
	_coins(b)
	if hx >= float(RA.x1) - 70:
		_finish_raft()

## largura do que se passa abaixado na corredeira
const DUCK_W := {"lowbranch": 100.0, "trunk": 130.0, "bridge": 170.0, "net": 110.0, "vinebranch": 130.0}

func _hurt_raft(_k: String) -> void:
	var p: Dictionary = g.player
	hits += 1
	stumble = 40
	spd = 1.5
	vy = -5.0
	big = false
	g.shake = 5
	g.shake_dir = Vector2(-1, 0) * 5.0
	g.hit_stop = 4
	Audio.play("hurt")
	Audio.play("splash", -4)
	Audio.vib(60)
	g.burst(hx + 20, hy - 30, 12, Color("#e07a6a"))
	Polish.impact(hx + 20, hy - 30, Color(1, .65, .55), 6, 24.0)
	if p.iframe > 0:
		return
	p.iframe = 50
	p.hp -= 1
	if p.hp <= 0:
		tries += 1
		g.iris_t = 30
		var C: Array = RA.get("cps", [])
		var keep: int = cp_i
		var h0: int = hits
		_start_raft()
		hits = h0
		if keep >= 0:
			# volta para o último marco (com os obstáculos dali para a frente de volta)
			cp_i = keep
			hx = float(C[keep]) - 120.0
			hy = water_y(hx)
			spd = raft_spd_at(hx) * .6
			for o in OBS:
				o.hit = float(o.x) < hx - 40.0
			_place_player()
		g.flash("A jangada virou! De volta ao marco — PULAR para saltar, ↓ para abaixar." if keep >= 0 else "A jangada virou! De novo — PULAR para saltar, ↓ para abaixar.", 220)
		# a câmera volta junto (antes atravessava o rio inteiro deslizando até o começo)
		g.snap_camera()

func _drop_raft_sol() -> void:
	if not RAFT_SOL.is_empty():
		g.SOL.erase(RAFT_SOL)
		RAFT_SOL = {}

func _finish_raft() -> void:
	var p: Dictionary = g.player
	mode = ""
	raft_done = true
	_drop_raft_sol()
	_end_fence()
	RA.px = float(RA.x1) - 90
	p.x = float(RA.x1) + 10
	p.y = 500 - p.h - 4
	p.vx = 2.0
	p.vy = -4.0
	p.onGround = false
	p.hp = max(p.hp, 1)
	if g.X.DOG.get("st", "") == "ride":
		g.X.DOG.st = "door"
		g.X.DOG.x = p.x - 30
		g.X.DOG.y = 500.0
	Audio.play("splash", -6)
	# chegada: a faixa com a nota da corredeira e festa na margem
	cheer("CHEGADA!", _grade(), 190)
	Audio.play("special", -4)
	for k in 26:
		var an: float = -PI * randf()
		Polish.part("star" if k % 3 == 0 else "spark", p.x + randf_range(-40, 60), 420, cos(an) * randf_range(1.5, 4.5), sin(an) * randf_range(1.5, 4.5), 55, [Color(1, .86, .4), Color(.6, .9, 1), Color(1, .6, .5)][k % 3], {"g": .08, "drag": .97})
	g.flash("Terra firme! Que corredeira...", 200)

# ---------- avião ----------
func _plane_step() -> void:
	var p: Dictionary = g.player
	match phase:
		"board":
			# o Tomé sobe na cabine, o motor pega e o avião começa a andar
			pb += 1
			if pb == 30:
				Audio.play("roar", -10)
			if pb > 34 and g.T % 4 == 0:
				g.fx("fx_dust", hx - 60, hy - 4, 14, .14, -.2)
			if pb >= PBOARD:
				phase = "taxi"
				g.flash_tut("Decolar!", "No ar: ↑ sobe, ↓ desce. Desvie dos pássaros e das nuvens de tempestade.", 220)
		"taxi":
			spd = min(spd + .06, float(PL.spd))
			hx += spd
			hy = float(PL.y)
			if g.T % 3 == 0:
				g.fx("fx_dust", hx - 50, hy - 4, 14, .14, -.2)
			if hx > float(PL.edge):
				phase = "fly"
				vy = 1.5
				g.note("Voando!")
		"fly":
			spd = move_toward(spd, plane_spd_at(hx), .05)
			# marcos do voo: passou da bandeira (balão), recomeça dali se rodopiar
			var C: Array = PL.get("cps", [])
			if cp_i + 1 < C.size() and hx > float(C[cp_i + 1]):
				cp_i += 1
				cheer("MARCO %d" % (cp_i + 1), "Se o avião rodopiar, recomeça daqui.", 110, true)
				Audio.play("unlock", -8, 1.2)
			var up: bool = (g.kd("U") or g.kd("J")) and stumble < 25
			var dn: bool = g.kd("S") and stumble < 25
			var want: float = -4.2 if up else (4.2 if dn else .35)
			vy = move_toward(vy, want, .22)
			hy = clamp(hy + vy, float(PL.top), float(PL.low))
			hx += spd
			tilt = lerpf(tilt, vy * .06, .2)
			_plane_obs()
			if hx >= float(PL.x1) - 900:
				phase = "land"
		"land":
			# desce sozinho até a clareira
			var gy: float = float(PL.land)
			# desce na medida certa para tocar o chão um pouco antes do fim
			var left: float = max(8.0, (float(PL.x1) - 260.0 - hx) / max(spd, 1.0))
			vy = move_toward(vy, (gy - hy) / left, .3)
			hy = min(gy, hy + vy)
			hx += spd
			tilt = lerpf(tilt, vy * .05, .2)
			if hx > float(PL.x1) - 260 or hy >= gy - .5:
				if not fin_cheer:
					# tocou o chão: pouso! a faixa com a nota do voo
					fin_cheer = true
					cheer("POUSO PERFEITO!" if hits == 0 else "CHEGADA!", _grade(), 190)
					Audio.play("special", -4)
					g.shake = max(g.shake, 3)
					for k in 12:
						Polish.part("dust", hx - 40 + randf_range(-20, 20), gy - 2, -randf_range(1, 4), -randf_range(.3, 1.5), 30, Color(.95, .97, 1, .8), {"size": 4.0})
				hy = gy
				spd = move_toward(spd, 0.0, .12)
				tilt = lerpf(tilt, 0.0, .2)
				if g.T % 3 == 0:
					g.fx("fx_dust", hx - 50, hy - 4, 14, .14, -.2)
			if spd <= 0.0 and hy >= gy:
				_finish_plane()
	if stumble > 0:
		stumble -= 1
	if phase == "fly":
		_coins(box())
	# fumaça do motor saindo pelo escapamento (preta e mais grossa logo depois de uma batida)
	if phase in ["taxi", "fly", "land"] and g.T % 3 == 0:
		var ex := Vector2(30, -52).rotated(tilt)
		var dark: bool = stumble > 0
		Polish.part("puff", hx + ex.x, hy + ex.y, -spd * .35 - randf() * .6, -.3 - randf() * .4, 34 if dark else 26, Color(.25, .24, .26, .55) if dark else Color(.85, .87, .9, .4), {"size": 3.5 if dark else 2.6, "grow": .22})

func _plane_obs() -> void:
	var b := box()
	for o in OBS:
		if o.x - hx > 900 or o.x - hx < -400:
			continue
		o.t += 1
		match o.k:
			"flock":
				o.x = o.ox - o.t * 1.2
				o.y = o.oy + sin(o.t * .05) * 16
				for i in int(o.get("n", 5)):
					var bx: float = o.x + (i % 3) * 34 - (i / 3) * 14
					var by: float = o.y + (i / 3) * 26 + (i % 3) * 6
					if not o.hit and Game.hit(b, g.R(bx - 12, by - 8, 24, 16)):
						o.hit = true
						_hurt_plane()
			"hawk":
				# avisa (!), mergulha até a altura em que o avião estava e varre a faixa voando reto
				match o.st:
					"wait":
						if o.x - hx < 820:
							o.st = "warn"
							o.t = 0
							o.ty = hy - 26
					"warn":
						if o.t > 60:
							o.st = "dive"
							o.t = 0
							o.vx = -120.0 / 30.0
							o.vy = (o.ty - o.y) / 30.0
					"dive":
						o.x += o.vx
						o.y += o.vy
						if o.t >= 30:
							o.st = "sweep"
							o.t = 0
							o.y = o.ty
					"sweep":
						o.x -= 4.5
						if o.t > 120:
							o.st = "gone"
				if o.st in ["dive", "sweep"] and not o.hit and Game.hit(b, g.R(o.x - 22, o.y - 12, 44, 24)):
					o.hit = true
					_hurt_plane()
			"spire":
				# pico de pedra subindo do vale: passa por cima
				if not o.hit and Game.hit(b, g.R(o.x - 38, float(o.top) + 10, 76, 2000)):
					o.hit = true
					_hurt_plane()
			"cloud":
				if not o.hit and Game.hit(b, g.R(o.x + 20, o.y + 14, o.w - 40, o.h - 28)):
					o.hit = true
					g.flash_t = 0
					_hurt_plane()

## velocidade do voo: vai acelerando até o trecho final
func plane_spd_at(x: float) -> float:
	return float(PL.spd) + float(PL.get("ramp", .8)) * smoothstep(float(PL.edge) + 600.0, float(PL.x1) - 1600.0, x)

func _hurt_plane() -> void:
	var p: Dictionary = g.player
	hits += 1
	g.shake_dir = Vector2(-1, 0) * 5.0
	Polish.impact(hx + 30, hy - 30, Color(1, .65, .55), 6, 26.0)
	stumble = 40
	vy = 2.5
	g.shake = 6
	g.hit_stop = 4
	Audio.play("hurt")
	Audio.play("thunder", -10)
	Audio.vib(60)
	g.burst(hx + 30, hy - 30, 14, Color("#e07a6a"))
	if p.iframe > 0:
		return
	p.iframe = 50
	p.hp -= 1
	if p.hp <= 0:
		tries += 1
		g.iris_t = 30
		var keep: int = cp_i
		var h0: int = hits
		var C: Array = PL.get("cps", [])
		g.flash("O avião rodopiou! De volta ao marco — ↑ sobe, ↓ desce." if keep >= 0 else "O avião rodopiou! De novo — ↑ sobe, ↓ desce.", 220)
		_start_plane()
		hits = h0
		cp_i = keep
		# recomeça já no ar: no último marco, ou logo depois do precipício
		phase = "fly"
		hx = float(C[keep]) - 120.0 if keep >= 0 else float(PL.edge) + 20
		hy = float(PL.y) + 30
		vy = 0.0
		spd = plane_spd_at(hx)
		for o in OBS:
			o.hit = float(o.x) < hx - 300.0
		_place_player()
		g.snap_camera()

func _finish_plane() -> void:
	var p: Dictionary = g.player
	mode = ""
	plane_done = true
	PL.px = hx
	PL.py = hy
	p.x = hx - 110
	p.y = hy - p.h - 4
	p.vx = 0.0
	p.vy = -5.0
	p.onGround = false
	p.hp = max(p.hp, 1)
	if g.X.DOG.get("st", "") == "ride":
		g.X.DOG.st = "door"
		g.X.DOG.x = p.x - 30
		g.X.DOG.y = hy
	Audio.play("stomp", -8)
	g.flash("Pouso perfeito! A mina fica logo ali.", 220)

func _coins(b: Dictionary) -> void:
	for c in g.coins_near(hx - 120, hx + 120):
		if not c.got and abs(c.x - hx) < 90 and Game.hit(b, g.R(c.x - 15, c.y - 15, 30, 30)):
			c.got = true
			g.STATS.pen += 1
			g.gain_coin(c.x, c.y)

func save_data() -> Dictionary:
	return {"raft": raft_done, "plane": plane_done, "sled": sled_done, "ppx": PL.get("px", 0.0), "ppy": PL.get("py", 0.0)}

func restore(d: Dictionary) -> void:
	raft_done = d.get("raft", false)
	sled_done = d.get("sled", false)
	plane_done = d.get("plane", false)
	if raft_done and not RA.is_empty():
		RA.px = float(RA.x1) - 90
		_drop_raft_sol()
		_end_fence()
	if plane_done and not PL.is_empty():
		PL.px = d.get("ppx", PL.x1)
		PL.py = d.get("ppy", PL.land)
