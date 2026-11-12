extends RefCounted
class_name Mech
## Mecânicas no estilo "Oddmar": golpe de picareta e defesa com a lanterna, pulo na parede,
## objetos com física (caixas de empurrar, placas de pressão, portões, plataformas que desabam)
## e o Pipoca como parceiro controlável (troca de personagem).

var g  # Game
var ctrl := false            # true = o jogador está controlando o Pipoca
var tome := {}               # corpo do Tomé parado enquanto o Pipoca anda
var drawing_tome := false
var swing_t := 0
var swing_hit := {}
var hold_g := 0
# luta do aeroporto: combo do bastão (3 golpes, o 3º é um giro), chute (rasteira no chão, voadora no
# ar) e defesa (segurar = escudo de energia; apertar na hora certa = aparo; com direção = esquiva)
var combo_n := 0
var combo_wait := 0
var kick_t := 0
var kick_kind := ""
var kick_hit := {}
var parry_t := 0
var dodge_t := 0
var combo_q := false   # golpe apertado cedo demais: guarda e solta assim que der
var PLATES: Array = []
var GATES: Array = []
var CRUMB: Array = []
var PUSH: Array = []
var dig_t := 0
var dog_note := 0
const DOG_W := 30.0
const DOG_H := 20.0

func _init(game) -> void:
	g = game

func load_level() -> void:
	ctrl = false
	tome = {}
	swing_t = 0
	hold_g = 0
	dig_t = 0
	PLATES = []
	for p in g.L.get("plates", []):
		var o: Dictionary = p.duplicate()
		o.on = false
		o.d = 0.0
		PLATES.append(o)
	GATES = []
	CRUMB = []
	for s in g.SOL:
		if s.t == "pgate":
			s.open = 0.0
			GATES.append(s)
		if s.get("crumble"):
			s.ct = 0
			s.fallen = false
			s.fy = 0.0
			s.rt = 0
			s.oy = s.y
			CRUMB.append(s)
	PUSH = []
	for c in g.CR:
		if c.t == "push":
			c.vy = 0.0
			PUSH.append(c)

# ======================================================================
#  CORPOS (o Tomé e o Pipoca usam a mesma física)
# ======================================================================
func is_dog() -> bool:
	return g.player.get("dog", false)

func tome_body() -> Dictionary:
	return tome if ctrl else g.player

func dog_ok_now() -> String:
	var p: Dictionary = g.player
	if not g.X.dog_free():
		return "no"
	if not g.CINE.is_empty() or g.X.boss_active() or p.dyingT > 0:
		return "agora não"
	if g.ZN and g.ZN.zone != null:
		return "a Bag ficou esperando"
	if g.VIL and g.VIL.go and not g.VIL.gone:
		return "agora não: o Barão está fugindo!"
	if not ctrl and (p.ladder or p.vine or p.swim or not p.onGround):
		return "pare em chão firme para trocar"
	if ctrl and not p.onGround and not p.swim:
		return "espere a Bag pousar"
	return ""

func toggle_dog() -> void:
	var why := dog_ok_now()
	if why == "no":
		return
	if why != "":
		g.note("Trocar para a Bag: " + why + ".")
		return
	var X = g.X
	if not ctrl:
		tome = g.player
		tome.vx = 0.0
		tome.run = 0
		tome.guard = false
		var d: Dictionary = g.make_body(X.DOG.x - DOG_W / 2, X.DOG.y - DOG_H)
		d.w = DOG_W
		d.h = DOG_H
		d.dog = true
		d.face = X.DOG.face
		d.onGround = true
		d.airJumps = 0
		d.hp = tome.hp
		d.spawnX = tome.spawnX
		d.spawnY = tome.spawnY
		g.player = d
		ctrl = true
		X.DOG.st = "ctrl"
		X.DOG.hy = 0.0
		g.prev_px = d.x
		g.prev_py = d.y
		X._bark()
		if dog_note < 1:
			dog_note = 1
			g.tip("Agora você é a Bag! Ela passa por portinholas e buracos pequenos e buzina (✦). Troque de volta pelo mesmo botão.", 260)
	else:
		_back_to_tome()

