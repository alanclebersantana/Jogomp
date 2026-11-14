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
	_props_load()
	SH = []
	SMOKE = []
	sp = 0
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
	_shots(p)
	_props(p)
	_bodies()
	sp_fx = max(0, sp_fx - 1)
	word_t = max(0, word_t - 1)
	var kf: Array = []
	for f in FX:
		f.t += 1
		if f.t < int(f.n):
			kf.append(f)
	FX = kf
	how = "hit"
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
			SH = []
			SMOKE = []
			_props_reset(float(z.a.x0), float(z.a.x1))
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
		if z.wi == z.waves.size() - 1:
			# último capanga da zona: um instante de câmera lenta
			g.slowmo = max(g.slowmo, 38)
			Polish.flash_white = max(Polish.flash_white, 4)

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
	if sp.has("y"):
		e.y = float(sp.y)
		e.base = float(sp.y)
	if sp.has("r"):
		e.r = [float(sp.r[0]), float(sp.r[1])]
	if k == "grunt":
		for kk in ["tp", "sc", "hp", "spd"]:
			if sp.has(kk):
				e[kk] = sp[kk]
		_ginit(e)
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
	sp = min(SP_MAX, sp + 2)
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
	if blocked:
		blocked = false
		FX.append({"k": "clang", "x": e.x + e.dir * 24.0, "y": e.y - 60.0, "t": 0, "n": 10, "r": randf() * TAU})
		return
	add_combo(1)
	sp = min(SP_MAX, sp + 1)
	# estrela de impacto desenhada (maior nos golpes fortes) e um tranco na câmera
	var forte: bool = how in ["spin", "kick", "sweep", "special"]
	FX.append({"k": "star", "x": e.x, "y": e.y - 58.0 * float(e.get("sc", 1.0)), "t": 0, "n": 12 if forte else 9, "r": randf() * TAU, "s": 1.5 if forte else 1.0})
	g.shake = max(g.shake, 5 if forte else 2)
	if combo in [5, 10, 20, 30, 50]:
		var w: String = {5: "BOA!", 10: "ÓTIMO!", 20: "INCRÍVEL!", 30: "IMPARÁVEL!", 50: "LENDÁRIO!"}[combo]
		word = w
		word_t = 70

func on_ko(e: Dictionary, how: String) -> void:
	if e.get("k", "") == "zona":
		return
	kos += 1
	if how == "stomp":
		add_combo(1)
	FX.append({"k": "ring", "x": e.x, "y": e.y - 50.0, "t": 0, "n": 14, "r": 0.0})
	g.shake = max(g.shake, 4)
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

# ------------------------------------------------------------------ capangas de capuz (cinco papéis)
const G_H := 100.0
## papel -> vida, tamanho, passo, cor (o desenho é o mesmo capuz até as folhas novas chegarem)
const TP := {
	"": {"hp": 1, "sc": 1.0, "spd": 2.0, "mod": Color(1, .86, .86)},
	"escudo": {"hp": 2, "sc": 1.06, "spd": 1.6, "mod": Color(.85, 1.05, 1.5)},    # só apanha pelas costas, ou depois do giro/rasteira
	"atira": {"hp": 1, "sc": .95, "spd": 1.9, "mod": Color(1.5, 1.15, .7)},       # fica longe e arremessa malas em arco
	"salta": {"hp": 1, "sc": .86, "spd": 3.1, "mod": Color(.8, 1.5, 1.3)},        # rápido: pula por cima e ataca pelas costas
	"agarra": {"hp": 4, "sc": 1.34, "spd": 1.3, "mod": Color(1.5, .7, .6)},       # grandão: não sente os golpes fracos e arremessa o Milis
}
var how := "hit"        # o golpe que está acertando agora (a luta avisa antes de cada pancada)
var blocked := false
var SH: Array = []      # malas arremessadas
var PR: Array = []      # objetos do cenário que viram arma
var SMOKE: Array = []
var FX: Array = []      # estrelas de impacto, faíscas do escudo, poeira
var word := ""
var word_t := 0
var sp := 0             # barra do golpe especial
var sp_fx := 0
const SP_MAX := 12

static func grunt_box(g, e: Dictionary) -> Dictionary:
	var sc: float = float(e.get("sc", 1.0))
	return g.R(e.x - 17 * sc, e.y - 92 * sc, 34 * sc, 92 * sc)

