extends Node2D
## Cenário fixo da fase (chão, árvores, casas, barranco...). Cada pedaço de 1024 px é um nó separado,
## desenhado uma vez só; o Godot só desenha os pedaços que aparecem na tela.

var game: Game
var x0 := 0.0
var x1 := 0.0
const EARTH := Color("#2a1a0e")
const CAVE := Color("#0d0a06")

func _ready() -> void:
	# cada pedaço pinta só a sua faixa [x0, x1] (com 1 px de folga dos dois lados, para não abrir fresta
	# com a tela escalada). O que passa da emenda (casas, morros, árvores, enfeites) é desenhado pelos dois
	# pedaços, na mesma ordem e cortado na emenda: um pedaço não cobre mais o chão/neve do vizinho
	var rid := get_canvas_item()
	RenderingServer.canvas_item_set_custom_rect(rid, true, Rect2(x0 - 1, -40000, x1 - x0 + 2, 80000))
	RenderingServer.canvas_item_set_clip(rid, true)

func _draw() -> void:
	var __t := Time.get_ticks_usec()
	_draw_raw()
	Spr.pt("static", __t)

func _draw_raw() -> void:
	var L := game.L
	Spr.begin(self)
	if L.has("under"):
		_dirt_fill(x0, x1, L.under, L.bottom + 200, 0.0, .5)
		# chão alto (morro do moinho, fundo do lago) que termina um pouco acima da terra de baixo:
		# completa com terra até ela, senão aparece uma faixa do fundo (o trigal) embaixo do chão.
		# Vem antes das grutas e fossos, que continuam desenhados por cima.
		for s in L.solids:
			if s.get("deco") or not str(s.t) in ["ground", "dirt"]:
				continue
			var sb: float = float(s.y) + float(s.get("h", 0))
			if float(s.get("h", 0)) < 50.0 or sb < 490.0 or sb >= float(L.under):
				continue
			var fa: float = max(float(s.x), x0)
			var fb: float = min(float(s.x) + float(s.w), x1)
			if fb > fa:
				_dirt_fill(fa, fb, sb - 6, float(L.under) + 4, 0.0, .34)
	# fossos e cavernas: cada pedaço do cenário desenha só a sua faixa [x0, x1]; senão o fundo da
	# caverna do pedaço seguinte cobre as pedras e plataformas desenhadas pelo anterior
	for pit in L.get("pits", []):
		if pit[1] < x0 or pit[0] > x1:
			continue
		var pa: float = max(float(pit[0]), x0)
		var pb: float = min(float(pit[1]), x1)
		Spr.vgrad(pa, 480, pb - pa, 200, Color(.03, .02, .04, .0), Color(.02, .015, .03, 1))
		Spr.rect(pa, 680, pb - pa, L.bottom - 480, Color(.02, .015, .03))
		# paredes de terra do buraco: barranco irregular com pedras, sumindo no escuro
		if pit[0] >= x0 - 40 and pit[0] < x1:
			_pit_wall(pit[0], 500, 1.0)
		if pit[1] > x0 and pit[1] <= x1 + 40:
			_pit_wall(pit[1], 500, -1.0)
	for c in L.get("caves", []):
		if c.x + c.w < x0 or c.x > x1:
			continue
		var ca: float = max(float(c.x), x0)
		var cb: float = min(float(c.x + c.w), x1)
		if c.get("ice"):
			# caverna de gelo: paredes de gelo com textura (placas facetadas, veios e brilho) e pingentes no teto
			Spr.vgrad(ca, c.y, cb - ca, c.h, Color("#3a5a7a"), Color("#16263a"))
			_ice_wall(ca, cb, c.y, c.h)
			var ix: float = c.x + 14
			while ix < c.x + c.w - 14:
				if ix >= x0 - 8 and ix < x1 + 8:
					var ln: float = 10 + fmod(ix * 1.37, 22.0)
					_icicle_reg(ix, c.y + ln)
					Spr.poly(PackedVector2Array([Vector2(ix - 6, c.y), Vector2(ix, c.y + ln), Vector2(ix + 6, c.y)]), Color(.8, .92, 1, .85))
				ix += 30
		elif c.get("wet"):
			# fundo de lago: azul-esverdeado escuro, com pedras no fundo. Começa abaixo do vale mais fundo
			# das ondas (a faixa de cima, que acompanha a ondulação, é desenhada na camada que se mexe)
			Spr.vgrad(ca, c.y + 30, cb - ca, c.h - 30, Color("#2a5a66"), Color("#0c1e28"))
			var rx: float = c.x + 30
			while rx < c.x + c.w - 30:
				if rx >= x0 - 50 and rx < x1 + 50:
					Spr.ellipse(rx, c.y + c.h - 6, 26 + fmod(rx * .7, 18.0), 9, Color("#16303a"))
				rx += 90
		else:
			# fundo da gruta: a mesma terra (raízes, pedras) bem escura, nada de retângulo chapado
			_dirt_fill(ca, cb, c.y, c.y + c.h, c.x, .3)
		_cave_border(c, c.get("ice", false))
	# vãos no chão dos túneis (embaixo dos cavaletes da mina): fundo escuro e paredes de terra
	for sh in L.get("shafts", []):
		if sh[1] < x0 or sh[0] > x1:
			continue
		var sa: float = max(float(sh[0]), x0)
		var sb: float = min(float(sh[1]), x1)
		var sy: float = sh[2]
		Spr.vgrad(sa, sy - 6, sb - sa, 160, Color(.03, .02, .02), Color(0, 0, 0))
		Spr.rect(sa, sy + 150, sb - sa, L.bottom - sy, Color(0, 0, 0))
		if sh[0] >= x0 - 40 and sh[0] < x1:
			_pit_wall(sh[0], sy, 1.0)
		if sh[1] > x0 and sh[1] <= x1 + 40:
			_pit_wall(sh[1], sy, -1.0)
	for d in L.get("decor", []):
		# peças largas (a toca do urso) passam por mais de um pedaço do cenário: margem maior
		var mg: float = 480.0 if d.k == "bearden" else 340.0
		if d.x + mg < x0 or d.x - mg > x1:
			continue
		if WorldNature.is_front(L, d):
			continue
		WorldNature.clip_x0 = x0
		WorldNature.clip_x1 = x1
		WorldNature.decor(d)
		WorldNature.clip_x0 = -1e9
		WorldNature.clip_x1 = 1e9
	for s in L.solids:
		var pad := 140.0 + float(s.get("tun", 0))
		if s.x + s.get("w", 0) + pad < x0 or s.x - pad > x1:
			continue
		# morros e paredões grandes são desenhados por todos os pedaços que eles cruzam: cada pedaço corta
		# na sua faixa (clip em _ready), a ordem é sempre a mesma e o morro não cobre o carrinho
		_contact_shadow(s)
		match s.t:
			"ground": ground(s)
			"plat", "branch":
				pass   # desenhados na camada que se mexe (afundam quando o Tomé pisa)
			"trunk": trunk(s)
			"dirt": dirt(s)
			"fakewall":
				Spr.rect(s.x, s.y, s.w, s.h, EARTH)
				Spr.seg(s.x + 4, s.y + 10, s.x + 14, s.y + 30, Color(0, 0, 0, .35), 1.5)
				Spr.seg(s.x + 14, s.y + 30, s.x + 6, s.y + 52, Color(0, 0, 0, .35), 1.5)
			"cabin": cabin(s)
			"root": root_log(s)
			"treehouse": treehouse(s)
			"hollow": Spr.AB("o_hollow", s.x - 22, s.y + s.h + 4 - 92, 154, 92)
			"cliff": cliff(s)
			"log":
				var w: float = s.w + 24
				Spr.AB("sw_log", s.x - 12, s.y - 12, w, w * 165 / 373)
			"deadtree": dead_tree(s)
			"damwall": planks(s, true)
			"wall": planks(s, false)
			"stone": stone(s)
			"hill": hill(s)
			"shed": shed(s)
			"beam": beam(s)
			"rockw": rockw(s)
			"portal": portal(s)
			"brickw":
				# parede de pedra do quarto da Isis (com a fresta embaixo)
				_masonry(s, Color(.62, .58, .54), Color(.3, .25, .2), Color(.1, .08, .06, .97), s.y)
				Spr.rect(s.x, s.y + s.h - 4, s.w, 4, Color(0, 0, 0, .5))
			"house":
				# casa da vila (Episódio 2): o telhado é o caminho do Tomé
				Spr.P("casa%d" % int(s.get("v", 0)), s.x + s.w / 2, s.y + 3, s.w, bool(s.get("flip", false)))
			"cart":
				if s.get("sprite"):
					Spr.ABb(s.sprite, s.x + s.w / 2, s.y + s.h + 4, s.w + 20)
					Spr.ellipse(s.x + s.w / 2, s.y + 6, s.w * .45, 6, Color(.96, .97, 1))
				else:
					Spr.AB("mi_cart", s.x - 8, s.y + s.h - 84, s.w + 16, 84)
			"ice":
				# placa de gelo sobre a água: borda ondulada, pontas arredondadas e rachaduras
				var tp := PackedVector2Array()
				var bp := PackedVector2Array()
				var ix: float = s.x
				var rr0: float = (s.h + 3) * .5
				while ix <= s.x + s.w:
					# pontas redondas (meio círculo) nas duas pontas
					var dd: float = min(ix - s.x, s.x + s.w - ix)
					var ins: float = 0.0
					if dd < rr0:
						ins = rr0 - sqrt(max(0.0, rr0 * rr0 - (rr0 - dd) * (rr0 - dd)))
					var wv: float = 1.0 if dd > rr0 * 2 else dd / (rr0 * 2)
					tp.push_back(Vector2(ix, s.y + 1.5 * sin(ix * .05) * wv + ins))
					bp.push_back(Vector2(ix, s.y + s.h + 3 + 2 * sin(ix * .08 + 1.0) * wv - ins))
					var nx: float = ix + (3.0 if dd < rr0 * 2 + 10 else 10.0)
					if ix < s.x + s.w and nx > s.x + s.w:
						nx = s.x + s.w
					ix = nx if nx > ix else ix + 10
				var ip := PackedVector2Array(tp)
				for i in range(bp.size() - 1, -1, -1):
					ip.push_back(bp[i])
				Spr.poly(ip, Color(.72, .88, 1, .9))
				Spr.line(tp, Color(1, 1, 1, .85), 2)
				Spr.line(bp, Color(.4, .6, .8, .6), 1.5)
				var cx2: float = s.x + 24
				while cx2 < s.x + s.w - 24:
					Spr.seg(cx2, s.y + 3, cx2 + 9, s.y + s.h * .6, Color(1, 1, 1, .5), 1.2)
					Spr.seg(cx2 + 9, s.y + s.h * .6, cx2 + 4, s.y + s.h + 2, Color(1, 1, 1, .35), 1)
					# bolhinhas presas no gelo e geada branca na beira
					if hh(cx2, 136) > .45:
						bt_ellipse(cx2 + 22, s.y + s.h * .55, 1.6, 1.6, Color(1, 1, 1, .55), 0.0, 6)
						bt_ellipse(cx2 + 27, s.y + s.h * .4, 1.1, 1.1, Color(1, 1, 1, .45), 0.0, 6)
					cx2 += 46 + fmod(cx2 * .7, 30.0)
				var fx2: float = max(s.x + 10, x0 - 10)
				while fx2 < min(s.x + s.w - 10, x1 + 10):
					bt_ellipse(fx2, s.y + 1.5 * sin(fx2 * .05) + 1, 1.3, 1.3, Color(1, 1, 1, .8), 0.0, 6)
					fx2 += 9 + hh(fx2, 137) * 8
				bt_flush()

# ---------- peças ----------
func tile_h(t: Texture2D, x0_: float, x1_: float, y: float, src: Rect2 = Rect2()) -> void:
	var sr := src if src.size != Vector2.ZERO else Rect2(Vector2.ZERO, t.get_size())
	var tw := sr.size.x - 1
	var x := x0_
	while x < x1_:
		var w: float = min(tw + 1, x1_ - x)
		Spr.img(t, x, y, w, sr.size.y, Rect2(sr.position.x, sr.position.y, w, sr.size.y))
		x += tw

## ponta do chão sem vizinho do lado: desenhada com contorno arredondado (sem quina de caixa)
func _open_end(s: Dictionary, right: bool) -> bool:
	var key := "_or" if right else "_ol"
	if s.has(key):
		return s[key]
	var open := true
	var ex: float = s.x + s.w if right else s.x
	for o in game.L.solids:
		if o == s or not o.t in ["ground", "dirt", "cliff", "hill"]:
			continue
		if o.y <= s.y + 2 and o.y + o.get("h", 0) > s.y + 4 and ex >= o.x - 1 and ex <= o.x + o.get("w", 0) + 1:
			open = false
			break
	s[key] = open
	return open

const ROUND := 22.0
## a textura do chão emendada duas vezes (a ponta pode cair na divisa entre dois ladrilhos)
static var _c2s := {}
## textura do chão do trecho em x (seção com "gt": "mina" ou "vila"; senão a grama do bosque)
static func gt_at(g, x: float) -> String:
	var k := ""
	for sc in g.L.get("sections", []):
		if sc.x <= x:
			k = str(sc.get("gt", ""))
	return k

const MIX_W := 420.0     # largura da mistura entre dois chãos diferentes
const MIX_STRIP := 14.0

## [chão de antes, chão de depois, peso do de depois] em x (perto da divisa de dois trechos)
static func mix_at(g, x: float) -> Array:
	var prev := ""
	for sc in g.L.get("sections", []):
		var k := str(sc.get("gt", ""))
		if k != prev:
			var bx: float = float(sc.x)
			if x < bx - MIX_W / 2:
				break
			if x < bx + MIX_W / 2:
				var u: float = clamp((x - (bx - MIX_W / 2)) / MIX_W, 0.0, 1.0)
				return [prev, k, u * u * (3.0 - 2.0 * u)]
			prev = k
		else:
			prev = k
	return [prev, prev, 0.0]

## o trecho [a, b] cruza a divisa de dois chãos?
func _mix_span(a: float, b: float) -> bool:
	var prev := ""
	var first := true
	for sc in game.L.get("sections", []):
		var k := str(sc.get("gt", ""))
		if not first and k != prev:
			var bx: float = float(sc.x)
			if b > bx - MIX_W / 2 and a < bx + MIX_W / 2:
				return true
		prev = k
		first = false
	return false

## chão misturado: tiras finas com a textura de antes e a de depois por cima (transparência pelo peso)
func _ground_mixed(s: Dictionary, xa: float, xb: float) -> void:
	var x: float = xa
	while x < xb:
		var e: float = min(x + MIX_STRIP, xb)
		var m: Array = mix_at(game, (x + e) * .5)
		var tc := _ground_tint((x + e) * .5)
		for j in 2:
			var w: float = 1.0 if j == 0 else float(m[2])
			if w <= 0.0 or (j == 0 and float(m[2]) >= 1.0):
				continue
			var key: String = str(m[j])
			var t: Texture2D = Spr.tex.get("chao_" + key, Spr.tex.chao) if key != "" else Spr.tex.chao
			var tw: float = t.get_width() - 1
			var th: float = min(float(t.get_height()), s.h + 32.0)
			var u0: float = fposmod(x, tw)
			var ww: float = e - x
			if u0 + ww > tw:
				ww = tw - u0
			Spr.ci.draw_texture_rect_region(t, Rect2(x, s.y - 32, ww, th), Rect2(u0, 0, ww, th), Color(tc.r, tc.g, tc.b, w))
			if ww < e - x:
				Spr.ci.draw_texture_rect_region(t, Rect2(x + ww, s.y - 32, e - x - ww, th), Rect2(0, 0, e - x - ww, th), Color(tc.r, tc.g, tc.b, w))
		x = e