func _back_to_tome() -> void:
	var X = g.X
	var d: Dictionary = g.player
	X.DOG.x = d.x + d.w / 2
	X.DOG.y = d.y + d.h
	X.DOG.face = d.face
	X.DOG.hy = 0.0
	X.DOG.st = "stay" if on_any_plate(d) else "follow"
	tome.hp = max(tome.hp, d.hp)
	g.player = tome
	ctrl = false
	g.prev_px = tome.x
	g.prev_py = tome.y
	X._resync()
	if X.DOG.st == "stay":
		g.note("Fica, Bag! Ela vai segurar a placa.")

## o Pipoca levou uma pancada ou caiu: ganiu e volta correndo para perto do Tomé (sem perder vida)
func dog_hurt() -> void:
	if not ctrl:
		return
	Audio.play("bark", -2)
	g.burst(g.player.x + DOG_W / 2, g.player.y, 12, Color("#d8c8a0"))
	g.flash("A Bag levou um susto e voltou rolando para o Milis.", 160)
	_back_to_tome()
	g.X.DOG.x = tome.x - tome.face * 30
	g.X.DOG.y = tome.y + tome.h
	g.X.DOG.st = "follow"
	g.X._resync()

# ======================================================================
#  ANTES DA FÍSICA: golpe, defesa, troca e ações do Pipoca
# ======================================================================
func pre() -> void:
	var p: Dictionary = g.player
	if g.pressed("D"):
		toggle_dog()
		p = g.player
	if p.get("dog"):
		p.guard = false
		if dig_t > 0:
			dig_t -= 1
			g.keys.clear()
			if dig_t % 6 == 0:
				g.PARTS.append({"x": p.x + p.w / 2 - p.face * 12, "y": p.y + p.h - 4, "vx": -p.face * (2 + randf() * 2), "vy": -2 - randf() * 2, "life": 18, "col": Color("#7a5a3a")})
			if dig_t == 0:
				_dig_done()
		if g.pressed("G"):
			g.keys["Ap"] = true
		return
	if swing_t > 0:
		swing_t -= 1
	if g.L.get("theme", "") == "aeroporto":
		_fight(p)
		return
	if g.TR.pick_out() and g.pressed("G"):
		g.TR.recall_pick()
	elif g.TR.want_throw() and swing_t == 0 and g.pressed("G"):
		g.TR.throw_pick()
		hold_g = -30
	# debaixo d'água também dá picaretada (um pouco mais lenta); com o arpão, o GOLPE na água dispara o arpão
	if g.pressed("G") and swing_t == 0 and not p.ladder and not p.vine and not p.get("bar") and not p.crouch:
		swing_t = 26 if p.swim else 22
		swing_hit = {}
		p.act = "swing"
		p.actT = 22
		# "vush" da picareta: o mesmo som do deslize, mais agudo e curto (não confunde com o deslizar)
		Audio.play("slide", -8, randf_range(1.3, 1.45))
	if g.kd("G"):
		hold_g += 1
	else:
		hold_g = 0
	p.guard = hold_g > 14 and swing_t == 0 and not p.ladder and not p.vine and not p.swim and p.dyingT == 0
	if swing_t >= 8 and swing_t <= 16:
		_swing_hits()

