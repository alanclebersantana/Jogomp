extends Node2D
class_name Jogo
## Uma fase em andamento: o Milis corre sozinho; um toque pula, toque no ar dá o pulo duplo, segurar no ar
## plana com as asas; paredes verdes ele sobe correndo (toque salta para o outro lado). Bateu numa parede
## comum, ele vira. Tropeçou num obstáculo: volta ao último totem de check-in e o relógio continua.

signal embarcou(res: Dictionary)
signal perdeu_voo
signal pausa

const T := 40.0
const CORRE := 265.0
const GRAV := 2300.0
const PULO := 860.0
const PULO2 := 760.0
const CORTE := 330.0
const QUEDA_MAX := 1050.0
const PLANA := 110.0
const PAREDE_V := 330.0
const MOLA_V := 1260.0
const PISAO_V := 700.0
const JW := 30.0
const JH := 68.0
const ZOOM := 1.1
const ESTEIRA_V := 170.0
const MOLHADO_K := 1.45

var fase: Fase
var gw := 0
var gh := 0
var g := PackedByteArray()
var solido := PackedByteArray()
var objs: Array = []
var portas: Array = []
var ventos: Array = []

# jogador
var pos := Vector2.ZERO          # pés (centro embaixo)
var vel := Vector2.ZERO
var dir := 1
var estado := "chao"             # chao, ar, parede, caiu
var no_chao := false
var sup := 32                    # letra embaixo dos pés
var pulos_ar := 1
var coyote := 0.0
var buffer := 0.0
var segurando := false
var pulando := false
var planando := false
var t_duplo := 9.0
var trava_parede := 0.0
var invul := 0.0
var t_caiu := 0.0
var bonus_x := 0.0
var t_anim := 0.0
var toques := {}
var pode_planar := false
var pode_parede := true

var checkpoint := {}
var moeda := "milha"
var tempo_total := 90.0
var tempo_rest := 90.0
var meta := 15.0
var milhas := 0
var total := 0
var quedas := 0
var situacao := "pronto"         # pronto, jogando, embarcando, perdeu, pausado
var t_sit := 0.0
var t := 0.0
var cam := Vector2.ZERO
var fade := 0.0
var aviso := ""
var t_aviso := 0.0
var fx: Array = []
var combo := 0
var t_combo := 0.0
var ultimo_seg := -1

var fundo: Node2D
var mundo: Node2D
var hud: Node2D
var camada_fundo: CanvasLayer
var camada_hud: CanvasLayer
var tela := Vector2(540, 960)
var r_pausa := Rect2(10, 14, 64, 64)
var bot := false                 # testes automáticos: sem tela de "pronto"


func inicia(f: Fase) -> void:
	fase = f
	gw = f.w
	gh = f.h
	g.resize(gw * gh)
	g.fill(32)
	for cy in gh:
		var l := f.linhas[cy]
		for cx in l.length():
			g[cy * gw + cx] = l.unicode_at(cx)
	solido.resize(256)
	solido.fill(0)
	for ch in "#MWKC<>~":
		solido[ch.unicode_at(0)] = 1
	tempo_total = f.mf("tempo", 90)
	tempo_rest = tempo_total
	meta = f.mf("meta", 15)
	pode_planar = f.m("asas", "0") == "1"
	if f.m("cia") != "" and Arte.info.has("milha_" + f.m("cia")):
		moeda = "milha_" + f.m("cia")
	_le_objetos()
	checkpoint = {"pos": pos, "dir": dir}
	cam = pos + Vector2(dir * 120, -120)
	_monta_nos()
	Som.tema(f.m("musica", "corrida"))


func _monta_nos() -> void:
	camada_fundo = CanvasLayer.new()
	camada_fundo.layer = -5
	add_child(camada_fundo)
	fundo = preload("res://scripts/desenho.gd").new()
	fundo.f = _desenha_fundo
	camada_fundo.add_child(fundo)
	mundo = preload("res://scripts/desenho.gd").new()
	mundo.f = _desenha_mundo
	add_child(mundo)
	camada_hud = CanvasLayer.new()
	camada_hud.layer = 5
	add_child(camada_hud)
	hud = preload("res://scripts/desenho.gd").new()
	hud.f = _desenha_hud
	camada_hud.add_child(hud)


# ------------------------------------------------------------------ leitura da grade
func L(ch: String) -> int:
	return ch.unicode_at(0)


func cel(cx: int, cy: int) -> int:
	if cx < 0 or cx >= gw:
		return 35     # '#': as laterais do mundo são parede
	if cy < 0:
		return 32
	if cy >= gh:
		return 32
	return g[cy * gw + cx]


func eh_solido(cx: int, cy: int) -> bool:
	return solido[cel(cx, cy)] == 1


func _chao_abaixo(cx: int, cy: int) -> float:
	var y := cy
	while y < gh and not eh_solido(cx, y) and cel(cx, y) != 61:
		y += 1
	return y * T


func _teto_acima(cx: int, cy: int) -> float:
	var y := cy
	while y >= 0 and not eh_solido(cx, y):
		y -= 1
	return (y + 1) * T


