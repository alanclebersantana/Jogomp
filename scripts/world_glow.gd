extends Node2D
## Camada acima da escuridão: lápis, objetos, pistas e desenhos brilham mesmo à noite.
## Também desenha o que fica na frente do Tomé (água do brejo e moitas).

var game: Game
const AFX = preload("res://scripts/ambient_fx.gd")
const WSt = preload("res://scripts/world_static.gd")

func _ready() -> void:
	# camada de ambiente (AmbientFx) no mundo: logo depois do cenário fixo e antes do que se mexe (fica
	# dentro da escuridão e atrás do Tomé). Se main.gd já criou uma (patch_C.md), não cria outra
	if game == null:
		return
	var idx := -1
	var wp: Node = game.world_parent if game.world_parent else game
	for c in wp.get_children():
		if c.is_queued_for_deletion():
			continue
		if c.get_script() == AFX:
			return
		if c.get_script() == WSt:
			idx = c.get_index()
	var amb: Node2D = AFX.new()
	amb.game = game
	amb.name = "AmbientFx"
	wp.add_child(amb)
	if idx >= 0:
		wp.move_child(amb, idx + 1)

func _process(_d: float) -> void:
	queue_redraw()

func _draw() -> void:
	var __t := Time.get_ticks_usec()
	__draw_raw()
	Spr.pt("glow", __t)

