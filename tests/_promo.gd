extends SceneTree
## grava cenas de jogo para o vídeo promocional (usar com --write-movie)
var main
var g
var clip := ""
func _initialize() -> void:
	clip = OS.get_environment("CLIP")
	DirAccess.make_dir_recursive_absolute("/tmp/promo/fr_" + clip)
	var S = root.get_node("Save")
	for c in ["seguranca", "drone", "vento", "fiscal", "guarda"]:
		S.setv("comic", c, true)
	S.setv("dica", "seg_arena", true)
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	for i in 3:
		await process_frame
	main.start_level(false, 0)
	await process_frame
	for k in 6:
		if main.panel and main.panel.has_meta("ok"):
			main.panel.get_meta("ok").call()
		for c in main.ui_layer.get_children():
			if c.has_method("_end"):
				c._end()
		await process_frame
	g = main.game
	for n in g.L.npcs:
		n.seen = true
	g.CINE = {}
	main.state = main.S.PLAY
	g.lives = 9
	match clip:
		"corre": await _corre()
		"luta": await _luta()
		"fios": await _fios()
		"foguete": await _foguete()
		"chefe": await _chefe()
		"defesa": await _defesa()
		"drone": await _drone()
		"chefe2": await _chefe2()
	quit()

func _put(x: float, y: float) -> void:
	g.player.x = x
	g.player.y = y
	g.player.vx = 0.0
	g.player.vy = 0.0
	g.cam = x - g.W * .45
	g.flash_t = 0

var nf := 0
func _tick() -> void:
	main._show_hud(false)
	if nf >= 0:
		root.get_texture().get_image().save_jpg("/tmp/promo/fr_%s/%04d.jpg" % [clip, nf], .92)
		nf += 1
	g.player.hp = 5
	g.CINE = {}
	g.flash_t = 0
	if main.state != main.S.PLAY:
		if main.panel and main.panel.has_meta("ok"):
			main.panel.get_meta("ok").call()
		main.state = main.S.PLAY
	await process_frame

func _keys(d: Dictionary) -> void:
	for k in ["L", "R", "J", "G", "F", "K", "RUN", "U", "S"]:
		g.keys[k] = d.get(k, false)

func _press(k: String) -> void:
	g.keys[k + "p"] = true
	g.keys[k] = true

func _warm(n: int) -> void:
	for i in n:
		_keys({})
		await _tick()

func _corre() -> void:
	_put(380.0, 440.0)
	await _warm(25)
	for i in 165:
		_keys({"R": true, "RUN": true})
		if i % 42 == 10:
			_press("J")
		elif i % 42 < 22 and i % 42 > 10:
			g.keys["J"] = true
		await _tick()

func _luta() -> void:
	_put(1150.0, 440.0)
	await _warm(10)
	for i in 230:
		var e = null
		for q in g.EN:
			if q.k == "boar" and not q.dead and q.x < 1500:
				e = q
		var d := {}
		if e:
			var dx: float = e.x - (g.player.x + g.player.w / 2)
			if absf(dx) > 95:
				d["R" if dx > 0 else "L"] = true
			elif i % 16 == 0:
				_press("G")
			elif i % 50 == 30:
				_press("K")
			if i % 60 > 50:
				d["F"] = true
		for k in d:
			g.keys[k] = true
		await _tick()
		for k in ["L", "R", "F"]:
			g.keys[k] = false

func _fios() -> void:
	g.give_item("luvas")
	_put(11380.0, 100.0)
	await _warm(20)
	var st := 0
	var held := 0
	for i in 260:
		var p = g.player
		var d := {"R": true}
		if p.vine == null:
			if p.onGround and st == 0 and p.x > 11400:
				_press("J"); st = 1; held = 0
			elif st == 1:
				held += 1
				d["J"] = held < 30
				if held == 15:
					_press("J")
			elif p.onGround and st == 2:
				st = 0
		else:
			st = 2
			var v = p.vine
			if float(v.get("th", 0.0)) > .3 and float(v.get("om", 0.0)) > 0.0:
				_press("J")
				st = 1
				held = 20
		if p.onGround and p.x > 12240:
			d = {}
		for k in d:
			g.keys[k] = d[k]
		await _tick()
		g.keys["R"] = false

func _foguete() -> void:
	g.give_item("botas_foguete")
	_put(3880.0, 340.0)
	await _warm(25)
	var st := 0
	for i in 120:
		var p = g.player
		var d := {}
		if i == 5:
			_press("J"); st = 1
		elif st == 1 and p.vy > -1:
			_press("J"); st = 2
		elif st == 2 and p.vy > -1 and i > 20:
			_press("J"); st = 3
		if st >= 1 and st < 4:
			d["J"] = true
		if i > 8 and p.x < 3975:
			d["R"] = true
		for k in d:
			g.keys[k] = d[k]
		await _tick()
		_keys({})

