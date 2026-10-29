extends Node2D
## Milhas Plus - Última Chamada! — telas, desenho da fase, controles, HUD, música e sons.
## A física fica em sim.gd. A fase vem de assets/data/guarulhos.json. A arte vem do Gemini (assets/sprites/arte.json).
## Linha de comando (depois de "--"): --bot (joga sozinho), --x=300 (começa no metro 300),
## --deus (não tropeça), --fotos=5,100 --pasta=/tmp (tira prints nesses metros e fecha), --final (mostra o final).

const PX := 72.0          # pixels por metro na visão lateral
const W := 720.0
const H := 1280.0
const FOCO := 760.0       # visão de trás: distância focal em px
const DIST_TRAS := 6.8
const ALT_TRAS := 3.7
const HZ := 0.4           # horizonte da visão de trás (fração da altura)
const CHAO_TELA := 0.74   # onde fica o chão na tela (fração da altura)
const TINTA := Color("#1f1a17")
const ROTA := [
	["Guarulhos", "SP", "Milhas LATAM", "Marginal, garoa, multidão e o trem entre terminais"],
	["Maringá", "PR", "Milhas Azul", "Ipês, Catedral e terra roxa"],
	["Brasília", "DF", "Milhas Smiles", "Curvas de Niemeyer e o Eixo Monumental"],
	["Salvador", "BA", "Milhas Azul", "Túnel de bambu, Pelourinho e Olodum"],
	["Rio de Janeiro", "RJ", "Milhas Smiles", "Santos Dumont, bondinho e Galeão"],
]
const POSES := {"sobe": 0, "cai": 1, "plana": 2, "dash": 3, "tropeca": 4, "vitoria": 5, "bola": 6, "parado": 7}
const VOOS := [["PLUS 218", "MARINGÁ"], ["PLUS 104", "BRASÍLIA"], ["PLUS 330", "SALVADOR"], ["PLUS 512", "RIO SDU"], ["PLUS 077", "MIAMI"]]

var F: Dictionary
var S: Sim
var T := {}              # texturas
var META := {}           # tamanhos das imagens (arte.json + objetos.json)
var COR_TOPO := {}       # cor do alto de cada fundo (para preencher o céu/teto)
var lado: Node2D
var tras_v: Node2D
var final_v: Node2D
var estado := "menu"
var bot := false
var deus := false
var x_inicio := 0.0
var fotos: Array = []
var pasta_fotos := "user://"
var espera_foto := -1
var fotos_t: Array = []     # prints por tempo (segundos de relógio)
var com_intro := false
var acum := 0.0
var relogio := 0.0
var t := 0.0
var t_final := 0.0
var fim_tipo := ""

# câmera
var cam_x := 0.0
var cam_y := 0.0
var cam_chao := 0.0
var tras := 0.0
var tremer := 0.0
var fase_anim := 0.0
var gotas: Array = []
var raio_t := 0.0          # relâmpago no temporal
var monitor_t := 0.0       # monitor do raio-x
var monitor_x := 0.0
var entraram := {}         # perseguidores que já entraram
var dingdong_feito := {}
var apito_t := 0.0
var portas_estado := {}

# toque
var toque_ativo := false
var toque_ini := Vector2.ZERO
var toque_t := 0.0
var toque_feito := false
var ultimo_tap := -10.0

# HUD
var fonte: FontFile
var hud: Control
var lbl_tempo: Label
var lbl_milhas: Label
var lbl_cartao: Label
var lbl_chuva: Label
var barra_guarda: ColorRect
var lbl_dica: Label
var lbl_aviso: Label
var flash: ColorRect
var tela_inicio: Control
var tela_pausa: Control
var tela_fim: Control
var lbl_fim_titulo: Label
var lbl_fim_estrelas: Label
var lbl_fim_res: Label
var lbl_rota: Array = []
var dica_t := 0.0
var aviso_t := 0.0

var sons := {}
var tocadores: Array = []
var musica: AudioStreamPlayer
var chuva_som: AudioStreamPlayer


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	bot = "--bot" in args
	deus = "--deus" in args
	com_intro = "--intro" in args
	for a in args:
		if a.begins_with("--x="):
			x_inicio = float(a.substr(4))
		elif a.begins_with("--fotos="):
			for v in a.substr(8).split(","):
				fotos.append(float(v))
			bot = true
		elif a.begins_with("--fotos_t="):
			for v in a.substr(10).split(","):
				fotos_t.append(float(v))
		elif a.begins_with("--pasta="):
			pasta_fotos = a.substr(8)
	F = JSON.parse_string(FileAccess.get_file_as_string("res://assets/data/guarulhos.json"))
	var velho = JSON.parse_string(FileAccess.get_file_as_string("res://assets/sprites/objetos.json"))
	for k in velho:
		META[k] = velho[k]
	var arte = JSON.parse_string(FileAccess.get_file_as_string("res://assets/sprites/arte.json"))
	for k in arte:
		META[k] = arte[k]
	for nome in META:
		var tipo: String = META[nome].get("tipo", "obj")
		var caminho := "res://assets/bg/%s.jpg" % nome if tipo == "bg" else "res://assets/sprites/%s.png" % nome
		if ResourceLoader.exists(caminho):
			T[nome] = load(caminho)
			if tipo == "bg":
				var img: Image = (T[nome] as Texture2D).get_image()
				COR_TOPO[nome] = img.get_pixel(img.get_width() / 2, 2)
	lado = _pintor(_desenhar_lado)
	tras_v = _pintor(_desenhar_tras)
	final_v = _pintor(_desenhar_final)
	final_v.visible = false
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	for i in 220:
		gotas.append(Vector2(rng.randf() * W, rng.randf() * H))
	_montar_hud()
	_montar_sons()
	novo_jogo()
	if "--final" in args:
		iniciar()
		_comecar_final("venceu")
	elif bot or x_inicio > 0.0:
		iniciar()
	else:
		_mostrar_tela("inicio")


func _pintor(f: Callable) -> Node2D:
	var n := Node2D.new()
	n.set_script(load("res://scripts/pintor.gd"))
	n.desenhar = f
	n.texture_repeat = CanvasItem.TEXTURE_REPEAT_DISABLED
	add_child(n)
	return n


func novo_jogo() -> void:
	S = Sim.new(F, x_inicio, com_intro or not (bot or x_inicio > 0.0))
	S.bot = bot
	S.deus = deus
	cam_chao = S.py
	tras = 1.0 if S.na_zona_tras(S.px) else 0.0
	entraram.clear()
	dingdong_feito.clear()
	portas_estado.clear()
	fim_tipo = ""
	_camera(0.0, true)
	_atualizar_hud()


func iniciar() -> void:
	novo_jogo()
	estado = "jogo"
	final_v.visible = false
	_mostrar_tela("")
	if S.intro > 0.0:
		som("buzina")
	else:
		aviso("PLUS 218 · ÚLTIMA CHAMADA!", 1.6)
	if musica and not musica.playing:
		musica.play()


# ------------------------------------------------------------------ laço
func _process(delta: float) -> void:
	var dt: float = minf(delta, 0.05)
	relogio += dt
	t += dt
	if toque_ativo and not toque_feito and relogio - toque_t > 0.2 and estado == "jogo":
		toque_feito = true
		S.acao("cima")
		S.hold = true
	if not fotos_t.is_empty() and relogio >= fotos_t[0]:
		var img := get_viewport().get_texture().get_image()
		img.save_png(pasta_fotos.path_join("tempo_%04d.png" % int(fotos_t[0] * 100.0)))
		fotos_t.pop_front()
		if fotos_t.is_empty():
			get_tree().quit()
	if not fotos.is_empty() and estado == "jogo":
		_modo_fotos()
		return
	if estado == "jogo":
		acum += dt
		var h := 1.0 / 120.0
		while acum >= h:
			S.passo(h)
			acum -= h
			if S.fim != "":
				break
		_eventos()
		_ambiente(dt)
	elif estado == "final":
		t_final += dt
		if S.px < float(F["fim"]) + 0.6:
			S.px += dt * 3.5
		if t_final > 7.5:
			_mostrar_resultado()
	if estado in ["jogo", "final"]:
		if S.no_chao and S.rolar_t <= 0.0:
			fase_anim += dt * S.vx * 1.1
		_camera(dt)
		_atualizar_hud()
		lado.queue_redraw()
		tras_v.queue_redraw()
		final_v.queue_redraw()
	monitor_t = maxf(0.0, monitor_t - dt)
	raio_t = maxf(0.0, raio_t - dt)
	if dica_t > 0.0:
		dica_t -= dt
		if dica_t <= 0.0:
			lbl_dica.visible = false
	if aviso_t > 0.0:
		aviso_t -= dt
		if aviso_t <= 0.0:
			lbl_aviso.visible = false
	flash.color.a = maxf(0.0, flash.color.a - dt * 3.0)


func _modo_fotos() -> void:
	if espera_foto < 0:
		var n := 0
		while S.fim == "" and S.px < fotos[0] and n < 120 * 40:
			S.passo(1.0 / 120.0)
			n += 1
		S.eventos.clear()
		_camera(0.0, true)
		espera_foto = 3
	elif espera_foto == 0:
		var img := get_viewport().get_texture().get_image()
		img.save_png(pasta_fotos.path_join("ultima_%d.png" % int(fotos[0])))
		print("foto ", fotos[0])
		fotos.pop_front()
		espera_foto = -1
		if fotos.is_empty():
			get_tree().quit()
	else:
		espera_foto -= 1
	lbl_aviso.visible = false
	lbl_dica.visible = false
	_atualizar_hud()
	lado.queue_redraw()
	tras_v.queue_redraw()


func _eventos() -> void:
	for e in S.eventos:
		match e[0]:
			"som":
				som(e[1])
			"aviso":
				aviso(e[1], 0.9)
			"dica":
				dica(e[1])
			"flash":
				flash.color.a = 0.4
			"tremer":
				tremer = maxf(tremer, e[1])
			"raiox":
				monitor_t = 1.6
				monitor_x = e[1]
			"ataque":
				som({"etiqueta": "etiqueta", "cao": "latido", "cone": "cone"}.get(e[1], "etiqueta"))
			"fim":
				_comecar_final(e[1])
	S.eventos.clear()


