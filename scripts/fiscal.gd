class_name FiscalBoss
extends RefCounted
## Mini-chefe da 1-1: o FISCAL FALSO, capanga do ladrão disfarçado de agente de segurança.
## Fica na cabine de controle (alto, à direita da arena) e ataca em padrões que obrigam a se mexer:
##   rasteiro  laser no rodapé (pule)          alto   laser na altura do peito (abaixe ↓)
##   grade     feixes verticais com vãos       piso   faixas do chão acendem e dão choque (saia)
##   rola      malas rolando pelo chão (pule)  cai    malas caindo onde a sombra marca (desvie)
## Depois de cada rodada, o painel de energia abre — cada vez num lugar diferente, longe do Milis — e
## fica aberto pouco tempo: um golpe dá curto, o Fiscal cai tonto e aí é pisar na cabeça ou bater.
## 3 fases: na 2ª a esteira do piso da arena puxa para a esquerda; na 3ª ela inverte e o Fiscal desce
## da cabine e corre atrás do Milis (com malas caindo) até o painel ser acertado.

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
	# lugares do painel: esquerda, meio e perto da cabine (troca a cada rodada)
	b.pan_spots = [float(b.x0) + 70.0, (float(b.x0) + float(b.x1) - 190.0) / 2.0, float(b.x1) - 290.0]
	b.objs = []
	b.floor = []


static func box(g, b: Dictionary) -> Dictionary:
	# do tamanho da arte: sentado tonto é mais baixo
	if str(b.get("st", "")) == "tonto":
		return g.R(b.x - 44, b.y - 128, 88, 128)
	return g.R(b.x - 34, b.y - 168, 68, 168)


static func _pattern_list(hp: int) -> Array:
	match hp:
		3:
			return ["rasteiro", "rola", "piso", "alto", "grade"]
		2:
			return ["cai", "piso", "rola", "alto", "cai", "rasteiro"]
		_:
			return ["persegue"]


## o painel abre longe do Milis (nunca no mesmo lugar duas vezes seguidas)
static func _open_panel(g, b: Dictionary) -> void:
	var pcx: float = g.player.x + g.player.w / 2
	var best: float = b.pan_spots[0]
	var dbest := -1.0
	for sx in b.pan_spots:
		if absf(float(sx) - float(b.get("pan_x", -9999.0))) < 10.0:
			continue
		var d: float = absf(float(sx) - pcx)
		if d > dbest:
			dbest = d
			best = float(sx)
	b.pan_x = best
	b.panel = 1
	Audio.play("unlock", -4)
	g.flash("O painel de energia abriu ali! Corra e acerte com o bastão antes que feche.", 170)


static func _panel_time(b: Dictionary) -> int:
	return [200, 240, 300][clampi(int(b.hp) - 1, 0, 2)]


## esteira do piso da arena: parada na 1ª fase, puxa para a esquerda na 2ª e para a direita na 3ª
static func _arena_belt(g, b: Dictionary) -> void:
	var want: float = 0.0
	if b.active and not b.done and b.st != "down":
		want = 0.0 if int(b.hp) >= 3 else (-1.0 if int(b.hp) == 2 else 1.0)
	var wk = b.get("walk")
	if want == 0.0:
		if wk != null:
			g.WALKS.erase(wk)
			b.walk = null
		return
	if wk == null:
		wk = {"x0": float(b.x0) + 20.0, "x1": float(b.x1) - 270.0, "y": GY, "dir": want, "spd": 1.3}
		g.WALKS.append(wk)
		b.walk = wk
	wk.dir = want
	wk.spd = 1.3 if int(b.hp) == 2 else 1.7


static func _speed(b: Dictionary) -> float:
	return 1.0 + (int(b.maxhp) - int(b.hp)) * 0.22


