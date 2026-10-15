class_name DoodleStyle
extends RefCounted
## 見た目の決まりごと。色・フォント・質感をここに集め、各所はここを参照する。
## 世界観: 神々の世界が終わったあと、緑によみがえった巨人の骨の大地「はかり野」。
## プレイヤーは「かたち読み」の旅人。記録帳に描いたかたちが、石と骨の獣としてよみがえる。
## 獣の線は金継ぎの継ぎ目のように光る。敵は、かたちを凍らせにくる「霜の獣」。守るのは石碑の上の「金の駒」。
## 参考: docs/moodboard/

const HAND_FONT: FontFile = preload("res://assets/fonts/ZenOldMincho-Black.ttf")
const UI_FONT: FontFile = preload("res://assets/fonts/ZenOldMincho-Bold.ttf")
const SURFACE_SHADER: Shader = preload("res://assets/shaders/surface.gdshader")

# 夕暮れの大地
const NIGHT := Color("1c2130")
const SLATE := Color("3f4a5e")
const SLATE_LIGHT := Color("6a7690")
const FOG := Color("a7aebb")
const BONE := Color("d6cdb6")
const BONE_SHADE := Color("9c947f")
const MOSS_DARK := Color("3a4325")
const MOSS := Color("5d6834")
const MOSS_LIGHT := Color("8a9150")
const STONE := Color("6b6c66")
const STONE_DARK := Color("45463f")
const RUST := Color("8a4f2e")
const BLOOD := Color("7a2f2f")
const WOOD := Color("5a4232")

# 光
const GOLD := Color("d9ad4f")
const GOLD_LIGHT := Color("f3d68a")
const LANTERN := Color("f4b65c")

# 文字と線
const INK := Color("1d1b19")
const INK_SOFT := Color("1d1b19b0")
const SEPIA := Color("3b2a1c")
const CREAM := Color("ece3cc")
const PARCHMENT := Color("e6d9b8")
const SHADOW := Color(0.05, 0.06, 0.08, 0.35)
const PANEL := Color(0.09, 0.1, 0.14, 0.84)

# 霜の獣
const FROST := Color("d6e8f0")
const FROST_DEEP := Color("8db6cc")
const FROST_BODY := Color("4a5672")
const EMBER := Color("c24f4f")
const EMBER_BODY := Color("3a2a33")

# プレイヤー（外套と襟巻きの色）
const P1 := Color("6f9fd8")
const P1_CLOAK := Color("3d4f6e")
const P2 := Color("e0a14a")
const P2_CLOAK := Color("6a5236")
const PLAYER_COLORS := {1: P1, 2: P2}
const PLAYER_CLOAKS := {1: P1_CLOAK, 2: P2_CLOAK}

# 獣の素材
const BEAST_BODY := Color("9fa3a0")
const BEAST_WEAPON := Color("8a7660")
const BEAST_UNDER := Color("4a463c")
const BEAST_RIM := Color("221f1b")
const BEAST_HOLLOW := Color("201d1a")

const HP_GOOD := Color("8fb35a")
const HP_MID := Color("d9ad4f")
const HP_LOW := Color("c0533f")
const ACCENT_RED := Color("c0533f")

static var _glow_material: CanvasItemMaterial


static func surface_material(grain: float = 1.0, moss: float = 0.0, boil: float = 0.0) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = SURFACE_SHADER
	material.set_shader_parameter("grain", grain)
	material.set_shader_parameter("moss", moss)
	material.set_shader_parameter("boil_amount", boil)
	return material


## 光を足し合わせる（加算）マテリアル。ランタンや金の光に使う。
static func glow_material() -> CanvasItemMaterial:
	if _glow_material == null:
		_glow_material = CanvasItemMaterial.new()
		_glow_material.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	return _glow_material


static func hp_color(ratio: float) -> Color:
	if ratio > 0.5:
		return HP_MID.lerp(HP_GOOD, (ratio - 0.5) * 2.0)
	return HP_LOW.lerp(HP_MID, ratio * 2.0)


## 文字。縁取りをつけて、どんな背景でも読めるようにする。
static func draw_text(canvas: CanvasItem, font: Font, pos: Vector2, text: String, size: int,
		color: Color, align: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT, width: float = -1.0,
		outline: int = 0, outline_color: Color = NIGHT) -> void:
	if outline > 0:
		canvas.draw_string_outline(font, pos, text, align, width, size, outline, outline_color)
	canvas.draw_string(font, pos, text, align, width, size, color)


## 楕円の点列。
static func ellipse(center: Vector2, radii: Vector2, points: int = 24) -> PackedVector2Array:
	var result := PackedVector2Array()
	for i in range(points):
		var t := TAU * i / points
		result.append(center + Vector2(cos(t) * radii.x, sin(t) * radii.y))
	return result


