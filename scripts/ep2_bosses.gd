extends RefCounted
class_name Ep2Bosses
## Os chefes do Episódio 2, com mecânicas próprias (nada repetido do Ep. 1):
##  - BRUTUS (quintal da vila): preso por uma corrente comprida numa estaca perto do portão. Ele investe
##    até o fim da corrente e leva um tranco. O Pipoca late do canto para provocar a investida (o Tomé no
##    chão também serve de isca). Com a corrente esticada no chão, um MERGULHO na argola que brilha
##    prende um elo: a corrente encurta. Na 3ª argola ele não alcança mais nada, deita e desiste.
##  - MORCEGO-REI (caverna da mina): no escuro ele some; só ataca quando o Tomé está longe da luz
##    (chiado e olhos vermelhos avisam o rasante). O Tomé sobe nas plataformas e acende as 3 lamparinas
##    (✦ USAR perto delas). Cada uma acesa encolhe o escuro; com as 3 acesas ele fica ofuscado e cai.
##  - SAPO-REI (lago do moinho): sentado numa vitória-régia gigante, lança a língua grudenta (uma mira
##    brilha antes). Três colmeias pendem sobre as vitórias-régias: parado na frente de uma, desvie no
##    último instante e a língua gruda na colmeia; as abelhas atacam o sapo, que fica tonto — pule na
##    cabeça dele. 3 colmeias, 3 pulos. Puxado pela língua, o Tomé cai na água e perde um coração.
## As funções são estáticas: o estado fica nos dicionários de sempre (X.BOSS, K.HAWK, K.FISH).

# ======================================================================
#  BRUTUS: a corrente
# ======================================================================
const BR_HOME := 90.0      # de guarda: quantos px à frente da estaca
const BR_TAUT := 132       # quadros com a corrente esticada no chão (a janela do mergulho)
const BR_RING_R := 54.0    # o mergulho prende a argola se cair até aqui dela

static func brutus_setup(b: Dictionary, L: Dictionary) -> void:
	var c: Dictionary = L.boss.get("chain", {})
	b.stake = float(c.get("stake", float(b.x1) - 40.0))
	b.rings = []
	for rx in c.get("rings", []):
		b.rings.append({"x": float(rx), "on": false})
	b.lens = c.get("len", [700.0, 470.0, 240.0, 60.0])
	b.hooked = 0
	b.len = float(b.lens[0])
	b.maxhp = b.rings.size()
	b.hp = b.maxhp
	b.lureT = 0
	b.lure_x = 0.0
	b.chained = true
	b.sulk = false

static func brutus_reach_l(b: Dictionary) -> float:
	return max(float(b.x0) + 80.0, float(b.stake) - float(b.len))

## caixa de dano: o corpo do cão (baixa o bastante para quem está em cima de uma banca não ser pego)
static func brutus_box(g, b: Dictionary) -> Dictionary:
	return g.R(b.x - 70, b.y - 100, 140, 100)

## a próxima argola (a mais longe da estaca que ainda está solta)
static func brutus_ring(b: Dictionary):
	var k: int = int(b.get("hooked", 0))
	if k < b.get("rings", []).size():
		return b.rings[k]
	return null

