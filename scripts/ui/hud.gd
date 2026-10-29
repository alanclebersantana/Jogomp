extends Control
## HUD: corações, vidas, lápis, lápis especiais, tempo, nome da fase, desenhos, dica e avisos.

var game: Game
var hint_alpha := 0.0
var hint_txt := ""
var last_coins := -1
var coin_pop := 0.0
var last_hp := -1
var boss_name := ""
var boss_lag := 1.0
var boss_shk := 0.0
var boss_hold := 0
var lost_heart := -1
var lost_t := 0.0
var hint_cur := ""
var hint_show := 0.0
const HINT_FRAMES := 240.0
var hint_seen := {}
var last_hp2 := -1
var tex_face: Texture2D = preload("res://assets/ui/btn_tome.png")
var mobile: bool = OS.has_feature("mobile") or DisplayServer.is_touchscreen_available()
var ICON := {}
## altura atual das faixas de cinema (main.gd -> cinema_bars.gd)
var cine_bar := 0.0
## painel dos corações e placa do canto: desenhados num filho próprio para poder esmaecer e tingir
var stats: Control
var stats_a := 1.0
var idle_t := 0.0
var last_sig := []
var tint := Color(1, 1, 1)
## corações: efeitos por coração (rachar ao perder, inflar ao ganhar)
var heart_fx: Array = []
var heart_shake := 0.0
## nome do lugar ao entrar num trecho novo (uma vez por trecho em cada partida)
var place_seen := {}
var place_pending := ""
var place_wait := 0.0
var place_cur := ""
var place_t := -1.0
var bars_y := 0.0   # base das barras do alto (fôlego, vida do chefe) neste quadro
var msg_bot := 0.0  # base da dica / do aviso no alto neste quadro (o nome do lugar fica embaixo deles)
var place_y := -1.0
var place_ty := 92.0
const PLACE_DUR := 2.5
const PLACE_NAMES := {"manha": "O terminal", "tarde": "A segurança", "chuva": "O pátio", "rio": "O rio",
	"neve": "A neve", "ceu": "O céu", "noite": "Noite na mina", "perseguicao": "A perseguição", "tunel": "O túnel"}

func _ready() -> void:
	var m := {"G": "btn_golpe", "J": "btn_jump", "A": "btn_use", "U": "pad_U", "S": "pad_S", "L": "pad_L", "R": "pad_R", "Q": "btn_dog"}
	for k in m:
		ICON[k] = load("res://assets/ui/%s.png" % m[k])
	stats = _Stats.new()
	stats.hud = self
	stats.set_anchors_preset(Control.PRESET_FULL_RECT)
	stats.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stats.show_behind_parent = true
	add_child(stats)

class _Stats extends Control:
	var hud
	func _draw() -> void:
		hud._draw_stats(self)

## partida nova ou continuada: os nomes dos lugares aparecem de novo e os corações recomeçam
func reset_run() -> void:
	place_seen.clear()
	place_pending = ""
	place_cur = ""
	place_t = -1.0
	heart_fx.clear()
	last_hp = -1
	idle_t = 0.0
	last_sig = []
	stats_a = 1.0

## a dica sumiu mas o lugar ainda tem dica: o pergaminho pode trazê-la de volta
func can_replay() -> bool:
	return hint_cur != "" and hint_alpha <= 0.01

func show_hint_again() -> void:
	hint_show = 0.0

## no celular, as teclas viram o desenho do próprio botão dentro do texto
## (o texto das dicas e avisos é o mesmo por muitos quadros: troca de ícones, quebra de linha e
## larguras ficam guardadas em vez de refeitas a cada quadro)
var _ic_cache := {}
var _rl_cache := {}
var _ww_cache := {}
func _icons(t: String) -> String:
	if not mobile:
		return t
	if _ic_cache.has(t):
		return _ic_cache[t]
	if _ic_cache.size() > 200:
		_ic_cache.clear()
	var r0 := _icons_raw(t)
	_ic_cache[t] = r0
	return r0