func _ginit(e: Dictionary) -> void:
	var tp: String = str(e.get("tp", ""))
	var d: Dictionary = TP.get(tp, TP[""])
	e.tp = tp
	e.nocontact = 1
	e.gs = "in"
	e.t = 20 + randi() % 20
	e.sc = float(e.get("sc", d.sc))
	e.hp = int(e.get("hp", d.hp))
	e.spd = float(e.get("spd", d.spd)) * randf_range(.92, 1.08)
	e.slot = randf_range(-1.0, 1.0)
	e.wd = 0.0
	e.acd = 30 + randi() % 30
	e.open = 0

## a pancada vai entrar? (true = defendeu: nada acontece com ele)
func pre_hit(e: Dictionary) -> bool:
	blocked = false
	if e.k != "grunt" or not e.has("gs"):
		return false
	var p: Dictionary = g.player
	var front: bool = sign(p.x + p.w / 2 - e.x) == sign(float(e.dir))
	if str(e.tp) == "escudo" and int(e.open) <= 0 and front and str(e.gs) in ["in", "walk", "wind"] and not how in ["special", "prop", "stomp"]:
		blocked = true
		e.blockFx = 10
		if how in ["spin", "sweep"]:
			# giro ou rasteira: quebra a defesa (fica aberto um tempo)
			e.open = 110
			e.gs = "rest"
			e.t = 80
			_txt(e.x, e.y - 110, "DEFESA QUEBRADA!", Color(.6, .9, 1), 18.0)
			Audio.play("clanc", -4, .8)
			g.shake = max(g.shake, 4)
		else:
			Audio.play("clanc", -6, 1.5)
			p.vx = -sign(float(e.dir)) * -2.0
			g.burst(e.x + e.dir * 22, e.y - 56, 6, Color(.8, .95, 1))
		return true
	return false

func grunt(e: Dictionary) -> bool:
	var p: Dictionary = g.player
	var pc: float = p.x + p.w / 2
	var dx: float = pc - e.x
	if not e.has("gs"):
		_ginit(e)
		e.gs = "walk"
	var sc: float = float(e.sc)
	var tp: String = str(e.tp)
	# longe do Milis (fora das zonas): espera parado
	if not e.has("zid") and abs(dx) > 520.0 and str(e.gs) == "walk":
		return true
	if str(e.gs) != "leap":
		e.y = e.base
	e.t = int(e.get("t", 0)) - 1
	e.open = max(0, int(e.open) - 1)
	e.blockFx = max(0, int(e.get("blockFx", 0)) - 1)
	# levou pancada: o grandão não sente (só o giro, o especial ou um objeto o param)
	if int(e.get("hitFx", 0)) > 0 and e.gs != "hurt" and (tp != "agarra" or how in ["spin", "special", "prop"]):
		e.gs = "hurt"
		e.t = 16
	var lvl: bool = abs((p.y + p.h) - e.base) < 70.0
	match str(e.gs):
		"in":
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
			e.acd = int(e.acd) - 1
			var reach: float = 50.0 * sc
			var busy: int = _attackers()
			var want: float
			if tp == "atira":
				want = 300.0 + 40.0 * float(e.slot)      # mantém distância
			elif busy < 2 or abs(dx) < reach:
				want = reach - 6.0
			else:
				want = 96.0 + 46.0 * float(e.slot)       # espera a vez um pouco mais longe
			var sgn: float = sign(dx) if dx != 0 else 1.0
			var tx: float = clamp(pc - sgn * want, e.r[0], e.r[1])
			var step: float = clamp(tx - e.x, -float(e.spd), float(e.spd))
			if abs(tx - e.x) > 3.0:
				e.x += step
				e.wd = float(e.wd) + abs(step)
			if p.dyingT > 0 or int(e.acd) > 0:
				pass
			elif tp == "atira":
				if abs(dx) < 620.0:
					e.gs = "wind"
					e.t = 34
			elif tp == "salta" and lvl and abs(dx) > 110.0 and abs(dx) < 260.0:
				# pula por cima do Milis e cai do outro lado
				e.gs = "leap"
				e.t = 30
				e.lx0 = e.x
				e.lx1 = clamp(pc + sgn * 74.0, e.r[0], e.r[1])
				Audio.play("slide", -10, 1.6)
			elif abs(dx) <= reach + 8.0 and lvl and busy < 2:
				e.gs = "wind"
				e.t = 38 if tp == "agarra" else (30 if tp == "escudo" else 26)
				Audio.play("robo_bip", -14, 1.6 if tp != "agarra" else .7)
		"leap":
			var u: float = 1.0 - float(e.t) / 30.0
			e.x = lerp(float(e.lx0), float(e.lx1), u)
			e.y = e.base - sin(u * PI) * 124.0
			if e.t <= 0:
				e.y = e.base
				e.dir = 1 if dx > 0 else -1
				e.gs = "wind"
				e.t = 12
				g.fx("fx_dust", e.x, e.base - 6, 16, .14)
		"wind":
			if e.t <= 0:
				if tp == "atira":
					_throw(e, p)
					e.gs = "rest"
					e.t = 30
					e.acd = 70 + randi() % 50
				else:
					e.gs = "strike"
					e.t = 12 if tp == "agarra" else 9
					Audio.play("slide", -8, .8)
		"strike":
			if e.t > 3:
				e.x = clamp(e.x + e.dir * (7.5 if tp == "agarra" else 6.5) * sc, e.r[0], e.r[1])
				var hb: Dictionary = g.R(e.x + (0.0 if e.dir > 0 else -44.0 * sc), e.y - 80 * sc, 44 * sc, 80 * sc)
				if Game.hit(hb, p):
					var hp0: int = p.hp
					g.hurt(1, e.x - e.dir * 10.0)
					if tp == "agarra" and p.hp < hp0:
						# o grandão pega e arremessa
						p.vx = e.dir * 10.0
						p.vy = -8.5
						p.onGround = false
						g.shake = max(g.shake, 7)
			if e.t <= 0:
				e.gs = "rest"
				e.t = 46 if tp == "agarra" else 34
		"rest":
			# errou o bote (ou está tossindo na fumaça): fica aberto
			if e.t <= 0:
				e.gs = "walk"
				e.acd = 30 + randi() % 40
	return true

