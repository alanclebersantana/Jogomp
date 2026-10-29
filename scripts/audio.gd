extends Node
## Efeitos, música por trecho, som ambiente e chuva.
## Músicas e ambientes (OGG) são gravados com instrumentos reais por tools/make_music.py;
## os efeitos curtos (WAV) vêm de tools/make_audio.py e tools/make_music.py.

var on := true
var sfx := {}
var players: Array[AudioStreamPlayer] = []
var music: AudioStreamPlayer
var music2: AudioStreamPlayer
var rain: AudioStreamPlayer
var danger: AudioStreamPlayer
var danger_lv := 0.0
var song := ""
var amb: AudioStreamPlayer
var amb2: AudioStreamPlayer
var amb_name := ""
## volume de cada música (dB) para todas soarem parecidas (medido com a sonoridade de cada faixa)
const SONG_DB := {"perseguicao": -3.0, "vitoria": -6.0, "tarde": -6.5, "tema": -5.0, "chuva": -3.0, "noite": -4.0, "tunel": -3.5,
	"cavalo": -6.0, "treno": -8.0, "jangada": -5.5, "voo": -8.0, "carrinho": -4.0}
## som ambiente de cada trecho (pelo nome pedido ou pela faixa que toca)
const AMB_FOR := {"manha": "passaros", "tarde": "passaros", "chuva": "sapos", "noite": "grilos", "tunel": "caverna", "perseguicao": "vento",
	"neve": "vento", "cavalo": "vento", "treno": "vento", "voo": "vento", "jangada": "sapos", "carrinho": "caverna"}
## músicas calmas e longas gravadas em três camadas sincronizadas (mus_X, mus_X_2, mus_X_3):
## a 1 é a música calma; a 2 traz o pulso (baixo, violão, percussão leve); a 3 o brilho (contracanto,
## xilofone, pandeiro). Conforme o Tomé avança no trecho, as camadas entram aos poucos.
const LAYERED := ["tema", "tarde", "chuva", "noite", "tunel"]
## músicas em que a música pode dar uma pausa (nunca em chefes, perseguição e trechos especiais)
const REST_SONGS := ["manha", "tarde", "chuva", "noite", "tunel", "tema"]
const BATTLE := ["perseguicao", "gaviao", "bagre", "urso", "pedra"]
var rain_target := 0.0
## barramentos: Música (músicas e tambores), Efeitos (sons curtos e ambiente) e Mundo (chuva e sons
## presos no cenário: fogueiras, água). O Mundo fica mudo fora do jogo (menus, fogueira grande, placar).
var bus_music := 0
var bus_sfx := 0
var bus_world := 0
var vol_music := 1.0
var vol_sfx := 1.0
var world_on := true
var world_gain := 1.0
var _mus_tw: Tween
var _amb_tw: Tween
var bus_amb := 0
const NAMES := ["jump", "dj", "pen", "stomp", "hurt", "item", "clue", "combine", "unlock", "splash", "slide", "fire", "thunder", "door", "spring", "climb", "die", "special", "roar"]   # (o latido do Pipoca ficou mudo: era irritante)

func _bus(n: String, send: String) -> int:
	var i := AudioServer.get_bus_index(n)
	if i < 0:
		AudioServer.add_bus()
		i = AudioServer.bus_count - 1
		AudioServer.set_bus_name(i, n)
	AudioServer.set_bus_send(i, send)
	return i

