extends RefCounted
class_name CartRide
## Carrinho de bagagem pilotável (aeroporto): o Milis sobe no carrinho parado (botão usar ✋) e desce
## o mezanino embalado. Não se dirige: só PULAR (pilhas de malas) e ABAIXAR (placas penduradas baixas).
## Os capangas no caminho são derrubados pelo carrinho. Bateu? Cai do carrinho e pode subir de novo.
## Dados da fase: "cartRide": {"x0", "x1", "y", "obs": [{"k": "pile"|"low", "x", "w"}]}

var g
var C: Dictionary = {}
var x := 0.0
var on := false
var done := false
var spd := 0.0
var bump := 0      # quadros do tranco depois de bater (o carrinho balança parado)

func _init(game) -> void:
	g = game

func load_level() -> void:
	C = g.L.get("cartRide", {})
	on = false
	done = false
	spd = 0.0
	bump = 0
	x = float(C.get("x0", 0.0))

func active() -> bool:
	return not C.is_empty()

func on_respawn() -> void:
	if not active():
		return
	on = false
	spd = 0.0
	if not done:
		x = float(C.x0)

## perto do carrinho parado, no chão: o botão usar sobe nele
func near() -> bool:
	if not active() or on or done or not g.player.onGround:
		return false
	var p: Dictionary = g.player
	return abs(p.x + p.w / 2 - x) < 46 and abs(p.y + p.h - float(C.y)) < 8

func start() -> void:
	on = true
	spd = 0.0
	var p: Dictionary = g.player
	p.vx = 0.0
	p.x = x - p.w / 2
	Audio.play("door", -6, 1.4)
	g.flash("Segure firme! PULE as pilhas de malas e ABAIXE nas placas baixas.")

## a cada quadro, antes da física do Milis
func step() -> void:
	if not active():
		return
	if bump > 0:
		bump -= 1
	if not on:
		return
	var p: Dictionary = g.player
	if p.dyingT > 0:
		on = false
		return
	spd = min(spd + .14, 5.4)
	x += spd
	# o Milis vai junto (no ar também: pula e cai de volta no carrinho)
	var want: float = x - p.w / 2
	var before: float = p.x
	g.move_x(want - p.x)
	if abs(p.x - want) > 4.0 and abs(p.x - before) < spd * .5:
		_crash(x + 40)
		return
	p.vx = 0.0
	if g.T % 5 == 0 and Polish.FRESH:
		g.PARTS.append({"x": x - 26, "y": float(C.y) - 2, "vx": -1.2, "vy": -randf_range(.2, .8), "life": 14, "col": Color(.75, .75, .78, .6)})
	# capangas no caminho: derrubados pelo carrinho
	for e in g.EN:
		if e.dead or e.k in ["crow", "bat", "fly", "spider"]:
			continue
		if abs(e.x - (x + 26)) < 34 and abs(e.y - float(C.y)) < 40:
			g.kill_enemy(e, "cart")
			g.gain_coin(e.x, e.y - 40)
	# obstáculos (só valem com o carrinho andando)
	var pr: Dictionary = g.R(p.x + 3, p.y, p.w - 6, p.h)
	for o in C.get("obs", []):
		var ox: float = float(o.x)
		var ow: float = float(o.w)
		if ox > x + 80 or ox + ow < x - 80:
			continue
		var hz: Dictionary
		if o.k == "pile":
			hz = g.R(ox, float(C.y) - 30, ow, 30)
		else:
			# placa baixa: passa abaixado (o corpo abaixado tem 20 de altura)
			hz = g.R(ox, float(C.y) - 120, ow, 120 - g.crouch_h() - 4)
		if g.hit(pr, hz):
			_crash(ox)
			return
	if x >= float(C.x1):
		_finish()

func _crash(from_x: float) -> void:
	on = false
	spd = 0.0
	bump = 24
	x -= 30.0
	Audio.play("stomp", -4, .7)
	g.shake = max(g.shake, 7)
	g.hurt(1, from_x)
	if g.player.dyingT <= 0:
		g.flash("Caiu do carrinho! Toque em ✋ perto dele para subir de novo.")