## começa a próxima rajada de laser
static func _next_beam(g, b: Dictionary) -> void:
	if b.queue.is_empty():
		b.st = "painel"
		b.t = 0
		_open_panel(g, b)
		return
	var k: String = b.queue.pop_front()
	if k == "persegue":
		# 3ª fase: desce da cabine e corre atrás do Milis
		b.st = "persegue"
		b.t = 0
		b.y = GY
		b.x = float(b.cab_x) - 100.0
		b.beams = []
		g.shake = 8
		Audio.play("roar", -4)
		g.flash("O Fiscal desceu da cabine! Fuja dele e acerte o painel quando abrir!", 170)
		return
	var sp: float = _speed(b)
	var warn := int(56.0 / sp)
	var on := 34
	var beams: Array = []
	b.floor = []
	match k:
		"rasteiro":
			beams.append({"k": "h", "y": GY - 7, "h": 7})
			on = 22
		"alto":
			# (na altura do peito do Milis em pé; abaixado ele passa por baixo)
			beams.append({"k": "h", "y": GY - 40, "h": 9})
		"piso":
			# faixas do chão: acende metade (sempre a faixa de onde o Milis está), depois dá choque
			var pcx: float = g.player.x + g.player.w / 2
			var x0: float = float(b.x0)
			var wst := 120.0
			var n2: int = int((float(b.x1) - 190.0 - x0) / wst)
			var mine: int = clampi(int((pcx - x0) / wst), 0, n2 - 1)
			for i in n2:
				if (i - mine) % 2 == 0:
					b.floor.append({"x": x0 + i * wst, "w": wst})
			warn = int(64.0 / sp)
			on = 40
		"rola":
			# duas malas rolando da cabine para a esquerda (pular)
			for i in 2:
				b.objs.append({"k": "rola", "x": float(b.cab_x) - 90.0 + i * 140.0, "y": GY, "vx": -(4.2 + sp), "rot": 0.0, "wait": i * 34})
			warn = 30
			on = 110
		"cai":
			# três malas caindo: uma onde o Milis está e duas dos lados (a sombra cresce antes)
			var pcx2: float = g.player.x + g.player.w / 2
			for dx in [0.0, -150.0, 150.0]:
				var xx: float = clampf(pcx2 + dx, float(b.x0) + 30.0, float(b.x1) - 220.0)
				b.objs.append({"k": "cai", "x": xx, "y": GY, "t": int(62.0 / sp) + (0 if dx == 0.0 else 12), "hy": -260.0})
			warn = 20
			on = 90
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
	_arena_belt(g, b)
	_objs(g, b)
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
				# piso eletrificado: em pé (no chão) numa faixa acesa
				if p.onGround:
					var fx: float = p.x + p.w / 2
					for fl in b.floor:
						if fx > float(fl.x) and fx < float(fl.x) + float(fl.w) and absf(p.y + p.h - GY) < 6.0:
							g.hurt(1, fx + 1)
							break
			if b.bt > b.warn + b.on + 14:
				b.beams = []
				b.floor = []
				_next_beam(g, b)
		"painel", "painel_chao":
			# o painel fica aberto pouco tempo; se ninguém acertar, fecha e vem outra rodada
			if b.st == "painel_chao":
				_chase(g, b, 1.5)
			if b.t > _panel_time(b):
				b.panel = 0
				b.t = 0
				g.tip("O painel fechou. Desvie e corra para o painel quando ele abrir de novo!", 180)
				if b.st == "painel_chao":
					b.st = "persegue"
				else:
					b.st = "lasers"
					b.queue = _pattern_list(int(b.hp))
					_next_beam(g, b)
		"persegue":
			# corre atrás do Milis e chove mala; depois de um tempo o painel abre (ele continua atrás)
			_chase(g, b, 2.3 + minf(b.t / 300.0, 1.0))
			if b.t % 80 == 40:
				var pcx3: float = p.x + p.w / 2
				b.objs.append({"k": "cai", "x": clampf(pcx3, float(b.x0) + 30.0, float(b.x1) - 220.0), "y": GY, "t": 58, "hy": -260.0})
			if b.t > 330:
				b.st = "painel_chao"
				b.t = 0
				_open_panel(g, b)
		"curto_chao":
			# levou o choque no chão: treme e cai tonto ali mesmo
			if b.t > 34:
				b.st = "tonto"
				b.t = 0
				g.shake = 8
				Audio.play("stomp")
				g.flash("Ele tomou o choque! Pule na cabeça dele ou bata!", 140)
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
			if b.t > 240:
				b.t = 0
				# na 3ª fase ele levanta e volta a correr atrás; antes, volta para a cabine
				b.st = "persegue" if int(b.hp) <= 1 else "volta"
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
	# na cabine ele empurra quem chegar perto; correndo no chão, o encontrão machuca
	if int(b.get("cool", 0)) > 0:
		b.cool -= 1
	elif b.st in ["lasers", "painel", "curto", "persegue", "painel_chao"] and p.dyingT == 0 and Game.hit(p, box(g, b)):
		g.hurt(1, b.x)
		if b.st in ["persegue", "painel_chao"]:
			# depois do encontrão ele recua um pouco (não prende o Milis num canto)
			b.cool = 70
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
	if b.st == "painel_chao" and Game.hit(hb, g.R(b.pan_x - 26, b.pan_y - 40, 52, 70)):
		# 3ª fase: o choque corre pelo chão até o Fiscal
		b.panel = 2
		b.st = "curto_chao"
		b.t = 0
		b.zap = 40
		g.shake = 12
		Audio.play("thunder", -6)
		Audio.vib(90)
		g.burst(b.pan_x, b.pan_y, 18, Color("#ffe066"))
		g.burst(b.x, b.y - 80, 24, Color("#9ad7ff"))
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
		b.objs = []
		b.floor = []
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
		b.t = 0
		b.objs = []
		b.floor = []
		if b.hp == 1:
			b.st = "persegue"
			g.flash("Ele ficou furioso! Agora ele vem atrás de você. Falta 1!", 150)
		else:
			b.st = "volta"
			g.flash("Isso! A esteira do chão ligou. Faltam %d." % b.hp, 140)


