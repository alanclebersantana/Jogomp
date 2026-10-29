extends SceneTree
## Prints para conferir: FOTO=telas (todas as telas) ou FOTO=fase com FASE=1-1 e PONTOS="x,y;x,y" (em quadrados).
## Uso: xvfb-run -a godot --path . -s tests/foto.gd --rendering-driver opengl3

var pasta := "/tmp/corrida_fotos"
var main


func _snap(n: String, frames := 6) -> void:
	for i in frames:
		await process_frame
	root.get_texture().get_image().save_png(pasta.path_join(n + ".png"))


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(pasta)
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await _snap("x", 2)
	var modo := OS.get_environment("FOTO")
	if modo == "telas":
		await _snap("t0_titulo", 20)
		main.mapa()
		await _snap("t1_mapa", 8)
		main.abertura("1-1")
		await _snap("t2_abertura", 8)
		main.comeca("1-1")
		await _snap("t3_pronto", 20)
		main._pausa()
		await _snap("t4_pausa", 8)
		main._continua()
		main._embarcou({"milhas": 120, "total": 148, "sobra": 24.0, "todas": false, "rapido": true, "quedas": 2, "meta": 20})
		await _snap("t5_resultado", 10)
		main._perdeu()
		await _snap("t6_perdeu", 10)
	else:
		var fid := OS.get_environment("FASE")
		main.comeca(fid)
		var j = main.jogo
		j.bot = true
		var pts := OS.get_environment("PONTOS").split(";")
		var i := 0
		for p in pts:
			var xy := p.split(",")
			j.pos = Vector2(float(xy[0]) * 40 + 20, float(xy[1]) * 40)
			j.cam = j.pos
			j.vel = Vector2.ZERO
			j.estado = "chao"
			j.invul = 0.0
			j.fade = 0.0
			if xy.size() > 2:
				j.dir = int(xy[2])
			await _snap("f%s_%02d" % [fid, i], 40)
			i += 1
	quit()
