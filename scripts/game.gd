extends Node2D
class_name Game
## Simulação da fase (porta fiel da versão HTML): física do Tomé, fase 1 (escadas, agachar,
## mochila, cadeados, pântano, noite), inimigos, itens e câmera. Tudo roda em passos fixos.

signal clue_opened(id: int)
signal bag_wanted(l: Dictionary)   # perto de uma trava com as peças soltas: abrir a mochila para juntar
signal results_ready
signal isis_start      # Episódio 2: o Tomé chegou à porta de ferro — agora se joga com a Isis
signal game_over
signal level_won
signal rest_reached(n: int)
signal drawing_found(i: int)

# ---------- física (mesmos números da versão HTML) ----------
const GRAV := .62
const JUMP := -11.8
const DJUMP := -10.8
const TOP := 4.3
const ACCg := .9
const ACCa := .52
const FRIC := .74
const COY := 10
const BUF := 11
const PUFF_GRAV := .10
const PUFF_FALL := 1.8
const PUFF_TOP := 3.8
const PUFF_ACC := .55
const SLAM_GRAV := 1.8
const SLAM_MAX := 21.0
const STOMP := -9.6
const MAXHP := 5
const VINE_G := .3          # gravidade do balanço no cipó
const RUN_TOP := 6.6
const RUN_ACC := 1.05
const FLY := {"fly": 1, "owl": 1, "bat": 1, "crow": 1, "piranha": 1}

var L: Dictionary
var level_idx := 0
var SOL: Array = []
var CR: Array = []
var SPR: Array = []
var EN: Array = []
var COINS: Array = []
var COIN_GRID := {}      # lápis por faixa de 512 px (para não testar os 660 a cada passo)
var CHK: Array = []
var VINES: Array = []
var CLK: Array = []
var DRWS: Array = []
var CLIMB: Array = []
var ENTR: Array = []
var ITEMS: Array = []
var LOCKS: Array = []
var CLUES: Array = []
var SPECS: Array = []
var LILY: Array = []
var MUD: Array = []
var SWAMP: Array = []
var CRANKS: Array = []   # portas de manivela: toques em USAR vão subindo a porta
var BUSH: Array = []
var VIL = null
var DOOR: Dictionary
var INV: Array = []
var CLUEGOT := {}
var SPECGOT := {}
var DRAWN := {}
var STATS := {"pen": 0, "penTotal": 0}
var AMB := {"dark": 0.0, "rain": 0.0, "night": 0.0, "tint": "", "tint_c": Color(0, 0, 0, 0), "song": "manha", "fog": 0.0, "wind": 0.0, "snow": 0.0, "snowfall": 0.0}
var X: Extras
var M: Mech
var PR: Props
var TR: Traps
var ZN: Zones
var NT: Nature
var K: Kings
var RD: Ride
var VH: Vehicles
var EV: Events
var SL: Slam
var WV: Waves
var MV: Movers
var VL: Village
var RESTED := {}        # fogueiras grandes já descansadas
var player: Dictionary = {}
var keys := {}
var T := 0
var time_left := 0
var lives := 3
var coins := 0
var coin_life := 0
var shake := 0.0
var hit_stop := 0
var slowmo := 0            # câmera lenta (golpe final nos chefes)
var shake_dir := Vector2.ZERO   # tremor com direção (empurra para o lado do impacto)
var bird_near := false     # algum passarinho voando perto (o Tomé olha para cima)
var iris_t := 0
var flash_msg := ""
var flash_t := 0
var lantern_lit := true
## óleo da lanterna (0..1): cresce ao pegar frascos, gasta devagar no escuro; fuel_vis segue aos poucos
var FUEL := .55
var fuel_vis := .55
var OIL: Array = []
var oil_seen := false
## tipos de inimigo já apresentados (dica do primeiro encontro)
var en_seen := {}
var look_y := 0.0
var thunder_t := 200
var lightning := 0
var thunder_snd := 0
var PARTS: Array = []
var COAL: Array = []
var no_coal := false
var FXS: Array = []
var cam := 0.0
var cam_y := 0.0
var cam_focus := 0.0
var cam_vx := 0.0          # velocidades da câmera (mola amortecida: sem tremedeira)
var cam_vy := 0.0
var look_x := 0.0
var look_vx := 0.0
var look_hold := 0
var CINE := {}             # cena dramática dentro do jogo (câmera, faixas de cinema, falas)
const CINE_BACK := 46      # quadros para a câmera voltar do chefe para o Tomé no fim da cena
var W := 960.0
var H := 540.0
var running := false
var cur_chk := -1           # fogueira onde o Tomé volta ao morrer
var auto_cine: bool = DisplayServer.get_name() == "headless"
## quadrinhos: chefes e primeiras vezes (cipó, mergulho, neve...). A tela principal mostra e o jogo espera.
var comic_req := ""
var COMIC_TRIG: Array = []
const COMIC_CINE := {"boss": "javali", "gaviao": "gaviao", "bagre": "bagre", "urso": "urso", "vargas": "vargas", "cao": "pipoca", "cavalo": "cavalo"}   # testes automáticos: falas passam sozinhas
var max_x := 0.0          # até onde o Tomé já chegou (para o mapa)
var tps := 60
## celular com dificuldade: desliga os enfeites menos importantes (reflexo, poeira, fachos de sol)
var low_fx := false
var shown_crate := false
var rng := RandomNumberGenerator.new()
var camera: Camera2D
## onde ficam os nós do mundo (tela à parte com o contorno; main.gd)
var world_parent: Node = null
# interpolação do desenho entre passos fixos (movimento liso em telas de 90/120 Hz)
var prev_px := 0.0
var prev_py := 0.0
var prev_cam := 0.0
var prev_cam_y := 0.0
var rcam := 0.0
var rcam_y := 0.0
# analógico: inclinação horizontal (1 = digital / máximo)
var axis_x := 1.0

func _ready() -> void:
	camera = Camera2D.new()
	camera.anchor_mode = Camera2D.ANCHOR_MODE_FIXED_TOP_LEFT
	add_child(camera)
	camera.make_current()

# ======================================================================
#  CARREGAR
# ======================================================================
func load_level(i: int) -> void:
	Polish.reset(self)
	DIPS = []
	_floor_cache = {}
	_base_cache = {}
	_tall_cache = {}
	level_idx = i
	max_x = 0.0
	cur_chk = -1
	L = JSON.parse_string(FileAccess.get_file_as_string("res://assets/data/level%d.json" % (i + 1)))
	PERIODS = L.get("periods", PERIODS1)
	_support_physics()
	SOL = []
	for s in L.solids:
		if s.get("deco"):
			continue
		var o: Dictionary = s.duplicate()
		if s.t in ["plat", "branch", "island"]:
			o.h = 16
			o.oneway = 1
		SOL.append(o)
	CR = []
	for c in L.get("crates", []):
		var o: Dictionary = c.duplicate()
		o.ox = c.x
		o.oy = c.y
		o.w = c.get("w", 70 if c.t == "push" else 38)
		o.h = c.get("h", 70 if c.t == "push" else 38)
		o.vy = 0.0
		o.dead = false
		o.shake = 0
		o.crate = 1
		CR.append(o)
	SPR = []
	for s in L.get("springs", []):
		var o: Dictionary = s.duplicate()
		o.t = 0
		SPR.append(o)
	EN = []
	for e in L.get("enemies", []):
		var o: Dictionary = e.duplicate()
		o.dir = -1
		o.dead = 0
		o.base = e.y
		o.y = e.cy if e.has("cy") else e.y
		o.stun = 0
		o.leap = 0
		o.x0 = e.x
		o.sx = e.x
		EN.append(o)
	COINS = []
	COIN_GRID = {}
	for k in L.get("coins", []).size():
		var c = L.coins[k]
		var co := {"x": c[0], "y": c[1], "got": false, "ci": k}
		COINS.append(co)
		var cell := int(floor(float(c[0]) / 512.0))
		if not COIN_GRID.has(cell):
			COIN_GRID[cell] = []
		COIN_GRID[cell].append(co)
	CHK = []
	for c in L.get("checks", []):
		var ch := {"x": c[0], "y": c[1], "on": false}
		if c.size() > 3 and c[2] == "rest":
			ch.rest = int(c[3])
		CHK.append(ch)
	VINES = []
	for v in L.get("vines", []):
		var vo := {"x": v.x, "y": v.y, "len": v.len, "th": 0.0, "om": 0.0, "bend": 0.0}
		if v.has("aim"):
			vo.aim = v.aim
		VINES.append(vo)
	OIL = []
	for c in L.get("oil", []):
		OIL.append({"x": c[0], "y": c[1], "got": false})
	FUEL = .55
	fuel_vis = .55
	oil_seen = false
	# ampulhetas ("+20 segundos") saíram: o jogo não tem relógio
	CLK = []
	DRWS = []
	var di := 0
	for d in L.get("drawings", []):
		var o: Dictionary = d.duplicate()
		o.i = di
		o.got = DRAWN.has("%d:%d" % [level_idx, di])
		o.hidden = d.has("toca") and not o.got
		DRWS.append(o)
		di += 1
	DOOR = {"x": L.door.x, "y": L.door.y, "w": 60, "h": 90, "locked": false}
	# troncos de assento das fogueiras grandes: só onde há chão firme embaixo; são degraus baixos
	for c in CHK:
		if not c.has("rest"):
			continue
		c.seats = []
		for sx in [-74, 74]:
			var lx: float = c.x + sx
			var ok := false
			for s in SOL:
				if s.t in ["ground", "dirt", "cliff", "stone"] and abs(s.y - c.y) < 2 and s.x <= lx - 36 and s.x + s.w >= lx + 36:
					ok = true
			# e sem nada perto que atrapalhe a passagem (parede, passagem baixa, escada)
			var area := R(lx - 90, c.y - 90, 180, 88)
			for s in SOL:
				if not s.get("oneway") and hit(area, s) and not (abs(s.y - c.y) < 2 and s.t in ["ground", "dirt"]):
					ok = false
			for cl in CLIMB:
				if hit(area, cl):
					ok = false
			if ok:
				c.seats.append(lx)
				SOL.append({"t": "seat", "x": lx - 34, "y": c.y - 12, "w": 68, "h": 12})
	_p1_load()
	# objetos perto do chão ficam pousados nele (não flutuando)
	for arr in [COINS, ITEMS, CLUES, SPECS]:
		for o in arr:
			o.ry = _rest_y(o.x, o.y)
	for c in CLK:
		c.ry = _rest_y(c.x, c.y, 110)
	for c in OIL:
		c.ry = _rest_y(c.x, c.y, 110)
	X = Extras.new(self)
	X.load_level()
	M = Mech.new(self)
	M.load_level()
	PR = Props.new(self)
	PR.load_level()
	TR = Traps.new(self)
	TR.load_level()
	ZN = Zones.new(self)
	ZN.load_level()
	NT = Nature.new(self)
	NT.load_level()
	K = Kings.new(self)
	K.load_level()
	RD = Ride.new(self)
	RD.load_level()
	VH = Vehicles.new(self)
	VH.load_level()
	EV = Events.new(self)
	EV.load_level()
	SL = Slam.new(self)
	SL.load_level()
	WV = Waves.new(self)
	WV.load_level()
	MV = Movers.new(self)
	MV.load_level()
	VL = Village.new(self)
	VL.load_level()
	RESTED = {}
	_reset_player(L.spawn.x - 12, L.spawn.y - 34)
	time_left = int(L.get("time", 180)) * 60
	coins = 0
	T = 0
	PARTS = []
	FXS = []
	COAL = []
	cam = clamp(player.x - W / 2, 0, max(0, L.spanX - W))
	cam_focus = player.y
	cam_y = clamp(player.y - H * .55, L.top, max(L.top, L.bottom - H))
	flash_t = 0
	running = true

func _rest_y(x: float, y: float, reach: float = 48) -> float:
	var best := INF
	for s in SOL:
		if x >= s.x - 2 and x <= s.x + s.w + 2 and s.y >= y - 4 and s.y - y <= reach and s.y < best:
			best = s.y
	return best if best < INF else -1.0

func _p1_load() -> void:
	CLIMB = []
	for z in L.get("climb", []):
		CLIMB.append(z.duplicate())
	ENTR = []
	for e in L.get("entrances", []):
		ENTR.append(e.duplicate())
	ITEMS = []
	for it in L.get("items", []):
		var o: Dictionary = it.duplicate()
		o.got = false
		ITEMS.append(o)
	LOCKS = []
	for l in L.get("locks", []):
		var o: Dictionary = l.duplicate()
		o.done = false
		o.turn = 0.0
		o.idle = 0
		LOCKS.append(o)
	CRANKS = []
	for c in L.get("cranks", []):
		var o2: Dictionary = c.duplicate()
		o2.done = false
		o2.turn = 0.0
		o2.idle = 0
		o2.ang = 0.0
		CRANKS.append(o2)
	CLUES = []
	for c in L.get("clues", []):
		var o: Dictionary = c.duplicate()
		o.got = CLUEGOT.has(int(c.id))
		CLUES.append(o)
	SPECS = []
	for s in L.get("specials", []):
		var o: Dictionary = s.duplicate()
		o.got = SPECGOT.has(s.c)
		SPECS.append(o)
	LILY = []
	for p in L.get("lily", []):
		var o: Dictionary = p.duplicate()
		o.y0 = p.y
		o.h = 14
		o.oneway = 1
		o.lily = 1
		o.t = 0
		o.st = 0
		o.tm = 0
		LILY.append(o)
	MUD = L.get("mud", []).duplicate(true)
	SWAMP = []
	for s in L.get("swamp", []):
		var o: Dictionary = s.duplicate()
		o.y0 = s.y
		SWAMP.append(o)
	BUSH = L.get("bushes", []).duplicate(true)
	VIL = null
	if L.has("villain"):
		VIL = L.villain.duplicate()
		VIL.x = VIL.x0
		VIL.go = false
		VIL.gone = false
	INV = ["picareta"]
	_comic_triggers()
	lantern_lit = not L.has("lanternOutX")
	look_y = 0
	STATS = {"pen": 0, "penTotal": L.get("coins", []).size(), "pdeath": [0, 0, 0, 0, 0, 0]}

## Episódio 2: depois da porta de ferro, a fuga da Isis (o último trecho do episódio)
func begin_isis() -> void:
	var sp: Array = L.isisPart.spawn
	_reset_player(float(sp[0]) - 12, float(sp[1]) - 34)
	VH.mode = ""
	flash_t = 0
	snap_camera()
	iris_t = 30
	running = true

func _reset_player(x: float, y: float, adjust: bool = true) -> void:
	player = make_body(x, y)
	if L and (L.get("isis") or (L.has("isisPart") and x >= float(L.isisPart.x0))):
		# fase da Isis: ela é menor (cabe nos buracos) e pula mais baixo
		player.isis = true
		player.w = 20.0
		player.h = 26.0
		# o ponto de volta já guardado é do tamanho dela: só ajusta pontos do tamanho do Tomé
		if adjust:
			player.x += 2
			player.y += 8
		player.spawnX = player.x
		player.spawnY = player.y
	if M:
		M.ctrl = false

func make_body(x: float, y: float) -> Dictionary:
	return {"x": x, "y": y, "w": 24, "h": 34, "vx": 0.0, "vy": 0.0, "onGround": false, "face": 1, "puff": false, "slam": false,
		"coyote": 0, "jbuf": 0, "airJumps": 1, "cutOk": false, "hp": MAXHP, "iframe": 0, "armor": 0, "squash": 0.0, "landT": 0, "anim": 0.0,
		"run": 0, "rdir": 1, "tR": -99, "tL": -99, "hR": false, "hL": false, "holdT": 0, "skidT": 0, "spawnX": x, "spawnY": y,
		"vine": null, "vr": 0.0, "vineCD": 0, "dyingT": 0, "exitT": 0, "_g": null, "actT": 0, "act": "", "pushT": 0, "leap": 0,
		"crouch": false, "slideT": 0, "ladder": null, "ladderCD": 0, "dropT": 0, "lookT": 0, "climbA": 0.0, "mud": false,
		"nearE": null, "nearL": null, "blink": 0, "turnT": 0, "lastFace": 1, "dieMsg": "", "swim": false, "water": null,
		"wall": 0, "wallT": 0, "wsl": 0, "lastWall": 0, "wlock": 0, "wslide": false, "guard": false, "dog": false,
		"warp": {}, "wdy": 0.0, "wal": 1.0, "wpose": "", "bar": null, "lastVine": null, "hitT": 0}

# ======================================================================
#  UTILIDADES
# ======================================================================
static func hit(a: Dictionary, b: Dictionary) -> bool:
	return a.x < b.x + b.w and a.x + a.w > b.x and a.y < b.y + b.h and a.y + a.h > b.y

func R(x: float, y: float, w: float, h: float) -> Dictionary:
	return {"x": x, "y": y, "w": w, "h": h}

func pressed(k: String) -> bool:
	if keys.get(k + "p", false):
		keys[k + "p"] = false
		return true
	return false

func kd(k: String) -> bool:
	return keys.get(k, false)

func flash(m: String, t: int = 150) -> void:
	# avisos curtos: no máximo ~3,5 s (textos longos ganham só um pouquinho a mais)
	flash_msg = m
	flash_t = min(t, 150 + min(60, m.length()))

func note(m: String) -> void:
	if flash_t <= 30:
		flash(m)

## tutorial ligado? (opção do menu; perguntado no começo do jogo)
static func tutorial_on() -> bool:
	return bool(Save.getv("opt", "tutorial", true))

## dica de "como fazer": só aparece com o tutorial ligado
func tip(m: String, t: int = 150) -> void:
	if tutorial_on() and flash_t <= 30:
		flash(m, t)

## mensagem com explicação só no tutorial (sem ele, só o essencial)
func flash_tut(short: String, long: String, t: int = 150) -> void:
	flash(long if tutorial_on() else short, t)

func burst(x: float, y: float, n: int, c: Color) -> void:
	for i in n:
		PARTS.append({"x": x, "y": y, "vx": (rng.randf() - .5) * 4.5, "vy": (rng.randf() - .9) * 4.5, "life": 18 + rng.randf() * 14, "col": c})

func fx(n: String, x: float, y: float, life: int, sc: float, vy: float = 0.0) -> void:
	FXS.append({"n": n, "x": x, "y": y, "t": 0, "life": life, "sc": sc, "vy": vy})

## sólidos que bloqueiam, só os perto da tela (a fase tem centenas): calculado uma vez por passo
var _blk: Array = []
var _blk_key := ""
var _blk_a := 0.0
var _blk_b := 0.0
var _cand: Array = []
var _cand_a := 0.0
var _cand_b := 0.0
var _cand_n := -1
var _cand_T := -999
func blockers() -> Array:
	var px: float = player.get("x", 0.0)
	var dog: bool = player.get("dog", false)
	var key := "%d|%d|%s" % [T, SOL.size() + CR.size() * 1000, dog]
	if key == _blk_key and px > _blk_a + 500 and px < _blk_b - 500:
		return _blk
	var a: float = min(cam, px) - 1500.0
	var b0: float = max(cam + W, px) + 1500.0
	_blk_a = a
	_blk_b = b0
	_blk_key = key
	# candidatos pela posição (janela maior, refeita só quando a tela sai dela, a lista de sólidos muda
	# ou a cada segundo, por causa do que anda): o filtro de cada passo olha dezenas em vez de centenas
	if SOL.size() != _cand_n or a < _cand_a or b0 > _cand_b or T - _cand_T > 60 or T < _cand_T:
		_cand_n = SOL.size()
		_cand_T = T
		_cand_a = a - 800.0
		_cand_b = b0 + 800.0
		_cand = []
		for s in SOL:
			if s.x <= _cand_b and s.x + s.w >= _cand_a:
				_cand.append(s)
	var b: Array = []
	for s in _cand:
		if s.x > b0 or s.x + s.w < a:
			continue
		if s.get("ghost") and not s.on:
			continue
		if s.get("fallen"):
			continue
		if s.get("open", 0.0) > .85:
			continue
		if dog and s.get("dogpass"):
			continue
		b.append(s)
	for c in CR:
		if not c.dead:
			b.append(c)
	for p in LILY:
		if p.st != 2:
			b.append(p)
	_blk = b
	return b

## só os sólidos em volta do Tomé (uns 300 px): colisão, parede, teto e beirada olham esta lista
## pequena em vez de todos os sólidos perto da tela, várias vezes por passo
var _nb: Array = []
var _nb_src: Array = []
var _nb_x := 0.0
var _nb_y := 0.0
func near_blockers() -> Array:
	var bl := blockers()
	var px: float = player.x + player.w * .5
	var py: float = player.y + player.h * .5
	if is_same(bl, _nb_src) and abs(px - _nb_x) < 150.0 and abs(py - _nb_y) < 150.0:
		return _nb
	_nb_src = bl
	_nb_x = px
	_nb_y = py
	var out: Array = []
	for s in bl:
		if s.x < px + 300.0 and s.x + s.w > px - 300.0 and s.y < py + 300.0 and s.y + float(s.get("h", 0.0)) > py - 300.0:
			out.append(s)
	_nb = out
	return out

## esquece a lista de sólidos (depois de abrir/fechar algo no meio do passo)
## lápis entre x0 e x1 (pela grade)
func coins_near(x0: float, x1: float) -> Array:
	var out: Array = []
	for cell in range(int(floor(x0 / 512.0)), int(floor(x1 / 512.0)) + 1):
		if COIN_GRID.has(cell):
			out.append_array(COIN_GRID[cell])
	return out

