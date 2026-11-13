extends RefCounted
class_name Acao
## MODO AÇÃO (fase de teste "Galeão · Ação"): a luta e o movimento no centro.
##  - zonas de luta: as grades descem e os capangas entram em ONDAS (grupos, não um por vez)
##  - capanga de capuz ("grunt"): chega perto, AVISA (braços para cima, brilho vermelho) e dá o bote
##  - dash (botão de defesa): arrancada curta com invencibilidade, no chão e no ar; cancela o golpe
##  - esquiva perfeita: o dash passa por dentro de um ataque = câmera lenta + contra-ataque
##  - combo: cada pancada soma; o combo multiplica as milhas de cada nocaute e zera se levar dano
##  - nota no fim (S, A, B, C): dano levado, maior combo e tempo
##  - passeio de bondinho: a cabine grande atravessa o vão enquanto as malas voadoras atacam
## Dados da fase: "action": 1, "zones": [{x0, x1, waves: [[{k, side|x, ...}, ...], ...]}],
##   "ride": {mover, x0, x1, spawns: [[u, [{k, dx, cy}, ...]], ...]}, "rank": {dano, combo, tempo}

var g
var Z: Array = []
var RIDE: Dictionary = {}
var combo := 0
var combo_t := 0
var best := 0
var hits := 0
var kos := 0
var pop := 0.0        # pulso do número do combo
var dash_t := 0
var dash_cd := 0
var dash_dir := 1
var air_used := false
var perfect_ok := false
var perfect_n := 0
var ticks := 0
var bonus := 0

const COMBO_T := 170
const DASH_N := 9
const DASH_CD := 30

func _init(game) -> void:
	g = game

func load_level() -> void:
	Z = []
	var i := 0
	for z in g.L.get("acZones", []):
		# o "dono" da arena é um capanga de mentira: cai quando a última onda acaba (as grades, a música
		# de luta, a câmera aberta e as faixas de cinema vêm da arena do segurança, ArenaSeg)
		var boss := {"k": "zona", "dead": 0, "x": (float(z.x0) + float(z.x1)) * .5, "r": [float(z.x0), float(z.x1)], "base": 500.0, "stun": 0, "hp": 1}
		var a := {"e": boss, "x0": float(z.x0), "x1": float(z.x1), "on": false, "done": false, "h": 0.0, "t": 0, "acao": 1}
		g.ARN.A.append(a)
		Z.append({"id": "z%d" % i, "a": a, "boss": boss, "waves": z.waves, "wi": -1, "wt": 0, "was_on": false, "y": float(z.get("y", 500))})
		i += 1
	RIDE = {}
	if g.L.has("acRide"):
		RIDE = g.L.acRide.duplicate(true)
		RIDE.st = 0      # 0 esperando o Milis subir, 1 andando, 2 chegou
		RIDE.fired = {}
		RIDE.mv = g.MV.MV[int(RIDE.mover)]
		RIDE.mv.t = 0.0
		RIDE.mv.hold = true

# ------------------------------------------------------------------ passo
func step() -> void:
	var p: Dictionary = g.player
	ticks += 1
	if combo_t > 0:
		combo_t -= 1
		if combo_t == 0:
			combo = 0
	pop = max(0.0, pop - .08)
	if dash_cd > 0:
		dash_cd -= 1
	if p.onGround:
		air_used = false
	for z in Z:
		_zone(z, p)
	if not RIDE.is_empty():
		_ride(p)

func _alive(zid: String) -> int:
	var n := 0
	for e in g.EN:
		if str(e.get("zid", "")) == zid and not e.dead:
			n += 1
	return n

func _clear(zid: String) -> void:
	var keep: Array = []
	for e in g.EN:
		if str(e.get("zid", "")) != zid:
			keep.append(e)
	g.EN.assign(keep)

