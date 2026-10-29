extends RefCounted
class_name Props
## Objetos com física simples que dão vida ao cenário:
## - o barco do canal: boia na água, balança, afunda um pouco com o peso do Tomé e, quando a comporta
##   escoa o canal, desce junto e fica encalhado em cima das pedras (vira uma ponte);
## - a mesa da varanda: assentada no chão, escorrega quando o Tomé esbarra e tomba com a picareta,
##   espalhando os papéis da Isis.

var g  # Game
var BOAT := {}
var TABLE := {}
var PAPERS: Array = []

const BOAT_W := 112.0
const BOAT_HULL := 26.0      # altura do casco
const BOAT_DRAFT := 12.0     # quanto do casco fica debaixo d'água
const TABLE_W := 104.0
const TABLE_H := 50.0

func _init(game) -> void:
	g = game

func load_level() -> void:
	_sup_n = -1
	BOAT = {}
	TABLE = {}
	PAPERS = []
	var bd = g.L.get("boat")
	if bd is Dictionary:
		var canal = null
		for s in g.SWAMP:
			if s.get("id") == bd.get("water", "canal"):
				canal = s
		if canal:
			BOAT = {"x": float(bd.x), "w": BOAT_W, "y": canal.y - (BOAT_HULL - BOAT_DRAFT), "vy": 0.0, "water": canal,
				"sink": 0.0, "ang": 0.0, "grounded": false, "post": bd.get("post", [canal.x - 30, 500]),
				"sol": {"t": "boat", "x": float(bd.x) + 8, "y": 0.0, "w": BOAT_W - 16, "h": 14, "boat": 1}}
			_boat_place()
			g.SOL.append(BOAT.sol)
	var td = g.L.get("table")
	if td is Dictionary:
		TABLE = {"x": float(td.x), "y": float(td.y) - TABLE_H, "vx": 0.0, "vy": 0.0, "ang": 0.0, "va": 0.0, "dir": 1, "st": "up", "hit": 0}
		for i in 5:
			PAPERS.append({"x": TABLE.x + 14 + i * 18.0, "y": TABLE.y - 2, "vx": 0.0, "vy": 0.0, "r": (i - 2) * .12, "vr": 0.0,
				"on": "table", "c": i})
		# duas folhas já no chão, deitadas
		PAPERS.append({"x": TABLE.x - 18, "y": float(td.y) - 1, "vx": 0.0, "vy": 0.0, "r": .05, "vr": 0.0, "on": "ground", "c": 5})
		PAPERS.append({"x": TABLE.x + TABLE_W + 12, "y": float(td.y) - 1, "vx": 0.0, "vy": 0.0, "r": -.08, "vr": 0.0, "on": "ground", "c": 6})

# ======================================================================
#  BARCO
# ======================================================================
## topo da pedra / chão mais alto embaixo do barco (para encalhar)
## (os sólidos que podem apoiar ficam guardados em faixas de 512 px; a lista só é refeita quando
## g.SOL muda de tamanho — antes o barco percorria todos os sólidos da fase a cada passo)
var _sup_n := -1
var _sup := {}
func _support_cells() -> Dictionary:
	if g.SOL.size() != _sup_n:
		_sup_n = g.SOL.size()
		_sup = {}
		for s in g.SOL:
			if s.get("boat") or s.get("deco") or not str(s.get("t", "")) in ["stone", "ground", "dirt"]:
				continue
			for c in range(int(floor(s.x / 512.0)), int(floor((s.x + s.w) / 512.0)) + 1):
				if not _sup.has(c):
					_sup[c] = []
				_sup[c].append(s)
	return _sup

func _support_under(x0: float, x1: float, y: float) -> float:
	var best := INF
	var cells := _support_cells()
	for c in range(int(floor(x0 / 512.0)), int(floor(x1 / 512.0)) + 1):
		for s in cells.get(c, []):
			if s.x < x1 and s.x + s.w > x0 and s.y >= y - 4 and s.y < best:
				best = s.y
	return best

func _boat_place() -> void:
	var b: Dictionary = BOAT
	var w: Dictionary = b.water
	var target: float = w.y - (BOAT_HULL - BOAT_DRAFT) + b.sink
	var bob: float = 0.0 if b.grounded else sin(g.T * .045) * 1.6
	var sup: float = _support_under(b.x + 10, b.x + b.w - 10, b.y + BOAT_HULL - 8)
	b.grounded = sup < INF and target + BOAT_HULL >= sup - 1
	if b.grounded:
		target = sup - BOAT_HULL - 1
		bob = 0.0
	b.y = lerpf(b.y, target, .12)
	b.vis_y = b.y + bob
	b.sol.x = b.x + 10
	b.sol.y = b.y + 2 + bob
	# inclina um pouco: encalhado fica torto; boiando, balança
	var want_ang: float = .06 if b.grounded else sin(g.T * .03) * .03
	b.ang = lerpf(b.ang, want_ang, .05)

