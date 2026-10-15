extends SceneTree
## 見た目の確認用に、各画面を短く順に表示する（入力なし）。低い fps で書き出して静止画を拾う。
##   xvfb-run godot --path . --rendering-driver opengl3 -s res://tests/stills.gd --write-movie out/still.png --fixed-fps 10
## タイトル 2 秒 → 描画フェーズ（見本の絵を読み込んだ状態）2 秒 → 戦闘 14 秒。

var _phase := 0
var _elapsed := 0.0
var _phase_started := 0.0


func _process(delta: float) -> bool:
	_elapsed += delta
	var in_phase := _elapsed - _phase_started
	match _phase:
		0:
			_show("res://src/title/title.tscn")
			_next()
		1:
			if in_phase >= 2.0:
				var draw := _show("res://src/draw/draw_phase.tscn")
				draw.get_node("BodyPanel").load_strokes(SampleDoodles.body())
				draw.get_node("WeaponPanel").load_strokes(SampleDoodles.weapon())
				_next()
		2:
			if in_phase >= 2.0:
				root.get_node("GameSession").store(SampleDoodles.body(), SampleDoodles.weapon(), 3000.0)
				_show("res://src/game/main.tscn")
				_next()
		3:
			if in_phase >= 14.0:
				quit(0)
				return true
	return false


func _next() -> void:
	_phase += 1
	_phase_started = _elapsed


func _show(path: String) -> Node:
	if current_scene != null:
		current_scene.queue_free()
	var scene := (load(path) as PackedScene).instantiate()
	root.add_child(scene)
	current_scene = scene
	return scene