func _zone(z: Dictionary, p: Dictionary) -> void:
	var a: Dictionary = z.a
	if a.done:
		return
	if not a.on:
		if z.was_on:
			# perdeu uma vida lá dentro: a zona recomeça da primeira onda
			z.was_on = false
			z.wi = -1
			_clear(z.id)
		return
	if not z.was_on:
		z.was_on = true
		z.wi = -1
		z.wt = 34
	if z.wt > 0:
		z.wt -= 1
		if z.wt == 0:
			z.wi += 1
			if z.wi >= z.waves.size():
				z.boss.dead = 1      # acabou: as grades sobem
				bonus += 1
				_txt(p.x + p.w / 2, p.y - 40, "ZONA LIMPA!", Color(.5, 1, .7), 26.0)
				Audio.play("special", -6)
			else:
				_spawn_wave(z, z.waves[z.wi])
		return
	if _alive(z.id) == 0:
		z.wt = 40

func _spawn_wave(z: Dictionary, wave: Array) -> void:
	var a: Dictionary = z.a
	var n := 0
	for sp in wave:
		var k: String = str(sp.k)
		var side: int = int(sp.get("side", 1 if n % 2 == 0 else -1))
		var x: float = float(sp.x) if sp.has("x") else ((a.x1 - 46.0 - n * 22.0) if side > 0 else (a.x0 + 46.0 + n * 22.0))
		var e := mk(k, x, z.y, [a.x0 + 30.0, a.x1 - 30.0], sp)
		e.zid = z.id
		e.dir = -side
		g.EN.append(e)
		g.burst(x, e.y - 40, 10, Color(.55, .45, .7))
		g.fx("fx_dust", x, z.y - 8, 20, .2)
		n += 1
	Audio.play("clanc", -8, 1.2)

## monta um capanga novo no meio da fase (os mesmos campos que o load_level dá)
func mk(k: String, x: float, gy: float, r: Array, sp: Dictionary = {}) -> Dictionary:
	var e := {"k": k, "x": x, "y": gy, "r": r, "dir": -1, "dead": 0, "base": gy, "stun": 0, "leap": 0, "x0": x, "sx": x}
	if sp.has("cy"):
		e.cy = float(sp.cy)
		e.y = float(sp.cy)
		e.base = float(sp.cy)
	if k == "grunt":
		e.nocontact = 1
		e.gs = "in"
		e.t = 20 + randi() % 20
		e.sc = float(sp.get("sc", 1.0))
		e.hp = int(sp.get("hp", 1))
		e.spd = float(sp.get("spd", 2.0)) * randf_range(.9, 1.1)
		e.slot = randf_range(-1.0, 1.0)
		e.wd = 0.0
	if k == "boar":
		e.hp = 3
	for kk in ["radio"]:
		if sp.has(kk):
			e[kk] = sp[kk]
	return e

# ------------------------------------------------------------------ bondinho
func _ride(p: Dictionary) -> void:
	var mv: Dictionary = RIDE.mv
	var half: float = float(mv.get("per", 1200)) * .5
	match int(RIDE.st):
		0:
			mv.hold = true
			mv.t = 0.0
			if g.MV.on_plat(mv) and p.dyingT == 0:
				RIDE.st = 1
				RIDE.fired = {}
				Audio.play("door", -4, .7)
				_txt(p.x + p.w / 2, p.y - 46, "SEGURE-SE!", Color(1, .9, .5), 24.0)
		1:
			mv.hold = false
			var u: float = float(mv.t) / half
			var s: Dictionary = mv.plats[0]
			var i := 0
			for sp in RIDE.spawns:
				if u >= float(sp[0]) and not RIDE.fired.has(i):
					RIDE.fired[i] = 1
					for q in sp[1]:
						var x: float = s.x + s.w / 2 + float(q.dx)
						var e := mk(str(q.k), x, float(q.cy), [float(RIDE.x0), float(RIDE.x1)], q)
						e.zid = "ride"
						e.y = float(q.cy) - 260.0     # entra por cima da tela
						g.EN.append(e)
					Audio.play("robo_bip", -8, 1.3)
				i += 1
			if float(mv.t) >= half:
				mv.t = half
				mv.hold = true
				RIDE.st = 2
				bonus += 1
			# caiu ou perdeu a vida: o bondinho volta e o passeio recomeça
			if p.dyingT > 0 or p.y > 700:
				RIDE.st = 0
				_clear("ride")
		2:
			mv.hold = true

