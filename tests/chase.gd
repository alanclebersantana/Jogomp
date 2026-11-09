extends "res://tests/route_gru.gd"
## Teste das perseguições do vulto (1-1): correndo alcança; só andando ele escapa.
func _one(run: bool, idx: int) -> int:
	carregar(0, false)
	var c: Dictionary = g.TC.CH[idx]
	P.x = float(c.trig) - 60
	P.y = float(c.y) - P.h
	wait_ground()
	if run:
		frame({"R": true})
		frame({})
		frame({"R": true})
	for i in 400:
		frame({"R": true})
		if int(c.st) >= 2:
			break
	return int(c.st)

func _initialize() -> void:
	var f := 0
	for i in 2:
		var a := _one(true, i)
		var b := _one(false, i)
		print("perseguição %d: correndo=%s andando=%s" % [i + 1, ["", "", "pegou", "escapou"][a], ["", "", "pegou", "escapou"][b]])
		if a != 2:
			f += 1
	print("FALHAS: %d" % f)
	quit()