## 角の丸い四角の点列。
static func rounded_rect(rect: Rect2, radius: float, segments: int = 4) -> PackedVector2Array:
	var r := minf(radius, minf(rect.size.x, rect.size.y) * 0.5)
	var result := PackedVector2Array()
	var corners := [
		[rect.position + Vector2(rect.size.x - r, r), -PI / 2.0],
		[rect.position + Vector2(rect.size.x - r, rect.size.y - r), 0.0],
		[rect.position + Vector2(r, rect.size.y - r), PI / 2.0],
		[rect.position + Vector2(r, r), PI],
	]
	for corner in corners:
		for i in range(segments + 1):
			var t: float = corner[1] + (PI / 2.0) * i / segments
			result.append(corner[0] + Vector2(cos(t), sin(t)) * r)
	return result


## 塗り + 輪郭線。
static func draw_shape(canvas: CanvasItem, points: PackedVector2Array, fill: Color, line_width: float = 2.0,
		line_color: Color = INK) -> void:
	canvas.draw_colored_polygon(points, fill)
	if line_width > 0.0:
		var closed := points.duplicate()
		closed.append(points[0])
		canvas.draw_polyline(closed, line_color, line_width, true)


## 地面の影。
static func draw_shadow(canvas: CanvasItem, center: Vector2, radii: Vector2) -> void:
	canvas.draw_colored_polygon(ellipse(center, radii, 20), SHADOW)


## やわらかい光の輪。加算マテリアルのノードで呼ぶと光って見える。
static func draw_glow(canvas: CanvasItem, center: Vector2, radius: float, color: Color, strength: float = 1.0, rings: int = 7) -> void:
	for i in range(rings):
		var k := 1.0 - float(i) / rings
		canvas.draw_circle(center, radius * k, Color(color, strength * 0.05 * (1.0 + i * 0.2)))


## HP などのバー。暗い溝に色を入れ、金の縁で囲む。
static func draw_bar(canvas: CanvasItem, rect: Rect2, ratio: float, fill: Color = Color.TRANSPARENT) -> void:
	var color := fill if fill.a > 0.0 else hp_color(ratio)
	canvas.draw_rect(rect, Color(NIGHT, 0.85))
	if ratio > 0.0:
		var inner := Rect2(rect.position + Vector2(1.0, 1.0), Vector2((rect.size.x - 2.0) * clampf(ratio, 0.0, 1.0), rect.size.y - 2.0))
		canvas.draw_rect(inner, color)
		canvas.draw_rect(Rect2(inner.position, Vector2(inner.size.x, maxf(1.0, inner.size.y * 0.35))), Color(1, 1, 1, 0.18))
	canvas.draw_rect(rect, Color(GOLD, 0.8), false, 1.0)


## 情報用の板。暗い地に金の細い縁と、四隅の菱形の飾り（組紐の代わり）。
static func draw_panel(canvas: CanvasItem, rect: Rect2, alpha: float = 1.0) -> void:
	canvas.draw_rect(Rect2(rect.position + Vector2(3.0, 4.0), rect.size), Color(0, 0, 0, 0.35 * alpha))
	canvas.draw_rect(rect, Color(PANEL, PANEL.a * alpha))
	canvas.draw_rect(rect.grow(-3.0), Color(GOLD, 0.55 * alpha), false, 1.0)
	for corner in [rect.position, Vector2(rect.end.x, rect.position.y), rect.end, Vector2(rect.position.x, rect.end.y)]:
		var c: Vector2 = corner
		canvas.draw_colored_polygon(PackedVector2Array([c + Vector2(0, -5), c + Vector2(5, 0), c + Vector2(0, 5), c + Vector2(-5, 0)]), Color(GOLD, alpha))


## 金の駒（正二十面体を正面から見た形）。
static func draw_d20(canvas: CanvasItem, center: Vector2, radius: float, color: Color = GOLD, line: Color = Color("6b4f1d")) -> void:
	var outer := PackedVector2Array()
	for i in range(6):
		var a := -PI / 2.0 + TAU * i / 6.0
		outer.append(center + Vector2(cos(a), sin(a)) * radius)
	canvas.draw_colored_polygon(outer, color)
	var inner := PackedVector2Array()
	for i in range(3):
		var a := -PI / 2.0 + TAU * i / 3.0 + PI / 3.0
		inner.append(center + Vector2(cos(a), sin(a)) * radius * 0.55)
	canvas.draw_colored_polygon(PackedVector2Array([inner[0], inner[1], inner[2]]), color.lightened(0.25))
	var closed := outer.duplicate()
	closed.append(outer[0])
	canvas.draw_polyline(closed, line, 1.5, true)
	var tri := inner.duplicate()
	tri.append(inner[0])
	canvas.draw_polyline(tri, line, 1.2, true)
	for i in range(6):
		canvas.draw_line(outer[i], inner[(i / 2 + (1 if i % 2 == 1 else 0)) % 3], line, 1.0, true)