static func gtex(g, x: float) -> Texture2D:
	var k := gt_at(g, x)
	if k != "" and Spr.tex.has("chao_" + k):
		return Spr.tex["chao_" + k]
	return Spr.tex.chao

func _chao2(t: Texture2D, tw: float) -> Texture2D:
	var _c2: Texture2D = _c2s.get(t.get_rid().get_id(), null)
	if _c2 == null:
		var im: Image = t.get_image()
		if im.is_compressed():
			im.decompress()
		var w: int = im.get_width()
		var out := Image.create(int(tw) + w, im.get_height(), false, im.get_format())
		out.blit_rect(im, Rect2i(0, 0, w, im.get_height()), Vector2i(0, 0))
		out.blit_rect(im, Rect2i(0, 0, w, im.get_height()), Vector2i(int(tw), 0))
		_c2 = ImageTexture.create_from_image(out)
		_c2s[t.get_rid().get_id()] = _c2
	return _c2
func ground(s: Dictionary) -> void:
	var x_a: float = max(s.x, x0 - 4)
	var x_b: float = min(s.x + s.w, x1 + 4)
	if x_b <= x_a:
		return
	# a textura é a do trecho onde este pedaço do chão está (não a do meio do bloco inteiro)
	var t: Texture2D = gtex(game, (x_a + x_b) * .5)
	# chão de pedra/mina: textura alinhada ao mundo (dois blocos vizinhos emendam sem costura)
	var ox: float = 0.0 if gt_at(game, (x_a + x_b) * .5) != "" else s.x
	var ol: bool = _open_end(s, false) and s.w > 60
	var orr: bool = _open_end(s, true) and s.w > 60
	# as pontas abertas ficam por conta do contorno arredondado
	var cut_a: float = s.x + (ROUND if ol else 0.0)
	var cut_b: float = s.x + s.w - (ROUND if orr else 0.0)
	# alinhado ao início do bloco para não "pular" entre pedaços
	var tw: float = t.get_width() - 1
	var start: float = ox + floor((x_a - ox) / tw) * tw
	var x := start
	# nada passa do fundo do bloco (senão a terra cobre a caverna que fica embaixo)
	var th: float = min(float(t.get_height()), s.h + 32.0)
	var mixed: bool = _mix_span(x_a, x_b)
	# ponta aberta só em cima: o vizinho é um pouco mais baixo (degrau, buraco da placa) — dali para
	# baixo a terra continua inteira, sem a faixa lisa da beira descendo pelo bloco todo
	var lo_l: float = _end_lo(s, false) if ol else INF
	var lo_r: float = _end_lo(s, true) if orr else INF
	if mixed:
		# divisa entre dois chãos (vila → mina): as duas texturas se misturam aos poucos
		_ground_mixed(s, max(x_a, cut_a), min(x_b, cut_b))
	while x < x_b and not mixed:
		var xa2: float = max(x, cut_a)
		var xb2: float = min(x + tw + 1, cut_b)
		if xb2 > xa2:
			# o chão muda de cor aos poucos entre os trechos (grama amarelando, lama, frio)
			var tc := _ground_tint((xa2 + xb2) * .5)
			Spr.ci.draw_texture_rect_region(t, Rect2(xa2, s.y - 32, xb2 - xa2, th), Rect2(xa2 - x, 0, xb2 - xa2, th), tc)
		for side in [0, 1]:
			var lo: float = lo_l if side == 0 else lo_r
			if lo == INF:
				continue
			var sa: float = max(x, s.x if side == 0 else cut_b)
			var sb2: float = min(x + tw + 1, cut_a if side == 0 else s.x + s.w)
			var ya3: float = lo + 6.0 - (s.y - 32.0)
			if sb2 > sa and ya3 < th:
				Spr.ci.draw_texture_rect_region(t, Rect2(sa, s.y - 32 + ya3, sb2 - sa, th - ya3), Rect2(sa - x, ya3, sb2 - sa, th - ya3), _ground_tint((sa + sb2) * .5))
		x += tw
	var fy: float = s.y - 34 + t.get_height()
	if s.y + s.h > fy:
		# a terra continua para baixo com a mesma textura (raízes, pedras), escurecendo aos poucos
		_dirt_fill(max(x_a, cut_a if lo_l == INF else s.x), min(x_b, cut_b if lo_r == INF else s.x + s.w), fy - 2, s.y + s.h, ox)
		_earth_detail(cut_a + 6, cut_b - 6, fy + 4, s.y + min(s.h, 700.0), Color("#34200f"))
	if ol and s.x >= x0 - ROUND and s.x < x1:
		_ground_end(s, t, tw, false, lo_l)
	if orr and s.x + s.w > x0 and s.x + s.w <= x1 + ROUND:
		_ground_end(s, t, tw, true, lo_r)
	if s.get("snow"):
		_snow_top(x_a + (8.0 if ol and x_a <= s.x else 0.0), x_b - (8.0 if orr and x_b >= s.x + s.w else 0.0), s.y)
	_ground_vary(s, x_a, x_b)
	_ground_deco(s)

## terra por baixo do chão: a parte de terra da textura do chão repetida para baixo (uma cópia
## sim, outra espelhada, para não aparecer emenda), cada vez mais escura com a profundidade
func _dirt_fill(xa: float, xb: float, ya: float, yb: float, ox: float, k0: float = 1.0) -> void:
	xa = max(xa, x0 - 2)
	xb = min(xb, x1 + 2)
	if xb <= xa or yb <= ya:
		return
	if _mix_span(xa, xb):
		# na divisa de dois chãos: faixas finas, cada uma com a mistura das duas texturas
		var sx: float = xa
		while sx < xb:
			var ex: float = min(sx + MIX_STRIP, xb)
			var m: Array = mix_at(game, (sx + ex) * .5)
			_dirt_fill_t(sx, ex, ya, yb, ox, k0, Spr.tex.get("chao_" + str(m[0]), Spr.tex.chao) if m[0] != "" else Spr.tex.chao, 1.0)
			if float(m[2]) > 0.0:
				_dirt_fill_t(sx, ex, ya, yb, ox, k0, Spr.tex.get("chao_" + str(m[1]), Spr.tex.chao) if m[1] != "" else Spr.tex.chao, float(m[2]))
			sx = ex
		return
	_dirt_fill_t(xa, xb, ya, yb, ox, k0, gtex(game, (xa + xb) * .5), 1.0)

func _dirt_fill_t(xa: float, xb: float, ya: float, yb: float, ox: float, k0: float, t: Texture2D, alpha: float) -> void:
	var ts := t.get_size()
	var v0: float = 60.0
	var th: float = ts.y - v0
	var tw: float = ts.x - 1
	var yend: float = min(yb, ya + 900.0)
	var y: float = ya
	var row := 0
	var tint := _ground_tint((xa + xb) * .5)
	while y < yend:
		var hh_: float = min(th, yend - y)
		var u: float = clamp((y - ya) / 600.0, 0, 1)
		var m: float = k0 * lerpf(.92, .42, u)
		var col := Color(tint.r * m, tint.g * m, tint.b * m, alpha)
		var x: float = ox + floor((xa - ox) / tw) * tw
		while x < xb:
			var a: float = max(x, xa)
			var b: float = min(x + tw, xb)
			if b > a:
				var u0: float = (a - x) / ts.x
				var u1: float = (b - x) / ts.x
				var va: float = v0 / ts.y
				var vb: float = (v0 + hh_) / ts.y
				if row % 2 == 1:
					va = 1.0
					vb = (ts.y - hh_) / ts.y
				Spr.ci.draw_polygon(PackedVector2Array([Vector2(a, y), Vector2(b, y), Vector2(b, y + hh_), Vector2(a, y + hh_)]),
					PackedColorArray([col, col, col, col]), PackedVector2Array([Vector2(u0, va), Vector2(u1, va), Vector2(u1, vb), Vector2(u0, vb)]), t)
			x += tw
		y += max(hh_ - 1.0, 1.0)
		if hh_ < th:
			break
		row += 1
	if yb > yend:
		Spr.rect(xa, yend - 1, xb - xa, yb - yend + 1, Color(tint.r * .1 * k0 + .02, tint.g * .07 * k0 + .015, .02))

## contorno de rocha da caverna: pontas no teto, paredes irregulares e pedras no chão (sem quinas retas)
func _cave_border(c: Dictionary, ice: bool) -> void:
	var rock: Color = Color("#2a1a0e") if not ice else Color("#1d2c40")
	var rock2: Color = Color("#3a2616") if not ice else Color("#2c4060")
	# teto: dentes irregulares descendo (nos lagos não: ali o "teto" é a superfície da água)
	var x: float = c.x
	while x < c.x + c.w and not c.get("wet"):
		var w: float = 22 + hh(x, 51) * 30
		if x + w > x0 - 4 and x < x1 + 4:
			var d: float = 6 + hh(x, 52) * 16
			Spr.poly(PackedVector2Array([Vector2(x, c.y - 1), Vector2(x + w * .45, c.y + d), Vector2(x + w * .6, c.y + d * .8), Vector2(x + w, c.y - 1)]), rock)
			# chão: pedras arredondadas
			var rh: float = 4 + hh(x, 53) * 8
			Spr.ellipse(x + w * .5, c.y + c.h, w * .55, rh, rock2)
		x += w
	# paredes dos lados: bordas onduladas entrando no vazio
	for side in [0, 1]:
		var e: float = c.x if side == 0 else c.x + c.w
		if e < x0 - 30 or e > x1 + 30:
			continue
		var dir: float = 1.0 if side == 0 else -1.0
		var pts := PackedVector2Array([Vector2(e - dir, c.y)])
		var y: float = c.y
		while y <= c.y + c.h:
			var u: float = (y - c.y) / max(1.0, c.h)
			var dep: float = max(2.0, 10 + 6 * sin(y * .13 + e) + 5 * sin(y * .37 + e * .7) + 14 * pow(abs(u - .5) * 2.0, 3.0))
			pts.push_back(Vector2(e + dir * dep, y))
			y += 10
		pts.push_back(Vector2(e - dir, c.y + c.h))
		Spr.poly(pts, rock)

## fundo da caverna de gelo: placas facetadas de gelo (mais claras em cima), veios, bolhas presas
func _ice_wall(ca: float, cb: float, y0: float, h: float) -> void:
	var x: float = floor(ca / 70.0) * 70.0 - 70
	while x < cb + 70:
		var k1: float = hh(x, 71)
		var k2: float = hh(x, 72)
		var yy: float = y0 + 6
		var row := 0
		while yy < y0 + h - 10:
			var ph: float = 40 + hh(x + row * 13, 73) * 50
			var ox: float = (k1 - .5) * 20 + (row % 2) * 30
			var w: float = 64 + k2 * 26
			var pa := Vector2(x + ox, yy)
			var pts := PackedVector2Array([pa, pa + Vector2(w * .6, -3), pa + Vector2(w, ph * .35), pa + Vector2(w * .8, ph), pa + Vector2(w * .15, ph + 4), pa + Vector2(-6, ph * .5)])
			var u: float = (yy - y0) / h
			var cc := Color(.62, .8, .95, .16 - u * .1).lerp(Color(.3, .5, .7, .1), hh(x + row, 74))
			Spr.poly(pts, cc)
			# aresta clara em cima e escura embaixo (cada placa parece ter volume)
			Spr.seg(pts[0].x, pts[0].y, pts[1].x, pts[1].y, Color(.9, .97, 1, .28 - u * .18), 1.5)
			Spr.seg(pts[3].x, pts[3].y, pts[4].x, pts[4].y, Color(.08, .15, .26, .3), 1.5)
			# veio branco atravessando a placa
			if hh(x + row, 75) > .55:
				Spr.seg(pa.x + w * .2, pa.y + ph * .2, pa.x + w * .55, pa.y + ph * .75, Color(1, 1, 1, .12), 1.2)
			# bolhinhas de ar presas no gelo
			if hh(x + row, 76) > .6:
				Spr.circle(pa.x + w * .5, pa.y + ph * .5, 2.5, Color(.9, .97, 1, .25))
				Spr.circle(pa.x + w * .58, pa.y + ph * .4, 1.5, Color(.9, .97, 1, .2))
			yy += ph - 6
			row += 1
		x += 70

## parede de um buraco: terra desmoronada, entrando no vão com contorno de pedras, escurecendo para baixo
func _pit_wall(e: float, y0: float, dir: float) -> void:
	var bands := [[Color("#5a3d26"), 0.0], [Color("#3c281a"), 60.0], [Color("#1e140c"), 140.0], [Color(.05, .03, .02), 220.0]]
	for b in bands:
		var pts := PackedVector2Array()
		var yt: float = y0 + b[1]
		pts.push_back(Vector2(e - dir * 2, yt))
		var y: float = yt
		while y <= yt + 90:
			var depth: float = 14 + 9 * sin(y * .11 + e) + 6 * sin(y * .31 + e * 1.7) + max(0.0, 20.0 - (y - y0) * .2)
			pts.push_back(Vector2(e + dir * depth, y))
			y += 9
		pts.push_back(Vector2(e - dir * 2, yt + 90))
		Spr.poly(pts, b[0])
	# pedras presas na parede e na beirada
	for k in 4:
		var py: float = y0 + 14 + k * 36
		var px: float = e + dir * (10 + hh(e + k, 48) * 10)
		var rw: float = 5 + hh(e - k, 49) * 4
		var c := Color(.42, .34, .26).darkened(k * .2)
		Spr.ellipse(px, py, rw, rw * .7, c)
		Spr.ellipse(px - rw * .3, py - rw * .3, rw * .35, rw * .2, Color(1, 1, 1, .15 * (1.0 - k * .25)))

## terra por dentro: pedrinhas, raízes finas e manchas, escurecendo com a profundidade (nada de chapado)
func _earth_detail(sa: float, sb: float, ya: float, yb: float, base: Color) -> void:
	# [sa, sb] = o bloco inteiro; manchas e camadas só na faixa deste pedaço, mas as pedrinhas e raízes
	# perto da emenda são desenhadas pelos dois pedaços (cada um corta a sua metade)
	var xa: float = max(sa, x0 - 2)
	var xb: float = min(sb, x1 + 2)
	if xb <= xa or yb <= ya:
		return
	Spr.vgrad(xa, ya, xb - xa, min(yb - ya, 260.0), Color(0, 0, 0, 0), Color(0, 0, 0, .28))
	if yb - ya > 260:
		Spr.rect(xa, ya + 260, xb - xa, yb - ya - 260, Color(0, 0, 0, .28))
	# camadas da terra: faixas de tons diferentes (mais avermelhada, mais escura), onduladas de leve
	var sy0: float = ya + 26
	var li := 0
	while sy0 < min(yb, ya + 520):
		var bh: float = 16 + hh(sy0 + xa * .01, 71) * 22
		var tone: Color = [Color(.45, .2, .08, .10), Color(0, 0, 0, .10), Color(.6, .45, .25, .07)][li % 3]
		var pts := PackedVector2Array()
		var stp: float = 48.0
		var xx: float = floor(xa / stp) * stp
		var top := PackedVector2Array()
		while xx <= xb + stp:
			top.push_back(Vector2(clamp(xx, xa, xb), sy0 + sin(xx * .011 + li) * 5))
			xx += stp
		for q in top:
			pts.push_back(q)
		for qi in range(top.size() - 1, -1, -1):
			pts.push_back(Vector2(top[qi].x, top[qi].y + bh))
		if pts.size() >= 3:
			Spr.poly(pts, tone)
		sy0 += bh + 30 + hh(sy0, 72) * 40
		li += 1
	var gx: float = floor(max(sa, x0 - 40) / 46.0) * 46.0
	while gx < min(sb, x1 + 40):
		var gy: float = floor(ya / 40.0) * 40.0
		while gy < min(yb, ya + 420):
			var r := hh(gx * 1.3 + gy, 41)
			var px: float = gx + hh(gx + gy, 42) * 40
			var py: float = gy + hh(gx - gy, 43) * 34
			if px > sa + 4 and px < sb - 4 and py > ya + 4 and py < yb - 4:
				var fade: float = clamp(1.0 - (py - ya) / 420.0, .3, 1.0)
				if r < .32:
					var rw: float = 3 + hh(px, 44) * 5
					Spr.ellipse(px, py, rw, rw * .65, base.lightened(.22 + hh(py, 45) * .15) * Color(1, 1, 1, fade))
					Spr.ellipse(px - rw * .3, py - rw * .25, rw * .4, rw * .22, Color(1, 1, 1, .12 * fade))
				elif r < .45:
					var pts := PackedVector2Array()
					var dir: float = 1.0 if hh(px, 46) > .5 else -1.0
					for k in 6:
						var u := k / 5.0
						pts.push_back(Vector2(px + dir * u * 22, py + sin(u * 4.0 + px) * 4 + u * 8))
					Spr.line(pts, base.lightened(.12) * Color(1, 1, 1, .7 * fade), 1.6)
				elif r < .55:
					Spr.ellipse(px, py, 12 + hh(py, 47) * 10, 5, base.darkened(.25) * Color(1, 1, 1, .6 * fade))
			gy += 40
		gx += 46

