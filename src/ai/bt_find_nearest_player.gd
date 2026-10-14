class_name BTFindNearestPlayer
extends BTAction
## 索敵。[member radius] 以内で一番近いプレイヤーを blackboard の [member target_key] に入れる。
## 見つかれば SUCCESS、いなければ FAILURE。
## agent は Node2D であること。対象が is_targetable() を持つ場合、false のものは無視する。

@export var radius: float = 240.0
@export var group: StringName = &"players"
@export var target_key: StringName = &"target"


func _tick(agent: Node, blackboard: Blackboard, _delta: float) -> Status:
	var origin := agent as Node2D
	if origin == null or not origin.is_inside_tree():
		return Status.FAILURE
	var best: Node2D = null
	var best_distance_sq := radius * radius
	for candidate in origin.get_tree().get_nodes_in_group(group):
		var node := candidate as Node2D
		if node == null:
			continue
		if node.has_method("is_targetable") and not node.is_targetable():
			continue
		var distance_sq := origin.global_position.distance_squared_to(node.global_position)
		if distance_sq <= best_distance_sq:
			best = node
			best_distance_sq = distance_sq
	if best == null:
		return Status.FAILURE
	blackboard.set_value(target_key, best)
	return Status.SUCCESS
