class_name DrawPanel
extends Node2D
## 一人ぶんのキャンバス（記録帳の 1 ページ）。パッド（スティックでカーソル、ボタンで描く）か、マウスで描く。
## 線のデータは strokes に溜まり、解析と立体化はこのデータだけを見る。

signal changed
signal done_changed(done: bool)

@export_range(1, 2) var player_index: int = 1
@export var panel_size: Vector2 = Vector2(470.0, 440.0)
@export var ink_budget: float = 3000.0
@export var title: String = "からだ"
@export var guide: String = "ここに からだ を描こう"
@export var accent: Color = DoodleStyle.P1
## 合体の演出で、インクの線を金に変える割合（0〜1）。
var gild: float = 0.0
## true なら、このパネルはマウスでも描ける。
@export var use_mouse: bool = false

var strokes: Array[PackedVector2Array] = []
var current: PackedVector2Array = PackedVector2Array()
var cursor: Vector2
var drawing := false
var done := false
var locked := false
var ink_used := 0.0

var _mouse_down := false
var _t := 0.0
var _stamp := 0.0
var _ink: InkLayer
var _paper: ColorRect


## 線だけを描く子ノード。紙（_paper）より手前、飾りや文字と同じ高さに線を描く。
class InkLayer:
	extends Node2D
	var panel: DrawPanel

	func _draw() -> void:
		var color := DoodleStyle.SEPIA.lerp(DoodleStyle.GOLD_LIGHT, panel.gild)
		for stroke in panel.strokes:
			_stroke(stroke, color)
		if panel.drawing:
			_stroke(panel.current, color)

	func _stroke(stroke: PackedVector2Array, color: Color) -> void:
		if stroke.size() >= 2:
			if panel.gild > 0.0:
				draw_polyline(stroke, Color(DoodleStyle.GOLD, 0.35 * panel.gild), 14.0, true)
			draw_polyline(stroke, color, 4.0, true)
			draw_circle(stroke[0], 2.0, color)
			draw_circle(stroke[stroke.size() - 1], 2.0, color)
		elif stroke.size() == 1:
			draw_circle(stroke[0], 2.0, color)


func _ready() -> void:
	cursor = panel_size * 0.5
	_paper = ColorRect.new()
	_paper.size = panel_size
	_paper.show_behind_parent = true
	_paper.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var paper_material := ShaderMaterial.new()
	paper_material.shader = preload("res://assets/shaders/parchment.gdshader")
	paper_material.set_shader_parameter("size", panel_size)
	_paper.material = paper_material
	add_child(_paper)
	_ink = InkLayer.new()
	_ink.panel = self
	add_child(_ink)
	queue_redraw()


func _process(delta: float) -> void:
	_t += delta
	if done:
		_stamp = minf(1.0, _stamp + delta * 5.0)
	else:
		_stamp = 0.0
	if not (locked or done):
		var prefix := "p%d_" % player_index
		var direction := Input.get_vector(prefix + "left", prefix + "right", prefix + "up", prefix + "down")
		if direction != Vector2.ZERO:
			var cursor_speed := lerpf(90.0, 420.0, clampf(direction.length(), 0.0, 1.0))
			_move_cursor(cursor + direction.normalized() * cursor_speed * delta)
		var pad_draw := Input.is_action_pressed(prefix + "attack")
		if pad_draw or _mouse_down:
			if not drawing:
				begin_stroke(cursor)
			else:
				extend_stroke(cursor)
		elif drawing:
			end_stroke()
		if Input.is_action_just_pressed(prefix + "repair"):
			undo()
		if Input.is_action_just_pressed(prefix + "done"):
			set_done(not done)
	elif Input.is_action_just_pressed("p%d_done" % player_index) and done and not locked:
		set_done(false)
	queue_redraw()
	_ink.queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if not use_mouse or locked or done:
		return
	if event is InputEventMouseMotion:
		_move_cursor(to_local(event.position))
		if _mouse_down and drawing:
			extend_stroke(cursor)
	elif event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			_mouse_down = event.pressed
			if event.pressed:
				_move_cursor(to_local(event.position))
		elif event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			undo()


func _move_cursor(to: Vector2) -> void:
	cursor = Vector2(clampf(to.x, 0.0, panel_size.x), clampf(to.y, 0.0, panel_size.y))


