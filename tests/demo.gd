extends SceneTree
## 一連の流れ（タイトル → 描く → 合体 → 戦う）を入力なしで再生する。動画の書き出しに使う。
##   xvfb-run godot --path . --rendering-driver opengl3 -s res://tests/demo.gd --write-movie out/demo.png --fixed-fps 30
## パネルの API ではなく、本物の入力（Input.action_press）とカーソル位置で描くので、
## 実際に遊ぶときと同じコードが動く。

const TITLE_SCENE := "res://src/title/title.tscn"
const CURSOR_SPEED := 460.0
const TITLE_SECONDS := 3.0
const BATTLE_SECONDS := 30.0

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
			var scene := current_scene
			if scene != null and scene.name == "DrawPhase":
				_body_panel = scene.get_node("BodyPanel")
				_weapon_panel = scene.get_node("WeaponPanel")
				_body_plan = SampleDoodles.body()
				_weapon_plan = SampleDoodles.weapon()
				_enter("draw")
		"draw":
			var scene := current_scene
			if scene != null and scene.name == "Main":
				_enter("battle")
				return false
			if not (is_instance_valid(_body_panel) and is_instance_valid(_weapon_panel)):
				return false
			if _elapsed - _phase_started > 0.8:
				_drive(_body_panel, _body_plan, _body_state, "p1_attack", delta)
				_drive(_weapon_panel, _weapon_plan, _weapon_state, "p2_attack", delta)
			if _body_plan.is_empty() and _weapon_plan.is_empty() and not _done_sent:
				_done_sent = true
				Input.action_release("p1_attack")
				Input.action_release("p2_attack")
				_body_panel.set_done(true)
				_weapon_panel.set_done(true)
		"battle":
			if _elapsed - _phase_started >= BATTLE_SECONDS:
				quit(0)
				return true
	return false


func _enter(phase: String) -> void:
	_phase = phase
	_phase_started = _elapsed


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
