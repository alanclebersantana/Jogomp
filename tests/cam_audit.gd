extends "res://tests/route_gru.gd"
## Auditoria da câmera na 1-1: o robô de teste percorre a fase e, a cada quadro, confere o que o
## jogador enxerga num celular deitado (tela 20:9 = 1200x540, câmera do aeroporto 1,25x → 960x432 do
## mundo). Marca: Milis embaixo do HUD/fora da tela, Milis atrás dos botões, fio/capanga/mala presa
## perto mas fora da tela, pouca visão para a frente. Uso: godot --headless --path . -s tests/cam_audit.gd -- 1
var VW := 960.0
var VH := 432.0
var HUD_TOP := 44.0            # barra de vidas/milhas e o cartão da fase
var BTN_W := 210.0             # botões da direita (canto de baixo)
var BTN_H := 200.0
var ZM := 1.25
var AUD := {}
var NF := 0

func frame(set: Dictionary = {}) -> void:
	if g:
		# o mesmo zoom do main.gd (sem a suavização): 1,25 normal, abre para o alto, arena, Fiscal
		var zt := 1.25
		zt = min(zt, g.aero_up_zoom(540.0))
		if g.ARN and not g.ARN.active().is_empty():
			zt = min(zt, 1.08)
		if g.X and g.X.boss_active() and g.X.BOSS.get("skin", "") == "fiscal":
			zt = 1200.0 / 1280.0
		ZM = lerpf(ZM, zt, .03 if zt < ZM else .02)
		VW = 1200.0 / ZM
		VH = 540.0 / ZM
		HUD_TOP = 55.0 / ZM
		BTN_W = 262.0 / ZM
		BTN_H = 250.0 / ZM
		g.W = VW
		g.H = VH
	super.frame(set)
	_aud()

func _mark(kind: String, x: float, info: String = "") -> void:
	var b := int(x / 100.0) * 100
	var k := kind + "|" + str(b)
	if not AUD.has(k):
		AUD[k] = {"n": 0, "info": info}
	AUD[k].n += 1

func _vis(x: float, y: float, m: float = 0.0) -> bool:
	return x > g.cam + m and x < g.cam + VW - m and y > g.cam_y + HUD_TOP and y < g.cam_y + VH - m

func _aud() -> void:
	if g == null or not g.running or not g.CINE.is_empty():
		return
	NF += 1
	var p: Dictionary = g.player
	var px: float = p.x + p.w / 2
	var sx: float = p.x - g.cam
	var head: float = p.y - g.cam_y
	var feet: float = p.y + p.h - g.cam_y
	if head < HUD_TOP - 6:
		_mark("milis_no_alto_(HUD)", px, "cabeça a %d px do topo" % int(head))
	if feet > VH - 6:
		_mark("milis_no_pe_da_tela", px, "pés a %d px do fundo" % int(VH - feet))
	if sx + p.w > VW - BTN_W and feet > VH - BTN_H:
		_mark("milis_atras_dos_botoes", px)
	if sx < 0 or sx + p.w > VW:
		_mark("milis_fora_dos_lados", px)
	# visão para a frente (andando/correndo)
	if abs(p.vx) > 2.0 and p.onGround:
		var frac: float = (px - g.cam) / VW
		if (p.vx > 0 and frac > .62) or (p.vx < 0 and frac < .38):
			_mark("pouca_visao_a_frente", px, "Milis a %d%% da tela" % int(frac * 100))
	# fios perto: a ponta e o meio do fio precisam aparecer
	for v in g.VINES:
		if abs(v.x - px) < 330:
			var th: float = float(v.get("th", 0.0))
			var tip := Vector2(v.x + sin(th) * float(v.len), v.y + cos(th) * float(v.len))
			var mid := Vector2(v.x + sin(th) * float(v.len) * .5, v.y + cos(th) * float(v.len) * .5)
			if not _vis(tip.x, tip.y):
				_mark("ponta_do_fio_fora", px, "fio x=%d" % int(v.x))
			if not _vis(mid.x, mid.y):
				_mark("meio_do_fio_fora", px, "fio x=%d" % int(v.x))
	# capangas perto e vivos
	for e in g.EN:
		if e.dead:
			continue
		if abs(e.x - px) < 360 and abs(e.y - p.y) < 500:
			if not _vis(e.x, e.y - 20.0):
				_mark("capanga_perto_fora", px, "%s x=%d y=%d" % [e.k, int(e.x), int(e.y)])
	# malas presas (gancho) e ímãs
	if g.GD:
		for s in g.GD.STUCK:
			if int(s.get("st", 0)) == 0 and abs(float(s.x) - px) < 260 and not _vis(float(s.x), float(s.y)):
				_mark("mala_presa_fora", px, "x=%d y=%d" % [int(s.x), int(s.y)])
	for a in g.L.get("anchors", []):
		if abs(float(a.x) - px) < 260 and not _vis(float(a.x), float(a.y)):
			_mark("ima_fora", px, "x=%d y=%d" % [int(a.x), int(a.y)])
	# caixas e moedas logo acima (o que dá para pegar e não aparece)
	for c in g.L.coins:
		if abs(c[0] - px) < 140 and c[1] < p.y and p.y - c[1] < 300 and not _vis(c[0], c[1]):
			_mark("milhas_acima_fora", px, "y=%d" % int(c[1]))

func _initialize() -> void:
	carregar(0, false)
	fase_1_1()
	var keys := AUD.keys()
	keys.sort_custom(func(a, b): return AUD[a].n > AUD[b].n)
	print("quadros auditados: ", NF)
	var tipos := {}
	for k in keys:
		var t: String = k.split("|")[0]
		tipos[t] = tipos.get(t, 0) + AUD[k].n
	for t in tipos:
		print("TIPO ", t, ": ", tipos[t], " quadros")
	for k in keys:
		if AUD[k].n >= 8:
			print("  ", k, "  x", AUD[k].n, "  ", AUD[k].info)
	quit()
