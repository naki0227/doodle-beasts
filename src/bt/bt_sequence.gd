class_name BTSequence
extends BTComposite
## 子を順番に評価し、全部 SUCCESS なら SUCCESS。
## どれかが FAILURE を返した時点で FAILURE。RUNNING ならそこで止まって RUNNING。
## 「条件A → 条件B → 行動C」のような手順を書くのに使う。


func _tick(agent: Node, blackboard: Blackboard, delta: float) -> Status:
	var children := bt_children()
	for i in range(_start_index(), children.size()):
		var status := children[i].tick(agent, blackboard, delta)
		if status == Status.RUNNING:
			_mark_running(children, i)
			return Status.RUNNING
		if status == Status.FAILURE:
			_finish(children)
			return Status.FAILURE
	_finish(children)
	return Status.SUCCESS
