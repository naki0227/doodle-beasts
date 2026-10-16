extends SceneTree
## 一連の流れを入力なしで再生する。動画の書き出しに使う。
##   タイトル → 記録帳に描く → 合体 → 自動の戦闘（第一の波）→ 波を守る → 記録帳で目を一つ描き足す → 第二の波
##   xvfb-run godot --path . --rendering-driver opengl3 -s res://tests/demo.gd --write-movie out/demo.png --fixed-fps 30
## パネルの API ではなく、本物の入力（Input.action_press）とカーソル位置で描くので、
## 実際に遊ぶときと同じコードが動く。

const TITLE_SCENE := "res://src/title/title.tscn"
const CURSOR_SPEED := 460.0
const TITLE_SECONDS := 3.5
const SECOND_BATTLE_SECONDS := 16.0
const SAFETY_SECONDS := 150.0

var _phase := "boot"
var _elapsed := 0.0
var _phase_started := 0.0
var _body_panel: DrawPanel
var _weapon_panel: DrawPanel
var _body_plan: Array = []
var _weapon_plan: Array = []
var _body_state := {"index": 0, "pressed": false}
var _weapon_state := {"index": 0, "pressed": false}
var _done_sent := false


func _process(delta: float) -> bool:
	_elapsed += delta
	if _elapsed > SAFETY_SECONDS:
		quit(1)
		return true
	var scene := current_scene
	var scene_name := String(scene.name) if scene != null else ""
	match _phase:
		"boot":
			var title := (load(TITLE_SCENE) as PackedScene).instantiate()
			root.add_child(title)
			current_scene = title
			_enter("title")
		"title":
			Input.action_release("p1_done")
			if _elapsed - _phase_started >= TITLE_SECONDS:
				Input.action_press("p1_done")
				_enter("to_draw")
		"to_draw":
			Input.action_release("p1_done")
			if scene_name == "DrawPhase":
				_begin_drawing(scene, SampleDoodles.body(), SampleDoodles.weapon())
				_enter("draw")
		"draw", "redraw":
			if scene_name == "Main":
				_enter("battle" if _phase == "draw" else "battle2")
				return false
			if not (is_instance_valid(_body_panel) and is_instance_valid(_weapon_panel)):
				return false
			if _elapsed - _phase_started > 1.0:
				_drive(_body_panel, _body_plan, _body_state, "p1_attack", delta)
				_drive(_weapon_panel, _weapon_plan, _weapon_state, "p2_attack", delta)
			if _body_plan.is_empty() and _weapon_plan.is_empty() and not _done_sent and _elapsed - _phase_started > 2.0:
				_done_sent = true
				Input.action_release("p1_attack")
				Input.action_release("p2_attack")
				_body_panel.set_done(true)
				_weapon_panel.set_done(true)
		"battle":
			# 第一の波を守ると、自動で記録帳へ戻る。目を一つ描き足す。
			if scene_name == "DrawPhase":
				var third_eye: Array[PackedVector2Array] = [_circle(Vector2(221, 200), 15.0)]
				_begin_drawing(scene, third_eye, [] as Array[PackedVector2Array])
				_enter("redraw")
		"battle2":
			if _elapsed - _phase_started >= SECOND_BATTLE_SECONDS:
				quit(0)
				return true
	return false


func _enter(phase: String) -> void:
	_phase = phase
	_phase_started = _elapsed


func _begin_drawing(scene: Node, body: Array, weapon: Array) -> void:
	_body_panel = scene.get_node("BodyPanel")
	_weapon_panel = scene.get_node("WeaponPanel")
	_body_plan = body.duplicate()
	_weapon_plan = weapon.duplicate()
	_body_state = {"index": 0, "pressed": false}
	_weapon_state = {"index": 0, "pressed": false}
	_done_sent = false


func _circle(center: Vector2, radius: float) -> PackedVector2Array:
	var stroke := PackedVector2Array()
	for i in range(21):
		stroke.append(center + Vector2.RIGHT.rotated(TAU * i / 20.0) * radius)
	return stroke


## 線を一本ずつ、カーソルを一定速度で動かしながら描く。
func _drive(panel: DrawPanel, plan: Array, state: Dictionary, action: String, delta: float) -> void:
	if plan.is_empty():
		Input.action_release(action)
		return
	var stroke: PackedVector2Array = plan[0]
	if state["index"] == 0 and not state["pressed"]:
		# 線の始点まで、ペンを上げたまま移動する。
		panel.cursor = panel.cursor.move_toward(stroke[0], CURSOR_SPEED * 1.6 * delta)
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
			plan.pop_front()
