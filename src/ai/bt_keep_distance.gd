class_name BTKeepDistance
extends BTAction
## 標的が [member min_distance] より近ければ離れる（RUNNING）。十分離れていれば SUCCESS。弓の獣が使う。

@export var min_distance: float = 110.0
@export var target_key: StringName = &"target"


func _tick(agent: Node, blackboard: Blackboard, delta: float) -> Status:
	var mover := agent as Node2D
	var raw_target: Variant = blackboard.get_value(target_key)
	if mover == null or not is_instance_valid(raw_target):
		return Status.FAILURE
	var target := raw_target as Node2D
	if target == null:
		return Status.FAILURE
	var away := mover.global_position - target.global_position
	if away.length() >= min_distance:
		return Status.SUCCESS
	if away.length() < 1.0:
		away = Vector2.RIGHT
	mover.move_toward_point(mover.global_position + away.normalized() * 60.0, delta)
	return Status.RUNNING