## bloco de terra: quando a lateral fica à mostra, ela tem contorno irregular (barranco), não corte reto
func dirt(s: Dictionary) -> void:
	var xa: float = max(s.x, x0 - 2)
	var xb: float = min(s.x + s.w, x1 + 2)
	if xb <= xa:
		return
	var lf: float = _lake_floor(s)
	if lf > 0.0:
		_lake_ledge(s, lf)
		return
	var ol0: bool = _open_end(s, false)
	var or0: bool = _open_end(s, true)
	var ol: bool = ol0 and s.x >= x0 - 16 and s.x <= x1 + 2
	var orr: bool = or0 and s.x + s.w <= x1 + 16 and s.x + s.w >= x0 - 2
	var ia: float = max(xa, s.x + 10.0) if ol else xa
	var ib: float = min(xb, s.x + s.w - 10.0) if orr else xb
	# terra com textura (raízes, pedras) em vez de um bloco escuro liso; o buraco estreito da placa,
	# entre dois chãos, fica no mesmo tom da terra do chão (nada de coluna escura embaixo da placa)
	var hole: bool = not ol0 and not or0 and float(s.w) <= 90.0 and float(s.h) <= 140.0
	_dirt_fill(ia, ib, s.y, s.y + s.h, s.x, 1.08 if hole else .8)
	if hole:
		_hole_tex(s, ia, ib)
	for side in [0, 1]:
		if (side == 0 and not ol) or (side == 1 and not orr):
			continue
		var e: float = s.x if side == 0 else s.x + s.w
		var pts := PackedVector2Array()
		var y: float = s.y
		var inner: float = e + 10.0 if side == 0 else e - 10.0
		pts.push_back(Vector2(inner, s.y))
		while y <= s.y + s.h:
			var ins: float = 2.0 + 3.0 * sin(y * .07 + e) + 2.0 * sin(y * .19 + e * 2.0) + 3.0
			pts.push_back(Vector2(e + ins if side == 0 else e - ins, y))
			y += 12
		pts.push_back(Vector2(e + 4 if side == 0 else e - 4, s.y + s.h))
		pts.push_back(Vector2(inner, s.y + s.h))
		Spr.poly(pts, EARTH)
	_earth_detail(s.x + (10.0 if ol0 else 0.0), s.x + s.w - (10.0 if or0 else 0.0), s.y + 6, s.y + s.h, EARTH)

## buraco da placa: continua a MESMA textura do chão vizinho (mesmas linhas, mesmo alinhamento),
## só que começando abaixo da grama — some a coluna de outra cor embaixo da placa
func _hole_tex(s: Dictionary, xa: float, xb: float) -> void:
	var n = null
	for o in game.L.solids:
		if str(o.get("t", "")) == "ground" and not o.get("deco") and abs(float(o.x) + float(o.w) - float(s.x)) < 2.0 and float(o.y) < float(s.y):
			n = o
			break
	if n == null:
		return
	var t: Texture2D = gtex(game, (xa + xb) * .5)
	var tw: float = t.get_width() - 1
	var ox: float = 0.0 if gt_at(game, (xa + xb) * .5) != "" else float(n.x)
	var ty0: float = float(n.y) - 32.0
	var th: float = min(float(t.get_height()), float(n.get("h", 140)) + 32.0)
	var ya: float = float(s.y)
	var yb: float = min(float(s.y) + float(s.h), ty0 + th)
	if yb <= ya:
		return
	var x: float = ox + floor((xa - ox) / tw) * tw
	while x < xb:
		var a: float = max(x, xa)
		var b: float = min(x + tw + 1, xb)
		if b > a:
			Spr.ci.draw_texture_rect_region(t, Rect2(a, ya, b - a, yb - ya), Rect2(a - x, ya - ty0, b - a, yb - ya), _ground_tint((a + b) * .5))
		x += tw

## laje fina dentro de um lago (onde ficam o capacete e o arpão): devolve o fundo do lago embaixo
## dela, ou -1 se não for uma laje de lago
func _lake_floor(s: Dictionary) -> float:
	if float(s.get("h", 0)) > 24.0:
		return -1.0
	for c in game.L.get("caves", []):
		if c.get("wet") and float(s.x) >= float(c.x) and float(s.x) + float(s.w) <= float(c.x) + float(c.w) \
				and float(s.y) > float(c.y) and float(s.y) + float(s.h) < float(c.y) + float(c.h):
			# o fundo é o chão firme logo abaixo (ou o fundo da gruta)
			var fl: float = float(c.y) + float(c.h)
			for o in game.L.solids:
				if str(o.get("t", "")) in ["dirt", "ground"] and o != s and float(o.y) > float(s.y) + 4 and float(o.y) < fl \
						and float(o.x) < float(s.x) + float(s.w) * .5 and float(o.x) + float(o.get("w", 0)) > float(s.x) + float(s.w) * .5:
					fl = float(o.y)
			return fl
	return -1.0

## laje de pedra de verdade no lago: placa de rocha com musgo em cima de um pilar de pedras que vem
## do fundo (um pouco atrás e mais escuro), em vez de uma faixa de terra boiando na água
func _lake_ledge(s: Dictionary, floor_y: float) -> void:
	var cx: float = s.x + s.w / 2
	var gy: float = s.y + s.h
	var pw: float = min(76.0, s.w * .42)
	if floor_y - gy > 16:
		var pil := {"x": cx - pw / 2, "y": gy - 4, "w": pw, "h": floor_y - gy + 10}
		_masonry(pil, Color(.5, .52, .5), Color(.24, .22, .2), Color(.08, .07, .06, .97), gy - 4)
		Spr.rect(cx - pw / 2, gy - 4, pw, floor_y - gy + 10, Color(.05, .12, .16, .3))
		# pedras do pé do pilar, meio enterradas no fundo
		for k in [-1, 1]:
			Spr.PR("mossrock_s", cx + k * (pw / 2 + 4) - 17, floor_y - 18, 34, 24, Color(.72, .8, .82), k > 0)
	Spr.ellipse(cx, gy + 4, s.w * .42, 5, Color(0, 0, 0, .22))
	Spr.PR("slab%d" % (absi(hash(int(s.x))) % 3), s.x - 10, s.y - 8, s.w + 20, s.h + 16, Color(.86, .93, .95))
	# alguns fiapos de alga pendurados na beira da laje
	for k in 4:
		var ax: float = s.x + 14 + k * (s.w - 28) / 3.0
		var al: float = 10 + hh(ax, 61) * 14
		Spr.seg(ax, gy + 2, ax + 2 + hh(ax, 62) * 3, gy + 2 + al, Color(.3, .55, .3, .55), 2.0)

const TINTS := {"manha": Color(1, 1, 1), "tarde": Color(1.04, .93, .74), "chuva": Color(.84, .91, .84), "neve": Color(.93, .97, 1.04),
	"tema": Color(.93, .97, 1.04), "noite": Color(.8, .84, .96), "perseguicao": Color(.8, .84, .96)}
## cor do chão em x: mistura a do trecho anterior com a do atual numa faixa de 900 px
func _ground_tint(x: float) -> Color:
	return tint_at(game, x)

static func tint_at(g: Game, x: float) -> Color:
	var S: Array = g.L.get("sections", [])
	var prev := Color(1, 1, 1)
	var cur := Color(1, 1, 1)
	var sx := -1e9
	for sc in S:
		if sc.x <= x:
			prev = cur
			cur = TINTS.get("neve" if sc.get("bg", "") == "neve" else sc.get("song", "manha"), Color(1, 1, 1))
			sx = sc.x
	return prev.lerp(cur, clamp((x - sx + 450.0) / 900.0, 0.0, 1.0))

## o "clima" do trecho em x (para escolher os enfeites do chão)
func _theme_at(x: float) -> String:
	var th := "manha"
	for sc in game.L.get("sections", []):
		if sc.x <= x:
			th = "neve" if sc.get("bg", "") == "neve" else sc.get("song", "manha")
	return th

static func hh(x: float, k: int = 0) -> float:
	var v := sin(x * 12.9898 + k * 78.233) * 43758.5453
	return v - floor(v)

## enfeites pequenos em cima do chão: flores, pedrinhas, folhas secas, poças, montinhos de neve
## e raízes saindo da beira. Tudo fixo (sorteado pela posição), desenhado uma vez só.
func _ground_deco(s: Dictionary) -> void:
	if s.w < 120:
		return
	var y: float = s.y
	var th := _theme_at(s.x + s.w / 2)
	var under: bool = game.L.has("under") and y > game.L.under
	var gx: float = s.x + 40 + fposmod(-(s.x + 40), 58.0)
	while gx < s.x + s.w - 40:
		if gx >= x0 - 48 and gx < x1 + 48:
			var r := hh(gx, 11)
			if r < .5 and not _covered(gx, y):
				var kind := int(hh(gx, 12) * 100)
				if s.get("snow") or th == "neve":
					if kind < 45:
						_snow_mound(gx, y)
					elif kind < 70:
						_pebbles(gx, y, Color(.55, .58, .64))
					elif kind < 80:
						_ice_puddle(gx, y)
				elif under or th in ["noite", "perseguicao", "tunel"]:
					if kind < 55:
						_pebbles(gx, y, Color(.36, .32, .3))
					elif kind < 75:
						_tiny_mush(gx, y)
				elif th == "chuva":
					if kind < 30:
						_puddle(gx, y)
					elif kind < 60:
						_pebbles(gx, y, Color(.38, .4, .36))
					elif kind < 75:
						_leaves(gx, y, [Color(.36, .42, .2), Color(.3, .32, .18)])
				elif th == "tarde":
					if kind < 45:
						_leaves(gx, y, [Color(.86, .5, .16), Color(.72, .32, .12), Color(.9, .7, .2)])
					elif kind < 65:
						pass   # flor: desenhada no quadro dinâmico (balança e abre quando o Tomé passa)
					elif kind < 85:
						_pebbles(gx, y, Color(.55, .48, .4))
				else:
					if kind < 50:
						pass   # flor (quadro dinâmico)
					elif kind < 75:
						_pebbles(gx, y, Color(.58, .55, .5))
		gx += 58
	# chegando na neve: manchas de neve cada vez mais frequentes no chão
	if not s.get("snow"):
		for sc in game.L.get("sections", []):
			if sc.get("bg", "") == "neve":
				var nx: float = sc.x
				var sxp: float = max(s.x + 30, nx - 1100)
				while sxp < min(s.x + s.w - 30, nx):
					var dens: float = 1.0 - (nx - sxp) / 1100.0
					if sxp >= x0 - 50 and sxp < x1 + 50 and hh(sxp, 71) < dens:
						var w2: float = 16 + 30 * dens * hh(sxp, 72)
						Spr.ellipse(sxp, s.y - 2, w2, 4 + 3 * dens, Color(.95, .97, 1, .95))
					sxp += 34
				break
	# raízes saindo da beira do barranco (embaixo da grama)
	if not s.get("snow") and not under:
		var rx: float = s.x + 70 + fposmod(-(s.x + 70), 170.0)
		while rx < s.x + s.w - 70:
			if rx >= x0 - 30 and rx < x1 + 30 and hh(rx, 14) < .45:
				_root_curl(rx, y + 14 + hh(rx, 15) * 10)
			rx += 170

## flores do chão (mesmo sorteio dos enfeites): lista [x, espécie, largura, vira] guardada no bloco de chão
static func flowers_of(g: Game, s: Dictionary) -> Array:
	if s.has("_fl"):
		return s._fl
	var out: Array = []
	if s.w >= 120 and not s.get("snow") and s.get("t", "") == "ground":
		var y: float = s.y
		var under: bool = g.L.has("under") and y > g.L.under
		var gx: float = s.x + 40 + fposmod(-(s.x + 40), 58.0)
		while gx < s.x + s.w - 40:
			if hh(gx, 11) < .5:
				var th := theme_at(g, gx)
				var kind := int(hh(gx, 12) * 100)
				var c := Color(0, 0, 0, 0)
				if th == "neve" or under or th in ["noite", "perseguicao", "tunel", "chuva"]:
					pass
				elif th == "tarde":
					if kind >= 45 and kind < 65:
						c = Color(1, .82, .3)
				elif kind < 50:
					c = [Color(1, .55, .7), Color(1, .95, .55), Color(.98, .98, 1), Color(.6, .7, 1)][int(hh(gx, 13) * 4)]
				if c.a > 0 and not covered(g, gx, y):
					var n := "fl_yellow"
					if c.b > .9 and c.r < .8:
						n = "fl_blue"
					elif c.r > .95 and c.g < .7:
						n = "fl_lilac"
					elif c.r > .95 and c.g > .95 and c.b > .95:
						n = "fl_white"
					elif hh(gx, 16) > .6:
						n = "fl_dande"
					out.append([gx, n, 20 + hh(gx, 17) * 8, hh(gx, 18) > .5])
					if hh(gx, 19) > .55:
						out.append([gx + 12, n, 15 + hh(gx, 20) * 5, hh(gx, 21) > .5])
			gx += 58
	s._fl = out
	return out

static func theme_at(g: Game, x: float) -> String:
	var th := "manha"
	for sc in g.L.get("sections", []):
		if sc.x <= x:
			th = "neve" if sc.get("bg", "") == "neve" else sc.get("song", "manha")
	return th

static func covered(g: Game, x: float, y: float) -> bool:
	for o in g.L.solids:
		if o.t in ["ground", "dirt", "cliff", "hill"]:
			continue
		if x > o.x - 14 and x < o.x + o.get("w", 0) + 14 and y > o.y - 4 and y < o.y + o.get("h", 0) + 30:
			return true
	return false

## não enfeita onde tem outra coisa em cima do chão (parede, caixa fixa, pedra...)
func _covered(x: float, y: float) -> bool:
	for o in game.L.solids:
		if o.t in ["ground", "dirt", "cliff", "hill"]:
			continue
		if x > o.x - 14 and x < o.x + o.get("w", 0) + 14 and y > o.y - 4 and y < o.y + o.get("h", 0) + 30:
			return true
	return false

func _flower(x: float, y: float, c: Color) -> void:
	# florzinha pintada; a cor pedida escolhe a espécie (amarela, azul, lilás, branca, dente-de-leão)
	var n := "fl_yellow"
	if c.b > .9 and c.r < .8:
		n = "fl_blue"
	elif c.r > .95 and c.g < .7:
		n = "fl_lilac"
	elif c.r > .95 and c.g > .95 and c.b > .95:
		n = "fl_white"
	elif hh(x, 16) > .6:
		n = "fl_dande"
	var tc := _ground_tint(x)
	Spr.P(n, x, y + 2, 20 + hh(x, 17) * 8, hh(x, 18) > .5, 0.0, tc)
	if hh(x, 19) > .55:
		Spr.P(n, x + 12, y + 2, 15 + hh(x, 20) * 5, hh(x, 21) > .5, 0.0, tc)

