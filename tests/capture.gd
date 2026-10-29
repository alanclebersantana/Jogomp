extends SceneTree
## Grava trechos de jogo para o vídeo promocional (sem HUD).
## Uso: godot --path . --write-movie /tmp/vid/<seg>.avi --fixed-fps 30 -s tests/capture.gd -- <seg>
var main
var g
var P: Dictionary
var nf := 0

func _initialize() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	for i in 3:
		await process_frame
	var sv = root.get_node("Save")
	for id in ["cipo", "mergulho", "neve", "pipoca", "picareta", "cavalo", "mina", "toxico", "javali", "gaviao", "bagre", "urso", "vargas", "bola", "aviao", "jangada", "colmeia", "carrinho", "moinho", "telhados"]:
		sv.setv("comic", id, true)
	sv.setv("opt", "tut_asked", true)
	var seg0: String = OS.get_cmdline_user_args()[0]
	main.start_level(false, 1 if seg0.begins_with("e2_") else 0)
	await process_frame
	if main.panel and main.panel.has_meta("ok"):
		main.panel.get_meta("ok").call()
		await process_frame
	for c in main.ui_layer.get_children():
		if c.has_method("_end"):
			c._end()
	await process_frame
	if main.panel and main.panel.has_meta("ok"):
		main.panel.get_meta("ok").call()
	g = main.game
	g.lives = 99
	g.clue_opened.disconnect(main._on_clue)
	var seg: String = OS.get_cmdline_user_args()[0]
	await call(seg)
	quit()

func put(x: float, y: float) -> void:
	g.CINE = {}
	g.VH.mode = ""
	g.player.x = x - 12
	g.player.y = y - 34
	g.player.vx = 0
	g.player.vy = 0
	g.player.vine = null
	g.player.ladder = null
	g.player.spawnX = g.player.x
	g.player.spawnY = g.player.y
	g.snap_camera()
	P = g.player

var posf: FileAccess

func hide_ui() -> void:
	main.hud_layer.visible = false
	## posição do Tomé na tela (0..1) por quadro, para o corte que acompanha o personagem
	if posf == null:
		var seg: String = OS.get_cmdline_user_args()[0]
		posf = FileAccess.open("/tmp/vid/hi/%s.pos" % seg, FileAccess.WRITE)
	if posf and g and g.camera:
		var vs: Vector2 = main.get_viewport().get_visible_rect().size
		var z: float = g.camera.zoom.x
		var c: Vector2 = g.camera.position
		var u: float = (g.player.x + 12 - c.x) * z / vs.x
		var v: float = (g.player.y + 20 - c.y) * z / vs.y
		posf.store_line("%d %.4f %.4f" % [Engine.get_process_frames(), u, v])

## roda n quadros do vídeo; keys(i) devolve as teclas apertadas no quadro i
func run(n: int, keys: Callable) -> void:
	for i in n:
		hide_ui()
		g.flash_t = 0
		var k: Dictionary = keys.call(i)
		for kk in ["L", "R", "J", "S", "U", "A", "G"]:
			var down: bool = k.get(kk, false)
			if down and not g.keys.get(kk, false):
				g.keys[kk + "p"] = true
			g.keys[kk] = down
		for kk in k:
			if kk.ends_with("p"):
				g.keys[kk] = true
		g.player.hp = 5
		await process_frame

func kill_enemies() -> void:
	for e in g.EN:
		e.dead = 99

# ---------- trechos ----------
func manha() -> void:
	kill_enemies()
	put(2550, 430)
	await run(120, func(i): return {})

func flor() -> void:
	kill_enemies()
	put(3855, 440)
	await run(110, func(i): return {})

func javali() -> void:
	kill_enemies()
	put(5040, 500)
	var b: Dictionary = g.X.BOSS
	b.active = true
	b.st = "paw"
	b.t = 0
	b.x = 5460.0
	b.y = 500.0
	b.dir = -1
	b.hp = b.maxhp
	g.X._gate_on(true)
	var st := {"j": -1}
	await run(120, func(i):
		var bb: Dictionary = g.X.BOSS
		var px: float = g.player.x + 12
		if st.j < 0 and bb.st == "charge" and abs(bb.x - px) < 190:
			st.j = i
		if st.j >= 0:
			var k: int = i - st.j
			return {"Jp": k == 0 or k == 12, "J": k < 26}
		return {})

func cipos() -> void:
	kill_enemies()
	put(19140, 300)
	var v: Dictionary = g.VINES[1]
	g.player.vine = v
	g.player.vr = 210.0
	v.om = .028
	v.th = -.3
	await run(150, func(i):
		var pv = g.player.vine
		var d := {}
		if pv:
			d = {"R": true} if pv.om > 0 else {"L": true}
			if pv.th > .3 and pv.om > 0:
				d["Jp"] = true
		return d)

