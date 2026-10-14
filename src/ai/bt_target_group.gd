class_name BTTargetGroup
extends BTAction
## 指定グループの最初のノードを狙いにする。拠点（core）を狙うときに使う。
## 見つかれば SUCCESS、グループが空なら FAILURE。

@export var group: StringName = &"core"
@export var target_key: StringName = &"target"


func _tick(agent: Node, blackboard: Blackboard, _delta: float) -> Status:
	if not agent.is_inside_tree():
		return Status.FAILURE
	var target := agent.get_tree().get_first_node_in_group(group)
	if target == null:
		return Status.FAILURE
	blackboard.set_value(target_key, target)
	return Status.SUCCESS
