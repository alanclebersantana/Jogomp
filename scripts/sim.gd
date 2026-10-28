class_name Sim
extends RefCounted
## Simulação da fase (sem desenho): física do mascote, guarda, obstáculos, milhas, tempo.
## Unidades em metros: x = corrida, y = altura, z = faixa (só no trecho de trás).
## A tela lê o estado e os "eventos" (sons, avisos, dicas) a cada quadro.

var F: Dictionary
var solidos: Array = []
var perigos: Array = []
var molas: Array = []
var milhas: Array = []
var mala: Dictionary = {}
var eventos: Array = []   # [tipo, valor]

var px := 0.0
var py := 0.0
var pz := 0.0
var vx := 0.0
var vy := 0.0
var no_chao := true
var coyote := 0.0
var buffer := 0.0
var faixa := 0
var rolar_t := 0.0
var dash_t := 0.0
var dash_cd := 0.0
var mergulho := false
var planando := false
var tropeco_t := 0.0
var invuln := 0.0
var guarda := Regras.GUARDA_INI
var tempo := 100.0
var n_milhas := 0
var achou_mala := false
var tropecos := 0
var sobre = null
var ultima_dica := -1
var fim := ""
var intro := 0.0
var t_alarme := 0.0
var hold := false
var t := 0.0
var bot := false
var deus := false


func _init(fase: Dictionary, x_inicio := 0.0, com_intro := true) -> void:
	F = fase
	for s in F["solidos"]:
		var o: Dictionary = s.duplicate()
		o["x0"] = float(s["x"]) - float(s["w"]) / 2.0
		o["x1"] = float(s["x"]) + float(s["w"]) / 2.0
		o["fantasma"] = false
		o["rampa"] = float(s.get("rampa", 0.0))
		o["esteira"] = float(s.get("esteira", 0.0))
		solidos.append(o)
	for p in F["perigos"]:
		var o: Dictionary = p.duplicate()
		o["x0i"] = float(p["x"])
		o["vx"] = float(p.get("vx", 0.0))
		o["ativa"] = float(p.get("ativa", 25.0))
		o["ativo"] = false
		o["usado"] = false
		o["morto"] = 0.0
		o["alarme"] = 0.0
		perigos.append(o)
	for m in F["molas"]:
		molas.append({"x": float(m["x"]), "y": float(m["y"]), "forca": float(m["forca"]), "anim": 0.0})
	for m in F["milhas"]:
		milhas.append({"x": float(m[0]), "y": float(m[1]), "z": float(m[2]), "pega": false, "anim": 0.0})
	if F.get("mala_dourada") != null:
		var md: Array = F["mala_dourada"]
		mala = {"x": float(md[0]), "y": float(md[1]), "z": float(md[2]), "pega": false}
	tempo = float(F["tempo"])
	px = x_inicio
	if x_inicio > 0.0:
		var s = suporte(px, 0.0, 10.0)
		py = s["y"] if s != null else 0.0
	intro = 1.6 if com_intro else 0.0


func ev(tipo: String, valor = null) -> void:
	eventos.append([tipo, valor])


func z_overlap(z: float, a: float, d: float) -> bool:
	return absf(z - a) < d / 2.0 + Regras.MEIO - 0.05


func topo_solido(s: Dictionary, x: float) -> float:
	if s["rampa"] > 0.0 and x < s["x0"] + s["rampa"]:
		return float(s["y"]) + float(s["h"]) * clampf((x - s["x0"]) / s["rampa"], 0.0, 1.0)
	return float(s["y"]) + float(s["h"])


## Maior superfície com topo <= max_topo sob (x, z). Retorna null ou {"y", "o"}.
func suporte(x: float, z: float, max_topo: float):
	var best = null
	for c in F["chao"]:
		if x >= c["x0"] and x <= c["x1"] and c["y"] <= max_topo and (best == null or c["y"] > best["y"]):
			best = {"y": float(c["y"]), "o": null}
	for p in F["plataformas"]:
		if x >= p["x0"] - 0.15 and x <= p["x1"] + 0.15 and p["y"] <= max_topo and (best == null or p["y"] > best["y"]):
			best = {"y": float(p["y"]), "o": null}
	for s in solidos:
		if s["fantasma"] or x < s["x0"] - 0.15 or x > s["x1"] + 0.15 or not z_overlap(z, s["z"], s["d"]):
			continue
		var tp := topo_solido(s, clampf(x, s["x0"], s["x1"]))
		if tp <= max_topo and (best == null or tp > best["y"]):
			best = {"y": tp, "o": s}
	return best