func _ambiente(dt: float) -> void:
	# perseguidores que entram, avisos do aeroporto, apito, portas
	for p in F.get("perseguidores", []):
		if not entraram.has(p["tipo"]) and S.px >= float(p["x"]):
			entraram[p["tipo"]] = true
			dica(p["texto"])
			if p["tipo"] == "cao":
				som("latido")
	var sec: String = secao_em(S.px)["tipo"]
	if sec == "embarque" and not dingdong_feito.has("embarque"):
		dingdong_feito["embarque"] = true
		som("dingdong")
	if S.tempo < 20.0 and not dingdong_feito.has("ultima"):
		dingdong_feito["ultima"] = true
		som("dingdong")
		aviso("ÚLTIMA CHAMADA!", 1.4)
	apito_t -= dt
	if S.guarda < 4.0 and apito_t <= 0.0 and S.px > float(F.get("guarda_entra", 0.0)):
		apito_t = 2.6
		som("apito")
	for i in S.portas.size():
		var d: Dictionary = S.portas[i]
		var ab := S.porta_aberta(d, S.t)
		if portas_estado.get(i, true) != ab and absf(d["x"] - S.px) < 14.0:
			som("porta")
		portas_estado[i] = ab
	if sec == "trem" and randf() < dt * 0.12:
		raio_t = 0.25
	var fora := sec in ["marginal", "estacionamento", "calcada", "trem", "finger"]
	if chuva_som:
		var alvo_db := (-4.0 if sec == "trem" else -12.0) if fora else -40.0
		chuva_som.volume_db = lerpf(chuva_som.volume_db, alvo_db, minf(1.0, dt * 2.0))


# ------------------------------------------------------------------ câmera e projeção
func _camera(dt: float, imediato := false) -> void:
	var alvo_tras := 1.0 if S.na_zona_tras(S.px) else 0.0
	tras = alvo_tras if imediato else move_toward(tras, alvo_tras, dt * 2.8)
	var alvo := S.py if S.no_chao else cam_chao
	if S.py < cam_chao - 0.8:
		alvo = S.py
	if S.py > cam_chao + 2.6:
		alvo = S.py - 2.6
	cam_chao = alvo if imediato else lerpf(cam_chao, alvo, minf(1.0, dt * (4.0 if S.no_chao else 3.0)))
	cam_x = S.px + 2.4
	if S.intro > 0.0:
		cam_x = S.px + 1.6
	cam_y = cam_chao + (CHAO_TELA - 0.5) * H / PX
	tremer = maxf(0.0, tremer - dt)
	var a := smoothstep(0.0, 1.0, tras)
	lado.visible = a < 0.999 and estado != "final" or (estado == "final" and t_final < 1.4)
	tras_v.visible = a > 0.001 and estado != "final"
	tras_v.modulate.a = a
	final_v.visible = estado == "final" and t_final >= 1.2
	var sh := Vector2(randf() - 0.5, randf() - 0.5) * tremer * 40.0
	lado.position = sh
	tras_v.position = sh


func tela(x: float, y: float) -> Vector2:
	return Vector2((x - cam_x) * PX + W * 0.5, H * 0.5 - (y - cam_y) * PX)


func _margem(nome: String) -> float:
	return float(META[nome].get("base", 0.0)) * float(META[nome]["pxm"])


## Objeto: centro em x, base em y (metros). largura > 0 encaixa a largura desenhada (sem a margem).
func obj(c: CanvasItem, nome: String, x: float, y: float, quadro := 0, mod := Color.WHITE, largura := 0.0, espelho := false, rot := 0.0, esc_y := 1.0) -> void:
	if not T.has(nome):
		return
	var tex: Texture2D = T[nome]
	var m: Dictionary = META[nome]
	var q: int = int(m.get("quadros", 1))
	var fw := float(tex.get_width()) / q
	var fh := float(tex.get_height())
	var mg := _margem(nome)
	var k := PX / float(m["pxm"])
	if largura > 0.0:
		k = largura * PX / maxf(1.0, fw - 2.0 * mg)
	var base := tela(x, y)
	if rot != 0.0:
		var centro := base - Vector2(0, (fh * 0.5 - mg) * k)
		c.draw_set_transform(centro, rot, Vector2(k * (-1.0 if espelho else 1.0), k * esc_y))
		c.draw_texture_rect_region(tex, Rect2(-fw * 0.5, -fh * 0.5, fw, fh), Rect2((quadro % q) * fw, 0, fw, fh), mod)
	else:
		c.draw_set_transform(base, 0.0, Vector2(k * (-1.0 if espelho else 1.0), k * esc_y))
		c.draw_texture_rect_region(tex, Rect2(-fw * 0.5, -(fh - mg), fw, fh), Rect2((quadro % q) * fw, 0, fw, fh), mod)
	c.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## Personagem (folha de quadros com o ponto do pé): pés em (x, y).
func pers(c: CanvasItem, nome: String, quadro: int, x: float, y: float, mod := Color.WHITE, espelho := false, esc := 1.0, rot := 0.0) -> void:
	var m: Dictionary = META[nome]
	var qw := float(m["qw"])
	var qh := float(m["qh"])
	var pe: Array = m["pe"]
	var k := PX / float(m["pxm"]) * esc
	var q: int = quadro % int(m["quadros"])
	if rot != 0.0:
		var centro := tela(x, y) - Vector2(0, (float(pe[1]) - qh * 0.45) * k)
		c.draw_set_transform(centro, rot, Vector2(k * (-1.0 if espelho else 1.0), k))
		c.draw_texture_rect_region(T[nome], Rect2(-float(pe[0]), -qh * 0.45 - (qh - float(pe[1])) * 0.0 - qh * 0.1, qw, qh), Rect2(q * qw, 0, qw, qh), mod)
	else:
		c.draw_set_transform(tela(x, y), 0.0, Vector2(k * (-1.0 if espelho else 1.0), k))
		c.draw_texture_rect_region(T[nome], Rect2(-float(pe[0]), -float(pe[1]), qw, qh), Rect2(q * qw, 0, qw, qh), mod)
	c.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## Repete uma imagem na horizontal entre sx0 e sx1 (px de tela), espelhando uma sim, outra não (a emenda some).
func ladrilhar(c: CanvasItem, tex: Texture2D, sx0: float, sx1: float, deslocamento: float, topo: float, altura: float, mod := Color.WHITE) -> void:
	if sx1 <= sx0:
		return
	var tw := float(tex.get_width()) * altura / float(tex.get_height())
	var texw := float(tex.get_width())
	var i := floori((sx0 - deslocamento) / tw)
	while true:
		var x0 := deslocamento + i * tw
		if x0 >= sx1:
			break
		var a := maxf(x0, sx0)
		var b := minf(x0 + tw, sx1)
		if b > a:
			var u0 := (a - x0) / tw
			var u1 := (b - x0) / tw
			if posmod(i, 2) == 0:
				c.draw_texture_rect_region(tex, Rect2(a, topo, b - a, altura), Rect2(u0 * texw, 0, (u1 - u0) * texw, tex.get_height()), mod)
			else:
				# espelhado: desenha virado com uma transformação (retângulo negativo não aparece no GL)
				c.draw_set_transform(Vector2(b, 0), 0.0, Vector2(-1, 1))
				c.draw_texture_rect_region(tex, Rect2(0, topo, b - a, altura), Rect2((1.0 - u1) * texw, 0, (u1 - u0) * texw, tex.get_height()), mod)
				c.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		i += 1


func secao_em(x: float) -> Dictionary:
	for s in F["secoes"]:
		if x >= s["x0"] and x < s["x1"]:
			return s
	return F["secoes"][F["secoes"].size() - 1]


func _baixo_em(x: float) -> float:
	## Altura do piso de baixo nesse ponto (ou 99 se não houver).
	for ch in F["chao"]:
		if ch["y"] < -1.0 and x >= ch["x0"] and x <= ch["x1"]:
			return float(ch["y"])
	return 99.0