static func brutus_step(g, X) -> void:
	var b: Dictionary = X.BOSS
	var p: Dictionary = g.player
	var pcx: float = p.x + p.w / 2
	var feet: float = p.y + p.h
	var on_floor: bool = p.onGround and feet >= 494 and pcx > b.x0 and pcx < b.x1 and not p.get("dog")
	if b.red > 0:
		b.red -= 1
	for k in ["hitT", "landT"]:
		if b.get(k, 0) > 0:
			b[k] -= 1
	if b.get("lureT", 0) > 0:
		b.lureT -= 1
	var home: float = float(b.stake) - BR_HOME
	var lim_l: float = brutus_reach_l(b)
	match b.st:
		"idle":
			b.t += 1
			if abs(b.x - home) > 4:
				# volta para perto da estaca (guarda o portão), sem pressa
				b.dir = 1 if home > b.x else -1
				b.x = move_toward(b.x, home, 1.4)
			else:
				b.dir = 1 if pcx > b.x else -1
			var tgt := -1.0
			if on_floor:
				tgt = pcx
			elif b.lureT > 0:
				tgt = float(b.lure_x)
			if tgt > 0 and b.t > 26:
				b.st = "paw"
				b.t = 0
				b.tx = tgt
				b.dir = 1 if tgt > b.x else -1
			elif b.t > 420 and not on_floor and X.DOG.get("st", "") != "bait":
				b.t = 0
				g.tip("Desça ao chão longe do Brutus para provocar: ele corre até o fim da corrente!", 200)
		"paw":
			b.t += 1
			if b.t % 9 == 0:
				g.fx("fx_dust", b.x - b.dir * 50, 494, 16, .14, -.3)
				Audio.play("slide", -12)
			if b.t % 14 == 1:
				Audio.play("bark", -6)
			if b.t > 40:
				b.st = "charge"
				b.t = 0
				b.spd = 2.0
				Audio.play("roar", -14)
				Polish.roar(b.x + b.dir * 60, b.y - 60)
		"charge":
			b.t += 1
			b.spd = min(b.spd + .42, 8.0)
			b.x += b.dir * b.spd
			if g.T % 4 == 0:
				g.fx("fx_dust", b.x - b.dir * 60, 494, 14, .16, -.25)
			if b.dir < 0 and b.x <= lim_l:
				b.x = lim_l
				_brutus_snap(g, b)
			elif b.dir > 0 and b.x >= min(float(b.x1) - 80.0, float(b.stake) - 30.0):
				b.x = min(float(b.x1) - 80.0, float(b.stake) - 30.0)
				b.st = "trot"
				b.t = 0
			elif b.dir < 0 and b.x < float(b.tx) - 70.0 and float(b.tx) > lim_l + 20.0:
				# o alvo estava ao alcance e ele passou direto (o Tomé pulou): freia e volta
				b.st = "trot"
				b.t = 0
		"taut":
			# esticado no fim da corrente: puxa, late, raspa as patas (a corrente fica reta no chão)
			b.t += 1
			b.x = lim_l + sin(b.t * .55) * 2.0 + 4.0 * clamp(1.0 - b.t / 10.0, 0.0, 1.0)
			b.dir = -1
			if b.t % 26 == 6:
				Audio.play("bark", -4)
				b.barkT = 14
			if b.get("barkT", 0) > 0:
				b.barkT -= 1
			if b.t > BR_TAUT:
				b.st = "trot"
				b.t = 0
		"stun":
			# a corrente encurtou com um tranco: gane, sacode a cabeça e volta para a estaca
			b.t += 1
			var kb: float = b.get("kb", 0.0)
			if kb > .1:
				b.x = min(b.x + kb, float(b.stake) - 30.0)
				b.kb = kb * .86
			if b.t > 70:
				b.st = "trot"
				b.t = 0
		"trot":
			b.t += 1
			b.dir = 1 if home > b.x else -1
			var tv: float = min(min(3.2, float(b.get("tv", 0.0)) + .14), abs(home - b.x) * .08 + .35)
			b.tv = tv
			b.x += b.dir * tv
			if abs(home - b.x) < 3:
				b.st = "idle"
				b.t = 0
				b.tv = 0.0
		"down":
			# desistiu: deita do lado da estaca, de orelhas baixas
			b.t += 1
			b.x = move_toward(b.x, float(b.stake) - 46.0, 2.0)
			if b.t == 1:
				Audio.play("bark", -10, .7)
			if b.t > 150:
				b.done = true
				b.active = false
	# contato: só a investida machuca (de cima das bancas o Tomé fica a salvo)
	if b.st == "charge" and p.dyingT == 0 and not p.get("dog"):
		var bb := brutus_box(g, b)
		if Game.hit(p, bb):
			if p.vy > 0.5 and feet - bb.y < 30:
				p.vy = -8.5
				p.y = bb.y - p.h - 1
				p.cutOk = false
				Audio.play("spring", -8)
				g.tip("Pular no Brutus não adianta: prenda a corrente nas argolas do chão!")
			else:
				g.hurt(1, b.x)

## chegou ao fim da corrente: tranco, a corrente estica reta no chão
static func _brutus_snap(g, b: Dictionary) -> void:
	b.st = "taut"
	b.t = 0
	b.hitT = 10
	g.shake = max(g.shake, 12)
	g.shake_dir = Vector2(1, 0)
	Audio.play("unlock", -2, .7)
	Audio.play("stomp", -8)
	Audio.vib(70)
	g.burst(b.x - 40, b.y - 70, 10, Color("#9aa0a6"))
	if not g.L.get("_br_taut", false):
		g.L["_br_taut"] = true
		g.flash_tut("A corrente esticou! MERGULHO na argola!", "A corrente esticou no chão! Agora: MERGULHO (pule e aperte ↓) bem em cima da argola que brilha.", 220)