func na_zona_tras(x: float) -> bool:
	for z in F["zonas_tras"]:
		if x >= z["x0"] and x <= z["x1"]:
			return true
	return false


func acao(a: String) -> void:
	if fim != "" or intro > 0.0:
		return
	var tr := na_zona_tras(px)
	match a:
		"cima":
			buffer = Regras.BUFFER
		"baixo":
			if no_chao:
				rolar_t = Regras.ROLAR_T
				ev("som", "rolar")
			else:
				vy = minf(vy, Regras.MERGULHO)
				mergulho = true
				planando = false
				ev("som", "mergulho")
		"dir":
			if tr:
				mudar_faixa(1)
			else:
				dash()
		"esq":
			if tr:
				mudar_faixa(-1)
		"dash":
			dash()


func mudar_faixa(d: int) -> void:
	var n := clampi(faixa + d, -1, 1)
	if n != faixa:
		faixa = n
		ev("som", "faixa")


func dash() -> void:
	if dash_cd > 0.0:
		return
	dash_t = Regras.DASH_T
	dash_cd = Regras.DASH_CD
	ev("som", "dash")


func tropecar(tipo: String, msg := "") -> bool:
	if invuln > 0.0 or deus:
		return false
	tropeco_t = Regras.TROPECO_T
	invuln = Regras.INVULN
	guarda -= Regras.PEN.get(tipo, 4.0)
	tropecos += 1
	rolar_t = 0.0
	dash_t = 0.0
	ev("som", "tropeco")
	ev("tremer", 0.35)
	ev("flash")
	if msg != "":
		ev("aviso", msg)
	if guarda <= 0.0:
		acabar("pego")
	return true


func acabar(tipo: String) -> void:
	if fim != "":
		return
	fim = tipo
	hold = false
	ev("fim", tipo)


