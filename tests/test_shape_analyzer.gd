extends GameTestCase
## 形の解析が、意図した絵を意図したとおりに読むかを確かめる。

const W := ShapeAnalyzer.Weapon


func _circle(center: Vector2, radius: float, points: int = 48) -> PackedVector2Array:
	var stroke := PackedVector2Array()
	for i in range(points + 1):
		stroke.append(center + Vector2.RIGHT.rotated(TAU * i / points) * radius)
	return stroke


func _square(origin: Vector2, size: float) -> PackedVector2Array:
	return PackedVector2Array([
		origin, origin + Vector2(size, 0), origin + Vector2(size, size), origin + Vector2(0, size), origin])


func _line(a: Vector2, b: Vector2, points: int = 20) -> PackedVector2Array:
	var stroke := PackedVector2Array()
	for i in range(points + 1):
		stroke.append(a.lerp(b, float(i) / points))
	return stroke


func _zigzag(origin: Vector2, teeth: int, width: float, height: float) -> PackedVector2Array:
	var stroke := PackedVector2Array()
	for i in range(teeth * 2 + 1):
		stroke.append(origin + Vector2(width * i / 2.0, height if i % 2 == 1 else 0.0))
	return stroke


func test_length_and_bounds() -> void:
	var strokes: Array[PackedVector2Array] = [_line(Vector2(0, 0), Vector2(100, 0))]
	assert_true(is_equal_approx(StrokeTools.total_length(strokes), 100.0))
	var rect := StrokeTools.bounds(strokes)
	assert_eq(rect.position, Vector2(0, 0))
	assert_eq(rect.size, Vector2(100, 0))
	assert_eq(StrokeTools.bounds([] as Array[PackedVector2Array]), Rect2())


func test_closed_detection() -> void:
	assert_true(StrokeTools.is_closed(_circle(Vector2(100, 100), 60)))
	assert_false(StrokeTools.is_closed(_line(Vector2(0, 0), Vector2(200, 0))))
	assert_false(StrokeTools.is_closed(_circle(Vector2(0, 0), 4)), "小さすぎる輪は閉じているとみなさない")


func test_simplify_keeps_corners_of_square() -> void:
	var dense := PackedVector2Array()
	for i in range(0, 101):
		dense.append(Vector2(i, 0))
	for i in range(1, 101):
		dense.append(Vector2(100, i))
	var simple := StrokeTools.simplify(dense, 2.0)
	assert_eq(simple.size(), 3, "直線上の点は消え、角だけ残る")
	assert_eq(simple[1], Vector2(100, 0))


func test_corner_count_square_vs_circle() -> void:
	assert_eq(StrokeTools.corner_count(_square(Vector2(0, 0), 100)), 4)
	assert_eq(StrokeTools.corner_count(_circle(Vector2(0, 0), 60)), 0)
	assert_true(StrokeTools.corner_count(_zigzag(Vector2(0, 0), 6, 20, 30)) >= 10)


func test_symmetry_of_mirrored_shape() -> void:
	var symmetric: Array[PackedVector2Array] = [_circle(Vector2(200, 200), 100)]
	var lopsided: Array[PackedVector2Array] = [
		_line(Vector2(0, 0), Vector2(300, 0)), _line(Vector2(0, 0), Vector2(0, 300)), _line(Vector2(0, 0), Vector2(60, 200))]
	assert_true(StrokeTools.horizontal_symmetry(symmetric) > 0.85, "円はほぼ対称")
	assert_true(StrokeTools.horizontal_symmetry(lopsided) < 0.5, "片寄った形は非対称")


func test_thicken_produces_polygon() -> void:
	var polygons := StrokeTools.thicken(_line(Vector2(0, 0), Vector2(100, 0)), 3.0)
	assert_true(polygons.size() >= 1)
	assert_true(polygons[0].size() >= 4)


func test_body_empty_is_default() -> void:
	var info := ShapeAnalyzer.analyze_body([] as Array[PackedVector2Array], 3000.0)
	assert_eq(info["trait"], "まだ何も描いていない")
	assert_eq(info["total_points"], 0.0)


func test_body_points_never_exceed_cap() -> void:
	var huge: Array[PackedVector2Array] = []
	for i in range(30):
		huge.append(_circle(Vector2(250, 250), 200 - i * 3))
	var info := ShapeAnalyzer.analyze_body(huge, 3000.0)
	assert_true(StrokeTools.total_length(huge) > 3000.0, "予算を超えるインク")
	assert_true(is_equal_approx(info["total_points"], ShapeAnalyzer.STAT_POINTS), "総量は上限で止まる")
	var sum := 0.0
	for key in info["points"]:
		sum += info["points"][key]
	assert_true(is_equal_approx(sum, info["total_points"]), "配分の合計は総量に等しい")


