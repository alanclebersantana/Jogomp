extends SceneTree
## Brejo das vitórias-régias: o Pipoca nunca fica "no ar" em cima de folha que afundou ou sumiu,
## e as folhas voltam a boiar. Uso: godot --headless -s tests/lily_dog_test.gd
var g
var fails := 0
var bad := 0
var worst := ""

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
	_check()

## o cachorro parado (sem pulo) em cima da água do brejo precisa ter onde pisar
func _check() -> void:
	var D: Dictionary = g.X.DOG
	if D.get("st", "") not in ["follow", "sit"] or D.has("jmp") or abs(float(D.get("hy", 0.0))) > .5:
		return
	if g.X._dog_over_swamp(D.x, D.y) and not g.X._dog_supported(D.x, D.y):
		bad += 1
		if worst == "":
			worst = "T=%d dog=(%d,%d) st=%s" % [g.T, int(D.x), int(D.y), D.st]

func put(x: float, y: float) -> void:
	g.M.ctrl = false
	g.player = g.make_body(x - 12, y - 34)
	g.player.spawnX = g.player.x
	g.player.spawnY = g.player.y
	g.snap_camera()

## pula da posição atual até a folha/margem em tx (anda e pula no momento certo)
func hop_to(tx: float, maxf: int = 200) -> bool:
	var jumped := false
	var jt := 0
	for i in maxf:
		var p: Dictionary = g.player
		var pcx: float = p.x + p.w / 2
		var dir := "R" if tx > pcx else "L"
		var k := {}
		if abs(tx - pcx) > 6:
			k[dir] = true
		if p.onGround and not jumped and abs(tx - pcx) > 40:
			jumped = true
			jt = 14
			k["Jp"] = true
		if jt > 0:
			k["J"] = true
			jt -= 1
		frame(k)
		if g.player.dyingT > 0:
			return false
		if jumped and g.player.onGround and abs(tx - (g.player.x + 12)) < 30:
			for j in 4:
				frame()
			return true
	return false

func _initialize() -> void:
	g = load("res://scripts/game.gd").new()
	root.add_child(g)
	g.load_level(0)
	g.no_coal = true
	g.lives = 99
	for e in g.EN:
		e.dead = 99
	put(12560, 500)
	g.X.DOG.st = "follow"
	g.X.DOG.x = 12480.0
	g.X.DOG.y = 500.0
	g.X.TRAIL = [Vector2(12480, 500), Vector2(12560, 500)]
	g.X.DOG.i = 0
	for i in 40:
		frame()
	var lil: Array = g.LILY.filter(func(l): return l.x > 12500 and l.x < 13000)
	lil.sort_custom(func(a, b): return a.x < b.x)
	var ok := true
	for l in lil:
		ok = ok and hop_to(l.x + l.w / 2)
		for i in 20:
			frame()
	say("Tomé atravessa as vitórias-régias", ok, "p=(%d,%d)" % [int(g.player.x), int(g.player.y)])
	# fica parado na última folha até ela afundar: pula para o tronco antes de cair
	var sunk := false
	for i in 200:
		frame()
		if lil.back().st != 0:
			sunk = true
			break
	say("folha afunda com o Tomé parado", sunk)
	ok = hop_to(13120)
	say("Tomé chega no tronco", ok, "p=(%d,%d)" % [int(g.player.x), int(g.player.y)])
	# todas as folhas somem com o Pipoca no meio do caminho
	for l in lil:
		l.st = 2
		l.tm = 300
	for i in 260:
		frame()
	var D: Dictionary = g.X.DOG
	say("o Pipoca nunca fica no ar sobre folha sumida", bad == 0, "%d quadros  %s  dog=(%d,%d) st=%s" % [bad, worst, int(D.x), int(D.y), D.st])
	# as folhas voltam a boiar (com mola) e seguram de novo
	for i in 120:
		frame()
	var back := true
	for l in lil:
		back = back and l.st == 0
	say("folhas voltam a boiar", back)
	print("FALHAS: ", fails)
	quit()
