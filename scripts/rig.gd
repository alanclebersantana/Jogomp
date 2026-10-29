extends RefCounted
class_name Rig
## Tomé montado em peças e animado por "ossos" (como no Oddmar): cada parte do corpo é uma imagem
## separada em assets/rig/tome/ e o código gira e move as peças a cada quadro.
## Se as peças não existirem, o jogo continua usando as folhas de quadros antigas.
##
## Peças (PNG com fundo transparente, todas viradas para a DIREITA, mesma escala entre si):
##   cabeca.png       chapéu + rosto + barba          — ponto de giro: o "pescoço", a 72% da altura, no meio
##   tronco.png       casaco + cachecol (sem braços)  — ponto de giro: meio da base (quadril)
##   braco_frente.png braço da frente com a mão       — ponto de giro: meio do topo (ombro)
##   braco_tras.png   braço de trás com a mão         — ponto de giro: meio do topo (ombro)
##   perna_frente.png perna + bota da frente          — ponto de giro: meio do topo (quadril)
##   perna_tras.png   perna + bota de trás            — ponto de giro: meio do topo (quadril)
##   lanterna.png     lanterna acesa                  — ponto de giro: meio do topo (alça)
##   picareta.png     picareta (cabo para baixo)      — ponto de giro: ponta de baixo do cabo
## Ajustes finos (opcional): assets/rig/tome/rig.json com {"peça": {"px": 0.5, "py": 0.0}, ...}

const PARTS := ["cabeca", "tronco", "braco_frente", "braco_tras", "perna_frente", "perna_tras", "lanterna", "picareta"]
const DEF_PIV := {
	"cabeca": [.5, .72], "tronco": [.5, 1.0], "braco_frente": [.5, .06], "braco_tras": [.5, .06],
	"perna_frente": [.5, .04], "perna_tras": [.5, .04], "lanterna": [.5, .02], "picareta": [.5, .95],
}
static var data := {}

static func load_char(ch: String) -> void:
	if data.has(ch):
		return
	var d := {"ok": false, "tex": {}, "piv": {}}
	var base := "res://assets/rig/%s/" % ch
	var ok := true
	for n in PARTS:
		var path: String = base + n + ".png"
		if ResourceLoader.exists(path):
			d.tex[n] = load(path)
		elif n in ["lanterna", "picareta"]:
			pass
		else:
			ok = false
	if ok:
		var over := {}
		if FileAccess.file_exists(base + "rig.json"):
			var j = JSON.parse_string(FileAccess.get_file_as_string(base + "rig.json"))
			if j is Dictionary:
				over = j
		d.ps = {}
		for n in PARTS:
			var pv: Array = DEF_PIV[n]
			var sc := 1.0
			if over.has(n):
				pv = [float(over[n].get("px", pv[0])), float(over[n].get("py", pv[1]))]
				sc = float(over[n].get("s", 1.0))
			d.piv[n] = pv
			d.ps[n] = sc
		# encaixes (frações do tronco): pernas entram no casaco, ombros, pescoço
		d.lay = {"leg_in": .0, "hip_x": .14, "sh_x": .2, "sh_y": .78, "neck_x": .02, "neck_y": .97, "arm_len": .9}
		for kk in d.lay.keys():
			if over.has(kk):
				d.lay[kk] = float(over[kk])
		var tw: Texture2D = d.tex.tronco
		var lw: Texture2D = d.tex.perna_frente
		var hw: Texture2D = d.tex.cabeca
		# altura total "em pé" (perna + tronco + cabeça até o topo do chapéu)
		d.total = lw.get_height() * .96 - d.lay.leg_in * tw.get_height() + tw.get_height() * d.lay.neck_y + hw.get_height() * d.piv.cabeca[1]
		d.scale_k = float(over.get("altura", 80.0)) / d.total
	d.ok = ok
	data[ch] = d

static func ready(ch: String = "tome") -> bool:
	load_char(ch)
	return data[ch].ok

## pose: dicionário de ângulos (rad) e deslocamentos; desenha com os pés em (cx, by)
static func draw_pose(ch: String, cx: float, by: float, face: float, pose: Dictionary, sq: Vector2 = Vector2.ONE, al: float = 1.0) -> void:
	var d: Dictionary = data[ch]
	var k: float = d.scale_k
	var T: Dictionary = d.tex
	var tro: Texture2D = T.tronco
	var tw: float = tro.get_width()
	var th: float = tro.get_height()
	var leg_h: float = T.perna_frente.get_height() * .96
	Spr.save()
	Spr.translate(cx, by)
	Spr.scale(face * k * sq.x, k * sq.y)
	# quadril
	var lay: Dictionary = d.lay
	var hip := Vector2(pose.get("hx", 0.0), -leg_h + lay.leg_in * th + pose.get("hy", 0.0))
	var lean: float = pose.get("lean", 0.0)
	var hipb := hip + Vector2(-tw * lay.hip_x, -th * lay.leg_in)
	var hipf := hip + Vector2(tw * lay.hip_x, -th * lay.leg_in)
	# ombros e pescoço no referencial do tronco (gira junto com a inclinação)
	var rot := func(v: Vector2) -> Vector2:
		return hip + v.rotated(lean)
	var sh_b: Vector2 = rot.call(Vector2(-tw * lay.sh_x, -th * lay.sh_y))
	var sh_f: Vector2 = rot.call(Vector2(tw * lay.sh_x, -th * lay.sh_y))
	var neck: Vector2 = rot.call(Vector2(tw * lay.neck_x, -th * lay.neck_y))
	# de trás para a frente (no golpe, o braço com a picareta vem para a frente do corpo)
	var pick: bool = pose.get("pick", false) and T.has("picareta")
	if not pick:
		_part(d, "braco_tras", sh_b, pose.get("ab", 0.0), al)
	_part(d, "perna_tras", hipb, pose.get("lb", 0.0), al)
	_part(d, "perna_frente", hipf, pose.get("lf", 0.0), al)
	_part(d, "tronco", hip, lean, al, pose.get("breath", 1.0))
	_part(d, "cabeca", neck, lean + pose.get("hd", 0.0), al)
	if pick:
		var ab: float = pose.get("ab", 0.0)
		var ah: float = T.braco_tras.get_height() * lay.arm_len
		var hand: Vector2 = sh_b + Vector2(0, ah).rotated(ab)
		_part(d, "picareta", hand, ab + PI + pose.get("pk", 0.0), al)
		_part(d, "braco_tras", sh_b, ab, al)
	if T.has("lanterna"):
		var af: float = pose.get("af", 0.0)
		var ah2: float = T.braco_frente.get_height() * lay.arm_len
		var hand2: Vector2 = sh_f + Vector2(0, ah2).rotated(af)
		_part(d, "lanterna", hand2, sin(pose.get("t", 0.0) * .1) * .08 + pose.get("lsw", 0.0), al)
	_part(d, "braco_frente", sh_f, pose.get("af", 0.0), al)
	Spr.restore()

