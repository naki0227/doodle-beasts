extends Camera2D
## 揺れるカメラ。Fx.shake() から add_shake() が呼ばれる。

var _shake := 0.0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	add_to_group(&"shake_camera")
	process_mode = Node.PROCESS_MODE_ALWAYS
	_rng.randomize()


func add_shake(amount: float) -> void:
	_shake = maxf(_shake, amount)


func _process(delta: float) -> void:
	_shake = maxf(0.0, _shake - delta * 30.0)
	offset = Vector2(_rng.randf_range(-1.0, 1.0), _rng.randf_range(-1.0, 1.0)) * _shake
