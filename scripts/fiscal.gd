class_name FiscalBoss
extends RefCounted
## Mini-chefe da 1-1: o FISCAL FALSO, capanga do Barão disfarçado de agente de segurança.
## Fica na cabine de controle (alto, à direita da arena) e liga os lasers do raio-X em padrões:
##   rasteiro  laser no rodapé (pule)          alto   laser na altura do peito (abaixe ↓)
##   grade     feixes verticais com vãos (fique num vão)
## Depois de cada rodada, o painel de energia (à esquerda) abre e pisca: um golpe de bastão
## dá curto na cabine, o Fiscal cai tonto no chão e aí é só pisar na cabeça dele (ou bater).
## 3 vidas. As rodadas ficam mais rápidas a cada vida perdida.

const GY := 500.0


static func setup(b: Dictionary, _L: Dictionary) -> void:
	b.cab_x = float(b.x1) - 120.0          # centro da cabine
	b.cab_y = 330.0                        # chão da cabine
	b.pan_x = float(b.x0) + 70.0           # painel de energia
	b.pan_y = 430.0
	b.beams = []
	b.round = 0
	b.queue = []
	b.panel = 0
	b.zap = 0
	b.x = b.cab_x
	b.y = b.cab_y


static func box(g, b: Dictionary) -> Dictionary:
	return g.R(b.x - 22, b.y - 76, 44, 76)


static func _pattern_list(hp: int) -> Array:
	match hp:
		3:
			return ["rasteiro", "alto", "rasteiro", "grade"]
		2:
			return ["grade", "rasteiro", "alto", "grade", "rasteiro"]
		_:
			return ["alto", "rasteiro", "grade", "alto", "grade", "rasteiro"]


static func _speed(b: Dictionary) -> float:
	return 1.0 + (int(b.maxhp) - int(b.hp)) * 0.22


## começa a próxima rajada de laser
static func _next_beam(g, b: Dictionary) -> void:
	if b.queue.is_empty():
		b.st = "painel"
		b.t = 0
		b.panel = 1
		Audio.play("unlock", -4)
		g.flash("O painel de energia abriu! Acerte com o bastão (botão do bastão).", 170)
		return
	var k: String = b.queue.pop_front()
	var sp: float = _speed(b)
	var warn := int(56.0 / sp)
	var on := 34
	var beams: Array = []
	match k:
		"rasteiro":
			beams.append({"k": "h", "y": GY - 7, "h": 7})
			on = 22
		"alto":
			beams.append({"k": "h", "y": GY - 30, "h": 9})
		"grade":
			# feixes verticais a cada ~110 px, com dois vãos sorteados
			var x: float = float(b.x0) + 70.0
			var lista: Array = []
			while x < float(b.x1) - 190.0:
				lista.append(x)
				x += 104.0
			var vaos := {}
			var n: int = lista.size()
			if n > 2:
				vaos[randi() % n] = true
				vaos[(randi() % (n - 1) + n / 2) % n] = true
			for i in n:
				if not vaos.has(i):
					beams.append({"k": "v", "x": lista[i], "w": 12})
			on = 46
			warn = int(84.0 / sp)
	b.beams = beams
	b.beam_k = k
	b.warn = warn
	b.on = on
	b.bt = 0
	Audio.play("slide", -10, 1.6)


