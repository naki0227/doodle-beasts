class_name BTMoveToAnchor
extends BTAction
## 基準点（金の駒など）のそばの決まった位置へ戻る。着いたら止まって SUCCESS、移動中は RUNNING。
## 基準点がなければ FAILURE。offset は基準点からのずれ（持ち場）。

@export var anchor_group: StringName = &"core"
@export var offset: Vector2 = Vector2(0.0, 90.0)
@export var stop_distance: float = 24.0


func _tick(agent: Node, _blackboard: Blackboard, delta: float) -> Status:
	var mover := agent as Node2D
	if mover == null or not mover.is_inside_tree():
		return Status.FAILURE
	var anchor := mover.get_tree().get_first_node_in_group(anchor_group) as Node2D
	if anchor == null:
		return Status.FAILURE
	var spot := anchor.global_position + offset
	if mover.global_position.distance_to(spot) <= stop_distance:
		if mover.has_method("stop_moving"):
			mover.stop_moving()
		return Status.SUCCESS
	mover.move_toward_point(spot, delta)
	return Status.RUNNING
