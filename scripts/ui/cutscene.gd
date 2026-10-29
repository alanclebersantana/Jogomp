extends Control
## Cenas curtas da história: quadros com zoom/pan lento, legenda que vai aparecendo letra a letra,
## a fala fica parada até o toque, e o botão PULAR CENA pula tudo. Cenas: "abertura", "cracha", "mina".

signal finished

var scene_id := "abertura"
var shots: Array = []
var idx := 0
var t := 0.0            # tempo no quadro atual (s)
var fade := 1.0         # preto entre quadros
var done := false
var skip_btn: Button
var cena: Texture2D
var img_rect := Rect2()   # onde a última imagem de fundo foi desenhada (para posicionar coisas sobre ela)
var leaving := -1.0       # >= 0: o jogador tocou e o quadro está escurecendo para o próximo
## nos testes automáticos (sem tela) as falas avançam sozinhas
var auto := DisplayServer.get_name() == "headless"

const INK := Color("#f0e4c8")

func _init(id: String = "abertura") -> void:
	scene_id = id

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	cena = load("res://assets/ui/cena1.jpg")
	mouse_filter = Control.MOUSE_FILTER_STOP
	match scene_id:
		"abertura":
			shots = [
				{"d": _s_porch, "txt": "Toda tarde, a Isis desenhava na varanda enquanto o pai voltava da mina.", "dur": 5.5},
				{"d": _s_shadow, "txt": "Naquele dia, uma sombra chegou antes dele.", "dur": 4.5},
				{"d": _s_pencils, "txt": "Tomé encontrou só os lápis espalhados... e uma trilha de cores entrando no bosque.", "dur": 6.0},
				{"d": _s_lantern, "txt": "— Aguenta firme, filha. O papai está indo.", "dur": 4.5},
			]
		"cracha":
			shots = [
				{"d": _s_badge_glint, "txt": "Alguma coisa brilhou na luz da lanterna. Um crachá...", "dur": 4.5},
				{"d": _s_villain_face, "txt": "Ademar Vargas. O gerente que Tomé denunciou por roubar a mina.", "dur": 5.0},
			]
		"posfinal":
			shots = [
				{"d": _s_post_rails, "txt": "Lá no fundo da mina, longe de qualquer luz...", "dur": 4.5},
				{"d": _s_post_pencil, "txt": "...uma mãozinha deixou cair mais um lápis nos trilhos. A Isis ainda está marcando o caminho.", "dur": 6.0},
				{"d": _s_post_card, "txt": "Episódio 2: As Profundezas da Mina.", "dur": 4.5},
			]
		"ep2":
			shots = [
				{"d": _pic("cut_ep2_a", true), "txt": "A boca da mina estava escura e o portão, arrombado. Nos trilhos, um lápis vermelho.", "dur": 5.5},
				{"d": _pic("cut_ep2_b", false), "txt": "— Estou indo, filha. Nem que eu tenha que descer até o fundo da terra.", "dur": 5.0},
			]
		"ep2fim":
			shots = [
				{"d": _pic("cut_ep2fim", true), "txt": "Os trilhos acabavam numa porta de ferro enorme, com um V gravado. E, no chão, um lápis roxo.", "dur": 6.0},
			]
		"isis":
			shots = [
				{"d": _pic("cut_isis_a", true), "txt": "Do outro lado daquela porta, a Isis desenhava o pai nas paredes, à luz de uma vela.", "dur": 6.0},
				{"d": _pic("cut_isis_b", false), "txt": "Embaixo da parede havia uma fresta. Pequena demais para um adulto... mas não para ela.", "dur": 6.0},
			]
		"isis_fim":
			shots = [
				{"d": _pic("cut_isis_c", true), "txt": "O Vargas a levou de volta ao quarto de pedra. — Pode fugir quanto quiser, menina. — Ele já está vindo, seu Vargas. O meu pai sempre vem.", "dur": 7.0},
				{"d": _s_vargas_plan, "txt": "— Então vamos para onde ele não alcança. Antes do amanhecer, o trem de carga leva você para as montanhas.", "dur": 6.5},
				{"d": _pic("cut_ep2fim", false), "txt": "Do outro lado, o Tomé encostou o ouvido na porta de ferro. Lá dentro, bem longe, um apito de trem.", "dur": 6.0},
				{"d": _s_train, "txt": "O trem saiu da mina pela passagem secreta. E da janela do último vagão, um lápis caiu nos trilhos.", "dur": 7.0},
				{"d": _s_ep3_card, "txt": "A trilha continua. Episódio 3 — em breve.", "dur": 5.0},
			]
		"mina":
			shots = [
				{"d": _s_mine_enter, "txt": "O carrinho sumiu na boca da mina, com a Isis lá dentro.", "dur": 5.0},
				{"d": _s_mine_closed, "txt": "O portão bateu. Mas no chão, mais um lápis: a trilha continua mina adentro.", "dur": 6.0},
			]
	skip_btn = Button.new()
	skip_btn.text = "PULAR CENA  ›"
	skip_btn.focus_mode = Control.FOCUS_NONE
	skip_btn.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	skip_btn.position = Vector2(-190, 18)
	skip_btn.custom_minimum_size = Vector2(170, 44)
	skip_btn.pressed.connect(_end)
	add_child(skip_btn)

