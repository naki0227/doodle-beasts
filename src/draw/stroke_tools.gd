class_name StrokeTools
extends RefCounted
## 線（点の列）に対する純粋な計算。描画・解析・立体化はすべてここを通る。
## 線のデータ型は PackedVector2Array、複数の線は Array[PackedVector2Array]。


static func length(stroke: PackedVector2Array) -> float:
	var total := 0.0
	for i in range(1, stroke.size()):
		total += stroke[i - 1].distance_to(stroke[i])
	return total


static func total_length(strokes: Array[PackedVector2Array]) -> float:
	var total := 0.0
	for stroke in strokes:
		total += length(stroke)
	return total


## 全部の線を含む矩形。線がなければ Rect2()。
static func bounds(strokes: Array[PackedVector2Array]) -> Rect2:
	var rect := Rect2()
	var started := false
	for stroke in strokes:
		for point in stroke:
			if not started:
				rect = Rect2(point, Vector2.ZERO)
				started = true
			else:
				rect = rect.expand(point)
	return rect


static func all_points(strokes: Array[PackedVector2Array]) -> PackedVector2Array:
	var points := PackedVector2Array()
	for stroke in strokes:
		points.append_array(stroke)
	return points


## 始点と終点が近い線を「閉じている」とみなす。
static func is_closed(stroke: PackedVector2Array) -> bool:
	if stroke.size() < 4:
		return false
	var len := length(stroke)
	if len < 40.0:
		return false
	var gap := stroke[0].distance_to(stroke[stroke.size() - 1])
	return gap < maxf(20.0, len * 0.12)


## 始点から終点への直線距離 ÷ 線の長さ。1 に近いほど真っ直ぐ、0 に近いほど戻ってきている。
static func chord_ratio(stroke: PackedVector2Array) -> float:
	var len := length(stroke)
	if len <= 0.0 or stroke.size() < 2:
		return 1.0
	return stroke[0].distance_to(stroke[stroke.size() - 1]) / len


## Ramer-Douglas-Peucker で点を間引く。角の数を数える前に使う。
static func simplify(stroke: PackedVector2Array, epsilon: float) -> PackedVector2Array:
	if stroke.size() < 3:
		return stroke.duplicate()
	var keep := PackedByteArray()
	keep.resize(stroke.size())
	keep.fill(0)
	keep[0] = 1
	keep[stroke.size() - 1] = 1
	var stack: Array[Vector2i] = [Vector2i(0, stroke.size() - 1)]
	while not stack.is_empty():
		var segment: Vector2i = stack.pop_back()
		var a := stroke[segment.x]
		var b := stroke[segment.y]
		var farthest := -1
		var farthest_distance := 0.0
		for i in range(segment.x + 1, segment.y):
			var closest := Geometry2D.get_closest_point_to_segment(stroke[i], a, b)
			var distance := stroke[i].distance_to(closest)
			if distance > farthest_distance:
				farthest_distance = distance
				farthest = i
		if farthest != -1 and farthest_distance > epsilon:
			keep[farthest] = 1
			stack.append(Vector2i(segment.x, farthest))
			stack.append(Vector2i(farthest, segment.y))
	var result := PackedVector2Array()
	for i in stroke.size():
		if keep[i] == 1:
			result.append(stroke[i])
	return result


## 曲がり角の数。min_angle_deg 以上向きが変わる点を数える。
static func corner_count(stroke: PackedVector2Array, min_angle_deg: float = 60.0, epsilon: float = 4.0) -> int:
	var simple := simplify(stroke, epsilon)
	var closed := is_closed(stroke)
	if simple.size() < 3:
		return 0
	var count := 0
	var last := simple.size() - 1
	for i in range(1, last):
		if _turn_angle_deg(simple[i - 1], simple[i], simple[i + 1]) >= min_angle_deg:
			count += 1
	if closed:
		# 始点と終点が同じ場所なので、そこも角として見る。
		if _turn_angle_deg(simple[last - 1], simple[0], simple[1]) >= min_angle_deg:
			count += 1
	return count


static func _turn_angle_deg(a: Vector2, b: Vector2, c: Vector2) -> float:
	var v1 := b - a
	var v2 := c - b
	if v1.length() < 1.0 or v2.length() < 1.0:
		return 0.0
	return absf(rad_to_deg(v1.angle_to(v2)))


## 線に沿って step ごとに点を打つ。密度の計算に使う。
static func sample(strokes: Array[PackedVector2Array], step: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	for stroke in strokes:
		if stroke.size() == 1:
			points.append(stroke[0])
		for i in range(1, stroke.size()):
			var a := stroke[i - 1]
			var b := stroke[i]
			var segment_length := a.distance_to(b)
			var steps := maxi(1, int(ceil(segment_length / step)))
			for k in range(steps):
				points.append(a.lerp(b, float(k) / steps))
		if stroke.size() >= 2:
			points.append(stroke[stroke.size() - 1])
	return points


## 左右対称の度合い（0〜1）。粗い格子に落として、鏡写しの相手がいる升目の割合。
static func horizontal_symmetry(strokes: Array[PackedVector2Array], cells: int = 24) -> float:
	var rect := bounds(strokes)
	if rect.size.x < 1.0 or rect.size.y < 1.0:
		return 0.0
	var occupied := {}
	var step := maxf(2.0, maxf(rect.size.x, rect.size.y) / cells / 2.0)
	for point in sample(strokes, step):
		var cell := Vector2i(
			clampi(int((point.x - rect.position.x) / rect.size.x * cells), 0, cells - 1),
			clampi(int((point.y - rect.position.y) / rect.size.y * cells), 0, cells - 1))
		occupied[cell] = true
	if occupied.is_empty():
		return 0.0
	var mirrored := 0
	for cell in occupied:
		var mirror := Vector2i(cells - 1 - cell.x, cell.y)
		if occupied.has(mirror):
			mirrored += 1
	return float(mirrored) / occupied.size()


## 平行移動と拡大縮小をまとめて適用した複製。
static func transformed(strokes: Array[PackedVector2Array], offset: Vector2, scale: float) -> Array[PackedVector2Array]:
	var result: Array[PackedVector2Array] = []
	for stroke in strokes:
		var moved := PackedVector2Array()
		moved.resize(stroke.size())
		for i in stroke.size():
			moved[i] = (stroke[i] + offset) * scale
		result.append(moved)
	return result


## 線を太らせた多角形にする。立体化と当たり判定の元になる。
static func thicken(stroke: PackedVector2Array, width: float) -> Array[PackedVector2Array]:
	if stroke.size() == 1:
		var circle := PackedVector2Array()
		for i in range(12):
			circle.append(stroke[0] + Vector2.RIGHT.rotated(TAU * i / 12.0) * width)
		return [circle]
	var polygons := Geometry2D.offset_polyline(stroke, width, Geometry2D.JOIN_ROUND, Geometry2D.END_ROUND)
	var result: Array[PackedVector2Array] = []
	for polygon in polygons:
		if not Geometry2D.is_polygon_clockwise(polygon):
			result.append(polygon)
	return result
