extends Node
## Biblioteca de desenho: atlas de peças + pilha de transformações (save/restore/translate/rotate/scale),
## parecida com o canvas 2D da versão HTML, para portar o desenho quase 1:1.

var tex := {}            # nome -> Texture2D
var prof_on := false      # medição de tempo por quadro (tests/bench.gd)
var prof := {}
func pt(k: String, t0: int) -> void:
	if prof_on:
		prof[k] = prof.get(k, 0) + Time.get_ticks_usec() - t0
var AR := {}             # peça -> [x,y,w,h,ax,ay,atlas]
var ci: CanvasItem
var M := Transform2D.IDENTITY
var stack: Array[Transform2D] = []
var alpha := 1.0
## quando tem alfa, as peças (A, frame, novo) saem em silhueta dessa cor (clarão branco do golpe)
var sil_c := Color(0, 0, 0, 0)
## gravação das silhuetas (contorno dos inimigos): com rec = [], os desenhos em silhueta são guardados
## em vez de desenhados; replay() repete a lista deslocada (a lógica do desenho roda 1 vez, não 8)
var rec = null

## silhueta de um retângulo de textura: desenha já ou grava
func _sdr(t: Texture2D, dst: Rect2, src: Rect2, c: Color) -> void:
	if rec != null:
		rec.append([M, t, dst, src, c])
	else:
		ci.draw_texture_rect_region(t, dst, src, c)

## silhueta de um polígono com textura: desenha já ou grava
func _spoly(pts: PackedVector2Array, c: Color, uvs: PackedVector2Array, t: Texture2D) -> void:
	if rec != null:
		rec.append([M, t, pts, uvs, c])
	else:
		ci.draw_polygon(pts, PackedColorArray([c, c, c, c]), uvs, t)

## desenha de novo o que foi gravado, deslocado de off (no espaço da tela de quem chamou)
func replay(r: Array, off: Vector2) -> void:
	var tr := Transform2D(0.0, off)
	for op in r:
		ci.draw_set_transform_matrix(tr * op[0])
		if op[2] is Rect2:
			ci.draw_texture_rect_region(op[1], op[2], op[3], op[4])
		else:
			var c: Color = op[4]
			ci.draw_polygon(op[2], PackedColorArray([c, c, c, c]), op[3], op[1])
	ci.draw_set_transform_matrix(M)
var astack: Array[float] = []
var glow_tex: Texture2D
var font: Font
var font_i: Font
var font_b: Font
var font_title: Font
## Animações extras do Tomé (opcionais): assets/sprites/tome/<nome>.png, quadros QUADRADOS lado a lado,
## pés no centro da base. Se o arquivo existir, o jogo usa no lugar das poses antigas.
var anim := {}
const ANIM_NAMES := ["idle", "walk", "run", "jump", "fall", "land", "crawl", "push", "look", "rain", "shiver", "lantern", "tired", "lookback", "ice", "hurt", "cheer"]
var novos := {}
const NOVOS := ["pipoca", "toupeira", "toupeira_capacete", "morcego", "aranha"]

## desenha o quadro f de uma arte nova com os pés em (0,0), altura h na tela
func novo(n: String, f: int, h: float, flip: bool = false, al: float = 1.0) -> bool:
	if not novos.has(n):
		return false
	var a: Dictionary = novos[n]
	var s: float = a.s
	var k := h / s
	save()
	scale(-k if flip else k, k)
	ci.draw_texture_rect_region(a.tex, Rect2(-s / 2, -s, s, s), Rect2((f % a.n) * s, 0, s, s), Color(1, 1, 1, alpha * al))
	restore()
	return true

