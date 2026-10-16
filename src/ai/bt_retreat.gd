class_name BTRetreat
extends BTAction
## 標的から離れる方向へ下がる。遊撃の獣が一撃のあとに使う（手前に BTAgentCheck("is_retreating") を置く）。
## 標的がいなければ基準点の方へ下がる。常に RUNNING。

@export var anchor_group: StringName = &"core"
@export var target_key: StringName = &"target"


func _tick(agent: Node, blackboard: Blackboard, delta: float) -> Status:
	var mover := agent as Node2D
	if mover == null or not mover.is_inside_tree():
		return Status.FAILURE
	var raw_target: Variant = blackboard.get_value(target_key)
	var away := Vector2.ZERO
	if is_instance_valid(raw_target) and raw_target is Node2D:
		away = mover.global_position - (raw_target as Node2D).global_position
	if away.length() < 1.0:
		var anchor := mover.get_tree().get_first_node_in_group(anchor_group) as Node2D
		away = (anchor.global_position - mover.global_position) if anchor != null else Vector2.DOWN
	mover.move_toward_point(mover.global_position + away.normalized() * 60.0, delta)
	return Status.RUNNING
