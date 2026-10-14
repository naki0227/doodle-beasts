class_name BehaviorTree
extends Node
## ビヘイビアツリーの実行器。この直下に置いた最初の BTNode をルートとして評価する。
##
## [member agent] が行動の主体（敵キャラなど）。各葉ノードは agent のメソッドを呼んで動かす。
## 毎物理フレーム評価する。重くなってきたら [member tick_interval] を上げて間引く。

@export var agent: Node
## 0 なら毎物理フレーム評価。0.1 なら 0.1 秒ごと。
@export var tick_interval: float = 0.0
@export var enabled: bool = true

var blackboard := Blackboard.new()
## ツリーを動かし始めてからの経過秒。BTCooldown などが使う。
var elapsed: float = 0.0
var last_status: BTNode.Status = BTNode.Status.FAILURE

var _accumulated: float = 0.0


func _ready() -> void:
	if agent == null:
		agent = get_parent()


func _physics_process(delta: float) -> void:
	if not enabled:
		return
	_accumulated += delta
	if _accumulated >= tick_interval:
		tick(_accumulated)
		_accumulated = 0.0


func root_node() -> BTNode:
	var children := bt_children_of(self)
	return children[0] if not children.is_empty() else null


## 1回評価する。テストやターン制から手動で呼ぶこともできる。
func tick(delta: float) -> BTNode.Status:
	elapsed += delta
	blackboard.set_value(&"time", elapsed)
	var root := root_node()
	if root == null or agent == null:
		last_status = BTNode.Status.FAILURE
		return last_status
	last_status = root.tick(agent, blackboard, delta)
	return last_status


func reset() -> void:
	var root := root_node()
	if root != null:
		root.reset()


static func bt_children_of(node: Node) -> Array[BTNode]:
	var result: Array[BTNode] = []
	for child in node.get_children():
		if child is BTNode:
			result.append(child)
	return result
