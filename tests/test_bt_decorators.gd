extends GameTestCase

const S := BTNode.Status.SUCCESS
const F := BTNode.Status.FAILURE
const R := BTNode.Status.RUNNING

var agent: Node
var bb: Blackboard


func setup() -> void:
	agent = Node.new()
	add_to_scene(agent)
	bb = Blackboard.new()


func test_inverter_flips_success_and_failure() -> void:
	var inv := BTInverter.new()
	inv.add_child(BTTestStubs.ScriptedLeaf.make([S, F, R]))
	add_to_scene(inv)
	assert_status(inv.tick(agent, bb, 0.1), F)
	assert_status(inv.tick(agent, bb, 0.1), S)
	assert_status(inv.tick(agent, bb, 0.1), R, "RUNNING はそのまま")


func test_cooldown_blocks_after_success() -> void:
	var cd := BTCooldown.new()
	cd.cooldown_seconds = 2.0
	var leaf := BTTestStubs.ScriptedLeaf.make([S])
	cd.add_child(leaf)
	add_to_scene(cd)
	bb.set_value(&"time", 0.0)
	assert_status(cd.tick(agent, bb, 0.1), S)
	bb.set_value(&"time", 1.0)
	assert_status(cd.tick(agent, bb, 0.1), F, "クールダウン中は FAILURE")
	assert_eq(leaf.ticks, 1, "クールダウン中は子を評価しない")
	bb.set_value(&"time", 2.0)
	assert_status(cd.tick(agent, bb, 0.1), S)
	assert_eq(leaf.ticks, 2)


func test_cooldown_does_not_start_on_failure() -> void:
	var cd := BTCooldown.new()
	cd.cooldown_seconds = 5.0
	var leaf := BTTestStubs.ScriptedLeaf.make([F, S])
	cd.add_child(leaf)
	add_to_scene(cd)
	bb.set_value(&"time", 0.0)
	assert_status(cd.tick(agent, bb, 0.1), F)
	bb.set_value(&"time", 0.1)
	assert_status(cd.tick(agent, bb, 0.1), S, "子が失敗してもクールダウンは始まらない")