# ------------------------------------------------------------------ dash
## chamado pela luta (Mech._fight) quando o botão de defesa é apertado no modo ação
func dash(p: Dictionary, m) -> void:
	if dash_cd > 0 or dash_t > 0 or (not p.onGround and air_used):
		return
	var dir: int = 1 if g.kd("R") else (-1 if g.kd("L") else int(p.face))
	dash_dir = dir
	dash_t = DASH_N
	dash_cd = DASH_CD
	perfect_ok = true
	if not p.onGround:
		air_used = true
	p.face = dir
	p.iframe = max(int(p.iframe), DASH_N + 5)
	p.wlock = DASH_N
	p.act = "dodge"
	p.actT = DASH_N
	# cancela o golpe em andamento (o Milis nunca fica preso numa animação)
	m.swing_t = 0
	m.kick_t = 0
	Audio.play("slide", -5, 1.35)

func dash_step(p: Dictionary) -> void:
	if dash_t <= 0:
		return
	dash_t -= 1
	g.move_x(dash_dir * (9.0 if dash_t > 2 else 4.0))
	p.vx = dash_dir * 3.2
	p.vy = min(float(p.vy), 0.0) * .4      # no ar: segue reto, sem cair
	# rastro: fantasmas claros atrás
	if dash_t % 2 == 0:
		g.PARTS.append({"x": p.x + p.w / 2 - dash_dir * 14, "y": p.y + p.h * .5, "vx": -dash_dir * 1.2, "vy": 0.0, "life": 12, "col": Color(.7, .95, 1, .8)})
		g.PARTS.append({"x": p.x + p.w / 2 - dash_dir * 6, "y": p.y + p.h * .25, "vx": -dash_dir * .8, "vy": 0.0, "life": 10, "col": Color(1, 1, 1, .7)})

## um ataque ia acertar o Milis no meio do dash? esquiva perfeita (uma por dash)
func try_perfect() -> bool:
	if dash_t <= 0 and dash_cd < DASH_CD - 16:
		return false
	if not perfect_ok:
		return true
	perfect_ok = false
	perfect_n += 1
	var p: Dictionary = g.player
	g.slowmo = max(g.slowmo, 26)
	p.counterT = 80
	dash_cd = 0
	air_used = false
	add_combo(2)
	Polish.part("ringw", p.x + p.w / 2, p.y + p.h / 2, 0, 0, 22, Color(.6, .95, 1))
	_txt(p.x + p.w / 2, p.y - 44, "ESQUIVA PERFEITA!", Color(.6, .95, 1), 22.0)
	Audio.play("special", -4, 1.4)
	return true

# ------------------------------------------------------------------ combo e nota
func add_combo(n: int = 1) -> void:
	combo += n
	combo_t = COMBO_T
	best = max(best, combo)
	pop = 1.0

func mult() -> int:
	return 1 + min(4, combo / 6)

func on_hit(e: Dictionary) -> void:
	add_combo(1)

func on_ko(e: Dictionary, how: String) -> void:
	if e.get("k", "") == "zona":
		return
	kos += 1
	if how == "stomp":
		add_combo(1)
	# o combo multiplica as milhas de cada nocaute
	var n: int = mult()
	g.STATS.pen += n
	for i in n:
		g.hud_fly(e.x + randf_range(-14, 14), e.y - 50 - randf_range(0, 24), "coin")
	if n > 1:
		_txt(e.x, e.y - 96, "+%d" % n, Color(.85, .6, 1), 18.0 + n * 2.0)

func on_hurt() -> void:
	hits += 1
	if combo >= 5:
		var p: Dictionary = g.player
		_txt(p.x + p.w / 2, p.y - 40, "COMBO PERDIDO", Color(1, .5, .45), 18.0)
	combo = 0
	combo_t = 0

