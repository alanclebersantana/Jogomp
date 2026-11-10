extends "res://tests/route_gru.gd"
## Fios eletrificados do vão do mezanino: sem as luvas isolantes dão choque (não seguram, e o Milis
## volta para a passarela sem cair no buraco); com as luvas, seguram.
func _tenta(com_luvas: bool) -> String:
	carregar(0, false)
	g.lives = 99
	if com_luvas:
		g.give_item("luvas")
	P.x = 11380.0
	P.y = 100.0
	wait_ground()
	walk_to(11432)
	# pula com pulo duplo segurando para a direita (como o jogador faria) até agarrar ou pousar
	press("J")
	for i in 160:
		P = g.player
		if i == 16:
			press("J")
		frame({"J": i < 40, "R": true})
		if P.vine == g.VINES[0]:
			return "segurou"
		if P.onGround and i > 5:
			break
	wait_ground()
	return "chão y=%d x=%d vidas=%d" % [int(P.y + P.h), int(px()), g.lives]
func _initialize() -> void:
	var f := 0
	var sem := _tenta(false)
	print("sem luvas: ", sem)
	if sem == "segurou" or not sem.begins_with("chão y=160"):
		f += 1
	var com := _tenta(true)
	print("com luvas: ", com)
	if com != "segurou":
		f += 1
	print("FALHAS: ", f)
	quit()
