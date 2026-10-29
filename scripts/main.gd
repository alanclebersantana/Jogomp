extends Node
## Cena principal: monta o mundo, as camadas, o HUD, os controles de toque e as telas
## (início, abertura da fase, mochila, pista, placar, fim de jogo, pausa).

enum S { TITLE, INTRO, PLAY, BAG, CLUE, RESULTS, OVER, PAUSE, CUT, REST, COMIC }
var state := S.TITLE
var game: Game
var hud: Control
var glow_layer: CanvasLayer
var screen_layer: CanvasLayer
var hud_layer: CanvasLayer
var ui_layer: CanvasLayer
var light_map: LightMap
var player_light: LightMap.Dot
var lights: Array = []
var touch: Array = []
var stick: Control
var top_buttons: HBoxContainer
var snd_btn: Button
var dog_btn: TextureButton
var tex_dog: Texture2D = preload("res://assets/ui/btn_dog.png")
var bag_btn: TextureButton
var tex_golpe: Texture2D = preload("res://assets/ui/btn_golpe.png")
var tex_use: Texture2D = preload("res://assets/ui/btn_use.png")
var tex_bagb: Texture2D = preload("res://assets/ui/btn_bag.png")
var tex_check: Texture2D = load("res://assets/ui/btn_check.png") if ResourceLoader.exists("res://assets/ui/btn_check.png") else tex_use
var tex_crank: Texture2D = load("res://assets/ui/btn_crank.png") if ResourceLoader.exists("res://assets/ui/btn_crank.png") else tex_use
var tex_harpoon: Texture2D = preload("res://assets/ui/btn_harpoon.png")
var hint_btn: TextureButton
var tex_tome: Texture2D = preload("res://assets/ui/btn_tome.png")
var panel: Control = null
var bag_sel := ""
var theme_ui: Theme
var light_tex: Texture2D
var last_joy_ms := -9999
# navegação de menus pelo controle (gamepad): moldura dourada no botão escolhido
var joy_idx := 0
var joy_sig := ""
var joy_ring: Panel
var joy_ax := {}
var last_touch_ms := -9999   # último toque na tela (o gesto de "voltar" da borda vem junto com toques)
const KEYMAP := {
	KEY_LEFT: "L", KEY_A: "L", KEY_RIGHT: "R", KEY_D: "R", KEY_UP: "U", KEY_W: "U", KEY_DOWN: "S", KEY_S: "S",
	KEY_SPACE: "J", KEY_Z: "J", KEY_K: "J", KEY_C: "P", KEY_F: "A", KEY_E: "A", KEY_X: "A", KEY_V: "A", KEY_R: "B",
	KEY_G: "G", KEY_J: "G", KEY_Q: "D",
}
const GOLD := Color("#e8d39a")
const INK := Color("#f0e4c8")
## faixas de cinema (cenas, apresentação dos chefes e câmera lenta)
var cine_bars: Control
var vivid: ColorRect

func _ready() -> void:
	RenderingServer.set_default_clear_color(Color("#0b0906"))
	# posições "de desenho" (Interp) voltam às verdadeiras assim que o desenho do quadro termina
	RenderingServer.frame_pre_draw.connect(Interp.restore)
	add_child(_FontWarm.new())
	# o "voltar" do Android nunca fecha o jogo direto: abre a pausa ou volta ao menu anterior
	get_tree().quit_on_go_back = false
	Save.before_save_run = _before_save_run
	_migrate_gallery()
	# ritmo do jogo: o antigo "Calma" (44 passos por segundo) agora é o Normal;
	# todo mundo passa para ele uma vez só (depois vale o que a pessoa escolher nas opções)
	if not Save.getv("opt", "tps44n", false):
		Save.setv("opt", "tps44n", true)
		Save.setv("opt", "tps", 44)
	Engine.physics_ticks_per_second = int(Save.getv("opt", "tps", 44))
	# posição padrão nova dos botões (mais para dentro da tela): quem tinha arrastado os botões para
	# chegar nela recomeça do padrão novo uma vez só (senão o arrasto antigo empurraria ainda mais)
	if not Save.getv("opt", "btnpos2", false):
		Save.setv("opt", "btnpos2", true)
		for k in ["J", "A", "G", "bag", "dog", "stick"]:
			Save.setv("opt", "pos_" + k, [0, 0])
	# o analógico de madeira passa a ser o controle padrão (uma vez só; depois vale a escolha nas opções)
	if not Save.getv("opt", "stick_an1", false):
		Save.setv("opt", "stick_an1", true)
		Save.setv("opt", "stick", "analog")
	# APK de teste (encontre-a-teste.apk): todos os episódios já vêm liberados na tela inicial.
	# No APK normal, cada episódio só abre depois de terminar o anterior.
	if OS.has_feature("teste") and int(Save.getv("prog", "eps", 1)) < EPISODES.size():
		Save.setv("prog", "eps", EPISODES.size())
	Engine.max_fps = 0
	_make_theme()
	_make_light_tex()
	game = Game.new()
	game.name = "Game"
	add_child(game)
	game.clue_opened.connect(_on_clue)
	game.bag_wanted.connect(func(l): open_bag(l))
	game.results_ready.connect(_on_level_end)
	game.isis_start.connect(_on_isis_start)
	game.game_over.connect(_on_over)
	game.level_won.connect(_on_results)
	game.rest_reached.connect(_on_rest)
	game.drawing_found.connect(func(i: int):
		# a galeria guarda os desenhos separados por episódio (o 1º desenho do Ep. 2 não abre o do Ep. 1)
		Save.setv("gallery", "e%d_d%d" % [game.level_idx + 1, i], true)
		var dr := preload("res://scripts/ui/drawing_reveal.gd").new()
		dr.kind = [0, 1, 3][clamp(i, 0, 2)]
		hud_layer.add_child(dr))
	light_map = LightMap.new()
	light_map.game = game
	add_child(light_map)
	glow_layer = CanvasLayer.new()
	glow_layer.layer = 2
	glow_layer.follow_viewport_enabled = true
	add_child(glow_layer)
	screen_layer = CanvasLayer.new()
	screen_layer.layer = 3
	add_child(screen_layer)
	# faixa de comemoração das corridas ("CHEGADA!", "POUSO PERFEITO!"): por cima da escuridão, dos
	# efeitos de tela e do contorno (senão o traço preto cortava o letreiro), embaixo do HUD
	var cheer_layer := CanvasLayer.new()
	cheer_layer.layer = 4
	cheer_layer.follow_viewport_enabled = true
	add_child(cheer_layer)
	var cheer := _CheerNode.new()
	cheer.game = game
	cheer_layer.add_child(cheer)
	hud_layer = CanvasLayer.new()
	hud_layer.layer = 5
	add_child(hud_layer)
	ui_layer = CanvasLayer.new()
	ui_layer.layer = 6
	add_child(ui_layer)
	var sky := preload("res://scripts/sky_fx.gd").new()
	sky.game = game
	screen_layer.add_child(sky)
	var front := preload("res://scripts/front.gd").new()
	front.game = game
	screen_layer.add_child(front)
	var fxn := preload("res://scripts/screen_fx.gd").new()
	fxn.game = game
	screen_layer.add_child(fxn)
	# acerto final de cor do mundo: cores vivas, contornos firmes, luz de sol (o HUD fica por cima)
	vivid = ColorRect.new()
	vivid.set_anchors_preset(Control.PRESET_FULL_RECT)
	vivid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var vm := ShaderMaterial.new()
	vm.shader = preload("res://scripts/vivid.gdshader")
	vivid.material = vm
	screen_layer.add_child(vivid)
	cine_bars = preload("res://scripts/ui/cinema_bars.gd").new()
	cine_bars.set_anchors_preset(Control.PRESET_FULL_RECT)
	cine_bars.mouse_filter = Control.MOUSE_FILTER_IGNORE
	screen_layer.add_child(cine_bars)
	hud = preload("res://scripts/ui/hud.gd").new()
	hud.game = game
	hud.set_anchors_preset(Control.PRESET_FULL_RECT)
	hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud_layer.add_child(hud)
	_make_top_buttons()
	_make_touch()
	apply_controls()
	_show_hud(false)
	get_viewport().size_changed.connect(_layout)
	_layout()
	show_title()

## cor viva: mais forte de dia, a luz quente do sol some à noite e no escuro; na qualidade baixa
## fica só a cor (sem as 4 leituras do contorno)
var _lq_applied := false
func _update_vivid() -> void:
	if vivid == null:
		return
	# qualidade baixa: o jogo inteiro é desenhado na resolução de base (540 linhas) e ampliado — muito
	# menos pixels para a placa de vídeo pintar (o que mais pesa nos celulares de tela grande)
	var lq: bool = game != null and game.low_fx
	if lq != _lq_applied:
		_lq_applied = lq
		var w := get_tree().root
		if lq:
			w.content_scale_mode = Window.CONTENT_SCALE_MODE_VIEWPORT
		else:
			w.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	# sem as leituras do contorno (que agora vem do outline.gdshader) é uma leitura só por pixel: fica
	# ligado também na qualidade baixa
	vivid.visible = game != null and game.L and state != S.TITLE
	if outline_rect:
		outline_rect.visible = vivid.visible
	if not vivid.visible:
		return
	var m: ShaderMaterial = vivid.material
	var night: float = clamp(float(game.AMB.get("night", 0.0)), 0.0, 1.0)
	var dark: float = clamp(float(game.AMB.get("dark", 0.0)), 0.0, 1.0)
	m.set_shader_parameter("warm", .03 * (1.0 - night) * (1.0 - dark * .8))
	# o contorno agora vem do outline.gdshader (tela do mundo); aqui só a cor, sem as 4 leituras extras
	m.set_shader_parameter("edge", 0.0)
	m.set_shader_parameter("px", clamp(get_viewport().get_visible_rect().size.y / 540.0, 1.0, 3.0) * 1.2)

# ======================================================================
#  MUNDO
# ======================================================================
func _build_world() -> void:
	for c in game.get_children():
		if c is Camera2D:
			continue
		c.queue_free()
	for c in glow_layer.get_children():
		c.queue_free()
	lights.clear()
	light_map.clear()
	var bg := preload("res://scripts/bg.gd").new()
	bg.game = game
	bg.z_index = -10
	game.add_child(bg)
	# o mundo (tudo menos o plano de fundo) é desenhado numa tela transparente à parte e colado por cima
	# do fundo com o contorno de desenho animado (outline.gdshader)
	_make_world_vp()
	for c in world_root.get_children():
		c.queue_free()
	game.world_parent = world_root
	world_show = _WorldShow.new()
	world_show.vp = world_vp
	var om := ShaderMaterial.new()
	om.shader = preload("res://scripts/premul.gdshader")
	world_show.material = om
	game.add_child(world_show)
	var span: int = game.L.spanX
	var x := 0
	while x < span:
		var ch := preload("res://scripts/world_static.gd").new()
		ch.game = game
		ch.x0 = x
		ch.x1 = min(x + 1024, span)
		world_root.add_child(ch)
		x += 1024
	var dyn := preload("res://scripts/world_dyn.gd").new()
	dyn.game = game
	world_root.add_child(dyn)
	var gl := preload("res://scripts/world_glow.gd").new()
	gl.game = game
	glow_layer.add_child(gl)
	# sons posicionados: fogueiras estalando e água correndo
	for c in game.CHK:
		Audio.emitter(game, "loop_fogo", Vector2(c.x, c.y - 20), -4.0 if c.has("rest") else -9.0, 700.0)
	var waters: Array = []
	for w in game.X.WATER:
		waters.append([float(w.x), float(w.x + w.w), float(w.y)])
	for sw in game.SWAMP:
		waters.append([float(sw.x), float(sw.x + sw.w), float(sw.y)])
	if game.VH and not game.VH.RA.is_empty():
		waters.append([float(game.VH.RA.x0), float(game.VH.RA.x1), 480.0])
	for wv in waters:
		var wx: float = wv[0] + 200
		while wx < wv[1]:
			Audio.emitter(game, "loop_agua", Vector2(wx, wv[2]), -8.0, 800.0)
			wx += 900
	player_light = _light(Color(1, .86, .62), 210)
	for c in game.CHK:
		lights.append({"n": _light(Color(1, .7, .35), 140), "chk": c})
	for s in game.SPR:
		lights.append({"n": _light(Color(.45, .75, 1), 110), "pos": Vector2(s.x, s.y - 30)})
	lights.append({"n": _light(Color(1, .8, .5), 150), "pos": Vector2(game.DOOR.x + 30, game.DOOR.y + 20), "door": true})
	lights.append({"n": _light(Color(1, .85, .55), 100), "vil": true})
	# cone de luz quente da lanterna, para o lado em que o Tomé olha
	cone_light = light_map.dot(Color(1, .82, .5), 128, _cone_tex())
	cone_light.texture_scale = 1.0
	cone_light.offset = Vector2(150, 0)
	# cogumelos gigantes iluminam em volta com a cor deles
	if game.TR:
		for o in game.TR.T:
			if o.k == "giant":
				var gc := Color(o.get("c", "#6a5acd")).lightened(.25) if o.has("to") else Color(o.get("c", "#6a5acd")).darkened(.3)
				lights.append({"n": _light(gc, 170 if o.has("to") else 110), "pos": Vector2(o.x, o.cap + 10)})
	# facho concentrado da lanterna, cristais e lápis dourado
	lights.append({"n": _light(Color(1, .9, .65), 200), "beam": true})
	for c in game.X.CRYSTALS:
		lights.append({"n": _light(Color(.6, .85, 1), 120), "crystal": c})
	if not game.X.GOLD.is_empty():
		lights.append({"n": _light(Color(1, .85, .4), 90), "gold": true})

var cone_light: LightMap.Dot
## textura do cone: claro perto da lanterna, abrindo e sumindo para a frente
var _cone: Texture2D
func _cone_tex() -> Texture2D:
	if _cone:
		return _cone
	var im := Image.create(300, 200, false, Image.FORMAT_RGBA8)
	for y in 200:
		for x in 300:
			var u: float = x / 300.0
			var half: float = 18.0 + u * 80.0
			var d: float = abs(y - 100.0) / half
			var a: float = clamp(1.0 - d, 0, 1) * (1.0 - u) * clamp(u * 6.0, 0, 1)
			im.set_pixel(x, y, Color(1, 1, 1, a * a))
	_cone = ImageTexture.create_from_image(im)
	return _cone

func _make_light_tex() -> void:
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 1))
	g.add_point(.55, Color(1, 1, 1, .55))
	g.set_color(g.get_point_count() - 1, Color(1, 1, 1, 0))
	var t := GradientTexture2D.new()
	t.gradient = g
	t.fill = GradientTexture2D.FILL_RADIAL
	t.fill_from = Vector2(.5, .5)
	t.fill_to = Vector2(1, .5)
	t.width = 256
	t.height = 256
	light_tex = t

func _light(c: Color, r: float) -> LightMap.Dot:
	return light_map.dot(c, r, light_tex)

func _update_lights() -> void:
	var a: float = game.AMB.dark
	var dark: float = clamp(a, 0, 1)
	# escuro com cor (azul de noite) e não preto chapado: a cena continua legível e as luzes brilham por cima
	light_map.ambient = Color(1, 1, 1).lerp(Color(.06, .075, .15), dark * .92)
	var p: Dictionary = game.player
	var pc := Vector2(p.x + p.w / 2, p.y + p.h / 2 + p.get("wdy", 0.0))
	var out: bool = game.L.has("lanternOutX") and not game.lantern_lit and pc.x > game.L.lanternOutX
	# a lanterna balança na mão conforme ele anda (a luz acompanha)
	var sw: float = sin(game.T * .17) * clamp(abs(p.vx) / 4.0, 0, 1)
	player_light.position = pc + Vector2(p.face * 6 + sw * 7, -4 + abs(sw) * 3)
	# o raio depende do óleo (ou dos vaga-lumes, com a lanterna apagada) e cresce aos poucos
	var fv: float = game.fuel_vis
	player_light.texture_scale = (lerpf(100.0, 185.0, fv) if out else lerpf(150.0, 300.0, fv)) * 2 / 256.0
	player_light.energy = dark * (1.4 + sin(game.T * .21) * .05) * (.25 + .75 * p.get("wal", 1.0))
	if cone_light:
		cone_light.position = player_light.position + Vector2(p.face * 10, 0)
		cone_light.rotation = 0.0 if p.face > 0 else PI
		cone_light.energy = 0.0 if out else dark * .9 * (.25 + .75 * p.get("wal", 1.0))
	for l in lights:
		var n: LightMap.Dot = l.n
		if l.has("chk"):
			n.position = Vector2(l.chk.x, l.chk.y - 20)
			n.energy = dark * (1.1 + sin(game.T * .3 + l.chk.x) * .12) if l.chk.on else 0.0
		elif l.has("beam"):
			var on: bool = game.X.focus
			var o: Vector2 = game.X.lamp()
			n.position = o + Vector2(p.face * 190, 0)
			n.energy = dark * 1.25 if on else 0.0
		elif l.has("crystal"):
			n.position = Vector2(l.crystal.x, l.crystal.y)
			n.energy = dark * (1.3 if l.crystal.on else l.crystal.charge / 60.0)
		elif l.has("gold"):
			n.position = Vector2(game.X.GOLD.x, game.X.GOLD.y)
			n.energy = 0.0 if game.X.GOLD.got else dark * .9
		elif l.has("vil"):
			var v = game.VIL
			n.energy = dark * 1.2 if (v and v.go and not v.gone) else 0.0
			if v:
				n.position = Vector2(v.x - 41, v.y - 97)
		else:
			n.position = l.pos
			n.energy = dark * 1.1