func _pebbles(x: float, y: float, c: Color) -> void:
	var m: float = c.v / .55
	var col := Color(m, m, m * 1.02)
	Spr.P("peb%d" % int(hh(x, 19) * 2.99), x, y + 3, 14 + hh(x, 20) * 8, hh(x, 21) > .5, 0.0, col)
	if hh(x, 22) > .4:
		Spr.P("peb%d" % int(hh(x, 23) * 2.99), x + 11, y + 3, 9 + hh(x, 24) * 5, false, 0.0, col)

func _leaves(x: float, y: float, cs: Array) -> void:
	for k in 4:
		var lx: float = x + (hh(x + k, 21) - .5) * 30
		var c: Color = cs[int(hh(x + k, 22) * cs.size()) % cs.size()]
		Spr.ellipse(lx, y - 1.5, 5, 2, c, (hh(x + k, 23) - .5) * .8)
		Spr.seg(lx - 4, y - 1.5, lx + 4, y - 1.5, c.darkened(.35), 1)

func _puddle(x: float, y: float) -> void:
	var w: float = 18 + hh(x, 24) * 16
	Spr.ellipse(x, y + 1, w, 3.5, Color(.16, .24, .26, .9))
	Spr.ellipse(x - w * .2, y + .5, w * .45, 1.2, Color(.7, .85, .9, .55))

func _snow_mound(x: float, y: float) -> void:
	var w: float = 14 + hh(x, 25) * 14
	Spr.ellipse(x, y - 3, w, 6 + w * .18, Color(.8, .87, .97))
	Spr.ellipse(x - 2, y - 5, w * .85, 4.5 + w * .15, Color(.97, .98, 1))
	Spr.ellipse(x - w * .35, y - 8 - w * .1, w * .25, 1.5, Color(1, 1, 1))

func _tiny_mush(x: float, y: float) -> void:
	Spr.P("mush3" if hh(x, 27) > .5 else "mush1", x, y + 2, 18 + hh(x, 28) * 8, hh(x, 29) > .5, 0.0, Color(.85, .82, .9))

func _root_curl(x: float, y: float) -> void:
	var pts := PackedVector2Array()
	var dir: float = 1.0 if hh(x, 26) > .5 else -1.0
	for i in 9:
		var u := i / 8.0
		pts.push_back(Vector2(x + dir * (u * 16 + sin(u * 5.0) * 4), y + u * 14 + u * u * 6))
	Spr.line(pts, Color(.24, .15, .08), 3.2)
	Spr.line(pts, Color(.45, .3, .16), 1.4)

## até onde a ponta aberta fica à mostra: o topo do vizinho mais baixo encostado nela (degrau,
## buraco da placa), se ele descer até o fundo do bloco; INF se a ponta é um barranco inteiro
func _end_lo(s: Dictionary, right: bool) -> float:
	var key := "_lr" if right else "_ll"
	if s.has(key):
		return s[key]
	var ex: float = s.x + s.w if right else s.x
	var lo := INF
	for o in game.L.solids:
		if o == s or not str(o.get("t", "")) in ["ground", "dirt", "cliff"]:
			continue
		var oy: float = float(o.y)
		var ob: float = oy + float(o.get("h", 0))
		var touch: bool = ex >= float(o.x) - 1 and ex <= float(o.x) + float(o.get("w", 0)) + 1
		if touch and oy > s.y + 2 and oy <= s.y + 60.0 and ob >= s.y + s.h - 4:
			lo = min(lo, oy)
	s[key] = lo
	return lo

## a ponta: a textura do chão num polígono com a quina de cima arredondada, a parede um pouco
## irregular, sombra na borda e um tufo de grama caindo por cima
func _ground_end(s: Dictionary, t: Texture2D, tw: float, right: bool, lo: float = INF) -> void:
	var e: float = s.x + s.w if right else s.x
	var inner: float = e - ROUND if right else e + ROUND
	var top: float = s.y - 10
	var fy: float = s.y - 34 + t.get_height()
	var bot: float = s.y + min(s.h, 900.0)
	# vizinho um pouco mais baixo: a beira só vai até o chão dele (o resto é terra inteira)
	var short: bool = lo < bot - 12.0
	if short:
		bot = lo + 12.0
	var tile_x: float = s.x + floor((min(inner, e) - s.x) / tw) * tw
	var t2: Texture2D = _chao2(t, tw)
	var seed_v: float = e * .013
	var inset := func(y: float) -> float:
		var r := ROUND - 4
		var c: float = 0.0
		if y < s.y + r:
			var dy: float = (s.y + r) - y
			c = r - sqrt(max(0.0, r * r - dy * dy))
		var wob: float = 2.5 * sin(y * .09 + seed_v) + 1.5 * sin(y * .23 + seed_v * 3.0)
		var bc: float = 0.0
		if s.h < 300 and not short and y > bot - r:
			var dy2: float = y - (bot - r)
			bc = r - sqrt(max(0.0, r * r - dy2 * dy2))
		return clamp(c + 2.0 + wob + bc, 0.0, ROUND - 1)
	# parte de cima: a textura do chão (grama + terra com raízes); embaixo, terra lisa
	var y_tex: float = min(fy, bot)
	var gt := _ground_tint(e)
	_end_band(top, y_tex, 8.0, inner, e, right, inset, t2, tile_x, s.y - 32, gt, Color(.86, .83, .8) * gt)
	if bot > y_tex + 1:
		_end_band(y_tex, bot, 30.0, inner, e, right, inset, null, 0, 0, Color("#34200f"), Color("#2a190b"))
	# tufo de grama arredondando a quina de cima
	var gx: float = e - 6.0 if right else e + 6.0
	var gc := Color(.36, .58, .2)
	if s.get("snow"):
		Spr.ellipse(gx, s.y - 3, 15, 7, Color(.96, .98, 1))
	elif gt_at(game, e) != "":
		_pebbles(gx, s.y, Color(.45, .42, .4))
	else:
		# tufo de grama pintado caindo por cima da quina
		Spr.P("grass%d" % int(hh(e, 41) * 5), gx, s.y + 4, 24, right, 0.0, _ground_tint(e))
	# pedrinhas soltas na parede
	for k in 2:
		var py: float = s.y + 30 + k * 34
		if py < bot - 10:
			var px: float = (e - 6.0 - k * 3) if right else (e + 6.0 + k * 3)
			Spr.ellipse(px, py, 4, 3, Color(.45, .36, .28, .8))

## uma faixa da ponta: lado de dentro reto, lado de fora pelo contorno (inset)
func _end_band(ya: float, yb: float, stp: float, inner: float, e: float, right: bool, inset: Callable,
		tex: Texture2D, tile_x: float, ty: float, c_in: Color, c_out: Color) -> void:
	var ys: Array = []
	var yy: float = ya
	while yy < yb:
		ys.append(yy)
		yy += stp
	ys.append(yb)
	var pts := PackedVector2Array()
	var cols := PackedColorArray()
	for y in ys:
		pts.push_back(Vector2(inner, y))
		cols.push_back(c_in)
	for i in range(ys.size() - 1, -1, -1):
		var ins: float = inset.call(ys[i])
		pts.push_back(Vector2(e - ins if right else e + ins, ys[i]))
		cols.push_back(c_out)
	if tex == null:
		Spr.ci.draw_polygon(pts, cols)
		return
	var uvs := PackedVector2Array()
	var tw: float = tex.get_width()
	var th: float = tex.get_height()
	for p in pts:
		uvs.push_back(Vector2(clamp((p.x - tile_x) / tw, 0.0, 1.0), clamp((p.y - ty) / th, 0.0, 1.0)))
	Spr.ci.draw_polygon(pts, cols, uvs, tex)

## camada de neve por cima do chão (com bordas fofas)
func _snow_top(xa: float, xb: float, y: float) -> void:
	Spr.rect(xa, y - 6, xb - xa, 14, Color(.95, .97, 1))
	Spr.rect(xa, y + 6, xb - xa, 4, Color(.78, .85, .96))
	# volume: sombra azulada embaixo do monte de neve e brilho quente no topo
	Spr.vgrad(xa, y + 2, xb - xa, 8, Color(.7, .78, .95, 0), Color(.62, .7, .92, .55))
	Spr.rect(xa, y - 7, xb - xa, 2, Color(1, .98, .92, .7))
	var x: float = floor(xa / 26.0) * 26.0
	while x < xb:
		var hgt: float = 4 + fmod(x * 7.31, 5.0)
		Spr.ellipse(x + 13, y - 5, 16, hgt, Color(.97, .98, 1))
		x += 26

## até onde descem as pernas do cavalete: o chão firme logo embaixo (antes iam sempre até y=700 e
## atravessavam o chão da galeria); sem chão embaixo (vão da mina) continuam para o escuro
static func leg_floor(s: Dictionary, x: float) -> float:
	var key := "_lf%d" % int(x - float(s.x))
	if s.has(key):
		return s[key]
	var best := 700.0
	var g: Game = Polish.g
	if g != null and g.L:
		for o in g.L.solids:
			if o.get("deco") or not str(o.get("t", "")) in ["ground", "dirt", "stone", "cliff", "rockw"]:
				continue
			if x >= float(o.x) and x <= float(o.x) + float(o.get("w", 0)) and float(o.y) > float(s.y) + 16 and float(o.y) < best:
				best = float(o.y) + 4.0
	s[key] = best
	return best

static func plat(s: Dictionary) -> void:
	if s.get("crumble"):
		return
	if s.get("trestle"):
		var wood := Color("#4a3220")
		for lx in [s.x + 8, s.x + s.w - 16]:
			Spr.rect(lx, s.y + 10, 8, leg_floor(s, lx + 4) - s.y - 6, wood)
		# cruz de travamento: nunca abaixo do chão (cavaletes baixos ficam com a cruz menor)
		var cb: float = min(s.y + 120.0, min(leg_floor(s, s.x + 12), leg_floor(s, s.x + s.w - 12)) - 8.0)
		if cb > s.y + 40.0:
			Spr.seg(s.x + 12, s.y + 30, s.x + s.w - 12, cb, wood, 5)
			Spr.seg(s.x + s.w - 12, s.y + 30, s.x + 12, cb, wood, 5)
	# tábuas separadas (cada uma com veio e prego), pontas arredondadas e um pouco irregulares
	var bx: float = s.x
	var bi := 0
	while bx < s.x + s.w - 2:
		var bw: float = min(36.0 + hh(s.x + bi, 61) * 26.0, s.x + s.w - bx)
		if s.x + s.w - (bx + bw) < 14:
			bw = s.x + s.w - bx
		var jy: float = (hh(s.x - bi, 62) - .5) * 2.5
		# tábua pintada (veios, nós e pregos): um pedaço diferente da madeira para cada tábua
		var u0: float = hh(s.x + bi * 7, 64) * .6
		var m: float = .9 + hh(s.x + bi * 3, 63) * .15
		Spr.PRs("seesaw_plank", bx, s.y - 1 + jy, bw, 18, u0, u0 + min(.4, bw / 180.0), Color(m, m, m))
		Spr.circle(bx + 5, s.y + 8 + jy, 1.4, Color(.25, .22, .2))
		Spr.circle(bx + bw - 5, s.y + 8 + jy, 1.4, Color(.25, .22, .2))
		bx += bw
		bi += 1
	if s.get("hatch"):
		return
	Spr.seg(s.x + 10, s.y + 16, s.x + 4, s.y + 40, Color(0, 0, 0, .35), 2)
	Spr.seg(s.x + s.w - 10, s.y + 16, s.x + s.w - 4, s.y + 40, Color(0, 0, 0, .35), 2)

## galho (desenhado a cada quadro pela camada que se mexe, já descido em "dip"): verga sob o peso do
## Tomé (a ponta presa no tronco quase não desce), balança depois que ele sai, e ganha casca, raminhos,
## folhas na ponta, toco quebrado, musgo na chuva e neve por cima (que cai quando o Tomé pousa)
static func branch(s: Dictionary) -> void:
	var g: Game = Polish.g
	var T: int = g.T if g != null else 0
	var t: Texture2D = Spr.tex.galho
	var bx: float = s.x - 12
	var bw: float = s.w + 24
	var by: float = s.y - 14
	var bh := 60.0
	if g == null:
		Spr.img(t, bx, by, bw, bh)
		return
	if not s.has("_att"):
		_branch_info(g, s)
	var att: int = s._att
	var dip: float = float(s.get("dip", 0.0))
	var px: float = s.x + s.w * .5
	if g.player.get("_g") == s:
		px = clamp(g.player.x + g.player.w * .5, s.x, s.x + s.w)
	var wv: float = sin(T * .33) * float(s.get("_wob", 0.0)) * 2.4
	var N := 10
	var offs := PackedFloat32Array()
	var pts := PackedVector2Array()
	var uvs := PackedVector2Array()
	for i in N + 1:
		var u: float = float(i) / N
		# f: quanto este ponto desce/balança (0 = preso no tronco, 1 = ponta solta)
		var f: float = u if att < 0 else (1.0 - u if att > 0 else .45 + .55 * abs(u - .5) * 2.0)
		var k: float = exp(-pow((bx + bw * u - px) / (bw * .4), 2.0))
		var sink: float = clamp(max(f, k * .85), 0.0, 1.0)
		offs.push_back(-dip * (1.0 - sink) + wv * f)
	for i in N + 1:
		pts.push_back(Vector2(bx + bw * i / N, by + offs[i]))
		uvs.push_back(Vector2(float(i) / N, 0.0))
	for i in range(N, -1, -1):
		pts.push_back(Vector2(bx + bw * i / N, by + bh + offs[i]))
		uvs.push_back(Vector2(float(i) / N, 1.0))
	Spr.ci.draw_polygon(pts, PackedColorArray([Spr.col(Color.WHITE)]), uvs, t)
	if g.low_fx:
		return
	var th: String = s._th
	var yat := func(u: float) -> float:
		var fi: float = clamp(u, 0.0, 1.0) * N
		var i0: int = min(int(fi), N - 1)
		return by + lerpf(offs[i0], offs[i0 + 1], fi - i0)
	# casca: dois veios escuros ao longo da madeira (a madeira desce um pouco para a ponta direita)
	var gl := PackedVector2Array()
	for v in [[.33, .43], [.44, .58]]:
		for i in range(1, N - 1):
			var u0: float = float(i) / N
			var u1: float = float(i + 1) / N
			gl.push_back(Vector2(bx + bw * u0, yat.call(u0) + bh * lerpf(v[0], v[1], u0) + sin(u0 * 23.0 + s.x) * 1.2))
			gl.push_back(Vector2(bx + bw * u1, yat.call(u1) + bh * lerpf(v[0], v[1], u1) + sin(u1 * 23.0 + s.x) * 1.2))
	Spr.ci.draw_multiline(gl, Spr.col(Color(.2, .11, .05, .32)), 1.2, true)
	# toco de galho quebrado embaixo (alguns galhos), raminhos na ponta fina com um tufo de folhas da cor
	# do trecho e musgo na chuva: tudo num lote de triângulos (uma chamada)
	if s._stub > 0.0:
		var su: float = s._stub
		var sx: float = bx + bw * su
		var sy: float = yat.call(su) + bh * lerpf(.45, .62, su)
		bt_seg(Vector2(sx, sy), Vector2(sx + 5, sy + 9), Color("#3e2714"), 5)
		bt_ellipse(sx + 5, sy + 10, 3, 2, Color("#b08a5a"), 0.0, 8)
	var tx: float = bx + 6
	var ty: float = yat.call(0.02) + bh * .3
	bt_seg(Vector2(tx, ty), Vector2(tx - 9, ty - 10), Color("#4a2e18"), 2)
	bt_seg(Vector2(tx - 5, ty - 5), Vector2(tx - 3, ty - 15), Color("#4a2e18"), 1.5)
	if th != "neve":
		var lc: Color = Color(.86, .45, .14) if th == "tarde" else (Color(.32, .45, .2) if th == "chuva" else Color(.4, .62, .24))
		for j in 4:
			var la: float = -2.2 + j * .55 + sin(T * .05 + j + s.x) * .08
			bt_ellipse(tx - 6 + cos(la) * 8, ty - 11 + sin(la) * 6, 4.5, 2.2, lc.darkened(j * .06), la, 8)
	if th == "chuva":
		for j in 3:
			var mu: float = .25 + j * .22
			bt_ellipse(bx + bw * mu, yat.call(mu) + bh * .3, 9, 3, Color(.26, .42, .16, .7))
	bt_flush()
	# neve por cima (some quando o Tomé pousa e volta aos poucos)
	if th == "neve":
		var na: float = 1.0
		if s.has("_snow_t"):
			na = clamp((T - int(s._snow_t) - 600) / 300.0, 0.0, 1.0)
		if na > 0.0:
			# neve fofa: montinhos irregulares assentados na madeira (um lote só)
			var j := 0
			var u: float = .06
			while u < .95:
				var sw: float = 7.0 + hh(s.x + j, 123) * 9.0
				var sh: float = 2.5 + hh(s.x - j, 124) * 2.2
				var sx2: float = bx + bw * u
				var sy2: float = yat.call(u) + bh * lerpf(.25, .33, u) - 1.5
				bt_ellipse(sx2, sy2 + 1.5, sw + 1, sh + .5, Color(.72, .8, .94, .8 * na), 0.0, 10)
				bt_ellipse(sx2, sy2, sw, sh, Color(.97, .98, 1, na), 0.0, 10)
				u += (sw * 1.3) / bw
				j += 1
			bt_flush()

