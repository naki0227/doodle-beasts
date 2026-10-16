class_name BTAgentCheck
extends BTCondition
## agent のメソッド（引数なし、bool を返す）を呼んで条件にする。
## 例: is_retreating（遊撃の獣が身を引いている間）、is_whimsical（謎の武器の気まぐれ）、core_needs_repair（旅人）。
## メソッドがなければ false。

@export var method: StringName = &""


func _check(agent: Node, _blackboard: Blackboard) -> bool:
	return method != &"" and agent.has_method(method) and bool(agent.call(method))