func _icons_raw(t: String) -> String:
	var r := t
	for pair in [["GOLPE (botão do bastão / tecla G)", "GOLPE [G]"], ["(botão do bastão / tecla G)", "[G]"], ["(botão do bastão)", "[G]"], ["(botão da picareta)", "[G]"],
			["(tecla G)", "[G]"], ["PULAR (Z/espaço)", "PULAR [J]"], ["(botão da mala / tecla Q)", "[Q]"], ["(botão da mala / Q)", "[Q]"], ["(botão da mala)", "[Q]"],
			["(botão do cachorro)", "[Q]"], ["✦ USAR", "[A]"], ["✦", "[A]"], ["↑ + GOLPE", "[U] + [G]"], ["← →", "[L] [R]"], ["←/→", "[L] [R]"], ["↑/↓", "[U] [S]"],
			["↑ ↓ ← →", "[U] [S] [L] [R]"], ["↘", "[R]+[S]"], ["↑", "[U]"], ["↓", "[S]"], ["←", "[L]"], ["→", "[R]"]]:
		r = r.replace(pair[0], pair[1])
	# ícone sempre como palavra solta (sem parênteses grudados)
	for k in ICON:
		r = r.replace("([%s])" % k, "[%s]" % k).replace("[%s]" % k, " [%s] " % k)
	while r.find("  ") >= 0:
		r = r.replace("  ", " ")
	return r.replace(" ,", ",").replace(" .", ".").replace(" !", "!").strip_edges()

## quebra de linha com ícones: cada linha é uma lista de palavras ("[G]" vira um ícone)
## (as larguras são medidas com a MESMA fonte do desenho; medir com a itálica e desenhar com a
## normal, mais larga, grudava as palavras: "sobreo bosque", "escuro...Sem")
func _rlines(t: String, maxw: float, fs: int, f: Font = null) -> Array:
	var ff: Font = f if f else Spr.font_i
	var key := "%s|%d|%d|%d" % [t, int(maxw), fs, ff.get_instance_id()]
	if _rl_cache.has(key):
		return _rl_cache[key]
	if _rl_cache.size() > 200:
		_rl_cache.clear()
	var res := _rlines_raw(t, maxw, fs, ff)
	_rl_cache[key] = res
	return res