func _ready() -> void:
	on = Save.getv("opt", "sound", true)
	bus_music = _bus("Musica", "Master")
	bus_sfx = _bus("Efeitos", "Master")
	bus_world = _bus("Mundo", "Efeitos")
	# o ambiente tem barramento próprio: sobe um pouco quando a música faz uma pausa
	bus_amb = _bus("Ambiente", "Efeitos")
	vol_music = float(Save.getv("opt", "vol_music", 1.0))
	vol_sfx = float(Save.getv("opt", "vol_sfx", 1.0))
	for n in NAMES:
		sfx[n] = load("res://assets/audio/%s.wav" % n)
	# músicas e sons de ambiente já carregados (sem travada ao mudar de trecho)
	for b in ["mus_manha", "mus_tarde", "mus_noite", "mus_chuva", "mus_perseguicao", "mus_tunel", "mus_tema", "mus_vitoria",
			"mus_cavalo", "mus_treno", "mus_jangada", "mus_voo", "mus_carrinho",
			"amb_caverna", "amb_grilos", "amb_passaros", "amb_sapos", "amb_vento"]:
		_stream(b)
	# latido do Pipoca: só uma vez, quando ele acha algo escondido
	# o latido do Pipoca foi retirado (ficava repetitivo): "bark" não toca nada
	for k in STEPS:
		for v in ["a", "b"]:
			var sp := "res://assets/audio/step_%s_%s.wav" % [k, v]
			if ResourceLoader.exists(sp):
				sfx["step_%s_%s" % [k, v]] = load(sp)
	for i in 10:
		var p := AudioStreamPlayer.new()
		p.bus = "Efeitos"
		add_child(p)
		players.append(p)
		_pname.append("")
		_pt0.append(0)
	music = AudioStreamPlayer.new()
	music2 = AudioStreamPlayer.new()
	music.bus = "Musica"
	music2.bus = "Musica"
	add_child(music)
	add_child(music2)
	amb = AudioStreamPlayer.new()
	amb2 = AudioStreamPlayer.new()
	amb.bus = "Ambiente"
	amb2.bus = "Ambiente"
	add_child(amb)
	add_child(amb2)
	# camada extra da música (tambores) que cresce quando há perigo por perto
	danger = AudioStreamPlayer.new()
	danger.bus = "Musica"
	if ResourceLoader.exists("res://assets/audio/loop_tambores.wav"):
		danger.stream = _loop(load("res://assets/audio/loop_tambores.wav"))
	danger.volume_db = -60
	add_child(danger)
	rain = AudioStreamPlayer.new()
	rain.stream = _loop(load("res://assets/audio/rain.wav"))
	rain.volume_db = -60
	rain.bus = "Mundo"
	add_child(rain)
	_apply()
	_apply_volumes()

func _loop(s: AudioStreamWAV) -> AudioStreamWAV:
	var c: AudioStreamWAV = s.duplicate()
	c.loop_mode = AudioStreamWAV.LOOP_FORWARD
	c.loop_begin = 0
	c.loop_end = int(c.get_length() * c.mix_rate)
	return c

func _apply() -> void:
	AudioServer.set_bus_mute(0, not on)

func set_on(v: bool) -> void:
	on = v
	Save.setv("opt", "sound", v)
	_apply()

## volume da música e dos efeitos (0..1), guardados nas opções e aplicados na hora
func _apply_volumes() -> void:
	# (rest_gain: a pausa da música, que desce e volta aos poucos)
	var mv: float = vol_music * rest_gain
	AudioServer.set_bus_volume_db(bus_music, linear_to_db(max(mv, .0001)))
	AudioServer.set_bus_mute(bus_music, mv <= .001)
	AudioServer.set_bus_volume_db(bus_sfx, linear_to_db(max(vol_sfx, .0001)))
	AudioServer.set_bus_mute(bus_sfx, vol_sfx <= .001)

func set_music_vol(v: float, store: bool = true) -> void:
	vol_music = clampf(v, 0.0, 1.0)
	_apply_volumes()
	if store:
		Save.setv("opt", "vol_music", vol_music)

func set_sfx_vol(v: float, store: bool = true) -> void:
	vol_sfx = clampf(v, 0.0, 1.0)
	_apply_volumes()
	if store:
		Save.setv("opt", "vol_sfx", vol_sfx)

## sons do mundo (chuva, tambores do perigo, fogueiras, água) só durante o jogo
func set_world(v: bool) -> void:
	world_on = v

