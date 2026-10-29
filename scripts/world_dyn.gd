extends Node2D
const WS = preload("res://scripts/world_static.gd")
## Tudo o que se mexe no mundo: escadas, cadeados, vitórias-régias, vilão, caixas, inimigos,
## o Tomé, poeira e faíscas. Redesenhado a cada quadro.

var game: Game
var T := 0
var pl_node: Node2D
var front_node: Node2D

class _Sub extends Node2D:
	var cb: Callable
	func _draw() -> void:
		cb.call(self)

var en_node: Node2D

func _ready() -> void:
	en_node = _Sub.new()
	en_node.cb = _draw_enemy_node
	var me := ShaderMaterial.new()
	me.shader = preload("res://scripts/depth_en.gdshader")
	en_node.material = me
	add_child(en_node)
	# gráficos no máximo: o mesmo volume (sombra de forma larga, luz do lado do sol) em tudo o que se
	# mexe no mundo — bichos, Isis, Pipoca, caixas, plantas — não só nos inimigos e no Tomé
	material = me
	pl_node = _Sub.new()
	pl_node.cb = _draw_player_node
	var m := ShaderMaterial.new()
	m.shader = preload("res://scripts/depth.gdshader")
	pl_node.material = m
	# folhas do Tomé com mipmaps: reduzidas na tela, o recorte fica liso (sem degraus)
	pl_node.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	add_child(pl_node)
	front_node = _Sub.new()
	front_node.cb = _draw_front_node
	add_child(front_node)

func _process(_d: float) -> void:
	queue_redraw()

## true no primeiro desenho depois de um passo da lógica: contadores visuais só andam aí
static var FRESH := true
var _lastT := -1

func _draw() -> void:
	var __t := Time.get_ticks_usec()
	__draw_raw()
	Spr.pt("dyn", __t)

func __draw_raw() -> void:
	if game == null or not game.L:
		return
	var g := game
	T = g.T
	FRESH = g.T != _lastT
	_lastT = g.T
	Polish.FRESH = FRESH
	Spr.begin(self)
	var cx0: float = g.cam - 400
	var cx1: float = g.cam + g.W + 400
	# tábuas e galhos (atrás de tudo que se mexe: o Javali-Rei e os bichos passam na frente): afundam um pouquinho e balançam quando o Tomé pisa ou aterrissa
	for so in g.SOL:
		var st_: String = str(so.get("t", ""))
		if (st_ != "plat" and st_ != "branch") or so.x > cx1 or so.x + so.w < cx0:
			continue
		var dp: float = so.get("dip", 0.0)
		Spr.save()
		Spr.translate(0, dp)
		if st_ == "plat":
			WS.plat(so)
		else:
			WS.branch(so)
		Spr.restore()
	var __q_mvvl := Time.get_ticks_usec()
	if g.MV:
		g.MV.draw(T)
	if g.VL:
		g.VL.draw(T)
	Spr.pt("d_mvvl", __q_mvvl)
	var __d__deco := Time.get_ticks_usec()
	_deco(g)
	Polish.draw_back(g, T)
	WorldExtras.flowers(g, T)
	Spr.pt("d__deco", __d__deco)
	var __d__climb := Time.get_ticks_usec()
	_climb(g)
	Spr.pt("d__climb", __d__climb)
	var __d__locks := Time.get_ticks_usec()
	_locks(g)
	Spr.pt("d__locks", __d__locks)
	var __d__entrances := Time.get_ticks_usec()
	_entrances(g)
	Spr.pt("d__entrances", __d__entrances)
	var __d__lily_mud := Time.get_ticks_usec()
	_lily_mud(g)
	Spr.pt("d__lily_mud", __d__lily_mud)
	var __d_Extras_chalk := Time.get_ticks_usec()
	WorldExtras.chalk(g, T)
	Spr.pt("d_Extras_chalk", __d_Extras_chalk)
	var __d_Extras_footprints := Time.get_ticks_usec()
	WorldExtras.footprints(g)
	Spr.pt("d_Extras_footprints", __d_Extras_footprints)
	var __d_Extras_crawl := Time.get_ticks_usec()
	WorldExtras.crawl(g, T)
	Spr.pt("d_Extras_crawl", __d_Extras_crawl)
	var __d_Extras_solids := Time.get_ticks_usec()
	WorldExtras.solids(g, T)
	Spr.pt("d_Extras_solids", __d_Extras_solids)
	var __d_Extras_mech := Time.get_ticks_usec()
	WorldExtras.mech(g, T)
	Spr.pt("d_Extras_mech", __d_Extras_mech)
	if g.SL:
		g.SL.draw(T)
	var __d_Props_draw := Time.get_ticks_usec()
	WorldProps.draw(g, T)
	Spr.pt("d_Props_draw", __d_Props_draw)
	WorldLake.back(g, T)
	var __d_Traps_draw := Time.get_ticks_usec()
	WorldTraps.draw(g, T)
	Spr.pt("d_Traps_draw", __d_Traps_draw)
	var __d_Nature_draw := Time.get_ticks_usec()
	WorldNature.draw(g, T)
	Spr.pt("d_Nature_draw", __d_Nature_draw)
	var __d__ride_world := Time.get_ticks_usec()
	_ride_world(g)
	Spr.pt("d__ride_world", __d__ride_world)
	var __d_Vehicles_draw := Time.get_ticks_usec()
	WorldVehicles.draw(g, T)
	Spr.pt("d_Vehicles_draw", __d_Vehicles_draw)
	var __d_Extras_boss := Time.get_ticks_usec()
	WorldExtras.boss(g, T)
	Spr.pt("d_Extras_boss", __d_Extras_boss)
	var __d_Kings_draw := Time.get_ticks_usec()
	WorldKings.draw(g, T)
	Spr.pt("d_Kings_draw", __d_Kings_draw)
	if g.VIL and g.VIL.go and not g.VIL.gone:
		var v: Dictionary = g.VIL
		var f: int = (T / max(3, int(10 - v.get("spd", 3.3)))) % 2
		Spr.A("lia_scared", v.x + 44, v.y - 58, .5)
		Spr.A("vg_cart1" if f else "vg_cart2", v.x, v.y + 2, 1)
	var __q_levhint := Time.get_ticks_usec()
	_levers(g)
	_hints(g)
	Spr.pt("d_levhint", __q_levhint)
	var __q_vinespr := Time.get_ticks_usec()
	for v in g.VINES:
		if v.x + v.len < cx0 or v.x - v.len > cx1:
			continue
		_vine(v)
	for s in g.SPR:
		_glow_mush(s.x, s.y, s.t)
	Spr.pt("d_vinespr", __q_vinespr)
	var __q_fircrit := Time.get_ticks_usec()
	for c in g.CHK:
		if c.x < cx0 or c.x > cx1:
			continue
		_campfire(c)
	for c in g.CR:
		if not c.dead and c.t != "push" and c.x > cx0 and c.x < cx1:
			_crate(c)
	Critters.draw(g, T)
	Spr.pt("d_fircrit", __q_fircrit)
	var __d_Extras_tocas := Time.get_ticks_usec()
	WorldExtras.tocas(g, T)
	Spr.pt("d_Extras_tocas", __d_Extras_tocas)
	if g.M and g.M.ctrl:
		var doff := g.ip_off()
		Spr.save()
		Spr.translate(doff.x, doff.y)
		WorldExtras.dog(g, T)
		Spr.restore()
	else:
		WorldExtras.dog(g, T)
	var __q_refl := Time.get_ticks_usec()
	if not g.low_fx:
		_reflection(g)
	Spr.pt("d_refl", __q_refl)
	# o Tomé é desenhado num nó só dele (com o sombreado de volume) e o que fica na frente dele
	# (capim, faíscas, poeira) num terceiro nó por cima
	en_node.queue_redraw()
	pl_node.queue_redraw()
	front_node.queue_redraw()

## nó do Tomé: volume com luz do sol (de cima, atrás) ou da lanterna (da frente)

## inimigos num nó próprio: ganham o mesmo volume (luz na borda) e a cor do ambiente do Tomé
func _draw_enemy_node(n: CanvasItem) -> void:
	var __t := Time.get_ticks_usec()
	_draw_enemy_node_raw(n)
	Spr.pt("en", __t)

func _draw_enemy_node_raw(n: CanvasItem) -> void:
	var g := game
	if g == null or not g.L:
		return
	Spr.begin(n)
	var mat: ShaderMaterial = n.material
	var dark: float = g.AMB.dark
	mat.set_shader_parameter("light_uv", Vector2(0.0, -1.0))
	mat.set_shader_parameter("rim_col", Color(1, .9, .72) if dark < .3 else Color(1, .78, .45))
	mat.set_shader_parameter("rim_amt", .26 if dark < .3 else .3 * clamp((dark - .3) * 3.0, 0, 1))
	mat.set_shader_parameter("shade_amt", .26)
	n.self_modulate = _env(g)
	for e in g.EN:
		if e.dead > 50:
			continue
		if e.x < g.cam - 200 or e.x > g.cam + g.W + 200:
			continue
		var eo := g.e_off(e)
		Spr.edist(e)
		Spr.eturn(e)
		_enemy_fx_under(g, e, eo)
		Spr.save()
		Spr.translate(eo.x, eo.y)
		var st0: int = e.get("startT", -99)
		var hop_u: float = (g.T - st0) / 18.0
		# pulinho de susto ao ver o Tomé (a poça da sanguessuga, a aranha no fio e o morcego
		# pendurado dormindo não pulam)
		var can_hop: bool = not e.k in ["leech", "spider", "plant", "mole"] and not (e.k == "bat" and e.get("st", 0) == 0)
		if hop_u >= 0 and hop_u < 1 and can_hop:
			Spr.translate(0, -sin(hop_u * PI) * 12)
		# inimigo: contorno vermelho pulsando (mais forte quando o Tomé está perto) — os bichos
		# do cenário nunca têm isso
		if not e.dead and not (e.k == "leech" and e.get("hid", true)) and not (e.k == "mole" and e.get("st", 0) in [0, 1]):
			var pp: Dictionary = g.player
			var dn: float = clamp(1.0 - Vector2(pp.x + pp.w / 2 - e.x, pp.y + pp.h / 2 - e.y).length() / 420.0, 0, 1)
			var pul: float = .5 + .5 * sin(T * .14 + e.x * .01)
			var oa: float = (.35 + .5 * dn) * (.55 + .45 * pul)
			Spr.glow(e.x, e.y - 14, 46 + 10 * dn, Color(1, .15, .08, .10 + .12 * dn * pul))
			Spr.sil_c = Color(1, .12, .06, oa)
			if not e.k in OUT_SHAPES:
				# o desenho do bicho roda uma vez só, gravando as silhuetas, e a gravação é repetida nos
				# 8 deslocamentos (antes o desenho inteiro, com toda a sua conta, rodava 8 vezes)
				Spr.rec = []
				_enemy(e)
				var rr: Array = Spr.rec
				Spr.rec = null
				for d in OUT8:
					Spr.replay(rr, d * 2.6)
			else:
				for d in OUT8:
					Spr.save()
					Spr.translate(d.x * 2.6, d.y * 2.6)
					_enemy(e)
					Spr.restore()
			Spr.sil_c = Color(0, 0, 0, 0)
		_enemy(e)
		if not e.dead:
			_enemy_eyes(e)
		# clarão branco logo que leva o golpe
		if e.dead > 0 and e.dead <= 5:
			Spr.sil_c = Color(1, 1, 1, .9 * (1.0 - (e.dead - 1) / 5.0))
			_enemy(e)
			Spr.sil_c = Color(0, 0, 0, 0)
		Spr.restore()
		if e.get("dizzyT", 0) > 0 and not e.dead:
			if FRESH:
				e.dizzyT -= 1
			if e.stun > 0:
				dizzy(e.x + eo.x, e.y + eo.y - 46, T)
		_enemy_fx_over(g, e, eo, hop_u)

## cor do ambiente: mais quente no fim da tarde, mais azulada na neve e à noite
func _env(g: Game) -> Color:
	var ws: Dictionary = g.section_weights()
	var env := Color(1, 1, 1)
	env = env.lerp(Color(1.03, .95, .86), ws.get("tarde", 0.0))
	env = env.lerp(Color(.94, .97, 1.04), ws.get("neve", 0.0))
	env = env.lerp(Color(.9, .94, 1.02), ws.get("noite", 0.0))
	env = env.lerp(Color(.92, .96, .94), ws.get("pantano", 0.0))
	return env

func _draw_player_node(n: CanvasItem) -> void:
	var g := game
	if g == null or not g.L:
		return
	Spr.begin(n)
	var __d__player := Time.get_ticks_usec()
	var p: Dictionary = g.player
	var mat: ShaderMaterial = n.material
	var dark: float = g.AMB.dark
	if g.L.has("under") and p.y > g.L.under:
		dark = 1.0
	var face: float = 1.0 if p.face > 0 else -1.0
	var lk: float = _light_k if int(p.get("turnT", 0)) > 0 else face
	if dark > .3:
		mat.set_shader_parameter("light_uv", Vector2(1.0, -.35).normalized())
		mat.set_shader_parameter("rim_col", Color(1, .78, .45))
		mat.set_shader_parameter("rim_amt", .4 * clamp((dark - .3) * 3.0, 0, 1))
	else:
		var tw: float = g.section_weights().get("tarde", 0.0)
		# a luz do sol vem de cima/trás; na meia-volta ela passa pelo meio do corpo (gira junto, sem pular de lado)
		mat.set_shader_parameter("light_uv", Vector2(-.7 * lk, -.75).normalized())
		mat.set_shader_parameter("rim_col", Color(1, .95, .8).lerp(Color(1, .74, .42), tw))
		mat.set_shader_parameter("rim_amt", .34)
	# na meia-volta o corpo fica de lado para a luz: sombra um pouco mais forte (volume)
	mat.set_shader_parameter("shade_amt", (.55 if p.swim else .32) + .14 * (1.0 - abs(lk)))
	var env := _env(g)
	# levou golpe: clarão branco curto (some em 10 quadros)
	var hf: int = int(p.get("hitFx", 0))
	if hf > 0:
		var u: float = hf / 10.0
		env = Color(env.r + 2.2 * u, env.g + 2.2 * u, env.b + 2.2 * u)
	n.self_modulate = env
	_player(g)
	_breath(g)
	Spr.pt("d__player", __d__player)

## nó da frente: o que passa por cima do Tomé
func _draw_front_node(n: CanvasItem) -> void:
	var g := game
	if g == null or not g.L:
		return
	Spr.begin(n)
	_front_decor_fade(g)
	WorldExtras.palisade_front(g)
	_ride_front(g)
	WorldVehicles.front(g, T)
	if g.VL:
		g.VL.draw_front(T)
	var __d_Traps_draw_front := Time.get_ticks_usec()
	WorldTraps.draw_front(g, T)
	Spr.pt("d_Traps_draw_front", __d_Traps_draw_front)
	var __d_Extras_grass := Time.get_ticks_usec()
	WorldExtras.grass(g, T)
	Spr.pt("d_Extras_grass", __d_Extras_grass)
	WorldTraps.draw_shadows(g, T)
	Polish.draw_front(g, T)
	for f in g.FXS:
		Spr.A(f.n, f.x, f.y, f.sc, false, 1.0 - float(f.t) / f.life)
	for p in g.PARTS:
		if p.has("k"):
			Polish.draw_part(p)
			continue
		var c: Color = p.col
		var pa: float = c.a * clamp(p.life / 24.0, 0, 1)
		if p.get("ember"):
			# brasa: brilho alaranjado, ziguezagueando e esfriando para vermelho
			var ex: float = p.x + sin(p.life * .5 + p.y * .1) * 3
			var ec := Color(1, .85, .4).lerp(Color(1, .35, .1), 1.0 - clamp(p.life / 28.0, 0, 1))
			Spr.glow(ex, p.y, 7, Color(ec.r, ec.g, ec.b, pa * .5))
			Spr.circle(ex, p.y, 1.6, Color(ec.r, ec.g, ec.b, pa))
		elif p.has("ring"):
			# onda de choque do mergulho: anel de poeira se abrindo rente ao chão
			var u: float = 1.0 - p.life / 18.0
			Spr.ci.draw_arc(Vector2(p.x, p.y), p.ring * u, PI, TAU, 28, Color(1, .93, .75, .6 * (1.0 - u)), 3, true)
			Spr.ellipse(p.x, p.y, p.ring * u, 4, Color(1, .95, .8, .18 * (1.0 - u)))
		else:
			Spr.rect(p.x, p.y, 3, 3, Color(c.r, c.g, c.b, pa))

## Y3 árvores da frente ficam translúcidas quando o Tomé passa por trás delas
func _front_decor_fade(g: Game) -> void:
	var p: Dictionary = g.player
	var pcx: float = p.x + p.w / 2
	for d in g.L.get("decor", []):
		if d.x < g.cam - 300 or d.x > g.cam + g.W + 300:
			continue
		if not WorldNature.is_front(g.L, d):
			continue
		var behind: bool = abs(d.x - pcx) < 80.0 and p.y + p.h > float(d.get("y", 0.0)) - 340.0 and p.y < float(d.get("y", 0.0)) + 20.0
		var fa: float = float(d.get("_fa", 1.0))
		if FRESH:
			fa = move_toward(fa, .45 if behind else 1.0, .06)
			d._fa = fa
		Spr.save()
		Spr.alpha *= fa
		WorldNature.decor(d)
		Spr.restore()

## Y9 o que dá para usar perto do Tomé brilha de leve no chão (fogueira apagada, manivela, toca, entrada)
func _hints(g: Game) -> void:
	var p: Dictionary = g.player
	var pc := Vector2(p.x + p.w / 2, p.y + p.h)
	var pts: Array = []
	if p.get("nearE") is Dictionary:
		var e: Dictionary = p.nearE
		pts.append(Vector2(e.x + e.w / 2, e.y + e.h))
	for c in g.CHK:
		if not c.on and abs(c.x - pc.x) < 150 and abs(c.y - pc.y) < 90:
			pts.append(Vector2(c.x, c.y))
	for c in g.CRANKS:
		if not c.done and abs(float(c.x) - pc.x) < 130 and abs(float(c.y) - pc.y) < 120:
			pts.append(Vector2(float(c.x), float(c.y)))
	if g.X and g.X.dog_free():
		for tc in g.X.TOCAS:
			if not tc.done and abs(float(tc.x) - pc.x) < 160 and abs(float(tc.y) - pc.y) < 90:
				pts.append(Vector2(float(tc.x), float(tc.y)))
	for q in pts:
		var s: float = .5 + .5 * sin(T * .12)
		Spr.glow(q.x, q.y - 8, 46, Color(1, .9, .55, .16 + .12 * s))
		Spr.ellipse(q.x, q.y - 1, 30 + 4 * s, 5, Color(1, .92, .6, .18 + .1 * s))
		if FRESH and T % 14 == 0:
			Polish.part("spark", q.x + randf_range(-22, 22), q.y - 4, 0, -randf_range(.4, .9), 34, Color(1, .9, .55), {"g": 0.0, "size": 1.2})

var _cat := {}   # juncos: (ângulo, velocidade) da mola de cada um