## mergulho do Tomé no chão do quintal (chamado pelo Slam): prende a corrente na argola
static func brutus_slam(g, cx: float, feet: float) -> bool:
	var X = g.X
	if X == null or not X.boss_active():
		return false
	var b: Dictionary = X.BOSS
	if b.get("skin", "") != "dog" or b.st == "down" or abs(feet - 500.0) > 14.0:
		return false
	var r = brutus_ring(b)
	if r == null or abs(cx - float(r.x)) > BR_RING_R:
		return false
	if b.st != "taut":
		g.note("A corrente precisa estar esticada no chão: deixe o Brutus correr até o fim dela!")
		return true
	r.on = true
	b.hooked += 1
	b.hp -= 1
	b.len = float(b.lens[min(b.hooked, b.lens.size() - 1)])
	b.red = 30
	b.st = "stun"
	b.t = 0
	b.kb = 6.0
	g.hit_stop = 6
	g.shake = max(g.shake, 14)
	Audio.play("unlock", 0, .6)
	Audio.play("door", -6)
	Audio.vib(110)
	g.burst(float(r.x), 494, 22, Color("#ffd76a"))
	g.fx("fx_pieces", float(r.x), 486, 14, .25, -.4)
	if b.hooked >= b.rings.size():
		_brutus_win(g, X, b)
	else:
		var n: int = b.rings.size() - b.hooked
		g.flash("Clanc! A corrente ficou mais curta. Falta%s %d argola%s." % ["m" if n > 1 else "", n, "s" if n > 1 else ""], 180)
	return true

static func _brutus_win(g, X, b: Dictionary) -> void:
	b.st = "down"
	b.t = 0
	b.sulk = true
	b.hp = 0
	Polish.final_blow()
	Polish.loot_arc(b.x, b.y - 80, 12, 500.0)
	X._gate_on(false)
	if str(b.get("open", "")) != "":
		for so in g.SOL.duplicate():
			if so.get("id", "") == b.open:
				g.SOL.erase(so)
				if g.K:
					g.K.sink_gate(so)
		g.blockers_dirty()
	for i in 12:
		g.gain_coin(b.item[0], b.item[1] - 20, true)
	Audio.play("door", -4)
	g.flash("Com a corrente curtinha, o Brutus não alcança mais o portão: deitou e desistiu! O portão do quintal abriu.", 280)
	if X.DOG.get("st", "") == "bait":
		X.DOG.st = "follow"
		X._resync()

## Pipoca na luta do Brutus: fica no canto do quintal e late para provocar a investida
static func pipoca_bait(g, X) -> void:
	var D: Dictionary = X.DOG
	var b: Dictionary = X.BOSS
	var spot: float = float(b.x0) + 50.0
	var arrived: bool = X._run_to(spot, 500.0, 5.5)
	if not arrived:
		return
	D.face = 1
	D.moving = false
	var p: Dictionary = g.player
	var on_floor: bool = p.onGround and p.y + p.h >= 494
	# late quando o Brutus está parado de guarda e o Tomé está a salvo (em cima de uma banca)
	if b.st == "idle" and b.t > 70 and not on_floor and int(D.t) % 120 == 0:
		X._bark()
		b.lureT = 30
		b.lure_x = D.x
		if not g.L.get("_br_lure", false):
			g.L["_br_lure"] = true
			g.note("Au! Au! O Pipoca está provocando o Brutus lá do canto!")

# ======================================================================
#  MORCEGO-REI: as lamparinas
# ======================================================================
const LAMP_R := 210.0      # raio da luz de uma lamparina acesa (o morcego não entra)
const BAT_OFF := 142.0     # o corpo do morcego fica esse tanto acima de HAWK.y (por causa do desenho)

static func bat_setup(h: Dictionary, L: Dictionary) -> void:
	h.lamps = []
	for l in L.hawk.get("lamps", []):
		h.lamps.append({"x": float(l[0]), "y": float(l[1]), "lit": false, "k": 0.0, "dot": null})
	h.maxhp = max(1, h.lamps.size())
	h.hp = h.maxhp
	h.cd = 120
	h.gx = (float(h.x0) + float(h.x1)) / 2.0
	h.gyy = float(h.gy) - 300.0

static func bat_center(h: Dictionary) -> Vector2:
	return Vector2(h.x, h.y - BAT_OFF)

static func bat_box(g, h: Dictionary) -> Dictionary:
	var c := bat_center(h)
	return g.R(c.x - 46, c.y - 46, 92, 92)

## centro da luz de uma lamparina
static func lamp_light(l: Dictionary) -> Vector2:
	return Vector2(l.x, l.y - 74)

static func lit_at(h: Dictionary, pt: Vector2, r: float = LAMP_R) -> bool:
	for l in h.get("lamps", []):
		if l.lit and pt.distance_to(lamp_light(l)) < r:
			return true
	return false