## corre na direção do Milis (no chão da arena)
static func _chase(g, b: Dictionary, spd: float) -> void:
	var pcx: float = g.player.x + g.player.w / 2
	var d: float = pcx - float(b.x)
	if int(b.get("cool", 0)) > 0:
		spd = -1.4   # recuando depois do encontrão
	if absf(d) > 6.0:
		b.dir = 1 if d > 0 else -1
		b.x = clampf(float(b.x) + b.dir * spd, float(b.x0) + 40.0, float(b.x1) - 180.0)
	b.y = GY


## malas rolando e malas caindo
static func _objs(g, b: Dictionary) -> void:
	var p: Dictionary = g.player
	var keep: Array = []
	for o in b.get("objs", []):
		if o.k == "rola":
			if int(o.wait) > 0:
				o.wait -= 1
				keep.append(o)
				continue
			o.x += o.vx
			o.rot += o.vx * .05
			if p.dyingT == 0 and Game.hit(p, g.R(o.x - 18, GY - 30, 36, 30)):
				g.hurt(1, o.x)
			if o.x > float(b.x0) - 40.0:
				keep.append(o)
		else:
			o.t -= 1
			if o.t <= 0:
				# caiu: estrondo e quem estiver embaixo se machuca
				if o.t == 0:
					g.shake = max(g.shake, 6)
					Audio.play("stomp", -6, 1.2)
					g.burst(o.x, GY - 6, 10, Color("#c9a26a"))
					if p.dyingT == 0 and Game.hit(p, g.R(o.x - 26, GY - 46, 52, 46)):
						g.hurt(1, o.x)
				if o.t > -40:
					keep.append(o)
			else:
				keep.append(o)
	b.objs = keep


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
	# a cabine de vidro pintada (o Fiscal fica em cima, no posto de controle)
	if Spr.AR.has("p_pc_cabine"):
		Spr.AB("p_pc_cabine", cx - 76, cy - 6, 152, GY - cy + 10)
	else:
		Spr.rect(cx - 70, cy, 140, GY - cy, Color("#3a4150"))
	Spr.rect(cx - 72, cy - 2, 144, 8, Color("#f2c230"))
	for i in 6:
		Spr.rect(cx + 70, cy + 18 + i * 26, 18, 4, Color("#8b95a3"))
	# posto de controle em cima da cabine: uma salinha de vidro (o Fiscal fica DENTRO dela)
	Spr.rect(cx - 78, cy - 200, 156, 200, Color(.12, .15, .2, .7))
	Spr.rect(cx - 70, cy - 190, 140, 110, Color(.55, .8, .95, .18))
	Spr.rect(cx - 84, cy - 212, 168, 14, Color("#5b6470"))
	var luz: Color = Color("#e8302a") if b.get("st", "") == "lasers" and int(T / 8) % 2 == 0 else Color("#36c26a")
	Spr.circle(cx + 62, cy - 222, 9, luz)
	Spr.text("SEGURANÇA", cx - 70, cy - 216, 14, Color("#f2c230"))
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
	# piso eletrificado: aviso amarelo piscando, depois choque azul
	if b.get("st", "") == "lasers" and not b.get("floor", []).is_empty():
		var bt2: int = int(b.get("bt", 0))
		var warn2: int = int(b.get("warn", 50))
		for fl in b.floor:
			var fx0: float = float(fl.x)
			var fw: float = float(fl.w)
			if bt2 < warn2:
				var a3: float = .25 + .35 * float(int(bt2 / 6) % 2)
				Spr.rect(fx0 + 3, GY - 4, fw - 6, 6, Color(1, .85, .2, a3))
				for k in int(fw / 24):
					Spr.seg(fx0 + 8 + k * 24, GY - 2, fx0 + 20 + k * 24, GY - 2, Color(.1, .1, .1, a3), 3)
			elif bt2 < warn2 + int(b.get("on", 40)):
				Spr.rect(fx0 + 2, GY - 6, fw - 4, 8, Color(.55, .9, 1, .85))
				for k in 4:
					var zx: float = fx0 + randf() * fw
					Spr.seg(zx, GY - 2, zx + randf_range(-8, 8), GY - 18 - randf() * 16, Color(.8, .97, 1), 2)
	# malas: rolando (girando) e caindo (sombra crescendo, depois a mala no chão)
	for o in b.get("objs", []):
		if o.k == "rola":
			if int(o.wait) > 0:
				continue
			Spr.save()
			Spr.translate(o.x, GY - 16)
			Spr.rotate(o.rot)
			Spr.rr(-18, -15, 36, 30, 5, Color("#b5502c"))
			Spr.rect(-18, -2, 36, 4, Color("#e8c060"))
			Spr.rr(-6, -20, 12, 6, 2, Color("#3a2a1a"))
			Spr.restore()
		else:
			var tt: int = int(o.t)
			if tt > 0:
				var u: float = clampf(1.0 - tt / 70.0, 0.0, 1.0)
				Spr.ellipse(o.x, GY + 1, 10 + 22 * u, 4 + 3 * u, Color(0, 0, 0, .2 + .35 * u))
				if tt < 14:
					var yy: float = GY - 22.0 - tt * 18.0
					Spr.rr(o.x - 22, yy - 20, 44, 34, 5, Color("#3d6fb5"))
					Spr.rect(o.x - 22, yy - 6, 44, 4, Color("#f2c230"))
			else:
				var fade: float = clampf(1.0 + tt / 40.0, 0.0, 1.0)
				Spr.rr(o.x - 22, GY - 34, 44, 34, 5, Color(.24, .44, .71, fade))
				Spr.rect(o.x - 22, GY - 20, 44, 4, Color(.95, .76, .19, fade))
	# o Fiscal (arte provisória: o cambista de terno com quepe; vira a arte do Gemini depois)
	# frente da salinha de vidro: por cima do Fiscal só quando ele está lá dentro
	var dentro: bool = abs(float(b.x) - float(b.get("cab_x", 0.0))) < 80 and float(b.y) <= float(b.get("cab_y", 330.0)) + 4 \
			and not (b.done and b.st != "down") and b.get("st", "wait") != "wait"
	if not dentro:
		_booth_front(b, T)
	if b.done and b.st != "down":
		return
	var st: String = b.get("st", "wait")
	if st == "wait":
		return
	var face_left: bool = g.player.x < b.x
	var c: Color = Polish.fury(int(b.hp)) if int(b.get("red", 0)) == 0 else Color(1, .5, .5)
	var pose := "parado"
	match st:
		"lasers":
			pose = "botao"
		"persegue", "painel_chao":
			pose = "foge"
		"curto_chao":
			pose = "choque"
		"painel":
			pose = "ri"
		"curto", "cai":
			pose = "choque"
		"tonto":
			pose = "tonto"
		"down":
			pose = "ko"
		"volta":
			pose = "bracos"
		_:
			pose = "parado" if int(T / 90) % 3 != 2 else "bracos"
	var r = Spr.AR.get("p_fiscal_" + pose)
	if r != null:
		var hgt: float = 186.0 if pose != "ko" else 90.0
		if pose == "tonto":
			hgt = 146.0
		var w: float = hgt * r[2] / r[3]
		# a arte olha para a direita
		Spr.P("fiscal_" + pose, b.x, b.y + 2, w, face_left, 0.0, c)
		if dentro:
			_booth_front(b, T)
		if st == "tonto":
			for i in 3:
				var a2: float = T * .12 + i * TAU / 3.0
				Spr.text("★", b.x + cos(a2) * 34 - 6, b.y - 140 + sin(a2) * 7, 16, Color("#ffd23a"))
		return
	if st in ["tonto", "down"]:
		Spr.P("boar_ko" if st == "down" else "boar_wind", b.x, b.y + 2, 110, not face_left, 0.0, c)
	else:
		Spr.P("boar_wind", b.x, b.y + 2, 100, not face_left, 0.0, c)
	if dentro:
		_booth_front(b, T)