## botões de luta do aeroporto (G golpe, K chute, F defesa)
func _fight(p: Dictionary) -> void:
	if combo_wait > 0:
		combo_wait -= 1
		if combo_wait == 0:
			combo_n = 0
	if parry_t > 0:
		parry_t -= 1
	if int(p.get("counterT", 0)) > 0:
		p.counterT = int(p.counterT) - 1
		# brilho no bastão enquanto a janela de contra-ataque está aberta
		if g.T % 3 == 0:
			g.PARTS.append({"x": p.x + p.w / 2 + p.face * 14, "y": p.y + p.h * .35, "vx": randf_range(-.4, .4), "vy": -.8, "life": 14, "col": Color(.6, .95, 1)})
	var busy: bool = p.ladder or p.vine or p.get("bar") or p.swim or p.dyingT > 0
	# --- defesa / esquiva
	if g.pressed("F") and not busy:
		var dir: int = 1 if g.kd("R") else (-1 if g.kd("L") else 0)
		if dir != 0 and p.onGround and dodge_t == 0:
			dodge_t = 14
			p.face = dir
			p.vx = dir * 3.0
			p.iframe = max(int(p.iframe), 18)
			p.wlock = 12
			p.act = "dodge"
			p.actT = 14
			Audio.play("slide", -6, 1.15)
			for k in 6:
				g.PARTS.append({"x": p.x + p.w / 2 - dir * 10, "y": p.y + p.h - 3, "vx": -dir * randf_range(1, 2.5), "vy": -randf_range(.2, 1), "life": 16, "col": Color(.82, .84, .88, .7)})
		else:
			parry_t = 9
	if dodge_t > 0:
		dodge_t -= 1
		# a física limita a velocidade de andar: a esquiva empurra o corpo direto (rápida e curta)
		g.move_x(p.face * (6.5 if dodge_t > 4 else 2.0))
		p.vx = p.face * 3.0
	p.guard = g.kd("F") and dodge_t == 0 and swing_t == 0 and kick_t == 0 and not busy
	# --- golpe: combo de 3 (o 3º gira e arremessa)
	if g.pressed("G"):
		combo_q = true
	if combo_q and swing_t > 9 and combo_n in [1, 2]:
		pass   # espera o golpe atual chegar no ponto de emendar
	elif combo_q and not busy and not p.crouch and kick_t == 0 and dodge_t == 0:
		combo_q = false
		if swing_t == 0 or (swing_t <= 9 and combo_n in [1, 2]):
			combo_n = combo_n + 1 if (combo_wait > 0 and combo_n < 3) else 1
			swing_hit = {}
			if combo_n == 3:
				swing_t = 26
				p.act = "spin"
				p.actT = 26
				p.vx += p.face * 2.0
				Audio.play("slide", -5, 1.0)
			else:
				swing_t = 18
				p.act = "swing" if combo_n == 1 else "swing2"
				p.actT = 18
				p.vx += p.face * 1.2
				Audio.play("slide", -8, randf_range(1.3, 1.45) + combo_n * .08)
			combo_wait = swing_t + 16
	if swing_t > 0:
		if p.act == "spin":
			if swing_t >= 4 and swing_t <= 22:
				_attack_hits(_spin_box(), "spin")
		elif swing_t >= 6 and swing_t <= 14:
			_attack_hits(swing_box(), "hit")
			if swing_t == 10:
				_swing_world(swing_box())
	# --- chute: rasteira no chão, voadora no ar
	if g.pressed("K") and not busy and kick_t == 0 and swing_t == 0 and dodge_t == 0:
		kick_hit = {}
		if p.onGround:
			kick_kind = "sweep"
			kick_t = 20
			p.vx = p.face * 6.0
			p.wlock = 14
			p.act = "sweep"
			p.actT = 20
			Audio.play("slide", -6, .95)
		else:
			kick_kind = "fly"
			kick_t = 60
			p.vx = p.face * 7.5
			p.vy = max(float(p.vy), 2.0)
			p.wlock = 60
			p.act = "flykick"
			p.actT = 60
			Audio.play("slide", -5, .8)
	if kick_t > 0:
		kick_t -= 1
		var cx: float = p.x + p.w / 2
		var hb: Dictionary
		# (empurrão direto: a física limitaria a velocidade de andar)
		if kick_kind == "sweep" and kick_t > 6:
			g.move_x(p.face * 2.6)
		elif kick_kind == "fly" and not p.onGround:
			g.move_x(p.face * 3.2)
		if kick_kind == "sweep":
			hb = g.R(cx + (2.0 if p.face > 0 else -66.0), p.y + p.h - 24, 64, 24)
			if kick_t <= 16 and kick_t >= 4:
				_attack_hits(hb, "kick")
		else:
			hb = g.R(cx + (0.0 if p.face > 0 else -56.0), p.y + p.h * .35, 56, p.h * .65 + 8)
			_attack_hits(hb, "kick")
			if p.onGround and kick_t < 58:
				# pousou: acaba a voadora
				kick_t = 0
				p.wlock = 0
				p.actT = 0
		if kick_t == 0:
			p.wlock = min(int(p.wlock), 0) if kick_kind == "fly" else p.wlock

