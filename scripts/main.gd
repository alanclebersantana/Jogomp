extends Node
## Telas e fluxo: título → mapa de Guarulhos → abertura do voo → corrida → resultado / voo perdido.

const FASES := {
	"1-1": {"nome": "Saguão de Check-in", "voo": "LA 3410"},
	"1-2": {"nome": "Raio-X e Portas", "voo": "LA 3522"},
	"1-3": {"nome": "Free Shop", "voo": "LA 3615"},
	"1-4": {"nome": "Esteiras de Bagagem", "voo": "LA 3730"},
	"1-5": {"nome": "Pátio dos Aviões", "voo": "LA 3804"},
	"1-6": {"nome": "Hangar", "voo": "LA 3911"},
	"1-7": {"nome": "Pista ao Anoitecer", "voo": "LA 4020"},
	"1-8": {"nome": "Portão Final", "voo": "LA 4136"},
	"1-chefe": {"nome": "Chefe: Motoboy Turbo", "voo": "LA 4200"},
}

var ui: CanvasLayer
var tela: Control
var jogo: Jogo
var fase_id := ""
var sit_antes := ""


func _ready() -> void:
	RenderingServer.set_default_clear_color(Color("1b2333"))
	ui = CanvasLayer.new()
	ui.layer = 10
	add_child(ui)
	get_tree().root.size_changed.connect(_redimensiona)
	titulo()


func _redimensiona() -> void:
	if tela:
		tela.size = get_viewport().get_visible_rect().size


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		if jogo and jogo.situacao in ["jogando", "pronto"]:
			_pausa()
		elif jogo == null and tela and tela.name == "Mapa":
			titulo()


# ------------------------------------------------------------------ peças de interface
func _limpa() -> void:
	if tela:
		tela.queue_free()
		tela = null


func _nova_tela(nome: String) -> Control:
	_limpa()
	tela = Control.new()
	tela.name = nome
	tela.size = get_viewport().get_visible_rect().size
	tela.mouse_filter = Control.MOUSE_FILTER_STOP
	ui.add_child(tela)
	return tela


func _caixa(cor: Color, raio := 22, borda := 0, cor_borda := Color.BLACK) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = cor
	sb.set_corner_radius_all(raio)
	if borda > 0:
		sb.set_border_width_all(borda)
		sb.border_color = cor_borda
	sb.content_margin_left = 18
	sb.content_margin_right = 18
	sb.content_margin_top = 10
	sb.content_margin_bottom = 10
	return sb


func _rotulo(pai: Control, txt: String, tam: int, cor := Arte.BRANCO, fonte: Font = null, contorno := 0) -> Label:
	var l := Label.new()
	l.text = txt
	l.add_theme_font_override("font", fonte if fonte else Arte.fonte_titulo)
	l.add_theme_font_size_override("font_size", tam)
	l.add_theme_color_override("font_color", cor)
	if contorno > 0:
		l.add_theme_constant_override("outline_size", contorno)
		l.add_theme_color_override("font_outline_color", Color(0.06, 0.08, 0.14))
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	pai.add_child(l)
	return l


func _botao(pai: Control, txt: String, cb: Callable, cor := Arte.AMARELO, cor_txt := Color("1b2333"), tam := 30) -> Button:
	var b := Button.new()
	b.text = txt
	b.custom_minimum_size = Vector2(0, 74)
	b.add_theme_font_override("font", Arte.fonte_titulo)
	b.add_theme_font_size_override("font_size", tam)
	for st in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		b.add_theme_color_override(st, cor_txt)
	b.add_theme_stylebox_override("normal", _caixa(cor, 37, 4, cor.darkened(0.45)))
	b.add_theme_stylebox_override("hover", _caixa(cor.lightened(0.08), 37, 4, cor.darkened(0.45)))
	b.add_theme_stylebox_override("pressed", _caixa(cor.darkened(0.12), 37, 4, cor.darkened(0.5)))
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	b.pressed.connect(func():
		Som.toca("ok", -6.0)
		cb.call())
	pai.add_child(b)
	return b


func _coluna(pai: Control, x0: float, x1: float, y: float, sep := 14) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", sep)
	v.position = Vector2(x0, y)
	v.size = Vector2(x1 - x0, 0)
	pai.add_child(v)
	return v