# ---------- cenário com estado ----------
var cabins: Array = []
var _bars: Array = []
var _bar_n := -1
var _bar_L = null
func _deco(g: Game) -> void:
	var cam := g.cam
	# fumaça da chaminé da cabana
	if cabins.is_empty() or cabins[0] != g.L:
		cabins = [g.L]
		for so in g.L.solids:
			if so.t == "cabin":
				cabins.append(so)
	for ci_ in range(1, cabins.size()):
		var cb: Dictionary = cabins[ci_]
		if cb.x > cam + g.W + 300 or cb.x + 400 < cam:
			continue
		var chx: float = cb.x - 15 + 167
		var chy: float = cb.y + cb.h - 221 + 6
		for i in 9:
			var age: float = fposmod(T * .5 + i * 22.0, 198.0)
			var u: float = age / 198.0
			var sx: float = chx + u * (46 + (g.AMB.get("wind", 0.0) + Polish.gust_k() * .6) * 110.0) + sin(u * 6.0 + i) * 7
			var sy: float = chy - u * 170
			var sa: float = .5 * (1.0 - u) * min(1.0, u * 6.0)
			Spr.circle(sx, sy, 6 + u * 24, Color(.86, .86, .88, sa))
	var k := 0
	var pp: Dictionary = g.player
	var ppx: float = pp.x + pp.w / 2
	for x in g.L.get("cattails", []):
		if x > cam - 80 and x < cam + g.W + 80:
			# os juncos se curvam quando o Tomé passa e balançam com o vento
			# Q10 mola: quem passa empurra, o junco passa do ponto ao voltar e assenta balançando
			var tgt: float = clamp(Polish.grass_push(x, 512.0, 50.0) * .05, -.45, .45) + sin(T * .03 + x) * .04 + g.AMB.get("wind", 0.0) * .12 + Polish.wind_wave(x) * .015
			var sp: Vector2 = _cat.get(x, Vector2.ZERO)
			if FRESH:
				sp.y += (tgt - sp.x) * .22
				sp.y *= .8
				sp.x += sp.y
				_cat[x] = sp
			var bend: float = sp.x
			Spr.save()
			Spr.translate(x, 512)
			Spr.rotate(bend)
			Spr.A("sw_cattail", 0, 0, .62 + (k % 3) * .1, k % 2 == 1)
			Spr.restore()
		k += 1
	# mina: trilhos (com pontes sobre os buracos), carrinho parado e porta
	var rx0: float = g.L.villain.x0 - 160 if g.L.has("villain") else 9380.0
	var rx1: float = g.L.spanX
	if g.L.has("rails"):
		rx0 = float(g.L.rails[0])
		rx1 = float(g.L.rails[1])
	if cam + g.W > rx0 and cam < rx1:
		var xa: float = max(rx0, floor((cam - 10) / 18) * 18)
		var xb: float = min(rx1, cam + g.W + 10)
		var x := xa
		# só os buracos que caem na tela (antes cada dormente olhava todos os buracos da fase)
		var vpits: Array = []
		for pit in g.L.get("pits", []):
			if pit[1] > xa and pit[0] < xb:
				vpits.append(pit)
		while x < xb:
			var over_pit := false
			for pit in vpits:
				if x > pit[0] and x < pit[1]:
					over_pit = true
			if over_pit:
				# cavalete de madeira pintada segurando o trilho sobre o buraco
				if int(x) % 72 < 18:
					Spr.PR("log", x - 2, 497, 10, 140, Color(.7, .62, .55))
					Spr.seg(x + 3, 520, x + 39, 590, Color("#3e2a18"), 4)
			else:
				# dormente de madeira com veio e prego
				Spr.rr(x - 1, 493, 14, 8, 2, Color("#4a3220"))
				Spr.rect(x, 494, 12, 2, Color("#6b4a2c"))
				Spr.circle(x + 6, 497, 1.2, Color(.6, .6, .62))
			x += 18
		# trilho de ferro: escuro embaixo, brilho em cima, emendas com chapas e rebites
		var ra: float = max(rx0, cam - 10)
		Spr.rect(ra, 491, xb - ra, 5, Color("#4c5058"))
		Spr.rect(ra, 491, xb - ra, 1.5, Color("#c9ced6"))
		# ferrugem: manchas alaranjadas presas ao trilho (sorteadas pela posição, não pela câmera)
		var rux: float = floor(ra / 53.0) * 53.0
		while rux < xb:
			if rux > ra and Polish.hh2(rux, 61) > .55:
				Spr.ellipse(rux + Polish.hh2(rux, 62) * 30, 494, 6 + Polish.hh2(rux, 63) * 10, 1.6, Color(.55, .27, .1, .5))
			rux += 53.0
		var jx: float = floor(ra / 144.0) * 144.0
		while jx < xb:
			if jx > ra:
				Spr.rr(jx - 5, 489, 10, 8, 2, Color("#5e626a"))
				Spr.circle(jx - 2, 493, 1, Color(.85, .85, .9))
				Spr.circle(jx + 2, 493, 1, Color(.85, .85, .9))
			jx += 144
		var gx: float = g.DOOR.x - 60
		if g.L.door.get("kind", "") == "vault":
			if gx > cam - 300 and gx < cam + g.W + 300:
				_vault(g.DOOR.x + 30, 500)
		elif g.L.door.get("kind", "") == "exit":
			# saída do túnel: o luar entrando por uma abertura na rocha
			var ex: float = g.DOOR.x
			if ex > cam - 300 and ex < cam + g.W + 300:
				Spr.rect(ex - 90, 120, 300, 382, Color("#2a1d14"))
				for st in 9:
					Spr.ellipse(ex - 90, 140 + st * 42, 16, 24, Color("#3a2a1c"))
					Spr.ellipse(ex + 210, 150 + st * 42, 16, 24, Color("#3a2a1c"))
				Spr.rr(ex - 10, 330, 120, 172, 50, Color("#1a2a44"))
				Spr.rr(ex, 342, 100, 160, 44, Color("#3a5a86"))
				Spr.circle(ex + 66, 380, 12, Color(.95, .95, .85))
				for st in 5:
					Spr.circle(ex + 14 + st * 19, 360 + (st * 37) % 50, 1.4, Color(1, 1, 1, .8))
				Spr.glow(ex + 50, 430, 120, Color(.6, .75, 1, .25))
		elif gx > cam - 300 and gx < cam + g.W + 300:
			Spr.A("mi_cart_full", gx - 70, 502, .8)
			if g.VIL and g.VIL.go and not g.VIL.gone:
				Spr.AB("mi_door_open", gx, 500 - 221, 230, 221)
			else:
				Spr.AB("mi_door_closed", gx + 11, 500 - 207, 210, 207)
	# portão da comporta e parede escura do túnel (lista guardada; refeita quando os sólidos mudam)
	if _bar_n != g.SOL.size() or not is_same(_bar_L, g.L):
		_bar_n = g.SOL.size()
		_bar_L = g.L
		_bars = []
		for s in g.SOL:
			if s.t == "barrier":
				_bars.append(s)
	for s in _bars:
		if s.x < g.cam + g.W + 80 and s.x + 30 > g.cam - 80:
			Spr.hgrad(s.x - 30, s.y - 20, 50, s.h + 20, Color(0, 0, 0, 0), Color(0, 0, 0, .95))

func _climb(g: Game) -> void:
	for z in g.CLIMB:
		if z.x + z.w < g.cam - 200 or z.x > g.cam + g.W + 200:
			continue
		if z.kind == "ladder":
			Spr.PV("ladder", z.x + z.w / 2 - 20, z.y - 4, 40, z.h + 4)
		elif z.kind == "net":
			Spr.strip_v("o_net", z.x - 3, z.y, z.w + 6, z.h)
		else:
			# corda trançada pintada, balançando de leve
			Spr.save()
			Spr.translate(sin(T * .04 + z.x) * 1.5, 0)
			Spr.PV("rope", z.x + z.w / 2 - 6, z.y, 12, z.h)
			Spr.restore()

func _locks(g: Game) -> void:
	for l in g.LOCKS:
		if float(l.x) + float(l.w) < g.cam - 300 or float(l.x) > g.cam + g.W + 300:
			continue   # fora da tela
		if l.kind == "hook":
			Spr.ellipse(l.ring[0] - 15, l.ring[1] + 41, 34, 6, Color(0, 0, 0, .28))
			Spr.P("rock_ring", l.ring[0] - 15, l.ring[1] + 43, 72)
			if l.done:
				Spr.A("it_gancho", l.ring[0], l.ring[1] + 4, .32)
		elif l.kind == "dam":
			# a comporta sobe enquanto o Tomé gira a manivela
			var lift: float = 0.0 if l.done else float(l.get("turn", 0.0)) * 70.0
			Spr.A("sw_gate_open" if l.done else "sw_gate", l.x + l.w + 25, 503 - lift, 1)
			if l.done or g.has_item(l.need) or float(l.get("turn", 0.0)) > 0.0:
				crank_post(l.x - 10, 500, float(l.get("turn", 0.0)) * TAU * 3.0 if not l.done else 0.0, T)
		if not l.done and g.player.nearL == l:
			var b := sin(T * .15) * 3
			var um: String = g.use_mode()
			var lbl: String = {"bag": "JUNTE NA MOCHILA", "check": "✔ USAR", "crank": "↻ GIRE A MANIVELA"}.get(um, "✦ USAR" if g.has_item(l.need) else "?")
			Spr.text(lbl, l.x + l.w / 2, l.y - 14 + b, 18, Color("#ffecaa"), HORIZONTAL_ALIGNMENT_CENTER, Spr.font_b, 4)
	# portas de manivela
	for c in g.CRANKS:
		if float(c.x) < g.cam - 200 or float(c.x) > g.cam + g.W + 200:
			continue
		crank_post(float(c.x), float(c.y), float(c.turn) * TAU * 3.0, T)

## poste com engrenagem e a manivela girando (ângulo a)
static func crank_post(x: float, gy: float, a: float, T: int) -> void:
	if Spr.has("p_crankpost") and Spr.has("p_crankarm"):
		# poste de madeira com a engrenagem (pintado) e a manivela girando em volta do eixo
		var rp: Array = Spr.AR["p_crankpost"]
		var k: float = 72.0 / rp[3]
		var pw: float = rp[2] * k
		var left: float = x - pw * .52
		var top: float = gy + 3 - rp[3] * k
		Spr.PR("crankpost", left, top, pw, rp[3] * k)
		# centro da engrenagem na pintura: (237, 275) de 455x696
		var hub := Vector2(left + 237.0 / 455.0 * pw, top + 275.0 / 696.0 * rp[3] * k)
		var ra: Array = Spr.AR["p_crankarm"]
		var ka: float = 62.0 / ra[2]
		Spr.save()
		Spr.translate(hub.x, hub.y)
		Spr.rotate(a)
		Spr.PR("crankarm", -37.0 / 620.0 * ra[2] * ka, -225.0 / 354.0 * ra[3] * ka, ra[2] * ka, ra[3] * ka)
		Spr.restore()
		return
	Spr.PR("stake", x - 6, gy - 70, 12, 72, Color(.85, .8, .75))
	var hub := Vector2(x, gy - 56)
	for k in 8:
		var aa: float = a * .5 + k * TAU / 8.0
		Spr.circle(hub.x + cos(aa) * 15, hub.y + sin(aa) * 15, 4, Color("#5e626a"))
	Spr.circle(hub.x, hub.y, 15, Color("#6e727a"))
	Spr.circle(hub.x, hub.y, 6, Color("#3a3c40"))
	var tip := hub + Vector2(cos(a), sin(a)) * 22
	Spr.seg(hub.x, hub.y, tip.x, tip.y, Color("#3a3c40"), 4)
	Spr.rr(tip.x - 3, tip.y - 10, 6, 12, 3, Color("#8a5e34"))



func _entrances(g: Game) -> void:
	var p: Dictionary = g.player
	for e in g.ENTR:
		if e.get("exit"):
			var cx: float = e.x + e.w / 2
			var top: float = e.y + e.h - 200
			var pts := PackedVector2Array([Vector2(cx - 18, top), Vector2(cx + 18, top), Vector2(cx + 46, e.y + e.h), Vector2(cx - 46, e.y + e.h)])
			Spr.ci.draw_polygon(pts, PackedColorArray([Color(1, .88, .59, .55), Color(1, .88, .59, .55), Color(1, .88, .59, .08), Color(1, .88, .59, .08)]))
			Spr.PV("ladder", cx - 20, top, 40, 200)
			Spr.text("⬆ SAIR", cx, e.y - 24 + sin(T * .15) * 4, 22, Color(1, .91, .66, .6 + sin(T * .12) * .35), HORIZONTAL_ALIGNMENT_CENTER, Spr.font_b, 4)
			continue
		var de: float = abs(p.x + p.w / 2 - (e.x + e.w / 2))
		if e.get("label", "") != "" and p.nearE != e and de < 320 and abs(p.y + p.h - (e.y + e.h)) < 80:
			Spr.text("⬇", e.x + e.w / 2, e.y - 62 + sin(T * .15) * 6, 34, Color(1, .93, .67, .55 + sin(T * .12) * .35), HORIZONTAL_ALIGNMENT_CENTER, Spr.font_b, 5)
		if p.nearE == e:
			Spr.text("↓", e.x + e.w / 2, e.y - 6 + sin(T * .15) * 3, 22, Color("#ffecaa"), HORIZONTAL_ALIGNMENT_CENTER, Spr.font_b, 4)

func _lily_mud(g: Game) -> void:
	# vitórias-régias sempre inteiras: afundam e inclinam com o peso do Tomé (mola em game._plat_dips),
	# descem para baixo da água turva quando afundam de vez e voltam boiando de lá
	for p in g.LILY:
		var cx: float = p.x + p.w / 2
		if cx < g.cam - 200 or cx > g.cam + g.W + 200:
			continue
		var by: float = p.y + 22 + float(p.get("dip", 0.0))
		var al := 1.0
		if p.st == 2:
			# lá no fundo, balançando devagar (a água por cima deixa só a sombra dela)
			by = p.y0 + 22 + 44 + sin(T * .04 + p.x) * 2
			al = .75
		elif p.st == 1:
			al = clamp(1.0 - (p.y - p.y0 - 14.0) / 20.0, .75, 1.0)
		var piv: float = float(p.get("piv", 0.0))
		Spr.save()
		Spr.translate(cx + piv, by - 6)
		Spr.rotate(float(p.get("tilt", 0.0)) + (sin(T * .03 + p.x) * .02 if p.st == 2 else 0.0))
		Spr.translate(-piv, 6)
		Spr.ABb("sw_lily", 0, 0, p.w + 16, al)
		Spr.restore()
	for m in g.MUD:
		Spr.strip_at("sw_mud", m.x, m.x, m.x + m.w, m.y - 8, 22)

func _vine(v: Dictionary) -> void:
	# cipó flexível: curva com o embalo (a ponta fica para trás) e enverga quando o Tomé agarra
	var p: Dictionary = game.player
	var held: bool = p.vine == v
	var r: float = p.vr if held else v.len
	var pts := PackedVector2Array()
	var dir := Vector2(sin(v.th), cos(v.th))
	var nrm := Vector2(dir.y, -dir.x)
	var bow: float = -v.om * r * 1.4 + v.get("bend", 0.0) * 7.0 * sin(T * .45)
	var N := 14
	for i in N + 1:
		var u := i / float(N)
		var q: Vector2 = Vector2(v.x, v.y) + dir * r * u + nrm * bow * sin(u * PI) * (1.0 if held else u)
		pts.push_back(q)
	# pedaço que sobra abaixo das mãos fica balançando solto
	if held and v.len - r > 6:
		var end: Vector2 = pts[N]
		var a2: float = v.th * .55 - v.om * 5.0
		var d2 := Vector2(sin(a2), cos(a2))
		for i in range(1, 7):
			var u2 := i / 6.0
			pts.push_back(end + d2 * (v.len - r) * u2 + Vector2(sin(T * .07 + u2 * 3) * 2 * u2, 0))
	# cipó pintado (folhas e nós da arte) seguindo a curva: um pedaço da textura em cada trecho
	var r_ = Spr.AR.get("p_vine")
	if r_ != null:
		var tex: Texture2D = Spr.atlas_tex(r_)
		var vw: float = 16.0
		var th: float = vw * r_[3] / r_[2]
		var acc := 0.0
		for i in range(1, pts.size()):
			var a: Vector2 = pts[i - 1]
			var b: Vector2 = pts[i]
			var L2: float = a.distance_to(b)
			if L2 < .5:
				continue
			var v0: float = fmod(acc, th) / th
			var v1: float = v0 + L2 / th
			Spr.save()
			Spr.translate(a.x, a.y)
			Spr.rotate(atan2(b.y - a.y, b.x - a.x) - PI / 2)
			var sy0: float = r_[1] + r_[3] * v0
			var sh_: float = r_[3] * min(1.0 - v0, v1 - v0)
			Spr.ci.draw_texture_rect_region(tex, Rect2(-vw / 2, 0, vw, L2 + .8), Rect2(r_[0], sy0, r_[2], max(1.0, sh_)), Color(1, 1, 1, Spr.alpha))
			Spr.restore()
			acc += L2
	# o cipó continua subindo até as copas (não fica pendurado no nada)
	Spr.PV("vine", v.x - 8, v.y - 520, 16, 522)

func _glow_mush(x: float, y: float, t: int) -> void:
	Spr.glow(x, y - 34, 70, Color(.47, .78, 1, .35))
	Spr.A("mu_1" if t > 5 else ("mu_2" if t > 0 else "mu_0"), x, y + 2, 1)

func _campfire(c: Dictionary) -> void:
	if c.has("rest"):
		# fogueira grande: troncos de assento dos dois lados e fogo alto, sempre acesa (chama o Tomé)
		Spr.glow(c.x, c.y - 30, 110 + sin(T * .2) * 6, Color(1, .7, .3, .4))
		for lx in c.get("seats", []):
			var sx: float = sign(lx - c.x)
			Spr.ellipse(lx, c.y + 1, 40, 5, Color(0, 0, 0, .3))
			Spr.rr(lx - 36, c.y - 15, 72, 16, 8, Color("#3a2414"))
			Spr.rr(lx - 34, c.y - 14, 68, 13, 7, Color("#8a5a32"))
			Spr.seg(lx - 24, c.y - 9, lx + 14, c.y - 9, Color("#5a3820"), 2)
			Spr.ellipse(lx + sx * 32, c.y - 7, 5, 7, Color("#d8b07a"))
			Spr.ring(lx + sx * 32, c.y - 7, 3, Color("#8a5a32"), 1.5)
		if FRESH and T % 3 == 0:
			game.PARTS.append({"x": c.x + (randf() - .5) * 24, "y": c.y - 40, "vx": (randf() - .5) * .8, "vy": -1.8, "life": 28, "col": Color("#ffcf6a"), "ember": true})
		_flame(c.x, c.y + 4, 1.25)
		if not game.RESTED.has(c.rest) and (T / 20) % 2 == 0:
			Spr.text("▼", c.x, c.y - 100 + sin(T * .1) * 4, 20, Color("#ffe0a0"), HORIZONTAL_ALIGNMENT_CENTER, Spr.font_b, 4)
		return
	if c.on:
		Spr.glow(c.x, c.y - 20, 60, Color(1, .75, .35, .35))
		if FRESH and T % 5 == 0:
			game.PARTS.append({"x": c.x + (randf() - .5) * 14, "y": c.y - 26, "vx": (randf() - .5) * .6, "vy": -1.4, "life": 22, "col": Color("#ffcf6a"), "ember": true})
	if c.on:
		_flame(c.x, c.y + 4, .8)
	else:
		Spr.A("o_fire_off", c.x, c.y + 4, .8)
	# R3 fogueira onde o Tomé volta: bandeirinha tremulando ao lado
	if game.cur_chk >= 0 and game.cur_chk < game.CHK.size() and game.CHK[game.cur_chk] == c:
		_pennant(c.x + 34, c.y)