func _le_objetos() -> void:
	var dicas_pos: Array = []
	for cy in gh:
		for cx in gw:
			var c := cel(cx, cy)
			if c == 32 or solido[c] == 1 or c == 61:
				continue
			var ch := String.chr(c)
			var x := cx * T + T / 2
			var y := cy * T + T / 2
			var base := (cy + 1) * T
			var o := {}
			match ch:
				"S", "s":
					pos = Vector2(x, _chao_abaixo(cx, cy))
					dir = 1 if ch == "S" else -1
				"o":
					o = {"t": "milha", "p": Vector2(x, y), "v": 1}
				"$":
					o = {"t": "milha", "p": Vector2(x, y), "v": 10, "cartao": true}
				"T":
					o = {"t": "totem", "p": Vector2(x, _chao_abaixo(cx, cy)), "ativo": false}
				"G":
					o = {"t": "portao", "p": Vector2(x, _chao_abaixo(cx, cy)), "aberto": 0.0}
				"p", "q", "P":
					o = {"t": "pass", "p": Vector2(x, _chao_abaixo(cx, cy)), "d": -1 if ch == "p" else 1,
						"v": 0.0 if ch == "P" else 48.0, "var": (cx * 7 + cy) % 3, "x0": x, "alcance": 170.0}
				"c", "x":
					o = {"t": "carrinho", "p": Vector2(x, _chao_abaixo(cx, cy)), "d": -1 if ch == "c" else 1}
				"m", "n":
					o = {"t": "calha", "p": Vector2(x, cy * T), "d": -1 if ch == "m" else 1,
						"prox": fmod(cx * 0.37, 1.0) * 1.2 + 0.4}
				"k":
					o = {"t": "capanga", "tipo": "cambista", "p": Vector2(x, _chao_abaixo(cx, cy)), "d": -1, "v": 70.0, "x0": x, "alcance": 130.0}
				"r":
					o = {"t": "capanga", "tipo": "robo", "p": Vector2(x, _chao_abaixo(cx, cy)), "d": -1, "v": 125.0, "x0": x, "alcance": 200.0}
				"v":
					o = {"t": "mala_voa", "p": Vector2(x, y), "y0": y, "fase": fmod(cx * 0.61, 6.28)}
				"l":
					var ch_y := _chao_abaixo(cx, cy)
					o = {"t": "laser", "tipo": "chao", "p": Vector2(x, ch_y), "r": Rect2(x - 4, ch_y - 92, 8, 92)}
				"j":
					var te := _teto_acima(cx, cy)
					var cj := _chao_abaixo(cx, cy)
					o = {"t": "laser", "tipo": "teto", "p": Vector2(x, te), "r": Rect2(x - 4, te, 8, maxf(10.0, cj - 86 - te))}
				"L":
					var tl := _teto_acima(cx, cy)
					var cl := _chao_abaixo(cx, cy)
					o = {"t": "laser", "tipo": "pisca", "p": Vector2(x, tl), "r": Rect2(x - 4, tl, 8, cl - tl), "fase": fmod(cx * 0.53, 2.6)}
				"D":
					var cd := _chao_abaixo(cx, cy)
					o = {"t": "porta", "p": Vector2(x, cy * T), "r": Rect2(x - 10, cy * T, 20, cd - cy * T),
						"fase": fmod(cx * 0.41, 3.2), "abre": 1.0}
					portas.append(o)
				"F":
					var cf := _chao_abaixo(cx, cy)
					var topo := cf
					var k := 0
					while k < 11 and not eh_solido(cx, int(topo / T) - 1):
						topo -= T
						k += 1
					o = {"t": "vento", "p": Vector2(x, cf), "r": Rect2(x - 46, topo, 92, cf - topo)}
					ventos.append(o)
				"^":
					o = {"t": "mola", "p": Vector2(x, _chao_abaixo(cx, cy)), "aperta": 0.0}
				"A":
					o = {"t": "asas", "p": Vector2(x, y)}
				"?":
					dicas_pos.append(Vector2(x, y))
			g[cy * gw + cx] = 32
			if not o.is_empty():
				if o.t == "milha":
					total += int(o.v)
				objs.append(o)
	dicas_pos.sort_custom(func(a, b): return a.x < b.x)
	for i in dicas_pos.size():
		if i < fase.dicas.size():
			objs.append({"t": "dica", "p": dicas_pos[i], "txt": fase.dicas[i], "vista": false})
	# placa amarela no começo de cada trecho de chão molhado
	for cy in gh:
		for cx in gw:
			if cel(cx, cy) == 126 and cel(cx - 1, cy) != 126 and not eh_solido(cx, cy - 1):
				objs.append({"t": "placa", "p": Vector2(cx * T + 6, cy * T)})


# ------------------------------------------------------------------ entrada
func _unhandled_input(e: InputEvent) -> void:
	if situacao == "pausado":
		return
	if e is InputEventScreenTouch:
		var st := e as InputEventScreenTouch
		if st.pressed:
			if r_pausa.grow(10).has_point(st.position) and situacao == "jogando":
				pausa.emit()
				return
			toques[st.index] = true
			aperta()
		else:
			toques.erase(st.index)
			if toques.is_empty():
				solta()
	elif e is InputEventKey:
		var k := e as InputEventKey
		if k.echo:
			return
		if k.keycode in [KEY_SPACE, KEY_UP, KEY_W, KEY_Z]:
			if k.pressed:
				aperta()
			else:
				solta()
		elif k.keycode == KEY_ESCAPE and k.pressed and situacao == "jogando":
			pausa.emit()


func aperta() -> void:
	segurando = true
	buffer = 0.13
	if situacao == "pronto" and t_sit > 0.3:
		_comeca()


func solta() -> void:
	segurando = false


func _comeca() -> void:
	situacao = "jogando"
	t_sit = 0.0


# ------------------------------------------------------------------ laço
func _physics_process(dt: float) -> void:
	if situacao == "pausado":
		return
	t += dt
	t_sit += dt
	tela = get_viewport_rect().size
	match situacao:
		"pronto":
			t_anim += dt
			if bot or t_sit > 1.6:
				_comeca()
		"jogando":
			tempo_rest -= dt
			var s := int(ceilf(tempo_rest))
			if s != ultimo_seg:
				ultimo_seg = s
				if s <= 5 and s > 0:
					Som.toca("cartao", -4.0, 1.6)
			if tempo_rest <= 0.0:
				tempo_rest = 0.0
				situacao = "perdeu"
				t_sit = 0.0
				Som.toca("derrota")
			else:
				_passo_jogador(dt)
		"embarcando":
			t_anim += dt
			vel.x = move_toward(vel.x, 0.0, 600 * dt)
			pos.x += vel.x * dt
			if t_sit > 2.2:
				situacao = "fim"
				embarcou.emit(resultado())
		"perdeu":
			if t_sit > 1.8:
				situacao = "fim"
				perdeu_voo.emit()
	_passo_objetos(dt)
	_passo_fx(dt)
	_camera(dt)
	if t_aviso > 0:
		t_aviso -= dt
	if t_combo > 0:
		t_combo -= dt
	else:
		combo = 0
	fundo.queue_redraw()
	mundo.queue_redraw()
	hud.queue_redraw()


func resultado() -> Dictionary:
	return {"milhas": milhas, "total": total, "sobra": tempo_rest, "todas": milhas >= total,
		"rapido": tempo_rest >= meta, "quedas": quedas, "meta": meta}


func rect_jog() -> Rect2:
	return Rect2(pos.x - JW / 2, pos.y - JH, JW, JH)