func __draw_raw() -> void:
	if game == null or not game.L:
		return
	var g := game
	var T := g.T
	var x0 := g.cam - 60
	var x1 := g.cam + g.W + 60
	Spr.begin(self)
	if g.VL:
		g.VL.draw_glow(T)
	# Ep. 2: chama das lamparinas e olhos vermelhos do Morcego-Rei (acima da escuridão)
	WorldEp2.glow(g, T)
	# beiradas dos buracos aparecem mesmo no escuro: borda clara e pedrinhas soltas
	for pit in g.L.get("pits", []):
		if pit[1] < x0 or pit[0] > x1:
			continue
		var pa: float = pit[0]
		var pb: float = pit[1]
		var k: float = .55 + .15 * sin(T * .05)
		# o vão fica bem mais escuro que o chão em volta
		Spr.vgrad(pa, 500, pb - pa, 120, Color(0, 0, 0, .55), Color(0, 0, 0, .85))
		Spr.rect(pa, 620, pb - pa, 600, Color(0, 0, 0, .85))
		_pit_rim(pa, 499, 1.0, k)
		_pit_rim(pb, 499, -1.0, k)
	for sh in g.L.get("shafts", []):
		if sh[1] < x0 or sh[0] > x1:
			continue
		var qa: float = sh[0]
		var qb: float = sh[1]
		var qy: float = sh[2]
		var q: float = .55 + .15 * sin(T * .05)
		Spr.vgrad(qa, qy, qb - qa, 120, Color(0, 0, 0, .55), Color(0, 0, 0, .9))
		Spr.rect(qa, qy + 120, qb - qa, 600, Color(0, 0, 0, .9))
		_pit_rim(qa, qy - 1, 1.0, q)
		_pit_rim(qb, qy - 1, -1.0, q)
	for c in g.coins_near(x0, x1):
		if c.got or c.x < x0 or c.x > x1:
			continue
		var pen: String = "pen_" + GameData.PEN_LIST[int(c.ci) % 6]
		if c.ry > 0:
			# lápis caído no chão, cada um num ângulo
			var ang: float = 1.25 + (int(c.ci) * 37 % 40) / 100.0
			if int(c.ci) % 2 == 1:
				ang = -ang
			Spr.ellipse(c.x, c.ry - 1, 13, 2.5, Color(0, 0, 0, .25))
			Spr.save()
			Spr.translate(c.x, c.ry - 5)
			Spr.rotate(ang)
			Spr.A(pen, 0, 0, .62)
			Spr.restore()
			if (T + int(c.ci) * 23) % 140 < 8:
				Spr.glow(c.x + 6, c.ry - 7, 10, Color(1, 1, .85, .7))
		else:
			var b := sin(T * .1 + c.x * .05) * 3
			if c.get("mag", false):
				# rastro colorido voando para o Tomé
				var pc: Color = GameData.PEN_COL[GameData.PEN_LIST[int(c.ci) % 6]]
				Spr.glow(c.x, c.y, 16, Color(pc.r, pc.g, pc.b, .5))
				b = 0.0
			Spr.save()
			Spr.translate(c.x, c.y + b)
			Spr.rotate(sin(T * .03 + c.x * .013) * .45)
			Spr.A(pen, 0, 0, .62)
			Spr.restore()
			# brilho em cruz passando de vez em quando
			var gt: int = (T + int(c.ci) * 37) % 150
			if gt < 12:
				var gk: float = sin(gt / 12.0 * PI)
				var gx: float = c.x + 3
				var gy: float = c.y + b - 9
				Spr.seg(gx - 8 * gk, gy, gx + 8 * gk, gy, Color(1, 1, .9, .9 * gk), 1.6)
				Spr.seg(gx, gy - 8 * gk, gx, gy + 8 * gk, Color(1, 1, .9, .9 * gk), 1.6)
				Spr.glow(gx, gy, 9, Color(1, 1, .8, .6 * gk))
	# (objetos fora da tela não são desenhados: antes todos os da fase passavam por aqui a cada quadro)
	for c in g.CLK:
		if not c.got and c.x > x0 - 60 and c.x < x1 + 60:
			if c.ry > 0:
				Spr.glow(c.x, c.ry - 18, 26, Color(.75, .88, 1, .35 + sin(T * .08) * .15))
				Spr.ellipse(c.x, c.ry - 1, 12, 3, Color(0, 0, 0, .28))
				Spr.A("hourglass", c.x, c.ry, .48)
			else:
				Spr.A("hourglass", c.x, c.y + 16 + sin(T * .08 + c.x) * 3, .48)
	for c in g.OIL:
		if not c.got and c.x > x0 - 60 and c.x < x1 + 60:
			_oil(c, T, g.lantern_lit)
	for d in g.DRWS:
		if not d.got and not d.get("hidden") and d.x > x0 - 60 and d.x < x1 + 60:
			Spr.glow(d.x, d.y, 34, Color(1, .94, .78, .45))
			Spr.save()
			Spr.translate(d.x, d.y + sin(T * .06) * 3)
			Spr.rotate(sin(T * .04 + d.x) * .12)
			Spr.A("drawing", 0, 0, .6)
			Spr.restore()
	for it in g.ITEMS:
		if it.got or it.x < x0 - 60 or it.x > x1 + 60:
			continue
		_ground_obj("it_" + it.id, it, .6, Color(1, .94, .74, .5), false)
	for c in g.CLUES:
		if c.got or c.x < x0 - 60 or c.x > x1 + 60:
			continue
		var flat: bool = int(c.id) in [2, 3, 4, 6]
		var cy: float = _ground_obj("cl_%d" % int(c.id), c, .55, Color(.67, .86, 1, .6), flat)
		Spr.text("?", c.x + 17, cy - 18 + sin(T * .12) * 2, 15, Color("#e8f4ff"), HORIZONTAL_ALIGNMENT_CENTER, Spr.font_b, 3)
	for s in g.SPECS:
		if s.got or s.x < x0 - 60 or s.x > x1 + 60:
			continue
		var b4 := sin(T * .09 + s.x) * 4
		var sy: float = s.y + b4 if s.ry < 0 else s.ry - 22 + b4 * .5
		Spr.glow(s.x, sy, 30 + sin(T * .2) * 3, Color(1, 1, 1, .4))
		Spr.A("pen_" + s.c, s.x, sy, 1.05)
		# as faíscas nascem no passo de física (AmbientFx._tick_sparkles), não aqui no desenho
	# água do brejo (na frente do pai: ele afunda nela)
	for s in g.SWAMP:
		var a: float = max(s.x, x0)
		var b5: float = min(s.x + s.w, x1)
		if b5 <= a:
			continue
		var depth: float = max(30, s.y0 + s.h - s.y)
		# água tóxica (verde ácido): aqui o Tomé afunda — bem diferente da água azul onde dá para nadar
		_water(g, a, b5, s.y, depth, Color(.42, .86, .16, .9), Color(.08, .26, .04, .97), T, false, 0.0, "s%d" % g.SWAMP.find(s), s.x, s.x + s.w)
		if not s.get("fumes"):
			_shade_under(s.y + depth, Color(.02, .03, .08, g.AMB.dark * .45))
		var deep: bool = depth >= 100.0
		if deep:
			# brejo fundo visto de lado: a água turva escurece para baixo (nada de bloco verde chapado),
			# com uns fiapos de lodo boiando no meio
			var my: float = s.y + 40.0
			var by1: float = s.y0 + s.h
			# algas do fundo, escuras, balançando devagar (o lodo de baixo escurece as pontas de baixo)
			var ak: float = floor(a / 90.0) * 90.0 - 90.0
			while ak < b5 + 90.0:
				var ax: float = ak + WorldExtras.h(ak, 21) * 50.0
				var ah: float = min(depth - 60.0, 60.0 + WorldExtras.h(ak, 22) * 90.0)
				if ax > s.x + 24 and ax < s.x + s.w - 24 and ah > 40.0:
					var aw: float = ah * .32
					var sw2: float = sin(T * .025 + ax * .05) * 6.0
					for k in 5:
						var v0: float = k / 5.0
						var v1: float = (k + 1) / 5.0
						Spr.PB("alga%d" % int(WorldExtras.h(ak, 23) * 6), ax - aw / 2 + sw2 * pow(v0, 1.5), by1 - 8 - ah * v1, aw, ah / 5.0 + 1.5, 1.0 - v1, 1.0 - v0, Color(.35, .5, .22, .7))
				ak += 90.0
			Spr.vgrad(a, my, b5 - a, 24.0, Color(.13, .2, .09, 0), Color(.13, .2, .09, .42))
			Spr.vgrad(a, my + 24.0, b5 - a, max(0.0, by1 - my - 24.0), Color(.13, .2, .09, .42), Color(.02, .07, .03, .85))
			var lk: float = floor(a / 70.0) * 70.0
			while lk < b5:
				var lx2: float = lk + WorldExtras.h(lk, 11) * 40.0
				if lx2 > a + 8 and lx2 < b5 - 8 and lx2 > s.x + 20 and lx2 < s.x + s.w - 20:
					var ly2: float = s.y + 70.0 + WorldExtras.h(lk, 12) * max(10.0, depth - 120.0) + sin(T * .02 + lk) * 4.0
					Spr.ellipse(lx2, ly2, 9 + WorldExtras.h(lk, 13) * 8, 2.2, Color(.3, .5, .16, .22))
				lk += 70.0
		if s.get("fumes") or deep:
			# fundo do lago: leito de lama irregular com pedrinhas (nada de linha reta)
			var bed := PackedVector2Array()
			var bx2: float = a
			var by0: float = s.y0 + s.h
			while bx2 <= b5 + 12:
				var u2: float = clamp((bx2 - s.x) / max(1.0, float(s.w)), 0.0, 1.0)
				var dip: float = sin(u2 * PI) * 26.0
				bed.push_back(Vector2(min(bx2, b5), by0 - 34 + 26 - dip + 5 * sin(bx2 * .07) + 3 * sin(bx2 * .19)))
				bx2 += 12
			bed.push_back(Vector2(b5, by0 + 4))
			bed.push_back(Vector2(a, by0 + 4))
			Spr.poly(bed, Color("#2e2410"))
			var pk: float = floor(a / 46.0) * 46.0
			while pk < b5:
				if pk > s.x + 12 and pk < s.x + s.w - 12 and WorldExtras.h(pk, 7) > .55:
					Spr.P("peb%d" % (int(pk) % 3), pk, by0 - 6 - sin(clamp((pk - s.x) / float(s.w), 0, 1) * PI) * 18, 16, false, 0.0, Color(.55, .65, .4))
				pk += 46
		if s.get("fumes"):
			# vapor de veneno subindo (não deixa planar por cima)
			for k in 7:
				var fx: float = s.x + fposmod(k * 53.0 + T * .3, max(20.0, s.w - 20)) + 10
				var u: float = fposmod(T * .006 + k * .37, 1.0)
				var fy: float = s.y - u * 170.0
				var fa: float = sin(u * PI) * .22
				Spr.circle(fx + sin(T * .03 + k) * 10, fy, 10 + u * 22, Color(.55, .95, .3, fa))
		Spr.rect(a, s.y - 2, b5 - a, 4, Color(.75, 1, .35, .7))
		# bolhas tóxicas subindo e estourando, e um vapor fraco por cima
		var bx: float = floor(a / 46.0) * 46.0
		while bx < b5:
			var ph: float = fmod(T * .011 + bx * .0131, 1.0)
			var px: float = bx + sin(bx * .7) * 14
			if px > a and px < b5:
				var r: float = 3.0 + fmod(bx * .37, 4.0)
				if ph < .8:
					var by: float = s.y + 40 - ph / .8 * 40
					Spr.circle(px, by, r, Color(.6, 1, .3, .55))
					Spr.ring(px, by, r, Color(.85, 1, .55, .8), 1.2)
				else:
					var u: float = (ph - .8) / .2
					Spr.ring(px, s.y - 2, r + u * 9, Color(.8, 1, .45, .8 * (1.0 - u)), 1.5)
					Spr.glow(px, s.y - 4, 16, Color(.55, 1, .25, .35 * (1.0 - u)))
				var vy: float = s.y - 8 - fmod(T * .4 + bx, 40.0)
				Spr.ellipse(px + 10, vy, 14, 5, Color(.6, .95, .4, .1))
			bx += 46.0
		# pingos de chuva na superfície (presos ao brejo, não à câmera)
		_rain_rings(g, a, b5, s.x, s.x + s.w, T, true, last_top)
	_projectiles(g, T)
	_extras(g, T)
	# manivela: aviso e barrinha de quanto a porta já subiu (por cima do escuro da mina)
	for c in g.CRANKS:
		if not c.done and g.near_crank() == c:
			Spr.text("↻ GIRE A MANIVELA", float(c.x), float(c.y) - 120 + sin(T * .15) * 3, 18, Color("#ffecaa"), HORIZONTAL_ALIGNMENT_CENTER, Spr.font_b, 4)
			Spr.rr(float(c.x) - 30, float(c.y) - 104, 60, 8, 4, Color(0, 0, 0, .55))
			Spr.rr(float(c.x) - 29, float(c.y) - 103, 58 * float(c.turn), 6, 3, Color("#ffd27a"))
	for l in g.LOCKS:
		if l.get("crank") and not l.done and g.player.nearL == l and g.has_item(l.need):
			Spr.rr(float(l.x) - 10, float(l.y) - 40, 60, 8, 4, Color(0, 0, 0, .55))
			Spr.rr(float(l.x) - 9, float(l.y) - 39, 58 * float(l.turn), 6, 3, Color("#ffd27a"))
	# cogumelos gigantes brilham no escuro, e vaga-lumes mostram o caminho
	if g.TR:
		for o in g.TR.T:
			if o.k == "giant" and o.x > x0 - 200 and o.x < x1 + 200:
				var gc := Color(o.get("c", "#6a5acd"))
				if not o.has("to"):
					gc = gc.darkened(.4)
				Spr.glow(o.x, o.cap + 4, o.w * .7, Color(gc.r, gc.g, gc.b, (.22 if o.has("to") else .1) + .06 * sin(T * .05 + o.x)))
				if o.has("to"):
					WorldTraps.giant_arc(o, T)
				for d in [[-.3, -.15, .07], [.05, -.22, .08], [.3, -.1, .06]]:
					Spr.circle(o.x + d[0] * o.w, o.cap + 8 + d[1] * o.w, d[2] * o.w * .6, Color(.85, 1, .95, .35))
	# no túnel: gotas pingando do teto e poeira dançando na luz da lanterna
	var tn: Array = g.L.get("tunnel", [])
	if tn.size() >= 2 and float(tn[1]) > x0 and float(tn[0]) < x1:
		for k in 9:
			var dx: float = float(tn[0]) + fposmod(k * 433.0 + 97.0, float(tn[1]) - float(tn[0]))
			if dx < x0 or dx > x1:
				continue
			var per: float = 90.0 + k * 13
			var ph: float = fposmod(T + k * 37.0, per)
			if ph < 30:
				# gota se formando
				Spr.ellipse(dx, 382 + ph * .1, 2 + ph * .05, 2.5 + ph * .08, Color(.6, .75, .85, .7))
			elif ph < 55:
				var fy: float = 385 + pow((ph - 30) / 25.0, 2) * 115
				Spr.ellipse(dx, fy, 1.8, 3.5, Color(.7, .85, .95, .8))
			elif ph < 70:
				var u: float = (ph - 55) / 15.0
				Spr.ring(dx, 499, 3 + u * 12, Color(.7, .85, .95, .6 * (1.0 - u)), 1.2)
	if g.indoors() or g.AMB.dark > .45:
		var pl: Dictionary = g.player
		var lx: float = pl.x + pl.w / 2 + pl.face * 16
		var ly: float = pl.y + pl.h * .4
		for k in 16:
			var ang: float = k * 2.4 + T * (.004 + k * .0007)
			var rad: float = 30 + fposmod(k * 17.0, 70.0) + sin(T * .01 + k) * 10
			var mx: float = lx + cos(ang) * rad + pl.face * 30
			var my: float = ly + sin(ang * 1.3) * rad * .6 - 10
			var a: float = clamp(1.0 - rad / 110.0, 0, 1) * (.4 + .3 * sin(T * .07 + k))
			Spr.circle(mx, my, 1.2, Color(1, .92, .7, a))
	# lembranças escondidas: pedra rachada atrás de uma moita; quebrada, mostra a lembrança brilhando
	if g.X:
		for r in g.X.RELICS:
			if r.x < x0 - 80 or r.x > x1 + 80:
				continue
			if not r.broken:
				Spr.ellipse(r.x, r.y + 1, 26, 5, Color(0, 0, 0, .3))
				Spr.AB("o_rocks", r.x - 30, r.y - 44, 60, 48)
				Spr.seg(r.x - 6, r.y - 34, r.x + 2, r.y - 20, Color(.1, .08, .06, .9), 2)
				Spr.seg(r.x + 2, r.y - 20, r.x - 4, r.y - 8, Color(.1, .08, .06, .9), 2)
				Spr.seg(r.x + 2, r.y - 20, r.x + 12, r.y - 14, Color(.1, .08, .06, .9), 1.6)
				if (T + int(r.x)) % 160 < 10:
					Spr.glow(r.x + 2, r.y - 22, 12, Color(1, .9, .6, .6))
			elif not r.got:
				var by: float = r.y - 20 + sin(T * .08) * 3
				Spr.glow(r.x, by, 34, Color(1, .85, .55, .5))
				Spr.circle(r.x, by, 8, Color("#f0c060"))
				Spr.ring(r.x, by, 8, Color("#8a5a20"), 2)
				Spr.circle(r.x - 2, by - 2, 2.5, Color(1, 1, 1, .7))
			# moita na frente (fica transparente quando o Tomé chega perto)
			var near_r: bool = abs(g.player.x + g.player.w / 2 - r.x) < 70 and abs(g.player.y + g.player.h - r.y) < 80
			Spr.AB("o_bush", r.x - 70 + 24, r.y - 74, 110, 76, .3 if near_r else 1.0)
	# enchente tóxica subindo na gruta
	if g.EV and not g.EV.FL.is_empty() and g.EV.FL.st in ["warn", "rise", "fall"]:
		var F: Dictionary = g.EV.FL
		var fa: float = max(float(F.x0), x0)
		var fb: float = min(float(F.x1), x1)
		if fb > fa:
			_water(g, fa, fb, F.level, float(F.y0) + 20 - F.level, Color(.42, .86, .16, .9), Color(.08, .26, .04, .97), T, true, 0.0, "flood", float(F.x0), float(F.x1))
			if F.st == "warn" and T % 6 < 3:
				Spr.text("⚠", g.player.x + g.player.w / 2, g.player.y - 30, 30, Color(.7, 1, .3), HORIZONTAL_ALIGNMENT_CENTER, Spr.font_b, 5, Color(0, 0, 0, .8))
	# janelas acesas das casas da vila: a luz de dentro tremula como lamparina
	for d in g.L.get("decor", []):
		if not d.k in ["house1", "house2"] or d.x < x0 - 200 or d.x > x1 + 200:
			continue
		var r = Spr.AR["v_" + d.k]
		var k: float = 210.0 * d.get("s", 1.0) / r[2]
		var wins: Array = [[35, 107], [62, 107], [110, 100], [160, 100], [42, 167], [65, 167]] if d.k == "house1" else [[37, 107], [67, 107], [117, 102], [169, 102], [155, 55], [51, 165], [169, 170]]
		for i in wins.size():
			var wx: float = d.x + (wins[i][0] - r[2] / 2.0) * k
			var wy: float = d.y + 6 - (r[3] - wins[i][1]) * k
			var fl: float = .7 + .3 * sin(T * .13 + i * 2.1) * sin(T * .07 + i)
			Spr.glow(wx, wy, 26, Color(1, .78, .35, .32 * fl))
	_village_windows(g, T, x0, x1)
	# vaga-lumes dos trechos marcados: piscam de verdade (acendem rápido, apagam devagar, ficam um tempo
	# apagados) e não aparecem dentro da terra nem com o Tomé debaixo d'água
	var hide_ff: bool = g.indoors() or g.submerged()
	for ff in g.L.get("fireflies", []):
		if hide_ff or ff[1] < x0 or ff[0] > x1:
			continue
		for k in 26:
			var fx: float = ff[0] + fposmod(k * 137.0 + sin(T * .01 + k) * 60.0, ff[1] - ff[0])
			if fx < x0 or fx > x1:
				continue
			var fy: float = ff[2] + fposmod(k * 71.0, 360.0) + sin(T * .03 + k * 1.3) * 18
			var on: float = _ff_blink(T * .07 + k * 5.3, k)
			Spr.circle(fx, fy, 1.3, Color(.55, .6, .3, .5))
			if on > .02:
				Spr.glow(fx, fy, 12 + 4 * on, Color(.75, 1, .4, .38 * on))
				Spr.circle(fx, fy, 2, Color(.95, 1, .65, .95 * on))
	_spores(T)
	# moitas (escondem passagens)
	var p: Dictionary = g.player
	for bsh in g.BUSH:
		if bsh.x > x1 + 60 or bsh.x + bsh.w < x0 - 60:
			continue
		var near: bool = abs(p.x + p.w / 2 - (bsh.x + bsh.w / 2)) < bsh.w / 2 + 10 and abs(p.y + p.h - (bsh.y + bsh.h)) < bsh.h
		# a moita treme quando o Tomé passa por dentro e solta folhinhas
		var wob: float = sin(T * .5) * .04 if (near and abs(p.vx) > .5) else 0.0
		Spr.save()
		Spr.translate(bsh.x + bsh.w / 2, bsh.y + bsh.h)
		Spr.rotate(wob)
		Spr.AB("o_bush_gold", -bsh.w / 2 - 20, -84, bsh.w + 40, 84, .35 if near else 1.0)
		Spr.restore()
		# folhinhas soltas: AmbientFx._tick_sparkles (passo de física)