func _attackers() -> int:
	var n := 0
	for o in g.EN:
		if o.k == "grunt" and not o.dead and str(o.get("tp", "")) != "atira" and str(o.get("gs", "")) in ["wind", "strike"]:
			n += 1
	return n

# ------------------------------------------------------------------ malas arremessadas
func _throw(e: Dictionary, p: Dictionary) -> void:
	var T := 50.0
	var x0: float = e.x + e.dir * 14.0
	var y0: float = e.y - 96.0 * float(e.sc)
	var tx: float = p.x + p.w / 2 + float(p.vx) * 10.0
	var ty: float = p.y + p.h * .5
	SH.append({"x": x0, "y": y0, "vx": (tx - x0) / T, "vy": (ty - y0) / T - .5 * .3 * T, "back": false, "rot": 0.0, "t": 0})
	Audio.play("slide", -9, .7)

func _shots(p: Dictionary) -> void:
	var keep: Array = []
	var m = g.M
	for s in SH:
		s.t += 1
		s.x += float(s.vx)
		s.y += float(s.vy)
		s.vy = float(s.vy) + .3
		s.rot = float(s.rot) + .22 * sign(float(s.vx))
		var b: Dictionary = g.R(s.x - 14, s.y - 12, 28, 24)
		var gone := false
		if not s.back:
			# rebatida: o bastão (ou a voadora) devolve a mala
			var atk: bool = (m.swing_t > 0 and Game.hit(m.swing_box(), b)) or (m.kick_t > 0 and Game.hit(g.R(p.x - 30, p.y - 10, p.w + 60, p.h + 20), b))
			if atk:
				s.back = true
				s.vx = -float(s.vx) * 1.5
				s.vy = -5.0
				add_combo(1)
				g.hit_stop = max(int(g.hit_stop), 3)
				Audio.play("clanc", -5, 1.3)
				g.burst(s.x, s.y, 6, Color(1, .9, .6))
			elif Game.hit(b, p):
				g.hurt(1, s.x - float(s.vx))
				gone = true
		else:
			for e in g.EN:
				if not e.dead and Game.hit(b, g.ebox(e)):
					how = "prop"
					g.kill_enemy(e, "hit")
					gone = true
					break
		if g.floor_under(s.x, s.y - 30.0) <= s.y + 10.0 or s.t > 260:
			gone = true
		if gone:
			g.burst(s.x, s.y, 8, Color(.6, .45, .75))
			g.fx("fx_dust", s.x, s.y, 14, .12)
		else:
			keep.append(s)
	SH = keep

