extends RefCounted
class_name Slam
## O MERGULHO (pular e apertar ↓ no ar) com funções que só ele tem:
##  - chão rachado (crack com kind "slam"): só o mergulho rompe (a picareta não dá conta)
##  - estacas: cravar a estaca no chão abre o portão preso a ela
##  - gangorra: mergulhar na ponta de cá lança a pedra da outra ponta lá no alto (derruba lápis e frutas)
##  - onda de choque: deixa tontos os bichos que estão no chão em volta (até os de capacete)
##  - sacudir a natureza: arbustos de frutas soltam as frutas (cada uma devolve um coração)
## Tudo que reage ao mergulho tem a mesma marca: uma rachadura dourada piscando de leve.

var g
var STAKES: Array = []
var SAWS: Array = []
var FRUIT: Array = []
var DROPS: Array = []      # frutas e lápis caindo / no chão
var taught := false

const WAVE_R := 150.0

func _init(game) -> void:
	g = game

func load_level() -> void:
	STAKES = []
	SAWS = []
	FRUIT = []
	DROPS = []
	var d: Dictionary = g.L.get("slam", {})
	for s in d.get("stakes", []):
		var o: Dictionary = s.duplicate(true)
		o.done = false
		o.sink = 0.0
		o.lift = 0.0
		if o.has("gate"):
			var gt: Dictionary = o.gate
			o.sol = {"t": "sgate", "x": float(gt.x), "y": float(gt.y), "w": float(gt.w), "h": float(gt.h)}
			g.SOL.append(o.sol)
		else:
			# ponte levadiça: em pé, presa pela corda da estaca; quando a estaca afunda ela cai deitada
			var br: Dictionary = o.bridge
			o.sol = {"t": "sbridge", "x": float(br.x), "y": float(br.y), "w": float(br.w), "h": 12, "oneway": 1}
		# a estaca: dá para subir em cima dela (é de lá que se crava com o mergulho)
		o.top = {"t": "stakesol", "x": float(o.x) - 11, "y": float(o.y) - 44, "w": 22, "h": 44, "oneway": 1}
		g.SOL.append(o.top)
		STAKES.append(o)
	for s in d.get("seesaw", []):
		var o2: Dictionary = s.duplicate(true)
		o2.done = false
		o2.tilt = 0.0
		o2.t = 0
		o2.rock = null
		o2.sol = {"t": "seesaw", "x": float(s.x) - float(s.w) / 2, "y": float(s.y) - 44, "w": float(s.w), "h": 10, "oneway": 1}
		g.SOL.append(o2.sol)
		SAWS.append(o2)
	for s in d.get("fruit", []):
		var o3: Dictionary = s.duplicate(true)
		o3.left = int(s.get("n", 3))
		o3.shake = 0
		FRUIT.append(o3)
	g.blockers_dirty()

# ---------------------------------------------------------------- passo
func step() -> void:
	for o in STAKES:
		if o.done:
			o.sink = min(1.0, o.sink + .12)
			if o.lift < 1.0:
				if o.has("gate"):
					o.lift = min(1.0, o.lift + .012)
					o.sol.y = float(o.gate.y) - o.lift * (float(o.gate.h) - 10)
					if o.lift >= 1.0:
						g.SOL.erase(o.sol)
						g.blockers_dirty()
				else:
					# a ponte tomba (acelerando) e bate na outra margem
					o.lift = min(1.0, o.lift + .006 + o.lift * .05)
					if o.lift >= 1.0:
						g.SOL.append(o.sol)
						g.blockers_dirty()
						g.shake = max(g.shake, 9)
						Audio.play("stomp", -2, .8)   # (não há som "crate" nem "coin": tocavam mudos; usa a pancada e o lápis)
						g.burst(float(o.bridge.x) + float(o.bridge.w), float(o.bridge.y), 14, Color("#b08a5a"))
	for s in SAWS:
		if s.t > 0:
			s.t += 1
		s.tilt = lerpf(s.tilt, (-.32 if s.done else .18) * float(s.get("dir", 1)), .25)
		var r = s.rock
		if r != null:
			r.vy += Game.GRAV
			r.x += r.vx
			r.y += r.vy
			r.a += .2
			# a pedra bate na copa lá em cima e derruba o que estava preso
			if not r.hit and r.vy > 0 and r.y < float(s.target[1]) + 30:
				r.hit = true
				_drop_items(float(s.target[0]), float(s.target[1]), s.get("items", 4), s.get("heart", 1))
				g.shake = max(g.shake, 4)
				Audio.play("stomp", -8, .9)
			if r.y > float(s.y) + 40:
				s.rock = null
	for f in FRUIT:
		if f.shake > 0:
			f.shake -= 1
	var p: Dictionary = g.player
	for d in DROPS:
		if d.got:
			continue
		if not d.land:
			d.vy = min(d.vy + .35, 8.0)
			d.y += d.vy
			d.x += d.vx
			if d.y >= d.gy:
				d.y = d.gy
				d.land = true
		if Game.hit(p, g.R(d.x - 12, d.y - 22, 24, 24)):
			d.got = true
			if d.k == "apple":
				if p.hp < Game.MAXHP:
					p.hp += 1
					g.flash("Uma fruta fresquinha! +1 coração.", 100)
					Audio.play("item", -4, 1.2)
				else:
					g.gain_coin(d.x, d.y - 10)
			else:
				g.gain_coin(d.x, d.y - 10)
	# marca de aprender: perto da primeira rachadura, ensina o mergulho uma vez
	if not taught:
		var px: float = p.x + p.w / 2
		for m in marks():
			if abs(px - m.x) < 240 and abs(p.y + p.h - m.y) < 90:
				taught = true
				g.flash_tut("Mergulho!", "MERGULHO: pule e, no ar, aperte ↓. Onde aparece esta rachadura dourada, o mergulho faz alguma coisa: quebra o chão, crava estacas, lança a gangorra, derruba frutas e deixa os bichos tontos.", 320)
				break