func _rlines_raw(t: String, maxw: float, fs: int, ff: Font) -> Array:
	var out: Array = []
	var cur: Array = []
	var cw := 0.0
	var sp: float = ff.get_string_size(" ", HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	for wd in t.split(" "):
		if wd == "":
			continue
		var ww: float = _wwidth(wd, fs, ff)
		if cw + ww > maxw and not cur.is_empty():
			out.append(cur)
			cur = []
			cw = 0.0
		cur.append(wd)
		cw += ww + sp
	if not cur.is_empty():
		out.append(cur)
	return out

func _is_icon(wd: String) -> bool:
	return wd.length() >= 3 and wd[0] == "[" and wd[2] == "]" and ICON.has(wd[1])

func _wwidth(wd: String, fs: int, f: Font = null) -> float:
	var ff: Font = f if f else Spr.font_i
	var key := "%s|%d|%d" % [wd, fs, ff.get_instance_id()]
	var cw = _ww_cache.get(key)
	if cw != null:
		return cw
	if _ww_cache.size() > 2000:
		_ww_cache.clear()
	var w := _wwidth_raw(wd, fs, ff)
	_ww_cache[key] = w
	return w

func _wwidth_raw(wd: String, fs: int, ff: Font) -> float:
	if _is_icon(wd):
		return fs * 1.7 + ff.get_string_size(wd.substr(3), HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	return ff.get_string_size(wd, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x

func _rwidth(ln: Array, fs: int, f: Font = null) -> float:
	var ff: Font = f if f else Spr.font_i
	var sp: float = ff.get_string_size(" ", HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var w := 0.0
	for wd in ln:
		w += _wwidth(wd, fs, ff) + sp
	return w - sp

func _rdraw(ln: Array, cx: float, y: float, fs: int, c: Color, f: Font) -> void:
	var sp: float = f.get_string_size(" ", HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var x: float = cx - _rwidth(ln, fs, f) / 2
	for wd in ln:
		var ww: float = _wwidth(wd, fs, f)
		if _is_icon(wd):
			var isz: float = fs * 1.6
			Spr.ci.draw_texture_rect(ICON[wd[1]], Rect2(x, y - fs * 1.15, isz, isz), false, Color(1, 1, 1, c.a))
			if wd.length() > 3:
				Spr.text(wd.substr(3), x + fs * 1.7, y, fs, c, HORIZONTAL_ALIGNMENT_LEFT, f)
		else:
			Spr.text(wd, x, y, fs, c, HORIZONTAL_ALIGNMENT_LEFT, f)
		x += ww + sp

func _process(_d: float) -> void:
	queue_redraw()
	if stats:
		stats.queue_redraw()
	if game == null or not game.L or not visible:
		return
	if Polish.g == null:
		Polish.g = game
	_fade_step(_d)
	_place_step(_d)
	for f in heart_fx:
		f.t += _d
	heart_fx = heart_fx.filter(func(f): return f.t < (.75 if f.k == "crack" else .32))
	heart_shake = max(0.0, heart_shake - _d * 3.5)

## Y4: o painel fica a 35% depois de ~4 s sem mudar nada (fora de perigo); volta a 100% na hora
## quando corações/contadores mudam, ao levar dano ou perto de um chefe.
## K9: tom do painel pelo período: quente à tarde, azulado à noite, neutro de manhã.
func _fade_step(d: float) -> void:
	var p: Dictionary = game.player
	var nd := 0
	for dr in game.DRWS:
		if dr.got:
			nd += 1
	var sig := [p.hp, game.lives, game.coin_life, game.SPECGOT.size(), nd, p.armor, game.M and game.M.ctrl, game.AMB.dark > .45]
	if sig != last_sig:
		last_sig = sig
		idle_t = 0.0
	idle_t += d
	var X: Extras = game.X
	var danger: bool = not Polish.bosses().is_empty() or (game.K and game.K.active()) or p.hp <= 1 \
		or (X and X.breath < Extras.BREATH) or (game.AMB.dark > .45 and game.fuel_vis < .3) or p.dyingT > 0
	# (antes esmaecia até 35%: no escuro o painel virava um retângulo cinza apagado — agora quase não esmaece)
	var want: float = 1.0 if (idle_t < 4.0 or danger or not game.running or not game.CINE.is_empty()) else .92
	if want > stats_a:
		stats_a = want
	else:
		stats_a = move_toward(stats_a, want, d * .9)
	var per: String = Polish.period()
	var tt := Color(1, 1, 1)
	if per == "tarde":
		tt = Color(1.0, .9, .76)
	elif per == "noite":
		tt = Color(.8, .88, 1.0)
	tint = tint.lerp(tt, clamp(d * 1.5, 0, 1))
	stats.modulate = Color(tint.r, tint.g, tint.b, stats_a)

## Y6: nome do trecho em letras bonitas no alto, aparecendo e sumindo (~2,5 s)
func _section_name() -> String:
	var S: Array = game.L.get("sections", [])
	if S.is_empty():
		return ""
	var px: float = game.amb_x()
	var sc = null
	for s in S:
		if float(s.x) <= px:
			sc = s
	if sc == null:
		return ""
	if sc.has("name"):
		return str(sc.name)
	if sc.has("per") and int(sc.per) < game.PERIODS.size():
		return str(game.PERIODS[int(sc.per)])
	var k: String = sc.get("map", "neve" if sc.get("bg", "") == "neve" else sc.get("song", "manha"))
	return PLACE_NAMES.get(k, "")

func _place_step(d: float) -> void:
	if game.running and game.CINE.is_empty() and game.player.dyingT == 0:
		var n := _section_name()
		if n != "" and not place_seen.has(n):
			place_seen[n] = true
			place_pending = n
			place_wait = 0.0
	if place_pending != "" and place_t < 0:
		place_wait += d
		# espera o aviso e a dica saírem (no máximo uns segundos)
		if (game.flash_t == 0 and hint_alpha < .05) or place_wait > 8.0:
			place_cur = place_pending
			place_pending = ""
			place_t = 0.0
	if place_t >= 0:
		place_t += d
		place_y = lerpf(place_y, place_ty, 1.0 - exp(-d * 12.0))
		if place_t >= PLACE_DUR:
			place_t = -1.0

func _draw_place(W: float) -> void:
	if place_t < 0 or place_cur == "":
		return
	var a: float = clamp(min(place_t / .5, (PLACE_DUR - place_t) / .5), 0.0, 1.0)
	a = a * a * (3.0 - 2.0 * a)
	# com a dica do lugar na tela, o nome desce para baixo dela
	# e com o fôlego ou a vida do chefe no alto, ou um aviso aparecendo, desce para baixo deles
	# (desliza até o lugar novo em vez de pular)
	var ty: float = max(92.0, bars_y + 34.0)
	if hint_alpha >= .05:
		ty = max(ty, 146.0)
	if msg_bot > 0.0:
		ty = max(ty, msg_bot + 44.0)
	place_ty = ty
	if place_y < 0.0 or place_t < .05:
		place_y = ty
	var y: float = place_y - (1.0 - a) * 6.0
	var fs := 30
	var tw: float = Spr.font_title.get_string_size(place_cur, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var gold := Color(1, .88, .62, a)
	# fitas finas dos lados e um losango pequeno: moldura discreta
	var lw: float = 60.0 * a + 20.0
	for sd in [-1, 1]:
		var x0: float = W / 2 + sd * (tw / 2 + 14)
		Spr.hgrad(x0 if sd > 0 else x0 - lw, y - 11, lw, 2, Color(1, .88, .62, a * (.9 if sd > 0 else 0)), Color(1, .88, .62, a * (0 if sd > 0 else .9)))
		Spr.poly(PackedVector2Array([Vector2(x0, y - 15), Vector2(x0 + 4, y - 10), Vector2(x0, y - 5), Vector2(x0 - 4, y - 10)]), gold)
	Spr.text(place_cur, W / 2, y, fs, gold, HORIZONTAL_ALIGNMENT_CENTER, Spr.font_title, 6, Color(.08, .05, .02, .8 * a))

func _box(x: float, y: float, w: float, h: float) -> void:
	Spr.rr(x, y, w, h, 9, Color(.04, .03, .02, .55))

## placa de pergaminho com moldura de madeira (mesmo estilo dos botões)
func _plaque(x: float, y: float, w: float, h: float, a: float = 1.0) -> void:
	Spr.rr(x - 1, y + 2, w + 2, h + 2, 11, Color(0, 0, 0, .28 * a))
	Spr.rr(x, y, w, h, 10, Color(.42, .27, .12, .96 * a))
	Spr.rr(x + 3, y + 3, w - 6, h - 6, 8, Color(.93, .85, .66, .96 * a))
	Spr.rr(x + 5, y + 4, w - 10, 6, 3, Color(1, 1, 1, .22 * a))
	Spr.rr(x + 5, y + h - 9, w - 10, 5, 3, Color(.55, .4, .2, .18 * a))

func _draw() -> void:
	var __t := Time.get_ticks_usec()
	__draw_raw()
	Spr.pt("hud", __t)

func __draw_raw() -> void:
	if game == null or not game.L or not visible:
		return
	var W := size.x
	var p: Dictionary = game.player
	Spr.begin(self)
	if not game.CINE.is_empty():
		_cine(W, size.y)
		return
	var X: Extras = game.X
	_draw_bars_and_hints(W, p, X)
	_draw_place(W)

## J1: meio coração (metade esquerda ou direita do desenho), girado em volta do centro
func _half(n: String, x: float, y: float, sc: float, left: bool, rot: float, al: float) -> void:
	var r = Spr.AR.get(n)
	if r == null:
		return
	Spr.save()
	Spr.translate(x, y)
	Spr.rotate(rot)
	Spr.scale(sc, sc)
	var hw: float = r[2] / 2.0
	Spr.ci.draw_texture_rect_region(Spr.atlas_tex(r), Rect2(-r[4] + (0.0 if left else hw), -r[5], hw, r[3]), Rect2(r[0] + (0.0 if left else hw), r[1], hw, r[3]), Color(1, 1, 1, al * Spr.alpha))
	Spr.restore()

## painel dos corações, vidas, lápis e a placa do canto (num filho que esmaece e muda de tom)
func _draw_stats(ci: Control) -> void:
	if game == null or not game.L or not visible or not game.CINE.is_empty():
		return
	var W := size.x
	var p: Dictionary = game.player
	Spr.begin(ci)
	var o := 40.0   # 5 corações: o resto do painel anda para a direita
	_plaque(8, 8, 290 + o, 42)
	# corações: batem de leve; com pouca vida o último pulsa forte.
	# Perdeu: o coração racha, as duas metades se abrem e caem (com um tremidinho no painel).
	# Ganhou: o coração enche como um balão (1,3 -> 1).
	if last_hp >= 0 and p.hp < last_hp:
		for i in range(max(p.hp, 0), last_hp):
			heart_fx.append({"i": i, "t": 0.0, "k": "crack"})
		heart_shake = 1.0
	elif last_hp >= 0 and p.hp > last_hp:
		for i in range(last_hp, min(p.hp, Game.MAXHP)):
			heart_fx.append({"i": i, "t": 0.0, "k": "pop"})
	last_hp = p.hp
	var shx: float = sin(Time.get_ticks_msec() * .06) * 2.5 * heart_shake
	for i in Game.MAXHP:
		var hx: float = 26 + i * 23 + shx
		var fx = null
		for f in heart_fx:
			if f.i == i:
				fx = f
		if fx != null and fx.k == "crack" and i >= p.hp:
			var u: float = clamp(fx.t / .75, 0.0, 1.0)
			Spr.A("hud_heart_empty", hx, 28, .45)
			var al: float = 1.0 - u * u
			var gap: float = 1.5 + u * 9.0
			var fall: float = u * u * 30.0 - sin(u * PI) * 4.0
			_half("hud_heart_full", hx - gap, 28 + fall, .45, true, -u * .7, al)
			_half("hud_heart_full", hx + gap, 28 + fall * 1.1, .45, false, u * .8, al)
			continue
		var hs := .45
		if i < p.hp:
			var beat: float = pow(max(0.0, sin(game.T * (.16 if p.hp <= 2 else .07) - i * .5)), 8.0)
			hs *= 1.0 + beat * (.22 if (p.hp <= 2 and i == p.hp - 1) else .06)
			if fx != null and fx.k == "pop":
				var u2: float = clamp(fx.t / .32, 0.0, 1.0)
				hs = .45 * (1.0 + .3 * (1.0 - u2) * (1.0 - u2) * (1.0 + sin(u2 * PI) * .3))
		Spr.A("hud_heart_full" if i < p.hp else "hud_heart_empty", hx, 28, hs)
	if p.armor > 0:
		Spr.A("hud_shield", 108 + o, 28, .48)
	Spr.text("× %d" % max(0, game.lives), 122 + o, 34, 16, Color("#3a2410"), HORIZONTAL_ALIGNMENT_LEFT, Spr.font_b)
	# o contador de lápis "pula" a cada lápis pego
	if last_coins >= 0 and game.coin_life != last_coins:
		coin_pop = 1.0
	last_coins = game.coin_life
	coin_pop = max(0.0, coin_pop - .07)
	var cp: float = 1.0 + sin(coin_pop * PI) * .35
	Spr.A("pen_vermelho", 179 + o, 30, .62 * 1.1 * cp)
	Spr.save()
	Spr.translate(194 + o, 34)
	Spr.scale(cp, cp)
	Spr.text("%d/100" % game.coin_life, 0, 0, 14, Color("#6a3a08").lerp(Color("#c07010"), coin_pop), HORIZONTAL_ALIGNMENT_LEFT, Spr.font_b)
	Spr.restore()
	var k := 0
	for c in GameData.PEN_LIST:
		Spr.rr(240 + o + k * 8, 15, 6, 26, 2, GameData.PEN_COL[c] if game.SPECGOT.has(c) else Color(.55, .45, .32, .45))
		k += 1
	if game.X and not game.X.GOLD.is_empty() and game.X.GOLD.got:
		Spr.rr(240 + o + k * 8, 14, 6, 26, 2, Color("#ffd76a"))
	# placa do canto (madeira e pergaminho): tempo, desenhos achados e o período do dia,
	# tudo junto e pequeno, ao lado da pausa — o alto da tela fica livre para o cenário
	var nd := 0
	for d in game.DRWS:
		if d.got:
			nd += 1
	var px0: float = W - 64 - 176
	_plaque(px0, 8, 176, 50)
	Spr.A("hud_paper", px0 + 60, 24, .3)
	Spr.text("%d/%d" % [nd, game.DRWS.size()], px0 + 78, 31, 16, Color("#8a5a10") if nd == game.DRWS.size() else Color("#3a2410"), HORIZONTAL_ALIGNMENT_LEFT, Spr.font_b)
	Spr.text(game.period_label(), px0 + 88, 50, 12, Color("#5a3a1c"), HORIZONTAL_ALIGNMENT_CENTER, Spr.font_i)
	# óleo da lanterna: medidor pequeno só no escuro
	if game.AMB.dark > .45 and not (game.M and game.M.ctrl) and not game.chase_on() and not game.player.get("isis"):
		var fv: float = game.fuel_vis
		_plaque(8, 54, 132, 30)
		Spr.A("hud_lantern_full" if game.lantern_lit else "hud_lantern_empty", 26, 69, .34)
		Spr.rr(42, 63, 86, 10, 5, Color(.2, .12, .06, .85))
		var fc: Color = Color("#ffc24a") if game.lantern_lit else Color("#b6f06a")
		if fv < .3:
			fc = fc.lerp(Color("#e0563a"), .5 + .5 * sin(game.T * .15))
		Spr.rr(42, 63, max(8.0, 86 * fv), 10, 5, fc)
		Spr.rr(44, 64, max(4.0, 82 * fv), 3, 2, Color(1, 1, 1, .35))
	# controlando o Pipoca
	if game.M and game.M.ctrl:
		_box(8, 54, 228, 30)
		Spr.text("Controlando a BAG", 20, 75, 15, Color("#ffe9a0"), HORIZONTAL_ALIGNMENT_LEFT, Spr.font_b)

## fôlego, barra do chefe, dica e avisos (sempre a 100%)
func _draw_bars_and_hints(W: float, p: Dictionary, X: Extras) -> void:
	# fôlego (na água); com a vida do chefe no alto, a barra do fôlego desce para baixo dela
	bars_y = 0.0
	msg_bot = 0.0
	var by0: float = 52.0 if Polish.bosses().is_empty() else 98.0
	if X and X.breath < Extras.BREATH:
		bars_y = by0 + 30.0
		var n: int = int(ceil(X.breath / float(Extras.BREATH) * 8))
		_box(W / 2 - 92, by0 - 2, 184, 28)
		for i in 8:
			var on := i < n
			var bx: float = W / 2 - 74 + i * 21
			Spr.circle(bx, by0 + 12, 7, Color(.6, .85, 1, .85) if on else Color(.3, .35, .4, .4))
			if on:
				Spr.circle(bx - 2, by0 + 10, 2, Color(1, 1, 1, .8))
	# chefes: barra de vida viva (o pedaço perdido fica branco, treme e escorre devagar)
	var bl: Array = Polish.bosses()
	if not bl.is_empty():
		bars_y = max(bars_y, 94.0)
		var bb: Dictionary = bl[0]
		var bw := 300.0
		var fr: float = clamp(float(bb.hp) / float(max(1, bb.max)), 0, 1)
		if boss_name != bb.name:
			boss_name = bb.name
			boss_lag = fr
			boss_shk = 0.0
		if fr < boss_lag - .001 and boss_shk <= 0.0 and boss_hold <= 0:
			boss_hold = 30
			boss_shk = 1.0
		if boss_hold > 0:
			boss_hold -= 1
		else:
			boss_lag = move_toward(boss_lag, fr, .006)
		boss_shk = max(0.0, boss_shk - .05)
		var sx: float = sin(game.T * 1.3) * 4.0 * boss_shk
		_box(W / 2 - bw / 2 - 10 + sx, 52, bw + 20, 40)
		Spr.text(bb.name, W / 2 + sx, 68, 13, Color("#ffcf9a"), HORIZONTAL_ALIGNMENT_CENTER, Spr.font_title)
		Spr.rr(W / 2 - bw / 2 + sx, 74, bw, 10, 5, Color(.2, .1, .08, .9))
		if boss_lag > fr:
			Spr.rr(W / 2 - bw / 2 + sx, 74, bw * boss_lag, 10, 5, Color(1, .95, .85, .9))
		if fr > 0:
			var pc: Color = Color("#e0463a").lerp(Color("#ff8a5a"), .5 + .5 * sin(game.T * .2)) if bb.hp == 1 else Color("#e0463a")
			Spr.rr(W / 2 - bw / 2 + sx, 74, bw * fr, 10, 5, pc)
	else:
		boss_name = ""
	# dica do lugar: pergaminho com o rostinho do Tomé; aparece, fica uns segundos e some sozinha
	# (o pergaminho pequeno no alto traz a dica de volta)
	var h := game.hint_text() if game.running else ""
	var boss: bool = (X and X.boss_active()) or (game.K and game.K.active())
	if h != hint_cur:
		hint_cur = h
		# dica já vista não volta sozinha (fica no pergaminho pequeno para rever)
		hint_show = HINT_FRAMES if hint_seen.has(h) else 0.0
	if h != "":
		hint_show += 1.0
		if hint_show >= (180.0 if boss else HINT_FRAMES) - 1:
			hint_seen[h] = true
	# levou dano: a dica sai na hora para não atrapalhar
	if last_hp2 >= 0 and p.hp < last_hp2:
		hint_show = max(hint_show, HINT_FRAMES)
	last_hp2 = p.hp
	var limit: float = 180.0 if boss else HINT_FRAMES
	var vis: bool = h != "" and hint_show < limit
	if vis:
		hint_txt = h
		hint_alpha = min(1, hint_alpha + .1)
	else:
		hint_alpha = max(0, hint_alpha - .08)
	if hint_alpha > 0 and hint_txt != "":
		var fs: int = 13 if boss else 14
		var mw: float = 330.0 if boss else min(W - 380, 460)
		# na luta a dica fica no canto: não pode entrar embaixo da barra de vida do chefe
		if boss and not bl.is_empty():
			mw = clamp(W / 2 - 160 - 8 - 8 - 70 - 6, 200.0, 330.0)
		var hl := _rlines(_icons(hint_txt), mw, fs)
		var hw := 0.0
		for ln in hl:
			hw = max(hw, _rwidth(ln, fs))
		var bw2: float = hw + 70
		var bh2: float = max(44.0, hl.size() * (fs + 6) + 16)
		# nas lutas vai para o canto de cima, embaixo do painel dos corações
		var bx2: float = 8.0 if boss else W / 2 - bw2 / 2
		var hy: float = (58.0 if boss else 62.0) - (1.0 - hint_alpha) * 8.0
		# Tomé (ou o chefe) passando por baixo: o pergaminho fica quase transparente
		var a2: float = hint_alpha
		var z: float = game.camera.zoom.x if game.camera else 1.0
		var ps := Vector2((p.x + p.w / 2 - game.rcam) * z, (p.y - game.rcam_y) * z)
		if ps.x > bx2 - 30 and ps.x < bx2 + bw2 + 30 and ps.y < hy + bh2 + 60:
			a2 *= .25
		_plaque(bx2, hy, bw2, bh2, a2)
		if not boss:
			msg_bot = max(msg_bot, hy + bh2)
		Spr.ci.draw_texture_rect(tex_face, Rect2(bx2 + 7, hy + bh2 / 2 - 17, 34, 34), false, Color(1, 1, 1, a2))
		var yy2: float = hy + 18 + (bh2 - 14 - hl.size() * (fs + 6)) / 2.0
		for ln in hl:
			_rdraw(ln, bx2 + 44 + (bw2 - 50) / 2, yy2, fs, Color(.24, .14, .06, a2), Spr.font_i)
			yy2 += fs + 6
	# aviso (flash)
	if game.flash_t > 0 and game.flash_msg != "":
		var a: float = clamp(game.flash_t / 40.0, 0, 1)
		var lines := _rlines(_icons(game.flash_msg), min(W - 80, 760), 17, Spr.font)
		var bh := 16 + lines.size() * 23
		var bw := 0.0
		for ln in lines:
			bw = max(bw, _rwidth(ln, 17, Spr.font))
		bw += 36
		# aviso no alto, abaixo da dica: nunca em cima das setas e dos botões de baixo
		# (e abaixo das barras de fôlego / vida do chefe)
		var by: float = max(150.0 if hint_alpha > .05 else 104.0, bars_y + 14.0) - (1.0 - clamp(game.flash_t / 10.0, 0, 1)) * 10.0
		Spr.rr(W / 2 - bw / 2, by, bw, bh, 10, Color(.04, .03, .02, .78 * a))
		msg_bot = max(msg_bot, by + bh)
		var y := by + 30
		for ln in lines:
			_rdraw(ln, W / 2, y, 17, Color(.96, .9, .78, a), Spr.font)
			y += 23

func _lines(t: String, maxw: float, fs: int) -> Array:
	var out: Array = []
	var cur := ""
	for wd in t.split(" "):
		var test := (cur + " " + wd).strip_edges()
		if Spr.font.get_string_size(test, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x > maxw and cur != "":
			out.append(cur)
			cur = wd
		else:
			cur = test
	if cur != "":
		out.append(cur)
	return out

func _wrapped(t: String, cx: float, y: float, maxw: float, fs: int, c: Color, f: Font) -> void:
	var y2 := y
	for ln in _lines(t, maxw, fs):
		Spr.text(ln, cx, y2, fs, c, HORIZONTAL_ALIGNMENT_CENTER, f)
		y2 += 21

# ---------- cena dramática: faixas de cinema, título e falas ----------
func _cine(W: float, H: float) -> void:
	var c: Dictionary = game.CINE
	var t: int = c.t
	var a: float = clamp(min(t, c.dur - t) / 18.0, 0, 1)
	# as faixas de cinema vêm de cinema_bars.gd (camada de baixo); aqui só se redesenham sobre a imagem do título
	var bar: float = cine_bar
	if c.title.size() == 4 and t >= c.title[0] and t < c.title[1]:
		var k: float = clamp(min(t - c.title[0], c.title[1] - t) / 14.0, 0, 1)
		var ct: String = "cena_" + {"boss": "javali", "vargas": "vargas", "cao": "cao"}.get(c.id, "")
		if Spr.tex.has(ct):
			var tx: Texture2D = Spr.tex[ct]
			var zs: float = max(W / tx.get_width(), H / tx.get_height()) * (1.0 + (t - c.title[0]) * .0012)
			var tw: float = tx.get_width() * zs
			var th: float = tx.get_height() * zs
			Spr.ci.draw_texture_rect(tx, Rect2(W / 2 - tw / 2, H / 2 - th / 2, tw, th), false, Color(1, 1, 1, k))
			Spr.rect(0, 0, W, bar, Color(0, 0, 0, 1))
			Spr.rect(0, H - bar, W, bar, Color(0, 0, 0, 1))
		var sc := 1.0 + (1.0 - k) * .25
		var y := H * .34
		Spr.save()
		Spr.translate(W / 2, y)
		Spr.scale(sc, sc)
		Spr.text(c.title[2], 0, 0, 54, Color(1, .85, .55, k), HORIZONTAL_ALIGNMENT_CENTER, Spr.font_title, 8, Color(0, 0, 0, .85 * k))
		Spr.text(c.title[3], 0, 38, 20, Color(.95, .9, .8, k), HORIZONTAL_ALIGNMENT_CENTER, Spr.font_i, 4, Color(0, 0, 0, .8 * k))
		Spr.restore()
	var l = game.cine_line()
	if l != null:
		var wt: bool = c.get("waiting", false)
		# parada esperando o toque: a caixa da fala fica totalmente visível
		var k2: float = 1.0 if wt else clamp(min(t - l[0], l[1] - t) / 8.0, 0, 1)
		var bw: float = min(W - 80, 760)
		var bx: float = W / 2 - bw / 2
		var by: float = H - 62 - 92
		Spr.rr(bx, by, bw, 84, 12, Color(.05, .04, .03, .88 * k2))
		Spr.ci.draw_rect(Rect2(bx, by, bw, 84), Color(.8, .66, .4, .7 * k2), false, 2)
		# retrato
		Spr.rr(bx + 10, by + 8, 68, 68, 8, Color(.2, .15, .1, k2))
		match l[4]:
			"vargas":
				_portrait("vg_face", bx + 44, by + 42, 62, k2)
			"lia":
				_portrait("lia_scared", bx + 44, by + 42, 62, k2)
			_:
				# rosto do Tomé dentro da moldura (antes o corpo vazava para fora da caixa)
				Spr.ci.draw_texture_rect(tex_face, Rect2(bx + 12, by + 10, 64, 64), false, Color(1, 1, 1, k2))
		var col: Color = {"BARÃO": Color("#ff9a7a"), "BAG": Color("#ffb0d0"), "MILIS": Color("#ffd27a"), "VARGAS": Color("#ff9a7a"), "TOMÉ": Color("#ffd27a")}.get(l[2], Color.WHITE)
		Spr.text(l[2], bx + 92, by + 26, 15, Color(col.r, col.g, col.b, k2), HORIZONTAL_ALIGNMENT_LEFT, Spr.font_title)
		var shown: int = 9999 if c.get("waiting", false) else int((t - l[0]) * 1.6)
		var txt: String = l[3].substr(0, shown)
		var yy := by + 50
		for ln in _lines(txt, bw - 110, 17):
			Spr.text(ln, bx + 92, yy, 17, Color(.96, .92, .82, k2), HORIZONTAL_ALIGNMENT_LEFT, Spr.font_i)
			yy += 21
		if wt:
			var pa: float = .78 + .22 * sin(game.T * .12)
			Spr.text(("▸ aperte um botão" if Save.getv("opt", "stick", "") == "gamepad" else "▸ toque para continuar"), bx + bw - 14, by + 78, 15, Color(1, .88, .6, pa), HORIZONTAL_ALIGNMENT_RIGHT, Spr.font_b, 3, Color(0, 0, 0, .8))
	Spr.text("PULAR CENA ▸", W - 20, H - 22, 15, Color(1, .9, .7, .7 * a), HORIZONTAL_ALIGNMENT_RIGHT, Spr.font_b)

func _portrait(n: String, cx: float, cy: float, h: float, al: float) -> void:
	var r = Spr.AR.get(n)
	if r == null:
		return
	var w: float = h * r[2] / r[3]
	if w > 64:
		w = 64
		h = w * r[3] / r[2]
	Spr.ci.draw_texture_rect_region(Spr.atlas_tex(r), Rect2(cx - w / 2, cy - h / 2, w, h), Rect2(r[0], r[1], r[2], r[3]), Color(1, 1, 1, al))