func gaviao() -> void:
	kill_enemies()
	put(14340, 500)
	var h: Dictionary = g.K.HAWK
	h.active = true
	h.st = "mark"
	h.t = 0
	h.tx = 14340.0
	h.x = 14340.0
	h.y = h.gy - 300.0
	g.K._gate("hawkL", true, Rect2(h.x0 - 24, h.gy - 260, 24, 260))
	g.K._gate("hawkR", true, Rect2(h.x1, h.gy - 260, 24, 260))
	await run(140, func(i):
		var hh: Dictionary = g.K.HAWK
		if hh.st == "stuck":
			var dx: float = hh.x - (g.player.x + 12)
			if abs(dx) > 40:
				return {"R": dx > 0, "L": dx < 0}
			g.player.face = 1 if dx > 0 else -1
			return {"Gp": i % 20 == 0}
		return {"L": i > 6 and i < 40})

func bagre() -> void:
	kill_enemies()
	put(24140, 850)
	g.NT.helmet = true
	g.NT.harpoon = true
	var f: Dictionary = g.K.FISH
	f.active = true
	f.st = "suck"
	f.t = 0
	f.x = 24140 + 330.0
	f.y = 850.0
	f.dir = -1
	await run(150, func(i): return {"L": i > 10 and i < 70, "U": i % 18 < 6})

func gelo() -> void:
	kill_enemies()
	put(37770, 868)
	await run(110, func(i): return {"R": i > 4 and i < 95, "Jp": i == 30 or i == 68, "J": (i > 30 and i < 42) or (i > 68 and i < 80)})

func cavalo() -> void:
	kill_enemies()
	put(40840, 500)
	g.RD._start()
	g.RD.hx = 33640.0
	g.RD.spd = 5.2
	g.snap_camera()
	await run(150, func(i):
		var d := {}
		for o in g.RD.OBS:
			var dx: float = o.x - g.RD.hx
			if dx < -140 or dx > 220:
				continue
			if o.k in ["log", "rock", "gap"] and dx < 80 and dx > 34 and g.RD.hy >= 500:
				d["Jp"] = true
				d["J"] = true
			if o.k in ["branch", "rope"] and dx < 130:
				d["S"] = true
			break
		return d)

func urso() -> void:
	# perseguição: o urso vem correndo atrás, o Tomé foge pulando o tronco
	kill_enemies()
	put(50460, 500)
	var b: Dictionary = g.K.BEAR
	b.active = true
	b.st = "chase"
	b.t = 40
	b.x = 50200.0
	b.dir = 1
	b.v = 5.0
	b.seen = true
	await run(200, func(i):
		var d := {"R": true}
		for o in g.K.BOBS:
			var dist: float = o.x - (g.player.x + g.player.w)
			if not o.get("fallen") and o.k != "branch" and dist > 0 and dist < abs(g.player.vx) * 7.0 + 6.0 and g.player.onGround:
				d["Jp"] = true
				d["J"] = true
		return d)

func noite() -> void:
	kill_enemies()
	put(78300, 500)
	g.lantern_lit = true
	g.VIL.go = true
	g.VIL.x = 78680.0
	await run(110, func(i): return {"R": true, "Jp": i == 45, "J": i > 45 and i < 58})

# ---------- ajudantes assíncronos (um passo de física por chamada, como o bot da rota) ----------
func fr(set: Dictionary = {}) -> void:
	hide_ui()
	g.flash_t = 0
	g.player.hp = 5
	for k in ["L", "R", "J", "S", "U", "A", "G", "P"]:
		g.keys[k] = false
	for k in set:
		g.keys[k] = set[k]
	await physics_frame
	P = g.player
	nf += 1
	if nf % 60 == 0 or OS.has_environment("CAPDBG"):
		print("f%d x=%d y=%d st=%s" % [nf, int(px()), int(g.player.y), str(main.state)])
	if nf > 2480:
		quit()

func press(k: String) -> void:
	g.keys[k + "p"] = true

func px() -> float:
	return g.player.x + g.player.w / 2

func hold(set: Dictionary, n: int) -> void:
	for i in n:
		await fr(set)

func until(set: Dictionary, cond: Callable, mx: int = 900) -> void:
	for i in mx:
		if cond.call():
			return
		await fr(set)

func wait_ground(set: Dictionary = {}, mx: int = 300) -> void:
	await until(set, func(): return g.player.onGround, mx)

func walk_to(x: float, mx: int = 900) -> void:
	for i in mx:
		if abs(px() - x) < 6 and g.player.onGround:
			return
		await fr({"R" if x > px() else "L": true})

func jump_to(x: float, dbl: bool = false, mx: int = 200) -> void:
	press("J")
	var used := false
	for i in mx:
		var d := {}
		if px() < x - 5:
			d = {"R": true}
		elif px() > x + 5:
			d = {"L": true}
		if dbl and not used and i > 14 and g.player.vy > -1:
			press("J")
			used = true
		d["J"] = i < 16 or (dbl and i < 34)
		await fr(d)
		if g.player.onGround and i > 3:
			return