func _fundo_img(pai: Control, nome: String, veu := 0.45) -> void:
	var tx := Arte.t(nome)
	if tx:
		var r := TextureRect.new()
		r.texture = tx
		r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		r.set_anchors_preset(Control.PRESET_FULL_RECT)
		r.mouse_filter = Control.MOUSE_FILTER_IGNORE
		pai.add_child(r)
	var c := ColorRect.new()
	c.color = Color(0.06, 0.08, 0.14, veu)
	c.set_anchors_preset(Control.PRESET_FULL_RECT)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pai.add_child(c)


func _desenho(pai: Control, f: Callable) -> Node2D:
	var d: Node2D = preload("res://scripts/desenho.gd").new()
	d.f = f
	pai.add_child(d)
	return d


# ------------------------------------------------------------------ título
func titulo() -> void:
	_sai_do_jogo()
	var t := _nova_tela("Titulo")
	var W := t.size.x
	var H := t.size.y
	_fundo_img(t, "bg_terminal", 0.35)
	Som.tema("titulo")
	var marca := _rotulo(t, "MILHAS PLUS", 24, Arte.BRANCO, Arte.fonte)
	marca.autowrap_mode = TextServer.AUTOWRAP_OFF
	marca.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	marca.add_theme_stylebox_override("normal", _caixa(Arte.VERDE, 20))
	marca.position = Vector2(W / 2 - 110, H * 0.07)
	marca.size = Vector2(220, 46)
	var nome := _rotulo(t, "Cadê as\nmilhas?!", 92, Arte.AMARELO, null, 18)
	nome.position = Vector2(0, H * 0.12)
	nome.size = Vector2(W, 230)
	nome.add_theme_constant_override("line_spacing", -34)
	var sub := _rotulo(t, "Corra pelo aeroporto e recupere as milhas roubadas antes do portão fechar!", 21, Arte.BRANCO, Arte.fonte, 6)
	sub.position = Vector2(40, H * 0.37)
	sub.size = Vector2(W - 80, 60)
	var tempo := [0.0]
	var d := _desenho(t, func(ci: Node2D):
		var k: float = tempo[0]
		Arte.anim(ci, "barao", k, Vector2(W * 0.78, H * 0.62 + sin(k * 2) * 6), false, 0.62)
		for i in 5:
			var fx := W * 0.66 + i * 24 + sin(k * 3 + i) * 6
			var fy := H * 0.5 + fmod(k * 90 + i * 37, 120)
			Arte.quadro(ci, "milha_latam", 0, Vector2(fx, fy), false, 0.6)
		Arte.anim(ci, "milis_corre", k, Vector2(W * 0.3, H * 0.66), false, 2.1))
	var tm := Timer.new()
	tm.wait_time = 1.0 / 30.0
	tm.autostart = true
	tm.timeout.connect(func():
		tempo[0] += 1.0 / 30.0
		d.queue_redraw())
	t.add_child(tm)
	var col := _coluna(t, 60, W - 60, H * 0.72)
	_botao(col, "JOGAR", mapa, Arte.AMARELO, Color("1b2333"), 40).custom_minimum_size.y = 92
	var linha := HBoxContainer.new()
	linha.add_theme_constant_override("separation", 14)
	col.add_child(linha)
	var bm := _botao(linha, "", func(): pass, Color("2c3a55"), Arte.BRANCO, 22)
	bm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var bs := _botao(linha, "", func(): pass, Color("2c3a55"), Arte.BRANCO, 22)
	bs.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var atualiza := func():
		bm.text = "Música: " + ("sim" if Som.musica_ligada else "não")
		bs.text = "Sons: " + ("sim" if Som.sons_ligados else "não")
	atualiza.call()
	bm.pressed.connect(func():
		Som.liga_musica(not Som.musica_ligada)
		atualiza.call())
	bs.pressed.connect(func():
		Som.liga_sons(not Som.sons_ligados)
		atualiza.call())
	var ver := _rotulo(t, "versão de teste: todas as fases liberadas" if Save.teste() else "Episódio 1 · Guarulhos", 16, Color(1, 1, 1, 0.7), Arte.fonte_media)
	ver.position = Vector2(0, H - 40)
	ver.size = Vector2(W, 30)