## sons que se repetem muito: mais baixos e sempre um pouco diferentes (tom variando)
const TRIM := {"coin": -6.0, "jump": -5.0, "stomp": -3.0, "climb": -5.0, "swing": -4.0, "splash": -3.0, "crate": -3.0, "spring": -3.0, "unlock": -3.0}
## outros sons comuns também variam um pouquinho o tom (o mesmo som idêntico toda vez cansa)
const VARY := {"slide": .05, "door": .04, "hurt": .05, "dj": .03, "item": .03, "roar": .05, "pen": .02, "thunder": .06}
## quantas vozes do mesmo som podem tocar juntas (o resto rouba a mais antiga do mesmo som: nada
## de oito "stomp" empilhados estourando o volume quando várias coisas caem juntas)
const MAXV := {"stomp": 3, "pen": 2, "unlock": 2, "splash": 2, "slide": 2, "door": 2, "roar": 2, "thunder": 1, "die": 1, "clue": 1, "special": 1, "fire": 1}
var _last := {}
var _pname: Array[String] = []
var _pt0: Array[int] = []
var _pen_n := 0
var _pen_ms := -9999
func play(n: String, vol_db: float = 0.0, pitch: float = 1.0) -> void:
	if not sfx.has(n):
		return
	# o mesmo som não empilha no mesmo instante (lápis em sequência, passos)
	var now := Time.get_ticks_msec()
	if now - int(_last.get(n, -1000)) < 45:
		return
	_last[n] = now
	if TRIM.has(n):
		vol_db += TRIM[n]
		if pitch == 1.0:
			pitch = randf_range(.93, 1.07)
	elif VARY.has(n) and pitch == 1.0:
		pitch = 1.0 + randf_range(-1.0, 1.0) * VARY[n]
	# lápis pegos em sequência: cada um um pouquinho mais agudo (a trilha "canta"); recomeça ao parar
	if n == "pen":
		_pen_n = _pen_n + 1 if now - _pen_ms < 700 else 0
		_pen_ms = now
		pitch *= 1.0 + .035 * min(_pen_n, 10)
	var p := _voice(n, now)
	p.stream = sfx[n]
	p.volume_db = vol_db
	p.pitch_scale = pitch
	p.play()

## escolhe o tocador: respeita o limite de vozes do som; senão um livre; senão o mais antigo
func _voice(n: String, now: int) -> AudioStreamPlayer:
	var cap: int = MAXV.get(n, 3) if not n.begins_with("step_") else 2
	var same := 0
	var old_same := -1
	var free := -1
	var oldest := -1
	for i in players.size():
		if players[i].playing:
			if _pname[i] == n:
				same += 1
				if old_same < 0 or _pt0[i] < _pt0[old_same]:
					old_same = i
			if oldest < 0 or _pt0[i] < _pt0[oldest]:
				oldest = i
		elif free < 0:
			free = i
	var k: int = old_same if same >= cap else (free if free >= 0 else oldest)
	_pname[k] = n
	_pt0[k] = now
	return players[k]

## passo no tipo de chão (grama, terra, neve, madeira, pedra, lama), com variação de tom
const STEPS := ["grass", "dirt", "snow", "wood", "stone", "mud"]
var _alt := false
func step(kind: String, vol_db: float = -19.0) -> void:
	_alt = not _alt
	# cada passo um pouco diferente: tom e força variam (o pé não bate sempre igual)
	play("step_%s_%s" % [kind, "a" if _alt else "b"], vol_db + randf_range(-1.5, 1.0), randf_range(.9, 1.12))

var _st_cache := {}
func _stream(base: String) -> AudioStream:
	## procura .ogg (instrumentos reais) e, se não houver, .wav (sintetizado); devolve em loop
	## (fica guardada: carregar a música na troca de trecho dava uma travadinha)
	if _st_cache.has(base):
		return _st_cache[base]
	var r := _stream_load(base)
	_st_cache[base] = r
	return r

func _stream_load(base: String) -> AudioStream:
	# música em camadas: as três tocam juntas, na mesma amostra (AudioStreamSynchronized),
	# e o volume de cada camada é mudado durante a música (ver _apply_layers)
	if base.begins_with("mus_") and base.substr(4) in LAYERED and ResourceLoader.exists("res://assets/audio/%s_3.ogg" % base):
		var sy := AudioStreamSynchronized.new()
		sy.stream_count = 3
		for i in 3:
			var st = load("res://assets/audio/%s%s.ogg" % [base, "" if i == 0 else "_%d" % (i + 1)])
			var c: AudioStreamOggVorbis = st.duplicate()
			c.loop = true
			sy.set_sync_stream(i, c)
			sy.set_sync_stream_volume(i, 0.0 if i == 0 else -60.0)
		return sy
	for ext in ["ogg", "wav"]:
		var path := "res://assets/audio/%s.%s" % [base, ext]
		if ResourceLoader.exists(path):
			var st = load(path)
			if st is AudioStreamOggVorbis:
				var c: AudioStreamOggVorbis = st.duplicate()
				c.loop = true
				return c
			return _loop(st)
	return null