## ponta presa no tronco (-1 esquerda, 1 direita, 0 solto), clima e toco quebrado do galho
static func _branch_info(g: Game, s: Dictionary) -> void:
	var att := 0
	for o in g.L.solids:
		if not str(o.get("t", "")) in ["trunk", "deadtree"]:
			continue
		if o.y > s.y + 40 or o.y + o.get("h", 0) < s.y - 20:
			continue
		if abs(s.x - (o.x + o.w * .5)) < o.w + 20:
			att = -1
		elif abs(s.x + s.w - (o.x + o.w * .5)) < o.w + 20:
			att = 1
	s._att = att
	s._th = theme_at(g, s.x + s.w * .5)
	s._stub = .35 + hh(s.x, 121) * .3 if hh(s.x, 120) > .5 else 0.0

func trunk(s: Dictionary) -> void:
	# sombra da copa no chão, o tronco entrando na terra e as raízes num montinho de terra e grama
	_tree_shade(s)
	_roots_flare(s)
	Spr.img(Spr.tex.tronco, s.x - s.w * .75, s.y - 10, s.w * 2.5, s.h + 28)
	_root_mound(s.x + s.w / 2, s.y + s.h, s.w)
	_bark(s)

func _root_mound(cx: float, gy: float, w: float) -> void:
	# base da árvore: sombra macia e tufos de grama pintados enraizados no musgo (nada solto no ar)
	Spr.ellipse(cx, gy + 3, w * 1.1, 6, Color(0, 0, 0, .22))
	for k in 4:
		var side: float = -1.0 if k % 2 == 0 else 1.0
		var gx: float = cx + side * (w * .55 + (k / 2) * 14.0)
		var kind: int = int(hh(gx, 31) * 5)
		Spr.P("grass%d" % kind, gx, gy + 4, 22.0 + (k / 2) * 4.0, side > 0, 0.0, _ground_tint(gx))

func cabin(s: Dictionary) -> void:
	Spr.AB("o_cabin", s.x - 15, s.y + s.h - 221, 330, 221)

func treehouse(s: Dictionary) -> void:
	var r = Spr.AR.o_treehouse
	var w := 280.0
	var hh: float = w * r[3] / r[2]
	Spr.AB("o_treehouse", s.x + s.w / 2 - w / 2, s.y + s.h + 8 - hh, w, hh)

func root_log(s: Dictionary) -> void:
	var x: float = s.x
	var y: float = s.y
	var w: float = s.w
	var h: float = s.h
	var r := w / 6
	Spr.rr(x + 6, y + 20, w - 12, h - 30, r * .8, Color("#24160c"))
	var rows = [[3, y + h - r - 4], [3, y + h - r * 3 - 6], [2, y + h - r * 5 - 8]]
	for k in 3:
		var n: int = rows[k][0]
		var cy: float = rows[k][1]
		for i in n:
			var cx: float = x + r + (r if k == 2 else 0.0) + i * r * 2
			# ponta cortada pintada (casca, anéis, rachaduras), cada tora de um tamanho e giro
			var rr2: float = r * (1.02 + hh(cx + cy, 71) * .1)
			Spr.save()
			Spr.translate(cx, cy)
			Spr.rotate(hh(cx, 72) * TAU)
			Spr.PR("logend%d" % int(hh(cx - cy, 73) * 2.99), -rr2, -rr2, rr2 * 2, rr2 * 2)
			Spr.restore()
	# presa por cordas que sobem até o alto e dão a volta no feixe de toras (por isso fica suspensa)
	var ptop: float = y + h - r * 6 - 8
	_hang_ropes(x + w * .22, x + w * .78, ptop, 0.0)
	_wrap(x - 3, ptop - 2, w + 6, y + h - ptop + 2, r, false)
	# sombra no chão embaixo da pilha suspensa
	Spr.ellipse(x + w / 2, y + h + 24, w * .55, 6, Color(0, 0, 0, .3))

## cordas (ou correntes) grossas subindo até sair da tela, amarradas em volta da peça, com ganchos de ferro
func _hang_ropes(xa: float, xb: float, y: float, h: float, chain: bool = false) -> void:
	var top: float = y - 900
	for rx in [xa, xb]:
		if chain:
			# elos de ferro velho (alguns com pátina de ferrugem): todos os anéis em duas chamadas
			var iron := PackedVector2Array()
			var rust := PackedVector2Array()
			var yy: float = max(top, -1200.0)
			var ci_ := 0
			while yy < y:
				var arr: PackedVector2Array = rust if hh(rx + ci_, 146) > .62 else iron
				for k in 8:
					var a0: float = TAU * k / 8.0
					var a1: float = TAU * (k + 1) / 8.0
					arr.push_back(Vector2(rx + cos(a0) * 5, yy + 6 + sin(a0) * 5))
					arr.push_back(Vector2(rx + cos(a1) * 5, yy + 6 + sin(a1) * 5))
				if hh(rx + ci_, 146) > .62:
					rust = arr
				else:
					iron = arr
				yy += 10
				ci_ += 1
			if iron.size() >= 2:
				Spr.ci.draw_multiline(iron, Spr.col(Color("#6b6560")), 2.5, true)
			if rust.size() >= 2:
				Spr.ci.draw_multiline(rust, Spr.col(Color("#7a4a2a")), 2.5, true)
		else:
			Spr.PV("rope", rx - 5, top, 10, y - top + 6)
		# gancho
		Spr.ring(rx, y - 2, 7, Color("#5f5a55"), 3, PI * .1, PI * 1.6)


## laço de corda (ou corrente) dando a volta inteira na peça, com nós onde as cordas de cima chegam
func _wrap(x: float, y: float, w: float, h: float, rad: float, chain: bool) -> void:
	var pts := PackedVector2Array()
	var rr: float = min(rad, min(w, h) / 2.0)
	var corners := [[x + w - rr, y + rr, -PI / 2], [x + w - rr, y + h - rr, 0.0], [x + rr, y + h - rr, PI / 2], [x + rr, y + rr, PI]]
	for c in corners:
		for k in 7:
			var a: float = c[2] + k / 6.0 * PI / 2
			pts.push_back(Vector2(c[0] + cos(a) * rr, c[1] + sin(a) * rr))
	pts.push_back(pts[0])
	if chain:
		Spr.line(pts, Color("#3a3632"), 7)
		Spr.line(pts, Color("#6b6560"), 4)
	else:
		Spr.line(pts, Color("#5a4428"), 8)
		Spr.line(pts, Color("#a8875a"), 5)
		for i in range(0, pts.size() - 1, 2):
			Spr.circle(pts[i].x, pts[i].y, 1.2, Color("#7a5f3c"))
	for kx in [x + w * .22 + 3, x + w * .78 - 3]:
		Spr.circle(kx, y, 6, Color("#8a6a40") if not chain else Color("#4a4642"))
		Spr.ring(kx, y, 6, Color("#4a3420"), 1.5)

## paredão de pedras (rocha ou gelo): cada fileira termina onde a última pedra termina, com as
## pontas arredondadas e desencontradas — a borda segue o contorno das pedras, nada de corte reto
func _masonry(s: Dictionary, c_hi: Color, c_lo: Color, mortar: Color, y0: float) -> void:
	# só as pedras que caem na faixa deste pedaço (o resto é cortado pelo clip de qualquer jeito), e em
	# três passadas para o Godot juntar os desenhos: argamassa, pedras pintadas, luz/sombra/rachaduras
	var cx0: float = x0 - 16
	var cx1: float = x1 + 16
	var yy: float = y0
	var row := 0
	var seed_x: float = s.x * .37 + s.y * .11
	var stones: Array = []
	var hi := PackedVector2Array()
	var lo_ := PackedVector2Array()
	var cr := PackedVector2Array()
	while yy < s.y + s.h - 4:
		var bh: float = 30.0 + hh(seed_x + row, 33) * 24.0
		var hb: float = min(bh, s.y + s.h - yy + 6)
		# pontas da fileira: entram ou saem um pouco da linha da parede
		var lo: float = s.x + (hh(seed_x + row, 31) - .35) * 16.0
		var ro: float = s.x + s.w - (hh(seed_x + row, 32) - .35) * 16.0
		# argamassa (fundo escuro da fileira), também arredondada nas pontas (cortada perto do pedaço)
		var ma: float = max(lo - 3, cx0 - 20)
		var mb: float = min(ro + 3, cx1 + 20)
		if mb > ma:
			Spr.rr(ma, yy - 2, mb - ma, hb + 4, 14, mortar)
		var u: float = clamp((yy - s.y) / max(1.0, s.h), 0, 1)
		var x: float = lo
		var i := 0
		while x < ro - 10:
			# pedra pintada (textura de rocha com rachaduras e musgo), larga no máximo ~1,8x a altura
			var bw: float = hb * (1.05 + hh(seed_x + row * 13 + i, 34) * .8)
			if ro - (x + bw) < hb * .7:
				bw = ro - x
			var bx: float = x + 1
			var bww: float = bw - 2
			if bx + bww + 6 >= cx0 and bx - 6 <= cx1:
				var jy: float = (hh(seed_x + row * 7 + i, 35) - .5) * 5.0
				var shade: float = (hh(seed_x + row * 3 + i, 36) - .5) * .1
				var m: float = 1.0 - u * .38 + shade
				var byy: float = yy + max(jy, 0.0)
				var bhh: float = hb - 1 - abs(jy)
				if bww > 8 and bhh > 6:
					var pick: int = int(hh(seed_x + row * 5 + i * 11, 37) * 6)
					stones.append([pick, bx, byy, bww, bhh, Color(m * c_hi.r, m * c_hi.g, m * c_hi.b), hh(seed_x + i, 38) > .5])
					# volume: luz no topo da pedra, sombra embaixo e uma rachadura de vez em quando
					hi.push_back(Vector2(bx + 4, byy + 2))
					hi.push_back(Vector2(bx + bww - 4, byy + 2))
					lo_.push_back(Vector2(bx + 3, byy + bhh - 2.5))
					lo_.push_back(Vector2(bx + bww - 3, byy + bhh - 2.5))
					if hh(bx, 39) > .6:
						cr.push_back(Vector2(bx + bww * .3, byy + bhh * .3))
						cr.push_back(Vector2(bx + bww * .42, byy + bhh * .6))
			x += bw
			i += 1
		yy += bh
		row += 1
	# um pouco maior que a vaga: os contornos se encostam e o muro fica fechado
	for st in stones:
		Spr.PR("wb%d" % st[0], st[1] - 4, st[2] - 4, st[3] + 8, st[4] + 7, st[5], st[6])
	if hi.size() >= 2:
		Spr.ci.draw_multiline(hi, Spr.col(Color(1, .98, .9, .18)), 2.0)
		Spr.ci.draw_multiline(lo_, Spr.col(Color(0, 0, 0, .16)), 3.0)
	if cr.size() >= 2:
		Spr.ci.draw_multiline(cr, Spr.col(Color(0, 0, 0, .2)), 1.0)

## faixa de chão (grama e terra) no topo de um paredão, com as pontas arredondadas como o chão
func _cap(s: Dictionary) -> void:
	# o paredão inteiro é desenhado pelo pedaço onde ele começa: a grama do topo também vai até o fim
	# (antes ela parava na emenda do pedaço e o Tomé parecia flutuar sobre as pedras)
	# (agora cada pedaço que o paredão cruza desenha a sua parte: o clip corta na emenda)
	var fake := {"x": s.x - 6, "y": s.y, "w": s.w + 12, "h": 30, "_ol": true, "_or": true, "t": "ground"}
	ground(fake)

func snow_cliff(s: Dictionary) -> void:
	_masonry(s, Color(.86, .93, 1.06), Color(.42, .5, .66), Color(.24, .28, .38, .95), s.y + 10)
	_snow_cap(s.x, s.x + s.w, s.y)
	if s.get("overhang"):
		# beirada de neve fofa embaixo, com pingentes de gelo
		var by: float = s.y + s.h
		Spr.rr(s.x - 6, by - 18, s.w + 12, 20, 10, Color(.85, .93, 1))
		var ix: float = s.x + 8
		var n := 0
		while ix < s.x + s.w - 8:
			var L2: float = 14 + (n * 37 % 5) * 6
			Spr.poly(PackedVector2Array([Vector2(ix - 6, by), Vector2(ix, by + L2), Vector2(ix + 6, by)]), Color(.85, .95, 1, .95))
			_icicle_reg(ix, by + L2)
			ix += 22
			n += 1

## neve por cima de um bloco, com as pontas fofas e arredondadas (sem corte reto)
func _snow_cap(xa: float, xb: float, y: float) -> void:
	Spr.rr(xa - 8, y - 9, xb - xa + 16, 20, 10, Color(.97, .98, 1))
	Spr.rr(xa - 2, y + 6, xb - xa + 4, 6, 3, Color(.78, .85, .96))
	var x: float = xa + 6
	while x < xb - 6:
		var hgt: float = 4 + fmod(x * 7.31, 5.0)
		Spr.ellipse(x + 10, y - 6, 15, hgt, Color(.97, .98, 1))
		x += 24
	Spr.ellipse(xa - 4, y + 1, 10, 9, Color(.97, .98, 1))
	Spr.ellipse(xb + 4, y + 1, 10, 9, Color(.97, .98, 1))

func cliff(s: Dictionary) -> void:
	if s.get("snow"):
		snow_cliff(s)
		return
	# rocha maciça: pedras encaixadas com a borda seguindo as pedras; grama só no topo
	_masonry(s, Color(1, .97, .92), Color(.3, .25, .2), Color(.16, .12, .09, .97), s.y + 24)
	_cap(s)