static func _part(d: Dictionary, n: String, at: Vector2, ang: float, al: float, sy: float = 1.0) -> void:
	if not d.tex.has(n):
		return
	var t: Texture2D = d.tex[n]
	var pv: Array = d.piv[n]
	var w: float = t.get_width()
	var h: float = t.get_height()
	var ps: float = d.ps.get(n, 1.0)
	Spr.save()
	Spr.translate(at.x, at.y)
	Spr.rotate(ang)
	Spr.scale(ps, sy * ps)
	Spr.ci.draw_texture_rect(t, Rect2(-w * pv[0], -h * pv[1], w, h), false, Color(1, 1, 1, Spr.alpha * al))
	Spr.restore()

## escolhe a pose a partir do estado do Tomé
static func pose_for(p: Dictionary, T: int) -> Dictionary:
	var t := float(T)
	var ps := {"t": t}
	var ph: float = p.anim * 2.2
	if p.get("act", "") == "swing" and p.actT > 0:
		var u: float = clamp((22 - p.actT) / 14.0, 0, 1)
		ps.ab = lerpf(2.3, 5.45, u * u * (3 - 2 * u))
		ps.pick = true
		ps.pk = .35
		ps.lean = lerpf(-.12, .22, u)
		ps.af = .3
		ps.lf = -.25
		ps.lb = .3
		return ps
	if p.get("guard", false):
		ps.af = -1.55
		ps.ab = .4
		ps.lean = -.08
		ps.lf = -.2
		ps.lb = .25
		return ps
	if p.get("wslide", false):
		# de costas para a parede: o braço de trás estica até ela, o da frente equilibra
		ps.af = -.9
		ps.ab = 1.9
		ps.lean = .1
		ps.lf = -.6
		ps.lb = -.2
		return ps
	if p.swim:
		ps.af = -1.4 + sin(t * .15) * 1.2
		ps.ab = -1.4 - sin(t * .15) * 1.2
		ps.lf = sin(t * .3) * .5
		ps.lb = -sin(t * .3) * .5
		ps.lean = .5
		return ps
	if p.crouch:
		ps.hy = 12.0
		ps.lean = .3
		ps.lf = -.75 + (sin(ph) * .3 if abs(p.vx) > .3 else 0.0)
		ps.lb = .55 - (sin(ph) * .3 if abs(p.vx) > .3 else 0.0)
		ps.af = -.5
		ps.ab = .2
		return ps
	if p.get("pushT", 0) > 0 and p.onGround:
		ps.lean = .38
		ps.af = -1.35
		ps.ab = -1.2
		ps.lf = -.5 + sin(ph) * .35
		ps.lb = .45 - sin(ph) * .35
		ps.hy = 3.0
		return ps
	if not p.onGround:
		if p.vy < 0:
			ps.lf = -.75
			ps.lb = .35
			ps.af = -2.1
			ps.ab = -1.7
			ps.lean = -.06
		else:
			var w: float = sin(t * .45) * .25
			ps.lf = .25 + w
			ps.lb = -.2 - w
			ps.af = -2.5 + w
			ps.ab = -2.2 - w
			ps.lean = .04
		return ps
	if p.get("landT", 0) > 0:
		var q: float = p.landT / 8.0
		ps.hy = 8.0 * q
		ps.lf = -.45 * q
		ps.lb = .45 * q
		ps.af = .3 * q
		ps.ab = .3 * q
		return ps
	if abs(p.vx) > .4:
		var run: bool = p.run
		var A: float = .85 if run else .55
		ps.lf = sin(ph) * A
		ps.lb = -sin(ph) * A
		ps.af = -sin(ph) * (A * .8)
		ps.ab = sin(ph) * (A * .8)
		ps.hy = -abs(cos(ph)) * (5.0 if run else 3.0)
		ps.lean = .2 if run else .07
		ps.hd = -ps.lean * .4
		return ps
	# parado: respira, a lanterna balança
	ps.breath = 1.0 + sin(t * .06) * .015
	ps.hy = sin(t * .06) * .8
	ps.af = sin(t * .05) * .06
	ps.ab = -sin(t * .05) * .05
	ps.hd = sin(t * .03) * .04
	return ps
