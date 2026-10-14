class_name BTNode
extends Node
## ビヘイビアツリーを構成する全ノードの基底クラス。
##
## ツリーはシーンツリーそのものとして組む。BehaviorTree ノードの下に
## Selector / Sequence / Condition / Action を子ノードとして並べると、
## エディタのシーンドックでそのまま木構造を編集できる。
##
## 各ノードは [method tick] で評価され、SUCCESS / FAILURE / RUNNING のどれかを返す。
## RUNNING は「まだ途中。次のフレームも続けて評価してほしい」という意味。

enum Status { SUCCESS, FAILURE, RUNNING }


## 1回分の評価。外から呼ぶのはこちら。
func tick(agent: Node, blackboard: Blackboard, delta: float) -> Status:
	return _tick(agent, blackboard, delta)


## 各ノードが上書きする本体。
func _tick(_agent: Node, _blackboard: Blackboard, _delta: float) -> Status:
	push_error("%s は _tick() を実装していません" % get_path())
	return Status.FAILURE


## 途中状態を捨てて初期状態に戻す。親が別の枝に切り替えたときに呼ばれる。
func reset() -> void:
	for child in bt_children():
		child.reset()
	_reset()


## 各ノードが必要なら上書きする。
func _reset() -> void:
	pass


## 子ノードのうち BTNode であるものだけを順番どおりに返す。
func bt_children() -> Array[BTNode]:
	var result: Array[BTNode] = []
	for child in get_children():
		if child is BTNode:
			result.append(child)
	return result


static func status_name(status: Status) -> String:
	match status:
		Status.SUCCESS:
			return "SUCCESS"
		Status.FAILURE:
			return "FAILURE"
		_:
			return "RUNNING"