static func bat_step(g, K) -> void:
	var h: Dictionary = K.HAWK
	if h.is_empty() or h.done:
		_lamp_lights(g, h)
		return
	var p: Dictionary = g.player
	var pc := Vector2(p.x + p.w / 2, p.y + p.h / 2)
	var feet: float = p.y + p.h
	var gy: float = h.gy
	if h.red > 0:
		h.red -= 1
	if h.get("landT", 0) > 0:
		h.landT -= 1
	_lamp_lights(g, h)
	# visível só perto da luz (lamparina acesa ou a lanterna do Tomé); no escuro, um vulto
	var bc := bat_center(h)
	var seen: bool = lit_at(h, bc, LAMP_R + 20.0) or bc.distance_to(pc) < 200.0 or not g.CINE.is_empty() or h.st in ["wait", "dazzle", "fall", "down", "flee"]
	h.vis = move_toward(float(h.get("vis", 1.0)), 1.0 if seen else .14, .06)
	var unlit := 0
	for l in h.lamps:
		if not l.lit:
			unlit += 1
	match h.st:
		"wait":
			if pc.x > h.trig and pc.x < h.x1 and feet <= gy + 4 and feet > gy - 300 and p.dyingT == 0:
				h.active = true
				h.st = "lurk"
				h.t = 0
				h.cd = 150
				h.x = h.x1 - 160.0
				h.y = gy - 330.0 + BAT_OFF
				h.hp = h.maxhp
				K._gate("hawkL", true, Rect2(h.x0 - 24, gy - 260, 24, 260))
				K._gate("hawkR", true, Rect2(h.x1, gy - 260, 24, 260))
				Audio.play("thunder", -8)
				if h.get("seen", false):
					# voltou da fogueira: sem a apresentação de novo, a luta recomeça direto
					g.flash("O Morcego-Rei de novo: acenda as lamparinas!", 140)
					return
				h.seen = true
				g.start_cine("morcego", (h.x0 + h.x1) / 2.0, gy - 160, 250,
					[[150, 245, "TOMÉ", "Um morcego gigante! No escuro eu nem vejo ele... Se eu acender as lamparinas da caverna, ele não tem onde se esconder.", "tome"]],
					[60, 150, "MORCEGO-REI", "o dono das profundezas"])
			return
		"lurk":
			h.t += 1
			h.cd -= 1
			# procura um canto escuro perto do Tomé, lá no alto (fica longe das lamparinas acesas)
			if h.t % 80 == 1 or lit_at(h, Vector2(h.gx, h.gyy), LAMP_R + 40.0):
				var best := Vector2(h.gx, h.gyy)
				var bs := -1e9
				for i in 14:
					var cx: float = lerpf(float(h.x0) + 70.0, float(h.x1) - 70.0, i / 13.0)
					for cy in [gy - 360.0, gy - 290.0, gy - 230.0]:
						var q := Vector2(cx, cy)
						if lit_at(h, q, LAMP_R + 50.0):
							continue
						var sc: float = -abs(cx - pc.x) * .6 + randf() * 140.0
						if sc > bs:
							bs = sc
							best = q
				h.gx = best.x
				h.gyy = best.y
			var c := bat_center(h)
			var to := Vector2(h.gx, h.gyy + sin(h.t * .05) * 14.0)
			var nc: Vector2 = c + (to - c).limit_length(2.6)
			if abs(nc.x - c.x) > .3:
				h.dir = 1 if nc.x > c.x else -1
			h.x = nc.x
			h.y = nc.y + BAT_OFF
			if h.cd <= 0 and p.dyingT == 0:
				if not lit_at(h, pc):
					h.st = "warn"
					h.t = 0
					Audio.play("roar", -8, 2.4)
					Audio.vib(20)
				else:
					h.cd = 70
					if not g.L.get("_bat_light", false):
						g.L["_bat_light"] = true
						g.note("Na luz das lamparinas o Morcego-Rei não chega perto!")
		"warn":
			# chiado e olhos vermelhos: ele vai dar o rasante
			h.t += 1
			h.dir = 1 if pc.x > h.x else -1
			var wt: int = 34 if unlit <= 1 else 44
			if h.t == wt:
				var c2 := bat_center(h)
				h.s0 = c2
				h.s1 = pc + Vector2(0, -4)
				var ex: float = clamp(h.s1.x + (h.s1.x - c2.x), float(h.x0) + 60.0, float(h.x1) - 60.0)
				h.s2 = Vector2(ex, c2.y)
				h.st = "swoop"
				h.t = 0
				Audio.play("slide", -2, .8)
		"swoop":
			h.t += 1
			var n: float = 40.0 if unlit <= 1 else 46.0
			var u: float = clamp(h.t / n, 0.0, 1.0)
			var s0: Vector2 = h.s0
			var s1: Vector2 = h.s1
			var s2: Vector2 = h.s2
			var q2 := Vector2(lerpf(s0.x, s2.x, u), lerpf(s0.y, s2.y, u) + (s1.y - s0.y) * sin(PI * u))
			h.dir = 1 if s2.x > s0.x else -1
			h.x = q2.x
			h.y = q2.y + BAT_OFF
			if lit_at(h, q2, LAMP_R - 30.0):
				# entrou na luz: dá meia-volta guinchando
				h.st = "recoil"
				h.t = 0
				Audio.play("roar", -10, 2.8)
				g.burst(q2.x, q2.y, 10, Color("#ffe9a0"))
				if not g.L.get("_bat_recoil", false):
					g.L["_bat_recoil"] = true
					g.note("A luz espantou o Morcego-Rei!")
			elif p.dyingT == 0 and Game.hit(p, bat_box(g, h)):
				g.hurt(1, h.x)
			if u >= 1.0 and h.st == "swoop":
				h.st = "lurk"
				h.t = 0
				h.cd = 90 if unlit <= 1 else 130
		"recoil":
			h.t += 1
			h.y -= 4.0
			h.x -= h.dir * 2.0
			if h.t > 26:
				h.st = "lurk"
				h.t = 0
				h.cd = 100
		"dazzle":
			# tudo aceso: ofuscado, bate as asas sem rumo e despenca
			h.t += 1
			h.x += sin(h.t * .5) * 3.0
			h.red = 6
			if h.t > 70:
				h.st = "fall"
				h.t = 0
				h.vy = 0.0
		"fall":
			h.t += 1
			h.vy = float(h.get("vy", 0.0)) + .5
			h.y = min(gy, h.y + h.vy)
			if h.y >= gy:
				h.st = "down"
				h.t = 0
				h.landT = 12
				g.shake = 12
				g.shake_dir = Vector2(0, 1)
				Audio.play("stomp", -4)
				g.burst(h.x, gy, 16, Color("#cdbfa6"))
				Polish.loot_arc(h.x, gy - 60, 10, gy)
				for i in 10:
					g.gain_coin(h.x, gy - 40, true)
		"down":
			h.t += 1
			h.y = gy
			if h.t > 150:
				h.st = "flee"
				h.t = 0
				Audio.play("dj", -8)
		"flee":
			h.t += 1
			h.x += min(6.0, .5 + h.t * .12)
			h.y -= min(4.5, .3 + h.t * .09)
			if h.t > 120:
				h.done = true
				h.active = false
				Polish.smoke_cloud(h.x, h.y - 40)

