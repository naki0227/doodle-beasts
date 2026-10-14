class_name BTAttackTarget
extends BTAction
## blackboard の狙いを攻撃する。agent 側の attack(target) -> bool を呼ぶ。
## 当たれば SUCCESS、クールダウン中（false）なら RUNNING、狙いが無効なら FAILURE。
## 射程判定はこのノードではなく、手前に BTIsTargetInRange を置いて行う。

@export var target_key: StringName = &"target"


func _tick(agent: Node, blackboard: Blackboard, _delta: float) -> Status:
	var raw_target: Variant = blackboard.get_value(target_key)
	if not is_instance_valid(raw_target):
		return Status.FAILURE
	var target := raw_target as Node
	if not agent.has_method("attack"):
		push_error("%s は attack() を持っていません" % agent.get_path())
		return Status.FAILURE
	if agent.has_method("stop_moving"):
		agent.stop_moving()
	return Status.SUCCESS if agent.attack(target) else Status.RUNNING
