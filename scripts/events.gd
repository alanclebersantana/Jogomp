extends RefCounted
class_name Events
## Trechos novos que mudam o ritmo:
##  ENCHENTE  na gruta da engrenagem (pântano): ao pegar a engrenagem, a água tóxica começa a subir
##            e o Tomé precisa voltar correndo e subir a escada antes que ela o alcance.
##  ALAVANCAS na entrada do túnel da mina: duas alavancas baixam dois contrapesos; com os dois
##            pesos embaixo, o portão de ferro sobe.

var g
var FL := {}            # enchente
var LV := {}            # alavancas e portão
var GATE := {}
## quanto o portão sobe com uma alavanca só (a mesma conta no passo e ao continuar do save)
const ONE_LEVER_LIFT := 0.12

func _init(game) -> void:
	g = game

func load_level() -> void:
	FL = {}
	LV = {}
	GATE = {}
	var L: Dictionary = g.L
	if L.has("flood"):
		FL = L.flood.duplicate(true)
		FL.st = "idle"
		FL.level = float(FL.y0)
		FL.t = 0
		FL.done = false
	if L.has("levers"):
		LV = L.levers.duplicate(true)
		for lv in LV.list:
			lv.down = false
			lv.a = 0.0
		GATE = {"t": "irongate", "x": float(LV.gate.x), "y": float(LV.gate.y), "w": float(LV.gate.w), "h": float(LV.gate.h), "lift": 0.0}
		g.SOL.append(GATE)
		g.blockers_dirty()

# ---------------------------------------------------------------- passo
func step() -> void:
	_flood_step()
	_lever_step()
	_gate_bump()

func _flood_step() -> void:
	if FL.is_empty() or FL.done:
		return
	var p: Dictionary = g.player
	match FL.st:
		"idle":
			# com a engrenagem na mão, de volta ao pé da escada: a gruta começa a encher
			var tr: Array = FL.trig
			var pcx0: float = p.x + p.w / 2
			if g.has_item(FL.item) and p.ladder != null and pcx0 > tr[0] and pcx0 < tr[1] and p.y + p.h > tr[2] and p.dyingT == 0:
				FL.st = "warn"
				FL.t = 0
				g.shake = max(g.shake, 8)
				Audio.play("thunder", -6)
				g.flash("A água tóxica está subindo! Suba a escada, rápido!", 220)
		"warn":
			FL.t += 1
			if FL.t % 10 == 0:
				g.shake = max(g.shake, 3)
			if FL.t > 30:
				FL.st = "rise"
		"rise":
			FL.level = max(float(FL.ytop), FL.level - float(FL.spd))
			var pcx: float = p.x + p.w / 2
			if pcx > FL.x0 and pcx < FL.x1 and p.y + p.h > FL.level + 8 and p.dyingT == 0:
				g.die("A água tóxica te alcançou!")
			# saiu da gruta: a água para e vai baixando
			if p.y + p.h < float(FL.ytop) - 4 or pcx < FL.x0 - 40 or pcx > FL.x1 + 40:
				FL.st = "fall"
		"fall":
			FL.level = min(float(FL.y0), FL.level + 1.5)
			if FL.level >= float(FL.y0):
				FL.done = true
				FL.st = "idle"

## depois de cair, a gruta volta ao normal (e a enchente só acontece de novo se o Tomé voltar sem a engrenagem)
func on_respawn() -> void:
	if not FL.is_empty() and FL.st in ["warn", "rise"]:
		FL.st = "fall"

func _lever_step() -> void:
	if LV.is_empty():
		return
	var down := 0
	for lv in LV.list:
		lv.a = move_toward(lv.a, 1.0 if lv.down else 0.0, .06)
		if lv.down:
			down += 1
	# cada peso embaixo puxa o portão um pouco; com os dois, ele abre de vez
	var want: float = (ONE_LEVER_LIFT if down == 1 else (1.0 if down >= 2 else 0.0)) * (GATE.h - 6)
	var old: float = GATE.lift
	GATE.lift = move_toward(GATE.lift, want, 1.6)
	if GATE.lift != old:
		GATE.y = float(LV.gate.y) - GATE.lift
		g.blockers_dirty()
		if g.T % 8 == 0:
			Audio.play("door", -14)

## o Tomé empurrando o portão fechado: diz quantas alavancas faltam (não parece defeito)
var bumpT := 0
func _gate_bump() -> void:
	if LV.is_empty() or GATE.lift >= GATE.h - 8:
		return
	if bumpT > 0:
		bumpT -= 1
		return
	var p: Dictionary = g.player
	if p.x + p.w >= GATE.x - 3 and p.x + p.w <= GATE.x + 6 and g.kd("R") and p.onGround:
		var n := 0
		for o in LV.list:
			if not o.down:
				n += 1
		g.flash("Está preso... falta puxar %d alavanca%s." % [n, "s" if n > 1 else ""], 140)
		bumpT = 200

func near_lever():
	if LV.is_empty():
		return null
	var p: Dictionary = g.player
	for lv in LV.list:
		if abs(p.x + p.w / 2 - float(lv.x)) < 36 and abs(p.y + p.h - float(LV.y)) < 40 and not lv.down:
			return lv
	return null

func use() -> bool:
	var lv = near_lever()
	if lv == null:
		return false
	lv.down = true
	Audio.play("unlock")
	Audio.vib(30)
	var n := 0
	for o in LV.list:
		if o.down:
			n += 1
	if n < LV.list.size():
		g.flash("Clanc! Um contrapeso desceu e o portão subiu um pouco. Falta a outra alavanca.", 220)
	else:
		g.flash("Os dois pesos desceram: o portão de ferro abriu!", 200)
	return true

# ---------------------------------------------------------------- salvar
func save_data() -> Dictionary:
	var levs: Array = []
	if not LV.is_empty():
		for lv in LV.list:
			levs.append(lv.down)
	return {"flood": FL.get("done", false), "levers": levs}

func restore(d: Dictionary) -> void:
	if not FL.is_empty() and d.get("flood", false):
		FL.done = true
	var levs: Array = d.get("levers", [])
	if not LV.is_empty():
		for i in min(levs.size(), LV.list.size()):
			LV.list[i].down = levs[i]
			LV.list[i].a = 1.0 if levs[i] else 0.0
		var n := 0
		for lv in LV.list:
			if lv.down:
				n += 1
		# antes voltava em 0.32 e o passo puxava para 0.12: o portão "descia sozinho" depois de continuar
		GATE.lift = (ONE_LEVER_LIFT if n == 1 else (1.0 if n >= 2 else 0.0)) * (GATE.h - 6)
		GATE.y = float(LV.gate.y) - GATE.lift
		g.blockers_dirty()