## luz das lamparinas no mapa de luz (acende aos poucos e tremula)
static func _lamp_lights(g, h: Dictionary) -> void:
	if h.is_empty():
		return
	var mn = g.get_parent()
	for l in h.get("lamps", []):
		var on: bool = l.lit or h.get("done", false)
		l.k = move_toward(float(l.k), 1.0 if on else 0.0, .035)
		if l.k > 0.0 and l.dot == null and mn != null and mn.get("light_map") != null and mn.has_method("_light"):
			l.dot = mn._light(Color(1, .78, .42), LAMP_R + 30.0)
		if l.dot != null:
			l.dot.position = lamp_light(l)
			l.dot.energy = clamp(float(g.AMB.get("dark", 0.0)), 0.0, 1.0) * 1.3 * float(l.k) * (.94 + .06 * sin(g.T * .37 + l.x))

## lamparina apagada ao lado do Tomé (em pé na plataforma dela)
static func near_lamp(g, K):
	var h: Dictionary = K.HAWK
	if h.is_empty() or h.get("skin", "") != "bat" or not h.get("active", false) or h.get("done", false):
		return null
	if h.st in ["wait", "dazzle", "fall", "down", "flee"]:
		return null
	var p: Dictionary = g.player
	if not p.onGround or p.get("dog"):
		return null
	var pcx: float = p.x + p.w / 2
	for l in h.lamps:
		if not l.lit and abs(pcx - float(l.x)) < 62.0 and abs(p.y + p.h - float(l.y)) < 12.0:
			return l
	return null

## ✦ USAR perto de uma lamparina: acende com a chama da lanterna
static func use_lamp(g, K) -> bool:
	var l = near_lamp(g, K)
	if l == null:
		return false
	var h: Dictionary = K.HAWK
	l.lit = true
	h.hp = 0
	for o in h.lamps:
		if not o.lit:
			h.hp += 1
	h.red = 20
	Audio.play("fire", -2)
	Audio.play("special", -8)
	Audio.vib(60)
	g.burst(float(l.x), float(l.y) - 74, 18, Color("#ffcf6a"))
	if h.hp <= 0:
		h.st = "dazzle"
		h.t = 0
		Polish.final_blow()
		K._gate("hawkL", false, Rect2())
		K._gate("hawkR", false, Rect2())
		g.player.hp = Game.MAXHP
		Audio.play("door", -4)
		g.flash("Tudo aceso! O Morcego-Rei ficou ofuscado e despencou! O caminho está livre.", 240)
	else:
		Audio.play("roar", -10, 2.6)
		g.flash("A lamparina acendeu! O escuro diminuiu. Falta%s %d." % ["m" if h.hp > 1 else "", h.hp], 160)
	return true