func dead_tree(s: Dictionary) -> void:
	# árvore morta com casca pintada, galhos secos e musgo pendurado
	var t: Texture2D = Spr.tex.tronco
	var gx: float = s.x + s.w * .5
	Spr.ci.draw_texture_rect(t, Rect2(s.x - 6, s.y + 10, s.w + 12, s.h - 6), false, Color(.72, .7, .66))
	# raízes abertas no chão
	for r in [-1.0, 1.0]:
		Spr.poly(PackedVector2Array([Vector2(gx + r * 10, s.y + s.h - 40), Vector2(gx + r * (s.w * .5 + 22), s.y + s.h + 2), Vector2(gx + r * 8, s.y + s.h + 2)]), Color("#4e3a2a"))
	# galhos secos (tora pintada fina)
	for br in [[-1.0, 40.0, -.7, 70.0], [1.0, 70.0, .55, 60.0], [-1.0, 140.0, -.35, 46.0], [1.0, 10.0, .9, 50.0]]:
		Spr.save()
		Spr.translate(gx + br[0] * s.w * .3, s.y + br[1])
		Spr.rotate(br[2] - PI / 2 * br[0] * 0.0)
		Spr.rotate(-PI / 2 if br[0] < 0 else PI / 2)
		Spr.rotate(-br[2] * .6)
		Spr.PR("log", -5, -br[3], 10, br[3], Color(.7, .66, .6))
		Spr.restore()
	# toco quebrado no alto
	Spr.poly(PackedVector2Array([Vector2(s.x - 6, s.y + 14), Vector2(s.x + 6, s.y - 6), Vector2(s.x + 18, s.y + 10), Vector2(s.x + 30, s.y - 12), Vector2(s.x + s.w + 6, s.y + 14)]), Color("#5e4a38"))
	# musgo: tufos verdes com brilho e fios pendurados
	var y: float = s.y + 50
	var k := 0
	while y < s.y + s.h - 30:
		var mx: float = gx + (hh(y, 62) - .5) * s.w * .6
		Spr.ellipse(mx, y, 11, 6, Color("#3f5e2a"))
		Spr.ellipse(mx - 2, y - 2, 7, 3, Color("#6b8c3a"))
		for j in 2:
			Spr.seg(mx - 4 + j * 7, y + 4, mx - 5 + j * 7, y + 16 + hh(y + j, 63) * 14, Color(.35, .5, .24, .85), 1.5)
		y += 46 + hh(y, 64) * 30
		k += 1

func planks(s: Dictionary, dark: bool) -> void:
	# tábuas de madeira pintada (com veios), cintas de ferro com rebites
	# (o cenário fixo é pintado uma vez só: o corte não pode depender de onde a câmera estava nessa hora,
	# senão a viga baixa pintada com a câmera lá embaixo ficava sem tábua nenhuma)
	var a: float = max(s.y, -1200.0)
	var b: float = s.y + s.h
	var n: int = max(1, int(round(s.w / 18.0)))
	var bw: float = s.w / n
	for i in n:
		var c := Color(.62, .55, .5) if dark else Color(.9, .84, .78)
		c = c * (1.0 + (hh(s.x + i, 61) - .5) * .18)
		# casca/veio da madeira: a textura do tronco repetida de cima a baixo
		var tt: Texture2D = Spr.tex.tronco
		var sh: float = (bw + 2) * tt.get_height() / tt.get_width() * .5
		var yy2: float = a
		while yy2 < b:
			var hh2: float = min(sh, b - yy2)
			Spr.ci.draw_texture_rect_region(tt, Rect2(s.x + i * bw - 1, yy2, bw + 2, hh2), Rect2(tt.get_width() * .3, 0, tt.get_width() * .4, tt.get_height() * hh2 / sh * .5), Color(c.r, c.g, c.b, 1))
			yy2 += sh
		Spr.seg(s.x + i * bw, a, s.x + i * bw, b, Color(.1, .06, .03, .5), 1.5)
		# veios e nós da madeira, borda gasta mais clara
		var gy0: float = a + hh(s.x + i, 65) * 40
		while gy0 < b - 10:
			if hh(gy0 + i, 66) > .55:
				Spr.ellipse(s.x + i * bw + bw * .5, gy0, 2.6, 4.2, Color(.18, .1, .05, .45))
				Spr.ring(s.x + i * bw + bw * .5, gy0, 4.5, Color(.2, .12, .06, .25), 1.0)
			gy0 += 60 + hh(gy0, 67) * 50
		Spr.seg(s.x + i * bw + 2, a, s.x + i * bw + 2, b, Color(1, .95, .85, .12), 1.0)
	var y: float = s.y + 30
	while y < b:
		if y > a - 10:
			Spr.rr(s.x - 3, y, s.w + 6, 9, 2, Color("#3c3a40"))
			Spr.rect(s.x - 3, y + 1, s.w + 6, 2, Color(.75, .75, .8, .35))
			# ferrugem: manchas alaranjadas na cinta e escorridos descendo dos rebites
			for k in 3:
				var rx: float = s.x + 6 + k * (s.w - 12) / 2.0
				if hh(rx + y, 141) > .35:
					Spr.ellipse(rx + (hh(rx, 142) - .5) * 10, y + 5, 5 + hh(y, 143) * 5, 2.6, Color(.55, .27, .1, .45))
					Spr.seg(rx, y + 8, rx + (hh(rx, 144) - .5) * 2, y + 14 + hh(rx + 1, 145) * 12, Color(.5, .25, .1, .32), 1.6)
				Spr.circle(rx, y + 4.5, 1.6, Color(.7, .7, .74))
		y += 90

## bloco de gelo (as "pedras" da neve): lascado nos cantos, com facetas, brilho e neve fofa por cima
func ice_block(s: Dictionary) -> void:
	var x: float = s.x
	var y: float = s.y
	var w: float = s.w
	var h: float = s.h
	Spr.ellipse(x + w / 2, y + h + 2, w * .55, 6, Color(0, 0, 0, .18))
	var k: float = float(hash(int(x)) % 97) / 97.0
	# contorno com cantos lascados (cada bloco do seu jeito)
	var c1: float = 6 + k * 8
	var c2: float = 5 + (1.0 - k) * 9
	var pts := PackedVector2Array([
		Vector2(x + c1, y), Vector2(x + w * .55, y - 2), Vector2(x + w - c2, y + 1), Vector2(x + w + 1, y + c2 + 2),
		Vector2(x + w - 1, y + h * .55), Vector2(x + w + 1, y + h - 4), Vector2(x + w - 6, y + h), Vector2(x + 7, y + h + 1),
		Vector2(x - 1, y + h - 6), Vector2(x + 1, y + h * .45), Vector2(x - 1, y + c1 + 1)])
	var cols := PackedColorArray()
	for p in pts:
		var u: float = (p.y - y) / h
		# um pouco translúcido: o fundo aparece de leve através do gelo
		cols.push_back(Color(.8, .93, 1, .84).lerp(Color(.42, .64, .86, .9), u))
	Spr.ci.draw_polygon(pts, cols)
	# miolo mais claro (o gelo parece ter espessura) e bolhas de ar presas
	Spr.ellipse(x + w * .5, y + h * .45, w * .32, h * .28, Color(.92, .98, 1, .16))
	for i in 4:
		var bxp: float = x + w * (.18 + hh(x + i, 131) * .64)
		var byp: float = y + h * (.4 + hh(x - i, 132) * .45)
		var br: float = 1.2 + hh(x + i * 3, 133) * 2.2
		bt_ellipse(bxp, byp, br, br, Color(.9, .97, 1, .35), 0.0, 8)
		bt_ellipse(bxp - br * .35, byp - br * .35, br * .4, br * .4, Color(1, 1, 1, .7), 0.0, 5)
	# faceta escura de um lado e clara do outro
	Spr.poly(PackedVector2Array([Vector2(x + w - c2, y + 1), Vector2(x + w + 1, y + c2 + 2), Vector2(x + w - 1, y + h * .55), Vector2(x + w * .72, y + h * .42)]), Color(.3, .5, .72, .3))
	Spr.poly(PackedVector2Array([Vector2(x + c1, y), Vector2(x + w * .4, y + h * .2), Vector2(x + 1, y + h * .45), Vector2(x - 1, y + c1 + 1)]), Color(1, 1, 1, .25))
	var outl := PackedVector2Array(pts)
	outl.push_back(pts[0])
	Spr.line(outl, Color(.22, .38, .58), 2.5)
	# rachaduras e reflexos
	Spr.seg(x + w * .3, y + 8, x + w * .45, y + h * .45, Color(1, 1, 1, .7), 1.5)
	Spr.seg(x + w * .45, y + h * .45, x + w * .35, y + h * .8, Color(1, 1, 1, .5), 1.2)
	Spr.seg(x + w * (.6 + k * .2), y + h * .2, x + w * .75, y + h * .55, Color(.25, .45, .65, .6), 1.2)
	# rachadura fina saindo de um canto, com galhinhos
	var q0 := Vector2(x + w - 4, y + h - 6)
	var q1 := q0 + Vector2(-w * .22, -h * (.18 + k * .1))
	var q2 := q1 + Vector2(-w * .12, -h * .2)
	var fr := PackedVector2Array([q0, q1, q1, q2, q1, q1 + Vector2(-2, h * .14)])
	# borda de geada: pontinhos brancos e um fio claro por dentro do contorno
	for i in pts.size():
		var pa: Vector2 = pts[i]
		var pb: Vector2 = pts[(i + 1) % pts.size()]
		var m := (pa + pb) * .5
		var inn := (Vector2(x + w * .5, y + h * .5) - m).normalized() * 3.0
		fr.push_back(pa + inn)
		fr.push_back(pb + inn)
		bt_ellipse(m.x + inn.x * .5, m.y + inn.y * .5, 1.3, 1.3, Color(1, 1, 1, .75), 0.0, 6)
	Spr.ci.draw_multiline(fr, Spr.col(Color(1, 1, 1, .3)), 1.0, true)
	# pingentes embaixo quando o bloco está no alto (sem chão logo abaixo)
	if _floor_below(x + w * .5, y + h) - (y + h) > 20:
		var ix: float = x + 8
		var n := 0
		while ix < x + w - 6:
			var ln: float = 7 + hh(ix, 134) * 12
			bt_quad(Vector2(ix - 4, y + h - 1), Vector2(ix + 4, y + h - 1), Vector2(ix, y + h + ln), Vector2(ix, y + h + ln), Color(.82, .94, 1, .9))
			bt_seg(Vector2(ix - 1.5, y + h), Vector2(ix - .5, y + h + ln * .7), Color(1, 1, 1, .6), 1.0)
			_icicle_reg(ix, y + h + ln)
			ix += 12 + hh(ix, 135) * 10
			n += 1
	bt_flush()
	# neve fofa por cima, escorrendo nas pontas
	Spr.ellipse(x + w / 2, y - 1, w * .5 + 3, 7, Color(.97, .98, 1))
	Spr.ellipse(x + 4, y + 3, 7, 6, Color(.97, .98, 1))
	Spr.ellipse(x + w - 4, y + 4, 6, 7, Color(.97, .98, 1))

func stone(s: Dictionary) -> void:
	if s.get("ice"):
		ice_block(s)
		return
	var h := hash(int(s.x) * 31 + int(s.y))
	var cx: float = s.x + s.w / 2
	var gy: float = s.y + s.h
	if s.get("perch"):
		# laje apoiada no topo de um tronco velho (o tronco é desenhado com as árvores)
		Spr.ellipse(cx, gy + 2, s.w * .45, 5, Color(0, 0, 0, .3))
		Spr.PR("slab%d" % (hash(int(s.x)) % 3), s.x - 10, s.y - 4, s.w + 20, s.h + 6)
		return
	if s.h <= s.w * .9 + 12:
		var fy: float = _floor_below(cx, gy)
		if fy - gy > 30:
			# pedra no alto: é o topo de um pilar de rocha que vem do chão (um pouco atrás, mais escuro)
			var pw: float = s.w * .8
			var pil := {"x": cx - pw / 2, "y": gy - 4, "w": pw, "h": fy - gy + 8}
			_masonry(pil, Color(.62, .58, .54), Color(.3, .25, .2), Color(.1, .08, .06, .97), gy - 4)
			Spr.ellipse(cx, fy + 2, pw * .7, 6, Color(0, 0, 0, .25))
			Spr.PR("slab%d" % (hash(int(s.x)) % 3), s.x - 10, s.y - 4, s.w + 20, s.h + 6)
			return
		# pedra baixa: um bloco de rocha com musgo, meio enterrado no chão
		Spr.ellipse(cx, gy + 2, s.w * .62, 7, Color(0, 0, 0, .25))
		Spr.PR("mossrock_l", s.x - 8, s.y - 8, s.w + 16, s.h + 16)
		_weather_coat(s.x - 4, s.y - 4, s.w + 8, s.h + 8)
		return
	# degrau de rocha (pedras em escada): um maciço firme que sai da terra, mais largo embaixo,
	# com uma laje achatada em cima onde o Tomé pisa — nada equilibrado na ponta
	var base_w: float = s.w + 26
	Spr.ellipse(cx, gy + 4, base_w * .62, 9, Color(0, 0, 0, .28))
	var body := {"x": s.x - 4, "y": s.y + 12, "w": s.w + 8, "h": s.h - 6}
	_masonry(body, Color(.95, .92, .86), Color(.3, .25, .2), Color(.16, .12, .09, .97), s.y + 14)
	# pé alargado: pedras grandes encostadas na base, enterradas na terra
	for k in [-1, 1]:
		var fw: float = 26 + ((h >> (k + 2)) & 7) * 2.0
		Spr.PR("mossrock_s", cx + k * (s.w / 2 + 2) - fw / 2, gy - fw * .55, fw, fw * .7, Color(.9, .88, .84), k > 0)
	# laje de cima: plana, com musgo, um pouco mais larga que a coluna
	var lw: float = s.w + 18
	var lh: float = 26.0
	Spr.PR("slab%d" % (h % 3), cx - lw / 2, s.y - 6, lw, lh)
	_weather_coat(s.x - 4, s.y - 6, s.w + 8, s.h + 6)
	# trepadeira descendo de um lado
	var vx: float = s.x + (6.0 if h % 2 == 0 else s.w - 8)
	var vl: float = min(s.h * .6, 140.0)
	var pts := PackedVector2Array()
	for j in 12:
		var u := j / 11.0
		pts.push_back(Vector2(vx + sin(u * 5.0 + h) * 4, s.y + 12 + u * vl))
	Spr.line(pts, Color("#3f6a2a"), 3)
	for j in range(1, 11, 2):
		var p: Vector2 = pts[j]
		Spr.ellipse(p.x + (5 if j % 4 == 1 else -5), p.y, 6, 3, Color("#5c8d38"), .5 if j % 4 == 1 else -.5)

## chão firme logo abaixo de (x, y) (para apoiar o que está no alto)
func _floor_below(x: float, y: float) -> float:
	var best := 99999.0
	for o in game.L.solids:
		if str(o.get("t", "")) in ["ground", "dirt", "cliff", "stone"] and x >= o.x and x <= o.x + o.get("w", 0) and o.y >= y - 2 and o.y < best:
			best = o.y
	return best if best < 99999.0 else y