var _slow_t := 0.0
func _process(_d: float) -> void:
	_update_vivid()
	if not Spr.warmed:
		Spr.warm()
	_joy_ring_update()
	# chuva, tambores e sons do cenário só tocam com o jogo rodando (somem nos menus e voltam depois)
	Audio.set_world(state == S.PLAY and game.running)
	_update_cine_bars()
	# (gráficos sempre no máximo: não existe mais a redução automática de qualidade)
	# botão da mão: só quando há algo para usar (ou enquanto está sendo segurado)
	for tb in touch:
		if tb.get_meta("k") == "A":
			var want: bool = top_buttons.visible and (game.use_available() or game.kd("A"))
			tb.modulate.a = lerpf(tb.modulate.a, .85 if want else 0.0, .25)
			tb.visible = tb.modulate.a > .03
			# o desenho do botão muda: mochila (juntar as peças), ✔ (usar o que juntou) ou manivela
			var um: String = game.use_mode() if game.running else "hand"
			var ut: Texture2D = {"bag": tex_bagb, "check": tex_check, "crank": tex_crank}.get(um, tex_use)
			if tb.texture_normal != ut:
				var base: float = tb.get_meta("size") * {"P": .85, "M": 1.0, "G": 1.2}[Save.getv("opt", "btn_size", "M")]
				tb.texture_normal = ut
				tb.scale = Vector2.ONE * base / float(ut.get_width())
				tb.set_meta("base_sc", tb.scale.x)
			# brilha pulsando quando muda de função, para chamar atenção
			var lum: float = 1.0 + (.25 + .25 * sin(Time.get_ticks_msec() * .008) if um != "hand" else 0.0)
			tb.modulate = Color(lum, lum, lum * .9, tb.modulate.a)
		elif tb.get_meta("k") == "G":
			# na luta do Bagre-Rei a picareta vira arpão
			var fish: bool = game.K and not game.K.FISH.is_empty() and game.K.FISH.active and not game.K.FISH.done and game.K.FISH.get("skin", "") != "frog"
			var want_t: Texture2D = tex_harpoon if fish else tex_golpe
			if tb.texture_normal != want_t:
				tb.texture_normal = want_t
			# a Isis não tem picareta (e o botão some junto com os outros na pausa e nas cenas)
			tb.visible = top_buttons.visible and not (game.player and game.player.get("isis"))
	_touch_squash(_d)
	if hint_btn:
		hint_btn.visible = top_buttons.visible and hud.can_replay()
		hint_btn.position = Vector2(352, 8)
	if bag_btn:
		bag_btn.visible = top_buttons.visible
	if dog_btn and game.X:
		dog_btn.visible = top_buttons.visible and game.X.dog_free()
		dog_btn.texture_normal = tex_tome if game.M.ctrl else tex_dog
	if game.L and game.running:
		var vs := get_viewport().get_visible_rect().size
		game.W = vs.x
		game.H = vs.y
		game.chao_frac = .66 if vs.y > vs.x else .9
		var amp: float = game.shake * (.55 if Save.getv("opt", "shake", true) else 0.0)
		var tt := Time.get_ticks_msec() / 1000.0
		var sh := Vector2(sin(tt * 53.0) + sin(tt * 31.0) * .5, cos(tt * 47.0) + sin(tt * 29.0) * .5) * amp * .5
		# tremor com direção: empurra para o lado do impacto e volta
		sh += game.shake_dir * amp * .9
		game.shake_dir *= .86
		# câmera chega mais perto nas cenas calmas e abre nas de ação
		# celular em pé: a câmera mostra uns 520 px de largura do mundo
		var retrato: float = clampf(vs.x / 520.0, .72, 1.1) if vs.y > vs.x else 1.0
		var zt: float = _zoom_target() * retrato * (1.12 if game.slowmo > 0 else 1.0)
		# abrir é mais rápido que fechar (nada fica cortado por muito tempo)
		cam_zoom = lerpf(cam_zoom, zt, .04 if zt < cam_zoom else .02)
		game.camera.zoom = Vector2(cam_zoom, cam_zoom)
		game.W = vs.x / cam_zoom
		game.H = vs.y / cam_zoom
		game.update_render_cam()
		if stick.mode == "analog" and stick.finger != -1:
			game.axis_x = stick.axis
		game.camera.position = Vector2(game.rcam, game.rcam_y) + sh
		_update_lights()
		var under: bool = game.L.has("under") and game.player.y > game.L.under
		Audio.set_rain(game.AMB.rain * (.35 if under else 1.0) if state == S.PLAY else 0.0)
		var song: String = game.AMB.song
		var px: float = game.player.x
		var tun: Array = game.L.get("tunnel", [0, 0])
		if px > tun[0] and px < tun[1] and game.player.y < 760:
			song = "tunel"
		if game.X and game.X.boss_active():
			song = str(game.L.get("boss_song", "perseguicao"))
		if game.K and not game.K.HAWK.is_empty() and game.K.HAWK.active and not game.K.HAWK.done:
			song = "gaviao"
		if game.K and not game.K.FISH.is_empty() and game.K.FISH.active and not game.K.FISH.done:
			song = "bagre"
		if game.K and game.K.bear_on():
			song = "urso"
		# na neve, a canção da Lia toca com vento de fundo
		if song == "tema" and game.AMB.get("snow", 0.0) > .2:
			song = "neve"
		var base_song := song
		# trechos especiais: cada um com a sua música animada
		if game.RD and game.RD.riding:
			song = "cavalo"
		if game.VH and game.VH.mode == "raft":
			song = "jangada"
		elif game.VH and game.VH.mode == "sled":
			song = "carrinho" if game.VH.is_cart() else "treno"
		elif game.VH and game.VH.mode == "plane":
			song = "voo"
		if game.TR:
			for o in game.TR.T:
				if o.k == "boulder" and o.st in ["drop", "roll"]:
					song = "pedra"
		if state == S.PLAY:
			# quanto do trecho já foi andado (as músicas calmas vão ganhando camadas) e se a
			# música pode dar uma pausa (só fora de luta, perseguição e trecho especial)
			var calm := false
			for c in game.CHK:
				if c.on and abs(c.x - px) < 260 and abs(c.y - (game.player.y + game.player.h)) < 120:
					calm = true
					break
			Audio.music_hint(_song_progress(game.amb_x(), base_song == "tunel", tun), song == base_song, calm)
			Audio.set_song(song)
			Audio.set_danger(_danger_level())
		var in_cine: bool = not game.CINE.is_empty()
		if state == S.PLAY and top_buttons.visible == in_cine:
			top_buttons.visible = not in_cine
			stick.visible = not in_cine
			for b in touch:
				b.visible = not in_cine and not (b.get_meta("k") == "G" and game.player.get("isis"))
			if in_cine:
				stick._release()
	# desenho liso entre passos: chefes, Pipoca, plataformas... (volta ao normal no frame_pre_draw)
	if state == S.PLAY and game.L and game.running:
		Interp.apply(game.ifrac())

## quanto do trecho da música atual o Tomé já andou (0..1): de onde começa a sequência de trechos
## com a mesma música até onde ela acaba (o túnel conta à parte)
func _song_progress(px: float, in_tunnel: bool, tun: Array) -> float:
	if in_tunnel:
		return clampf((px - float(tun[0])) / maxf(float(tun[1]) - float(tun[0]), 1.0), 0.0, 1.0)
	var secs: Array = game.L.get("sections", [])
	if secs.is_empty():
		return 0.0
	var i := 0
	while i + 1 < secs.size() and float(secs[i + 1].x) <= px:
		i += 1
	var sg: String = str(secs[i].get("song", ""))
	var a := i
	while a > 0 and str(secs[a - 1].get("song", "")) == sg:
		a -= 1
	var b := i
	while b + 1 < secs.size() and str(secs[b + 1].get("song", "")) == sg:
		b += 1
	var x0: float = float(secs[a].x)
	var x1: float = float(secs[b + 1].x) if b + 1 < secs.size() else float(game.L.get("spanX", x0 + 10000.0))
	# a noite acaba onde o túnel começa
	if float(tun[1]) > float(tun[0]) and float(tun[0]) > x0 and px < float(tun[0]):
		x1 = minf(x1, float(tun[0]))
	return clampf((px - x0) / maxf(x1 - x0, 1.0), 0.0, 1.0)

## quanto perigo há por perto (para a camada de tambores da música)
func _danger_level() -> float:
	var g := game
	if g.X and g.X.boss_active():
		return 1.0
	if g.K and (g.K.bear_on() or (not g.K.HAWK.is_empty() and g.K.HAWK.active and not g.K.HAWK.done) or (not g.K.FISH.is_empty() and g.K.FISH.active and not g.K.FISH.done)):
		return 1.0
	if g.TR:
		for o in g.TR.T:
			if o.k == "boulder" and o.st in ["drop", "roll"]:
				return 1.0
	var p: Dictionary = g.player
	var px: float = p.x + p.w / 2
	for e in g.EN:
		if not e.dead and abs(e.x - px) < 380 and abs(e.y - p.y) < 220:
			return .65
	return 0.0

var cam_zoom := 1.0
func _zoom_target() -> float:
	var g := game
	if not g.CINE.is_empty():
		return 1.0
	# ação: veículos, cavalgada, chefes, pedra rolando, perseguição
	# cavalgada e veículos: o zoom acompanha a velocidade e os saltos (Vehicles.zoom_want)
	if g.VH and g.VH.seq() != "":
		return g.VH.zoom_want()
	if g.X and g.X.boss_active():
		return .88
	# perseguição do urso: abre mais para mostrar o urso correndo atrás
	if g.K and g.K.bear_chase():
		return .8
	if g.K and (g.K.bear_on() or (not g.K.HAWK.is_empty() and g.K.HAWK.active and not g.K.HAWK.done) or (not g.K.FISH.is_empty() and g.K.FISH.active and not g.K.FISH.done)):
		return .88
	if g.VIL and g.VIL.go and not g.VIL.gone:
		return .9
	if g.TR:
		for o in g.TR.T:
			if o.k == "boulder" and o.st in ["drop", "roll"]:
				return .88
	var p: Dictionary = g.player
	# perto do moinho: a câmera abre para mostrar as pás inteiras
	if g.MV:
		for o in g.MV.MV:
			if o.k == "wheel" and abs(float(o.x) - (p.x + p.w / 2)) < 700:
				return .62
	# paredão alto ao lado: abre até mostrar o topo e um pouco acima
	var tz: float = g.tall_zoom(get_viewport().get_visible_rect().size.y)
	if tz < 1.0:
		return tz
	# calma: perto de uma fogueira, parado
	if abs(p.vx) < .5 and p.onGround:
		for c in g.CHK:
			if abs(c.x - (p.x + p.w / 2)) < 220 and abs(c.y - (p.y + p.h)) < 80:
				return 1.1
	return 1.0

func _physics_process(_d: float) -> void:
	Interp.restore()
	if state == S.PLAY and game.comic_req != "":
		_show_comic(game.comic_req)
		game.comic_req = ""
		return
	if state == S.PLAY:
		var __t := Time.get_ticks_usec()
		# tempo de jogo do placar: conta os passos jogados (o relógio da fase recomeça nas fogueiras
		# grandes e ao cair) e divide pelo ritmo escolhido (44/52/60 passos por segundo)
		if game.running:
			Save.run_secs += 1.0 / float(Engine.physics_ticks_per_second)
		# câmera lenta: só um de cada dois passos roda (o desenho continua liso: a mistura entre passos
		# passa a durar dois passos)
		game.ip_div = 1
		game.ip_phase = 0
		if game.slowmo > 0:
			game.slowmo -= 1
			game.ip_div = 2
			if game.slowmo % 2 == 1:
				game.ip_phase = 1
				return
		game.step()
		Spr.pt("step", __t)

## quadrinho (chefe ou primeira vez em algo novo): o jogo espera até ele acabar
func _show_comic(id: String) -> void:
	state = S.COMIC
	_clear_keys()
	if stick:
		stick._release()
	_show_hud(false)
	var c := preload("res://scripts/ui/comic.gd").new(id)
	c.theme = theme_ui
	ui_layer.add_child(c)
	c.finished.connect(func():
		_clear_keys()
		if state == S.COMIC:
			state = S.PLAY
			_show_hud(true))

# ======================================================================
#  ENTRADA (teclado, controle e toque)
# ======================================================================
func _set_key(k: String, down: bool) -> void:
	if down and not game.keys.get(k, false):
		game.keys[k + "p"] = true
	game.keys[k] = down

func _clear_keys() -> void:
	game.keys.clear()

func _input(e: InputEvent) -> void:
	if e is InputEventScreenTouch or e is InputEventScreenDrag:
		last_touch_ms = Time.get_ticks_msec()
	if state == S.PLAY and not game.CINE.is_empty() and ((e is InputEventScreenTouch and e.pressed) or (e is InputEventMouseButton and e.pressed)):
		# toque avança a fala; no canto de baixo à direita ("PULAR ▸") pula a cena inteira
		var vs := get_viewport().get_visible_rect().size
		var pos: Vector2 = e.position
		if pos.x > vs.x - 170 and pos.y > vs.y - 70:
			game.keys["Kp"] = true
		else:
			game.keys["Jp"] = true
		return
	if e is InputEventKey and not e.echo:
		if e.pressed and e.keycode == KEY_ESCAPE and state != S.PLAY:
			# Esc nos menus: volta para a tela anterior (nas cenas, a própria cena trata o Esc)
			if _go_back():
				get_viewport().set_input_as_handled()
			return
		if e.pressed and (e.keycode == KEY_ESCAPE or e.keycode == KEY_P):
			_toggle_pause("tecla Esc/P")
			return
		if e.pressed and e.keycode == KEY_N:
			# N: mapa da fase (a dica do teclado na tela inicial já anunciava, mas a tecla não fazia nada)
			if state == S.PLAY and game.CINE.is_empty():
				state = S.PAUSE
				pause_reason = ""
				_clear_keys()
				_show_hud(false)
				show_map(false)
			elif state == S.PAUSE and panel and panel.has_meta("map"):
				panel.get_meta("back").call()
			return
		if e.pressed and e.keycode in [KEY_M, KEY_I, KEY_TAB]:
			if state == S.PLAY:
				open_bag()
			elif state == S.BAG:
				if panel and panel.has_meta("assembled"):
					panel.get_meta("ok").call()
				else:
					close_panel()
			return
		if e.pressed and e.keycode in [KEY_ENTER, KEY_KP_ENTER] and panel and panel.has_meta("ok"):
			panel.get_meta("ok").call()
			return
		if KEYMAP.has(e.keycode):
			game.axis_x = 1.0
			_set_key(KEYMAP[e.keycode], e.pressed)
	elif e is InputEventJoypadButton:
		last_joy_ms = Time.get_ticks_msec()
		if _joy_menu_button(e):
			get_viewport().set_input_as_handled()
			return
		var m := {JOY_BUTTON_A: "J", JOY_BUTTON_X: "A", JOY_BUTTON_B: "P", JOY_BUTTON_DPAD_LEFT: "L", JOY_BUTTON_DPAD_RIGHT: "R", JOY_BUTTON_DPAD_UP: "U", JOY_BUTTON_DPAD_DOWN: "S", JOY_BUTTON_BACK: "B", JOY_BUTTON_RIGHT_SHOULDER: "G", JOY_BUTTON_LEFT_SHOULDER: "D"}
		if e.button_index == JOY_BUTTON_Y and e.pressed:
			if state == S.PLAY:
				open_bag()
			elif state == S.BAG:
				if panel and panel.has_meta("assembled"):
					panel.get_meta("ok").call()
				else:
					close_panel()
		elif e.button_index == JOY_BUTTON_START and e.pressed:
			_toggle_pause("botão Start do controle")
		elif m.has(e.button_index):
			_set_key(m[e.button_index], e.pressed)
	elif e is InputEventJoypadMotion:
		if _joy_menu_axis(e):
			get_viewport().set_input_as_handled()
			return
		if e.axis == JOY_AXIS_LEFT_X:
			_set_key("L", e.axis_value < -.3)
			_set_key("R", e.axis_value > .3)
			game.axis_x = clamp(abs(e.axis_value) * 1.25, .4, 1.0)
		elif e.axis == JOY_AXIS_LEFT_Y:
			_set_key("U", e.axis_value < -.55)
			_set_key("S", e.axis_value > .55)