func _passo_jogador(dt: float) -> void:
	t_anim += dt
	t_duplo += dt
	invul = maxf(0.0, invul - dt)
	trava_parede = maxf(0.0, trava_parede - dt)
	if estado == "caiu":
		_passo_caido(dt)
		return
	buffer -= dt
	coyote -= dt
	if no_chao:
		coyote = 0.09
		pulos_ar = 1
	# pulo / pulo duplo / salto da parede
	if buffer > 0.0:
		if estado == "parede":
			buffer = 0.0
			dir = -dir
			vel = Vector2(dir * CORRE, -PULO * 0.95)
			estado = "ar"
			pulando = true
			trava_parede = 0.16
			pulos_ar = 1
			Som.toca("pulo", 0.0, 1.15)
			_poeira(pos + Vector2(-dir * JW / 2, -JH / 2), 5)
		elif coyote > 0.0:
			buffer = 0.0
			coyote = 0.0
			vel.y = -PULO
			estado = "ar"
			no_chao = false
			pulando = true
			Som.toca("pulo")
			_poeira(pos, 4)
		elif pulos_ar > 0 and estado == "ar":
			buffer = 0.0
			pulos_ar -= 1
			vel.y = -PULO2
			pulando = true
			t_duplo = 0.0
			Som.toca("pulo", 0.0, 1.3)
			_fx_anel(pos + Vector2(0, -10))
	if estado == "parede":
		_passo_parede(dt)
		return
	# velocidade de corrida (esteira e chão molhado mudam)
	var alvo := dir * CORRE
	if no_chao:
		bonus_x = 0.0
		if sup == 62:
			bonus_x = ESTEIRA_V
		elif sup == 60:
			bonus_x = -ESTEIRA_V
		elif sup == 126:
			bonus_x = dir * CORRE * (MOLHADO_K - 1.0)
	vel.x = alvo + bonus_x
	# gravidade, pulo variável e planar
	vel.y += GRAV * dt
	if pulando and not segurando and vel.y < -CORTE:
		vel.y = -CORTE
	if vel.y >= 0:
		pulando = false
	planando = pode_planar and segurando and vel.y > 0 and not no_chao
	if planando and vel.y > PLANA:
		vel.y = move_toward(vel.y, PLANA, 5200 * dt)
	for v in ventos:
		var r: Rect2 = v.r
		if r.intersects(rect_jog()):
			if planando:
				vel.y = maxf(vel.y - 3600 * dt, -470.0)
			else:
				vel.y -= 1250 * dt
	vel.y = minf(vel.y, QUEDA_MAX)
	# move em x
	var bate := _move_x(vel.x * dt)
	if bate == 87 and trava_parede > 0.0 and estado == "ar":
		bate = 0          # escorregando encostado na parede verde: não vira
	if bate != 0:
		if bate == 87 and pode_parede and trava_parede <= 0.0:
			estado = "parede"
			vel = Vector2.ZERO
			pulando = false
			no_chao = false
			Som.toca("pisao", -6.0, 1.4)
			return
		else:
			dir = -dir
			bonus_x = -bonus_x if sup != 126 else 0.0
			_fx_bonk(pos + Vector2(-dir * JW / 2, -JH * 0.6))
			Som.toca("pisao", -8.0, 0.8)
	# move em y
	var estava := no_chao
	_move_y(vel.y * dt)
	if no_chao:
		estado = "chao"
		if not estava:
			_poeira(pos, 3)
			Som.toca("pouso", -6.0)
	else:
		estado = "ar"
	if pos.y > gh * T + 160:
		_machuca(true)


func _passo_parede(dt: float) -> void:
	var antes := pos.y
	_move_y(-PAREDE_V * dt)
	var subiu := pos.y < antes - 0.01
	var px := int(floorf((pos.x + dir * (JW / 2 + 3)) / T))
	var meio := int(floorf((pos.y - JH * 0.55) / T))
	var pe := int(floorf((pos.y - 4) / T))
	var c_meio := cel(px, meio)
	var c_pe := cel(px, pe)
	if not subiu:
		# bateu no teto: escorrega de volta para baixo (toque para saltar para o outro lado)
		_escorrega()
		return
	if c_meio == 87 or c_pe == 87:
		if c_meio != 87 and solido[c_meio] == 1:
			# acabou a parte verde (tampa cinza em cima): escorrega para baixo
			_escorrega()
		return
	# chegou ao topo: um pulinho para a frente
	estado = "ar"
	pos.y -= 6.0
	vel = Vector2(dir * CORRE, -470)
	pulando = false
	pulos_ar = 1


func _escorrega() -> void:
	estado = "ar"
	vel = Vector2(0, 40)
	trava_parede = 0.45
	pulos_ar = 1


func _passo_caido(dt: float) -> void:
	t_caiu += dt
	vel.y += GRAV * dt
	pos += vel * dt
	if t_caiu > 0.7:
		fade = minf(1.0, (t_caiu - 0.7) / 0.3)
	if t_caiu > 1.05:
		pos = checkpoint.pos
		dir = checkpoint.dir
		vel = Vector2.ZERO
		estado = "chao"
		no_chao = true
		invul = 1.3
		fade = 0.0
		bonus_x = 0.0
		segurando = false
		pulando = false
		toques.clear()
		cam = pos + Vector2(dir * 120, -120)


var motivo := ""


func _machuca(caiu_no_buraco := false, por := "") -> void:
	if estado == "caiu" or (invul > 0.0 and not caiu_no_buraco) or situacao != "jogando":
		return
	estado = "caiu"
	t_caiu = 0.0 if not caiu_no_buraco else 0.6
	vel = Vector2(-dir * 150, -560) if not caiu_no_buraco else Vector2.ZERO
	quedas += 1
	motivo = por if por != "" else ("buraco" if caiu_no_buraco else "?")
	planando = false
	Som.toca("tropeco")
	aviso_msg("Ops! De volta ao check-in", 1.6)


# ------------------------------------------------------------------ colisão com a grade
func _solido_em(r: Rect2, dx: float) -> int:
	# letra do obstáculo que bloqueia o retângulo (0 se livre); com dx, olha primeiro a coluna da frente
	var x0 := int(floorf(r.position.x / T))
	var x1 := int(floorf((r.end.x - 0.001) / T))
	var y0 := int(floorf(r.position.y / T))
	var y1 := int(floorf((r.end.y - 0.001) / T))
	var achou := 0
	var cols := range(x0, x1 + 1) if dx >= 0 else range(x1, x0 - 1, -1)
	for cx in cols:
		for cy in range(y0, y1 + 1):
			var c := cel(cx, cy)
			if solido[c] == 1:
				if c == 87:
					return 87
				achou = c
		if achou != 0:
			return achou
	for pt in portas:
		if float(pt.abre) < 0.15 and (pt.r as Rect2).intersects(r):
			return 68
	return 0


func _move_x(dx: float) -> int:
	if dx == 0.0:
		return 0
	pos.x += dx
	var r := rect_jog()
	var c := _solido_em(r, dx)
	if c == 0:
		return 0
	# encosta na parede
	if dx > 0:
		var borda := floorf((r.end.x - 0.001) / T) * T
		for pt in portas:
			if float(pt.abre) < 0.15 and (pt.r as Rect2).intersects(r):
				borda = minf(borda, (pt.r as Rect2).position.x)
		pos.x = borda - JW / 2 - 0.01
	else:
		var borda2 := (floorf(r.position.x / T) + 1) * T
		for pt in portas:
			if float(pt.abre) < 0.15 and (pt.r as Rect2).intersects(r):
				borda2 = maxf(borda2, (pt.r as Rect2).end.x)
		pos.x = borda2 + JW / 2 + 0.01
	return c


func _move_y(dy: float) -> void:
	var pe_antes := pos.y
	pos.y += dy
	no_chao = false
	var r := rect_jog()
	var x0 := int(floorf(r.position.x / T))
	var x1 := int(floorf((r.end.x - 0.001) / T))
	if dy > 0:
		var cy := int(floorf((pos.y - 0.001) / T))
		for cx in range(x0, x1 + 1):
			var c := cel(cx, cy)
			var topo := cy * T
			if solido[c] == 1 or (c == 61 and pe_antes <= topo + 0.5):
				pos.y = topo
				vel.y = 0.0
				no_chao = true
				sup = c
				for cx2 in range(x0, x1 + 1):
					var c2 := cel(cx2, cy)
					if c2 in [62, 60, 126]:
						sup = c2
				return
	elif dy < 0:
		var cy := int(floorf(r.position.y / T))
		for cx in range(x0, x1 + 1):
			if eh_solido(cx, cy):
				pos.y = (cy + 1) * T + JH
				vel.y = 0.0
				return


