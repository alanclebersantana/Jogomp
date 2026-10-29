extends SceneTree
## Filme quadro a quadro das sequências especiais (cavalo, trenó, jangada, avião, carrinho).
## Uso: godot --path . -s tests/veh_film.gd -- <ride|sled|raft|plane|cart> <pular> <quadros> <cada> [manual]
## Salva PNGs em $FILM (padrão /tmp/fh_film). O piloto automático é o mesmo do tests/route.gd
## (pula e abaixa na hora certa); "manual" deixa sem piloto (para ver batidas e recomeços).
var g
var main
var mode := ""
var hold_keys := {}

func _initialize() -> void:
	var dir: String = OS.get_environment("FILM") if OS.get_environment("FILM") != "" else "/tmp/fh_film"
	DirAccess.make_dir_recursive_absolute(dir)
	for f in DirAccess.get_files_at(dir):
		DirAccess.remove_absolute(dir + "/" + f)
	var args := OS.get_cmdline_user_args()
	mode = args[0]
	var skip := int(args[1])
	var n := int(args[2])
	var every := int(args[3])
	var manual: bool = args.size() > 4 and args[4] == "manual"
	var keyscript: String = args[5] if args.size() > 5 else ""
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	for i in 3:
		await process_frame
	main.start_level(false, 1 if mode == "cart" else 0)
	await process_frame
	if main.panel and main.panel.has_meta("ok"):
		main.panel.get_meta("ok").call()
		await process_frame
	for c in main.ui_layer.get_children():
		if c.has_method("_end"):
			c._end()
	await process_frame
	main.panel.get_meta("ok").call()
	g = main.game
	g.lives = 99
	g.clue_opened.disconnect(main._on_clue)
	for cid in ["cipo", "mergulho", "neve", "pipoca", "picareta", "cavalo", "mina", "toxico", "javali", "gaviao", "bagre", "urso", "vargas", "bola", "aviao", "jangada", "colmeia", "moinho", "telhados", "carrinho", "sapo", "morcego", "brutus", "vigia"]:
		root.get_node("Save").setv("comic", cid, true)
	for e in g.EN:
		e.dead = 99
	main.set_physics_process(false)
	var p: Dictionary = g.player
	match mode:
		"ride":
			p.x = float(g.RD.H.x) - 40
			p.y = 500 - p.h
			g.RD._start()
		"raft":
			p.x = float(g.VH.RA.x) - 12
			p.y = 500 - p.h
			g.VH._start_raft()
		"sled", "cart":
			p.x = float(g.VH.SL.x) - 12
			p.y = float(g.VH.SL.y) - p.h
			g.VH._start_sled()
		"plane":
			p.x = float(g.VH.PL.x) - 12
			p.y = float(g.VH.PL.y) - p.h
			g.VH._start_plane()
	g.snap_camera()
	var acts: Array = []
	if keyscript != "":
		for a in keyscript.split(";"):
			var kv = a.split("@")
			var fr = kv[1].split("-")
			acts.append({"k": kv[0], "a": int(fr[0]), "b": int(fr[1]) if fr.size() > 1 else int(fr[0])})
	var shot := 0
	for f in skip + n * every:
		# FILM_STOP=x: piloto automático só até x (para ver o que acontece sem apertar nada dali em diante)
		var stop_x: float = float(OS.get_environment("FILM_STOP")) if OS.get_environment("FILM_STOP") != "" else 1e9
		var cur_x: float = g.RD.hx if mode == "ride" else g.VH.hx
		var d := {} if (manual or cur_x > stop_x) else _auto()
		for a in acts:
			if a.k.length() == 2 and a.k.ends_with("p"):
				if f == a.a:
					g.keys[a.k] = true
			elif f >= a.a and f <= a.b:
				d[a.k] = true
		for k in ["L", "R", "J", "S", "U"]:
			g.keys[k] = d.get(k, false)
		g.player.hp = max(g.player.hp, 1) if manual else 3
		# câmera lenta como no main.gd: um passo sim, outro não
		var skip_step := false
		if g.slowmo > 0:
			g.slowmo -= 1
			skip_step = g.slowmo % 2 == 1
		if not skip_step:
			g.step()
		while not g.CINE.is_empty():
			g.step()
		if f >= skip and (f - skip) % every == 0:
			g.ip_div = 1
			g.ip_phase = 1
			await process_frame
			await process_frame
			root.get_texture().get_image().save_png("%s/f%04d.png" % [dir, shot])
			shot += 1
	print("FILM ", shot)
	quit()

func press(k: String) -> void:
	g.keys[k + "p"] = true

## piloto automático (o mesmo jeito do tests/route.gd)
func _auto() -> Dictionary:
	var d := {}
	if mode == "ride":
		var RD = g.RD
		if not RD.riding:
			return d
		for o in RD.OBS:
			var dx: float = o.x - RD.hx
			if dx < -200 or dx > 260:
				continue
			if o.k in ["log", "rock", "gap", "fence", "logs", "leap"] and not o.hit and RD.hy >= 500:
				var tk: float = RD.takeoff_x(o)
				if RD.hx >= tk - 3 and RD.hx < tk + 6:
					press("J")
					d["J"] = true
			if o.k in ["branch", "rope"] and dx < 110 and dx > -130:
				d["S"] = true
			if dx > -40:
				break
		return d
	var VH = g.VH
	if VH.mode == "raft":
		var wl: float = VH.water_y(VH.hx)
		for f in VH.RA.falls:
			var df: float = f - VH.hx
			if df > 4 and df < 40 and VH.hy >= wl - 1:
				press("J")
				d["J"] = true
		for o in VH.OBS:
			var dx: float = o.x - VH.hx
			if dx < -240 or dx > 220 or o.k == "rapid":
				continue
			if o.k in ["rock", "log"] and dx < 70 and dx > 26 and VH.hy >= wl - 1:
				press("J")
				d["J"] = true
			var dw: float = VH.DUCK_W.get(o.k, 0.0)
			if dw > 0 and dx < 120 and dx > -(dw + 36):
				d["S"] = true
			if dx > -40:
				break
	elif VH.mode == "sled":
		var ground: bool = VH.hy >= VH.sled_y(VH.su) - 1
		for o in VH.OBS:
			var dx: float = o.x - VH.hx
			if o.hit or o.k == "bump" or o.k == "kick" or dx < -140 or dx > 300:
				continue
			if o.k in ["rock", "log"] and ground and dx < VH.spd * 9.0 + 24 and dx > 30:
				press("J")
			if o.k == "crack" and ground and dx < 40 and dx > -5:
				press("J")
			if o.k == "branch" and dx < 110 and dx > -100:
				d["S"] = true
			break
		if not VH._kick_at(VH.su).is_empty():
			d["J"] = true
	elif VH.mode == "plane" and VH.phase == "fly":
		var target: float = VH.hy
		var best := 1e9
		for o in VH.OBS:
			if o.x < VH.hx - 60 or o.x > VH.hx + 700 or o.hit:
				continue
			var oy: float = o.y + (o.h * .5 if o.k == "cloud" else 20.0)
			if o.k == "hawk":
				oy = o.get("ty", o.y)
			for y in [VH.PL.top + 40.0, 0.0, 200.0, VH.PL.low - 30.0]:
				var c: float = -abs(y - oy) + abs(y - VH.hy) * .3
				if abs(y - oy) > 120 and c < best:
					best = c
					target = y
			break
		if VH.hy > target + 5:
			d["U"] = true
		elif VH.hy < target - 5:
			d["S"] = true
	return d