func _process(d: float) -> void:
	if done:
		return
	t += d
	var dur: float = shots[idx].dur
	if auto and leaving < 0 and t >= dur:
		leaving = 0.0
	if leaving >= 0:
		# o jogador tocou: escurece e passa para o próximo quadro
		leaving += d
		fade = clamp(leaving / .35, 0, 1)
		if leaving >= .35:
			_next()
	elif t < .5:
		fade = 1.0 - t / .5
	else:
		# a fala fica parada na tela até o jogador tocar
		fade = 0.0
	queue_redraw()

func _gui_input(e: InputEvent) -> void:
	if (e is InputEventMouseButton and e.pressed) or (e is InputEventScreenTouch and e.pressed):
		_tap()
		accept_event()

func _unhandled_input(e: InputEvent) -> void:
	if e is InputEventJoypadButton and e.pressed:
		if e.button_index == JOY_BUTTON_START:
			_end()
		else:
			_tap()
		get_viewport().set_input_as_handled()
	elif e is InputEventKey and e.pressed and not e.echo:
		if e.keycode == KEY_ESCAPE:
			_end()
		else:
			_tap()
		get_viewport().set_input_as_handled()

func _tap() -> void:
	if done or leaving >= 0:
		return
	var full: String = shots[idx].txt
	if _shown_chars() < full.length():
		t = max(t, full.length() / 38.0 + .6)   # completa a legenda
	else:
		leaving = 0.0

func _next() -> void:
	if idx + 1 >= shots.size():
		# último quadro: fica na tela (já escuro) enquanto a cena some
		_end()
		return
	idx += 1
	t = 0.0
	leaving = -1.0

## Voltar do celular / B do controle: pula a cena
func skip() -> void:
	_end()

func _end() -> void:
	if done:
		return
	done = true
	finished.emit()
	# some em vez de cortar seco: o que vem depois (painel, jogo) aparece por baixo/por cima suavemente
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if skip_btn:
		skip_btn.mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_process_unhandled_input(false)
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 0.0, .3)
	tw.tween_callback(queue_free)

## quadro pintado (assets/ui/<n>.jpg) com zoom lento (aproximando ou afastando)
var _pics := {}
func _pic(n: String, zin: bool) -> Callable:
	return func(W: float, H: float, k: float): _draw_pic(n, W, H, k, zin)

func _draw_pic(n: String, W: float, H: float, k: float, zin: bool) -> void:
	if not _pics.has(n):
		var p := "res://assets/ui/%s.jpg" % n
		_pics[n] = load(p) if ResourceLoader.exists(p) else null
	var tx: Texture2D = _pics[n]
	if tx == null:
		Spr.vgrad(0, 0, W, H, Color(.1, .08, .06), Color(0, 0, 0))
		return
	# Ken Burns: zoom lento 1,0 -> 1,06 (ou o contrário) e um passeio de lado que troca de sentido a
	# cada quadro (sobra 4% de imagem em volta para o passeio nunca mostrar a borda)
	var e: float = k * k * (3.0 - 2.0 * k)
	var z: float = 1.04 * (1.0 + .06 * (e if zin else 1.0 - e))
	var sc: float = max(W / tx.get_width(), H / tx.get_height()) * z
	var w: float = tx.get_width() * sc
	var h: float = tx.get_height() * sc
	var dir: float = 1.0 if idx % 2 == 0 else -1.0
	var ox: float = clamp((W - w) / 2 + (e - .5) * dir * (w - W) * .8, W - w, 0.0)
	var oy: float = clamp((H - h) / 2 + (e - .5) * dir * (h - H) * .35, H - h, 0.0)
	draw_texture_rect(tx, Rect2(ox, oy, w, h), false)
	_vignette(W, H, .45)

