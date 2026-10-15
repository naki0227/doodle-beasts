extends Node2D
## 戦場（ノートのページ）の余白に描かれた落書き。草・花・小石・雲・太陽。
## 決まった種から毎回同じ配置で描く。真ん中（お城のまわり）は空けておく。

@export var arena: Rect2 = Rect2(0.0, 0.0, 1280.0, 720.0)
@export var keep_clear: Rect2 = Rect2(420.0, 220.0, 440.0, 300.0)
@export var seed_value: int = 20261015

var _items: Array[Dictionary] = []
var _t := 0.0


func _ready() -> void:
	z_index = -6
	material = DoodleStyle.doodle_material(1.0, 1.0)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var kinds := ["grass", "grass", "grass", "flower", "flower", "pebble", "star"]
	var tries := 0
	while _items.size() < 34 and tries < 400:
		tries += 1
		var p := Vector2(rng.randf_range(arena.position.x + 130.0, arena.end.x - 30.0), rng.randf_range(arena.position.y + 130.0, arena.end.y - 40.0))
		if keep_clear.has_point(p):
			continue
		_items.append({"kind": kinds[rng.randi() % kinds.size()], "p": p, "s": rng.randf_range(0.8, 1.3), "c": rng.randi() % 4})


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _draw() -> void:
	_sun(Vector2(1180.0, 640.0))
	_cloud(Vector2(250.0, 130.0), 1.1)
	_cloud(Vector2(860.0, 160.0), 0.9)
	var flower_colors := [DoodleStyle.ERASER_PINK, DoodleStyle.P2_LIGHT, Color("b9d7ff"), Color("d9b8ff")]
	for item in _items:
		var p: Vector2 = item["p"]
		var s: float = item["s"]
		match item["kind"]:
			"grass":
				for k in range(3):
					var a := -PI / 2.0 + (k - 1) * 0.45 + sin(_t * 1.5 + p.x) * 0.05
					draw_line(p + Vector2((k - 1) * 4.0, 0.0), p + Vector2((k - 1) * 4.0, 0.0) + Vector2(cos(a), sin(a)) * 12.0 * s, Color("7fbf7a"), 2.5, true)
			"flower":
				draw_line(p, p + Vector2(0.0, -14.0 * s), Color("7fbf7a"), 2.5, true)
				var head := p + Vector2(0.0, -16.0 * s)
				for k in range(5):
					var a := TAU * k / 5.0
					draw_circle(head + Vector2(cos(a), sin(a)) * 5.0 * s, 4.0 * s, flower_colors[item["c"]])
				draw_circle(head, 3.0 * s, DoodleStyle.P2)
			"pebble":
				DoodleStyle.draw_shape(self, DoodleStyle.ellipse(p, Vector2(7.0, 4.5) * s, 10), Color("d8d2c4"), 2.0, DoodleStyle.INK_SOFT)
			"star":
				var points := PackedVector2Array()
				for k in range(10):
					var r := (7.0 if k % 2 == 0 else 3.0) * s
					var a := -PI / 2.0 + TAU * k / 10.0
					points.append(p + Vector2(cos(a), sin(a)) * r)
				DoodleStyle.draw_shape(self, points, DoodleStyle.P2_LIGHT, 1.5, DoodleStyle.INK_SOFT)


func _cloud(center: Vector2, s: float) -> void:
	var drift := Vector2(sin(_t * 0.3 + center.x) * 6.0, 0.0)
	for c in [Vector2(-26, 4), Vector2(0, -8), Vector2(26, 4), Vector2(0, 8)]:
		draw_circle(center + drift + c * s, 20.0 * s, Color(1, 1, 1, 0.85))
	for c in [Vector2(-26, 4), Vector2(0, -8), Vector2(26, 4)]:
		draw_arc(center + drift + c * s, 20.0 * s, PI * 0.9, PI * 2.1, 14, Color(DoodleStyle.CASTLE_FLAG, 0.6), 2.0, true)


func _sun(center: Vector2) -> void:
	for k in range(10):
		var a := TAU * k / 10.0 + _t * 0.2
		draw_line(center + Vector2(cos(a), sin(a)) * 34.0, center + Vector2(cos(a), sin(a)) * 48.0, DoodleStyle.P2, 3.0, true)
	DoodleStyle.draw_shape(self, DoodleStyle.ellipse(center, Vector2(26.0, 26.0), 20), DoodleStyle.P2_LIGHT, 2.5, DoodleStyle.P2.darkened(0.2))
	draw_circle(center + Vector2(-8.0, -4.0), 2.5, DoodleStyle.INK)
	draw_circle(center + Vector2(8.0, -4.0), 2.5, DoodleStyle.INK)
	draw_arc(center + Vector2(0.0, 4.0), 8.0, 0.3, PI - 0.3, 10, DoodleStyle.INK, 2.0, true)
