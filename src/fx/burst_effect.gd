extends Node2D
## 当たりや出現のときの、放射状の線と飛び散る粒。自分で消える。

var color: Color = DoodleStyle.INK
var size: float = 1.0
var crumb_count: int = 10
var lifetime: float = 0.45

var _t := 0.0
var _rays: Array[Vector2] = []
var _crumbs: Array[Dictionary] = []


func _ready() -> void:
	z_index = 20
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var ray_count := 7 + int(size * 2.0)
	for i in range(ray_count):
		var angle := TAU * i / ray_count + rng.randf_range(-0.2, 0.2)
		_rays.append(Vector2.RIGHT.rotated(angle) * rng.randf_range(0.7, 1.15))
	for i in range(crumb_count):
		var angle := rng.randf_range(0.0, TAU)
		_crumbs.append({
			"velocity": Vector2.RIGHT.rotated(angle) * rng.randf_range(90.0, 230.0) * size,
			"position": Vector2.ZERO,
			"spin": rng.randf_range(-12.0, 12.0),
			"angle": rng.randf_range(0.0, TAU),
			"length": rng.randf_range(3.0, 7.0) * size,
		})


func _process(delta: float) -> void:
	_t += delta
	for crumb in _crumbs:
		crumb["velocity"] += Vector2(0.0, 520.0) * delta
		crumb["velocity"] *= 0.96
		crumb["position"] += crumb["velocity"] * delta
		crumb["angle"] += crumb["spin"] * delta
	if _t >= lifetime:
		queue_free()
	queue_redraw()


func _draw() -> void:
	var k := clampf(_t / lifetime, 0.0, 1.0)
	var ease_out := 1.0 - pow(1.0 - k, 3.0)
	var alpha := 1.0 - k
	var inner := 14.0 * size * ease_out
	var outer := (20.0 + 30.0 * ease_out) * size
	for ray in _rays:
		draw_line(ray * inner, ray * outer, Color(DoodleStyle.INK, alpha), 3.0, true)
	if k < 0.35:
		draw_circle(Vector2.ZERO, 16.0 * size * (1.0 - k * 2.0), Color(1, 1, 1, 0.8 * (1.0 - k / 0.35)))
	for crumb in _crumbs:
		var dir: Vector2 = Vector2.RIGHT.rotated(crumb["angle"]) * crumb["length"]
		var p: Vector2 = crumb["position"]
		draw_line(p - dir, p + dir, Color(color, alpha), 3.5, true)