func crawl(x: float, mx: int = 600) -> void:
	var dir := "R" if x > px() else "L"
	for i in mx:
		if (px() >= x) if dir == "R" else (px() <= x):
			return
		await fr({"S": true, dir: true})

func climb(dir: String, cond: Callable, mx: int = 600) -> void:
	await until({dir: true}, cond, mx)

func crevice() -> void:
	var dir := "R"
	press("J")
	await hold({"J": true, dir: true}, 10)
	for i in 24:
		await until({dir: true}, func(): return g.player.wsl > 0 or g.player.onGround, 90)
		if g.player.onGround:
			return
		press("J")
		await fr({"J": true})
		dir = "L" if dir == "R" else "R"
		await hold({"J": true}, 6)

func swing_off() -> void:
	for i in 600:
		var v = g.player.vine
		if v == null:
			break
		await fr({"R": true} if v.om > 0 else {"L": true})
		if v.th > .35 and v.om > 0:
			break
	press("J")
	await fr()

func vine_hop(next_vine) -> void:
	await swing_off()
	if next_vine == null:
		await wait_ground()
	else:
		await until({}, func(): return g.player.vine == next_vine or g.player.onGround, 120)

func grab_vine(v) -> void:
	press("J")
	for i in 120:
		if g.player.vine == v:
			return
		if i == 16:
			press("J")
		await fr({"J": i < 40, "R": true})

# ---------- trechos da versão 2 (mais jogabilidade) ----------
func fenda() -> void:
	kill_enemies()
	put(7080, 500)
	await hold({}, 20)
	await crawl(7270)
	await crevice()
	await walk_to(7440)
	await hold({}, 20)

func copas() -> void:
	kill_enemies()
	put(8400, -10)
	await hold({}, 15)
	await jump_to(8490)
	await walk_to(8545)
	await jump_to(8700, true)
	await walk_to(8745)
	await jump_to(8875)
	await jump_to(9040, true)
	await walk_to(9105)
	await jump_to(9200)
	await walk_to(9220)
	await until({}, func(): return g.player.onGround and g.player.y + g.player.h <= -250, 400)
	await walk_to(9515)
	await jump_to(9670)
	await walk_to(9730)
	await jump_to(9845)
	await jump_to(10010, true)
	await hold({}, 20)

func regias() -> void:
	kill_enemies()
	put(17620, 500)
	await hold({}, 10)
	await walk_to(17720)
	for x in [17846, 17996, 18146, 18310]:
		await jump_to(x)
	await walk_to(18420)
	for x in [18566, 18716, 18866, 18990]:
		await jump_to(x)
	await walk_to(19070)
	await grab_vine(g.VINES[1])
	await vine_hop(g.VINES[2])
	await vine_hop(g.VINES[3])
	await vine_hop(null)
	await walk_to(20190)

func corda() -> void:
	kill_enemies()
	put(20340, 500)
	await hold({}, 10)
	await walk_to(20430)
	await grab_vine(g.VINES[4])
	await swing_off()
	await until({}, func(): return g.player.get("bar") != null, 120)
	await until({"R": true}, func(): return px() > 21480, 600)
	press("J")
	await fr()
	await wait_ground()
	await walk_to(21640)

func mergulho() -> void:
	kill_enemies()
	put(15880, 500)
	await hold({}, 10)
	await until({"R": true, "S": true}, func(): return px() > 16190 and g.player.y > 600, 300)
	await until({"R": true}, func(): return px() > 17140, 600)

func bolaneve() -> void:
	kill_enemies()
	put(33200, 500)
	await hold({}, 10)
	await jump_to(33320, true)
	await until({"R": true}, func(): return g.NT.SNOWB[0].x + g.NT.SNOWB[0].w >= 33687, 900)
	await jump_to(33610)
	await jump_to(33750, true)
	await walk_to(34040)

func gelofino() -> void:
	kill_enemies()
	put(34510, 500)
	await hold({}, 6)
	for i in 2:
		var x: float = [27570.0, 28090.0][i]
		await walk_to(x)
		var o: Dictionary = g.TR.by_kind("roll")[1 + i]
		await until({}, func(): return o.st == "go" and o.bx - px() < 85, 400)
		press("J")
		await hold({"J": true}, 16)
		await wait_ground()
		await hold({}, 6)
	await walk_to(35735)
	for x in [28591, 28671, 28751, 28805]:
		await jump_to(x)
	await walk_to(36110)

func tunel() -> void:
	kill_enemies()
	put(71830, 500)
	g.lantern_lit = true
	await hold({}, 10)
	await crawl(72000)
	await walk_to(72105)
	await jump_to(72210)
	await jump_to(72360)
	await walk_to(72400)
	await jump_to(72600)
	await walk_to(72735)
	await jump_to(72810)
	await jump_to(72900)
	await jump_to(73000)
	await walk_to(73040)
	await crawl(73190)
	await walk_to(73260)
	for k in 6:
		g.crank_tap(g.CRANKS[0])
		await hold({}, 8)
	await walk_to(73400)

