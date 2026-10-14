extends GameTestCase

const S := BTNode.Status.SUCCESS
const F := BTNode.Status.FAILURE
const R := BTNode.Status.RUNNING

var agent: BTTestStubs.FakeAgent
var bb: Blackboard


func setup() -> void:
	agent = BTTestStubs.FakeAgent.new()
	agent.position = Vector2.ZERO
	add_to_scene(agent)
	bb = Blackboard.new()


func _target(pos: Vector2, group: StringName = &"players") -> BTTestStubs.FakeTarget:
	var t := BTTestStubs.FakeTarget.new()
	t.position = pos
	t.add_to_group(group)
	add_to_scene(t)
	return t


func test_find_nearest_player_picks_closest_in_radius() -> void:
	var far := _target(Vector2(300, 0))
	var near := _target(Vector2(50, 0))
	var leaf := BTFindNearestPlayer.new()
	leaf.radius = 200.0
	add_to_scene(leaf)
	assert_status(leaf.tick(agent, bb, 0.1), S)
	assert_eq(bb.get_value(&"target"), near)
	assert_true(bb.get_value(&"target") != far)


func test_find_nearest_player_fails_when_none_in_radius() -> void:
	_target(Vector2(500, 0))
	var leaf := BTFindNearestPlayer.new()
	leaf.radius = 100.0
	add_to_scene(leaf)
	assert_status(leaf.tick(agent, bb, 0.1), F)
	assert_false(bb.has_value(&"target"))


func test_find_nearest_player_ignores_downed_players() -> void:
	var downed := _target(Vector2(10, 0))
	downed.targetable = false
	var standing := _target(Vector2(80, 0))
	var leaf := BTFindNearestPlayer.new()
	leaf.radius = 200.0
	add_to_scene(leaf)
	assert_status(leaf.tick(agent, bb, 0.1), S)
	assert_eq(bb.get_value(&"target"), standing)


func test_target_group_picks_core() -> void:
	var core := _target(Vector2(0, 100), &"core")
	var leaf := BTTargetGroup.new()
	leaf.group = &"core"
	add_to_scene(leaf)
	assert_status(leaf.tick(agent, bb, 0.1), S)
	assert_eq(bb.get_value(&"target"), core)


func test_target_group_fails_when_group_empty() -> void:
	var leaf := BTTargetGroup.new()
	leaf.group = &"nothing_here"
	add_to_scene(leaf)
	assert_status(leaf.tick(agent, bb, 0.1), F)


func test_is_target_in_range() -> void:
	var t := _target(Vector2(30, 0))
	bb.set_value(&"target", t)
	var cond := BTIsTargetInRange.new()
	cond.range = 40.0
	add_to_scene(cond)
	assert_status(cond.tick(agent, bb, 0.1), S)
	cond.range = 20.0
	assert_status(cond.tick(agent, bb, 0.1), F)


func test_is_target_in_range_fails_without_target() -> void:
	var cond := BTIsTargetInRange.new()
	add_to_scene(cond)
	assert_status(cond.tick(agent, bb, 0.1), F)


func test_move_to_target_runs_until_within_stop_distance() -> void:
	var t := _target(Vector2(100, 0))
	bb.set_value(&"target", t)
	var move := BTMoveToTarget.new()
	move.stop_distance = 60.0
	add_to_scene(move)
	agent.speed = 50.0
	assert_status(move.tick(agent, bb, 1.0), R, "距離 100 は停止距離の外")
	assert_eq(agent.global_position, Vector2(50, 0))
	assert_status(move.tick(agent, bb, 0.5), S, "距離 50 は停止距離の内")
	assert_eq(agent.stops, 1)
	assert_eq(agent.moves, 1)


func test_move_to_target_fails_when_target_gone() -> void:
	var t := _target(Vector2(100, 0))
	bb.set_value(&"target", t)
	t.get_parent().remove_child(t)
	t.free()
	var move := BTMoveToTarget.new()
	add_to_scene(move)
	assert_status(move.tick(agent, bb, 0.1), F)


func test_attack_target_success_then_running_on_cooldown() -> void:
	var t := _target(Vector2(10, 0))
	bb.set_value(&"target", t)
	var attack := BTAttackTarget.new()
	add_to_scene(attack)
	assert_status(attack.tick(agent, bb, 0.1), S)
	assert_eq(agent.attacks.size(), 1)
	agent.attack_ready = false
	assert_status(attack.tick(agent, bb, 0.1), R, "クールダウン中は RUNNING")
	assert_eq(agent.attacks.size(), 1)


func test_is_hp_below() -> void:
	var cond := BTIsHpBelow.new()
	cond.ratio = 0.5
	add_to_scene(cond)
	agent.hp = 20.0
	agent.max_hp = 30.0
	assert_status(cond.tick(agent, bb, 0.1), F)
	agent.hp = 10.0
	assert_status(cond.tick(agent, bb, 0.1), S)