# ---------- menus pelo controle ----------
func _joy_collect(n: Node, out: Array) -> void:
	for ch in n.get_children():
		if ch is BaseButton and ch.is_visible_in_tree() and not ch.disabled and ch.mouse_filter != Control.MOUSE_FILTER_IGNORE:
			out.append(ch)
		_joy_collect(ch, out)

func _joy_buttons() -> Array:
	var out: Array = []
	if panel != null and is_instance_valid(panel) and panel.is_inside_tree():
		_joy_collect(panel, out)
	return out

func _joy_signature(bs: Array) -> String:
	var s := str(bs.size())
	for b in bs:
		s += "|" + (b.text if b is Button else "")
	return s

## escolhe o botão inicial quando um painel novo aparece (mantém a posição se é o mesmo painel refeito)
func _joy_sync(bs: Array) -> void:
	var sig := _joy_signature(bs)
	if sig != joy_sig:
		joy_sig = sig
		joy_idx = 0
		if state == S.BAG and bag_sel != "":
			var k := game.INV.find(bag_sel)
			if k >= 0 and k < bs.size():
				joy_idx = k
	joy_idx = clampi(joy_idx, 0, max(bs.size() - 1, 0))

func _joy_press(b: BaseButton) -> void:
	b.pressed.emit()

## anda para o botão mais próximo na direção pedida (funciona em linhas, colunas e grades)
func _joy_move(bs: Array, d: Vector2) -> void:
	if bs.size() < 2:
		return
	var c: Vector2 = bs[joy_idx].get_global_rect().get_center()
	var best := -1
	var bsc := INF
	for i in bs.size():
		if i == joy_idx:
			continue
		var v: Vector2 = bs[i].get_global_rect().get_center() - c
		var along := v.dot(d)
		if along < 6:
			continue
		var side: float = abs(v.dot(Vector2(-d.y, d.x)))
		var sc := along + side * 2.5
		if sc < bsc:
			bsc = sc
			best = i
	if best < 0:
		# sem vizinho naquele lado: segue a ordem (dá a volta)
		best = (joy_idx + (1 if d.x + d.y > 0 else -1) + bs.size()) % bs.size()
	joy_idx = best

## botão do controle com um painel aberto: direcional escolhe, A confirma, B volta.
## Tela com um único botão (CONTINUAR, FECHAR, ENTRAR...) confirma com qualquer botão.
func _joy_menu_button(e: InputEventJoypadButton) -> bool:
	# fala de personagem na tela: qualquer botão avança (Start continua sendo a pausa)
	if state == S.PLAY and not game.CINE.is_empty() and e.button_index != JOY_BUTTON_START:
		if e.pressed:
			game.keys["Jp"] = true
		return true
	if panel == null or not is_instance_valid(panel) or state == S.PLAY:
		return false
	if e.button_index in [JOY_BUTTON_START, JOY_BUTTON_Y] and state in [S.PAUSE, S.BAG]:
		return false   # Start fecha a pausa, Y fecha a mochila (tratados abaixo)
	if not e.pressed:
		return true
	var bs := _joy_buttons()
	if bs.is_empty():
		# painel do objeto montado: B pula na hora (os outros botões continuam depois que ele aparece)
		if e.button_index == JOY_BUTTON_B and panel.has_meta("assembled"):
			panel.get_meta("back").call()
		elif panel.has_meta("ok"):
			panel.get_meta("ok").call()
		return true
	_joy_sync(bs)
	if bs.size() == 1:
		_joy_press(bs[0])
		return true
	match e.button_index:
		JOY_BUTTON_DPAD_LEFT: _joy_move(bs, Vector2.LEFT)
		JOY_BUTTON_DPAD_RIGHT: _joy_move(bs, Vector2.RIGHT)
		JOY_BUTTON_DPAD_UP: _joy_move(bs, Vector2.UP)
		JOY_BUTTON_DPAD_DOWN: _joy_move(bs, Vector2.DOWN)
		JOY_BUTTON_B, JOY_BUTTON_BACK:
			_go_back()
		_:
			_joy_press(bs[joy_idx])
	return true

func _joy_menu_axis(e: InputEventJoypadMotion) -> bool:
	if panel == null or not is_instance_valid(panel) or state == S.PLAY:
		return false
	if e.axis != JOY_AXIS_LEFT_X and e.axis != JOY_AXIS_LEFT_Y:
		return true
	var was: int = joy_ax.get(e.axis, 0)
	var now := 0
	if e.axis_value > .6:
		now = 1
	elif e.axis_value < -.6:
		now = -1
	joy_ax[e.axis] = now
	if now != 0 and now != was:
		var bs := _joy_buttons()
		if bs.size() > 1:
			_joy_sync(bs)
			_joy_move(bs, Vector2(now, 0) if e.axis == JOY_AXIS_LEFT_X else Vector2(0, now))
	return true

func _joy_ring_update() -> void:
	if joy_ring == null:
		var cl := CanvasLayer.new()
		cl.layer = 120
		add_child(cl)
		joy_ring = Panel.new()
		joy_ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var sb := StyleBoxFlat.new()
		sb.draw_center = false
		sb.set_border_width_all(4)
		sb.border_color = Color("#ffd75a")
		sb.set_corner_radius_all(10)
		sb.shadow_color = Color(1, .8, .2, .45)
		sb.shadow_size = 8
		joy_ring.add_theme_stylebox_override("panel", sb)
		cl.add_child(joy_ring)
	var show := false
	if last_joy_ms > last_touch_ms and state != S.PLAY:
		var bs := _joy_buttons()
		if bs.size() > 1:
			_joy_sync(bs)
			_joy_scroll_to(bs[joy_idx])
			var r: Rect2 = bs[joy_idx].get_global_rect().grow(5)
			joy_ring.position = r.position
			joy_ring.size = r.size
			joy_ring.modulate.a = .75 + .25 * sin(Time.get_ticks_msec() / 160.0)
			show = true
	joy_ring.visible = show

## o botão escolhido pelo controle nunca fica fora da tela: a rolagem acompanha
var _joy_vis_key := ""
func _joy_scroll_to(b: Control) -> void:
	var key := joy_sig + "#" + str(joy_idx)
	if key == _joy_vis_key:
		return
	_joy_vis_key = key
	var n: Node = b.get_parent()
	while n != null and n != panel:
		if n is ScrollContainer:
			(n as ScrollContainer).ensure_control_visible(b)
			return
		n = n.get_parent()

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		# alguns controles Bluetooth mandam "voltar" junto com o botão B: ignora nesse caso
		if Time.get_ticks_msec() - last_joy_ms < 500:
			return
		# gesto de "voltar" pela borda da tela enquanto o polegar está no direcional: não pausa
		if state == S.PLAY and (Time.get_ticks_msec() - last_touch_ms < 900 or (stick and stick.finger != -1)):
			return
		if state == S.PLAY:
			_toggle_pause("gesto/botão Voltar do celular")
		else:
			_go_back()
	elif what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		# perder o foco por um instante (gesto de 3 dedos, barra do sistema): só solta os botões
		_clear_keys()
		if stick:
			stick._release()
	elif what == NOTIFICATION_APPLICATION_PAUSED:
		_clear_keys()
		if stick:
			stick._release()
		if state == S.PLAY:
			_toggle_pause("o jogo saiu da tela (gesto de início/apps do celular)")
			auto_paused_ms = Time.get_ticks_msec()
	elif what == NOTIFICATION_APPLICATION_RESUMED:
		# saiu e voltou rapidinho (gesto sem querer na borda): continua sem abrir a pausa
		if state == S.PAUSE and auto_paused_ms >= 0 and Time.get_ticks_msec() - auto_paused_ms < 3000:
			close_panel()
		auto_paused_ms = -1

## "voltar" (B do controle, Esc, botão/gesto Voltar do Android): cada tela sabe para onde volta
## (meta "back"); mochila, pausa e pista fecham e voltam ao jogo. Devolve se fez alguma coisa.
func _go_back() -> bool:
	if panel != null and is_instance_valid(panel) and panel.has_meta("back"):
		panel.get_meta("back").call()
		return true
	if panel != null and state in [S.BAG, S.PAUSE, S.CLUE]:
		close_panel()
		return true
	# cena da história ou quadrinho na tela: Voltar pula (antes não fazia nada e parecia travado)
	if state in [S.CUT, S.COMIC]:
		for c in ui_layer.get_children():
			if c.has_method("skip") and not c.is_queued_for_deletion() and not c.get("done"):
				c.skip()
				return true
	return false

# ---------- botões de toque ----------
func _make_touch() -> void:
	stick = preload("res://scripts/ui/touch_stick.gd").new()
	stick.set_anchors_preset(Control.PRESET_FULL_RECT)
	stick.mode = Save.getv("opt", "stick", "analog")
	stick.changed.connect(_on_stick)
	hud_layer.add_child(stick)
	var defs = [["J", "btn_jump", 112], ["A", "btn_use", 90], ["G", "btn_golpe", 86]]
	for d in defs:
		var b := TouchScreenButton.new()
		var t: Texture2D = load("res://assets/ui/%s.png" % d[1])
		b.texture_normal = t
		var sc: float = d[2] / float(t.get_width())
		b.scale = Vector2(sc, sc)
		var sh := CircleShape2D.new()
		sh.radius = t.get_width() * .70   # área de toque um pouco maior que o desenho
		b.shape = sh
		b.shape_centered = true
		b.visibility_mode = TouchScreenButton.VISIBILITY_TOUCHSCREEN_ONLY
		b.modulate = Color(1, 1, 1, .85)
		var k: String = d[0]
		b.pressed.connect(func(): _set_key(k, true))
		b.released.connect(func(): _set_key(k, false))
		b.set_meta("k", k)
		b.set_meta("size", d[2])
		hud_layer.add_child(b)
		touch.append(b)

## botão de toque apertado: afunda um pouco (88%) e escurece; ao soltar volta com uma molinha
func _touch_squash(_d: float) -> void:
	var k60: float = clamp(_d * 60.0, .25, 3.0)
	for tb in touch:
		var bsc: float = tb.get_meta("base_sc", tb.scale.x)
		var bp: Vector2 = tb.get_meta("base_pos", tb.position)
		var p: float = tb.get_meta("sq", 0.0)
		var v: float = tb.get_meta("sqv", 0.0)
		var tgt := 1.0 if (tb.visible and tb.is_pressed()) else 0.0
		v += (tgt - p) * (.5 if tgt > p else .2) * k60
		v *= pow(.6, k60)
		p += v * k60
		if tgt == 0.0 and abs(p) < .002 and abs(v) < .002:
			p = 0.0
			v = 0.0
		tb.set_meta("sq", p)
		tb.set_meta("sqv", v)
		var sq: float = 1.0 - .12 * p
		var sz: float = tb.texture_normal.get_width() * bsc
		tb.scale = Vector2.ONE * bsc * sq
		tb.position = bp + Vector2(sz, sz) * (1.0 - sq) / 2.0
		var dk: float = 1.0 - .2 * clamp(p, 0.0, 1.0)
		if tb.get_meta("k") == "A":
			tb.modulate = Color(tb.modulate.r * dk, tb.modulate.g * dk, tb.modulate.b * dk, tb.modulate.a)
		else:
			tb.modulate = Color(dk, dk, dk, tb.modulate.a)

func _on_stick(st: Dictionary) -> void:
	for k in st:
		_set_key(k, st[k])
	game.axis_x = stick.axis if stick.mode == "analog" else 1.0

func apply_controls() -> void:
	var sz: float = {"P": .85, "M": 1.0, "G": 1.2}[Save.getv("opt", "btn_size", "M")]
	var op: float = {"clara": .45, "media": .75, "forte": .95}[Save.getv("opt", "btn_alpha", "media")]
	stick.ui_scale = sz
	stick.opacity = op
	stick.left_handed = Save.getv("opt", "left", false)
	stick.mode = Save.getv("opt", "stick", "analog")
	stick._release()
	for b in touch:
		var base: float = b.get_meta("size") * sz
		var t: Texture2D = b.texture_normal
		b.scale = Vector2.ONE * base / float(t.get_width())
		b.set_meta("base_sc", b.scale.x)
		b.modulate = Color(1, 1, 1, op)
	_layout()

func _layout() -> void:
	var vs := get_viewport().get_visible_rect().size
	var left: bool = Save.getv("opt", "left", false)
	var js := 112.0
	for b in touch:
		if b.get_meta("k") == "J":
			js = float(b.get_meta("base_sc", b.scale.x)) * b.texture_normal.get_width()
	for b in touch:
		var k: String = b.get_meta("k")
		var sz: float = float(b.get_meta("base_sc", b.scale.x)) * b.texture_normal.get_width()
		var pos := Vector2.ZERO
		match k:
			# (distância da borda medida na tela que o Alan aprovou: os botões mais para dentro)
			"J": pos = Vector2(vs.x - 52 - sz, vs.y - 37 - sz)
			"A": pos = Vector2(vs.x - 52 - js - 30 - sz, vs.y - 55 - sz)
			"G": pos = Vector2(vs.x - 58 - (js + sz) / 2, vs.y - 39 - js - 18 - sz)
		if left:
			pos.x = vs.x - pos.x - sz
		var off: Array = Save.getv("opt", "pos_" + k, [0, 0])
		# posição arrastada no editor nunca sai da tela (outro celular, tela menor, botão maior)
		b.position = _keep_in(pos + Vector2(off[0], off[1]), Vector2(sz, sz), vs)
		b.set_meta("base_pos", b.position)
	var so: Array = Save.getv("opt", "pos_stick", [0, 0])
	stick.offset = Vector2(so[0], so[1])
	# mochila e Pipoca: empilhados em cima do botão da picareta
	var gpos := Vector2(vs.x - 100, vs.y - 260)
	var gsz := 86.0
	for b in touch:
		if b.get_meta("k") == "G":
			gsz = float(b.get_meta("base_sc", b.scale.x)) * b.texture_normal.get_width()
			gpos = b.get_meta("base_pos", b.position)
	var bs := 54.0
	var bx: float = gpos.x + (gsz - bs) / 2
	if bag_btn:
		var ob: Array = Save.getv("opt", "pos_bag", [0, 0])
		bag_btn.size = Vector2(bs, bs)
		bag_btn.position = _keep_in(Vector2(bx, gpos.y - 8 - bs) + Vector2(ob[0], ob[1]), Vector2(bs, bs), vs)
	if dog_btn:
		var od: Array = Save.getv("opt", "pos_dog", [0, 0])
		dog_btn.size = Vector2(bs, bs)
		dog_btn.position = _keep_in(Vector2(bx, gpos.y - 16 - bs * 2) + Vector2(od[0], od[1]), Vector2(bs, bs), vs)

## prende um botão de toque dentro da tela (com uma margem pequena)
func _keep_in(p: Vector2, sz: Vector2, vs: Vector2) -> Vector2:
	return Vector2(clamp(p.x, 4.0, max(4.0, vs.x - sz.x - 4.0)), clamp(p.y, 4.0, max(4.0, vs.y - sz.y - 4.0)))

func _make_top_buttons() -> void:
	# no topo só a pausa, no cantinho; mochila e Pipoca ficam empilhados em cima do botão da
	# picareta (ao alcance do polegar). Som e "voltar à fogueira" ficam no menu de pausa
	top_buttons = HBoxContainer.new()
	top_buttons.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	top_buttons.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	top_buttons.offset_left = -56
	top_buttons.offset_right = -8
	top_buttons.offset_top = 6
	top_buttons.offset_bottom = 6
	hud_layer.add_child(top_buttons)
	var pb := TextureButton.new()
	pb.texture_normal = load("res://assets/ui/btn_pause.png")
	pb.ignore_texture_size = true
	pb.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	pb.custom_minimum_size = Vector2(46, 46)
	pb.pressed.connect(_toggle_pause)
	top_buttons.add_child(pb)
	bag_btn = TextureButton.new()
	bag_btn.texture_normal = load("res://assets/ui/btn_bag.png")
	bag_btn.ignore_texture_size = true
	bag_btn.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	bag_btn.size = Vector2(54, 54)
	bag_btn.pressed.connect(func(): open_bag())
	hud_layer.add_child(bag_btn)
	dog_btn = TextureButton.new()
	dog_btn.texture_normal = load("res://assets/ui/btn_dog.png")
	dog_btn.ignore_texture_size = true
	dog_btn.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	dog_btn.size = Vector2(54, 54)
	dog_btn.tooltip_text = "Trocar entre o Milis e a Bag (Q)"
	dog_btn.pressed.connect(func(): game.keys["Dp"] = true)
	dog_btn.visible = false
	hud_layer.add_child(dog_btn)
	# rever a dica do lugar (aparece quando a dica já sumiu)
	hint_btn = TextureButton.new()
	hint_btn.texture_normal = load("res://assets/ui/btn_hint.png")
	hint_btn.ignore_texture_size = true
	hint_btn.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	hint_btn.size = Vector2(42, 42)
	hint_btn.pressed.connect(func(): hud.show_hint_again())
	hint_btn.visible = false
	hud_layer.add_child(hint_btn)