# ------------------------------------------------------------------ o cenário como arma
func _props_load() -> void:
	PR = []
	for q in g.L.get("acProps", []):
		var o: Dictionary = q.duplicate(true)
		o.x0 = float(o.x)
		o.y0 = float(o.y)
		PR.append(o)
	_props_reset(-1e9, 1e9)

func _props_reset(a: float, b: float) -> void:
	for o in PR:
		if float(o.x0) >= a and float(o.x0) <= b:
			o.x = o.x0
			o.y = o.y0
			o.vx = 0.0
			o.vy = 0.0
			o.st = 0
			o.t = 0
			o.cd = 0

func _prop_box(o: Dictionary) -> Dictionary:
	match str(o.k):
		"carrinho":
			return g.R(float(o.x) - 38, float(o.y) - 52, 76, 52)
		"extintor":
			return g.R(float(o.x) - 12, float(o.y) - 46, 24, 46)
	return g.R(float(o.x) - 60, float(o.y) - 34, 120, 44)

func _props(p: Dictionary) -> void:
	var m = g.M
	var atk := {}
	if m.swing_t > 0:
		atk = m.swing_box() if p.act != "spin" else m._spin_box()
	elif m.kick_t > 0:
		atk = g.R(p.x + p.w / 2 + (0.0 if p.face > 0 else -60.0), p.y, 60, p.h + 8)
	for o in PR:
		o.cd = max(0, int(o.cd) - 1)
		var b: Dictionary = _prop_box(o)
		var hit: bool = not atk.is_empty() and int(o.cd) == 0 and Game.hit(atk, b)
		match str(o.k):
			"carrinho":
				if hit:
					o.vx = p.face * 11.0
					o.cd = 24
					g.hit_stop = max(int(g.hit_stop), 3)
					Audio.play("stomp", -5, .8)
					g.fx("fx_dust", float(o.x), float(o.y) - 6, 18, .2)
				if abs(float(o.vx)) > .6:
					var nx: float = float(o.x) + float(o.vx)
					if g.wall_at(nx + sign(float(o.vx)) * 40.0, float(o.y) - 20.0) or (g.ARN and _gate_at(nx + sign(float(o.vx)) * 40.0)):
						o.vx = -float(o.vx) * .5
						Audio.play("clanc", -8, .7)
					else:
						o.x = nx
					o.vx = float(o.vx) * .975
					for e in g.EN:
						if not e.dead and abs(e.x - float(o.x)) < 46.0 and abs(e.y - float(o.y)) < 60.0:
							how = "prop"
							e.hp = 1 if e.k == "grunt" else int(e.get("hp", 1))
							g.kill_enemy(e, "hit")
							if e.dead:
								e.dvx = sign(float(o.vx)) * 7.0
								e.dvy = -7.0
							add_combo(1)
							o.vx = float(o.vx) * .88
			"extintor":
				if hit and int(o.st) == 0:
					o.st = 1
					o.t = 240
					SMOKE.append({"x": float(o.x), "y": float(o.y) - 40.0, "t": 240})
					Audio.play("slide", -3, .5)
					g.shake = max(g.shake, 5)
				if int(o.st) == 1:
					o.t = int(o.t) - 1
					if int(o.t) <= 0:
						o.st = 2
			"placa":
				# painel pendurado: uma pancada (pule e bata) solta os cabos e ele despenca
				if hit and int(o.st) == 0:
					o.st = 1
					o.vy = 0.0
					Audio.play("clanc", -4, .6)
				if int(o.st) == 1:
					o.vy = float(o.vy) + .6
					o.y = float(o.y) + float(o.vy)
					var fl: float = g.floor_under(float(o.x), float(o.y) - 40.0)
					if float(o.y) >= fl - 4.0:
						o.y = fl
						o.st = 2
						o.t = 200
						g.shake = max(g.shake, 10)
						Audio.play("stomp", -2, .55)
						g.burst(float(o.x), fl - 10, 16, Color(.9, .85, .7))
						g.fx("fx_dust", float(o.x) - 40, fl - 6, 22, .25)
						g.fx("fx_dust", float(o.x) + 40, fl - 6, 22, .25)
						for e in g.EN:
							if not e.dead and abs(e.x - float(o.x)) < 96.0 and abs(e.y - fl) < 80.0:
								how = "prop"
								e.hp = 1 if e.k == "grunt" else int(e.get("hp", 1))
								g.kill_enemy(e, "hit")
								add_combo(1)
				elif int(o.st) == 2:
					o.t = int(o.t) - 1
	# fumaça do extintor: quem está dentro tosse (fica aberto, sem defesa)
	var ks: Array = []
	for c in SMOKE:
		c.t -= 1
		if c.t > 0:
			ks.append(c)
			for e in g.EN:
				if e.k == "grunt" and not e.dead and e.has("gs") and abs(e.x - float(c.x)) < 170.0 and abs(e.y - float(c.y)) < 140.0:
					e.open = max(int(e.open), 20)
					if str(e.gs) in ["walk", "wind", "in"]:
						e.gs = "rest"
						e.t = 24
	SMOKE = ks