func blockers_dirty() -> void:
	_blk_key = ""
	_cand_n = -1
	if X:
		X._blk_cache.clear()

func has_item(id: String) -> bool:
	return INV.has(id)

func item_name(id: String) -> String:
	return GameData.ITEM_INFO[id][0]

# ======================================================================
#  MOCHILA, CADEADOS E DICAS
# ======================================================================
func give_item(id: String) -> void:
	INV.append(id)
	if id == "engrenagem":
		player.act = "gear"
		player.actT = 60
	Audio.play("item")
	Audio.vib(40)
	flash("Achou: " + item_name(id) + " (veja a mochila)")

func try_combine(a: String, b: String) -> String:
	if not has_item(a) or not has_item(b):
		return ""
	for r in GameData.RECIPES:
		if (r[0] == a and r[1] == b) or (r[0] == b and r[1] == a):
			INV.erase(a)
			INV.erase(b)
			INV.append(r[2])
			if r[2] == "lanterna_acesa":
				lantern_lit = true
			Audio.play("combine")
			Audio.vib(60)
			return r[3]
	return ""

func lock_msg(l) -> String:
	if l == null or l.done:
		return ""
	if has_item(l.need):
		return l.use
	var miss: Array = []
	for p in l.parts:
		if not has_item(p):
			miss.append(p)
	if miss.is_empty():
		return l.pre + " Você já tem " + item_name(l.parts[0]).to_lower() + " e " + item_name(l.parts[1]).to_lower() + ": abra a mochila e junte os dois!"
	var parts: Array = []
	for p in miss:
		parts.append(item_name(p).to_lower() + " — " + l.where[p])
	return l.pre + " Falta " + "; e ".join(parts) + "."

func item_msg(id: String) -> String:
	if id == "picareta":
		return "A velha picareta de mineiro do Tomé. Perto de uma rocha rachada, toque ✦ USAR para quebrar."
	if id == "lanterna_acesa" and lantern_lit:
		return "A lanterna está acesa. Segure ✦ USAR para concentrar o facho de luz."
	for l in LOCKS:
		if l.need == id:
			if not l.done:
				return "Este objeto já está pronto, não precisa combinar! " + l.place
			return "A lanterna está acesa e iluminando o caminho." if id == "lanterna_acesa" else "Este objeto já foi usado."
	for r in GameData.RECIPES:
		if r[0] == id or r[1] == id:
			var o: String = r[1] if r[0] == id else r[0]
			if has_item(o):
				return "Agora toque em " + item_name(o).to_lower() + " para combinar."
			for l in LOCKS:
				if l.has("parts") and l.parts.has(o):
					return "Ainda falta achar: " + item_name(o).to_lower() + " — " + l.where[o] + "."
			return "Ainda falta achar: " + item_name(o).to_lower() + "."
	return ""

## (o HUD pergunta a cada quadro: guarda a resposta do passo atual)
var _ht := ""
var _ht_k := Vector3(-1, 0, 0)
func hint_text() -> String:
	var hk := Vector3(T, player.x, player.y)
	if hk == _ht_k:
		return _ht
	_ht = _hint_text()
	_ht_k = hk
	return _ht

func _hint_text() -> String:
	if not tutorial_on():
		return ""
	var px: float = player.x + player.w / 2
	for h in L.get("hints", []):
		if px < h.a or px > h.b:
			continue
		if h.has("yl") and player.y >= h.yl:
			continue
		if h.has("yg") and player.y <= h.yg:
			continue
		if h.get("boss") and not X.boss_active():
			continue
		if h.has("crack") and X.broken.has(h.crack):
			continue
		if h.get("dogtied") and X.dog_free():
			continue
		if h.has("trap") and int(h.trap) < TR.T.size():
			var tst: String = TR.T[int(h.trap)].st
			if tst in ["down", "used", "done"] or (h.has("trapst") and tst != h.trapst):
				continue
		if h.has("toca") and (X.TOCAS.is_empty() or X.TOCAS[0].done):
			continue
		if h.get("hawk") and (K.HAWK.is_empty() or not K.HAWK.active or K.HAWK.done):
			continue
		if h.get("horse") and (RD.H.is_empty() or RD.H.st != "trapped"):
			continue
		if h.get("raft") and (VH.raft_done or VH.active()):
			continue
		if h.get("plane") and (VH.plane_done or VH.active()):
			continue
		if X.boss_active() and not h.get("boss"):
			continue
		var m: String = lock_msg(LOCKS[int(h.lock)]) if h.has("lock") else h.get("t", "")
		if m == "":
			continue
		return m
	return ""

func touching_wall(dir: int) -> bool:
	var probe := R(player.x + (player.w if dir > 0 else -3.0), player.y + 6, 3, player.h - 14)
	for s in near_blockers():
		if s.get("oneway") or s.get("crate") or s.get("lily"):
			continue
		if hit(probe, s):
			return true
	return false

## altura em pé / abaixado (a Isis é menor: cabe nos buracos)
func body_h() -> float:
	return 26.0 if player.get("isis") else 34.0
func crouch_h() -> float:
	return 16.0 if player.get("isis") else 20.0

func can_stand() -> bool:
	var dh: float = body_h() - crouch_h()
	for s in near_blockers():
		if not s.get("oneway") and hit(R(player.x + 1, player.y - dh, player.w - 2, body_h()), s):
			return false
	return true

func stand_up() -> bool:
	if player.crouch and can_stand():
		player.crouch = false
		player.y -= body_h() - crouch_h()
		player.h = body_h()
		player.slideT = 0
		return true
	return not player.crouch

var _amb_prev := {}
var _amb_last_T := -99

func ambient() -> void:
	var S: Array = L.get("sections", [])
	if S.is_empty():
		return
	# valores do passo anterior: neblina, vento e chuva mudam suavemente (sem estalos)
	var snap: bool = T - _amb_last_T > 3 or _amb_prev.is_empty()
	_amb_last_T = T
	if ZN and ZN.zone != null:
		AMB.dark = 0.0
		AMB.rain = 0.0
		AMB.night = 0.0
		AMB.tint = ""
		AMB.tint_c = Color(0, 0, 0, 0)
		AMB.fog = 0.0
		AMB.wind = 0.0
		AMB.song = ZN.zone.get("song", "manha")
		_amb_prev = {}
		return
	var px: float = amb_x()
	var i := 0
	while i + 1 < S.size() and S[i + 1].x <= px:
		i += 1
	var a: Dictionary = S[i]
	var b = S[i + 1] if i + 1 < S.size() else null
	var t := 0.0
	if b:
		t = clamp((px - (b.x - 260)) / 260.0, 0, 1)
	var mix = func(k: String) -> float:
		var va: float = a.get(k, 0.0)
		var vb: float = b.get(k, 0.0) if b else va
		return va + (vb - va) * t
	AMB.dark = mix.call("dark")
	AMB.rain = mix.call("rain")
	AMB.night = mix.call("night")
	AMB.snow = mix.call("snow")
	# na neve, neva de vez em quando: períodos de nevasca e de céu calmo (~45 s por ciclo)
	var cyc: float = .5 + .5 * sin(T * TAU / 2700.0)
	AMB.snowfall = AMB.snow * clamp((cyc - .3) / .35, 0.0, 1.0)
	var src: Dictionary = a if (t < .5 or b == null) else b
	AMB.tint = src.get("tint", "")
	AMB.song = src.get("song", "manha")
	# cor de tela misturada entre os dois trechos (sem troca num estalo)
	var ca: Color = _tint_col(str(a.get("tint", "")))
	var cb: Color = _tint_col(str(b.get("tint", ""))) if b else ca
	if ca.a <= 0.0:
		ca = Color(cb.r, cb.g, cb.b, 0.0)
	if cb.a <= 0.0:
		cb = Color(ca.r, ca.g, ca.b, 0.0)
	AMB.tint_c = ca.lerp(cb, t)
	# zonas escuras com rampa de 260 px nas bordas
	for z in L.get("darkZones", []):
		if px > z.x and px < z.x + z.w:
			var r: float = clamp(min(px - z.x, z.x + z.w - px) / 260.0, 0.0, 1.0)
			AMB.dark = max(AMB.dark, z.dark * r)
	if L.has("lanternOutX") and px > L.lanternOutX and not lantern_lit:
		AMB.dark = max(AMB.dark, .86 * clamp((px - L.lanternOutX) / 200.0, 0.0, 1.0))
	if X:
		X.weather_amb()
	# a hora passando dentro de cada trecho: neblina da manhãzinha que vai sumindo,
	# e a noite ficando mais escura conforme o Tomé avança
	if px < 2400 and not indoors() and str(S[0].get("song", "")) == "manha":
		AMB.fog = max(AMB.fog, .4 * (1.0 - px / 2400.0))
	if AMB.song in ["noite", "perseguicao"] and S.size() > 0:
		var n0: float = 64250.0
		AMB.dark = min(.9, AMB.dark + .12 * clamp((px - n0) / 13000.0, 0, 1))
	# dentro do túnel e debaixo da terra não chove nem venta
	if indoors():
		AMB.rain = 0.0
		AMB.fog = 0.0
		AMB.wind = 0.0
	if not snap:
		AMB.fog = move_toward(float(_amb_prev.get("fog", AMB.fog)), AMB.fog, .012)
		AMB.wind = move_toward(float(_amb_prev.get("wind", AMB.wind)), AMB.wind, .01)
		AMB.rain = move_toward(float(_amb_prev.get("rain", AMB.rain)), AMB.rain, .012)
		AMB.dark = move_toward(float(_amb_prev.get("dark", AMB.dark)), AMB.dark, .03)
	_amb_prev = {"fog": AMB.fog, "wind": AMB.wind, "rain": AMB.rain, "dark": AMB.dark}

var _tint_cache := {}
func _tint_col(s: String) -> Color:
	if s == "" or s == "<null>":
		return Color(0, 0, 0, 0)
	if not _tint_cache.has(s):
		var m := s.replace("rgba(", "").replace("rgb(", "").replace(")", "").split(",")
		_tint_cache[s] = Color(0, 0, 0, 0) if m.size() < 3 else Color(float(m[0]) / 255.0, float(m[1]) / 255.0, float(m[2]) / 255.0, float(m[3]) if m.size() > 3 else 1.0)
	return _tint_cache[s]

## o Tomé está com a cabeça debaixo d'água?
func submerged() -> bool:
	var p: Dictionary = player
	return p.get("swim", false) and p.get("water") != null and p.y > float(p.water.y) + 2.0

## o Tomé está debaixo da terra, dentro do túnel ou da mina?
func indoors() -> bool:
	if L.has("under") and player.y > L.under:
		return true
	var tn: Array = L.get("tunnel", [])
	var px: float = player.x + player.w / 2
	if tn.size() >= 2 and px > float(tn[0]) and px < float(tn[1]):
		return true
	return _in_mine(px)

var _mine_cache := {"x": -1e9, "v": false}
func _in_mine(px: float) -> bool:
	if abs(px - float(_mine_cache.x)) < 8.0:
		return _mine_cache.v
	var S: Array = L.get("sections", [])
	var v := false
	for k in S.size():
		var s0: Dictionary = S[k]
		var x1: float = float(S[k + 1].x) if k + 1 < S.size() else 1e12
		if px >= float(s0.x) and px < x1:
			v = str(s0.get("gt", "")) == "mina" or str(s0.get("song", "")) == "tunel"
			break
	_mine_cache = {"x": px, "v": v}
	return v

## estrelas de cada período (1 por terminar, +1 com 80% dos lápis do trecho, +1 sem cair nenhuma vez)
func period_stars() -> Array:
	var bounds: Array = [-1e9]
	for c in CHK:
		if c.has("rest"):
			bounds.append(float(c.x))
	bounds.sort()
	bounds.append(1e9)
	var out: Array = []
	for i in PERIODS.size():
		var a: float = bounds[min(i, bounds.size() - 2)]
		var b: float = bounds[min(i + 1, bounds.size() - 1)]
		var tot := 0
		var got := 0
		for c in COINS:
			if c.x >= a and c.x < b:
				tot += 1
				if c.got:
					got += 1
		var st := 1
		if tot == 0 or got >= tot * .8:
			st += 1
		if STATS.get("pdeath", [0, 0, 0, 0, 0, 0])[i] == 0:
			st += 1
		out.append(st)
	return out

## o botão da mão (USAR) só aparece quando há algo para usar ou quando o facho da lanterna serve
func use_available() -> bool:
	if not running or player.dyingT > 0 or not CINE.is_empty():
		return false
	if player.nearL != null or (M and M.is_dog()):
		return true
	if RD and RD.near_horse():
		return true
	if VH and (VH.near_sled() or VH.near_raft() or VH.near_plane()):
		return true
	if near_crank() != null:
		return true
	if MV and MV.near_use():
		return true
	if EV and EV.near_lever() != null:
		return true
	return X.near_use() or X.beam_useful()

## nome do período do dia em que o Tomé está (a fase é uma só, dividida pelas fogueiras grandes)
const PERIODS1 := ["Manhã no bosque", "Tarde", "Pântano", "Neve", "Céu", "Noite na mina"]
var PERIODS: Array = PERIODS1
## pistas da fase (Episódio 1: 1..6; Episódio 2: 7..12)
func clue_ids() -> Array:
	return L.get("clueIds", [1, 2, 3, 4, 5, 6]) if L else [1, 2, 3, 4, 5, 6]
func period_index() -> int:
	var px: float = amb_x()
	var n := 0
	for c in CHK:
		if c.has("rest") and px > c.x + 30:
			n = max(n, int(c.rest))
	return n

## o nome no topo acompanha o cenário (a fogueira grande marca o fim de cada período)
const PERIOD_OF := {"manha": 0, "tarde": 1, "chuva": 2, "rio": 2, "neve": 3, "ceu": 4, "noite": 5, "perseguicao": 5, "tunel": 5}
func period_label() -> String:
	var px: float = amb_x()
	var i: int = period_index()
	var S: Array = L.get("sections", [])
	for sc in S:
		if sc.x <= px:
			var k: String = sc.get("map", sc.get("bg", sc.get("song", "manha")))
			if sc.get("bg", "") == "neve" and not sc.has("map"):
				k = "neve"
			i = int(sc.per) if sc.has("per") else PERIOD_OF.get(k, i)
	return "%d/%d · %s" % [i + 1, PERIODS.size(), PERIODS[min(i, PERIODS.size() - 1)]]

## posição usada para clima e cenário (no trenó, a trilha fica longe do mapa: vale a do morro)
func amb_x() -> float:
	if VH and VH.mode == "sled":
		return float(VH.SL.x)
	return player.x + player.w / 2

## valor de um parâmetro do trecho onde o jogador está (ex.: "leaves", "flock", "toucans")
func sec_param(k: String, def = null):
	var v = def
	var px: float = amb_x()
	for sc in L.get("sections", []):
		if sc.x <= px:
			v = sc.get(k, def)
	return v

const SEC_BG := {"manha": "bosque", "tarde": "tarde", "chuva": "pantano", "noite": "noite", "tunel": "noite", "perseguicao": "noite"}
var _sw: Dictionary = {}
var _sw_px := -1e18
var _sw_L = null
func section_weights() -> Dictionary:
	## peso de cada cenário de fundo conforme a posição (para o fundo trocar suavemente)
	## (pedido várias vezes por quadro pelo desenho: guarda o último resultado para a mesma posição;
	## quem usa só lê o dicionário)
	var px: float = amb_x()
	if px == _sw_px and is_same(_sw_L, L):
		return _sw
	_sw_px = px
	_sw_L = L
	_sw = _section_weights(px)
	return _sw

func _section_weights(px: float) -> Dictionary:
	var S: Array = L.get("sections", [])
	var map: Dictionary = SEC_BG
	var out := {}
	if S.is_empty():
		return {"bosque": 1.0}
	var i := 0
	while i + 1 < S.size() and S[i + 1].x <= px:
		i += 1
	var ka: String = S[i].get("bg", map.get(S[i].get("song", "manha"), "bosque"))
	out[ka] = 1.0
	if i + 1 < S.size():
		var kb: String = S[i + 1].get("bg", map.get(S[i + 1].get("song", "manha"), "bosque"))
		var t: float = clamp((px - (S[i + 1].x - 400)) / 400.0, 0, 1)
		if kb != ka and t > 0:
			out[kb] = t
	return out

# ======================================================================
#  PASSO
# ======================================================================
func _save_prev() -> void:
	prev_px = player.x
	prev_py = player.y
	prev_cam = cam
	prev_cam_y = cam_y
	for e in EN:
		e.ppx = e.x
		e.ppy = e.y
	Interp.save(self)

## deslocamento para desenhar o Tomé na posição "entre" dois passos
func ip_off() -> Vector2:
	var f := ifrac()
	if abs(player.x - prev_px) > 60 or abs(player.y - prev_py) > 60:
		return Vector2.ZERO
	return Vector2((prev_px - player.x) * (1 - f), (prev_py - player.y) * (1 - f))

func e_off(e: Dictionary) -> Vector2:
	var f := ifrac()
	if not e.has("ppx") or abs(e.x - e.ppx) > 60 or abs(e.y - e.ppy) > 60:
		return Vector2.ZERO
	return Vector2((e.ppx - e.x) * (1 - f), (e.ppy - e.y) * (1 - f))

## fração do caminho entre o passo anterior e o atual (na câmera lenta a mistura dura dois passos)
var ip_div := 1
var ip_phase := 0
func ifrac() -> float:
	return clamp((ip_phase + Engine.get_physics_interpolation_fraction()) / float(ip_div), 0.0, 1.0)

func update_render_cam() -> void:
	var f := ifrac()
	if abs(cam - prev_cam) > 80 or abs(cam_y - prev_cam_y) > 80:
		rcam = cam
		rcam_y = cam_y
	else:
		rcam = lerpf(prev_cam, cam, f)
		rcam_y = lerpf(prev_cam_y, cam_y, f)

