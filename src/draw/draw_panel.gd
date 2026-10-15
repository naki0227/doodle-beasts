class_name DrawPanel
extends Node2D
## 一人ぶんのキャンバス（スケッチブックの 1 ページ）。パッド（スティックでカーソル、ボタンで描く）か、マウスで描く。
## 線のデータは strokes に溜まり、解析と立体化はこのデータだけを見る。

signal changed
signal done_changed(done: bool)

@export_range(1, 2) var player_index: int = 1
@export var panel_size: Vector2 = Vector2(480.0, 470.0)
@export var ink_budget: float = 3000.0
@export var title: String = "からだ"
@export var guide: String = "ここに からだ を描こう"
@export var accent: Color = DoodleStyle.P1
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


## 線だけを描く子ノード。線にだけ「ふるえ」のシェーダーをかけるために分けている。
class InkLayer:
	extends Node2D
	var panel: DrawPanel

	func _draw() -> void:
		for stroke in panel.strokes:
			_stroke(stroke)
		if panel.drawing:
			_stroke(panel.current)

	func _stroke(stroke: PackedVector2Array) -> void:
		if stroke.size() >= 2:
			draw_polyline(stroke, DoodleStyle.INK, 5.0, true)
			draw_circle(stroke[0], 2.5, DoodleStyle.INK)
			draw_circle(stroke[stroke.size() - 1], 2.5, DoodleStyle.INK)
		elif stroke.size() == 1:
			draw_circle(stroke[0], 2.5, DoodleStyle.INK)


func _ready() -> void:
	cursor = panel_size * 0.5
	_ink = InkLayer.new()
	_ink.panel = self
	_ink.material = DoodleStyle.doodle_material(0.7, 0.0)
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
	var rect := Rect2(Vector2.ZERO, panel_size)
	# 影と紙
	draw_colored_polygon(DoodleStyle.rounded_rect(Rect2(rect.position + Vector2(8.0, 12.0), rect.size), 8.0), Color(0, 0, 0, 0.28))
	draw_colored_polygon(DoodleStyle.rounded_rect(Rect2(rect.position + Vector2(3.0, 4.0), rect.size), 8.0), DoodleStyle.PAPER_SHADE)
	draw_colored_polygon(DoodleStyle.rounded_rect(rect, 8.0), DoodleStyle.PAPER)
	# 方眼の点
	for x in range(24, int(panel_size.x), 24):
		for y in range(72, int(panel_size.y), 24):
			draw_circle(Vector2(x, y), 1.1, Color(0.6, 0.7, 0.85, 0.45))
	# リング
	for x in range(30, int(panel_size.x) - 10, 38):
		draw_circle(Vector2(x, 2.0), 7.0, Color(0, 0, 0, 0.35))
		draw_arc(Vector2(x, -4.0), 8.0, PI * 0.1, PI * 1.9, 14, Color("9aa0a8"), 3.5, true)
	# 見出し
	DoodleStyle.draw_text(self, DoodleStyle.HAND_FONT, Vector2(22.0, 52.0), title, 34, DoodleStyle.INK)
	var title_width := DoodleStyle.HAND_FONT.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, 34).x
	draw_line(Vector2(20.0, 60.0), Vector2(30.0 + title_width, 58.0), accent, 6.0, true)
	DoodleStyle.draw_text(self, DoodleStyle.UI_FONT, Vector2(panel_size.x - 140.0, 48.0), "P%d がかく" % player_index, 16, accent.darkened(0.2), HORIZONTAL_ALIGNMENT_RIGHT, 120.0)
	if strokes.is_empty() and not drawing:
		var pulse := 0.35 + 0.15 * sin(_t * 3.0)
		DoodleStyle.draw_text(self, DoodleStyle.HAND_FONT, Vector2(0.0, panel_size.y * 0.55), guide, 26, Color(DoodleStyle.INK, pulse), HORIZONTAL_ALIGNMENT_CENTER, panel_size.x)
	# 鉛筆のインク残量（短くなっていく）
	_draw_ink_pencil(Vector2(10.0, panel_size.y + 30.0), panel_size.x - 20.0)
	if not (locked or done):
		_draw_cursor()
	if done:
		_draw_stamp()


