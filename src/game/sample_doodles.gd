class_name SampleDoodles
extends RefCounted
## 見本の絵。タイトル画面のマスコットと、デモの自動再生で使う。
## パネルのローカル座標（470 x 440 のページ）に収まるよう、FIT 倍して返す。

const FIT := 0.92


static func _fit(strokes: Array[PackedVector2Array]) -> Array[PackedVector2Array]:
	return StrokeTools.transformed(strokes, Vector2.ZERO, FIT)


static func _ellipse(center: Vector2, radii: Vector2, points: int = 36, start_angle: float = 0.0) -> PackedVector2Array:
	var stroke := PackedVector2Array()
	for i in range(points + 1):
		var t := start_angle + TAU * i / points
		stroke.append(center + Vector2(cos(t) * radii.x, sin(t) * radii.y))
	return stroke


## からだ: 丸い胴体、背中のトゲ、目、口、短い脚。
static func body() -> Array[PackedVector2Array]:
	var result: Array[PackedVector2Array] = []
	result.append(_ellipse(Vector2(240, 290), Vector2(160, 115), 40, PI))
	var spikes := PackedVector2Array()
	for i in range(7):
		var x := 108.0 + i * 40.0
		spikes.append(Vector2(x, 200.0))
		spikes.append(Vector2(x + 20.0, 140.0 + (i % 2) * 14.0))
	spikes.append(Vector2(388, 200))
	result.append(spikes)
	result.append(_ellipse(Vector2(185, 275), Vector2(22, 22), 16))
	result.append(_ellipse(Vector2(295, 275), Vector2(22, 22), 16))
	result.append(PackedVector2Array([Vector2(190, 278), Vector2(196, 284)]))
	result.append(PackedVector2Array([Vector2(300, 278), Vector2(306, 284)]))
	result.append(PackedVector2Array([Vector2(205, 340), Vector2(240, 360), Vector2(275, 340)]))
	result.append(PackedVector2Array([Vector2(170, 398), Vector2(165, 446), Vector2(195, 446)]))
	result.append(PackedVector2Array([Vector2(310, 398), Vector2(315, 446), Vector2(345, 446)]))
	return _fit(result)


## ぶき: 長い柄の先に重い頭（ハンマー）。
static func weapon() -> Array[PackedVector2Array]:
	var result: Array[PackedVector2Array] = []
	result.append(PackedVector2Array([Vector2(50, 300), Vector2(300, 244)]))
	result.append(PackedVector2Array([Vector2(50, 312), Vector2(300, 256)]))
	result.append(PackedVector2Array([
		Vector2(296, 170), Vector2(424, 142), Vector2(440, 326), Vector2(312, 352), Vector2(296, 170)]))
	result.append(_ellipse(Vector2(368, 248), Vector2(46, 64), 20))
	result.append(_ellipse(Vector2(368, 248), Vector2(26, 40), 16))
	return _fit(result)