## beirada do buraco que aparece até no escuro: contorno claro seguindo a terra que desmorona e
## pedrinhas soltas caindo da borda


func _pit_rim(e: float, y: float, dir: float, k: float) -> void:
	# beira do buraco: musgo e cogumelinhos que brilham sozinhos (dá para ver a borda mesmo no
	# escuro), vaga-lumes em volta e, lá no fundo, uma claridade fraca dando noção da altura
	var dark: float = clamp(game.AMB.dark, 0, 1)
	var a: float = clamp(dark * 1.4, .25, 1.0)
	var t := float(game.T)
	Spr.ellipse(e - dir * 16, y + 1, 18, 3, Color(.45, 1, .75, .35 * a))
	Spr.glow(e - dir * 14, y - 4, 26, Color(.4, .95, 1, .22 * a + .05 * sin(t * .05 + e)))
	Spr.P("mush1", e - dir * 9, y + 2, 13, dir < 0, 0.0, Color(.75, 1.3, 1.5, a))
	Spr.P("mush3", e - dir * 26, y + 2, 17, dir > 0, 0.0, Color(.75, 1.25, 1.45, a))
	for i in 3:
		var ph: float = t * .03 + i * 2.1 + e
		var fx: float = e + dir * (6 + 14 * sin(ph))
		var fy: float = y - 20 + 12 * cos(ph * 1.3)
		var tw: float = .5 + .5 * sin(t * .2 + i)
		Spr.glow(fx, fy, 7, Color(1, 1, .5, .45 * a * tw))
		Spr.circle(fx, fy, 1.4, Color(1, 1, .7, .9 * a * tw))
	# claridade fraca no fundo
	Spr.glow(e + dir * 50, y + 150, 60, Color(.35, .6, .9, .07 * a))