## J7/O8 chama viva: tremula, estica e deita com o vento
func _flame(x: float, y: float, sc: float) -> void:
	var w: float = float(game.AMB.get("wind", 0.0)) + Polish.gust_k() * .6
	Spr.save()
	Spr.translate(x, y)
	Spr.rotate(w * .14 + sin(T * .23) * .035 + sin(T * .61) * .02)
	Spr.scale(1.0 + sin(T * .47) * .035, 1.0 + sin(T * .31 + 1.3) * .055 + sin(T * .9) * .02)
	Spr.A("o_fire_on", 0, 0, sc)
	Spr.restore()

## bandeirinha do ponto de volta
func _pennant(x: float, gy: float) -> void:
	var top: float = gy - 54
	Spr.seg(x, gy, x, top, Color("#5a3820"), 2.5)
	var w: float = float(game.AMB.get("wind", 0.0)) * .6 + .4
	var pts := PackedVector2Array()
	for i in 6:
		var u: float = i / 5.0
		pts.append(Vector2(x + u * 22, top + 2 + sin(T * .18 - u * 3.0) * 2.5 * w * u))
	for i in range(5, -1, -1):
		var u: float = i / 5.0
		pts.append(Vector2(x + u * 22, top + 12 - u * 5 + sin(T * .18 - u * 3.0) * 2.5 * w * u))
	Spr.poly(pts, Color("#d8463a"))
	Spr.circle(x, top, 2.5, Color("#f0cd72"))

func _crate(c: Dictionary) -> void:
	var o := (randf() - .5) * 4 if c.shake else 0.0
	var it: String = c.get("item", "coin")
	var w: float = c.w + 6
	Spr.ellipse(c.x + c.w / 2, c.y + c.h + 1, w * .5, 4, Color(0, 0, 0, .25))
	if it == "heart":
		# coração entalhado brilhando de leve
		Spr.glow(c.x + c.w / 2 + o, c.y + c.h / 2, c.w * .7, Color(1, .4, .4, .12 + .06 * sin(T * .08)))
		Spr.PR("crate_heart", c.x - 3 + o, c.y - 3, w, c.h + 6)
	else:
		Spr.PR("crate", c.x - 3 + o, c.y - 3, w, c.h + 6, Color(.86, .92, 1.08) if it == "armor" else Color.WHITE)
		if it == "armor":
			Spr.circle(c.x + c.w / 2 + o, c.y + c.h / 2, 7, Color(.25, .3, .4, .8))
			Spr.circle(c.x + c.w / 2 + o, c.y + c.h / 2, 5, Color(.65, .8, 1, .9))
	if c.get("item") == "heart" and game.player.hp >= Game.MAXHP:
		Spr.rect(c.x, c.y, c.w, c.h, Color(0, 0, 0, .25))

# ---------- inimigos ----------
const NO_SHADOW := {"spider": 1, "leech": 1, "plant": 1, "piranha": 1, "mole": 1}
## sombra no chão e o "susto" quando vê o Tomé chegando
func _enemy_fx_under(g: Game, e: Dictionary, eo: Vector2) -> void:
	if e.dead:
		return
	if not Game.FLY.has(e.k) and not NO_SHADOW.has(e.k):
		Spr.ellipse(e.x + eo.x, e.y + 3, 24, 4.5, Polish.shadow_col(.24))
	elif e.k in ["crow", "bat", "owl", "fly"]:
		Polish.flyer_shadow(e, eo.x)
	if not e.has("seen"):
		var p: Dictionary = g.player
		if abs(p.x + p.w / 2 - e.x) < 300 and abs(p.y + p.h - e.y) < 180:
			e.seen = true
			e.startT = g.T

## bichos desenhados (em parte) com formas em vez de peças: o contorno deles continua do jeito antigo
const OUT_SHAPES := {"spider": 1, "mole": 1, "plant": 1}
const OUT8 := [Vector2(1, 0), Vector2(-1, 0), Vector2(0, 1), Vector2(0, -1), Vector2(.7, .7), Vector2(-.7, .7), Vector2(.7, -.7), Vector2(-.7, -.7)]
## estados em que o bicho começa um ataque (aparece o "!" vermelho antes)
const ATK := {"crow": [5], "squirrel": [1], "spider": [1], "bat": [1], "owl": [1], "mole": [2]}
## nomes para a dica do primeiro encontro
const EN_NAME := {"crow": "Corvo", "bat": "Morcego", "fly": "Mosca", "spider": "Aranha", "squirrel": "Esquilo bravo",
	"frog": "Sapo", "piranha": "Piranha", "leech": "Sanguessuga", "boar": "Javali", "owl": "Coruja brava", "mole": "Toupeira"}
## olhos vermelhos brilhando (posição na arte de cada bicho, olhando para a direita)
const EYES := {"crow": [Vector2(17, -13)], "squirrel": [Vector2(28, -25)], "bat": [Vector2(8, 5), Vector2(13, 5)],
	"spider": [Vector2(2, 3), Vector2(7, 3)], "fly": [Vector2(13, 2)], "frog": [Vector2(-5, -38), Vector2(6, -38)], "boar": [Vector2(18, -30)],
	"piranha": [Vector2(13, -8)]}

func _enemy_eyes(e: Dictionary) -> void:
	var ey: Array = EYES.get(e.k, [])
	if ey.is_empty() or (e.k == "bat" and e.get("st", 0) == 0):
		return
	if e.k == "frog":
		# os olhos acompanham a pose pintada (agachado e no salto a cabeça vai para a frente)
		var jt: int = int(e.get("jt", 0)) % 130
		if e.get("leap"):
			ey = [Vector2(14, -34), Vector2(22, -34)]
		elif jt >= 86 and jt < 100:
			ey = [Vector2(10, -30), Vector2(20, -30)]
	elif e.k == "squirrel" and e.get("st", 0) == 2:
		# no bote ele se ergue: a cabeça fica bem mais alta
		ey = [Vector2(16, -42)]
	elif e.k == "spider" and e.get("st", 0) != 2:
		# pendurada de cabeça para baixo: os olhos ficam embaixo
		ey = [Vector2(-4, 22), Vector2(2, 22)]
	var f: float = 1.0 if e.dir > 0 else -1.0
	var b: float = .75 + .25 * sin(T * .2 + e.x)
	var oy: float = e.get("eyeY", 0.0)
	# antes do bote os olhos acendem forte (aviso)
	var wk: float = clamp(float(e.get("warnT", 0)) / 14.0, 0, 1)
	if e.get("wind", 0) > 0:
		wk = 1.0
	for v in ey:
		var x: float = e.x + v.x * f
		var y: float = e.y + v.y + oy
		if wk > 0:
			Spr.glow(x, y, 9 + 16 * wk, Color(1, .15, .05, .6 * wk))
		Spr.glow(x, y, 9, Color(1, .1, .05, .55 * b))
		Spr.circle(x, y, 2.4, Color(1, .2, .1, b))
		Spr.circle(x - .6, y - .6, .9, Color(1, .9, .8, b))

## "!" vermelho (viu o Tomé / vai atacar) e estrelinhas girando quando está tonto
func _enemy_fx_over(g: Game, e: Dictionary, eo: Vector2, hop_u: float) -> void:
	if e.dead:
		return
	var hx: float = e.x + eo.x
	var hy: float = e.y + eo.y - (34 if not Game.FLY.has(e.k) else 30)
	# primeiro encontro com cada tipo de inimigo: dica curta dizendo que ele é perigoso
	if e.get("seen") and not g.en_seen.has(e.k) and EN_NAME.has(e.k):
		g.en_seen[e.k] = true
		g.flash("%s: inimigo (olhos e contorno vermelhos). Pule na cabeça ou use a picareta." % EN_NAME[e.k], 170)
	var s: int = e.get("st", 0)
	if s != e.get("pst", 0) and ATK.get(e.k, []).has(s):
		e.warnT = 34
	e.pst = s
	if e.get("charge") and not e.get("pch"):
		e.warnT = 34
	if e.k == "boar" and e.get("wind", 0) == 15:
		Polish.snort(e.x + e.dir * 34, e.y - 22, e.dir)
	e.pch = e.get("charge", false)
	if e.k == "frog":
		var jt: int = int(e.get("jt", 0)) % 130
		var pp: Dictionary = g.player
		if jt >= 74 and jt < 100 and abs(pp.x - e.x) < 320:
			e.warnT = max(e.get("warnT", 0), 2)
	if e.k == "squirrel" and s == 1 and int(e.get("t", 0)) < 22:
		# esquilo leva um susto antes do bote
		var qa: float = clamp(1.0 - e.t / 22.0, 0, 1)
		Spr.text("?", hx + 10, hy - 30, 22, Color(1, .95, .7, qa), HORIZONTAL_ALIGNMENT_CENTER, Spr.font_b, 4)
	var wt: int = e.get("warnT", 0)
	if wt > 0:
		if FRESH:
			e.warnT = wt - 1
		var k: float = min(1.0, wt / 8.0)
		var sc: float = 1.0 + .25 * sin(wt * .5)
		Spr.text("!", hx, hy - 24, int(28 * sc), Color(1, .2, .12, k), HORIZONTAL_ALIGNMENT_CENTER, Spr.font_b, 5, Color(.25, 0, 0, k * .9))
	elif hop_u >= 0 and hop_u < 1.6:
		var a: float = clamp(1.6 - hop_u, 0, 1)
		Spr.text("!", hx, hy - 22 - sin(min(hop_u, 1.0) * PI) * 12, 26, Color(1, .25, .15, a), HORIZONTAL_ALIGNMENT_CENTER, Spr.font_b, 5, Color(.25, 0, 0, a * .9))
	if e.get("stun", 0) > 0:
		dizzy(hx, hy - 8, T)

## estrelinhas de tontura girando em volta da cabeça (inimigos e chefes)
static func dizzy(x: float, y: float, t: int) -> void:
	for i in 3:
		var a: float = t * .12 + TAU * i / 3.0
		var sx: float = x + cos(a) * 20
		var sy: float = y + sin(a) * 6
		var s: float = 4.5 + sin(a) * 1.2
		var pts := PackedVector2Array()
		for k in 10:
			var r: float = s if k % 2 == 0 else s * .45
			var aa: float = -PI / 2 + TAU * k / 10.0 + t * .05
			pts.push_back(Vector2(sx + cos(aa) * r, sy + sin(aa) * r))
		Spr.poly(pts, Color(1, .9, .3, .95))
## corpo vivo dos bichos (como nos filmes 3D): inclina na direção em que acelera, respira parado,
## achata antes do bote do javali e se inclina nas curvas de quem voa
func _enemy_body(e: Dictionary, dist: float) -> void:
	var fly: bool = Game.FLY.has(e.k) or e.k in ["crow", "bat", "owl", "piranha"]
	# estado só avança uma vez por quadro (o contorno chama este desenho 8 vezes)
	var fpf := Engine.get_process_frames()
	if int(e.get("_bodyf", -1)) != fpf:
		e._bodyf = fpf
		e._bvx = e.x - float(e.get("_pbx", e.x))
		e._pbx = e.x
		var tl: float = clamp(float(e._bvx) * (.05 if fly else .035), -.12, .12)
		e._ln = lerp(float(e.get("_ln", 0.0)), tl, .12)
	var vx: float = e.get("_bvx", 0.0)
	var w: int = int(e.get("wind", 0))
	if w > 0:
		# antecipação do bote: abaixa e joga o peso para trás
		var u: float = sin((16 - w) / 16.0 * PI)
		Spr.rotate(-e.dir * .1 * u)
		Spr.scale(1.0 + .07 * u, 1.0 - .1 * u)
		return
	Spr.rotate(e._ln)
	var lt: int = int(e.get("landT", 0)) if e.k != "frog" else 0
	if lt > 0:
		Spr.scale(1.0 + .16 * lt / 10.0, 1.0 - .2 * lt / 10.0)
	elif e.get("leap") and e.k != "frog":
		Spr.scale(.94, 1.07)
	if abs(vx) < .2 and not fly:
		Spr.scale(1.0 - sin(T * .08 + e.x) * .008, 1.0 + sin(T * .08 + e.x) * .016)

func _enemy(e: Dictionary) -> void:
	Spr.save()
	if e.dead:
		Spr.alpha = clamp(1 - (e.dead - 24) / 14.0, 0, 1) if e.dk == "flat" else clamp(1 - (e.dead - 34) / 16.0, 0, 1)
	var dist: float = e.get("_dd", 0.0)
	var fs: float = e.get("_fs", 1.0 if e.dir > 0 else -1.0)
	Spr.translate(e.x, e.y)
	if not e.dead:
		_enemy_body(e, dist)
	if e.dead:
		Spr.scale(1.0 if e.dir > 0 else -1.0, 1)
	else:
		# virada com peso: espelha de uma vez, agachando e se recompondo (sem "folha de papel")
		var tw: float = 1.0 + (1.0 - Spr.tsy(e)) * .6
		Spr.scale(sign(fs) * tw, Spr.tsy(e))
		if Spr.turned_now(e) and not e.get("_tdust", false) and not Game.FLY.has(e.k) and not e.k in ["crow", "bat", "owl", "piranha", "spider", "leech", "plant", "mole"]:
			e._tdust = true
			WorldExtras.turn_dust(game, e.x, e.get("base", e.y), e.dir, game._dust_col())
		elif not Spr.turned_now(e):
			e._tdust = false
	if e.dead:
		if e.dk == "flat":
			# achatado com quique: passa do ponto e volta (borracha)
			var q: float = min(1, e.dead / 4.0)
			var wob: float = sin(e.dead * .9) * .09 * (1.0 - min(1.0, e.dead / 18.0)) if e.dead > 4 else 0.0
			Spr.scale(1 + .3 * q - wob, 1 - .62 * q + wob)
		else:
			Spr.translate(float(e.get("ddx", 0.0)), e.ddy)
			var m := 0.0 if Game.FLY.has(e.k) else -15.0
			Spr.translate(0, m)
			Spr.rotate(e.dead * .25 * (1.0 if float(e.get("dvx", 1.0)) >= 0 else -1.0))
			Spr.translate(0, -m)
	elif not Game.FLY.has(e.k) and not e.k in ["spider", "mole", "frog", "plant", "leech"]:
		# sobe-e-desce do passo, só quando anda (parado fica no chão, respirando);
		# no quadro de apoio o corpo achata um tiquinho e estica no impulso
		var ph: float = sin(dist * .14)
		Spr.translate(0, -abs(ph) * 1.6)
		Spr.scale(1.0 - abs(ph) * .015, 1.0 + (abs(ph) - .5) * .03)
	match e.k:
		"frog":
			var jt0: int = int(e.get("jt", 0)) % 130
			var pp0: Dictionary = game.player
			if e.dead and Spr.opt("frog_ko"):
				var fk: Texture2D = Spr.opt("frog_ko")
				Spr.save()
				Spr.scale(.82, .82)
				Spr.trect(fk, Rect2(-fk.get_width() * .5, -fk.get_height() + 4, fk.get_width(), fk.get_height()))
				Spr.restore()
			elif e.dead:
				Spr.A("en_frog_dead", 0, 3, .9)
			elif not e.leap and jt0 >= 74 and jt0 < 86 and abs(pp0.x - e.x) < 320 and Spr.opt("frog_tongue"):
				# ameaça: estica a língua antes do pulo
				var ft: Texture2D = Spr.opt("frog_tongue")
				Spr.save()
				Spr.scale(.82, .82)
				Spr.trect(ft, Rect2(-ft.get_width() * .22, -ft.get_height() + 4, ft.get_width(), ft.get_height()))
				Spr.restore()
			elif Spr.tex.has("en_frog2"):
				# respira (papo inflando), pisca de vez em quando, agacha antes do pulo e estica no ar
				var jt: int = int(e.get("jt", 0)) % 130
				var ff: int = (T / 22) % 2
				if (T + int(e.x)) % 150 < 7:
					ff = 2
				if jt >= 86 and jt < 100:
					ff = 3
				if e.leap:
					ff = 4
				# estica no salto (subindo), achata ao cair no chão, papo respira parado
				var fsq := 1.0
				var lt: int = jt - 100
				if e.leap:
					fsq = 1.0 + .12 * cos(clamp(lt / 30.0, 0, 1) * PI)
				elif jt < 8:
					fsq = 1.0 - .18 * (1.0 - jt / 8.0)
				elif jt >= 86:
					fsq = 1.0 - .1 * sin(clamp((jt - 86) / 14.0, 0, 1) * PI * .5)
				else:
					fsq = 1.0 + sin(T * .09 + e.x) * .015
				Spr.scale(1.0 / sqrt(fsq), fsq)
				if ff <= 1:
					Spr.frame_seq(Spr.tex.en_frog2, [0, 1], T / 22.0, 130, 70, 65, 68, 0, 3, .82)
				else:
					Spr.frame(Spr.tex.en_frog2, ff, 130, 70, 65, 68, 0, 3, .82)
			else:
				Spr.A("en_frog_jump" if e.leap else "en_frog", 0, 3, .9 if e.leap else .82 + sin(T * .12) * .02)
		"fly":
			Spr.P_cycle("fly", ["fly0", "fly1"], T / 2.0, 0, 0, 40, false, Color.WHITE, true)
		"owl":
			if e.dead:
				Spr.A("en_owl_dead", 0, 22, .9)
			elif e.get("st", 0) == 0:
				Spr.A("en_owl", 0, 24, .9)
			elif e.st == 1:
				Spr.A("en_owl_dive" if e.t < 34 else "en_owl_atk", 0, 0, .95)
			else:
				Spr.A_cycle("en_owl", ["en_owl1", "en_owl2"], T / 7.0 + 1.0, 0, 0, .95)
		"bat":
			WorldExtras.bat(e, T)
		"spider":
			WorldExtras.spider(e, T)
		"mole":
			WorldExtras.mole(e, T)
		"plant":
			WorldTraps.plant(e, T)
		"squirrel":
			WorldNature.squirrel(e, T)
		"crow":
			WorldNature.crow(e, T)
		"piranha":
			WorldNature.piranha(e, T)
		"leech":
			Spr.A("en_puddle", 0, 6, .9)
			if e.dead:
				WorldExtras._pc("leech0", 0, 2, 36)
			else:
				# sai da poça se esticando (o corpo cresce para cima a partir da água), balança
				# procurando o Tomé e volta a se enfiar na poça. A área de perigo acompanha (Game.leech_up)
				var t: int = int(e.get("lt", 0)) % 200
				var lu: float = Game.leech_up(t)
				if lu > 0.0:
					var lw: float = 34.0
					var lh: float = Spr.PH("leech1", lw)
					var ww: float = lw * (1.25 - .25 * lu)
					Spr.save()
					Spr.translate(0, 4)
					Spr.rotate(sin(T * .09 + e.x) * .09 * lu)
					Spr.PR("leech1", -ww / 2, -lh * lu, ww, lh * lu)
					Spr.restore()
		_:
			# javali
			var fr: int
			if e.dead or e.stun:
				fr = 6
			elif e.get("charge"):
				fr = 5
			else:
				fr = [0, 1, 2, 3][(T / 8) % 4]
			var bov: Texture2D = null
			if (e.dead or e.stun) and Spr.opt("boar_ko"):
				bov = Spr.opt("boar_ko")
			elif not e.dead and e.get("wind", 0) > 0 and not e.get("charge") and Spr.opt("boar_wind"):
				bov = Spr.opt("boar_wind")
			if bov != null:
				# poses pintadas: antecipação (raspando a pata) e tonto
				Spr.save()
				Spr.scale(.46, .46)
				Spr.trect(bov, Rect2(-bov.get_width() * .5, -bov.get_height() + 6, bov.get_width(), bov.get_height()))
				Spr.restore()
			elif fr == 5 and Spr.tex.has("en_boar"):
				# investindo: galope (as pernas correm de verdade, passada mais longa) e cabeça baixa
				Spr.save()
				Spr.translate(0, -abs(sin(dist * .2)) * 2.5)
				Spr.rotate(.06)
				Spr.frame_mix(Spr.tex.en_boar, dist / 5.0, 6, 0, 210, 140, 105, 136, 0, 3, .46)
				Spr.restore()
			elif fr < 4 and Spr.tex.has("en_boar"):
				# andando: 6 quadros novos, pernas alternando, com transição entre um quadro e outro
				Spr.frame_mix(Spr.tex.en_boar, dist / 6.6, 6, 0, 210, 140, 105, 136, 0, 3, .46)
			else:
				Spr.frame(Spr.tex.javali, fr, 210, 140, 105, 136, 0, 3, .46)
	Spr.restore()