# ------------------------------------------------------------------ mapa
func mapa() -> void:
	_sai_do_jogo()
	var t := _nova_tela("Mapa")
	var W := t.size.x
	var H := t.size.y
	_fundo_img(t, "bg_mezanino", 0.6)
	Som.tema("titulo")
	var topo := Panel.new()
	topo.add_theme_stylebox_override("panel", _caixa(Color("14181f"), 0, 0))
	topo.position = Vector2(0, 0)
	topo.size = Vector2(W, 150)
	t.add_child(topo)
	var a := _rotulo(topo, "GUARULHOS", 46, Arte.AMARELO)
	a.position = Vector2(0, 14)
	a.size = Vector2(W, 50)
	var b := _rotulo(topo, "Milhas LATAM · Episódio 1", 20, Arte.BRANCO, Arte.fonte_media)
	b.position = Vector2(0, 66)
	b.size = Vector2(W, 30)
	var c := _rotulo(topo, "O Barão das Milhas Falsas espalhou as milhas roubadas pelo aeroporto.", 16, Color(1, 1, 1, 0.75), Arte.fonte_media)
	c.position = Vector2(30, 98)
	c.size = Vector2(W - 60, 44)
	var voltar := _botao(t, "‹", titulo, Color("2c3a55"), Arte.BRANCO, 34)
	voltar.position = Vector2(12, 14)
	voltar.size = Vector2(60, 60)
	var sc := ScrollContainer.new()
	sc.position = Vector2(0, 160)
	sc.size = Vector2(W, H - 170)
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	t.add_child(sc)
	var lista := VBoxContainer.new()
	lista.add_theme_constant_override("separation", 12)
	lista.custom_minimum_size = Vector2(W, 0)
	sc.add_child(lista)
	for id in Fase.ORDEM:
		lista.add_child(_cartao_fase(id, W))
	var fim := Control.new()
	fim.custom_minimum_size = Vector2(0, 30)
	lista.add_child(fim)


func _cartao_fase(id: String, W: float) -> Control:
	var info: Dictionary = FASES[id]
	var pronta := Fase.existe(id) and id in Fase.PRONTAS
	var liberada := pronta and Save.liberada(Fase.ORDEM, id)
	var res := Save.fase(id)
	var margem := MarginContainer.new()
	margem.add_theme_constant_override("margin_left", 24)
	margem.add_theme_constant_override("margin_right", 24)
	var b := Button.new()
	b.custom_minimum_size = Vector2(0, 98)
	var cor := Color("f7f4ec") if liberada else Color("5b6577")
	b.add_theme_stylebox_override("normal", _caixa(cor, 18, 4, Color(0, 0, 0, 0.4)))
	b.add_theme_stylebox_override("hover", _caixa(cor.lightened(0.05), 18, 4, Color(0, 0, 0, 0.4)))
	b.add_theme_stylebox_override("pressed", _caixa(cor.darkened(0.08), 18, 4, Color(0, 0, 0, 0.4)))
	b.add_theme_stylebox_override("disabled", _caixa(cor, 18, 4, Color(0, 0, 0, 0.4)))
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	b.disabled = not liberada
	margem.add_child(b)
	var num := _rotulo(b, id.replace("1-chefe", "★"), 34, Color("1b2333") if liberada else Color(1, 1, 1, 0.5))
	num.position = Vector2(8, 22)
	num.size = Vector2(90, 50)
	var cor_txt := Color("1b2333") if liberada else Color(1, 1, 1, 0.6)
	var nm := _rotulo(b, str(info.nome), 24, cor_txt)
	nm.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	nm.position = Vector2(96, 10)
	nm.size = Vector2(W - 170, 36)
	var linha2 := ""
	if not pronta:
		linha2 = "Em breve"
	elif not liberada:
		linha2 = "Termine a fase anterior"
	elif res.is_empty():
		linha2 = "Voo %s · ainda não embarcou" % info.voo
	else:
		linha2 = "%d/%d milhas · sobrou %ds" % [int(res.milhas), int(res.total), int(res.sobra)]
	var l2 := _rotulo(b, linha2, 17, cor_txt.darkened(0.1) if liberada else cor_txt, Arte.fonte_media)
	l2.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	l2.position = Vector2(96, 50)
	l2.size = Vector2(W - 170, 30)
	if not res.is_empty():
		var selos := _desenho(b, func(ci: Node2D):
			_selo(ci, Vector2(W - 92, 30), true, "✈")
			_selo(ci, Vector2(W - 92, 70), bool(res.todas), "M")
		)
		selos.position = Vector2.ZERO
	if liberada:
		b.pressed.connect(func():
			Som.toca("ok", -6.0)
			abertura(id))
	return margem