func step() -> void:
	if not running:
		return
	_save_prev()
	# toques únicos (voltar, golpe para baixo) não ficam guardados durante cenas, cavalgada e veículos
	if not CINE.is_empty() or player.dyingT > 0 or not player.get("warp", {}).is_empty() or player.exitT > 0 or RD.riding or (VH and VH.active()) or player.get("mantleT", 0) > 0:
		keys.Bp = false
		keys.Sp = false
	if hit_stop > 0:
		hit_stop -= 1
		return
	if iris_t > 0:
		iris_t -= 1
	if not CINE.is_empty():
		_cine_step()
		return
	if player.dyingT > 0:
		T += 1
		player.dyingT -= 1
		player.vy = min(player.vy + .5, 12)
		player.y += player.vy
		_tick_fx()
		if player.dyingT == 0:
			respawn()
		return
	_comic_check()
	if not player.get("warp", {}).is_empty():
		T += 1
		_warp_step()
		_tick_fx()
		_camera()
		return
	if player.exitT > 0:
		T += 1
		player.exitT -= 1
		player.vx = 0
		var dx: float = DOOR.x + DOOR.w / 2 - (player.x + player.w / 2)
		player.x += clamp(dx, -2, 2)
		_tick_fx()
		if player.exitT == 0:
			running = false
			if L.has("isisPart") and not player.get("isis"):
				isis_start.emit()
				return
			if L.get("results"):
				results_ready.emit()
			else:
				level_won.emit()
		return
	if RD.riding:
		if flash_t > 0:
			flash_t -= 1
		if shake > 0:
			shake *= .85
		RD.step()
		max_x = max(max_x, player.x + 300)
		_tick_fx()
		_camera()
		return
	if VH and VH.active():
		if flash_t > 0:
			flash_t -= 1
		if shake > 0:
			shake *= .85
		VH.step()
		WV.step()
		max_x = max(max_x, player.x + 300)
		_tick_fx()
		_camera()
		return
	T += 1
	# faixa "CHEGADA!" que ficou de uma corrida/salto: some sozinha também fora do veículo
	if VH:
		VH.tick_cheer()
	if ZN == null or ZN.zone == null:
		max_x = max(max_x, player.x + 300)
	if shake > 0:
		shake *= .85
	for k in ["iframe", "vineCD", "actT", "pushT", "leap", "skidT", "hitT"]:
		if player[k] > 0:
			player[k] -= 1
	if flash_t > 0:
		flash_t -= 1
	# sem relógio: o tempo só é contado para o resumo do fim (nunca acaba)
	time_left -= 1
	var __m := Time.get_ticks_usec()
	MV.pre()
	VL.pre()
	X.pre_step()
	if player.dyingT > 0:
		return
	NT.pre()
	M.pre()
	TR.pre()
	ZN.pre()
	Spr.pt("s_pre", __m); __m = Time.get_ticks_usec()
	if player.get("mantleT", 0) > 0:
		_mantle_step()
		_camera()
		_tick_fx()
		return
	# encostado numa parede no ar (para deslizar e pular de parede em parede)
	player.wslide = false
	# encostado de verdade agora (a memória "wall" dura uns quadros a mais, só para o pulo de parede)
	player.wtouch = false
	if player.wsl > 0:
		player.wsl -= 1
	if player.wlock > 0:
		player.wlock -= 1
	if player.onGround or player.ladder or player.vine or player.swim:
		player.lastWall = 0
		player.wall = 0
		player.wallT = 0
	elif not player.dog and not player.crouch:
		var wd := 0
		if touching_wall(1):
			wd = 1
		elif touching_wall(-1):
			wd = -1
		player.wtouch = wd != 0
		if wd != 0:
			player.wall = wd
			player.wallT = 6
		elif player.wallT > 0:
			player.wallT -= 1
		else:
			player.wall = 0
	if pressed("B"):
		_back_to_fire()
		return
	# corrida: dois toques na mesma direção
	if kd("R") and not player.hR:
		if T - player.tR < 16:
			player.run = 1
			player.rdir = 1
			burst(player.x, player.y + player.h - 4, 6, Color("#e9dbb8"))
		player.tR = T
	if kd("L") and not player.hL:
		if T - player.tL < 16:
			player.run = 1
			player.rdir = -1
			burst(player.x + player.w, player.y + player.h - 4, 6, Color("#e9dbb8"))
		player.tL = T
	player.hR = kd("R")
	player.hL = kd("L")
	if player.run and not (kd("R") if player.rdir > 0 else kd("L")):
		player.run = 0
	# cipós livres
	for v in VINES:
		if player.vine == v:
			continue
		v.om += -(VINE_G / v.len) * sin(v.th)
		v.om *= .97
		v.th += v.om

	var pcx: float = player.x + player.w / 2
	var pcy: float = player.y + player.h / 2
	player.mud = false
	for m in MUD:
		if pcx > m.x and pcx < m.x + m.w and abs(player.y + player.h - m.y) < 4:
			player.mud = true
	_p1_pre(pcx)
	if player.vine:
		_vine_step()
	elif player.ladder:
		_p1_ladder()
		keys.Sp = false
	elif player.get("bar"):
		NT.bar_step()
		keys.Sp = false
	elif player.swim:
		X.swim()
		keys.Sp = false
	else:
		# M3 planando, o vento leva um pouquinho
		if player.puff:
			player.vx += (float(AMB.get("wind", 0.0)) + Polish.gust_k()) * .02
		# planar
		player.puff = (kd("P") or (kd("J") and player.airJumps == 0 and player.vy > .5)) and not player.onGround and not player.slam and player.vy > -1.5 and not player.dog and not player.get("isis") and player.wall == 0 and not in_fumes()
		# pulos
		var g0 = player._g
		if pressed("J"):
			if player.onGround and kd("S") and g0 and g0.get("oneway") and not g0.get("lily"):
				player.dropT = 14
				stand_up()
				player.y += 4
				player.onGround = false
				player.coyote = 0
			else:
				player.jbuf = BUF
		# M7 pulo saindo do deslize: guarda o embalo (pulo comprido)
		var slide_jump: bool = player.jbuf > 0 and player.crouch and player.slideT and (player.onGround or player.coyote > 0)
		if player.jbuf > 0 and player.crouch and (player.onGround or player.coyote > 0) and not stand_up():
			player.jbuf = 0
		elif slide_jump and not player.crouch:
			player.vx = clamp(player.vx * 1.12, -RUN_TOP - .6, RUN_TOP + .6)
		var mudF := .78 if player.mud else 1.0
		if player.jbuf > 0:
			if player.onGround or player.coyote > 0:
				player.vy = (JUMP * .9 if player.dog else (JUMP * .76 if player.get("isis") else JUMP)) * mudF
				Audio.play("jump", -6)
				player.onGround = false
				player.coyote = 0
				player.airJumps = 0 if (player.dog or player.get("isis")) else 1
				player.jbuf = 0
				player.cutOk = true
				player.slam = false
				player.squash = -.5
				burst(player.x + player.w / 2, player.y + player.h, 6, Color("#cdbfa6"))
			elif player.wall != 0 and player.wall != player.lastWall and not player.dog and not player.get("isis") and (player.wsl > 0 or player.airJumps == 0):
				# pulo na parede: empurra para o lado oposto e devolve o pulo duplo
				player.lastWall = player.wall
				player.vx = -player.wall * 6.4
				player.vy = JUMP * .93
				player.face = -player.wall
				player.wlock = 11
				player.wall = 0
				player.wallT = 0
				player.airJumps = 1
				player.jbuf = 0
				player.cutOk = true
				player.puff = false
				player.squash = -.4
				Audio.play("jump", -4)
				fx("fx_dust", player.x + (player.w if player.face < 0 else 0.0), player.y + player.h / 2, 16, .12, -.1)
				burst(player.x + player.w / 2 - player.face * 12, player.y + player.h / 2, 8, Color("#cdbfa6"))
			elif player.airJumps > 0 and not player.dog and not player.get("isis") and _ground_near():
				# apertou PULAR caindo, a um palmo do chão: guarda o toque para o pulo do chão (sai mais alto
				# um quadro depois, e o pulo duplo continua guardado) em vez de gastar o duplo rente ao chão
				pass
			elif player.airJumps > 0 and not player.dog and not player.get("isis"):
				player.vy = DJUMP
				Polish.air_ring(player.x + player.w / 2, player.y + player.h)
				Audio.play("dj", -6)
				player.airJumps -= 1
				player.puff = false
				player.jbuf = 0
				player.squash = -.4
				player.cutOk = true
				for a in 10:
					PARTS.append({"x": player.x + player.w / 2, "y": player.y + player.h, "vx": cos(a / 10.0 * TAU) * 2.6, "vy": sin(a / 10.0 * TAU) * 2.6, "life": 16, "col": Color("#e9dbb8")})
		if player.jbuf > 0:
			player.jbuf -= 1
		if player.coyote > 0:
			player.coyote -= 1
		if player.cutOk and not kd("J") and player.vy < -3.5 and not player.slam and player.leap <= 0:
			player.vy = -3.5
		# mergulho
		if pressed("S") and not player.onGround and not player.slam and not player.dog and not player.get("isis"):
			player.slam = true
			# "fffu" do mergulho começando (antes era mudo até bater no chão)
			Audio.play("slide", -10, .78)
			player.puff = false
			player.vy = max(player.vy, 4)
		# horizontal (logo depois de pular na parede, o controle fica um instante travado)
		var held_l: bool = keys.get("L", false)
		var held_r: bool = keys.get("R", false)
		if player.wlock > 0 or player.get("launchT", 0) > 0:
			keys.L = false
			keys.R = false
		# deslizou para fora da beirada: levanta (no ar não se anda agachado)
		if player.crouch and not player.onGround and player.coyote <= 0:
			player.slideT = 0
			player.belly = false
			stand_up()
		if player.crouch:
			var want := -1 if (kd("L") and not kd("R")) else (1 if (kd("R") and not kd("L")) else 0)
			if want != 0:
				player.face = want
			if player.slideT:
				var gk: String = ground_kind()
				# de barriga na neve e na lama: escorrega longe, espirrando
				var slick: bool = gk == "snow" or (gk == "mud" and not player.mud)
				player.vx *= .9 if player.mud else (.992 if slick else .976)
				player.belly = slick
				if slick and T % 3 == 0:
					PARTS.append({"x": player.x + player.w / 2 - player.face * 14, "y": player.y + player.h - 4, "vx": -player.face * randf_range(.5, 2.0), "vy": -randf_range(1.0, 2.6), "life": 18,
						"col": Color(.95, .97, 1, .9) if gk == "snow" else Color(.35, .26, .16, .9)})
				if T % 4 == 0:
					fx("fx_dust", player.x + player.w / 2 - player.face * 10, player.y + player.h - 3, 12, .08, -.2)
				if abs(player.vx) < 1.3:
					player.slideT = 0
			else:
				player.vx += (want * 1.8 - player.vx) * .25
		else:
			var run: bool = player.run and not player.puff
			var acc: float = PUFF_ACC if player.puff else (( RUN_ACC if run else ACCg) if player.onGround else ACCa)
			var top: float = PUFF_TOP if player.puff else (RUN_TOP if run else TOP)
			var want := -1 if (kd("L") and not kd("R")) else (1 if (kd("R") and not kd("L")) else 0)
			if player.onGround and want != 0 and player.vx * want < -2.2 and not player.puff:
				player.vx += want * acc * 1.3
				player.skidT = 6
				if T % 3 == 0:
					fx("fx_dust", player.x + player.w / 2, player.y + player.h - 4, 14, .12, -.3)
			if player.onGround and want != 0 and abs(player.vx) >= TOP - .15 and not player.run:
				player.holdT += 1
				if player.holdT > 75:
					player.run = 1
					player.rdir = want
					burst(player.x + player.w / 2, player.y + player.h - 4, 6, Color("#e9dbb8"))
			elif want == 0 or (not player.onGround and not player.run):
				player.holdT = 0
			var wet: bool = player._g != null and player._g.get("wet") and player.onGround
			var top2 := top
			if player.mud and player.onGround:
				top2 = min(top, 1.9)
			if axis_x < 1 and player.onGround and not player.run:
				top2 = top2 * axis_x
			if X.focus:
				top2 = min(top2, 1.6)
			if player.guard:
				top2 = min(top2, 1.2)
			if player.dog:
				top2 = top2 * 1.18
			if wet and want == 0:
				# escorrega um pouco e para: gelo desliza mais que o tronco molhado
				player.vx *= (.955 if player._g.t == "ice" else .88) / FRIC
			if player.onGround and abs(player.vx) < 1.4 and not player.run and not player.puff:
				acc *= .78
			# M4 no ar, virar para o outro lado responde mais rápido (correção de pulo)
			if not player.onGround and not player.puff and want != 0 and player.vx * want < 0:
				acc *= 1.35
			if want < 0 and not player.slam:
				player.vx = min(-top2, player.vx * .985) if player.vx < -top2 else max(player.vx - acc, -top2)
				player.face = -1
			elif want > 0 and not player.slam:
				player.vx = max(top2, player.vx * .985) if player.vx > top2 else min(player.vx + acc, top2)
				player.face = 1
			elif player.get("launchT", 0) <= 0:
				# soltou o direcional: para firme no chão e quase não deriva no ar (pulo preciso)
				# (no pulo de parede o controle fica travado um instante: aí o impulso continua)
				player.vx *= FRIC if player.onGround else (.9 if player.slam else (.985 if player.wlock > 0 else .88))
		keys.L = held_l
		keys.R = held_r
	# vertical
	if not player.vine and not player.ladder and not player.swim and not player.get("bar"):
		var g := GRAV
		var maxv := 13.0
		if player.slam:
			g = SLAM_GRAV
			maxv = SLAM_MAX
		elif player.puff:
			g = PUFF_GRAV
			maxv = PUFF_FALL
		if kd("J") and not player.puff and not player.slam and abs(player.vy) < 1.6 and player.get("launchT", 0) <= 0:
			g *= .55
		elif player.vy > 1.6 and not player.puff and not player.slam and player.wsl == 0 and player.wall == 0 and player.get("launchT", 0) <= 0:
			# a queda pesa um pouco mais que a subida (pulo com peso)
			# (cair mais pesado ao soltar PULAR encurtava os pulos nos precipícios da montanha: ficou só no desenho)
			g *= 1.08
		player.vy = clamp(player.vy + g, -34 if player.get("launchT", 0) > 0 else -20, maxv)
		# deslizar na parede só encostado nela de verdade (a memória de alguns quadros deixava o Tomé
		# "flutuando" devagar no ar depois que a parede acabava, e marcava deslize já pousado no chão)
		if player.wall != 0 and player.get("wtouch", false) and not player.onGround and player.vy > 1.5 and kd("R" if player.wall > 0 else "L") and player.wlock == 0:
			# raspar na parede: um "chhh" ao encostar e bem baixinho enquanto escorrega
			if player.wsl == 0:
				Audio.play("slide", -15, 1.35)
			elif T % 22 == 0:
				Audio.play("slide", -24, 1.5)
			player.vy = min(player.vy, 2.3)
			player.wslide = true
			player.wsl = 6
			# de costas para a parede, com a mão de trás apoiada nela (já olhando para onde vai pular)
			player.face = -player.wall
			player.slam = false
			if T % 6 == 0:
				PARTS.append({"x": player.x + (player.w if player.wall > 0 else 0.0), "y": player.y + 6, "vx": -player.wall * .6, "vy": -.4, "life": 14, "col": Color(.85, .78, .62, .7)})

	var prev_vy: float = player.vy
	var was_ground: bool = player.onGround
	if not player.vine and not player.get("bar"):
		player.onGround = false
		move_x(player.vx)
		move_y(player.vy)
	# pousou sem segurar direção: freia na hora (não escorrega para fora da plataforma)
	if player.onGround and not was_ground and not kd("L") and not kd("R") and not (player._g != null and player._g.get("wet")):
		player.vx *= .35
		player.run = 0
	player.landV = prev_vy if (player.onGround and not was_ground) else 0.0
	if player.onGround and not was_ground and prev_vy > 3:
		Audio.step(ground_kind(), -10.0 if prev_vy > 8 else -14.0)
		# queda alta: um baque grave por baixo do passo (o pouso tem peso)
		if prev_vy > 11 and not player.slam:
			Audio.play("stomp", -13.0 + min(5.0, (prev_vy - 11.0) * .8), .72)
		# o capim em volta deita em círculo com o pouso
		Polish.blasts.append({"x": player.x + player.w / 2, "y": player.y + player.h, "t": 14, "r": 40.0 + prev_vy * 4.0, "f": 8.0 + prev_vy})
	if player.onGround and not was_ground and prev_vy > 11 and not player.slam:
		Polish.land_heavy(player.x + player.w / 2, player.y + player.h, prev_vy)
		player.squash = min(1.2, prev_vy / 11)
	if player.onGround and not was_ground and prev_vy > 4 and not player.slam:
		Polish.land_soft(player.x + player.w / 2, player.y + player.h, prev_vy)
	if player.onGround and not was_ground and prev_vy > 6:
		player.squash = max(player.squash, min(1, prev_vy / 14))
		player.landT = 8
		if prev_vy > 10:
			Audio.vib(18)
		# peso no pouso: poeira proporcional à queda
		burst(player.x + player.w / 2, player.y + player.h, int(clamp(prev_vy * .6, 4, 10)), Color("#b7a77f"))
		fx("fx_dust", player.x + player.w / 2, player.y + player.h - 6, 16, .08 + prev_vy * .01, -.2)
	player.squash *= .78
	if player.landT > 0:
		player.landT -= 1
	if player.slam and player.onGround:
		# o mergulho batendo no chão: pancada grave e tremida (a onda de choque tem peso)
		Audio.play("stomp", -1, .62)
		Audio.vib(70)
		shake = max(shake, 9)
		shake_dir = Vector2(0, 1)
		Polish.flatten(player.x + player.w / 2, player.y + player.h, 80.0, 240)
		Polish.scare(player.x, 420.0)
		Polish.slam_wave(player.x + player.w / 2, player.y + player.h)
		burst(player.x + player.w / 2, player.y + player.h, 16, Color("#d9c290"))
		var r := R(player.x - 30, player.y - 6, player.w + 60, player.h + 40)
		for c in CR:
			if not c.dead and c.t == "break" and hit(r, c):
				break_crate(c)
		for e in EN:
			if not e.dead and hit(r, ebox(e)):
				kill_enemy(e, "stomp")
		SL.on_slam(player.x + player.w / 2, player.y + player.h)
		player.slam = false
	# correndo, chuta uma pedrinha de vez em quando
	if player.onGround and player.run and abs(player.vx) > 4 and T % 37 == 0 and not player.swim:
		var gk2: String = ground_kind()
		if gk2 in ["grass", "dirt", "stone"]:
			PARTS.append({"x": player.x + player.w / 2 + player.face * 8, "y": player.y + player.h - 3, "vx": player.face * randf_range(2.5, 4.0), "vy": -randf_range(2.0, 3.0),
				"life": 60, "col": Color(.5, .46, .4), "gy": player.y + player.h - 3})
	# cansaço: depois de correr bastante, quando para, fica ofegante um tempinho
	if (player.run and abs(player.vx) > 3 or player.get("isis") and abs(player.vx) > 2.4) and player.onGround:
		player.runT = player.get("runT", 0) + 1
	elif abs(player.vx) < .4 and player.onGround:
		if player.get("runT", 0) > 160:
			player.pant = 150
		player.runT = 0
	if player.get("pant", 0) > 0:
		player.pant -= 1
		if abs(player.vx) > .4 or not player.onGround:
			player.pant = 0
	# quadros seguidos fora do chão (o desenho só troca para a pose de queda depois de um tiquinho:
	# descer um degrau ou a beirada de uma tábua não pisca a pose de pulo)
	player.airT = 0 if player.onGround else int(player.get("airT", 0)) + 1
	# folga até o teto (o desenho do Tomé é bem mais alto que a caixa: perto do teto ele se encolhe no desenho)
	player.ceil = _ceil_gap()
	if player.onGround and abs(player.vx) < .3:
		player.idleT = player.get("idleT", 0) + 1
	else:
		player.idleT = 0
	if player.blink > 0:
		player.blink -= 1
	elif rng.randf() < .004:
		player.blink = 8
	player.anim += abs(player.vx) * .06
	# compasso do passo: o quadro da perna segue a distância andada (sem patinar)
	var gm: float = 1.35 if player.run else 1.2
	if player.get("gm", gm) != gm:
		# troca andar/correr sem pular de quadro: ajusta a contagem para manter a fase
		player.anim = player.get("gait", 0.0) / gm
	player.gm = gm
	player.gait = player.anim * gm
	# passos: som e poeirinha no instante em que o pé da frente pousa (quadros 3 e 7 da folha)
	if player.onGround and abs(player.vx) > .8 and not player.crouch and not player.swim:
		var ph: int = int(player.gait * 2.0) % 4
		if ph != player.get("stepPh", -1) and ph == 3:
			Audio.step(ground_kind(), -15.0 if player.run else -18.0)
			var fx0: float = player.x + player.w / 2 + player.face * 12
			var fy0: float = player.y + player.h - 1
			var gk2 := ground_kind()
			var dc := Color(.95, .97, 1, .7) if gk2 == "snow" else (Color(.45, .6, .32, .45) if gk2 == "grass" else Color(.59, .55, .43, .5))
			for k in (3 if player.run else 2):
				PARTS.append({"x": fx0 - player.face * k * 3, "y": fy0, "vx": -player.face * randf_range(.4, 1.4), "vy": -randf_range(.3, .9), "life": 12 + k * 2, "col": dc})
			if player.run and abs(player.vx) > 4:
				fx("fx_dust", fx0 - player.face * 6, fy0 - 4, 14, .08, -.25)
		player.stepPh = ph
	# agarrar cipó
	if player.onGround or player.swim:
		player.lastVine = null
	# pendurado na corda não agarra cipó (o cipó balançando passava por ele e o puxava de volta)
	if not player.vine and not player.onGround and player.vineCD <= 0 and not player.ladder and not player.dog and not player.get("bar"):
		var hx: float = player.x + player.w / 2
		var hy: float = player.y + 6
		for v in VINES:
			if v == player.get("lastVine"):
				continue   # o cipó que acabou de soltar não pega de novo
			var sx := sin(v.th)
			var cy := cos(v.th)
			var dx: float = hx - v.x
			var dy: float = hy - v.y
			var t: float = dx * sx + dy * cy
			var perp: float = abs(dx * cy - dy * sx)
			if t > 24 and t < v.len + 22 and perp < 30:
				player.vine = v
				player.erase("voff")
				player.vr = clamp(t, 40.0, v.len)
				# conserva um pouco do embalo, sem disparar o balanço
				v.om = clamp((player.vx * cy - player.vy * sx) / player.vr * .6, -.02, .02)
				v.bend = 1.0
				player.vang = v.th * .4
				player.slam = false
				player.puff = false
				player.airJumps = 1
				player.run = 0
				Audio.play("climb", -8)
				tip("←/→ balança · ↑/↓ sobe e desce · PULAR solta")
				break

	Spr.pt("s_phys", __m); __m = Time.get_ticks_usec()
	_p1_post(pcx, pcy)
	Spr.pt("s_post", __m); __m = Time.get_ticks_usec()
	for d in DRWS:
		if not d.got and not d.get("hidden") and abs(d.x - pcx) < 80 and hit(player, R(d.x - 22, d.y - 22, 44, 44)):
			d.got = true
			DRAWN["%d:%d" % [level_idx, d.i]] = 1
			Save.setv("gallery", "d%d" % int(d.i), true)
			flash(d.txt, 280)
			burst(d.x, d.y, 24, Color("#f6efdc"))
			drawing_found.emit(int(d.i))
			Polish.celebrate(player.x + player.w / 2, player.y + 10, false)
			Audio.play("clue")
			Audio.vib(50)
	# molas (cogumelo)
	if player.vy >= 0 and not player.vine:
		for s in SPR:
			var top_y: float = s.y - 24
			if player.x < s.x + 28 and player.x + player.w > s.x - 28 and player.y + player.h >= top_y and player.y + player.h <= s.y + 12:
				player.y = top_y - player.h
				player.vy = s.pow
				Audio.play("spring")
				player.onGround = false
				player.airJumps = 0 if (player.dog or player.get("isis")) else 1
				player.cutOk = false
				player.coyote = 0
				player.jbuf = 0
				player.slam = false
				s.t = 10
				burst(s.x, top_y, 10, Color("#8fd0ff"))
	for s in SPR:
		if s.t > 0:
			s.t -= 1
	if player.y > L.bottom + 60:
		die("Você caiu.")
	for pit in L.get("pits", []):
		if pcx > pit[0] and pcx < pit[1] and player.y > 660 and player.dyingT == 0:
			die("Você caiu no buraco.")
	if not running or player.dyingT > 0:
		_tick_fx()
		_camera()
		return
	# lápis (moedas)
	var pcm := Vector2(player.x + player.w / 2, player.y + player.h / 2)
	for c in coins_near(player.x - 120, player.x + 120):
		if c.got:
			continue
		# ímã curtinho: o lápis voa para o Tomé quando ele chega perto
		var cy0: float = c.ry - 5 if c.ry > 0 else c.y
		var dv := pcm - Vector2(c.x, cy0)
		if dv.length() < 80 and player.dyingT == 0:
			c.mag = true
			var stp: Vector2 = dv.normalized() * min(dv.length(), 7.0)
			c.x += stp.x
			if c.ry > 0:
				c.ry += stp.y
			else:
				c.y += stp.y
		if hit(player, R(c.x - 15, c.y - 15, 30, 30)) or (c.get("mag", false) and dv.length() < 18):
			c.got = true
			STATS.pen += 1
			gain_coin(c.x, c.y)
	for c in CLK:
		var cyy: float = c.ry - 16 if c.ry > 0 else c.y
		if not c.got and hit(player, R(c.x - 18, cyy - 18, 36, 36)):
			c.got = true
			time_left += 20 * 60
			flash("Ampulheta: +20 segundos.")
			burst(c.x, c.y, 14, Color("#bfe3ff"))
	_fuel_step()
	_auto_safe()
	_plat_dips()
	EV.step()
	SL.step()
	# fogueiras
	for k in CHK.size():
		var c: Dictionary = CHK[k]
		if k == cur_chk or player.dog or abs(player.x + player.w / 2 - c.x) >= 26 or abs(player.y + player.h - c.y) >= 60:
			continue
		# qualquer fogueira que não seja a atual vira o ponto de volta (mesmo já acesa)
		player.spawnX = c.x - 12
		player.spawnY = c.y - body_h()
		cur_chk = k
		if not c.on:
			c.on = true
			Audio.play("fire")
			Audio.play("special", -12, .8)
			Audio.vib(35)
			flash("Fogueira acesa: progresso salvo.")
			burst(c.x, c.y - 30, 12, Color("#ffd76a"))
		else:
			note("Progresso salvo.")
		if c.has("rest") and not RESTED.has(c.rest):
			RESTED[c.rest] = 1
			time_left = int(L.get("period", L.get("time", 300))) * 60
			player.vx = 0.0
			save_checkpoint(k)
			running = false
			rest_reached.emit(c.rest)
			return
		save_checkpoint(k)
	Spr.pt("s_items", __m); __m = Time.get_ticks_usec()
	# inimigos
	var camc: float = cam + W * .5
	for e in EN:
		if e.dead:
			# (depois de sumir de vez não precisa mais contar nem cair)
			if e.dead < 400:
				e.dead += 1
				if e.get("dk") == "flip":
					e.ddy += e.dvy
					e.dvy += .45
					# X1 voa girando para longe do golpe
					e.ddx = float(e.get("ddx", 0.0)) + float(e.get("dvx", 0.0))
			continue
		# bem longe da tela e do Tomé: espera parado (não aparece; a fase tem muitos bichos)
		if abs(e.x - camc) > 1700.0 and abs(e.x - pcm.x) > 1700.0:
			continue
		update_enemy(e)
		if e.dead:
			continue
		# longe do Tomé: nem monta a caixa de colisão (as maiores alcançam uns 120 px)
		if abs(e.x - pcm.x) > 260 or abs(e.y - pcm.y) > 360:
			continue
		var b := ebox(e)
		if hit(player, b):
			# pisão: os pés entraram por cima nesta passada (conta onde os pés e o bicho estavam no
			# passo anterior: caindo rápido ou no mergulho os pés afundam mais de 22 px num passo só)
			var btop0: float = b.y - (e.y - float(e.get("ppy", e.y)))
			var stomp: bool = (player.vy > 1 or player.slam) and ((player.y + player.h) - b.y < 22 or prev_py + player.h <= btop0 + 8)
			if stomp and e.k == "mole" and e.get("helm") and not e.get("helm_off") and e.get("st", 0) != 5 and e.stun <= 0:
				player.vy = STOMP * .8
				player.cutOk = false
				Audio.play("unlock", -10)
				burst(e.x, b.y, 6, Color("#e8b030"))
				if X.dog_free():
					tip("O capacete protege! O Pipoca consegue puxá-la para fora quando ela estiver debaixo da terra.")
				else:
					note("O capacete protege! Sozinho não dá...")
				continue
			if e.k == "mole" and e.get("st", 0) == 5 and not stomp:
				continue
			if stomp:
				kill_enemy(e, "stomp")
				player.vy = STOMP * .6 if player.slam else (STOMP * 1.3 if kd("J") else STOMP)
				player.slam = false
				player.squash = .6
				player.cutOk = false
				player.airJumps = 1
			elif not e.stun:
				hurt(1, e.x)
	if ZN.zone != null:
		player.x = clamp(player.x, ZN.zone.x0, ZN.zone.x1 - player.w)
	else:
		player.x = clamp(player.x, 0, L.spanX - player.w)
	# saída (porta da mina)
	if not player.dog and hit(player, R(DOOR.x + 10, DOOR.y, DOOR.w - 20, DOOR.h)) and not DOOR.locked and (VIL == null or VIL.gone):
		player.exitT = 40
		burst(DOOR.x + DOOR.w / 2, DOOR.y + DOOR.h / 2, 20, Color("#ffe9a0"))
		Audio.play("door")
	Spr.pt("s_enem", __m); __m = Time.get_ticks_usec()
	_tick_fx()
	Spr.pt("s_fx", __m); __m = Time.get_ticks_usec()
	_camera()
	Spr.pt("s_cam", __m)

