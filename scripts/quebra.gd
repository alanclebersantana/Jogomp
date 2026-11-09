extends RefCounted
class_name Quebra
## Cenário que reage (aeroporto): placa de piso molhado, vaso de planta, pilha de malas, máquina de
## lanches e carrinho de bagagem. O bastão, o chute, o giro, um capanga arremessado ou a investida do
## falso segurança derrubam, quebram ou empurram — e às vezes soltam milhas.
##  placa    voa girando e fica caída
##  vaso     quebra em cacos e terra (1 milha)
##  malas    a pilha desaba: malas quicando (2 milhas)
##  lanche   máquina de lanches: cada pancada balança, racha o vidro e solta um lanche + milhas (até 3)
##  carrinho carrinho de bagagem: rola para longe e bate nas coisas

var g
var O: Array = []

const NOMES := {"placa": "p_ob_placa", "malas": "p_ob_malas"}

func _init(game) -> void:
	g = game

func load_level() -> void:
	O = []
	for d in g.L.get("brk", []):
		var o: Dictionary = d.duplicate(true)
		o.x = float(o.x)
		o.y = float(o.get("y", 500))
		o.base = o.y
		o.w = float(o.get("w", 40))
		o.vx = 0.0
		o.vy = 0.0
		o.rot = 0.0
		o.vr = 0.0
		o.hp = 3 if o.k == "lanche" else 1
		o.done = false
		o.shk = 0
		o.cd = 0
		o.bits = []
		O.append(o)

func _h(o: Dictionary) -> float:
	match o.k:
		"lanche": return 130.0
		"vaso": return 80.0
		"malas": return 64.0
		"carrinho": return 110.0
	return 48.0

func box(o: Dictionary) -> Dictionary:
	var w: float = o.w
	return {"x": o.x - w / 2, "y": o.y - _h(o), "w": w, "h": _h(o)}

## golpe do Milis (caixa do golpe, direção, tipo)
func hit_box(hb: Dictionary, dir: float, how: String) -> void:
	for o in O:
		if o.cd > 0 or (o.done and o.k != "carrinho"):
			continue
		if Game.hit(hb, box(o)):
			_knock(o, dir, 5.0 if how in ["spin", "kick"] else 3.5)

## algo voando ou correndo bate no ponto (x, y) com velocidade vx
func hit_point(x: float, y: float, vx: float) -> void:
	if abs(vx) < 2.0:
		return
	for o in O:
		if o.cd > 0 or (o.done and o.k != "carrinho"):
			continue
		var b := box(o)
		if x > b.x - 10 and x < b.x + b.w + 10 and y > b.y - 20 and y < b.y + b.h + 30:
			_knock(o, sign(vx), clamp(abs(vx), 3.0, 7.0))

func _coins(o: Dictionary, n: int) -> void:
	for i in n:
		g.gain_coin(o.x, o.y - _h(o) * .6, i > 0)
	for i in 5:
		g.PARTS.append({"x": o.x + randf_range(-8, 8), "y": o.y - _h(o) * .6, "vx": randf_range(-2, 2), "vy": -randf_range(2.5, 5.0), "life": 34, "col": Color(1, .82, .3), "gy": o.base - 2})