## Troca a música com um cruzamento suave (e o som ambiente do trecho junto)
## músicas de batalha dos reis: a mesma faixa de batalha em outro andamento e tom
## (cavalo, trenó, jangada, avião e carrinho têm faixa própria: mus_cavalo, mus_treno...)
## "neve" é a canção da Lia tocando na neve (com vento de fundo; nos menus ela toca sem vento)
const SONG_ALIAS := {"gaviao": ["perseguicao", 1.1], "bagre": ["perseguicao", .84], "urso": ["perseguicao", .94], "pedra": ["perseguicao", 1.15], "neve": ["tema", 1.0]}
var song_base := ""

func set_song(n: String) -> void:
	if n == song or n == "":
		return
	var al: Array = SONG_ALIAS.get(n, [n, 1.0])
	var s := _stream("mus_" + al[0])
	if s == null:
		return
	# depois de uma luta, a música respira: uma pausa logo em seguida (se a última já vai longe)
	if song in BATTLE and al[0] in REST_SONGS and _since_rest > 45.0:
		_since_rest = maxf(_since_rest, _next_rest - 8.0)
	# outra música em camadas: o tempo no trecho recomeça (voltar do cavalo para a neve não zera)
	if al[0] in LAYERED and al[0] != _layer_song:
		_layer_song = al[0]
		_layer_time = 0.0
	song = n
	song_base = al[0]
	if s is AudioStreamSynchronized:
		_int_cur = _int_value()
		_apply_layers(s as AudioStreamSynchronized, _int_cur)
	# troca rápida (antes do cruzamento anterior acabar): o cruzamento velho é cancelado, senão
	# ele terminava parando o tocador que já estava com a música nova (ficava tudo mudo)
	if _mus_tw and _mus_tw.is_valid():
		_mus_tw.kill()
	var old := music
	music = music2
	music2 = old
	music.stream = s
	music.pitch_scale = al[1]
	music.volume_db = -40
	music.play()
	var tw := create_tween()
	_mus_tw = tw
	var fading := music2
	tw.tween_property(music, "volume_db", SONG_DB.get(al[0], -7.0), 1.4)
	tw.parallel().tween_property(fading, "volume_db", -40.0, 1.4)
	tw.tween_callback(func():
		# só para o tocador se ele ainda for o que estava saindo
		if fading != music:
			fading.stop())
	set_amb(AMB_FOR.get(n, AMB_FOR.get(al[0], "")))

func set_amb(n: String) -> void:
	if n == amb_name:
		return
	amb_name = n
	if _amb_tw and _amb_tw.is_valid():
		_amb_tw.kill()
	var old := amb
	amb = amb2
	amb2 = old
	var tw := create_tween()
	_amb_tw = tw
	if n != "":
		var s := _stream("amb_" + n)
		if s:
			amb.stream = s
			amb.volume_db = -40
			amb.play()
			tw.tween_property(amb, "volume_db", -13.0, 2.0)
		else:
			amb.stop()
	else:
		amb.stop()
	var fading := amb2
	tw.parallel().tween_property(fading, "volume_db", -40.0, 2.0)
	tw.tween_callback(func():
		if fading != amb:
			fading.stop())

func stop_music() -> void:
	if _mus_tw and _mus_tw.is_valid():
		_mus_tw.kill()
	# some em meio segundo em vez de cortar seco (fim de jogo, menu)
	var tw := create_tween().set_parallel(true)
	_mus_tw = tw
	for m in [music, music2]:
		if m.playing:
			tw.tween_property(m, "volume_db", -40.0, .5)
	tw.chain().tween_callback(func():
		if song == "":
			music.stop()
			music2.stop())
	danger.stop()
	danger_lv = 0.0
	song = ""
	song_base = ""
	set_amb("")