func _tick_fx() -> void:
	Polish.g = self
	Polish.tick(self)
	for f in FXS:
		f.t += 1
		f.y += f.vy
		f.sc *= 1.01
	FXS = FXS.filter(func(f): return f.t < f.life)
	var wnd: float = AMB.get("wind", 0.0)
	for p in PARTS:
		if p.has("k"):
			Polish.tick_part(p, wnd)
			continue
		p.vy += -.015 if p.has("ember") else .18
		p.x += p.vx
		p.y += p.vy
		p.life -= 1
		# pedrinha chutada: quica no chão
		if p.has("gy") and p.y > p.gy:
			p.y = p.gy
			p.vy *= -.45
			p.vx *= .7
	PARTS = PARTS.filter(func(p): return p.life > 0)

## Mola criticamente amortecida (SmoothDamp): segue o alvo suave, sem passar do ponto nem tremer.
static func damp(cur: float, target: float, vel: float, smooth: float) -> Array:
	var dt := 1.0 / 60.0
	var omega: float = 2.0 / maxf(0.0001, smooth)
	var x: float = omega * dt
	var e: float = 1.0 / (1.0 + x + .48 * x * x + .235 * x * x * x)
	var change: float = cur - target
	var temp: float = (vel + omega * change) * dt
	vel = (vel - omega * temp) * e
	return [target + (change + temp) * e, vel]

## quadros desde que subiu num veículo: a câmera vai trocando de jeito aos poucos (sem pulo)
var veh_t := 0
func _vk(k: float) -> float:
	var u: float = clamp(veh_t / 70.0, 0.0, 1.0)
	return lerpf(.035, k, u * u)

## põe a câmera direto num lugar (troca de lugar com a tela fechada)
func set_cam(x: float, y: float) -> void:
	cam = x
	cam_y = y
	prev_cam = x
	prev_cam_y = y
	rcam = x
	rcam_y = y
	cam_vx = 0.0
	cam_vy = 0.0

func _camera() -> void:
	var px: float = player.x + player.w / 2
	var tx: float
	var ty: float
	if (RD and RD.riding) or (VH and VH.active()):
		veh_t += 1
	else:
		veh_t = 0
	if not CINE.is_empty():
		tx = CINE.fx - W / 2
		ty = CINE.fy - H * .55
	elif RD and RD.riding:
		# cavalgada: câmera firme na altura da trilha, cavalo à esquerda para ver os obstáculos chegando
		# (rápido: olha mais para a frente; no salto grande a câmera sobe um pouco junto)
		tx = RD.hx - W * (.3 - .05 * clamp((RD.spd - 5.0) / 1.4, 0.0, 1.0))
		ty = 500.0 - H * .66 - (max(0.0, 470.0 - RD.hy) * .4 if RD.big else 0.0)
		var cb0 := cam_bounds()
		tx = clamp(tx, cb0.position.x, max(cb0.position.x, cb0.end.x - W))
		ty = clamp(ty, cb0.position.y, max(cb0.position.y, cb0.end.y - H))
		cam = lerpf(cam, tx, _vk(.25))
		cam_vx = 0.0
		cam_y = lerpf(cam_y, ty, _vk(.1))
		cam_vy = 0.0
		cam_focus = 500.0
		look_x = 0.0
		return
	elif VH and VH.active():
		# jangada e avião: câmera firme, veículo à esquerda para ver o que vem
		tx = VH.hx - W * .3
		if VH.mode == "raft":
			ty = VH.water_y(VH.hx) - H * .64
		elif VH.mode == "sled" and (VH.sboard > 0 or VH.sfin > 0):
			# embarcando/chegando: câmera normal, a tela fecha em círculo
			ty = VH.hy - H * .56
			cam = lerpf(cam, tx, _vk(.08))
			cam_y = lerpf(cam_y, ty, _vk(.08))
			cam_vx = 0.0
			cam_vy = 0.0
			cam_focus = player.y
			look_x = 0.0
			return
		elif VH.mode == "sled":
			# trenó: a câmera olha bem para a frente e acompanha a descida (sem os limites do mapa)
			tx = VH.hx - W * .26
			ty = VH.hy * .6 + VH.sled_y(VH.su + 300.0) * .4 - H * .56
			cam = lerpf(cam, tx, _vk(.2))
			cam_vx = 0.0
			cam_y = lerpf(cam_y, ty, _vk(.12))
			cam_vy = 0.0
			cam_focus = player.y
			look_x = 0.0
			return
		else:
			ty = VH.hy - H * .5
		var cb1 := cam_bounds()
		tx = clamp(tx, cb1.position.x, max(cb1.position.x, cb1.end.x - W))
		ty = clamp(ty, cb1.position.y, max(cb1.position.y, cb1.end.y - H))
		cam = lerpf(cam, tx, _vk(.25))
		cam_vx = 0.0
		cam_y = lerpf(cam_y, ty, _vk(.08 if VH.mode == "plane" else .1))
		cam_vy = 0.0
		cam_focus = player.y
		look_x = 0.0
		return
	else:
		# olhar para a frente só depois de andar um pouco na mesma direção (virar rápido não balança a tela)
		var want: float = player.face * (120.0 if player.run else 70.0)
		if abs(player.vx) > 1.2 and sign(player.vx) == player.face:
			look_hold += 1
		else:
			look_hold = 0
		if look_hold < 14:
			want = look_x
		# perseguição do urso: o Tomé fica mais à direita da tela e o urso aparece atrás dele
		if K and K.bear_chase():
			want = (-1.0 if K.BEAR.x < px else 1.0) * W * .16
		var r := damp(look_x, want, look_vx, .7)
		look_x = r[0]
		look_vx = r[1]
		tx = px - W / 2 + look_x
		# vertical: só muda de altura quando pisa em algo, sobe muito ou cai
		if player.onGround or player.vine or player.ladder or player.swim or player.y > cam_focus + 40:
			cam_focus = player.y
		elif player.y < cam_focus - 150:
			cam_focus = player.y + 150
		# o chão de verdade fica sempre na mesma altura da tela (pouco subsolo aparecendo), em qualquer
		# fase; galhos, tábuas e ilhas não contam. Se o chão estiver longe lá embaixo (penhasco, lago
		# fundo, plataformas altas) volta a seguir o Tomé, e ele nunca sai por cima da tela
		ty = cam_ty(px, cam_focus) + look_y
	var cb := cam_bounds()
	tx = clamp(tx, cb.position.x, max(cb.position.x, cb.end.x - W))
	ty = clamp(ty, cb.position.y, max(cb.position.y, cb.end.y - H))
	var rx := damp(cam, tx, cam_vx, .13 if CINE.is_empty() else .5)
	cam = rx[0]
	cam_vx = rx[1]
	var ry := damp(cam_y, ty, cam_vy, .21 if CINE.is_empty() else .5)
	cam_y = ry[0]
	cam_vy = ry[1]

# ======================================================================
#  CENAS DRAMÁTICAS DENTRO DO JOGO
# ======================================================================
func want_comic(id: String) -> void:
	if id == "" or auto_cine or comic_req != "":
		return
	if Save.getv("comic", id, false):
		return
	comic_req = id

## pontos da fase onde aparece um quadrinho na primeira passagem
func _comic_triggers() -> void:
	COMIC_TRIG = []
	var add := func(id: String, x: float): COMIC_TRIG.append({"id": id, "x": x, "done": false})
	var vx := INF
	for v in L.get("vines", []):
		vx = min(vx, float(v.x))
	if vx < INF:
		add.call("cipo", vx - 320)
	var sw: Array = L.get("swamp", [])
	if not sw.is_empty():
		add.call("toxico", float(sw[0].x) - 220)
	var wx := INF
	for w in L.get("water", []):
		if float(w.get("h", 0)) >= 300:
			wx = min(wx, float(w.x))
	if wx < INF:
		# se há uma colmeia logo antes da água, o quadrinho vem depois de passar por ela
		var mx: float = wx - 160
		for tr in L.get("traps", []):
			if tr.get("k") == "hive" and float(tr.x) < wx and float(tr.x) > wx - 420:
				mx = max(mx, float(tr.x) + 70)
		add.call("mergulho", mx)
	for sct in L.get("sections", []):
		if sct.get("bg", "") == "neve":
			add.call("neve", float(sct.x) + 60)
			break
	# colmeia: o quadrinho explica que é preciso mergulhar para despistar as abelhas
	for tr in L.get("traps", []):
		if tr.get("k") == "hive":
			add.call("colmeia", float(tr.x) - 130)
	# (sem quadrinho da picareta: o Tomé já começa com ela)
	for cm in L.get("comics", []):
		add.call(str(cm.id), float(cm.x))
	var dz: Array = L.get("darkZones", [])
	if not dz.is_empty():
		add.call("mina", float(dz[0].x) + 40)

func _comic_check() -> void:
	var px: float = player.x + player.w / 2
	for t in COMIC_TRIG:
		if not t.done and px > t.x and px < t.x + 600:
			t.done = true
			want_comic(t.id)

## id: "boss", "vargas", "cao". A câmera vai até o foco, aparecem as faixas de cinema e as falas.
func start_cine(id: String, fx: float, fy: float, dur: int, lines: Array = [], title: Array = []) -> void:
	want_comic(COMIC_CINE.get(id, ""))
	# a câmera só volta para o Tomé depois que a última fala sai da tela (antes voltava com a fala
	# ainda aberta e cortava o chefe pela metade); a cena ganha o tempo da volta, se precisar
	var last_end := 0
	for l in lines:
		last_end = max(last_end, int(l[1]))
	var back: int = max(dur - 50, last_end)
	CINE = {"id": id, "t": 0, "dur": max(dur, back + CINE_BACK), "fx": fx, "fy": fy, "fx0": fx, "lines": lines, "title": title, "back": back}
	keys.clear()
	player.vx = 0.0
	player.run = 0
	player.puff = false
	player.slam = false

func cine_line():
	if CINE.is_empty():
		return null
	for l in CINE.lines:
		if CINE.t >= l[0] and CINE.t < l[1]:
			return l
	return null

func _cine_step() -> void:
	T += 1
	# cada fala fica parada na tela até o jogador tocar (nos testes sem tela, segue sozinha)
	var cl: Array = []
	var lv: Variant = cine_line()
	if lv is Array:
		cl = lv
	var tap: bool = pressed("J") or pressed("A")
	if pressed("K"):
		CINE.t = CINE.dur
	elif not cl.is_empty():
		var full_t: int = int(cl[0] + cl[3].length() / 1.6) + 1
		if tap and CINE.t < min(full_t, cl[1] - 3):
			CINE.t = min(full_t, cl[1] - 3)
		elif CINE.t >= cl[1] - 3 and not CINE.get("ok", {}).has(cl[0]) and not auto_cine:
			CINE.waiting = true
			if tap:
				CINE.waiting = false
				if not CINE.has("ok"):
					CINE.ok = {}
				CINE.ok[cl[0]] = 1
				CINE.t += 1
		else:
			CINE.waiting = false
			CINE.t += 1
	else:
		CINE.waiting = false
		CINE.t += 1
	var t: int = CINE.t
	# o Tomé fica parado (mas a gravidade continua)
	player.vx *= .7
	if player.swim:
		player.vy *= .9
		move_y(player.vy)
	elif not player.onGround and not player.ladder and not player.vine and not player.get("bar"):
		player.vy = min(player.vy + GRAV, 13)
		player.onGround = false
		move_y(player.vy)
	X.cine_step(CINE)
	K.cine_step(CINE)
	RD.cine_step(CINE)
	if lightning > 0:
		lightning -= 1
	if shake > 0:
		shake *= .85
	# volta a câmera para o Tomé no fim, com aceleração e freada suaves (sem estalo no último quadro)
	var back: int = int(CINE.get("back", CINE.dur - 50))
	if t > back:
		if not CINE.has("fxs"):
			CINE.fxs = CINE.fx
			CINE.fys = CINE.fy
		var u: float = smoothstep(0.0, 1.0, clamp(float(t - back) / float(max(1, CINE.dur - back)), 0.0, 1.0))
		CINE.fx = lerpf(float(CINE.fxs), player.x + player.w / 2, u)
		CINE.fy = lerpf(float(CINE.fys), player.y, u)
	if t >= CINE.dur:
		var id: String = CINE.id
		CINE = {}
		X.cine_end(id)
		K.cine_end(id)
		RD.cine_end(id)
	_tick_fx()
	_camera()

## limites da câmera: a fase inteira, ou a sala da torre onde o Tomé está
func cam_bounds() -> Rect2:
	if ZN and ZN.zone != null:
		return ZN.cam_rect()
	return Rect2(0, L.top, L.spanX, L.bottom - L.top)

## altura da câmera: o chão de verdade sob o Tomé fica sempre na mesma altura da tela
## Em cima de casa, plataforma, muro ou platô, quem manda é o chão de verdade da região (a altura de
## chão que ocupa mais largura em volta): ele continua aparecendo embaixo, e o Tomé fica mais alto
## na tela. Buracos e fundos de lago perto não puxam a câmera (ocupam pouca largura).
func cam_ty(px: float, focus: float) -> float:
	var feet: float = focus + player.h
	var gy: float = floor_under(px, feet - 4.0)
	# fundo de lago/brejo com o Tomé por cima (vitória-régia, pulo): não é chão para a câmera
	if gy < 90000.0 and _submerged(px, gy, feet):
		gy = 99999.0
	var base: float = base_ground(px, feet)
	# sobre lago/brejo (sem chão firme embaixo): a superfície é o chão da região, não o fundo
	if base < 90000.0 and base >= feet - 30.0 and (base > feet + 30.0 or gy >= 90000.0) and base - feet < H * .78:
		gy = base
	var t: float = cam_focus_ty(focus)
	if gy < 90000.0 and gy - feet < H * .78:
		t = gy - H * .9
		# algo interessante mais embaixo que o chão (canal, poço, água funda entre pilares): mostra
		var low: float = low_interest(px, gy)
		if low > 0.0:
			t = max(t, low + 30.0 - H)
	return min(t, focus - H * .12)

## o ponto (px, y) está no fundo de água/brejo e o Tomé está por cima da superfície (não nadando)
func _submerged(px: float, y: float, feet: float) -> bool:
	for arr in [SWAMP, X.WATER if X else []]:
		for w in arr:
			var wx: float = float(w.x)
			if px < wx or px > wx + float(w.w):
				continue
			var top: float = float(w.y)
			if y > top + 12.0 and feet < top + 20.0:
				return true
	return false

## a parte de baixo que vale mostrar (superfície de canal/água/brejo bem abaixo do chão, mais um
## pedaço dela) numa faixa em volta do Tomé; 0 = nada (só subsolo). Lago na altura do chão não conta.
func low_interest(px: float, gy: float) -> float:
	var low := 0.0
	var x0: float = px - 960.0 * .42
	var x1: float = px + 960.0 * .42
	for arr in [SWAMP, X.WATER if X else []]:
		for w in arr:
			var wx: float = float(w.x)
			if wx > x1 or wx + float(w.w) < x0:
				continue
			var top: float = float(w.y)
			if top > gy + 40.0 and top < gy + 280.0:
				low = max(low, min(top + 50.0, top + float(w.h)))
	return low

## altura do chão "da região": entre os chãos (terra/grama) abaixo dos pés numa faixa da largura da
## tela, o que cobre mais largura
var _base_cache := {}
func base_ground(px: float, feet: float) -> float:
	var key := Vector2i(int(floor(px / 32.0)), int(floor(feet / 16.0)))
	if _base_cache.has(key):
		return _base_cache[key]
	var x0: float = px - W * .6
	var x1: float = px + W * .6
	# lagos, brejos e água: o fundo deles não é "o chão" que a câmera deve mostrar
	var waters: Array = []
	for k in ["swamp", "water", "bogs"]:
		for w in L.get(k, []):
			if w is Dictionary and w.has("x") and w.has("y"):
				waters.append(w)
	var cover := {}
	for s in near_solids(x0, x1):
		if s.get("deco") or not str(s.get("t", "")) in ["ground", "dirt"]:
			continue
		var sy: float = float(s.y)
		# (o chão "da região" pode estar um tiquinho acima dos pés: vitória-régia, tábua baixa)
		if sy < feet - 30.0 or sy > feet + H * .78:
			continue
		var sub := false
		for w in waters:
			if sy > float(w.y) + 12.0 and float(s.x) < float(w.x) + float(w.get("w", 0)) and float(s.x) + float(s.get("w", 0)) > float(w.x):
				sub = true
				break
		if sub:
			continue
		var ov: float = min(x1, float(s.x) + float(s.get("w", 0))) - max(x0, float(s.x))
		if ov <= 0.0:
			continue
		var k := int(round(sy / 10.0))
		cover[k] = cover.get(k, 0.0) + ov
	var best := 99999.0
	var bw := 0.0
	for k in cover:
		if cover[k] > bw:
			bw = cover[k]
			best = float(k) * 10.0
	_base_cache[key] = best
	return best

