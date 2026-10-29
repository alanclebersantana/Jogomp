extends SceneTree
## Jangada sempre na margem certa: embarcar, voltar à fogueira (pausa ou morte) e embarcar de novo;
## e depois de terminar a corredeira, voltar à fogueira de antes do rio (sem acender a seguinte).
## Uso: godot --headless -s tests/raft_test.gd
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

func st() -> String:
	return "modo=%s feita=%s px=%s na_lista=%s p=(%d,%d)" % [g.VH.mode, g.VH.raft_done, g.VH.RA.get("px"), g.SOL.has(g.VH.RAFT_SOL), int(g.player.x), int(g.player.y)]

## anda para a direita até embarcar (falha se morrer antes)
func board(maxf: int = 600) -> bool:
	for i in maxf:
		frame({"R": true})
		if g.VH.mode == "raft":
			return true
		if g.player.dyingT > 0:
			for j in 80:
				frame()
			return false
	return false

func _initialize() -> void:
	g = load("res://scripts/game.gd").new()
	root.add_child(g)
	g.load_level(0)
	g.no_coal = true
	g.lives = 99
	for e in g.EN:
		e.dead = 99
	var fire: Array = []
	for c in g.L.checks:
		if float(c[0]) < float(g.VH.RA.x0) and float(c[0]) > float(g.VH.RA.x0) - 400:
			fire = c
	put(float(fire[0]), float(fire[1]))
	say("embarca na jangada", board(), st())
	for i in 90:
		frame()
	g._back_to_fire()
	say("voltou à fogueira: jangada no cais", not g.VH.raft_done and g.SOL.has(g.VH.RAFT_SOL), st())
	say("embarca de novo", board(), st())
	for i in 200:
		frame()
	g.die("teste")
	for i in 120:
		frame()
	say("morreu no rio: jangada no cais", g.SOL.has(g.VH.RAFT_SOL), st())
	say("embarca depois de morrer", board(), st())
	# corredeira inteira (pulando sempre) e volta para a fogueira antes do rio
	var n := 0
	while g.VH.mode == "raft" and n < 5000:
		frame({"J": n % 30 < 2})
		g.player.hp = 3
		n += 1
	say("termina a corredeira", g.VH.raft_done, st())
	for i in 3:
		frame()
	g._back_to_fire()
	say("fogueira antes do rio depois de terminar: jangada de volta no cais", not g.VH.raft_done and g.SOL.has(g.VH.RAFT_SOL) and abs(float(g.VH.RA.px) - float(g.VH.RA.x)) < 1.0, st())
	var fence := false
	for s in g.SOL:
		if s.get("id") == "raftfence":
			fence = true
	say("sem a cerca do fim do rio", not fence)
	say("embarca de novo depois de terminar", board(), st())
	print("FALHAS: ", fails)
	quit()