# ------------------------------------------------------------------ objetos
func _passo_objetos(dt: float) -> void:
	var rj := rect_jog()
	var centro := pos + Vector2(0, -JH / 2)
	var ativo := situacao == "jogando" and estado != "caiu"
	var novos: Array = []
	for o in objs:
		match o.t:
			"milha":
				if not o.get("pego", false):
					if ativo and centro.distance_to(o.p) < 34:
						o.pego = true
						milhas += int(o.v)
						combo += 1
						t_combo = 0.6
						if o.get("cartao", false):
							Som.toca("cartao")
							aviso_msg("Cartão dourado! +10 milhas", 1.6)
						else:
							Som.toca("milha", -3.0, 1.0 + minf(combo, 12) * 0.04)
						_brilho(o.p)
			"totem":
				var rt := Rect2(o.p.x - 22, o.p.y - 86, 44, 86)
				if ativo and not o.ativo and rt.intersects(rj):
					o.ativo = true
					checkpoint = {"pos": Vector2(o.p.x, o.p.y), "dir": dir}
					Som.toca("dingdong", -4.0)
					aviso_msg("Check-in feito!", 1.4)
			"portao":
				var rp := Rect2(o.p.x - 30, o.p.y - 120, 60, 120)
				if situacao == "embarcando":
					o.aberto = minf(1.0, o.aberto + dt * 2.0)
				if ativo and rp.intersects(rj):
					situacao = "embarcando"
					t_sit = 0.0
					t_anim = 0.0
					vel.x = dir * 120.0
					Som.toca("vitoria")
			"pass":
				_anda(o, dt, float(o.v))
				var rpa := Rect2(o.p.x - 18, o.p.y - 84, 36, 84)
				if ativo and invul <= 0.0 and rpa.intersects(rj):
					_machuca(false, "passageiro")
			"carrinho":
				_anda(o, dt, 215.0)
				var rc := Rect2(o.p.x - 46, o.p.y - 62, 92, 62)
				if ativo and rc.intersects(rj):
					if vel.y > 0 and pos.y < rc.position.y + 18:
						_quica(PISAO_V + 80)
						Som.toca("mola", -3.0, 1.3)
					elif invul <= 0.0:
						_machuca(false, "carrinho")
			"calha":
				# solta uma mala quando o Milis vem chegando: ela cai na frente dele e rola na direção dele
				o.prox -= dt
				o.treme = maxf(0.0, float(o.get("treme", 0.0)) - dt)
				var dxp: float = (o.p.x - pos.x) * dir
				if o.prox <= 0.0 and ativo and dxp > 280.0 and dxp < 460.0 and absf(pos.y - o.p.y) < 420.0:
					o.prox = 1.5
					o.treme = 0.3
					novos.append({"t": "mala", "p": o.p + Vector2(0, 30), "vy": 0.0, "d": -dir, "chao": false,
						"cor": randi() % 4, "vida": 9.0})
			"mala":
				o.vida -= dt
				if not o.chao:
					o.vy = minf(o.vy + GRAV * dt, QUEDA_MAX)
					o.p.y += o.vy * dt
					var cx := int(floorf(o.p.x / T))
					var cy := int(floorf(o.p.y / T))
					if eh_solido(cx, cy):
						o.p.y = cy * T
						o.chao = true
						Som.toca("mala", -8.0)
				else:
					o.p.x += o.d * 130.0 * dt
					var cx2 := int(floorf((o.p.x + o.d * 24) / T))
					var cy2 := int(floorf((o.p.y - 10) / T))
					if eh_solido(cx2, cy2) or o.vida <= 0.0:
						o.morta = true
						_poof(o.p + Vector2(0, -18))
					elif not eh_solido(int(floorf(o.p.x / T)), int(floorf((o.p.y + 2) / T))):
						o.chao = false
						o.vy = 0.0
				var rm := Rect2(o.p.x - 22, o.p.y - 36, 44, 36)
				if ativo and not o.get("morta", false) and rm.intersects(rj):
					if vel.y > 0 and pos.y < rm.position.y + 16:
						o.morta = true
						_quica(PISAO_V)
						_poof(o.p + Vector2(0, -18))
						Som.toca("pisao")
					elif invul <= 0.0:
						_machuca(false, "mala caida=%s" % o.chao)
			"capanga":
				if o.get("ko", false):
					o.vy += GRAV * dt
					o.p += Vector2(o.kx, o.vy) * dt
				else:
					_anda(o, dt, float(o.v))
					var rcp := Rect2(o.p.x - 20, o.p.y - 84, 40, 84)
					if ativo and rcp.intersects(rj):
						if vel.y > 0 and pos.y < rcp.position.y + 22:
							o.ko = true
							o.vy = -420.0
							o.kx = dir * 120.0
							_quica(PISAO_V)
							Som.toca("pisao")
							_estrelas(o.p + Vector2(0, -90))
						elif invul <= 0.0:
							_machuca(false, "capanga")
			"mala_voa":
				if o.get("ko", false):
					o.vy += GRAV * dt
					o.p.y += o.vy * dt
				else:
					o.p.y = o.y0 + sin(t * 2.6 + o.fase) * 52.0
					var rv := Rect2(o.p.x - 26, o.p.y - 22, 52, 44)
					if ativo and rv.intersects(rj):
						if vel.y > 0 and pos.y < rv.position.y + 20:
							o.ko = true
							o.vy = -200.0
							_quica(PISAO_V)
							Som.toca("pisao")
							_estrelas(o.p)
						elif invul <= 0.0:
							_machuca(false, "mala voadora")
			"laser":
				var on := true
				if o.tipo == "pisca":
					var ciclo := fmod(t + o.fase, 2.6)
					on = ciclo < 1.1
					o.aviso = ciclo > 2.2
				o.on = on
				if on and ativo and invul <= 0.0 and (o.r as Rect2).grow_individual(-1, 0, -1, 0).intersects(rj.grow(-4)):
					_machuca(false, "laser " + str(o.tipo))
			"porta":
				var ciclo2 := fmod(t + o.fase, 3.6)
				var quer := 1.0 if ciclo2 < 1.7 else 0.0
				if quer < 0.5 and (o.r as Rect2).grow(6).intersects(rj):
					quer = 1.0
				o.abre = move_toward(o.abre, quer, dt * 4.5)
			"mola":
				o.aperta = maxf(0.0, o.aperta - dt * 4.0)
				var rmo := Rect2(o.p.x - 24, o.p.y - 26, 48, 26)
				if ativo and vel.y >= 0 and rmo.intersects(rj):
					pos.y = rmo.position.y
					vel.y = -MOLA_V
					pulos_ar = 1
					pulando = false
					estado = "ar"
					no_chao = false
					o.aperta = 1.0
					Som.toca("mola")
			"asas":
				if not o.get("pego", false) and ativo and centro.distance_to(o.p) < 44:
					o.pego = true
					pode_planar = true
					Som.toca("ok")
					_brilho(o.p)
					aviso_msg("Asas de avião! Segure o toque no ar para planar", 3.4)
			"dica":
				if not o.vista and ativo and absf(pos.x - o.p.x) < T * 1.2 and absf(pos.y - o.p.y) < T * 6:
					o.vista = true
					aviso_msg(o.txt, 3.2)
	objs.append_array(novos)
	objs = objs.filter(func(o): return not o.get("morta", false) and not (o.t == "capanga" and o.get("ko", false) and o.p.y > gh * T + 200))


