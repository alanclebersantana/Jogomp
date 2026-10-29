extends SceneTree
## Prints das telas (em pé): título, abertura da fase, compartimento, pausa, opções, mapa, galeria, placar.
var main
var pasta := "/tmp/cade_ui"

func _snap(n: String, frames: int = 8) -> void:
	for i in frames:
		await process_frame
	root.get_texture().get_image().save_png(pasta.path_join("f_%s.png" % n))

func _fecha() -> void:
	if main.panel and is_instance_valid(main.panel):
		main.panel.queue_free()
		main.panel = null
	await process_frame

func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(pasta)
	root.get_node("Save").setv("opt", "tut_asked", true)
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await _snap("0titulo", 15)
	main.start_level(false, 0)
	await _snap("1abertura", 10)
	main.panel.get_meta("ok").call()
	await process_frame
	var g = main.game
	g.give_item("cartao_acesso")
	g.give_item("cordao")
	main.open_bag()
	await _snap("2compartimento")
	await _fecha()
	main._pause_menu()
	await _snap("3pausa")
	await _fecha()
	main.show_options(true)
	await _snap("4opcoes")
	await _fecha()
	main.show_map(false, false)
	await _snap("5mapa")
	await _fecha()
	main.show_gallery(1)
	await _snap("6galeria")
	await _fecha()
	main._on_results()
	await _snap("7placar")
	quit()