func _spin_box() -> Dictionary:
	var p: Dictionary = g.player
	var cx: float = p.x + p.w / 2
	return g.R(cx - 70, p.y - 10, 140, p.h + 16)

## acerta capangas numa caixa; "spin" e "kick" arremessam longe
func _attack_hits(hb: Dictionary, how: String) -> void:
	var p: Dictionary = g.player
	var book: Dictionary = kick_hit if how == "kick" else swing_hit
	for i in g.EN.size():
		var e: Dictionary = g.EN[i]
		if e.dead or book.has(i):
			continue
		if Game.hit(hb, g.ebox(e)):
			# sem acertar através de balcão ou parede
			var eb: Dictionary = g.ebox(e)
			if not g.los(p.x + p.w / 2, p.y + p.h * .4, eb.x + eb.w / 2, eb.y + eb.h * .5):
				continue
			book[i] = 1
			var dir: float = 1.0 if e.x > p.x + p.w / 2 else -1.0
			g.kill_enemy(e, "hit")
			if int(e.get("blockT", 0)) == 16:
				book.erase(i)   # defendeu com o escudo: o próximo golpe do combo ainda pode acertar
			# empurrão com peso: o capanga é jogado para trás (no giro e no chute, bem mais longe)
			var push: float = 70.0 if how in ["spin", "kick"] else 30.0
			if not e.dead:
				e.x += dir * push * .5
			elif e.get("dk", "") == "tomba":
				# derrubado no aeroporto: o golpe forte joga mais longe, mas ele tomba e quica (não voa girando)
				e.dvx = dir * (6.5 if how in ["spin", "kick"] else 4.2)
				e.dvy = -6.0 if how in ["spin", "kick"] else -4.5
			elif e.get("dk", "") != "seg":
				# derrubado: voa girando para longe (no giro e no chute, bem mais longe)
				e.dk = "flip"
				e.dvx = dir * (9.0 if how in ["spin", "kick"] else 5.0)
				e.dvy = -7.0 if how != "kick" else -5.0
				e.ddx = float(e.get("ddx", 0.0))
				e.ddy = float(e.get("ddy", 0.0))
			Polish.impact(e.x, e.y - 60)
			var fin: bool = how == "spin"
			var ctr: bool = int(p.get("counterT", 0)) > 0
			g.hit_stop = max(int(g.hit_stop), 7 if fin or ctr else (5 if how == "kick" else 3))
			g.shake = max(g.shake, 7 if fin or ctr else (5 if how == "kick" else 3))
			if fin or ctr:
				# golpe final do combo (ou contra-ataque depois da defesa perfeita): tem outro peso — clarão,
				# estalo grave e faíscas
				Polish.flash_white = max(Polish.flash_white, 5)
				Audio.play("stomp", -3, .74)
				Audio.vib(45)
				Polish.impact(e.x, e.y - 60, Color(1, .9, .5), 12, 34.0)
				g.burst(e.x, e.y - 60, 14, Color("#ffd76a"))
			if ctr and not e.dead and e.get("k", "") == "boar" and SegGuard.is_seg(g, e):
				# contra-ataque no segurança conta um golpe a mais
				SegGuard.on_hit(g, e, "hit")
			if ctr:
				p.counterT = 0
			if how == "kick" and kick_kind == "fly":
				# voadora acertou: quica para trás
				p.vy = -6.5
				p.vx = -p.face * 3.0
				kick_t = 0
				p.wlock = 0
				p.actT = 0
	FiscalBoss.swing(g, g.X, hb)
	if g.QB:
		g.QB.hit_box(hb, float(p.face), how)
	for c in g.CR:
		if not c.dead and c.t == "break" and not book.has(c) and Game.hit(hb, c):
			book[c] = 1
			g.break_crate(c)