func _small_btn(t: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = t
	b.custom_minimum_size = Vector2(52, 52)
	b.focus_mode = Control.FOCUS_NONE
	b.pressed.connect(cb)
	return b

func _show_hud(v: bool) -> void:
	hud.visible = v
	top_buttons.visible = v
	for b in touch:
		b.visible = v
	stick.visible = v
	if not v:
		stick._release()

# ======================================================================
#  TELAS
# ======================================================================
func _make_theme() -> void:
	theme_ui = Theme.new()
	theme_ui.default_font = Spr.font
	theme_ui.default_font_size = 18
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(.08, .06, .04, .85)
	sb.border_color = Color(.61, .51, .32, .8)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(8)
	sb.content_margin_left = 22
	sb.content_margin_right = 22
	sb.content_margin_top = 10
	sb.content_margin_bottom = 10
	var sbh := sb.duplicate()
	sbh.bg_color = Color(.2, .15, .08, .95)
	sbh.border_color = GOLD
	var sbp := sbh.duplicate()
	sbp.bg_color = Color(.3, .22, .1, 1)
	for st in ["normal", "focus"]:
		theme_ui.set_stylebox(st, "Button", sb)
	theme_ui.set_stylebox("hover", "Button", sbh)
	theme_ui.set_stylebox("pressed", "Button", sbp)
	theme_ui.set_color("font_color", "Button", GOLD)
	theme_ui.set_color("font_hover_color", "Button", Color("#fff1c8"))
	theme_ui.set_color("font_color", "Label", INK)
	theme_ui.set_font("font", "Button", Spr.font_b)
	theme_ui.set_font_size("font_size", "Button", 18)
	# barras de volume: trilho de madeira escura, parte cheia dourada e um botão redondo de latão
	var trk := StyleBoxFlat.new()
	trk.bg_color = Color(.12, .09, .05, .95)
	trk.border_color = Color(.61, .51, .32, .8)
	trk.set_border_width_all(1)
	trk.set_corner_radius_all(5)
	trk.content_margin_top = 4
	trk.content_margin_bottom = 4
	var fil := trk.duplicate()
	fil.bg_color = Color("#c9a24a")
	theme_ui.set_stylebox("slider", "HSlider", trk)
	theme_ui.set_stylebox("grabber_area", "HSlider", fil)
	theme_ui.set_stylebox("grabber_area_highlight", "HSlider", fil)
	var gt := _knob_tex(Color("#f2d28a"))
	theme_ui.set_icon("grabber", "HSlider", gt)
	theme_ui.set_icon("grabber_highlight", "HSlider", _knob_tex(Color("#fff1c8")))
	hud_layer_theme_later()

func _knob_tex(c: Color) -> Texture2D:
	var n := 24
	var im := Image.create(n, n, false, Image.FORMAT_RGBA8)
	for y in n:
		for x in n:
			var d: float = Vector2(x + .5 - n / 2.0, y + .5 - n / 2.0).length()
			var a: float = clamp(n / 2.0 - d, 0.0, 1.0)
			var col: Color = Color("#5a3a1c") if d > n / 2.0 - 3.0 else c.lerp(Color.WHITE, clamp((n / 2.0 - d) / n * .6 - (y - n / 2.0) / n * .3, 0, .4))
			im.set_pixel(x, y, Color(col.r, col.g, col.b, a))
	return ImageTexture.create_from_image(im)

func hud_layer_theme_later() -> void:
	call_deferred("_apply_hud_theme")

func _apply_hud_theme() -> void:
	if top_buttons:
		top_buttons.theme = theme_ui

func close_panel() -> void:
	if panel:
		# some suavemente (o painel sai da lista na hora; só o desenho termina de sumir)
		var old: Control = panel
		panel = null
		old.mouse_filter = Control.MOUSE_FILTER_IGNORE
		for ch in old.get_children():
			if ch is Control:
				ch.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var tw := old.create_tween()
		tw.tween_property(old, "modulate:a", 0.0, .14)
		tw.tween_callback(old.queue_free)
	if state in [S.BAG, S.CLUE, S.PAUSE]:
		state = S.PLAY
		_show_hud(true)
	_clear_keys()

func _overlay(dim: float = .78) -> VBoxContainer:
	if panel:
		panel.queue_free()
	var root := Control.new()
	root.theme = theme_ui
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = Color(0, 0, 0, dim)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(bg)
	var sc := ScrollContainer.new()
	sc.set_anchors_preset(Control.PRESET_FULL_RECT)
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	root.add_child(sc)
	var cc := CenterContainer.new()
	cc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	cc.custom_minimum_size = get_viewport().get_visible_rect().size
	sc.add_child(cc)
	var vb := VBoxContainer.new()
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.add_theme_constant_override("separation", 10)
	cc.add_child(vb)
	ui_layer.add_child(root)
	panel = root
	# aparece com um esmaecer rápido e o conteúdo subindo um pouquinho
	root.modulate.a = 0.0
	var tw := root.create_tween()
	tw.tween_property(root, "modulate:a", 1.0, .2)
	_rise_in(vb, cc)
	return vb

## o conteúdo do painel sobe 14 px até o lugar. Espera o contêiner centralizar primeiro (antes a
## animação partia da posição 0 e o menu ficava grudado no alto da tela, com o título cortado)
func _rise_in(vb: Control, cc: Container) -> void:
	await get_tree().process_frame
	if not is_instance_valid(vb) or not is_instance_valid(cc) or not vb.is_inside_tree():
		return
	var y0: float = vb.position.y
	vb.position.y = y0 + 14
	var tw := vb.create_tween()
	tw.tween_property(vb, "position:y", y0, .22).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	# no fim, o contêiner arruma de novo (se o tamanho mudou no meio, fica centralizado mesmo assim)
	tw.tween_callback(cc.queue_sort)

func _label(t: String, size: int = 18, c: Color = INK, f: Font = null, maxw: float = 0) -> Label:
	var l := Label.new()
	l.text = t
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", c)
	if f:
		l.add_theme_font_override("font", f)
	# celular em pé: nenhum texto passa da largura da tela
	var vw: float = get_viewport().get_visible_rect().size.x - 44.0
	if maxw <= 0 and t.length() > 38:
		maxw = vw
	if maxw > 0:
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size = Vector2(min(maxw, vw), 0)
	return l

func _button(t: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = t
	b.focus_mode = Control.FOCUS_NONE
	b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	b.custom_minimum_size = Vector2(220, 46)
	b.pressed.connect(cb)
	return b

func _atlas_icon(n: String, h: float) -> TextureRect:
	var r = Spr.AR.get(n)
	var tr := TextureRect.new()
	if r == null:
		return tr
	var at := AtlasTexture.new()
	at.atlas = Spr.atlas_tex(r)
	at.region = Rect2(r[0], r[1], r[2], r[3])
	tr.texture = at
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tr.custom_minimum_size = Vector2(h * r[2] / r[3], h)
	tr.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	return tr

# ---------- início ----------
func show_title() -> void:
	state = S.TITLE
	game.running = false
	_show_hud(false)
	Audio.set_song("aero_tema")
	var vb := _overlay(.35)
	# a ilustração da Isis desenhando, escurecida atrás do título (como era antes)
	var img := TextureRect.new()
	img.texture = load("res://assets/ui/cena1.jpg")
	img.set_anchors_preset(Control.PRESET_FULL_RECT)
	img.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	img.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	img.modulate = Color(.8, .8, .8)
	panel.add_child(img)
	panel.move_child(img, 0)
	vb.add_child(_label("CADÊ AS\nMILHAS?!", 50, Color("#f2d28a"), Spr.font_title))
	var eps: int = int(Save.getv("prog", "eps", 1))
	vb.add_child(_label("MILHAS PLUS · EPISÓDIO 1 · BRASIL", 18, Color("#e8c98a"), Spr.font_title))
	if OS.has_feature("teste"):
		vb.add_child(_label("VERSÃO DE TESTE · todos os episódios liberados", 13, Color("#ffb070"), Spr.font_b))
	vb.add_child(_label("O Barão das Milhas Falsas roubou as milhas dos clientes. O Milis vai buscar!", 17, Color("#e8dcc0"), Spr.font_i, 460))
	var sp := Control.new()
	sp.custom_minimum_size = Vector2(0, 8)
	vb.add_child(sp)
	var run := Save.load_run()
	if not run.is_empty():
		vb.add_child(_button("CONTINUAR", func(): start_level(true)))
	if eps >= 2:
		vb.add_child(_button("ESCOLHER EPISÓDIO", _choose_episode))
	else:
		vb.add_child(_button("NOVO JOGO" if not run.is_empty() else "COMEÇAR", func(): _confirm_wipe(func(): start_level(false), show_title)))
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 10)
	var gb := _button("GALERIA", show_gallery)
	gb.custom_minimum_size = Vector2(150, 46)
	row.add_child(gb)
	var ob := _button("OPÇÕES", func(): show_options(false))
	ob.custom_minimum_size = Vector2(150, 46)
	row.add_child(ob)
	vb.add_child(row)
	vb.add_child(_label("Teclado: ← → andar · ↑ ↓ subir/abaixar · Espaço pular · G bastão · F usar · M compartimento · N mapa", 12, Color(.8, .75, .65, .8), null, 460))
	panel.set_meta("ok", func(): start_level(not run.is_empty()))
	# voltar na tela inicial: pergunta antes de fechar o jogo
	panel.set_meta("back", func(): _confirm("SAIR DO JOGO?", "O progresso do último totem de check-in continua salvo.", "SAIR", func(): get_tree().quit(), show_title))

## caixa de confirmação no estilo do jogo. O botão escolhido de início (e o Voltar/B/Enter) é o CANCELAR.
func _confirm(title: String, msg: String, yes_txt: String, yes: Callable, no: Callable) -> void:
	var vb := _overlay(.9)
	vb.add_child(_label(title, 28, GOLD, Spr.font_title))
	vb.add_child(_label(msg, 16, Color("#e8dcc0"), Spr.font_i, 560))
	var sp := Control.new()
	sp.custom_minimum_size = Vector2(0, 6)
	vb.add_child(sp)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 14)
	var cancel := func():
		if panel:
			panel.queue_free()
			panel = null
		no.call()
	var nb := _button("CANCELAR", cancel)
	nb.custom_minimum_size = Vector2(190, 46)
	row.add_child(nb)
	var yb := _button(yes_txt, func():
		if panel:
			panel.queue_free()
			panel = null
		yes.call())
	yb.custom_minimum_size = Vector2(250, 46)
	yb.add_theme_color_override("font_color", Color("#ffb08a"))
	row.add_child(yb)
	vb.add_child(row)
	panel.set_meta("ok", cancel)
	panel.set_meta("back", cancel)

## começar de novo apaga o ponto de retorno: se há um salvo, pergunta antes
func _confirm_wipe(next: Callable, back: Callable) -> void:
	if Save.load_run().is_empty():
		next.call()
		return
	_confirm("COMEÇAR DE NOVO?", "O progresso salvo no último totem será apagado. Isso não tem volta.", "APAGAR E COMEÇAR", next, back)

## escolher o episódio (aparece depois de terminar o primeiro)
const EPISODES := [["GUARULHOS · 1-1 TERMINAL", "Saguão, check-in, segurança e o mezanino."], ["GUARULHOS · 1-2 BAGAGENS", "O subsolo escuro das esteiras e a Bag."], ["GUARULHOS · 1-3 HANGAR", "O pátio na garoa, turbinas, guindastes e o Hangar 7."], ["GUARULHOS · CHEFE", "O Motoboy Turbo na pista."]]
func _choose_episode() -> void:
	var vb := _overlay(.9)
	vb.add_child(_label("ESCOLHA O EPISÓDIO", 30, GOLD, Spr.font_title))
	var eps: int = int(Save.getv("prog", "eps", 1))
	for i in min(eps, EPISODES.size()):
		var lv: int = i
		var b := Save.best(i)
		var st: String = "  " + "★".repeat(int(b.get("stars", 0))) if not b.is_empty() else ""
		vb.add_child(_button(EPISODES[i][0] + st, func():
			_confirm_wipe(func():
				if panel:
					panel.queue_free()
					panel = null
				start_level(false, lv), _choose_episode)))
		vb.add_child(_label(EPISODES[i][1], 13, Color(.8, .75, .65), Spr.font_i))
	var back := func():
		panel.queue_free()
		panel = null
		show_title()
	vb.add_child(_button("VOLTAR", back))
	panel.set_meta("back", back)

## Tela de opções (do início ou da pausa). Compacta: cabe inteira em 540 px de altura.
func show_options(from_pause: bool) -> void:
	var vb := _overlay(.86)
	vb.add_theme_constant_override("separation", 6)
	vb.add_child(_label("OPÇÕES", 28, GOLD, Spr.font_title))
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 4)
	grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	vb.add_child(grid)
	var row_label = func(title: String) -> void:
		var l := _label(title, 15, Color("#e8dcc0"))
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		l.custom_minimum_size = Vector2(170, 0)
		grid.add_child(l)
	var opt_row = func(title: String, key: String, opts: Array, def):
		row_label.call(title)
		var hb := HBoxContainer.new()
		hb.add_theme_constant_override("separation", 5)
		var cur = Save.getv("opt", key, def)
		for o in opts:
			var b := _compact_btn(o[0])
			b.toggle_mode = true
			b.button_pressed = cur == o[1]
			var val = o[1]
			b.pressed.connect(func():
				Save.setv("opt", key, val)
				if key == "tps":
					Engine.physics_ticks_per_second = val
				if key == "sound":
					Audio.set_on(val)
				if key == "lowfx":
					game.low_fx = val
				apply_controls()
				show_options(from_pause))
			hb.add_child(b)
		grid.add_child(hb)
	## volume: − [barra] + e a porcentagem (a barra é para o toque; − e + servem no controle)
	var vol_row = func(title: String, cur: float, setter: Callable, sample: bool):
		row_label.call(title)
		var hb := HBoxContainer.new()
		hb.add_theme_constant_override("separation", 5)
		var sl := HSlider.new()
		sl.min_value = 0
		sl.max_value = 100
		sl.step = 5
		sl.value = round(cur * 100.0)
		sl.focus_mode = Control.FOCUS_NONE
		sl.custom_minimum_size = Vector2(190, 30)
		sl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		var pct := _label("%d%%" % int(sl.value), 14, Color("#e8dcc0"))
		pct.custom_minimum_size = Vector2(46, 0)
		var dragging := [false]
		sl.drag_started.connect(func(): dragging[0] = true)
		sl.drag_ended.connect(func(_ch: bool):
			dragging[0] = false
			setter.call(sl.value / 100.0, true)
			if sample:
				Audio.play("item", -4))
		sl.value_changed.connect(func(v: float):
			pct.text = "%d%%" % int(v)
			setter.call(v / 100.0, not dragging[0]))
		var mb := _compact_btn("−")
		mb.custom_minimum_size = Vector2(40, 0)
		mb.pressed.connect(func():
			sl.value = max(0.0, sl.value - 10)
			if sample:
				Audio.play("item", -4))
		var pb := _compact_btn("+")
		pb.custom_minimum_size = Vector2(40, 0)
		pb.pressed.connect(func():
			sl.value = min(100.0, sl.value + 10)
			if sample:
				Audio.play("item", -4))
		hb.add_child(mb)
		hb.add_child(sl)
		hb.add_child(pb)
		hb.add_child(pct)
		grid.add_child(hb)
	opt_row.call("Controle", "stick", [["Analógico", "analog"], ["Direcional", "dpad"], ["Gamepad", "gamepad"]], "analog")
	opt_row.call("Tamanho dos botões", "btn_size", [["Pequeno", "P"], ["Médio", "M"], ["Grande", "G"]], "M")
	opt_row.call("Transparência", "btn_alpha", [["Clara", "clara"], ["Média", "media"], ["Forte", "forte"]], "media")
	opt_row.call("Mão", "left", [["Destro", false], ["Canhoto", true]], false)
	opt_row.call("Velocidade", "tps", [["Normal", 44], ["Rápida", 52], ["Muito rápida", 60]], 44)
	opt_row.call("Tutorial (dicas)", "tutorial", [["Ligado", true], ["Desligado", false]], true)
	opt_row.call("Som", "sound", [["Ligado", true], ["Desligado", false]], true)
	vol_row.call("Música", Audio.vol_music, Audio.set_music_vol, false)
	vol_row.call("Efeitos sonoros", Audio.vol_sfx, Audio.set_sfx_vol, true)
	opt_row.call("Vibração", "vibrate", [["Sim", true], ["Não", false]], true)
	opt_row.call("Tremor da tela", "shake", [["Sim", true], ["Não", false]], true)
	vb.add_child(_label("Destro: movimento à esquerda e PULAR à direita. Canhoto: ao contrário.", 12, Color(.8, .75, .65), Spr.font_i))
	var back := func():
		if from_pause:
			_pause_menu()
		else:
			panel.queue_free()
			panel = null
			show_title()
	var brow := HBoxContainer.new()
	brow.alignment = BoxContainer.ALIGNMENT_CENTER
	brow.add_theme_constant_override("separation", 12)
	var eb := _button("POSICIONAR BOTÕES", func(): _edit_controls(from_pause))
	eb.custom_minimum_size = Vector2(230, 42)
	brow.add_child(eb)
	var bk := _button("VOLTAR", back)
	bk.custom_minimum_size = Vector2(160, 42)
	brow.add_child(bk)
	vb.add_child(brow)
	panel.set_meta("ok", back)
	panel.set_meta("back", back)

