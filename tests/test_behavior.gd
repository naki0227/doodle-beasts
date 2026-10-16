extends GameTestCase
## 描いた形 → 性格 → ビヘイビアツリー → 行動、のつながりを確かめる。戦闘は自動なので、ここがゲームの中心。

const S := BTNode.Status.SUCCESS
const F := BTNode.Status.FAILURE
const R := BTNode.Status.RUNNING
const W := ShapeAnalyzer.Weapon


func _circle(center: Vector2, radius: float, points: int = 32) -> PackedVector2Array:
	var stroke := PackedVector2Array()
	for i in range(points + 1):
		stroke.append(center + Vector2.RIGHT.rotated(TAU * i / points) * radius)
	return stroke


func _line(a: Vector2, b: Vector2, points: int = 20) -> PackedVector2Array:
	var stroke := PackedVector2Array()
	for i in range(points + 1):
		stroke.append(a.lerp(b, float(i) / points))
	return stroke


func _zigzag(origin: Vector2, teeth: int, width: float, height: float) -> PackedVector2Array:
	var stroke := PackedVector2Array()
	for i in range(teeth * 2 + 1):
		stroke.append(origin + Vector2(width * i / 2.0, height if i % 2 == 1 else 0.0))
	return stroke


func _spiky_body() -> Array[PackedVector2Array]:
	return [_zigzag(Vector2(0, 100), 14, 20, 60)]


func _round_body() -> Array[PackedVector2Array]:
	return [_circle(Vector2(200, 200), 150)]


func _wide_body() -> Array[PackedVector2Array]:
	return [_line(Vector2(0, 100), Vector2(400, 100)), _line(Vector2(0, 130), Vector2(400, 130))]


func _spear() -> Array[PackedVector2Array]:
	return [_line(Vector2(20, 250), Vector2(460, 250))]


func _beast(body: Array[PackedVector2Array], weapon: Array[PackedVector2Array], at: Vector2 = Vector2.ZERO) -> Beast:
	var beast := (load("res://src/game/beast.tscn") as PackedScene).instantiate() as Beast
	beast.position = at
	add_to_scene(beast)
	beast.build(body, weapon, 3000.0)
	(beast.get_node("BehaviorTree") as BehaviorTree).enabled = false
	return beast


func _target(pos: Vector2, group: StringName) -> BTTestStubs.FakeTarget:
	var t := BTTestStubs.FakeTarget.new()
	t.position = pos
	t.add_to_group(group)
	add_to_scene(t)
	return t


func _tree(beast: Beast) -> BehaviorTree:
	return beast.get_node("BehaviorTree") as BehaviorTree


# --- 形 → 性格・目 ---

func test_nature_follows_shape() -> void:
	assert_eq(ShapeAnalyzer.analyze_body(_spiky_body(), 3000.0)["nature"], "assault")
	assert_eq(ShapeAnalyzer.analyze_body(_wide_body(), 3000.0)["nature"], "skirmish")
	assert_eq(ShapeAnalyzer.analyze_body(_round_body(), 3000.0)["nature"], "guard")
	assert_eq(ShapeAnalyzer.analyze_body([] as Array[PackedVector2Array], 3000.0)["nature"], "none")


func test_eyes_widen_vision() -> void:
	var no_eyes := ShapeAnalyzer.analyze_body(_round_body(), 3000.0)
	var body := _round_body()
	body.append(_circle(Vector2(150, 170), 18, 16))
	body.append(_circle(Vector2(250, 170), 18, 16))
	var two_eyes := ShapeAnalyzer.analyze_body(body, 3000.0)
	assert_eq(no_eyes["eyes"], 0)
	assert_eq(two_eyes["eyes"], 2)
	assert_true(two_eyes["vision"] > no_eyes["vision"], "目が多いほど遠くまで見える")


func test_sample_doodle_has_two_eyes() -> void:
	assert_eq(ShapeAnalyzer.count_eyes(SampleDoodles.body()), 2)


func test_every_nature_has_label_and_description() -> void:
	for key in ShapeAnalyzer.NATURES:
		assert_true(ShapeAnalyzer.nature_label(key) != "")
		assert_true(ShapeAnalyzer.nature_description(key) != "")


# --- 性格 → ツリー → 行動 ---

func test_assault_charges_nearest_enemy() -> void:
	var beast := _beast(_spiky_body(), _spear())
	assert_eq(beast.nature, "assault")
	var enemy := _target(Vector2(40, 0), &"enemies")
	assert_status(_tree(beast).tick(0.1), S)
	assert_true(enemy.damage_taken > 0.0, "射程内の敵を殴る")


func test_guard_ignores_enemies_far_from_seed() -> void:
	var beast := _beast(_round_body(), _spear())
	assert_eq(beast.nature, "guard")
	_target(Vector2(0, 0), &"core")
	var far := _target(Vector2(320, 0), &"enemies")
	_tree(beast).tick(0.1)
	assert_true(_tree(beast).blackboard.get_value(&"target") != far, "駒から遠い敵は狙わない")
	assert_eq(far.damage_taken, 0.0)