func passo(dt: float) -> void:
	t += dt
	if fim != "":
		return
	if intro > 0.0:
		intro -= dt
		if intro <= 0.0:
			ev("aviso", "CORRE!")
			ev("som", "apito")
		return
	var tr := na_zona_tras(px)
	var alvo := Regras.VEL
	var molhado := false
	if no_chao:
		for z in F["zonas"]:
			if px >= z["x0"] and px <= z["x1"] and absf(float(z.get("y", 0.0)) - py) < 0.3:
				if z["tipo"] == "esteira":
					alvo += float(z["boost"])
				elif z["tipo"] == "molhado":
					molhado = true
					alvo += 2.5
		if sobre != null and sobre["esteira"] > 0.0:
			alvo += sobre["esteira"]
	if dash_t > 0.0:
		alvo += Regras.DASH
	if tropeco_t > 0.0:
		alvo = Regras.TROPECO_VEL
	vx += clampf(alvo - vx, -Regras.ACEL * 3.0 * dt, Regras.ACEL * dt)
	if tropeco_t > 0.0:
		vx = minf(vx, Regras.TROPECO_VEL + 1.0)
	px += vx * dt
	var z_alvo := faixa * Regras.FAIXA if tr else 0.0
	if not tr:
		faixa = 0
	pz += clampf(z_alvo - pz, -Regras.TROCA * dt, Regras.TROCA * dt)
	rolar_t = maxf(0.0, rolar_t - dt)
	dash_t = maxf(0.0, dash_t - dt)
	dash_cd = maxf(0.0, dash_cd - dt)
	tropeco_t = maxf(0.0, tropeco_t - dt)
	invuln = maxf(0.0, invuln - dt)
	buffer = maxf(0.0, buffer - dt)
	coyote = Regras.COYOTE if no_chao else maxf(0.0, coyote - dt)
	if molhado:
		rolar_t = maxf(rolar_t, 0.12)
	if buffer > 0.0 and (no_chao or coyote > 0.0):
		vy = Regras.PULO
		no_chao = false
		coyote = 0.0
		buffer = 0.0
		rolar_t = 0.0
		mergulho = false
		ev("som", "pulo")
	var y_ant := py
	if not no_chao:
		var g := Regras.G
		planando = false
		if hold and vy < 0.0 and not mergulho:
			g *= Regras.PLANAR_G
			planando = true
		vy -= g * dt
		if planando:
			vy = maxf(vy, Regras.PLANAR_VY)
		py += vy * dt
	if no_chao:
		var s = suporte(px, pz, py + Regras.PASSO_RAMPA)
		if s != null and s["y"] >= py - 0.35:
			py = s["y"]
			sobre = s["o"]
		else:
			no_chao = false
			vy = 0.0
			sobre = null
	elif vy <= 0.0:
		var s = suporte(px, pz, y_ant + 0.02)
		if s != null and py <= s["y"]:
			py = s["y"]
			vy = 0.0
			no_chao = true
			planando = false
			sobre = s["o"]
			if mergulho:
				mergulho = false
				rolar_t = Regras.ROLAR_T
				ev("tremer", 0.12)
			ev("som", "pouso")
	for m in molas:
		m["anim"] = maxf(0.0, m["anim"] - dt)
		if absf(px - m["x"]) < 0.75 and py - m["y"] < 0.7 and py - m["y"] > -0.3 and vy <= 0.0 and absf(pz) < 0.9:
			vy = m["forca"]
			no_chao = false
			mergulho = false
			m["anim"] = 0.4
			ev("som", "mola")
	if py < -12.0:
		py = 0.5
		vy = 0.0
		tropecar("solido")
	var alt := Regras.ALT_ROLA if rolar_t > 0.0 else Regras.ALT
	for s in solidos:
		if s["fantasma"] or not z_overlap(pz, s["z"], s["d"]):
			continue
		if px + Regras.MEIO < s["x0"] or px - Regras.MEIO > s["x1"]:
			continue
		var topo := topo_solido(s, clampf(px + Regras.MEIO, s["x0"], s["x1"]))
		var tol := Regras.PASSO_RAMPA if s["rampa"] > 0.0 else Regras.PASSO
		if py >= topo - tol:
			continue
		if py + alt <= s["y"]:
			continue
		if s["rampa"] > 0.0 and px < s["x0"] + s["rampa"]:
			continue
		tropecar("solido", "Opa!")
		s["fantasma"] = true
	for p in perigos:
		if p["alarme"] > 0.0:
			p["alarme"] = maxf(0.0, p["alarme"] - dt)
		if p["morto"] > 0.0:
			p["morto"] = minf(2.0, p["morto"] + dt * 3.0)
		if not p["ativo"] and p["vx"] != 0.0 and p["x"] - px < p["ativa"]:
			p["ativo"] = true
		if p["ativo"] and p["vx"] != 0.0 and p["morto"] == 0.0:
			p["x"] += p["vx"] * dt
		if p["usado"] or not z_overlap(pz, p["z"], p["d"]):
			continue
		var hx: float = p["w"] / 2.0
		if px + Regras.MEIO < p["x"] - hx or px - Regras.MEIO > p["x"] + hx:
			continue
		if py + alt <= p["y0"] or py >= p["y1"]:
			continue
		match p["tipo"]:
			"pessoa":
				if vy < 0.0 and py > p["y1"] - 0.55:
					vy = 12.0
					no_chao = false
					mergulho = false
					p["usado"] = true
					p["morto"] = 1.0
					ev("som", "pisao")
					ev("aviso", "Desculpa!")
				elif tropecar("pessoa", "Com licença!"):
					p["usado"] = true
					p["morto"] = 1.0
			"detector":
				p["usado"] = true
				p["alarme"] = 1.2
				if rolar_t > 0.0:
					ev("aviso", "Liberado!")
					ev("som", "ok")
				else:
					if not deus:
						guarda -= Regras.PEN["detector"]
						t_alarme = 1.2
					ev("som", "alarme")
					ev("aviso", "BIP BIP BIP!")
					ev("flash")
					if guarda <= 0.0:
						acabar("pego")
			_:
				if tropecar("trem" if p["tipo"] == "trem" else "placa", "Trem!" if p["tipo"] == "trem" else "Ai!"):
					p["usado"] = true
	var cy := py + 0.75
	for m in milhas:
		if m["pega"]:
			m["anim"] = minf(1.0, m["anim"] + dt * 5.0)
			continue
		var dx: float = m["x"] - px
		if dx > 1.0 or dx < -1.0:
			continue
		if absf(m["y"] - cy) < 0.95 and absf(m["z"] - pz) < 0.7:
			m["pega"] = true
			n_milhas += 1
			ev("som", "milha")
	if not mala.is_empty() and not mala["pega"] and absf(mala["x"] - px) < 0.9 and absf(mala["y"] - cy) < 1.1:
		mala["pega"] = true
		achou_mala = true
		ev("aviso", "Mala dourada! ★")
		ev("som", "mala")
	if tropeco_t <= 0.0:
		guarda = minf(Regras.GUARDA_MAX, guarda + Regras.GUARDA_REC * dt)
	t_alarme = maxf(0.0, t_alarme - dt)
	tempo -= dt
	if tempo <= 0.0:
		tempo = 0.0
		acabar("voo")
	var dicas: Array = F["dicas"]
	for i in dicas.size():
		if i > ultima_dica and px >= dicas[i]["x"]:
			ultima_dica = i
			ev("dica", dicas[i]["texto"])
	if px >= F["fim"]:
		acabar("venceu")
	if bot:
		_bot()


