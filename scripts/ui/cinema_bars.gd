extends Control
## Faixas pretas de cinema (em cima e embaixo): entram deslizando com suavidade nas falas,
## na apresentação dos chefes e na câmera lenta do golpe final, e saem depois.

var target := 0.0
var amt := 0.0
const BAR := 58.0

func _process(d: float) -> void:
	var old := amt
	amt = move_toward(amt, target, d * (2.6 if target > amt else 1.8))
	if amt != old or amt > 0.0:
		queue_redraw()

## altura atual da faixa (com aceleração e freio suaves)
func px() -> float:
	var e: float = amt * amt * (3.0 - 2.0 * amt)
	return e * BAR

func _draw() -> void:
	var h := px()
	if h <= .5:
		return
	draw_rect(Rect2(0, 0, size.x, h), Color.BLACK)
	draw_rect(Rect2(0, size.y - h, size.x, h), Color.BLACK)