# ======================================================================
#  SAPO-REI: a língua e as colmeias
# ======================================================================
const FR_REACH := 760.0    # alcance da língua
const FR_TSPD := 30.0      # velocidade da ponta da língua

static func frog_setup(f: Dictionary, L: Dictionary) -> void:
	var fd: Dictionary = L.fish
	f.pad = null
	# vitória-régia gigante [x, w, y] (é uma das "lily" da fase; achada quando as vitórias-régias carregam)
	f.pd = fd.get("pad", [float(fd.x1) - 300.0, 220.0, float(fd.y0) - 15.0])
	f.hives = []
	for hv in fd.get("hives", []):
		f.hives.append({"x": float(hv[0]), "y": float(hv[1]), "top": float(fd.get("hang", -330)), "st": "hang", "t": 0, "sx": 0.0, "sy": 0.0})
	f.maxhp = max(1, f.hives.size())
	f.hp = f.maxhp
	f.dir = -1
	f.tg = {"st": "", "t": 0}
	f.cd = 80
	frog_home(f)

static func frog_home(f: Dictionary) -> void:
	var pd: Array = f.get("pd", [0.0, 0.0, 0.0])
	f.x = float(pd[0]) + float(pd[1]) / 2.0 + 20.0
	f.y = float(pd[2])

static func _find_pad(g, f: Dictionary) -> void:
	var pd: Array = f.get("pd", [])
	for o in g.LILY:
		if pd.size() > 0 and abs(float(o.x) - float(pd[0])) < 2:
			f.pad = o

## boca do sapo (de onde sai a língua)
static func frog_mouth(f: Dictionary) -> Vector2:
	return Vector2(f.x + f.dir * 112.0, f.y - 66.0)

static func frog_box(g, f: Dictionary) -> Dictionary:
	# tonto, ele fica achatado na folha (língua de fora): dá para pular na cabeça vindo de uma vitória-régia
	if f.get("st", "") in ["dizzy", "hurt"]:
		return g.R(f.x - 92, f.y - 74, 184, 74)
	return g.R(f.x - 92, f.y - 112, 184, 112)

static func frog_step(g, K) -> void:
	var f: Dictionary = K.FISH
	if f.is_empty() or f.done:
		return
	var p: Dictionary = g.player
	var pc := Vector2(p.x + p.w / 2, p.y + p.h / 2)
	var feet: float = p.y + p.h
	if f.red > 0:
		f.red -= 1
	if f.get("hitT", 0) > 0:
		f.hitT -= 1
	if f.get("pad") == null:
		_find_pad(g, f)
	if f.get("pad") != null and f.st not in ["down"]:
		f.y = float(f.pad.y)
	var tg: Dictionary = f.tg
	_hives_step(g, f)
	match f.st:
		"wait":
			if pc.x > f.trig and pc.x < f.x1 and feet < float(f.y0) + 10.0 and feet > float(f.y0) - 140.0 and p.dyingT == 0 and not p.get("dog"):
				f.active = true
				f.st = "idle"
				f.t = 0
				f.cd = 90
				f.hp = f.maxhp
				frog_home(f)
				K._gate("fishL", true, Rect2(f.x0 - 24, f.y0 - 330, 24, f.y1 - f.y0 + 330))
				K._gate("fishR", true, Rect2(f.x1, f.y0 - 330, 24, f.y1 - f.y0 + 330))
				Audio.play("thunder", -8)
				if f.get("seen", false):
					# já viu a apresentação (voltou da fogueira): a luta recomeça direto
					g.flash("O Sapo-Rei de novo: engane a língua com as colmeias!", 140)
					return
				f.seen = true
				g.start_cine("sapo", f.x - 60.0, f.y - 80.0, 250,
					[[150, 245, "TOMÉ", "Um sapo do tamanho de uma carroça! Essa língua gruda em tudo... e se ela grudar numa daquelas colmeias?", "tome"]],
					[60, 150, "SAPO-REI", "o dono do lago do moinho"])
			return
		"idle":
			f.t += 1
			f.cd -= 1
			if abs(pc.x - f.x) > 40:
				f.dir = 1 if pc.x > f.x else -1
			var near: bool = pc.distance_to(frog_mouth(f)) < FR_REACH and pc.x > f.x0 - 10 and p.dyingT == 0
			if f.cd <= 0 and near:
				f.st = "aim"
				f.t = 0
				tg.tgt = pc
				Audio.play("roar", -12, 1.6)
		"aim":
			# a mira brilha no Tomé; nos últimos quadros ela trava (é a hora de desviar)
			f.t += 1
			var aim_t: int = 40 if f.hp <= 1 else 52
			if f.t < aim_t - 18:
				tg.tgt = (tg.tgt as Vector2).lerp(pc, .3)
			if f.t >= aim_t:
				f.st = "tongue"
				f.t = 0
				tg.st = "out"
				tg.tip = frog_mouth(f)
				Audio.play("slide", -4, 1.4)
		"tongue":
			f.t += 1
			_tongue_step(g, K, f, tg, p)
		"dizzy":
			# as abelhas atacam: olhos girando, língua de fora — hora de pular na cabeça
			f.t += 1
			if f.t % 24 == 0:
				Audio.play("climb", -16, 1.6)
			if f.t > 300:
				# passou a tontura: as abelhas voltam para a colmeia (ela volta para o lugar)
				for hv in f.hives:
					if hv.st == "swarm":
						hv.st = "home"
						hv.t = 0
				f.st = "idle"
				f.t = 0
				f.cd = 70
				g.note("As abelhas voltaram para a colmeia. Tente de novo!")
		"hurt":
			f.t += 1
			if f.t > 40:
				f.st = "idle"
				f.t = 0
				f.cd = 80
		"down":
			# vencido: dá um pulo para trás, cai no lago e some lá no fundo
			f.t += 1
			if f.t < 30:
				f.x -= f.dir * 3.0
				f.y = float(f.pd[2]) - sin(f.t / 30.0 * PI) * 70.0
			else:
				f.y += 2.2
			if f.t == 30:
				Audio.play("splash")
				g.burst(f.x, float(f.y0), 20, Color(.7, .85, .9))
			if f.t > 160:
				f.done = true
				f.active = false
	# contato: encostar no sapo (sem estar tonto) machuca; tonto, um pulo na cabeça vale um golpe
	if p.dyingT == 0 and not p.get("dog") and f.st not in ["down", "wait"]:
		var fb := frog_box(g, f)
		if Game.hit(p, fb):
			if f.st == "dizzy" and p.vy > .8 and feet - fb.y < 34:
				_frog_stomp(g, K, f, p)
			elif f.st not in ["dizzy", "hurt"]:
				g.hurt(1, f.x)