## paredão alto ao lado (barranco, muro de pedra, torre): quanto a câmera precisa abrir para mostrar o
## topo dele e um pouco acima, com o chão ainda embaixo (1 = não precisa)
var _tall_cache := {}
func tall_zoom(base_h: float) -> float:
	var p: Dictionary = player
	var px: float = p.x + p.w / 2
	var feet: float = p.y + p.h
	var key := Vector2i(int(floor(px / 32.0)), int(floor(feet / 24.0)))
	if _tall_cache.has(key):
		return _tall_cache[key]
	var gy: float = floor_under(px, feet - 4.0)
	if gy >= 90000.0 or gy - feet > 120.0:
		var bg: float = base_ground(px, feet)
		if bg < 90000.0:
			gy = bg
	var z := 1.0
	# no chão ou subindo pelo paredão (pulando nas paredes, escada): o topo aparece a subida toda
	if gy < 90000.0 and gy > feet - 10.0:
		var top := 99999.0
		for s in near_solids(px - 160.0, px + 430.0):
			if s.get("deco") or not str(s.get("t", "")) in ["cliff", "wall", "stone", "damwall", "hill"]:
				continue
			var sx: float = float(s.x)
			var sw: float = float(s.get("w", 0))
			if sx > px + 430.0 or sx + sw < px - 160.0:
				continue
			var sy: float = float(s.y)
			var sb: float = sy + float(s.get("h", 0))
			# de pé no mesmo chão do Tomé e mais alto que o que já aparece
			if sb < gy - 40.0 or sy > gy - base_h * .7 or feet <= sy + 10.0:
				continue
			top = min(top, sy)
		if top < 90000.0:
			var need: float = (gy - top + 60.0) / .9
			if need > base_h:
				z = clamp(base_h / need, .72, 1.0)
	# no alto (barranco, plataforma, casa) com o chão lá embaixo: abre para caber o chão E o que está
	# acima do Tomé (folga sobre a cabeça e o topo das paliçadas ali perto) — nada cortado em cima
	var base: float = base_ground(px, feet)
	if base < 90000.0 and base - feet > 30.0 and base - feet < base_h * 1.2:
		var top2: float = p.y - 110.0
		if M:
			for gt in M.GATES:
				if gt.get("crank") or float(gt.h) <= 200.0:
					continue
				if float(gt.x) > px - 250.0 and float(gt.x) < px + 450.0:
					top2 = min(top2, WorldExtras.palisade_top(self, gt) - 40.0)
		var need2: float = (base - top2) / .9
		if need2 > base_h:
			z = min(z, clamp(base_h / need2, .65, 1.0))
	# algo para mostrar embaixo (canal, água entre pilares): cabe isso e a folga sobre a cabeça
	var g3: float = gy if gy < 90000.0 else base
	if g3 < 90000.0 and g3 >= feet - 10.0:
		var low: float = low_interest(px, g3)
		if low > 0.0:
			var need3: float = (low + 30.0) - (p.y - 110.0)
			if need3 > base_h:
				z = min(z, clamp(base_h / need3, .72, 1.0))
	_tall_cache[key] = z
	return z

func cam_focus_ty(focus: float) -> float:
	return focus - H * .55

## leis da física: nada fica flutuando no ar.
##  - galho sem árvore: ganha um tronco (só desenho) no lado de onde ele nasce, até o chão (ou até o
##    fundo do barranco, se não houver chão embaixo)
##  - pedra no alto: vira pilar de rocha firme até o chão (antes o pilar era só desenho e o Tomé
##    passava por dentro dele)
##  - tábua solta no ar: ganha cavalete com pernas até o chão
func _support_physics() -> void:
	var sol: Array = L.solids
	var bottom: float = float(L.get("bottom", 900))
	var floor_at := func(x: float, y: float) -> float:
		var best := 99999.0
		for o in sol:
			if o.get("deco") or not str(o.get("t", "")) in ["ground", "dirt", "stone", "cliff", "rockw", "hill"]:
				continue
			if x >= float(o.x) and x <= float(o.x) + float(o.get("w", 0)) and float(o.y) >= y - 2 and float(o.y) < best:
				best = float(o.y)
		return best
	var holders: Array = []
	for o in sol:
		if str(o.get("t", "")) in ["trunk", "deadtree", "cliff", "rockw", "wall", "treehouse", "hill", "beam", "shed", "cabin"]:
			holders.append(o)
	var held := func(s: Dictionary, extra: Array) -> bool:
		for o in holders + extra:
			var ox0: float = float(o.x)
			var ox1: float = ox0 + float(o.get("w", 0))
			var oy0: float = float(o.y)
			var oy1: float = oy0 + float(o.get("h", 4000))
			if oy0 > float(s.y) + 10 or oy1 < float(s.y):
				continue
			var sx0: float = float(s.x)
			var sx1: float = sx0 + float(s.w)
			if abs(sx0 - ox1) < 26 or abs(sx1 - ox0) < 26 or (sx0 < ox1 and sx1 > ox0):
				return true
		return false
	var add: Array = []
	for s in sol:
		var t := str(s.get("t", ""))
		if t == "stone" and not s.get("rubble") and not s.get("deco") and not s.get("ice"):
			# pedra no alto: fica apoiada no topo quebrado de um tronco velho (atrás, como as outras
			# árvores — a caixa e o Tomé passam pela frente, igual passam pelos troncos dos galhos)
			var fy: float = floor_at.call(float(s.x) + float(s.w) / 2, float(s.y) + float(s.h) + 1)
			var gap: float = fy - (float(s.y) + float(s.h))
			if gap > 20.0 and gap < 900.0:
				s.perch = 1
				var tw2: float = min(float(s.w) - 6.0, 46.0)
				var ty2: float = float(s.y) + float(s.h) - 8.0
				add.append({"t": "trunk", "x": float(s.x) + float(s.w) / 2 - tw2 / 2, "y": ty2, "w": tw2, "h": fy - ty2, "deco": 1, "auto": 1, "stump": 1})
		elif t == "branch" and not held.call(s, add):
			for side in [-1, 1]:
				var tw := 50.0
				var tx: float = float(s.x) - tw + 8 if side < 0 else float(s.x) + float(s.w) - 8
				var fy2: float = floor_at.call(tx + tw / 2, float(s.y))
				if fy2 > 90000.0:
					if side < 0:
						continue   # tenta o outro lado; se nenhum tiver chão, desce até o fundo do barranco
					fy2 = bottom + 200.0
				var top: float = float(s.y) - 160.0
				add.append({"t": "trunk", "x": tx, "y": top, "w": tw, "h": fy2 - top, "deco": 1, "auto": 1})
				break
		elif t == "plat" and not s.get("trestle") and not s.get("hatch") and not s.get("crumble") and not held.call(s, add):
			var fy3: float = floor_at.call(float(s.x) + float(s.w) / 2, float(s.y) + 2)
			if fy3 - float(s.y) < 420.0:
				s.trestle = 1
	sol.append_array(add)

func snap_camera() -> void:
	prev_px = -99999
	cam_vx = 0.0
	cam_vy = 0.0
	look_x = player.face * 70.0
	look_vx = 0.0
	if ZN:
		ZN.zone = ZN.zone_at(player.x + player.w / 2, player.y + player.h / 2)
	var cb := cam_bounds()
	cam = clamp(player.x + player.w / 2 - W / 2 + look_x, cb.position.x, max(cb.position.x, cb.end.x - W))
	cam_focus = player.y
	cam_y = clamp(cam_ty(player.x + player.w / 2, player.y), cb.position.y, max(cb.position.y, cb.end.y - H))
	prev_cam = cam
	prev_cam_y = cam_y
	rcam = cam
	rcam_y = cam_y

# ======================================================================
#  CIPÓ: pêndulo de verdade (impulso como num balanço de parque)
# ======================================================================
func _vine_step() -> void:
	var v: Dictionary = player.vine
	var r: float = player.vr
	# gravidade puxando o pêndulo (mais fraca que a do pulo: balanço lento e tranquilo)
	v.om += -(VINE_G / r) * sin(v.th)
	# impulso: empurrar no sentido em que já está indo rende mais, sobretudo perto do ponto mais baixo
	var d := 0
	if kd("R") and not kd("L"):
		d = 1
	elif kd("L") and not kd("R"):
		d = -1
	if d != 0:
		player.face = d
		var same: bool = v.om * d > 0 or abs(v.om) < .004
		v.om += d * (.0012 if same else .0006) * max(.25, cos(v.th))
	v.om *= .994
	v.om = clamp(v.om, -.032, .032)
	# topo macio: perto do alto o cipó perde força devagar (uma pausinha no alto antes de voltar)
	var lim := .75
	if abs(v.th) > lim:
		v.om -= sign(v.th) * (abs(v.th) - lim) * .06
	v.th += v.om
	if abs(v.th) > 1.42:
		v.th = sign(v.th) * 1.42
		v.om = -v.om * .3
	# subir e descer pelo cipó (mais curto = balança mais rápido: conserva o giro)
	var nr := r
	if kd("U"):
		nr = max(40.0, r - 1.6)
	elif kd("S"):
		nr = min(v.len, r + 1.8)
	elif r < v.len * .7:
		# agarrou lá no alto: escorrega um pouco até uma altura boa para balançar
		nr = min(v.len * .7, r + 2.5)
	if nr != r:
		v.om *= clamp(r / nr, .95, 1.06)
		player.vr = nr
		player.climbA += 3
		r = nr
	if v.has("bend"):
		v.bend *= .93
	# o corpo inclina só uma parte do ângulo do cipó, com atraso (fica "pendurado" pelas mãos)
	player.vang = lerpf(player.get("vang", 0.0), v.th * .42 + v.om * 3.0, .18)
	var tx: float = v.x + sin(v.th) * r - player.w / 2
	var ty: float = v.y + cos(v.th) * r - 6
	# agarrou agora: as mãos deslizam até o cipó em vez de pular para ele
	var off: Vector2 = player.get("voff", Vector2(player.x - tx, player.y - ty))
	off *= .7
	if off.length() < .5:
		off = Vector2.ZERO
	player.voff = off
	player.x = tx + off.x
	player.y = ty + off.y
	player.vx = 0
	player.vy = 0
	player.onGround = false
	if pressed("J"):
		# solta com impulso na direção do movimento (quanto mais rápido, mais longe)
		var vt: float = r * v.om
		player.vx = clamp(vt * cos(v.th) * 1.12, -10, 10)
		player.vy = max(-15.0, -vt * sin(v.th) - 3.4)
		if d != 0 and abs(player.vx) < 2.0:
			player.vx = d * 2.0
		# ajudinha: soltando para o lado do alvo do cipó (próximo cipó, corda, margem), o pulo vai certinho até ele
		if v.has("aim"):
			var tgt := Vector2(float(v.aim[0]), float(v.aim[1]) - player.h)
			var dx: float = tgt.x - player.x - player.w / 2
			# sempre vai para a frente (o próximo cipó, a corda ou a margem), mesmo com o direcional
			# apertado para trás no balanço — para voltar, desce até a ponta do cipó e solta com ↓
			if abs(dx) < 620:
				var from := Vector2(player.x + player.w / 2, player.y)
				var sol := TR.ballistic(from, tgt, .75)
				if sol.y < -16.0:
					sol = TR.ballistic(from, tgt, .6)
				if sol.y > -17.0:
					player.vx = sol.x
					player.vy = sol.y
					player.launchT = int(sol.z)
		player.lastVine = v
		player.vine = null
		player.vineCD = 22
		# sem ninguém pendurado, o cipó perde o embalo logo
		v.om *= .4
		player.airJumps = 1
		player.cutOk = false
		player.jbuf = 0
		player.squash = -.4
		Audio.play("jump", -6)
		burst(player.x + player.w / 2, player.y, 8, Color("#cdbfa6"))
	elif pressed("S") and r >= v.len - 1:
		player.vine = null
		player.vineCD = 22

# ======================================================================
#  ENTRAR E SAIR DE ESCONDERIJOS (tronco oco, portas, tocas): animação em vez de teleporte seco
# ======================================================================
## mode: "down" (abaixa e entra pelo buraco), "up" (sobe pela saída), "door" (atravessa a porta)
func start_warp(e: Dictionary) -> void:
	var mode: String = e.get("mode", "up" if e.get("exit") else "down")
	stand_up()
	var cx: float = e.x + e.w / 2
	if int(e.get("dir", 0)) != 0:
		cx = e.x + (e.w * .3 if int(e.dir) > 0 else e.w * .7)
	player.warp = {"e": e, "ph": "in", "t": 0, "mode": mode, "cx": cx}
	player.vx = 0.0
	player.vy = 0.0
	player.run = 0
	player.puff = false
	player.slam = false
	keys.clear()
	Audio.play("climb", -6)

func _warp_step() -> void:
	var w: Dictionary = player.warp
	w.t += 1
	var t: int = w.t
	player.vx = 0.0
	player.vy = 0.0
	if w.ph == "in":
		match w.mode:
			"up":
				# sobe pela luz da saída e some
				player.wpose = "climb"
				player.climbA += 4
				player.wdy = -t * 2.4
				player.wal = clamp(1.0 - t / 22.0, 0, 1)
				if t >= 24:
					_warp_jump()
			"door":
				player.wpose = ""
				var dx: float = w.cx - (player.x + player.w / 2)
				player.x += clamp(dx, -2.2, 2.2)
				player.anim += .1
				player.face = 1 if dx >= 0 else -1
				player.wal = clamp(1.0 - (t - 8) / 16.0, 0, 1)
				if t >= 26:
					_warp_jump()
			_:
				# anda até a boca, se abaixa e entra engatinhando, sumindo na sombra
				var dx2: float = w.cx - (player.x + player.w / 2)
				if t <= 12 and abs(dx2) > 1.5:
					player.wpose = ""
					player.x += clamp(dx2, -2.6, 2.6)
					player.anim += .12
					player.face = 1 if dx2 > 0 else -1
				elif t <= 20:
					player.wpose = "crouch"
				else:
					player.wpose = "crawl"
					var u: float = (t - 20) / 22.0
					var dd: int = int(w.e.get("dir", 0))
					if dd != 0:
						# entra engatinhando pela boca do tronco
						player.face = dd
						player.x += dd * 1.5
						player.wdy = u * 4
					else:
						player.wdy = u * 30
					player.wal = clamp(1.0 - u, 0, 1)
					if t % 5 == 0:
						PARTS.append({"x": w.cx + (rng.randf() - .5) * 30, "y": w.e.y + 2, "vx": (rng.randf() - .5) * 2, "vy": -1.5 - rng.randf(), "life": 18, "col": Color(.6, .5, .32, .8)})
				if t >= 42:
					_warp_jump()
	else:
		var from_below: bool = w.mode == "up"
		match w.mode:
			"door":
				player.wpose = ""
				player.wdy = 0.0
				player.wal = clamp(t / 16.0, 0, 1)
				if t >= 18:
					_warp_end()
			_:
				var u2: float = clamp(t / 22.0, 0, 1)
				player.wal = u2
				var od: int = int(w.e.get("odir", 0))
				if from_below and od != 0:
					# sai engatinhando pela boca do tronco, levanta e sacode a poeira
					player.face = od
					if t <= 22:
						player.x += od * 1.4
					player.wdy = 0.0
					player.wpose = "crawl" if t < 22 else ("crouch" if t < 30 else "")
				elif from_below:
					player.wdy = (1.0 - u2) * 30
					player.wpose = "crawl" if t < 22 else ("crouch" if t < 30 else "")
				else:
					# cai do buraco para dentro do esconderijo
					player.wdy = -(1.0 - u2) * (1.0 - u2) * 40
					player.wpose = "crouch" if t < 28 else ""
				if t == 30:
					player.squash = .5
					fx("fx_dust", player.x + player.w / 2, player.y + player.h - 6, 18, .12, -.2)
					burst(player.x + player.w / 2, player.y + 6, 8, Color(.75, .65, .45, .9))
					Audio.play("slide", -12)
				if t >= 36:
					_warp_end()

func _warp_jump() -> void:
	var w: Dictionary = player.warp
	var e: Dictionary = w.e
	if e.get("mode", "") == "door" and X.dog_free() and X.DOG.st in ["follow", "sit", "stay"]:
		X.DOG.st = "door"
	player.x = e.to[0] - player.w / 2 - int(e.get("odir", 0)) * 31
	player.y = e.to[1] - player.h
	_rest_player()
	w.ph = "out"
	w.t = 0
	iris_t = 30
	Audio.play("door")
	snap_camera()
	if e.get("label", "") != "":
		flash(e.label)

## pousa o Tomé no chão mais próximo do ponto de chegada
func _rest_player() -> void:
	var feet: float = player.y + player.h
	var best := INF
	for s in blockers():
		if player.x + player.w > s.x and player.x < s.x + s.w and s.y >= feet - 30 and s.y < best:
			best = s.y
	if best < INF and best - feet < 80:
		player.y = best - player.h
		player.onGround = true

func _warp_end() -> void:
	player.warp = {}
	player.wdy = 0.0
	player.wal = 1.0
	player.wpose = ""
	player.iframe = max(player.iframe, 10)

# ======================================================================
#  COLISÃO
# ======================================================================
func move_x(dx: float) -> void:
	player.x += dx
	for s in near_blockers():
		if s.get("oneway") or not hit(player, s):
			continue
		if s.get("crate") and dx != 0 and M.try_push(s, dx):
			if not hit(player, s):
				continue
		# degrau baixo: sobe sozinho
		if player._g and not s.get("crate") and (player.y + player.h) - s.y <= 12 and (player.y + player.h) - s.y > 0:
			player.y = s.y - player.h
			continue
		# ajuda na quina: no ar, descendo ou no alto do pulo, com os pés só um pouco abaixo do topo
		if player._g == null and player.coyote <= 0 and not player.ladder and player.vy > -1.5 and (player.y + player.h) - s.y <= 10 and (player.y + player.h) - s.y > 0:
			player.y = s.y - player.h
			continue
		# agarra na beirada: o pulo ficou curto, mas as mãos alcançam o topo -> ele sobe
		var lift: float = (player.y + player.h) - s.y
		if dx != 0 and player._g == null and player.get("mantleT", 0) == 0 and not player.ladder and not player.vine and not player.swim \
				and not player.dog and not player.crouch and player.vy > -1.5 and lift > 10 and lift <= 40 and not s.get("crate") \
				and player.wlock == 0 and player.wsl == 0 and player.lastWall == 0 \
				and kd("R" if dx > 0 else "L"):
			var tx: float = s.x + 2 if dx > 0 else s.x + s.w - player.w - 2
			var ty: float = s.y - player.h
			if _ledge_free(tx, ty):
				player.x = s.x - player.w if dx > 0 else s.x + s.w
				player.mantleT = 16
				player.mx0 = player.x
				player.my0 = player.y
				player.mx1 = tx
				player.my1 = ty
				player.vx = 0
				player.vy = 0
				player.face = 1 if dx > 0 else -1
				Audio.play("climb", -8)
				return
		if dx > 0:
			player.x = s.x - player.w
		elif dx < 0:
			player.x = s.x + s.w
		else:
			player.x = s.x - player.w if (player.x + player.w / 2 < s.x + s.w / 2) else s.x + s.w
		player.vx = 0
		player.run = 0

## molas das tábuas e galhos: afundam com o peso do Tomé e voltam balançando
var DIPS: Array = []
func _plat_dips() -> void:
	var gs = player.get("_g")
	var lily: bool = gs is Dictionary and gs.get("lily", 0) == 1
	if gs is Dictionary and (lily or str(gs.get("t", "")) in ["plat", "branch"]) and not gs.get("crumble"):
		if not gs.has("dip"):
			gs.dip = 0.0
			gs.dipv = 0.0
		if not DIPS.has(gs):
			DIPS.append(gs)
			gs.dipv += 1.6 + max(0.0, player.get("landV", 0.0)) * .25
			if lily:
				# vitória-régia: afunda com o tranco do pouso, respingo e ondinhas em volta
				var lx: float = player.x + player.w / 2
				gs.dipv += max(0.0, player.get("landV", 0.0)) * .2
				X.ripple(lx, gs.y + 8, 1.3)
				X.ripple(gs.x + gs.w / 2, gs.y + 8, .8)
				if player.get("landV", 0.0) > 3.0:
					WV.splash(lx, gs.y + 8, min(5.0, player.landV * .5), false)
					for k in 6:
						PARTS.append({"x": lx + randf_range(-gs.w * .5, gs.w * .5), "y": gs.y + 6, "vx": randf_range(-1.6, 1.6), "vy": -randf_range(1.5, 3.4), "life": 22, "col": Color(.78, .92, .82, .9)})
	var keep: Array = []
	for d in DIPS:
		var target: float = 0.0
		if d == gs:
			target = 3.4 if d.get("lily", 0) == 1 else (2.5 if str(d.t) == "plat" else 3.5)
		d.dipv = (d.dipv + (target - d.dip) * .18) * .82
		d.dip += d.dipv
		if d.get("lily", 0) == 1:
			# a folha inclina para o lado em que o Tomé está e volta boiando quando ele sai
			var tt: float = 0.0
			if d == gs:
				var off: float = player.x + player.w / 2 - (d.x + d.w / 2)
				d.piv = clamp(off, -d.w / 2, d.w / 2)
				tt = clamp(off / (d.w / 2), -1.0, 1.0) * .09
			d.tiltv = (float(d.get("tiltv", 0.0)) + (tt - float(d.get("tilt", 0.0))) * .16) * .8
			d.tilt = float(d.get("tilt", 0.0)) + d.tiltv
			if abs(d.tilt) > .003 or abs(d.tiltv) > .003:
				keep.append(d)
				continue
		if d == gs or abs(d.dip) > .05 or abs(d.dipv) > .05:
			keep.append(d)
		else:
			d.dip = 0.0
	DIPS = keep