func cogumelo() -> void:
	kill_enemies()
	put(71220, 500)
	g.lantern_lit = true
	await hold({}, 10)
	await until({"R": true}, func(): return g.player.vy < -15, 300)
	var dj := false
	for i in 200:
		if not dj and g.player.vy > -1:
			press("J")
			dj = true
		await fr({"R": px() < 71370, "J": dj and i < 60})
		if dj and g.player.onGround:
			break
	await walk_to(71540)
	await until({}, func(): return g.player.onGround and g.player.y > 400, 200)
	await hold({}, 20)

# ---------- trechos da versão 3 (fases novas) ----------
func trap_at(k: String, x: float) -> Dictionary:
	var best: Dictionary = {}
	for o in g.TR.T:
		if o.k == k and (best.is_empty() or abs(o.x - x) < abs(best.x - x)):
			best = o
	return best

func jangada() -> void:
	kill_enemies()
	put(25510, 500)
	await hold({}, 4)
	press("A")
	await fr()
	var VH = g.VH
	VH.hx = 27620.0
	VH.spd = 5.0
	g.snap_camera()
	for it in 520:
		if VH.mode != "raft":
			break
		var d := {}
		var wl: float = VH.water_y(VH.hx)
		for f in VH.RA.falls:
			var df: float = f - VH.hx
			if df > 4 and df < 40 and VH.hy >= wl - 1:
				press("J")
				d["J"] = true
		for o in VH.OBS:
			var dx: float = o.x - VH.hx
			if dx < -140 or dx > 220:
				continue
			if o.k in ["rock", "log"] and dx < 70 and dx > 26 and VH.hy >= wl - 1:
				press("J")
				d["J"] = true
			if o.k == "branch" and dx < 130:
				d["S"] = true
			if dx > -40 or o.k == "branch":
				break
		await fr(d)

func vento() -> void:
	kill_enemies()
	put(53880, 360)
	await hold({}, 10)
	for it in 420:
		if px() > 55100:
			break
		var gusting := false
		for o in g.TR.T:
			if o.k == "gust" and g.TR.gust_state(o) > 0 and px() > o.x - 220 and px() < o.x + o.w + 40:
				gusting = true
		var step_up := false
		for s2 in g.SOL:
			if s2.t == "ground" and s2.x > px() and s2.x - px() < 40 and s2.y < P.y + P.h - 4 and P.onGround:
				step_up = true
		var edge := false
		for c in g.L.chasms:
			if c[0] - px() > 0 and c[0] - px() < 30 and P.onGround:
				edge = true
		if edge:
			if gusting:
				await fr({"S": true})
				continue
			press("J")
			for i in 40:
				await fr({"J": i < 18, "R": true})
				if P.onGround and i > 4:
					break
			continue
		if step_up:
			press("J")
			for i in 30:
				await fr({"J": i < 12, "R": true})
				if P.onGround and i > 4:
					break
			continue
		# na rajada fica abaixado um pouco para mostrar
		if gusting and g.TR.T.any(func(o): return o.k == "gust" and g.TR.gust_state(o) == 2 and px() > o.x and px() < o.x + o.w):
			await fr({"S": true})
		else:
			await fr({"R": true})

func ponte() -> void:
	kill_enemies()
	put(55520, 190)
	await hold({}, 10)
	var o: Dictionary = trap_at("bridge", 55660)
	var gaps: Array = []
	for gi in o.get("gaps", []):
		gaps.append(o.x + gi * 40.0)
	await fr({})
	await fr({"R": true})
	await fr({})
	var jt := 0
	for it in 400:
		if px() > o.x + o.w + 120 and P.onGround:
			break
		for gx in gaps:
			if gx - px() > 0 and gx - px() < 34 and P.onGround and jt <= 0:
				press("J")
				jt = 14
		jt -= 1
		await fr({"R": true, "J": jt > 0})
	await hold({}, 20)

func _obs_box(o: Dictionary) -> Array:
	match o.k:
		"flock":
			return [o.x - 30, o.x + 90, o.y - 26, o.y + 64]
		"cloud":
			return [o.x + 10, o.x + o.w - 10, o.y + 8, o.y + o.h - 8]
		"hawk":
			var ty: float = o.get("ty", o.y)
			if o.st in ["warn", "dive", "sweep"]:
				return [o.x - 400, o.x + 40, ty - 18, ty + 18]
	return []

func _free_spans(boxes: Array, top: float, low: float) -> Array:
	var spans := [[top, low]]
	for bx in boxes:
		var cut0: float = bx[2] + 6 - 14
		var cut1: float = bx[3] + 46 + 14
		var out := []
		for sp in spans:
			if sp[1] < cut0 or sp[0] > cut1:
				out.append(sp)
			else:
				if sp[0] < cut0:
					out.append([sp[0], cut0])
				if sp[1] > cut1:
					out.append([cut1, sp[1]])
		spans = out
	return spans