func ink_left() -> float:
	return maxf(0.0, ink_budget - ink_used)


## 確定した線に、描いている途中の線を加えたもの。判定の表示に使う。
func strokes_with_current() -> Array[PackedVector2Array]:
	var result := strokes.duplicate()
	if drawing and current.size() >= 2:
		result.append(current)
	return result


func begin_stroke(at: Vector2) -> void:
	if ink_left() <= 0.0:
		return
	drawing = true
	current = PackedVector2Array([at])


func extend_stroke(at: Vector2) -> void:
	if not drawing:
		return
	var last := current[current.size() - 1]
	var step := last.distance_to(at)
	if step < 2.0:
		return
	if ink_used + step > ink_budget:
		end_stroke()
		return
	ink_used += step
	current.append(at)
	changed.emit()


func end_stroke() -> void:
	if not drawing:
		return
	drawing = false
	if current.size() >= 2:
		strokes.append(current)
	elif current.size() == 1:
		# 点だけでも残す。小さな目などに使える。
		strokes.append(PackedVector2Array([current[0], current[0] + Vector2(1.0, 0.0)]))
	current = PackedVector2Array()
	changed.emit()


func undo() -> void:
	if drawing:
		ink_used -= StrokeTools.length(current)
		current = PackedVector2Array()
		drawing = false
	elif not strokes.is_empty():
		var removed: PackedVector2Array = strokes.pop_back()
		ink_used -= StrokeTools.length(removed)
	ink_used = maxf(0.0, ink_used)
	changed.emit()


func clear() -> void:
	strokes = []
	current = PackedVector2Array()
	drawing = false
	ink_used = 0.0
	changed.emit()


func load_strokes(source: Array[PackedVector2Array]) -> void:
	strokes = source.duplicate(true)
	ink_used = StrokeTools.total_length(strokes)
	changed.emit()


func set_done(value: bool) -> void:
	if drawing:
		end_stroke()
	done = value
	done_changed.emit(done)
	queue_redraw()


func _draw() -> void:
	# 紙そのものは _paper（羊皮紙のシェーダー）が描く。ここでは飾りと文字とカーソル。
	_draw_sprigs()
	DoodleStyle.draw_text(self, DoodleStyle.HAND_FONT, Vector2(24.0, 50.0), title, 30, DoodleStyle.SEPIA)
	var title_width := DoodleStyle.HAND_FONT.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, 30).x
	draw_line(Vector2(24.0, 60.0), Vector2(34.0 + title_width, 60.0), Color(accent.darkened(0.2), 0.9), 2.0)
	draw_colored_polygon(PackedVector2Array([Vector2(40.0 + title_width, 56.0), Vector2(44.0 + title_width, 60.0), Vector2(40.0 + title_width, 64.0), Vector2(36.0 + title_width, 60.0)]), accent.darkened(0.2))
	DoodleStyle.draw_text(self, DoodleStyle.UI_FONT, Vector2(panel_size.x - 160.0, 48.0), "旅人 %d が描く" % player_index, 15, accent.darkened(0.35), HORIZONTAL_ALIGNMENT_RIGHT, 136.0)
	if strokes.is_empty() and not drawing:
		var pulse := 0.3 + 0.15 * sin(_t * 2.5)
		DoodleStyle.draw_text(self, DoodleStyle.HAND_FONT, Vector2(0.0, panel_size.y * 0.55), guide, 24, Color(DoodleStyle.SEPIA, pulse), HORIZONTAL_ALIGNMENT_CENTER, panel_size.x)
	_draw_inkwell(Vector2(26.0, panel_size.y + 34.0), panel_size.x - 52.0)
	if not (locked or done):
		_draw_cursor()
	if done:
		_draw_seal()


## ページの隅の、かすれた植物のスケッチ（記録帳らしさ）。
func _draw_sprigs() -> void:
	var faint := Color(DoodleStyle.SEPIA, 0.18)
	for corner in [Vector2(panel_size.x - 60.0, panel_size.y - 30.0), Vector2(40.0, panel_size.y - 26.0)]:
		var base: Vector2 = corner
		draw_line(base, base + Vector2(10.0, -70.0), faint, 1.5)
		for k in range(5):
			var p := base + Vector2(2.0 * k, -14.0 * k - 8.0)
			draw_colored_polygon(DoodleStyle.ellipse(p + Vector2(8.0, -2.0), Vector2(7.0, 3.0), 8), faint)
			draw_colored_polygon(DoodleStyle.ellipse(p + Vector2(-6.0, -4.0), Vector2(6.0, 2.5), 8), faint)