# ------------------------------------------------------------------ visão lateral
func _desenhar_lado(c: CanvasItem) -> void:
	var xa := cam_x - W / PX * 0.62
	var xb := cam_x + W / PX * 0.62
	var chao_y := tela(0, 0).y
	c.draw_rect(Rect2(0, 0, W, H), Color("#8597a8"))
	# fundos de cada trecho (cada um só dentro do seu pedaço)
	for s in F["secoes"]:
		var a: float = s["x0"]
		var b: float = s["x1"]
		if b < xa or a > xb:
			continue
		var sx0: float = clampf(tela(a, 0).x, -2.0, W + 2.0)
		var sx1: float = clampf(tela(b, 0).x, -2.0, W + 2.0)
		var tipo: String = s["tipo"]
		match tipo:
			"marginal", "calcada", "trem", "finger":
				var nome := "marginal" if tipo == "marginal" else "ceu_sp"
				var tex: Texture2D = T[nome]
				var alt := H * 0.82
				var topo := chao_y + 70.0 - alt
				if tipo == "finger":
					topo = chao_y + 3.75 * PX - alt
					c.draw_rect(Rect2(sx0, topo + alt - 6.0, sx1 - sx0, H), Color("#5d646b"))
				c.draw_rect(Rect2(sx0, 0, sx1 - sx0, topo + 4), COR_TOPO[nome])
				ladrilhar(c, tex, sx0, sx1, -cam_x * PX * 0.3, topo, alt)
				if tipo == "finger":
					# avião atrás, com a porta aberta no fim do finger
					obj(c, "aviao", float(F["fim"]) + 0.5 - 9.17, -3.69, 0, Color.WHITE, 30.0)
					var fim_f: float = float(F["fim"]) - 0.6
					_parede(c, "parede_finger", a, fim_f, 0.0, 3.6, sx0, clampf(tela(fim_f, 0).x, sx0, sx1), false)
			"estacionamento":
				var tex2: Texture2D = T["estacionamento"]
				var alt2 := 9.5 * PX
				var topo2 := chao_y + 0.6 * PX - alt2
				c.draw_rect(Rect2(sx0, 0, sx1 - sx0, topo2 + 4), Color("#4a4f55"))
				ladrilhar(c, tex2, sx0, sx1, -cam_x * PX * 0.7, topo2, alt2)
			"checkin", "subsolo", "seguranca", "embarque":
				var nome2: String = {"checkin": "parede_checkin", "subsolo": "parede_checkin", "seguranca": "parede_seguranca", "embarque": "parede_embarque"}[tipo]
				_parede(c, nome2, a, b, -0.1, 8.7, sx0, sx1)
	# áreas de baixo (subsolo e alçapões): só aparecem nesses pedaços
	for ch in F["chao"]:
		if ch["y"] > -1.0 or ch["x1"] < xa or ch["x0"] > xb:
			continue
		var y: float = ch["y"]
		var s0: float = clampf(tela(ch["x0"], 0).x, -2.0, W + 2.0)
		var s1: float = clampf(tela(ch["x1"], 0).x, -2.0, W + 2.0)
		var topo3 := tela(0, -0.55).y
		var base3 := tela(0, y).y
		c.draw_rect(Rect2(s0, topo3, s1 - s0, base3 - topo3), Color("#2c3136"))
		var tex3: Texture2D = T["parede_subsolo"]
		ladrilhar(c, tex3, s0, s1, -cam_x * PX * 0.9, base3 - minf(5.0, -y - 0.55) * PX, minf(5.0, -y - 0.55) * PX)
	# decoração de fundo
	for d in F["decor"]:
		var dx: float = d["x"]
		if dx < xa - 14.0 or dx > xb + 14.0:
			continue
		match d["tipo"]:
			"taxi":
				obj(c, "taxi", dx, 0.0, 0, Color("#c9d0d6"), 4.0)
			"taxi_parado":
				var aberto := S.intro <= 1.6 or S.intro <= 0.0
				obj(c, "taxi_aberto" if aberto and S.intro < 1.7 else "taxi", dx, 0.0, 0, Color.WHITE, 4.2)
				if S.intro > 1.5:
					_balao(c, tela(dx + 1.2, 2.6), "BI-BI!", Color("#c0392b"))
			"carrinho_vazio":
				if not S.montado and S.px < dx:
					obj(c, "carrinho", dx, 0.0, 0, Color.WHITE, 1.8)
			"vendedor":
				pers(c, "vendedor", int(t * 2.5) % 2, dx, 0.0)
				if absf(S.px - dx) < 9.0:
					_balao(c, tela(dx - 0.5, 2.3), "Olha o guarda-chuva!", Color("#1f6fbf"))
			"painel":
				_painel(c, dx, 4.2, d.get("ultima", false))
			"pastel":
				obj(c, "pastel", dx, 0.0, 0, Color("#f0ece6"), 4.2)
			"freeshop":
				obj(c, "freeshop", dx - 1.9, 0.0, 0, Color("#ece8e2"), 3.6)
				obj(c, "freeshop", dx + 1.9, 0.0, 0, Color("#ece8e2"), 3.6)
			"portao":
				obj(c, "portao", dx + 0.8, 0.0, 0, Color.WHITE, 3.4)
				_texto(c, tela(dx + 0.8, 3.15), "PORTÃO 218", 30, Color("#fcc352"), true)
			"aviao":
				pass
			"detector":
				obj(c, "detector", dx, 0.0, 0, Color.WHITE, 1.3)
				var alarme := false
				for p in S.perigos:
					if p["tipo"] == "detector" and absf(p["x"] - dx) < 1.0 and p["alarme"] > 0.0:
						alarme = true
				c.draw_circle(tela(dx, 2.62), 9.0, (Color("#ff3040") if int(t * 10.0) % 2 == 0 else Color("#550000")) if alarme else Color("#3fe07a"))
	# chão e lajes
	for ch in F["chao"]:
		var a2: float = maxf(ch["x0"], xa - 2.0)
		var b2: float = minf(minf(ch["x1"], xb + 2.0), float(F["fim"]) + 0.3)
		if b2 <= a2:
			continue
		var y2: float = ch["y"]
		var tipo2: String = secao_em((a2 + b2) / 2.0)["tipo"]
		var p0 := tela(a2, y2)
		var p1 := tela(b2, y2 - 0.42)
		if tipo2 == "trem":
			c.draw_rect(Rect2(p0, tela(b2, y2 - 0.8) - p0), Color("#a9b0b6"))
			c.draw_rect(Rect2(tela(a2, y2 + 0.45), tela(b2, y2) - tela(a2, y2 + 0.45)), Color("#cfd5da"))
			c.draw_line(tela(a2, y2 + 0.45), tela(b2, y2 + 0.45), TINTA, 3.0)
			c.draw_line(tela(a2, y2 - 0.8), tela(b2, y2 - 0.8), TINTA, 3.0)
			var pil := ceilf(a2 / 15.0) * 15.0
			while pil < b2:
				c.draw_rect(Rect2(tela(pil - 0.7, y2 - 0.8), Vector2(1.4 * PX, 16 * PX)), Color("#9aa1a8"))
				c.draw_rect(Rect2(tela(pil - 0.7, y2 - 0.8), Vector2(1.4 * PX, 16 * PX)), TINTA, false, 3.0)
				pil += 15.0
			continue
		var cor_piso: Color = {"marginal": Color("#8f8a80"), "estacionamento": Color("#7d838a"), "calcada": Color("#d9d6cf")}.get(tipo2, Color("#e3e8ec"))
		var nome_tex := "calcada" if tipo2 == "calcada" else ("piso" if tipo2 in ["checkin", "subsolo", "seguranca", "embarque"] or y2 < -1.0 else "")
		if nome_tex != "":
			var tx: Texture2D = T[nome_tex]
			var sk := float(tx.get_width()) / 2.0
			c.draw_texture_rect_region(tx, Rect2(p0, p1 - p0), Rect2(a2 * sk, 0, (b2 - a2) * sk, tx.get_height()), Color("#c9ced3") if y2 < -1.0 else Color.WHITE)
		else:
			c.draw_rect(Rect2(p0, p1 - p0), cor_piso)
			if tipo2 == "estacionamento":
				var fx := ceilf(a2 / 4.0) * 4.0
				while fx < b2:
					c.draw_rect(Rect2(tela(fx, y2 - 0.12), Vector2(1.6 * PX, 0.12 * PX)), Color("#f2c230"))
					fx += 4.0
		var f0 := tela(a2, y2 - 0.42)
		var f1 := tela(b2, y2 - 0.62)
		var cor_borda := Color("#f2c230") if tipo2 in ["calcada", "marginal", "estacionamento"] else Color("#0d5a33")
		c.draw_rect(Rect2(f0, f1 - f0), cor_borda)
		c.draw_line(tela(a2, y2), tela(b2, y2), TINTA, 3.0)
		c.draw_line(f0, Vector2(f1.x, f0.y), TINTA, 3.0)
		c.draw_line(Vector2(f0.x, f1.y), f1, TINTA, 3.0)
		if tipo2 == "finger":
			continue
		if y2 > -1.0:
			# fundação (onde não há área de baixo)
			var fx2 := a2
			while fx2 < b2:
				var fx3 := minf(b2, fx2 + 0.5)
				if _baixo_em((fx2 + fx3) / 2.0) > 50.0:
					c.draw_rect(Rect2(tela(fx2, y2 - 0.62), Vector2((fx3 - fx2) * PX + 1.0, 9.0 * PX)), Color("#3b4248"))
				fx2 = fx3
	# alçapões: tampas abertas nas bordas dos buracos
	for al in F.get("alcapoes", []):
		if al.get("grande", false):
			continue
		for par in [[al["x0"], al["x1"]], [al["x2"], al["x3"]]]:
			var a3: float = par[0]
			var b3: float = par[1]
			if b3 < xa or a3 > xb:
				continue
			for lado_x in [a3, b3]:
				var pivo := tela(lado_x, 0.0)
				var ponta := pivo + Vector2(0, 1.25 * PX)
				c.draw_line(pivo, ponta, TINTA, 16.0)
				c.draw_line(pivo, ponta, Color("#8a939b"), 10.0)
				for k2 in 3:
					var yy := pivo.y + 10.0 + k2 * 28.0
					c.draw_line(Vector2(pivo.x - 4, yy), Vector2(pivo.x + 4, yy + 10), Color("#f2c230"), 4.0)
	# mezanino
	for p in F["plataformas"]:
		var a4: float = p["x0"]
		var b4: float = p["x1"]
		if b4 < xa or a4 > xb:
			continue
		var y4: float = p["y"]
		c.draw_rect(Rect2(tela(a4, y4 + 0.95), tela(b4, y4) - tela(a4, y4 + 0.95)), Color(0.68, 0.85, 0.9, 0.35))
		c.draw_line(tela(a4, y4 + 0.95), tela(b4, y4 + 0.95), Color("#7c8a96"), 5.0)
		c.draw_rect(Rect2(tela(a4, y4), tela(b4, y4 - 0.3) - tela(a4, y4)), Color("#d9dee3"))
		c.draw_rect(Rect2(tela(a4, y4), tela(b4, y4 - 0.3) - tela(a4, y4)), TINTA, false, 3.0)
		var px_ := a4 + 1.0
		while px_ < b4:
			c.draw_rect(Rect2(tela(px_ - 0.08, y4 - 0.3), Vector2(0.16 * PX, (y4 - 0.3) * PX)), Color("#aab4bd"))
			px_ += 6.0
	# esteiras e piso molhado
	for z in F["zonas"]:
		var a5: float = z["x0"]
		var b5: float = z["x1"]
		if b5 < xa or a5 > xb:
			continue
		var y5: float = z.get("y", 0.0)
		if z["tipo"] == "esteira":
			var te: Texture2D = T["esteira"]
			var e0 := tela(a5, y5 + 0.02)
			var e1 := tela(b5, y5 - 0.3)
			var off := fmod(t * float(z["boost"]) * 132.0, 132.0)
			c.draw_texture_rect_region(te, Rect2(e0, e1 - e0), Rect2(-off, 0, (b5 - a5) * 132.0, 40))
			c.draw_rect(Rect2(e0, e1 - e0), TINTA, false, 3.0)
		elif z["tipo"] == "molhado":
			c.draw_rect(Rect2(tela(a5, y5 + 0.03), tela(b5, y5 - 0.25) - tela(a5, y5 + 0.03)), Color(0.62, 0.85, 1.0, 0.55))
			for i in 4:
				var bx := a5 + (b5 - a5) * (i + 0.5) / 4.0
				c.draw_line(tela(bx - 0.5, y5 - 0.12), tela(bx + 0.2, y5 - 0.12), Color(1, 1, 1, 0.8), 3.0)
			obj(c, "cavalete", a5 - 1.0, 0.0, 0, Color.WHITE, 0.6)
	# portas automáticas
	for d2 in S.portas:
		var dxp: float = d2["x"]
		if absf(dxp - cam_x) > 10.0:
			continue
		var aberta := S.porta_aberta(d2, S.t)
		obj(c, "porta_aberta" if aberta else "porta", dxp, 0.0, 0, Color.WHITE, 3.2)
		_texto(c, tela(dxp, 2.75), "ENTRADA", 26, Color("#fcc352"), true)
		if not aberta:
			c.draw_rect(Rect2(tela(dxp - 0.08, 2.5), Vector2(0.16 * PX, 2.5 * PX)), Color(0.75, 0.9, 1.0, 0.25))
	# objetos sólidos
	for s2 in S.solidos:
		var sx: float = s2["x"]
		if sx < xa - 4.0 or sx > xb + 4.0:
			continue
		var mod := Color(1, 1, 1, 0.55) if s2["fantasma"] else Color.WHITE
		match s2["tipo"]:
			"mala":
				obj(c, "mala", sx, s2["y"], 0, Color(s2.get("cor", "#c0392b")).lightened(0.15) * Color(1, 1, 1, mod.a), float(s2["w"]))
			"escada":
				var esp: bool = s2.get("contra", false)
				obj(c, "escada", sx, s2["y"], 0, Color("#ffe0d0") if esp else Color.WHITE, float(s2["w"]) * 1.03)
				var seta := "▼" if esp else "▲"
				for k3 in 3:
					var fr := fposmod(t * (0.5 if not esp else -0.5) + k3 / 3.0, 1.0)
					var sxp: float = float(s2["x0"]) + fr * float(s2["w"])
					_texto(c, tela(sxp, float(s2["h"]) * fr + 0.6), seta, 26, Color("#f2c230") if not esp else Color("#ff6b6b"), true)
			"cone":
				obj(c, "cone", sx, s2["y"], 0, mod, 0.6, false, -0.25)
			"fita":
				if float(s2["d"]) > 3.0:
					obj(c, "fita", sx, s2["y"], 0, mod, float(s2["w"]))
			"balcao", "carrinho", "raiox", "bandeja", "banco":
				obj(c, s2["tipo"], sx, s2["y"], 0, mod, float(s2["w"]) * (1.05 if s2["tipo"] == "raiox" else 1.0))
	if monitor_t > 0.0:
		obj(c, "monitor_raiox", monitor_x, 1.8, 0, Color(1, 1, 1, minf(1.0, monitor_t * 2.0)), 1.6)
		_texto(c, tela(monitor_x, 3.5), "Raio-x: é um robô!", 26, Color.WHITE, true)
	for m in S.molas:
		if absf(m["x"] - cam_x) < 9.0:
			obj(c, "mola", m["x"], m["y"], 0, Color.WHITE, 1.4, false, 0.0, 0.7 if m["anim"] > 0.2 else 1.0)
	for p2 in S.perigos:
		var ppx: float = p2["x"]
		if ppx < xa - 3.0 or ppx > xb + 3.0 or p2["z"] != 0.0:
			continue
		match p2["tipo"]:
			"placa":
				var y0: float = p2["y0"]
				var topo_y := 8.6
				var sp: String = secao_em(ppx)["tipo"]
				if sp in ["calcada", "marginal"]:
					topo_y = 6.0
				elif sp == "finger":
					topo_y = 3.4
				var larg: float = float(p2["w"]) + 0.2
				obj(c, "placa", ppx, y0, 0, Color.WHITE, larg)
				var alto_placa: float = larg * 0.735
				for dx2 in [-0.36, 0.36]:
					c.draw_line(tela(ppx + dx2 * larg, y0 + alto_placa), tela(ppx + dx2 * larg, topo_y), Color("#4a4f55"), 3.0)
				_texto(c, tela(ppx, y0 + alto_placa * 0.36), p2.get("texto", ""), 22, Color.WHITE, true, larg * PX * 0.82)
			"pessoa":
				var q := 4 if p2["morto"] > 0.0 else int(t * 7.0 + p2["x0i"]) % 4
				pers(c, "passageiro%d" % int(p2.get("var", 0)), q, ppx, p2["y0"])
			"mala_rolando":
				if not p2["usado"] or p2["morto"] == 0.0:
					obj(c, "mala", ppx, p2["y0"], 0, Color("#5dade2"), 0.6, false, -t * 9.0 if p2["ativo"] else 0.0)
	# moedas (milhas), cartão, itens, mala dourada
	for mi in S.milhas:
		var mx: float = mi["x"]
		if mx < xa - 1.0 or mx > xb + 1.0 or mi["z"] != 0.0:
			continue
		if mi["pega"]:
			if mi["anim"] < 1.0:
				obj(c, "milha", mx, mi["y"] - 0.36 + mi["anim"] * 1.2, 0, Color(1, 1, 1, 1.0 - mi["anim"]), 0.62)
			continue
		var giro := absf(cos(t * 3.5 + mx * 0.7))
		obj(c, "milha", mx, mi["y"] - 0.36 + sin(t * 3.0 + mx) * 0.05, 0, Color.WHITE, 0.62 * maxf(0.15, giro))
	for ci in S.cartoes.size():
		var ca: Dictionary = S.cartoes[ci]
		if ca["z"] != 0.0 or absf(ca["x"] - cam_x) > 8.0 or (ca["pega"] and ca["anim"] >= 1.0):
			continue
		var subida: float = ca["anim"] * 1.5
		c.draw_circle(tela(ca["x"], ca["y"] + 0.05 + subida), 30.0 + sin(t * 5.0) * 4.0, Color(1, 0.95, 0.6, 0.35 * (1.0 - ca["anim"])))
		obj(c, "cartao", ca["x"], ca["y"] - 0.35 + sin(t * 3.0) * 0.08 + subida, ci, Color(1, 1, 1, 1.0 - ca["anim"]), 0.55)
	for it in S.itens:
		if not it["pega"] and absf(it["x"] - cam_x) < 8.0:
			c.draw_circle(tela(it["x"], it["y"] + 0.1), 36.0, Color(1, 1, 1, 0.3))
			obj(c, "guarda_chuva", it["x"], it["y"] - 0.5 + sin(t * 3.0) * 0.1, 1, Color.WHITE, 1.0)
	if not S.mala.is_empty() and not S.mala["pega"]:
		obj(c, "mala_dourada", S.mala["x"], S.mala["y"] - 0.35 + sin(t * 3.0) * 0.08, 0, Color.WHITE, 0.8)
	_perseguidores(c)
	_projeteis(c)
	_desenhar_mascote(c)
	var sec := secao_em(S.px)
	if sec["tipo"] in ["marginal", "estacionamento", "calcada", "trem", "finger"]:
		_garoa(c, 1.0 if sec["tipo"] != "estacionamento" else 0.25)


