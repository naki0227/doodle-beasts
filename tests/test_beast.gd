extends GameTestCase


func _body() -> Array[PackedVector2Array]:
	var circle := PackedVector2Array()
	for i in range(33):
		circle.append(Vector2(260, 260) + Vector2.RIGHT.rotated(TAU * i / 32) * 150.0)
	return [circle]


func _weapon() -> Array[PackedVector2Array]:
	var line := PackedVector2Array()
	for i in range(21):
		line.append(Vector2(20 + i * 22, 250))
	return [line]


func test_build_sets_stats_and_shape() -> void:
	var beast := (load("res://src/game/beast.tscn") as PackedScene).instantiate() as Beast
	add_to_scene(beast)
	beast.build(_body(), _weapon(), 3000.0)
	assert_true(beast.max_hp > 40.0)
	assert_eq(beast.hp, beast.max_hp)
	assert_eq(beast.weapon_kind, ShapeAnalyzer.Weapon.SPEAR)
	assert_true(beast.attack_range > 80.0, "槍は射程が長い")
	var collision := beast.get_node("CollisionPolygon2D") as CollisionPolygon2D
	assert_true(collision.polygon.size() >= 3)
	var visual := beast.get_node("Visual")
	assert_true(visual.get_child_count() >= 2, "体と武器の多角形がある")
	var rect := Rect2()
	for i in collision.polygon.size():
		rect = Rect2(collision.polygon[i], Vector2.ZERO) if i == 0 else rect.expand(collision.polygon[i])
	assert_true(absf(maxf(rect.size.x, rect.size.y) - beast.target_size) < 2.0, "長い辺が target_size に収まる")


func test_defense_reduces_damage() -> void:
	var beast := (load("res://src/game/beast.tscn") as PackedScene).instantiate() as Beast
	add_to_scene(beast)
	beast.build(_body(), [] as Array[PackedVector2Array], 3000.0)
	beast.defense = 0.5
	var before := beast.hp
	beast.take_damage(20.0)
	assert_true(is_equal_approx(before - beast.hp, 10.0))


func test_beast_tree_hunts_enemies() -> void:
	var beast := (load("res://src/game/beast.tscn") as PackedScene).instantiate() as Beast
	beast.position = Vector2.ZERO
	add_to_scene(beast)
	beast.build(_body(), _weapon(), 3000.0)
	var tree_node := beast.get_node("BehaviorTree") as BehaviorTree
	tree_node.enabled = false
	var enemy := BTTestStubs.FakeTarget.new()
	enemy.position = Vector2(30, 0)
	enemy.add_to_group(&"enemies")
	add_to_scene(enemy)
	assert_status(tree_node.tick(0.1), BTNode.Status.SUCCESS)
	assert_true(enemy.damage_taken > 0.0, "射程内の敵を殴る")
	assert_eq(beast.attacks_landed, 1)
