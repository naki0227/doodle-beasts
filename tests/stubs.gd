class_name BTTestStubs
extends RefCounted
## テスト用の最小ノード群。


## 決められた順に結果を返す葉ノード。何回評価されたかも数える。
class ScriptedLeaf:
	extends BTNode
	var results: Array = []
	var ticks := 0
	var resets := 0

	static func make(sequence: Array) -> ScriptedLeaf:
		var leaf := ScriptedLeaf.new()
		leaf.results = sequence
		return leaf

	func _tick(_agent: Node, _blackboard: Blackboard, _delta: float) -> Status:
		var index := mini(ticks, results.size() - 1)
		ticks += 1
		return results[index]

	func _reset() -> void:
		resets += 1


## 物理なしで BTMoveToTarget / BTAttackTarget の契約を満たす仮の敵。
class FakeAgent:
	extends Node2D
	var speed := 100.0
	var moves := 0
	var stops := 0
	var attacks: Array[Node] = []
	var attack_ready := true
	var hp := 30.0
	var max_hp := 30.0

	func move_toward_point(point: Vector2, delta: float) -> void:
		moves += 1
		global_position = global_position.move_toward(point, speed * delta)

	func stop_moving() -> void:
		stops += 1

	func attack(target: Node) -> bool:
		if not attack_ready:
			return false
		attacks.append(target)
		return true


## 狙われる側。
class FakeTarget:
	extends Node2D
	var targetable := true
	var damage_taken := 0.0

	func is_targetable() -> bool:
		return targetable

	func take_damage(amount: float, _source: Node = null) -> void:
		damage_taken += amount