func _parede(c: CanvasItem, nome: String, a: float, b: float, y_base: float, alt_m: float, sx0: float, sx1: float, teto := true) -> void:
	var tex: Texture2D = T[nome]
	var topo := tela(0, y_base + alt_m).y
	var base := tela(0, y_base).y
	if teto:
		c.draw_rect(Rect2(sx0, 0, sx1 - sx0, topo + 2), Color("#e9eef2"))
	c.draw_line(Vector2(sx0, topo), Vector2(sx1, topo), Color("#9aa6b1"), 4.0)
	ladrilhar(c, tex, sx0, sx1, -cam_x * PX * 0.9, topo, base - topo)


func _painel(c: CanvasItem, x: float, y: float, ultima: bool) -> void:
	obj(c, "painel", x, y, 0, Color.WHITE, 4.2)
	var esq := tela(x - 1.75, y + 2.25)
	_texto(c, esq + Vector2(0, 0), "PARTIDAS · DEPARTURES", 22, Color("#ffd24d"))
	for i in 4:
		var v: Array = VOOS[i]
		var yy := esq.y + 34.0 + i * 30.0
		_texto(c, Vector2(esq.x, yy), v[0], 19, Color("#e8e8e8"))
		_texto(c, Vector2(esq.x + 92, yy), v[1], 19, Color("#e8e8e8"))
		var st := "EMBARQUE" if i == 0 else ("NO HORÁRIO" if i < 3 else "ATRASADO")
		var cor := Color("#3fe07a") if i == 0 else Color("#9fb3c8")
		if i == 0 and ultima:
			var s := int(ceil(S.tempo))
			st = "FECHA %d:%02d" % [s / 60, s % 60]
			cor = Color("#ff3b4d") if int(t * 3.0) % 2 == 0 else Color("#ff9aa5")
		_texto(c, Vector2(esq.x + 196, yy), st, 19, cor)


func _texto(c: CanvasItem, p: Vector2, s: String, tam: int, cor: Color, centro := false, larg_max := 0.0) -> void:
	if s == "":
		return
	var tamanho := tam
	var w := fonte.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, tamanho).x
	if larg_max > 0.0 and w > larg_max:
		tamanho = maxi(10, int(tamanho * larg_max / w))
		w = fonte.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, tamanho).x
	var pos := p - Vector2(w * 0.5, -tamanho * 0.35) if centro else p
	c.draw_string_outline(fonte, pos, s, HORIZONTAL_ALIGNMENT_LEFT, -1, tamanho, 5, TINTA)
	c.draw_string(fonte, pos, s, HORIZONTAL_ALIGNMENT_LEFT, -1, tamanho, cor)


func _balao(c: CanvasItem, p: Vector2, s: String, cor: Color) -> void:
	var w := fonte.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, 28).x + 28.0
	var r := Rect2(p - Vector2(w * 0.5, 30), Vector2(w, 46))
	c.draw_rect(r, Color.WHITE)
	c.draw_rect(r, cor, false, 4.0)
	c.draw_colored_polygon(PackedVector2Array([p + Vector2(-10, 16), p + Vector2(10, 16), p + Vector2(-4, 34)]), Color.WHITE)
	c.draw_string(fonte, r.position + Vector2(14, 34), s, HORIZONTAL_ALIGNMENT_LEFT, -1, 28, cor)