# ---------- cavalo e trilha da cavalgada ----------
const RS := .58   # escala das folhas da cavalgada (quadros 260x250, chão em 244)

func _ride_world(g: Game) -> void:
	var RD: Ride = g.RD
	if RD == null or RD.H.is_empty():
		return
	var x0: float = g.cam - 160
	var x1: float = g.cam + g.W + 160
	# longe da trilha da cavalgada: nem olha os obstáculos (o cavalo continua sendo desenhado abaixo)
	var near_trail: bool = x1 > float(RD.H.get("ride0", -1e9)) - 200.0 and x0 < float(RD.H.get("ride1", 1e9)) + 400.0
	for o in (RD.OBS if near_trail else []):
		if o.x > x1 or o.x + 400 < x0:
			continue
		# marca de cascos na neve: o melhor ponto para saltar
		var cx: float = Ride.obs_center(o)
		if cx > 0 and not o.hit and (RD.riding or RD.H.st == "trapped"):
			var tx: float = RD.takeoff_x(o)
			var pa: float = .45 + .25 * sin(T * .12 + o.x)
			Spr.glow(tx, 497, 22, Color(.75, .9, 1, .25 * pa))
			for k in 2:
				var hxk: float = tx - 7 + k * 14
				Spr.ellipse(hxk, 498, 5, 2.5, Color(.35, .45, .6, .55 + pa * .3))
				Spr.ring(hxk, 497.5, 4, Color(.3, .38, .5, .6), 1.2, PI, TAU)
		match o.k:
			"log":
				# tora pintada com neve em cima (sombra azulada no chão)
				Spr.ellipse(o.x + 32, 501, 34, 4, Color(.25, .32, .5, .25))
				WorldNature.prop("tora_neve", o.x + 32, 503, 36)
			"logs":
				# pilha de toras amarradas: duas embaixo, uma em cima
				Spr.ellipse(o.x + 50, 501, 54, 5, Color(.25, .32, .5, .25))
				WorldNature.prop("tora_neve", o.x + 28, 503, 30)
				WorldNature.prop("tora_neve", o.x + 74, 503, 30, true)
				WorldNature.prop("tora_neve", o.x + 50, 478, 26)
				Spr.seg(o.x + 50, 466, o.x + 50, 501, Color("#6b4a2a"), 3)
				Spr.seg(o.x + 51, 466, o.x + 51, 501, Color("#c9a26a"), 1.2)
			"rock":
				Spr.ellipse(o.x + 30, 501, 30, 4, Color(.25, .32, .5, .25))
				WorldNature.prop("pedra_neve", o.x + 30, 504, 48)
			"leap":
				_leap(o, T)
			"fence":
				# cerquinha de madeira: dois mourões e duas travessas, neve em cima
				for px2 in [o.x + 14.0, o.x + 46.0]:
					Spr.PR("stake", px2 - 6, 456, 12, 46, Color(.85, .8, .75))
				WorldVehicles._hlog(o.x + 4, o.x + 58, 466, 8)
				WorldVehicles._hlog(o.x + 4, o.x + 58, 482, 8)
				Spr.ellipse(o.x + 14, 457, 7, 3, Color(.97, .98, 1))
				Spr.ellipse(o.x + 46, 457, 7, 3, Color(.97, .98, 1))
			"gap":
				# riacho gelado: água escura correndo, placas de gelo e margens de neve com pedras
				var gw: float = o.w
				if Spr.has("p_riacho"):
					# riacho pintado: a água (36% do meio da pintura) cobre o vão
					var rk: float = (gw + 24.0) / 421.0
					var aw: float = 680.0 * rk
					var ah: float = 290.0 * rk
					var rcx: float = o.x + gw / 2.0
					Spr.PR("riacho", rcx - aw * .511, 499.0 - 40.0 * rk, aw, ah)
					# brilhos da correnteza
					for k in 3:
						var wx: float = o.x + 8 + fposmod(T * 1.2 + k * 37.0, gw - 16)
						Spr.seg(wx, 516 + k * 6, wx + 8, 516 + k * 6, Color(.8, .92, 1, .5), 1.5)
					continue
				Spr.vgrad(o.x, 470, gw, 30, Color("#5f9cc4"), Color("#24506e"))
				Spr.vgrad(o.x, 500, gw, 160, Color("#163a52"), Color("#04090f"))
				Spr.rect(o.x, 470, gw, 3, Color(.85, .95, 1, .8))
				for k in 4:
					var wx: float = o.x + fposmod(T * 1.4 + k * 31.0, gw - 20) + 4
					Spr.line(PackedVector2Array([Vector2(wx, 482 + k * 5), Vector2(wx + 7, 480 + k * 5), Vector2(wx + 14, 482 + k * 5)]), Color(.6, .8, .95, .5), 1.5)
				for k in 2:
					var fx: float = o.x + 18 + k * (gw - 56)
					var bob: float = sin(T * .08 + k * 2.0) * 1.5
					Spr.poly(PackedVector2Array([Vector2(fx, 476 + bob), Vector2(fx + 22, 473 + bob), Vector2(fx + 28, 479 + bob), Vector2(fx + 4, 482 + bob)]), Color(.85, .94, 1, .95))
				for sd in [0, 1]:
					var ex: float = o.x if sd == 0 else o.x + gw
					var dr: float = 1.0 if sd == 0 else -1.0
					Spr.poly(PackedVector2Array([Vector2(ex - dr * 14, 466), Vector2(ex + dr * 10, 468), Vector2(ex + dr * 6, 482), Vector2(ex - dr * 14, 488)]), Color(.8, .92, 1))
					Spr.P("peb%d" % sd, ex + dr * 4, 492, 18, sd == 1, 0.0, Color(.8, .85, .95))
					Spr.ellipse(ex, 465, 18, 6, Color(.97, .98, 1))
			"branch":
				# árvore com neve do lado de lá e o toco com o galho baixo (atrás do cavalo); a parte do
				# galho que atravessa a trilha é desenhada de novo por cima do cavaleiro, em _ride_front
				WorldNature.prop("arvore_neve", o.x + 130, 504, 300)
				WorldNature.prop("galho_neve", o.x + 73, 504, 130, true)
			"rope":
				_ride_rope(o, T)
	if near_trail:
		_ride_marks(g, RD, x0, x1)
	var H: Dictionary = RD.H
	if RD.riding:
		return
	# cavalo longe da tela (preso lá na neve, ou indo embora): não desenha
	var hxv: float = float(H.hx) if H.st == "gone" else float(H.x)
	if hxv < x0 - 200 or hxv > x1 + 200:
		return
	var ft := Spr.opt("horse_free")
	match H.st:
		"trapped", "free":
			var fr := 1
			if H.st == "trapped":
				# preso: fica de cabeça baixa e de vez em quando empina puxando o arame
				fr = 0 if (T % 220) < 50 else 1
				Spr.text("!", H.x - 20, H.y - 150 + sin(T * .2) * 3, 26, Color("#ffecaa"), HORIZONTAL_ALIGNMENT_CENTER, Spr.font_b, 4)
			else:
				fr = 0 if (H.t > 90 and H.t < 130) else 2
			Spr.ellipse(H.x, H.y + 2, 60, 7, Color(0, 0, 0, .22))
			if ft:
				Spr.frame(ft, fr, 260, 250, 130, 244, H.x, H.y + 3, RS, true)
		"gone":
			Spr.ellipse(H.hx, 502, 60, 7, Color(0, 0, 0, .22))
			if ft:
				Spr.frame(ft, 3, 260, 250, 130, 244, H.hx, 503, RS, true)

## corda esticada entre dois mourões, com bandeirinhas de pano balançando no vento do galope
func _ride_rope(o: Dictionary, T: int) -> void:
	for px3 in [o.x - 4.0, o.x + 88.0]:
		Spr.ellipse(px3, 501, 12, 3, Color(.25, .32, .5, .25))
		Spr.PR("stake", px3 - 7, 362, 14, 142, Color(.85, .8, .75))
		Spr.ellipse(px3, 363, 8, 3, Color(.97, .98, 1))
	var rope := PackedVector2Array()
	for k in 9:
		var u: float = k / 8.0
		rope.push_back(Vector2(lerpf(o.x - 4, o.x + 88, u), 381 + sin(u * PI) * 7))
	Spr.line(rope, Color("#4a3018"), 5)
	Spr.line(rope, Color("#b08850"), 3)
	# trança da corda: risquinhos claros
	for k in 8:
		var q: Vector2 = rope[k].lerp(rope[k + 1], .5)
		Spr.seg(q.x - 2, q.y - 1.5, q.x + 2, q.y + 1.5, Color("#e2c48e"), 1.2)
	var cols := [Color("#e0463a"), Color("#f0c040"), Color("#3a8ad0"), Color("#5ab04a")]
	for k in 4:
		var u2: float = (k + .6) / 4.6
		var a: Vector2 = Vector2(lerpf(o.x - 4, o.x + 88, u2), 381 + sin(u2 * PI) * 7)
		var sw: float = sin(T * .25 + k * 1.3) * 3.0
		var c: Color = cols[k]
		var tri := PackedVector2Array([a + Vector2(-7, 0), a + Vector2(7, 0), a + Vector2(sw, 16)])
		Spr.poly(tri, c)
		Spr.poly(PackedVector2Array([a + Vector2(-7, 0), a + Vector2(-1, 0), a + Vector2(sw - 1, 15)]), c.darkened(.25))
		tri.push_back(tri[0])
		Spr.line(tri, Color(.16, .1, .05, .85), 1.3)

## desfiladeiro do salto grande: a fenda de gelo cortando a trilha, a rampa de neve batida antes da
## beirada (com as bandeirinhas de aviso) e a névoa subindo lá de dentro
func _leap(o: Dictionary, T: int) -> void:
	var w: float = float(o.w)
	var cx: float = o.x + w / 2.0
	# o vão: escuro azulado sumindo lá embaixo, com as bordas de pedra irregulares
	var bot: float = 900.0
	var L0 := PackedVector2Array()
	var R0 := PackedVector2Array()
	for k in 10:
		var yy: float = 498.0 + k * 45.0
		L0.push_back(Vector2(o.x + 6 + 10 * sin(k * 1.9 + o.x) + k * 3.0, yy))
		R0.push_back(Vector2(o.x + w - 6 - 10 * sin(k * 2.3 + o.x) - k * 3.0, yy))
	var body := PackedVector2Array(L0)
	var cols := PackedColorArray()
	for q in L0:
		cols.push_back(Color("#3a5576").lerp(Color("#03060b"), pow(clamp((q.y - 498.0) / 260.0, 0, 1), .55)))
	for i in range(R0.size() - 1, -1, -1):
		body.push_back(R0[i])
		cols.push_back(Color("#3a5576").lerp(Color("#03060b"), pow(clamp((R0[i].y - 498.0) / 260.0, 0, 1), .55)))
	Spr.ci.draw_polygon(body, cols)
	# paredão do fundo (do outro lado do vão, longe): faixas de pedra azuladas sumindo na névoa
	for k in 5:
		var sy: float = 530.0 + k * 34.0
		var pts := PackedVector2Array()
		for j in 7:
			var u: float = j / 6.0
			pts.push_back(Vector2(lerpf(L0[min(k + 1, 9)].x, R0[min(k + 1, 9)].x, u), sy + 5.0 * sin(u * 9.0 + k * 2.0)))
		Spr.line(pts, Color(.75, .85, 1, .13 - k * .02), 3)
	# paredes de pedra: pedras pintadas escurecendo com a fundura, encostadas nas bordas
	for k in 9:
		var yy2: float = 512.0 + k * 40.0
		var dk: float = clamp(1.0 - k * .1, .25, 1.0)
		var tc := Color(.58 * dk, .56 * dk, .6 * dk)
		var jx: float = 6.0 * sin(k * 2.7 + o.x)
		Spr.P("rock%d" % (k % 2), L0[min(k + 1, 9)].x - 10 + jx, yy2 + 34, 62 - k * 3, k % 2 == 0, 0.0, tc)
		Spr.P("rock%d" % ((k + 1) % 2), R0[min(k + 1, 9)].x + 10 - jx, yy2 + 34, 62 - k * 3, k % 2 == 1, 0.0, tc)
	# névoa fria subindo do fundo
	for k in 3:
		var u: float = fposmod(T * .005 + k * .33, 1.0)
		Spr.glow(o.x + w * (.25 + k * .25), 640 - u * 120, 70, Color(.85, .93, 1, .16 * sin(u * PI)))
	# beiradas de neve com pingentes de gelo pendurados
	for sd in [0, 1]:
		var ex: float = o.x + (0.0 if sd == 0 else w)
		var dr: float = 1.0 if sd == 0 else -1.0
		Spr.poly(PackedVector2Array([Vector2(ex - dr * 30, 492), Vector2(ex + dr * 14, 494), Vector2(ex + dr * 18, 503), Vector2(ex - dr * 30, 506)]), Color(.92, .96, 1))
		Spr.line(PackedVector2Array([Vector2(ex - dr * 30, 492), Vector2(ex + dr * 14, 494), Vector2(ex + dr * 18, 503)]), Color(1, 1, 1), 2)
		for j in 3:
			Spr.P("icicle", ex + dr * (12 - j * 9), 503 + 26 - j * 5, 9 - j)
	# rampa de neve batida antes da beirada
	var r0: float = o.x - Ride.LEAP_RAMP
	var ramp := PackedVector2Array([Vector2(r0 - 10, 501), Vector2(o.x - 30, 494), Vector2(o.x + 2, 490), Vector2(o.x + 6, 501)])
	Spr.poly(ramp, Color(.88, .93, 1))
	Spr.line(PackedVector2Array([Vector2(r0 - 10, 500), Vector2(o.x - 30, 493), Vector2(o.x + 2, 489)]), Color(1, 1, 1), 2.5)
	# estacas com bandeirinhas vermelhas no começo da rampa e na beirada
	for fx in [r0, o.x - 4.0, o.x + w + 8.0]:
		Spr.save()
		Spr.translate(fx, 502)
		Spr.rotate(sin(T * .1 + fx) * .03)
		Spr.P("flagred", 0, 0, 40)
		Spr.restore()

## marcos (bandeiras) da trilha e placas de aviso antes dos obstáculos de abaixar e do desfiladeiro
func _ride_marks(g: Game, RD: Ride, x0: float, x1: float) -> void:
	var C: Array = RD.cps()
	for i in C.size():
		var cx: float = float(C[i])
		if cx < x0 - 100 or cx > x1 + 100:
			continue
		var passed: bool = RD.cp_i >= i and RD.riding
		# mastro alto com a bandeira: vermelha antes, dourada depois de passar
		Spr.ellipse(cx, 501, 16, 4, Color(.25, .32, .5, .3))
		Spr.PR("stake", cx - 6, 380, 12, 122, Color(.85, .8, .75))
		Spr.save()
		Spr.translate(cx, 400)
		Spr.rotate(sin(T * .12 + cx) * .04)
		Spr.P("flagred", 0, 0, 64, false, 0.0, Color(1.25, 1.1, .45) if passed else Color.WHITE)
		Spr.restore()
		if passed:
			Spr.glow(cx + 14, 352, 40, Color(1, .85, .4, .25 + .1 * sin(T * .2)))
		Spr.text("%d" % (i + 1), cx + 16, 368, 15, Color(1, 1, 1), HORIZONTAL_ALIGNMENT_CENTER, Spr.font_b, 3, Color(.3, .1, .05, .8))
	# arco de chegada
	var ax: float = RD.finish_x()
	if ax > x0 - 200 and ax < x1 + 200:
		WorldVehicles.finish_arch(ax, 500.0, 0.0, T)
	# (sem placas de seta antes dos obstáculos: o próprio obstáculo avisa)

var _hpitch := 0.0
## cavalgada: o galho baixo por cima do Tomé e do cavalo (a árvore fica atrás, em _ride_world)
func _ride_front(g: Game) -> void:
	var RD: Ride = g.RD
	if RD == null or RD.H.is_empty():
		return
	var x0: float = g.cam - 160
	var x1: float = g.cam + g.W + 160
	if x1 < float(RD.H.get("ride0", -1e9)) - 200.0 or x0 > float(RD.H.get("ride1", 1e9)) + 400.0:
		return
	var t: Texture2D = null
	for o in RD.OBS:
		if o.k == "branch" and o.x <= x1 and o.x + 160 >= x0:
			if t == null:
				WorldNature.prop("galho_neve", -9999, 0, 1)   # garante a textura carregada
				t = Spr.tex["p_galho_neve"]
			# só o galho (colunas da direita da pintura, espelhada): o toco continua atrás do cavalo
			var hh := 130.0
			var ww: float = hh * t.get_width() / t.get_height()
			var c0: float = t.get_width() * .5
			Spr.save()
			Spr.translate(o.x + 73, 504)
			Spr.scale(-1, 1)
			Spr.ci.draw_texture_rect_region(t, Rect2(-ww / 2 + ww * .5, -hh, ww * .5, hh), Rect2(c0, 0, t.get_width() - c0, t.get_height()), Color(1, 1, 1, Spr.alpha))
			Spr.restore()

