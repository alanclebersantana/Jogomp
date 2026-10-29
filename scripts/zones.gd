extends RefCounted
class_name Zones
## Áreas fora do mapa principal (ex.: a corrida a cavalo), cada uma com sua câmera, fundo e clima.
## No JSON da fase: "zones": [{"id", "x0", "y0", "x1", "y1", "bg", "song"}]

var g  # Game
var ZONES: Array = []
var zone = null

func _init(game) -> void:
	g = game

func load_level() -> void:
	ZONES = g.L.get("zones", [])
	zone = null

func zone_at(x: float, y: float):
	for z in ZONES:
		if x >= z.x0 and x <= z.x1 and y >= z.y0 - 200 and y <= z.y1 + 200:
			return z
	return null

func pre() -> void:
	var p: Dictionary = g.player
	zone = zone_at(p.x + p.w / 2, p.y + p.h / 2)

func post() -> void:
	var p: Dictionary = g.player
	if zone != null and p.y > zone.y1 + 60 and p.dyingT == 0:
		g.die("Você caiu.")

func cam_rect() -> Rect2:
	return Rect2(zone.x0, zone.y0, zone.x1 - zone.x0, zone.y1 - zone.y0)