func _ready() -> void:
	for k in ["atlas1", "atlas2"]:
		tex[k] = load("res://assets/sprites/%s.png" % k)
	for k in ["en_boar", "en_frog2", "en_crow2"]:
		var ep := "res://assets/sprites/%s.png" % k
		if ResourceLoader.exists(ep):
			tex[k] = load(ep)
	for k in ["pai", "pai2", "javali", "chao", "tronco", "galho", "filha", "vigia", "cao", "vargas_pe", "isis2", "pai_climb", "pai_rope_a", "pai_rope_b", "pai_vine_a", "pai_vine_b", "gaviao", "bagre"]:
		tex[k] = load("res://assets/sprites/%s.png" % k)
	for k in ["bosque", "tarde", "pantano", "noite", "neve", "mina", "moinho", "vila", "esconderijo"]:
		tex["bg_" + k] = load("res://assets/bg/%s.jpg" % k)
		# cenário em camadas pintadas (opcional): assets/bg/<trecho>/1_ceu.jpg, 2_longe.png, 3_meio.png, 4_perto.png
		var layers: Array = []
		for ln in ["1_ceu.jpg", "2_longe.png", "3_meio.png", "4_perto.png"]:
			var lp: String = "res://assets/bg/%s/%s" % [k, ln]
			if ResourceLoader.exists(lp):
				layers.append(load(lp))
		if layers.size() >= 2:
			tex["bgl_" + k] = layers
	for k in ANIM_NAMES:
		var ap := "res://assets/sprites/tome/%s.png" % k
		if ResourceLoader.exists(ap):
			var at: Texture2D = load(ap)
			var fh := at.get_height()
			anim[k] = {"tex": at, "n": max(1, int(round(at.get_width() / float(fh)))), "s": fh}
	# peças extras desenhadas à parte (atlas 2 = extra.png)
	tex["extra"] = load("res://assets/sprites/extra.png")
	for k in ["mina", "vila"]:
		var gp := "res://assets/sprites/chao_%s.png" % k
		if ResourceLoader.exists(gp):
			tex["chao_" + k] = load(gp)
	tex["pad_S"] = load("res://assets/ui/pad_S.png")
	_warm_start.call_deferred()
	tex["btn_use"] = load("res://assets/ui/btn_use.png")
	AR["it_picareta"] = [17, 12, 102, 110, 51, 55, 2]
	# artes novas opcionais (assets/sprites/novos/<nome>.png, quadros quadrados lado a lado)
	for k in NOVOS:
		var npth := "res://assets/sprites/novos/%s.png" % k
		if ResourceLoader.exists(npth):
			var nt: Texture2D = load(npth)
			var nh := nt.get_height()
			novos[k] = {"tex": nt, "n": max(1, int(round(nt.get_width() / float(nh)))), "s": nh}
	for k in ["javali", "vargas", "cao"]:
		var cp := "res://assets/ui/cena_%s.jpg" % k
		if ResourceLoader.exists(cp):
			tex["cena_" + k] = load(cp)
	_x4_load()
	var j = JSON.parse_string(FileAccess.get_file_as_string("res://assets/data/atlas.json"))
	for n in j.atlas1:
		var r = j.atlas1[n]
		AR[n] = [r[0], r[1], r[2], r[3], r[4], r[5], 0]
	for n in j.atlas2:
		var r = j.atlas2[n]
		AR[n] = [r[0], r[1], r[2], r[3], r[4], r[5], 1]
	# artes pintadas novas (tools/pack_paint.py): atlas 3, 4...
	var pj = JSON.parse_string(FileAccess.get_file_as_string("res://assets/data/paint.json"))
	for n in pj:
		var r = pj[n]
		var pg: int = int(r[6])
		var key := "paint%d" % (pg + 1)
		if not tex.has(key):
			tex[key] = load("res://assets/sprites/%s.png" % key)
		AR["p_" + n] = [r[0], r[1], r[2], r[3], r[4], r[5], 3 + pg]
		# ícones pintados de objetos e pistas novos: valem também pelo nome antigo (it_x, cl_7, clb_7)
		if (n.begins_with("it_") or n.begins_with("cl_") or n.begins_with("clb_")) and not AR.has(n):
			AR[n] = AR["p_" + n]
	# brilho radial (substitui os gradientes radiais do canvas)
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 1))
	g.set_color(1, Color(1, 1, 1, 0))
	var gt := GradientTexture2D.new()
	gt.gradient = g
	gt.fill = GradientTexture2D.FILL_RADIAL
	gt.fill_from = Vector2(.5, .5)
	gt.fill_to = Vector2(1, .5)
	gt.width = 128
	gt.height = 128
	glow_tex = gt
	font = load("res://assets/fonts/Lora-Regular.woff2")
	font_i = load("res://assets/fonts/Lora-Italic.woff2")
	font_b = load("res://assets/fonts/Lora-Bold.woff2")
	font_title = load("res://assets/fonts/Cinzel-Bold.woff2")

## folha opcional em assets/sprites/<n>.png (carrega na primeira vez; null se não existir)
func opt(n: String) -> Texture2D:
	if not tex.has(n):
		var pth := "res://assets/sprites/%s.png" % n
		late(pth)
		tex[n] = load(pth) if ResourceLoader.exists(pth) else null
	return tex[n]

func atlas_tex(r) -> Texture2D:
	if r[6] >= 3:
		return tex["paint%d" % (r[6] - 2)]
	if r[6] == 2:
		return tex.extra
	return tex.atlas2 if r[6] == 1 else tex.atlas1

func has(n: String) -> bool:
	return AR.has(n)

## peça pintada com a base em (cx, by): largura w (altura pela proporção), espelhada se flip,
## inclinada (topo deslocado em lean px, para grama/flores balançando) e com cor (período do dia)
func P(n: String, cx: float, by: float, w: float, flip: bool = false, lean: float = 0.0, c: Color = Color.WHITE) -> void:
	var r = AR.get("p_" + n)
	if r == null:
		return
	var h: float = w * r[3] / r[2]
	var t := atlas_tex(r)
	var ts := t.get_size()
	var u0: float = r[0] / ts.x
	var u1: float = (r[0] + r[2]) / ts.x
	if flip:
		var tmp := u0
		u0 = u1
		u1 = tmp
	var v0: float = r[1] / ts.y
	var v1: float = (r[1] + r[3]) / ts.y
	var col := Color(c.r, c.g, c.b, c.a * alpha)
	if sil_c.a > 0:
		t = sil(t)
		col = Color(sil_c.r, sil_c.g, sil_c.b, sil_c.a * alpha * c.a)
	var pts := PackedVector2Array([Vector2(cx - w / 2 + lean, by - h), Vector2(cx + w / 2 + lean, by - h), Vector2(cx + w / 2, by), Vector2(cx - w / 2, by)])
	var uvs := PackedVector2Array([Vector2(u0, v0), Vector2(u1, v0), Vector2(u1, v1), Vector2(u0, v1)])
	if sil_c.a > 0:
		_spoly(pts, col, uvs, t)
		return
	ci.draw_polygon(pts, PackedColorArray([col, col, col, col]), uvs, t)