func secs() -> int:
	return int(ticks / float(Engine.physics_ticks_per_second))

## [letra, [dano ok, combo ok, tempo ok], [dano, combo, tempo]]
func rank() -> Array:
	var rk: Dictionary = g.L.get("rank", {})
	var oks: Array = [hits <= int(rk.get("dano", 2)), best >= int(rk.get("combo", 20)), secs() <= int(rk.get("tempo", 240))]
	var n := 0
	for o in oks:
		if o:
			n += 1
	return [["C", "B", "A", "S"][n], oks, [hits, best, secs()]]

func _txt(x: float, y: float, s: String, c: Color, size: float) -> void:
	Polish.part("txt", x, y, 0, -1.0, 54, c, {"txt": s, "g": .012, "size": size})

# ------------------------------------------------------------------ capanga de capuz
const G_H := 100.0

static func grunt_box(g, e: Dictionary) -> Dictionary:
	var sc: float = float(e.get("sc", 1.0))
	return g.R(e.x - 17 * sc, e.y - 92 * sc, 34 * sc, 92 * sc)

## true = cuidou do movimento
func grunt(e: Dictionary) -> bool:
	var p: Dictionary = g.player
	var pc: float = p.x + p.w / 2
	var dx: float = pc - e.x
	var sc: float = float(e.get("sc", 1.0))
	if not e.has("gs"):
		# capanga posto direto na fase (fora das zonas): ganha os campos agora
		e.nocontact = 1
		e.gs = "walk"
		e.sc = float(e.get("sc", 1.0))
		e.spd = float(e.get("spd", 2.0))
		e.slot = randf_range(-1.0, 1.0)
		e.wd = 0.0
		e.acd = 30
	# longe do Milis (fora das zonas): espera parado
	if not e.has("zid") and abs(dx) > 520.0 and str(e.gs) == "walk":
		return true
	e.y = e.base
	e.t = int(e.get("t", 0)) - 1
	if int(e.get("hitFx", 0)) > 0 and e.gs != "hurt":
		e.gs = "hurt"
		e.t = 16
	match str(e.gs):
		"in":
			# acabou de chegar: um instante parado (dá para ver quem entrou)
			e.dir = 1 if dx > 0 else -1
			if e.t <= 0:
				e.gs = "walk"
		"hurt":
			e.x = clamp(e.x + float(e.get("kb", 0.0)), e.r[0], e.r[1])
			e.kb = float(e.get("kb", 0.0)) * .8
			if e.t <= 0:
				e.gs = "walk"
				e.acd = 20
		"walk":
			e.dir = 1 if dx > 0 else -1
			e.acd = int(e.get("acd", 0)) - 1
			var reach: float = 50.0 * sc
			# só dois atacam por vez: os outros rodeiam um pouco mais longe, esperando a vez
			var busy: int = _attackers()
			var want: float = reach - 6.0 if (busy < 2 or abs(dx) < reach) else (96.0 + 46.0 * float(e.slot))
			var tx: float = pc - sign(dx) * want if dx != 0 else pc - want
			var step: float = clamp(tx - e.x, -float(e.spd), float(e.spd))
			if abs(tx - e.x) > 3.0:
				e.x = clamp(e.x + step, e.r[0], e.r[1])
				e.wd = float(e.wd) + abs(step)
			var lvl: bool = abs((p.y + p.h) - e.base) < 70.0
			if abs(dx) <= reach + 8.0 and lvl and int(e.acd) <= 0 and busy < 2 and p.dyingT == 0:
				e.gs = "wind"
				e.t = int(26 * (1.25 if sc > 1.1 else 1.0))
				Audio.play("robo_bip", -14, 1.6)
		"wind":
			# aviso: braços para cima e brilho vermelho — a hora de bater antes ou sair com o dash
			if e.t <= 0:
				e.gs = "strike"
				e.t = 9
				Audio.play("slide", -8, .8)
		"strike":
			if e.t > 3:
				e.x = clamp(e.x + e.dir * 6.5 * sc, e.r[0], e.r[1])
				var hb: Dictionary = g.R(e.x + (0.0 if e.dir > 0 else -44.0 * sc), e.y - 80 * sc, 44 * sc, 80 * sc)
				if Game.hit(hb, p):
					g.hurt(1, e.x - e.dir * 10.0)
			if e.t <= 0:
				e.gs = "rest"
				e.t = 34
		"rest":
			# errou o bote: fica aberto um instante
			if e.t <= 0:
				e.gs = "walk"
				e.acd = 30 + randi() % 40
	return true