## ponto seguro automático: em chão firme, longe de buracos, armadilhas, inimigos e arenas de chefe,
## bem depois da última fogueira — ao cair, o Tomé volta logo antes do desafio
func _auto_safe() -> void:
	if T % 30 != 0 or not player.onGround or player.dog or player.swim or (VH and VH.active()) or (RD and RD.riding):
		return
	var s = player.get("_g")
	if s == null or not (s is Dictionary) or str(s.get("t", "")) not in ["ground", "cliff"] or s.get("oneway") or s.get("street"):
		return
	var px: float = player.x + player.w / 2
	if px < player.spawnX + 1400 or abs(player.vx) > 4:
		return
	if px < s.x + 90 or px > s.x + s.w - 90:
		return
	for k in ["boss", "bear", "hawk"]:
		var a = L.get(k)
		if a is Dictionary and px > float(a.get("x0", 0)) - 300 and px < float(a.get("x1", 0)) + 200:
			return
	for pit in L.get("pits", []):
		if px > pit[0] - 160 and px < pit[1] + 160:
			return
	if TR:
		for o in TR.T:
			if abs(o.get("x", -9999.0) - px) < 260:
				return
	for e in EN:
		if not e.dead and abs(e.x - px) < 420:
			return
	if X.water_at(px, player.y + player.h + 4) != null or player.mud:
		return
	player.spawnX = player.x
	player.spawnY = player.y

## distância do alto da caixa até o sólido logo acima (99 = céu livre); só para o desenho
func _ceil_gap() -> float:
	var top: float = player.y
	var best := 99.0
	for s in near_blockers():
		if s.get("oneway"):
			continue
		if s.x >= player.x + player.w - 3 or s.x + s.w <= player.x + 3:
			continue
		var b: float = s.y + float(s.get("h", 0.0))
		if b <= top + 1.0 and top - b < best:
			best = top - b
	return best

## caindo e com chão firme logo abaixo dos pés (pousa no próximo quadro)?
func _ground_near() -> bool:
	if player.vy < 2.0 or player.slam or player.puff:
		return false
	var feet: float = player.y + player.h
	var reach: float = player.vy + GRAV * 1.1 + 1.0
	var r := R(player.x + 2, feet, player.w - 4, reach)
	for s in near_blockers():
		if s.get("oneway") and (s.y < feet - 1 or player.dropT > 0):
			continue
		if s.get("crate") and s.get("t") == "break":
			continue   # caixa que quebra com o peso: não segura o pouso
		if hit(r, s):
			return true
	return false

## cabe o Tomé em pé em (x, y)? (para subir numa beirada)
func _ledge_free(x: float, y: float) -> bool:
	var r := R(x, y - 2, player.w, player.h)
	for o in near_blockers():
		if o.get("oneway"):
			continue
		if hit(r, o):
			return false
	return true

## subindo na beirada: primeiro o corpo sobe pendurado, depois passa por cima
func _mantle_step() -> void:
	player.mantleT -= 1
	var u: float = 1.0 - player.mantleT / 16.0
	if u < .6:
		var k: float = u / .6
		player.x = player.mx0
		player.y = lerpf(player.my0, player.my1 - 4, k * k * (3 - 2 * k))
	else:
		var k2: float = (u - .6) / .4
		player.x = lerpf(player.mx0, player.mx1, k2)
		player.y = player.my1 - 4 * (1.0 - k2)
	player.vx = 0
	player.vy = 0
	if player.mantleT == 0:
		player.x = player.mx1
		player.y = player.my1
		player.vy = 1
		# já está em cima da beirada: esquece a parede que escalou
		player.wall = 0
		player.wallT = 0
		player.wsl = 0
		player.squash = .3

func move_y(dy: float) -> void:
	var prev_feet: float = player.y + player.h
	player.y += dy
	player._g = null
	for s in near_blockers():
		if not hit(player, s):
			continue
		if s.get("oneway"):
			if dy > 0 and not (player.dropT > 0) and not player.ladder and prev_feet <= s.y + 1 + (2 if s.get("lily") else 0) - min(0.0, float(s.get("dy", 0.0))):
				player.y = s.y - player.h
				_land(s)
			continue
		if dy > 0:
			if s.get("crate") and s.t == "break" and (player.vy > 1 or player.slam):
				break_crate(s)
				if not player.slam:
					player.vy = -7
					player.cutOk = false
				continue
			player.y = s.y - player.h
			_land(s)
		elif dy < 0:
			if not s.get("crate"):
				var ol: float = (player.x + player.w) - s.x
				var orr: float = (s.x + s.w) - player.x
				if ol <= 8:
					player.x = s.x - player.w
					continue
				if orr <= 8:
					player.x = s.x + s.w
					continue
			player.y = s.y + s.h
			# cabeçada no teto: achata um pouquinho, poeira caindo e um "toc" baixinho
			if player.vy < -3.0 and not player.get("dog"):
				player.squash = max(player.squash, .28)
				Audio.play("stomp", -20, 1.4)
				for k in 4:
					PARTS.append({"x": player.x + player.w / 2 + (k - 1.5) * 5, "y": player.y + 1, "vx": (k - 1.5) * .5, "vy": .4 + k * .15, "life": 16, "col": Color(.72, .64, .5, .8)})
			player.vy = 0

## que chão está debaixo do Tomé (para o som do passo)
func ground_kind() -> String:
	var s = player.get("_g")
	if s == null or not (s is Dictionary):
		return "dirt"
	var t: String = str(s.get("t", ""))
	if s.get("snow") or t in ["ice", "snowbank"]:
		return "snow"
	if t in ["plat", "branch", "trunk", "log", "cabin", "treehouse", "wall", "damwall", "beam", "shed", "cart", "root"]:
		return "wood"
	if t in ["stone", "cliff", "hill"]:
		return "stone"
	if L.has("under") and player.y > L.under:
		return "dirt"
	match AMB.get("song", "manha"):
		"chuva":
			return "mud"
		"noite", "perseguicao", "tunel":
			return "dirt"
	return "grass"

func _land(s: Dictionary) -> void:
	player.launchT = 0
	player.combo = 0
	player.onGround = true
	player.coyote = COY
	player.airJumps = 0 if (player.get("dog") or player.get("isis")) else 1
	player.lastWall = 0
	player._g = s
	player.vy = 0

# ======================================================================
#  FASE 1: antes e depois da física
# ======================================================================
func _p1_pre(pcx: float) -> void:
	if player.ladderCD > 0:
		player.ladderCD -= 1
	if player.dropT > 0:
		player.dropT -= 1
	# entradas de esconderijo
	var nearE = null
	for e in ENTR:
		if player.onGround and not player.dog and pcx > e.x and pcx < e.x + e.w and abs(player.y + player.h - (e.y + e.h)) < 16:
			nearE = e
	var door_up: bool = nearE != null and (nearE.get("exit") or nearE.get("mode", "") == "door") and keys.get("Up", false)
	# entrar: ↓ na boca do esconderijo; sair: só com ↑ (o ↓ que ainda está apertado ao chegar lá embaixo não pode tirar o Tomé de volta)
	if nearE and ((keys.get("Sp", false) and nearE.get("mode", "") != "door" and not nearE.get("exit")) or door_up) and not player.ladder:
		keys.Sp = false
		keys.Up = false
		start_warp(nearE)
	player.nearE = nearE
	# agarrar escada / rede / corda
	var z = null
	for c in CLIMB:
		if pcx > c.x - 6 and pcx < c.x + c.w + 6 and player.y + player.h > c.y - 2 and player.y < c.y + c.h:
			z = c
			break
	if not player.ladder and z and not player.vine and player.ladderCD <= 0 and not player.dog:
		var at_top: bool = player.onGround and abs(player.y + player.h - z.y) < 6
		if (kd("U") and not at_top) or (kd("S") and at_top):
			stand_up()
			player.ladder = z
			player.vx = 0
			player.vy = 0
			player.slam = false
			player.puff = false
			player.run = 0
			player.airJumps = 1
			if at_top:
				player.y += 8
				player.dropT = 10
	if player.ladder:
		var l2: Dictionary = player.ladder
		if not (pcx > l2.x - 10 and pcx < l2.x + l2.w + 10 and player.y + player.h > l2.y - 4 and player.y < l2.y + l2.h + 4):
			player.ladder = null
	# abaixar / deslizar
	var wantC: bool = player.onGround and kd("S") and not player.ladder and nearE == null and not player.vine and not player.dog
	# passagem baixa à frente: o jogador precisa segurar ↓ (só avisa, não abaixa sozinho)
	var mdir := -1 if (kd("L") and not kd("R")) else (1 if (kd("R") and not kd("L")) else 0)
	if player.onGround and not player.crouch and not player.ladder and not player.vine and not player.swim and not player.dog and mdir != 0 and X.crawl_auto(mdir):
		tip("Passagem baixa: segure ↓ para se abaixar e passar.")
	if wantC and not player.crouch:
		player.crouch = true
		player.y += body_h() - crouch_h()
		player.h = crouch_h()
		if abs(player.vx) > 3.1 and not player.get("isis"):
			player.slideT = 1
			Audio.play("slide")
			fx("fx_dust", pcx, player.y + player.h - 4, 16, .14, -.2)
	elif player.crouch and not wantC and (not player.slideT or can_stand()):
		# soltou ↓ no meio do deslize (e cabe em pé): levanta já, com o embalo (antes o deslize
		# ia sozinho até quase parar, mais de um segundo sem controle)
		stand_up()
	# olhar para cima / para baixo
	var still: bool = player.onGround and abs(player.vx) < .4 and not kd("L") and not kd("R") and not player.ladder
	if still and kd("U") and z == null:
		player.lookT += 1
	elif still and player.crouch:
		player.lookT -= 1
	else:
		player.lookT = 0
	var tgt := -150.0 if player.lookT > 28 else (150.0 if player.lookT < -40 else 0.0)
	look_y += (tgt - look_y) * .08

func _p1_ladder() -> void:
	var z: Dictionary = player.ladder
	player.puff = false
	player.slam = false
	player.onGround = false
	var sp := 2.6
	player.vy = -sp if kd("U") else (sp if kd("S") else 0.0)
	if z.kind == "net":
		player.vx = -2.2 if kd("L") else (2.2 if kd("R") else 0.0)
	elif (kd("L") or kd("R")) and not kd("U") and not kd("S"):
		player.ladder = null
		player.ladderCD = 12
		player.vx = -2.4 if kd("L") else 2.4
		player.vy = 0
		return
	else:
		player.vx = 0
		player.x += ((z.x + z.w / 2) - (player.x + player.w / 2)) * .3
	if kd("L"):
		player.face = -1
	if kd("R"):
		player.face = 1
	if (player.vy != 0 or player.vx != 0) and T % 14 == 0:
		Audio.play("climb", -10)
	player.climbA += abs(player.vy) + abs(player.vx)
	if pressed("J"):
		player.ladder = null
		player.ladderCD = 14
		player.vy = JUMP * .82
		player.vx = (-1 if kd("L") else (1 if kd("R") else 0)) * 3.6
		player.cutOk = true
		player.airJumps = 1
		Audio.play("jump", -6)
	elif player.y + player.h < z.y + 3 and kd("U"):
		var ty: float = z.get("topY", z.y)
		var nx: float = z.get("topX", player.x)
		var sup_at = func(x: float) -> bool:
			for s in blockers():
				if x + player.w > s.x + 2 and x < s.x + s.w - 2 and abs(s.y - ty) < 8:
					return true
			return false
		var nx2 = null
		var sides: Array = [z.x + z.w + 1, z.x - player.w - 1] if player.face > 0 else [z.x - player.w - 1, z.x + z.w + 1]
		if sup_at.call(nx):
			nx2 = nx
		elif not z.has("topX"):
			for c in sides:
				if sup_at.call(c):
					nx2 = c
					break
		if nx2 != null:
			player.ladder = null
			player.ladderCD = 12
			player.x = nx2
			player.y = ty - player.h - 1
			player.vy = 0
			player.squash = .3
		else:
			player.vy = 0
			player.y = z.y - player.h + 3
			if T % 90 == 0:
				tip("Topo da escada: pule para o lado (PULAR + ← ou →).")

func _p1_post(pcx: float, _pcy: float) -> void:
	if player.ladder and player.onGround and kd("S"):
		player.ladder = null
	# vitórias-régias afundam
	for p in LILY:
		if p.st == 0:
			if player._g == p:
				p.t += 1
				if p.t > 50 and not p.get("keep"):
					p.st = 1
			else:
				p.t = max(0, p.t - 1)
			p.y = p.y0 + sin(T * .05 + p.x) * 1.5 + (min(p.t, 50) * .08 if p.t > 0 else 0.0)
		elif p.st == 1:
			p.y += .9
			if p.y > p.y0 + 26:
				p.st = 2
				p.tm = 150
				Audio.play("splash")
		else:
			p.tm -= 1
			if p.tm <= 0:
				p.st = 0
				p.t = 0
				p.y = p.y0
				# volta boiando: sobe lá do fundo com mola (passa um pouco do ponto e assenta)
				p.dip = 22.0
				p.dipv = -1.2
				p.tilt = 0.0
				p.tiltv = 0.0
				if not DIPS.has(p):
					DIPS.append(p)
				X.ripple(p.x + p.w / 2, p.y0 + 8, 1.0)
	# brejo
	for s in SWAMP:
		if s.get("drain") and s.y < s.y2:
			s.y = min(s.y2, s.y + 1.2)
		if player.y + player.h > s.y + 14 and player.y < s.y0 + s.h and pcx > s.x and pcx < s.x + s.w and player.dyingT == 0:
			WV.splash(pcx, s.y, 8.0)
			Audio.play("splash")
			burst(pcx, s.y, 14, Color("#9ab08a"))
			die("Você afundou no brejo.")
			return
	# itens, pistas, lápis especiais
	for it in ITEMS:
		if not it.got and abs(it.x - pcx) < 80 and hit(player, R(it.x - 20, it.y - 20, 40, 40)):
			it.got = true
			give_item(it.id)
			burst(it.x, it.y, 18, Color("#ffe9a0"))
	for c in CLUES:
		if not c.got and abs(c.x - pcx) < 80 and hit(player, R(c.x - 20, c.y - 20, 40, 40)):
			c.got = true
			CLUEGOT[int(c.id)] = 1
			Save.setv("gallery", "c%d" % int(c.id), true)
			Audio.play("clue")
			Audio.vib(80)
			clue_opened.emit(int(c.id))
			Polish.celebrate(player.x + player.w / 2, player.y + 10, false)
	for s in SPECS:
		if not s.got and abs(s.x - pcx) < 80 and hit(player, R(s.x - 20, s.y - 22, 40, 44)):
			s.got = true
			SPECGOT[s.c] = 1
			Audio.play("special")
			Audio.vib(30)
			burst(s.x, s.y, 22, GameData.PEN_COL[s.c])
			flash("Lápis especial " + s.c.to_upper() + "! (%d/6)" % SPECGOT.size())
	# usar perto de um obstáculo
	var nearL = null
	for l in LOCKS:
		if not l.done and not player.dog and hit(player, R(l.x - 40, l.y - 40, l.w + 80, l.h + 80)):
			nearL = l
			break
	player.nearL = nearL
	# já tem o objeto certo: chegando na trava, ele é usado sozinho (sem botão)
	if nearL and not nearL.done and not nearL.get("crank") and has_item(nearL.need) and not X.boss_active() \
			and hit(player, R(nearL.x - 12, nearL.y - 12, nearL.w + 24, nearL.h + 24)):
		use_lock(nearL)
	elif nearL and keys.get("Ap", false):
		keys.Ap = false
		if X.boss_active():
			flash("Agora não dá: o javali está em cima de você!", 120)
		elif has_item(nearL.need):
			if nearL.get("crank"):
				crank_tap(nearL)
			else:
				use_lock(nearL)
		elif parts_ready(nearL):
			# as peças estão na mochila, mas soltas: abre a mochila para juntar
			bag_wanted.emit(nearL)
		else:
			flash(lock_msg(nearL), 260)
			Audio.vib(15)
	# portas de manivela
	_cranks_step(nearL)
	VL.post()
	var __qX := Time.get_ticks_usec()
	X.post()
	Spr.pt("p_X", __qX)
	var __qM := Time.get_ticks_usec()
	M.post()
	Spr.pt("p_M", __qM)
	var __qPR := Time.get_ticks_usec()
	PR.post()
	Spr.pt("p_PR", __qPR)
	var __qTR := Time.get_ticks_usec()
	TR.post()
	Spr.pt("p_TR", __qTR)
	var __qK := Time.get_ticks_usec()
	K.post()
	Spr.pt("p_K", __qK)
	var __qNT := Time.get_ticks_usec()
	NT.post()
	Spr.pt("p_NT", __qNT)
	var __qRD := Time.get_ticks_usec()
	RD.post()
	Spr.pt("p_RD", __qRD)
	var __qVH := Time.get_ticks_usec()
	VH.check_river()
	VH.check_plane()
	VH.check_sled()
	Spr.pt("p_VH", __qVH)
	WV.step()
	var __qZN := Time.get_ticks_usec()
	ZN.post()
	Spr.pt("p_ZN", __qZN)
	# vilão foge
	if VIL:
		if not VIL.go and pcx > VIL.trig and pcx < L.spanX:
			VIL.go = true
			start_cine("vargas", VIL.x - 40, VIL.y - 40, 300,
				[[44, 135, "VARGAS", "Desista, Tomé! Quem mandou abrir a boca sobre o dinheiro da mina?", "vargas"],
				[135, 205, "ISIS", "PAPAI! ME AJUDA!", "lia"],
				[205, 290, "TOMÉ", "Aguenta firme, filha! Eu vou te buscar!", "tome"]],
				[8, 44, "ADEMAR VARGAS", "o gerente ladrão"])
		if VIL.go and not VIL.gone:
			if VIL.get("chase"):
				# perseguição: o carrinho fica sempre um pouco à frente (nunca dá para alcançar)
				var d: float = VIL.x - pcx
				var v: float = clamp(2.4 + (420.0 - d) * .02, 1.0, 6.8)
				VIL.x += v
				VIL.spd = v
				VIL.coal_t = VIL.get("coal_t", 70) - 1
				if VIL.coal_t <= 0 and d > 140 and d < 720 and not no_coal and player.dyingT == 0:
					VIL.coal_t = 80 + rng.randi() % 50
					COAL.append({"x": VIL.x - 40, "y": VIL.y - 74, "vx": -(2.6 + rng.randf() * 1.6), "vy": -5.5 - rng.randf() * 1.5, "b": 0, "life": 260, "rot": 0.0})
					Audio.play("slide", -6)
					note("Cuidado: o Vargas está jogando carvão em brasa!")
					Audio.play("stomp", -10)
			else:
				VIL.x += 3.3
			if VIL.x > VIL.gateX:
				VIL.gone = true
				burst(VIL.gateX, VIL.y - 30, 20, Color("#ffd28a"))
				Audio.play("door", -4)
				shake = 6
	var __qupdatecoal := Time.get_ticks_usec()
	_update_coal()
	Spr.pt("p_updatecoal", __qupdatecoal)
	var __qambient := Time.get_ticks_usec()
	ambient()
	Spr.pt("p_ambient", __qambient)
	# raio na tempestade
	if AMB.rain > .6:
		thunder_t -= 1
		if thunder_t <= 0:
			thunder_t = 320 + rng.randi() % 420
			lightning = 10
			thunder_snd = 18 + rng.randi() % 42
	if thunder_snd > 0:
		thunder_snd -= 1
		if thunder_snd == 0:
			Audio.play("thunder", -4)
	if lightning > 0:
		lightning -= 1

