class_name Core
extends StaticBody2D
## 全員で守る拠点。HP が 0 になるとゲームオーバー。プレイヤーが近くで修理できる。

signal hp_changed(hp: float, max_hp: float)
signal destroyed

@export var max_hp: float = 300.0
@export var radius: float = 40.0

var hp: float
var _destroyed := false


func _ready() -> void:
	hp = max_hp
	add_to_group(&"core")
	hp_changed.emit(hp, max_hp)


func take_damage(amount: float, _source: Node = null) -> void:
	if _destroyed:
		return
	hp = maxf(0.0, hp - amount)
	hp_changed.emit(hp, max_hp)
	queue_redraw()
	if hp <= 0.0:
		_destroyed = true
		destroyed.emit()


func repair(amount: float) -> void:
	if _destroyed:
		return
	hp = minf(max_hp, hp + amount)
	hp_changed.emit(hp, max_hp)
	queue_redraw()


func is_destroyed() -> bool:
	return _destroyed


func _draw() -> void:
	var ratio := hp / max_hp if max_hp > 0.0 else 0.0
	draw_circle(Vector2.ZERO, radius + 6.0, Color(0.2, 0.25, 0.35))
	draw_circle(Vector2.ZERO, radius, Color(0.35, 0.65, 1.0).lerp(Color(0.6, 0.2, 0.2), 1.0 - ratio))
	draw_arc(Vector2.ZERO, radius + 10.0, -PI / 2.0, -PI / 2.0 + TAU * ratio, 48, Color(0.8, 0.95, 1.0), 4.0)