func _perseguidores(c: CanvasItem) -> void:
	if S.px < float(F.get("guarda_entra", 0.0)) or S.intro > 0.0:
		return
	var gd: float = clampf(S.guarda, 0.0, 20.0)
	var gx := S.px - 0.9 - gd * 0.15
	var grupo := [["guarda", 0.0, 6, 12.0]]
	if entraram.has("atendente"):
		grupo.append(["atendente", -0.8, 6, 11.0])
	if entraram.has("cao"):
		grupo.append(["cao", -1.5, 5, 14.0])
	if entraram.has("patio"):
		grupo.append(["patio", -2.2, 5, 10.0])
	for i in range(grupo.size() - 1, -1, -1):
		var g: Array = grupo[i]
		var x: float = gx + float(g[1])
		if tela(x, 0).x < -120.0:
			continue
		var sg = S.suporte(x, 0.0, S.py + 3.0)
		var y: float = sg["y"] if sg != null else S.py
		var quadros: int = int(META[g[0]]["quadros"])
		pers(c, g[0], int(t * float(g[3])) % (quadros if g[0] != "cao" else 4), x, y)
	if gd < 4.0:
		var sg2 = S.suporte(gx, 0.0, S.py + 3.0)
		_balao(c, tela(gx + 0.5, (sg2["y"] if sg2 != null else S.py) + 2.6), "EI! VOLTA AQUI!", Color("#c0392b"))


func _projeteis(c: CanvasItem) -> void:
	for p in S.projeteis:
		if p["usado"] and p["t"] > 2.0:
			continue
		var x: float = p["x"]
		var ym: float = (float(p["y0"]) + float(p["y1"])) * 0.5
		var sxp := tela(x, ym)
		if sxp.x < 30.0 and not p["usado"]:
			# aviso "!" na beirada da tela
			var pisca := 1.0 if int(t * 8.0) % 2 == 0 else 0.6
			c.draw_circle(Vector2(46, sxp.y), 30.0, Color(0.9, 0.1, 0.15, pisca))
			c.draw_circle(Vector2(46, sxp.y), 30.0, Color.WHITE, false, 4.0)
			_texto(c, Vector2(46, sxp.y), "!", 40, Color.WHITE, true)
			continue
		match p["tipo"]:
			"etiqueta":
				obj(c, "etiqueta", x, p["y0"], 0, Color.WHITE, 0.55, false, t * 14.0)
			"cao":
				pers(c, "cao", 4, x, p["y0"])
			_:
				obj(c, "cone", x, p["y0"], 0, Color.WHITE, 0.55, false, t * 12.0)


func _desenhar_mascote(c: CanvasItem) -> void:
	if S.invuln > 0.0 and int(t * 14.0) % 2 == 0 and estado == "jogo":
		return
	if S.intro > 1.6:
		return  # ainda dentro do táxi
	var x := S.px
	var y := S.py
	if S.intro > 0.0:
		x = lerpf(1.3, S.px, clampf((1.6 - S.intro) / 0.6, 0.0, 1.0))
		pers(c, "m_acoes", POSES["sobe"] if S.intro > 1.1 else POSES["dash"], x, y)
		return
	if estado == "final":
		if t_final < 0.7:
			pers(c, "m_corre", int(fase_anim) % 6, x, y)
		var fx := float(F["fim"])
		var k := clampf((t_final - 0.55) / 0.4, 0.0, 1.0)
		if k > 0.0:
			var r := Rect2(tela(fx, 2.15), Vector2(1.05 * PX * k, 2.15 * PX))
			c.draw_rect(r, Color("#e9edf0"))
			c.draw_rect(r, TINTA, false, 4.0)
			if k >= 1.0:
				_balao(c, tela(fx + 0.5, 3.0), "TUM!", Color("#c0392b"))
		return
	if S.montado:
		pers(c, "m_carrinho", int(t * 8.0) % 2, x, y)
		return
	if S.rolar_t > 0.0 and S.no_chao:
		pers(c, "m_acoes", POSES["bola"], x, y, Color.WHITE, false, 1.0, t * 16.0)
		return
	if S.fim == "venceu":
		pers(c, "m_acoes", POSES["vitoria"], x, y)
		return
	if S.tropeco_t > 0.0:
		pers(c, "m_acoes", POSES["tropeca"], x, y)
		return
	if not S.no_chao:
		if S.planando and S.guarda_chuva_t > 0.0:
			pers(c, "m_acoes", POSES["sobe"], x, y)
			obj(c, "guarda_chuva", x + 0.05, y + 1.75, 1, Color.WHITE, 1.4)
			return
		if S.planando:
			pers(c, "m_acoes", POSES["plana"], x, y)
			return
		pers(c, "m_acoes", POSES["sobe"] if S.vy > 0.0 else POSES["cai"], x, y)
		return
	if S.dash_t > 0.0:
		pers(c, "m_acoes", POSES["dash"], x, y)
		return
	pers(c, "m_corre", int(fase_anim) % 6, x, y)
	if S.guarda_chuva_t > 0.0:
		obj(c, "guarda_chuva", x - 0.35, y + 0.55, 0, Color.WHITE, 0.9, false, -0.6)


func _garoa(c: CanvasItem, forca: float) -> void:
	var cor := Color(0.9, 0.94, 0.97, minf(0.75, 0.42 * forca))
	var n := int(gotas.size() * minf(1.0, 0.5 * forca + 0.2))
	for i in n:
		var g: Vector2 = gotas[i]
		var y := fposmod(g.y + t * 900.0 * (1.0 + 0.3 * (forca - 1.0)), H)
		var x := fposmod(g.x - t * 120.0 * forca, W)
		c.draw_line(Vector2(x, y), Vector2(x - 5 * forca, y + 26), cor, 2.0)
	if raio_t > 0.0:
		c.draw_rect(Rect2(0, 0, W, H), Color(1, 1, 1, raio_t * 2.0))


# ------------------------------------------------------------------ visão de trás (pseudo-3D)
func _proj(x: float, y: float, z: float):
	var cx := S.px - DIST_TRAS
	var d := x - cx
	if d < 0.6:
		return null
	var cy := cam_chao + ALT_TRAS
	var cz := S.pz * 0.55
	return Vector3(W * 0.5 + (z - cz) * FOCO / d, H * HZ + (cy - y) * FOCO / d, FOCO / d)


func _neblina(d: float) -> Color:
	var k := clampf((d - 25.0) / 70.0, 0.0, 0.8)
	return Color(1, 1, 1).lerp(Color("#b9c5cf"), k)


func _quad(c: CanvasItem, pts: Array, cor: Color, contorno := true) -> void:
	var arr := PackedVector2Array()
	for p in pts:
		if p == null:
			return
		arr.append(Vector2(p.x, p.y))
	c.draw_colored_polygon(arr, cor)
	if contorno:
		arr.append(arr[0])
		c.draw_polyline(arr, TINTA, 3.0)


