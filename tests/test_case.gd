class_name GameTestCase
extends RefCounted
## テストの基底。外部アドオンなしで動く最小限のアサーション。
## test_ で始まるメソッドが1つずつ実行される。

var tree: SceneTree
var failed := false
var messages: Array[String] = []

var _spawned: Array[Node] = []


func setup() -> void:
	pass


func teardown() -> void:
	for node in _spawned:
		if is_instance_valid(node):
			node.get_parent().remove_child(node)
			node.free()
	_spawned.clear()


## ルートにノードを追加し、teardown で片付ける。
func add_to_scene(node: Node) -> Node:
	tree.root.add_child(node)
	_spawned.append(node)
	return node


func fail(message: String) -> void:
	failed = true
	messages.append(message)


func assert_true(condition: bool, message: String = "") -> void:
	if not condition:
		fail("期待: true  %s" % message)


func assert_false(condition: bool, message: String = "") -> void:
	if condition:
		fail("期待: false  %s" % message)


func assert_eq(actual: Variant, expected: Variant, message: String = "") -> void:
	if actual != expected:
		fail("期待: %s  実際: %s  %s" % [str(expected), str(actual), message])


func assert_status(actual: BTNode.Status, expected: BTNode.Status, message: String = "") -> void:
	if actual != expected:
		fail("期待: %s  実際: %s  %s" % [BTNode.status_name(expected), BTNode.status_name(actual), message])
