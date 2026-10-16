class_name BTRepairCore
extends BTAction
## 金の駒のそばへ行って直す。直し終わったら SUCCESS、移動中・修理中は RUNNING、駒がなければ FAILURE。
## agent には repair_core(delta) と repair_range が要る。

@export var anchor_group: StringName = &"core"


func _tick(agent: Node, _blackboard: Blackboard, delta: float) -> Status:
	var mover := agent as Node2D
	if mover == null or not mover.is_inside_tree():
		return Status.FAILURE
	var core := mover.get_tree().get_first_node_in_group(anchor_group) as Node2D
	if core == null:
		return Status.FAILURE
	if core.hp >= core.max_hp:
		return Status.SUCCESS
	var reach: float = mover.repair_range - 16.0
	if mover.global_position.distance_to(core.global_position) > reach:
		mover.move_toward_point(core.global_position + (mover.global_position - core.global_position).normalized() * reach * 0.7, delta)
		return Status.RUNNING
	mover.stop_moving()
	mover.repair_core(delta)
	return Status.RUNNING