## peça pintada esticada num retângulo (x, y, w, h)
func PR(n: String, x: float, y: float, w: float, h: float, c: Color = Color.WHITE, flip: bool = false) -> void:
	var r = AR.get("p_" + n)
	if r == null:
		return
	var col := Color(c.r, c.g, c.b, c.a * alpha)
	var st: Texture2D = atlas_tex(r)
	if sil_c.a > 0:
		st = sil(st)
		col = Color(sil_c.r, sil_c.g, sil_c.b, sil_c.a * alpha * c.a)
	if flip:
		var t := st
		var ts := t.get_size()
		var u0: float = r[0] / ts.x
		var u1: float = (r[0] + r[2]) / ts.x
		var v0: float = r[1] / ts.y
		var v1: float = (r[1] + r[3]) / ts.y
		var fpts := PackedVector2Array([Vector2(x, y), Vector2(x + w, y), Vector2(x + w, y + h), Vector2(x, y + h)])
		var fuvs := PackedVector2Array([Vector2(u1, v0), Vector2(u0, v0), Vector2(u0, v1), Vector2(u1, v1)])
		if sil_c.a > 0:
			_spoly(fpts, col, fuvs, t)
		else:
			ci.draw_polygon(fpts, PackedColorArray([col, col, col, col]), fuvs, t)
	elif sil_c.a > 0:
		_sdr(st, Rect2(x, y, w, h), Rect2(r[0], r[1], r[2], r[3]), col)
	else:
		ci.draw_texture_rect_region(st, Rect2(x, y, w, h), Rect2(r[0], r[1], r[2], r[3]), col)

## só uma fatia horizontal (u0..u1, de 0 a 1) da peça pintada, esticada em (x, y, w, h)
func PRs(n: String, x: float, y: float, w: float, h: float, u0: float, u1: float, c: Color = Color.WHITE) -> void:
	var r = AR.get("p_" + n)
	if r == null:
		return
	var col := Color(c.r, c.g, c.b, c.a * alpha)
	ci.draw_texture_rect_region(atlas_tex(r), Rect2(x, y, w, h), Rect2(r[0] + r[2] * u0, r[1], r[2] * (u1 - u0), r[3]), col)

## só uma faixa de linhas (v0..v1, de 0 em cima a 1 embaixo) da peça pintada, em (x, y, w, h)
func PB(n: String, x: float, y: float, w: float, h: float, v0: float, v1: float, c: Color = Color.WHITE) -> void:
	var r = AR.get("p_" + n)
	if r == null:
		return
	var col := Color(c.r, c.g, c.b, c.a * alpha)
	ci.draw_texture_rect_region(atlas_tex(r), Rect2(x, y, w, h), Rect2(r[0], r[1] + r[3] * v0, r[2], r[3] * (v1 - v0)), col)

## peça pintada repetida na vertical (escada, corda, cipó): largura w, de y até y+h
func PV(n: String, x: float, y: float, w: float, h: float, c: Color = Color.WHITE) -> void:
	var r = AR.get("p_" + n)
	if r == null:
		return
	var th: float = w * r[3] / r[2]
	var t := atlas_tex(r)
	var col := Color(c.r, c.g, c.b, c.a * alpha)
	var yy := y
	while yy < y + h - .5:
		var hh: float = min(th, y + h - yy)
		ci.draw_texture_rect_region(t, Rect2(x, yy, w, hh), Rect2(r[0], r[1], r[2], r[3] * hh / th), col)
		yy += th - 1

## altura de uma peça pintada desenhada com largura w
func PH(n: String, w: float) -> float:
	var r = AR.get("p_" + n)
	if r == null:
		return 0.0
	return w * r[3] / r[2]

# ---------- pilha de transformações ----------
func begin(c: CanvasItem) -> void:
	ci = c
	M = Transform2D.IDENTITY
	stack.clear()
	astack.clear()
	alpha = 1.0
	ci.draw_set_transform_matrix(M)

func save() -> void:
	stack.push_back(M)
	astack.push_back(alpha)

func restore() -> void:
	if stack.size() > 0:
		M = stack.pop_back()
		alpha = astack.pop_back()
	ci.draw_set_transform_matrix(M)

func translate(x: float, y: float) -> void:
	M = M * Transform2D(0, Vector2(x, y))
	ci.draw_set_transform_matrix(M)

func rotate(a: float) -> void:
	M = M * Transform2D(a, Vector2.ZERO)
	ci.draw_set_transform_matrix(M)

func scale(sx: float, sy: float) -> void:
	M = M * Transform2D(Vector2(sx, 0), Vector2(0, sy), Vector2.ZERO)
	ci.draw_set_transform_matrix(M)

# ---------- peças do atlas ----------
## Desenha a peça n com a âncora em (x,y)
func A(n: String, x: float, y: float, sc: float = 1.0, flip: bool = false, al: float = 1.0) -> void:
	var r = AR.get(n)
	if r == null:
		return
	save()
	translate(x, y)
	scale(-sc if flip else sc, sc)
	if sil_c.a > 0:
		_sdr(sil(atlas_tex(r)), Rect2(-r[4], -r[5], r[2], r[3]), Rect2(r[0], r[1], r[2], r[3]), Color(sil_c.r, sil_c.g, sil_c.b, sil_c.a * alpha * al))
	else:
		ci.draw_texture_rect_region(atlas_tex(r), Rect2(-r[4], -r[5], r[2], r[3]), Rect2(r[0], r[1], r[2], r[3]), Color(1, 1, 1, alpha * al))
	restore()

## silhueta branca da textura (mesmo alfa) — para o contorno de luz (rim light) dos personagens
var _sil := {}
func sil(t: Texture2D) -> Texture2D:
	var id := t.get_instance_id()
	if not _sil.has(id):
		# silhueta pronta (tools/make_sil.py), senão calcula aqui
		var sp: String = t.resource_path.get_basename() + "_sil.png" if t.resource_path != "" else ""
		if sp != "" and ResourceLoader.exists(sp):
			late(sp)
			_sil[id] = load(sp)
			return _sil[id]
		var _t0 := Time.get_ticks_msec()
		push_warning("silhueta calculada no aparelho (falta %s_sil.png): %s" % [t.resource_path.get_basename(), t.resource_path])
		var im: Image = t.get_image()
		if im.is_compressed():
			im.decompress()
		im.convert(Image.FORMAT_RGBA8)
		var w := im.get_width()
		var h := im.get_height()
		var data := im.get_data()
		for i in range(0, data.size(), 4):
			data[i] = 255
			data[i + 1] = 255
			data[i + 2] = 255
		_sil[id] = ImageTexture.create_from_image(Image.create_from_data(w, h, false, Image.FORMAT_RGBA8, data))
		print("SILSLOW ", t.resource_path, " ", w, "x", h, " ", Time.get_ticks_msec() - _t0, "ms")
	return _sil[id]

