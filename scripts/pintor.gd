extends Node2D
## Camada que só desenha: a função é passada pelo main.gd.
var desenhar: Callable

func _draw() -> void:
	if desenhar.is_valid():
		desenhar.call(self)