static func _tongue_step(g, K, f: Dictionary, tg: Dictionary, p: Dictionary) -> void:
	var mouth := frog_mouth(f)
	match tg.st:
		"out":
			var tip: Vector2 = tg.tip
			var d: Vector2 = (tg.tgt as Vector2) - tip
			tip += d.limit_length(FR_TSPD)
			tg.tip = tip
			# pegou o Tomé no caminho?
			if p.dyingT == 0 and p.iframe == 0 and not p.get("dog") and Game.hit(p, g.R(tip.x - 14, tip.y - 14, 28, 28)):
				tg.st = "grab"
				tg.t = 0
				p.vx = 0.0
				p.vy = 0.0
				Audio.play("spring", -4, .6)
				return
			if d.length() <= FR_TSPD:
				tg.tip = tg.tgt
				# chegou na mira: tem colmeia ali?
				var hit_hive = null
				for hv in f.hives:
					if hv.st == "hang" and (tg.tip as Vector2).distance_to(Vector2(hv.x, hv.y - 25)) < 42.0:
						hit_hive = hv
				if hit_hive != null:
					tg.st = "stuck"
					tg.t = 0
					tg.hive = hit_hive
					hit_hive.st = "stuck"
					g.shake = max(g.shake, 6)
					Audio.play("stomp", -10, 1.4)
					g.burst(hit_hive.x, hit_hive.y - 25, 10, Color("#e8c26a"))
				else:
					tg.st = "back"
					tg.t = 0
		"stuck":
			# grudou na colmeia: puxa, a colmeia solta do cipó e vem junto até a boca
			tg.t += 1
			var hv: Dictionary = tg.hive
			if tg.t > 14:
				var tip2: Vector2 = tg.tip
				tip2 += (mouth - tip2).limit_length(16.0)
				tg.tip = tip2
				hv.st = "pulled"
				hv.sx = tip2.x
				hv.sy = tip2.y + 25.0
				if tip2.distance_to(mouth) < 18.0:
					# a colmeia bateu na cara do sapo: enxame em cima dele
					hv.st = "swarm"
					hv.t = 0
					tg.st = ""
					f.st = "dizzy"
					f.t = 0
					f.red = 20
					g.shake = max(g.shake, 8)
					Audio.play("roar", -6, 1.3)
					g.burst(mouth.x, mouth.y, 16, Color("#e8c26a"))
					if not g.L.get("_frog_dizzy", false):
						g.L["_frog_dizzy"] = true
						g.flash_tut("As abelhas atacaram! Pule na cabeça dele!", "As abelhas atacaram o Sapo-Rei e ele ficou tonto! Pule na cabeça dele agora!", 220)
		"back":
			var tip3: Vector2 = tg.tip
			tip3 += (mouth - tip3).limit_length(FR_TSPD + 6.0)
			tg.tip = tip3
			if tip3.distance_to(mouth) < FR_TSPD + 6.0:
				tg.st = ""
				f.st = "idle"
				f.t = 0
				f.cd = 70 if f.hp > 1 else 50
		"grab":
			# puxou o Tomé: arrasta até a boca e cospe no lago (perde um coração)
			tg.t += 1
			var tip4: Vector2 = tg.tip
			tip4 += (mouth - tip4).limit_length(20.0)
			tg.tip = tip4
			p.x = tip4.x - p.w / 2
			p.y = tip4.y - p.h / 2
			p.vx = 0.0
			p.vy = 0.0
			p.onGround = false
			if tip4.distance_to(mouth) < 24.0 or tg.t > 50:
				tg.st = ""
				f.st = "idle"
				f.t = 0
				f.cd = 150
				# cuspido de volta numa vitória-régia pequena (antes caía no fundo do lago e ficava
				# preso lá embaixo sem ar): cai em cima dela, molhado, e perde um coração
				var land = null
				var bd := 1e9
				for l in g.LILY:
					if l.get("big") or l.st != 0:
						continue
					var lc: float = float(l.x) + float(l.w) / 2.0
					var dd: float = abs(lc - (f.x - 330.0))
					if lc < f.x - 120.0 and dd < bd:
						bd = dd
						land = l
				Audio.play("splash")
				g.burst(mouth.x, mouth.y, 14, Color(.7, .85, .9))
				if land != null:
					p.x = float(land.x) + float(land.w) / 2.0 - p.w / 2
					p.y = float(land.y) - p.h - 60.0
				else:
					p.x = f.x + f.dir * 190.0 - p.w / 2
					p.y = float(f.y0) - p.h - 60.0
				p.vy = 1.0
				g.hurt(1, f.x)
				if not g.L.get("_frog_grab", false):
					g.L["_frog_grab"] = true
					g.note("Quando a mira brilhar, fique na frente de uma colmeia e desvie no último instante!")

