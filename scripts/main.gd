extends Node2D
## Milhas Plus - Última Chamada! — telas, desenho da fase, controles e HUD.
## A física fica em sim.gd. A fase vem de assets/data/guarulhos.json.
## Linha de comando (depois de "--"): --bot (joga sozinho), --x=300 (começa no metro 300),
## --deus (não tropeça), --fotos=5,100 --pasta=/tmp (tira prints nesses metros e fecha).

const PX := 72.0          # pixels por metro na visão lateral
const W := 720.0
const H := 1280.0
const ESC_PERS := 132.0   # px por metro das folhas de personagens e objetos
const FOCO := 760.0       # visão de trás: distância focal em px
const DIST_TRAS := 6.8
const ALT_TRAS := 3.7
const CHAO_TELA := 0.74   # onde fica o chão na tela (fração da altura)
const EXPR := ["aberto", "feliz", "x", "susto", "foco", "pisca"]
const PLACAS := {"EMBARQUE": "placa_embarque", "CHECK-IN 1-20": "placa_checkin", "DESPACHO": "placa_despacho",
	"PISO MOLHADO": "placa_molhado", "PORTÕES 201-230": "placa_portoes", "CUIDADO": "placa_cuidado", "PARE": "placa_pare"}
const CEU := {"calcada": "#8597a8", "checkin": "#e3e8ec", "subsolo": "#e3e8ec", "seguranca": "#dfe6eb", "trem": "#8597a8", "embarque": "#ece8df", "finger": "#8597a8"}
const ROTA := [
	["Guarulhos", "SP", "Milhas LATAM", "Garoa, multidão e o trem entre terminais"],
	["Maringá", "PR", "Milhas Azul", "Ipês, Catedral e terra roxa"],
	["Brasília", "DF", "Milhas Smiles", "Curvas de Niemeyer e o Eixo Monumental"],
	["Salvador", "BA", "Milhas Azul", "Túnel de bambu, Pelourinho e Olodum"],
	["Rio de Janeiro", "RJ", "Milhas Smiles", "Santos Dumont, bondinho e Galeão"],
]

var F: Dictionary
var S: Sim
var T := {}              # texturas
var OBJ := {}            # tamanhos dos objetos (objetos.json)
var BGM := {}            # tamanhos dos fundos (fundos.json)
var MAS := {}            # mascote.json
var lado: Node2D
var tras_v: Node2D
var estado := "menu"
var bot := false
var deus := false
var x_inicio := 0.0
var fotos: Array = []
var pasta_fotos := "user://"
var espera_foto := -1
var acum := 0.0
var relogio := 0.0
var t := 0.0

# câmera
var cam_x := 0.0
var cam_y := 0.0
var cam_chao := 0.0
var tras := 0.0
var tremer := 0.0
var fase_anim := 0.0
var gotas: Array = []

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


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	bot = "--bot" in args
	deus = "--deus" in args
	for a in args:
		if a.begins_with("--x="):
			x_inicio = float(a.substr(4))
		elif a.begins_with("--fotos="):
			for v in a.substr(8).split(","):
				fotos.append(float(v))
			bot = true
		elif a.begins_with("--pasta="):
			pasta_fotos = a.substr(8)
	F = JSON.parse_string(FileAccess.get_file_as_string("res://assets/data/guarulhos.json"))
	OBJ = JSON.parse_string(FileAccess.get_file_as_string("res://assets/sprites/objetos.json"))
	BGM = JSON.parse_string(FileAccess.get_file_as_string("res://assets/bg/fundos.json"))
	MAS = JSON.parse_string(FileAccess.get_file_as_string("res://assets/sprites/mascote.json"))
	for nome in OBJ.keys():
		T[nome] = load("res://assets/sprites/%s.png" % nome)
	for nome in ["mascote_corpo", "mascote_cabeca", "mascote_costas", "mascote_rola", "guarda", "passageiro0", "passageiro1", "passageiro2", "comissaria"]:
		T[nome] = load("res://assets/sprites/%s.png" % nome)
	for nome in BGM.keys():
		T[nome] = load("res://assets/bg/%s.png" % nome)
	texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	lado = Node2D.new()
	lado.set_script(load("res://scripts/pintor.gd"))
	lado.desenhar = _desenhar_lado
	lado.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	add_child(lado)
	tras_v = Node2D.new()
	tras_v.set_script(load("res://scripts/pintor.gd"))
	tras_v.desenhar = _desenhar_tras
	tras_v.visible = false
	add_child(tras_v)
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	for i in 160:
		gotas.append(Vector2(rng.randf() * W, rng.randf() * H))
	_montar_hud()
	_montar_sons()
	novo_jogo()
	if bot or x_inicio > 0.0:
		iniciar()
	else:
		_mostrar_tela("inicio")


func novo_jogo() -> void:
	S = Sim.new(F, x_inicio, not (bot or x_inicio > 0.0))
	S.bot = bot
	S.deus = deus
	cam_chao = S.py
	tras = 1.0 if S.na_zona_tras(S.px) else 0.0
	_camera(0.0, true)
	_atualizar_hud()


func iniciar() -> void:
	novo_jogo()
	estado = "jogo"
	_mostrar_tela("")
	aviso("PLUS 218 · ÚLTIMA CHAMADA!", 1.6)