func _boat_post() -> void:
	if BOAT.is_empty():
		return
	var p: Dictionary = g.player
	var on: bool = p._g == BOAT.sol
	var want_sink: float = 4.0 if (on and not BOAT.grounded) else 0.0
	BOAT.sink = lerpf(BOAT.sink, want_sink, .15)
	var oy: float = BOAT.sol.y
	_boat_place()
	# quem está em cima acompanha o barco
	if on:
		p.y += BOAT.sol.y - oy
		# rangido da madeira de vez em quando
		if g.T % 90 == 0 or (abs(p.vx) > 1.0 and g.T % 40 == 0):
			Audio.play("climb", -20)
		if not BOAT.grounded and abs(p.vx) > 2.5 and g.T % 12 == 0:
			g.X.RIP.append({"x": p.x + p.w / 2, "y": BOAT.water.y + 2, "t": 0, "s": .8})
	if not BOAT.grounded and g.T % 40 == 0:
		g.X.RIP.append({"x": BOAT.x + (BOAT.w if g.T % 80 == 0 else 0.0), "y": BOAT.water.y + 1, "t": 0, "s": .7})

# ======================================================================
#  MESA
# ======================================================================
func _table_rect() -> Dictionary:
	return g.R(TABLE.x, TABLE.y, TABLE_W, TABLE_H)

func _table_post() -> void:
	if TABLE.is_empty():
		return
	var t: Dictionary = TABLE
	if abs(t.x - (g.cam + g.W / 2)) > 1500 and abs(t.vx) < .05 and t.vy == 0.0:
		return
	var p: Dictionary = g.player
	# esbarrão: andando contra a mesa (de pé), ela escorrega um pouco sem travar o caminho
	if t.st == "up" and p.onGround and abs(p.vx) > .8 and Game.hit(p, _table_rect()):
		var pcx: float = p.x + p.w / 2
		if (p.vx > 0 and pcx < t.x + TABLE_W / 2) or (p.vx < 0 and pcx > t.x + TABLE_W / 2):
			t.vx = lerpf(t.vx, p.vx * .55, .4)
			if g.T % 9 == 0:
				g.fx("fx_dust", t.x + (0.0 if p.vx > 0 else TABLE_W), t.y + TABLE_H - 4, 12, .08, -.2)
				Audio.play("slide", -14)
	t.vx *= .82
	if abs(t.vx) > .05:
		var nx: float = t.x + t.vx
		var r: Dictionary = g.R(nx, t.y + 4, TABLE_W, TABLE_H - 8)
		var free := true
		for s in g.SOL:
			if s.get("deco") or s.get("oneway") or s.get("boat"):
				continue
			if Game.hit(r, s):
				free = false
		if free:
			t.x = nx
		else:
			t.vx = 0.0
	# gravidade: assenta no chão de verdade
	t.vy = min(t.vy + .6, 12.0)
	var feet: float = t.y + TABLE_H
	var land := INF
	for s in g.SOL:
		if s.get("deco") or s.get("boat"):
			continue
		if t.x + 10 < s.x + s.w and t.x + TABLE_W - 10 > s.x and s.y >= feet - 2 and s.y <= feet + t.vy + 1 and s.y < land:
			land = s.y
	if land < INF:
		t.y = land - TABLE_H
		t.vy = 0.0
	else:
		t.y += t.vy
	# tombando (girando em torno do pé do lado para onde cai)
	if t.st == "tip":
		t.va += .012
		t.ang += t.va * t.dir
		if abs(t.ang) >= PI / 2:
			t.ang = PI / 2 * t.dir
			t.st = "down"
			g.shake = max(g.shake, 5)
			Audio.play("stomp", -6)
			g.fx("fx_dust", t.x + TABLE_W / 2 + t.dir * 40, t.y + TABLE_H - 6, 18, .16, -.2)
			for pp in PAPERS:
				if pp.on == "table":
					pp.on = "air"
					pp.vx = t.dir * (1.5 + randf() * 3.5)
					pp.vy = -2.0 - randf() * 3.0
					pp.vr = (randf() - .5) * .3
	if t.hit > 0:
		t.hit -= 1
	# papéis voando caem planando, balançando, até deitar no chão
	for pp in PAPERS:
		if pp.on == "table":
			pp.y = t.y - 2
			continue
		if pp.on == "ground":
			# um ventinho às vezes levanta a pontinha
			pp.lift = sin(g.T * .05 + pp.c) * (1.5 + g.AMB.get("wind", 0.0) * 4)
			continue
		pp.vy = min(pp.vy + .12, 1.1)
		pp.vx *= .97
		pp.x += pp.vx + sin(g.T * .1 + pp.c) * .6
		pp.y += pp.vy
		pp.r += pp.vr + sin(g.T * .08 + pp.c) * .02
		var gy: float = g.L.get("table", {}).get("y", 500.0)
		var sup: float = _support_under(pp.x - 4, pp.x + 4, pp.y - 10)
		if sup < INF:
			gy = sup
		if pp.y >= gy - 1:
			pp.y = gy - 1
			pp.on = "ground"
			pp.r = (randf() - .5) * .16

## picareta acertou algo? (chamado pelo golpe)
func swing_hits(hb: Dictionary) -> void:
	if not TABLE.is_empty() and TABLE.st == "up" and TABLE.hit == 0 and Game.hit(hb, _table_rect()):
		TABLE.hit = 20
		TABLE.st = "tip"
		TABLE.dir = g.player.face
		TABLE.va = .02
		Audio.play("unlock", -8)
		g.burst(TABLE.x + TABLE_W / 2, TABLE.y + 10, 10, Color("#c9a26a"))
		g.note("A mesa tombou e os papéis da Isis voaram...")

func post() -> void:
	_boat_post()
	_table_post()
