extends Node2D
## (teste) poses do Tomé em peças
var t := 0
func _draw() -> void:
	Spr.begin(self)
	draw_rect(Rect2(0, 0, 1600, 520), Color(.55, .7, .55))
	var states := [
		{"name": "parado", "p": {}},
		{"name": "andando", "p": {"vx": 3.0, "anim": 3.0}},
		{"name": "correndo", "p": {"vx": 6.0, "anim": 5.0, "run": 1}},
		{"name": "pulo", "p": {"onGround": false, "vy": -6.0}},
		{"name": "queda", "p": {"onGround": false, "vy": 6.0}},
		{"name": "golpe1", "p": {"act": "swing", "actT": 20}},
		{"name": "golpe2", "p": {"act": "swing", "actT": 14}},
		{"name": "golpe3", "p": {"act": "swing", "actT": 8}},
		{"name": "defesa", "p": {"guard": true}},
		{"name": "agachado", "p": {"crouch": true}},
		
	]
	var i := 0
	for s in states:
		var p := {"vx": 0.0, "vy": 0.0, "anim": 0.0, "run": 0, "onGround": true, "swim": false, "crouch": false, "act": "", "actT": 0, "guard": false, "wslide": false, "pushT": 0, "landT": 0}
		for k in s.p:
			p[k] = s.p[k]
		var x := 80.0 + (i % 5) * 300
		var y := 240.0 + int(i / 5) * 260
		Rig.draw_pose("tome", x, y, 1.0, Rig.pose_for(p, 40), Vector2.ONE)
		Spr.begin(self)
		Spr.text(s.name, x - 40, y + 20, 16, Color.BLACK)
		i += 1