func _quica(v: float) -> void:
	vel.y = -v
	pulos_ar = 1
	pulando = segurando
	estado = "ar"
	no_chao = false


func _anda(o: Dictionary, dt: float, v: float, cai_beira := false) -> void:
	if v <= 0.0:
		return
	var nx: float = o.p.x + o.d * v * dt
	var frente := int(floorf((nx + o.d * 22) / T))
	var cy := int(floorf((o.p.y - 10) / T))
	var piso := int(floorf((o.p.y + 4) / T))
	var bloqueia := eh_solido(frente, cy) or eh_solido(frente, cy - 1)
	if not bloqueia:
		for pt in portas:
			if float(pt.abre) < 0.5 and (pt.r as Rect2).has_point(Vector2(nx + o.d * 22, o.p.y - 20)):
				bloqueia = true
	var sem_chao := not eh_solido(frente, piso) and cel(frente, piso) != 61
	if o.has("x0") and absf(nx - float(o.x0)) > float(o.get("alcance", 160.0)):
		bloqueia = bloqueia or signf(nx - float(o.x0)) == float(o.d)
	if bloqueia or (sem_chao and not cai_beira):
		o.d = -o.d
	else:
		o.p.x = nx


# ------------------------------------------------------------------ efeitos
func aviso_msg(s: String, dur := 2.0) -> void:
	aviso = s
	t_aviso = dur


func _poeira(p: Vector2, n: int) -> void:
	for i in n:
		fx.append({"t": "poeira", "p": p + Vector2(randf_range(-12, 12), -4), "v": Vector2(randf_range(-60, 60), randf_range(-60, -20)), "vida": 0.4, "max": 0.4})


func _brilho(p: Vector2) -> void:
	for i in 6:
		var a := i * TAU / 6.0
		fx.append({"t": "brilho", "p": p, "v": Vector2(cos(a), sin(a)) * 140, "vida": 0.35, "max": 0.35})


func _poof(p: Vector2) -> void:
	for i in 7:
		var a := i * TAU / 7.0
		fx.append({"t": "poeira", "p": p, "v": Vector2(cos(a), sin(a)) * 90, "vida": 0.45, "max": 0.45})


func _estrelas(p: Vector2) -> void:
	for i in 5:
		var a := -PI / 2 + (i - 2) * 0.5
		fx.append({"t": "estrela", "p": p, "v": Vector2(cos(a), sin(a)) * 160, "vida": 0.6, "max": 0.6})


func _fx_anel(p: Vector2) -> void:
	fx.append({"t": "anel", "p": p, "v": Vector2.ZERO, "vida": 0.3, "max": 0.3})


func _fx_bonk(p: Vector2) -> void:
	fx.append({"t": "bonk", "p": p, "v": Vector2(0, -30), "vida": 0.4, "max": 0.4})


func _passo_fx(dt: float) -> void:
	for f in fx:
		f.vida -= dt
		f.p += f.v * dt
		if f.t == "poeira":
			f.v *= 0.9
	fx = fx.filter(func(f): return f.vida > 0)


# ------------------------------------------------------------------ câmera
func vis() -> Vector2:
	return tela / ZOOM


func _camera(dt: float) -> void:
	var v := vis()
	var alvo := pos + Vector2(dir * 150.0, -JH - v.y * 0.04)
	if estado == "parede":
		alvo = pos + Vector2(-dir * 60.0, -JH - 120)
	if estado == "caiu":
		alvo = cam
	var k := 1.0 - exp(-4.2 * dt)
	var ky := 1.0 - exp(-3.2 * dt)
	cam.x = lerpf(cam.x, alvo.x, k)
	cam.y = lerpf(cam.y, alvo.y, ky)
	cam.x = clampf(cam.x, v.x / 2, maxf(v.x / 2, gw * T - v.x / 2))
	cam.y = clampf(cam.y, v.y / 2 - T * 2, maxf(v.y / 2, gh * T - v.y / 2))
	mundo.scale = Vector2(ZOOM, ZOOM)
	mundo.position = (tela / 2 - cam * ZOOM).round()


# ------------------------------------------------------------------ desenho
func _desenha_fundo(ci: Node2D) -> void:
	var nome := "bg_" + fase.m("fundo", "terminal")
	var tx := Arte.t(nome)
	ci.draw_rect(Rect2(Vector2.ZERO, tela), Color("2b3446"))
	if tx == null:
		return
	var esc := tela.y * 1.12 / tx.get_height()
	var w := tx.get_width() * esc
	var h := tx.get_height() * esc
	var ox := -fmod(cam.x * ZOOM * 0.22, w * 2)
	var oy := -(h - tela.y) * clampf((cam.y - vis().y / 2) / maxf(1.0, gh * T - vis().y), 0.0, 1.0)
	var x := ox
	var i := 0
	while x < tela.x:
		var r := Rect2(x, oy, w, h)
		if i % 2 == 1:
			ci.draw_texture_rect(tx, Rect2(x + w, oy, -w, h), false)
		else:
			ci.draw_texture_rect(tx, r, false)
		x += w
		i += 1
	# véu para destacar o primeiro plano
	ci.draw_rect(Rect2(Vector2.ZERO, tela), Color(0.06, 0.08, 0.14, 0.22))


func _desenha_mundo(ci: Node2D) -> void:
	var v := vis()
	var x0 := maxi(0, int(floorf((cam.x - v.x / 2) / T)) - 1)
	var x1 := mini(gw - 1, int(floorf((cam.x + v.x / 2) / T)) + 1)
	var y0 := maxi(0, int(floorf((cam.y - v.y / 2) / T)) - 1)
	var y1 := mini(gh - 1, int(floorf((cam.y + v.y / 2) / T)) + 1)
	_desenha_ventos(ci)
	_desenha_grade(ci, x0, x1, y0, y1)
	for o in objs:
		if absf(o.p.x - cam.x) > v.x / 2 + 200 or absf(o.p.y - cam.y) > v.y / 2 + 300:
			continue
		_desenha_obj(ci, o)
	_desenha_jogador(ci)
	_desenha_fx(ci)


func _piso_tex() -> String:
	return "piso_" + fase.m("piso", "terminal")