## o resto do mundo que o bastão alcança (pedras, armadilhas, objetos)
func _swing_world(hb: Dictionary) -> void:
	g.PR.swing_hits(hb)
	g.TR.swing_hits(hb)
	g.K.swing_hits(hb)
	for c in g.X.CRACKS:
		if not g.X.broken.has(c.id) and Game.hit(hb, c):
			g.X.break_crack(c, true)

func swing_box() -> Dictionary:
	var p: Dictionary = g.player
	var cx: float = p.x + p.w / 2
	return g.R(cx + 2 if p.face > 0 else cx - 58, p.y - 10, 56, p.h + 16)

func _swing_hits() -> void:
	var hb := swing_box()
	if g.player.onGround:
		Polish.cut_grass(hb.x, hb.x + hb.w, g.player.y + g.player.h)
	var p: Dictionary = g.player
	for i in g.EN.size():
		var e: Dictionary = g.EN[i]
		# (chave pelo índice: o dicionário do inimigo muda a cada passo e não serve de chave)
		if e.dead or swing_hit.has(i):
			continue
		if Game.hit(hb, g.ebox(e)):
			swing_hit[i] = 1
			if e.k == "mole" and e.get("helm") and not e.get("helm_off") and e.get("st", 0) != 5:
				Audio.play("unlock", -8)
				g.burst(e.x, e.base - 26, 8, Color("#e8b030"))
				g.tip("Clanc! O capacete aguenta o bastão. A Bag consegue puxar ele para fora.")
				e.stun = 30
			else:
				g.kill_enemy(e, "hit")
	g.PR.swing_hits(hb)
	for r in g.X.RELICS:
		if not r.broken and Game.hit(hb, g.R(r.x - 26, r.y - 46, 52, 46)):
			r.broken = true
			Audio.play("stomp")
			g.shake = max(g.shake, 6)
			g.fx("fx_pieces", r.x, r.y - 20, 20, .35, -.4)
			g.burst(r.x, r.y - 20, 18, Color("#9a8a7a"))
	g.TR.swing_hits(hb)
	g.K.swing_hits(hb)
	FiscalBoss.swing(g, g.X, hb)
	var X = g.X
	for c in g.CR:
		if not c.dead and c.t == "break" and not swing_hit.has(c) and Game.hit(hb, c):
			swing_hit[c] = 1
			g.break_crate(c)
	for c in X.CRACKS:
		if not X.broken.has(c.id) and Game.hit(hb, c):
			X.break_crack(c, true)
	for c in g.COAL:
		if not c.get("ref") and Game.hit(hb, g.R(c.x - 12, c.y - 12, 24, 24)):
			reflect(c)
			g.shake = max(g.shake, 4)

func reflect(c: Dictionary) -> void:
	var p: Dictionary = g.player
	c.ref = true
	c.vx = p.face * (6.0 + abs(c.vx) * .4)
	c.vy = -4.5
	c.life = 140
	c.b = 1
	Audio.play("unlock", -10)
	Audio.vib(20)
	g.burst(c.x, c.y, 8, Color("#ffcf6a"))

## defesa: a lanterna levantada bloqueia o que vem de frente
func blocks(from_x: float) -> bool:
	var p: Dictionary = g.player
	if not p.get("guard", false):
		return false
	var cx: float = p.x + p.w / 2
	return (from_x - cx) * p.face > -4