## botão baixinho (opções): mesmo estilo do jogo, com menos margem em cima e embaixo
var _cstyles := {}
func _compact_btn(t: String) -> Button:
	if _cstyles.is_empty():
		for st in ["normal", "hover", "pressed", "focus"]:
			var sb: StyleBoxFlat = theme_ui.get_stylebox(st, "Button").duplicate()
			sb.content_margin_top = 5
			sb.content_margin_bottom = 5
			sb.content_margin_left = 12
			sb.content_margin_right = 12
			_cstyles[st] = sb
	var b := Button.new()
	b.text = t
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", 14)
	for st in _cstyles:
		b.add_theme_stylebox_override(st, _cstyles[st])
	return b

## editor: arraste o direcional e os botões para onde preferir
func _edit_controls(from_pause: bool) -> void:
	if panel:
		panel.queue_free()
		panel = null
	var ed := _CtrlEditor.new()
	ed.main = self
	# botões no estilo do jogo (sem o tema saíam cinza, no estilo padrão) e centralizados no alto
	ed.theme = theme_ui
	ed.set_anchors_preset(Control.PRESET_FULL_RECT)
	ui_layer.add_child(ed)
	panel = ed
	var hb := HBoxContainer.new()
	hb.set_anchors_preset(Control.PRESET_TOP_WIDE)
	hb.alignment = BoxContainer.ALIGNMENT_CENTER
	hb.offset_top = 16
	hb.add_theme_constant_override("separation", 12)
	ed.add_child(hb)
	var ok := _button("PRONTO", func():
		ed.queue_free()
		panel = null
		show_options(from_pause))
	var rst := _button("RESTAURAR", func():
		for k in ["J", "A", "G", "stick", "bag", "dog"]:
			Save.setv("opt", "pos_" + k, [0, 0])
		_layout())
	hb.add_child(rst)
	hb.add_child(ok)
	panel.set_meta("ok", func(): ok.pressed.emit())
	panel.set_meta("back", func(): ok.pressed.emit())

class _CtrlEditor extends Control:
	var main
	var drag := ""
	var last := Vector2.ZERO
	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_STOP
	func _process(_d: float) -> void:
		queue_redraw()
	func _targets() -> Dictionary:
		var t := {}
		for b in main.touch:
			var sz: float = float(b.get_meta("base_sc", b.scale.x)) * b.texture_normal.get_width()
			t[b.get_meta("k")] = [b.get_meta("base_pos", b.position) + Vector2(sz, sz) / 2, sz / 2, b]
		t["stick"] = [main.stick._home(), main.stick.radius * main.stick.ui_scale, null]
		for nb in [["bag", main.bag_btn], ["dog", main.dog_btn]]:
			var cb: TextureButton = nb[1]
			if cb:
				t[nb[0]] = [cb.position + cb.size / 2, cb.size.x / 2, cb]
		return t
	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), Color(0, 0, 0, .55))
		draw_string(Spr.font_i, Vector2(0, size.y / 2), "Arraste o direcional e os botões para onde preferir.", HORIZONTAL_ALIGNMENT_CENTER, size.x, 18, Color(1, .95, .8))
		var t := _targets()
		for k in t:
			var c: Vector2 = t[k][0]
			var r: float = t[k][1]
			draw_circle(c, r + 6, Color(1, .85, .4, .25 if drag != k else .5))
			draw_arc(c, r + 6, 0, TAU, 48, Color(1, .9, .6, .9), 3, true)
			if t[k][2]:
				var sz: float = r * 2
				draw_texture_rect(t[k][2].texture_normal, Rect2(c - Vector2(r, r), Vector2(sz, sz)), false)
			elif k == "stick" and main.stick.tex.has("base"):
				# o analógico de verdade (antes era só um disco liso)
				draw_texture_rect(main.stick.tex.base, Rect2(c - Vector2(r, r), Vector2(r, r) * 2), false)
				if main.stick.tex.has("knob"):
					draw_texture_rect(main.stick.tex.knob, Rect2(c - Vector2(r, r) * .5, Vector2(r, r)), false)
	func _gui_input(e: InputEvent) -> void:
		var pos := Vector2.ZERO
		var down := false
		var moving := false
		if e is InputEventScreenTouch:
			pos = e.position
			down = e.pressed
			if not down:
				if drag != "":
					Save.flush()
				drag = ""
				return
		elif e is InputEventMouseButton:
			pos = e.position
			down = e.pressed
			if not down:
				if drag != "":
					Save.flush()
				drag = ""
				return
		elif e is InputEventScreenDrag or e is InputEventMouseMotion:
			pos = e.position
			moving = true
		else:
			return
		if down:
			var t := _targets()
			for k in t:
				if pos.distance_to(t[k][0]) < t[k][1] + 14:
					drag = k
					last = pos
					return
		elif moving and drag != "":
			var d := pos - last
			last = pos
			var cur: Array = Save.getv("opt", "pos_" + drag, [0, 0])
			# só na memória enquanto arrasta; grava no disco ao soltar
			Save.cfg.set_value("opt", "pos_" + drag, [cur[0] + d.x, cur[1] + d.y])
			main._layout()

func start_level(cont: bool, lvl: int = 0) -> void:
	Spr.warm()
	# contorno dos telhados para a neve (lê a arte da placa de vídeo: lento, então faz agora e não no meio do jogo)
	for rn in ["v_house1", "v_house2"]:
		if Spr.AR.has(rn):
			WorldNature._roof_line(rn)
	game.CLUEGOT.clear()
	game.SPECGOT.clear()
	game.DRAWN.clear()
	game.lives = 3
	game.coin_life = 0
	var run := Save.load_run()
	if cont and not run.is_empty():
		game.restore_run(run)
		_restore_extra(run)
		# tempo jogado: o salvo (ou o desta sessão, se for maior: voltar à fogueira depois de perder)
		Save.run_secs = max(float(run.get("secs", 0.0)), Save.run_secs)
	else:
		Save.clear_run()
		game.load_level(lvl)
		Save.run_secs = 0.0
	# gráficos sempre no máximo (a opção "Leves" e a redução automática saíram)
	game.low_fx = false
	hud.reset_run()
	_build_world()
	_warm_shaders()
	game.running = false
	if cont:
		show_intro(true)
	else:
		if game.level_idx > 0 or Save.getv("opt", "tut_asked", false):
			show_intro(false)
		else:
			_ask_tutorial(func(): show_intro(false))

## completa o ponto de retorno antes de gravar (Save.before_save_run):
##  - lápis e frutas que a gangorra e os arbustos derrubaram e ainda estão no chão (antes sumiam)
##  - chefe que levou o último golpe mas ainda está caindo/fugindo conta como vencido
func _before_save_run(d: Dictionary) -> void:
	if game == null:
		return
	var ex := {}
	if game.SL:
		var drops: Array = []
		for o in game.SL.DROPS:
			if o.got:
				continue
			drops.append({"k": str(o.k), "x": float(o.x), "y": float(o.gy if not o.land else o.y), "gy": float(o.gy), "c": str(o.get("c", ""))})
		ex["drops"] = drops
	d["ex"] = ex
	if game.X and not game.X.BOSS.is_empty() and d.has("x"):
		var b: Dictionary = game.X.BOSS
		if b.get("done", false) or b.get("st", "") == "down" or (b.has("hp") and int(b.hp) <= 0):
			d.x["boss"] = true
	if game.K and d.has("k"):
		for kk in [["hawk", game.K.HAWK, ["flee"]], ["bear", game.K.BEAR, ["flee", "down"]], ["fish", game.K.FISH, ["down"]]]:
			var o: Dictionary = kk[1]
			if o.is_empty():
				continue
			if o.get("done", false) or o.get("st", "") in kk[2] or (o.get("active", false) and o.has("hp") and int(o.hp) <= 0):
				d.k[kk[0]] = true

## o que _before_save_run guardou volta para o mundo
func _restore_extra(run: Dictionary) -> void:
	var ex: Dictionary = run.get("ex", {})
	if game.SL:
		for o in ex.get("drops", []):
			var dd := {"k": str(o.get("k", "pen")), "x": float(o.get("x", 0)), "y": float(o.get("y", 0)), "vx": 0.0, "vy": 0.0, "gy": float(o.get("gy", 0)), "land": true, "got": false}
			if dd.k == "pen":
				dd["c"] = str(o.get("c", GameData.PEN_LIST[0])) if str(o.get("c", "")) != "" else GameData.PEN_LIST[0]
			game.SL.DROPS.append(dd)

## faixas de cinema: entram nas falas, na apresentação dos chefes e na câmera lenta do golpe final
func _update_cine_bars() -> void:
	if cine_bars == null:
		return
	var want := 0.0
	if Polish.g == null and game.L:
		Polish.g = game
	if state == S.PLAY and game.L and game.running:
		if not game.CINE.is_empty() or game.slowmo > 0:
			want = 1.0
		else:
			for b in Polish.bosses():
				if b.ref.get("st", "") == "intro":
					want = 1.0
	cine_bars.target = want
	hud.cine_bar = cine_bars.px()

## grande fogueira: fim de um período. Pausa, lembrança da Isis e escolha de seguir ou parar.
const REST_INFO := {
	1: ["FIM DA MANHÃ", "Toda tarde ela desenhava na varanda, esperando eu voltar do trabalho.", "Aguenta firme, filha. Estou chegando."],
	2: ["FIM DA TARDE", "Pega-pega no quintal... e ela sempre ganhava de mim.", "Aguenta firme, filha. Estou chegando."],
	3: ["FIM DO PÂNTANO", "Pular nas poças com a lanterna acesa. Ela nunca teve medo da chuva.", "Estou chegando, Isis. Não tenha medo do escuro."],
	4: ["FIM DA NEVE", "O boneco de neve ficou com o meu gorro. Ela riu a tarde inteira.", "Falta pouco, filha. Aguenta firme."],
	5: ["FIM DO CÉU", "Soltar pipa no morro... ela dizia que um dia ia voar de avião.", "Voei por você, filha. Agora falta só a mina."],
}

func _on_rest(n: int) -> void:
	state = S.REST
	_clear_keys()
	_show_hud(false)
	if panel:
		panel.queue_free()
	var root := Control.new()
	root.theme = theme_ui
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	# tela do totem grande: uma imagem da fase (se existir) e o texto da parada
	var bgc := ColorRect.new()
	bgc.color = Color(0.03, 0.05, 0.09, 0.94)
	bgc.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(bgc)
	var img_path := "res://assets/ui/rest_%d_%d.jpg" % [game.level_idx + 1, n]
	if ResourceLoader.exists(img_path):
		var tr := TextureRect.new()
		tr.texture = load(img_path)
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		tr.set_anchors_preset(Control.PRESET_FULL_RECT)
		tr.modulate = Color(1, 1, 1, .85)
		root.add_child(tr)
	var info: Array = ["CHECK-IN FEITO", "O Milis respira fundo (ou o que um robô faz no lugar disso).", "Mais um trecho, e as milhas voltam para quem é dono delas."]
	var lr: Dictionary = game.L.get("rests", {})
	if lr.has(str(n)):
		info = lr[str(n)]
	var vb := VBoxContainer.new()
	vb.alignment = BoxContainer.ALIGNMENT_END
	vb.set_anchors_preset(Control.PRESET_FULL_RECT)
	vb.offset_bottom = -18
	vb.add_theme_constant_override("separation", 8)
	vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(vb)
	var title := _label(info[0] + " · progresso salvo", 15, Color("#cdbfa6"))
	var mem := _label(info[1], 17, Color("#e8dcc0"), Spr.font_i, 620)
	var line := _label("“" + info[2] + "”", 22, GOLD, Spr.font_title, 640)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 14)
	var go := func():
		if panel:
			panel.queue_free()
			panel = null
		state = S.PLAY
		_show_hud(true)
		_clear_keys()
		game.running = true
	var b_go := _button("CONTINUAR", go)
	var b_later := _button("JOGAR MAIS TARDE", func():
		if panel:
			panel.queue_free()
			panel = null
		show_title())
	# os botões só valem depois que a lembrança termina de aparecer (antes, um toque de quem vinha
	# correndo ou um Enter/A apertado pulava a fogueira grande sem querer)
	for b in [b_go, b_later]:
		b.disabled = true
		row.add_child(b)
	for c in [title, mem, line, row]:
		c.modulate.a = 0.0
		vb.add_child(c)
	ui_layer.add_child(root)
	panel = root
	Audio.set_song("aero_tema")
	var tw := root.create_tween()
	tw.tween_interval(.4)
	tw.tween_property(title, "modulate:a", 1.0, .5)
	tw.tween_property(mem, "modulate:a", 1.0, .8)
	tw.tween_interval(1.2)
	tw.tween_property(line, "modulate:a", 1.0, .8)
	tw.tween_interval(.6)
	tw.tween_property(row, "modulate:a", 1.0, .5)
	tw.tween_callback(func():
		if panel != root or not is_instance_valid(root):
			return
		for b in [b_go, b_later]:
			b.disabled = false
		root.set_meta("ok", go))

## no começo de um jogo novo: quer as dicas do tutorial?
func _ask_tutorial(next: Callable) -> void:
	state = S.INTRO
	_show_hud(false)
	var vb := _overlay(.9)
	vb.add_child(_label("ANTES DE COMEÇAR", 30, GOLD, Spr.font_title))
	vb.add_child(_label("Quer ajuda do tutorial? As dicas explicam os controles e os desafios pelo caminho. Dá para mudar depois em OPÇÕES.", 17, Color("#e8dcc0"), Spr.font_i, 620))
	var pick := func(on: bool):
		Save.setv("opt", "tutorial", on)
		Save.setv("opt", "tut_asked", true)
		panel.queue_free()
		panel = null
		next.call()
	vb.add_child(_button("SIM, QUERO DICAS", func(): pick.call(true)))
	vb.add_child(_button("NÃO, QUERO DESCOBRIR SOZINHO", func(): pick.call(false)))
	panel.set_meta("ok", func(): pick.call(true))

func show_intro(cont: bool) -> void:
	state = S.INTRO
	_show_hud(false)
	var vb := _overlay(.88)
	vb.add_child(_label(str(game.L.get("introSub", "EPISÓDIO %d" % (game.level_idx + 1))), 16, Color("#cdbfa6"), Spr.font_title))
	var img := TextureRect.new()
	var ip: String = game.L.get("introImg", "res://assets/ui/cena1.jpg")
	img.texture = load(ip) if ResourceLoader.exists(ip) else load("res://assets/ui/cena1.jpg")
	img.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	img.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	img.custom_minimum_size = Vector2(520, 190)
	img.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	vb.add_child(img)
	vb.add_child(_label(game.L.name.to_upper(), 30, GOLD, Spr.font_title))
	vb.add_child(_label(game.L.intro, 16, Color("#e8dcc0"), Spr.font_i, 640))
	var go := func():
		close_panel()
		state = S.PLAY
		game.running = true
		_show_hud(true)
		if cont:
			game.flash("Você continua do último totem de check-in.")
	vb.add_child(_button("ENTRAR", go))
	panel.set_meta("ok", go)

var pause_reason := ""
var auto_paused_ms := -1

func _toggle_pause(reason: String = "botão II") -> void:
	if state == S.PLAY:
		pause_reason = reason
		state = S.PAUSE
		_clear_keys()
		_show_hud(false)
		_pause_menu()
	elif state == S.PAUSE:
		close_panel()

func _pause_menu() -> void:
	var vb := _overlay(.7)
	vb.add_child(_label("PAUSA", 34, GOLD, Spr.font_title))
	if pause_reason != "":
		vb.add_child(_label("(pausado por: %s)" % pause_reason, 12, Color("#a89a80"), Spr.font_i))
	vb.add_child(_button("CONTINUAR", close_panel))
	var sb := _button("SOM: " + ("LIGADO" if Audio.on else "DESLIGADO"), func(): pass)
	sb.pressed.connect(func():
		Audio.set_on(not Audio.on)
		sb.text = "SOM: " + ("LIGADO" if Audio.on else "DESLIGADO"))
	vb.add_child(sb)
	vb.add_child(_button("VOLTAR AO ÚLTIMO TOTEM", func():
		close_panel()
		if game.RD and game.RD.riding:
			# na cavalgada o ponto de volta é o começo da trilha (antes o pedido ficava guardado e,
			# no fim da cavalgada, mandava o Tomé de volta para a fogueira de repente)
			game.RD.restart()
		elif game.VH and game.VH.active():
			game._back_to_fire()
		else:
			game.keys["Bp"] = true))
	vb.add_child(_button("MAPA DA FASE", func(): show_map(true)))
	vb.add_child(_button("OPÇÕES", func(): show_options(true)))
	# sair para o menu perde o que foi feito desde a última fogueira: pergunta antes
	vb.add_child(_button("MENU INICIAL", func():
		_confirm("VOLTAR AO MENU INICIAL?", "O que você fez depois do último totem não fica salvo.", "IR PARA O MENU", show_title, _pause_menu)))
	panel.set_meta("ok", close_panel)
	panel.set_meta("back", close_panel)

