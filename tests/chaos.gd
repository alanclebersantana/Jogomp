extends "res://tests/route.gd"
## Robô do caos: joga errado de propósito (teclas aleatórias, pula à toa, volta, abaixa, usa coisas)
## a partir de cada fogueira, procurando: cair para fora do mapa sem morrer, ficar preso dentro de
## parede, travar o jogo (passo demorado) e erros de script (aparecem no log).
##   godot --headless --path . -s tests/chaos.gd -- [semente] [quadros por fogueira]

func _initialize() -> void:
	g = load("res://scripts/game.gd").new()
	root.add_child(g)
	g.load_level(0)
	g.lives = 99
	var args := OS.get_cmdline_user_args()
	var seed_v: int = int(args[0]) if args.size() > 0 else 7
	var per: int = int(args[1]) if args.size() > 1 else 900
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_v
	var keys := ["L", "R", "J", "S", "U", "A", "G"]
	var probs := 0
	var slow := 0
	var starts: Array = g.L.checks.map(func(c): return Vector2(c[0], c[1]))
	for st in starts:
		g.lives = 99
		g.CINE = {}
		g.VH.mode = ""
		var p: Dictionary = g.player
		p.x = st.x - 12
		p.y = st.y - 40
		p.vx = 0
		p.vy = 0
		p.hp = 5
		p.vine = null
		p.ladder = null
		g.snap_camera()
		var hold_k := {}
		var hold_t := 0
		var out_t := 0
		var wall_t := 0
		for i in per:
			if hold_t <= 0:
				hold_k = {}
				for k in keys:
					if rng.randf() < (.35 if k in ["L", "R"] else .12):
						hold_k[k] = true
				if hold_k.has("J") and rng.randf() < .5:
					press("J")
				if hold_k.has("A"):
					press("A")
				if hold_k.has("G"):
					press("G")
				hold_t = rng.randi_range(4, 50)
			hold_t -= 1
			var t0 := Time.get_ticks_usec()
			frame(hold_k)
			var dt := (Time.get_ticks_usec() - t0) / 1000.0
			if dt > 250.0:
				slow += 1
				print("LENTO %.0f ms perto de x=%d" % [dt, int(g.player.x)])
			p = g.player
			# caiu para baixo do mapa e não morreu
			if p.y > g.L.bottom + 150 and p.dyingT == 0 and not (g.VH.mode == "sled"):
				out_t += 1
				if out_t == 90:
					probs += 1
					print("FORA DO MAPA a partir da fogueira x=%d: x=%d y=%d" % [int(st.x), int(p.x), int(p.y)])
			else:
				out_t = 0
			# preso dentro de algo sólido
			var inside := false
			if p.dyingT == 0 and not p.get("dog") and not p.swim and p.ladder == null and p.vine == null and g.VH.mode == "" and not g.RD.riding:
				for s in g.SOL:
					if s.get("oneway") or s.get("deco") or s.get("boat") or str(s.get("t", "")) in ["branch", "plat", "seat", "trunk", "ice"]:
						continue
					if p.x + 4 < s.x + s.w and p.x + p.w - 4 > s.x and p.y + 6 < s.y + s.h and p.y + p.h - 6 > s.y:
						inside = true
						break
			wall_t = wall_t + 1 if inside else 0
			if wall_t == 60:
				probs += 1
				print("PRESO NA PAREDE a partir da fogueira x=%d: x=%d y=%d" % [int(st.x), int(p.x), int(p.y)])
	print("CAOS: %d problema(s), %d passo(s) lento(s)" % [probs, slow])
	print("FALHAS: ", probs)
	quit()