## a peça n em silhueta de uma cor só (para o rim light)
func A_sil(n: String, x: float, y: float, sc: float, flip: bool, c: Color) -> void:
	var r = AR.get(n)
	if r == null:
		return
	save()
	translate(x, y)
	scale(-sc if flip else sc, sc)
	ci.draw_texture_rect_region(sil(atlas_tex(r)), Rect2(-r[4], -r[5], r[2], r[3]), Rect2(r[0], r[1], r[2], r[3]), Color(c.r, c.g, c.b, c.a * alpha))
	restore()

## Peça esticada num retângulo
func AB(n: String, x: float, y: float, w: float, h: float, al: float = 1.0) -> void:
	var r = AR.get(n)
	if r == null:
		return
	ci.draw_texture_rect_region(atlas_tex(r), Rect2(x, y, w, h), Rect2(r[0], r[1], r[2], r[3]), Color(1, 1, 1, alpha * al))

## Peça com base no chão (centro x, base y) e largura w
func ABb(n: String, cx: float, by: float, w: float, al: float = 1.0) -> void:
	var r = AR.get(n)
	if r == null:
		return
	var h: float = w * r[3] / r[2]
	AB(n, cx - w / 2, by - h, w, h, al)

## Faixa repetida na horizontal, alinhada em ox, recortada entre x0 e x1
func strip_at(n: String, ox: float, x0: float, x1: float, y: float, h: float, al: float = 1.0) -> void:
	var r = AR.get(n)
	if r == null or x1 <= x0:
		return
	var t := atlas_tex(r)
	var tw: float = r[2] * h / r[3] - 1
	var xx: float = ox + floor((x0 - ox) / tw) * tw
	while xx < x1:
		var a: float = max(xx, x0)
		var b: float = min(xx + tw + 1, x1)
		if b > a:
			var u0: float = (a - xx) / (tw + 1) * r[2]
			var u1: float = (b - xx) / (tw + 1) * r[2]
			ci.draw_texture_rect_region(t, Rect2(a, y, b - a, h), Rect2(r[0] + u0, r[1], u1 - u0, r[3]), Color(1, 1, 1, alpha * al))
		xx += tw

## Faixa repetida na vertical (escadas, redes)
func strip_v(n: String, x: float, y: float, w: float, h: float, al: float = 1.0) -> void:
	var r = AR.get(n)
	if r == null:
		return
	var t := atlas_tex(r)
	var th: float = w * r[3] / r[2] - 1
	var yy := y
	while yy < y + h:
		var b: float = min(yy + th + 1, y + h)
		var v: float = (b - yy) / (th + 1) * r[3]
		ci.draw_texture_rect_region(t, Rect2(x, yy, w, b - yy), Rect2(r[0], r[1], r[2], v), Color(1, 1, 1, alpha * al))
		yy += th

## Textura (ou recorte dela) num retângulo
func img(t: Texture2D, x: float, y: float, w: float, h: float, src: Rect2 = Rect2(), al: float = 1.0) -> void:
	if src.size == Vector2.ZERO:
		ci.draw_texture_rect(t, Rect2(x, y, w, h), false, Color(1, 1, 1, alpha * al))
	else:
		ci.draw_texture_rect_region(t, Rect2(x, y, w, h), src, Color(1, 1, 1, alpha * al))

## Quadro de uma folha de sprites (cw x ch) com âncora
## textura inteira num retângulo (respeita a silhueta de contorno sil_c)
func trect(t: Texture2D, r: Rect2) -> void:
	if sil_c.a > 0:
		_sdr(sil(t), r, Rect2(Vector2.ZERO, t.get_size()), Color(sil_c.r, sil_c.g, sil_c.b, sil_c.a * alpha))
	else:
		ci.draw_texture_rect(t, r, false, Color(1, 1, 1, alpha))

func frame(t: Texture2D, fr: int, cw: float, ch: float, ax: float, ay: float, x: float, y: float, sc: float, flip: bool = false, al: float = 1.0) -> void:
	save()
	translate(x, y)
	scale(-sc if flip else sc, sc)
	if sil_c.a > 0:
		_sdr(sil(t), Rect2(-ax, -ay, cw, ch), Rect2(fr * cw, 0, cw, ch), Color(sil_c.r, sil_c.g, sil_c.b, sil_c.a * alpha * al))
	else:
		ci.draw_texture_rect_region(t, Rect2(-ax, -ay, cw, ch), Rect2(fr * cw, 0, cw, ch), Color(1, 1, 1, alpha * al))
	restore()

## ciclo de quadros com transição: perto da troca, o quadro seguinte aparece por cima aos poucos
## (fpos = posição contínua no ciclo; quadros base .. base + n - 1)
func frame_mix(t: Texture2D, fpos: float, n: int, base: int, cw: float, ch: float, ax: float, ay: float, x: float, y: float, sc: float, flip: bool = false, al: float = 1.0) -> void:
	frame_seq(t, range(base, base + n), fpos, cw, ch, ax, ay, x, y, sc, flip, al)