func _rider(g: Game) -> void:
	var RD: Ride = g.RD
	var p: Dictionary = g.player
	if p.iframe > 0 and (T / 4) % 2 == 0:
		Spr.alpha = .55
	var gt := Spr.opt("ride_gallop")
	var jt := Spr.opt("ride_jump")
	var dt := Spr.opt("ride_dis")
	if RD.endT >= 0:
		# desmontando (cena curta): o cavalo parado e o Tomé descendo
		Spr.ellipse(RD.hx, 502, 62, 7, Color(0, 0, 0, .22))
		var df: int = 0 if RD.endT < 50 else (1 if RD.endT < 95 else 2)
		if dt:
			Spr.frame(dt, df, 340, 250, 130, 244, RD.hx, RD.hy + 3, RS)
		else:
			var ft := Spr.opt("horse_free")
			if ft:
				Spr.frame(ft, 2, 260, 250, 130, 244, RD.hx, RD.hy + 3, RS)
			var u: float = clamp(RD.endT / 110.0, 0, 1)
			Spr.save()
			Spr.translate(lerpf(RD.hx - 6, RD.hx - 30, u), lerpf(RD.hy - 64, RD.hy + 2, u * u))
			Spr.frame(Spr.tex.pai, 0, 170, 160, 85, 156, 0, 0, .46, false)
			Spr.restore()
		Spr.alpha = 1.0
		return
	# sombra no chão (some em cima do desfiladeiro)
	var over_gap := false
	for o in RD.OBS:
		if (o.k == "leap" or o.k == "gap") and RD.hx > o.x + 10 and RD.hx < o.x + o.w - 10:
			over_gap = true
	if not over_gap:
		Spr.ellipse(RD.hx, 502, 62 * (1.0 - clamp((500.0 - RD.hy) / 160.0, 0, .6)), 7, Color(0, 0, 0, .22 * (1.0 - clamp((500.0 - RD.hy) / 300.0, 0, .7))))
	Spr.save()
	Spr.translate(RD.hx, RD.hy + 3)
	if RD.stumble > 0:
		Spr.rotate(sin(T * .6) * .06)
	elif RD.hy >= 497.0:
		# galopando: o corpo sobe e desce com a passada e inclina para a frente quando corre mais
		Spr.rotate(-clamp((RD.spd - 5.0) / 1.5, 0.0, 1.0) * .035)
	# pouso: amassa um pouco e volta (peso)
	if RD.land_k > 0.0:
		Spr.scale(1.0 + RD.land_k * .07, 1.0 - RD.land_k * .1)
	# no salto o cavalo empina subindo e abaixa o focinho descendo (gira em volta das patas)
	var pt: float = clamp(RD.vy * .014, -.12, .1) if RD.hy < 497.0 else 0.0
	if FRESH:
		_hpitch = lerp(_hpitch, pt, .2)
	Spr.rotate(_hpitch)
	if RD.hy < 497.0 and jt:
		var jf: int = 0 if RD.vy < -3.0 else (1 if RD.vy < 3.0 else 2)
		Spr.frame(jt, jf, 260, 250, 130, 244, 0, 0, RS)
	elif RD.duck and jt:
		# abaixado: o cavalo baixa o corpo e o Tomé deita sobre o pescoço
		Spr.scale(1.04, .86)
		Spr.frame(jt, 3, 260, 250, 130, 244, 0, 0, RS)
	elif gt:
		var gf: int = int(RD.gallop) % 8
		if RD.duck:
			Spr.translate(0, 10)
			Spr.scale(1, .9)
		if RD.hy < 497.0:
			Spr.frame(gt, 3, 260, 250, 130, 244, 0, 0, RS)
		else:
			# galope com transição entre os quadros (passada contínua)
			Spr.frame_mix(gt, RD.gallop, 8, 0, 260, 250, 130, 244, 0, 0, RS)
	Spr.restore()
	Spr.alpha = 1.0

# ---------- alavancas, contrapesos e portão de ferro da mina ----------
func _levers(g: Game) -> void:
	if not g.EV or g.EV.LV.is_empty():
		return
	var LV: Dictionary = g.EV.LV
	var G: Dictionary = g.EV.GATE
	if G.x < g.cam - 300 or G.x > g.cam + g.W + 300:
		return
	var y: float = float(LV.y)
	# portão de ferro forjado subindo entre batentes de pedra, com duas luzinhas (uma por alavanca)
	var gx: float = G.x
	var gy: float = G.y
	var ndown := 0
	for o in LV.list:
		if o.down:
			ndown += 1
	Spr.PR("wb3", gx - 16, 360, G.w + 32, 24, Color(.75, .72, .7))
	Spr.PR("gate_iron", gx - 6, gy - 10, G.w + 12, G.h + 10)
	for k in 2:
		var lit: bool = k < ndown
		var lx2: float = gx + G.w / 2 + (k - .5) * 16
		if lit:
			Spr.glow(lx2, 372, 14, Color(1, .85, .4, .6))
		Spr.circle(lx2, 372, 4, Color(1, .85, .4) if lit else Color(.25, .22, .2))
	# roldana no teto
	Spr.circle(gx + G.w / 2, 392, 9, Color("#4a4642"))
	Spr.ring(gx + G.w / 2, 392, 9, Color("#2a2622"), 2)
	var near_any: bool = false
	for lv in LV.list:
		var lx: float = float(lv.x)
		var a: float = lv.a
		var wy: float = lerpf(390, 452, a)
		# corrente da alavanca até o contrapeso e do contrapeso até a roldana do portão
		_chain(Vector2(lx, wy - 12), Vector2(lx, 384))
		_chain(Vector2(lx, 384), Vector2(gx + G.w / 2 - 8, 388))
		# contrapeso de pedra com argola
		Spr.PR("wb2", lx - 15, wy - 14, 30, 26, Color(.7, .7, .74))
		Spr.ring(lx, wy - 14, 4, Color("#5f5a55"), 2)
		# alavanca pintada na base de pedra (gira de cima para baixo ao puxar)
		Spr.save()
		Spr.translate(lx, y)
		Spr.rotate(lerpf(-.35, .9, a))
		Spr.P("lever", 0, 2, 40)
		Spr.restore()
		var near: bool = not lv.down and abs(g.player.x + g.player.w / 2 - lx) < 60
		if near:
			near_any = true
			Spr.glow(lx, y - 26, 30, Color(1, .85, .45, .25 + .15 * sin(T * .15)))
			Spr.ci.draw_texture_rect(Spr.tex.btn_use if Spr.tex.has("btn_use") else Spr.tex.pad_S, Rect2(lx - 15, y - 82 + sin(T * .12) * 3, 30, 30), false, Color(1, 1, 1, .95))
			Spr.text("PUXAR", lx, y - 40 + sin(T * .12) * 3, 13, Color("#ffecaa"), HORIZONTAL_ALIGNMENT_CENTER, Spr.font_b, 3)

## corrente de elos de ferro entre dois pontos
func _chain(a: Vector2, b: Vector2) -> void:
	var L2: float = a.distance_to(b)
	var n: int = max(1, int(L2 / 7.0))
	for i in n:
		var p: Vector2 = a.lerp(b, (i + .5) / n)
		if i % 2 == 0:
			Spr.ellipse(p.x, p.y, 3.2, 2.2, Color("#5f5a55"), atan2(b.y - a.y, b.x - a.x))
		else:
			Spr.ellipse(p.x, p.y, 2.4, 1.2, Color("#3a3632"), atan2(b.y - a.y, b.x - a.x))

# ---------- reflexo do Tomé na água ----------
func _reflection(g: Game) -> void:
	var p: Dictionary = g.player
	if p.swim or p.dyingT > 0 or not g.WV or p.get("wpose", "") != "" or (g.VH and g.VH.active()) or (g.RD and g.RD.riding):
		return
	var px: float = p.x + p.w / 2
	var by: float = p.y + p.h
	for k in g.WV.B:
		var b: Dictionary = g.WV.B[k]
		var d: float = b.y - by
		if px < b.x0 + 10 or px > b.x1 - 10 or d < -2 or d > 150:
			continue
		var off := g.ip_off()
		var wy: float = b.y + off.y
		Spr.save()
		var a0: float = Spr.alpha
		Spr.alpha = a0 * .32 * (1.0 - d / 150.0)
		# espelha em volta da linha da água, com um tremidinho de onda
		Spr.translate(off.x + sin(T * .09) * 1.5, wy * 2.0)
		Spr.scale(1, -1)
		_player_draw(g)
		Spr.alpha = a0
		Spr.restore()
		return

# ---------- vapor da respiração no frio ----------
var puffs: Array = []
func _breath(g: Game) -> void:
	var p: Dictionary = g.player
	var cold: bool = g.AMB.get("snow", 0.0) > .2
	if cold and g.running and not p.swim and p.dyingT == 0 and not (g.VH and g.VH.active()) and not (g.RD and g.RD.riding):
		var per: int = 46 if (abs(p.vx) > 2.5 or p.get("pant", 0) > 0) else 110
		if FRESH and (T % per == 0 or T % per == 8):
			var off := g.ip_off()
			puffs.append({"x": p.x + p.w / 2 + p.face * 12 + off.x, "y": p.y + p.h - 44 + off.y, "vx": p.face * .5 + p.vx * .3, "t": 0})
	var keep: Array = []
	for f in puffs:
		# a fumacinha anda no ritmo da lógica (a 90/120 Hz desenhava mais de uma vez por passo: nascia em dobro e subia rápido)
		if FRESH:
			f.t += 1
			f.x += f.vx
			f.vx *= .96
			f.y -= .25
		var u: float = f.t / 50.0
		if u < 1:
			Spr.circle(f.x, f.y, 3 + u * 9, Color(.95, .97, 1, .45 * (1 - u)))
			keep.append(f)
	puffs = keep

# ---------- o Tomé ----------
func _player(g: Game) -> void:
	# cavalgada e veículos andam no ritmo da lógica: desenha "entre passos" junto com a câmera
	# (sem isso, a 90/120 Hz o cavalo/veículo tremia em relação ao cenário)
	if g.RD and g.RD.riding:
		var ro := g.ip_off()
		Spr.save()
		Spr.translate(ro.x, ro.y)
		_rider(g)
		Spr.restore()
		return
	if g.VH and g.VH.active():
		var vo := g.ip_off()
		Spr.save()
		Spr.translate(vo.x, vo.y)
		WorldVehicles.rider(g, T)
		Spr.restore()
		return
	if g.M and g.M.ctrl:
		# o jogador está com o Pipoca: o Tomé fica parado onde estava
		var real: Dictionary = g.player
		g.player = g.M.tome
		_player_draw(g)
		g.player = real
		return
	var off := g.ip_off()
	var p: Dictionary = g.player
	# fim de tarde: sombra comprida do Tomé deitada no chão
	var tw: float = g.section_weights().get("tarde", 0.0)
	if tw > 0 and p.onGround:
		var u: float = clamp((p.x - 3430.0) / 11710.0, 0, 1) * tw
		if u > .2:
			Spr.ellipse(p.x + p.w / 2 + off.x + 22 * u, p.y + p.h + 1 + off.y, 18 + 26 * u, 3.2, Color(.2, .08, .02, .22 * u))
	Spr.save()
	var gd = p.get("_g")
	var pdip: float = gd.get("dip", 0.0) if gd is Dictionary else 0.0
	Spr.translate(off.x, off.y + p.get("wdy", 0.0) + p.get("sink", 0.0) + pdip)
	var a0: float = Spr.alpha
	Spr.alpha = a0 * p.get("wal", 1.0)
	if p.get("wpose", "") != "":
		_warp_pose(p)
	else:
		_player_draw(g)
		# com o capacete de mergulho: nadando, ele é desenhado junto do corpo (_player_draw, preso na cabeça);
		# aqui só deitado no fundo (rastejando): a cabeça fica na frente, perto do chão
		if g.NT and g.NT.helmet and p.swim and p.crouch and not p.get("dog") and p.dyingT == 0 and not (p.iframe > 0 and (T / 4) % 2 == 0):
			WorldNature.prop("capacete", p.x + p.w / 2 + p.face * 20, p.y + p.h - 2, 46, p.face < 0)
		WorldExtras.tool_fx(g, T)
	Spr.alpha = a0
	Spr.restore()

## a Isis (fase da fuga) — arte do Gemini, isis2.png: 0-3 correndo, 4 parada, 5 pulando, 6 caindo,
## 7 ajoelhada (shh), 8 subindo escada, 9 agachada escondida, 10 pendurada, 11-12 engatinhando
const ISIS_H := 76.0
func _isis_draw(p: Dictionary) -> void:
	var cx: float = p.x + p.w / 2
	var by: float = p.y + p.h + 2
	var fr := 4
	var flip: bool = p.face < 0
	if p.dyingT > 0:
		# tombo: gira no ar e cai (como o Tomé)
		var td: Texture2D = Spr.tex.get("isis2")
		if td:
			var s0: float = ISIS_H / 150.0
			Spr.save()
			Spr.translate(cx, by - 20)
			Spr.rotate((46 - p.dyingT) * .12 * (1.0 if p.face > 0 else -1.0))
			Spr.translate(0, 20)
			Spr.scale(-s0 if flip else s0, s0)
			Spr.ci.draw_texture_rect_region(td, Rect2(-75, -150, 150, 150), Rect2(6 * 150, 0, 150, 150), Color(1, 1, 1, Spr.alpha))
			Spr.restore()
		return
	if p.get("bar"):
		fr = 10
		by = game.NT.bar_y(p.bar, cx) + ISIS_H * .66
	elif p.ladder:
		fr = 8
		flip = false
		if p.ladder.kind == "ladder":
			cx = p.ladder.x + p.ladder.w / 2
	elif not p.onGround:
		# braços para cima subindo e no começo da descida; a pose de tombo só numa queda longa
		fr = 6 if p.vy > 7.5 else 5
	elif p.crouch:
		if abs(p.vx) > .4:
			fr = 11 + int(p.anim * .5) % 2
		else:
			fr = 9 if game.VL and game.VL.hidden(p) else 7
	elif abs(p.vx) > .5:
		fr = int(p.anim * .78) % 4
	_ppos = Vector2(p.x, p.y)
	var air: float = clamp(1 - abs(p.vy) / 16.0, .35, 1) if not p.onGround else 1.0
	if fr != 10 and fr != 8 and p.onGround:
		Polish.shadow(cx, p.y + p.h + 1, 13 * air, 3 * air, .3 * air)
	var t: Texture2D = Spr.tex.get("isis2")
	if t == null:
		return
	var s: float = ISIS_H / 150.0
	# poses pintadas extras: subindo corda/cipó, escondida com medo, feliz
	var ovn := ""
	# (também na escada de verdade: o quadro 8 da folha tem uma escadinha pintada junto)
	if p.ladder:
		ovn = "isis_climb"
	elif p.get("cheerT", 0) > 0:
		ovn = "isis_joy"
	elif fr == 9:
		ovn = "isis_scared"
	var ovt: Texture2D = Spr.opt(ovn) if ovn != "" else null
	if ovt != null:
		var ow: float = ovt.get_width()
		var oh: float = ovt.get_height()
		var bob2: float = -abs(sin(T * .3)) * 4.0 if ovn == "isis_joy" else 0.0
		_pose(ovn, ovt, Rect2(0, 0, ow, oh), Rect2(-ow / 2, -oh, ow, oh), cx, by - 2 + bob2, 0.0, -s if flip else s, s)
		Spr.save()
		Spr.translate(cx, by - 2 + bob2)
		Spr.scale(-s if flip else s, s)
		Spr.trect(ovt, Rect2(-ow / 2, -oh, ow, oh))
		Spr.restore()
		return
	var rot := 0.0
	var st := Vector2.ONE
	if fr <= 6:
		st = _body_flex(p, "isis", fr, 4)
		rot = float(p.get("lean", 0.0))
		if fr == 4:
			# parada: respira; ofegante depois de correr muito (curvada, rápido)
			var ip: float = p.get("pant", 0) / 150.0
			st.y *= 1.0 + sin(T * .07) * .012 + sin(T * .32) * .035 * ip - .02 * ip
			rot += p.face * .07 * ip
		if fr < 4:
			# passada: o corpo sobe um tiquinho no quadro de apoio (1 e 3)
			st.y *= 1 + (.012 if fr % 2 == 1 else -.008) * clamp(abs(p.vx) / 4.3, 0, 1)
	elif fr == 10:
		rot = float(p.get("bsw", 0.0))
	var sq: float = p.squash
	var dk: float = float(p.get("duck", 1.0))
	var sx: float = (-s if flip else s) * st.x * (1 + sq * .2) * (1.0 + (1.0 - dk) * .3)
	var sy: float = s * st.y * (1 - sq * .25) * dk
	var src := Rect2(fr * 150, 0, 150, 150)
	var dst := Rect2(-75, -150, 150, 150)
	# folha de corrida completa (assets/sprites/isis_run.png, quadros 150x150 na mesma escala), se existir
	var rt: Texture2D = Spr.opt("isis_run")
	var rn: int = int(rt.get_width() / 150) if rt else 0
	var fp2: float = p.anim * .78
	if fr < 4 and rt and rn > 0:
		t = rt
		src = Rect2((int(fp2) % rn) * 150, 0, 150, 150)
	# quadros intermediários (x4): corrida e engatinhar agachada
	var im4: Dictionary = {}
	var ifp := 0.0
	if fr < 4 and p.onGround and not p.crouch:
		im4 = Spr.x4("isis_run:0-1-2-3-4-5-6-7") if (rt and rn == 8) else Spr.x4("isis2:0-1-2-3")
		ifp = fp2 if (rt and rn == 8) else p.anim * .78
	elif fr >= 11 and fr <= 12:
		im4 = Spr.x4("isis2:11-12")
		ifp = p.anim * .5
	var ik4 := 0.0
	var isrc4 := Rect2()
	if not im4.is_empty():
		var iq: Array = Spr.x4_pos(im4, ifp)
		t = im4.tex
		src = Spr.x4_src(im4, iq[0])
		isrc4 = Spr.x4_src(im4, iq[1])
		ik4 = smoothstep(.5, 1.0, iq[2]) * .5 if iq[1] != iq[0] else 0.0
	_pose("isis%d" % (fr if fr >= 4 else 0), t, src, dst, cx, by, rot, sx, sy)
	Spr.save()
	Spr.translate(cx, by)
	Spr.rotate(rot)
	Spr.scale(sx, sy)
	Spr.ci.draw_texture_rect_region(t, dst, src, Color(1, 1, 1, Spr.alpha))
	if not im4.is_empty():
		if ik4 > .02:
			Spr.ci.draw_texture_rect_region(t, dst, isrc4, Color(1, 1, 1, Spr.alpha * ik4))
	elif fr < 4 and rt and rn > 0 and p.onGround and not p.crouch:
		var kr: float = smoothstep(.6, 1.0, fp2 - floor(fp2)) * .5
		if kr > .02:
			Spr.ci.draw_texture_rect_region(t, dst, Rect2(((int(fp2) + 1) % rn) * 150, 0, 150, 150), Color(1, 1, 1, Spr.alpha * kr))
	elif fr < 4 and p.onGround and not p.crouch:
		# só 4 quadros de corrida: perto da troca o próximo aparece por cima (movimento contínuo)
		var fp: float = p.anim * .78
		var kk: float = smoothstep(.55, 1.0, fp - floor(fp)) * .7
		if kk > .02:
			Spr.ci.draw_texture_rect_region(t, dst, Rect2(((fr + 1) % 4) * 150, 0, 150, 150), Color(1, 1, 1, Spr.alpha * kk))
	Spr.restore()