func _gate_at(x: float) -> bool:
	for a in g.ARN.A:
		if a.on and (x < float(a.x0) + 16.0 or x > float(a.x1) - 16.0):
			return true
	return false

## capanga derrubado que sai voando derruba quem estiver no caminho
func _bodies() -> void:
	for e in g.EN:
		if e.k != "grunt" or not e.dead or int(e.dead) > 26 or e.get("dk", "") != "tomba" or abs(float(e.get("dvx", 0.0))) < 5.0:
			continue
		var bx: float = e.x + float(e.get("ddx", 0.0))
		for o in g.EN:
			if o.dead or o.k != "grunt" or int(o.get("bh", 0)) > ticks:
				continue
			if abs(o.x - bx) < 34.0 and abs(o.base - e.base) < 50.0:
				o.bh = ticks + 30
				how = "prop"
				g.kill_enemy(o, "hit")
				add_combo(1)
				e.dvx = float(e.dvx) * .6

# ------------------------------------------------------------------ golpe especial
func sp_full() -> bool:
	return sp >= SP_MAX

func try_special() -> bool:
	if not sp_full() or g.player.dyingT > 0:
		return false
	var p: Dictionary = g.player
	sp = 0
	sp_fx = 30
	p.iframe = max(int(p.iframe), 40)
	p.act = "spin"
	p.actT = 26
	g.slowmo = max(g.slowmo, 20)
	Polish.flash_white = max(Polish.flash_white, 7)
	g.shake = max(g.shake, 12)
	Audio.play("special", 0, .8)
	Audio.play("stomp", -2, .6)
	var cx: float = p.x + p.w / 2
	for r in 3:
		Polish.part("ringw", cx, p.y + p.h / 2, 0, 0, 24 + r * 8, Color(1, .85, .4))
	_txt(cx, p.y - 60, "GIRO TURBO!", Color(1, .85, .4), 28.0)
	SH = []
	for e in g.EN:
		if e.dead or abs(e.x - cx) > 330.0 or abs(e.y - (p.y + p.h)) > 190.0:
			continue
		how = "special"
		if e.k == "grunt":
			e.hp = max(1, int(e.get("hp", 1)) - 2)
		for i in (2 if e.k == "boar" else 1):
			if not e.dead:
				g.kill_enemy(e, "hit")
		if e.dead and e.get("dk", "") == "tomba":
			e.dvx = sign(e.x - cx) * 10.0
			e.dvy = -9.0
		add_combo(1)
	how = "hit"
	return true