func test_guard_strikes_enemy_near_seed() -> void:
	var beast := _beast(_round_body(), _spear())
	_target(Vector2(0, 0), &"core")
	var near := _target(Vector2(60, 0), &"enemies")
	assert_status(_tree(beast).tick(0.1), S)
	assert_true(near.damage_taken > 0.0)


func test_skirmish_targets_enemy_nearest_seed_and_retreats() -> void:
	# 目のない獣の見える範囲（230）に両方が入る位置に置く。
	var beast := _beast(_wide_body(), _spear(), Vector2(250, 0))
	assert_eq(beast.nature, "skirmish")
	_target(Vector2(0, 0), &"core")
	var close_to_beast := _target(Vector2(320, 0), &"enemies")
	var close_to_seed := _target(Vector2(120, 0), &"enemies")
	_tree(beast).tick(0.1)
	assert_eq(_tree(beast).blackboard.get_value(&"target"), close_to_seed, "駒に近い敵を先に狙う")
	assert_true(close_to_beast.damage_taken == 0.0)
	beast.attack(close_to_seed)
	assert_true(beast.is_retreating(), "一撃のあと身を引く")


func test_bulwark_taunts_and_steps_between() -> void:
	var body: Array[PackedVector2Array] = [_line(Vector2(0, 0), Vector2(0, 30))]
	var beast := _beast(body, [] as Array[PackedVector2Array], Vector2(0, 200))
	assert_eq(beast.nature, "bulwark")
	assert_true(beast.taunting, "敵を引きつける")
	assert_true(beast.has_node("BehaviorTree/Root/Hunt/Engage/Intercept"), "駒と敵のあいだに割り込む枝がある")


func test_bow_keeps_distance() -> void:
	var arc := PackedVector2Array()
	for i in range(41):
		var t := -PI / 2.0 + PI * i / 40.0
		arc.append(Vector2(100, 200) + Vector2(cos(t), sin(t)) * 150.0)
	var bow: Array[PackedVector2Array] = [arc, _line(arc[0], arc[arc.size() - 1])]
	var beast := _beast(_spiky_body(), bow)
	assert_eq(beast.weapon_kind, W.BOW)
	assert_true(beast.has_node("BehaviorTree/Root/Hunt/Engage/Strike/KeepDistance"))


func test_unknown_weapon_adds_whim_branch() -> void:
	var weapon: Array[PackedVector2Array] = [_zigzag(Vector2(0, 0), 2, 60, 100)]
	var beast := _beast(_spiky_body(), weapon)
	assert_eq(beast.weapon_kind, W.UNKNOWN)
	assert_true(beast.has_node("BehaviorTree/Root/Whim"))


func test_vision_limits_search() -> void:
	var beast := _beast(_spiky_body(), _spear())
	_target(Vector2(beast.vision + 50.0, 0), &"enemies")
	assert_status(_tree(beast).tick(0.1), F, "見えない敵には気づかない（駒もないので見張りにも行けない）")


func test_hammer_splashes_neighbours() -> void:
	var hammer: Array[PackedVector2Array] = [_line(Vector2(0, 100), Vector2(300, 100))]
	for i in range(6):
		hammer.append(_circle(Vector2(320, 100), 20 + i * 5))
	var beast := _beast(_spiky_body(), hammer)
	assert_eq(beast.weapon_kind, W.HAMMER)
	var main := _target(Vector2(40, 0), &"enemies")
	var side := _target(Vector2(80, 30), &"enemies")
	beast.attack(main)
	assert_true(side.damage_taken > 0.0, "まわりの敵にも当たる")
	assert_true(side.damage_taken < main.damage_taken)


func test_shield_reduces_damage_to_seed() -> void:
	var core := (load("res://src/game/core.tscn") as PackedScene).instantiate() as Core
	add_to_scene(core)
	core.take_damage(10.0)
	var unshielded := core.max_hp - core.hp
	core.hp = core.max_hp
	var shield: Array[PackedVector2Array] = [_circle(Vector2(200, 200), 120)]
	var beast := _beast(_spiky_body(), shield, core.position + Vector2(60, 0))
	assert_eq(beast.weapon_kind, W.SHIELD)
	core.take_damage(10.0)
	assert_true(core.max_hp - core.hp < unshielded, "盾の獣がそばにいると傷が減る")


# --- 葉ノード ---