## poses da animação de entrar/sair dos esconderijos
func _warp_pose(p: Dictionary) -> void:
	var cx: float = p.x + p.w / 2
	var by: float = p.y + p.h
	match p.wpose:
		"crouch":
			Spr.A("pai_crouch", cx, by, .56, p.face < 0)
		"crawl":
			Spr.A_cycle("pai_crawl", ["pai_crawl1", "pai_crawl2", "pai_crawl3", "pai_crawl2"], T / 7.0, cx, by, .56, p.face < 0)
		"climb":
			var t3: Texture2D = Spr.tex.pai_climb
			var mv := int(p.climbA / 22) % 2
			Spr.save()
			Spr.translate(cx, by + 6)
			Spr.scale(-.56 if mv else .56, .56)
			Spr.ci.draw_texture(t3, Vector2(-t3.get_width() / 2.0, -t3.get_height()), Color(1, 1, 1, Spr.alpha))
			Spr.restore()

func _player_draw(g: Game) -> void:
	var p: Dictionary = g.player
	# teto baixo logo acima: o desenho (bem mais alto que a caixa) se encolhe para o chapéu não entrar
	# no teto; subindo, já antecipa um pouco. Só o desenho muda (a caixa de colisão é a mesma).
	var cg: float = float(p.get("ceil", 99.0)) + min(0.0, float(p.vy)) * 1.5
	var art_h: float = 58.0 if p.get("isis") else 66.0
	var dk_t: float = 1.0 if p.crouch or p.ladder or p.vine else clamp((p.h + max(cg, 0.0) + 6.0) / art_h, .7, 1.0)
	if FRESH or not p.has("duck"):
		var d0: float = float(p.get("duck", 1.0))
		p.duck = lerpf(d0, dk_t, .75 if dk_t < d0 else .18)
	if p.iframe > 0 and (T / 4) % 2 == 0 and p.dyingT == 0:
		return
	if p.get("isis"):
		_isis_draw(p)
		return
	var cx: float = p.x + p.w / 2
	var by: float = p.y + p.h
	_ppos = Vector2(p.x, p.y)
	# pose de dor: no tranco e enquanto está no ar; pousou e saiu andando, já volta a passada
	# (antes a pose parada de dor "patinava" pelo chão até o fim do tempo)
	var hurt_on: bool = p.get("hitT", 0) > 0 and (not p.onGround or int(p.hitT) > 18 or abs(p.vx) < .5)
	if p.lastFace != p.face:
		# meia-volta: o desenho gira até o outro lado em TURN_N passos (a física já virou na hora)
		p.lastFace = p.face
		if p.turnT > 0 and _mg_face == (1.0 if p.face > 0 else -1.0):
			# voltou antes de o desenho passar da metade: fica como estava
			p.turnT = 0
		else:
			p.tfrom = -1.0 if p.face > 0 else 1.0
			p.turnT = TURN_N
	if p.turnT > 0 and int(p.get("_tt", -1)) != T:
		p._tt = T
		p.turnT -= 1
	var tst: Array = _turn_state(g, p)
	_mg_flip(tst[0])
	if g.player == p:
		_light_k = float(tst[0]) * (float(tst[1]) - .45) / .55
	if float(tst[2]) < 1.0:
		# na meia-volta a pose antiga não fica "fantasma" por baixo (ela olhava para o outro lado)
		_ghostT = 0
	var pai: Texture2D = Spr.tex.pai
	var pai2: Texture2D = Spr.tex.pai2
	# subindo na beirada: braço erguido segurando, corpo inclinado sobre a quina
	if p.get("mantleT", 0) > 0:
		var u: float = 1.0 - p.mantleT / 16.0
		Spr.save()
		Spr.translate(cx, by)
		Spr.rotate(p.face * (.25 if u > .5 else .1))
		Spr.scale(p.face * .48, .48 * (1.0 + .06 * sin(u * PI)))
		Spr.ci.draw_texture_rect_region(pai, Rect2(-85, -156, 170, 160), Rect2(4 * 170, 0, 170, 160), Color(1, 1, 1, Spr.alpha))
		Spr.restore()
		return
	if p.dyingT > 0:
		Spr.save()
		Spr.translate(cx, by - 30)
		Spr.rotate((46 - p.dyingT) * .12)
		Spr.translate(0, 30)
		Spr.frame(pai2, 8, 170, 160, 85, 156, 0, 0, .48, p.face < 0)
		Spr.restore()
		return
	# pendurado na corda esticada: mão sobre mão
	if p.get("bar"):
		# mão sobre mão: troca de mão a cada palmo; o corpo balança como um pêndulo preso às mãos
		var bt: Texture2D = Spr.tex.pai_vine_a if int(p.get("bfr", 0)) == 0 else Spr.tex.pai_vine_b
		var bax := 63.0 if bt == Spr.tex.pai_vine_a else 60.0
		var bty: float = g.NT.bar_y(p.bar, cx) + 1
		var brot: float = float(p.get("bsw", 0.0)) + sin(T * .05) * .02
		_pose("bar%d" % int(p.get("bfr", 0)), bt, Rect2(Vector2.ZERO, bt.get_size()), Rect2(Vector2(-bax, -2), bt.get_size()), cx, bty, brot, -.56 if p.face < 0 else .56, .56)
		Spr.save()
		Spr.translate(cx, bty)
		Spr.rotate(brot)
		Spr.scale(-.56 if p.face < 0 else .56, .56)
		Spr.ci.draw_texture(bt, Vector2(-bax, -2))
		Spr.restore()
		return
	# subindo: escada/rede (de costas), corda (de lado) e cipó (pendurado pela mão)
	if not hurt_on and (p.ladder or p.vine):
		var mv := int(p.climbA / 22) % 2
		if p.vine:
			var v: Dictionary = p.vine
			var hx: float = v.x + sin(v.th) * p.vr
			var hy: float = v.y + cos(v.th) * p.vr
			# pose firme enquanto balança; a outra só quando quase parado (sem ficar trocando)
			var still: bool = p.get("vstill", false)
			if still and abs(v.om) > .012:
				still = false
			elif not still and abs(v.om) < .004:
				still = true
			p.vstill = still
			var t: Texture2D = Spr.tex.pai_vine_b if still else Spr.tex.pai_vine_a
			var ax := 63.0 if t == Spr.tex.pai_vine_a else 60.0
			_pose("vine" + str(still), t, Rect2(Vector2.ZERO, t.get_size()), Rect2(Vector2(-ax, -2), t.get_size()), hx, hy, -p.get("vang", v.th), -.56 if p.face < 0 else .56, .56)
			Spr.save()
			Spr.translate(hx, hy)
			Spr.rotate(-p.get("vang", v.th))
			Spr.scale(-.56 if p.face < 0 else .56, .56)
			Spr.ci.draw_texture(t, Vector2(-ax, -2))
			Spr.restore()
		elif p.ladder.kind == "rope":
			var t2: Texture2D = Spr.tex.pai_rope_a if mv else Spr.tex.pai_rope_b
			var rx := 46.0 if mv else 52.0
			var lx: float = p.ladder.x + p.ladder.w / 2
			_pose("rope%d" % mv, t2, Rect2(Vector2.ZERO, t2.get_size()), Rect2(Vector2(-rx, -t2.get_height()), t2.get_size()), lx, by + 4, 0.0, .56, .56)
			Spr.save()
			Spr.translate(lx, by + 4)
			Spr.scale(.56, .56)
			Spr.ci.draw_texture(t2, Vector2(-rx, -t2.get_height()))
			Spr.restore()
		else:
			var t3: Texture2D = Spr.tex.pai_climb
			var lx2: float = p.ladder.x + p.ladder.w / 2 if p.ladder.kind == "ladder" else cx
			var bob := -2.0 if mv else 0.0
			_pose("ladder%d" % mv, t3, Rect2(Vector2.ZERO, t3.get_size()), Rect2(Vector2(-t3.get_width() / 2.0, -t3.get_height()), t3.get_size()), lx2, by + 6 + bob, 0.0, -.56 if mv else .56, .56)
			Spr.save()
			Spr.translate(lx2, by + 6 + bob)
			Spr.scale(-.56 if mv else .56, .56)
			Spr.ci.draw_texture(t3, Vector2(-t3.get_width() / 2.0, -t3.get_height()))
			Spr.restore()
		_armor(p, cx, by)
		return
	# Tomé em peças com "ossos" (se as artes de assets/rig/tome existirem)
	if not hurt_on and Rig.ready("tome"):
		var air2: float = clamp(1 - abs(p.vy) / 16.0, .3, 1) if not p.onGround else 1.0
		Spr.ellipse(cx, by + 1, 17 * air2, 4 * air2, Color(0, 0, 0, .25 * air2))
		var sqv := Vector2(1 + p.squash * .25, 1 - p.squash * .3)
		Rig.draw_pose("tome", cx, by, p.face, Rig.pose_for(p, T), sqv)
		_armor(p, cx, by)
		return
	# poses novas (atlas 2)
	if not hurt_on:
		var n := ""
		var cyk := ""
		var cyn: Array = []
		var cyf := 0.0
		if p.crouch:
			if p.slideT:
				n = "pai_slide"
			elif abs(p.vx) > .3:
				cyk = "pai_crawl"
				cyn = ["pai_crawl1", "pai_crawl2", "pai_crawl3", "pai_crawl2"]
				cyf = T / 8.0
				n = cyn[(T / 8) % 4]
			else:
				n = "pai_crouch"
		elif p.actT > 0 and p.act in ["throw1", "throw2", "gear"]:
			n = "pai_" + p.act
		elif p.actT > 0 and p.act == "swing":
			n = "pai_throw1" if p.actT > 14 else "pai_throw2"
		elif p.pushT > 0 and p.onGround:
			cyk = "pai_push"
			cyn = ["pai_push1", "pai_push2", "pai_push3"]
			cyf = T / 10.0
			n = cyn[(T / 10) % 3]
		elif p.run and p.onGround and abs(p.vx) > 3 and not Spr.anim.has("run"):
			n = "pai_run1" if int(p.anim * 1.6) % 2 else "pai_run2"
		if n != "":
			if p.onGround:
				Spr.ellipse(cx, by + 1, 18, 4, Color(0, 0, 0, .22))
			var cm: Dictionary = Spr.x4("A:" + cyk) if cyk != "" else {}
			var ar = Spr.AR.get(n)
			if not cm.is_empty():
				_pose(cyk, cm.tex, Spr.x4_src(cm, Spr.x4_pos(cm, cyf)[0]), Rect2(-float(cm.ax), -float(cm.ay), float(cm.cw), float(cm.ch)), cx, by, 0.0, -.56 if p.face < 0 else .56, .56)
			elif ar != null:
				_pose(n, Spr.atlas_tex(ar), Rect2(ar[0], ar[1], ar[2], ar[3]), Rect2(-ar[4], -ar[5], ar[2], ar[3]), cx, by, 0.0, -.56 if p.face < 0 else .56, .56)
			if FRESH:
				p.lean = lerp(float(p.get("lean", 0.0)), 0.0, .3)
			if not cm.is_empty():
				Spr.A_cycle(cyk, cyn, cyf, cx, by, .56, p.face < 0)
			else:
				Spr.A(n, cx, by, .56, p.face < 0)
			_armor(p, cx, by)
			return
	# nadando: o corpo deita na direção do nado (braçada), sobe e desce devagar; parado, fica de pé
	# batendo as pernas (sem ficar trocando entre as poses de pulo e queda)
	# com o capacete de mergulho (lago do Bagre-Rei) ele nada EM PÉ, batendo as pernas embaixo, e o capacete
	# vai preso na cabeça (desenhado junto do corpo: acompanha subir, descer, parado e o tiro do arpão)
	var helm: bool = g.NT != null and g.NT.helmet and p.swim and not p.get("dog")
	if p.swim and not p.crouch and (not hurt_on or helm) and Spr.anim.has("fall"):
		var sa: Dictionary = Spr.anim["fall"]
		var ssz: float = sa.s
		var sk := 78.0 / ssz
		var spd: float = Vector2(p.vx, p.vy).length()
		var mvk: float = clamp(spd / 3.0, 0, 1)
		var tgt: float = 0.0
		if helm:
			# em pé: só uma inclinação pequena para o lado do nado (a cabeça fica dentro do capacete)
			tgt = clamp(p.vx * .03, -.12, .12)
			if p.get("act", "") == "harpoon" and p.actT > 0:
				# coice do arpão: o corpo vai um tiquinho para trás
				tgt -= p.face * .1 * p.actT / 12.0
		elif abs(p.vx) > .3:
			tgt = sign(p.vx) * mvk * .95 + p.vy * .05 * sign(p.vx)
		if FRESH:
			p.swr = lerp(float(p.get("swr", 0.0)), tgt, .1 if not helm else .18)
		var stroke: float = sin(T * (.12 + mvk * .1))
		var sbob: float = sin(T * .06) * 2.0 * (1.0 - mvk)
		_ppos = Vector2(p.x, p.y)
		var sx_s: float = sk * (1 + stroke * .03 * mvk)
		var sy_s: float = sk * (1 - stroke * .04)
		var dst_s := Rect2(-ssz / 2, -ssz + 30 / sk, ssz, ssz)
		Spr.save()
		Spr.translate(cx, by - 30 + sbob)
		Spr.rotate(p.swr)
		if helm:
			# subindo: estica e bate as pernas forte; descendo: encolhe um pouco e bate devagar
			var up: float = clamp(-p.vy / 3.0, -1.0, 1.0)
			sy_s *= 1.0 + .04 * max(up, 0.0) - .03 * max(-up, 0.0)
			sx_s *= 1.0 - .02 * max(up, 0.0)
			_mg_springs(g, p, 0.0)
			_mg_setup(ssz, ssz, _mg_anchor("fall", 0.0), 0.0, 70.0)
			_turn_mg(p, tst)
			# a ponta do gorro com o pompom fica guardada dentro do capacete
			MG.pd = Vector2(24.0, 14.0) * ssz / 256.0
			MG.kick = (7.0 + 9.0 * mvk + 5.0 * max(up, 0.0)) * ssz / 256.0
			MG.kph = T * (.2 + .16 * mvk + .1 * max(up, 0.0))
			Spr.scale(float(tst[0]) * sx_s * float(tst[1]), sy_s)
			_mg_prep(dst_s)
			_mg_layer(sa.tex, Rect2(0, 0, ssz, ssz), Spr.alpha)
			if p.dyingT == 0:
				# o capacete na cabeça, no mesmo espaço do desenho (gira e estica junto)
				var hk: float = ssz / 256.0
				WorldNature.prop("capacete", (3.0 + MG.tl * .6) * hk, dst_s.position.y + 150.0 * hk, 160.0 * hk)
		else:
			Spr.scale(p.face * sx_s, sy_s)
			Spr.ci.draw_texture_rect_region(sa.tex, dst_s, Rect2(0, 0, ssz, ssz), Color(1, 1, 1, Spr.alpha))
		Spr.restore()
		_armor(p, cx, by)
		return
	# animações novas (se existirem em assets/sprites/tome/)
	if not Spr.anim.is_empty() and (not hurt_on or Spr.anim.has("hurt")) and not p.puff and not p.slam:
		var key := ""
		var f := 0
		var fnext := -1      # quadro seguinte (mistura suave entre quadros = animação mais fluida)
		var fmix := 0.0
		var grounded: bool = p.onGround or (int(p.get("airT", 9)) <= 2 and p.vy >= 0 and p.vy < 2.5 and not p.get("wslide", false))
		if not grounded:
			key = "jump" if p.vy < 0 else "fall"
		elif p.landT > (4 if abs(p.vx) > 2.0 else 0):
			# pousou correndo: só a dobradinha dos joelhos (sem deslizar parado no chão) e já volta a passada
			key = "land"
		elif abs(p.vx) > .4:
			key = "run" if p.run and Spr.anim.has("run") else "walk"
		else:
			key = _reaction(g, p)
		# poses pintadas extras: dano, comemoração, empurrando, escorregando no gelo
		if hurt_on and Spr.anim.has("hurt"):
			key = "hurt"
		elif p.get("cheerT", 0) > 0 and Spr.anim.has("cheer"):
			key = "cheer"
		elif p.onGround and p.get("pushT", 0) > 0 and abs(p.vx) > .2 and Spr.anim.has("push"):
			key = "push"
		elif p.onGround and abs(p.vx) > 1.2 and p._g is Dictionary and str(p._g.get("t", "")) == "ice" and not g.kd("L") and not g.kd("R") and Spr.anim.has("ice"):
			key = "ice"
		if Spr.anim.has(key):
			var a: Dictionary = Spr.anim[key]
			var n: int = a.n
			# deslizando na parede: de costas para ela, braços abertos, a mão de trás apoiada na parede
			var wsl: bool = key == "fall" and p.get("wslide", false)
			if FRESH:
				p.wsk = lerpf(float(p.get("wsk", 0.0)), 1.0 if wsl else 0.0, .35)
			var wk: float = float(p.get("wsk", 0.0))
			match key:
				"shiver":
					f = (T / 3) % n
				"lantern":
					f = (T / 40) % n
				"walk", "run":
					var ff: float = p.get("gait", p.anim * 1.2) * n / 4.0
					f = int(ff) % n
					fnext = (f + 1) % n
					fmix = ff - floor(ff)
				"idle":
					f = (T / 12) % n
					fnext = (f + 1) % n
					fmix = (T % 12) / 12.0
				"jump":
					f = int(clamp((p.vy + 12) / 12.0, 0, .999) * n)
				"fall":
					f = 0 if wsl else int(clamp(p.vy / 10.0, 0, .999) * n)
				"land":
					f = min(n - 1, int((1 - p.landT / 8.0) * n))
			var sz: float = a.s
			var k2 := 78.0 / sz
			var air3: float = clamp(1 - abs(p.vy) / 16.0, .35, 1) if not p.onGround else 1.0
			var sq3: float = p.squash
			var st: Vector2 = _body_flex(p, key, f, n)
			# meia-volta com volume: o corpo gira em torno do eixo (estreita e abre do outro lado), com um
			# passinho de apoio no meio (desce um tiquinho)
			var dk3: float = float(p.get("duck", 1.0))
			var tdip: float = .05 * sin(PI * float(tst[2]))
			var sx3: float = float(tst[0]) * k2 * (1 + sq3 * .2) * st.x * float(tst[1]) * (1.0 + (1.0 - dk3) * .3)
			var sy3: float = k2 * (1 - sq3 * .25) * st.y * (1.0 - tdip) * dk3
			var src3 := Rect2(f * sz, 0, sz, sz)
			var dst3 := Rect2(-sz / 2, -sz, sz, sz)
			# quadros intermediários (x4): posição contínua dentro da animação
			var tx3: Texture2D = a.tex
			var src4 := Rect2()
			var k4 := 0.0
			var m4: Dictionary = {}
			var fp := -1.0
			match key:
				"walk", "run":
					fp = p.get("gait", p.anim * 1.2) * n / 4.0
				"shiver":
					fp = T / 3.0
				"lantern":
					fp = T / 40.0
				"jump":
					fp = clamp((p.vy + 12) / 12.0, 0, 1) * (n - 1)
				"fall":
					fp = 0.0 if wsl else clamp(p.vy / 10.0, 0, 1) * (n - 1)
				"land":
					fp = clamp(1 - p.landT / 8.0, 0, 1) * (n - 1)
			if fp >= 0.0:
				m4 = Spr.x4("tome/" + key + ":" + Spr.seqkey(range(n)))
			if not m4.is_empty():
				var q4: Array = Spr.x4_pos(m4, fp)
				tx3 = m4.tex
				src3 = Spr.x4_src(m4, q4[0])
				src4 = Spr.x4_src(m4, q4[1])
				k4 = smoothstep(.5, 1.0, q4[2]) * .5 if q4[1] != q4[0] else 0.0
			# meia-volta em "3D": no meio da virada ele aparece de frente (pose de corpo inteiro, com volume),
			# em vez de afinar como uma folha; dos lados, o corpo só estreita um pouco
			var front_t: bool = float(tst[2]) > .2 and float(tst[2]) < .8 and Spr.anim.has("lookback") and not wsl
			if front_t:
				var la: Dictionary = Spr.anim["lookback"]
				var lsz: float = float(la.s)
				var kl: float = 78.0 / lsz
				tx3 = la.tex
				src3 = Rect2(0, 0, lsz, lsz)
				dst3 = Rect2(-lsz / 2, -lsz, lsz, lsz)
				m4 = {}
				fnext = -1
				k4 = 0.0
				sz = lsz
				var nf3: float = 1.0 if p.face > 0 else -1.0
				sx3 = nf3 * kl * (1 + sq3 * .2) * st.x * (.94 + .06 * abs(cos(PI * float(tst[2]))))
				sy3 = kl * (1 - sq3 * .25) * st.y * (1.0 - tdip) * dk3
				fp = -1.0
			# peso: sobe-e-desce da passada (baixo no apoio), lanterna e pompom nas molas, meia-volta na grade
			var bob3: float = _gait_bob(p, key, fp) if p.onGround else 0.0
			_mg_springs(g, p, bob3)
			_mg_setup(sz, sz, _mg_anchor(key, fp) if fp >= 0.0 else [], bob3, 82.0)
			_turn_mg(p, tst)
			# a sombra respira com o passo: mais larga e escura no apoio
			var bn: float = bob3 / 8.0
			# (no ar não tem sombra: ela ficava "voando" junto, debaixo dos pés)
			if p.onGround:
				Polish.shadow(cx, by + 1, 16 * air3 * (1.0 + .07 * bn), 4 * air3, .25 * air3 * (1.0 + .15 * bn))
			# na parede: o corpo afasta um palmo (só a mão encosta) e inclina para fora, tremendo com o atrito
			var cx3: float = cx + p.face * 8.0 * wk
			var rot3: float = p.lean + (p.face * .1 + sin(T * 1.1) * .012) * wk + p.face * (1.0 - dk3) * .35
			_pose("wall" if wsl else key, tx3, src3, dst3, cx3, by, rot3, sx3, sy3)
			# vento forte com ele parado: a ponta do cachecol voa para o lado do vento
			var wnd: float = g.AMB.get("wind", 0.0)
			if wnd > .3 and key in ["idle", "look", "lantern", "shiver", "rain"]:
				Spr.save()
				Spr.translate(cx, by)
				Spr.rotate(p.lean)
				Spr.scale(-.48 if wnd > 0 else .48, .48)   # o vento sopra para a direita: a ponta vai para lá
				_scarf(p, clamp(abs(wnd), .4, 1.0))
				Spr.restore()
			# J10 rastro de velocidade: um "borrão" do próprio desenho logo atrás quando corre no máximo
			if abs(p.vx) > 5.2 and not g.low_fx:
				for si in 2:
					var so: float = -p.vx * (1.6 + si * 1.8)
					Spr.save()
					Spr.translate(cx + so, by)
					Spr.rotate(p.lean)
					Spr.scale(sx3 * 1.04, sy3)
					Spr.ci.draw_texture_rect_region(tx3, dst3, src3, Color(1, 1, 1, Spr.alpha * (.16 - si * .07)))
					Spr.restore()
			Spr.save()
			Spr.translate(cx3, by)
			Spr.rotate(rot3)
			Spr.scale(sx3, sy3)
			_mg_prep(dst3)
			_mg_layer(tx3, src3, Spr.alpha)
			if not m4.is_empty():
				if k4 > .02:
					_mg_layer(tx3, src4, Spr.alpha * k4)
			elif fnext >= 0 and fmix > .2:
				# mistura com o próximo quadro: o passo fica contínuo (sem "pulos" entre quadros)
				_mg_layer(a.tex, Rect2(fnext * sz, 0, sz, sz), Spr.alpha * smoothstep(.2, 1.0, fmix) * .55)
			Spr.restore()
			if not front_t:
				_turn_other(p, tst, tx3, src3, dst3, cx3, by, rot3, sx3, sy3)
			_armor(p, cx, by)
			return
	# folhas de sprites antigas (parado, andar, pulo, planar, mergulho)
	var tex := pai
	var fr := 0
	if hurt_on:
		tex = pai2
		fr = 8
	elif p.puff:
		tex = pai2
		fr = [0, 1][(T / 14) % 2]
	elif p.slam:
		tex = pai2
		fr = [4, 7][(T / 6) % 2]
	elif not p.onGround:
		fr = 4 if p.vy < -3 else (6 if p.vy < 2 else 7)
	elif abs(p.vx) > .4:
		fr = [1, 2, 3, 2][int(p.anim * (1.6 if p.run else 1.2)) % 4]
	else:
		fr = 0
	# quadros intermediários (x4) dos ciclos da folha antiga
	var otex: Texture2D = tex
	var osrc := Rect2(fr * 170, 0, 170, 160)
	var om: Dictionary = {}
	var ofp := 0.0
	if not hurt_on:
		if p.puff:
			om = Spr.x4("pai2:0-1")
			ofp = T / 14.0
		elif p.slam:
			om = Spr.x4("pai2:4-7")
			ofp = T / 6.0
		elif p.onGround and abs(p.vx) > .4:
			om = Spr.x4("pai:1-2-3-2")
			ofp = p.anim * (1.6 if p.run else 1.2)
	if not om.is_empty():
		otex = om.tex
		osrc = Spr.x4_src(om, Spr.x4_pos(om, ofp)[0])
	var air: float = clamp(1 - abs(p.vy) / 16.0, .3, 1)
	if p.onGround:
		Polish.shadow(cx, by + 1, 16 * air, 4 * air, .25 * air)
	if p.puff:
		Spr.glow(cx, by - 30, 50, Color(1, .96, .82, .55))
	if p.run and p.onGround:
		for k in 3:
			var yy: float = by - 44 + k * 12
			Spr.seg(cx - p.face * (20 + k * 4), yy, cx - p.face * (40 + k * 6), yy, Color(.94, .9, .78, .5), 2)
	var sc := .48
	var sq: float = p.squash
	var idle := sin(T * .08) * .025 if (fr == 0 and tex == pai and p.onGround) else 0.0
	# cansado depois de correr muito: respira rápido e fundo, curvado para a frente
	var pant: float = p.get("pant", 0) / 150.0
	if pant > 0 and fr == 0 and tex == pai:
		idle = sin(T * .32) * .05 * pant - .02 * pant
	var rim2 := _rim(g, p)
	_body_flex(p, "old", fr, 4)
	var rot0: float = p.lean + (p.face * .06 * pant if (pant > 0 and fr == 0 and tex == pai) else 0.0) + p.face * (1.0 - float(p.get("duck", 1.0))) * .35
	var dk0: float = float(p.get("duck", 1.0))
	# meia-volta com volume (como nas animações novas): estreita girando e abre do outro lado
	var sx0: float = float(tst[0]) * sc * (1 + sq * .25) * float(tst[1]) * (1.0 + (1.0 - dk0) * .3)
	var sy0: float = sc * (1 - sq * .3 + idle) * (1.0 - .05 * sin(PI * float(tst[2]))) * dk0
	# parado: lanterna e pompom continuam nas molas (balançam depois de parar ou virar)
	_mg_springs(g, p, 0.0)
	_mg_setup(170.0, 160.0, _mg_anchor("pai", 0.0) if (tex == pai and fr == 0 and om.is_empty()) else [], 0.0, 52.0)
	_turn_mg(p, tst)
	_pose("old%d_%d" % [tex.get_instance_id(), fr], otex, osrc, Rect2(-85, -156, 170, 160), cx, by, rot0, sx0, sy0)
	# J10 mergulho: borrão vertical acima do corpo
	if p.slam and p.vy > 6 and not g.low_fx:
		for si in 2:
			Spr.save()
			Spr.translate(cx, by - p.vy * (1.4 + si * 1.6))
			Spr.rotate(rot0)
			Spr.scale(sx0, sy0 * 1.06)
			Spr.ci.draw_texture_rect_region(otex, Rect2(-85, -156, 170, 160), osrc, Color(1, 1, 1, Spr.alpha * (.18 - si * .08)))
			Spr.restore()
	for pass_i in (2 if rim2.a > 0 else 1):
		var rimp: bool = pass_i == 0 and rim2.a > 0
		Spr.save()
		Spr.translate(cx + (rim_off.x if rimp else 0.0), by + (rim_off.y if rimp else 0.0))
		Spr.rotate(rot0)
		Spr.scale(sx0, sy0)
		if rimp:
			Spr.ci.draw_texture_rect_region(Spr.sil(otex), Rect2(-85, -156, 170, 160), osrc, Color(rim2.r, rim2.g, rim2.b, rim2.a * Spr.alpha))
		else:
			if tex == pai and (abs(p.vx) > 2.2 or not p.onGround):
				_scarf(p)
			_mg_prep(Rect2(-85, -156, 170, 160))
			_mg_layer(otex, osrc, Spr.alpha)
			if tex == pai and fr == 0 and float(tst[2]) >= 1.0:
				_blink(p)
		Spr.restore()
	_turn_other(p, tst, otex, osrc, Rect2(-85, -156, 170, 160), cx, by, rot0, sx0, sy0)
	_armor(p, cx, by)
	if not p.onGround and not p.vine and not p.ladder and p.airJumps > 0:
		Spr.ring(cx, by + 7, 4, Color(.92, .88, .76, .55), 1.5)