# ------------------------------------------------------------------ laço
func _process(delta: float) -> void:
	var dt: float = minf(delta, 0.05)
	relogio += dt
	t += dt
	if toque_ativo and not toque_feito and relogio - toque_t > 0.2 and estado == "jogo":
		toque_feito = true
		S.acao("cima")
		S.hold = true
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
	elif estado == "fim" and S.fim == "venceu":
		S.px += dt * 4.0
	if estado in ["jogo", "fim"]:
		if S.no_chao and S.rolar_t <= 0.0:
			fase_anim += dt * S.vx * 1.15
		_camera(dt)
		_atualizar_hud()
		lado.queue_redraw()
		tras_v.queue_redraw()
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
			"fim":
				_fim_de_jogo(e[1])
	S.eventos.clear()


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
	cam_y = cam_chao + (CHAO_TELA - 0.5) * H / PX
	tremer = maxf(0.0, tremer - dt)
	var a := smoothstep(0.0, 1.0, tras)
	lado.visible = a < 0.999
	tras_v.visible = a > 0.001
	tras_v.modulate.a = a
	var sh := Vector2(randf() - 0.5, randf() - 0.5) * tremer * 40.0
	lado.position = sh
	tras_v.position = sh


func tela(x: float, y: float) -> Vector2:
	return Vector2((x - cam_x) * PX + W * 0.5, H * 0.5 - (y - cam_y) * PX)


## Desenha um objeto pelo nome: centro em x, base em y (metros).
func spr(c: CanvasItem, nome: String, x: float, y: float, quadro := 0, mod := Color.WHITE, esc := 1.0, espelho := false) -> void:
	var tex: Texture2D = T[nome]
	var m: Dictionary = OBJ[nome]
	var q: int = int(m.get("quadros", 1))
	var fw := float(tex.get_width()) / q
	var fh := float(tex.get_height())
	var k := PX / float(m["pxm"]) * esc
	var base := tela(x, y - float(m.get("base", 0.0)) * esc)
	var tam := Vector2(fw, fh) * k
	var r := Rect2(base - Vector2(tam.x * 0.5, tam.y), tam)
	if espelho:
		r.position.x += r.size.x
		r.size.x = -r.size.x
	c.draw_texture_rect_region(tex, r, Rect2((quadro % q) * fw, 0, fw, fh), mod)


## Folha de personagem (quadros de largura fixa): ponto (ax, ay) do quadro vai para (x, y) metros.
func folha(c: CanvasItem, nome: String, quadro: int, qw: float, qh: float, ax: float, ay: float, x: float, y: float, mod := Color.WHITE, k := PX / ESC_PERS) -> void:
	var tex: Texture2D = T[nome]
	var p := tela(x, y) - Vector2(ax, ay) * k
	c.draw_texture_rect_region(tex, Rect2(p, Vector2(qw, qh) * k), Rect2(quadro * qw, 0, qw, qh), mod)


## Repete um fundo na horizontal entre a e b (metros), com a base em y.
func faixa_fundo(c: CanvasItem, nome: String, a: float, b: float, y_base: float, mod := Color.WHITE) -> void:
	var m: Dictionary = BGM[nome]
	var tw: float = m["w"]
	var th: float = m["h"]
	var tex: Texture2D = T[nome]
	var esc := float(tex.get_width()) / tw
	a = maxf(a, cam_x - W / PX)
	b = minf(b, cam_x + W / PX)
	if b <= a:
		return
	var p0 := tela(a, y_base + th)
	var p1 := tela(b, y_base)
	c.draw_texture_rect_region(tex, Rect2(p0, p1 - p0), Rect2(a * esc, 0, (b - a) * esc, tex.get_height()), mod)


func secao_em(x: float) -> Dictionary:
	for s in F["secoes"]:
		if x >= s["x0"] and x < s["x1"]:
			return s
	return F["secoes"][F["secoes"].size() - 1]


func _sub_em(x: float) -> bool:
	for s in F["secoes"]:
		if s["tipo"] == "subsolo" and x >= s["x0"] and x < s["x1"]:
			return true
	return false


