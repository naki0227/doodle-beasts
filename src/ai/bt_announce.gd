class_name BTAnnounce
extends BTAction
## いまの行動を agent に知らせる（agent.announce(text)）。常に SUCCESS。
## 枝の先頭に置くと、行動が切り替わったときに頭上へ言葉を出せる（同じ言葉の繰り返しは agent 側で抑える）。

@export var text: String = ""


func _tick(agent: Node, _blackboard: Blackboard, _delta: float) -> Status:
	if agent.has_method("announce"):
		agent.announce(text)
	return Status.SUCCESS