## Objeto pousado no chão (com sombra e brilho suave); se não houver chão perto, flutua.
func _ground_obj(n: String, o: Dictionary, sc: float, glow: Color, flat: bool) -> float:
	var r = Spr.AR.get(n)
	if r == null:
		return o.y
	var T := game.T
	if o.ry < 0:
		var b := sin(T * .08 + o.x) * 3
		Spr.glow(o.x, o.y + b, 32, glow)
		Spr.A(n, o.x, o.y + b, sc)
		return o.y + b
	var h: float = r[3] * sc * (.5 if flat else 1.0)
	var cy: float = o.ry - h / 2 - 1
	var pulse := .55 + sin(T * .08 + o.x) * .25
	Spr.glow(o.x, cy, 30, Color(glow.r, glow.g, glow.b, glow.a * pulse))
	Spr.ellipse(o.x, o.ry - 1, r[2] * sc * .45, 3, Color(0, 0, 0, .28))
	Spr.save()
	Spr.translate(o.x, o.ry - 1)
	Spr.scale(1, .5 if flat else 1.0)
	Spr.A(n, 0, -r[3] * sc / 2, sc)
	Spr.restore()
	return cy

## Sistemas novos que brilham ou ficam na frente: facho, raio dos espelhos, lápis dourado, água,
## bolhas, ondinhas, mariposas, vaga-lumes e a "tampa" das salas secretas ainda não achadas.
func _extras(g: Game, T: int) -> void:
	var X: Extras = g.X
	var p: Dictionary = g.player
	var dark: float = g.AMB.dark
	# lápis dourado
	if not X.GOLD.is_empty() and not X.GOLD.got:
		var gy: float = X.GOLD.y + sin(T * .07) * 3
		Spr.glow(X.GOLD.x, gy, 46 + sin(T * .15) * 5, Color(1, .85, .35, .55))
		Spr.save()
		Spr.translate(X.GOLD.x, gy)
		Spr.rotate(-.5)
		Spr.A("pen_gold", 0, 0, 1.1)
		Spr.restore()
	# água (na frente do Tomé)
	for w in X.WATER:
		if w.x > g.cam + g.W or w.x + w.w < g.cam:
			continue
		# tinge de leve: o Tomé e os peixes continuam bem visíveis debaixo d'água
		_water(g, max(w.x, g.cam - 40), min(w.x + w.w, g.cam + g.W + 40), w.y, w.h, Color(.24, .52, .6, .26), Color(.04, .14, .22, .4), T, false, 0.0, "w%d" % X.WATER.find(w), w.x, w.x + w.w)
		_shade_under(w.y + w.h, Color(.02, .03, .08, dark * .25))
	WorldLake.front(g, T)
	WorldKings.draw_fish(g, T)
	WorldNature.draw_bogs(g, T)
	for b in X.BUB:
		Spr.ring(b.x, b.y, 2 + b.t * .02, Color(.85, .95, 1, .7), 1.2)
	for r in X.RIP:
		var a: float = 1.0 - r.t / 50.0
		Spr.ci.draw_arc(Vector2(r.x, r.y), (4 + r.t * .7) * r.s, 0, TAU, 20, Color(.85, .95, .9, .45 * a), 1.2)
	_wave_rings(g)
	# facho da lanterna
	if X.focus:
		var o := X.lamp()
		var f: float = p.face
		var L := Extras.BEAM_LEN
		var spread: float = tan(Extras.BEAM_ANG) * L
		var cone := PackedVector2Array([o, Vector2(o.x + f * L, o.y - spread), Vector2(o.x + f * L, o.y + spread)])
		var ca := .16 + dark * .22
		Spr.ci.draw_polygon(cone, PackedColorArray([Color(1, .92, .65, ca + .15), Color(1, .9, .6, 0), Color(1, .9, .6, 0)]))
		var core := PackedVector2Array([o, Vector2(o.x + f * L * .8, o.y - spread * .35), Vector2(o.x + f * L * .8, o.y + spread * .35)])
		Spr.ci.draw_polygon(core, PackedColorArray([Color(1, .95, .75, ca + .2), Color(1, .95, .7, 0), Color(1, .95, .7, 0)]))
		Spr.glow(o.x, o.y, 26, Color(1, .9, .6, .6))
	if X.BEAM.size() >= 2:
		var pl := PackedVector2Array(X.BEAM)
		Spr.ci.draw_polyline(pl, Color(1, .9, .55, .35), 9, true)
		Spr.ci.draw_polyline(pl, Color(1, .97, .8, .95), 3, true)
		Spr.glow(X.BEAM[X.BEAM.size() - 1].x, X.BEAM[X.BEAM.size() - 1].y, 22, Color(1, .95, .7, .7))
	for c in X.CRYSTALS:
		if (c.on or c.charge > 0) and c.x > g.cam - 120 and c.x < g.cam + g.W + 120:
			Spr.glow(c.x, c.y, 30 + c.charge * .5, Color(.6, .85, 1, .25 + c.charge / 120.0))
	# mariposas em volta da lanterna
	if g.lantern_lit and dark > .35 and not g.player.get("isis"):
		var o2 := X.lamp()
		for m in X.MOTHS:
			var mx: float = o2.x + cos(m.a) * m.r
			var my: float = o2.y + sin(m.a * 1.3) * m.r * .6 - 6
			# asinhas em "V" batendo (abrem para cima e fecham), corpinho escuro no meio
			var fl: float = sin(m.ph)
			var wa: float = .35 + .55 * fl
			var wc := Color(.92, .88, .78, .8)
			Spr.ellipse(mx - 2.6, my - 1.0 * fl, 3.2, 1.8, wc, -wa)
			Spr.ellipse(mx + 2.6, my - 1.0 * fl, 3.2, 1.8, wc, wa)
			Spr.ellipse(mx, my + .5, 1.0, 2.0, Color(.45, .38, .32, .95))
	# vaga-lumes (fogem da lanterna): piscada de vaga-lume de verdade; o corpinho escuro fica visível
	# de leve entre as piscadas
	if not (g.indoors() or g.submerged()):
		var fi := 0
		for ff in X.FIRE:
			var bl: float = _ff_blink(ff.ph, fi)
			Spr.circle(ff.x, ff.y, 1.1, Color(.5, .55, .3, .35))
			if bl > .02:
				Spr.glow(ff.x, ff.y, 9 + 4 * bl, Color(.85, 1, .45, .55 * bl * (.45 + dark)))
				Spr.circle(ff.x, ff.y, 1.6, Color(1, 1, .7, bl))
			fi += 1
	# salas secretas ainda tampadas
	var mod := Color(1, 1, 1).lerp(Color(.035, .05, .1), clamp(dark, 0, 1) * .97)
	for sc in X.SECRETS:
		if sc.a > 0 and sc.x < g.cam + g.W + 20 and sc.x + sc.w > g.cam - 20:
			Spr.rect(sc.x - 2, sc.y - 2, sc.w + 4, sc.h + 4, Color(.165 * mod.r, .102 * mod.g, .055 * mod.b, sc.a))