func _parede_tex(c: int) -> String:
	match c:
		77:
			return "parede_metal"
		67:
			return "parede_concreto"
		87:
			return "parede_aderente"
	return "parede_" + fase.m("parede", "terminal")


func _desenha_grade(ci: Node2D, x0: int, x1: int, y0: int, y1: int) -> void:
	var piso := Arte.t(_piso_tex())
	var pw := float(piso.get_width()) if piso else 1.0
	var ph := float(piso.get_height()) if piso else 1.0
	var escuro := Color(0.1, 0.1, 0.13)
	# 1) enchimento
	for cy in range(y0, y1 + 1):
		for cx in range(x0, x1 + 1):
			var c := cel(cx, cy)
			if solido[c] == 0:
				continue
			var r := Rect2(cx * T, cy * T, T, T)
			if c == 75:
				continue
			var nome := _parede_tex(c)
			var tx := Arte.t(nome)
			if tx:
				var tw := tx.get_width()
				var th := tx.get_height()
				var src := Rect2(fposmod(cx * T * 2, tw), fposmod(cy * T * 2, th), 80, 80)
				ci.draw_texture_rect_region(tx, r, src)
	# 2) topo (piso), esteiras, chão molhado, caixotes
	for cy in range(y0, y1 + 1):
		for cx in range(x0, x1 + 1):
			var c := cel(cx, cy)
			if c == 75:
				Arte.caixa(ci, "caixote", Rect2(cx * T - 1, cy * T - 1, T + 2, T + 2))
				continue
			if c == 61:
				var viga := Arte.t("piso_viga")
				if viga:
					var vs := Rect2(fposmod(cx * T * 2, viga.get_width()), 0, 80, viga.get_height())
					ci.draw_texture_rect_region(viga, Rect2(cx * T, cy * T, T, 18), vs)
				continue
			if solido[c] == 0:
				continue
			var exposto_cima := not eh_solido(cx, cy - 1)
			if exposto_cima and c != 87:
				if piso:
					var src2 := Rect2(fposmod(cx * T * 2, pw), 0, 80, ph)
					ci.draw_texture_rect_region(piso, Rect2(cx * T, cy * T, T, ph * 0.5), src2)
				if c == 62 or c == 60:
					_desenha_esteira(ci, cx, cy, 1 if c == 62 else -1)
				elif c == 126:
					ci.draw_rect(Rect2(cx * T, cy * T + 1, T, 9), Color(0.55, 0.8, 1.0, 0.45))
					var brilho := fposmod(t * 40 + cx * 23, 60)
					if brilho < 30:
						ci.draw_line(Vector2(cx * T + brilho, cy * T + 4), Vector2(cx * T + brilho + 8, cy * T + 4), Color(1, 1, 1, 0.7), 2)
			elif exposto_cima and c == 87:
				ci.draw_rect(Rect2(cx * T, cy * T, T, 6), Color("2a8a52"))
	# 3) contornos laterais e sombra embaixo
	for cy in range(y0, y1 + 1):
		for cx in range(x0, x1 + 1):
			var c := cel(cx, cy)
			if solido[c] == 0 or c == 75:
				continue
			if not eh_solido(cx - 1, cy):
				ci.draw_rect(Rect2(cx * T, cy * T, 3, T), escuro)
			if not eh_solido(cx + 1, cy):
				ci.draw_rect(Rect2(cx * T + T - 3, cy * T, 3, T), escuro)
			if not eh_solido(cx, cy + 1) and cy + 1 < gh:
				ci.draw_rect(Rect2(cx * T, cy * T + T - 4, T, 4), escuro)
				ci.draw_rect(Rect2(cx * T, cy * T + T, T, 10), Color(0, 0, 0, 0.18))


func _desenha_esteira(ci: Node2D, cx: int, cy: int, d: int) -> void:
	var r := Rect2(cx * T, cy * T, T, 14)
	ci.draw_rect(r, Color("2e3138"))
	var passo := 20.0
	var off := fposmod(t * ESTEIRA_V * d, passo)
	var x := cx * T - passo + off
	while x < cx * T + T:
		var a := Vector2(x, cy * T + 3)
		var pts := PackedVector2Array([a, a + Vector2(6 * d, 4), a + Vector2(0, 8)])
		if x > cx * T and x < cx * T + T - 6:
			ci.draw_polyline(pts, Color("f2c230"), 2.0)
		x += passo
	ci.draw_rect(Rect2(cx * T, cy * T + 12, T, 3), Color("9aa3ad"))


func _desenha_ventos(ci: Node2D) -> void:
	for v in ventos:
		var r: Rect2 = v.r
		if absf(r.get_center().x - cam.x) > vis().x:
			continue
		for i in 6:
			var fx_ := r.position.x + 10 + i * (r.size.x - 20) / 5.0
			var yy := r.end.y - fposmod(t * 260 + i * 57, r.size.y)
			var a := 0.35 * clampf((yy - r.position.y) / 60.0, 0, 1)
			ci.draw_line(Vector2(fx_, yy), Vector2(fx_, yy - 34), Color(0.85, 0.95, 1.0, a), 3)


func _desenha_obj(ci: Node2D, o: Dictionary) -> void:
	match o.t:
		"milha":
			if o.get("pego", false):
				return
			if o.get("cartao", false):
				Arte.quadro(ci, "cartao", 0, o.p + Vector2(0, sin(t * 3) * 4), false, 0.8)
			else:
				var esc := absf(cos(t * 3.0 + o.p.x * 0.01))
				Arte.quadro(ci, moeda, 0, o.p, false, 1.0, Color.WHITE, 0.0, maxf(0.2, esc))
		"totem":
			Arte.quadro(ci, "totem", 1 if o.ativo else 0, o.p, false, 0.98)
		"portao":
			_desenha_portao(ci, o)
		"pass":
			var nome := "passageiro%d" % int(o["var"])
			var bob := absf(sin(t * 7.0 + o.p.x)) * 3.0 if float(o.v) > 0 else 0.0
			Arte.quadro(ci, nome, int(t * 5.0) if float(o.v) > 0 else 0, o.p + Vector2(0, -bob), o.d < 0)
		"carrinho":
			var tremor := Vector2(0, sin(t * 40) * 1.2)
			Arte.quadro(ci, "carrinho", 0, o.p + tremor, o.d < 0)
		"calha":
			var tr := Vector2(sin(t * 60) * 2.0, 0) if float(o.get("treme", 0.0)) > 0 else Vector2.ZERO
			var r := Rect2(o.p.x - 30 + tr.x, o.p.y, 60, 22)
			ci.draw_rect(r, Color("3a3f48"))
			ci.draw_rect(Rect2(r.position.x + 6, r.position.y + 6, 48, 16), Color("15171c"))
			for i in 5:
				ci.draw_line(Vector2(r.position.x + 10 + i * 10, r.position.y + 8), Vector2(r.position.x + 10 + i * 10, r.end.y + 6), Color("2b2e35"), 4)
		"mala":
			Arte.quadro(ci, "malas", int(o.cor), o.p + Vector2(0, -18), o.d < 0, 0.95)
		"capanga":
			var tipo: String = o.tipo
			var vira: bool = o.d > 0           # os capangas foram desenhados olhando para a esquerda
			if o.get("ko", false):
				Arte.quadro(ci, tipo + "_ko", 0, o.p, vira, 1.0, Color.WHITE, o.vy * 0.0006)
			else:
				Arte.anim(ci, tipo + "_anda", t, o.p, vira)
		"mala_voa":
			if o.get("ko", false):
				Arte.quadro(ci, "mala_tonta", 0, o.p, false, 1.0, Color.WHITE, t * 6)
			else:
				Arte.anim(ci, "mala_voa", t, o.p, false)
		"laser":
			_desenha_laser(ci, o)
		"porta":
			_desenha_porta(ci, o)
		"vento":
			Arte.quadro(ci, "ventilador", 0, o.p + Vector2(0, 2))
		"mola":
			var k := 1.0 - 0.3 * float(o.aperta)
			Arte.quadro(ci, "mola", 0, o.p, false, 0.85, Color.WHITE, 0.0, 1.0, k)
		"asas":
			if not o.get("pego", false):
				var halo := 0.5 + 0.5 * sin(t * 4)
				ci.draw_circle(o.p, 40 + halo * 6, Color(1, 0.9, 0.4, 0.22))
				Arte.quadro(ci, "asas", 0, o.p + Vector2(0, sin(t * 3) * 5), false, 1.3)
		"placa":
			Arte.quadro(ci, "placa_molhado", 0, o.p, false, 0.9)


