class_name Enemy
extends CharacterBody2D
## CPU 側の敵。何をするかは子の BehaviorTree が決める。
## このクラスは「できること」（移動・攻撃・被弾）だけを提供し、判断は BT の葉ノードに任せる。
##
## BT の葉ノードから呼ばれる契約:
##   move_toward_point(point: Vector2, delta: float)
##   stop_moving()
##   attack(target: Node) -> bool   当たれば true、クールダウン中なら false
##   hp / max_hp                    BTIsHpBelow が読む

signal died(enemy: Enemy)

@export var max_hp: float = 30.0
@export var speed: float = 95.0
@export var damage: float = 8.0
@export var attack_interval: float = 1.0
@export var color: Color = Color(0.9, 0.35, 0.3)

var hp: float
var _attack_timer := 0.0
var _hit_flash := 0.0


func _ready() -> void:
	hp = max_hp
	add_to_group(&"enemies")


func _physics_process(delta: float) -> void:
	_attack_timer = maxf(0.0, _attack_timer - delta)
	_hit_flash = maxf(0.0, _hit_flash - delta)
	queue_redraw()


func move_toward_point(point: Vector2, _delta: float) -> void:
	velocity = (point - global_position).normalized() * speed
	move_and_slide()


func stop_moving() -> void:
	velocity = Vector2.ZERO


func attack(target: Node) -> bool:
	if _attack_timer > 0.0:
		return false
	_attack_timer = attack_interval
	if target.has_method("take_damage"):
		target.take_damage(damage, self)
	return true


func take_damage(amount: float, _source: Node = null) -> void:
	hp -= amount
	_hit_flash = 0.1
	if hp <= 0.0:
		die()


func die() -> void:
	died.emit(self)
	queue_free()


func _draw() -> void:
	draw_circle(Vector2.ZERO, 12.0, Color.WHITE if _hit_flash > 0.0 else color)
	var ratio := clampf(hp / max_hp, 0.0, 1.0) if max_hp > 0.0 else 0.0
	draw_rect(Rect2(-12.0, -20.0, 24.0, 3.0), Color(0.1, 0.1, 0.1))
	draw_rect(Rect2(-12.0, -20.0, 24.0 * ratio, 3.0), Color(1.0, 0.6, 0.2))