func _drop_items(x: float, y: float, n: int, hearts: int) -> void:
	var gy: float = _floor(x, y)
	for i in n:
		DROPS.append({"k": "pen", "x": x + (i - n / 2.0) * 16, "y": y + randf() * 10, "vx": randf_range(-1.2, 1.2), "vy": -randf() * 2.0, "gy": gy, "land": false, "got": false, "c": GameData.PEN_LIST[i % GameData.PEN_LIST.size()]})
	for i in hearts:
		DROPS.append({"k": "apple", "x": x + randf_range(-20, 20), "y": y, "vx": randf_range(-.6, .6), "vy": -1.0, "gy": gy, "land": false, "got": false})

func _floor(x: float, y: float) -> float:
	var best := 99999.0
	for s in g.SOL:
		if s.get("w", 0) > 0 and x >= s.x and x <= s.x + s.w and s.y >= y and s.y < best and not s.get("crate"):
			best = s.y
	return best if best < 99999.0 else y + 200.0

# ---------------------------------------------------------------- o mergulho bateu no chão
func on_slam(cx: float, feet: float) -> void:
	var p: Dictionary = g.player
	# 1) chão rachado embaixo dos pés
	for c in g.X.CRACKS:
		if c.get("kind") == "slam" and not g.X.broken.has(c.id) and cx > c.x - 14 and cx < c.x + c.w + 14 and abs(feet - c.y) < 10:
			g.X.break_crack(c, false)
			g.shake = max(g.shake, 12)
			g.burst(c.x + c.w / 2, c.y, 24, Color("#a07a4a"))
			Audio.play("stomp", 0.0, .75)
			if c.has("msg"):
				g.flash(c.msg, 200)
	# 2) estaca: cravou, o portão sobe
	for o in STAKES:
		if not o.done and abs(cx - float(o.x)) < 26 and abs(feet - (float(o.y) - 44)) < 12:
			o.done = true
			g.SOL.erase(o.top)
			g.blockers_dirty()
			g.shake = max(g.shake, 10)
			g.burst(float(o.x), float(o.y), 14, Color("#b08a5a"))
			Audio.play("door", -4)
			g.flash("A estaca afundou no chão: o portão se soltou!" if o.has("gate") else "A estaca afundou e soltou a corda: lá vem a ponte!", 180)
	# 3) gangorra: mergulho na ponta de cá
	for s in SAWS:
		if s.done:
			continue
		var near_x: float = float(s.x) - float(s.get("dir", 1)) * float(s.w) * .3
		if abs(cx - near_x) < float(s.w) * .3 and abs(feet - (float(s.y) - 44)) < 18:
			s.done = true
			s.t = 1
			var far_x: float = float(s.x) + float(s.get("dir", 1)) * float(s.w) * .4
			var tg: Array = s.target
			var v: Vector3 = g.TR.ballistic(Vector2(far_x, float(s.y) - 50), Vector2(float(tg[0]), float(tg[1])), 1.0) if g.TR else Vector3(0, -14, 40)
			s.rock = {"x": far_x, "y": float(s.y) - 50, "vx": v.x, "vy": v.y, "a": 0.0, "hit": false}
			g.shake = max(g.shake, 8)
			Audio.play("spring", -4)
			p.vy = -6.0
	# 4) onda de choque: bichos no chão em volta ficam tontos (até os de capacete)
	for e in g.EN:
		if e.dead or Game.FLY.has(e.k):
			continue
		if abs(e.x - cx) < WAVE_R and abs(e.y - feet) < 60:
			e.stun = max(e.stun, 170)
			e.dizzyT = 170
	# Brutus: o mergulho na argola prende a corrente
	Ep2Bosses.brutus_slam(g, cx, feet)
	# Javali-Rei atordoado: o mergulho perto dele vale uma batida extra
	if g.X and g.X.boss_active():
		var b: Dictionary = g.X.BOSS
		if b.get("skin", "") != "dog" and b.st == "stun" and b.get("bang", false) and abs(b.x - cx) < 170:
			b.bang = false
			g.X.boss_damage(true)
	# 5) sacudir a natureza: arbustos de frutas soltam as frutas
	for f in FRUIT:
		if f.left > 0 and abs(cx - float(f.x)) < 140 and abs(feet - float(f.y)) < 80:
			f.shake = 30
			var n: int = f.left
			f.left = 0
			for i in n:
				DROPS.append({"k": "apple", "x": float(f.x) + (i - 1) * 18, "y": float(f.y) - 60 - randf() * 12, "vx": randf_range(-1.0, 1.0), "vy": -2.0, "gy": float(f.y), "land": false, "got": false})
			Audio.play("stomp", -10, 1.1)
	# pingentes de gelo do teto por perto se soltam com o tranco
	if g.TR:
		for o in g.TR.T:
			if o.k == "icicle" and o.st == "idle" and o.get("grow", 1.0) >= 1.0 and abs(float(o.x) - cx) < 200 and float(o.y) < feet:
				o.st = "shake"
				o.t = 30
	# a onda: anel de poeira no chão
	g.PARTS.append({"x": cx, "y": feet - 2, "vx": 0.0, "vy": 0.0, "life": 18, "col": Color(1, .95, .8, .8), "ring": WAVE_R})