## ciclo em ordem livre (ex.: [1, 2, 3, 2]); usa os quadros intermediários (x4) quando existem
func frame_seq(t: Texture2D, seq: Array, fpos: float, cw: float, ch: float, ax: float, ay: float, x: float, y: float, sc: float, flip: bool = false, al: float = 1.0) -> void:
	var m := x4(tkey(t) + ":" + seqkey(seq))
	if not m.is_empty():
		save()
		translate(x, y)
		scale(-sc if flip else sc, sc)
		x4_draw(m, Rect2(-ax, -ay, cw, ch), fpos, Color(1, 1, 1, al))
		restore()
		return
	var n: int = seq.size()
	var f0: int = int(floor(fpos))
	frame(t, int(seq[posmod(f0, n)]), cw, ch, ax, ay, x, y, sc, flip, al)
	var k: float = smoothstep(.55, 1.0, fpos - f0) * .7
	if k > .02 and sil_c.a == 0:
		frame(t, int(seq[posmod(f0 + 1, n)]), cw, ch, ax, ay, x, y, sc, flip, al * k)

## mesma ideia para folhas desenhadas direto (chefes): seq = ordem dos quadros no ciclo
func region_mix(t: Texture2D, dst: Rect2, cw: float, ch: float, seq: Array, fpos: float, mod: Color) -> void:
	var m := x4(tkey(t) + ":" + seqkey(seq))
	if not m.is_empty():
		x4_draw(m, dst, fpos, Color(mod.r, mod.g, mod.b, mod.a / max(alpha, .001)))
		return
	var f0: int = int(floor(fpos))
	var n: int = seq.size()
	ci.draw_texture_rect_region(t, dst, Rect2(int(seq[posmod(f0, n)]) * cw, 0, cw, ch), mod)
	var k: float = smoothstep(.55, 1.0, fpos - f0) * .7
	if k > .02 and sil_c.a == 0:
		ci.draw_texture_rect_region(t, dst, Rect2(int(seq[posmod(f0 + 1, n)]) * cw, 0, cw, ch), Color(mod.r, mod.g, mod.b, mod.a * k))

# ---------- quadros intermediários (tools/x4.py): 4 quadros para cada quadro desenhado ----------
var X4M := {}
func _x4_load() -> void:
	var pth := "res://assets/data/x4.json"
	if FileAccess.file_exists(pth):
		var j = JSON.parse_string(FileAccess.get_file_as_string(pth))
		if j is Dictionary:
			X4M = j

## folha x4 da chave (vazio se não existir); carrega a textura na primeira vez
func x4(key: String) -> Dictionary:
	var m = X4M.get(key)
	if m == null:
		return {}
	if not m.has("tex"):
		var pth: String = "res://assets/sprites/" + str(m.file)
		if not ResourceLoader.exists(pth):
			X4M.erase(key)
			return {}
		late(pth)
		m.tex = load(pth)
	return m

func tkey(t: Texture2D) -> String:
	var p := t.resource_path
	if p.begins_with("res://assets/sprites/"):
		p = p.substr(21)
	return p.get_basename()

func seqkey(seq: Array) -> String:
	var parts := PackedStringArray()
	for v in seq:
		parts.append(str(int(v)))
	return "-".join(parts)

## quadro i da folha x4
func x4_src(m: Dictionary, i: int) -> Rect2:
	var cols: int = int(m.cols)
	return Rect2((i % cols) * float(m.cw), (i / cols) * float(m.ch), float(m.cw), float(m.ch))

## posição contínua (em quadros originais) -> [quadro, próximo, fração]
func x4_pos(m: Dictionary, fpos: float) -> Array:
	var n: int = int(m.n)
	var p: float = fpos * 4.0
	if m.get("cyc", true):
		var i0: int = posmod(int(floor(p)), n)
		return [i0, (i0 + 1) % n, p - floor(p)]
	p = clamp(p, 0.0, n - 1.0)
	var j0: int = int(floor(p))
	return [j0, min(j0 + 1, n - 1), p - j0]

## desenha a folha x4 no retângulo de um quadro original (com leve transição para o próximo)
func x4_draw(m: Dictionary, dst: Rect2, fpos: float, mod: Color = Color(1, 1, 1)) -> void:
	var q := x4_pos(m, fpos)
	var t: Texture2D = m.tex
	var c := Color(mod.r, mod.g, mod.b, mod.a * alpha)
	if sil_c.a > 0:
		t = sil(t)
		c = Color(sil_c.r, sil_c.g, sil_c.b, sil_c.a * alpha * mod.a)
		_sdr(t, dst, x4_src(m, q[0]), c)
		return
	ci.draw_texture_rect_region(t, dst, x4_src(m, q[0]), c)
	var k: float = smoothstep(.5, 1.0, q[2]) * .5
	# no contorno (silhueta) só o quadro principal: a silhueta do quadro seguinte aparecia por baixo
	# do desenho meio transparente (pernas do javali ficavam vermelhas no galope)
	if k > .02 and q[1] != q[0] and sil_c.a == 0:
		ci.draw_texture_rect_region(t, dst, x4_src(m, q[1]), Color(c.r, c.g, c.b, c.a * k))

## ciclo de peças do atlas (Spr.A): nomes na ordem do ciclo
func A_cycle(key: String, names: Array, fpos: float, x: float, y: float, sc: float = 1.0, flip: bool = false, al: float = 1.0) -> void:
	var m := x4("A:" + key)
	if m.is_empty():
		A(names[posmod(int(floor(fpos)), names.size())], x, y, sc, flip, al)
		return
	save()
	translate(x, y)
	scale(-sc if flip else sc, sc)
	x4_draw(m, Rect2(-float(m.ax), -float(m.ay), float(m.cw), float(m.ch)), fpos, Color(1, 1, 1, al))
	restore()

