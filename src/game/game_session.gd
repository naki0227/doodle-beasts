extends Node
## 描画フェーズと戦闘フェーズの間で、描いた線を受け渡す自動読み込みノード。
## 線のデータ（点の列）が正であり、ステータスも見た目もここから毎回導出する。

var body_strokes: Array[PackedVector2Array] = []
var weapon_strokes: Array[PackedVector2Array] = []
var ink_budget: float = 3000.0


func has_beast() -> bool:
	return not body_strokes.is_empty()


func store(body: Array[PackedVector2Array], weapon: Array[PackedVector2Array], budget: float) -> void:
	body_strokes = body.duplicate(true)
	weapon_strokes = weapon.duplicate(true)
	ink_budget = budget


func clear() -> void:
	body_strokes = []
	weapon_strokes = []