## a marca dourada (rachadura piscando) em tudo que reage ao mergulho, perto do Tomé
func marks() -> Array:
	var out: Array = []
	for c in g.X.CRACKS:
		if c.get("kind") == "slam" and not g.X.broken.has(c.id):
			out.append(Vector2(c.x + c.w / 2, c.y))
	for o in STAKES:
		if not o.done:
			out.append(Vector2(float(o.x), float(o.y) - 34))
	for s in SAWS:
		if not s.done:
			out.append(Vector2(float(s.x) - float(s.get("dir", 1)) * float(s.w) * .3, float(s.y) - 40))
	for f in FRUIT:
		if f.left > 0:
			out.append(Vector2(float(f.x), float(f.y)))
	return out

# ---------------------------------------------------------------- salvar
func save_data() -> Dictionary:
	var st: Array = []
	for o in STAKES:
		st.append(o.done)
	var sw: Array = []
	for s in SAWS:
		sw.append(s.done)
	var fr: Array = []
	for f in FRUIT:
		fr.append(f.left)
	return {"st": st, "sw": sw, "fr": fr, "taught": taught}

func restore(d: Dictionary) -> void:
	var st: Array = d.get("st", [])
	for i in min(st.size(), STAKES.size()):
		if st[i]:
			STAKES[i].done = true
			STAKES[i].sink = 1.0
			STAKES[i].lift = 1.0
			g.SOL.erase(STAKES[i].top)
			if STAKES[i].has("gate"):
				g.SOL.erase(STAKES[i].sol)
			elif not g.SOL.has(STAKES[i].sol):
				g.SOL.append(STAKES[i].sol)
	var sw: Array = d.get("sw", [])
	for i in min(sw.size(), SAWS.size()):
		SAWS[i].done = sw[i]
	var fr: Array = d.get("fr", [])
	for i in min(fr.size(), FRUIT.size()):
		FRUIT[i].left = fr[i]
	taught = d.get("taught", false)
	g.blockers_dirty()

