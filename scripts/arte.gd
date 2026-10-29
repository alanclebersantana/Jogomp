extends Node
## Arte do jogo: lê assets/art/arte.json (tiras de animação feitas por tools/arte.py) e desenha os quadros.
## As imagens estão no dobro do tamanho do mundo: cada quadro é desenhado com escala 0.5.

const ESC := 0.5
var info := {}
var tex := {}
var fonte_titulo: Font
var fonte: Font
var fonte_media: Font

# cores da Milhas Plus e do aeroporto
const VERDE := Color("1f6b3d")
const VERDE_CLARO := Color("2fa45d")
const AMARELO := Color("f2c230")
const AZUL_NOITE := Color("1b2333")
const BRANCO := Color("f7f4ec")
const VERMELHO := Color("e0463c")
const ROXO := Color("7a3fc2")


func _ready() -> void:
	var f := FileAccess.open("res://assets/art/arte.json", FileAccess.READ)
	if f:
		info = JSON.parse_string(f.get_as_text())
	fonte_titulo = load("res://assets/fonts/Baloo2-ExtraBold.woff2")
	fonte = load("res://assets/fonts/Poppins-Bold.ttf")
	fonte_media = load("res://assets/fonts/Poppins-Medium.ttf")


func t(nome: String) -> Texture2D:
	if not tex.has(nome):
		var m = info.get(nome)
		if m == null:
			push_warning("arte: falta " + nome)
			tex[nome] = null
		else:
			tex[nome] = load("res://assets/art/" + str(m.file))
	return tex[nome]


func n(nome: String) -> int:
	var m = info.get(nome)
	return int(m.n) if m else 1


func fps(nome: String) -> float:
	var m = info.get(nome)
	return float(m.fps) if m else 10.0


## tamanho de um quadro no mundo
func tam(nome: String) -> Vector2:
	var m = info.get(nome)
	if m == null:
		return Vector2.ZERO
	return Vector2(float(m.w), float(m.h)) * ESC


## desenha o quadro i da animação 'nome' com a âncora em 'pos' (no sistema do CanvasItem 'ci')
func quadro(ci: CanvasItem, nome: String, i: int, pos: Vector2, virar := false, k := 1.0,
		mod := Color.WHITE, rot := 0.0, kx := 1.0, ky := 1.0) -> void:
	var m = info.get(nome)
	var tx := t(nome)
	if m == null or tx == null:
		return
	var w := float(m.w)
	var h := float(m.h)
	var nq := int(m.n)
	i = posmod(i, nq)
	var src := Rect2(i * w, 0, w, h)
	var ax := float(m.ax)
	var ay := float(m.ay)
	var s := ESC * k
	ci.draw_set_transform(pos, rot, Vector2((-s if virar else s) * kx, s * ky))
	ci.draw_texture_rect_region(tx, Rect2(-ax, -ay, w, h), src, mod)
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## quadro da animação no tempo 'tempo' (segundos)
func anim(ci: CanvasItem, nome: String, tempo: float, pos: Vector2, virar := false, k := 1.0,
		mod := Color.WHITE, rot := 0.0) -> void:
	quadro(ci, nome, int(tempo * fps(nome)), pos, virar, k, mod, rot)


## desenha a imagem inteira esticada num retângulo
func caixa(ci: CanvasItem, nome: String, r: Rect2, i := 0, mod := Color.WHITE) -> void:
	var m = info.get(nome)
	var tx := t(nome)
	if m == null or tx == null:
		return
	ci.draw_texture_rect_region(tx, r, Rect2(i * float(m.w), 0, float(m.w), float(m.h)), mod)


## texto com contorno
func texto(ci: CanvasItem, s: String, pos: Vector2, tam_fonte: int, cor := BRANCO,
		alinha := HORIZONTAL_ALIGNMENT_CENTER, largura := -1.0, contorno := 6, cor_contorno := Color(0.08, 0.1, 0.16, 0.95),
		f: Font = null) -> void:
	if f == null:
		f = fonte_titulo
	if contorno > 0:
		ci.draw_string_outline(f, pos, s, alinha, largura, tam_fonte, contorno, cor_contorno)
	ci.draw_string(f, pos, s, alinha, largura, tam_fonte, cor)
