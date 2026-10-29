extends SceneTree
## Teste automático: o robô joga a Fase 1 inteira e precisa embarcar.
## godot --headless --path . -s tests/route.gd

func _init() -> void:
	var F: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/data/guarulhos.json"))
	var falhas := 0
	for caso in [["normal", false], ["sem planar (subsolo)", true]]:
		var s := Sim.new(F, 0.0, false)
		s.bot = true
		var n := 0
		while s.fim == "" and n < 120 * 200:
			s.passo(1.0 / 120.0)
			if caso[1]:
				s.hold = false
			n += 1
		var ok: bool = s.fim == "venceu"
		print("%s %s: fim=%s x=%.1f milhas=%d/%d mala=%s cartao=%d tempo=%.1f tropecos=%d guarda=%.1f" % ["✓" if ok else "✗", caso[0], s.fim, s.px, s.n_milhas, int(F["alvo_milhas"]), s.achou_mala, s.n_cartao, float(F["tempo"]) - s.tempo, s.tropecos, s.guarda])
		if not ok:
			falhas += 1
	print("FALHAS: %d" % falhas)
	quit(1 if falhas > 0 else 0)