## ciclo de peças pintadas com largura fixa: centradas (PC, como WorldExtras._pc) ou pela base (P)
func P_cycle(key: String, names: Array, fpos: float, cx: float, y: float, w: float, flip: bool = false, c: Color = Color.WHITE, centered: bool = false) -> void:
	var m := x4(("PC:" if centered else "P:") + key)
	if m.is_empty():
		var nm: String = names[posmod(int(floor(fpos)), names.size())]
		if centered:
			var hgt: float = PH(nm, w)
			PR(nm, cx - w / 2, y - hgt / 2, w, hgt, c)
		else:
			P(nm, cx, y, w, flip, 0.0, c)
		return
	var u: float = w / (float(m.w) * float(m.px))
	var W: float = float(m.cw) * u
	var H: float = float(m.ch) * u
	save()
	translate(cx, y)
	if flip:
		scale(-1, 1)
	x4_draw(m, Rect2(-W / 2, -H / 2 if centered else -H, W, H), fpos, c)
	restore()

# ---------- formas ----------
func col(c: Color, a: float = 1.0) -> Color:
	return Color(c.r, c.g, c.b, c.a * a * alpha)

func rect(x: float, y: float, w: float, h: float, c: Color) -> void:
	ci.draw_rect(Rect2(x, y, w, h), col(c))

func circle(x: float, y: float, r: float, c: Color) -> void:
	ci.draw_circle(Vector2(x, y), r, col(c))

func ring(x: float, y: float, r: float, c: Color, w: float = 2.0, a0: float = 0.0, a1: float = TAU) -> void:
	ci.draw_arc(Vector2(x, y), r, a0, a1, 24, col(c), w, true)

var _UC := PackedVector2Array()
func ellipse(x: float, y: float, rx: float, ry: float, c: Color, rot: float = 0.0) -> void:
	# elipse muito pequena vira círculo (polígono minúsculo não triangula)
	if rx < 3.5 or ry < 2.0:
		if rx >= 3.5:
			# elipse fininha: um traço com a mesma largura
			var d := Vector2(rx - ry, 0).rotated(rot)
			ci.draw_line(Vector2(x, y) - d, Vector2(x, y) + d, col(c), max(1.0, ry * 2.0), true)
		else:
			ci.draw_circle(Vector2(x, y), max(.5, (rx + ry) * .5), col(c))
		return
	# (círculo de 20 pontos já pronto: sem 40 senos e cossenos a cada elipse, e são centenas por quadro)
	if _UC.is_empty():
		for i in 20:
			var a0 := TAU * i / 20.0
			_UC.push_back(Vector2(cos(a0), sin(a0)))
	var pts := PackedVector2Array()
	pts.resize(20)
	var o := Vector2(x, y)
	var r := Vector2(rx, ry)
	if rot == 0.0:
		for i in 20:
			pts[i] = o + _UC[i] * r
	else:
		for i in 20:
			pts[i] = o + (_UC[i] * r).rotated(rot)
	ci.draw_colored_polygon(pts, col(c))

func poly(pts: PackedVector2Array, c: Color) -> void:
	if pts.size() >= 3:
		ci.draw_colored_polygon(pts, col(c))

func line(pts: PackedVector2Array, c: Color, w: float = 2.0) -> void:
	ci.draw_polyline(pts, col(c), w, true)

func seg(x0: float, y0: float, x1: float, y1: float, c: Color, w: float = 2.0) -> void:
	ci.draw_line(Vector2(x0, y0), Vector2(x1, y1), col(c), w, true)

func rr(x: float, y: float, w: float, h: float, r: float, c: Color) -> void:
	if w < 1.0 or h < 1.0:
		return
	r = min(r, min(w, h) / 2)
	if r < 1.0:
		ci.draw_rect(Rect2(x, y, w, h), col(c))
		return
	var pts := PackedVector2Array()
	var cs = [[x + w - r, y + r, -PI / 2], [x + w - r, y + h - r, 0.0], [x + r, y + h - r, PI / 2], [x + r, y + r, PI]]
	for cc in cs:
		for i in 6:
			var a: float = cc[2] + PI / 2 * i / 5.0
			pts.push_back(Vector2(cc[0] + cos(a) * r, cc[1] + sin(a) * r))
	ci.draw_colored_polygon(pts, col(c))

## quadro de uma folha de sprites em linha (células cw x ch, pés no fundo da célula):
## desenhado com a base em (x, by), a célula inteira com altura hgt; flip vira para a esquerda
func sheet(name: String, fr: int, cw: float, ch: float, x: float, by: float, hgt: float, flip: bool = false, mod: Color = Color(1, 1, 1)) -> void:
	var t: Texture2D = tex.get(name)
	if t == null:
		return
	var s: float = hgt / ch
	save()
	translate(x, by)
	scale(-s if flip else s, s)
	ci.draw_texture_rect_region(t, Rect2(-cw / 2, -ch, cw, ch), Rect2(fr * cw, 0, cw, ch), Color(mod.r, mod.g, mod.b, mod.a * alpha))
	restore()

func glow(x: float, y: float, r: float, c: Color) -> void:
	ci.draw_texture_rect(glow_tex, Rect2(x - r, y - r, r * 2, r * 2), false, col(c))

func vgrad(x: float, y: float, w: float, h: float, c0: Color, c1: Color) -> void:
	var pts := PackedVector2Array([Vector2(x, y), Vector2(x + w, y), Vector2(x + w, y + h), Vector2(x, y + h)])
	ci.draw_polygon(pts, PackedColorArray([col(c0), col(c0), col(c1), col(c1)]))

func hgrad(x: float, y: float, w: float, h: float, c0: Color, c1: Color) -> void:
	var pts := PackedVector2Array([Vector2(x, y), Vector2(x + w, y), Vector2(x + w, y + h), Vector2(x, y + h)])
	ci.draw_polygon(pts, PackedColorArray([col(c0), col(c1), col(c1), col(c0)]))