func voo() -> void:
	kill_enemies()
	put(57380, 190)
	await hold({}, 6)
	press("A")
	await fr()
	var VH = g.VH
	for it in 1500:
		if VH.mode != "plane":
			break
		if VH.phase != "fly":
			await fr()
			continue
		var groups := []
		var list := []
		for o in VH.OBS:
			var bx := _obs_box(o)
			if bx.is_empty() or bx[1] < VH.hx - 60 or bx[0] > VH.hx + 900:
				continue
			list.append(bx)
		list.sort_custom(func(a, b): return a[0] < b[0])
		for bx in list:
			if groups.is_empty() or bx[0] > groups.back()[0][0] + 120:
				groups.append([bx])
			else:
				groups.back().append(bx)
		var target: float = VH.hy
		if not groups.is_empty():
			var spans := _free_spans(groups[0], VH.PL.top + 10, VH.PL.low - 10)
			var nxt := []
			if groups.size() > 1:
				nxt = _free_spans(groups[1], VH.PL.top + 10, VH.PL.low - 10)
			var best := 1e9
			for sp in spans:
				for k in 9:
					var y: float = lerpf(sp[0], sp[1], k / 8.0)
					var c: float = abs(y - VH.hy)
					if not nxt.is_empty():
						var dn := 1e9
						for sp2 in nxt:
							dn = min(dn, 0.0 if (y >= sp2[0] and y <= sp2[1]) else min(abs(y - sp2[0]), abs(y - sp2[1])))
						c += dn * 2.0
					if c < best:
						best = c
						target = y
		var dd := {}
		if VH.hy > target + 5:
			dd["U"] = true
		elif VH.hy < target - 5:
			dd["S"] = true
		await fr(dd)

func bounce_to(bx: float) -> void:
	press("J")
	var launched := false
	for i in 300:
		if P.get("launchT", 0) > 0:
			launched = true
		var d := {}
		if not launched:
			if px() < bx - 4:
				d = {"R": true}
			elif px() > bx + 4:
				d = {"L": true}
			d["J"] = i < 16
		await fr(d)
		if launched and P.onGround:
			return

func cogumelos() -> void:
	kill_enemies()
	put(65080, 500)
	g.lantern_lit = true
	await hold({}, 10)
	await walk_to(65245)
	await bounce_to(65295)
	await hold({}, 8)
	await jump_to(65740)
	await bounce_to(65785)
	await hold({}, 8)
	await jump_to(66265)
	await jump_to(66450)
	await walk_to(66640)

func pedra() -> void:
	kill_enemies()
	put(73580, 500)
	g.lantern_lit = true
	await hold({}, 6)
	var o: Dictionary = trap_at("boulder", 73500)
	await until({"R": true}, func(): return o.st != "idle", 200)
	var obs: Array = []
	for sb in g.SOL:
		if sb.get("bob") and sb.bob != "barricade":
			obs.append(float(sb.x))
	for pit in g.L.pits:
		if pit[0] > o.x and pit[0] < o.end:
			obs.append(float(pit[0]))
	var niche: float = (o.niche[0] + o.niche[1]) / 2.0
	await fr({})
	await fr({"R": true})
	await fr({})
	var jt := 0
	for it in 900:
		if px() > niche - 70:
			break
		for ox in obs:
			var ahead: float = ox - (px() + P.w / 2)
			if ahead > 20 and ahead < 64 and P.onGround and jt <= 0:
				press("J")
				jt = 14
		jt -= 1
		await fr({"R": true, "J": jt > 0})
	for it in 400:
		if o.st in ["break", "done"]:
			break
		if px() > o.niche[0] + 14 and px() < o.niche[1] - 14 and P.onGround:
			await fr({"S": true})
		else:
			await fr({"R" if niche > px() else "L": true})
	await hold({}, 30)
	await jump_to(77140)
	await walk_to(77400)

func colmeia() -> void:
	kill_enemies()
	put(12000, 500)
	await hold({}, 8)
	await jump_to(12080)
	await hold({}, 12)
	await fr({})
	await fr({"L": true})
	await fr({})
	await until({"L": true}, func(): return px() < 11440, 260)
	await hold({}, 20)


# ---------- trechos de ação para o trailer (versão 2) ----------
## pula e, no alto do pulo, aperta ↓ (mergulho) e espera bater no chão
func slam_here() -> void:
	press("J")
	await fr({"J": true})
	for i in 40:
		await fr({"J": true})
		if g.player.vy > -2:
			break
	press("S")
	await fr()
	for i in 90:
		await fr()
		if g.player.onGround or g.player.ladder != null or g.player.y > 600:
			break