func _knock(o: Dictionary, dir: float, pw: float) -> void:
	o.cd = 12
	g.shake = max(g.shake, 2.5)
	match o.k:
		"placa":
			o.done = true
			o.vx = dir * pw * 1.1
			o.vy = -pw * 1.1
			o.vr = dir * .35
			Audio.play("slide", -8, 1.4)
		"vaso":
			o.done = true
			Audio.play("door", -6, 1.8)
			for i in 9:
				Polish.part("chip", o.x + randf_range(-12, 12), o.y - 30, dir * randf_range(.5, 3.5) + randf_range(-1, 1), -randf_range(2.0, 5.0), 70,
					Color("#b5653a") if i % 3 else Color("#3f7a3a"), {"gy": o.base, "size": randf_range(2.5, 5.0)})
			for i in 6:
				g.PARTS.append({"x": o.x + randf_range(-10, 10), "y": o.y - 20, "vx": randf_range(-1.5, 1.5), "vy": -randf_range(.5, 2.0), "life": 22, "col": Color(.35, .25, .18, .8)})
			_coins(o, 1)
		"malas":
			o.done = true
			Audio.play("stomp", -8, 1.2)
			for i in 3:
				o.bits.append({"x": o.x + (i - 1) * 12.0, "y": o.y - 20.0 - i * 16.0, "vx": dir * randf_range(1.5, 4.0) + (i - 1) * .6, "vy": -randf_range(2.5, 5.5),
					"r": 0.0, "vr": dir * randf_range(.1, .3), "c": [Color("#b0473a"), Color("#3d6ea8"), Color("#d9a63a")][i], "w": 30.0 - i * 4.0})
			_coins(o, 2)
		"lanche":
			o.hp -= 1
			o.shk = 16
			Audio.play("clanc", -6, .7)
			# lanche caindo da prateleira (um pacotinho que quica) e milhas
			o.bits.append({"x": o.x, "y": o.y - 50.0, "vx": dir * randf_range(1.0, 2.5), "vy": -randf_range(2.0, 3.5), "r": 0.0, "vr": .2,
				"c": [Color("#e0452e"), Color("#f2c230"), Color("#3aa35a")][o.hp % 3], "w": 14.0})
			_coins(o, 2)
			if o.hp <= 0:
				o.done = true
				Audio.play("door", -4, 1.6)
				for i in 8:
					Polish.part("chip", o.x + randf_range(-20, 20), o.y - 100, dir * randf_range(.5, 3) + randf_range(-1, 1), -randf_range(1.5, 4.0), 60,
						Color(.75, .9, 1, .9), {"gy": o.base, "size": randf_range(2.0, 4.0)})
		"carrinho":
			o.vx = dir * pw * 1.2
			Audio.play("slide", -6, .9)

func step() -> void:
	for o in O:
		if o.cd > 0:
			o.cd -= 1
		if o.shk > 0:
			o.shk -= 1
		match o.k:
			"placa":
				if o.done and (o.vy != 0.0 or o.y < o.base):
					o.x += o.vx
					o.y += o.vy
					o.vy += .5
					o.rot += o.vr
					if o.y >= o.base:
						o.y = o.base
						if abs(o.vy) > 3.0:
							o.vy = -o.vy * .3
							o.vx *= .6
							o.vr *= .5
							Audio.play("slide", -14, 1.6)
						else:
							o.vy = 0.0
							o.vx = 0.0
							o.vr = 0.0
							o.rot = PI / 2 * sign(o.rot) if o.rot != 0.0 else PI / 2
			"carrinho":
				if abs(o.vx) > .05:
					o.x += o.vx
					o.vx *= .965
					o.rot = sin(g.T * .5) * .02 * abs(o.vx)
					# o carrinho desgovernado derruba o que encontrar
					for o2 in O:
						if o2 != o and not o2.done and abs(o2.x - o.x) < (o2.w + o.w) / 2:
							_knock(o2, sign(o.vx), abs(o.vx) + 2.0)
							o.vx *= -.3
					# e o capanga também
					for e in g.EN:
						if not e.dead and abs(e.x - o.x) < 40 and abs(e.y - o.base) < 30 and abs(o.vx) > 2.5:
							g.kill_enemy(e, "cart")
							o.vx *= -.4
		for b in o.bits:
			if b.vy == 0.0 and b.y >= o.base:
				continue
			b.x += b.vx
			b.y += b.vy
			b.vy += .45
			b.r += b.vr
			if b.y >= o.base - 4:
				b.y = o.base - 4
				if abs(b.vy) > 2.5:
					b.vy = -b.vy * .35
					b.vx *= .6
				else:
					b.vy = 0.0
					b.vx = 0.0
					b.vr = 0.0
	# o Milis correndo empurra o carrinho de bagagem
	var p: Dictionary = g.player
	for o in O:
		if o.k == "carrinho" and p.onGround and abs(p.vx) > 2.5:
			var cx: float = p.x + p.w / 2
			if abs(cx - o.x) < o.w / 2 + p.w / 2 and abs(p.y + p.h - o.base) < 10 and sign(o.x - cx) == sign(p.vx):
				o.vx = p.vx * 1.4
				if o.cd == 0:
					Audio.play("slide", -10, 1.1)
					o.cd = 20