## perigo de 0 a 1: os tambores entram aos poucos e saem suavemente
func set_danger(v: float) -> void:
	if danger.stream == null:
		return
	# (suavização pelo tempo, não por quadro: o mesmo ritmo em telas de 60, 90 ou 120 Hz)
	var f: float = get_process_delta_time() * 60.0
	danger_lv = lerpf(danger_lv, v, 1.0 - pow(1.0 - (.02 if v > danger_lv else .008), f))
	if danger_lv > .02 and not danger.playing:
		danger.play()
	elif danger_lv <= .02 and danger.playing:
		danger.stop()
	danger.volume_db = linear_to_db(max(danger_lv, .0001)) - 9.0

## som que sai de um ponto do mundo (fogueira, riacho): mais alto de perto e do lado certo no fone
func emitter(parent: Node, name_: String, pos: Vector2, vol: float, dist: float) -> void:
	var path := "res://assets/audio/%s.wav" % name_
	if not ResourceLoader.exists(path):
		return
	var e := AudioStreamPlayer2D.new()
	# o mesmo laço para todas as fogueiras/riachos (antes cada uma ganhava uma cópia do som)
	if not _loops.has(path):
		_loops[path] = _loop(load(path))
	e.stream = _loops[path]
	e.position = pos
	e.volume_db = vol
	e.max_distance = dist
	e.attenuation = 1.6
	e.autoplay = true
	e.bus = "Mundo"
	parent.add_child(e)
	emitters.append(e)

## fogueiras e riachos longe (fora do alcance do som) ficam pausados: o mixer não processa dezenas de
## laços tocando em silêncio pela fase inteira
var emitters: Array = []
var _em_t := 0
var _loops := {}
func _pause_far_emitters() -> void:
	_em_t += 1
	if _em_t % 12 != 0:
		return
	emitters = emitters.filter(func(e): return is_instance_valid(e))
	if emitters.is_empty():
		return
	var cam := get_viewport().get_camera_2d()
	if cam == null:
		return
	var c: Vector2 = cam.get_screen_center_position()
	for e in emitters:
		var far: bool = e.global_position.distance_to(c) > e.max_distance * 1.15 + 400.0
		if e.stream_paused != far:
			e.stream_paused = far

func set_rain(v: float) -> void:
	rain_target = v
	if v > 0.01 and not rain.playing:
		rain.play()

func _process(_d: float) -> void:
	_pause_far_emitters()
	# fora do jogo o Mundo some suave; os tambores do perigo também saem
	world_gain = move_toward(world_gain, 1.0 if world_on else 0.0, _d * 3.0)
	AudioServer.set_bus_volume_db(bus_world, linear_to_db(max(world_gain, .0001)))
	AudioServer.set_bus_mute(bus_world, world_gain <= .001)
	if not world_on and danger_lv > 0.0:
		danger_lv = move_toward(danger_lv, 0.0, _d * 1.5)
		danger.volume_db = linear_to_db(max(danger_lv, .0001)) - 9.0
		if danger_lv <= .02 and danger.playing:
			danger.stop()
			danger_lv = 0.0
	_music_flow(_d)
	var tgt := -60.0 if rain_target < 0.01 else lerpf(-30.0, -10.0, rain_target)
	rain.volume_db = lerpf(rain.volume_db, tgt, 1.0 - pow(.95, _d * 60.0))
	if rain_target < 0.01 and rain.volume_db < -55 and rain.playing:
		rain.stop()

# ----------------------------------------------------------------- camadas e pausas da música
## O jogo chama music_hint() a cada quadro durante a partida: quanto do trecho já foi andado (0..1),
## se a música pode dar uma pausa agora e se é um lugar calmo (fogueira). Sem chamada recente
## (menus, cenas, placar), as camadas voltam para a calma e a pausa acaba.
var _hint_frame := -100
var _hint_pos := 0.0
var _hint_rest := false
var _hint_calm := false
var _layer_song := ""
var _layer_time := 0.0
var _int_cur := 0.0
var rest_gain := 1.0
var _rest_st := 0          # 0 tocando, 1 descendo, 2 em silêncio, 3 voltando
var _rest_t := 0.0
var _rest_hold := 20.0
var _since_rest := 0.0
var _next_rest := 150.0
const REST_FADE := 4.0