# ---------- mochila ----------
func open_bag(l = null) -> void:
	if state != S.PLAY:
		return
	state = S.BAG
	_clear_keys()
	_show_hud(false)
	bag_sel = ""
	_render_bag("")

## pares de objetos da mochila que se juntam (receitas com as duas peças)
func _bag_pairs() -> Array:
	var out: Array = []
	for r in GameData.RECIPES:
		if game.has_item(r[0]) and game.has_item(r[1]):
			out.append(r)
	return out

## o que cada objeto montado faz (frase do painel de montagem)
const BUILT_INFO := {
	"cracha": "Crachá da área restrita: encoste na leitora da porta da segurança.",
	"fusivel_ok": "Fusível emendado: encaixe no gerador de emergência para religar o portão.",
}

## juntou: antes de voltar ao jogo, mostra o objeto novo montado (as peças voam e se juntam, o objeto
## aparece grande, girando e brilhando, com o nome e o que ele faz). Tocar continua.
func _bag_combined(res: String, msg: String) -> void:
	var pa := ""
	var pb := ""
	for r in GameData.RECIPES:
		if r[2] == res:
			pa = r[0]
			pb = r[1]
	if panel:
		panel.queue_free()
	var root := Control.new()
	root.theme = theme_ui
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	var asm := _Assemble.new()
	asm.a = pa
	asm.b = pb
	asm.res = res
	asm.title = GameData.ITEM_INFO[res][0] if GameData.ITEM_INFO.has(res) else res
	asm.desc = BUILT_INFO.get(res, msg)
	asm.font_t = Spr.font_title
	asm.font_i = Spr.font_i
	asm.gold = GOLD
	root.add_child(asm)
	ui_layer.add_child(root)
	panel = root
	_clear_keys()
	# tocar/confirmar só continua depois que o objeto apareceu (o mesmo toque do JUNTAR não pula o
	# painel); Voltar (B, Esc) pula na hora
	var go := func(skip: bool = false):
		if not is_instance_valid(asm) or asm.done or (asm.t < asm.READY and not skip):
			return
		asm.done = true
		_bag_combined_go(res, msg)
	asm.cont = go
	panel.set_meta("ok", go)
	panel.set_meta("back", go.bind(true))
	panel.set_meta("assembled", true)

## painel de montagem: as duas peças voam e se encaixam num clarão; o objeto novo aparece grande,
## girando como uma moeda e brilhando, com o nome e a frase do que ele faz
class _Assemble extends Control:
	const READY := 1.15
	var a := ""
	var b := ""
	var res := ""
	var title := ""
	var desc := ""
	var font_t: Font
	var font_i: Font
	var gold := Color("#e8d39a")
	var t := 0.0
	var done := false
	var cont: Callable
	var _snd := false
	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_STOP
		position = Vector2.ZERO
		size = get_viewport_rect().size
	func _process(d: float) -> void:
		size = get_viewport_rect().size
		t += d
		if not _snd and t > .55:
			_snd = true
			Audio.play("special")
			Audio.vib(60)
		queue_redraw()
	func _gui_input(e: InputEvent) -> void:
		if (e is InputEventMouseButton and e.pressed) or (e is InputEventScreenTouch and e.pressed):
			accept_event()
			if cont.is_valid():
				cont.call()
	func _icon(id: String, c: Vector2, h: float, rot: float, sx: float, al: float) -> void:
		var r = Spr.AR.get("it_" + id)
		if r == null:
			return
		var w: float = h * r[2] / r[3]
		draw_set_transform(c, rot, Vector2(sx, 1.0))
		draw_texture_rect_region(Spr.atlas_tex(r), Rect2(-w / 2, -h / 2, w, h), Rect2(r[0], r[1], r[2], r[3]), Color(1, 1, 1, al))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	func _draw() -> void:
		Spr.begin(self)
		var vs: Vector2 = size
		var fade: float = clamp(t / .2, 0, 1)
		draw_rect(Rect2(Vector2.ZERO, vs), Color(.02, .02, .05, .86 * fade))
		var c := Vector2(vs.x * .5, vs.y * .4)
		var hsz: float = clamp(vs.y * .3, 120.0, 220.0)
		# 1) as peças voam de lados opostos girando e se encaixam no meio
		if t < .62:
			var u: float = clamp((t - .08) / .5, 0, 1)
			var e: float = u * u * (3.0 - 2.0 * u)
			for k in 2:
				var sd: float = -1.0 if k == 0 else 1.0
				var p0 := c + Vector2(sd * vs.x * .3, 30)
				var p := p0.lerp(c, e) + Vector2(0, -sin(e * PI) * 90)
				_icon(a if k == 0 else b, p, hsz * .55, sd * (1.0 - e) * 2.6, 1.0, fade)
		# 2) clarão do encaixe
		var fl: float = clamp(1.0 - abs(t - .6) / .16, 0, 1)
		if fl > 0:
			Spr.glow(c.x, c.y, hsz * (.7 + fl), Color(1, .95, .75, .9 * fl))
			for i in 12:
				var an: float = TAU * i / 12.0
				var rr: float = hsz * (.3 + (t - .44) * 2.2)
				draw_circle(c + Vector2(cos(an), sin(an)) * rr, 5.0 * fl, Color(1, .9, .5, fl))
		# 3) o objeto novo, grande, girando e brilhando
		if t > .52:
			var v: float = clamp((t - .52) / .4, 0, 1)
			var pop: float = v + sin(v * PI) * .35
			var ray_a: float = clamp((t - .6) / .4, 0, 1)
			for i in 12:
				var an2: float = t * .45 + TAU * i / 12.0
				var p1 := c + Vector2(cos(an2), sin(an2)) * hsz * .45
				var p2 := c + Vector2(cos(an2 + .1), sin(an2 + .1)) * hsz * 1.25
				var p3 := c + Vector2(cos(an2 - .1), sin(an2 - .1)) * hsz * 1.25
				draw_colored_polygon(PackedVector2Array([p1, p2, p3]), Color(1, .86, .45, .16 * ray_a))
			Spr.glow(c.x, c.y, hsz * 1.1, Color(1, .85, .4, .45 * ray_a))
			var spin: float = cos((t - .52) * 2.2)
			if abs(spin) < .12:
				spin = .12 * (1.0 if spin >= 0 else -1.0)
			var bob: float = sin(t * 2.4) * 6.0
			_icon(res, c + Vector2(0, bob), hsz * pop, sin(t * 1.3) * .06, spin, 1.0)
			# brilhinhos em volta
			for i in 5:
				var ph: float = fmod(t * .7 + i * .2, 1.0)
				var sp := c + Vector2(cos(i * 2.4 + t * .3), sin(i * 1.7)) * hsz * .7
				var ss: float = sin(ph * PI) * 7.0
				draw_line(sp - Vector2(ss, 0), sp + Vector2(ss, 0), Color(1, 1, 1, .9 * ray_a), 2.0, true)
				draw_line(sp - Vector2(0, ss), sp + Vector2(0, ss), Color(1, 1, 1, .9 * ray_a), 2.0, true)
		# 4) nome, o que faz e "toque para continuar"
		var ta: float = clamp((t - .75) / .3, 0, 1)
		if ta > 0:
			var ty: float = c.y + hsz * .82 + (1.0 - ta) * 16.0
			Spr.text("VOCÊ MONTOU:", c.x, ty, 15, Color(.85, .8, .7, ta), HORIZONTAL_ALIGNMENT_CENTER, font_i)
			Spr.text(title.to_upper(), c.x, ty + 40, 36, Color(gold.r, gold.g, gold.b, ta), HORIZONTAL_ALIGNMENT_CENTER, font_t, 6, Color(0, 0, 0, .6 * ta))
			var lines: Array = _wrap(desc, min(vs.x - 80.0, 640.0), 18)
			for i in lines.size():
				Spr.text(lines[i], c.x, ty + 74 + i * 24, 18, Color(.94, .9, .8, ta), HORIZONTAL_ALIGNMENT_CENTER, font_i)
			if t > READY:
				var bl: float = .55 + .45 * sin(t * 4.0)
				Spr.text("toque para continuar", c.x, min(vs.y - 22, ty + 92 + lines.size() * 24), 15, Color(1, .93, .7, bl), HORIZONTAL_ALIGNMENT_CENTER, font_i)
	func _wrap(s: String, mw: float, fs: int) -> Array:
		var out: Array = []
		var cur := ""
		for w in s.split(" "):
			var tst: String = w if cur == "" else cur + " " + w
			if font_i and font_i.get_string_size(tst, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x > mw and cur != "":
				out.append(cur)
				cur = w
			else:
				cur = tst
		if cur != "":
			out.append(cur)
		return out

## (depois do painel de montagem) fecha a mochila e já usa o objeto novo, na trava que está perto
## ou chegando nela
func _bag_combined_go(res: String, msg: String) -> void:
	close_panel()
	var nl = game.player.nearL
	if nl != null and not nl.done and nl.need == res:
		if nl.get("crank"):
			game.flash(msg + " Agora gire: toque várias vezes no botão da manivela!", 240)
		else:
			game.use_lock(nl)
		return
	for l in game.LOCKS:
		if not l.done and l.need == res:
			game.flash(msg + " Leve até " + str(l.get("short", "a trava")) + ": ao chegar perto, ele é usado sozinho.", 260)
			return
	game.flash(msg, 220)

func _render_bag(msg: String) -> void:
	var vb := _overlay(.82)
	vb.add_child(_label("COMPARTIMENTO", 30, GOLD, Spr.font_title))
	# peças que se encaixam: aviso bem claro e um botão grande para juntar
	var pairs: Array = _bag_pairs()
	var glow_ids := {}
	for r in pairs:
		glow_ids[r[0]] = 1
		glow_ids[r[1]] = 1
	if not pairs.is_empty():
		vb.add_child(_label("✦ Estas peças se encaixam! Junte para usar. ✦", 20, Color("#ffd76a"), Spr.font_title, 700))
		for r in pairs:
			var rr: Array = r
			var jb := _button("JUNTAR  " + game.item_name(rr[0]).to_upper() + "  +  " + game.item_name(rr[1]).to_upper(), func():
				var m2 := game.try_combine(rr[0], rr[1])
				if m2 != "":
					_bag_combined(rr[2], m2))
			jb.custom_minimum_size = Vector2(420, 58)
			jb.modulate = Color(1.15, 1.05, .8)
			var tw := jb.create_tween().set_loops()
			tw.tween_property(jb, "scale", Vector2(1.04, 1.04), .45)
			tw.tween_property(jb, "scale", Vector2(1, 1), .45)
			jb.pivot_offset = Vector2(210, 29)
			vb.add_child(jb)
	var items := HBoxContainer.new()
	items.alignment = BoxContainer.ALIGNMENT_CENTER
	items.add_theme_constant_override("separation", 10)
	vb.add_child(items)
	if game.INV.is_empty():
		items.add_child(_label("O compartimento está vazio. Procure objetos pelo caminho.", 16, Color("#d8ccb0"), Spr.font_i))
	for id in game.INV:
		var b := Button.new()
		b.focus_mode = Control.FOCUS_NONE
		b.toggle_mode = true
		b.button_pressed = bag_sel == id
		b.custom_minimum_size = Vector2(118, 104)
		var inner := VBoxContainer.new()
		inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
		inner.set_anchors_preset(Control.PRESET_FULL_RECT)
		inner.alignment = BoxContainer.ALIGNMENT_CENTER
		var ic := _atlas_icon("it_" + id, 54)
		ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
		inner.add_child(ic)
		var nl := _label(GameData.ITEM_INFO[id][0], 13, INK)
		nl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		inner.add_child(nl)
		b.add_child(inner)
		var iid: String = id
		if glow_ids.has(id):
			b.modulate = Color(1.25, 1.1, .7)
		b.pressed.connect(func(): _bag_tap(iid))
		items.add_child(b)
	var m := msg
	if m == "" and not pairs.is_empty():
		m = "Toque em JUNTAR: o objeto novo já é usado sozinho."
	if m == "":
		if game.INV.size() > 1:
			m = "Toque num objeto e depois em outro para combinar."
		elif game.INV.size() == 1:
			m = game.item_msg(game.INV[0])
	if Save.getv("opt", "stick", "") == "gamepad":
		# no controle: o direcional escolhe e o A confirma; o X usa
		m = m.replace("Toque num objeto e depois em outro", "Escolha um objeto com o direcional e aperte A; depois outro")
		m = m.replace("Toque em ", "Escolha ").replace("toque em ", "escolha ").replace("toque no botão da manivela", "aperte X para girar a manivela").replace("toque no botão ✔", "aperte X para usar").replace("toque em ✔", "aperte X")
	vb.add_child(_label(m, 16, Color("#e8d8b0"), Spr.font_i, 680))
	vb.add_child(_label("PISTAS DO BARÃO", 13, Color("#b8a888")))
	var clues := HBoxContainer.new()
	clues.alignment = BoxContainer.ALIGNMENT_CENTER
	clues.add_theme_constant_override("separation", 6)
	var cids: Array = game.clue_ids()
	for ci in cids.size():
		var i: int = int(cids[ci])
		var b2 := Button.new()
		b2.focus_mode = Control.FOCUS_NONE
		b2.custom_minimum_size = Vector2(98, 76)
		var inner2 := VBoxContainer.new()
		inner2.mouse_filter = Control.MOUSE_FILTER_IGNORE
		inner2.set_anchors_preset(Control.PRESET_FULL_RECT)
		inner2.alignment = BoxContainer.ALIGNMENT_CENTER
		if game.CLUEGOT.has(i):
			var ic3 := _atlas_icon("cl_%d" % i, 36)
			ic3.mouse_filter = Control.MOUSE_FILTER_IGNORE
			inner2.add_child(ic3)
			var cl := _label(GameData.CLUE_INFO[i][0], 11, INK, null, 92)
			cl.mouse_filter = Control.MOUSE_FILTER_IGNORE
			inner2.add_child(cl)
			var ii := i
			b2.pressed.connect(func():
				state = S.PLAY
				_on_clue(ii, true))
		else:
			var q := _label("?", 28, Color(.6, .55, .45))
			q.mouse_filter = Control.MOUSE_FILTER_IGNORE
			inner2.add_child(q)
			var ql := _label("Pista %d" % (ci + 1), 11, Color(.6, .55, .45))
			ql.mouse_filter = Control.MOUSE_FILTER_IGNORE
			inner2.add_child(ql)
			b2.disabled = true
		b2.add_child(inner2)
		clues.add_child(b2)
	vb.add_child(clues)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 10)
	var mb := _button("MAPA", func(): show_map(false, true))
	mb.custom_minimum_size = Vector2(150, 46)
	row.add_child(mb)
	var fb := _button("FECHAR", close_panel)
	fb.custom_minimum_size = Vector2(150, 46)
	row.add_child(fb)
	vb.add_child(row)
	if not pairs.is_empty():
		# no controle/teclado, o botão de confirmar já junta o primeiro par
		var r0: Array = pairs[0]
		panel.set_meta("ok", func():
			var m3 := game.try_combine(r0[0], r0[1])
			if m3 != "":
				_bag_combined(r0[2], m3))
	else:
		panel.set_meta("ok", close_panel)
	panel.set_meta("back", close_panel)

func _bag_tap(id: String) -> void:
	if bag_sel != "" and bag_sel != id:
		var a0: String = bag_sel
		var r := game.try_combine(bag_sel, id)
		bag_sel = ""
		if r != "":
			var res := ""
			for rc in GameData.RECIPES:
				if (rc[0] == a0 and rc[1] == id) or (rc[0] == id and rc[1] == a0):
					res = rc[2]
			_bag_combined(res, r)
			return
		_render_bag("Esses dois não combinam.")
	else:
		bag_sel = "" if bag_sel == id else id
		_render_bag(game.item_msg(bag_sel) if bag_sel != "" else "")

# ---------- pista ----------
func _on_clue(id: int, from_bag: bool = false) -> void:
	if id == 6 and not from_bag and game.level_idx == 0:
		state = S.CUT
		_clear_keys()
		play_cut("cracha", func(): _show_clue(6, false))
		return
	_show_clue(id, from_bag)

