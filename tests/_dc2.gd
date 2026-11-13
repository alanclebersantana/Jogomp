extends SceneTree
var main
func _dc() -> int:
	var tot := 0
	for i in 2:
		await process_frame
	for i in 3:
		await process_frame
		tot += int(RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME))
	return tot / 3
func walk(n: Node, out: Array, path: String) -> void:
	for c in n.get_children():
		var nm: String = path + "/" + (c.get_script().resource_path.get_file() if c.get_script() else c.get_class())
		if c is CanvasItem and c.visible:
			out.append([nm, c])
		walk(c, out, nm)
func _initialize() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	for i in 3:
		await process_frame
	main.start_level(false, int(OS.get_environment("LVL")))
	await process_frame
	for k in 3:
		if main.panel and main.panel.has_meta("ok"):
			main.panel.get_meta("ok").call()
		for c in main.ui_layer.get_children():
			if c.has_method("_end"):
				c._end()
		await process_frame
	var g = main.game
	for n in g.L.get("npcs", []):
		n.seen = true
	for a in OS.get_cmdline_user_args():
		g.player.x = float(a)
		g.player.y = 400
		g.snap_camera()
		for i in 60:
			await process_frame
		var base: int = await _dc()
		var out := []
		walk(main, out, "")
		var res := []
		for cd in out:
			cd[1].visible = false
			var v: int = await _dc()
			cd[1].visible = true
			res.append([base - v, cd[0]])
		res.sort_custom(func(x, y): return x[0] > y[0])
		var s := ""
		for r in res.slice(0, 12):
			s += "\n   %d %s" % [r[0], r[1]]
		print("DC x=%s total=%d nodes=%d%s" % [a, base, out.size(), s])
	quit()
