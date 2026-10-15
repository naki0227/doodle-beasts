extends Node2D
## 地面に残る消しカスやインクの点。一つのノードでまとめて描いて軽くする。

const MAX_MARKS := 400

var _marks: Array[Dictionary] = []
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	add_to_group(&"fx_decals")
	z_index = -5
	_rng.randomize()


func add_marks(at: Vector2, color: Color, count: int, spread: float) -> void:
	for i in range(count):
		_marks.append({
			"position": at + Vector2(_rng.randf_range(-spread, spread), _rng.randf_range(-spread * 0.5, spread * 0.5)),
			"angle": _rng.randf_range(0.0, TAU),
			"length": _rng.randf_range(2.0, 5.0),
			"color": Color(color, _rng.randf_range(0.55, 0.9)),
		})
	while _marks.size() > MAX_MARKS:
		_marks.pop_front()
	queue_redraw()


func _draw() -> void:
	for mark in _marks:
		var dir: Vector2 = Vector2.RIGHT.rotated(mark["angle"]) * mark["length"]
		var p: Vector2 = mark["position"]
		draw_line(p - dir, p + dir, mark["color"], 3.0, true)
