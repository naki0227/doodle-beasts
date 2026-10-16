class_name BTIntercept
extends BTAction
## 基準点（金の駒）と標的のあいだ、基準点から [member guard_distance] の位置に立ちはだかる。
## 着いたら止まって SUCCESS、移動中は RUNNING、標的か基準点がなければ FAILURE。

@export var anchor_group: StringName = &"core"
@export var guard_distance: float = 110.0
@export var stop_distance: float = 18.0
@export var target_key: StringName = &"target"


func _tick(agent: Node, blackboard: Blackboard, delta: float) -> Status:
	var mover := agent as Node2D
	var raw_target: Variant = blackboard.get_value(target_key)
	if mover == null or not mover.is_inside_tree() or not is_instance_valid(raw_target):
		return Status.FAILURE
	var target := raw_target as Node2D
	var anchor := mover.get_tree().get_first_node_in_group(anchor_group) as Node2D
	if target == null or anchor == null:
		return Status.FAILURE
	var to_target := target.global_position - anchor.global_position
	var distance := minf(guard_distance, to_target.length() * 0.7)
	var spot := anchor.global_position + to_target.normalized() * distance
	if mover.global_position.distance_to(spot) <= stop_distance:
		if mover.has_method("stop_moving"):
			mover.stop_moving()
		return Status.SUCCESS
	mover.move_toward_point(spot, delta)
	return Status.RUNNING
