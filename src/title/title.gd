extends Node2D
## タイトル画面。ロゴ・見本のビースト・はじめかた。ボタンかクリックで描画フェーズへ。

const NEXT_SCENE := "res://src/draw/draw_phase.tscn"
const BEAST_SCENE := preload("res://src/game/beast.tscn")

var _t := 0.0
var _leaving := false
var _fade := 1.0
var _decor: Node2D
var _mascot: Beast


class Decor:
	extends Node2D
	var title: Node

	func _draw() -> void:
		title.draw_decor(self)


func _ready() -> void:
	Engine.time_scale = 1.0
	_decor = Decor.new()
	_decor.title = self
	_decor.material = DoodleStyle.doodle_material(1.2, 1.0)
	add_child(_decor)
	_mascot = BEAST_SCENE.instantiate() as Beast
	_mascot.target_size = 230.0
	_mascot.position = Vector2(930.0, 420.0)
	add_child(_mascot)
	_mascot.build(SampleDoodles.body(), SampleDoodles.weapon(), 3000.0)
	var tree_node := _mascot.get_node("BehaviorTree") as BehaviorTree
	tree_node.enabled = false


func _process(delta: float) -> void:
	_t += delta
	_fade = maxf(0.0, _fade - delta * 2.0) if not _leaving else minf(1.0, _fade + delta * 4.0)
	if not _leaving:
		for action in ["ui_accept", "p1_done", "p2_done", "p1_attack", "p2_attack"]:
			if Input.is_action_just_pressed(action):
				start()
				break
	if _mascot != null and is_instance_valid(_mascot):
		var weapon := _mascot.get_node_or_null("Visual/Weapon") as Node2D
		if weapon != null:
			weapon.rotation = sin(_t * 2.2) * 0.25
	queue_redraw()
	_decor.queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and not _leaving:
		start()


func start() -> void:
	if _leaving:
		return
	_leaving = true
	await get_tree().create_timer(0.3).timeout
	get_tree().change_scene_to_file(NEXT_SCENE)


func draw_decor(c: Node2D) -> void:
	# 余白のらくがき
	for i in range(5):
		var p := Vector2(150.0 + i * 150.0, 640.0 + sin(i * 1.7) * 18.0)
		_star(c, p, 14.0 + (i % 2) * 6.0, [DoodleStyle.P2, DoodleStyle.CASTLE_FLAG, DoodleStyle.P1, DoodleStyle.ERASER_PINK, DoodleStyle.CASTLE_ROOF][i])
	var spiral := PackedVector2Array()
	for i in range(60):
		var a := i * 0.35
		spiral.append(Vector2(1180.0, 110.0) + Vector2(cos(a), sin(a)) * (2.0 + i * 0.6))
	c.draw_polyline(spiral, DoodleStyle.INK_SOFT, 3.0, true)
	# 地面の線
	var ground := PackedVector2Array()
	for i in range(30):
		ground.append(Vector2(760.0 + i * 13.0, 560.0 + sin(i * 1.3) * 3.0))
	c.draw_polyline(ground, DoodleStyle.INK, 3.0, true)


func _star(c: Node2D, center: Vector2, radius: float, color: Color) -> void:
	var points := PackedVector2Array()
	for i in range(10):
		var r := radius if i % 2 == 0 else radius * 0.45
		var a := -PI / 2.0 + TAU * i / 10.0 + _t * 0.3
		points.append(center + Vector2(cos(a), sin(a)) * r)
	DoodleStyle.draw_shape(c, points, color, 2.5)


func _draw() -> void:
	# ロゴ
	var colors := [DoodleStyle.P1, DoodleStyle.P2, DoodleStyle.CASTLE_FLAG, DoodleStyle.CASTLE_ROOF]
	var line1 := "らくがき"
	var line2 := "ビースト"
	_draw_logo_line(line1, Vector2(150.0, 230.0), 96, colors, 0.0)
	_draw_logo_line(line2, Vector2(200.0, 360.0), 120, colors, 2.0)
	DoodleStyle.draw_text(self, DoodleStyle.HAND_FONT, Vector2(206.0, 420.0), "DOODLE  BEASTS", 34, DoodleStyle.INK, HORIZONTAL_ALIGNMENT_LEFT, -1, 8)
	DoodleStyle.draw_text(self, DoodleStyle.UI_FONT, Vector2(150.0, 480.0), "みんなで描いた いきものが、消しゴム軍団と たたかう！", 22, DoodleStyle.INK, HORIZONTAL_ALIGNMENT_LEFT, -1, 6)
	var blink := 0.55 + 0.45 * sin(_t * 4.0)
	_draw_button_hint(Vector2(150.0, 560.0), blink)
	DoodleStyle.draw_text(self, DoodleStyle.UI_FONT, Vector2(0.0, 704.0), "1〜2人 きょうりょく ・ ゲームパッド / キーボード / マウス ・ Remote Play Together", 15, Color(DoodleStyle.INK, 0.6), HORIZONTAL_ALIGNMENT_CENTER, 1280.0)
	if _fade > 0.0:
		draw_rect(Rect2(0.0, 0.0, 1280.0, 720.0), Color(1.0, 1.0, 1.0, _fade))


func _draw_logo_line(text: String, origin: Vector2, size: int, colors: Array, phase: float) -> void:
	var x := origin.x
	for i in range(text.length()):
		var ch := text.substr(i, 1)
		var bob := sin(_t * 3.0 + i * 0.9 + phase) * 6.0
		var tilt := sin(i * 2.3 + phase) * 0.12
		var w := DoodleStyle.HAND_FONT.get_string_size(ch, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
		draw_set_transform(Vector2(x + w * 0.5, origin.y + bob), tilt, Vector2.ONE)
		var p := Vector2(-w * 0.5, 0.0)
		draw_string_outline(DoodleStyle.HAND_FONT, p + Vector2(4.0, 7.0), ch, HORIZONTAL_ALIGNMENT_LEFT, -1, size, 22, Color("b9ab92"))
		draw_string_outline(DoodleStyle.HAND_FONT, p, ch, HORIZONTAL_ALIGNMENT_LEFT, -1, size, 22, DoodleStyle.PAPER)
		draw_string_outline(DoodleStyle.HAND_FONT, p, ch, HORIZONTAL_ALIGNMENT_LEFT, -1, size, 8, DoodleStyle.INK)
		draw_string(DoodleStyle.HAND_FONT, p, ch, HORIZONTAL_ALIGNMENT_LEFT, -1, size, colors[(i + int(phase)) % colors.size()])
		x += w + 4.0
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_button_hint(origin: Vector2, alpha: float) -> void:
	var rect := Rect2(origin, Vector2(470.0, 58.0))
	draw_colored_polygon(DoodleStyle.rounded_rect(Rect2(rect.position + Vector2(4.0, 6.0), rect.size), 29.0), DoodleStyle.SHADOW)
	DoodleStyle.draw_shape(self, DoodleStyle.rounded_rect(rect, 29.0), Color(DoodleStyle.ACCENT_RED, 0.75 + 0.25 * alpha), 3.0)
	DoodleStyle.draw_text(self, DoodleStyle.HAND_FONT, rect.position + Vector2(0.0, 40.0), "A ボタン / Enter / クリックで はじめる", 24, DoodleStyle.PAPER, HORIZONTAL_ALIGNMENT_CENTER, rect.size.x)