func _update_coal() -> void:
	for c in COAL:
		c.vy += .35
		c.x += c.vx
		c.y += c.vy
		c.rot += c.vx * .08
		c.life -= 1
		if T % 3 == 0:
			c.gy = _rest_y(c.x, c.y, 500)
		if not c.get("k", "") in ["dirt", "acorn"] and T % 2 == 0:
			PARTS.append({"x": c.x, "y": c.y, "vx": -c.vx * .2 + (rng.randf() - .5), "vy": -.5 - rng.randf(), "life": 14, "col": Color(1, .55 + rng.randf() * .3, .15)})
		for s in SOL:
			if s.get("oneway"):
				continue
			if c.x > s.x and c.x < s.x + s.w and c.y + 7 >= s.y and c.y + 7 <= s.y + 20 and c.vy > 0:
				c.y = s.y - 7
				if c.get("k", "") in ["dirt", "acorn"]:
					c.life = 0
					burst(c.x, c.y + 4, 10, Color("#7a5a3a"))
					break
				if c.b < 1:
					c.vy = -c.vy * .45
					c.b += 1
					burst(c.x, c.y + 6, 4, Color(.3, .3, .32))
				else:
					c.vy = 0
					c.vx *= .97
		if c.get("ref"):
			for e in EN:
				if not e.dead and hit(R(c.x - 11, c.y - 11, 22, 22), ebox(e)):
					kill_enemy(e, "hit")
					c.life = 0
			continue
		if c.life > 0 and player.dyingT == 0 and hit(player, R(c.x - 11, c.y - 11, 22, 22)) and M.blocks(c.x - c.vx * 10):
			M.reflect(c)
			continue
		if c.life > 0 and player.dyingT == 0 and hit(player, R(c.x - 11, c.y - 11, 22, 22)):
			hurt(1, c.x - c.vx * 10)
			c.life = 0
			burst(c.x, c.y, 10, Color(.25, .25, .27) if not c.get("k", "") in ["dirt", "acorn"] else Color("#7a5a3a"))
	COAL = COAL.filter(func(c): return c.life > 0 and c.y < L.bottom)

## em cima de um lago de veneno: o vapor não deixa planar
func in_fumes() -> bool:
	var pcx: float = player.x + player.w / 2
	for sw in SWAMP:
		if sw.get("fumes") and pcx > float(sw.x) - 10 and pcx < float(sw.x) + float(sw.w) + 10 and player.y < float(sw.y):
			return true
	return false

## todas as peças de uma trava estão na mochila (falta só juntar)
func parts_ready(l) -> bool:
	if l == null or l.done or has_item(l.need) or not l.has("parts"):
		return false
	for p in l.parts:
		if not has_item(p):
			return false
	return true

## o que o botão de usar faz agora: "bag" (abrir a mochila e juntar), "check" (usar o que juntou),
## "crank" (girar a manivela) ou "hand" (usar normal)
func use_mode() -> String:
	if player.dyingT > 0 or player.get("dog") or (M and M.is_dog()) or (X and X.boss_active()):
		return "hand"
	var l = player.nearL
	if l != null and not l.done:
		if has_item(l.need):
			return "crank" if l.get("crank") else "check"
		if parts_ready(l):
			return "bag"
	if near_crank() != null:
		return "crank"
	return "hand"

func near_crank():
	if player.get("dog") or player.dyingT > 0:
		return null
	var pcx: float = player.x + player.w / 2
	for c in CRANKS:
		if not c.done and abs(pcx - float(c.x)) < 70 and abs(player.y + player.h - float(c.y)) < 40:
			return c
	return null

## a porta (sólido) ligada a uma manivela
func crank_gate(c: Dictionary):
	# guarda a porta achada (procurar nos centenas de sólidos a cada passo pesava)
	var cg = c.get("_gate")
	if cg != null and (T % 120 != 0 or SOL.has(cg)):
		return cg
	var gid: String = c.get("gate", "")
	for s in SOL:
		if s.get("id", "") == gid:
			c._gate = s
			return s
	return null

## um toque em USAR: a manivela dá uma volta e a porta sobe um pouco (6 voltas abrem de vez)
func crank_tap(c: Dictionary) -> void:
	if c.done:
		return
	c.turn = min(1.0, float(c.turn) + 1.0 / 6.0)
	c.idle = 0
	player.face = 1 if float(c.get("x", player.x)) >= player.x else -1
	player.act = "crank"
	player.actT = 14
	Audio.play("climb", -2, .8 + c.turn * .4)
	Audio.vib(25)
	shake = max(shake, 1.5)
	if c.turn >= .999:
		if c.has("need"):
			use_lock(c)
		else:
			c.done = true
			Audio.play("door")
			Audio.vib(80)
			flash("A porta subiu! Pode passar.", 140)
	elif c.turn < .2:
		flash("Continue girando: toque mais vezes no botão da manivela!", 120)

func _cranks_step(nearL) -> void:
	var nc = near_crank()
	if nc != null and keys.get("Ap", false):
		keys.Ap = false
		crank_tap(nc)
	for c in CRANKS:
		_crank_decay(c)
		var gt = crank_gate(c)
		if gt != null:
			# girando, a porta pesada só desgruda do chão (sem abrir um vão onde o Tomé caberia
			# mas que ainda não deixa passar); na última volta ela sobe de vez, sem pular de uma vez
			var want: float = 1.0 if c.done else float(c.turn) * .2
			gt.open = move_toward(float(gt.open), want, .05 if c.done else .03)
	for l in LOCKS:
		if l.get("crank"):
			_crank_decay(l)

## largou a manivela no meio: a porta vai descendo devagar
func _crank_decay(c: Dictionary) -> void:
	if c.done:
		return
	c.idle = int(c.idle) + 1
	if int(c.idle) > 50 and float(c.turn) > 0.0:
		c.turn = max(0.0, float(c.turn) - .004)
	c.ang = float(c.get("ang", 0.0))

func use_lock(l: Dictionary) -> void:
	l.done = true
	INV.erase(l.need)
	Audio.play("unlock")
	Audio.vib(120)
	shake = 8
	if l.kind == "hook":
		player.act = "throw2"
		player.actT = 36
		CLIMB.append({"x": l.ring[0] - 10, "y": l.ring[1], "w": 20, "h": l.ground - l.ring[1], "kind": "rope", "topX": l.topX, "topY": l.topY})
		flash("O gancho prendeu na argola! Suba pela corda (↑).")
	elif l.kind == "dam":
		for s in SWAMP:
			if s.get("id") == l.water:
				s.drain = true
		SOL = SOL.filter(func(s): return s.get("id") != l.gate)
		flash("A comporta abriu! A água está baixando...")
	elif l.kind == "mill":
		# velas novas no moinho: as pás começam a girar (as tábuas das pontas levam o Tomé para cima)
		flash(l.get("msg", "Velas novas! O vento pegou e as pás começaram a girar."), 200)
	elif l.kind == "gate":
		# a porteira sobe devagar (Village.pre anima)
		for s in SOL:
			if s.get("id") == l.gate:
				s.unlocking = true
		blockers_dirty()
		Audio.play("door")
		flash(l.get("msg", "Abriu!"), 180)
	elif l.kind == "dark":
		INV.append("lanterna_acesa")
		SOL = SOL.filter(func(s): return s.get("id") != l.barrier)
		lantern_lit = true
		flash("A lanterna brilha forte de novo. Agora dá para entrar no túnel.")

## óleo da lanterna: frascos pelo caminho escuro (antes de cada queda); a luz cresce aos poucos
## e diminui bem devagar enquanto está escuro. Com a lanterna apagada, são potes de vaga-lumes.
## perseguição final do Vargas (depois do túnel)
func chase_on() -> bool:
	if VIL == null or not L.has("villain") or not L.villain.get("chase"):
		return false
	return player.x > float(L.villain.trig) - 200.0 and not VIL.get("gone", false)

func _fuel_step() -> void:
	var pcx0: float = player.x + player.w / 2
	for c in OIL:
		if c.got or abs(c.x - pcx0) > 60:
			continue
		var cyy: float = c.ry - 16 if c.ry > 0 else c.y
		if hit(player, R(c.x - 20, cyy - 22, 40, 44)):
			c.got = true
			FUEL = min(1.0, FUEL + .42)
			Audio.play("pen")
			burst(c.x, cyy, 16, Color("#ffd27a") if lantern_lit else Color("#c8ff8a"))
			if not oil_seen:
				oil_seen = true
				if lantern_lit:
					flash("Óleo para a lanterna: a luz vai crescendo. No escuro ela gasta devagar.")
				else:
					flash("Um pote de vaga-lumes! Eles clareiam um pouco o caminho.")
	if chase_on() or player.get("isis"):
		# perseguição do Vargas (e a fuga da Isis): luz cheia o tempo todo
		FUEL = 1.0
		fuel_vis = min(1.0, fuel_vis + .02)
		return
	if AMB.dark > .45:
		FUEL = max(.15, FUEL - 1.0 / 3000.0)
	# a luz cresce aos poucos (~3 s) e diminui ainda mais devagar
	if fuel_vis < FUEL:
		fuel_vis = min(FUEL, fuel_vis + .005)
	else:
		fuel_vis = max(FUEL, fuel_vis - .0015)

# ======================================================================
#  INIMIGOS, DANO E MORTE
# ======================================================================
func ebox(e: Dictionary) -> Dictionary:
	if e.k == "plant":
		if e.dead or e.stun > 0:
			return R(-9999, -9999, 0, 0)
		return TR.plant_box(e)
	if e.k == "spider":
		return R(e.x - 16, e.y - 14, 32, 28)
	if e.k == "mole":
		if e.dead:
			return R(-9999, -9999, 0, 0)
		if e.get("st", 0) in [2, 3]:
			return R(e.x - 18, e.base - 30, 36, 30)
		if e.get("st", 0) == 5:
			return R(e.x - 22, e.base - 22, 44, 22)
		return R(-9999, -9999, 0, 0)
	if e.k == "bat" and e.get("st", 0) == 0:
		return R(e.x - 12, e.y - 2, 24, 26)
	if e.k == "leech":
		# a área de perigo cresce e encolhe junto com o corpo que sai da poça (sem pegar o Tomé
		# com a sanguessuga ainda escondida)
		var lu: float = leech_up(int(e.get("lt", 0)) % 200)
		if e.get("hid", true) or e.dead or lu < .2:
			return R(-9999, -9999, 0, 0)
		return R(e.x - 16, e.y - 40 * lu, 32, 40 * lu)
	if e.k == "crow":
		return R(e.x - 30, e.y - 18, 60, 30)
	if FLY.has(e.k):
		return R(e.x - 22, e.y - 8, 44, 22)
	return R(e.x - 20, e.y - 34, 40, 34)

## quanto a sanguessuga está para fora da poça (0 = escondida, 1 = esticada) no tempo t do ciclo de 200
static func leech_up(t: int) -> float:
	if t < 88 or t >= 190:
		return 0.0
	if t < 100:
		var u: float = (t - 88) / 12.0
		return u * u * (3.0 - 2.0 * u)
	if t >= 180:
		return 1.0 - (t - 180) / 10.0
	return 1.0

## voa/nada de um lado a outro fazendo a curva: desacelera perto da ponta e volta aos poucos
func _glide(e: Dictionary, sp: float) -> void:
	var edge: float = (e.r[1] - e.x) if e.dir > 0 else (e.x - e.r[0])
	if edge < 40:
		e.dir = -e.dir if edge < 2 else e.dir
	var tv: float = e.dir * sp * clamp(edge / 40.0, .15, 1.0) if edge >= 2 else e.dir * sp * .15
	var fv: float = move_toward(float(e.get("fv", e.dir * sp)), tv, .07)
	e.fv = fv
	e.x = clamp(e.x + fv, e.r[0], e.r[1])
	if e.x <= e.r[0]:
		e.dir = 1
	elif e.x >= e.r[1]:
		e.dir = -1

func _dust_col() -> Color:
	var gk := ground_kind()
	if gk == "snow":
		return Color(.95, .97, 1, .75)
	if gk == "grass":
		return Color(.5, .6, .36, .45)
	return Color(.62, .55, .42, .5)

func update_enemy(e: Dictionary) -> void:
	_update_enemy_core(e)
	_enemy_life(e)

## vida dos bichos (estilo animação 3D): poeirinha nos passos e no pouso
func _enemy_life(e: Dictionary) -> void:
	var lx: float = e.get("_lx2", e.x)
	e._lx2 = e.x
	if e.dead or FLY.has(e.k) or e.k in ["crow", "bat", "spider", "piranha", "leech", "plant", "owl", "mole"]:
		return
	var vx: float = e.x - lx
	var on: bool = abs(e.y - float(e.get("base", e.y))) < 2
	if e.get("landT", 0) > 0:
		e.landT -= 1
	if on and not e.get("_on", true):
		# pousou: poeira e achata (o desenho usa landT); o sapo respinga água
		e.landT = 10
		if e.k == "frog":
			Polish.drops(e.x, e.y - 4, 5, 2.4)
		for k in (5 if e.k == "frog" else 3):
			PARTS.append({"x": e.x + (k - 2) * 7, "y": e.y - 1, "vx": (k - 2) * .7, "vy": -randf_range(.4, 1.2), "life": 16, "col": _dust_col()})
	e._on = on
	if e.k == "frog":
		return
	if on and abs(vx) > .3:
		e._sd = float(e.get("_sd", 0.0)) + abs(vx)
		var stp := 34.0 if abs(vx) < 2 else 22.0
		if e._sd > stp:
			e._sd -= stp
			for k in (2 if abs(vx) > 2 else 1):
				PARTS.append({"x": e.x - sign(vx) * (14 + k * 4), "y": e.y - 1, "vx": -sign(vx) * randf_range(.3, 1.2), "vy": -randf_range(.3, .9), "life": 14, "col": _dust_col()})

func _update_enemy_core(e: Dictionary) -> void:
	if e.stun > 0:
		e.stun -= 1
		return
	if e.k == "plant":
		TR.plant_update(e)
		return
	if e.k == "squirrel":
		NT.squirrel(e)
		return
	if e.k == "crow":
		_crow(e)
		return
	if e.k == "piranha":
		_piranha(e)
		return
	if e.k == "leech":
		e.lt = e.get("lt", e.get("ph", 0)) + 1
		var t: int = int(e.lt) % 200
		e.hid = t < 95 or t >= 188
		e.y = e.base
		e.dir = 1 if player.x > e.x else -1
		if t == 88 and abs(player.x - e.x) < 600:
			# a poça borbulha e respinga logo antes de ela sair (aviso)
			Polish.drops(e.x, e.y - 4, 6, 2.0, Color(.42, .5, .3, .85))
		if t == 95 and abs(player.x - e.x) < 600:
			Audio.play("splash", -8)
		return
	if e.k == "frog":
		e.jt = e.get("jt", 0) + 1
		var t: int = int(e.jt) % 130
		if t == 66 or not e.has("jdir"):
			# decide o lado do pulo antes de agachar: vira já (a virada leva ~12 quadros) e pula
			# olhando para a frente, em vez de sair de costas e virar no ar
			var dx: float = player.x - e.x
			e.jdir = (sign(dx) if dx != 0 else 1) if abs(dx) < 300 else (1 if e.x < (e.r[0] + e.r[1]) / 2.0 else -1)
			if t >= 66 and t < 100:
				e.dir = e.jdir
		if t == 100:
			Polish.drops(e.x, e.y - 10, 4)
		if t >= 100:
			var u := (t - 100) / 30.0
			e.leap = 1
			e.dir = e.jdir
			e.x = clamp(e.x + e.jdir * 2.6, e.r[0], e.r[1])
			e.y = e.base - sin(u * PI) * 80
		else:
			e.leap = 0
			e.y = e.base
		return
	if e.k == "bat":
		_bat(e)
		return
	if e.k == "spider":
		_spider(e)
		return
	if e.k == "mole":
		_mole(e)
		return
	if e.k == "owl":
		var st: int = e.get("st", 0)
		if st != 3 and X.scare(e.x, e.y):
			e.st = 3
			e.t = 0
			e.dir = -1 if player.x + player.w / 2 > e.x else 1
			Audio.play("dj", -8)
			return
		if st == 3:
			e.t += 1
			e.x = clamp(e.x + e.dir * 2.4, e.r[0], e.r[1])
			e.y -= 2.2 if e.t < 60 else 0.0
			if e.t > 220:
				e.st = 2
				e.t = 0
			return
		if st == 0:
			e.st = 0
			e.y = e.cy + sin(T * .05) * 3
			var dx: float = player.x + player.w / 2 - e.x
			if abs(dx) < 240 and player.y > e.y - 10 and player.dyingT == 0:
				e.st = 1
				e.t = 0
				e.sx = e.x
				e.sy = e.y
				e.tx = player.x + player.w / 2
				e.ty = player.y + 10
				e.dir = sign(dx) if dx != 0 else 1
		elif st == 1:
			e.t += 1
			var u: float = e.t / 80.0
			e.x = clamp(e.sx + (e.tx - e.sx) * min(1, u * 1.6), e.r[0], e.r[1])
			e.y = e.sy + (e.ty - e.sy) * sin(min(1, u) * PI)
			if e.t >= 80:
				e.st = 2
				e.t = 0
		else:
			e.t += 1
			e.x += (e.sx - e.x) * .04
			e.y += (e.cy - e.y) * .06
			if e.t > 140:
				e.st = 0
		return
	if FLY.has(e.k):
		_glide(e, 1.8)
		e.y = e.cy + sin(T * .05 + e.x * .02) * 30
		return
	# javali (anda e investe)
	var spd := 1.1
	if e.k == "boar":
		var dx2: float = player.x + player.w / 2 - e.x
		var dy2: float = player.y + player.h - e.base
		var ch: bool = abs(dx2) < 230 and abs(dy2) < 40 and dx2 * e.dir > 0
		# antecipação (como em animação): antes de investir ele recua, raspa a pata e só então dispara
		if ch and not e.get("charge") and e.get("wind", 0) == 0:
			e.wind = 16
			Audio.play("stomp", -16)
		e.charge = ch
		if e.get("wind", 0) > 0:
			e.wind -= 1
			e.cs = -.5 if e.wind > 8 else 0.0
			e.x = clamp(e.x - e.dir * .5 if e.wind > 8 else e.x, e.r[0], e.r[1])
			if e.wind % 4 == 0:
				PARTS.append({"x": e.x - e.dir * 18, "y": e.base - 2, "vx": -e.dir * randf_range(1.0, 2.2), "vy": -randf_range(.8, 1.8), "life": 16, "col": _dust_col()})
			e.y = e.base
			return
		if e.charge:
			spd = 2.7
	# freia chegando na ponta do caminho, vira e arranca de novo (sem dar meia-volta seca)
	var edge: float = (e.r[1] - e.x) if e.dir > 0 else (e.x - e.r[0])
	if not e.get("charge"):
		spd = min(spd, max(.2, edge * .07))
	else:
		# investindo também freia antes da ponta (derrapa levantando poeira, sem parar num estalo)
		var brake: float = sqrt(.4 * max(0.0, edge)) * .95
		if brake < spd:
			spd = max(.2, brake)
			if T % 3 == 0 and float(e.get("cs", 0.0)) > 1.0:
				PARTS.append({"x": e.x + e.dir * 10, "y": e.base - 2, "vx": e.dir * randf_range(.6, 1.8), "vy": -randf_range(.5, 1.4), "life": 16, "col": _dust_col()})
	# arranca e freia com peso (não muda de 1 para 2,7 num quadro só)
	var cs: float = move_toward(float(e.get("cs", spd)), spd, .12 if spd >= float(e.get("cs", 0.0)) else .2)
	e.cs = cs
	spd = cs
	e.x += e.dir * spd
	if e.x < e.r[0]:
		e.x = e.r[0]
		e.dir = 1
		e.cs = 0.0
	if e.x > e.r[1]:
		e.x = e.r[1]
		e.dir = -1
		e.cs = 0.0
	e.y = e.base

## corvo: voa de um lado a outro e dá rasantes quando o Tomé passa embaixo
func _crow(e: Dictionary) -> void:
	var st: int = e.get("st", 0)
	var pc := Vector2(player.x + player.w / 2, player.y + player.h / 2)
	e.t = e.get("t", 0) + 1
	# penas: uma de vez em quando batendo as asas, várias no mergulho
	if (st == 0 and rng.randf() < .006) or (st == 1 and rng.randf() < .12):
		Polish.part("feather", e.x - e.dir * 10, e.y - 4, -e.dir * randf_range(.3, 1.2), -randf_range(.2, .8), 140, Color(.13, .13, .17))
	if st == 0:
		_glide(e, 2.2)
		e.y = e.cy + sin(T * .06 + e.x * .01) * 16
		if abs(pc.x - e.x) < 230 and pc.y > e.y + 40 and e.t > (160 if e.get("minion") else 90) and player.dyingT == 0:
			# antes do mergulho ele para no ar batendo as asas e mostra o "!" vermelho
			e.st = 5
			e.t = 0
			e.dir = 1 if pc.x > e.x else -1
	elif st == 5:
		e.y += sin(T * .5) * .6 - .25
		if e.t >= 26:
			e.st = 1
			e.t = 0
			e.sx = e.x
			e.sy = e.y
			e.tx = pc.x + player.vx * 14
			# o rasante não entra no chão nem atravessa telhado/rocha que esteja embaixo dele
			# (o ponto mais baixo do arco fica a 80% do caminho até o alvo: confere o chão ali e no alvo)
			var lowx: float = clamp(e.sx + (e.tx - e.sx) * .8, e.r[0], e.r[1])
			var fl: float = min(floor_under(clamp(e.tx, e.r[0], e.r[1]), e.y + 20.0), floor_under(lowx, e.y + 20.0))
			e.ty = min(pc.y, fl - 22.0)
			e.dir = 1 if e.tx > e.x else -1
			Audio.play("dj", -12)
	else:
		var u: float = e.t / 56.0
		var nx: float = clamp(e.sx + (e.tx - e.sx) * u * 1.6, e.r[0], e.r[1])
		var ny: float = e.sy + (e.ty - e.sy) * sin(min(1.0, u) * PI)
		# não atravessa telhado, rocha nem quina de parede no meio do rasante: se o caminho bate,
		# ele para de avançar de lado (sobe/desce reto) ou espera ali mesmo
		if e.has("xl"):
			nx = e.xl
		if _crow_blocked(nx, ny):
			if not _crow_blocked(e.x, ny):
				e.xl = e.x
				nx = e.x
			else:
				nx = e.x
				ny = e.y
		e.x = nx
		e.y = ny
		if e.t >= 56:
			e.st = 0
			e.t = 0
			e.erase("xl")
			e.cy = e.get("base", e.cy)

