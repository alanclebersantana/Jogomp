class_name Sons
## Sons provisórios gerados em código.


## Som simples gerado em código (onda quadrada/triangular com queda).
static func tom(f0: float, f1: float, dur: float, onda := "square", vol := 0.35) -> AudioStreamWAV:
	var taxa := 22050
	var n := int(dur * taxa)
	var dados := PackedByteArray()
	dados.resize(n * 2)
	var fase := 0.0
	for i in n:
		var t := float(i) / n
		var f: float = f0 * pow(f1 / f0, t) if f1 > 0.0 else f0
		fase += f / taxa
		var s := 0.0
		match onda:
			"square":
				s = 1.0 if fmod(fase, 1.0) < 0.5 else -1.0
			"triangle":
				s = 4.0 * abs(fmod(fase, 1.0) - 0.5) - 1.0
			"saw":
				s = 2.0 * fmod(fase, 1.0) - 1.0
			_:
				s = sin(fase * TAU)
		var env := pow(1.0 - t, 2.0)
		dados.encode_s16(i * 2, int(clamp(s * env * vol, -1.0, 1.0) * 32000.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = taxa
	w.stereo = false
	w.data = dados
	return w