func music_hint(pos: float, can_rest: bool, calm: bool) -> void:
	_hint_frame = Engine.get_process_frames()
	_hint_pos = clampf(pos, 0.0, 1.0)
	_hint_rest = can_rest
	_hint_calm = calm

func _hint_fresh() -> bool:
	return Engine.get_process_frames() - _hint_frame <= 2

## animação desejada (0..1): o quanto o Tomé andou no trecho, ou o tempo que ele já passou nele
## (quem demora explorando também ganha música mais viva: até a metade em 4 minutos)
func _int_value() -> float:
	if not _hint_fresh():
		return 0.0
	return maxf(_hint_pos, minf(_layer_time / 240.0, .55))

## volume de cada camada: a 2 entra entre 15% e 45% da animação, a 3 entre 50% e 85%
func _apply_layers(sy: AudioStreamSynchronized, v: float) -> void:
	var g2: float = smoothstep(.15, .45, v)
	var g3: float = smoothstep(.5, .85, v)
	sy.set_sync_stream_volume(1, maxf(linear_to_db(maxf(g2, .0001)), -60.0))
	sy.set_sync_stream_volume(2, maxf(linear_to_db(maxf(g3, .0001)), -60.0))

## começa a volta da música a partir do volume em que ela está (sem salto)
var _rest_k := 0.0
func _rest_back() -> void:
	_rest_st = 3
	_rest_k = acos(clampf(1.0 - 2.0 * rest_gain, -1.0, 1.0)) / PI

func _music_flow(d: float) -> void:
	var fresh := _hint_fresh()
	# camadas: sobem devagar (uns 30 s da calma à animação completa), sem nenhum corte
	if song_base in LAYERED and fresh:
		_layer_time += d
	var tgt := _int_value()
	_int_cur = move_toward(_int_cur, tgt, d * (1.0 / 30.0 if fresh else .35))
	if music and music.stream is AudioStreamSynchronized:
		_apply_layers(music.stream as AudioStreamSynchronized, _int_cur)
	# pausas: de tempos em tempos a música desce até o silêncio (~4 s), deixa ouvir o mundo
	# por 15-30 s e volta (~4 s). Chefe, perseguição ou trecho especial começando: volta já.
	var ok: bool = fresh and _hint_rest and song_base in REST_SONGS
	var g0 := rest_gain
	_rest_t += d
	match _rest_st:
		0:
			if ok:
				_since_rest += d
			if ok and danger_lv < .3 and (_since_rest >= _next_rest or (_hint_calm and _since_rest >= 75.0)):
				_rest_st = 1
				_rest_t = 0.0
		1:
			rest_gain = .5 + .5 * cos(PI * clampf(_rest_t / REST_FADE, 0.0, 1.0))
			if not ok:
				_rest_back()
			elif _rest_t >= REST_FADE:
				_rest_st = 2
				_rest_t = 0.0
				_rest_hold = randf_range(15.0, 30.0)
		2:
			rest_gain = 0.0
			if not ok or _rest_t >= _rest_hold:
				_rest_back()
		3:
			# volta em ~4 s (curva suave); se foi interrompida (chefe, menu), volta em 1 s
			_rest_k = minf(_rest_k + d / (REST_FADE if ok else 1.0), 1.0)
			rest_gain = .5 - .5 * cos(PI * _rest_k)
			if _rest_k >= 1.0:
				rest_gain = 1.0
				_rest_st = 0
				_since_rest = 0.0
				_next_rest = randf_range(120.0, 180.0)
	if rest_gain != g0:
		_apply_volumes()
		# o ambiente sobe um pouco (até +4 dB) enquanto a música está quieta
		AudioServer.set_bus_volume_db(bus_amb, 4.0 * (1.0 - rest_gain))

## vibração: uma por vez — pedidos durante uma vibração mais longa são ignorados (vários golpes no
## mesmo instante não viram um zumbido contínuo), e nada mais longo que 250 ms
var _vib_until := 0
func vib(ms: int) -> void:
	if not Save.getv("opt", "vibrate", true):
		return
	var now := Time.get_ticks_msec()
	if now < _vib_until and now + ms <= _vib_until + 20:
		return
	ms = mini(ms, 250)
	_vib_until = now + ms
	Input.vibrate_handheld(ms)
