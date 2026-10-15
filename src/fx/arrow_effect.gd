extends Node2D
## 弓の矢。見た目だけ（ダメージは撃った瞬間に入っている）。

var from: Vector2
var to: Vector2
var duration: float = 0.18

var _t := 0.0


func _ready() -> void:
	z_index = 25
	position = from


func _process(delta: float) -> void:
	_t += delta
	position = from.lerp(to, clampf(_t / duration, 0.0, 1.0))
	if _t >= duration:
		queue_free()
	queue_redraw()


func _draw() -> void:
	var dir := (to - from).normalized()
	var tail := -dir * 26.0
	draw_line(tail, Vector2.ZERO, DoodleStyle.INK, 3.0, true)
	draw_colored_polygon(PackedVector2Array([dir * 8.0, dir.orthogonal() * 5.0, -dir.orthogonal() * 5.0]), DoodleStyle.INK)
	draw_line(tail, tail - dir * 6.0 + dir.orthogonal() * 6.0, DoodleStyle.P2, 3.0)
	draw_line(tail, tail - dir * 6.0 - dir.orthogonal() * 6.0, DoodleStyle.P2, 3.0)
