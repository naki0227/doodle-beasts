class_name Backdrop
extends Node2D
## はかり野の遠景。地平線（horizon_y）より上に描く。
## 奥から順に: 山並み → 世界樹 → 湖 → 針葉樹 → 巨人の肋骨 → 大測輪の残骸 → 石碑 → 飛ぶワタリガラス。
## 奥ほど霧の色に寄せて（空気遠近法）、手前ほど暗く濃くする。決まった種から毎回同じ景色を描く。

@export var horizon_y: float = 236.0
@export var width: float = 1280.0
@export var tree_x: float = 1000.0
@export var seed_value: int = 9001
## 遠景全体の縦の縮尺。タイトル画面では大きく見せる。
@export var height_scale: float = 1.0

var _t := 0.0
var _mountains: Array[PackedVector2Array] = []
var _pines: Array[Vector3] = []
var _ravens: Array[Dictionary] = []


func _ready() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	for layer in range(2):
		var ridge := PackedVector2Array()
		ridge.append(Vector2(-60.0, horizon_y))
		var x := -60.0
		while x < width + 60.0:
			var peak := horizon_y - (34.0 + 26.0 * layer + rng.randf_range(0.0, 46.0 - layer * 20.0)) * height_scale
			ridge.append(Vector2(x, peak))
			x += rng.randf_range(40.0, 90.0)
		ridge.append(Vector2(width + 60.0, horizon_y))
		_mountains.append(ridge)
	for i in range(70):
		var px := rng.randf_range(-20.0, width + 20.0)
		if absf(px - 820.0) < 140.0 and rng.randf() < 0.7:
			continue
		_pines.append(Vector3(px, horizon_y + rng.randf_range(-6.0, 8.0), rng.randf_range(0.6, 1.3)))
	for i in range(3):
		_ravens.append({"x": rng.randf_range(0.0, width), "y": rng.randf_range(40.0, horizon_y - 80.0), "speed": rng.randf_range(28.0, 46.0), "phase": rng.randf() * TAU})


func _process(delta: float) -> void:
	_t += delta
	for raven in _ravens:
		raven["x"] += raven["speed"] * delta
		if raven["x"] > width + 40.0:
			raven["x"] = -40.0
	queue_redraw()


func _draw() -> void:
	var far := DoodleStyle.SLATE_LIGHT.lerp(DoodleStyle.FOG, 0.45)
	var near := DoodleStyle.SLATE.lerp(DoodleStyle.FOG, 0.15)
	draw_colored_polygon(_mountains[0], far)
	_draw_world_tree(Vector2(tree_x, horizon_y - 6.0))
	draw_colored_polygon(_mountains[1], near)
	_draw_lake()
	for pine in _pines:
		_draw_pine(Vector2(pine.x, pine.y), pine.z)
	_draw_ribs()
	_draw_ring(Vector2(1150.0, horizon_y + 4.0), 46.0 * height_scale)
	_draw_runestone(Vector2(90.0, horizon_y + 6.0), Vector2(16.0, 52.0) * height_scale)
	_draw_runestone(Vector2(700.0, horizon_y + 4.0), Vector2(10.0, 30.0) * height_scale)
	for raven in _ravens:
		_draw_raven(Vector2(raven["x"], raven["y"] + sin(_t * 0.8 + raven["phase"]) * 6.0), _t * 9.0 + raven["phase"])


func _draw_world_tree(base: Vector2) -> void:
	var h := 150.0 * height_scale
	var color := Color("2c3243").lerp(DoodleStyle.FOG, 0.18)
	var rim := Color("4a536b").lerp(DoodleStyle.FOG, 0.25)
	var crown := base + Vector2(0.0, -h * 0.86)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value + 3
	# 枝葉: 横に広い傘のかたまり。上の縁だけ少し明るくする。
	var blobs: Array[Vector3] = []
	for i in range(34):
		var a := rng.randf_range(PI * 1.0, PI * 2.0)
		var r := sqrt(rng.randf())
		var c := crown + Vector2(cos(a) * 150.0 * r, sin(a) * 52.0 * r + 10.0) * height_scale
		blobs.append(Vector3(c.x, c.y, rng.randf_range(26.0, 46.0) * height_scale))
	for b in blobs:
		draw_colored_polygon(DoodleStyle.ellipse(Vector2(b.x, b.y - 3.0), Vector2(b.z, b.z * 0.5), 16), rim)
	for b in blobs:
		draw_colored_polygon(DoodleStyle.ellipse(Vector2(b.x, b.y), Vector2(b.z, b.z * 0.5), 16), color)
	# 幹と根
	var trunk := PackedVector2Array([
		base + Vector2(-70, 4), base + Vector2(-30, -8), base + Vector2(-18, -h * 0.5), base + Vector2(-26, -h * 0.82),
		base + Vector2(26, -h * 0.82), base + Vector2(18, -h * 0.5), base + Vector2(32, -8), base + Vector2(74, 4)])
	for i in range(trunk.size()):
		trunk[i] = base + (trunk[i] - base) * Vector2(height_scale * 0.8, 1.0)
	draw_colored_polygon(trunk, color)
	# 幹を走るかすかな金の線
	draw_line(base + Vector2(0, -6), base + Vector2(0, -h * 0.78), Color(DoodleStyle.GOLD_LIGHT, 0.3 + 0.1 * sin(_t)), 2.0)


