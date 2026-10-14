class_name BTIsHpBelow
extends BTCondition
## agent の hp / max_hp が [member ratio] 未満か。逃走や増援呼びの条件に使う。

@export_range(0.0, 1.0) var ratio: float = 0.3


func _check(agent: Node, _blackboard: Blackboard) -> bool:
	if not ("hp" in agent and "max_hp" in agent):
		return false
	var max_hp: float = agent.max_hp
	if max_hp <= 0.0:
		return false
	return float(agent.hp) / max_hp < ratio
