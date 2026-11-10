class_name PadMap
## Mapeamento do controle (gamepad): cada função do jogo num botão, escolhido pelo jogador
## (Opções > MAPEAR CONTROLE). Direcional e analógico esquerdo ficam sempre no movimento.
## Gatilhos L2/R2 que chegam como eixo viram os "botões" 100 e 101.

const L2 := 100
const R2 := 101

## [id, nome na tela, tecla interna do jogo, botão padrão]
const FUNCS := [
	["pulo", "Pular", "J", JOY_BUTTON_A],
	["golpe", "Bastão (golpe)", "G", JOY_BUTTON_RIGHT_SHOULDER],
	["chute", "Chute / investida", "K", R2],
	["usar", "Usar / gancho", "A", JOY_BUTTON_Y],
	["defesa", "Defesa / esquiva", "F", JOY_BUTTON_LEFT_SHOULDER],
	["correr", "Correr (segurar)", "RUN", L2],
	["planar", "Planar", "P", JOY_BUTTON_X],
	["mochila", "Mochila", "BAG", JOY_BUTTON_B],
	["mapa", "Mapa da fase", "MAP", JOY_BUTTON_BACK],
	["pausa", "Pausa", "PAUSE", JOY_BUTTON_START],
	["totem", "Voltar ao totem (segurar)", "B", JOY_BUTTON_LEFT_STICK],
	["cena", "Pular cena", "SKIP", JOY_BUTTON_RIGHT_STICK],
]

const DPAD := [JOY_BUTTON_DPAD_UP, JOY_BUTTON_DPAD_DOWN, JOY_BUTTON_DPAD_LEFT, JOY_BUTTON_DPAD_RIGHT]

## o Save (autoload) buscado na hora: este script também é carregado por testes antes dos autoloads
static func _sv() -> Node:
	return (Engine.get_main_loop() as SceneTree).root.get_node("Save")

static func default_of(id: String) -> int:
	for f in FUNCS:
		if f[0] == id:
			return int(f[3])
	return -1

## botão escolhido para a função
static func btn(id: String) -> int:
	return int(_sv().getv("pad", id, default_of(id)))

## função ligada ao botão ("" = nenhuma)
static func func_of(b: int) -> String:
	for f in FUNCS:
		if btn(f[0]) == b:
			return f[0]
	return ""

static func key_of(id: String) -> String:
	for f in FUNCS:
		if f[0] == id:
			return f[2]
	return ""

static func label_of(id: String) -> String:
	for f in FUNCS:
		if f[0] == id:
			return f[1]
	return id

## liga a função ao botão; se o botão já era de outra função, as duas trocam de botão
## (assim nenhum botão fica com duas funções e nenhuma função fica sem botão)
static func assign(id: String, b: int) -> void:
	var old: int = btn(id)
	var other: String = func_of(b)
	if other != "" and other != id:
		_sv().setv("pad", other, old)
	_sv().setv("pad", id, b)

static func reset() -> void:
	for f in FUNCS:
		_sv().setv("pad", f[0], int(f[3]))

static func name_of(b: int) -> String:
	match b:
		JOY_BUTTON_A: return "A"
		JOY_BUTTON_B: return "B"
		JOY_BUTTON_X: return "X"
		JOY_BUTTON_Y: return "Y"
		JOY_BUTTON_BACK: return "SELECT"
		JOY_BUTTON_GUIDE: return "HOME"
		JOY_BUTTON_START: return "START"
		JOY_BUTTON_LEFT_STICK: return "L3"
		JOY_BUTTON_RIGHT_STICK: return "R3"
		JOY_BUTTON_LEFT_SHOULDER: return "L1"
		JOY_BUTTON_RIGHT_SHOULDER: return "R1"
		L2: return "L2"
		R2: return "R2"
		JOY_BUTTON_MISC1: return "EXTRA"
	return "Botão %d" % b