# ---------- o Tomé de "borracha": o quadro pintado desenhado numa grade que dobra ----------
## Em vez de só esticar o quadro inteiro (cara de boneco de papel), o desenho vai numa grade de triângulos
## e cada ponto pode andar um pouco: a lanterna balança presa na mão, o pompom do gorro sacode com atraso,
## o corpo desce no apoio do passo sem tirar o pé do chão, na meia-volta o alto do corpo atrasa e os pés
## adiantam, as pernas batem no nado; e o lado que gira para longe escurece (sombra da rotação).
const MG_C := 16
const MG_R := 16
const TURN_N := 10      # passos da meia-volta (rápida: a física vira na hora, só o desenho gira)
## pontos de cada quadro (em pixels do quadro pintado): mão que segura a lanterna (x, y), centro da lanterna (x, y)
## e o pompom do gorro (x, y) — medidos nas folhas assets/sprites/tome/*.png e pai.png (quadro 0)
const MG_PTS := {
	"walk": [[201, 110, 201, 150, 73, 56], [200, 110, 200, 150, 75, 56], [197, 108, 197, 148, 77, 56], [200, 112, 200, 152, 75, 56], [199, 106, 199, 146, 75, 56], [187, 118, 187, 158, 85, 52], [188, 105, 188, 145, 83, 55], [198, 108, 198, 148, 78, 56]],
	"run": [[200, 114, 200, 154, 75, 62], [200, 114, 200, 154, 76, 62], [200, 120, 200, 160, 76, 62], [198, 116, 198, 156, 75, 62], [197, 109, 197, 149, 76, 62], [183, 113, 183, 153, 90, 57], [188, 110, 188, 150, 84, 61], [196, 110, 196, 150, 80, 61]],
	"jump": [[204, 92, 204, 132, 68, 52], [194, 114, 194, 154, 64, 49], [197, 84, 197, 124, 68, 42]],
	"fall": [[197, 84, 197, 124, 68, 42], [185, 86, 185, 126, 85, 14]],
	"land": [[188, 123, 188, 163, 75, 63], [196, 119, 196, 159, 68, 64], [189, 100, 189, 140, 66, 60]],
	"pai": [[138, 64, 138, 90, 54, 30]],
}
var _mg_idx := PackedInt32Array()
var _mg_fr := PackedVector2Array()      # posição de cada ponto da grade (0..1 no quadro)
var _mg_pts := PackedVector2Array()
var _mg_csh: Array[Color] = []          # cor de cada coluna (sombra da rotação)
var _mg_shade := false
var _mg_flat := true
var _mg_dst := Rect2()
var _mg_uvc := {}                         # coordenadas de textura já calculadas, por quadro
var _mg_col := PackedColorArray()
## deformação do desenho atual (preenchida antes de desenhar; em pixels do quadro pintado)
var MG := {}
## molas (no espaço do desenho virado para a frente): lanterna (ângulo) e pompom (deslocamento)
var _lan_a := 0.0
var _lan_v := 0.0
var _pom := Vector2.ZERO
var _pom_v := Vector2.ZERO
var _sp_vx := 0.0
var _sp_vy := 0.0
var _sp_bob := 0.0
var _sp_bobv := 0.0
var _sp_tick := -1
var _mg_face := 1.0     # para que lado o desenho está virado (troca no meio da meia-volta)
var _light_k := 1.0     # lado da luz no corpo: 1/-1 virado, perto de 0 no meio da meia-volta

func _mg_init() -> void:
	if not _mg_idx.is_empty():
		return
	for j in MG_R + 1:
		for i in MG_C + 1:
			_mg_fr.push_back(Vector2(float(i) / MG_C, float(j) / MG_R))
	for j in MG_R:
		for i in MG_C:
			var a: int = j * (MG_C + 1) + i
			_mg_idx.append_array([a, a + 1, a + MG_C + 2, a, a + MG_C + 2, a + MG_C + 1])
	var nv: int = (MG_C + 1) * (MG_R + 1)
	_mg_pts.resize(nv)
	_mg_csh.resize(MG_C + 1)
	_mg_col.resize(nv)

## pontos de lanterna/pompom no quadro (mistura entre dois quadros pintados para os intermediários)
func _mg_anchor(key: String, fpos: float) -> Array:
	var tb: Array = MG_PTS.get(key, [])
	if tb.is_empty():
		return []
	var n: int = tb.size()
	var cyc: bool = key == "walk" or key == "run"
	var f0: int = posmod(int(floor(fpos)), n) if cyc else clampi(int(floor(fpos)), 0, n - 1)
	var f1: int = (f0 + 1) % n if cyc else mini(f0 + 1, n - 1)
	var u: float = fpos - floor(fpos)
	var a: Array = tb[f0]
	var b: Array = tb[f1]
	var out: Array = []
	for k in 6:
		out.append(lerpf(float(a[k]), float(b[k]), u))
	return out

## prepara a deformação para um quadro de fw x fh pixels
func _mg_setup(fw: float, fh: float, anc: Array, bob: float, hip: float) -> void:
	MG = {"fw": fw, "fh": fh, "bob": bob, "hip": hip, "tl": 0.0, "tf": 0.0, "sh": 0.0, "kick": 0.0, "kph": 0.0, "la": 0.0, "pd": Vector2.ZERO}
	var k: float = fw / 256.0
	if anc.size() == 6:
		MG.lpx = anc[0]
		MG.lpy = anc[1]
		MG.lcx = anc[2]
		MG.lcy = anc[3]
		MG.lrx = 21.0 * k
		MG.lry = 36.0 * k
		MG.la = _lan_a
		MG.pmx = anc[4]
		MG.pmy = anc[5]
		MG.pd = _pom * k

## calcula a grade deformada no retângulo dst (uma vez por desenho; as camadas reaproveitam).
## Feito para ser barato no celular: o que depende só da altura (passo, meia-volta, pernas no nado) é
## calculado uma vez por linha; lanterna e pompom só mexem nos pontos dentro da caixinha deles.
func _mg_prep(dst: Rect2) -> void:
	_mg_init()
	var fw: float = MG.fw
	var fh: float = MG.fh
	var kx: float = dst.size.x / fw
	var ky: float = dst.size.y / fh
	var ox: float = dst.position.x
	var oy: float = dst.position.y
	var bob: float = MG.bob
	var hip: float = MG.hip
	var tl: float = MG.tl
	var tf: float = MG.tf
	var kick: float = MG.kick
	var kph: float = MG.kph
	var hy: float = fh - hip
	var c1: int = MG_C + 1
	var cw: float = fw / MG_C
	var rh: float = fh / MG_R
	var flat := true
	for j in MG_R + 1:
		var y: float = j * rh
		var hgt: float = fh - y
		var dx := 0.0
		var dy := 0.0
		# passo: o corpo desce no apoio e sobe na passagem, com o pé preso no chão (as pernas dobram)
		if bob != 0.0:
			dy += bob * smoothstep(fh * .03, hip, hgt)
		# meia-volta: o alto (gorro, barba, lanterna) atrasa, os pés dão o passinho para o lado novo
		if tl != 0.0 or tf != 0.0:
			var u: float = clamp(hgt / fh, 0.0, 1.0)
			var lo: float = 1.0 - u
			dx += tl * u * u + tf * lo * lo * lo
		# nado: as pernas batem (uma onda descendo da cintura até os pés)
		if kick != 0.0 and y > hy:
			dx += kick * smoothstep(hy, hy + hip * .6, y) * sin(kph - (y - hy) * .07)
		if dx != 0.0 or dy != 0.0:
			flat = false
		var py: float = oy + (y + dy) * ky
		var b: int = j * c1
		for i in c1:
			_mg_pts[b + i] = Vector2(ox + (i * cw + dx) * kx, py)
	# lanterna: gira presa na mão (só os pontos em volta dela)
	var la: float = MG.la
	if abs(la) > .002:
		flat = false
		var lcx: float = MG.lcx
		var lcy: float = MG.lcy
		var lrx: float = MG.lrx
		var lry: float = MG.lry
		var lpx: float = MG.lpx
		var lpy: float = MG.lpy
		var c: float = cos(la)
		var s: float = sin(la)
		var i0: int = maxi(0, int(floor((lcx - lrx * 1.5) / cw)))
		var i1: int = mini(MG_C, int(ceil((lcx + lrx * 1.5) / cw)))
		var j0: int = maxi(0, int(floor(max(lcy - lry * 1.5, lpy - 6.0) / rh)))
		var j1: int = mini(MG_R, int(ceil((lcy + lry * 1.5) / rh)))
		for j in range(j0, j1 + 1):
			var y: float = j * rh
			var wy: float = smoothstep(lpy - 6.0, lpy + 8.0, y)
			if wy <= 0.0:
				continue
			var ly: float = (y - lcy) / lry
			var ry: float = y - lpy
			for i in range(i0, i1 + 1):
				var x: float = i * cw
				var lx: float = (x - lcx) / lrx
				var r: float = sqrt(lx * lx + ly * ly)
				if r >= 1.5:
					continue
				var w: float = (1.0 - smoothstep(1.0, 1.5, r)) * wy
				var rx: float = x - lpx
				_mg_pts[j * c1 + i] += Vector2((rx * c - ry * s - rx) * w * kx, (rx * s + ry * c - ry) * w * ky)
	# pompom: sacode com atraso (a ponta do gorro estica junto)
	var pd: Vector2 = MG.pd
	if pd.length_squared() > .01:
		flat = false
		var k2: float = fw / 256.0
		var pmx: float = MG.pmx
		var pmy: float = MG.pmy
		var rr: float = 30.0 * k2
		var i0: int = maxi(0, int(floor((pmx - rr) / cw)))
		var i1: int = mini(MG_C, int(ceil((pmx + rr) / cw)))
		var j0: int = maxi(0, int(floor((pmy - rr) / rh)))
		var j1: int = mini(MG_R, int(ceil((pmy + rr) / rh)))
		var pk := Vector2(pd.x * kx, pd.y * ky)
		for j in range(j0, j1 + 1):
			for i in range(i0, i1 + 1):
				var pr: float = Vector2(i * cw - pmx, j * rh - pmy).length()
				if pr < rr:
					_mg_pts[j * c1 + i] += pk * (1.0 - smoothstep(7.0 * k2, rr, pr))
	# sombra da rotação: o lado de trás (que está indo para longe) escurece, mais na borda (por coluna)
	var sh: float = MG.sh
	_mg_shade = sh > .01
	if _mg_shade:
		flat = false
		for i in c1:
			var v: float = sh * clamp((fw * .52 - i * cw) / (fw * .34), 0.0, 1.0)
			_mg_csh[i] = Color(1.0 - .42 * v, 1.0 - .4 * v, 1.0 - .28 * v, 1.0)
	_mg_flat = flat
	_mg_dst = dst