## Carvão em brasa (Vargas) e torrões de terra (toupeira): grandes, brilhando, com sombra no chão.
func _projectiles(g: Game, T: int) -> void:
	for c in g.COAL:
		var dirt: bool = c.get("k", "") == "dirt"
		var gy: float = c.get("gy", -1.0)
		if gy > 0 and gy > c.y:
			var k: float = clamp(1.0 - (gy - c.y) / 300.0, .25, 1.0)
			Spr.ellipse(c.x, gy - 1, 14 * k, 4 * k, Color(.8, .15, .05, .45 * k) if not dirt and c.get("k", "") != "acorn" else Color(0, 0, 0, .35 * k))
		if c.get("k", "") == "acorn":
			Spr.save()
			Spr.translate(c.x, c.y)
			Spr.rotate(c.rot)
			Spr.ellipse(0, 2, 6, 7, Color("#9a6a32"))
			Spr.ellipse(0, -4, 7, 3.5, Color("#5a3a1a"))
			Spr.seg(0, -7, 1, -10, Color("#5a3a1a"), 1.5)
			Spr.ellipse(-2, 1, 1.5, 3, Color(1, 1, 1, .35))
			Spr.restore()
			continue
		if dirt:
			Spr.save()
			Spr.translate(c.x, c.y)
			Spr.rotate(c.rot)
			# torrão de terra (pedrinha pintada em tom de terra)
			Spr.P("peb1", 0, 9, 22, false, 0.0, Color(.72, .52, .34))
			Spr.restore()
			continue
		var fl: float = .8 + sin(T * .6 + c.x) * .2
		Spr.glow(c.x, c.y, 34 * fl, Color(1, .45, .1, .55))
		Spr.save()
		Spr.translate(c.x, c.y)
		Spr.rotate(c.rot)
		Spr.scale(1.5, 1.5)
		Spr.poly(PackedVector2Array([Vector2(-8, -3), Vector2(-3, -8), Vector2(6, -6), Vector2(8, 2), Vector2(2, 8), Vector2(-7, 5)]), Color(.16, .12, .12))
		Spr.ci.draw_polyline(PackedVector2Array([Vector2(-5, -2), Vector2(0, 1), Vector2(4, -3)]), Color(1, .6, .15, fl), 1.6, true)
		Spr.ci.draw_polyline(PackedVector2Array([Vector2(-2, 5), Vector2(1, 2), Vector2(5, 4)]), Color(1, .45, .1, fl), 1.4, true)
		Spr.restore()

## água parada com cara de água: degradê pela profundidade, faixas de luz (cáusticas) perto da superfície,
## a linha de cima (com as ondas) da última água desenhada
var last_top := PackedVector2Array()

## escurece a água do jeito da superfície (sem faixa reta acima das ondas)
func _shade_under(bottom: float, c: Color) -> void:
	if last_top.size() < 2 or c.a <= 0.0:
		return
	var pts := last_top.duplicate()
	pts.push_back(Vector2(last_top[last_top.size() - 1].x, bottom))
	pts.push_back(Vector2(last_top[0].x, bottom))
	Spr.poly(pts, c)