func hill(s: Dictionary) -> void:
	var pts := PackedVector2Array()
	var a := Vector2(s.x - 80, s.y + s.h)
	pts.push_back(a)
	for i in 21:
		var t := i / 20.0
		# duas curvas suaves até o topo e de volta
		var p: Vector2
		if t < .5:
			var u := t * 2
			p = _quad(Vector2(s.x - 80, s.y + s.h), Vector2(s.x + s.w * .2, s.y + 60), Vector2(s.x + s.w / 2, s.y + 40), u)
		else:
			var u2 := (t - .5) * 2
			p = _quad(Vector2(s.x + s.w / 2, s.y + 40), Vector2(s.x + s.w * .85, s.y + 60), Vector2(s.x + s.w + 80, s.y + s.h), u2)
		pts.push_back(p)
	# o morro do túnel tem mais de 6000 px e é desenhado por todos os pedaços que ele cruza: cada pedaço
	# pinta só a sua faixa, sem depender do corte (clip) do pedaço. Sem isso, no celular em que o corte
	# falha, o fundo preto do túnel pintado pelo pedaço seguinte cobria o carrinho e a viga baixa do
	# pedaço anterior (o Tomé ficava em pé "no ar" e a passagem baixa não tinha viga)
	var ca: float = max(s.x - 80.0, x0 - 1.0)
	var cb: float = min(s.x + s.w + 80.0, x1 + 1.0)
	if cb <= ca:
		return
	var box := PackedVector2Array([Vector2(ca, s.y - 10), Vector2(cb, s.y - 10), Vector2(cb, s.y + s.h + 1), Vector2(ca, s.y + s.h + 1)])
	for part in Geometry2D.intersect_polygons(pts, box):
		Spr.poly(part, Color("#1e2a1e"))
	var ra: float = max(float(s.x), ca)
	var rb: float = min(float(s.x + s.w), cb)
	if rb > ra:
		Spr.vgrad(ra, s.y + 200, rb - ra, s.h - 200, Color("#1e2a1e"), Color("#2a2018"))
		Spr.rect(ra, s.y + s.h, rb - ra, 120, Color("#0a0806"))
	var wood := Color("#5a3d22")
	Spr.rect(s.x - 14, s.y + s.h - 10, 22, 130, wood)
	Spr.rect(s.x - 24, s.y + s.h - 20, 110, 18, wood)
	Spr.rect(s.x + s.w - 8, s.y + s.h - 10, 22, 130, wood)
	Spr.rect(s.x + s.w - 90, s.y + s.h - 20, 110, 18, wood)

func _quad(p0: Vector2, p1: Vector2, p2: Vector2, t: float) -> Vector2:
	return p0.lerp(p1, t).lerp(p1.lerp(p2, t), t)

## celeiro/barracão: tábuas de tons diferentes com contorno, portas baixas nas pontas, telhado
## vermelho de telhas e uma janelinha redonda na empena (antes era um bloco marrom chapado)
func shed(s: Dictionary) -> void:
	var ol := Color("#2a1a0e")
	var x0s: float = s.x + 20
	var x1s: float = s.x + s.w - 20
	var yb: float = s.y + 120
	# sombra no chão e parede de tábuas
	Spr.ellipse(s.x + s.w / 2, yb + 2, s.w * .55, 8, Color(0, 0, 0, .28))
	Spr.rect(x0s - 2, s.y + 18, x1s - x0s + 4, yb - s.y - 18, ol)
	var tones := [Color("#8a5d36"), Color("#7a5030"), Color("#94653c"), Color("#70482a")]
	var x: float = x0s
	var i := 0
	while x < x1s - .5:
		var w: float = min(26.0, x1s - x)
		var c: Color = tones[int(hh(x + s.x, 71) * 4) % 4]
		Spr.rect(x, s.y + 20, w - 2, yb - s.y - 20, c)
		Spr.rect(x + 2, s.y + 22, 3, yb - s.y - 26, Color(1, .9, .7, .12))
		# nós da madeira
		if hh(x, 72) > .6:
			Spr.ellipse(x + w * .5, s.y + 40 + hh(x, 73) * 60, 2.5, 3.5, Color(.25, .15, .08, .6))
		x += w
		i += 1
	# travessas e a cruz do meio
	Spr.rect(x0s, s.y + 34, x1s - x0s, 6, Color("#5a3a1e"))
	Spr.rect(x0s, yb - 22, x1s - x0s, 6, Color("#5a3a1e"))
	var mx: float = s.x + s.w / 2
	Spr.seg(mx - 34, s.y + 42, mx + 34, yb - 24, Color("#5a3a1e"), 5)
	Spr.seg(mx + 34, s.y + 42, mx - 34, yb - 24, Color("#5a3a1e"), 5)
	# portas baixas nas duas pontas (é por elas que o Tomé entra abaixado)
	for dx in [x0s + 6, x1s - 42]:
		Spr.rect(dx - 3, yb - 58, 42, 58, ol)
		Spr.rect(dx, yb - 55, 36, 55, Color("#1e140c"))
		Spr.rect(dx, yb - 55, 36, 4, Color("#6b4626"))
	# telhado vermelho com telhas e cumeeira clara
	var r0 := Vector2(s.x - 24, s.y + 22)
	var r1 := Vector2(mx, s.y - 44)
	var r2 := Vector2(s.x + s.w + 24, s.y + 22)
	Spr.poly(PackedVector2Array([r0 + Vector2(-3, 3), r1 + Vector2(0, -4), r2 + Vector2(3, 3)]), ol)
	Spr.poly(PackedVector2Array([r0, r1, r2]), Color("#a8452c"))
	for k in range(1, 5):
		var u: float = k / 5.0
		var la: Vector2 = r0.lerp(r1, u)
		var lb: Vector2 = r2.lerp(r1, u)
		Spr.seg(la.x, la.y, lb.x, lb.y, Color("#7e2f1e"), 2)
	Spr.seg(r0.x, r0.y, r1.x, r1.y, Color(1, .8, .6, .35), 2)
	Spr.circle(mx, s.y - 6, 9, ol)
	Spr.circle(mx, s.y - 6, 7, Color("#f0c070"))
	Spr.seg(mx - 7, s.y - 6, mx + 7, s.y - 6, ol, 1.5)
	Spr.seg(mx, s.y - 13, mx, s.y + 1, ol, 1.5)
	# beiral (onde dá para andar): viga de madeira com brilho em cima
	Spr.rect(s.x, s.y, s.w, s.h, Color("#6b4a2a"))
	Spr.rect(s.x, s.y, s.w, 3, Color(1, .9, .7, .25))
	Spr.rect(s.x, s.y + s.h - 2, s.w, 2, ol)
	_weather_coat(s.x, s.y - 40, s.w, 60)

func beam(s: Dictionary) -> void:
	# viga baixa de escoramento da mina: só passa abaixado
	_hang_ropes(s.x + 10, s.x + s.w - 10, s.y - 6, 0.0, true)
	planks(s, true)
	Spr.rect(s.x - 24, s.y - 6, s.w + 48, 14, Color("#5a3d22"))
	# cada corrente dá a volta na trave de cima
	for rx in [s.x + 10, s.x + s.w - 10]:
		_wrap(rx - 9, s.y - 10, 18, 22, 6, true)
	var y: float = s.y + s.h - 10
	var x: float = s.x
	while x < s.x + s.w:
		Spr.rect(x, y, 10, 8, Color(.85, .7, .2, .85))
		Spr.rect(x + 10, y, 10, 8, Color(.1, .08, .05, .85))
		x += 20


## maciço de rocha da mina (teto ou parede): terra com pedras da textura da mina, borda de pedras
## e, no teto, pontas de rocha penduradas
## boca da mina no fim da vila: paredão de pedra com a entrada escorada por vigas
func portal(s: Dictionary) -> void:
	var x: float = s.x
	var w: float = s.w
	var gy: float = s.y
	var op0: float = x + 50          # vão da entrada
	var op1: float = x + w - 30
	var top: float = gy - 268
	var mt: Texture2D = Spr.tex.get("chao_mina", Spr.tex.chao)
	var tun: float = float(s.get("tun", 0))
	var tx1: float = x + w + tun           # fim do túnel (dali para frente, as galerias da mina)
	# o túnel lá dentro: escurece para o fundo, com escoras e trilhos sumindo no escuro
	Spr.vgrad(op0, top, tx1 - op0, gy - top, Color("#2a1e14"), Color("#0c0806"))
	var cx: float = (op0 + op1) / 2
	for k in 3:
		var sc: float = .78 - k * .2
		var fw: float = (op1 - op0) * sc
		var fh: float = (gy - top) * sc
		var fy: float = gy - 6 - k * 14
		var c := Color(.32 - k * .08, .21 - k * .05, .11 - k * .03)
		Spr.rect(cx - fw / 2, fy - fh, 8 * sc + 2, fh, c)
		Spr.rect(cx + fw / 2 - 8 * sc - 2, fy - fh, 8 * sc + 2, fh, c)
		Spr.rect(cx - fw / 2 - 4, fy - fh - 6 * sc, fw + 8, 9 * sc + 2, c)
	# escoras do túnel (dentro, depois da porteira)
	var ex: float = op1 + 150
	while ex < tx1 - 40:
		Spr.rect(ex, top + 8, 14, gy - top - 8, Color("#3e2914"))
		Spr.rect(ex + 3, top + 8, 4, gy - top - 8, Color(1, .8, .5, .1))
		Spr.rect(ex - 30, top + 4, 74, 14, Color("#4a3018"))
		Spr.glow(ex + 7, top + 60, 34, Color(1, .7, .35, .14))
		Spr.circle(ex + 7, top + 60, 2.5, Color(1, .85, .5, .7))
		ex += 170
	Spr.glow(cx + 10, gy - 120, 60, Color(1, .7, .35, .18))
	Spr.circle(cx + 10, gy - 120, 3, Color(1, .85, .5, .8))
	# paredão de rocha da mina em volta (a mesma terra pedregosa das galerias)
	for band in [[-760.0, -100.0], [-100.0, gy]]:
		_dirt_fill_t(x - 70, op0, band[0], band[1], 0.0, 1.15, mt, 1.0)
		_dirt_fill_t(op0, tx1 + 60, band[0], min(band[1], top + 6), 0.0, 1.15, mt, 1.0)
	if tun <= 0:
		for band in [[-760.0, -100.0], [-100.0, gy]]:
			_dirt_fill_t(op1, x + w + 90, band[0], band[1], 0.0, 1.15, mt, 1.0)
	# teto do túnel: pedras irregulares na borda de baixo
	var bx2: float = op1 + 12
	while bx2 < tx1 + 40:
		var r2 := hh(bx2, 23)
		Spr.ellipse(bx2 + 12, top + 6, 16 + r2 * 6, 8 + r2 * 4, Color("#2a2018"))
		Spr.ellipse(bx2 + 10, top + 3, 12 + r2 * 5, 5 + r2 * 3, Color("#4a3a2c"))
		bx2 += 28
	# saída do túnel para as galerias: a rocha some aos poucos
	if tun > 0:
		Spr.hgrad(tx1 - 10, -760, 90, top + 766, Color(.08, .06, .04, .0), Color(.08, .06, .04, 0))
	# borda irregular do lado da vila: a rocha recortada, com luz de lua nas quinas
	var edge := PackedVector2Array()
	var yy: float = -760
	while yy <= gy:
		edge.push_back(Vector2(x - 70 + sin(yy * .021 + x) * 9 + sin(yy * .07) * 5, yy))
		yy += 20
	Spr.line(edge, Color("#140e0a"), 6)
	for i in range(0, edge.size(), 4):
		var e2: Vector2 = edge[i]
		var r3 := hh(e2.y + x, 11)
		if r3 > .45:
			Spr.ellipse(e2.x + 4, e2.y + 6, 9 + r3 * 8, 6 + r3 * 4, Color("#5a4a3c"))
			Spr.seg(e2.x - 2, e2.y + 2, e2.x + 10, e2.y, Color(.75, .8, .95, .35), 2)
	# pedrinhas e musgo no pé do paredão
	for k in 5:
		var px: float = x - 80 + k * 14 + hh(x + k, 5) * 8
		Spr.ellipse(px, gy - 3, 8 + hh(px, 3) * 6, 5, Color("#5a4c40"))
	Spr.ellipse(x - 50, gy - 2, 26, 5, Color(.3, .45, .2, .7))
	# vigas: dois esteios e a travessa
	var wood := Color("#6b4524")
	var wood2 := Color("#2e1c0c")
	for px in [op0 - 6, op1 - 16]:
		Spr.rect(px, top, 22, gy - top, wood2)
		Spr.rect(px + 3, top, 15, gy - top, wood)
		Spr.rect(px + 6, top, 3, gy - top, Color(1, .85, .6, .22))
		for k in 5:
			Spr.seg(px + 5, top + 30 + k * 50, px + 15, top + 42 + k * 50, Color(0, 0, 0, .3), 1.2)
	Spr.rect(op0 - 26, top - 26, op1 - op0 + 52, 28, wood2)
	Spr.rect(op0 - 22, top - 22, op1 - op0 + 44, 20, wood)
	Spr.rect(op0 - 22, top - 22, op1 - op0 + 44, 4, Color(1, .85, .6, .22))
	for k in 2:
		Spr.seg(op0 + 16 + k * (op1 - op0 - 52), top, op0 + 46 + k * (op1 - op0 - 112), top + 32, wood, 6)
	# placa
	Spr.rect(cx - 46, top - 62, 92, 30, wood2)
	Spr.rect(cx - 43, top - 59, 86, 24, Color("#8a6036"))
	Spr.text("MINA", cx, top - 41, 16, Color("#f0dcb0"), HORIZONTAL_ALIGNMENT_CENTER, Spr.font_b, 2, Color(0, 0, 0, .7))
	# lanterninha pendurada
	Spr.seg(op0 + 4, top - 2, op0 + 4, top + 26, Color("#222"), 1.5)
	Spr.circle(op0 + 4, top + 32, 7, Color("#3a2a18"))
	Spr.ring(op0 + 4, top + 32, 7, Color(.55, .28, .12, .6), 1.5, PI * .1, PI * .9)
	Spr.circle(op0 + 4, top + 32, 4, Color(1, .8, .4))
	Spr.glow(op0 + 4, top + 32, 40, Color(1, .75, .35, .3))

func rockw(s: Dictionary) -> void:
	var xa: float = max(s.x, x0 - 4)
	var xb: float = min(s.x + s.w, x1 + 4)
	if xb <= xa:
		return
	_dirt_fill(xa, xb, s.y, s.y + s.h, s.x, .62)
	var rim := Color("#4a3a2c")
	var rim2 := Color("#2a2018")
	if s.get("ceil"):
		var by: float = s.y + s.h
		var x: float = s.x + fposmod(-s.x, 34.0)
		while x < s.x + s.w:
			if x >= x0 - 40 and x < x1 + 40:
				var r := hh(x, 31)
				Spr.ellipse(x + 17, by - 4, 22, 9 + r * 5, rim2)
				Spr.ellipse(x + 15, by - 6, 18, 6 + r * 4, rim)
				if r > .55:
					var ln: float = 14 + r * 30
					Spr.poly(PackedVector2Array([Vector2(x + 6, by - 4), Vector2(x + 15, by + ln), Vector2(x + 26, by - 4)]), rim2)
					Spr.seg(x + 11, by, x + 15, by + ln * .8, Color(.55, .45, .35, .6), 1.5)
			x += 34
	else:
		# borda de cima (chão de pedra) e laterais irregulares
		var x2: float = s.x + fposmod(-s.x, 30.0)
		while x2 < s.x + s.w:
			if x2 >= x0 - 40 and x2 < x1 + 40:
				Spr.ellipse(x2 + 15, s.y + 4, 19, 7, rim2)
				Spr.ellipse(x2 + 14, s.y + 2, 15, 4, rim)
			x2 += 30
		for e in [s.x, s.x + s.w]:
			if e >= x0 - 40 and e <= x1 + 40:
				var yy: float = s.y + 10
				while yy < s.y + s.h - 6:
					var r2 := hh(yy + e, 33)
					Spr.ellipse(e, yy, 10 + r2 * 8, 14, rim2)
					yy += 26


## sombra macia de contato na base do que fica apoiado no chão (casas, cabana, muros, carrinhos, troncos)
func _contact_shadow(s: Dictionary) -> void:
	var t: String = str(s.t)
	if not t in ["house", "cabin", "wall", "damwall", "cart", "log", "treehouse", "shed", "brickw"]:
		return
	var w: float = float(s.get("w", 0))
	var base: float = s.y + float(s.get("h", 0)) if t != "house" else s.y + 3.0
	if t == "log":
		base = s.y + float(s.get("h", 20))
	var c: Color = _shade_col(_theme_at(s.x + w / 2))
	Spr.ellipse(s.x + w / 2, base + 2, w * .62 + 10, 9, Color(c.r, c.g, c.b, .22))
	Spr.ellipse(s.x + w / 2, base + 1, w * .48, 5, Color(c.r, c.g, c.b, .25))