func test_spiky_body_leans_attack() -> void:
	var spiky: Array[PackedVector2Array] = [_zigzag(Vector2(0, 100), 14, 20, 60)]
	var round_body: Array[PackedVector2Array] = [_circle(Vector2(200, 200), 120)]
	var a := ShapeAnalyzer.analyze_body(spiky, 3000.0)
	var b := ShapeAnalyzer.analyze_body(round_body, 3000.0)
	assert_true(a["spiky"] > b["spiky"])
	assert_eq(a["trait"], "トゲトゲ → 攻撃型")


func test_wide_body_leans_speed() -> void:
	var wide: Array[PackedVector2Array] = [_line(Vector2(0, 100), Vector2(400, 100)), _line(Vector2(0, 130), Vector2(400, 130))]
	var info := ShapeAnalyzer.analyze_body(wide, 3000.0)
	assert_true(info["wide"] > 0.9)
	assert_eq(info["trait"], "横長 → 俊足型")


func test_symmetric_closed_body_leans_defense() -> void:
	var shape: Array[PackedVector2Array] = [_circle(Vector2(200, 200), 150)]
	var info := ShapeAnalyzer.analyze_body(shape, 3000.0)
	assert_eq(info["trait"], "まとまり → 守り型")
	assert_true(info["defense"] > 0.1)


func test_same_strokes_same_result() -> void:
	var shape: Array[PackedVector2Array] = [_zigzag(Vector2(0, 0), 5, 30, 40), _circle(Vector2(100, 100), 50)]
	var a := ShapeAnalyzer.analyze_body(shape, 3000.0)
	var b := ShapeAnalyzer.analyze_body(shape.duplicate(true), 3000.0)
	assert_eq(a["hp"], b["hp"])
	assert_eq(a["attack"], b["attack"])
	assert_eq(a["trait"], b["trait"])


func test_weapon_none_when_empty() -> void:
	assert_eq(ShapeAnalyzer.classify_weapon([] as Array[PackedVector2Array]), W.NONE)


func test_weapon_long_line_is_spear() -> void:
	var strokes: Array[PackedVector2Array] = [_line(Vector2(0, 100), Vector2(400, 110))]
	assert_eq(ShapeAnalyzer.classify_weapon(strokes), W.SPEAR)


func test_weapon_medium_blade_is_sword() -> void:
	var strokes: Array[PackedVector2Array] = [
		_line(Vector2(0, 100), Vector2(300, 100)), _line(Vector2(0, 100), Vector2(300, 200)), _line(Vector2(300, 100), Vector2(300, 200))]
	assert_eq(ShapeAnalyzer.classify_weapon(strokes), W.SWORD)


func test_weapon_line_with_blob_is_hammer() -> void:
	var strokes: Array[PackedVector2Array] = [_line(Vector2(0, 100), Vector2(300, 100))]
	for i in range(6):
		strokes.append(_circle(Vector2(320, 100), 20 + i * 5))
	assert_eq(ShapeAnalyzer.classify_weapon(strokes), W.HAMMER)


func test_weapon_handle_with_boxy_head_is_hammer() -> void:
	# デモで描く形。外接矩形はあまり細長くないが、片端に頭がある。
	var strokes: Array[PackedVector2Array] = [
		_line(Vector2(60, 300), Vector2(330, 240)), _line(Vector2(60, 312), Vector2(330, 252)),
		PackedVector2Array([Vector2(320, 160), Vector2(460, 130), Vector2(480, 330), Vector2(340, 360), Vector2(320, 160)]),
		_circle(Vector2(400, 245), 50, 20)]
	assert_eq(ShapeAnalyzer.classify_weapon(strokes), W.HAMMER)


func test_weapon_many_short_strokes_are_claws() -> void:
	var strokes: Array[PackedVector2Array] = []
	for i in range(5):
		strokes.append(_line(Vector2(i * 30, 0), Vector2(i * 30 + 10, 60)))
	assert_eq(ShapeAnalyzer.classify_weapon(strokes), W.CLAWS)


func test_weapon_big_closed_shape_is_shield() -> void:
	var strokes: Array[PackedVector2Array] = [_circle(Vector2(200, 200), 120)]
	assert_eq(ShapeAnalyzer.classify_weapon(strokes), W.SHIELD)


func test_weapon_arc_with_string_is_bow() -> void:
	var arc := PackedVector2Array()
	for i in range(41):
		var t := -PI / 2.0 + PI * i / 40.0
		arc.append(Vector2(100, 200) + Vector2(cos(t), sin(t)) * 150.0)
	var strokes: Array[PackedVector2Array] = [arc, _line(arc[0], arc[arc.size() - 1])]
	assert_eq(ShapeAnalyzer.classify_weapon(strokes), W.BOW)


func test_weapon_scribble_is_unknown() -> void:
	var strokes: Array[PackedVector2Array] = [_zigzag(Vector2(0, 0), 2, 60, 100)]
	assert_eq(ShapeAnalyzer.classify_weapon(strokes), W.UNKNOWN)


func test_every_weapon_has_label_and_profile() -> void:
	for kind in W.values():
		assert_true(ShapeAnalyzer.weapon_label(kind) != "")
		assert_true(ShapeAnalyzer.weapon_profile(kind).has("range"))