func _s_post_card3(W: float, H: float, k: float) -> void:
	var a: float = clamp(k * 3, 0, 1)
	Spr.text("ENCONTRE-A", W / 2, H * .36, 58, Color(.95, .82, .55, a), HORIZONTAL_ALIGNMENT_CENTER, Spr.font_title, 6)
	Spr.text("EPISÓDIO 3", W / 2, H * .36 + 54, 34, Color(.95, .82, .55, a), HORIZONTAL_ALIGNMENT_CENTER, Spr.font_title, 6)

func _shown_chars() -> int:
	return int(max(0.0, t - .6) * 38.0)

# ----------------------------------------------------------------------
func _draw() -> void:
	if idx >= shots.size():
		return
	var W := size.x
	var H := size.y
	draw_rect(Rect2(0, 0, W, H), Color.BLACK)
	var dur: float = shots[idx].dur
	var k: float = clamp(t / dur, 0, 1)
	Spr.begin(self)
	shots[idx].d.call(W, H, k)
	Spr.begin(self)
	# barras de cinema
	draw_rect(Rect2(0, 0, W, 34), Color.BLACK)
	draw_rect(Rect2(0, H - 92, W, 92), Color(0, 0, 0, .9))
	var full: String = shots[idx].txt
	var n: int = min(full.length(), _shown_chars())
	var shown := full.substr(0, n)
	var f: Font = Spr.font_i
	var fs := 22
	var lines := _wrap(shown, f, fs, W - 160)
	var y := H - 92 + 34 - (lines.size() - 1) * 13
	for ln in lines:
		var tw := f.get_string_size(ln, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		draw_string_outline(f, Vector2(W / 2 - tw / 2, y), ln, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 4, Color(0, 0, 0, .9))
		draw_string(f, Vector2(W / 2 - tw / 2, y), ln, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, INK)
		y += 27
	# pontinhos de progresso
	for i in shots.size():
		draw_circle(Vector2(W / 2 - (shots.size() - 1) * 9 + i * 18, H - 14), 4, Color(1, .9, .7, .9 if i == idx else .25))
	if n >= full.length() and leaving < 0:
		# aviso bem visível, piscando devagar, até o toque
		var a: float = .78 + .22 * sin(t * 4.0)
		var msg := "▸ aperte um botão" if Save.getv("opt", "stick", "") == "gamepad" else "▸ toque para continuar"
		var mw: float = Spr.font_b.get_string_size(msg, HORIZONTAL_ALIGNMENT_LEFT, -1, 17).x
		draw_string_outline(Spr.font_b, Vector2(W - mw - 24, H - 10), msg, HORIZONTAL_ALIGNMENT_LEFT, -1, 17, 4, Color(0, 0, 0, .9))
		draw_string(Spr.font_b, Vector2(W - mw - 24, H - 10), msg, HORIZONTAL_ALIGNMENT_LEFT, -1, 17, Color(1, .88, .55, a))
	if fade > 0:
		draw_rect(Rect2(0, 0, W, H), Color(0, 0, 0, fade))

func _wrap(s: String, f: Font, fs: int, maxw: float) -> Array:
	var out: Array = []
	var cur := ""
	for word in s.split(" "):
		var tryv := word if cur == "" else cur + " " + word
		if f.get_string_size(tryv, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x > maxw and cur != "":
			out.append(cur)
			cur = word
		else:
			cur = tryv
	out.append(cur)
	return out

## Imagem que cobre a tela com zoom/pan: foco (fx,fy) em 0..1 vai de z0 a z1
func _kb(tex: Texture2D, W: float, H: float, k: float, f0: Vector2, f1: Vector2, z0: float, z1: float, mod: Color = Color.WHITE) -> void:
	var e := k * k * (3 - 2 * k)
	var z: float = lerp(z0, z1, e)
	var f: Vector2 = f0.lerp(f1, e)
	var tw := float(tex.get_width())
	var th := float(tex.get_height())
	var base: float = max(W / tw, H / th) * z
	var dw := tw * base
	var dh := th * base
	var x: float = clamp(W / 2 - f.x * dw, W - dw, 0)
	var y: float = clamp(H / 2 - f.y * dh, H - dh, 0)
	img_rect = Rect2(x, y, dw, dh)
	draw_texture_rect(tex, img_rect, false, mod)

## ponto da imagem (em pixels da imagem original) -> tela
func _ip(tex: Texture2D, px: float, py: float) -> Vector2:
	return img_rect.position + Vector2(px / tex.get_width() * img_rect.size.x, py / tex.get_height() * img_rect.size.y)

func _vignette(W: float, H: float, a: float) -> void:
	Spr.vgrad(0, 0, W, H * .35, Color(0, 0, 0, a), Color(0, 0, 0, 0))
	Spr.vgrad(0, H * .65, W, H * .35, Color(0, 0, 0, 0), Color(0, 0, 0, a))
	Spr.hgrad(0, 0, W * .25, H, Color(0, 0, 0, a), Color(0, 0, 0, 0))
	Spr.hgrad(W * .75, 0, W * .25, H, Color(0, 0, 0, 0), Color(0, 0, 0, a))

func _tome(x: float, by: float, sc: float, fr: int = 0, flip: bool = false, lamp: bool = true) -> void:
	if lamp:
		var fl := 1.0 + sin(t * 9) * .04
		Spr.glow(x + (-38 if flip else 38) * sc / .5, by - 70 * sc / .5, 190 * sc / .5 * fl, Color(1, .82, .45, .45))
	Spr.ellipse(x, by + 2, 34 * sc / .5, 7 * sc / .5, Color(0, 0, 0, .3))
	Spr.frame(Spr.tex.pai, fr, 170, 160, 85, 156, x, by, sc, flip)

# ---------- abertura ----------
func _s_porch(W: float, H: float, k: float) -> void:
	_kb(cena, W, H, k, Vector2(.3, .58), Vector2(.34, .57), 1.6, 1.35)
	_vignette(W, H, .5)

func _s_shadow(W: float, H: float, k: float) -> void:
	var dark: float = lerp(1.0, .55, k)
	_kb(cena, W, H, k, Vector2(.5, .6), Vector2(.72, .78), 1.3, 1.7, Color(dark, dark * .92, dark * .9))
	_vignette(W, H, .6 + k * .3)

func _s_pencils(W: float, H: float, k: float) -> void:
	_kb(Spr.tex.bg_noite, W, H, k, Vector2(.3, .7), Vector2(.45, .7), 1.25, 1.4, Color(.6, .6, .75))
	var gy := H * .78
	Spr.vgrad(0, gy - 30, W, H - gy + 30, Color(.05, .04, .06, 0), Color(.05, .04, .06, .9))
	# lápis espalhados e um desenho amassado
	var pens := ["vermelho", "azul", "amarelo", "verde", "laranja", "roxo"]
	for i in pens.size():
		var px := W * (.18 + i * .1) + sin(i * 2.3) * 30
		Spr.save()
		Spr.translate(px, gy + 8 + (i % 2) * 10)
		Spr.rotate(1.2 + i * .7)
		Spr.A("pen_" + pens[i], 0, 0, .9)
		Spr.restore()
	Spr.save()
	Spr.translate(W * .62, gy + 4)
	Spr.rotate(-.3)
	Spr.A("drawing", 0, 0, .9)
	Spr.restore()
	# Tomé chega pela esquerda
	var tx: float = lerp(-80.0, W * .38, clamp(k * 1.6, 0, 1))
	var walking := k < .62
	_tome(tx, gy + 10, .62, [1, 2, 3, 2][int(t * 8) % 4] if walking else 0)
	_vignette(W, H, .7)

func _s_lantern(W: float, H: float, k: float) -> void:
	Spr.vgrad(0, 0, W, H, Color(.05, .05, .1), Color(.02, .02, .03))
	var fl := 1.0 + sin(t * 7) * .05
	Spr.glow(W * .5 + 70, H * .45, 420 * fl, Color(1, .78, .4, .35))
	var z: float = lerp(1.0, 1.12, k)
	_tome(W * .5, H * .5 + 230 * z, 1.45 * z, 0, false, false)
	Spr.glow(W * .5 + 110 * z, H * .5 + 30 * z, 120 * fl, Color(1, .9, .6, .55))
	_vignette(W, H, .8)

# ---------- crachá ----------
func _s_badge_glint(W: float, H: float, k: float) -> void:
	Spr.vgrad(0, 0, W, H, Color(.06, .05, .05), Color(.02, .02, .02))
	Spr.glow(W * .5, H * .5, 380, Color(1, .8, .45, .25))
	var cx := W * .5
	var cy := H * .48
	Spr.save()
	Spr.translate(cx, cy)
	Spr.rotate(-.12 + k * .08)
	Spr.scale(1.4 + k * .3, 1.4 + k * .3)
	Spr.rr(-70, -46, 140, 92, 8, Color("#d9c38a"))
	Spr.rr(-64, -40, 128, 80, 6, Color("#efe2bb"))
	Spr.rect(-56, -30, 38, 46, Color(.4, .35, .3))
	Spr.rect(-8, -26, 62, 6, Color(.35, .3, .25))
	Spr.rect(-8, -14, 50, 5, Color(.35, .3, .25))
	Spr.rect(-8, -2, 56, 5, Color(.35, .3, .25))
	Spr.restore()
	var g: float = clamp(sin(k * PI * 2.2), 0, 1)
	Spr.glow(cx + 60, cy - 30, 70 * g + 5, Color(1, 1, .9, .9 * g))
	Spr.seg(cx + 60 - 40 * g, cy - 30, cx + 60 + 40 * g, cy - 30, Color(1, 1, .95, g), 2)
	Spr.seg(cx + 60, cy - 30 - 40 * g, cx + 60, cy - 30 + 40 * g, Color(1, 1, .95, g), 2)
	_vignette(W, H, .8)

func _s_villain_face(W: float, H: float, k: float) -> void:
	Spr.vgrad(0, 0, W, H, Color(.18, .05, .05), Color(.03, .01, .01))
	var r = Spr.AR.get("vg_face")
	var z: float = lerp(1.0, 1.15, k)
	if r != null:
		var hh: float = H * .56 * z
		var ww: float = hh * r[2] / r[3]
		var cy := H * .44
		Spr.glow(W / 2, cy, hh * .8, Color(1, .25, .15, .35))
		draw_texture_rect_region(Spr.atlas_tex(r), Rect2(W / 2 - ww / 2, cy - hh / 2, ww, hh), Rect2(r[0], r[1], r[2], r[3]), Color(1, .85, .8))
	var ta: float = clamp(k * 3 - .3, 0, 1)
	Spr.text("ADEMAR VARGAS", W * .5, H - 112, 34, Color(1, .8, .6, ta), HORIZONTAL_ALIGNMENT_CENTER, Spr.font_title, 6)
	_vignette(W, H, .85)

# ---------- entrada da mina ----------
## fundo da noite com a boca da mina no centro; devolve o ponto da entrada (base) e a escala
func _mine_bg(W: float, H: float, k: float, dark: float) -> Array:
	var bg: Texture2D = Spr.tex.bg_noite
	_kb(bg, W, H, k, Vector2(.53, .6), Vector2(.53, .62), 2.0, 2.15, Color(dark, dark, dark * 1.1))
	var door := _ip(bg, 957, 470)
	var sc: float = img_rect.size.x / bg.get_width()
	return [door, sc]

func _s_mine_enter(W: float, H: float, k: float) -> void:
	var m := _mine_bg(W, H, k, .8)
	var door: Vector2 = m[0]
	var sc: float = m[1]
	# o carrinho sobe os trilhos e encolhe até sumir no túnel
	var e: float = clamp(k * 1.25, 0, 1)
	var start := Vector2(W * .3, H * 1.02)
	var p: Vector2 = start.lerp(door + Vector2(0, -6 * sc), e)
	var z: float = lerp(1.5, .22 * sc, e)
	var al: float = clamp((1.0 - e) * 4.0, 0, 1)
	var f := int(t * 7) % 2
	Spr.A("lia_scared", p.x + 44 * z, p.y - 60 * z, .55 * z, false, al)
	Spr.A("vg_cart1" if f else "vg_cart2", p.x, p.y, 1.1 * z, false, al)
	_vignette(W, H, .7)

func _s_mine_closed(W: float, H: float, k: float) -> void:
	var m := _mine_bg(W, H, k, .62)
	var door: Vector2 = m[0]
	var sc: float = m[1]
	# portão de tábuas fechado na boca do túnel
	var dw := 82.0 * sc
	var dh := 118.0 * sc
	var drop: float = clamp(k * 4, 0, 1)
	var dy: float = door.y - dh * drop
	Spr.rect(door.x - dw / 2, dy, dw, dh * drop, Color(.33, .21, .12))
	for i in 5:
		Spr.rect(door.x - dw / 2 + i * dw / 5 + 1, dy, 2, dh * drop, Color(.18, .11, .06))
	Spr.rect(door.x - dw / 2, dy + dh * drop * .3, dw, 6 * sc, Color(.2, .14, .08))
	Spr.rect(door.x - dw / 2, dy + dh * drop * .7, dw, 6 * sc, Color(.2, .14, .08))
	if drop >= 1:
		Spr.rect(door.x - 6 * sc, door.y - dh * .5, 12 * sc, 14 * sc, Color(.55, .55, .6))
	# Tomé chega e encontra o lápis roxo
	var gy := H - 104
	var tx: float = lerp(-80.0, W * .34, clamp(k * 1.5, 0, 1))
	var walking := k < .66
	_tome(tx, gy, .9, [1, 2, 3, 2][int(t * 8) % 4] if walking else 0)
	Spr.save()
	Spr.translate(W * .48, gy - 4)
	Spr.rotate(1.4)
	Spr.A("pen_roxo", 0, 0, 1.2)
	Spr.restore()
	Spr.glow(W * .48, gy - 6, 36 + sin(t * 5) * 6, Color(.85, .6, 1, .6))
	_vignette(W, H, .7)

# ---------- depois dos créditos ----------
func _rails(W: float, H: float, k: float, dark: float) -> void:
	Spr.vgrad(0, 0, W, H, Color(.05, .04, .04), Color(.01, .01, .01))
	var vx := W * .5
	var vy := H * .38
	for i in 14:
		var u := pow((i + fmod(t * .4, 1.0)) / 14.0, 2.0)
		var y: float = lerp(vy, H + 40, u)
		var hw: float = lerp(8.0, W * .55, u)
		Spr.rect(vx - hw, y, hw * 2, 3 + u * 10, Color(.25, .17, .1, .9 * u + .1))
	for sd in [-1, 1]:
		Spr.ci.draw_line(Vector2(vx + sd * 4, vy), Vector2(vx + sd * W * .32, H + 40), Color(.55, .55, .6), 3)
	# paredes da galeria
	Spr.poly(PackedVector2Array([Vector2(0, 0), Vector2(vx - 30, vy - 20), Vector2(vx - 30, vy + 10), Vector2(0, H)]), Color(.09, .07, .06))
	Spr.poly(PackedVector2Array([Vector2(W, 0), Vector2(vx + 30, vy - 20), Vector2(vx + 30, vy + 10), Vector2(W, H)]), Color(.08, .06, .05))
	for i in 5:
		var u2 := (i + 1) / 6.0
		var x0: float = lerp(vx - 30, 0.0, u2)
		var x1: float = lerp(vx + 30, W, u2)
		var yt: float = lerp(vy - 20, 0.0, u2)
		var yb: float = lerp(vy + 10, H, u2)
		Spr.rect(x0 - 6 * u2, yt, 12 * u2, yb - yt, Color(.3, .2, .12))
		Spr.rect(x1 - 6 * u2, yt, 12 * u2, yb - yt, Color(.3, .2, .12))
		Spr.rect(x0, yt, x1 - x0, 10 * u2, Color(.3, .2, .12))
	# uma lanterna balançando, bem longe
	var sw := sin(t * 2.0) * 6
	Spr.glow(vx + sw, vy - 4, 46, Color(1, .75, .4, .5 * dark))
	Spr.circle(vx + sw, vy - 4, 2.5, Color(1, .9, .6, dark))

func _s_post_rails(W: float, H: float, k: float) -> void:
	_rails(W, H, k, clamp(k * 2, 0, 1))
	_vignette(W, H, .8)

func _s_post_pencil(W: float, H: float, k: float) -> void:
	_rails(W, H, k, 1.0)
	# o lápis rola pelo trilho até parar
	var e: float = clamp(k * 1.6, 0, 1)
	var px: float = lerp(W * .5, W * .42, e)
	var py: float = lerp(H * .45, H * .8, e)
	var sc: float = lerp(.3, 1.6, e)
	Spr.save()
	Spr.translate(px, py)
	Spr.rotate(e * 9.0)
	Spr.A("pen_vermelho", 0, 0, sc)
	Spr.restore()
	if e >= 1:
		Spr.glow(px, py, 40 + sin(t * 4) * 6, Color(1, .5, .4, .4))
	_vignette(W, H, .75)

## o Vargas no esconderijo, rindo, com o lampião (fundo pintado do esconderijo)
func _s_vargas_plan(W: float, H: float, k: float) -> void:
	var bg: Texture2D = Spr.tex.get("bg_esconderijo")
	if bg:
		var sc: float = H / bg.get_height() * 1.15
		var bw: float = bg.get_width() * sc
		Spr.img(bg, (W - bw) / 2 - k * 40, -H * .08, bw, bg.get_height() * sc)
	Spr.rect(0, 0, W, H, Color(0, 0, 0, .35))
	var z: float = 1.0 + k * .08
	var vx: float = W * .42
	var by: float = H * .96
	Spr.glow(vx + 70 * z, by - H * .32, H * .35, Color(1, .75, .35, .35))
	Spr.ellipse(vx, by, 120 * z, 16 * z, Color(0, 0, 0, .45))
	Spr.sheet("vargas_pe", 7 if int(t * 2.2) % 3 != 2 else 4, 200, 200, vx, by, H * .82 * z, false)
	# o bilhete da passagem do trem na mão
	if k > .35:
		var a: float = clamp((k - .35) * 4, 0, 1)
		Spr.save()
		Spr.translate(W * .66, H * .38)
		Spr.rotate(-.18)
		Spr.rr(-70, -40, 140, 80, 8, Color(.93, .86, .66, a))
		Spr.rr(-70, -40, 140, 18, 6, Color(.55, .2, .15, a))
		Spr.text("CARGA · MONTANHAS", 0, -26, 12, Color(1, .95, .85, a), HORIZONTAL_ALIGNMENT_CENTER, Spr.font_b)
		Spr.text("Partida 5h", 0, 6, 18, Color(.3, .2, .1, a), HORIZONTAL_ALIGNMENT_CENTER, Spr.font_title)
		Spr.text("1 vagão fechado", 0, 28, 11, Color(.3, .2, .1, a), HORIZONTAL_ALIGNMENT_CENTER, Spr.font_i)
		Spr.restore()
	_vignette(W, H, .75)

## o trem de carga saindo da mina de madrugada, rumo às montanhas; um lápis cai da janela
func _s_train(W: float, H: float, k: float) -> void:
	Spr.vgrad(0, 0, W, H * .8, Color("#0e1430"), Color("#4a3a5c"))
	Spr.circle(W * .78, H * .18, H * .07, Color(.95, .93, .82))
	Spr.glow(W * .78, H * .18, H * .22, Color(.8, .85, 1, .22))
	for i in 46:
		var sx: float = fposmod(i * 197.3, W)
		var sy: float = fposmod(i * 71.9, H * .42)
		Spr.circle(sx, sy, 1.2, Color(1, 1, 1, .45 + .4 * sin(t * 2 + i)))
	# cordilheira: picos com neve (luz da lua do lado direito)
	var peaks := [[.05, .48, .14], [.2, .36, .16], [.36, .44, .13], [.52, .3, .18], [.7, .4, .15], [.86, .33, .17], [1.0, .45, .14]]
	for pk in peaks:
		var px: float = W * float(pk[0])
		var py: float = H * float(pk[1])
		var hw: float = W * float(pk[2])
		Spr.poly(PackedVector2Array([Vector2(px - hw, H * .66), Vector2(px, py), Vector2(px + hw, H * .66)]), Color("#2c3152"))
		Spr.poly(PackedVector2Array([Vector2(px, py), Vector2(px + hw, H * .66), Vector2(px + hw * .35, H * .66)]), Color("#363c63"))
		var cap: float = H * .07
		Spr.poly(PackedVector2Array([Vector2(px - hw * cap / (H * .66 - py), py + cap), Vector2(px, py), Vector2(px + hw * cap / (H * .66 - py), py + cap)]), Color(.86, .9, .98, .9))
	# morro da mina (mais perto) com a passagem secreta
	Spr.poly(PackedVector2Array([Vector2(0, H), Vector2(0, H * .46), Vector2(W * .12, H * .42), Vector2(W * .26, H * .5), Vector2(W * .36, H * .68), Vector2(W * .38, H)]), Color("#191410"))
	Spr.rr(W * .2, H * .6, W * .11, H * .2, 34, Color("#040302"))
	Spr.rect(W * .195, H * .6, W * .012, H * .2, Color("#3a2614"))
	Spr.rect(W * .303, H * .6, W * .012, H * .2, Color("#3a2614"))
	# aterro e trilho
	var ty: float = H * .8
	Spr.vgrad(0, ty - 6, W, H - ty + 6, Color("#241c1a"), Color("#0b0909"))
	var sx2: float = fposmod(-k * 30.0, 26.0)
	while sx2 < W:
		Spr.rect(sx2, ty - 3, 14, 5, Color("#3a2a1c"))
		sx2 += 26
	Spr.rect(0, ty - 7, W, 3, Color("#8a8a94"))
	# o trem: locomotiva na frente, vagões de carga e o vagão fechado (a janelinha acesa) no fim
	var tx: float = lerp(W * .45, W * 1.05, k)
	var cw: float = W * .12
	var gap: float = W * .127
	for c in 4:
		var cx: float = tx - c * gap
		var top: float = ty - H * .17
		if c == 0:
			# locomotiva virada para a direita: cabine atrás, caldeira, chaminé e farol na frente
			Spr.rr(cx - cw, top - H * .02, cw * .32, H * .16, 4, Color("#2a2522"))
			Spr.rect(cx - cw * .96, top + H * .01, cw * .24, H * .04, Color(1, .8, .45, .8))
			Spr.rr(cx - cw * .7, top + H * .03, cw * .66, H * .11, 10, Color("#1e1b1a"))
			Spr.rect(cx - cw * .25, top - H * .05, cw * .1, H * .08, Color("#1e1b1a"))
			Spr.rect(cx - cw * .28, top - H * .06, cw * .16, H * .02, Color("#141212"))
			Spr.circle(cx - 8, top + H * .08, H * .018, Color(1, .92, .6))
			Spr.glow(cx + cw * .5, top + H * .08, H * .16, Color(1, .85, .5, .25))
			for sm in 7:
				var u: float = fposmod(t * .5 + sm / 7.0, 1.0)
				Spr.circle(cx - cw * .2 - u * W * .22, top - H * .06 - u * H * .22, H * (.025 + u * .07), Color(.72, .72, .78, .5 * (1.0 - u)))
		else:
			var col := Color("#3a2a20") if c < 3 else Color("#2c2a30")
			Spr.rr(cx - cw, top + H * .02, cw - 6, H * .12, 4, col)
			Spr.rect(cx - cw, top + H * .02, cw - 6, 5, Color(0, 0, 0, .35))
			for pl in 4:
				Spr.rect(cx - cw + 6 + pl * (cw - 18) / 4.0, top + H * .03, 2, H * .1, Color(0, 0, 0, .25))
			if c == 3:
				# o vagão fechado: a janelinha com grade, acesa
				Spr.rect(cx - cw * .62, top + H * .04, cw * .2, H * .045, Color(1, .8, .45, .85))
				for gb in 3:
					Spr.rect(cx - cw * .6 + gb * cw * .07, top + H * .04, 2, H * .045, Color("#1a1414"))
		Spr.rect(cx - cw - 4, ty - H * .035, 6, 4, Color("#141212"))
		for wv in 2:
			var wx: float = cx - cw * (.25 + .5 * wv)
			Spr.circle(wx, ty - H * .025, H * .028, Color("#0e0c0c"))
			Spr.circle(wx, ty - H * .025, H * .01, Color("#5a5a60"))
	# o lápis que cai da janelinha do vagão fechado e fica brilhando nos trilhos
	var x_drop: float = lerp(W * .45, W * 1.05, .3) - 3 * gap - cw * .52
	if k > .3:
		var e: float = clamp((k - .3) * 3, 0, 1)
		var px2: float = x_drop - e * 30
		var py2: float = lerp(ty - H * .12, ty - 10, e * e)
		Spr.save()
		Spr.translate(px2, py2)
		Spr.rotate(e * 6.0)
		Spr.A("pen_amarelo", 0, 0, .9)
		Spr.restore()
		Spr.glow(px2, py2, 24 + sin(t * 4) * 4, Color(1, .9, .4, .5))
	_vignette(W, H, .55)

func _s_ep3_card(W: float, H: float, k: float) -> void:
	Spr.rect(0, 0, W, H, Color(0, 0, 0))
	_s_post_card3(W, H, k)
	var a: float = clamp(k * 3 - .6, 0, 1)
	Spr.text("A trilha de lápis continua...", W / 2, H * .36 + 110, 22, Color(.9, .85, .75, a), HORIZONTAL_ALIGNMENT_CENTER, Spr.font_i, 4)

func _s_ep1_card(W: float, H: float, k: float) -> void:
	Spr.vgrad(0, 0, W, H, Color(.08, .06, .04), Color(0, 0, 0))
	var a: float = clamp(k * 3, 0, 1)
	Spr.text("ENCONTRE-A", W / 2, H * .3, 26, Color(.8, .72, .6, a), HORIZONTAL_ALIGNMENT_CENTER, Spr.font_title)
	Spr.text("EPISÓDIO 1", W / 2, H * .3 + 60, 44, Color(.95, .82, .55, a), HORIZONTAL_ALIGNMENT_CENTER, Spr.font_title, 6)
	Spr.text("O Bosque", W / 2, H * .3 + 104, 24, Color(.85, .8, .7, a * .9), HORIZONTAL_ALIGNMENT_CENTER, Spr.font_i)

func _s_post_card(W: float, H: float, k: float) -> void:
	Spr.vgrad(0, 0, W, H, Color(.06, .05, .04), Color(0, 0, 0))
	var a: float = clamp(k * 3, 0, 1)
	Spr.text("EPISÓDIO 2", W / 2, H * .36, 22, Color(.8, .72, .6, a), HORIZONTAL_ALIGNMENT_CENTER, Spr.font_title)
	Spr.text("AS PROFUNDEZAS DA MINA", W / 2, H * .36 + 54, 40, Color(.95, .82, .55, a), HORIZONTAL_ALIGNMENT_CENTER, Spr.font_title, 6)