func test_find_target_prefers_nearest_to_anchor() -> void:
	var agent := BTTestStubs.FakeAgent.new()
	agent.position = Vector2(300, 0)
	add_to_scene(agent)
	_target(Vector2(0, 0), &"core")
	var near_agent := _target(Vector2(320, 0), &"enemies")
	var near_core := _target(Vector2(60, 0), &"enemies")
	var find := BTFindTarget.new()
	find.radius = 1000.0
	find.anchor_group = &"core"
	find.nearest_to_anchor = true
	add_to_scene(find)
	var bb := Blackboard.new()
	assert_status(find.tick(agent, bb, 0.1), S)
	assert_eq(bb.get_value(&"target"), near_core)
	find.nearest_to_anchor = false
	find.tick(agent, bb, 0.1)
	assert_eq(bb.get_value(&"target"), near_agent)


func test_intercept_moves_between_anchor_and_target() -> void:
	var agent := BTTestStubs.FakeAgent.new()
	agent.speed = 10000.0
	agent.position = Vector2(0, 300)
	add_to_scene(agent)
	_target(Vector2(0, 0), &"core")
	var enemy := _target(Vector2(400, 0), &"enemies")
	var bb := Blackboard.new()
	bb.set_value(&"target", enemy)
	var intercept := BTIntercept.new()
	intercept.guard_distance = 100.0
	add_to_scene(intercept)
	intercept.tick(agent, bb, 0.1)
	assert_true(agent.global_position.distance_to(Vector2(100, 0)) < 2.0, "駒から敵へ 100 の位置に立つ")


func test_keep_distance_backs_away() -> void:
	var agent := BTTestStubs.FakeAgent.new()
	agent.position = Vector2(0, 0)
	add_to_scene(agent)
	var enemy := _target(Vector2(30, 0), &"enemies")
	var bb := Blackboard.new()
	bb.set_value(&"target", enemy)
	var keep := BTKeepDistance.new()
	keep.min_distance = 100.0
	add_to_scene(keep)
	assert_status(keep.tick(agent, bb, 0.5), R)
	assert_true(agent.global_position.x < 0.0, "敵と反対へ下がる")
	enemy.position = Vector2(300, 0)
	assert_status(keep.tick(agent, bb, 0.1), S)


func test_agent_check_calls_method() -> void:
	var check := BTAgentCheck.new()
	check.method = &"is_retreating"
	add_to_scene(check)
	var beast := _beast(_wide_body(), _spear())
	assert_status(check.tick(beast, Blackboard.new(), 0.1), F)
	beast.attack(_target(Vector2(20, 0), &"enemies"))
	assert_status(check.tick(beast, Blackboard.new(), 0.1), S)


# --- 旅人 ---

func test_wanderer_repairs_damaged_seed() -> void:
	var core := (load("res://src/game/core.tscn") as PackedScene).instantiate() as Core
	add_to_scene(core)
	core.hp = core.max_hp - 50.0
	var player := (load("res://src/game/player.tscn") as PackedScene).instantiate() as Player
	player.position = core.position + Vector2(40, 0)
	add_to_scene(player)
	var tree_node := player.get_node("BehaviorTree") as BehaviorTree
	tree_node.enabled = false
	var before := core.hp
	for i in range(10):
		tree_node.tick(0.1)
	assert_true(core.hp > before, "傷んだ駒を直す")


func test_wanderer_defends_seed_before_repairing() -> void:
	var core := (load("res://src/game/core.tscn") as PackedScene).instantiate() as Core
	add_to_scene(core)
	core.hp = core.max_hp - 50.0
	var player := (load("res://src/game/player.tscn") as PackedScene).instantiate() as Player
	player.position = core.position + Vector2(40, 0)
	add_to_scene(player)
	var enemy := _target(core.position + Vector2(70, 0), &"enemies")
	var tree_node := player.get_node("BehaviorTree") as BehaviorTree
	tree_node.enabled = false
	tree_node.tick(0.1)
	assert_true(enemy.damage_taken > 0.0, "駒に近い霜を先に払う")


# --- 波と記録帳の往復 ---

func test_wave_manager_pauses_after_clear_when_not_auto() -> void:
	var manager := WaveManager.new()
	manager.auto_continue = false
	add_to_scene(manager)
	var cleared: Array[int] = []
	manager.wave_cleared.connect(func(w: int) -> void: cleared.append(w))
	manager.start(3)
	manager.wave = 3
	manager.phase = WaveManager.Phase.FIGHTING
	manager.alive = 0
	manager._process(0.1)
	assert_eq(cleared, [3])
	assert_eq(manager.phase, WaveManager.Phase.IDLE, "描き直しのあいだは次の波を出さない")


func test_session_carries_run_between_waves() -> void:
	var session: Node = tree.root.get_node("GameSession")
	session.reset_run()
	assert_false(session.is_redraw())
	var first: float = session.draw_seconds()
	session.drawings += 1
	session.wave_cleared(1, 220.0)
	assert_eq(session.next_wave, 2)
	assert_eq(session.core_hp, 220.0)
	assert_true(session.ink_budget > 3000.0, "波を守るとインクが増える")
	assert_true(session.draw_seconds() < first, "描き直しは短い")
	session.reset_run()
