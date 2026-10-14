class_name BTInverter
extends BTDecorator
## 子の SUCCESS と FAILURE を入れ替える。RUNNING はそのまま。


func _tick(agent: Node, blackboard: Blackboard, delta: float) -> Status:
	var child := decorated_child()
	if child == null:
		return Status.FAILURE
	var status := child.tick(agent, blackboard, delta)
	match status:
		Status.SUCCESS:
			return Status.FAILURE
		Status.FAILURE:
			return Status.SUCCESS
		_:
			return Status.RUNNING