## o corpo do corvo em (x, y) entraria em algum sólido?
func _crow_blocked(x: float, y: float) -> bool:
	var r := R(x - 26, y - 14, 52, 22)
	for s in blockers():
		if not s.get("oneway") and not s.get("crate") and hit(r, s):
			return true
	return false

## piranha: patrulha a água e dá botes quando o Tomé chega perto
func _piranha(e: Dictionary) -> void:
	var pc := Vector2(player.x + player.w / 2, player.y + player.h / 2)
	var d: Vector2 = pc - Vector2(e.x, e.y)
	if d.length() < 170 and player.swim and player.dyingT == 0:
		# persegue com inércia (antes trocava de lado a cada quadro com o Tomé logo acima dela)
		var pv: Vector2 = e.get("pv", Vector2(float(e.get("fv", 0.0)), 0.0))
		pv = pv.lerp(Vector2(clamp(d.x * .06, -2.8, 2.8), clamp(d.y, -1.6, 1.6)), .12)
		e.pv = pv
		e.fv = pv.x
		if abs(pv.x) > .5:
			e.dir = 1 if pv.x > 0 else -1
		e.x = clamp(e.x + pv.x, e.r[0], e.r[1])
		e.y += pv.y
	else:
		e.pv = Vector2(float(e.get("fv", 0.0)), 0.0)
		_glide(e, 1.3)
		e.y = lerpf(e.y, e.cy + sin(T * .05 + e.x * .02) * 26, .05)
	# não sai da água atrás do Tomé
	if not e.has("_wy"):
		var w = X.water_at(e.x, e.cy)
		e._wy = Vector2(float(w.y) + 16.0, float(w.y + w.h) - 12.0) if w != null else Vector2(e.cy - 60.0, e.cy + 160.0)
	e.y = clamp(e.y, e._wy.x, e._wy.y)

## topo do chão firme logo abaixo de (x, y) (guardado em faixas de 16 px: os sólidos fixos não mudam)
var _floor_cache := {}
## índice dos sólidos da fase por faixas de 256 px (a câmera e o chão olhavam a lista inteira, centenas
## de peças, toda vez que o Tomé andava um pouco): devolve só as peças que cruzam [x0, x1], sem repetir
var _sx_idx := {}
var _sx_n := -1
var _sx_L = null
var _sx_stamp := 0
func near_solids(x0: float, x1: float) -> Array:
	var sol: Array = L.solids
	if _sx_n != sol.size() or not is_same(_sx_L, L):
		_sx_idx = {}
		_sx_n = sol.size()
		_sx_L = L
		for o in sol:
			var a := int(floor(float(o.x) / 256.0))
			var b := int(floor((float(o.x) + float(o.get("w", 0))) / 256.0))
			for k in range(a, b + 1):
				if not _sx_idx.has(k):
					_sx_idx[k] = []
				_sx_idx[k].append(o)
	_sx_stamp += 1
	var out: Array = []
	for k in range(int(floor(x0 / 256.0)), int(floor(x1 / 256.0)) + 1):
		for o in _sx_idx.get(k, []):
			if int(o.get("_sxq", -1)) == _sx_stamp:
				continue
			o["_sxq"] = _sx_stamp
			out.append(o)
	return out

func floor_under(x: float, y: float) -> float:
	var key := Vector2i(int(floor(x / 16.0)), int(floor(y / 16.0)))
	if _floor_cache.has(key):
		return _floor_cache[key]
	var best := 99999.0
	for s in near_solids(x, x):
		# tábuas, galhos e ilhas são de mão única (em L.solids ainda não têm "oneway")
		if s.get("deco") or s.get("oneway") or s.get("t", "") in ["plat", "branch", "island"]:
			continue
		if x >= s.x and x <= s.x + s.w and s.y > y and s.y < best:
			best = s.y
	_floor_cache[key] = best
	return best

## morcego: dorme pendurado; acorda quando o Tomé chega perto e foge da luz
func _bat(e: Dictionary) -> void:
	var st: int = e.get("st", 0)
	var pc := Vector2(player.x + player.w / 2, player.y + player.h / 2)
	e.cd = max(0, e.get("cd", 0) - 1)
	if st == 0:
		e.y = e.cy
		if e.cd == 0 and pc.distance_to(Vector2(e.x, e.y)) < 230 and player.dyingT == 0:
			e.st = 1
			e.t = 0
			Audio.play("dj", -12)
	elif st == 1:
		e.t += 1
		var to := (pc - Vector2(e.x, e.y))
		# voo com inércia: faz curvas em vez de mudar de direção num quadro
		var want := to.normalized() * 2.3
		var bv: Vector2 = e.get("bv", Vector2.ZERO)
		bv = bv.lerp(want, .07)
		e.bv = bv
		var v := bv + Vector2(0, sin(e.t * .25) * 2.2)
		e.x = clamp(e.x + v.x, e.r[0], e.r[1])
		# voa baixo atrás do Tomé, mas não entra no chão
		e.y = clamp(e.y + v.y, e.cy, min(e.cy + 260, floor_under(e.x, e.cy) - 14.0))
		if abs(bv.x) > .3:
			e.dir = 1 if bv.x > 0 else -1
		if X.lit(e.x, e.y, 95.0) or X.scare(e.x, e.y) or e.t > 420:
			e.st = 2
			e.t = 0
	else:
		e.t += 1
		var home := Vector2(e.x0, e.cy)
		var d := home - Vector2(e.x, e.y)
		if d.length() < 4:
			e.x = e.x0
			e.y = e.cy
			e.st = 0
			e.cd = 150
			e.bv = Vector2.ZERO
		else:
			# volta para o poleiro ganhando velocidade e freando ao chegar
			var bv2: Vector2 = e.get("bv", Vector2.ZERO)
			bv2 = bv2.lerp(d.normalized() * min(3.6, d.length() * .08 + .6), .09)
			e.bv = bv2
			e.x += bv2.x
			e.y += bv2.y
			if abs(bv2.x) > .3:
				e.dir = 1 if bv2.x > 0 else -1

## aranha: desce do teto num fio quando o Tomé passa por baixo
func _spider(e: Dictionary) -> void:
	var st: int = e.get("st", 0)
	var top: float = e.top + 26
	var low: float = e.base - 22
	e.cd = max(0, e.get("cd", 0) - 1)
	if st == 0:
		e.y = top + sin(T * .05 + e.x) * 3
		if e.cd == 0 and abs(player.x + player.w / 2 - e.x) < 70 and player.y > e.y and player.dyingT == 0:
			e.st = 1
	elif st == 1:
		# desce rápido e o fio estica: freia perto do fim e quica de leve
		e.sv = min(float(e.get("sv", 0.0)) + .6, 6.0)
		e.y = min(low, e.y + e.sv)
		if e.y >= low:
			e.st = 2
			e.t = 0
			e.sv = 0.0
	elif st == 2:
		e.t += 1
		e.y = low - sin(min(e.t, 24) / 24.0 * PI * 2.0) * 8.0 * (1.0 - min(e.t, 24) / 24.0)
		if e.t > 55:
			e.st = 3
	else:
		e.y -= 1.6
		if e.y <= top:
			e.st = 0
			e.cd = 70
	e.dir = 1 if player.x > e.x else -1

## toupeira: anda escondida debaixo da terra (não dá para pisar), salta perto do Tomé,
## joga um torrão de terra e mergulha de novo. A de capacete só cai se o Pipoca puxá-la para fora.
func _mole(e: Dictionary) -> void:
	var st: int = e.get("st", 0)
	e.t = e.get("t", 0) + 1
	e.y = e.base
	var dx: float = player.x + player.w / 2 - e.x
	match st:
		0:
			if e.get("cd", 0) > 0:
				e.cd -= 1
			var dirm: int = (1 if dx > 0 else -1) if abs(dx) < 380 else int(e.dir)
			e.dir = dirm
			e.x = clamp(e.x + dirm * 1.4, e.r[0], e.r[1])
			if e.x <= e.r[0] or e.x >= e.r[1]:
				e.dir = -e.dir
			if abs(dx) < 120 and e.get("cd", 0) == 0 and abs(player.y + player.h - e.base) < 80:
				e.st = 1
				e.t = 0
		1:
			if e.t % 4 == 0:
				PARTS.append({"x": e.x + (rng.randf() - .5) * 26, "y": e.base - 2, "vx": (rng.randf() - .5) * 3, "vy": -2 - rng.randf() * 2, "life": 18, "col": Color("#7a5a3a")})
			if e.t > 26:
				e.st = 2
				e.t = 0
				e.dir = 1 if dx > 0 else -1
				Audio.play("stomp", -12)
		2:
			if e.t == 16 and abs(dx) < 360:
				var vx: float = clamp(dx / 38.0, -5.5, 5.5)
				COAL.append({"x": e.x + e.dir * 10, "y": e.base - 34, "vx": vx, "vy": -7.0, "b": 1, "life": 200, "rot": 0.0, "k": "dirt"})
				Audio.play("slide", -8)
			if e.t > 62:
				e.st = 3
				e.t = 0
		3:
			if e.t > 14:
				e.st = 0
				e.t = 0
				e.cd = 70
		5:
			# puxada para fora pelo Pipoca: de barriga para cima, tonta
			if e.t > 180:
				e.st = 3
				e.t = 0
		6:
			pass

func kill_enemy(e: Dictionary, how: String = "") -> void:
	if e.dead:
		return
	e.dead = 1
	e.dk = "flat" if (how == "stomp" and not FLY.has(e.k)) else "flip"
	e.ddy = 0.0
	e.dvy = -6.0
	e.ddx = 0.0
	e.dvx = (1.0 if e.x > player.x + player.w / 2 else -1.0) * (2.4 if how != "stomp" else 1.2)
	burst(e.x, e.y - 12, 14, Color("#ccbbbb"))
	Polish.ko(e)
	Polish.impact(e.x, e.y - (6.0 if how == "stomp" else 18.0))
	# M5 pisões seguidos sem tocar o chão: o som sobe de tom e aparece o contador
	if how == "stomp" and not player.onGround:
		player.combo = int(player.get("combo", 0)) + 1
		if player.combo >= 2:
			Polish.part("txt", e.x, e.y - 40, 0, -1.2, 40, Color(1, .9, .45), {"txt": "x%d" % player.combo, "g": .02, "size": 20.0 + 3.0 * min(player.combo, 5)})
			Audio.play("dj", -8, 1.0 + .12 * min(player.combo, 6))
	shake = max(shake, 5)
	hit_stop = 5 if how == "stomp" else 3
	Audio.play("stomp")
	Audio.vib(20)
	fx("fx_dust", e.x, e.y - 10, 18, .22)

func gain_coin(x: float, y: float, silent: bool = false) -> void:
	coins += 1
	coin_life += 1
	Audio.play("pen", -8)
	if not silent:
		burst(x, y, 8, Color("#f0cd72"))
		fx("fx_sparkle", x, y, 14, .14)
		Polish.pickup(x, y)
	if coin_life >= 100:
		coin_life -= 100
		lives += 1
		flash("100 lápis: +1 vida!")
		burst(player.x, player.y, 24, Color("#ffd76a"))

func break_crate(c: Dictionary) -> void:
	c.dead = true
	shake = max(shake, 5)
	# O9 lascas de madeira voando e quicando no chão
	for i in 8:
		Polish.part("chip", c.x + c.w / 2 + randf_range(-12, 12), c.y + c.h / 2, randf_range(-3.5, 3.5), -randf_range(2.5, 6.0), 70, Color("#9a7040") if i % 2 == 0 else Color("#6a4a2a"), {"gy": c.y + c.h, "size": randf_range(2.5, 4.5)})
	Polish.impact(c.x + c.w / 2, c.y + c.h / 2, Color(1, .92, .75), 6, 24.0)
	fx("fx_pieces", c.x + c.w / 2, c.y + c.h / 2, 20, .35, -.4)
	burst(c.x + c.w / 2, c.y + c.h / 2, 16, Color("#b08a4e"))
	# caixa quebrando: estalo de madeira (antes era muda)
	Audio.play("stomp", -6, 1.3)
	Audio.play("door", -16, 1.7)
	Audio.vib(25)
	var it: String = c.get("item", "")
	if it == "armor":
		player.armor = 1
		flash("Armadura! Ela aguenta 1 golpe.")
		Audio.play("item", -2, .85)
	elif it == "heart":
		if player.hp < MAXHP:
			player.hp += 1
			flash("+1 coração.")
			Audio.play("item", -2, 1.2)
		else:
			for i in 5:
				gain_coin(c.x + c.w / 2, c.y - 10, true)
			flash("Vida cheia: +5 lápis.")
	else:
		var n: int = c.get("n", 0)
		for i in n:
			gain_coin(c.x + c.w / 2, c.y - 10)
		if not shown_crate:
			shown_crate = true
			flash("Caixa ★: +%d lápis." % n)

func hurt(d: int, from_x: float) -> void:
	if player.iframe > 0 or player.dyingT > 0:
		return
	if TR and TR.trapped != null and not player.get("dog"):
		return
	if player.get("dog"):
		M.dog_hurt()
		return
	if M.blocks(from_x):
		M.on_block(from_x)
		player.iframe = 20
		return
	var kb = func():
		player.iframe = 70
		player.hitT = 30
		player.bar = null
		shake = max(shake, 8)
		# E6 o tranco empurra a tela para o lado do golpe
		shake_dir = Vector2(1.0 if player.x + player.w / 2 > from_x else -1.0, -.35)
		Polish.impact(player.x + player.w / 2, player.y + player.h / 2, Color(1, .7, .6), 6, 20.0)
		player.vx = (-1 if player.x + player.w / 2 < from_x else 1) * 5
		player.vy = -6
		# o tranco tira do chão: sem "pulo do chão" grátis logo depois (coyote/buffer) e sem beirada
		player.onGround = false
		player.coyote = 0
		player.jbuf = 0
		player.mantleT = 0
		player.slam = false
		player.puff = false
		player.cutOk = false
		player.vine = null
		player.vineCD = 20
		player.run = 0
		player.ladder = null
	if player.armor > 0:
		player.armor -= 1
		kb.call()
		# o brilho do escudo estoura em faíscas douradas
		burst(player.x + player.w / 2, player.y + player.h / 2, 22, Color("#ffe08a"))
		flash("A armadura aguentou o golpe!")
		return
	player.hp -= d
	kb.call()
	# impacto: clarão branco curto e corpo achatado com o tranco
	player.hitFx = 10
	player.squash = .7
	Audio.play("hurt")
	Audio.vib(60)
	burst(player.x + player.w / 2, player.y + player.h / 2, 12, Color("#e07a6a"))
	if player.hp <= 0:
		die("Sem forças.")

var died_log = null   # testes: guarda onde e por que morreu
func die(msg: String) -> void:
	if player.dyingT > 0 or not running:
		return
	if died_log != null:
		died_log.append([int(player.x), int(player.y), msg])
	if player.get("dog"):
		M.dog_hurt()
		return
	lives -= 1
	if STATS.has("pdeath"):
		STATS.pdeath[clamp(period_index(), 0, 5)] += 1
	shake = 14
	burst(player.x + player.w / 2, player.y + player.h / 2, 22, Color("#cc5555"))
	Polish.death_fx(player.x + player.w / 2, player.y + player.h / 2)
	Audio.play("die")
	Audio.vib(150)
	player.dieMsg = msg
	player.dyingT = 46
	player.vy = -9
	player.vx = 0
	player.iframe = 0
	player.vine = null
	player.puff = false
	player.slam = false
	player.ladder = null
	hit_stop = 8

## "Voltar à fogueira": como renascer, mas sem perder vida nem coração
func _back_to_fire() -> void:
	var hp: int = int(player.hp)
	var armor: int = int(player.armor)
	_reset_player(player.spawnX, player.spawnY, false)
	player.hp = hp
	player.armor = armor
	player.iframe = 40
	COAL.clear()
	M.reset_crates(player.spawnX)
	X.boss_reset()
	TR.reset_on_respawn()
	K.reset_on_respawn()
	EV.on_respawn()
	VH.on_respawn()
	X.breath = Extras.BREATH
	snap_camera()
	_tick_fx()
	flash("De volta à fogueira.")

func respawn() -> void:
	var msg: String = player.dieMsg
	if lives < 0:
		running = false
		game_over.emit()
		return
	iris_t = 30
	var sx: float = player.spawnX
	var sy: float = player.spawnY
	var armor: int = player.armor
	_reset_player(sx, sy, false)
	player.armor = armor
	player.iframe = 80
	time_left = int(L.get("time", 180)) * 60
	COAL.clear()
	if VIL and VIL.go and not VIL.gone and VIL.get("chase"):
		VIL.x = min(player.x + 420, VIL.gateX - 10)
	X.boss_reset()
	TR.reset_on_respawn()
	K.reset_on_respawn()
	EV.on_respawn()
	VH.on_respawn()
	X.breath = Extras.BREATH
	snap_camera()
	flash(msg + " Vidas: %d" % lives)

# ======================================================================
#  SALVAR
# ======================================================================
func save_checkpoint(k: int) -> void:
	var got_items: Array = []
	for it in ITEMS:
		if it.got:
			got_items.append(it.id)
	var locks: Array = []
	for l in LOCKS:
		locks.append(l.done)
	var coins_got: Array = []
	for c in COINS:
		if c.got:
			coins_got.append(c.ci)
	Save.save_run({"level": level_idx, "chk": k, "lives": lives, "inv": INV.duplicate(), "items": got_items, "locks": locks,
		"clues": CLUEGOT.keys(), "specs": SPECGOT.keys(), "drawn": DRAWN.keys(), "coins": coins_got, "coin_life": coin_life,
		"pen": STATS.pen, "lit": lantern_lit, "fuel": FUEL, "oil": OIL.filter(func(c): return c.got).map(func(c): return OIL.find(c)), "fires": CHK.filter(func(c): return c.on).map(func(c): return CHK.find(c)), "time": time_left, "x": X.save_data(), "m": M.save_data(), "tr": TR.save_data(),
		"nt": NT.save_data(), "k": K.save_data(), "rd": RD.save_data(), "vh": VH.save_data(), "ev": EV.save_data(), "sl": SL.save_data(), "rested": RESTED.keys(), "cranks": CRANKS.map(func(c): return c.done), "mv": MV.save_data()})

func restore_run(d: Dictionary) -> void:
	## Continua do ponto salvo: refaz a fase no estado da fogueira
	for c in d.get("clues", []):
		CLUEGOT[int(c)] = 1
	for s in d.get("specs", []):
		SPECGOT[s] = 1
	for k in d.get("drawn", []):
		DRAWN[k] = 1
	load_level(int(d.get("level", 0)))
	lives = int(d.get("lives", 3))
	INV = d.get("inv", []).duplicate()
	for it in ITEMS:
		if d.get("items", []).has(it.id):
			it.got = true
	var lk: Array = d.get("locks", [])
	for i in min(lk.size(), LOCKS.size()):
		if lk[i]:
			var l: Dictionary = LOCKS[i]
			var had: bool = INV.has(l.need)
			if not had:
				INV.append(l.need)
			var keep := INV.duplicate()
			use_lock(l)
			if l.kind == "dark":
				INV = keep
			for s in SWAMP:
				if s.get("drain"):
					s.y = s.y2
	MV.restore(d.get("mv", {}))
	shake = 0
	flash_t = 0
	for c in COINS:
		if d.get("coins", []).has(c.ci):
			c.got = true
	coin_life = int(d.get("coin_life", 0))
	STATS.pen = int(d.get("pen", 0))
	lantern_lit = d.get("lit", lantern_lit)
	FUEL = float(d.get("fuel", .55))
	fuel_vis = FUEL
	for k in d.get("oil", []):
		if int(k) < OIL.size():
			OIL[int(k)].got = true
	X.restore(d.get("x", {}))
	M.restore(d.get("m", {}))
	TR.restore(d.get("tr", {}))
	NT.restore(d.get("nt", {}))
	K.restore(d.get("k", {}))
	RD.restore(d.get("rd", {}))
	VH.restore(d.get("vh", {}))
	EV.restore(d.get("ev", {}))
	SL.restore(d.get("sl", {}))
	for r in d.get("rested", []):
		RESTED[int(r)] = 1
	var ck: Array = d.get("cranks", [])
	for i in min(ck.size(), CRANKS.size()):
		if ck[i]:
			CRANKS[i].done = true
			CRANKS[i].turn = 1.0
			var cg = crank_gate(CRANKS[i])
			if cg != null:
				cg.open = 1.0
	var k: int = int(d.get("chk", -1))
	if d.has("fires"):
		for i in d.fires:
			if int(i) < CHK.size():
				CHK[int(i)].on = true
	elif k >= 0 and k < CHK.size():
		CHK[k].on = true
	cur_chk = k
	if k >= 0 and k < CHK.size():
		_reset_player(CHK[k].x - 12, CHK[k].y - 34)
	snap_camera()
	time_left = int(d.get("time", time_left))
	flash("Você continua da última fogueira.")