# ------------------------------------------------------------------ visão lateral
func _desenhar_lado(c: CanvasItem) -> void:
	var xa := cam_x - W / PX * 0.6
	var xb := cam_x + W / PX * 0.6
	var sec := secao_em(S.px)
	# céu e cidade ao fundo (paralaxe)
	c.draw_rect(Rect2(0, 0, W, H), Color("#8597a8"))
	var tex: Texture2D = T["ceu_sp"]
	var k := PX / 66.0
	var tw := tex.get_width() * k
	var th := tex.get_height() * k
	var chao_tela := tela(0, 0).y
	var topo := lerpf(H * 0.72, chao_tela, 0.4) - float(BGM["ceu_sp"]["chao"]) * 66.0 * k
	var ox := -fposmod(cam_x * PX * 0.18, tw)
	var x := ox
	while x < W:
		c.draw_texture_rect(tex, Rect2(x, topo, tw, th), false)
		x += tw
	if topo + th < H:
		c.draw_rect(Rect2(0, topo + th, W, H - topo - th), Color("#5a6470"))
	# paredes de cada trecho
	for s in F["secoes"]:
		var a: float = s["x0"]
		var b: float = s["x1"]
		if b < xa or a > xb:
			continue
		match s["tipo"]:
			"calcada":
				var p0 := tela(a, 5.85)
				var p1 := tela(b, 5.35)
				c.draw_rect(Rect2(p0, p1 - p0), Color("#e8ecef"))
				c.draw_rect(Rect2(tela(a, 5.45), tela(b, 5.25) - tela(a, 5.45)), Color("#0d4a2b"))
				var col := ceilf(a / 10.0) * 10.0
				while col < b:
					var q0 := tela(col - 0.18, 5.35)
					c.draw_rect(Rect2(q0, Vector2(0.36 * PX, 5.35 * PX)), Color("#dfe3e6"))
					c.draw_rect(Rect2(q0, Vector2(0.36 * PX, 5.35 * PX)), Color("#1f1a17"), false, 3.0)
					col += 10.0
				c.draw_string(fonte, tela(-6, 5.29) + Vector2(0, 0), "AEROPORTO INTERNACIONAL DE GUARULHOS", HORIZONTAL_ALIGNMENT_LEFT, -1, 26, Color("#fcc352"))
			"checkin":
				faixa_fundo(c, "parede_checkin", a, b, 0.0)
			"seguranca":
				faixa_fundo(c, "parede_seguranca", a, b, 0.0)
			"embarque":
				faixa_fundo(c, "parede_embarque", a, b, 0.0)
			"subsolo":
				faixa_fundo(c, "parede_checkin", a, b, 0.0)
				faixa_fundo(c, "parede_subsolo", a, b, -5.2)
			"finger":
				faixa_fundo(c, "parede_finger", a, minf(b, 586.0), 0.0)
				var r0 := tela(a, 3.6)
				var r1 := tela(minf(b, 586.0), 3.25)
				c.draw_rect(Rect2(r0, r1 - r0), Color("#9aa3ab"))
			"trem":
				for xe in [a + 1.0, b - 1.0]:
					var e0 := tela(xe - 1.6, 4.4)
					c.draw_rect(Rect2(e0, Vector2(3.2 * PX, 0.3 * PX)), Color("#e8ecef"))
					c.draw_rect(Rect2(e0, Vector2(3.2 * PX, 0.3 * PX)), Color("#1f1a17"), false, 3.0)
		if s["tipo"] in ["checkin", "seguranca", "embarque", "subsolo"]:
			var r0 := tela(a, 8.9)
			var r1 := tela(b, 8.35)
			c.draw_rect(Rect2(r0, r1 - r0), Color("#5b646d"))
	# decoração de fundo
	for d in F["decor"]:
		var dx: float = d["x"]
		if dx < xa - 12.0 or dx > xb + 12.0:
			continue
		match d["tipo"]:
			"taxi":
				spr(c, "taxi", dx, 0.15, 0, Color("#c9d0d6"), 0.8)
			"porta":
				spr(c, "porta", dx, 0.0)
			"painel":
				spr(c, "painel_ultima" if d.get("ultima", false) else "painel", dx, 4.0, 0, Color.WHITE if not d.get("ultima", false) or int(t * 3.0) % 2 == 0 else Color(1.2, 0.8, 0.8))
			"pastel":
				spr(c, "pastel", dx, 0.0, 0, Color("#e9e4dc"))
			"freeshop":
				spr(c, "freeshop", dx, 0.0, 0, Color("#e9e4dc"))
			"portao":
				spr(c, "portao", dx + 0.6, 0.0)
				folha(c, "comissaria", int(t * 3.0) % 2, 220, 260, 110, 248, dx + 1.9, 0.0)
			"aviao":
				var am: Dictionary = OBJ["aviao"]
				spr(c, "aviao", 583.0 - 3.75 + float(am["w"]) / 2.0, -3.43)
			"detector":
				pass
	# chão e lajes
	for ch in F["chao"]:
		var a: float = maxf(ch["x0"], xa - 2.0)
		var b: float = minf(ch["x1"], xb + 2.0)
		if b <= a:
			continue
		var y: float = ch["y"]
		var tipo: String = secao_em((a + b) / 2.0)["tipo"]
		var nome := "calcada" if tipo == "calcada" else "piso"
		var p0 := tela(a, y)
		var p1 := tela(b, y - 0.42)
		var tx: Texture2D = T[nome]
		var sk := float(tx.get_width()) / 2.0
		if tipo == "trem":
			c.draw_rect(Rect2(p0, tela(b, y - 0.8) - p0), Color("#a9b0b6"))
			c.draw_rect(Rect2(tela(a, y + 0.45), tela(b, y) - tela(a, y + 0.45)), Color("#cfd5da"))
			c.draw_line(tela(a, y + 0.45), tela(b, y + 0.45), Color("#1f1a17"), 3.0)
			c.draw_line(tela(a, y - 0.8), tela(b, y - 0.8), Color("#1f1a17"), 3.0)
			var pil := ceilf(a / 15.0) * 15.0
			while pil < b:
				c.draw_rect(Rect2(tela(pil - 0.7, y - 0.8), Vector2(1.4 * PX, 16 * PX)), Color("#9aa1a8"))
				c.draw_rect(Rect2(tela(pil - 0.7, y - 0.8), Vector2(1.4 * PX, 16 * PX)), Color("#1f1a17"), false, 3.0)
				pil += 15.0
			continue
		c.draw_texture_rect_region(tx, Rect2(p0, p1 - p0), Rect2(a * sk, 0, (b - a) * sk, tx.get_height()))
		var f0 := tela(a, y - 0.42)
		var f1 := tela(b, y - 0.62)
		c.draw_rect(Rect2(f0, f1 - f0), Color("#f2c230") if tipo == "calcada" else Color("#0d5a33"))
		c.draw_line(tela(a, y), tela(b, y), Color("#1f1a17"), 3.0)
		c.draw_line(f0, Vector2(f1.x, f0.y), Color("#1f1a17"), 3.0)
		c.draw_line(Vector2(f0.x, f1.y), f1, Color("#1f1a17"), 3.0)
		if tipo == "finger":
			var sp := ceilf(a / 12.0) * 12.0
			while sp < b:
				c.draw_rect(Rect2(tela(sp - 0.2, y - 0.62), Vector2(0.4 * PX, 4.0 * PX)), Color("#8a9198"))
				sp += 12.0
			continue
		# fundação (onde não há subsolo)
		var fx := a
		while fx < b:
			var fx2 := minf(b, fx + 1.0)
			if not _sub_em((fx + fx2) / 2.0) or y < -1.0:
				c.draw_rect(Rect2(tela(fx, y - 0.62), Vector2((fx2 - fx) * PX + 1.0, 9.0 * PX)), Color("#3b4248"))
			fx = fx2
	# mezanino
	for p in F["plataformas"]:
		var a: float = p["x0"]
		var b: float = p["x1"]
		if b < xa or a > xb:
			continue
		var y: float = p["y"]
		var v0 := tela(a, y + 0.95)
		var v1 := tela(b, y)
		c.draw_rect(Rect2(v0, v1 - v0), Color(0.68, 0.85, 0.9, 0.35))
		c.draw_line(tela(a, y + 0.95), tela(b, y + 0.95), Color("#7c8a96"), 5.0)
		c.draw_rect(Rect2(tela(a, y), tela(b, y - 0.3) - tela(a, y)), Color("#d9dee3"))
		c.draw_rect(Rect2(tela(a, y), tela(b, y - 0.3) - tela(a, y)), Color("#1f1a17"), false, 3.0)
		var px_ := a + 1.0
		while px_ < b:
			c.draw_rect(Rect2(tela(px_ - 0.08, y - 0.3), Vector2(0.16 * PX, (y - 0.3) * PX)), Color("#aab4bd"))
			px_ += 6.0
	# esteiras e piso molhado
	for z in F["zonas"]:
		var a: float = z["x0"]
		var b: float = z["x1"]
		if b < xa or a > xb:
			continue
		var y: float = z.get("y", 0.0)
		if z["tipo"] == "esteira":
			var te: Texture2D = T["esteira"]
			var e0 := tela(a, y + 0.02)
			var e1 := tela(b, y - 0.3)
			var off := fmod(t * float(z["boost"]) * 132.0, 132.0)
			c.draw_texture_rect_region(te, Rect2(e0, e1 - e0), Rect2(-off, 0, (b - a) * 132.0, 40))
			c.draw_rect(Rect2(e0, e1 - e0), Color("#1f1a17"), false, 3.0)
		elif z["tipo"] == "molhado":
			c.draw_rect(Rect2(tela(a, y + 0.03), tela(b, y - 0.25) - tela(a, y + 0.03)), Color(0.62, 0.85, 1.0, 0.55))
			for i in 4:
				var bx := a + (b - a) * (i + 0.5) / 4.0
				c.draw_line(tela(bx - 0.5, y - 0.12), tela(bx + 0.2, y - 0.12), Color(1, 1, 1, 0.8), 3.0)
			spr(c, "cavalete", a - 1.0, 0.0)
	# objetos
	for s in S.solidos:
		var sx: float = s["x"]
		if sx < xa - 3.0 or sx > xb + 3.0:
			continue
		var mod := Color.WHITE
		if s["fantasma"]:
			mod = Color(1, 1, 1, 0.55)
		match s["tipo"]:
			"mala":
				spr(c, "mala", sx, s["y"], 0, Color(s.get("cor", "#c0392b")) * Color(1.15, 1.15, 1.15, mod.a))
			"fita", "balcao", "carrinho", "raiox", "bandeja", "banco":
				var ext := 0.2 if s["tipo"] == "balcao" else 0.0
				spr(c, s["tipo"], sx + ext, s["y"], 0, mod)
	for d in F["decor"]:
		if d["tipo"] == "detector" and absf(float(d["x"]) - cam_x) < 9.0:
			spr(c, "detector", d["x"], 0.0)
			var alarme := false
			for p in S.perigos:
				if p["tipo"] == "detector" and absf(p["x"] - d["x"]) < 1.0 and p["alarme"] > 0.0:
					alarme = true
			spr(c, "detector_luz", d["x"], 2.03, (1 if int(t * 10.0) % 2 == 0 else 0) if alarme else 0)
	for m in S.molas:
		if absf(m["x"] - cam_x) < 9.0:
			spr(c, "mola", m["x"], m["y"], 1 if m["anim"] > 0.2 else 0)
	for p in S.perigos:
		var ppx: float = p["x"]
		if ppx < xa - 3.0 or ppx > xb + 3.0 or p["z"] != 0.0:
			continue
		match p["tipo"]:
			"placa":
				var nome: String = PLACAS.get(p.get("texto", ""), "placa_cuidado")
				var y0: float = p["y0"]
				var topo_y := 8.2
				var sec_p: String = secao_em(ppx)["tipo"]
				if sec_p == "calcada":
					topo_y = 5.35
				elif sec_p == "finger":
					topo_y = 3.25
				for dx in [-0.45, 0.45]:
					c.draw_line(tela(ppx + dx, y0 + 0.95), tela(ppx + dx, topo_y), Color("#4a4f55"), 3.0)
				spr(c, nome, ppx, y0)
			"pessoa":
				var var_i := int(p["x0i"]) % 3
				var q := 4 if p["morto"] > 0.0 else int(t * 7.0 + p["x0i"]) % 4
				folha(c, "passageiro%d" % var_i, q, 220, 260, 110, 250, ppx, 0.0)
	# milhas
	var giro := int(t * 12.0)
	for m in S.milhas:
		var mx: float = m["x"]
		if mx < xa - 1.0 or mx > xb + 1.0 or m["z"] != 0.0:
			continue
		if m["pega"]:
			if m["anim"] < 1.0:
				spr(c, "milha", mx, m["y"] - 0.4 + m["anim"] * 1.2, giro % 8, Color(1, 1, 1, 1.0 - m["anim"]), 1.0 + m["anim"] * 0.4)
			continue
		spr(c, "milha", mx, m["y"] - 0.4 + sin(t * 3.0 + mx) * 0.05, (giro + int(mx * 3.0)) % 8)
	if not S.mala.is_empty() and not S.mala["pega"]:
		spr(c, "mala_dourada", S.mala["x"], S.mala["y"] - 0.35 + sin(t * 3.0) * 0.08)
	# guarda
	var gd: float = clampf(S.guarda, 0.0, 20.0)
	var gx := S.px - 0.9 - gd * 0.15
	if S.intro > 0.0:
		gx = S.px - 4.5 + (1.6 - S.intro) * 1.5
	if gx > cam_x - W / PX * 0.55:
		var sg = S.suporte(gx, 0.0, S.py + 3.0)
		var gy: float = sg["y"] if sg != null else S.py
		folha(c, "guarda", int(t * 12.0) % 6, 240, 270, 120, 252, gx, gy)
		if gd < 4.0 or S.intro > 0.0:
			var bp := tela(gx + 0.6, gy + 2.55)
			c.draw_rect(Rect2(bp - Vector2(10, 34), Vector2(210, 44)), Color.WHITE)
			c.draw_rect(Rect2(bp - Vector2(10, 34), Vector2(210, 44)), Color("#c0392b"), false, 4.0)
			c.draw_string(fonte, bp + Vector2(4, 0), "EI! VOLTA AQUI!", HORIZONTAL_ALIGNMENT_LEFT, -1, 28, Color("#c0392b"))
	_desenhar_mascote(c)
	# garoa do lado de fora
	if sec["tipo"] in ["calcada", "trem", "finger"]:
		_garoa(c, 1.0)