func _chefe() -> void:
	_put(14700.0, 400.0)
	await _warm(5)
	for i in 120:
		_keys({"R": g.player.x < 14830})
		await _tick()
		if g.X.boss_active() and str(g.X.BOSS.st) not in ["wait", "espera"]:
			break
	for i in 260:
		var d := {}
		var b = g.X.BOSS
		# pula os lasers baixos e o piso, segura o escudo nas malas
		if i % 38 == 0:
			_press("J")
		if i % 38 < 16:
			d["J"] = true
		var px: float = g.player.x
		if i % 120 < 60:
			d["R"] = px < 15200
		else:
			d["L"] = px > 14700
		for k in d:
			g.keys[k] = d[k]
		await _tick()
		_keys({})


func _seg():
	for q in g.EN:
		if q.k == "boar" and not q.dead and q.x < 1500:
			return q
	return null

func _defesa() -> void:
	_put(1170.0, 440.0)
	await _warm(10)
	for i in 300:
		var e = _seg()
		var d := {}
		if e:
			var dx: float = e.x - (g.player.x + g.player.w / 2)
			var perigo: bool = int(e.get("wind", 0)) > 0 or int(e.get("charge", 0)) > 0 or e.has("proj")
			if perigo and absf(dx) < 260:
				if i % 90 < 45:
					d["F"] = true          # escudo levantado
					g.player.face = 1 if dx > 0 else -1
				elif int(g.M.dodge_t) == 0:
					_press("F")             # esquiva
					d["F"] = true
					d["L" if dx > 0 else "R"] = true
			elif absf(dx) > 140:
				d["R" if dx > 0 else "L"] = true
			elif i % 40 == 0:
				_press("G")
		for k in d:
			g.keys[k] = d[k]
		await _tick()
		_keys({})

func _drone() -> void:
	for q in g.EN:
		if q.k == "boar" and q.x < 1500:
			q.dead = 99
	g.ARN.A[0].done = true
	g.ARN.A[0].h = 0.0
	_put(1620.0, 440.0)
	await _warm(10)
	for i in 220:
		var c = null
		for q in g.EN:
			if q.k == "crow" and not q.dead and q.x < 2100:
				c = q
		var d := {}
		if c:
			var dx: float = c.x - (g.player.x + g.player.w / 2)
			if absf(dx) > 40 and str(c.get("st", "")) != "dive":
				d["R" if dx > 0 else "L"] = true
			if absf(dx) < 90 and c.y > g.player.y - 140:
				if i % 10 == 0:
					_press("J")
				if i % 10 == 4:
					_press("G")
			d["J"] = g.keys.get("J", false)
		for k in d:
			g.keys[k] = d[k]
		await _tick()
		_keys({})

func _chefe2() -> void:
	_put(14700.0, 400.0)
	await _warm(5)
	# entra na arena e deixa a apresentação rodar (sem apagar a cena), pulando as falas
	for i in 400:
		_keys({"R": g.player.x < 14860})
		if not g.CINE.is_empty() and i % 8 == 0:
			g.keys["Jp"] = true
		for c in main.ui_layer.get_children():
			if c.has_method("_end"):
				c._end()
		if main.state != main.S.PLAY:
			if main.panel and main.panel.has_meta("ok"):
				main.panel.get_meta("ok").call()
			main.state = main.S.PLAY
		main._show_hud(false)
		g.player.hp = 5
		root.get_texture().get_image().save_jpg("/tmp/promo/fr_%s/%04d.jpg" % [clip, nf], .92)
		nf += 1
		await process_frame
		if g.X.boss_active() and str(g.X.BOSS.st) not in ["wait", "espera", "intro"] and g.CINE.is_empty():
			break
	print("chefe ativo em ", nf, " st=", g.X.BOSS.st)
	for i in 600:
		var b = g.X.BOSS
		var p = g.player
		var cx: float = p.x + p.w / 2
		var d := {}
		var sombra := false
		for o in b.get("objs", []):
			if o.k == "cai" and int(o.t) > 0 and int(o.t) < 40 and absf(float(o.x) - cx) < 60.0:
				sombra = true
			if o.k == "rola" and int(o.wait) == 0 and float(o.x) > cx and float(o.x) - cx < 110.0 and p.onGround:
				_press("J")
		if sombra:
			d["F"] = true    # escudo segura a mala que cai
		var k: String = str(b.get("beam_k", ""))
		var bt: int = int(b.get("bt", 0))
		var warn: int = int(b.get("warn", 50))
		if str(b.st) == "lasers" and k == "rasteiro" and bt == warn - 6 and p.onGround:
			_press("J")
		if str(b.st) == "lasers" and k == "alto" and bt > warn - 12:
			d["S"] = true
		if str(b.st) in ["painel"] and b.has("pan_x"):
			var pan: float = float(b.pan_x) + 46.0
			if absf(cx - pan) > 10:
				d["R" if pan > cx else "L"] = true
			elif i % 14 == 0:
				_press("G")
		elif not sombra and i % 140 < 70:
			d["R"] = cx < 15150
		elif not sombra:
			d["L"] = cx > 14760
		if g.keys.get("J", false) == false and int(g.keys.get("Jp", 0)) == 0:
			pass
		for kk in d:
			g.keys[kk] = d[kk]
		await _tick()
		_keys({})