# ------------------------------------------------------------------ desenho
static func grunt_draw(e: Dictionary, T: int) -> void:
	var t: Texture2D = Spr.opt("vulto")
	if t == null:
		return
	var sc0: float = float(e.get("sc", 1.0))
	var sc: float = G_H / 330.0 * sc0
	var tp: String = str(e.get("tp", ""))
	var fr: int = 10
	var lean := 0.0
	var st: String = str(e.get("gs", "walk"))
	var mod: Color = TP.get(tp, TP[""]).mod
	if e.dead:
		fr = 8
	elif st == "wind":
		fr = 8
		lean = -.1
		var k: float = .5 + .5 * sin(T * .9)
		Spr.glow(0, -70 * sc0, 46 * sc0, Color(1, .2, .15, .3 + .3 * k))
		mod = Color(mod.r * 1.2, mod.g * (.6 + .3 * k), mod.b * (.6 + .3 * k))
	elif st == "strike":
		fr = 11
		lean = .3
	elif st == "leap":
		fr = 11
		lean = .5
	elif st == "rest":
		fr = 12
		lean = .16 + (.06 * sin(T * .5) if int(e.get("open", 0)) > 0 else 0.0)
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
	if e.dead:
		return
	if tp == "escudo":
		# escudo de choque na frente (abaixa quando a defesa quebra)
		var down: bool = int(e.get("open", 0)) > 0 or st in ["rest", "hurt"]
		var sy: float = -40.0 * sc0 if down else -74.0 * sc0
		var bf: float = float(e.get("blockFx", 0)) / 10.0
		Spr.save()
		Spr.translate(24 * sc0 - bf * 4.0, sy)
		Spr.rotate(.5 if down else .06)
		Spr.rr(-10, -6, 20, 68 * sc0, 7, Color("#1c1418"))
		Spr.rr(-7, -3, 14, 62 * sc0, 5, Color(.55 + bf * .45, .8 + bf * .2, 1, .92))
		Spr.rect(-5, 6, 10, 12, Color(.9, .97, 1, .7))
		Spr.restore()
	elif tp == "atira" and st == "wind":
		Spr.save()
		Spr.translate(-6, -112 * sc0)
		Spr.rotate(sin(T * .4) * .15)
		Spr.rr(-15, -13, 30, 26, 5, Color("#1c1418"))
		Spr.rr(-12, -10, 24, 20, 4, Color("#8a5bb5"))
		Spr.rect(-12, -2, 24, 3, Color("#f2c94c"))
		Spr.restore()
	elif tp == "agarra":
		Spr.glow(6, -84 * sc0, 9, Color(1, .25, .2, .8))
	if st == "wind":
		Spr.text("!", 0, -118 * sc0 - 4, 26, Color(1, .3, .25), HORIZONTAL_ALIGNMENT_CENTER, Spr.font_b, 4)

## efeitos de impacto por cima de tudo (camada de brilho): estrela com traço de tinta, faíscas e anel
func draw_fx(T: int) -> void:
	for f in FX:
		var u: float = float(f.t) / float(f.n)
		var x: float = float(f.x)
		var y: float = float(f.y)
		match str(f.k):
			"star":
				var s: float = float(f.get("s", 1.0)) * (18.0 + 30.0 * (1.0 - pow(1.0 - u, 3.0)))
				var al: float = 1.0 - u * u
				var pts := PackedVector2Array()
				var pin := PackedVector2Array()
				for i in 14:
					var a: float = float(f.r) + i * TAU / 14.0
					var rr: float = s * (1.0 if i % 2 == 0 else .42)
					pts.append(Vector2(x + cos(a) * (rr + 4.0), y + sin(a) * (rr + 4.0)))
					pin.append(Vector2(x + cos(a) * rr, y + sin(a) * rr))
				Spr.poly(pts, Color(.11, .08, .1, al))
				Spr.poly(pin, Color(1, .93, .55, al))
				var pc := PackedVector2Array()
				for i in 14:
					var a2: float = float(f.r) + i * TAU / 14.0
					var r2: float = s * .5 * (1.0 if i % 2 == 0 else .42)
					pc.append(Vector2(x + cos(a2) * r2, y + sin(a2) * r2))
				Spr.poly(pc, Color(1, 1, 1, al))
			"clang":
				for i in 5:
					var a3: float = float(f.r) + i * 1.25
					var d0: float = 8.0 + 26.0 * u
					Spr.seg(x + cos(a3) * d0, y + sin(a3) * d0, x + cos(a3) * (d0 + 12.0), y + sin(a3) * (d0 + 12.0), Color(.75, .95, 1, 1.0 - u), 3.0)
			"ring":
				Spr.ring(x, y, 14.0 + 60.0 * u, Color(1, 1, 1, .8 * (1.0 - u)), 5.0 * (1.0 - u) + 1.0)