## Objeto em perspectiva: centro em (x, z), base em y; largura_m encaixa a largura desenhada.
func _spr3(c: CanvasItem, nome: String, x: float, y: float, z: float, quadro := 0, mod := Color.WHITE, largura_m := 0.0, esc_y := 1.0) -> void:
	var p = _proj(x, y, z)
	if p == null or not T.has(nome):
		return
	var tex: Texture2D = T[nome]
	var m: Dictionary = META[nome]
	var q: int = int(m.get("quadros", 1))
	var fw := float(tex.get_width()) / q
	var fh := float(tex.get_height())
	var mg := _margem(nome)
	var k: float = p.z / float(m["pxm"])
	if largura_m > 0.0:
		k = largura_m * p.z / maxf(1.0, fw - 2.0 * mg)
	c.draw_set_transform(Vector2(p.x, p.y), 0.0, Vector2(k, k * esc_y))
	c.draw_texture_rect_region(tex, Rect2(-fw * 0.5, -(fh - mg), fw, fh), Rect2((quadro % q) * fw, 0, fw, fh), mod * _neblina(x - S.px))
	c.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _desenhar_tras(c: CanvasItem) -> void:
	var sec: String = secao_em(S.px)["tipo"]
	var hz := H * HZ
	var perto := S.px - DIST_TRAS + 0.7
	var longe := S.px + 120.0
	if sec == "trem":
		var tex: Texture2D = T["frente_trem"]
		var k := 1.75
		var fuga: Array = META["frente_trem"]["fuga"]
		var tw := tex.get_width() * k
		var th := tex.get_height() * k
		var ox := W * 0.5 - tw * float(fuga[0]) - S.pz * 8.0
		var oy := hz - th * float(fuga[1])
		c.draw_rect(Rect2(0, 0, W, H), Color("#7f8b97"))
		c.draw_texture_rect(tex, Rect2(ox, oy, tw, th), false)
		c.draw_rect(Rect2(0, oy + th, W, H), Color("#4f7a3e"))
		# trilho elevado
		_quad(c, [_proj(perto, 0, -3.3), _proj(longe, 0, -3.3), _proj(longe, 0, 3.3), _proj(perto, 0, 3.3)], Color("#a9b0b6"), false)
		_quad(c, [_proj(perto, 0, -3.3), _proj(longe, 0, -3.3), _proj(longe, -0.8, -3.3), _proj(perto, -0.8, -3.3)], Color("#7f878e"), false)
		_quad(c, [_proj(perto, 0, 3.3), _proj(longe, 0, 3.3), _proj(longe, -0.8, 3.3), _proj(perto, -0.8, 3.3)], Color("#7f878e"), false)
		var d0 := ceilf(perto / 2.0) * 2.0
		var xd := longe
		while xd > d0:
			xd -= 2.0
			var a = _proj(xd, 0.01, -3.0)
			var b = _proj(xd, 0.01, 3.0)
			if a != null and b != null:
				c.draw_line(Vector2(a.x, a.y), Vector2(b.x, b.y), Color(0.45, 0.48, 0.52, 0.55), maxf(1.0, a.z * 0.06))
		for zz in [-Regras.FAIXA, 0.0, Regras.FAIXA]:
			for dz in [-0.45, 0.45]:
				var a2 = _proj(perto, 0.02, zz + dz)
				var b2 = _proj(longe, 0.02, zz + dz)
				c.draw_line(Vector2(a2.x, a2.y), Vector2(b2.x, b2.y), Color("#4f555b"), 5.0)
		for zz in [-3.35, 3.35]:
			_quad(c, [_proj(perto, 0, zz), _proj(longe, 0, zz), _proj(longe, 0.45, zz), _proj(perto, 0.45, zz)], Color("#cfd5da"))
	else:
		# fila do check-in vista de trás: piso, parede do fundo e teto
		var cor_parede: Color = COR_TOPO.get("parede_checkin", Color("#e3e8ec"))
		c.draw_rect(Rect2(0, 0, W, H), cor_parede)
		var texp: Texture2D = T["parede_checkin"]
		var hp := 330.0
		var wp := texp.get_width() * hp / texp.get_height()
		ladrilhar(c, texp, 0, W, -S.px * 6.0, hz - hp + 20.0, hp)
		c.draw_rect(Rect2(0, 0, W, hz - hp + 22.0), Color("#eef2f5"))
		var piso := [_proj(perto, 0, -6.0), _proj(longe, 0, -6.0), _proj(longe, 0, 6.0), _proj(perto, 0, 6.0)]
		_quad(c, piso, Color("#dfe4e8"), false)
		var xl := ceilf(perto / 1.5) * 1.5
		while xl < S.px + 60.0:
			var a3 = _proj(xl, 0.01, -6.0)
			var b3 = _proj(xl, 0.01, 6.0)
			if a3 != null and b3 != null:
				c.draw_line(Vector2(a3.x, a3.y), Vector2(b3.x, b3.y), Color("#c9d1d8"), maxf(1.0, a3.z * 0.03))
			xl += 1.5
		for zl in [-6.0, -3.0, 0.0, 3.0, 6.0]:
			var a4 = _proj(perto, 0.01, zl)
			var b4 = _proj(longe, 0.01, zl)
			c.draw_line(Vector2(a4.x, a4.y), Vector2(b4.x, b4.y), Color("#c9d1d8"), 2.0)
	# objetos de longe para perto
	var itens: Array = []
	for s in S.solidos:
		if s["d"] < 3.0 and s["x1"] > perto and s["x0"] < longe:
			itens.append([s["x0"], "s", s])
	for p in S.perigos:
		if p["z"] != 0.0 or p["tipo"] == "trem":
			if p["d"] < 3.0 and p["x"] + p["w"] / 2.0 > perto and p["x"] - p["w"] / 2.0 < longe:
				itens.append([p["x"] - p["w"] / 2.0, "p", p])
	for pc in S.pocas:
		if pc["x"] > perto and pc["x"] < longe:
			itens.append([pc["x"] + 0.5, "poca", pc])
	for m in S.milhas:
		if not m["pega"] and m["x"] > perto + 0.5 and m["x"] < S.px + 70.0 and S.na_zona_tras(m["x"]):
			itens.append([m["x"], "m", m])
	for ci in S.cartoes.size():
		var ca: Dictionary = S.cartoes[ci]
		if not ca["pega"] and ca["x"] > perto + 0.5 and ca["x"] < S.px + 70.0 and S.na_zona_tras(ca["x"]):
			itens.append([ca["x"], "c", ci])
	itens.append([S.px, "eu", null])
	itens.sort_custom(func(a, b): return a[0] > b[0])
	for it in itens:
		match it[1]:
			"s":
				_caixa3(c, it[2], it[2]["tipo"])
			"p":
				var p2: Dictionary = it[2]
				if p2["tipo"] == "trem":
					_caixa3(c, p2, "trem")
				else:
					_spr3(c, "placa_pare", p2["x"], 0.0, p2["z"], 0, Color.WHITE, 1.9)
					var pp = _proj(p2["x"], 2.55, p2["z"])
					if pp != null:
						_texto(c, Vector2(pp.x, pp.y), "ABAIXE!", int(maxf(10, pp.z * 0.33)), Color.WHITE, true)
			"poca":
				var pc2: Dictionary = it[2]
				_spr3(c, "poca", pc2["x"], 0.0, pc2["z"], 0, Color(1, 1, 1, 0.4 if pc2["usada"] else 0.95), 1.7, 0.6)
			"m":
				var m2: Dictionary = it[2]
				var giro := absf(cos(t * 3.5 + m2["x"] * 0.7))
				_spr3(c, "milha", m2["x"], m2["y"] - 0.36, m2["z"], 0, Color.WHITE, 0.62 * maxf(0.15, giro))
			"c":
				var ca2: Dictionary = S.cartoes[it[2]]
				_spr3(c, "cartao", ca2["x"], ca2["y"] - 0.35, ca2["z"], it[2], Color.WHITE, 0.6)
			"eu":
				_mascote_costas(c)
	if sec == "trem":
		_garoa(c, 2.2)


func _caixa3(c: CanvasItem, s: Dictionary, tipo: String) -> void:
	var x0: float = s["x0"] if s.has("x0") else float(s["x"]) - float(s["w"]) / 2.0
	var x1: float = s["x1"] if s.has("x1") else float(s["x"]) + float(s["w"]) / 2.0
	var z: float = s["z"]
	var hd: float = float(s["d"]) / 2.0
	var h: float = s["h"] if s.has("h") else s["y1"]
	var perto := S.px - DIST_TRAS + 0.7
	var xa := maxf(x0, perto)
	if tipo == "barreira":
		_spr3(c, "barreira_f", x0, 0.0, z, 0, Color.WHITE, 1.5)
		return
	if tipo == "fita":
		_spr3(c, "fita", x0, 0.0, z, 0, Color.WHITE, 1.5)
		return
	var nb := _neblina(x0 - S.px)
	if x0 < S.px - 0.5 and absf(z - S.pz) > 0.5:
		nb.a = 0.35
	var corpo := Color("#f6f7f8")
	_quad(c, [_proj(xa, 0, z - hd), _proj(x1, 0, z - hd), _proj(x1, h, z - hd), _proj(xa, h, z - hd)], Color("#c9d0d6") * nb)
	_quad(c, [_proj(xa, 0, z + hd), _proj(x1, 0, z + hd), _proj(x1, h, z + hd), _proj(xa, h, z + hd)], Color("#c9d0d6") * nb)
	_quad(c, [_proj(xa, h, z - hd), _proj(x1, h, z - hd), _proj(x1, h, z + hd), _proj(xa, h, z + hd)], corpo * nb)
	for lado_z in [z - hd, z + hd]:
		_quad(c, [_proj(xa, h * 0.36, lado_z), _proj(x1, h * 0.36, lado_z), _proj(x1, h * 0.42, lado_z), _proj(xa, h * 0.42, lado_z)], Color(F["cia"]["cor2"]) * nb, false)
	if x0 >= perto:
		_spr3(c, "trem_f" if tipo == "trem" else "vagao_f", x0, 0.0, z, 0, nb, 1.7)
	var rampa: float = s.get("rampa", 0.0)
	if rampa > 0.0:
		_quad(c, [_proj(maxf(x0 - 0.01, perto), 0.02, z - hd * 0.9), _proj(maxf(x0 - 0.01, perto), 0.02, z + hd * 0.9), _proj(x0 + rampa, h, z + hd * 0.9), _proj(x0 + rampa, h, z - hd * 0.9)], Color("#f39c12") * nb)
		var k3 := 0.0
		while k3 < 1.0:
			var a = _proj(x0 + rampa * k3, h * k3 + 0.02, z - hd * 0.9)
			var b = _proj(x0 + rampa * k3, h * k3 + 0.02, z + hd * 0.9)
			if a != null and b != null:
				c.draw_line(Vector2(a.x, a.y), Vector2(b.x, b.y), Color("#b0650c"), 2.0)
			k3 += 0.125


func _mascote_costas(c: CanvasItem) -> void:
	if S.invuln > 0.0 and int(t * 14.0) % 2 == 0:
		return
	var p = _proj(S.px, S.py, S.pz)
	if p == null:
		return
	var m: Dictionary = META["m_costas"]
	var k: float = p.z / float(m["pxm"])
	var ch = S.suporte(S.px, S.pz, S.py + 0.1)
	if ch != null:
		var sp = _proj(S.px, ch["y"], S.pz)
		if sp != null:
			c.draw_set_transform(Vector2(sp.x, sp.y), 0.0, Vector2(1, 0.3))
			c.draw_circle(Vector2.ZERO, 0.4 * sp.z, Color(0, 0, 0, 0.25))
			c.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	if S.rolar_t > 0.0 and S.no_chao:
		var ma: Dictionary = META["m_acoes"]
		var ka: float = p.z / float(ma["pxm"])
		c.draw_set_transform(Vector2(p.x, p.y - 0.55 * p.z), t * 16.0, Vector2(ka, ka))
		c.draw_texture_rect_region(T["m_acoes"], Rect2(-float(ma["qw"]) * 0.5, -float(ma["qh"]) * 0.62, float(ma["qw"]), float(ma["qh"])), Rect2(POSES["bola"] * float(ma["qw"]), 0, float(ma["qw"]), float(ma["qh"])))
		c.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		return
	var q := 4 if not S.no_chao else int(fase_anim * 0.6) % 4
	var pe: Array = m["pe"]
	c.draw_set_transform(Vector2(p.x, p.y), 0.0, Vector2(k, k))
	c.draw_texture_rect_region(T["m_costas"], Rect2(-float(pe[0]), -float(pe[1]), float(m["qw"]), float(m["qh"])), Rect2(q * float(m["qw"]), 0, float(m["qw"]), float(m["qh"])))
	c.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


# ------------------------------------------------------------------ final: decolagem e mapa
func _comecar_final(tipo: String) -> void:
	fim_tipo = tipo
	if tipo != "venceu":
		estado = "fim"
		som("derrota")
		if bot and fotos.is_empty():
			print("RESULTADO ", tipo, " milhas=", S.n_milhas)
		await get_tree().create_timer(0.9).timeout
		_mostrar_resultado()
		return
	estado = "final"
	t_final = 0.0
	hud.visible = false
	som("vitoria")
	get_tree().create_timer(0.8).timeout.connect(func(): som("porta"))
	if bot and fotos.is_empty():
		print("RESULTADO ", tipo, " milhas=", S.n_milhas)
	get_tree().create_timer(1.3).timeout.connect(func(): som("aviao"))


