class_name BTCooldown
extends BTDecorator
## 子が SUCCESS を返したあと、一定時間は子を評価せずに FAILURE を返す。
## 「突進は3秒に1回まで」のような使い方。
## 時間は BehaviorTree が blackboard の "time" に書き込む経過秒を使う。

@export var cooldown_seconds: float = 1.0

var _ready_at: float = -INF


func _reset() -> void:
	# クールダウンは枝が切り替わっても持ち越す（連打防止のため）。
	pass


func _tick(agent: Node, blackboard: Blackboard, delta: float) -> Status:
	var child := decorated_child()
	if child == null:
		return Status.FAILURE
	var now: float = blackboard.get_value(&"time", 0.0)
	if now < _ready_at:
		return Status.FAILURE
	var status := child.tick(agent, blackboard, delta)
	if status == Status.SUCCESS:
		_ready_at = now + cooldown_seconds
	return status