## インク残量。ページの下に、細いインクの帯と小さなインク壺。
func _draw_inkwell(origin: Vector2, length: float) -> void:
	var ratio := clampf(ink_left() / ink_budget, 0.0, 1.0) if ink_budget > 0.0 else 0.0
	DoodleStyle.draw_shape(self, PackedVector2Array([origin + Vector2(-12, 8), origin + Vector2(-12, -6), origin + Vector2(-8, -10), origin + Vector2(8, -10), origin + Vector2(12, -6), origin + Vector2(12, 8)]), Color("2d3240"), 1.5, DoodleStyle.INK)
	draw_rect(Rect2(origin + Vector2(-9, 7 - 14.0 * ratio), Vector2(18, 14.0 * ratio)), Color("141820"))
	var bar := Rect2(origin + Vector2(22.0, -3.0), Vector2(length - 22.0, 6.0))
	draw_rect(bar, Color(DoodleStyle.NIGHT, 0.6))
	draw_rect(Rect2(bar.position, Vector2(bar.size.x * ratio, bar.size.y)), Color("141820"))
	draw_rect(bar, Color(DoodleStyle.GOLD, 0.6), false, 1.0)
	DoodleStyle.draw_text(self, DoodleStyle.UI_FONT, origin + Vector2(22.0, 26.0), "インク  のこり %d%%" % roundi(ratio * 100.0), 13, DoodleStyle.CREAM)


## 羽根ペンのカーソル。ペン先が cursor の位置。
func _draw_cursor() -> void:
	var lift := 0.0 if drawing else -5.0
	draw_set_transform(cursor + Vector2(0.0, lift), 0.6, Vector2.ONE)
	draw_colored_polygon(PackedVector2Array([Vector2(4, 4), Vector2(10, -70), Vector2(20, -60), Vector2(8, 0)]), Color(0, 0, 0, 0.15))
	DoodleStyle.draw_shape(self, PackedVector2Array([Vector2(0, 0), Vector2(-2, -10), Vector2(2, -10)]), DoodleStyle.INK, 1.0)
	draw_line(Vector2(0, -10), Vector2(0, -78), Color("8a7356"), 2.0)
	var vane := PackedVector2Array([Vector2(0, -18), Vector2(-9, -34), Vector2(-12, -58), Vector2(-4, -80), Vector2(0, -78), Vector2(5, -60), Vector2(6, -36)])
	DoodleStyle.draw_shape(self, vane, accent.lerp(DoodleStyle.CREAM, 0.35), 1.2, DoodleStyle.SEPIA)
	for k in range(5):
		var y := -30.0 - k * 9.0
		draw_line(Vector2(0, y), Vector2(-8, y - 6), Color(DoodleStyle.SEPIA, 0.5), 1.0)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	if not drawing:
		draw_arc(cursor, 6.0 + sin(_t * 6.0), 0.0, TAU, 16, Color(accent.darkened(0.3), 0.8), 1.5, true)


## 完成の封蝋。
func _draw_seal() -> void:
	var pop := 1.0 + 1.0 * (1.0 - _stamp) * (1.0 - _stamp)
	var center := Vector2(panel_size.x - 70.0, panel_size.y - 70.0)
	draw_set_transform(center, -0.2, Vector2(pop, pop))
	var a := _stamp
	var wax := PackedVector2Array()
	for i in range(18):
		var ang := TAU * i / 18.0
		var r := 34.0 + (4.0 if i % 2 == 0 else 0.0)
		wax.append(Vector2(cos(ang), sin(ang)) * r)
	draw_colored_polygon(wax, Color(DoodleStyle.BLOOD, 0.95 * a))
	draw_arc(Vector2.ZERO, 24.0, 0.0, TAU, 24, Color(DoodleStyle.BLOOD.lightened(0.25), a), 2.0, true)
	DoodleStyle.draw_d20(self, Vector2.ZERO, 12.0, Color(DoodleStyle.GOLD, a), Color(DoodleStyle.BLOOD.darkened(0.3), a))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