func _desenhar_final(c: CanvasItem) -> void:
	var tf := t_final
	if tf < 3.8:
		# decolagem
		c.draw_rect(Rect2(0, 0, W, H), Color("#9aa9b6"))
		var tex: Texture2D = T["ceu_sp"]
		ladrilhar(c, tex, 0, W, -tf * 60.0, H * 0.35, H * 0.65)
		c.draw_rect(Rect2(0, H * 0.93, W, H * 0.07), Color("#4a4f55"))
		var k := clampf((tf - 1.4) / 2.4, 0.0, 1.0)
		var pos := Vector2(lerpf(-120.0, W + 380.0, k), lerpf(H * 0.78, H * 0.22, k * k))
		var av: Texture2D = T["aviao_decola"]
		var aw := 640.0
		var ah := aw * av.get_height() / av.get_width()
		c.draw_texture_rect(av, Rect2(pos - Vector2(aw * 0.5, ah * 0.5), Vector2(aw, ah)), false)
		_texto(c, Vector2(W * 0.5, H * 0.16), "PLUS 218 DECOLOU!", 52, Color("#fcc352"), true)
		_garoa(c, 0.6)
	else:
		# mapa com a rota
		c.draw_rect(Rect2(0, 0, W, H), Color("#0b3d22"))
		var mp: Texture2D = T["mapa"]
		var mw := 600.0
		var mh := mw * mp.get_height() / mp.get_width()
		var k2 := clampf((tf - 3.8) / 0.6, 0.0, 1.0)
		c.draw_texture_rect(mp, Rect2(Vector2(W * 0.5 - mw * 0.5, H * 0.24 + (1.0 - k2) * 60.0), Vector2(mw, mh)), false, Color(1, 1, 1, k2))
		_texto(c, Vector2(W * 0.5, H * 0.13), "GRU  →  MARINGÁ", 56, Color("#fcc352"), true)
		_texto(c, Vector2(W * 0.5, H * 0.19), "Próximo voo: Fase 2 · em breve", 30, Color.WHITE, true)
		_texto(c, Vector2(W * 0.5, H * 0.88), "Toque para continuar", 28, Color(1, 1, 1, 0.5 + 0.5 * sin(t * 4.0)), true)


func _mostrar_resultado() -> void:
	if estado == "fim_tela":
		return
	estado = "fim_tela"
	final_v.visible = false
	var tipo := fim_tipo
	var est := [tipo == "venceu", tipo == "venceu" and S.n_milhas >= int(F["alvo_milhas"]), tipo == "venceu" and S.achou_mala]
	var n := est.count(true)
	var cfg := ConfigFile.new()
	cfg.load("user://progresso.cfg")
	if tipo == "venceu":
		cfg.set_value("estrelas", F["id"], maxi(n, int(cfg.get_value("estrelas", F["id"], 0))))
		cfg.set_value("cartao", F["id"], maxi(S.n_cartao, int(cfg.get_value("cartao", F["id"], 0))))
		cfg.save("user://progresso.cfg")
	lbl_fim_titulo.text = {"venceu": "Embarcou!", "pego": "O guarda te pegou!", "voo": "Perdeu o voo!"}.get(tipo, "Fim")
	var e := ""
	for x in est:
		e += "★ " if x else "☆ "
	lbl_fim_estrelas.text = e.strip_edges()
	var usado := float(F["tempo"]) - S.tempo
	var linhas := [
		"%s  Chegou a tempo:  %s" % ["★" if est[0] else "☆", ("%d:%02d" % [int(usado) / 60, int(usado) % 60]) if tipo == "venceu" else "—"],
		"%s  Milhas %s:  %d de %d" % ["★" if est[1] else "☆", F["cia"]["nome"], S.n_milhas, int(F["alvo_milhas"])],
		"%s  Mala dourada:  %s" % ["★" if est[2] else "☆", "achou" if S.achou_mala else "escondida"],
		"Cartão de embarque:  %d de 5 pedaços" % S.n_cartao,
		"Tropeços:  %d" % S.tropecos,
	]
	lbl_fim_res.text = "\n".join(linhas)
	_mostrar_tela("fim")


# ------------------------------------------------------------------ entrada
func _unhandled_input(ev: InputEvent) -> void:
	if estado == "final" and ((ev is InputEventScreenTouch and ev.pressed) or (ev is InputEventKey and ev.pressed)):
		if t_final > 1.5:
			_mostrar_resultado()
		return
	if ev is InputEventScreenTouch:
		if estado != "jogo":
			return
		var tam := get_viewport().get_visible_rect().size
		if ev.pressed:
			if ev.position.y < tam.y * 0.11:
				return
			toque_ativo = true
			toque_ini = ev.position
			toque_t = relogio
			toque_feito = false
			if not S.no_chao:
				S.hold = true
		else:
			if toque_ativo and not toque_feito and relogio - toque_t < 0.26:
				S.acao("dash" if relogio - ultimo_tap < 0.3 else "cima")
				ultimo_tap = relogio
			toque_ativo = false
			S.hold = false
	elif ev is InputEventScreenDrag:
		if not toque_ativo or toque_feito:
			return
		var dlt: Vector2 = ev.position - toque_ini
		if dlt.length() > get_viewport().get_visible_rect().size.x * 0.06:
			toque_feito = true
			var dir := ""
			if absf(dlt.x) > absf(dlt.y):
				dir = "dir" if dlt.x > 0.0 else "esq"
			else:
				dir = "cima" if dlt.y < 0.0 else "baixo"
			S.acao(dir)
			S.hold = dir == "cima"
	elif ev is InputEventKey and not ev.echo:
		var k: Key = ev.physical_keycode
		var mapa := {KEY_UP: "cima", KEY_W: "cima", KEY_SPACE: "cima", KEY_DOWN: "baixo", KEY_S: "baixo",
			KEY_RIGHT: "dir", KEY_D: "dir", KEY_LEFT: "esq", KEY_A: "esq", KEY_SHIFT: "dash", KEY_X: "dash"}
		if ev.pressed and (k == KEY_ESCAPE or k == KEY_P):
			if estado == "jogo":
				pausar()
			elif estado == "pausa":
				continuar()
			return
		if not mapa.has(k):
			return
		if ev.pressed:
			if estado == "menu" and mapa[k] == "cima":
				iniciar()
				return
			S.acao(mapa[k])
			if mapa[k] == "cima":
				S.hold = true
		elif mapa[k] == "cima":
			S.hold = false
	elif ev is InputEventJoypadButton and ev.pressed:
		match ev.button_index:
			JOY_BUTTON_A:
				if estado == "menu":
					iniciar()
				else:
					S.acao("cima")
					S.hold = true
			JOY_BUTTON_B:
				S.acao("baixo")
			JOY_BUTTON_X, JOY_BUTTON_RIGHT_SHOULDER:
				S.acao("dash")
			JOY_BUTTON_DPAD_LEFT:
				S.acao("esq")
			JOY_BUTTON_DPAD_RIGHT:
				S.acao("dir")
			JOY_BUTTON_START:
				if estado == "jogo":
					pausar()
				else:
					continuar()
	elif ev is InputEventJoypadButton and not ev.pressed and ev.button_index == JOY_BUTTON_A:
		S.hold = false


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_APPLICATION_PAUSED:
		pausar()


func pausar() -> void:
	if estado != "jogo":
		return
	estado = "pausa"
	_mostrar_tela("pausa")


func continuar() -> void:
	if estado != "pausa":
		return
	estado = "jogo"
	_mostrar_tela("")


func _ir_menu() -> void:
	estado = "menu"
	_atualizar_rota()
	_mostrar_tela("inicio")


# ------------------------------------------------------------------ HUD e telas
func _estilo(cor: Color, borda := Color(0, 0, 0, 0), raio := 18, larg := 3) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = cor
	s.set_corner_radius_all(raio)
	if borda.a > 0.0:
		s.border_color = borda
		s.set_border_width_all(larg)
	s.content_margin_left = 16
	s.content_margin_right = 16
	s.content_margin_top = 6
	s.content_margin_bottom = 6
	return s


func _label(texto: String, tam: int, cor := Color("#f6f4ee"), quebra := true) -> Label:
	var l := Label.new()
	l.text = texto
	l.add_theme_font_size_override("font_size", tam)
	l.add_theme_color_override("font_color", cor)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if quebra:
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l


func _botao(texto: String, principal := true) -> Button:
	var b := Button.new()
	b.text = texto
	b.custom_minimum_size = Vector2(460, 100)
	b.add_theme_font_size_override("font_size", 40)
	var cor := Color("#f6b73c") if principal else Color(1, 1, 1, 0.1)
	var borda := TINTA if principal else Color(1, 1, 1, 0.35)
	for st in ["normal", "hover", "pressed", "focus"]:
		var c := cor.lightened(0.08) if st == "hover" else (cor.darkened(0.15) if st == "pressed" else cor)
		b.add_theme_stylebox_override(st, _estilo(c, Color.WHITE if st == "focus" else borda, 26, 4))
	for st in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		b.add_theme_color_override(st, Color("#2a1600") if principal else Color.WHITE)
	return b


func _tela_base() -> VBoxContainer:
	var fundo := ColorRect.new()
	fundo.color = Color(0.004, 0.094, 0.047, 0.93)
	fundo.set_anchors_preset(Control.PRESET_FULL_RECT)
	hud.get_parent().add_child(fundo)
	var cc := CenterContainer.new()
	cc.set_anchors_preset(Control.PRESET_FULL_RECT)
	fundo.add_child(cc)
	var v := VBoxContainer.new()
	v.custom_minimum_size = Vector2(640, 0)
	v.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_theme_constant_override("separation", 9)
	cc.add_child(v)
	return v


func _chip(borda: Color) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", _estilo(Color(0.004, 0.094, 0.047, 0.85), borda))
	return p