func _finish() -> void:
	on = false
	done = true
	bump = 30
	x = float(C.x1)
	var p: Dictionary = g.player
	p.vx = 4.0
	p.vy = -7.0
	p.onGround = false
	Audio.play("door", -6, .9)
	g.flash("Que descida! O carrinho ficou no fim do corredor.")

# ---------------------------------------------------------------- desenho
## atrás do Milis: alça e grade de trás
func draw_back(T: int) -> void:
	if not active():
		return
	# a pé, as placas e malas ficam atrás do Milis (ele passa por trás delas); andando no carrinho
	# elas vêm para a frente (é nelas que ele bate)
	if not on:
		_obstacles(T)
	var y: float = float(C.y)
	var sw: float = sin(T * .9) * 1.2 * (spd / 5.4) + (sin(bump * .9) * 2.0 if bump > 0 else 0.0)
	Spr.save()
	Spr.translate(x, y)
	Spr.rotate(sw * .01)
	# alça de empurrar (atrás) e a grade que segura as malas
	Spr.seg(-40, -16, -48, -84, Color("#8d97a3"), 5)
	Spr.seg(-54, -84, -34, -84, Color("#2a2e35"), 7)
	Spr.seg(34, -16, 38, -54, Color("#8d97a3"), 4)
	Spr.seg(38, -54, 26, -54, Color("#8d97a3"), 3)
	Spr.restore()

## na frente do Milis: plataforma, rodinhas e a placa "BAGAGEM"
func draw_front(T: int) -> void:
	if not active():
		return
	if on:
		_obstacles(T)
	var y: float = float(C.y)
	var sw: float = sin(T * .9) * 1.2 * (spd / 5.4) + (sin(bump * .9) * 2.0 if bump > 0 else 0.0)
	Spr.save()
	Spr.translate(x, y)
	Spr.rotate(sw * .01)
	Spr.rr(-44, -22, 88, 13, 3, Color("#5f6b78"))
	Spr.rect(-44, -22, 88, 4, Color("#a9b3be"))
	Spr.rr(-18, -19, 36, 8, 2, Color("#ffcf3a"))
	Spr.text("BAGAGEM", 0, -19.5, 6, Color("#1b2a44"), HORIZONTAL_ALIGNMENT_CENTER, Spr.font_b)
	var rot: float = x * .15
	for wx in [-30.0, 30.0]:
		Spr.circle(wx, -8, 8, Color("#1b1d22"))
		Spr.circle(wx, -8, 3, Color("#9aa3ad"))
		Spr.seg(wx + cos(rot) * 6, -8 + sin(rot) * 6, wx - cos(rot) * 6, -8 - sin(rot) * 6, Color("#4a515c"), 2)
	Spr.restore()
	if near():
		Spr.text("✋ subir", x, y - 96, 12, Color("#ffe9b0"), HORIZONTAL_ALIGNMENT_CENTER, Spr.font_b)

func _obstacles(T: int) -> void:
	var y: float = float(C.y)
	for o in C.get("obs", []):
		var ox: float = float(o.x)
		var ow: float = float(o.w)
		if ox > g.cam + g.W + 100 or ox + ow < g.cam - 100:
			continue
		if o.k == "pile":
			if Spr.AR.has("p_ob_malas"):
				Spr.P("ob_malas", ox + ow / 2, y + 2, ow + 10)
			else:
				Spr.rr(ox, y - 30, ow, 30, 4, Color("#7a4a2a"))
		else:
			# placa pendurada baixa (corrente do teto)
			# (a borda de baixo fica acima do desenho do Milis abaixado e abaixo dele em pé)
			var by: float = y - 52
			Spr.seg(ox + 10, by - 34, ox + 10, by - 260, Color("#3a414c"), 2)
			Spr.seg(ox + ow - 10, by - 34, ox + ow - 10, by - 260, Color("#3a414c"), 2)
			Spr.rr(ox, by - 34, ow, 34, 4, Color("#1b2a44"))
			Spr.rr(ox + 3, by - 31, ow - 6, 28, 3, Color("#ffcf3a"))
			Spr.text(str(o.get("txt", "PORTÃO 7")), ox + ow / 2, by - 27, 11, Color("#1b2a44"), HORIZONTAL_ALIGNMENT_CENTER, Spr.font_b)