func _desenha_portao(ci: Node2D, o: Dictionary) -> void:
	var p: Vector2 = o.p
	Arte.quadro(ci, "porta_saida", 1 if o.aberto > 0.5 else 0, p, false, 0.98)
	# placa do portão
	var num := fase.m("portao", "1")
	var r := Rect2(p.x - 62, p.y - 176, 124, 40)
	ci.draw_rect(r, Color("1c1f26"))
	ci.draw_rect(r, Color("f2c230"), false, 3)
	Arte.texto(ci, "PORTÃO " + num, Vector2(r.position.x, r.position.y + 30), 24, Color("f2c230"), HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 0)
	var seta_x := p.x - 90 + sin(t * 5) * 6
	if situacao == "jogando":
		Arte.quadro(ci, "seta", 0, Vector2(seta_x, p.y - 60), false, 0.9)


func _desenha_laser(ci: Node2D, o: Dictionary) -> void:
	var r: Rect2 = o.r
	var on: bool = o.get("on", true)
	if on:
		var pulsa := 0.6 + 0.4 * sin(t * 30)
		ci.draw_rect(r.grow_individual(4, 0, 4, 0), Color(1, 0.15, 0.1, 0.25 * pulsa))
		ci.draw_rect(r, Color(1, 0.2, 0.15, 0.85))
		ci.draw_rect(Rect2(r.get_center().x - 1, r.position.y, 2, r.size.y), Color(1, 0.85, 0.8))
	elif o.get("aviso", false) and fmod(t, 0.16) < 0.08:
		ci.draw_rect(Rect2(r.get_center().x - 1, r.position.y, 2, r.size.y), Color(1, 0.3, 0.2, 0.5))
	match o.tipo:
		"chao":
			Arte.quadro(ci, "laser_receptor", 0, Vector2(r.get_center().x, r.end.y + 4), false, 0.9)
			Arte.quadro(ci, "laser_emissor", 0, Vector2(r.get_center().x, r.position.y - 14), false, 0.6)
		"teto":
			Arte.quadro(ci, "laser_emissor", 0, Vector2(r.get_center().x, r.position.y - 4), false, 0.9)
			if on:
				ci.draw_circle(Vector2(r.get_center().x, r.end.y), 7, Color(1, 0.4, 0.3, 0.8))
		"pisca":
			Arte.quadro(ci, "laser_emissor", 0, Vector2(r.get_center().x, r.position.y - 4), false, 0.9)
			Arte.quadro(ci, "laser_receptor", 0, Vector2(r.get_center().x, r.end.y + 4), false, 0.9)


func _desenha_porta(ci: Node2D, o: Dictionary) -> void:
	var r: Rect2 = o.r
	var ab: float = o.abre
	var meia := 22.0
	var h := r.size.y
	# trilho
	ci.draw_rect(Rect2(r.position.x - 26, r.position.y, 72, 8), Color("5b636f"))
	var desl := ab * 40.0
	Arte.caixa(ci, "porta_vidro", Rect2(r.get_center().x - meia - desl, r.position.y + 6, meia, h - 6))
	Arte.caixa(ci, "porta_vidro", Rect2(r.get_center().x + desl, r.position.y + 6, meia, h - 6))
	Arte.quadro(ci, "porta_sensor", 0 if ab > 0.5 else 1, Vector2(r.get_center().x, r.position.y + 2), false, 0.9)


func _desenha_jogador(ci: Node2D) -> void:
	if situacao == "fim" and estado != "caiu":
		pass
	var p := pos
	var vira := dir < 0
	var mod := Color.WHITE
	if invul > 0.0 and fmod(invul, 0.2) < 0.1:
		mod = Color(1, 1, 1, 0.45)
	if situacao == "pronto":
		Arte.anim(ci, "milis_parado", t_anim, p, vira)
		return
	if situacao == "embarcando":
		Arte.anim(ci, "milis_festa" if t_sit > 0.5 else "milis_corre", t_anim, p, vira)
		return
	if situacao == "perdeu":
		Arte.quadro(ci, "milis_sentado", 0, p, vira)
		return
	match estado:
		"caiu":
			Arte.quadro(ci, "milis_tonto", 0, p, vira, 1.0, mod, t_caiu * 8.0 * -dir)
		"parede":
			var rot := -PI / 2 if dir > 0 else PI / 2
			Arte.anim(ci, "milis_corre", t_anim * 1.2, p + Vector2(dir * (JW / 2 + 6), -JH * 0.45), vira, 1.0, mod, rot)
		"ar":
			if planando:
				Arte.anim(ci, "milis_plana", t_anim, p, vira, 1.0, mod)
			elif t_duplo < 0.35:
				Arte.quadro(ci, "milis_duplo", int(t_duplo * 8), p, vira, 1.0, mod, t_duplo * 18.0 * dir)
			elif vel.y < 120:
				Arte.quadro(ci, "milis_sobe", 0, p, vira, 1.0, mod)
			else:
				Arte.quadro(ci, "milis_cai", 0, p, vira, 1.0, mod)
		_:
			var vk := absf(vel.x) / CORRE
			var incl := 0.0
			if sup == 126:
				incl = 0.12 * dir
			Arte.anim(ci, "milis_corre", t_anim * vk, p, vira, 1.0, mod, incl)