## desenha uma camada (quadro src da textura) na grade preparada
func _mg_layer(tex: Texture2D, src: Rect2, a: float) -> void:
	if _mg_flat:
		# nada dobrando agora (parado, molas em repouso): desenho simples
		Spr.ci.draw_texture_rect_region(tex, _mg_dst, src, Color(1, 1, 1, a))
		return
	# coordenadas de textura de cada quadro guardadas (os ciclos repetem os mesmos quadros)
	var key := Vector4(src.position.x, src.position.y, src.size.x, float(tex.get_instance_id() % 1000003))
	var uv: PackedVector2Array = _mg_uvc.get(key, PackedVector2Array())
	if uv.is_empty():
		if _mg_uvc.size() > 600:
			_mg_uvc.clear()
		var ts: Vector2 = tex.get_size()
		uv.resize(_mg_fr.size())
		for i in _mg_fr.size():
			var q: Vector2 = _mg_fr[i]
			uv[i] = Vector2((src.position.x + q.x * src.size.x) / ts.x, (src.position.y + q.y * src.size.y) / ts.y)
		_mg_uvc[key] = uv
	if _mg_shade:
		var c1: int = MG_C + 1
		for j in MG_R + 1:
			var b: int = j * c1
			for i in c1:
				var cc: Color = _mg_csh[i]
				cc.a = a
				_mg_col[b + i] = cc
	else:
		_mg_col.fill(Color(1, 1, 1, a))
	RenderingServer.canvas_item_add_triangle_array(Spr.ci.get_canvas_item(), _mg_idx, _mg_pts, _mg_col, uv, PackedInt32Array(), PackedFloat32Array(), tex.get_rid())

## molas da lanterna, do pompom e do sobe-e-desce (uma vez por passo da lógica)
func _mg_springs(g: Game, p: Dictionary, bob: float) -> void:
	if _sp_tick == T:
		return
	# passos da lógica desde a última vez (a tela pode desenhar só a cada 2 passos)
	var steps: int = T - _sp_tick
	_sp_tick = T
	var ax: float = p.vx - _sp_vx
	var ay: float = p.vy - _sp_vy
	_sp_vx = p.vx
	_sp_vy = p.vy
	var bv: float = bob - _sp_bob
	_sp_bob = bob
	if steps <= 0 or steps > 4 or abs(ax) > 4.0 * steps or abs(ay) > 14.0 * steps:
		# voltou de pausa/teleporte: sem solavanco
		_sp_bobv = 0.0
		return
	ax /= steps
	ay /= steps
	bv /= steps
	var ba: float = bv - _sp_bobv
	_sp_bobv = bv
	var axl: float = ax * _mg_face
	var gait: float = float(p.get("gait", 0.0))
	var drive: float = 0.0
	if p.onGround and abs(p.vx) > .5:
		drive = sin(gait * PI) * .006 * clamp(abs(p.vx) / 4.3, 0.0, 1.4)
	var acc := Vector2(axl * 2.6, ay * 1.6 + ba * 1.0)
	for i in steps:
		# lanterna: pêndulo (fica para trás na arrancada, vai para a frente na freada); o passo dá um embalo
		_lan_v += -.034 * _lan_a - .085 * _lan_v + axl * .032 + drive - ba * .002
		if p.swim:
			_lan_v *= .9
		_lan_a = clamp(_lan_a + _lan_v, -.75, .75)
		# pompom: mola em duas direções (para trás na arrancada, para baixo ao pousar e no apoio do passo)
		_pom_v += -_pom * .11 - _pom_v * .16 - acc * .5
		_pom = (_pom + _pom_v).limit_length(16.0)

## a meia-volta: [lado desenhado, largura (1 = normal), progresso 0..1 (1 = sem virada)]
func _turn_state(g: Game, p: Dictionary) -> Array:
	var tt: int = int(p.get("turnT", 0))
	if tt <= 0:
		return [1.0 if p.face > 0 else -1.0, 1.0, 1.0]
	var u: float = clamp((TURN_N - tt - 1 + g.ifrac()) / float(TURN_N - 1), 0.0, 1.0)
	var fr: float = float(p.get("tfrom", -p.face))
	var df: float = fr if u < .5 else (1.0 if p.face > 0 else -1.0)
	# gira em torno do eixo do corpo: estreita até a metade (sem ficar fino como papel: o corpo tem
	# grossura) e abre do outro lado
	var wf: float = .72 + .28 * abs(cos(PI * u))
	return [df, wf, u]

## no meio da meia-volta o outro lado aparece por cima, sumindo (o corpo de frente, sem "estalo" ao espelhar)
func _turn_cross(ts: Array) -> float:
	var u: float = ts[2]
	if u >= 1.0:
		return 0.0
	return .6 * (1.0 - smoothstep(0.0, .14, abs(u - .5)))

## liga a meia-volta na deformação (alto atrasa, pés adiantam, lado de trás escurece)
func _turn_mg(p: Dictionary, ts: Array) -> void:
	var u: float = ts[2]
	if u >= 1.0:
		return
	var s: float = sin(PI * u)
	var fr: float = float(p.get("tfrom", -p.face))
	var df: float = ts[0]
	var nf: float = 1.0 if p.face > 0 else -1.0
	var k: float = MG.fw / 256.0
	MG.tl = fr * df * 20.0 * k * s
	MG.tf = nf * df * 12.0 * k * s
	MG.sh = s * .75

## o outro lado por cima no meio da meia-volta (mesma grade, espelhada)
func _turn_other(p: Dictionary, ts: Array, tex: Texture2D, src: Rect2, dst: Rect2, x: float, y: float, rot: float, sx: float, sy: float) -> void:
	var a: float = _turn_cross(ts)
	if a <= .02:
		return
	_turn_mg(p, [-float(ts[0]), ts[1], ts[2]])
	_mg_prep(dst)
	Spr.save()
	Spr.translate(x, y)
	Spr.rotate(rot)
	Spr.scale(-sx, sy)
	_mg_layer(tex, src, Spr.alpha * a)
	Spr.restore()

## troca do lado desenhado: as molas são espelhadas (a lanterna continua para onde ia) e ganham o embalo da volta
func _mg_flip(df: float) -> void:
	if df == _mg_face:
		return
	_mg_face = df
	_lan_a = -_lan_a
	_lan_v = -_lan_v + .07
	_pom = Vector2(-_pom.x, _pom.y)
	_pom_v = Vector2(-_pom_v.x + 1.6, _pom_v.y - .6)

## sobe-e-desce da passada (em pixels do quadro de 256; + = para baixo): baixo no apoio, alto na passagem
func _gait_bob(p: Dictionary, key: String, fp: float) -> float:
	if key != "walk" and key != "run":
		return 0.0
	var amp: float = (8.0 if key == "run" else 5.5) * clamp(abs(p.vx) / 4.3, 0.0, 1.0)
	return amp * cos(TAU * (fp - .1) / 4.0)

## corpo vivo: inclinação suave (acompanha a velocidade, sem tranco), esticar no pulo,
## sobe-e-desce do passo (sem tirar o pé do chão: estica/encolhe a partir da sola)
func _body_flex(p: Dictionary, key: String, f: int, n: int) -> Vector2:
	if not p.has("lean"):
		p.lean = 0.0
	var lt: float = 0.0
	if p.onGround:
		lt = p.vx / 6.6 * (.075 if p.run else .05)
		if p.skidT > 0:
			lt = p.vx / 6.6 * .2
	else:
		lt = p.vx / 6.6 * .07 + clamp(p.vy / 13.0, -1, 1) * .025 * sign(p.vx)
	# N7 planando: balança devagar no ar
	if p.puff:
		lt += sin(T * .07) * .07 + float(game.AMB.get("wind", 0.0)) * .04
	# N10 empurrando: corpo jogado para a frente, tremendo de força
	if p.get("pushT", 0) > 0 and p.onGround:
		lt += p.face * .1 + sin(T * 1.3) * .012
	if FRESH:
		# inclinação com peso (mola): na arrancada o corpo vai para a frente na medida da aceleração;
		# na freada o corpo continua para a frente (inércia) e volta, passando um tiquinho para trás
		var acc: float = p.vx - float(p.get("lvx", p.vx))
		p.lvx = p.vx
		if abs(acc) > 2.5:
			acc = 0.0
		var force: float = 0.0
		if p.onGround and abs(acc) > .02 and not p.swim:
			if abs(p.vx) > .3 and sign(acc) == sign(p.vx):
				force = acc * .016
			else:
				force = -acc * .02
		var lv: float = float(p.get("leanv", 0.0)) * .78 + (lt - float(p.get("lean", 0.0))) * .12 + force
		p.leanv = lv
		p.lean = clamp(float(p.get("lean", 0.0)) + lv, -.3, .3)
	var sy: float = 1.0
	if not p.onGround and not p.vine and not p.ladder:
		if p.vy < 0:
			sy = 1 + clamp(-p.vy / 12.0, 0, 1) * .07
		else:
			sy = 1 + clamp((p.vy - 5) / 8.0, 0, 1) * .05
	# (andar/correr: o sobe-e-desce do passo agora é feito na grade do desenho, ver _gait_bob)
	var st: float = lerp(float(p.get("flex", 1.0)), sy, .35) if FRESH else float(p.get("flex", 1.0))
	p.flex = st
	return Vector2(1 - (st - 1) * .8, st)

## troca de pose sem salto: a pose anterior some aos poucos por baixo da nova (alguns quadros)
var _pose_last := {}
var _ghost := {}
var _ghostT := 0
var _ghost_tick := -1
var _ppos := Vector2.ZERO
const GHOST_N := 5
func _pose(key: String, tex: Texture2D, src: Rect2, dst: Rect2, x: float, y: float, rot: float, sx: float, sy: float) -> void:
	if _ghost_tick != T:
		_ghost_tick = T
		if _ghostT > 0:
			_ghostT -= 1
		if _pose_last.has("key") and _pose_last.key != key and T - int(_pose_last.t) <= 2:
			_ghost = _pose_last
			_ghostT = GHOST_N
	if _ghostT > 0 and not _ghost.is_empty():
		var a: float = float(_ghostT) / (GHOST_N + 1) * .6
		Spr.save()
		Spr.translate(_ppos.x + _ghost.off.x, _ppos.y + _ghost.off.y)
		Spr.rotate(_ghost.rot)
		Spr.scale(_ghost.sx, _ghost.sy)
		Spr.ci.draw_texture_rect_region(_ghost.tex, _ghost.dst, _ghost.src, Color(1, 1, 1, a * Spr.alpha))
		Spr.restore()
	_pose_last = {"key": key, "tex": tex, "src": src, "dst": dst, "rot": rot, "sx": sx, "sy": sy, "t": T, "off": Vector2(x, y) - _ppos}

## ponta do cachecol esvoaçando para trás quando corre ou pula (atrás do corpo)
func _scarf(p: Dictionary, force: float = -1.0) -> void:
	var sp: float = clamp(abs(p.vx) / 6.0, .4, 1.0) if force < 0.0 else force
	var pts_top := PackedVector2Array()
	var pts_bot := PackedVector2Array()
	var n := 7
	for i in n + 1:
		var u := float(i) / n
		var x: float = -18 - u * 46 * sp
		var y: float = -88 + u * (14 - sp * 10) + sin(T * .45 - u * 4.0) * 7 * u
		var wd: float = 8.0 - u * 2.0
		pts_top.push_back(Vector2(x, y - wd * .5))
		pts_bot.push_back(Vector2(x, y + wd * .5))
	# listras verdes e creme, como o cachecol do Tomé
	for i in n:
		var c := Color(.33, .55, .2) if i % 2 == 0 else Color(.93, .86, .55)
		var q := PackedVector2Array([pts_top[i], pts_top[i + 1], pts_bot[i + 1], pts_bot[i]])
		Spr.ci.draw_colored_polygon(q, Color(c.r, c.g, c.b, Spr.alpha))
	var outl := PackedVector2Array(pts_top)
	for i in range(n, -1, -1):
		outl.push_back(pts_bot[i])
	outl.push_back(pts_top[0])
	Spr.ci.draw_polyline(outl, Color(.12, .1, .05, Spr.alpha), 2.0, true)
	# franjinha na ponta
	var tip: Vector2 = (pts_top[n] + pts_bot[n]) / 2
	for k in 3:
		Spr.ci.draw_line(tip + Vector2(0, (k - 1) * 3), tip + Vector2(-6, (k - 1) * 3.5 + 1), Color(.93, .86, .55, Spr.alpha), 1.5)

## o Tomé parado reage ao mundo: cansado, olhando para cima, protegendo-se da chuva, tremendo de frio
## ou erguendo a lanterna no escuro
func _reaction(g: Game, p: Dictionary) -> String:
	if p.crouch or p.swim or p.get("act", "") != "" and p.actT > 0:
		return "idle"
	if p.get("pant", 0) > 0:
		return "tired"
	if p.lookT > 0:
		return "look"
	var it: int = p.get("idleT", 0)
	if g.get("bird_near") and it > 10:
		return "look"
	if (g.indoors() or g.AMB.dark > .5) and it > 50:
		return "lantern"
	if g.AMB.rain > .45 and not g.indoors() and it > 30:
		return "rain"
	if g.AMB.get("snow", 0.0) > .3 and it > 90:
		return "shiver"
	# parado há muito tempo: de vez em quando fica curioso, olhando em volta
	if it > 420 and (it - 420) % 360 < 60 and Spr.anim.has("lookback"):
		return "lookback"
	return "idle"

## contorno de luz: de dia vem do sol (de cima, atrás), à noite da lanterna (da frente)
var rim_off := Vector2.ZERO
func _rim(g: Game, p: Dictionary) -> Color:
	# o contorno por fora (silhueta clara atrás) deixava o Tomé com cara de papel recortado;
	# agora a luz e a sombra são feitas por dentro do desenho (scripts/depth.gdshader)
	if true:
		return Color(0, 0, 0, 0)
	if p.swim or p.dyingT > 0 or p.get("hitT", 0) > 0:
		return Color(0, 0, 0, 0)
	var dark: float = g.AMB.dark
	if g.L.has("under") and p.y > g.L.under:
		dark = 1.0
	if dark > .3:
		rim_off = Vector2(p.face * 1.6, -1.0)
		return Color(1, .78, .45, .55)
	rim_off = Vector2(-1.8, -1.6)
	var tw: float = g.section_weights().get("tarde", 0.0)
	return Color(1, .95, .78).lerp(Color(1, .72, .4), tw) * Color(1, 1, 1, .7)

## piscadinha: de vez em quando as pálpebras descem sobre os olhos (só na pose parada)
func _blink(p: Dictionary) -> void:
	var t: int = (T + int(p.x)) % 220
	var c: float = 0.0
	if t < 8:
		c = 1.0 - abs(t - 4) / 4.0
	elif t > 30 and t < 36 and (T / 220) % 3 == 0:
		c = 1.0 - abs(t - 33) / 3.0
	if c <= 0:
		return
	var skin := Color(.96, .69, .53)
	for e in [Vector2(5, -101), Vector2(21, -102)]:
		Spr.ci.draw_rect(Rect2(e.x - 4.5, e.y - 5, 9, 9 * c + .5), skin)
		Spr.ci.draw_line(Vector2(e.x - 4, e.y - 5 + 9 * c), Vector2(e.x + 4, e.y - 5 + 9 * c), Color(.35, .2, .15), 1.6)

func _armor(p: Dictionary, cx: float, by: float) -> void:
	if p.armor > 0:
		# escudo: um brilho quente e macio que respira, com faíscas douradas girando em volta
		var pu: float = .5 + .5 * sin(T * .07)
		Spr.glow(cx, by - 30, 44 + pu * 6, Color(1, .85, .5, .16 + pu * .08))
		for i in 6:
			var a: float = T * .045 + TAU * i / 6.0
			var r2: float = 24 + sin(T * .09 + i) * 3
			var sx: float = cx + cos(a) * r2
			var sy: float = by - 30 + sin(a) * r2 * 1.25
			var tw: float = .5 + .5 * sin(T * .2 + i * 1.7)
			Spr.glow(sx, sy, 6, Color(1, .9, .55, .35 * tw))
			Spr.circle(sx, sy, 1.3 + tw * .6, Color(1, .95, .7, .85 * tw))


## porta redonda de ferro do cofre do Vargas (fim do Episódio 2), com o V gravado
func _vault(cx: float, gy: float) -> void:
	var cy: float = gy - 118
	Spr.rect(cx - 150, gy - 250, 300, 250, Color("#3a3530"))
	for k in 6:
		Spr.rect(cx - 150 + k * 50, gy - 250, 48, 248, Color(.27 + .03 * (k % 2), .25, .23))
	Spr.circle(cx, cy, 116, Color("#1c1a18"))
	Spr.circle(cx, cy, 108, Color("#6a6e74"))
	Spr.circle(cx, cy, 96, Color("#55595f"))
	for k in 16:
		var a: float = k * TAU / 16
		Spr.circle(cx + cos(a) * 102, cy + sin(a) * 102, 4, Color("#8a8e96"))
	# o V gravado
	Spr.ci.draw_polyline(PackedVector2Array([Vector2(cx - 46, cy - 50), Vector2(cx, cy + 46), Vector2(cx + 46, cy - 50)]), Color("#2a2c30"), 16)
	Spr.ci.draw_polyline(PackedVector2Array([Vector2(cx - 46, cy - 52), Vector2(cx, cy + 42), Vector2(cx + 46, cy - 52)]), Color("#b0a070"), 6)
	# o volante
	var wx: float = cx + 70
	Spr.ring(wx, cy + 10, 20, Color("#2a2c30"), 6)
	for k in 4:
		var a2: float = k * PI / 4 + .3
		Spr.seg(wx - cos(a2) * 20, cy + 10 - sin(a2) * 20, wx + cos(a2) * 20, cy + 10 + sin(a2) * 20, Color("#2a2c30"), 4)
	Spr.circle(wx, cy + 10, 5, Color("#8a8e96"))
