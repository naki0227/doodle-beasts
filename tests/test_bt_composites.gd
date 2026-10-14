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


func _leaf(sequence: Array) -> BTTestStubs.ScriptedLeaf:
	return BTTestStubs.ScriptedLeaf.make(sequence)


func test_sequence_all_success() -> void:
	var seq := BTSequence.new()
	var a := _leaf([S])
	var b := _leaf([S])
	seq.add_child(a)
	seq.add_child(b)
	add_to_scene(seq)
	assert_status(seq.tick(agent, bb, 0.1), S)
	assert_eq(a.ticks, 1)
	assert_eq(b.ticks, 1)


func test_sequence_stops_at_first_failure() -> void:
	var seq := BTSequence.new()
	var a := _leaf([F])
	var b := _leaf([S])
	seq.add_child(a)
	seq.add_child(b)
	add_to_scene(seq)
	assert_status(seq.tick(agent, bb, 0.1), F)
	assert_eq(b.ticks, 0, "失敗の後ろの子は評価しない")


func test_sequence_running_propagates() -> void:
	var seq := BTSequence.new()
	var a := _leaf([S])
	var b := _leaf([R, R, S])
	var c := _leaf([S])
	seq.add_child(a)
	seq.add_child(b)
	seq.add_child(c)
	add_to_scene(seq)
	assert_status(seq.tick(agent, bb, 0.1), R)
	assert_eq(c.ticks, 0, "RUNNING の後ろの子は評価しない")
	assert_status(seq.tick(agent, bb, 0.1), R)
	assert_status(seq.tick(agent, bb, 0.1), S)
	assert_eq(c.ticks, 1)


func test_sequence_reactive_reevaluates_from_start() -> void:
	var seq := BTSequence.new()
	seq.remember_running = false
	var a := _leaf([S])
	var b := _leaf([R])
	seq.add_child(a)
	seq.add_child(b)
	add_to_scene(seq)
	seq.tick(agent, bb, 0.1)
	seq.tick(agent, bb, 0.1)
	assert_eq(a.ticks, 2, "反応型は毎回先頭から評価し直す")


func test_sequence_with_memory_resumes_running_child() -> void:
	var seq := BTSequence.new()
	seq.remember_running = true
	var a := _leaf([S])
	var b := _leaf([R, S])
	seq.add_child(a)
	seq.add_child(b)
	add_to_scene(seq)
	assert_status(seq.tick(agent, bb, 0.1), R)
	assert_status(seq.tick(agent, bb, 0.1), S)
	assert_eq(a.ticks, 1, "記憶ありは RUNNING だった子から再開する")


func test_sequence_resets_running_child_when_earlier_child_fails() -> void:
	var seq := BTSequence.new()
	var a := _leaf([S, F])
	var b := _leaf([R])
	seq.add_child(a)
	seq.add_child(b)
	add_to_scene(seq)
	assert_status(seq.tick(agent, bb, 0.1), R)
	assert_status(seq.tick(agent, bb, 0.1), F)
	assert_true(b.resets >= 1, "中断された RUNNING の子は reset される")


func test_selector_first_success_wins() -> void:
	var sel := BTSelector.new()
	var a := _leaf([F])
	var b := _leaf([S])
	var c := _leaf([S])
	sel.add_child(a)
	sel.add_child(b)
	sel.add_child(c)
	add_to_scene(sel)
	assert_status(sel.tick(agent, bb, 0.1), S)
	assert_eq(c.ticks, 0, "成功した後ろの子は評価しない")


func test_selector_all_failure() -> void:
	var sel := BTSelector.new()
	sel.add_child(_leaf([F]))
	sel.add_child(_leaf([F]))
	add_to_scene(sel)
	assert_status(sel.tick(agent, bb, 0.1), F)


func test_selector_higher_priority_interrupts_running_branch() -> void:
	# 1回目: a が失敗して b が RUNNING。2回目: a が成功したので b は捨てられる。
	var sel := BTSelector.new()
	var a := _leaf([F, S])
	var b := _leaf([R, R])
	sel.add_child(a)
	sel.add_child(b)
	add_to_scene(sel)
	assert_status(sel.tick(agent, bb, 0.1), R)
	assert_status(sel.tick(agent, bb, 0.1), S)
	assert_eq(b.ticks, 1)
	assert_true(b.resets >= 1, "優先度の高い枝に奪われた子は reset される")


func test_behavior_tree_runs_root_and_tracks_time() -> void:
	var tree_node := BehaviorTree.new()
	tree_node.agent = agent
	tree_node.enabled = false
	var root := BTSequence.new()
	var leaf := _leaf([S])
	root.add_child(leaf)
	tree_node.add_child(root)
	add_to_scene(tree_node)
	assert_status(tree_node.tick(0.5), S)
	assert_status(tree_node.tick(0.25), S)
	assert_eq(leaf.ticks, 2)
	assert_eq(tree_node.elapsed, 0.75)
	assert_eq(tree_node.blackboard.get_value(&"time"), 0.75)


func test_behavior_tree_without_root_fails() -> void:
	var tree_node := BehaviorTree.new()
	tree_node.agent = agent
	tree_node.enabled = false
	add_to_scene(tree_node)
	assert_status(tree_node.tick(0.1), F)
