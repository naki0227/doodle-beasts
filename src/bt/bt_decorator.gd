class_name BTDecorator
extends BTNode
## 子を1つだけ持ち、その結果を加工するノードの共通部分。


func decorated_child() -> BTNode:
	var children := bt_children()
	if children.is_empty():
		push_error("%s に子ノードがありません" % get_path())
		return null
	return children[0]