static func _frog_stomp(g, K, f: Dictionary, p: Dictionary) -> void:
	p.vy = Game.STOMP * 1.1
	p.y = frog_box(g, f).y - p.h - 1
	p.cutOk = false
	p.airJumps = 1
	f.hp -= 1
	f.red = 30
	f.hitT = 16
	g.hit_stop = 6
	g.shake = 12
	Audio.play("stomp")
	Audio.play("roar", -8, 1.2)
	Audio.vib(80)
	g.burst(f.x, f.y - 110, 18, Color("#9fe07a"))
	# a colmeia usada acaba; as abelhas somem
	for hv in f.hives:
		if hv.st == "swarm":
			hv.st = "gone"
	if f.hp <= 0:
		f.st = "down"
		f.t = 0
		Polish.final_blow()
		K._gate("fishR", false, Rect2())
		K._gate("fishL", false, Rect2())
		for k in 10:
			g.gain_coin(f.x, f.y - 60, true)
		g.player.hp = Game.MAXHP
		Audio.play("door", -4)
		g.flash("O Sapo-Rei fugiu para o fundo do lago! O caminho está livre.", 260)
	else:
		f.st = "hurt"
		f.t = 0
		g.flash("Pulou na cabeça! Falta%s %d." % ["m" if f.hp > 1 else "", f.hp], 140)

static func _hives_step(g, f: Dictionary) -> void:
	for hv in f.get("hives", []):
		hv.t += 1
		match hv.st:
			"swarm":
				# o enxame zunindo em volta da cabeça do sapo
				hv.sx = lerpf(hv.sx, f.x + f.dir * 30.0, .15)
				hv.sy = lerpf(hv.sy, f.y - 100.0, .15)
			"home":
				# as abelhas levam a colmeia de volta para o cipó
				hv.sx = lerpf(hv.sx, hv.x, .06)
				hv.sy = lerpf(hv.sy, hv.y, .06)
				if Vector2(hv.sx, hv.sy).distance_to(Vector2(hv.x, hv.y)) < 4.0:
					hv.st = "hang"

## morreu/voltou à fogueira: a luta recomeça do zero
static func on_respawn(g, K) -> void:
	var h: Dictionary = K.HAWK
	if not h.is_empty() and h.get("skin", "") == "bat" and not h.done:
		for l in h.get("lamps", []):
			l.lit = false
		h.hp = h.maxhp
		h.cd = 150
	var f: Dictionary = K.FISH
	if not f.is_empty() and f.get("skin", "") == "frog" and not f.done:
		for hv in f.get("hives", []):
			hv.st = "hang"
		f.hp = f.maxhp
		f.tg = {"st": "", "t": 0}
		frog_home(f)