func _montar_hud() -> void:
	fonte = load("res://assets/fonts/Baloo2-ExtraBold.woff2")
	var reserva: FontFile = load("res://assets/fonts/DejaVuSans-Bold.ttf")
	fonte.fallbacks = [reserva]
	var tema := Theme.new()
	tema.default_font = fonte
	var camada := CanvasLayer.new()
	add_child(camada)
	var raiz := Control.new()
	raiz.set_anchors_preset(Control.PRESET_FULL_RECT)
	raiz.mouse_filter = Control.MOUSE_FILTER_IGNORE
	raiz.theme = tema
	camada.add_child(raiz)
	flash = ColorRect.new()
	flash.color = Color(1, 0.15, 0.15, 0.0)
	flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	raiz.add_child(flash)
	hud = Control.new()
	hud.set_anchors_preset(Control.PRESET_FULL_RECT)
	hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	raiz.add_child(hud)
	var topo := HBoxContainer.new()
	topo.set_anchors_preset(Control.PRESET_TOP_WIDE)
	topo.offset_left = 20
	topo.offset_right = -20
	topo.offset_top = 46
	topo.add_theme_constant_override("separation", 10)
	hud.add_child(topo)
	var ct := _chip(Color("#fcc352"))
	lbl_tempo = _label("1:58", 36, Color("#f6f4ee"), false)
	ct.add_child(lbl_tempo)
	topo.add_child(ct)
	var cm := _chip(Color(F["cia"]["cor"]))
	lbl_milhas = _label("0", 32, Color.WHITE, false)
	cm.add_child(lbl_milhas)
	topo.add_child(cm)
	var esp := Control.new()
	esp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	topo.add_child(esp)
	var bp := _botao("II", false)
	bp.custom_minimum_size = Vector2(80, 72)
	bp.pressed.connect(pausar)
	topo.add_child(bp)
	var linha2 := HBoxContainer.new()
	linha2.set_anchors_preset(Control.PRESET_TOP_WIDE)
	linha2.offset_left = 20
	linha2.offset_top = 128
	linha2.add_theme_constant_override("separation", 10)
	hud.add_child(linha2)
	var cc2 := _chip(Color("#e9d27a"))
	lbl_cartao = _label("Cartão 0/5", 24, Color("#fff3c4"), false)
	cc2.add_child(lbl_cartao)
	linha2.add_child(cc2)
	var cu := _chip(Color("#e74c3c"))
	lbl_chuva = _label("Guarda-chuva", 24, Color.WHITE, false)
	cu.add_child(lbl_chuva)
	linha2.add_child(cu)
	var lg := _label("GUARDA", 22, Color(1, 1, 1, 0.9), false)
	lg.position = Vector2(24, 184)
	hud.add_child(lg)
	var fg := ColorRect.new()
	fg.color = Color(0.004, 0.094, 0.047, 0.8)
	fg.position = Vector2(130, 194)
	fg.size = Vector2(566, 18)
	hud.add_child(fg)
	barra_guarda = ColorRect.new()
	barra_guarda.size = Vector2(566, 18)
	fg.add_child(barra_guarda)
	lbl_dica = _label("", 32)
	lbl_dica.add_theme_stylebox_override("normal", _estilo(Color(0.004, 0.094, 0.047, 0.9), Color("#fcc352"), 24))
	lbl_dica.position = Vector2(50, 300)
	lbl_dica.size = Vector2(620, 0)
	lbl_dica.visible = false
	hud.add_child(lbl_dica)
	lbl_aviso = _label("", 60, Color("#fcc352"))
	lbl_aviso.add_theme_constant_override("outline_size", 16)
	lbl_aviso.add_theme_color_override("font_outline_color", TINTA)
	lbl_aviso.position = Vector2(20, 480)
	lbl_aviso.size = Vector2(680, 0)
	lbl_aviso.visible = false
	hud.add_child(lbl_aviso)
	# tela inicial
	var v := _tela_base()
	tela_inicio = v.get_parent().get_parent()
	v.add_child(_label("MILHAS PLUS", 40, Color("#fcc352")))
	var titulo := _label("Última Chamada!", 76)
	titulo.add_theme_constant_override("line_spacing", -30)
	v.add_child(titulo)
	var retrato := Control.new()
	retrato.custom_minimum_size = Vector2(0, 200)
	retrato.draw.connect(func(): _retrato(retrato))
	v.add_child(retrato)
	v.add_child(_label("Episódio 1 · Brasil. Atrasado para o voo! Corra, junte milhas e embarque antes de o portão fechar.", 26))
	for i in ROTA.size():
		var p := PanelContainer.new()
		p.add_theme_stylebox_override("panel", _estilo(Color(0.99, 0.76, 0.32, 0.18) if i == 0 else Color(1, 1, 1, 0.06), Color("#fcc352") if i == 0 else Color(1, 1, 1, 0.14)))
		var l := _label("", 23, Color.WHITE)
		l.custom_minimum_size = Vector2(600, 0)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		p.add_child(l)
		lbl_rota.append(l)
		v.add_child(p)
	_atualizar_rota()
	var bj := _botao("Jogar Guarulhos")
	bj.pressed.connect(iniciar)
	v.add_child(bj)
	v.add_child(_label("Arraste ↑ pular · segure planar · ↓ rolar · → acelerar · ← → trocar de faixa", 21, Color(1, 1, 1, 0.8)))
	# pausa
	v = _tela_base()
	tela_pausa = v.get_parent().get_parent()
	v.add_child(_label("Pausado", 80))
	var b1 := _botao("Continuar")
	b1.pressed.connect(continuar)
	v.add_child(b1)
	var b2 := _botao("Reiniciar fase", false)
	b2.pressed.connect(iniciar)
	v.add_child(b2)
	var b3 := _botao("Mapa de rotas", false)
	b3.pressed.connect(_ir_menu)
	v.add_child(b3)
	# fim
	v = _tela_base()
	tela_fim = v.get_parent().get_parent()
	v.add_child(_label("FASE 1 · %s · %s" % [F["nome"], F["estado"]], 28, Color("#fcc352")))
	lbl_fim_titulo = _label("Embarcou!", 72)
	v.add_child(lbl_fim_titulo)
	lbl_fim_estrelas = _label("★ ★ ★", 96, Color("#fcc352"))
	v.add_child(lbl_fim_estrelas)
	lbl_fim_res = _label("", 30)
	lbl_fim_res.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	var pr := PanelContainer.new()
	pr.add_theme_stylebox_override("panel", _estilo(Color(0, 0, 0, 0.28)))
	pr.add_child(lbl_fim_res)
	v.add_child(pr)
	var b4 := _botao("Jogar de novo")
	b4.pressed.connect(iniciar)
	v.add_child(b4)
	var b5 := _botao("Mapa de rotas", false)
	b5.pressed.connect(_ir_menu)
	v.add_child(b5)
	_mostrar_tela("")


func _retrato(ctl: Control) -> void:
	var m: Dictionary = META["m_acoes"]
	var k := 0.7
	var pe := Vector2(ctl.size.x * 0.5, 198)
	var qw := float(m["qw"])
	var qh := float(m["qh"])
	var pp: Array = m["pe"]
	ctl.draw_texture_rect_region(T["m_acoes"], Rect2(pe - Vector2(float(pp[0]), float(pp[1])) * k, Vector2(qw, qh) * k), Rect2(POSES["vitoria"] * qw, 0, qw, qh))


func _atualizar_rota() -> void:
	var cfg := ConfigFile.new()
	cfg.load("user://progresso.cfg")
	var best: int = cfg.get_value("estrelas", F["id"], 0)
	var cart: int = cfg.get_value("cartao", F["id"], 0)
	var liberadas := 5 if OS.has_feature("teste") else 1
	for i in lbl_rota.size():
		var r: Array = ROTA[i]
		var estado_txt := ("★".repeat(best) + "☆".repeat(3 - best) + ("  ✉%d/5" % cart if cart > 0 else "")) if i == 0 else ("em breve" if i >= liberadas else "")
		lbl_rota[i].text = "%d · %s (%s)   %s\n%s · %s" % [i + 1, r[0], r[1], estado_txt, r[2], r[3]]
		lbl_rota[i].modulate = Color.WHITE if i < liberadas else Color(1, 1, 1, 0.5)


func _mostrar_tela(qual: String) -> void:
	tela_inicio.visible = qual == "inicio"
	tela_pausa.visible = qual == "pausa"
	tela_fim.visible = qual == "fim"
	hud.visible = qual == ""


func _atualizar_hud() -> void:
	if lbl_tempo == null or S == null:
		return
	var s := int(ceil(S.tempo))
	lbl_tempo.text = "%d:%02d" % [s / 60, s % 60]
	lbl_tempo.add_theme_color_override("font_color", Color("#ff6b6b") if S.tempo < 20.0 else Color("#f6f4ee"))
	lbl_milhas.text = "Milhas %s  %d / %d" % [F["cia"]["nome"], S.n_milhas, int(F["alvo_milhas"])]
	lbl_cartao.text = "Cartão %d/5" % S.n_cartao
	lbl_chuva.get_parent().visible = S.guarda_chuva_t > 0.0
	lbl_chuva.text = "Guarda-chuva %ds" % int(ceil(S.guarda_chuva_t))
	var g: float = clampf(S.guarda / Regras.GUARDA_MAX, 0.0, 1.0)
	barra_guarda.size.x = 566.0 * g
	barra_guarda.color = Color("#ff4d4d").lerp(Color("#43d17a"), g)


func dica(texto: String) -> void:
	lbl_dica.text = texto
	lbl_dica.visible = true
	dica_t = 2.8


func aviso(texto: String, dur := 1.0) -> void:
	lbl_aviso.text = texto
	lbl_aviso.visible = true
	aviso_t = dur


# ------------------------------------------------------------------ som
func _montar_sons() -> void:
	for nome in ["pulo", "pouso", "milha", "rolar", "mergulho", "dash", "faixa", "tropeco", "pisao", "mola", "ok", "alarme",
			"apito", "dingdong", "latido", "buzina", "porta", "splash", "etiqueta", "cone", "vitoria", "derrota", "mala",
			"cartao", "aviao", "carrinho", "guarda_chuva"]:
		var caminho := "res://assets/audio/%s.wav" % nome
		if ResourceLoader.exists(caminho):
			sons[nome] = load(caminho)
	for i in 8:
		var a := AudioStreamPlayer.new()
		a.volume_db = -3.0
		add_child(a)
		tocadores.append(a)
	musica = AudioStreamPlayer.new()
	var mus: AudioStreamWAV = load("res://assets/audio/musica.wav")
	mus.loop_mode = AudioStreamWAV.LOOP_FORWARD
	mus.loop_begin = 0
	mus.loop_end = int(mus.get_length() * mus.mix_rate)
	musica.stream = mus
	musica.volume_db = -9.0
	add_child(musica)
	chuva_som = AudioStreamPlayer.new()
	var ch: AudioStreamWAV = load("res://assets/audio/chuva.wav")
	ch.loop_mode = AudioStreamWAV.LOOP_FORWARD
	ch.loop_begin = 0
	ch.loop_end = int(ch.get_length() * ch.mix_rate)
	chuva_som.stream = ch
	chuva_som.volume_db = -40.0
	add_child(chuva_som)
	chuva_som.play()


func som(nome: String) -> void:
	if not sons.has(nome):
		return
	for a in tocadores:
		if not (a as AudioStreamPlayer).playing:
			a.stream = sons[nome]
			a.play()
			return
