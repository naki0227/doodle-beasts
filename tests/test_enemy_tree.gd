extends GameTestCase
## enemy.tscn に組んだ実際のツリーが、意図どおりに優先度を切り替えるかを検証する。
## 物理は動かさず、BehaviorTree.tick() を手で呼ぶ。

const S := BTNode.Status.SUCCESS
const R := BTNode.Status.RUNNING

var enemy: Enemy
var tree_node: BehaviorTree
var core: BTTestStubs.FakeTarget


func setup() -> void:
	var scene := load("res://src/game/enemy.tscn") as PackedScene
	enemy = scene.instantiate() as Enemy
	enemy.position = Vector2(0, 0)
	add_to_scene(enemy)
	tree_node = enemy.get_node("BehaviorTree") as BehaviorTree
	tree_node.enabled = false
	core = BTTestStubs.FakeTarget.new()
	core.position = Vector2(500, 0)
	core.add_to_group(&"core")
	add_to_scene(core)


func test_without_players_enemy_heads_for_core() -> void:
	assert_status(tree_node.tick(0.1), R)
	assert_eq(tree_node.blackboard.get_value(&"target"), core)


func test_nearby_player_takes_priority_over_core() -> void:
	var player := BTTestStubs.FakeTarget.new()
	player.position = Vector2(100, 0)
	player.add_to_group(&"players")
	add_to_scene(player)
	assert_status(tree_node.tick(0.1), R)
	assert_eq(tree_node.blackboard.get_value(&"target"), player)


func test_far_player_is_ignored() -> void:
	var player := BTTestStubs.FakeTarget.new()
	player.position = Vector2(0, 400)
	player.add_to_group(&"players")
	add_to_scene(player)
	tree_node.tick(0.1)
	assert_eq(tree_node.blackboard.get_value(&"target"), core)


func test_enemy_in_range_attacks_core() -> void:
	core.position = Vector2(50, 0)
	assert_status(tree_node.tick(0.1), S)
	assert_eq(core.damage_taken, enemy.damage)


func test_enemy_attack_respects_cooldown() -> void:
	core.position = Vector2(50, 0)
	tree_node.tick(0.1)
	assert_status(tree_node.tick(0.1), R, "2回目はクールダウン中")
	assert_eq(core.damage_taken, enemy.damage)