func _show_clue(id: int, from_bag: bool) -> void:
	state = S.CLUE
	_clear_keys()
	_show_hud(false)
	var vb := _overlay(.84)
	vb.add_child(_label("PISTA %d DE %d" % [game.CLUEGOT.size(), game.clue_ids().size()] if not from_bag else "PISTAS DO BARÃO", 14, Color("#cdbfa6")))
	if id == 6 and game.level_idx == 0:
		vb.add_child(_Badge.new())
	else:
		vb.add_child(_atlas_icon("clb_%d" % id, 170))
	vb.add_child(_label(GameData.CLUE_INFO[id][0], 30, GOLD, Spr.font_title))
	vb.add_child(_label(GameData.CLUE_INFO[id][1], 17, Color("#e8dcc0"), Spr.font_i, 640))
	var ok := func():
		close_panel()
		if from_bag:
			open_bag()
	vb.add_child(_button("CONTINUAR", ok))
	panel.set_meta("ok", ok)
	panel.set_meta("back", ok)

class _Speaker extends Control:
	## alto-falante com ondas (som ligado) ou com um X (som desligado)
	func _draw() -> void:
		var c := Vector2(size.x / 2 - 4, size.y / 2)
		var col := Color("#e8d39a")
		draw_rect(Rect2(c.x - 13, c.y - 6, 8, 12), col)
		draw_colored_polygon(PackedVector2Array([Vector2(c.x - 6, c.y - 6), Vector2(c.x + 4, c.y - 14), Vector2(c.x + 4, c.y + 14), Vector2(c.x - 6, c.y + 6)]), col)
		if Audio.on:
			draw_arc(Vector2(c.x + 4, c.y), 8, -.9, .9, 10, col, 2.5, true)
			draw_arc(Vector2(c.x + 4, c.y), 14, -.9, .9, 12, col, 2.5, true)
		else:
			draw_line(Vector2(c.x + 9, c.y - 7), Vector2(c.x + 19, c.y + 7), Color("#ff8a6a"), 3, true)
			draw_line(Vector2(c.x + 19, c.y - 7), Vector2(c.x + 9, c.y + 7), Color("#ff8a6a"), 3, true)

class _CrownIcon extends Control:
	## coroa de um rei desenhada em código (a mesma do jogo); ainda não pega: silhueta escura com "?"
	var id := "javali"
	var got := false
	var h := 60.0
	var t := 0.0
	func _init(cid: String, have: bool, hh: float) -> void:
		id = cid
		got = have
		h = hh
		custom_minimum_size = Vector2(hh * 1.5, hh * 1.25)
		size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		mouse_filter = Control.MOUSE_FILTER_IGNORE
	func _process(d: float) -> void:
		if got:
			t += d
			queue_redraw()
	func _draw() -> void:
		Spr.begin(self)
		var c := Vector2(size.x / 2, size.y * .86)
		var s: float = h / 34.0
		if got:
			Spr.glow(c.x, c.y - h * .45, h * .8, Color(1, .85, .4, .3 + .1 * sin(t * 2.0)))
			WorldKings.crown_art(id, c.x, c.y + sin(t * 1.6) * 1.5, s, sin(t * 1.1) * .05, int(t * 60.0))
		else:
			# ainda não pega: só o fantasminha da coroa
			Spr.save()
			Spr.alpha = .2
			WorldKings.crown_art(id, c.x, c.y, s, 0.0, 0)
			Spr.restore()
			Spr.text("?", c.x, c.y - h * .3, int(h * .45), Color(1, .93, .75, .9), HORIZONTAL_ALIGNMENT_CENTER, Spr.font_b, 4)

class _Badge extends Control:
	## O crachá do gerente, com o rosto e o nome
	func _init() -> void:
		custom_minimum_size = Vector2(130, 200)
		size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	func _draw() -> void:
		Spr.begin(self)
		var r = Spr.AR.clb_6
		var h := 200.0
		var w: float = h * r[2] / r[3]
		var x := (size.x - w) / 2
		Spr.AB("clb_6", x, 0, w, h)
		var f = Spr.AR.vg_face
		var fw := w * .6
		var fh: float = fw * f[3] / f[2]
		Spr.ci.draw_texture_rect_region(Spr.atlas_tex(f), Rect2(x + w / 2 - fw / 2, h * .31, fw, min(fh, h * .42)), Rect2(f[0], f[1], f[2], min(f[3], f[3] * (h * .42) / fh)))
		Spr.rect(x + w * .17, h * .73, w * .66, h * .12, Color("#1f2a3a"))
		Spr.text("ADEMAR VARGAS", x + w / 2, h * .785, 9, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, Spr.font_b)
		Spr.text("GERENTE · MINA", x + w / 2, h * .83, 7, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER)

# ---------- cenas da história ----------
func play_cut(id: String, after: Callable) -> void:
	if panel:
		panel.queue_free()
		panel = null
	state = S.CUT
	_show_hud(false)
	_clear_keys()
	if id == "abertura":
		Audio.set_song("aero_tema")
	elif id == "mina":
		Audio.set_song("vitoria")
	elif id == "posfinal":
		Audio.set_song("tunel")
	elif id in ["ep2", "ep2fim"]:
		Audio.set_song("tunel")
	elif id in ["isis", "isis_fim"]:
		Audio.set_song("noite")
	var c := preload("res://scripts/ui/cutscene.gd").new(id)
	c.theme = theme_ui
	ui_layer.add_child(c)
	c.finished.connect(after)

func _on_level_end() -> void:
	if game.player.get("isis"):
		# fim da fuga da Isis (último trecho do Episódio 2): o Vargas a pegou — gancho para o Episódio 3
		play_cut("isis_fim", _on_results)
		return
	_on_results()

## Episódio 2: o Tomé chegou à porta de ferro. Cena da porta, cena da Isis do outro lado,
## e o último trecho do episódio é jogado com ela
func _on_isis_start() -> void:
	play_cut("ep2fim", func(): play_cut("isis", func():
		game.begin_isis()
		state = S.PLAY
		_show_hud(true)
		game.flash_tut("A Isis!", "Agora você joga com a Isis. Ela é pequena: cabe nos buracos, mas pula mais baixo. Fuja sem o Vargas ver: ↓ atrás de caixotes para se esconder.", 300)))

# ---------- mapa da fase ----------
## from_pause: volta ao menu de pausa; from_bag: volta à mochila; senão volta ao jogo
func show_map(from_pause: bool, from_bag: bool = false) -> void:
	var vb := _overlay(.9)
	vb.add_child(_label("MAPA DA FASE", 30, GOLD, Spr.font_title))
	var m := preload("res://scripts/ui/level_map.gd").new()
	m.game = game
	var vs := get_viewport().get_visible_rect().size
	m.custom_minimum_size = Vector2(min(vs.x - 60, 1100), 250)
	vb.add_child(m)
	vb.add_child(_label("Os totens de check-in são onde você volta. \"?\" = algo que ficou para trás num trecho já visitado.", 13, Color(.8, .75, .65), Spr.font_i, 700))
	var back := func():
		if from_pause:
			_pause_menu()
		elif from_bag:
			state = S.BAG
			_render_bag("")
		else:
			close_panel()
	vb.add_child(_button("VOLTAR", back))
	panel.set_meta("ok", back)
	panel.set_meta("back", back)
	panel.set_meta("map", true)

# ---------- galeria ----------
## nomes dos períodos de cada episódio (sem depender da fase carregada agora)
var _ep_per_cache := {}
func _ep_periods(ep: int) -> Array:
	if not _ep_per_cache.has(ep):
		var p := "res://assets/data/level%d.json" % ep
		var per: Array = Game.PERIODS1
		if FileAccess.file_exists(p):
			var L = JSON.parse_string(FileAccess.get_file_as_string(p))
			if L is Dictionary:
				per = L.get("periods", Game.PERIODS1)
		_ep_per_cache[ep] = per
	return _ep_per_cache[ep]

## nome curto do período ("A fuga da Isis" -> "A fuga", "Manhã no bosque" -> "Manhã")
func _short_period(s: String) -> String:
	var w: PackedStringArray = s.split(" ")
	if w.size() > 1 and w[0].length() <= 2:
		return w[0] + " " + w[1]
	return w[0]

## desenhos guardados por episódio (antes eram "d0".."d2" para todos: o Ep. 2 abria os do Ep. 1)
func _migrate_gallery() -> void:
	if Save.getv("gallery", "split_v1", false):
		return
	for i in 3:
		if Save.getv("gallery", "d%d" % i, false):
			Save.cfg.set_value("gallery", "e1_d%d" % i, true)
	if Save.getv("gallery", "d3", false):
		Save.cfg.set_value("gallery", "e2_d3", true)
	# a partida salva sabe exatamente de que episódio é cada desenho
	for k in Save.load_run().get("drawn", []):
		var pr: PackedStringArray = str(k).split(":")
		if pr.size() == 2:
			Save.cfg.set_value("gallery", "e%d_d%d" % [int(pr[0]) + 1, int(pr[1])], true)
	Save.setv("gallery", "split_v1", true)

func show_gallery(ep: int = 1) -> void:
	var eps: int = clampi(int(Save.getv("prog", "eps", 1)), 1, EPISODES.size())
	ep = clampi(ep, 1, eps)
	var vb := _overlay(.92)
	vb.add_theme_constant_override("separation", 8)
	vb.add_child(_label("GALERIA DO MILIS", 28, GOLD, Spr.font_title))
	# um episódio por vez (abas)
	if eps >= 2:
		var tabs := HBoxContainer.new()
		tabs.alignment = BoxContainer.ALIGNMENT_CENTER
		tabs.add_theme_constant_override("separation", 8)
		for e in eps:
			var en: int = e + 1
			var tb := _compact_btn(["1-1", "1-2", "1-3", "CHEFE"][e] if e < 4 else "FASE %d" % en)
			tb.toggle_mode = true
			tb.button_pressed = en == ep
			tb.pressed.connect(func(): show_gallery(en))
			tabs.add_child(tb)
		vb.add_child(tabs)
	# conquistas: o melhor de cada período deste episódio
	var per: Array = _ep_periods(ep)
	var sk: String = "stars" if ep == 1 else "stars%d" % ep
	var cs: Array = Save.getv("conq", sk, [])
	var crow := HBoxContainer.new()
	crow.alignment = BoxContainer.ALIGNMENT_CENTER
	crow.add_theme_constant_override("separation", 14)
	for i in per.size():
		var n: int = int(cs[i]) if i < cs.size() else 0
		var col := VBoxContainer.new()
		col.add_theme_constant_override("separation", 0)
		col.add_child(_label(_short_period(str(per[i])), 12, Color("#cdbfa6")))
		col.add_child(_label(("★".repeat(n) + "☆".repeat(3 - n)) if n > 0 else "— — —", 16, Color("#ffd76a")))
		crow.add_child(col)
	vb.add_child(crow)
	var bt2: int = int(Save.getv("conq", "time" if ep == 1 else "time%d" % ep, 0))
	vb.add_child(_label("Melhor tempo %s" % [("%d:%02d" % [bt2 / 60, bt2 % 60]) if bt2 > 0 else "—"], 13, Color(.85, .8, .7), Spr.font_i))
	# cartões de embarque dourados desta fase (o texto aparece depois de achar)
	vb.add_child(_label("CARTÕES DE EMBARQUE DOURADOS", 13, Color("#b8a888")))
	var L2 = JSON.parse_string(FileAccess.get_file_as_string("res://assets/data/level%d.json" % ep))
	var nd: int = L2.get("drawings", []).size() if L2 else 0
	for i in nd:
		var tx = Save.getv("gallery", "cartao_%d_%d" % [ep - 1, i], null)
		var rowc := HBoxContainer.new()
		rowc.add_theme_constant_override("separation", 8)
		rowc.add_child(_atlas_icon("drawing", 34))
		rowc.add_child(_label(str(tx) if tx != null else "??? (ainda escondido nesta fase)", 13, Color("#ffe9b0") if tx != null else Color(.6, .55, .45), Spr.font_i, 420))
		vb.add_child(rowc)
	if Save.getv("conq", "gold", false):
		var gl := HBoxContainer.new()
		gl.alignment = BoxContainer.ALIGNMENT_CENTER
		gl.add_child(_atlas_icon("pen_gold", 30))
		gl.add_child(_label("  Milha dourada encontrada!", 14, Color("#ffd76a"), Spr.font_i))
		vb.add_child(gl)
	var cl := HBoxContainer.new()
	cl.alignment = BoxContainer.ALIGNMENT_CENTER
	cl.add_theme_constant_override("separation", 10)
	cl.add_child(_label("PISTAS DO BARÃO", 13, Color("#b8a888")))
	var c0: int = 1
	for i in range(c0, c0 + 6):
		if Save.getv("gallery", "c%d" % i, false):
			var ic := _atlas_icon("clb_%d" % i, 50)
			ic.tooltip_text = GameData.CLUE_INFO[i][0]
			cl.add_child(ic)
		else:
			var q := _label("?", 28, Color(.5, .45, .38))
			q.custom_minimum_size = Vector2(50, 50)
			cl.add_child(q)
	vb.add_child(cl)
	var best := Save.best(ep - 1)
	if not best.is_empty():
		vb.add_child(_label("Melhor resultado %s: %s   ·   milhas %d   ·   pistas %d" % ["na fase %d" % ep, "★".repeat(int(best.get("stars", 0))), int(best.get("pen", 0)), int(best.get("clues", 0))], 14, Color("#ffd76a")))
	var b := HBoxContainer.new()
	b.alignment = BoxContainer.ALIGNMENT_CENTER
	b.add_theme_constant_override("separation", 10)
	var back := func():
		panel.queue_free()
		panel = null
		show_title()
	var vb2 := _button("VOLTAR", back)
	vb2.custom_minimum_size = Vector2(150, 44)
	b.add_child(vb2)
	vb.add_child(b)
	panel.set_meta("ok", back)
	panel.set_meta("back", back)

# ---------- placar ----------
func _on_results() -> void:
	state = S.RESULTS
	_show_hud(false)
	Audio.play("door")
	var nc := game.CLUEGOT.size()
	var ns := game.SPECGOT.size()
	var pen: int = game.STATS.pen
	var pt: int = game.STATS.penTotal
	# tempo jogado de verdade (contado em passos de jogo; o relógio da fase recomeça a cada fogueira grande)
	var secs := int(round(Save.run_secs))
	var dr := 0
	for d in game.DRWS:
		if d.got:
			dr += 1
	var ntot: int = game.clue_ids().size()
	var stars := 1
	if pen >= pt * .7 and (nc >= ntot - 1 or dr >= 2):
		stars = 2
	if pen >= pt * .9 and nc >= ntot and dr == game.DRWS.size():
		stars = 3
	Save.set_best(game.level_idx, {"stars": stars, "pen": pen, "clues": nc, "specs": ns})
	var gk: String = "final" if game.level_idx == 0 else "final%d" % (game.level_idx + 1)
	var prev: Array = Save.getv("gallery", gk, [])
	if game.SPECGOT.size() >= prev.size():
		Save.setv("gallery", gk, game.SPECGOT.keys())
	Save.clear_run()
	var vb := _overlay(.86)
	vb.add_theme_constant_override("separation", 6)
	# compacto (cabe em 540 px): título e estrelas em cima; desenho, números e estrelas por período lado a lado
	var head := HBoxContainer.new()
	head.alignment = BoxContainer.ALIGNMENT_CENTER
	head.add_theme_constant_override("separation", 18)
	head.add_child(_label(game.L.get("endTitle", "FIM DA FASE"), 16, Color("#cdbfa6"), Spr.font_title))
	head.add_child(_label("★".repeat(stars) + "☆".repeat(3 - stars), 34, Color("#ffd76a")))
	vb.add_child(head)
	var mid := HBoxContainer.new()
	mid.alignment = BoxContainer.ALIGNMENT_CENTER
	mid.add_theme_constant_override("separation", 26)
	vb.add_child(mid)
	var right := VBoxContainer.new()
	right.add_theme_constant_override("separation", 8)
	right.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	mid.add_child(right)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 24)
	grid.add_theme_constant_override("v_separation", 2)
	var gold_txt := "Milha dourada  " + ("✓" if game.X.GOLD.get("got", false) else "—")
	var sec_txt := "Lugares secretos  %d/%d" % [game.X.found.size(), game.X.SECRETS.size()]
	var rows := ["⏱ Tempo  %d:%02d" % [secs / 60, secs % 60], "✈ Milhas  %d/%d" % [pen, pt], "Cartões dourados  %d/%d" % [dr, game.DRWS.size()], "Pistas  %d/%d" % [nc, ntot]]
	if game.SPECS.size() > 0:
		rows.append("Milhas especiais  %d/%d" % [ns, game.SPECS.size()])
	if game.L.has("gold"):
		rows.append(gold_txt)
	if game.X.SECRETS.size() > 0:
		rows.append(sec_txt)
	for t in rows:
		var l := _label(t, 15, INK)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		grid.add_child(l)
	right.add_child(grid)
	# estrelas por período (guarda o melhor de cada um para a galeria de conquistas)
	var ps: Array = game.period_stars()
	var prow := HBoxContainer.new()
	prow.add_theme_constant_override("separation", 12)
	var sk: String = "stars" if game.level_idx == 0 else "stars%d" % (game.level_idx + 1)
	var best: Array = Save.getv("conq", sk, [0, 0, 0, 0, 0, 0])
	while best.size() < ps.size():
		best.append(0)
	for i in ps.size():
		best[i] = max(int(best[i]), int(ps[i]))
		var col := VBoxContainer.new()
		col.add_theme_constant_override("separation", 0)
		col.add_child(_label(_short_period(str(game.PERIODS[min(i, game.PERIODS.size() - 1)])), 11, Color("#cdbfa6")))
		col.add_child(_label("★".repeat(ps[i]) + "☆".repeat(3 - ps[i]), 15, Color("#ffd76a")))
		prow.add_child(col)
	right.add_child(prow)
	Save.setv("conq", sk, best)
	var kings := 0
	if game.X.BOSS.get("done", false):
		kings += 1
	for kk in [game.K.HAWK, game.K.BEAR, game.K.FISH]:
		if not kk.is_empty() and kk.get("done", false):
			kings += 1
	# reis vencidos contam por episódio (o Ep. 2 tem 3; antes somava tudo em "x/4")
	var kkey: String = "kings" if game.level_idx == 0 else "kings%d" % (game.level_idx + 1)
	Save.setv("conq", kkey, max(int(Save.getv("conq", kkey, 0)), kings))
	Save.setv("conq", "secrets", max(int(Save.getv("conq", "secrets", 0)), game.X.found.size()))
	Save.setv("conq", "specs", max(int(Save.getv("conq", "specs", 0)), ns))
	Save.setv("conq", "gold", Save.getv("conq", "gold", false) or game.X.GOLD.get("got", false))
	var tk: String = "time" if game.level_idx == 0 else "time%d" % (game.level_idx + 1)
	var bt: int = int(Save.getv("conq", tk, 0))
	if secs > 0 and (bt == 0 or secs < bt):
		Save.setv("conq", tk, secs)
	if game.X.found.size() >= game.X.SECRETS.size() and game.X.SECRETS.size() > 0:
		# todos os segredos: cena bônus (o desenho da pipa), guardada por episódio
		Save.setv("gallery", "bonus" if game.level_idx == 0 else "bonus%d" % (game.level_idx + 1), true)
		var bcol := VBoxContainer.new()
		bcol.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		bcol.add_child(_label("Todos os segredos!\nCena bônus:", 13, Color("#ffd76a"), Spr.font_b))
		var bd = preload("res://scripts/ui/kid_drawing.gd").new()
		bd.kind = 4
		bd.custom_minimum_size = Vector2(200, 125)
		bcol.add_child(bd)
		mid.add_child(bcol)
	var lvl: int = game.level_idx
	var story: String = game.L.get("endStory", "")
	if story != "":
		vb.add_child(_label(story, 15, Color("#e8dcc0"), Spr.font_i, 700))
	var cont: Callable
	if lvl + 1 < EPISODES.size():
		# a próxima fase fica liberada e começa logo depois
		Save.setv("prog", "eps", max(lvl + 2, int(Save.getv("prog", "eps", 1))))
		cont = func(): start_level(false, lvl + 1)
		vb.add_child(_button("PRÓXIMA FASE", cont))
	else:
		var brow := HBoxContainer.new()
		brow.alignment = BoxContainer.ALIGNMENT_CENTER
		brow.add_theme_constant_override("separation", 16)
		brow.add_child(_label("Próximo aeroporto: Maringá — em breve.", 13, Color(.75, .7, .6), Spr.font_i))
		cont = show_title
		brow.add_child(_button("CONTINUAR", cont))
		vb.add_child(brow)
	panel.set_meta("ok", cont)