func text(s: String, x: float, y: float, size: int, c: Color, align: int = HORIZONTAL_ALIGNMENT_LEFT, f: Font = null, outline: int = 0, oc: Color = Color(0, 0, 0, .8)) -> void:
	var ff: Font = f if f else font
	var w := -1.0
	var px := x
	if align == HORIZONTAL_ALIGNMENT_CENTER:
		var sz := ff.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, size)
		px = x - sz.x / 2
	elif align == HORIZONTAL_ALIGNMENT_RIGHT:
		var sz2 := ff.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, size)
		px = x - sz2.x
	if outline > 0:
		ci.draw_string_outline(ff, Vector2(px, y), s, HORIZONTAL_ALIGNMENT_LEFT, w, size, outline, col(oc))
	ci.draw_string(ff, Vector2(px, y), s, HORIZONTAL_ALIGNMENT_LEFT, w, size, col(c))

func hexc(h: String, a: float = 1.0) -> Color:
	var c := Color(h)
	c.a = a
	return c

## distância andada pelo bicho (para o passo acompanhar o chão, sem patinar)
func edist(e: Dictionary) -> float:
	var lx: float = e.get("_lx", e.x)
	e._dd = float(e.get("_dd", 0.0)) + abs(e.x - lx)
	e._lx = e.x
	return e._dd

## virada com peso (sem efeito de folha de papel): o bicho freia agachando um pouco, espelha de uma vez
## e se recompõe com um pequeno impulso. Devolve a escala x (com o lado); a escala y fica em e._tsy.
const TURN_T := 12      # duração da virada (quadros)
const TURN_FLIP := 7    # quadro em que espelha (antes disso: antecipação)
func eturn(e: Dictionary, _k: float = .2) -> float:
	return turn_face(e, 1.0 if e.dir > 0 else -1.0)

func turn_face(e: Dictionary, d: float) -> float:
	var fd: float = float(e.get("_fd", d))
	var tt: int = int(e.get("_tt", 0))
	var f := _tick()
	if int(e.get("_tg", -1)) != f:
		e._tg = f
		if tt == 0 and d != fd:
			tt = TURN_T
		if tt > 0:
			tt -= 1
			if tt == TURN_FLIP:
				fd = d
		e._tt = tt
		e._fd = fd
	var sx := 1.0
	var sy := 1.0
	if tt > TURN_FLIP:
		# antecipação: abaixa e alarga um pouco
		var u: float = float(TURN_T - tt) / float(TURN_T - TURN_FLIP)
		sy = 1.0 - .09 * u
		sx = 1.0 + .06 * u
	elif tt > 0:
		# recompõe: sai do achatado e passa um tiquinho do normal (impulso para o novo lado)
		var v: float = float(TURN_FLIP - tt) / float(TURN_FLIP)
		sy = lerpf(.91, 1.0, v) + sin(v * PI) * .05
		sx = lerpf(1.06, 1.0, v) - sin(v * PI) * .03
	e._tsy = sy
	e._fs = fd
	return fd * sx

## escala y da virada (achatar/esticar) calculada no último eturn/turn_face
func tsy(e: Dictionary) -> float:
	return float(e.get("_tsy", 1.0))

## acabou de espelhar neste quadro? (para soltar poeira nos pés)
func turned_now(e: Dictionary) -> bool:
	return int(e.get("_tt", 0)) == TURN_FLIP and int(e.get("_tg", -1)) == _tick()

## relógio da lógica do jogo (passo físico): animações de estado não dependem da taxa de quadros
func _tick() -> int:
	if Polish.g != null and is_instance_valid(Polish.g):
		return int(Polish.g.T)
	return Engine.get_physics_frames()

## compatibilidade: largura na virada (agora sem estreitar)
func turnw(fs: float, d: float = 1.0) -> float:
	if fs == 0:
		return d
	return sign(fs)


## ciclo de poucos quadros (andar/correr) com transição: perto da troca, o próximo quadro
## aparece por cima aos poucos — os 4 quadros da arte viram um movimento contínuo
## fpos: posição contínua no ciclo (ex.: distância / passo); quadros base .. base + n - 1
func sheet_cycle(name: String, fpos: float, n: int, base: int, cw: float, ch: float, x: float, by: float, hgt: float, flip: bool = false, mod: Color = Color(1, 1, 1)) -> void:
	# ciclo completo opcional (assets/sprites/<nome>_walk.png, mesmos quadros cw x ch): usa ele com
	# mais quadros, mantendo a mesma distância por passo
	var wt: Texture2D = opt(name + "_walk")
	if wt:
		var wn: int = int(wt.get_width() / cw)
		if wn > n:
			fpos = fpos * wn / float(n)
			n = wn
			base = 0
			name = name + "_walk"
	var m := x4(name + ":" + seqkey(range(base, base + n)))
	if not m.is_empty():
		var s4: float = hgt / ch
		save()
		translate(x, by)
		scale(-s4 if flip else s4, s4)
		x4_draw(m, Rect2(-cw / 2, -ch, cw, ch), fpos, mod)
		restore()
		return
	var f0: int = int(floor(fpos))
	var fr: float = fpos - f0
	var a: int = base + posmod(f0, n)
	var b: int = base + posmod(f0 + 1, n)
	sheet(name, a, cw, ch, x, by, hgt, flip, mod)
	var k: float = smoothstep(.55, 1.0, fr) * .7
	if k > .02:
		sheet(name, b, cw, ch, x, by, hgt, flip, Color(mod.r, mod.g, mod.b, mod.a * k))