func stake_cross(sx: float) -> void:
	var st: Dictionary = {}
	for o in g.SL.STAKES:
		if abs(float(o.x) - sx) < 5:
			st = o
	if st.is_empty():
		return
	if px() < sx - 60:
		await walk_to(sx - 60)
	await jump_to(sx)
	await hold({}, 6)
	await slam_here()
	await until({}, func(): return st.done and st.lift >= 1.0, 400)
	await walk_to(float(st.bridge.x) + float(st.bridge.w) + 40)

func djump(dir: String) -> void:
	press("J")
	await hold({"J": true, dir: true}, 16)
	for i in 30:
		if g.player.vy >= -.5:
			break
		await fr({dir: true})
	press("J")
	await hold({"J": true, dir: true}, 16)
	await wait_ground({dir: true})

func a_inicio() -> void:
	kill_enemies()
	put(430, 500)
	await hold({}, 4)
	await walk_to(600)
	await crawl(870)
	await walk_to(980)
	await jump_to(1060)
	await jump_to(1170)
	await jump_to(1300)
	await walk_to(1480)
	await hold({}, 10)

func a_estaca() -> void:
	kill_enemies()
	put(2075, 500)
	await hold({}, 10)
	await stake_cross(2040)
	await hold({}, 10)

func a_escada() -> void:
	kill_enemies()
	put(2600, 500)
	await hold({}, 4)
	await cross_spikes(trap_at("spikes", 2640), 2780)
	await walk_to(2835)
	await climb("U", func(): return g.player.ladder == null and g.player.y < 100, 400)
	await hold({}, 14)
	await walk_to(2835)
	await climb("S", func(): return g.player.onGround and g.player.y > 400, 500)
	await walk_to(3000)

func cross_spikes(o: Dictionary, x_after: float) -> void:
	var per: int = o.get("per", 140)
	for i in 400:
		if (g.T + int(o.get("ph", 0))) % per == per / 2 + 8:
			break
		await fr()
	await walk_to(x_after)

func a_galho() -> void:
	kill_enemies()
	put(3690, 500)
	await hold({}, 6)
	await walk_to(3720)
	await djump("R")
	await walk_to(3910)
	await jump_to(4060, true)
	await walk_to(4185)
	press("J")
	await hold({"J": true, "R": true}, 16)
	await until({"R": true}, func(): return g.player.vine != null, 80)
	await swing_off()
	await wait_ground()
	await hold({}, 10)

func a_chao() -> void:
	kill_enemies()
	put(4500, 500)
	await hold({}, 6)
	await walk_to(4685)
	await hold({}, 10)
	await slam_here()
	await walk_to(4690)
	await climb("S", func(): return g.player.onGround and g.player.y > 800, 500)
	await walk_to(4900)

func a_planar() -> void:
	kill_enemies()
	put(9515, -280)
	await wait_ground()
	await hold({}, 6)
	press("J")
	await hold({"J": true, "R": true}, 18)
	for i in 400:
		if g.player.onGround and i > 4:
			break
		await fr({"R": true, "P": true})
	await hold({}, 12)

func a_regias() -> void:
	kill_enemies()
	put(12480, 500)
	await hold({}, 4)
	await walk_to(12575)
	for x in [12676, 12816, 12946, 13090]:
		await jump_to(x)
	await walk_to(13200)
	await jump_to(13330)
	await walk_to(13460)

func a_colmeia() -> void:
	kill_enemies()
	put(15790, 500)
	await hold({}, 8)
	await crawl(15955)
	await walk_to(16035)
	await until({"R": true, "S": true}, func(): return px() > 16190 and g.player.y > 600, 300)
	await hold({"R": true}, 90)

func a_noite() -> void:
	kill_enemies()
	put(64400, 500)
	g.lantern_lit = true
	await hold({}, 4)
	await walk_to(64460)
	var axe: Dictionary = g.TR.by_kind("axe")[0]
	await until({}, func(): g.TR.axe_blade(axe); return axe.ang > .35, 300)
	await jump_to(64800, true)
	await walk_to(64910)
	await jump_to(64975)
	if px() < 65000:
		await jump_to(65040, true)
	await walk_to(65245)
	await bounce_to(65295)
	await hold({}, 6)
	await bounce_to(65755)
	await hold({}, 6)
	await jump_to(66265)
	await jump_to(66450)
	await walk_to(66600)

func a_tabuas() -> void:
	kill_enemies()
	put(72110, 500)
	g.lantern_lit = true
	await hold({}, 6)
	await jump_to(72210)
	await jump_to(72360)
	await walk_to(72400)
	await jump_to(72600)
	await walk_to(72735)
	await jump_to(72810)
	await jump_to(72900)
	await jump_to(73000)
	await walk_to(73040)
	await hold({}, 10)


# ---------- Episódio 2 (As Profundezas da Mina) ----------
func use_k() -> void:
	press("A")
	await fr()
	await hold({}, 6)

## pula segurando PULAR (pulo duplo e plana até pousar)
func glide_to(x: float, mx: int = 400) -> void:
	press("J")
	var used := false
	for i in mx:
		var d := {}
		if px() < x - 5:
			d = {"R": true}
		elif px() > x + 5:
			d = {"L": true}
		if not used and i > 14 and g.player.vy > -1:
			press("J")
			used = true
		d["J"] = true
		await fr(d)
		if g.player.onGround and i > 3:
			return