func on_block(from_x: float) -> void:
	var p: Dictionary = g.player
	p.vx = -p.face * 2.5
	g.shake = max(g.shake, 5)
	Audio.play("unlock", -6)
	Audio.vib(25)
	g.burst(p.x + p.w / 2 + p.face * 16, p.y + 12, 10, Color("#ffe9a0"))
	var parry: bool = parry_t > 0
	for e in g.EN:
		if not e.dead and abs(e.x - from_x) < (90 if parry else 40):
			e.stun = 110 if parry else 70
			if parry:
				# aparo: o capanga fica tonto e é jogado para trás
				e.dizzyT = 110
				e.charge = false
				e.x += (1.0 if e.x > p.x else -1.0) * 40.0
	if parry:
		parry_t = 0
		# defesa perfeita: câmera lenta, anel de luz e uma janela de contra-ataque (o próximo golpe pesa mais)
		g.slowmo = max(int(g.slowmo), 32)
		p.counterT = 75
		Polish.part("ringw", p.x + p.w / 2 + p.face * 18, p.y + p.h * .4, 0, 0, 22, Color(.6, .95, 1, .9), {"size": 80.0})
		g.hit_stop = max(int(g.hit_stop), 7)
		Audio.play("clue", -6, 1.6)
		Polish.impact(p.x + p.w / 2 + p.face * 24, p.y + p.h * .4)
		g.burst(p.x + p.w / 2 + p.face * 22, p.y + p.h * .4, 16, Color(.6, .95, 1))

# ---------- ações do Pipoca (✦) ----------
func dog_action() -> void:
	var p: Dictionary = g.player
	var X = g.X
	if g.TR.dog_bite(p):
		return
	for tc in X.TOCAS:
		if not tc.done and abs(p.x + p.w / 2 - tc.x) < 50 and abs(p.y + p.h - tc.y) < 40:
			dig_t = 70
			X.DOG.st = "ctrl"
			X.DOG.digtoca = tc
			Audio.play("bark", -6)
			return
	X._bark()
	for e in g.EN:
		if e.dead:
			continue
		var d: float = Vector2(e.x, e.y).distance_to(Vector2(p.x + p.w / 2, p.y + p.h / 2))
		if d > 170:
			continue
		if e.k == "mole" and e.get("st", 0) == 0:
			e.st = 5
			e.t = 0
			e.helm_off = true
			g.burst(e.x, e.base - 10, 14, Color("#7a5a3a"))
			g.note("O latido assustou a toupeira para fora da terra!")
		elif e.k == "bat":
			e.st = 2
			e.t = 0
		else:
			e.stun = 90

func _dig_done() -> void:
	var X = g.X
	var tc: Dictionary = X.DOG.get("digtoca", {})
	if tc.is_empty():
		return
	tc.done = true
	Audio.play("item")
	var p: Dictionary = g.player
	var found := false
	for d in g.DRWS:
		if d.get("hidden") and d.get("toca") == tc.get("id", 1):
			d.hidden = false
			d.x = p.x + p.w / 2 + p.face * 30
			d.y = p.y - 6
			found = true
	if not found:
		for i in 5:
			g.gain_coin(tc.x, tc.y - 20)
	g.burst(tc.x, tc.y - 10, 16, Color("#7a5a3a"))

