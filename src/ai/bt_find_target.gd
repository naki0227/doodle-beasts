class_name BTFindTarget
extends BTAction
## 標的を探して blackboard の [member target_key] に入れる。見つかれば SUCCESS、いなければ FAILURE。
##
## - [member radius]: agent から見える範囲。
## - [member anchor_group] を指定すると、そのグループの最初のノード（金の駒など）を基準点にする。
##   [member anchor_radius] > 0 なら、基準点からその距離以内の標的だけを選ぶ（守護）。
##   [member nearest_to_anchor] が true なら、基準点にいちばん近い標的を選ぶ（先回り・立ちはだかり）。
## - 対象が is_targetable() を持つ場合、false のものは無視する。

@export var group: StringName = &"enemies"
@export var radius: float = 300.0
@export var anchor_group: StringName = &""
@export var anchor_radius: float = 0.0
@export var nearest_to_anchor: bool = false
@export var target_key: StringName = &"target"


func _tick(agent: Node, blackboard: Blackboard, _delta: float) -> Status:
	var origin := agent as Node2D
	if origin == null or not origin.is_inside_tree():
		return Status.FAILURE
	var anchor: Node2D = null
	if anchor_group != &"":
		anchor = origin.get_tree().get_first_node_in_group(anchor_group) as Node2D
	var best: Node2D = null
	var best_score := INF
	for candidate in origin.get_tree().get_nodes_in_group(group):
		var node := candidate as Node2D
		if node == null or node == origin:
			continue
		if node.has_method("is_targetable") and not node.is_targetable():
			continue
		if origin.global_position.distance_to(node.global_position) > radius:
			continue
		if anchor != null and anchor_radius > 0.0 and anchor.global_position.distance_to(node.global_position) > anchor_radius:
			continue
		var from := anchor.global_position if (anchor != null and nearest_to_anchor) else origin.global_position
		var score := from.distance_squared_to(node.global_position)
		if score < best_score:
			best = node
			best_score = score
	if best == null:
		blackboard.erase_value(target_key)
		return Status.FAILURE
	blackboard.set_value(target_key, best)
	return Status.SUCCESS