func _draw_lake() -> void:
	var top := horizon_y - 2.0
	var lake := PackedVector2Array([Vector2(560, top), Vector2(width + 40, top), Vector2(width + 40, top + 18), Vector2(540, top + 18)])
	draw_colored_polygon(lake, DoodleStyle.FOG.lerp(DoodleStyle.SLATE_LIGHT, 0.3))
	for i in range(8):
		var y := top + 3.0 + i * 2.0
		var x0 := 600.0 + fmod(i * 97.0 + _t * 10.0, 500.0)
		draw_line(Vector2(x0, y), Vector2(x0 + 30.0 + i * 3.0, y), Color(DoodleStyle.CREAM, 0.25), 1.0)


func _draw_pine(base: Vector2, s: float) -> void:
	var color := Color("2f3a33").lerp(DoodleStyle.FOG, 0.25)
	for k in range(3):
		var y := base.y - k * 7.0 * s
		var w := (9.0 - k * 2.5) * s
		draw_colored_polygon(PackedVector2Array([Vector2(base.x - w, y), Vector2(base.x + w, y), Vector2(base.x, y - 13.0 * s)]), color)


## 巨人の肋骨。手前（左）ほど大きく、奥（右）ほど小さく霧に溶ける。背骨の線から生えて弧を描く。
func _draw_ribs() -> void:
	var count := 7
	var spine := PackedVector2Array()
	for i in range(count):
		var depth := float(i) / (count - 1)
		var scale_k := lerpf(1.0, 0.45, depth) * height_scale
		var x0 := lerpf(120.0, 520.0, pow(depth, 0.8))
		var foot_a := Vector2(x0, horizon_y + 4.0 - depth * 4.0)
		spine.append(foot_a + Vector2(-4.0, 2.0))
		var ctrl := foot_a + Vector2(60.0, -230.0) * scale_k
		var foot_b := foot_a + Vector2(150.0, -6.0) * scale_k
		var bone := DoodleStyle.BONE.darkened(0.22).lerp(DoodleStyle.SLATE_LIGHT, 0.4 + depth * 0.35)
		var shade := DoodleStyle.BONE_SHADE.darkened(0.35).lerp(DoodleStyle.SLATE, 0.35 + depth * 0.35)
		var outer := PackedVector2Array()
		var inner := PackedVector2Array()
		var steps := 26
		for k in range(steps + 1):
			var t := float(k) / steps
			var p := foot_a.lerp(ctrl, t).lerp(ctrl.lerp(foot_b, t), t)
			var tangent := (ctrl - foot_a).lerp(foot_b - ctrl, t).normalized()
			var normal := Vector2(-tangent.y, tangent.x)
			var thick := (10.0 - 5.0 * absf(t - 0.3)) * scale_k
			outer.append(p - normal * thick)
			inner.append(p + normal * thick)
		var shade_band := inner.duplicate()
		var mid := PackedVector2Array()
		for k in range(steps + 1):
			mid.append(outer[k].lerp(inner[k], 0.55))
		mid.reverse()
		shade_band.append_array(mid)
		inner.reverse()
		var band := outer.duplicate()
		band.append_array(inner)
		draw_colored_polygon(band, bone)
		draw_colored_polygon(shade_band, shade)
		for k in range(3, steps - 8, 5):
			draw_circle(outer[k], 3.5 * scale_k, Color(DoodleStyle.MOSS, 0.6 - depth * 0.3))
	draw_polyline(spine, DoodleStyle.BONE_SHADE.lerp(DoodleStyle.FOG, 0.45), 6.0 * height_scale)


## 大測輪の残骸。地面に半分沈んだ錆びた鉄の輪。
func _draw_ring(center: Vector2, radius: float) -> void:
	var rust := DoodleStyle.RUST.lerp(DoodleStyle.FOG, 0.25)
	draw_arc(center, radius, PI * 1.02, PI * 2.12, 28, rust, 9.0 * height_scale)
	draw_arc(center, radius - 5.0 * height_scale, PI * 1.05, PI * 2.1, 28, rust.darkened(0.35), 2.0 * height_scale)
	for k in range(6):
		var a := PI * 1.1 + k * 0.18
		draw_circle(center + Vector2(cos(a), sin(a)) * radius, 1.6 * height_scale, rust.lightened(0.3))


func _draw_runestone(base: Vector2, size: Vector2) -> void:
	var stone := DoodleStyle.STONE_DARK.lerp(DoodleStyle.FOG, 0.2)
	draw_colored_polygon(PackedVector2Array([
		base + Vector2(-size.x, 0), base + Vector2(size.x, 0), base + Vector2(size.x * 0.8, -size.y), base + Vector2(-size.x * 0.6, -size.y * 1.05)]), stone)
	var glow := Color(DoodleStyle.GOLD, 0.55 + 0.2 * sin(_t * 1.5))
	draw_line(base + Vector2(0, -size.y * 0.85), base + Vector2(0, -size.y * 0.2), glow, 1.5)
	draw_line(base + Vector2(-size.x * 0.45, -size.y * 0.7), base + Vector2(size.x * 0.45, -size.y * 0.45), glow, 1.5)


func _draw_raven(p: Vector2, flap: float) -> void:
	var wing := sin(flap) * 5.0
	var color := Color("23262d")
	draw_line(p, p + Vector2(-8.0, -wing), color, 2.0)
	draw_line(p, p + Vector2(8.0, -wing), color, 2.0)
	draw_circle(p, 1.8, color)
