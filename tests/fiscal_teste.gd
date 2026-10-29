extends "res://tests/route_gru.gd"
## Só a luta com o Fiscal Falso (para ajustar): começa no totem antes da arena.
func _initialize() -> void:
	carregar(0, false)
	g.player.x = 14380
	g.player.y = 466
	walk_to(14820)
	var b: Dictionary = g.X.BOSS
	print("ativo=", g.X.boss_active(), " st=", b.st)
	var hp0: int = P.hp
	var ult := ""
	for i in 40:
		var r = luta_fiscal_passos(150)
		var est := "st=%s hp=%d bt=%s k=%s jog_hp=%d vidas=%d x=%d y=%d" % [b.st, b.hp, b.get("bt", 0), b.get("beam_k", ""), P.hp, g.lives, int(px()), int(P.y)]
		if est != ult:
			print(est)
			ult = est
		if b.done:
			break
	quit()

func luta_fiscal_passos(n: int):
	return luta_fiscal_lim(n)