static func _shade_col(th: String) -> Color:
	match th:
		"tarde":
			return Color(.28, .08, .22)
		"chuva":
			return Color(.04, .16, .1)
		"neve":
			return Color(.2, .25, .5)
	return Color(.08, .1, .25)

## umidade e frio nas pedras: musgo esverdeado na base perto do brejo; geada branca em cima na neve
func _weather_coat(x: float, y: float, w: float, h: float) -> void:
	var th: String = _theme_at(x + w / 2)
	if th == "chuva":
		Spr.vgrad(x, y + h * .55, w, h * .45, Color(.25, .45, .15, 0), Color(.22, .42, .14, .35))
		for i in 4:
			Spr.ellipse(x + w * hh(x + i, 81), y + h * (.7 + hh(y + i, 82) * .25), 6 + hh(x - i, 83) * 6, 3, Color(.3, .5, .18, .45))
	elif th == "neve":
		Spr.vgrad(x, y, w, h * .35, Color(.95, .97, 1, .55), Color(.9, .94, 1, 0))
		for i in 5:
			Spr.circle(x + w * hh(x + i, 84), y + h * hh(y + i, 85) * .3, 1.3, Color(1, 1, 1, .8))

## chão sem repetição: manchas suaves (mais escuro, mais claro, mais avermelhado) e capim na beirada
func _ground_vary(s: Dictionary, xa: float, xb: float) -> void:
	if s.get("snow") or gt_at(game, (xa + xb) * .5) != "":
		return
	var x: float = floor((xa - 120.0) / 90.0) * 90.0
	while x < xb + 120.0:
		var r: float = hh(x, 91)
		if r > .35:
			var cx: float = x + hh(x, 92) * 90
			var wv: float = 40 + hh(x, 93) * 70
			var col: Color = [Color(0, 0, 0, .07), Color(1, 1, .85, .06), Color(.5, .2, .05, .07)][int(hh(x, 94) * 3)]
			if cx > s.x + wv * .5 and cx < s.x + s.w - wv * .5:
				Spr.ellipse(cx, s.y + 6 + hh(x, 95) * 14, wv, 8 + hh(x, 96) * 6, col)
		x += 90
	# fios de capim saindo da beirada do chão (quebra a linha reta)
	var gx: float = floor(xa / 7.0) * 7.0
	var tc: Color = _ground_tint(gx).darkened(.05)
	while gx < xb:
		var hgt: float = 3 + hh(gx, 97) * 6
		if hh(gx, 98) > .35:
			# a textura do chão fica opaca a partir de s.y (antes os fios ficavam 30 px acima, soltos no ar)
			Spr.seg(gx, s.y + 1, gx + (hh(gx, 99) - .5) * 4, s.y + 1 - hgt, Color(.36 * tc.r, .55 * tc.g, .22 * tc.b, .8), 1.4)
		gx += 7

# ---------------------------------------------------------------- árvores (troncos fixos)
## sombra da copa no chão: mancha grande e macia com manchinhas mais escuras e furos de sol
func _tree_shade(s: Dictionary) -> void:
	var gy: float = s.y + s.h
	var cx: float = s.x + s.w * .5
	var th := _theme_at(cx)
	if th in ["noite", "perseguicao", "tunel"] or (game.L.has("under") and gy > game.L.under + 10):
		return
	var c: Color = _shade_col(th)
	bt_ellipse(cx, gy + 1, s.w * 2.6 + 30, 7, Color(c.r, c.g, c.b, .1), 0.0, 16)
	for i in 5:
		var ox: float = (hh(s.x + i, 111) - .5) * s.w * 4.0
		bt_ellipse(cx + ox, gy + 1 + hh(s.x - i, 112) * 3, 14 + hh(s.x + i * 2, 113) * 22, 3, Color(c.r, c.g, c.b, .1))
	if th in ["manha", "tarde"]:
		for i in 3:
			var ox2: float = (hh(s.x + i, 114) - .5) * s.w * 3.4
			bt_ellipse(cx + ox2, gy, 5 + hh(s.x - i, 115) * 6, 1.6, Color(1, .95, .75, .12))
	bt_flush()

## raízes grossas saindo do pé do tronco e entrando na terra dos dois lados (duas chamadas para todas)
func _roots_flare(s: Dictionary) -> void:
	var gy: float = s.y + s.h
	var cx: float = s.x + s.w * .5
	var dk := PackedVector2Array()
	var hl := PackedVector2Array()
	for i in 3:
		var side: float = -1.0 if i % 2 == 0 else 1.0
		var reach: float = s.w * (.9 + hh(s.x + i, 116) * .5) + 10
		var prev := Vector2.ZERO
		for j in 7:
			var u := j / 6.0
			var p := Vector2(cx + side * (s.w * .3 + u * reach), gy - 12 + u * 14 + sin(u * 3.0 + s.x) * 1.5)
			if j > 0:
				# raiz afinando para a ponta: segmentos cada vez mais finos (quads no lote)
				bt_seg(prev, p, Color("#3a2414"), lerpf(7.0 - i * 1.2, 2.0, u))
				hl.push_back(prev)
				hl.push_back(p)
			prev = p
	bt_flush()
	Spr.ci.draw_multiline(hl, Spr.col(Color(.55, .38, .22, .5)), 1.5, true)

## casca do tronco: veios escuros ondulados (com fio claro), nós, musgo/líquen ou geada pelo clima,
## hera em alguns troncos, ninho de passarinho às vezes e neve no alto quando é neve.
## Tudo junto em poucas chamadas (linhas num multiline, manchas num lote de triângulos)
func _bark(s: Dictionary) -> void:
	var cx: float = s.x + s.w * .5
	var hw: float = s.w * .55
	var top: float = s.y - 4
	var bot: float = s.y + s.h - 14
	var th := _theme_at(cx)
	# veios: segmentos ondulados com falhas (nada de linha reta de cima a baixo)
	var vd := PackedVector2Array()
	var vl := PackedVector2Array()
	for i in 4:
		var bx: float = cx + (i - 1.5) / 1.5 * hw * .62 + (hh(s.x + i, 102) - .5) * 5
		var y: float = top + hh(s.x - i, 103) * 30
		while y < bot - 16:
			var ln: float = 50 + hh(y + i, 104) * 110
			var y2: float = min(y + ln, bot - 16)
			var yy: float = y
			var prev := Vector2(INF, 0)
			while yy <= y2:
				var p := Vector2(bx + sin(yy * .031 + i * 2.0) * 2.5 + sin(yy * .11 + i) * 1.0, yy)
				if prev.x != INF:
					vd.push_back(prev)
					vd.push_back(p)
					vl.push_back(prev + Vector2(1.8, 0))
					vl.push_back(p + Vector2(1.8, 0))
				prev = p
				yy += 14
			y = y2 + 18 + hh(y, 105) * 40
	if vd.size() >= 2:
		Spr.ci.draw_multiline(vd, Spr.col(Color(.16, .09, .04, .38)), 1.6, true)
		Spr.ci.draw_multiline(vl, Spr.col(Color(1, .88, .68, .1)), 1.0, true)
	# nós (um ou dois), alguns com buraco escuro
	var nk: int = 1 + (1 if s.h > 300 and hh(s.x, 106) > .4 else 0)
	for i in nk:
		var ky: float = s.y + s.h * (.3 + hh(s.x + i * 5, 107) * .4)
		var kx: float = cx + (hh(s.x - i * 3, 108) - .5) * hw * .7
		bt_ellipse(kx - 1, ky - 1.5, 7, 9.5, Color(1, .85, .6, .12))
		bt_ellipse(kx, ky, 6.5, 9, Color(.36, .22, .12, .9))
		bt_ellipse(kx, ky, 4.5, 6.5, Color(.16, .09, .05, .95))
		if hh(s.x + i, 109) > .45:
			bt_ellipse(kx, ky + 1, 2.6, 4.2, Color(.04, .03, .02), 0.0, 8)
	# musgo/líquen (do lado da sombra) ou geada (lado do vento)
	if th == "chuva":
		for i in 6:
			var my: float = bot - 10 - hh(s.x + i, 110) * min(s.h * .5, 200.0)
			bt_ellipse(cx - hw * .55 + hh(my, 117) * 8, my, 7 + hh(my, 118) * 5, 4, Color(.27, .44, .16, .75))
			bt_ellipse(cx - hw * .6 + hh(my, 117) * 8, my - 1.5, 4, 2, Color(.45, .62, .25, .7), 0.0, 8)
	elif th == "neve":
		bt_quad(Vector2(cx - hw * .9, top), Vector2(cx - hw * .9 + 5, top), Vector2(cx - hw * .9 + 5, bot), Vector2(cx - hw * .9, bot), Color(.95, .97, 1, .4))
		for i in 8:
			bt_ellipse(cx - hw * .8 + hh(s.x + i, 119) * 6, top + hh(s.x - i, 120) * (bot - top), 1.3, 1.3, Color(1, 1, 1, .8), 0.0, 6)
		# neve assentada no alto do tronco e no pé
		bt_ellipse(cx, top - 2, hw + 6, 6, Color(.96, .97, 1))
		bt_ellipse(cx - 3, top - 4, hw * .7, 3, Color(1, 1, 1))
		bt_ellipse(cx, s.y + s.h - 2, s.w * 1.1, 6, Color(.95, .97, 1, .95))
	else:
		for i in 5:
			var r: float = 1.8 + hh(s.x + i, 124) * 1.6
			bt_ellipse(cx - hw * .5 + hh(s.x + i, 122) * hw, s.y + s.h * (.25 + hh(s.x - i, 123) * .6), r, r, Color(.62, .7, .52, .45), 0.0, 7)
	# hera subindo (avermelhada na tarde)
	var ivy := PackedVector2Array()
	if hh(s.x, 125) < .5 and th != "neve":
		var vh: float = min(s.h * .7, 260.0)
		var lc: Color = Color(.72, .3, .14) if th == "tarde" else Color(.3, .5, .2)
		var y3: float = bot
		var i3 := 0
		var prev3 := Vector2(INF, 0)
		while y3 > bot - vh:
			var q := Vector2(cx + sin(y3 * .045 + s.x) * hw * .7, y3)
			if prev3.x != INF:
				ivy.push_back(prev3)
				ivy.push_back(q)
			if i3 % 2 == 1:
				var sd: float = 1.0 if i3 % 4 == 1 else -1.0
				bt_ellipse(q.x + sd * 4, q.y, 4, 2.6, lc.darkened(hh(q.y, 126) * .25), sd * .6, 8)
			prev3 = q
			y3 -= 8
			i3 += 1
	# ninho de passarinho no tronco alto, apoiado num tocozinho
	var nest := PackedVector2Array()
	if hh(s.x, 127) > .6 and s.h > 240:
		var ny: float = s.y + s.h * .42
		var sd2: float = 1.0 if hh(s.x, 128) > .5 else -1.0
		var nx: float = cx + sd2 * (hw + 8)
		bt_seg(Vector2(cx + sd2 * hw * .6, ny + 4), Vector2(nx, ny + 3), Color("#3e2714"), 4)
		bt_ellipse(nx, ny, 14, 6, Color(.42, .3, .17), 0.0, 12)
		bt_ellipse(nx, ny - 3, 10, 2.6, Color(.2, .13, .07))
		bt_ellipse(nx - 3, ny - 4, 2.2, 2.2, Color(.75, .88, .9), 0.0, 7)
		bt_ellipse(nx + 2, ny - 4.5, 2.2, 2.2, Color(.8, .92, .95), 0.0, 7)
		for j in 6:
			nest.push_back(Vector2(nx - 14 + j * 4.5, ny - 2 + sin(j) * 2))
			nest.push_back(Vector2(nx - 8 + j * 4.5, ny + 4))
	bt_flush()
	if ivy.size() >= 2:
		Spr.ci.draw_multiline(ivy, Spr.col(Color(.25, .2, .1, .8)), 1.6, true)
	if nest.size() >= 2:
		Spr.ci.draw_multiline(nest, Spr.col(Color(.3, .2, .1, .8)), 1.0, true)

# ---------------------------------------------------------------- lote de triângulos
## várias manchas pequenas (elipses, segmentos grossos, quads) numa chamada de desenho só: junta no
## lote e manda tudo de uma vez com bt_flush() (as cores já levam o alpha do Spr)
static var _bp := PackedVector2Array()
static var _bc := PackedColorArray()
static var _bi := PackedInt32Array()

static func bt_ellipse(x: float, y: float, rx: float, ry: float, c: Color, rot: float = 0.0, seg: int = 10) -> void:
	var base: int = _bp.size()
	var cc := Spr.col(c)
	_bp.push_back(Vector2(x, y))
	_bc.push_back(cc)
	for i in seg:
		var a: float = TAU * i / seg
		_bp.push_back(Vector2(x, y) + Vector2(cos(a) * rx, sin(a) * ry).rotated(rot))
		_bc.push_back(cc)
	for i in seg:
		_bi.push_back(base)
		_bi.push_back(base + 1 + i)
		_bi.push_back(base + 1 + (i + 1) % seg)

static func bt_quad(a: Vector2, b: Vector2, c: Vector2, d: Vector2, col: Color) -> void:
	var base: int = _bp.size()
	var cc := Spr.col(col)
	for p in [a, b, c, d]:
		_bp.push_back(p)
		_bc.push_back(cc)
	for k in [0, 1, 2, 0, 2, 3]:
		_bi.push_back(base + k)

static func bt_seg(a: Vector2, b: Vector2, col: Color, w: float) -> void:
	var n := (b - a).orthogonal().normalized() * w * .5
	bt_quad(a + n, b + n, b - n, a - n, col)

static func bt_flush() -> void:
	if _bi.size() >= 3:
		RenderingServer.canvas_item_add_triangle_array(Spr.ci.get_canvas_item(), _bi, _bp, _bc)
	_bp = PackedVector2Array()
	_bc = PackedColorArray()
	_bi = PackedInt32Array()

# ---------------------------------------------------------------- gelo, poças e pingentes
## poça congelada na neve: gelo azulado e liso com reflexo e uma rachadura
func _ice_puddle(x: float, y: float) -> void:
	var w: float = 16 + hh(x, 138) * 14
	Spr.ellipse(x, y - 1, w + 2, 4, Color(.75, .84, .96))
	Spr.ellipse(x, y - 1, w, 3, Color(.62, .8, .95, .95))
	Spr.ellipse(x - w * .3, y - 2, w * .4, 1, Color(1, 1, 1, .85))
	Spr.seg(x + w * .1, y - 2, x + w * .45, y, Color(1, 1, 1, .5), .8)

## pontas dos pingentes de gelo do cenário (para os pinguinhos caírem delas): posição -> ponta
static var ICICLES := {}
static var _ic_L = null
func _icicle_reg(x: float, y: float) -> void:
	if not is_same(_ic_L, game.L):
		_ic_L = game.L
		ICICLES = {}
	ICICLES[Vector2i(int(x), int(y))] = Vector2(x, y)

## poças do chão na chuva (mesmo sorteio de _ground_deco): [x, y, meia largura]
static func puddles_of(g: Game, s: Dictionary) -> Array:
	if s.has("_pd"):
		return s._pd
	var out: Array = []
	if s.w >= 120 and not s.get("snow") and str(s.get("t", "")) == "ground":
		var y: float = s.y
		var th := theme_at(g, s.x + s.w / 2)
		var under: bool = g.L.has("under") and y > g.L.under
		if th == "chuva" and not under:
			var gx: float = s.x + 40 + fposmod(-(s.x + 40), 58.0)
			while gx < s.x + s.w - 40:
				if hh(gx, 11) < .5 and not covered(g, gx, y) and int(hh(gx, 12) * 100) < 30:
					out.append([gx, y, 18 + hh(gx, 24) * 16])
				gx += 58
	s._pd = out
	return out
