extends "res://tests/route_gru.gd"
func _initialize() -> void:
	carregar(0, false)
	g.player.x = 13210
	g.player.y = 466
	g.snap_camera()
	wait_ground()
	jump_to(13285)
	for i in 120:
		frame()
		if i % 6 == 0:
			print(i, " x=", int(px()), " y=", int(P.y), " vy=", snapped(P.vy, .1), " g=", P.onGround)
	quit()