## superfície brilhante com ondinhas, reflexo da lanterna e bolhas / lentilha-d'água.
## [a, b] = faixa visível; [bx0, bx1] = o corpo d'água inteiro: todo detalhe que anda (espuma, bolhas,
## folhas, pingos, reflexos) fica preso no corpo d'água e só é desenhado se cair dentro de [a, b]
func _water(g: Game, a: float, b: float, y: float, depth: float, c0: Color, c1: Color, T: int, swamp: bool, ox: float = 0.0, key: String = "", bx0: float = 0.0, bx1: float = 0.0) -> void:
	var w: float = b - a
	if bx1 <= bx0:
		bx0 = a
		bx1 = b
	var W: float = max(1.0, bx1 - bx0)
	var toxic: bool = swamp or key.begins_with("s")
	var per: String = AFX.period(g)
	var sky: Color = AFX.sky_col(per)
	var lowfx: bool = g.low_fx
	# água tóxica pulsa devagar (mais clara e mais escura); a água limpa puxa a cor do céu na faixa de cima
	var pulse: float = .5 + .5 * sin(T * .025 + bx0 * .01)
	if toxic:
		c0 = c0.lightened(.07 * pulse)
	else:
		c0 = c0.lerp(Color(sky.r, sky.g, sky.b, c0.a), .28)
	var mid := c0.lerp(c1, .45)
	# superfície com ondas de verdade (molas) + um balanço suave constante
	var wb: Dictionary = {}
	if key != "" and g.WV:
		wb = g.WV.body(key, bx0, bx1, y)
	var top := PackedVector2Array()
	var hi := PackedVector2Array()
	var x2: float = floor(a / 8.0) * 8.0
	var ys: Array = []
	while x2 <= b + 8.1:
		var xx: float = clamp(x2, a, b)
		# balanço constante (três ondas cruzando) — a água nunca fica parada
		var oy: float = WorldLake.wave_off(g, wb, xx, T, toxic)
		top.push_back(Vector2(xx, y + oy))
		ys.append(oy)
		x2 += 8
	last_top = top
	var surf := func(px: float) -> float:
		var i: int = clamp(int(round((px - top[0].x) / 8.0)), 0, top.size() - 1)
		return top[i].y
	# corpo d'água: faixa de cima acompanha a onda, o resto em degradê
	var d1: float = min(depth, 70.0)
	var band := top.duplicate()
	band.push_back(Vector2(b, y + 12))
	band.push_back(Vector2(a, y + 12))
	Spr.poly(band, c0)
	Spr.vgrad(a, y + 12, w, max(0.0, d1 - 12), c0, mid)
	if depth > d1:
		Spr.vgrad(a, y + d1, w, depth - d1, mid, c1)
	# mais fundo, mais escuro e mais frio
	if not toxic and depth > 100:
		Spr.vgrad(a, y + 70, w, depth - 70, Color(.02, .07, .16, 0), Color(.01, .05, .14, .22))
	if toxic and Spr.has("sw_water"):
		Spr.strip_at("sw_water", ox, a, b, y - 6, min(70.0, depth + 6), .92)
	# faixas de luz que ondulam logo abaixo da superfície
	for k in 3:
		var pts := PackedVector2Array()
		var x := a
		var yy: float = y + 12 + k * 13
		while x <= b + 0.1:
			pts.push_back(Vector2(x, yy + sin(x * (.035 + k * .01) + T * (.035 + k * .012) + k * 2.0) * 3.5))
			x += 12
		if pts.size() >= 2:
			Spr.line(pts, Color(1, 1, .9, .07 - k * .015), 6 - k)
	# cáusticas: uma rede de luz (duas linhas em |seno| se cruzando) dançando logo abaixo da superfície
	if not toxic and not lowfx and depth > 30:
		for k in 2:
			var cp := PackedVector2Array()
			var cx: float = floor(a / 10.0) * 10.0
			while cx <= b + 10.0:
				var xc: float = clamp(cx, a, b)
				cp.push_back(Vector2(xc, y + 15 + k * 9 + abs(sin(xc * .045 + T * (.03 if k == 0 else -.026) + k * 1.3)) * 8.0))
				cx += 10.0
			Spr.line(cp, Color(1, 1, .92, .055), 1.6)
	# linha da superfície, brilho na crista das ondas e espuma onde a água está agitada
	for i in top.size():
		hi.push_back(top[i] + Vector2(0, -1.5))
	if toxic:
		# água tóxica: brilho verde pulsando na superfície (perigo bem visível)
		Spr.line(top, Color(.75, 1, .3, .18 + .1 * sin(T * .07)), 9)
	Spr.line(top, Color(.72, .86, .8, .7) if toxic else Color(.78, .95, 1, .75).lerp(Color(sky.r, sky.g, sky.b, .75), .3), 3)
	Spr.line(hi, Color(1, 1, 1, .35), 1)
	for i in range(1, top.size() - 1):
		var crest: float = ys[i] - (ys[i - 1] + ys[i + 1]) * .5
		if crest < -1.2:
			Spr.ellipse(top[i].x, top[i].y - 1, 6, 2, Color(1, 1, 1, clamp(-crest * .25, 0, .75)))
	# brilhos do sol piscando nas ondas (dia)
	if not toxic and per in ["manha", "tarde", "neve"]:
		var sx: float = floor(a / 41.0) * 41.0
		while sx < b:
			var tw: float = sin(T * .13 + sx * 1.7)
			var gx: float = sx + Polish.hh2(sx, 3) * 41.0
			if tw > .86 and gx > a and gx < b:
				var k2: float = (tw - .86) / .14
				var gy2: float = surf.call(gx) - 1
				Spr.seg(gx - 4 * k2, gy2, gx + 4 * k2, gy2, Color(1, 1, .95, .8 * k2), 1.2)
				Spr.seg(gx, gy2 - 3 * k2, gx, gy2 + 3 * k2, Color(1, 1, .95, .6 * k2), 1.0)
			sx += 41.0
	# pontinhos de espuma na superfície
	for k in int(W / 40.0):
		var fx: float = bx0 + fposmod(k * 53.7 + T * .2 * (1 + k % 3), W)
		if fx < a or fx > b:
			continue
		Spr.circle(fx, y + 2 + sin(T * .05 + k) * 1.2, 1.4, Color(1, 1, 1, .35))
	# reflexo da lanterna quando o Tomé está perto
	var p: Dictionary = g.player
	var px: float = p.x + p.w / 2
	if g.lantern_lit and px > a - 60 and px < b + 60 and abs(p.y + p.h - y) < 140:
		var rx: float = clamp(px + p.face * 10, a, b)
		var al: float = .35 * (1.0 - abs(p.y + p.h - y) / 140.0)
		for k in 4:
			Spr.ellipse(rx + sin(T * .1 + k) * 3, y + 6 + k * 7, 14 - k * 2.5, 2, Color(1, .85, .5, al * (1.0 - k * .2)))
	if not toxic and depth > 40:
		# luz dançando no fundo (cáusticas) e fachos de luz entrando na água, balançando devagar
		var rk: float = floor(a / 90.0) * 90.0
		while rk < b:
			var ra: float = .045 + .03 * sin(T * .02 + rk * .01)
			var r0: float = rk + 30 + sin(T * .01 + rk) * 10
			var lean: float = sin(T * .007 + rk * .02) * 8.0
			if r0 > a and r0 < b - 20:
				Spr.ci.draw_polygon(PackedVector2Array([Vector2(r0, y + 6), Vector2(r0 + 20, y + 6), Vector2(r0 + 46 + lean, y + min(depth, 160.0)), Vector2(r0 + 18 + lean, y + min(depth, 160.0))]),
					PackedColorArray([Color(1, 1, .9, ra), Color(1, 1, .9, ra), Color(1, 1, .9, 0), Color(1, 1, .9, 0)]))
			rk += 90
	# reflexo do céu: faixas claras e largas (na cor do céu) logo abaixo da superfície, ondulando devagar
	if not toxic:
		for k in 2:
			var rw: float = min(W * .35, 360.0)
			var rx2: float = bx0 + fposmod(k * W * .5 + T * .15 * (k + 1), W + rw) - rw * .5
			rx2 = clamp(rx2, bx0 + rw * .4, bx1 - rw * .4)
			if rx2 + rw * .5 < a or rx2 - rw * .5 > b:
				continue
			Spr.ellipse(rx2, y + 7 + k * 6, min(rw, W * .45) * .5, 3, Color(lerpf(1.0, sky.r, .4), lerpf(1.0, sky.g, .4), lerpf(1.0, sky.b, .4), .09))
	# margens: barranco arredondado cobrindo a quina, faixa de lama, juncos, pedras molhadas e folhas;
	# a lama e a espuma da beira sobem e descem junto com a onda daquele ponto
	for side in [0, 1]:
		var ex: float = bx0 if side == 0 else bx1
		if bx1 - bx0 < 60 or ex < a - 70 or ex > b + 70:
			continue
		var bi: int = clamp(int((clamp(ex, a, b) - top[0].x) / 8.0), 0, top.size() - 1)
		var soy: float = top[bi].y - y
		_bank(ex, y, 1.0 if side == 0 else -1.0, toxic, T, min(depth, 120.0), soy)
	if swamp:
		# lentilha-d'água e folhinhas boiando
		for k in int(W / 55.0):
			var lx: float = bx0 + fposmod(k * 71.3 + sin(T * .01 + k) * 6, W)
			if lx < a or lx > b:
				continue
			Spr.ellipse(lx, y + 1 + sin(T * .06 + k) * 1.2, 4 + k % 3, 1.6, Color(.45, .62, .25, .85))
	else:
		# bolhas subindo do fundo (cada uma do seu lugar, presas ao lago)
		for k in int(W / 70.0) + 1:
			var bx: float = bx0 + fposmod(k * 97.1, W)
			if bx < a or bx > b:
				continue
			var ph: float = fmod(T * .6 + k * 37.0, depth)
			Spr.ring(bx + sin(ph * .1 + k) * 3, y + depth - ph, 1.5 + ph * .01, Color(.85, .95, 1, .45 * (ph / depth)), 1.0)
	# folhas e pétalas boiando, levadas devagar pela correnteza (sobem e descem com a onda)
	if not toxic and per != "neve" and per != "tunel":
		var lcs: Array = Polish.C_LEAF_TARDE if per == "tarde" else (Polish.C_LEAF_PANT if per in ["chuva", "pantano"] else Polish.C_LEAF)
		for k in int(W / 140.0):
			var spd: float = .08 + Polish.hh2(bx0 + k, 21) * .1
			var lx2: float = bx0 + 10 + fposmod(Polish.hh2(bx0 + k, 22) * W + T * spd, W - 20)
			if lx2 < a + 4 or lx2 > b - 4:
				continue
			var ly2: float = surf.call(lx2) + 1
			var petal: bool = per == "manha" and k % 3 == 0
			var lc: Color = Color(1, .78, .86) if petal else lcs[k % lcs.size()]
			var rot: float = sin(T * .006 + k * 1.9) * .9 + k
			Spr.ellipse(lx2 + 1, ly2 + 1.5, 5, 1.6, Color(0, .05, .08, .18))
			Spr.ellipse(lx2, ly2, 3.2 if petal else 5.0, 1.8, lc, rot * .15)
			if not petal:
				Spr.seg(lx2 - 3.5, ly2, lx2 + 3.5, ly2, lc.darkened(.35), .8)
	# pingos de chuva (no brejo tóxico são desenhados depois da faixa clara da superfície)
	if not key.begins_with("s"):
		_rain_rings(g, a, b, bx0, bx1, T, toxic, top)
	# água tóxica: brilho verde doentio subindo da água, pulsando devagar (acima da escuridão)
	if toxic:
		var gx3: float = floor(a / 150.0) * 150.0
		while gx3 < b:
			var cxg: float = gx3 + 75.0
			if cxg > bx0 + 20 and cxg < bx1 - 20 and cxg > a - 60 and cxg < b + 60:
				var pk: float = .5 + .5 * sin(T * .021 + gx3 * .013)
				Spr.glow(cxg, y + 10, 95, Color(.45, 1, .18, .05 + .06 * pk))
			gx3 += 150.0