# ======================================================================
#  DEPOIS DA FÍSICA: caixas, placas, portões, plataformas que desabam
# ======================================================================
func post() -> void:
	var X = g.X
	var p: Dictionary = g.player
	if ctrl:
		X.DOG.x = p.x + p.w / 2
		X.DOG.y = p.y + p.h
		X.DOG.face = p.face
		X.DOG.moving = abs(p.vx) > .3 and p.onGround
		X.DOG.anim += abs(p.vx) * .08
		X.DOG.hy = 0.0
		if dig_t > 0:
			X.DOG.st = "dig"
		elif X.DOG.st == "dig":
			X.DOG.st = "ctrl"
	# caixas de empurrar caem
	var camc: float = g.cam + g.W / 2
	for c in PUSH:
		if c.dead:
			continue
		# longe da tela e parada: não precisa simular (a fase é longa)
		if abs(c.x - camc) > 1500 and c.vy == 0.0:
			continue
		# caiu num buraco sem fundo: volta para o lugar de origem
		if c.y > float(g.L.bottom) + 80.0:
			_reset_one(c)
			continue
		c.vy = min(c.vy + .6, 12.0)
		var ny: float = c.y + c.vy
		var land := INF
		for s in g.blockers():
			if s == c or s.get("oneway") and c.y + c.h > s.y + 1:
				continue
			if c.x + 2 < s.x + s.w and c.x + c.w - 2 > s.x and s.y >= c.y + c.h - 1 and s.y < ny + c.h:
				land = min(land, s.y)
		if land < INF:
			if c.vy > 4:
				g.shake = max(g.shake, 4)
				Audio.play("stomp", -10)
				g.burst(c.x + c.w / 2, land, 8, Color("#b7a77f"))
			c.y = land - c.h
			# caixa pesada: um quiquezinho na queda alta e assenta
			c.vy = -c.vy * .22 if c.vy > 6.0 else 0.0
		else:
			c.y = ny
	# placas de pressão (a lista de corpos é montada uma vez por passo: antes era refeita, com um
	# Dictionary novo por caixa, para cada placa, portão e tábua podre)
	var bl: Array = bodies()
	for pl in PLATES:
		# placa longe da tela e solta: nada pode estar em cima dela (as caixas só andam empurradas)
		if not pl.on and abs(pl.x - camc) > 2200:
			pl.d = move_toward(pl.d, 0.0, .2)
			continue
		var on := false
		for b in bl:
			var feet: float = b.y + b.h
			if feet > pl.y - 6 and feet < pl.y + 6 and b.x + b.w > pl.x + 6 and b.x < pl.x + pl.w - 6:
				on = true
		if on and not pl.on:
			Audio.play("unlock", -8)
			Audio.vib(20)
		pl.on = on
		pl.d = move_toward(pl.d, 1.0 if on else 0.0, .2)
	for gt in GATES:
		if gt.get("crank"):
			continue   # portas de manivela: quem mexe é a manivela (game.crank_tap)
		var want := 0.0
		for pl in PLATES:
			if pl.gate == gt.id and pl.on:
				want = 1.0
		if gt.get("force_open"):
			want = 1.0
		if gt.get("auto"):
			# porta automática de vidro: abre e fecha no ritmo (não fecha em cima de ninguém)
			var per: int = int(gt.get("per", 200))
			want = 1.0 if (g.T + int(gt.get("ph", 0))) % per < int(per * .55) else 0.0
		if want == 0.0 and gt.open > 0.0:
			for b in bl:
				if b.x + b.w > gt.x and b.x < gt.x + gt.w and b.y + b.h > gt.y and b.y < gt.y + gt.h:
					want = gt.open
		var was: float = gt.open
		gt.open = move_toward(gt.open, want, .04 if want > gt.open else .03)
		if was < .5 and gt.open >= .5:
			Audio.play("door", -8)
	# plataformas que desabam
	for s in CRUMB:
		if s.fallen:
			s.fy += 6.0
			s.rt -= 1
			if s.rt <= 0:
				# não volta por cima de quem está passando no lugar (prenderia o Tomé dentro da tábua)
				var busy := false
				for b in bl:
					if b.x + b.w > s.x and b.x < s.x + s.w and b.y + b.h > s.oy - 2 and b.y < s.oy + s.h:
						busy = true
				if busy:
					s.rt = 10
					continue
				s.fallen = false
				s.pop = 0.0   # volta aparecendo aos poucos (o desenho usa s.pop)
				s.ct = 0
				s.fy = 0.0
			continue
		if float(s.get("pop", 1.0)) < 1.0:
			s.pop = min(1.0, float(s.pop) + .06)
		# só quem anda pisa na tábua (as caixas da lista não têm chão próprio)
		var stood: bool = g.player.get("_g") == s or (ctrl and tome.get("_g") == s)
		if stood or s.ct > 0:
			s.ct += 1
			if s.ct == 1:
				Audio.play("climb")
			if s.ct > 30:
				s.fallen = true
				s.rt = 240
				Audio.play("stomp", -8)
				g.burst(s.x + s.w / 2, s.y + 8, 10, Color("#8a6a42"))

