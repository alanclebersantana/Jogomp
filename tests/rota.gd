extends SceneTree
## Robô de teste: joga cada fase do começo ao fim seguindo tests/rotas/<fase>.txt e confere se embarca.
## Cada linha da rota: "x dir acao [tempo] [y]" — quando o Milis cruza a coluna x (em quadrados) correndo
## na direção dir (1 ou -1) e, se dado, perto da linha y, faz a ação:
##   pula [s]   toque segurado por s segundos (padrão 0.3)
##   duplo [s]  pula e, depois de s segundos (padrão 0.3), pula de novo
##   plana [s]  pula e segura por s segundos (plana na descida)
##   solta      larga o toque
## Uso: godot --headless --path . -s tests/rota.gd   (FASES=1-1,1-2 para escolher; VERBOSO=1 para o passo a passo)

const DT := 1.0 / 120.0
var falhas := 0


func _initialize() -> void:
	var lista := OS.get_environment("FASES")
	var fases: Array = lista.split(",") if lista != "" else ["1-1", "1-2"]
	for f in fases:
		await _joga(f)
	print("FALHAS: %d" % falhas)
	quit(1 if falhas > 0 else 0)


func _le_rota(fid: String) -> Array:
	var res: Array = []
	var arq := FileAccess.open("res://tests/rotas/%s.txt" % fid, FileAccess.READ)
	if arq == null:
		return res
	while not arq.eof_reached():
		var l := arq.get_line().strip_edges()
		if l == "" or l.begins_with("#"):
			continue
		var p := l.split(" ", false)
		var r := {"x": float(p[0]), "dir": int(p[1]), "acao": p[2], "s": 0.3, "y": -1.0, "feito": false}
		if p.size() > 3:
			r.s = float(p[3])
		if p.size() > 4:
			r.y = float(p[4])
		res.append(r)
	return res


func _joga(fid: String) -> void:
	var verb := OS.get_environment("VERBOSO") == "1"
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	main.comeca(fid)
	var j = main.jogo
	j.bot = true
	j.set_physics_process(false)
	var rota := _le_rota(fid)
	var resultado := {}
	j.embarcou.connect(func(r): resultado.merge(r))
	var perdeu := [false]
	j.perdeu_voo.connect(func(): perdeu[0] = true)
	var acoes: Array = []          # [tempo, "aperta"/"solta"]
	var tempo := 0.0
	var x_ant: float = j.pos.x / 40.0
	var quedas_ant := 0
	var max_x := 0.0
	var passos := 0
	var dir_ant: int = j.dir
	var est_ant: String = j.estado
	while resultado.is_empty() and not perdeu[0] and passos < 120 * 400:
		passos += 1
		tempo += DT
		var xq: float = j.pos.x / 40.0
		var yq: float = j.pos.y / 40.0
		if j.estado != "caiu":
			for r in rota:
				if r.feito:
					continue
				if int(j.dir) != int(r.dir):
					continue
				var cruzou: bool = (x_ant < r.x and xq >= r.x) if r.dir > 0 else (x_ant > r.x and xq <= r.x)
				if str(r.acao) == "salta":
					# na parede verde: salta quando chegar à altura y
					cruzou = j.estado == "parede" and absf(xq - r.x) < 1.0 and yq <= r.y
					if cruzou:
						r.feito = true
						acoes.append([tempo, "aperta"])
						acoes.append([tempo + 0.15, "solta"])
						if verb:
							print("  t=%.2f x=%.1f y=%.1f salta da parede" % [tempo, xq, yq])
					continue
				if not cruzou:
					continue
				if r.y >= 0.0 and absf(yq - r.y) > 1.6:
					continue
				r.feito = true
				if verb:
					print("  t=%.2f x=%.1f y=%.1f %s %s" % [tempo, xq, yq, r.acao, r.s])
				match str(r.acao):
					"pula", "plana":
						acoes.append([tempo, "aperta"])
						acoes.append([tempo + float(r.s), "solta"])
					"duplo":
						acoes.append([tempo, "aperta"])
						acoes.append([tempo + 0.12, "solta"])
						acoes.append([tempo + float(r.s), "aperta"])
						acoes.append([tempo + float(r.s) + 0.3, "solta"])
					"solta":
						acoes.append([tempo, "solta"])
		x_ant = xq
		if j.no_chao and j.estado == "chao" and acoes.is_empty() and _perigo(j):
			if verb:
				print("  t=%.2f x=%.1f y=%.1f desvia" % [tempo, xq, yq])
			acoes.append([tempo, "aperta"])
			acoes.append([tempo + 0.32, "solta"])
		var resta: Array = []
		for a in acoes:
			if a[0] <= tempo:
				if a[1] == "aperta":
					j.aperta()
				else:
					j.solta()
			else:
				resta.append(a)
		acoes = resta
		j._physics_process(DT)
		max_x = maxf(max_x, xq)
		if verb and (j.dir != dir_ant or (j.estado != est_ant and (j.estado == "parede" or est_ant == "parede"))):
			print("  t=%.2f x=%.1f y=%.1f virou dir=%d estado=%s" % [tempo, j.pos.x / 40.0, j.pos.y / 40.0, j.dir, j.estado])
		dir_ant = j.dir
		est_ant = j.estado
		if j.quedas != quedas_ant:
			quedas_ant = j.quedas
			print("  [%s] tropeço em x=%.1f y=%.1f (t=%.1f) por %s" % [fid, xq, yq, tempo, j.motivo])
			# depois de voltar ao totem, as ações da rota valem de novo dali para a frente
			acoes.clear()
			j.solta()
			for r in rota:
				r.feito = false
	if not resultado.is_empty():
		print("[%s] EMBARCOU: milhas %d/%d, sobrou %.1fs, tropeços %d" % [fid, resultado.milhas, resultado.total, resultado.sobra, resultado.quedas])
		if resultado.quedas > 0:
			falhas += 1
	else:
		print("[%s] NÃO EMBARCOU (perdeu=%s, max_x=%.1f, x=%.1f y=%.1f)" % [fid, perdeu[0], max_x, j.pos.x / 40.0, j.pos.y / 40.0])
		falhas += 1
	main.queue_free()
	await process_frame


## algo perigoso vindo pela frente na mesma altura: pula na hora certa
func _perigo(j) -> bool:
	for o in j.objs:
		var v := 0.0
		var largura := 30.0
		match str(o.t):
			"pass":
				v = float(o.v) * -float(o.d) * float(j.dir)
				largura = 22.0
			"carrinho":
				v = 215.0 * -float(o.d) * float(j.dir)
				largura = 50.0
			"capanga":
				if o.get("ko", false):
					continue
				v = float(o.v) * -float(o.d) * float(j.dir)
				largura = 24.0
			"mala":
				if not o.chao:
					continue
				v = 130.0 * -float(o.d) * float(j.dir)
				largura = 26.0
			"laser":
				if str(o.tipo) != "chao":
					continue
				largura = 8.0
			"mala_voa":
				if o.get("ko", false):
					continue
				var dxm: float = (float(o.p.x) - j.pos.x) * j.dir
				if float(o.y0) > j.pos.y - 170.0 and dxm > 20.0 and dxm < 265.0 * 0.32 + 40.0:
					return true
				continue
			_:
				continue
		var dx: float = (float(o.p.x) - j.pos.x) * j.dir
		var dy: float = absf(float(o.p.y) - j.pos.y)
		if dy > 30.0 or dx < 0.0:
			continue
		var fecha := 265.0 + v
		if dx < fecha * 0.3 + largura + 16.0 and dx > largura:
			return true
	return false