# ---------------------------------------------------------------- desenho (camada do mundo)
func draw(T: int) -> void:
	var c0: float = g.cam - 200
	var c1: float = g.cam + g.W + 200
	for o in STAKES:
		var ox: float = float(o.x)
		if ox < c0 or ox > c1:
			continue
		var sy: float = float(o.y) - 44 + o.sink * 30
		if o.has("gate"):
			var gt: Dictionary = o.gate
			# portão de tábuas preso entre batentes; corda da estaca até o alto do portão
			var gy: float = float(gt.y) - o.lift * (float(gt.h) - 10)
			Spr.PR("stake", float(gt.x) - 13, float(gt.y) - 14, 12, float(gt.h) + 22, Color(.8, .76, .72))
			Spr.PR("stake", float(gt.x) + float(gt.w) + 1, float(gt.y) - 14, 12, float(gt.h) + 22, Color(.8, .76, .72), true)
			Spr.PR("gate_wood", float(gt.x) - 6, gy - 4, float(gt.w) + 12, float(gt.h) + 4)
			if not o.done:
				Spr.seg(ox + 4, sy + 6, float(gt.x) - 4, gy + 14, Color("#a8875a"), 2.5)
		else:
			var br: Dictionary = o.bridge
			var bx0: float = float(br.x)
			var bw: float = float(br.w)
			var byy: float = float(br.y)
			# ponte em pé (dobradiça na margem de cá) tombando até deitar na outra margem
			var ang: float = -PI / 2 * (1.0 - o.lift * o.lift)
			Spr.PR("stake", bx0 - 14, byy - 30, 16, 40, Color(.8, .76, .72))
			Spr.save()
			Spr.translate(bx0, byy - 4)
			Spr.rotate(ang)
			Spr.PR("seesaw_plank", 0, -8, bw, 18)
			Spr.restore()
			if not o.done:
				var tip := Vector2(bx0, byy - 4) + Vector2(cos(ang), sin(ang)) * bw
				Spr.seg(ox + 4, sy + 6, tip.x, tip.y, Color("#a8875a"), 2.5)
		# estaca grossa com a faixa vermelha, fincada no chão
		Spr.save()
		Spr.translate(0, 0)
		Spr.PR("stake", ox - 11, sy, 22, 58 - o.sink * 30)
		Spr.restore()
		Spr.ellipse(ox, float(o.y) + 1, 16, 3, Color(0, 0, 0, .3))
	for s in SAWS:
		var sx: float = float(s.x)
		if sx < c0 or sx > c1:
			continue
		var sy2: float = float(s.y)
		var w: float = float(s.w)
		Spr.ellipse(sx, sy2 + 1, 30, 4, Color(0, 0, 0, .3))
		Spr.PR("seesaw_rock", sx - 26, sy2 - 34, 52, 36)
		Spr.save()
		Spr.translate(sx, sy2 - 32)
		Spr.rotate(s.tilt)
		Spr.PR("seesaw_plank", -w / 2, -12, w, 16)
		var dir: float = float(s.get("dir", 1))
		if not s.done:
			Spr.P("rock0", dir * w * .4, -10, 34)
		Spr.restore()
		if s.rock != null:
			Spr.save()
			Spr.translate(s.rock.x, s.rock.y)
			Spr.rotate(s.rock.a)
			Spr.P("rock0", 0, 16, 34)
			Spr.restore()
	for f in FRUIT:
		var fx: float = float(f.x)
		if fx < c0 or fx > c1:
			continue
		var fy: float = float(f.y)
		var sh: float = sin(T * 1.3) * 3.0 if f.shake > 0 else 0.0
		Spr.save()
		Spr.translate(sh, 0)
		Spr.AB("o_bush", fx - 70, fy - 96, 140, 98)
		for i in f.left:
			Spr.P("apple", fx - 26 + i * 26, fy - 50 + (i % 2) * 14, 16)
		Spr.restore()
	for d in DROPS:
		if d.got or d.x < c0 or d.x > c1:
			continue
		if d.k == "apple":
			Spr.P("apple", d.x, d.y + 1, 18)
		else:
			if Spr.has("pen_" + d.c):
				Spr.A("pen_" + d.c, d.x, d.y - 8, .5)
			else:
				Spr.circle(d.x, d.y - 6, 4, Color(1, .8, .3))
	# marca dourada: só perto do Tomé, piscando devagar
	var p: Dictionary = g.player
	var pcx: float = p.x + p.w / 2
	for m in marks():
		if abs(m.x - pcx) > 420 or m.x < c0 or m.x > c1:
			continue
		var a: float = .45 + .35 * sin(T * .08 + m.x)
		Spr.glow(m.x, m.y - 4, 22, Color(1, .82, .35, a * .5))
		var pts := PackedVector2Array([Vector2(m.x - 10, m.y - 2), Vector2(m.x - 3, m.y - 9), Vector2(m.x + 1, m.y - 3), Vector2(m.x + 7, m.y - 11), Vector2(m.x + 11, m.y - 4)])
		Spr.ci.draw_polyline(pts, Color(1, .88, .45, a), 2.2, true)
		Spr.ci.draw_polyline(PackedVector2Array([Vector2(m.x + 1, m.y - 3), Vector2(m.x + 2, m.y + 3)]), Color(1, .88, .45, a), 1.6, true)
