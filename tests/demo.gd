extends SceneTree
## 一連の流れ（描く → 合体 → 戦う）を入力なしで再生する。動画の書き出しに使う。
##   xvfb-run godot --path . --rendering-driver opengl3 -s res://tests/demo.gd --write-movie out/demo.png --fixed-fps 30
## パネルの API ではなく、本物の入力（Input.action_press）とカーソル位置で描くので、
## 実際に遊ぶときと同じコードが動く。

const DRAW_SCENE := "res://src/draw/draw_phase.tscn"
const CURSOR_SPEED := 420.0
const BATTLE_SECONDS := 28.0

var _started := false
var _elapsed := 0.0
var _draw_phase: Node
var _body_panel: DrawPanel
var _weapon_panel: DrawPanel
var _body_plan: Array = []
var _weapon_plan: Array = []
var _body_cursor := {}
var _weapon_cursor := {}
var _done_sent := false
var _battle_started_at := -1.0


func _process(delta: float) -> bool:
	if not _started:
		_started = true
		_draw_phase = (load(DRAW_SCENE) as PackedScene).instantiate()
		root.add_child(_draw_phase)
		current_scene = _draw_phase
		_body_panel = _draw_phase.get_node("BodyPanel")
		_weapon_panel = _draw_phase.get_node("WeaponPanel")
		_body_plan = _body_strokes()
		_weapon_plan = _weapon_strokes()
		_body_cursor = _new_cursor(_body_panel.cursor)
		_weapon_cursor = _new_cursor(_weapon_panel.cursor)
		return false
	_elapsed += delta

	if is_instance_valid(_draw_phase) and _draw_phase.is_inside_tree() and not _draw_phase.merging:
		if _elapsed > 1.0:
			_drive(_body_panel, _body_plan, _body_cursor, "p1_attack", delta)
			_drive(_weapon_panel, _weapon_plan, _weapon_cursor, "p2_attack", delta)
		if _body_plan.is_empty() and _weapon_plan.is_empty() and not _done_sent and _elapsed > 2.0:
			_done_sent = true
			Input.action_release("p1_attack")
			Input.action_release("p2_attack")
			_body_panel.set_done(true)
			_weapon_panel.set_done(true)
		return false

	if _battle_started_at < 0.0:
		var scene := current_scene
		if scene != null and scene.name == "Main":
			_battle_started_at = _elapsed
		return false
	if _elapsed - _battle_started_at >= BATTLE_SECONDS:
		quit(0)
		return true
	return false


## 線を一本ずつ、カーソルを一定速度で動かしながら描く。
func _drive(panel: DrawPanel, plan: Array, state: Dictionary, action: String, delta: float) -> void:
	if plan.is_empty():
		Input.action_release(action)
		return
	var stroke: PackedVector2Array = plan[0]
	if state["index"] == 0 and not state["pressed"]:
		# 線の始点まで、ペンを上げたまま移動する。
		panel.cursor = panel.cursor.move_toward(stroke[0], CURSOR_SPEED * delta)
		if panel.cursor.distance_to(stroke[0]) < 1.0:
			state["pressed"] = true
			state["index"] = 1
			Input.action_press(action)
		return
	var target: Vector2 = stroke[state["index"]]
	panel.cursor = panel.cursor.move_toward(target, CURSOR_SPEED * delta)
	if panel.cursor.distance_to(target) < 1.0:
		state["index"] += 1
		if state["index"] >= stroke.size():
			Input.action_release(action)
			state["pressed"] = false
			state["index"] = 0
			state["pause"] = 0.15
			plan.pop_front()


func _new_cursor(start: Vector2) -> Dictionary:
	return {"index": 0, "pressed": false, "pause": 0.0, "pos": start}


func _ellipse(center: Vector2, radii: Vector2, points: int = 36, start_angle: float = 0.0) -> PackedVector2Array:
	var stroke := PackedVector2Array()
	for i in range(points + 1):
		var t := start_angle + TAU * i / points
		stroke.append(center + Vector2(cos(t) * radii.x, sin(t) * radii.y))
	return stroke


## からだ: 丸い胴体、背中のトゲ、目、短い脚。
func _body_strokes() -> Array:
	var plan: Array = []
	plan.append(_ellipse(Vector2(260, 290), Vector2(170, 130), 40, PI))
	var spikes := PackedVector2Array()
	for i in range(7):
		var x := 120.0 + i * 46.0
		spikes.append(Vector2(x, 185.0 - (i % 2) * 0.0))
		spikes.append(Vector2(x + 23.0, 120.0 + (i % 2) * 15.0))
	spikes.append(Vector2(442, 185))
	plan.append(spikes)
	plan.append(_ellipse(Vector2(200, 270), Vector2(22, 22), 16))
	plan.append(_ellipse(Vector2(320, 270), Vector2(22, 22), 16))
	plan.append(PackedVector2Array([Vector2(200, 270), Vector2(206, 276)]))
	plan.append(PackedVector2Array([Vector2(320, 270), Vector2(326, 276)]))
	plan.append(PackedVector2Array([Vector2(190, 410), Vector2(185, 470), Vector2(215, 470)]))
	plan.append(PackedVector2Array([Vector2(330, 410), Vector2(335, 470), Vector2(365, 470)]))
	plan.append(PackedVector2Array([Vector2(225, 340), Vector2(260, 360), Vector2(295, 340)]))
	return plan


## ぶき: 長い柄の先に重い頭（ハンマー）。
func _weapon_strokes() -> Array:
	var plan: Array = []
	plan.append(PackedVector2Array([Vector2(60, 300), Vector2(330, 240)]))
	plan.append(PackedVector2Array([Vector2(60, 312), Vector2(330, 252)]))
	var head := PackedVector2Array([
		Vector2(320, 160), Vector2(460, 130), Vector2(480, 330), Vector2(340, 360), Vector2(320, 160)])
	plan.append(head)
	plan.append(_ellipse(Vector2(400, 245), Vector2(50, 70), 20))
	plan.append(_ellipse(Vector2(400, 245), Vector2(30, 45), 16))
	return plan
