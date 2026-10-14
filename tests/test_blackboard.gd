extends GameTestCase


func test_set_get_has_erase() -> void:
	var bb := Blackboard.new()
	assert_false(bb.has_value(&"target"))
	assert_eq(bb.get_value(&"target", "none"), "none")
	bb.set_value(&"target", 42)
	assert_true(bb.has_value(&"target"))
	assert_eq(bb.get_value(&"target"), 42)
	bb.erase_value(&"target")
	assert_false(bb.has_value(&"target"))


func test_clear() -> void:
	var bb := Blackboard.new()
	bb.set_value(&"a", 1)
	bb.set_value(&"b", 2)
	bb.clear()
	assert_false(bb.has_value(&"a"))
	assert_false(bb.has_value(&"b"))