# ================================================================ pré-carregamento (sem travadas)
## Tudo o que antes carregava na primeira vez que aparecia (poses novas, folhas x4, objetos pintados,
## silhuetas do contorno) começa a carregar numa linha separada logo na abertura do jogo e fica pronto
## antes da fase; carregar no meio do jogo dava as "travadinhas" no celular.
const WARM_OPT := ["boar_ko", "boar_wind", "boss_charge", "crow_dive", "crow_ko", "dog_dig", "dog_joy", "dog_sniff",
	"dragonfly", "fish_bite", "frog_ko", "frog_tongue", "horse_free", "isis_run", "leaves", "morcego_rei", "ride_dis",
	"ride_gallop", "ride_jump", "sapo_rei", "sled_tome", "urso", "esquilo", "cavalo",
	"isis_climb", "isis_joy", "isis_scared", "p_tora_neve", "p_pedra_neve", "p_galho_neve"]
## folhas que saem em silhueta (clarão do golpe, contorno vermelho dos inimigos, contorno de luz do Tomé)
const WARM_SIL := ["atlas1", "atlas2", "extra", "en_boar", "en_frog2", "en_crow2", "javali", "pai", "pai2", "isis2",
	"pai_climb", "pai_rope_a", "pai_rope_b", "pai_vine_a", "pai_vine_b", "cao", "esquilo", "gaviao", "bagre", "urso",
	"boar_ko", "boar_wind", "crow_dive", "crow_ko", "frog_ko", "frog_tongue", "dog_dig", "dog_joy", "dog_sniff",
	"isis_climb", "isis_joy", "isis_scared", "isis_run", "morcego_rei", "sapo_rei"]
var _warm_req := {}      # caminho -> função que guarda o recurso pronto
## testes (tests/hitch.gd): avisa quando algo é carregado no meio do jogo (dá travadinha no celular)
var trace_late := false
func late(what: String) -> void:
	if trace_late:
		print("LOADLATE ", what)
var warmed := false

func _req(pth: String, put: Callable) -> void:
	if _warm_req.has(pth) or not ResourceLoader.exists(pth):
		return
	if ResourceLoader.load_threaded_request(pth, "", false) == OK:
		_warm_req[pth] = put

func _warm_start() -> void:
	for n in WARM_OPT:
		if tex.get(n) == null:
			_req("res://assets/sprites/%s.png" % n, func(r): tex[n] = r)
	for key in X4M:
		var m: Dictionary = X4M[key]
		var pth: String = "res://assets/sprites/" + str(m.get("file", ""))
		_req(pth, func(r): _put_x4(pth, r))
		# silhueta da folha x4 (contorno vermelho dos inimigos, clarão do golpe)
		var xs: String = pth.trim_suffix(".png") + "_sil.png"
		_req(xs, func(r): _put_sil(pth, r))
	var sil_names: Array = WARM_SIL.duplicate()
	for k in ANIM_NAMES:
		sil_names.append("tome/" + k)
	for k in tex:
		if str(k).begins_with("paint") and not str(k).ends_with("_sil"):
			sil_names.append(k)
	for n in sil_names:
		var base := "res://assets/sprites/%s.png" % n
		var sp := "res://assets/sprites/%s_sil.png" % n
		_req(base, func(r): if tex.get(n) == null and not "/" in n: tex[n] = r)
		_req(sp, func(r): _put_sil(base, r))
	# quadrinhos (aparecem de repente no meio da fase)
	var dc := DirAccess.open("res://assets/comic")
	if dc:
		for f in dc.get_files():
			f = f.trim_suffix(".import").trim_suffix(".remap")
			if f.ends_with(".jpg"):
				var ck := "comic_" + f.get_basename()
				_req("res://assets/comic/" + f, func(r): tex[ck] = r)
	var d := DirAccess.open("res://assets/sprites")
	if d:
		for f in d.get_files():
			f = f.trim_suffix(".import").trim_suffix(".remap")
			if f.begins_with("p_") and f.ends_with(".png") and not f.ends_with("_sil.png"):
				var k := f.get_basename()
				_req("res://assets/sprites/" + f, func(r): if not tex.has(k): tex[k] = r)

func _put_x4(pth: String, r: Texture2D) -> void:
	for key in X4M:
		var m: Dictionary = X4M[key]
		if "res://assets/sprites/" + str(m.get("file", "")) == pth and not m.has("tex"):
			m.tex = r

func _put_sil(base: String, r: Texture2D) -> void:
	# o ResourceLoader devolve a MESMA textura base que o resto do jogo usa (mesmo id)
	var bt: Texture2D = load(base)
	if bt and not _sil.has(bt.get_instance_id()):
		_sil[bt.get_instance_id()] = r

## recolhe o que já terminou de carregar, sem esperar (chamado a cada quadro e ao começar a fase).
## Se o jogador entrar na fase antes de tudo terminar, o resto continua carregando por trás — nada de
## tela parada esperando.
func warm() -> void:
	if _warm_req.is_empty():
		warmed = true
		return
	# bases primeiro (as silhuetas procuram a textura base pelo caminho)
	var paths: Array = _warm_req.keys()
	paths.sort_custom(func(a, b): return int(a.ends_with("_sil.png")) < int(b.ends_with("_sil.png")))
	var n := 0
	for pth in paths:
		var stt := ResourceLoader.load_threaded_get_status(pth)
		if stt == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
			continue
		if pth.ends_with("_sil.png") and _warm_req.has(pth.trim_suffix("_sil.png") + ".png"):
			continue   # a base ainda não foi recolhida
		var r = ResourceLoader.load_threaded_get(pth) if stt == ResourceLoader.THREAD_LOAD_LOADED else null
		if r != null:
			_warm_req[pth].call(r)
		_warm_req.erase(pth)
		n += 1
		if n >= 12:
			break   # poucos por quadro
	if _warm_req.is_empty():
		warmed = true