## corpos que apertam placas: Tomé, Pipoca (controlado ou não) e caixas
func bodies() -> Array:
	var out: Array = [g.player]
	if ctrl:
		out.append(tome)
	else:
		var D: Dictionary = g.X.DOG
		if not D.is_empty() and D.st in ["stay", "sit", "follow"]:
			out.append({"x": D.x - DOG_W / 2, "y": D.y - DOG_H, "w": DOG_W, "h": DOG_H, "_g": null})
	for c in PUSH:
		if not c.dead:
			out.append(c)   # (a própria caixa: só x, y, w, h são lidos; antes criava um Dictionary por caixa)
	return out

func on_any_plate(b: Dictionary) -> bool:
	for pl in PLATES:
		var feet: float = b.y + b.h
		if feet > pl.y - 6 and feet < pl.y + 6 and b.x + b.w > pl.x + 6 and b.x < pl.x + pl.w - 6:
			return true
	return false

## empurrar caixa (chamado pela colisão horizontal do Tomé)
func try_push(c: Dictionary, dx: float) -> bool:
	var p: Dictionary = g.player
	if c.t != "push" or p._g == null or p.crouch or p.get("dog") or p.get("guard"):
		return false
	var amt: float = clamp(dx * .92, -3.9, 3.9)
	# a caixa nunca volta para trás do lugar onde começou: assim não fica presa num paredão
	# sem espaço para o Tomé passar para trás dela
	if amt < 0 and c.x + amt < c.ox:
		amt = c.ox - c.x
		if amt > -.01:
			return false
	var r: Dictionary = g.R(c.x + amt, c.y, c.w, c.h - 2)
	for s in g.blockers():
		if s == c or s.get("oneway"):
			continue
		if Game.hit(r, s):
			return false
	c.x += amt
	p.pushT = 10
	if g.T % 10 == 0:
		g.fx("fx_dust", c.x + (0.0 if dx > 0 else c.w), c.y + c.h - 4, 12, .1, -.2)
	# O3 arrastando: a quina de trás raspa o chão (poeira e pedrinhas)
	if g.T % 5 == 0:
		var bx: float = c.x + (0.0 if dx > 0 else c.w)
		Polish.part("dust", bx, c.y + c.h - 3, -sign(dx) * randf_range(.4, 1.2), -randf_range(.2, .6), 22, Polish.ground_col(), {"size": 3.0})
		if c.get("snow"):
			Polish.part("snow", bx, c.y + c.h - 3, -sign(dx) * randf_range(.5, 1.5), -randf_range(.8, 1.6), 26, Color(.97, .98, 1, .9), {"gy": c.y + c.h})
	return true

# ======================================================================
#  SALVAR
# ======================================================================
func save_data() -> Dictionary:
	var crates := []
	for c in PUSH:
		crates.append([c.x, c.y])
	return {"push": crates}

func restore(d: Dictionary) -> void:
	var cs: Array = d.get("push", [])
	for i in min(cs.size(), PUSH.size()):
		PUSH[i].x = max(float(cs[i][0]), float(PUSH[i].ox))
		PUSH[i].y = float(cs[i][1])
		if float(cs[i][0]) < float(PUSH[i].ox):
			PUSH[i].y = float(PUSH[i].oy)

## ↻ voltar à fogueira: as caixas que ainda estão à frente voltam ao lugar
func reset_crates(from_x: float) -> void:
	for c in PUSH:
		if not c.dead and c.ox > from_x - 40:
			_reset_one(c)

## caixa/bola de neve de volta ao lugar e ao tamanho de origem
func _reset_one(c: Dictionary) -> void:
	c.x = float(c.ox)
	c.y = float(c.oy)
	c.vy = 0.0
	if c.has("ow"):
		c.w = float(c.ow)
		c.h = float(c.get("oh", c.ow))
		c.lx = c.x
