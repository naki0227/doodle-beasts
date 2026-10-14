extends GameTestCase


func test_enemy_count_grows_by_two_each_wave() -> void:
	assert_eq(WaveManager.enemies_for_wave(1), 3)
	assert_eq(WaveManager.enemies_for_wave(2), 5)
	assert_eq(WaveManager.enemies_for_wave(5), 11)


func test_hp_multiplier_grows() -> void:
	assert_eq(WaveManager.hp_multiplier_for_wave(1), 1.0)
	assert_true(WaveManager.hp_multiplier_for_wave(3) > WaveManager.hp_multiplier_for_wave(2))


func test_random_edge_point_lies_on_arena_border() -> void:
	var manager := WaveManager.new()
	manager.random_seed = 7
	manager.arena = Rect2(0, 0, 100, 50)
	add_to_scene(manager)
	for i in range(50):
		var p := manager.random_edge_point()
		var on_border := is_equal_approx(p.x, 0.0) or is_equal_approx(p.x, 100.0) \
			or is_equal_approx(p.y, 0.0) or is_equal_approx(p.y, 50.0)
		assert_true(on_border, "外周上にない: %s" % str(p))
		assert_true(p.x >= 0.0 and p.x <= 100.0 and p.y >= 0.0 and p.y <= 50.0)


func test_start_enters_countdown_then_spawns() -> void:
	var manager := WaveManager.new()
	manager.random_seed = 1
	manager.first_wave_delay = 1.0
	manager.enemy_scene = load("res://src/game/enemy.tscn")
	var container := Node2D.new()
	add_to_scene(container)
	manager.enemy_container = container
	add_to_scene(manager)
	var started: Array[int] = []
	manager.wave_started.connect(func(w: int) -> void: started.append(w))
	manager.start()
	assert_eq(manager.phase, WaveManager.Phase.COUNTDOWN)
	manager._process(0.5)
	assert_eq(started.size(), 0)
	manager._process(0.6)
	assert_eq(started, [1])
	assert_eq(manager.phase, WaveManager.Phase.SPAWNING)
	manager._process(0.0)
	assert_eq(manager.alive, 1)
	assert_eq(container.get_child_count(), 1)