func _pose() -> String:
	if S.fim == "venceu":
		return "vitoria"
	if S.intro > 0.0:
		return "parado"
	if S.tropeco_t > 0.0:
		return "tropeca"
	if not S.no_chao:
		if S.planando:
			return "plana%d" % (int(t * 10.0) % 2)
		return "sobe" if S.vy > 0.0 else "cai"
	if S.dash_t > 0.0:
		return "dash"
	return "corre%d" % (int(fase_anim) % 8)


func _olhos() -> String:
	if S.fim == "venceu":
		return "feliz"
	if S.tropeco_t > 0.0:
		return "x"
	if S.t_alarme > 0.0:
		return "susto"
	if S.guarda < 3.5:
		return "susto" if int(t * 4.0) % 2 == 1 else "aberto"
	if S.planando:
		return "feliz"
	if S.dash_t > 0.0 or S.rolar_t > 0.0:
		return "foco"
	if S.intro > 0.0:
		return "feliz" if S.intro > 0.8 else "susto"
	return "pisca" if fmod(t, 3.1) < 0.12 else "aberto"


func _desenhar_mascote(c: CanvasItem) -> void:
	if S.invuln > 0.0 and int(t * 14.0) % 2 == 0:
		return
	var k := PX / ESC_PERS
	if S.rolar_t > 0.0 and S.no_chao and S.fim == "":
		var centro := tela(S.px, S.py) - Vector2(0, (248 - 140) * k)
		c.draw_set_transform(centro, t * 16.0, Vector2(k, k))
		c.draw_texture(T["mascote_rola"], Vector2(-128, -140))
		c.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		return
	var pose := _pose()
	var i: int = MAS["poses"].find(pose)
	folha(c, "mascote_corpo", i, 256, 256, 124, 248, S.px, S.py)
	var n: Array = MAS["pescoco"][i]
	var e := EXPR.find(_olhos())
	var cab := tela(S.px, S.py) + (Vector2(n[0], n[1]) - Vector2(124, 248)) * k
	c.draw_texture_rect_region(T["mascote_cabeca"], Rect2(cab - Vector2(80, 130) * k, Vector2(170, 160) * k), Rect2(e * 170, 0, 170, 160))