# ------------------------------------------------------------------ robô de teste
func _bot() -> void:
	var look := vx * 0.3 + 0.9
	if na_zona_tras(px):
		var melhor := faixa
		var md := -INF
		for f in [-1, 0, 1]:
			var d := _bloqueio(f * Regras.FAIXA, px - 1.0, px + 26.0) - absi(f - faixa) * 2.0 + (1.0 if f == faixa else 0.0)
			if d > md:
				md = d
				melhor = f
		if melhor != faixa and absf(pz - faixa * Regras.FAIXA) < 0.3:
			mudar_faixa(signi(melhor - faixa))
	var pular := false
	var rolar := false
	for s in solidos:
		if not s["fantasma"] and z_overlap(pz, s["z"], s["d"]):
			var d: float = s["x0"] - (px + Regras.MEIO)
			if d > 0.0 and d < look and topo_solido(s, s["x0"] + 0.01) > py + 0.15 and s["rampa"] == 0.0:
				pular = true
	for p in perigos:
		if not p["usado"] and z_overlap(pz, p["z"], p["d"]):
			var d: float = p["x"] - p["w"] / 2.0 - (px + Regras.MEIO) + p["vx"] * 0.3
			if d < -0.2 or d > look + 0.6:
				continue
			if p["y0"] > 0.5 and py < p["y0"]:
				rolar = d < 2.2
			elif p["tipo"] == "pessoa":
				pular = true
	var sa = suporte(px + look, pz, py + 0.5)
	if sa == null or sa["y"] < py - 1.0:
		pular = true
	if no_chao and pular:
		acao("cima")
	if no_chao and rolar and rolar_t <= 0.0:
		acao("baixo")
	var sb = suporte(px + 2.0, pz, py + 0.1)
	hold = not no_chao and (sb == null or sb["y"] < py - 2.5)


func _bloqueio(z: float, x0: float, x1: float) -> float:
	var d := INF
	for s in solidos:
		if not s["fantasma"] and z_overlap(z, s["z"], s["d"]) and s["x1"] > x0 and s["x0"] < x1 and s["rampa"] == 0.0 and s["h"] > 1.4:
			d = minf(d, s["x0"] - x0)
	for p in perigos:
		if not p["usado"] and p["tipo"] == "trem" and z_overlap(z, p["z"], p["d"]) and p["x"] + p["w"] / 2.0 > x0 and p["x"] - p["w"] / 2.0 - 14.0 < x1:
			d = minf(d, p["x"] - p["w"] / 2.0 - x0)
	return d