## pingos de chuva na superfície: aneizinhos presos ao corpo d'água [bx0, bx1], só os da faixa [a, b]
func _rain_rings(g: Game, a: float, b: float, bx0: float, bx1: float, T: int, toxic: bool, top: PackedVector2Array) -> void:
	var rain: float = float(g.AMB.get("rain", 0.0))
	if rain <= .15 or top.size() < 2:
		return
	var W: float = max(1.0, bx1 - bx0)
	var nr: int = min(16, int(W / 80.0) + 2)
	if g.low_fx:
		nr = min(nr, 6)
	for k in nr:
		var ph2: float = T * .024 + Polish.hh2(bx0 + k, 23) + k * .37
		var u: float = fposmod(ph2, 1.0)
		var cyc: float = floor(ph2) * 3.1
		var rx3: float = bx0 + Polish.hh2(bx0 + k * 13.0 + cyc, 24) * W
		if rx3 < a or rx3 > b:
			continue
		var i: int = clamp(int(round((rx3 - top[0].x) / 8.0)), 0, top.size() - 1)
		# espalhados na faixa de cima da água (vista um pouco de cima)
		var ry3: float = top[i].y + 4 + Polish.hh2(rx3 + cyc, 25) * 6
		var c := Color(.86, 1, .8) if toxic else Color(.9, .96, 1)
		_flat_ring(rx3, ry3, 2.0 + u * 11.0, Color(c.r, c.g, c.b, (1.0 - u) * .55 * rain), .35)

## anel achatado (ondinha na água, vista de lado)
func _flat_ring(x: float, y: float, r: float, c: Color, sy: float = .3) -> void:
	Spr.save()
	Spr.translate(x, y)
	Spr.scale(1, sy)
	Spr.ring(0, 0, r, c, 1.2 / sy * .7)
	Spr.restore()

## W1 ondinhas de quem entra, sai ou nada na água (lista em Waves, avança no passo de física)
func _wave_rings(g: Game) -> void:
	if not g.WV:
		return
	for r in g.WV.RINGS:
		if r.x < g.cam - 60 or r.x > g.cam + g.W + 60:
			continue
		var b: Dictionary = g.WV.B.get(r.key, {})
		if b.is_empty():
			continue
		var u: float = float(r.t) / r.life
		var yy: float = b.y + g.WV.height(b, r.x) + 1
		var c: Color = Color(.75, 1, .45) if str(r.key).begins_with("s") else Color(.92, .98, 1)
		_flat_ring(r.x, yy, (6.0 + u * 34.0) * r.s, Color(c.r, c.g, c.b, (1.0 - u) * .55))
		if u > .2:
			_flat_ring(r.x, yy, (2.0 + (u - .2) * 22.0) * r.s, Color(c.r, c.g, c.b, (1.0 - u) * .35))

## piscada de vaga-lume: acende rápido, apaga devagar e fica um tempo apagado (0..1); alguns dão uma
## segunda piscadinha fraca logo depois
static func _ff_blink(ph: float, k: int) -> float:
	var per: float = 12.0 + fmod(k * 3.7, 8.0)
	var u: float = fposmod(ph + k * 2.9, per) / per
	if u < .05:
		return u / .05
	if u < .22:
		var d: float = (u - .05) / .17
		return 1.0 - d * d
	if k % 3 == 0 and u > .3 and u < .38:
		return sin((u - .3) / .08 * PI) * .5
	return 0.0

## S4 esporos brilhantes subindo devagar dos cogumelos (estado em AmbientFx, avança no passo de física)
func _spores(T: int) -> void:
	for sp in AFX.SPORES:
		var u: float = float(sp.l) / float(sp.l0)
		var al: float = min(1.0, (1.0 - u) * 6.0) * min(1.0, u * 3.0)
		var tw: float = .65 + .35 * sin(T * .15 + sp.ph)
		var c: Color = sp.c
		Spr.glow(sp.x, sp.y, 8, Color(c.r, c.g, c.b, .32 * al * tw))
		Spr.circle(sp.x, sp.y, 1.3, Color(lerpf(c.r, 1.0, .5), lerpf(c.g, 1.0, .5), lerpf(c.b, 1.0, .5), .9 * al * tw))

## S6 janelas das casas da vila acesas à tarde e à noite: brilho quente tremulando como lamparina,
## a luz caindo na rua embaixo das janelas de baixo e o lampião da parede
func _village_windows(g: Game, T: int, x0: float, x1: float) -> void:
	AFX._cache(g)
	var hs: Array = AFX.C.get("ho", [])
	if hs.is_empty():
		return
	var per: String = AFX.period(g)
	var dk: float = float(g.AMB.get("dark", 0.0))
	if not (per in ["tarde", "noite", "perseguicao"] or dk > .2):
		return
	var nk: float = clamp(.45 + dk * 1.5, .45, 1.0)
	for s in hs:
		if s.x > x1 + 100 or s.x + s.w < x0 - 100:
			continue
		var v: int = int(s.get("v", 0))
		var r = Spr.AR.get("p_casa%d" % v)
		if r == null or not AFX.WIN.has(v):
			continue
		var hgt: float = s.w * r[3] / r[2]
		var fl0: bool = bool(s.get("flip", false))
		var top: float = s.y + 3 - hgt
		var i := 0
		for wn in AFX.WIN[v]:
			var u: float = 1.0 - wn[0] if fl0 else wn[0]
			var wx: float = s.x + s.w * u
			var wy: float = top + hgt * wn[1]
			var ww: float = s.w * wn[2]
			var wh: float = hgt * wn[3]
			var fl: float = .78 + .22 * sin(T * .11 + i * 2.3 + s.x) * sin(T * .053 + i)
			Spr.glow(wx, wy, max(ww, wh) * 2.0, Color(1, .72, .34, .3 * fl * nk))
			Spr.glow(wx, wy, max(ww, wh) * .9, Color(1, .86, .55, .2 * fl * nk))
			if wn[1] > .7:
				# luz da janela caindo na calçada
				var gy: float = s.y + 4
				var wb: float = wy + wh * .5
				Spr.ci.draw_polygon(PackedVector2Array([Vector2(wx - ww * .45, wb), Vector2(wx + ww * .45, wb), Vector2(wx + ww * .9, gy), Vector2(wx - ww * .9, gy)]),
					PackedColorArray([Color(1, .8, .45, .07 * fl * nk), Color(1, .8, .45, .07 * fl * nk), Color(1, .8, .45, .0), Color(1, .8, .45, .0)]))
				Spr.ellipse(wx, gy + 1, ww * 1.1, 3.5, Color(1, .8, .45, .12 * fl * nk))
			i += 1
		if AFX.LAMP.has(v):
			var lu: float = 1.0 - AFX.LAMP[v][0] if fl0 else AFX.LAMP[v][0]
			var lf: float = .8 + .2 * sin(T * .17 + s.x)
			Spr.glow(s.x + s.w * lu, top + hgt * AFX.LAMP[v][1], 30, Color(1, .8, .45, .32 * lf * nk))

