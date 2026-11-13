extends SceneTree
func _initialize() -> void:
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	for i in 3:
		await process_frame
	var Spr = root.get_node("Spr")
	var lvl := int(OS.get_environment("LVL"))
	main.start_level(false, lvl)
	await process_frame
	for k in 3:
		if main.panel and main.panel.has_meta("ok"):
			main.panel.get_meta("ok").call()
		for c in main.ui_layer.get_children():
			if c.has_method("_end"):
				c._end()
		await process_frame
	var g = main.game
	g.lives = 99
	for n in g.L.get("npcs", []):
		n.seen = true
	for a in OS.get_cmdline_user_args():
		g.player.x = float(a)
		g.player.y = 400
		g.snap_camera()
		for i in 40:
			await process_frame
		Spr.cnt = {}
		for n in root.find_children("*", "CanvasItem", true, false):
			if n.get_script() and n.get_script().resource_path.ends_with("world_static.gd") and OS.get_environment("STATIC") != "" and n.x1 > g.cam and n.x0 < g.cam + g.W:
				n.queue_redraw()
		await process_frame
		await process_frame
		var c: Dictionary = Spr.cnt
		Spr.cnt = null
		var ks := c.keys()
		ks.sort_custom(func(x, y): return c[x] > c[y])
		var tot := 0
		for k in ks: tot += c[k]
		var s := ""
		for k in ks.slice(0, 22):
			s += " %s=%d" % [k, c[k] / 2]
		print("CNT x=%s prim=%d dc=%d |%s" % [a, tot / 2, RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME), s])
	quit()