func _desenha_fx(ci: Node2D) -> void:
	for f in fx:
		var k: float = f.vida / f.max
		match f.t:
			"poeira":
				ci.draw_circle(f.p, 6 + (1 - k) * 8, Color(0.92, 0.9, 0.85, 0.5 * k))
			"brilho":
				ci.draw_circle(f.p, 4 * k + 1, Color(1, 0.95, 0.5, k))
			"estrela":
				_estrela(ci, f.p, 9 * k + 3, Color(1, 0.85, 0.2, k))
			"anel":
				ci.draw_arc(f.p, 30 * (1 - k) + 10, 0, TAU, 24, Color(1, 1, 1, k * 0.8), 3)
			"bonk":
				Arte.texto(ci, "!", f.p, 34, Color(1, 0.9, 0.3, k), HORIZONTAL_ALIGNMENT_LEFT, -1, 5)


func _estrela(ci: Node2D, c: Vector2, r: float, cor: Color) -> void:
	var pts := PackedVector2Array()
	for i in 10:
		var a := -PI / 2 + i * PI / 5
		var rr := r if i % 2 == 0 else r * 0.45
		pts.append(c + Vector2(cos(a), sin(a)) * rr)
	ci.draw_colored_polygon(pts, cor)


# ------------------------------------------------------------------ HUD
func _pilula(ci: Node2D, r: Rect2, cor: Color) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = cor
	sb.set_corner_radius_all(int(r.size.y / 2))
	sb.border_color = Color(0, 0, 0, 0.35)
	sb.set_border_width_all(3)
	ci.draw_style_box(sb, r)


func _desenha_hud(ci: Node2D) -> void:
	var W := tela.x
	# barra de cima
	ci.draw_rect(Rect2(0, 0, W, 92), Color(0.05, 0.07, 0.12, 0.35))
	# pausa
	_pilula(ci, r_pausa, Color(0.1, 0.13, 0.2, 0.85))
	ci.draw_rect(Rect2(r_pausa.position.x + 22, r_pausa.position.y + 19, 7, 26), Arte.BRANCO)
	ci.draw_rect(Rect2(r_pausa.position.x + 35, r_pausa.position.y + 19, 7, 26), Arte.BRANCO)
	# relógio do embarque
	var s := maxi(0, int(ceilf(tempo_rest)))
	var txt := "%d:%02d" % [s / 60, s % 60]
	var cor := Color(0.1, 0.13, 0.2, 0.88)
	var urg := tempo_rest <= 10.0 and situacao == "jogando"
	if urg:
		cor = Color(0.75, 0.12, 0.1, 0.92) if fmod(t, 0.5) < 0.25 else Color(0.5, 0.08, 0.06, 0.92)
	var rr := Rect2(W / 2 - 92, 12, 184, 68)
	_pilula(ci, rr, cor)
	Arte.texto(ci, "EMBARQUE FECHA EM", Vector2(rr.position.x, rr.position.y + 22), 15, Color(1, 0.85, 0.4), HORIZONTAL_ALIGNMENT_CENTER, rr.size.x, 0, Color.BLACK, Arte.fonte)
	Arte.texto(ci, txt, Vector2(rr.position.x, rr.position.y + 60), 40, Arte.BRANCO, HORIZONTAL_ALIGNMENT_CENTER, rr.size.x, 0)
	# milhas
	var rm := Rect2(W - 160, 16, 150, 60)
	_pilula(ci, rm, Color(0.1, 0.13, 0.2, 0.88))
	Arte.quadro(ci, moeda, 0, Vector2(rm.position.x + 30, rm.position.y + 30), false, 0.8)
	Arte.texto(ci, "%d/%d" % [milhas, total], Vector2(rm.position.x + 54, rm.position.y + 42), 26, Arte.BRANCO, HORIZONTAL_ALIGNMENT_LEFT, -1, 0)
	# voo
	Arte.texto(ci, "%s · %s" % [fase.m("voo", ""), fase.m("nome", "")], Vector2(0, 112), 17, Color(1, 1, 1, 0.9), HORIZONTAL_ALIGNMENT_CENTER, W, 5, Color(0, 0, 0, 0.7), Arte.fonte)
	# aviso
	if t_aviso > 0.0 and aviso != "":
		var a := clampf(t_aviso / 0.3, 0, 1)
		var f: Font = Arte.fonte
		var linhas := _quebra(aviso, f, 22, W - 90)
		var hh := 24 + linhas.size() * 30
		var ra := Rect2(30, tela.y * 0.2, W - 60, hh)
		_pilula(ci, Rect2(ra.position, ra.size), Color(0.07, 0.3, 0.17, 0.9 * a))
		for i in linhas.size():
			Arte.texto(ci, linhas[i], Vector2(ra.position.x, ra.position.y + 36 + i * 30), 22, Color(1, 1, 1, a), HORIZONTAL_ALIGNMENT_CENTER, ra.size.x, 0, Color.BLACK, f)
	# começo
	if situacao == "pronto":
		var k := clampf(t_sit / 0.4, 0, 1)
		Arte.texto(ci, "PRONTO?", Vector2(0, tela.y * 0.42), 64, Color(1, 0.9, 0.4, k), HORIZONTAL_ALIGNMENT_CENTER, W, 10)
		Arte.texto(ci, "Toque na tela para pular", Vector2(0, tela.y * 0.42 + 50), 24, Color(1, 1, 1, k), HORIZONTAL_ALIGNMENT_CENTER, W, 6, Color(0, 0, 0, 0.8), Arte.fonte)
	elif situacao == "jogando" and t_sit < 0.8:
		var k2 := 1.0 - t_sit / 0.8
		Arte.texto(ci, "VAI!", Vector2(0, tela.y * 0.42), int(64 + (1 - k2) * 30), Color(0.6, 1, 0.6, k2), HORIZONTAL_ALIGNMENT_CENTER, W, 10)
	elif situacao == "perdeu":
		var k3 := clampf(t_sit / 0.4, 0, 1)
		ci.draw_rect(Rect2(Vector2.ZERO, tela), Color(0.2, 0, 0, 0.35 * k3))
		Arte.texto(ci, "PORTÃO FECHADO!", Vector2(0, tela.y * 0.42), 50, Color(1, 0.5, 0.4, k3), HORIZONTAL_ALIGNMENT_CENTER, W, 10)
	elif situacao == "embarcando":
		Arte.texto(ci, "EMBARCOU!", Vector2(0, tela.y * 0.4), 60, Color(0.6, 1, 0.6), HORIZONTAL_ALIGNMENT_CENTER, W, 10)
	if fade > 0.0:
		ci.draw_rect(Rect2(Vector2.ZERO, tela), Color(0, 0, 0, fade))


func _quebra(s: String, f: Font, tam: int, larg: float) -> PackedStringArray:
	var res := PackedStringArray()
	var linha := ""
	for p in s.split(" "):
		var teste := p if linha == "" else linha + " " + p
		if f.get_string_size(teste, HORIZONTAL_ALIGNMENT_LEFT, -1, tam).x > larg and linha != "":
			res.append(linha)
			linha = p
		else:
			linha = teste
	if linha != "":
		res.append(linha)
	return res