func _garoa(c: CanvasItem, forca: float) -> void:
	var cor := Color(0.9, 0.94, 0.97, 0.45 * forca)
	for i in gotas.size():
		var g: Vector2 = gotas[i]
		var y := fposmod(g.y + t * 900.0, H)
		var x := fposmod(g.x - t * 120.0, W)
		c.draw_line(Vector2(x, y), Vector2(x - 5, y + 26), cor, 2.0)


# ------------------------------------------------------------------ visão de trás (pseudo-3D)
func _proj(x: float, y: float, z: float):
	var cx := S.px - DIST_TRAS
	var d := x - cx
	if d < 0.6:
		return null
	var cy := cam_chao + ALT_TRAS
	var cz := S.pz * 0.55
	return Vector3(W * 0.5 + (z - cz) * FOCO / d, H * 0.38 + (cy - y) * FOCO / d, FOCO / d)


func _neblina(d: float) -> Color:
	var k := clampf((d - 25.0) / 70.0, 0.0, 0.85)
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
		c.draw_polyline(arr, Color("#1f1a17"), 3.0)


func _spr3(c: CanvasItem, nome: String, x: float, y: float, z: float, quadro := 0, mod := Color.WHITE) -> void:
	var p = _proj(x, y, z)
	if p == null:
		return
	var tex: Texture2D = T[nome]
	var m: Dictionary = OBJ[nome]
	var q: int = int(m.get("quadros", 1))
	var fw := float(tex.get_width()) / q
	var fh := float(tex.get_height())
	var k: float = p.z / float(m["pxm"])
	var tam := Vector2(fw, fh) * k
	var base := Vector2(p.x, p.y + float(m.get("base", 0.0)) * p.z)
	c.draw_texture_rect_region(tex, Rect2(base - Vector2(tam.x * 0.5, tam.y), tam), Rect2((quadro % q) * fw, 0, fw, fh), mod * _neblina(x - S.px))