func _selo(ci: Node2D, c: Vector2, ok: bool, s: String) -> void:
	ci.draw_circle(c, 16, Arte.VERDE if ok else Color(0, 0, 0, 0.15))
	Arte.texto(ci, s, c + Vector2(-16, 8), 20, Arte.BRANCO if ok else Color(0, 0, 0, 0.3), HORIZONTAL_ALIGNMENT_CENTER, 32, 0, Color.BLACK, Arte.fonte)


# ------------------------------------------------------------------ abertura do voo
func abertura(id: String) -> void:
	_sai_do_jogo()
	var f := Fase.abre(id)
	if f == null:
		return
	var t := _nova_tela("Abertura")
	var W := t.size.x
	var H := t.size.y
	_fundo_img(t, "bg_" + f.m("fundo", "terminal"), 0.55)
	# painel de embarque
	var p := Panel.new()
	p.add_theme_stylebox_override("panel", _caixa(Color("14181f"), 20, 4, Color("f2c230")))
	p.position = Vector2(30, H * 0.12)
	p.size = Vector2(W - 60, 300)
	t.add_child(p)
	var cab := _rotulo(p, "PARTIDAS · GUARULHOS", 20, Color("f2c230"), Arte.fonte)
	cab.position = Vector2(0, 16)
	cab.size = Vector2(p.size.x, 30)
	var linhas := [["VOO", f.m("voo")], ["DESTINO", f.m("destino", "—")], ["PORTÃO", f.m("portao")], ["SITUAÇÃO", "ÚLTIMA CHAMADA"]]
	for i in linhas.size():
		var y := 60 + i * 52
		var k := _rotulo(p, linhas[i][0], 18, Color(1, 1, 1, 0.6), Arte.fonte)
		k.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		k.position = Vector2(24, y + 6)
		k.size = Vector2(140, 30)
		var v := _rotulo(p, linhas[i][1], 28, Color("ffd862") if i < 3 else Color("ff7a5c"), Arte.fonte_titulo)
		v.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		v.position = Vector2(160, y)
		v.size = Vector2(p.size.x - 180, 40)
	var nome := _rotulo(t, "%s  %s" % [id, f.m("nome")], 40, Arte.AMARELO, null, 12)
	nome.position = Vector2(20, H * 0.12 + 320)
	nome.size = Vector2(W - 40, 60)
	var intro := _rotulo(t, f.m("intro"), 22, Arte.BRANCO, Arte.fonte_media, 6)
	intro.position = Vector2(36, H * 0.12 + 390)
	intro.size = Vector2(W - 72, 140)
	var obj := _rotulo(t, "Chegue ao portão em %ds · Pegue as milhas" % int(f.mf("tempo", 90)), 18, Color(0.75, 1, 0.8), Arte.fonte, 5)
	obj.position = Vector2(20, H * 0.12 + 540)
	obj.size = Vector2(W - 40, 30)
	var col := _coluna(t, 60, W - 60, H - 210)
	_botao(col, "CORRER!", func(): comeca(id), Arte.AMARELO, Color("1b2333"), 40).custom_minimum_size.y = 90
	_botao(col, "Voltar ao mapa", mapa, Color("2c3a55"), Arte.BRANCO, 24)


# ------------------------------------------------------------------ jogo
func comeca(id: String) -> void:
	_limpa()
	_sai_do_jogo()
	fase_id = id
	var f := Fase.abre(id)
	jogo = Jogo.new()
	add_child(jogo)
	jogo.inicia(f)
	jogo.embarcou.connect(_embarcou)
	jogo.perdeu_voo.connect(_perdeu)
	jogo.pausa.connect(_pausa)


