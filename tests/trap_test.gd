extends SceneTree
## Testes das armadilhas e saltos novos (sem tela). Uso: godot --headless -s tests/trap_test.gd
var g
var fails := 0

func say(name: String, ok: bool, extra: String = "") -> void:
	if not ok:
		fails += 1
	print(("· " if ok else "✗ ") + name + ("  " + extra if extra != "" else ""))

func frame(set: Dictionary = {}) -> void:
	for k in ["L", "R", "J", "P", "S", "U", "A", "G", "D"]:
		g.keys[k] = false
	for k in set:
		g.keys[k] = set[k]
	g.step()
	while not g.CINE.is_empty():
		g.step()

func put(x: float, y: float) -> void:
	g.M.ctrl = false
	g.player = g.make_body(x - 12, y - 34)
	g.player.spawnX = g.player.x
	g.player.spawnY = g.player.y
	g.snap_camera()

func _initialize() -> void:
	g = load("res://scripts/game.gd").new()
	root.add_child(g)
	g.load_level(0)
	g.no_coal = true
	g.lives = 99
	for e in g.EN:
		if e.k != "plant":
			e.dead = 99

	# 1) cogumelos em cadeia: cai no primeiro e termina no galho alto
	put(2915, 420)
	var path := []
	var landed := false
	for i in 400:
		frame()
		if i % 12 == 0:
			path.append("(%d,%d)" % [int(g.player.x + 12), int(g.player.y + 34)])
		if g.player.onGround and g.player.y + 34 <= 61 and i > 20:
			landed = true
			break
	say("cogumelos levam ao galho alto", landed, " ".join(path))

	# 2) flor-catapulta
	put(3855, 440)
	landed = false
	path = []
	for i in 400:
		frame()
		if i % 12 == 0:
			path.append("(%d,%d)" % [int(g.player.x + 12), int(g.player.y + 34)])
		if g.player.onGround and g.player.y + 34 <= 231 and g.player.x + 12 > 3970 and i > 40:
			landed = true
			break
	say("flor lança ao galho dos lápis", landed, " ".join(path))

	# 3) espinhos machucam quando sobem
	put(4326, 500)
	var hp0: int = g.player.hp
	for i in 200:
		frame()
	say("espinhos machucam", g.player.hp < hp0 or g.lives < 99)
	g.player.hp = 3

	# 4) picareta cravada no tronco vira degrau
	put(4720, 500)
	g.player.face = 1
	for i in 5:
		frame()
	g.keys["Gp"] = true
	frame({"U": true})
	var stuck := false
	for i in 60:
		frame()
		if not g.TR.PICK.is_empty() and g.TR.PICK.st == "stuck":
			stuck = true
			break
	say("picareta cravou", stuck, str(g.TR.PICK.get("x", 0)) + "," + str(g.TR.PICK.get("y", 0)))
	g.keys["Gp"] = true
	frame()
	for i in 60:
		frame()
	say("picareta voltou", g.TR.PICK.is_empty())

	# 5) machado machuca
	put(64640, 500)
	hp0 = g.player.hp
	for i in 160:
		frame()
		if g.player.hp < hp0:
			break
	say("machado machuca", g.player.hp < hp0)
	g.player.hp = 3

	# 6) galho que quebra
	put(12740, 330)
	for i in 80:
		frame()
	say("galho quebrou", g.TR.T[7].st == "fall")

	# 7) rede: Pipoca rói a corda
	g.X.DOG.st = "follow"
	g.X.DOG.x = 71030.0
	g.X.DOG.y = 500.0
	g.X.TRAIL = [Vector2(71030, 500)]
	put(71040, 500)
	for i in 30:
		frame({"R": true})
	say("rede segura o Tomé", g.player.x + 24 < 71102, str(int(g.player.x)))
	say("Pipoca disponível", g.X.dog_free())
	g.keys["Dp"] = true
	frame()
	say("virou Pipoca", g.M.ctrl)
	for i in 120:
		if abs(g.player.x + g.player.w / 2 - 71065) < 8:
			break
		frame({"R" if g.player.x + 15 < 71065 else "L": true})
	g.keys["Ap"] = true
	frame()
	for i in 10:
		frame()
	say("rede caiu", g.TR.T[9].st == "down")
	g.keys["Dp"] = true
	frame()

	# 8) jaula
	put(71160, 500)
	for i in 60:
		frame({"R": true})
	say("jaula prendeu", g.TR.trapped != null)
	for i in 30:
		frame({"R": true})
	say("preso não anda", g.player.x < 71200 + 64)
	g.keys["Dp"] = true
	frame()
	say("Pipoca no controle", g.M.ctrl)
	for i in 200:
		if abs(g.player.x + g.player.w / 2 - 71162) < 10:
			break
		frame({"R" if g.player.x + 15 < 71162 else "L": true})
	g.keys["Ap"] = true
	frame()
	for i in 5:
		frame()
	say("Pipoca soltou a jaula", g.TR.trapped == null)
	var why: String = g.M.dog_ok_now() + " y=%d vy=%.1f gr=%s x=%d" % [g.player.y, g.player.vy, g.player.onGround, g.player.x]
	g.keys["Dp"] = true
	frame()
	say("voltou ao Tomé", not g.M.ctrl, why)

	# 10) pedra rolando (bola de neve da descida)
	var rl: Dictionary = g.TR.by_kind("roll")[0]
	put(float(rl.trig) - 120.0, 500)
	for i in 60:
		frame({"R": true})
	var P = g.player
	say("pedra começou a rolar", rl.st == "go", rl.st + " x=%d y=%d" % [P.x, P.y])
	print("FALHAS: %d" % fails)
	quit()
