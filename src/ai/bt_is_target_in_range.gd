class_name BTIsTargetInRange
extends BTCondition
## blackboard の狙いが [member range] 以内にいるか。狙いが消えていれば false。

@export var range: float = 48.0
@export var target_key: StringName = &"target"


func _check(agent: Node, blackboard: Blackboard) -> bool:
	var origin := agent as Node2D
	var raw_target: Variant = blackboard.get_value(target_key)
	if origin == null or not is_instance_valid(raw_target):
		return false
	var target := raw_target as Node2D
	if target == null:
		return false
	return origin.global_position.distance_to(target.global_position) <= range
