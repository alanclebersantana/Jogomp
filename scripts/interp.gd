extends RefCounted
class_name Interp
## Desenho liso "entre" dois passos da lógica.
## A lógica roda num ritmo fixo (44/52/60 passos por segundo) e a tela a 60/90/120 Hz: sem isso, tudo o que
## anda dava trancos (um quadro parado, outro pulando). O Tomé, os inimigos e a câmera já tinham a sua
## correção (Game.ip_off / e_off / update_render_cam); aqui entram os chefes, o Pipoca, as plataformas que se
## mexem, caixotes, barco, jangada e bichos da vila.
## Como funciona: no começo de cada passo guarda a posição antiga; logo antes de desenhar troca x/y pela posição
## "do meio do caminho" e, assim que o desenho termina (frame_pre_draw), devolve a posição verdadeira — a lógica
## nunca vê a posição de desenho.

const KEYS := ["x", "y", "hy"]
const JUMP := 70.0          # andou mais que isso num passo = teleporte (não mistura)

static var _list: Array = []      # dicionários acompanhados neste passo
static var _snap: Array = []      # [dicionário, valores verdadeiros] enquanto desenha
static var _sol_n := -1
static var _sol_mov: Array = []
static var _sol_t := 0
static var _sol_src: Array = []

## lista de quem anda (só o que pode aparecer na tela; barato)
static func _targets(g) -> Array:
	var out: Array = []
	if g.X:
		out.append(g.X.BOSS)
		# Pipoca controlado pelo jogador já é desenhado com Game.ip_off (não misturar duas vezes)
		if not (g.M and g.M.ctrl):
			out.append(g.X.DOG)
	if g.K:
		out.append(g.K.HAWK)
		out.append(g.K.FISH)
		out.append(g.K.BEAR)
	if g.RD:
		out.append(g.RD.H)
	if g.VL:
		out.append_array(g.VL.DOGS)
		out.append_array(g.VL.WATCH)
	if g.PR:
		out.append(g.PR.TABLE)
	# caixotes de empurrar
	out.append_array(g.CR)
	# plataformas e corpos que se mexem dentro de SOL (refeita quando SOL muda ou a cada segundo)
	if g.SOL.size() != _sol_n or not is_same(g.SOL, _sol_src) or g.T < _sol_t or g.T - _sol_t > 60:
		_sol_n = g.SOL.size()
		_sol_src = g.SOL
		_sol_t = g.T
		_sol_mov = []
		for s in g.SOL:
			if s.get("t", "") in ["mplat", "push", "crate"] or s.has("dy") or s.get("boat") or s.get("raft"):
				_sol_mov.append(s)
	out.append_array(_sol_mov)
	return out

## começo do passo: guarda onde cada um estava
static func save(g) -> void:
	restore()
	_list = _targets(g)
	for d in _list:
		if d.is_empty():
			continue
		for k in KEYS:
			if d.has(k):
				d["_ip_" + k] = d[k]

## logo antes de desenhar: posição entre o passo anterior e o atual (f de 0 a 1)
static func apply(f: float) -> void:
	restore()
	if f >= .999:
		return
	for d in _list:
		if d.is_empty() or not d.has("_ip_x"):
			continue
		var real := []
		var ok := true
		for k in KEYS:
			if d.has(k) and d.has("_ip_" + k):
				var a = d["_ip_" + k]
				var b = d[k]
				if not (a is float or a is int) or not (b is float or b is int) or abs(float(b) - float(a)) > JUMP:
					ok = false
					break
		if not ok:
			continue
		for k in KEYS:
			if d.has(k) and d.has("_ip_" + k):
				real.append([k, d[k]])
				d[k] = lerpf(float(d["_ip_" + k]), float(d[k]), f)
		_snap.append([d, real])

## o desenho terminou: devolve as posições verdadeiras
static func restore() -> void:
	# de trás para frente: se um dicionário entrou duas vezes, volta à posição verdadeira
	for i in range(_snap.size() - 1, -1, -1):
		var s: Array = _snap[i]
		var d: Dictionary = s[0]
		for kv in s[1]:
			d[kv[0]] = kv[1]
	_snap.clear()