func _sai_do_jogo() -> void:
	if jogo:
		jogo.queue_free()
		jogo = null


func _pausa() -> void:
	if jogo == null or jogo.situacao == "pausado":
		return
	sit_antes = jogo.situacao
	jogo.situacao = "pausado"
	jogo.toques.clear()
	jogo.segurando = false
	var t := _nova_tela("Pausa")
	var W := t.size.x
	var H := t.size.y
	var c := ColorRect.new()
	c.color = Color(0.05, 0.07, 0.12, 0.75)
	c.set_anchors_preset(Control.PRESET_FULL_RECT)
	t.add_child(c)
	var a := _rotulo(t, "PAUSA", 64, Arte.AMARELO, null, 14)
	a.position = Vector2(0, H * 0.2)
	a.size = Vector2(W, 80)
	var b := _rotulo(t, "O relógio do embarque está parado.", 20, Arte.BRANCO, Arte.fonte_media)
	b.position = Vector2(0, H * 0.2 + 84)
	b.size = Vector2(W, 30)
	var col := _coluna(t, 60, W - 60, H * 0.42)
	_botao(col, "CONTINUAR", _continua, Arte.AMARELO, Color("1b2333"), 34)
	_botao(col, "Recomeçar a fase", func(): comeca(fase_id), Color("2c3a55"), Arte.BRANCO, 24)
	_botao(col, "Sair para o mapa", mapa, Color("2c3a55"), Arte.BRANCO, 24)
	var linha := HBoxContainer.new()
	linha.add_theme_constant_override("separation", 14)
	col.add_child(linha)
	var bm := _botao(linha, "", func(): pass, Color("3a4a68"), Arte.BRANCO, 20)
	bm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var bs := _botao(linha, "", func(): pass, Color("3a4a68"), Arte.BRANCO, 20)
	bs.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var atualiza := func():
		bm.text = "Música: " + ("sim" if Som.musica_ligada else "não")
		bs.text = "Sons: " + ("sim" if Som.sons_ligados else "não")
	atualiza.call()
	bm.pressed.connect(func():
		Som.liga_musica(not Som.musica_ligada)
		atualiza.call())
	bs.pressed.connect(func():
		Som.liga_sons(not Som.sons_ligados)
		atualiza.call())


func _continua() -> void:
	_limpa()
	if jogo:
		jogo.situacao = sit_antes