func _attackers() -> int:
	var n := 0
	for o in g.EN:
		if o.k == "grunt" and not o.dead and str(o.get("gs", "")) in ["wind", "strike"]:
			n += 1
	return n

## desenho (já no lugar do capanga, virado para o lado dele; pés em 0,0)
static func grunt_draw(e: Dictionary, T: int) -> void:
	var t: Texture2D = Spr.opt("vulto")
	if t == null:
		return
	var sc0: float = float(e.get("sc", 1.0))
	var sc: float = G_H / 330.0 * sc0
	var fr: int = 10
	var lean := 0.0
	var st: String = str(e.get("gs", "walk"))
	var mod := Color(1, .86, .86) if sc0 <= 1.1 else Color(1, .7, .62)
	if e.dead:
		fr = 8
	elif st == "wind":
		fr = 8
		lean = -.1
		var k: float = .5 + .5 * sin(T * .9)
		Spr.glow(0, -70 * sc0, 46 * sc0, Color(1, .2, .15, .3 + .3 * k))
		mod = Color(1, .55 + .25 * k, .55 + .25 * k)
	elif st == "strike":
		fr = 11
		lean = .3
	elif st == "rest":
		fr = 9 if false else 12
		lean = .16
	elif st == "hurt":
		fr = 8
		lean = -.22
	else:
		fr = [10, 11, 12, 11][int(float(e.get("wd", 0.0)) / 15.0) % 4]
	if int(e.get("hitFx", 0)) > 0:
		mod = Color(3, 3, 3)
	Spr.save()
	Spr.rotate(lean)
	Spr.scale(sc, sc)
	Spr.ci.draw_texture_rect_region(t, Rect2(-280 * .54, -352, 280, 360), Rect2(fr * 280, 0, 280, 360), Color(mod.r, mod.g, mod.b, Spr.alpha))
	Spr.restore()
	if st == "wind" and not e.dead:
		Spr.text("!", 0, -118 * sc0 - 4, 26, Color(1, .3, .25), HORIZONTAL_ALIGNMENT_CENTER, Spr.font_b, 4)

# ------------------------------------------------------------------ painel do combo (HUD)
func draw_hud(W: float) -> void:
	if combo < 2:
		return
	var x: float = W - 150.0
	var y: float = 128.0
	var k: float = 1.0 + .35 * pop
	var col: Color = [Color("#ffffff"), Color("#ffe08a"), Color("#ffb040"), Color("#ff6a3a"), Color("#ff3a6a")][mult() - 1]
	Spr.text("%d" % combo, x - 6, y - 26 * k, int(44 * k), col, HORIZONTAL_ALIGNMENT_RIGHT, Spr.font_title, 6)
	Spr.text("COMBO", x + 2, y - 14, 16, col, HORIZONTAL_ALIGNMENT_LEFT, Spr.font_b, 4)
	if mult() > 1:
		Spr.text("milhas x%d" % mult(), x + 2, y + 4, 13, Color("#d9b3ff"), HORIZONTAL_ALIGNMENT_LEFT, Spr.font_b, 4)
	# tempo que resta para emendar a próxima pancada
	var u: float = float(combo_t) / COMBO_T
	Spr.rect(x - 60, y + 26, 120, 5, Color(0, 0, 0, .5))
	Spr.rect(x - 60, y + 26, 120 * u, 5, col)