static func step(g, X) -> void:
	var b: Dictionary = X.BOSS
	var p: Dictionary = g.player
	b.t += 1
	if b.red > 0:
		b.red -= 1
	if b.get("hitT", 0) > 0:
		b.hitT -= 1
	match b.st:
		"idle":
			# acabou a apresentação: começa a primeira rodada
			b.st = "lasers"
			b.t = 0
			b.queue = _pattern_list(int(b.hp))
			_next_beam(g, b)
		"lasers":
			b.bt += 1
			if b.bt == b.warn:
				Audio.play("fire", -10, 1.8)
				g.shake = max(g.shake, 3)
			if b.bt >= b.warn and b.bt < b.warn + b.on and p.dyingT == 0:
				for bm in b.beams:
					if Game.hit(p, beam_rect(b, bm)):
						g.hurt(1, p.x + p.w / 2 + 1)
			if b.bt > b.warn + b.on + 14:
				b.beams = []
				_next_beam(g, b)
		"painel":
			# o painel fica aberto um tempo; se ninguém acertar, fecha e vem outra rodada
			if b.t > 420:
				b.panel = 0
				b.st = "lasers"
				b.t = 0
				b.queue = _pattern_list(int(b.hp))
				g.tip("O painel fechou. Desvie dos lasers e acerte o painel quando ele abrir de novo!", 180)
				_next_beam(g, b)
		"curto":
			# faíscas na cabine; o Fiscal despenca
			if b.t > 40:
				b.st = "cai"
				b.t = 0
				b.vy = -4.0
				b.vx = -2.6
		"cai":
			b.vy += .45
			b.x += b.vx
			b.y = minf(GY, b.y + b.vy)
			if b.y >= GY:
				b.st = "tonto"
				b.t = 0
				g.shake = 10
				Audio.play("stomp")
				g.burst(b.x, GY, 16, Color("#cdbfa6"))
				g.flash("Ele caiu tonto! Pule na cabeça dele ou use o bastão!", 140)
		"tonto":
			if b.t > 260:
				b.st = "volta"
				b.t = 0
		"volta":
			# corre de volta para a escadinha da cabine e sobe
			var alvo: float = float(b.cab_x)
			b.dir = 1 if alvo > b.x else -1
			b.x += b.dir * 3.2
			if absf(b.x - alvo) < 4.0:
				b.y = b.cab_y
				b.st = "lasers"
				b.t = 0
				b.queue = _pattern_list(int(b.hp))
				_next_beam(g, b)
		"down":
			if b.t > 150:
				b.done = true
				b.active = false
				Polish.smoke_cloud(b.x, b.y)
	# na cabine ele empurra quem chegar perto
	if b.st in ["lasers", "painel", "curto"] and p.dyingT == 0 and Game.hit(p, box(g, b)):
		g.hurt(1, b.x)
	# pisão no Fiscal tonto
	if b.st == "tonto" and p.dyingT == 0:
		var bb := box(g, b)
		if Game.hit(p, bb) and p.vy > 0.5 and (p.y + p.h) - bb.y < 30:
			p.vy = -8.5
			p.y = bb.y - p.h - 1
			_dano(g, X, b)


## golpe de bastão: no painel aberto (curto na cabine) ou no Fiscal tonto
static func swing(g, X, hb: Dictionary) -> void:
	var b: Dictionary = X.BOSS
	if b.is_empty() or b.get("skin", "") != "fiscal" or not b.active or b.done:
		return
	if b.st == "painel" and Game.hit(hb, g.R(b.pan_x - 26, b.pan_y - 40, 52, 70)):
		b.panel = 2
		b.st = "curto"
		b.t = 0
		b.zap = 40
		g.shake = 12
		Audio.play("thunder", -6)
		Audio.vib(90)
		g.burst(b.pan_x, b.pan_y, 18, Color("#ffe066"))
		g.burst(b.cab_x, b.cab_y - 40, 24, Color("#9ad7ff"))
	elif b.st == "tonto" and Game.hit(hb, box(g, b)) and b.get("hitT", 0) == 0:
		b.hitT = 20
		_dano(g, X, b)


static func _dano(g, X, b: Dictionary) -> void:
	b.hp -= 1
	b.red = 30
	Audio.play("roar", -8)
	g.hit_stop = 5
	if b.hp <= 0:
		b.st = "down"
		b.t = 0
		b.beams = []
		b.panel = 0
		Polish.final_blow()
		Polish.loot_arc(b.x, b.y - 60, 12, GY)
		X._gate_on(false)
		g.flash("O Fiscal Falso foi desmascarado! Os lasers desligaram e as milhas voltaram.", 260)
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
	else:
		b.st = "volta"
		b.t = 0
		g.flash("Isso! Falta%s %d." % ["m" if b.hp > 1 else "", b.hp], 120)


static func beam_rect(b: Dictionary, bm: Dictionary) -> Dictionary:
	if bm.k == "h":
		return {"x": float(b.x0), "y": float(bm.y), "w": float(b.x1) - float(b.x0) - 190.0, "h": float(bm.h)}
	return {"x": float(bm.x) - float(bm.w) / 2.0, "y": 300.0, "w": float(bm.w), "h": GY - 300.0}


