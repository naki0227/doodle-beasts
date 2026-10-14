class_name BTCondition
extends BTNode
## 真偽を判定するだけの葉ノード。[method _check] を上書きする。
## 副作用を持たせない（状態を変えるものは BTAction にする）。


func _tick(agent: Node, blackboard: Blackboard, _delta: float) -> Status:
	return Status.SUCCESS if _check(agent, blackboard) else Status.FAILURE


func _check(_agent: Node, _blackboard: Blackboard) -> bool:
	push_error("%s は _check() を実装していません" % get_path())
	return false
