extends Node2D
## Nó que só desenha: chama 'f' (Callable que recebe o próprio nó) no _draw.
var f: Callable


func _draw() -> void:
	if f.is_valid():
		f.call(self)