func e2_boca() -> void:
	kill_enemies()
	put(380, 500)
	g.lantern_lit = true
	await hold({}, 6)
	await walk_to(600)
	await jump_to(720)
	await walk_to(1230)
	await walk_to(1385)
	for x in [1498, 1648, 1808, 1960]:
		await jump_to(x)
	await walk_to(2200)

func e2_estaca() -> void:
	kill_enemies()
	put(5700, 500)
	g.lantern_lit = true
	await hold({}, 8)
	await stake_cross(5800)
	await walk_to(6460)
	await jump_to(6560)
	await jump_to(6800, true)
	await hold({}, 10)

func e2_degraus() -> void:
	kill_enemies()
	put(7300, 500)
	g.lantern_lit = true
	await hold({}, 6)
	for x in [7540, 7700, 7850, 8000, 8120]:
		await jump_to(x)
	await walk_to(8500)

func e2_elevador() -> void:
	kill_enemies()
	put(4300, 500)
	g.lantern_lit = true
	await hold({}, 6)
	await walk_to(4328)
	var lf: Dictionary = g.MV.MV[0]
	await use_k()
	await until({}, func(): return lf.pos == lf.goal and lf.pos == 0.0, 600)
	await walk_to(4780)
	await hold({}, 10)

func e2_flor() -> void:
	kill_enemies()
	put(10780, 500)
	await hold({}, 6)
	await walk_to(10900)
	await jump_to(10950)
	await until({}, func(): return g.player.onGround and g.player.y < 250, 300)
	await walk_to(11235)
	await walk_to(11420)
	await hold({}, 10)

func e2_celeiro() -> void:
	kill_enemies()
	put(11400, 500)
	await hold({}, 6)
	await crawl(11660)
	await crawl(11840)
	await walk_to(12110)
	await hold({}, 10)

func e2_pedras() -> void:
	kill_enemies()
	put(12560, 500)
	await hold({}, 6)
	await walk_to(12640)
	for x in [12760, 12910, 13110]:
		await jump_to(x)
	await walk_to(13560)
	await hold({}, 20)

func house_list() -> Array:
	var out: Array = []
	for s in g.L.solids:
		if s.t == "house":
			var parts: Array = []
			var chims: Array = []
			for r in g.L.solids:
				if r.x < s.x - 2 or r.x + r.w > s.x + s.w + 2:
					continue
				if r.t == "roof" and r.get("chim"):
					chims.append(r)
				elif r.t == "roof" and r.get("walk"):
					parts.append(r)
				elif r.t == "plat" and r.get("roofhole"):
					chims.append({"x": r.x, "w": r.w, "h": 0})
			var x0: float = 1e9
			var x1: float = -1e9
			for r in parts:
				x0 = min(x0, float(r.x))
				x1 = max(x1, float(r.x) + float(r.w))
			var obs: Array = []
			var loose: Array = chims.filter(func(c): return not c.has("t"))
			if not loose.is_empty():
				var lx0: float = loose.map(func(c): return float(c.x)).min()
				var lx1: float = loose.map(func(c): return float(c.x) + float(c.w)).max()
				obs.append({"x": lx0, "w": lx1 - lx0, "h": 0})
			for c in chims:
				if c.has("t"):
					obs.append(c)
			obs.sort_custom(func(a, b): return float(a.x) < float(b.x))
			if not parts.is_empty():
				out.append({"h": s, "walk": {"x": x0, "w": x1 - x0, "y": float(parts[0].y)}, "chims": obs})
	return out

func roof_walk(x: float, chims: Array) -> void:
	for c in chims:
		var cx0: float = float(c.x)
		var cx1: float = float(c.x) + float(c.w)
		if cx0 > px() and cx0 < x:
			await walk_to(cx0 - 24)
			if c.get("hot"):
				var hc: Dictionary = {}
				for h in g.VL.HOT:
					if abs(float(h.x) - cx0) < 3:
						hc = h
				if not hc.is_empty():
					await until({}, func(): return g.VL.hot_phase(hc) == 0 and int((g.T + int(hc.get("ph", 0))) % int(hc.per)) < 20, 400)
			await jump_to(cx1 + 26, c.get("hot", 0) == 1 or float(c.get("h", 0)) > 50)
	await walk_to(x)