func _draw_ink_pencil(origin: Vector2, max_length: float) -> void:
	var ratio := clampf(ink_left() / ink_budget, 0.0, 1.0) if ink_budget > 0.0 else 0.0
	var length := maxf(40.0, max_length * ratio)
	var h := 16.0
	var tip := origin + Vector2(length, 0.0)
	draw_colored_polygon(PackedVector2Array([origin + Vector2(4, h * 0.5 + 4), tip + Vector2(4, 4), tip + Vector2(-26, h * 0.5 + 4)]), Color(0, 0, 0, 0.25))
	DoodleStyle.draw_shape(self, PackedVector2Array([origin + Vector2(0, -h * 0.5), tip + Vector2(-28, -h * 0.5), tip + Vector2(-28, h * 0.5), origin + Vector2(0, h * 0.5)]), accent, 2.0)
	DoodleStyle.draw_shape(self, PackedVector2Array([tip + Vector2(-28, -h * 0.5), tip + Vector2(-8, -3), tip + Vector2(-8, 3), tip + Vector2(-28, h * 0.5)]), Color("f1d3a0"), 2.0)
	DoodleStyle.draw_shape(self, PackedVector2Array([tip + Vector2(-8, -3), tip, tip + Vector2(-8, 3)]), DoodleStyle.INK, 1.5)
	DoodleStyle.draw_shape(self, DoodleStyle.rounded_rect(Rect2(origin + Vector2(-14, -h * 0.5), Vector2(14, h)), 4.0), DoodleStyle.ERASER_PINK, 2.0)
	DoodleStyle.draw_text(self, DoodleStyle.UI_FONT, origin + Vector2(0.0, 32.0), "インク のこり %d%%" % roundi(ratio * 100.0), 14, DoodleStyle.PAPER, HORIZONTAL_ALIGNMENT_LEFT, -1, 4, Color(0, 0, 0, 0.5))


func _draw_cursor() -> void:
	var tilt := -0.5 if drawing else -0.75
	var lift := 0.0 if drawing else -6.0
	draw_set_transform(cursor + Vector2(0.0, lift), tilt, Vector2.ONE)
	draw_colored_polygon(PackedVector2Array([Vector2(6, 4), Vector2(14, -6), Vector2(14, -70), Vector2(-2, -70), Vector2(-2, -6)]), Color(0, 0, 0, 0.18))
	DoodleStyle.draw_shape(self, PackedVector2Array([Vector2(0, 0), Vector2(-4, -9), Vector2(4, -9)]), DoodleStyle.INK, 1.5)
	DoodleStyle.draw_shape(self, PackedVector2Array([Vector2(-4, -9), Vector2(4, -9), Vector2(8, -22), Vector2(-8, -22)]), Color("f1d3a0"), 2.0)
	DoodleStyle.draw_shape(self, PackedVector2Array([Vector2(-8, -22), Vector2(8, -22), Vector2(8, -64), Vector2(-8, -64)]), accent, 2.0)
	DoodleStyle.draw_shape(self, DoodleStyle.rounded_rect(Rect2(-8, -74, 16, 10), 3.0), DoodleStyle.ERASER_PINK, 2.0)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	if not drawing:
		draw_arc(cursor, 6.0 + sin(_t * 6.0), 0.0, TAU, 16, Color(accent, 0.8), 2.0, true)


func _draw_stamp() -> void:
	var pop := 1.0 + 1.2 * (1.0 - _stamp) * (1.0 - _stamp)
	var center := Vector2(panel_size.x - 90.0, panel_size.y - 90.0)
	draw_set_transform(center, -0.25, Vector2(pop, pop))
	var red := Color(DoodleStyle.ACCENT_RED, 0.85 * _stamp)
	draw_arc(Vector2.ZERO, 58.0, 0.0, TAU, 40, red, 6.0, true)
	draw_arc(Vector2.ZERO, 50.0, 0.0, TAU, 40, red, 2.0, true)
	DoodleStyle.draw_text(self, DoodleStyle.HAND_FONT, Vector2(-60.0, 16.0), "OK!", 44, red, HORIZONTAL_ALIGNMENT_CENTER, 120.0)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
