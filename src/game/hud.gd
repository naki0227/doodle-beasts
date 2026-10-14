extends CanvasLayer
## 画面上の情報表示。ゲームオーバー中も動くよう process_mode は Always にしてある。

@onready var status_label: Label = $Status
@onready var players_label: Label = $Players
@onready var center_label: Label = $Center
@onready var hint_label: Label = $Hint

var _core_hp := 0.0
var _core_max := 1.0
var _wave := 0
var _enemies := 0
var _countdown := 0.0
var _player_lines: Dictionary = {}


func set_core_hp(hp: float, max_hp: float) -> void:
	_core_hp = hp
	_core_max = max_hp
	_refresh()


func set_wave(wave: int) -> void:
	_wave = wave
	_countdown = 0.0
	_refresh()


func set_enemy_count(count: int) -> void:
	_enemies = count
	_refresh()


func set_countdown(seconds: float) -> void:
	_countdown = seconds
	_refresh()


func set_player_status(index: int, hp: float, max_hp: float, downed: bool) -> void:
	var state := "倒れた（復活待ち）" if downed else "%d / %d" % [roundi(hp), roundi(max_hp)]
	_player_lines[index] = "P%d  HP %s" % [index, state]
	_refresh()


func show_game_over(wave: int) -> void:
	center_label.text = "拠点が落ちた…  到達ウェーブ %d\nR キー / Start でやり直し" % wave
	center_label.visible = true


func _refresh() -> void:
	var lines: Array[String] = []
	lines.append("拠点 HP  %d / %d" % [roundi(_core_hp), roundi(_core_max)])
	if _countdown > 0.0:
		lines.append("次の波まで  %.1f 秒" % _countdown)
	else:
		lines.append("ウェーブ %d   敵 %d" % [_wave, _enemies])
	status_label.text = "\n".join(lines)
	var player_lines: Array[String] = []
	for index in [1, 2]:
		if _player_lines.has(index):
			player_lines.append(_player_lines[index])
	players_label.text = "\n".join(player_lines)


func _unhandled_input(event: InputEvent) -> void:
	if center_label.visible and event.is_action_pressed("restart"):
		get_tree().paused = false
		get_tree().reload_current_scene()
