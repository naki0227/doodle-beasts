class_name BTWander
extends BTAction
## 基準点のまわりを気ままに歩く。目的地に着くたび、次の目的地を選ぶ。常に RUNNING。

@export var anchor_group: StringName = &"core"
@export var radius: float = 220.0
@export var spot_key: StringName = &"wander_spot"

var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()


func _tick(agent: Node, blackboard: Blackboard, delta: float) -> Status:
	var mover := agent as Node2D
	if mover == null or not mover.is_inside_tree():
		return Status.FAILURE
	var spot: Variant = blackboard.get_value(spot_key)
	if spot == null or mover.global_position.distance_to(spot) < 20.0:
		var anchor := mover.get_tree().get_first_node_in_group(anchor_group) as Node2D
		var center := anchor.global_position if anchor != null else mover.global_position
		spot = center + Vector2.RIGHT.rotated(_rng.randf_range(0.0, TAU)) * _rng.randf_range(radius * 0.3, radius)
		blackboard.set_value(spot_key, spot)
	mover.move_toward_point(spot, delta)
	return Status.RUNNING