func _embarcou(r: Dictionary) -> void:
	var melhor := Save.registra(fase_id, r)
	var t := _nova_tela("Resultado")
	var W := t.size.x
	var H := t.size.y
	var c := ColorRect.new()
	c.color = Color(0.05, 0.07, 0.12, 0.8)
	c.set_anchors_preset(Control.PRESET_FULL_RECT)
	t.add_child(c)
	Som.tema("vitoria")
	var a := _rotulo(t, "EMBARCOU!", 66, Color(0.6, 1, 0.65), null, 14)
	a.position = Vector2(0, H * 0.08)
	a.size = Vector2(W, 80)
	var b := _rotulo(t, "%s · %s" % [jogo.fase.m("voo"), jogo.fase.m("nome")], 22, Arte.BRANCO, Arte.fonte_media)
	b.position = Vector2(0, H * 0.08 + 80)
	b.size = Vector2(W, 30)
	var tempo := [0.0]
	var d := _desenho(t, func(ci: Node2D):
		Arte.anim(ci, "milis_festa", tempo[0], Vector2(W / 2, H * 0.43), false, 1.7))
	var tm := Timer.new()
	tm.wait_time = 1.0 / 20.0
	tm.autostart = true
	tm.timeout.connect(func():
		tempo[0] += 0.05
		d.queue_redraw())
	t.add_child(tm)
	var p := Panel.new()
	p.add_theme_stylebox_override("panel", _caixa(Color("f7f4ec"), 22, 4, Color(0, 0, 0, 0.4)))
	p.position = Vector2(34, H * 0.46)
	p.size = Vector2(W - 68, 250)
	t.add_child(p)
	var itens := [
		["Milhas", "%d / %d" % [int(r.milhas), int(r.total)], bool(r.todas), "Todas as milhas!" if r.todas else "Faltaram %d" % (int(r.total) - int(r.milhas))],
		["Tempo de sobra", "%ds" % int(r.sobra), bool(r.rapido), "Meta: %ds" % int(r.meta)],
		["Tropeços", str(int(r.quedas)), int(r.quedas) == 0, "Sem tropeçar!" if int(r.quedas) == 0 else ""],
	]
	for i in itens.size():
		var y := 22 + i * 76
		var k := _rotulo(p, itens[i][0], 20, Color("4a5468"), Arte.fonte)
		k.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		k.position = Vector2(24, y)
		k.size = Vector2(240, 30)
		var dica := _rotulo(p, itens[i][3], 15, Color("2f8f52") if itens[i][2] else Color("8a6a3a"), Arte.fonte_media)
		dica.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		dica.position = Vector2(24, y + 30)
		dica.size = Vector2(260, 24)
		var v := _rotulo(p, itens[i][1], 34, Color("1b2333"))
		v.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		v.position = Vector2(p.size.x - 230, y - 2)
		v.size = Vector2(170, 50)
		var ok: bool = itens[i][2]
		_desenho(p, func(ci: Node2D):
			ci.draw_circle(Vector2(p.size.x - 34, y + 24), 17, Arte.VERDE if ok else Color(0, 0, 0, 0.12))
			if ok:
				ci.draw_polyline(PackedVector2Array([Vector2(p.size.x - 43, y + 24), Vector2(p.size.x - 36, y + 31), Vector2(p.size.x - 24, y + 16)]), Arte.BRANCO, 4))
	var col := _coluna(t, 60, W - 60, H * 0.46 + 270, 12)
	var i_prox := Fase.ORDEM.find(fase_id) + 1
	var prox: String = Fase.ORDEM[i_prox] if i_prox < Fase.ORDEM.size() else ""
	if prox != "" and prox in Fase.PRONTAS:
		_botao(col, "PRÓXIMO VOO", func(): abertura(prox), Arte.AMARELO, Color("1b2333"), 34)
	elif prox != "":
		var em := _rotulo(col, "Próxima fase (%s) em breve!" % FASES[prox].nome, 20, Arte.AMARELO, Arte.fonte)
		em.custom_minimum_size = Vector2(0, 40)
	_botao(col, "Jogar de novo", func(): comeca(fase_id), Color("2c3a55"), Arte.BRANCO, 24)
	_botao(col, "Mapa de Guarulhos", mapa, Color("2c3a55"), Arte.BRANCO, 24)
	if melhor.get("todas", false) and not r.todas:
		pass


func _perdeu() -> void:
	var t := _nova_tela("Perdeu")
	var W := t.size.x
	var H := t.size.y
	var c := ColorRect.new()
	c.color = Color(0.12, 0.04, 0.05, 0.82)
	c.set_anchors_preset(Control.PRESET_FULL_RECT)
	t.add_child(c)
	var a := _rotulo(t, "PORTÃO\nFECHADO!", 66, Color("ff7a5c"), null, 14)
	a.position = Vector2(0, H * 0.12)
	a.size = Vector2(W, 170)
	a.add_theme_constant_override("line_spacing", -22)
	var b := _rotulo(t, "O voo %s partiu sem o Milis.\nPegue os atalhos e não tropece!" % jogo.fase.m("voo"), 22, Arte.BRANCO, Arte.fonte_media)
	b.position = Vector2(30, H * 0.12 + 180)
	b.size = Vector2(W - 60, 80)
	var tempo := [0.0]
	var d := _desenho(t, func(ci: Node2D):
		Arte.quadro(ci, "milis_sentado", 0, Vector2(W / 2, H * 0.62), false, 1.8))
	d.queue_redraw()
	var col := _coluna(t, 60, W - 60, H * 0.68)
	_botao(col, "TENTAR DE NOVO", func(): comeca(fase_id), Arte.AMARELO, Color("1b2333"), 34)
	_botao(col, "Mapa de Guarulhos", mapa, Color("2c3a55"), Arte.BRANCO, 24)
	tempo[0] = 0.0
