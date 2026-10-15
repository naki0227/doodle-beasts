extends Node2D
## 戦場（はかり野の草地）の小物。草むら・白い小花・紫の花・苔むした石・半分埋まった骨・錆びた車輪・柵とワタリガラス。
## 決まった種から毎回同じ配置で描く。真ん中（金の駒のまわり）は空けておく。

@export var arena: Rect2 = Rect2(0.0, 250.0, 1280.0, 470.0)
@export var keep_clear: Rect2 = Rect2(400.0, 330.0, 480.0, 280.0)
@export var seed_value: int = 20261015

var _items: Array[Dictionary] = []
var _t := 0.0
var _raven_hop := 0.0


func _ready() -> void:
	z_index = -6
	material = DoodleStyle.surface_material(1.0, 0.0)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var kinds := ["grass", "grass", "grass", "grass", "umbel", "umbel", "lilac", "stone", "stone"]
	var tries := 0
	while _items.size() < 60 and tries < 600:
		tries += 1
		var p := Vector2(rng.randf_range(arena.position.x + 10.0, arena.end.x - 10.0), rng.randf_range(arena.position.y + 20.0, arena.end.y - 10.0))
		if keep_clear.has_point(p):
			continue
		_items.append({"kind": kinds[rng.randi() % kinds.size()], "p": p, "s": rng.randf_range(0.8, 1.4), "phase": rng.randf() * TAU})
	_items.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a["p"].y < b["p"].y)


func _process(delta: float) -> void:
	_t += delta
	_raven_hop = maxf(0.0, _raven_hop - delta)
	if randf() < delta * 0.3:
		_raven_hop = 0.25
	queue_redraw()


func _draw() -> void:
	_draw_fence()
	_draw_bone(Vector2(160.0, 660.0))
	_draw_wheel(Vector2(1150.0, 690.0), 58.0)
	for item in _items:
		var p: Vector2 = item["p"]
		var s: float = item["s"]
		var sway := sin(_t * 1.4 + item["phase"]) * 0.08
		match item["kind"]:
			"grass":
				for k in range(5):
					var a := -PI / 2.0 + (k - 2) * 0.28 + sway
					var len := (10.0 + (k % 3) * 5.0) * s
					var c := DoodleStyle.MOSS_DARK if k % 2 == 0 else DoodleStyle.MOSS
					draw_line(p + Vector2((k - 2) * 2.5, 0.0), p + Vector2((k - 2) * 2.5, 0.0) + Vector2(cos(a), sin(a)) * len, c, 2.0)
			"umbel":
				var top := p + Vector2(sway * 20.0, -20.0 * s)
				draw_line(p, top, DoodleStyle.MOSS_DARK, 1.5)
				for k in range(7):
					var a := PI + PI * k / 6.0
					draw_circle(top + Vector2(cos(a) * 6.0, sin(a) * 3.0) * s, 1.8 * s, Color("e9e4d6"))
			"lilac":
				draw_line(p, p + Vector2(0.0, -12.0 * s), DoodleStyle.MOSS_DARK, 1.5)
				draw_circle(p + Vector2(0.0, -13.0 * s), 2.6 * s, Color("a99bc6"))
			"stone":
				var r := Vector2(10.0, 6.0) * s
				DoodleStyle.draw_shadow(self, p + Vector2(0.0, 2.0), r * 1.1)
				DoodleStyle.draw_shape(self, DoodleStyle.ellipse(p, r, 10), DoodleStyle.STONE, 1.5, DoodleStyle.STONE_DARK)
				draw_colored_polygon(DoodleStyle.ellipse(p + Vector2(-1.0, -r.y * 0.5), Vector2(r.x * 0.7, r.y * 0.45), 8), DoodleStyle.MOSS)


## 左端の柵と縄。柱の上にワタリガラス。
func _draw_fence() -> void:
	var posts := [Vector2(40, 330), Vector2(48, 420), Vector2(56, 510), Vector2(64, 600)]
	for i in range(posts.size() - 1):
		var a: Vector2 = posts[i] + Vector2(0, -22)
		var b: Vector2 = posts[i + 1] + Vector2(0, -22)
		var sag := a.lerp(b, 0.5) + Vector2(0, 10)
		draw_polyline(PackedVector2Array([a, sag, b]), Color("8b7a5c"), 1.5)
	for post in posts:
		var p: Vector2 = post
		DoodleStyle.draw_shape(self, PackedVector2Array([p + Vector2(-4, 0), p + Vector2(4, 0), p + Vector2(4, -34), p + Vector2(-4, -36)]), DoodleStyle.WOOD, 1.5)
	var perch: Vector2 = posts[1] + Vector2(0, -36 - (6.0 if _raven_hop > 0.0 else 0.0))
	draw_colored_polygon(DoodleStyle.ellipse(perch + Vector2(0, -7), Vector2(7, 5), 10), Color("1f2228"))
	draw_circle(perch + Vector2(6, -11), 3.5, Color("1f2228"))
	draw_colored_polygon(PackedVector2Array([perch + Vector2(9, -12), perch + Vector2(14, -10), perch + Vector2(9, -9)]), Color("3a3d44"))
	draw_line(perch + Vector2(-6, -6), perch + Vector2(-13, -2), Color("1f2228"), 2.0)


## 半分埋まった巨人の骨。
func _draw_bone(p: Vector2) -> void:
	var pts := PackedVector2Array()
	for k in range(13):
		var t := float(k) / 12.0
		pts.append(p + Vector2(-90.0 + t * 180.0, -sin(t * PI) * 34.0))
	for k in range(12, -1, -1):
		var t := float(k) / 12.0
		pts.append(p + Vector2(-90.0 + t * 180.0, -sin(t * PI) * 22.0 + 4.0))
	DoodleStyle.draw_shape(self, pts, DoodleStyle.BONE, 2.0, DoodleStyle.BONE_SHADE.darkened(0.3))
	for k in range(3, 10, 2):
		var t := float(k) / 12.0
		draw_circle(p + Vector2(-90.0 + t * 180.0, -sin(t * PI) * 32.0), 3.0, DoodleStyle.MOSS)


## 錆びた車輪の残骸（右下、半分画面の外）。
func _draw_wheel(center: Vector2, radius: float) -> void:
	draw_arc(center, radius, PI, TAU, 24, DoodleStyle.RUST.darkened(0.2), 10.0)
	draw_arc(center, radius - 6.0, PI, TAU, 24, DoodleStyle.RUST.lightened(0.1), 2.0)
	for k in range(5):
		var a := PI + PI * (k + 0.5) / 5.0
		draw_line(center, center + Vector2(cos(a), sin(a)) * radius, DoodleStyle.RUST.darkened(0.3), 4.0)
	draw_circle(center, 9.0, DoodleStyle.RUST.darkened(0.4))