func _desenhar_tras(c: CanvasItem) -> void:
	# céu e cidade à frente
	var tex: Texture2D = T["frente_trem"]
	var k := W / float(tex.get_width()) * 1.15
	var hz := H * 0.38
	var topo := hz - float(BGM["frente_trem"]["horizonte"]) * k + 30.0
	c.draw_rect(Rect2(0, 0, W, H), Color("#8191a3"))
	c.draw_texture_rect(tex, Rect2(W * 0.5 - tex.get_width() * k * 0.5 - S.pz * 6.0, topo, tex.get_width() * k, tex.get_height() * k), false)
	c.draw_rect(Rect2(0, topo + tex.get_height() * k, W, H), Color("#56634f"))
	# trilho elevado
	var perto := S.px - DIST_TRAS + 0.7
	var longe := S.px + 120.0
	_quad(c, [_proj(perto, 0, -3.3), _proj(longe, 0, -3.3), _proj(longe, 0, 3.3), _proj(perto, 0, 3.3)], Color("#a9b0b6"), false)
	_quad(c, [_proj(perto, 0, -3.3), _proj(longe, 0, -3.3), _proj(longe, -0.8, -3.3), _proj(perto, -0.8, -3.3)], Color("#7f878e"), false)
	_quad(c, [_proj(perto, 0, 3.3), _proj(longe, 0, 3.3), _proj(longe, -0.8, 3.3), _proj(perto, -0.8, 3.3)], Color("#7f878e"), false)
	# dormentes que passam
	var d0 := ceilf(perto / 2.0) * 2.0
	var xd := longe
	while xd > d0:
		xd -= 2.0
		var a = _proj(xd, 0.01, -3.0)
		var b = _proj(xd, 0.01, 3.0)
		if a != null and b != null:
			c.draw_line(Vector2(a.x, a.y), Vector2(b.x, b.y), Color(0.45, 0.48, 0.52, 0.55), maxf(1.0, a.z * 0.06))
	for z in [-Regras.FAIXA, 0.0, Regras.FAIXA]:
		for dz in [-0.45, 0.45]:
			var a = _proj(perto, 0.02, z + dz)
			var b = _proj(longe, 0.02, z + dz)
			c.draw_line(Vector2(a.x, a.y), Vector2(b.x, b.y), Color("#4f555b"), 5.0)
	for z in [-3.35, 3.35]:
		_quad(c, [_proj(perto, 0, z), _proj(longe, 0, z), _proj(longe, 0.45, z), _proj(perto, 0.45, z)], Color("#cfd5da"))
	# objetos de longe para perto
	var itens: Array = []
	for s in S.solidos:
		if s["d"] < 3.0 and s["x1"] > perto and s["x0"] < longe:
			itens.append([s["x0"], "s", s])
	for p in S.perigos:
		if p["z"] != 0.0 or p["tipo"] == "trem":
			if p["d"] < 3.0 and p["x"] + p["w"] / 2.0 > perto and p["x"] - p["w"] / 2.0 < longe:
				itens.append([p["x"] - p["w"] / 2.0, "p", p])
	for m in S.milhas:
		if not m["pega"] and m["x"] > perto + 0.5 and m["x"] < S.px + 70.0 and S.na_zona_tras(m["x"]):
			itens.append([m["x"], "m", m])
	itens.append([S.px, "eu", null])
	itens.sort_custom(func(a, b): return a[0] > b[0])
	for it in itens:
		match it[1]:
			"s":
				_caixa3(c, it[2], it[2]["tipo"])
			"p":
				var p: Dictionary = it[2]
				if p["tipo"] == "trem":
					_caixa3(c, p, "trem")
				else:
					_spr3(c, "placa_pare", p["x"], 0.0, p["z"])
			"m":
				var m: Dictionary = it[2]
				_spr3(c, "milha", m["x"], m["y"] - 0.4, m["z"], (int(t * 12.0) + int(m["x"] * 3.0)) % 8)
			"eu":
				_mascote_costas(c)
	_garoa(c, 1.2)


func _caixa3(c: CanvasItem, s: Dictionary, tipo: String) -> void:
	var x0: float = s["x0"] if s.has("x0") else float(s["x"]) - float(s["w"]) / 2.0
	var x1: float = s["x1"] if s.has("x1") else float(s["x"]) + float(s["w"]) / 2.0
	var z: float = s["z"]
	var hd: float = float(s["d"]) / 2.0
	var h: float = s["h"] if s.has("h") else s["y1"]
	var perto := S.px - DIST_TRAS + 0.7
	var xa := maxf(x0, perto)
	if tipo == "barreira":
		_spr3(c, "barreira_f", x0, 0.0, z)
		return
	var corpo := Color("#eef1f3") if tipo != "trem" else Color("#f6f7f8")
	var nb := _neblina(x0 - S.px)
	if x0 < S.px - 0.5 and absf(z - S.pz) > 0.5:
		nb.a = 0.35
	# laterais e teto
	_quad(c, [_proj(xa, 0, z - hd), _proj(x1, 0, z - hd), _proj(x1, h, z - hd), _proj(xa, h, z - hd)], Color("#c9d0d6") * nb)
	_quad(c, [_proj(xa, 0, z + hd), _proj(x1, 0, z + hd), _proj(x1, h, z + hd), _proj(xa, h, z + hd)], Color("#c9d0d6") * nb)
	_quad(c, [_proj(xa, h, z - hd), _proj(x1, h, z - hd), _proj(x1, h, z + hd), _proj(xa, h, z + hd)], corpo * nb)
	# faixa azul nas laterais
	_quad(c, [_proj(xa, h * 0.36, z - hd), _proj(x1, h * 0.36, z - hd), _proj(x1, h * 0.44, z - hd), _proj(xa, h * 0.44, z - hd)], Color(F["cia"]["cor2"]) * nb, false)
	_quad(c, [_proj(xa, h * 0.36, z + hd), _proj(x1, h * 0.36, z + hd), _proj(x1, h * 0.44, z + hd), _proj(xa, h * 0.44, z + hd)], Color(F["cia"]["cor2"]) * nb, false)
	if x0 >= perto:
		_spr3(c, "trem_f" if tipo == "trem" else "vagao_f", x0, 0.0, z)
	var rampa: float = s.get("rampa", 0.0)
	if rampa > 0.0:
		_quad(c, [_proj(maxf(x0 - 0.01, perto), 0.02, z - hd * 0.9), _proj(maxf(x0 - 0.01, perto), 0.02, z + hd * 0.9), _proj(x0 + rampa, h, z + hd * 0.9), _proj(x0 + rampa, h, z - hd * 0.9)], Color("#f39c12") * nb)
		var r = _proj(x0 + rampa * 0.5, h * 0.5, z)
		if r != null:
			c.draw_string(fonte, Vector2(r.x - 12, r.y + 8), "▲", HORIZONTAL_ALIGNMENT_LEFT, -1, int(maxf(10, r.z * 0.4)), Color("#1f1a17"))