func draw(T: int) -> void:
	var x0: float = g.cam - 200
	var x1: float = g.cam + g.W + 200
	for o in O:
		if o.x < x0 or o.x > x1:
			continue
		var h: float = _h(o)
		Spr.ellipse(o.x, o.base + 1, o.w * .45, 5, Color(0, 0, 0, .22))
		match o.k:
			"placa":
				Spr.save()
				Spr.translate(o.x, o.y)
				Spr.rotate(o.rot)
				if Spr.AR.has("p_ob_placa"):
					Spr.P("ob_placa", 0, 3, o.w)
				else:
					_placa_proc()
				Spr.restore()
			"vaso":
				_tex_or(o, "brk_vaso_q" if o.done else "brk_vaso", T)
			"malas":
				if not o.done:
					Spr.P("ob_malas", o.x, o.y + 3, o.w)
			"lanche":
				var sx: float = sin(T * 1.7) * 2.5 * (o.shk / 16.0)
				Spr.save()
				Spr.translate(sx, 0)
				_tex_or(o, "brk_lanche_q" if o.hp < 3 else "brk_lanche", T)
				Spr.restore()
			"carrinho":
				Spr.save()
				Spr.translate(o.x, o.y)
				Spr.rotate(o.rot)
				_tex_or({"x": 0.0, "y": 0.0, "w": o.w, "k": "carrinho", "base": 0.0}, "brk_carrinho", T)
				Spr.restore()
		for b in o.bits:
			Spr.save()
			Spr.translate(b.x, b.y)
			Spr.rotate(b.r)
			var bw: float = b.w
			Spr.rr(-bw / 2, -bw * .7, bw, bw * .7, 3, Color(.08, .06, .05))
			Spr.rr(-bw / 2 + 1.5, -bw * .7 + 1.5, bw - 3, bw * .7 - 3, 2, b.c)
			Spr.rect(-bw * .18, -bw * .7 - 4, bw * .36, 4, Color(.1, .1, .1))
			Spr.restore()

## desenho pintado (se existir) com a base no chão; senão um desenho simples
func _tex_or(o: Dictionary, n: String, T: int) -> void:
	var t: Texture2D = Spr.opt(n)
	if t != null:
		var w: float = o.w * 1.25
		var hh: float = w * t.get_height() / t.get_width()
		Spr.trect(t, Rect2(o.x - w / 2, o.y - hh + 3, w, hh))
		return
	match o.k:
		"vaso":
			if o.get("done", false):
				Spr.rect(o.x - 14, o.y - 10, 28, 10, Color("#8a4a2a"))
			else:
				Spr.rr(o.x - 16, o.y - 34, 32, 34, 5, Color("#b5653a"))
				Spr.circle(o.x, o.y - 50, 20, Color("#3f7a3a"))
		"lanche":
			Spr.rr(o.x - o.w / 2, o.y - 150, o.w, 150, 6, Color("#c8302a"))
			Spr.rect(o.x - o.w / 2 + 8, o.y - 135, o.w * .62, 90, Color(.75, .9, 1, .6))
		"carrinho":
			Spr.rect(o.x - o.w / 2, o.y - 14, o.w, 6, Color("#8a939e"))
			Spr.rect(o.x - o.w / 2, o.y - 60, 5, 50, Color("#8a939e"))
			Spr.circle(o.x - o.w / 2 + 8, o.y - 4, 5, Color("#222"))
			Spr.circle(o.x + o.w / 2 - 8, o.y - 4, 5, Color("#222"))

func _placa_proc() -> void:
	Spr.poly(PackedVector2Array([Vector2(-14, 0), Vector2(0, -44), Vector2(14, 0)]), Color("#f2c230"))
