extends Node
## Efeitos e música. Os efeitos ficam em assets/audio/<nome>.wav; músicas em assets/audio/mus_<nome>.ogg.

var canais: Array[AudioStreamPlayer] = []
var musica: AudioStreamPlayer
var cache := {}
var atual := ""
var sons_ligados := true
var musica_ligada := true


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for i in 10:
		var p := AudioStreamPlayer.new()
		add_child(p)
		canais.append(p)
	musica = AudioStreamPlayer.new()
	musica.volume_db = -7.0
	add_child(musica)
	sons_ligados = bool(Save.opt("sons", true))
	musica_ligada = bool(Save.opt("musica", true))


func _stream(caminho: String) -> AudioStream:
	if not cache.has(caminho):
		cache[caminho] = load(caminho) if ResourceLoader.exists(caminho) else null
	return cache[caminho]


func toca(nome: String, vol_db := 0.0, tom := 1.0) -> void:
	if not sons_ligados:
		return
	var s := _stream("res://assets/audio/%s.wav" % nome)
	if s == null:
		return
	var livre: AudioStreamPlayer = null
	for p in canais:
		if not p.playing:
			livre = p
			break
	if livre == null:
		livre = canais[0]
	livre.stream = s
	livre.volume_db = vol_db
	livre.pitch_scale = tom
	livre.play()


func tema(nome: String) -> void:
	if nome == atual and musica.playing:
		return
	atual = nome
	musica.stop()
	if not musica_ligada or nome == "":
		return
	var s := _stream("res://assets/audio/mus_%s.ogg" % nome)
	if s == null:
		s = _stream("res://assets/audio/mus_%s.wav" % nome)
	if s == null:
		return
	if s is AudioStreamOggVorbis:
		(s as AudioStreamOggVorbis).loop = true
	elif s is AudioStreamWAV:
		(s as AudioStreamWAV).loop_mode = AudioStreamWAV.LOOP_FORWARD
		(s as AudioStreamWAV).loop_end = int((s as AudioStreamWAV).get_length() * (s as AudioStreamWAV).mix_rate)
	musica.stream = s
	musica.play()


func liga_musica(v: bool) -> void:
	musica_ligada = v
	Save.set_opt("musica", v)
	if v:
		var a := atual
		atual = ""
		tema(a)
	else:
		musica.stop()


func liga_sons(v: bool) -> void:
	sons_ligados = v
	Save.set_opt("sons", v)