## frente da salinha de controle (por cima do Fiscal quando ele está lá dentro): vidro, moldura e o
## console com o botão vermelho na altura da cintura
static func _booth_front(b: Dictionary, T: int) -> void:
	var cx: float = b.get("cab_x", float(b.x1) - 120.0)
	var cy: float = b.get("cab_y", 330.0)
	Spr.rect(cx - 78, cy - 200, 156, 200, Color(.7, .9, 1, .1))
	Spr.poly(PackedVector2Array([Vector2(cx - 66, cy - 186), Vector2(cx - 40, cy - 186), Vector2(cx - 66, cy - 140)]), Color(1, 1, 1, .18))
	for fx in [cx - 78, cx + 74]:
		Spr.rect(fx, cy - 200, 4, 200, Color("#c9ced6"))
	# console
	Spr.rect(cx - 78, cy - 64, 156, 64, Color("#2c323c"))
	Spr.rect(cx - 78, cy - 66, 156, 6, Color("#8d97a3"))
	for i in 3:
		Spr.rect(cx - 64 + i * 44, cy - 52, 34, 20, Color("#123047"))
		Spr.rect(cx - 62 + i * 44, cy - 50, 30, 3, Color(.4, .9, 1, .5 + .3 * sin(T * .1 + i)))
	Spr.circle(cx + 52, cy - 20, 8, Color("#d8302a"))
	Spr.rect(cx - 72, cy - 4, 144, 4, Color("#f2c230"))