## margem de um corpo d'água: terra arredondada descendo para dentro da água (sem quina reta),
## faixa de lama molhada, pedras brilhando, juncos e uma vitória-régia
func _bank(e: float, y: float, dir: float, toxic: bool, T: int, depth: float, soy: float = 0.0) -> void:
	# barranco com a textura da terra (raízes e pedrinhas), seguindo a curva e escurecendo para o fundo
	var t: Texture2D = preload("res://scripts/world_static.gd").gtex(game, e)
	var ts := t.get_size()
	var tint := Color(1, 1, 1) if not toxic else Color(.85, .95, .7)
	var pts := PackedVector2Array([Vector2(e - dir * 4, y - 4)])
	var edge := PackedVector2Array()
	for i in 13:
		var u := i / 12.0
		var p := Vector2(e + dir * (4 + sin(u * PI * .5) * 26 + sin(u * 9.0 + e) * 3), y - 4 + u * depth)
		pts.push_back(p)
		edge.push_back(p)
	pts.push_back(Vector2(e - dir * 4, y + depth))
	var uvs := PackedVector2Array()
	var cols := PackedColorArray()
	var ub: float = fposmod(e * .37, 80.0)
	for q in pts:
		uvs.push_back(Vector2((ub + 20 + (q.x - e) * dir) / ts.x, clamp((60.0 + (q.y - y + 4) * .75) / ts.y, 0, 1)))
		var dk: float = lerpf(.95, .45, clamp((q.y - y) / max(depth, 1.0), 0, 1))
		cols.push_back(Color(tint.r * dk, tint.g * dk, tint.b * dk))
	Spr.ci.draw_polygon(pts, cols, uvs, t)
	# contorno escuro da beira e a linha de lama molhada que sobe e desce com a onda
	Spr.line(edge, Color(.12, .08, .05, .7), 2)
	var wl: float = y + soy
	var mud := PackedVector2Array()
	for i in 7:
		var u2 := i / 6.0
		var yy: float = wl - 3 + u2 * 12
		var ex2: float = e + dir * (4 + sin(clamp((yy - y + 4) / max(depth, 1.0), 0, 1) * PI * .5) * 26)
		mud.push_back(Vector2(ex2 + dir * 1, yy))
	Spr.line(mud, Color("#2a1c10") if not toxic else Color("#28301a"), 6)
	Spr.line(mud, Color(1, 1, 1, .16), 1.5)
	var fo: float = .35 + .25 * sin(T * .09 + e)
	Spr.ellipse(e + dir * 30, wl + 1, 12, 2.2, Color(1, 1, 1, fo))
	Spr.ellipse(e + dir * 42, wl + 2, 6, 1.5, Color(1, 1, 1, fo * .7))
	# espuma acompanhando a margem: dois fiapos que vão e voltam com a água
	var fc := Color(1, 1, 1) if not toxic else Color(.85, 1, .7)
	for j in 2:
		var fl := PackedVector2Array()
		var off: float = 24 + j * 16 + sin(T * .03 + j * 2.0 + e) * 5
		for i in 6:
			var u3 := i / 5.0
			fl.push_back(Vector2(e + dir * (off + u3 * (24 + j * 12)), wl + 1.5 + j * 2.5 + sin(u3 * 5.0 + T * .05 + j) * 1.0))
		Spr.line(fl, Color(fc.r, fc.g, fc.b, (.3 - j * .1) * (.6 + .4 * sin(T * .04 + j + e))), 1.4)
	# pedrinhas pintadas e molhadas na beira
	for k in 3:
		var rx: float = e + dir * (6 + k * 11)
		var ry: float = wl + 6 + k * 4
		Spr.P("peb%d" % (k % 3), rx, ry, 14 - k * 2, dir < 0, 0.0, Color(.85, .9, .95))
	# juncos pintados balançando
	for k in 3:
		var jx: float = e - dir * (2 + k * 8)
		var sw: float = sin(T * .04 + jx) * 3
		Spr.P("cat_open" if k != 1 else "cat_bud", jx, y + 3, 15 + fmod(abs(jx) * .7, 8.0), dir < 0, sw, Color(.95, 1, .9) if not toxic else Color(.85, .95, .6))
	# vitória-régia boiando perto da margem
	if not toxic:
		var lx: float = e + dir * 52
		var ly: float = wl + 1
		Spr.ellipse(lx, ly, 14, 4, Color("#4f8a3a"))
		Spr.poly(PackedVector2Array([Vector2(lx, ly), Vector2(lx + 12, ly - 2), Vector2(lx + 12, ly + 2)]), Color(.2, .35, .4, .8))
		Spr.circle(lx - 4, ly - 2, 2.5, Color(1, .8, .9))

## frasco de óleo (lanterna acesa) ou pote de vaga-lumes (lanterna apagada), pousado no chão
func _oil(c: Dictionary, T: int, lit: bool) -> void:
	var by: float = c.ry if c.ry > 0 else c.y + 16
	var pul: float = .6 + sin(T * .09 + c.x) * .25
	if lit:
		Spr.glow(c.x, by - 16, 34, Color(1, .78, .35, .45 * pul))
		Spr.ellipse(c.x, by - 1, 10, 3, Color(0, 0, 0, .3))
		Spr.A("it_oleo", c.x, by - 15, .5)
	else:
		Spr.glow(c.x, by - 14, 36, Color(.7, 1, .4, .5 * pul))
		Spr.ellipse(c.x, by - 1, 10, 3, Color(0, 0, 0, .3))
		# pote de vidro com tampa de pano e vaga-lumes dentro
		Spr.rr(c.x - 9, by - 26, 18, 25, 5, Color(.75, .9, .85, .28))
		Spr.rect(c.x - 7, by - 30, 14, 5, Color(.55, .38, .22, 1))
		Spr.seg(c.x - 8, by - 26, c.x + 8, by - 26, Color(.35, .22, .12, 1), 1.6)
		for k in 5:
			var fx: float = c.x + sin(T * .05 + k * 2.1) * 6
			var fy: float = by - 13 + cos(T * .043 + k * 1.7) * 8
			Spr.circle(fx, fy, 1.6, Color(.9, 1, .5, .6 + .4 * sin(T * .2 + k)))
		Spr.ring(c.x, by - 13, 11, Color(.85, 1, .9, .35), 1.2)
