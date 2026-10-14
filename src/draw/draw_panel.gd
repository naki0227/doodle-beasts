class_name DrawPanel
extends Node2D
## 一人ぶんのキャンバス。パッド（スティックでカーソル、ボタンで描く）か、マウスで描く。
## 線のデータは strokes に溜まり、解析と立体化はこのデータだけを見る。

signal changed
signal done_changed(done: bool)

@export_range(1, 2) var player_index: int = 1
@export var panel_size: Vector2 = Vector2(520.0, 520.0)
@export var ink_budget: float = 3000.0
@export var title: String = "からだ"
@export var accent: Color = Color(0.4, 0.9, 0.5)
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


func _ready() -> void:
	cursor = panel_size * 0.5
	queue_redraw()


func _process(delta: float) -> void:
	if locked or done:
		return
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
	queue_redraw()


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
	draw_rect(rect, Color(0.97, 0.96, 0.92))
	draw_rect(rect, accent if done else Color(0.3, 0.3, 0.35), false, 4.0)
	for stroke in strokes:
		_draw_stroke(stroke, Color(0.15, 0.15, 0.2))
	if drawing:
		_draw_stroke(current, Color(0.15, 0.15, 0.2))
	if not (locked or done):
		draw_arc(cursor, 9.0, 0.0, TAU, 24, accent, 2.0)
		draw_line(cursor + Vector2(-14.0, 0.0), cursor + Vector2(14.0, 0.0), accent, 1.5)
		draw_line(cursor + Vector2(0.0, -14.0), cursor + Vector2(0.0, 14.0), accent, 1.5)
	# インク残量
	var bar := Rect2(0.0, panel_size.y + 8.0, panel_size.x, 10.0)
	draw_rect(bar, Color(0.2, 0.2, 0.25))
	var ratio := clampf(ink_left() / ink_budget, 0.0, 1.0) if ink_budget > 0.0 else 0.0
	draw_rect(Rect2(bar.position, Vector2(bar.size.x * ratio, bar.size.y)), accent)


func _draw_stroke(stroke: PackedVector2Array, color: Color) -> void:
	if stroke.size() >= 2:
		draw_polyline(stroke, color, 4.0, true)
	elif stroke.size() == 1:
		draw_circle(stroke[0], 2.0, color)
