class_name BTMoveToTarget
extends BTAction
## blackboard の狙いへ向かって移動する。
## [member stop_distance] 以内に着いたら SUCCESS、移動中は RUNNING、狙いが無効なら FAILURE。
##
## 移動の実体は agent 側の move_toward_point(point: Vector2, delta: float) に任せる。
## 物理（move_and_slide）を BT が知らずに済むので、テストでは単純な Node2D でも動く。

@export var stop_distance: float = 40.0
@export var target_key: StringName = &"target"


func _tick(agent: Node, blackboard: Blackboard, delta: float) -> Status:
	var mover := agent as Node2D
	var raw_target: Variant = blackboard.get_value(target_key)
	if mover == null or not is_instance_valid(raw_target):
		return Status.FAILURE
	var target := raw_target as Node2D
	if target == null:
		return Status.FAILURE
	if mover.global_position.distance_to(target.global_position) <= stop_distance:
		_stop(mover)
		return Status.SUCCESS
	if not mover.has_method("move_toward_point"):
		push_error("%s は move_toward_point() を持っていません" % mover.get_path())
		return Status.FAILURE
	mover.move_toward_point(target.global_position, delta)
	return Status.RUNNING


func _stop(mover: Node) -> void:
	if mover.has_method("stop_moving"):
		mover.stop_moving()