func _mascote_costas(c: CanvasItem) -> void:
	if S.invuln > 0.0 and int(t * 14.0) % 2 == 0:
		return
	var p = _proj(S.px, S.py, S.pz)
	if p == null:
		return
	var k: float = p.z / ESC_PERS
	var q := 4 if not S.no_chao else int(fase_anim * 0.5) % 4
	if S.rolar_t > 0.0 and S.no_chao:
		c.draw_set_transform(Vector2(p.x, p.y - 108 * k), t * 16.0, Vector2(k, k))
		c.draw_texture(T["mascote_rola"], Vector2(-128, -140))
		c.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		return
	# sombra
	var ch = S.suporte(S.px, S.pz, S.py + 0.1)
	if ch != null:
		var sp = _proj(S.px, ch["y"], S.pz)
		if sp != null:
			c.draw_set_transform(Vector2(sp.x, sp.y), 0.0, Vector2(1, 0.3))
			c.draw_circle(Vector2.ZERO, 0.4 * sp.z, Color(0, 0, 0, 0.25))
			c.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	c.draw_texture_rect_region(T["mascote_costas"], Rect2(Vector2(p.x, p.y) - Vector2(128, 248) * k, Vector2(256, 256) * k), Rect2(q * 256, 0, 256, 256))


# ------------------------------------------------------------------ entrada
func _unhandled_input(ev: InputEvent) -> void:
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


func _fim_de_jogo(tipo: String) -> void:
	estado = "fim"
	som("vitoria" if tipo == "venceu" else "derrota")
	if bot and fotos.is_empty():
		print("RESULTADO ", tipo, " milhas=", S.n_milhas)
	await get_tree().create_timer(1.3 if tipo == "venceu" else 0.9).timeout
	var est := [tipo == "venceu", tipo == "venceu" and S.n_milhas >= int(F["alvo_milhas"]), tipo == "venceu" and S.achou_mala]
	var n := est.count(true)
	var cfg := ConfigFile.new()
	cfg.load("user://progresso.cfg")
	if tipo == "venceu":
		cfg.set_value("estrelas", F["id"], maxi(n, int(cfg.get_value("estrelas", F["id"], 0))))
		cfg.save("user://progresso.cfg")
	lbl_fim_titulo.text = {"venceu": "Embarcou!", "pego": "O guarda te pegou!", "voo": "Perdeu o voo!"}[tipo]
	var e := ""
	for x in est:
		e += "★ " if x else "☆ "
	lbl_fim_estrelas.text = e.strip_edges()
	var usado := float(F["tempo"]) - S.tempo
	var linhas := [
		"%s  Chegou a tempo:  %s" % ["★" if est[0] else "☆", ("%d:%02d" % [int(usado) / 60, int(usado) % 60]) if tipo == "venceu" else "—"],
		"%s  Milhas %s:  %d de %d" % ["★" if est[1] else "☆", F["cia"]["nome"], S.n_milhas, int(F["alvo_milhas"])],
		"%s  Mala dourada:  %s" % ["★" if est[2] else "☆", "achou" if S.achou_mala else "escondida"],
		"Tropeços:  %d" % S.tropecos,
	]
	if tipo == "venceu":
		linhas.append("Próximo voo:  %s · em breve" % F["proxima"])
	lbl_fim_res.text = "\n".join(linhas)
	_mostrar_tela("fim")


