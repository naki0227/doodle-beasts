class_name DoodleStyle
extends RefCounted
## 見た目の決まりごと。色・フォント・質感をここに集め、各所はここを参照する。
## 世界観: ノートの上で、鉛筆たち（プレイヤー）とみんなで描いた生き物が、
## らくがきを消しにくる消しゴム軍団からお城の絵を守る。

const HAND_FONT: FontFile = preload("res://assets/fonts/YuseiMagic-Regular.ttf")
const UI_FONT: FontFile = preload("res://assets/fonts/ZenMaruGothic-Bold.ttf")
const DOODLE_SHADER: Shader = preload("res://assets/shaders/doodle.gdshader")

const INK := Color("2b2d42")
const INK_SOFT := Color("2b2d42b0")
const PAPER := Color("fbf6ea")
const PAPER_SHADE := Color("e9e1cf")
const SHADOW := Color(0.17, 0.13, 0.1, 0.22)

const P1 := Color("38b26a")
const P1_LIGHT := Color("a9e8bd")
const P2 := Color("f0a92e")
const P2_LIGHT := Color("ffe19a")
const PLAYER_COLORS := {1: P1, 2: P2}
const PLAYER_LIGHT := {1: P1_LIGHT, 2: P2_LIGHT}

const ERASER_PINK := Color("f5a3b3")
const ERASER_GREY := Color("c9c3d6")
const SLEEVE := Color("4fb3c8")
const SLEEVE_HARD := Color("7d6bc4")

const CASTLE_WALL := Color("f3dfbd")
const CASTLE_ROOF := Color("e4644b")
const CASTLE_FLAG := Color("3e8ed0")

const HP_GOOD := Color("5cc46f")
const HP_MID := Color("f2c14e")
const HP_LOW := Color("e5533d")
const ACCENT_RED := Color("e0433a")


static func doodle_material(boil: float = 1.2, crayon: float = 1.0) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = DOODLE_SHADER
	material.set_shader_parameter("boil_amount", boil)
	material.set_shader_parameter("crayon", crayon)
	return material


static func hp_color(ratio: float) -> Color:
	if ratio > 0.5:
		return HP_MID.lerp(HP_GOOD, (ratio - 0.5) * 2.0)
	return HP_LOW.lerp(HP_MID, ratio * 2.0)


## 手描き風の文字。縁取りをつけて、どんな背景でも読めるようにする。
static func draw_text(canvas: CanvasItem, font: Font, pos: Vector2, text: String, size: int,
		color: Color, align: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT, width: float = -1.0,
		outline: int = 0, outline_color: Color = PAPER) -> void:
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


## 塗り + インクの縁取り。
static func draw_shape(canvas: CanvasItem, points: PackedVector2Array, fill: Color, line_width: float = 3.0,
		line_color: Color = INK) -> void:
	canvas.draw_colored_polygon(points, fill)
	var closed := points.duplicate()
	closed.append(points[0])
	canvas.draw_polyline(closed, line_color, line_width, true)


## 地面の影。
static func draw_shadow(canvas: CanvasItem, center: Vector2, radii: Vector2) -> void:
	canvas.draw_colored_polygon(ellipse(center, radii, 20), SHADOW)


## 手描き風の HP バー。
static func draw_bar(canvas: CanvasItem, rect: Rect2, ratio: float, fill: Color = Color.TRANSPARENT) -> void:
	var color := fill if fill.a > 0.0 else hp_color(ratio)
	canvas.draw_colored_polygon(rounded_rect(rect, rect.size.y * 0.5), Color(1, 1, 1, 0.85))
	if ratio > 0.0:
		var inner := Rect2(rect.position, Vector2(maxf(rect.size.y, rect.size.x * clampf(ratio, 0.0, 1.0)), rect.size.y))
		canvas.draw_colored_polygon(rounded_rect(inner, rect.size.y * 0.5), color)
	var outline := rounded_rect(rect, rect.size.y * 0.5)
	outline.append(outline[0])
	canvas.draw_polyline(outline, INK, 2.0, true)
