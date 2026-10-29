extends SceneTree
## Desenha o Tomé em peças em várias poses, grande, para conferir os encaixes.
func _initialize() -> void:
	await process_frame
	var R = load("res://scripts/rig.gd")
	R.load_char("tome")
	R.data["tome"].scale_k *= 2.6
	var n = load("res://tests/rig_poser.gd").new()
	root.add_child(n)
	for i in 6:
		await process_frame
	root.get_texture().get_image().save_png("/tmp/fh_shots/rig_poses.png")
	quit()