# ---------------------------------------------------------------- desenho
static func draw(g, b: Dictionary, T: int) -> void:
	if b.is_empty():
		return
	# cabine de controle (vidro, painel, escadinha)
	var cx: float = b.get("cab_x", float(b.x1) - 120.0)
	var cy: float = b.get("cab_y", 330.0)
	Spr.rect(cx - 70, cy, 140, GY - cy, Color("#3a4150"))
	Spr.rect(cx - 70, cy, 140, 8, Color("#f2c230"))
	for i in 6:
		Spr.rect(cx + 52, cy + 18 + i * 26, 22, 4, Color("#8b95a3"))
	Spr.rect(cx - 74, cy - 96, 148, 96, Color("#2a313d"))
	Spr.rect(cx - 66, cy - 88, 132, 58, Color(.55, .8, .95, .35))
	var luz: Color = Color("#e8302a") if b.get("st", "") == "lasers" and int(T / 8) % 2 == 0 else Color("#36c26a")
	Spr.circle(cx + 58, cy - 108, 9, luz)
	Spr.text("SEGURANÇA", cx - 66, cy - 102, 14, Color("#f2c230"))
	if b.get("zap", 0) > 0:
		b.zap -= 1
		for i in 4:
			Spr.seg(cx - 60 + randf() * 120, cy - 90 + randf() * 60, cx - 60 + randf() * 120, cy - 90 + randf() * 60, Color("#bfe9ff"), 3)
	# painel de energia
	var px: float = b.get("pan_x", float(b.x0) + 70.0)
	var py: float = b.get("pan_y", 430.0)
	Spr.rect(px - 24, py - 40, 48, 64, Color("#5a6270"))
	var aberto: int = int(b.get("panel", 0))
	if aberto == 1:
		Spr.rect(px - 18, py - 34, 36, 52, Color("#1b1f26"))
		var pisca: float = .5 + .5 * sin(T * .3)
		Spr.glow(px, py - 8, 46 + pisca * 10, Color(1, .85, .2, .35 + pisca * .3))
		Spr.rect(px - 12, py - 26, 24, 8, Color("#ffd23a"))
		Spr.rect(px - 12, py - 12, 24, 8, Color("#ff7a3a"))
		Spr.text("!", px - 5, py - 46 - pisca * 6, 26, Color("#ffd23a"))
	elif aberto == 2:
		Spr.rect(px - 18, py - 34, 36, 52, Color("#111"))
	else:
		Spr.rect(px - 18, py - 34, 36, 52, Color("#6c7584"))
		Spr.rect(px - 6, py - 10, 12, 4, Color("#2a2f38"))
	# lasers (aviso piscando, depois o feixe)
	if b.get("st", "") == "lasers":
		var bt: int = int(b.get("bt", 0))
		var warn: int = int(b.get("warn", 50))
		for bm in b.get("beams", []):
			var r := beam_rect(b, bm)
			if bt < warn:
				if int(bt / 5) % 2 == 0:
					if bm.k == "h":
						Spr.rect(r.x, r.y + r.h / 2 - 1, r.w, 2, Color(1, .3, .2, .6))
					else:
						Spr.rect(r.x + r.w / 2 - 1, r.y, 2, r.h, Color(1, .3, .2, .6))
				if bm.k == "v":
					Spr.rect(r.x - 4, GY - 4, r.w + 8, 4, Color(1, .2, .1, .8))
			elif bt < warn + int(b.get("on", 34)):
				Spr.rect(r.x - 4, r.y - 3, r.w + 8, r.h + 6, Color(1, .15, .1, .3))
				Spr.rect(r.x, r.y, r.w, r.h, Color(1, .2, .15, .9))
				if bm.k == "h":
					Spr.rect(r.x, r.y + r.h / 2 - 1, r.w, 2, Color(1, .9, .85))
				else:
					Spr.rect(r.x + r.w / 2 - 1, r.y, 2, r.h, Color(1, .9, .85))
	# o Fiscal (arte provisória: o cambista de terno com quepe; vira a arte do Gemini depois)
	if b.done and b.st != "down":
		return
	var st: String = b.get("st", "wait")
	if st == "wait":
		return
	var face_left: bool = g.player.x < b.x
	var c: Color = Polish.fury(int(b.hp)) if int(b.get("red", 0)) == 0 else Color(1, .5, .5)
	if st in ["tonto", "down"]:
		Spr.P("boar_ko" if st == "down" else "boar_wind", b.x, b.y + 2, 110, not face_left, 0.0, c)
		if st == "tonto":
			for i in 3:
				var a: float = T * .12 + i * TAU / 3.0
				Spr.text("★", b.x + cos(a) * 26 - 6, b.y - 82 + sin(a) * 6, 16, Color("#ffd23a"))
	else:
		Spr.P("boar_wind", b.x, b.y + 2, 100, not face_left, 0.0, c)
	# quepe de fiscal
	if st not in ["tonto", "down"]:
		Spr.rect(b.x - 18, b.y - 84, 36, 9, Color("#1d2a4a"))
		Spr.rect(b.x - 22 if face_left else b.x, b.y - 77, 22, 4, Color("#11182c"))
		Spr.rect(b.x - 4, b.y - 83, 8, 6, Color("#f2c230"))