## telhados da vila: da casa a até a casa b (pulando de um telhado para o outro)
func roofs(a: int, b: int) -> void:
	kill_enemies()
	var HS := house_list()
	var w0: Dictionary = HS[a].walk
	put(float(w0.x) + 50, float(w0.y))
	await hold({}, 10)
	for i in range(a, b + 1):
		var hs: Dictionary = HS[i]
		var w: Dictionary = hs.walk
		var endx: float = w.x + w.w - 14
		for c in hs.chims:
			if float(c.x) + float(c.w) > endx - 40:
				endx = float(c.x) - 24
		await roof_walk(endx, hs.chims)
		if i == b or i + 1 >= HS.size():
			break
		var nw: Dictionary = HS[i + 1].walk
		if float(nw.y) < float(w.y) - 150:
			break
		var land: float = nw.x + 40
		for c in HS[i + 1].chims:
			if float(c.x) < land + 30 and float(c.x) + float(c.w) > nw.x:
				land = float(c.x) + float(c.w) + 30
		if nw.x - px() < 250:
			await jump_to(land, true)
		else:
			await glide_to(land + 20)
		var bb = g.player.get("bar")
		if bb != null:
			await until({"R": true}, func(): return px() > float(bb.x1) - 40, 400)
			press("J")
			await jump_to(nw.x + 50)
		var gs = g.player.get("_g")
		if gs is Dictionary and gs.get("tile"):
			await jump_to(nw.x + 40)
	await hold({}, 12)

func e2_telhados1() -> void:
	await roofs(0, 2)

func e2_telhados2() -> void:
	await roofs(3, 6)

func e2_fundo() -> void:
	kill_enemies()
	var D0: float = float(g.L.sections[3].x) - 420.0
	put(D0 + 300, 500)
	g.lantern_lit = true
	await hold({}, 6)
	await walk_to(D0 + 800)
	await jump_to(D0 + 900)
	await walk_to(D0 + 1100)
	await hold({}, 10)

## a fuga da Isis (sem o lampião do Vargas por perto)
func isis_start(x: float) -> void:
	kill_enemies()
	g.begin_isis()
	await fr()
	g.player.x = x - 10
	g.player.y = 500 - 26 - 2
	g.player.vx = 0
	g.player.vy = 0
	g.player.spawnX = g.player.x
	g.player.spawnY = g.player.y
	g.snap_camera()
	g.lantern_lit = true
	await hold({}, 8)

func e2_isis_quarto() -> void:
	var IX: float = float(g.L.isisPart.spawn[0]) - 170.0
	kill_enemies()
	g.begin_isis()
	await hold({}, 20)
	await walk_to(IX + 650)
	await hold({}, 10)

func e2_isis_poco() -> void:
	var IX: float = float(g.L.isisPart.spawn[0]) - 170.0
	await isis_start(IX + 2120)
	await walk_to(IX + 2140)
	for x in [2216, 2336, 2456, 2610]:
		await jump_to(IX + x)
	await walk_to(IX + 2785)
	var mv: Dictionary = {}
	for o in g.MV.MV:
		if o.k == "path" and absf(float(o.x0) - (IX + 2815)) < 3:
			mv = o
	if not mv.is_empty():
		var pl: Dictionary = mv.plats[0]
		await until({}, func(): return float(pl.x) < IX + 2830 and float(pl.dx) >= 0, 900)
		await jump_to(float(pl.x) + 50)
		await until({}, func(): return float(pl.x) + float(pl.w) > IX + 3240, 600)
		await jump_to(IX + 3400)
	await hold({}, 10)

func e2_isis_corda() -> void:
	var IX: float = float(g.L.isisPart.spawn[0]) - 170.0
	await isis_start(IX + 3420)
	await walk_to(IX + 3488)
	press("J")
	await until({"J": true}, func(): return g.player.get("bar") != null, 60)
	var bb = g.player.get("bar")
	if bb != null:
		await until({"R": true}, func(): return px() > float(bb.x1) - 40, 500)
		press("J")
		await jump_to(IX + 3960)
	await walk_to(IX + 4280)
	await crawl(IX + 4820)
	await hold({}, 12)

## o moinho girando: põe a vela nova, sobe numa tábua das pás e vai lá para cima
func e2_moinho() -> void:
	kill_enemies()
	put(13420, 500)
	g.give_item("vela")
	await hold({}, 8)
	await walk_to(13620)
	await use_k()
	await hold({}, 30)
	await walk_to(13600)
	var wh: Dictionary = {}
	for o in g.MV.MV:
		if o.k == "wheel":
			wh = o
	var target = null
	for i in 1500:
		for s in wh.plats:
			if s.y > 360 and abs(s.x + s.w / 2 - px()) < 140 and s.dx < 0:
				target = s
		if target != null:
			break
		await fr()
	if target == null:
		return
	press("J")
	for i in 120:
		var d := {"J": i < 16}
		if px() < target.x + target.w / 2 - 6:
			d["R"] = true
		elif px() > target.x + target.w / 2 + 6:
			d["L"] = true
		await fr(d)
		if g.player.onGround and g.player.get("_g") == target:
			break
	for i in 1400:
		await fr()
		if g.player.get("_g") != target:
			break
		if target.y < -150 + 40 and target.x + target.w > 14000 - 260 and target.dx > 0:
			break
	await glide_to(14080)
	await hold({}, 20)