# ------------------------------------------------------------------ HUD e telas
func _estilo(cor: Color, borda := Color(0, 0, 0, 0), raio := 18, larg := 3) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = cor
	s.set_corner_radius_all(raio)
	if borda.a > 0.0:
		s.border_color = borda
		s.set_border_width_all(larg)
	s.content_margin_left = 18
	s.content_margin_right = 18
	s.content_margin_top = 8
	s.content_margin_bottom = 8
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
	var borda := Color("#1f1a17") if principal else Color(1, 1, 1, 0.35)
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
	v.add_theme_constant_override("separation", 14)
	cc.add_child(v)
	return v


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
	topo.offset_left = 22
	topo.offset_right = -22
	topo.offset_top = 48
	topo.add_theme_constant_override("separation", 12)
	hud.add_child(topo)
	var ct := PanelContainer.new()
	ct.add_theme_stylebox_override("panel", _estilo(Color(0.004, 0.094, 0.047, 0.85), Color("#fcc352")))
	lbl_tempo = _label("1:40", 38, Color("#f6f4ee"), false)
	ct.add_child(lbl_tempo)
	topo.add_child(ct)
	var cm := PanelContainer.new()
	cm.add_theme_stylebox_override("panel", _estilo(Color(0.004, 0.094, 0.047, 0.85), Color(F["cia"]["cor"])))
	lbl_milhas = _label("0", 38, Color.WHITE, false)
	cm.add_child(lbl_milhas)
	topo.add_child(cm)
	var esp := Control.new()
	esp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	topo.add_child(esp)
	var bp := _botao("II", false)
	bp.custom_minimum_size = Vector2(84, 76)
	bp.pressed.connect(pausar)
	topo.add_child(bp)
	var lg := _label("GUARDA", 22, Color(1, 1, 1, 0.9), false)
	lg.position = Vector2(26, 138)
	hud.add_child(lg)
	var fg := ColorRect.new()
	fg.color = Color(0.004, 0.094, 0.047, 0.8)
	fg.position = Vector2(130, 148)
	fg.size = Vector2(566, 18)
	hud.add_child(fg)
	barra_guarda = ColorRect.new()
	barra_guarda.size = Vector2(566, 18)
	fg.add_child(barra_guarda)
	lbl_dica = _label("", 34)
	lbl_dica.add_theme_stylebox_override("normal", _estilo(Color(0.004, 0.094, 0.047, 0.9), Color("#fcc352"), 24))
	lbl_dica.position = Vector2(60, 300)
	lbl_dica.size = Vector2(600, 0)
	lbl_dica.visible = false
	hud.add_child(lbl_dica)
	lbl_aviso = _label("", 64, Color("#fcc352"))
	lbl_aviso.add_theme_constant_override("outline_size", 16)
	lbl_aviso.add_theme_color_override("font_outline_color", Color("#1f1a17"))
	lbl_aviso.position = Vector2(20, 470)
	lbl_aviso.size = Vector2(680, 0)
	lbl_aviso.visible = false
	hud.add_child(lbl_aviso)
	# tela inicial
	var v := _tela_base()
	tela_inicio = v.get_parent().get_parent()
	v.add_child(_label("MILHAS PLUS", 40, Color("#fcc352")))
	var titulo := _label("Última Chamada!", 92)
	titulo.add_theme_constant_override("line_spacing", -30)
	v.add_child(titulo)
	var retrato := Control.new()
	retrato.custom_minimum_size = Vector2(0, 250)
	retrato.draw.connect(func(): _retrato(retrato))
	v.add_child(retrato)
	v.add_child(_label("Episódio 1 · Brasil. O mascote está atrasado para o voo: corra pelos aeroportos, junte milhas e embarque antes de o portão fechar.", 28))
	for i in ROTA.size():
		var p := PanelContainer.new()
		p.add_theme_stylebox_override("panel", _estilo(Color(0.99, 0.76, 0.32, 0.18) if i == 0 else Color(1, 1, 1, 0.06), Color("#fcc352") if i == 0 else Color(1, 1, 1, 0.14)))
		var l := _label("", 26, Color.WHITE, false)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		p.add_child(l)
		lbl_rota.append(l)
		v.add_child(p)
	_atualizar_rota()
	var bj := _botao("Jogar Guarulhos")
	bj.pressed.connect(iniciar)
	v.add_child(bj)
	v.add_child(_label("Toque ou arraste para cima: pular · segure: planar · para baixo: rolar ou descer rápido · para a frente ou toque duplo: acelerar · no trem, para os lados: trocar de faixa", 22, Color(1, 1, 1, 0.8)))
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
	var k := 0.95
	var cx := ctl.size.x * 0.5
	var pes := Vector2(cx, 246)
	var i: int = MAS["poses"].find("vitoria")
	ctl.draw_texture_rect_region(T["mascote_corpo"], Rect2(pes - Vector2(124, 248) * k, Vector2(256, 256) * k), Rect2(i * 256, 0, 256, 256))
	var n: Array = MAS["pescoco"][i]
	var cab := pes + (Vector2(n[0], n[1]) - Vector2(124, 248)) * k
	ctl.draw_texture_rect_region(T["mascote_cabeca"], Rect2(cab - Vector2(80, 130) * k, Vector2(170, 160) * k), Rect2(170, 0, 170, 160))


func _atualizar_rota() -> void:
	var cfg := ConfigFile.new()
	cfg.load("user://progresso.cfg")
	var best: int = cfg.get_value("estrelas", F["id"], 0)
	var liberadas := 5 if OS.has_feature("teste") else 1
	for i in lbl_rota.size():
		var r: Array = ROTA[i]
		var estado_txt := ("★".repeat(best) + "☆".repeat(3 - best)) if i == 0 else ("em breve" if i >= liberadas else "")
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
	var g: float = clampf(S.guarda / Regras.GUARDA_MAX, 0.0, 1.0)
	barra_guarda.size.x = 566.0 * g
	barra_guarda.color = Color("#ff4d4d").lerp(Color("#43d17a"), g)


func dica(texto: String) -> void:
	lbl_dica.text = texto
	lbl_dica.visible = true
	dica_t = 2.6


func aviso(texto: String, dur := 1.0) -> void:
	lbl_aviso.text = texto
	lbl_aviso.visible = true
	aviso_t = dur


# ------------------------------------------------------------------ som
func _montar_sons() -> void:
	sons = {
		"milha": Sons.tom(880, 990, 0.09, "square", 0.16),
		"pulo": Sons.tom(320, 640, 0.16, "square", 0.2),
		"pouso": Sons.tom(120, 100, 0.06, "triangle", 0.3),
		"rolar": Sons.tom(220, 110, 0.18, "saw", 0.14),
		"mergulho": Sons.tom(600, 150, 0.2, "saw", 0.16),
		"dash": Sons.tom(200, 900, 0.22, "saw", 0.18),
		"faixa": Sons.tom(500, 700, 0.06, "triangle", 0.2),
		"tropeco": Sons.tom(160, 60, 0.3, "saw", 0.28),
		"pisao": Sons.tom(700, 1200, 0.12, "square", 0.18),
		"mola": Sons.tom(250, 1100, 0.35, "triangle", 0.32),
		"ok": Sons.tom(660, 990, 0.18, "square", 0.16),
		"alarme": Sons.tom(1300, 1250, 0.5, "square", 0.16),
		"apito": Sons.tom(2400, 2200, 0.35, "sine", 0.28),
		"mala": Sons.tom(523, 1046, 0.45, "square", 0.18),
		"vitoria": Sons.tom(523, 1046, 0.8, "square", 0.18),
		"derrota": Sons.tom(392, 196, 0.7, "triangle", 0.28),
	}
	for i in 6:
		var a := AudioStreamPlayer.new()
		add_child(a)
		tocadores.append(a)


func som(nome: String) -> void:
	if not sons.has(nome):
		return
	for a in tocadores:
		if not (a as AudioStreamPlayer).playing:
			a.stream = sons[nome]
			a.play()
			return
