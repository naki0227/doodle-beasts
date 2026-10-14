class_name BTSelector
extends BTComposite
## 子を順番に評価し、最初に SUCCESS か RUNNING を返した子の結果を採用する。
## 全部 FAILURE なら FAILURE。
## 「できるなら攻撃、だめなら接近、それもだめなら拠点へ」のような優先度付きの分岐に使う。


func _tick(agent: Node, blackboard: Blackboard, delta: float) -> Status:
	var children := bt_children()
	for i in range(_start_index(), children.size()):
		var status := children[i].tick(agent, blackboard, delta)
		if status == Status.RUNNING:
			_mark_running(children, i)
			return Status.RUNNING
		if status == Status.SUCCESS:
			_finish(children)
			return Status.SUCCESS
	_finish(children)
	return Status.FAILURE
