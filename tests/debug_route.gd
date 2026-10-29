extends SceneTree
## Mostra onde o robô tropeça (para ajustar a fase).
func _init() -> void:
	var F: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/data/guarulhos.json"))
	for sem_planar in [false, true]:
		var s := Sim.new(F, 0.0, false)
		s.bot = true
		var n := 0
		var ultimo := ""
		while s.fim == "" and n < 120 * 200:
			s.passo(1.0 / 120.0)
			if sem_planar:
				s.hold = false
			var trop := false
			for e in s.eventos:
				if e[0] == "aviso":
					ultimo = str(e[1])
				if e[0] == "queda":
					print("  QUEDA x=%.1f" % s.px)
				if e[0] == "som" and e[1] == "tropeco":
					trop = true
				if e[0] == "som" and e[1] == "alarme":
					print("  alarme x=%.1f" % s.px)
			if trop:
				print("  tropeço x=%.1f (antigo %.1f) y=%.1f z=%.1f (%s)" % [s.px, s.px - 140.0, s.py, s.pz, ultimo])
			s.eventos.clear()
			n += 1
		print("sem_planar=%s fim=%s x=%.1f guarda=%.1f cartao=%d mala=%s" % [sem_planar, s.fim, s.px, s.guarda, s.n_cartao, s.achou_mala])
	quit()