## malas no ar, objetos do cenário e fumaça (na camada do mundo, em coordenadas do mundo)
func draw_world(T: int) -> void:
	for o in PR:
		var x: float = float(o.x)
		var y: float = float(o.y)
		if x < g.cam - 200 or x > g.cam + g.W + 200:
			continue
		match str(o.k):
			"carrinho":
				Spr.P("pc_carrinhos", x, y + 2, 92.0)
				if abs(float(o.vx)) > 1.0:
					Spr.rect(x - sign(float(o.vx)) * 70 - 20, y - 30, 40, 2, Color(1, 1, 1, .5))
					Spr.rect(x - sign(float(o.vx)) * 80 - 14, y - 16, 28, 2, Color(1, 1, 1, .4))
			"extintor":
				if int(o.st) == 0:
					Spr.rr(x - 11, y - 46, 22, 46, 6, Color("#1c1418"))
					Spr.rr(x - 8, y - 42, 16, 40, 5, Color("#d8342c"))
					Spr.rect(x - 8, y - 30, 16, 8, Color("#f4efe2"))
					Spr.rect(x - 4, y - 52, 8, 8, Color("#1c1418"))
					Spr.rect(x + 2, y - 50, 12, 3, Color("#1c1418"))
					Spr.rect(x - 5, y - 40, 3, 22, Color(1, 1, 1, .35))
			"placa":
				if int(o.st) == 2 and int(o.t) <= 0:
					continue
				var al: float = 1.0 if int(o.st) < 2 else clamp(float(o.t) / 40.0, 0.0, 1.0)
				var yy: float = y - (0.0 if int(o.st) < 2 else 0.0)
				if int(o.st) == 0:
					Spr.rect(x - 46, yy - 240, 2, 210, Color("#3a3038"))
					Spr.rect(x + 44, yy - 240, 2, 210, Color("#3a3038"))
				Spr.rr(x - 64, yy - 38, 128, 46, 6, Color(.11, .08, .1, al))
				Spr.rr(x - 60, yy - 34, 120, 38, 4, Color(.13, .16, .22, al))
				for r in 3:
					Spr.rect(x - 54, yy - 28 + r * 11, 70 - r * 12, 5, Color(1, .82, .3, al))
					Spr.rect(x + 28, yy - 28 + r * 11, 22, 5, Color(.5, .9, .6, al))
	for s in SH:
		Spr.save()
		Spr.translate(float(s.x), float(s.y))
		Spr.rotate(float(s.rot))
		Spr.rr(-15, -13, 30, 26, 5, Color("#1c1418"))
		Spr.rr(-12, -10, 24, 20, 4, Color("#8a5bb5") if not s.back else Color("#f2c94c"))
		Spr.rect(-12, -2, 24, 3, Color("#f2c94c") if not s.back else Color("#ffffff"))
		Spr.restore()
	for c in SMOKE:
		var k: float = clamp(float(c.t) / 40.0, 0.0, 1.0) * clamp((240.0 - float(c.t)) / 14.0, 0.0, 1.0)
		for i in 9:
			var a: float = i * .7 + T * .012 * (1 if i % 2 == 0 else -1)
			var r: float = 60.0 + 40.0 * sin(i * 1.9)
			Spr.glow(float(c.x) + cos(a) * r * 1.5, float(c.y) + sin(a * 1.3) * 42.0 - 10, 74.0 + 14.0 * sin(T * .05 + i), Color(.93, .95, .97, .5 * k))

# ------------------------------------------------------------------ painel do combo (HUD)
func draw_hud(W: float) -> void:

	# barra do golpe especial (embaixo, no centro): cheia = o botão de chute aparece para soltar
	var bw := 150.0
	var bx: float = W * .5 - bw / 2
	var by := 22.0
	var fu: float = float(sp) / SP_MAX
	Spr.rr(bx - 3, by - 3, bw + 6, 14, 6, Color(0, 0, 0, .55))
	var fc: Color = Color("#ffd76a") if not sp_full() else Color(1, .55 + .35 * sin(ticks * .3), .25)
	Spr.rr(bx, by, max(8.0, bw * fu), 8, 4, fc)
	if sp_full():
		Spr.text("ESPECIAL PRONTO!", W * .5, by + 12, 13, fc, HORIZONTAL_ALIGNMENT_CENTER, Spr.font_b, 4)
	if word_t > 0:
		var wk: float = 1.0 + .5 * clamp((float(word_t) - 60.0) / 10.0, 0.0, 1.0)
		var wa: float = clamp(float(word_t) / 14.0, 0.0, 1.0)
		Spr.text(word, W * .5, 120, int(40 * wk), Color(1, .86, .3, wa), HORIZONTAL_ALIGNMENT_CENTER, Spr.font_title, 7)
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
