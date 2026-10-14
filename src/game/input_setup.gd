extends Node
## 起動時に InputMap へ操作を登録する自動読み込みノード。
## project.godot に手書きするより読みやすく、キー配置がここに一覧で残る。
##
## P1: WASD 移動 / J 攻撃 / K 修理、またはゲームパッド0
## P2: 矢印 移動 / . 攻撃 / / 修理、またはゲームパッド1
## R: ゲームオーバー後にやり直し

const PLAYERS := {
	1: {
		"device": 0,
		"left": KEY_A, "right": KEY_D, "up": KEY_W, "down": KEY_S,
		"attack": KEY_J, "repair": KEY_K,
	},
	2: {
		"device": 1,
		"left": KEY_LEFT, "right": KEY_RIGHT, "up": KEY_UP, "down": KEY_DOWN,
		"attack": KEY_PERIOD, "repair": KEY_SLASH,
	},
}


func _ready() -> void:
	for index in PLAYERS:
		_register_player(index, PLAYERS[index])
	_add_key("restart", KEY_R)
	for index in PLAYERS:
		_add_joy_button("restart", PLAYERS[index]["device"], JOY_BUTTON_START)


func _register_player(index: int, keys: Dictionary) -> void:
	var prefix := "p%d_" % index
	var device: int = keys["device"]
	_add_key(prefix + "left", keys["left"])
	_add_key(prefix + "right", keys["right"])
	_add_key(prefix + "up", keys["up"])
	_add_key(prefix + "down", keys["down"])
	_add_key(prefix + "attack", keys["attack"])
	_add_key(prefix + "repair", keys["repair"])
	_add_joy_axis(prefix + "left", device, JOY_AXIS_LEFT_X, -1.0)
	_add_joy_axis(prefix + "right", device, JOY_AXIS_LEFT_X, 1.0)
	_add_joy_axis(prefix + "up", device, JOY_AXIS_LEFT_Y, -1.0)
	_add_joy_axis(prefix + "down", device, JOY_AXIS_LEFT_Y, 1.0)
	_add_joy_button(prefix + "attack", device, JOY_BUTTON_A)
	_add_joy_button(prefix + "repair", device, JOY_BUTTON_X)


func _ensure_action(action: String) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action, 0.3)


func _add_key(action: String, keycode: Key) -> void:
	_ensure_action(action)
	var event := InputEventKey.new()
	event.physical_keycode = keycode
	InputMap.action_add_event(action, event)


func _add_joy_axis(action: String, device: int, axis: JoyAxis, direction: float) -> void:
	_ensure_action(action)
	var event := InputEventJoypadMotion.new()
	event.device = device
	event.axis = axis
	event.axis_value = direction
	InputMap.action_add_event(action, event)


func _add_joy_button(action: String, device: int, button: JoyButton) -> void:
	_ensure_action(action)
	var event := InputEventJoypadButton.new()
	event.device = device
	event.button_index = button
	InputMap.action_add_event(action, event)