class _FinalDrawing extends Control:
	## O desenho da Isis, colorido com os lápis especiais encontrados
	var specs := {}
	func _init() -> void:
		custom_minimum_size = Vector2(300, 170)
		size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	func colr(c: String) -> Color:
		return GameData.PEN_COL[c] if specs.has(c) else Color("#f6efdc")
	var ep := 1
	func _draw() -> void:
		if ep == 2:
			_draw_mill()
			return
		var w := 300.0
		var h := 170.0
		var ink := Color("#3a2a1a")
		draw_rect(Rect2(-3, -3, w + 6, h + 6), Color("#6b4a2a"))
		draw_rect(Rect2(0, 0, w, h * .6), colr("azul"))
		draw_rect(Rect2(0, h * .6, w, h * .4), colr("verde"))
		draw_line(Vector2(0, h * .6), Vector2(w, h * .6), ink, 3)
		draw_circle(Vector2(w * .82, h * .2), 22, colr("amarelo"))
		draw_arc(Vector2(w * .82, h * .2), 22, 0, TAU, 32, ink, 3)
		draw_rect(Rect2(w * .1, h * .38, 70, 52), colr("laranja"))
		draw_rect(Rect2(w * .1, h * .38, 70, 52), ink, false, 3)
		var roof := PackedVector2Array([Vector2(w * .1 - 8, h * .38), Vector2(w * .1 + 35, h * .24), Vector2(w * .1 + 78, h * .38)])
		draw_colored_polygon(roof, colr("vermelho"))
		draw_polyline(PackedVector2Array([roof[0], roof[1], roof[2], roof[0]]), ink, 3)
		for f in [[w * .55, 1.3, "roxo"], [w * .66, .95, "vermelho"]]:
			var x: float = f[0]
			var s: float = f[1]
			draw_circle(Vector2(x, h * .55 - 30 * s), 10 * s, colr(f[2]))
			draw_arc(Vector2(x, h * .55 - 30 * s), 10 * s, 0, TAU, 24, ink, 3)
			var b := PackedVector2Array([Vector2(x, h * .55 - 20 * s), Vector2(x - 14 * s, h * .55 + 18 * s), Vector2(x + 14 * s, h * .55 + 18 * s)])
			draw_colored_polygon(b, colr(f[2]))
			draw_polyline(PackedVector2Array([b[0], b[1], b[2], b[0]]), ink, 3)
		draw_line(Vector2(w * .55 + 8, h * .55 - 10), Vector2(w * .66 - 8, h * .55 - 6), ink, 3)
		var txt := "\"Papai e eu\" — Isis" if specs.size() == 6 else "Faltam cores: %d" % (6 - specs.size())
		draw_string(Spr.font_i, Vector2(10, h - 8), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, ink)

	## desenho do Episódio 2: o moinho, a montanha da mina e os dois de mãos dadas
	func _draw_mill() -> void:
		var w := 300.0
		var h := 170.0
		var ink := Color("#3a2a1a")
		draw_rect(Rect2(-3, -3, w + 6, h + 6), Color("#6b4a2a"))
		draw_rect(Rect2(0, 0, w, h * .62), colr("azul"))
		draw_rect(Rect2(0, h * .62, w, h * .38), colr("amarelo"))
		draw_line(Vector2(0, h * .62), Vector2(w, h * .62), ink, 3)
		var mt := PackedVector2Array([Vector2(w * .5, h * .62), Vector2(w * .72, h * .14), Vector2(w * .98, h * .62)])
		draw_colored_polygon(mt, colr("roxo"))
		draw_polyline(PackedVector2Array([mt[0], mt[1], mt[2]]), ink, 3)
		draw_rect(Rect2(w * .7, h * .46, 22, 22), Color("#2a2018"))
		draw_rect(Rect2(w * .7, h * .46, 22, 22), ink, false, 3)
		var mx := w * .2
		var tw := PackedVector2Array([Vector2(mx - 16, h * .62), Vector2(mx - 10, h * .3), Vector2(mx + 10, h * .3), Vector2(mx + 16, h * .62)])
		draw_colored_polygon(tw, colr("laranja"))
		draw_polyline(PackedVector2Array([tw[0], tw[1], tw[2], tw[3]]), ink, 3)
		for k in 4:
			var a: float = .5 + k * PI / 2
			draw_line(Vector2(mx, h * .3), Vector2(mx + cos(a) * 34, h * .3 + sin(a) * 34), ink, 4)
		draw_circle(Vector2(mx, h * .3), 5, colr("vermelho"))
		for f in [[w * .42, 1.3, "verde"], [w * .52, .95, "vermelho"]]:
			var x: float = f[0]
			var sc: float = f[1]
			draw_circle(Vector2(x, h * .6 - 30 * sc), 10 * sc, colr(f[2]))
			draw_arc(Vector2(x, h * .6 - 30 * sc), 10 * sc, 0, TAU, 24, ink, 3)
			var b := PackedVector2Array([Vector2(x, h * .6 - 20 * sc), Vector2(x - 14 * sc, h * .6 + 18 * sc), Vector2(x + 14 * sc, h * .6 + 18 * sc)])
			draw_colored_polygon(b, colr(f[2]))
			draw_polyline(PackedVector2Array([b[0], b[1], b[2], b[0]]), ink, 3)
		draw_line(Vector2(w * .42 + 8, h * .6 - 10), Vector2(w * .52 - 8, h * .6 - 6), ink, 3)
		var txt := "\"O moinho do domingo\" — Isis" if specs.size() == 6 else "Faltam cores: %d" % (6 - specs.size())
		draw_string(Spr.font_i, Vector2(10, h - 8), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, ink)

# ---------- fim de jogo ----------
func _on_over() -> void:
	state = S.OVER
	_show_hud(false)
	Audio.stop_music()
	var vb := _overlay(.88)
	vb.add_child(_label("O MILIS DESLIGOU", 34, GOLD, Spr.font_title))
	vb.add_child(_label("As vidas acabaram. Mas um pai não desiste.", 17, Color("#e8dcc0"), Spr.font_i))
	var run := Save.load_run()
	if not run.is_empty():
		vb.add_child(_button("VOLTAR AO TOTEM", func():
			start_level(true)
			game.lives = max(game.lives, 3)))
	vb.add_child(_button("RECOMEÇAR A FASE", func(): _confirm_wipe(func(): start_level(false, game.level_idx), _on_over)))
	var to_menu := func():
		if panel:
			panel.queue_free()
			panel = null
		show_title()
	vb.add_child(_button("MENU INICIAL", to_menu))
	# Voltar do celular / Esc / B: vai para o menu (antes não fazia nada nesta tela)
	panel.set_meta("back", to_menu)


## Prepara as letras das fontes logo na abertura (fora da tela): sem isso cada letra nova desenhada pela
## primeira vez (aviso, fala, placar) era gerada na hora e dava uma travadinha.
## tela à parte do mundo (fundo transparente), do tamanho da tela de verdade e com a mesma câmera
var world_vp: SubViewport
var world_root: Node2D
var world_show: Node2D
var outline_rect: ColorRect
func _make_world_vp() -> void:
	if world_vp != null:
		return
	world_vp = SubViewport.new()
	world_vp.disable_3d = true
	world_vp.transparent_bg = true
	world_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	world_vp.canvas_item_default_texture_filter = get_viewport().canvas_item_default_texture_filter
	world_vp.size_2d_override_stretch = true
	add_child(world_vp)
	world_root = Node2D.new()
	world_root.name = "Mundo"
	world_vp.add_child(world_root)
	# o contorno preto vai numa camada por cima de tudo (depois da luz, da escuridão e dos tons)
	outline_rect = ColorRect.new()
	outline_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	outline_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var olm := ShaderMaterial.new()
	olm.shader = preload("res://scripts/outline.gdshader")
	olm.set_shader_parameter("world_tex", world_vp.get_texture())
	outline_rect.material = olm
	screen_layer.add_child(outline_rect)
	screen_layer.move_child(outline_rect, vivid.get_index() + 1)
	RenderingServer.frame_pre_draw.connect(_sync_world_vp)
	_sync_world_vp()

## antes de cada quadro ser pintado: mesmo tamanho, mesma escala e mesma câmera da tela principal
func _sync_world_vp() -> void:
	if world_vp == null:
		return
	var root := get_tree().root
	var vis: Vector2 = root.get_visible_rect().size
	var real: Vector2i = root.size if root.content_scale_mode == Window.CONTENT_SCALE_MODE_CANVAS_ITEMS else Vector2i(vis)
	real = Vector2i(max(real.x, 16), max(real.y, 16))
	if world_vp.size != real:
		world_vp.size = real
	if world_vp.size_2d_override != Vector2i(vis):
		world_vp.size_2d_override = Vector2i(vis)
	var ct: Transform2D = root.canvas_transform
	world_vp.canvas_transform = ct
	if is_instance_valid(world_show):
		world_show.transform = ct.affine_inverse()
		world_show.size = vis
	if outline_rect:
		var olm: ShaderMaterial = outline_rect.material
		# traço de ~2,5 px na tela de base (540 linhas), proporcional nas telas maiores
		olm.set_shader_parameter("px", clamp(2.5 * float(real.y) / max(vis.y, 1.0), 1.8, 7.0))
		olm.set_shader_parameter("texel", Vector2(1.0 / float(real.x), 1.0 / float(real.y)))

class _CheerNode extends Node2D:
	var game: Game
	func _process(_d: float) -> void:
		queue_redraw()
	func _draw() -> void:
		if game and game.L and game.VH:
			Spr.begin(self)
			WorldVehicles._cheer(game, game.VH, game.T)

class _WorldShow extends Node2D:
	var vp: SubViewport
	var size := Vector2(960, 540)
	func _process(_d: float) -> void:
		queue_redraw()
	func _draw() -> void:
		if vp:
			draw_texture_rect(vp.get_texture(), Rect2(Vector2.ZERO, size), false)

class _FontWarm extends Node2D:
	func _draw() -> void:
		var s := ""
		for c in range(32, 127):
			s += char(c)
		s += "áàâãäéèêëíìîïóòôõöúùûüçñÁÀÂÃÉÊÍÓÔÕÚÇ▸◂▾▴✔✓…—–“”‘’•×←→↑↓°ºª¡¿·"
		for f in [Spr.font, Spr.font_i, Spr.font_b, Spr.font_title]:
			if f:
				draw_string(f, Vector2(-9000, -9000), s, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color(1, 1, 1, .01))
				draw_string_outline(f, Vector2(-9000, -9000), s, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, 4, Color(0, 0, 0, .01))
		queue_free.call_deferred()


## Compila de uma vez (durante a abertura da fase) todos os shaders e combinações de desenho que a fase usa:
## no celular (GL) cada combinação nova era compilada na primeira vez que aparecia na tela — o primeiro inimigo,
## a primeira água, o primeiro texto — e o jogo engasgava ali.
func _warm_shaders() -> void:
	var mats: Array = [null]
	var stack: Array = [self]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		if n is CanvasItem and (n as CanvasItem).material != null and not mats.has((n as CanvasItem).material):
			mats.append((n as CanvasItem).material)
		for c in n.get_children():
			stack.append(c)
	var add := CanvasItemMaterial.new()
	add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	mats.append(add)
	var mul := CanvasItemMaterial.new()
	mul.blend_mode = CanvasItemMaterial.BLEND_MODE_MUL
	mats.append(mul)
	var cl := CanvasLayer.new()
	cl.layer = 120
	add_child(cl)
	var i := 0
	for m in mats:
		var w := _ShaderWarm.new()
		w.material = m
		w.position = Vector2(2 + i * 3, 2)
		cl.add_child(w)
		i += 1
	get_tree().create_timer(.25).timeout.connect(cl.queue_free)

class _ShaderWarm extends Node2D:
	func _draw() -> void:
		var c := Color(1, 1, 1, .004)
		var texs: Array = []
		for k in ["atlas1", "paint1", "pai", "javali"]:
			if Spr.tex.get(k) is Texture2D:
				texs.append(Spr.tex[k])
		if Spr.glow_tex:
			texs.append(Spr.glow_tex)
		for t in texs:
			draw_texture_rect(t, Rect2(0, 0, 2, 2), false, c)
			draw_texture_rect_region(t, Rect2(0, 0, 2, 2), Rect2(0, 0, 8, 8), c)
			draw_polygon(PackedVector2Array([Vector2(0, 0), Vector2(2, 0), Vector2(2, 2)]), PackedColorArray([c, c, c]),
				PackedVector2Array([Vector2(0, 0), Vector2(1, 0), Vector2(1, 1)]), t)
		draw_colored_polygon(PackedVector2Array([Vector2(0, 0), Vector2(2, 0), Vector2(0, 2)]), c)
		draw_rect(Rect2(0, 0, 2, 2), c)
		draw_rect(Rect2(0, 0, 2, 2), c, false, 1.0)
		draw_circle(Vector2(1, 1), 1.0, c)
		draw_line(Vector2.ZERO, Vector2(2, 2), c, 1.0, true)
		draw_line(Vector2.ZERO, Vector2(2, 2), c, 2.0, false)
		draw_polyline(PackedVector2Array([Vector2(0, 0), Vector2(1, 2), Vector2(2, 0)]), c, 1.5, true)
		draw_multiline(PackedVector2Array([Vector2(0, 0), Vector2(1, 2)]), c, 1.0)
		for f in [Spr.font, Spr.font_i, Spr.font_b, Spr.font_title]:
			if f:
				draw_string(f, Vector2(0, 2), "Aa", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, c)
				draw_string_outline(f, Vector2(0, 2), "Aa", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, 3, c)
