class_name Player
extends CharacterBody2D
## ローカル協力プレイの1人分。移動・近接攻撃・拠点修理ができる。
## HP が 0 になると倒れ、数秒後に拠点のそばで復活する（協力ゲームなので全滅しにくくする）。

signal hp_changed(hp: float, max_hp: float)
signal downed_changed(downed: bool)

@export_range(1, 2) var player_index: int = 1
@export var speed: float = 220.0
@export var max_hp: float = 100.0
@export var attack_damage: float = 15.0
@export var attack_range: float = 52.0
@export var attack_interval: float = 0.35
@export var repair_range: float = 90.0
@export var repair_per_second: float = 25.0
@export var respawn_seconds: float = 5.0
@export var color: Color = Color(0.4, 0.9, 0.5)

var hp: float
var downed := false
var facing := Vector2.RIGHT

var _attack_timer := 0.0
var _respawn_timer := 0.0
var _attack_flash := 0.0


func _ready() -> void:
	hp = max_hp
	add_to_group(&"players")
	hp_changed.emit(hp, max_hp)


func _physics_process(delta: float) -> void:
	_attack_timer = maxf(0.0, _attack_timer - delta)
	_attack_flash = maxf(0.0, _attack_flash - delta)
	if downed:
		_respawn_timer -= delta
		if _respawn_timer <= 0.0:
			_respawn()
		queue_redraw()
		return

	var prefix := "p%d_" % player_index
	var direction := Input.get_vector(prefix + "left", prefix + "right", prefix + "up", prefix + "down")
	velocity = direction * speed
	move_and_slide()
	if direction != Vector2.ZERO:
		facing = direction.normalized()

	if Input.is_action_pressed(prefix + "attack") and _attack_timer <= 0.0:
		_attack()
	if Input.is_action_pressed(prefix + "repair"):
		_repair(delta)
	queue_redraw()


func is_targetable() -> bool:
	return not downed


func take_damage(amount: float, _source: Node = null) -> void:
	if downed:
		return
	hp = maxf(0.0, hp - amount)
	hp_changed.emit(hp, max_hp)
	if hp <= 0.0:
		_down()


func _attack() -> void:
	_attack_timer = attack_interval
	_attack_flash = 0.12
	for node in get_tree().get_nodes_in_group(&"enemies"):
		var enemy := node as Node2D
		if enemy == null or not enemy.has_method("take_damage"):
			continue
		if global_position.distance_to(enemy.global_position) <= attack_range:
			enemy.take_damage(attack_damage, self)


func _repair(delta: float) -> void:
	var core := get_tree().get_first_node_in_group(&"core") as Core
	if core == null:
		return
	if global_position.distance_to(core.global_position) <= repair_range:
		core.repair(repair_per_second * delta)


func _down() -> void:
	downed = true
	_respawn_timer = respawn_seconds
	velocity = Vector2.ZERO
	set_collision_layer_value(1, false)
	set_collision_mask_value(2, false)
	downed_changed.emit(true)


func _respawn() -> void:
	downed = false
	hp = max_hp
	set_collision_layer_value(1, true)
	set_collision_mask_value(2, true)
	var core := get_tree().get_first_node_in_group(&"core") as Node2D
	if core != null:
		global_position = core.global_position + Vector2(-60.0 if player_index == 1 else 60.0, 0.0)
	hp_changed.emit(hp, max_hp)
	downed_changed.emit(false)


func _draw() -> void:
	var body_color := color
	if downed:
		body_color = color.darkened(0.6)
		body_color.a = 0.5
	draw_circle(Vector2.ZERO, 14.0, body_color)
	draw_line(Vector2.ZERO, facing * 20.0, Color.WHITE, 3.0)
	if _attack_flash > 0.0:
		draw_arc(Vector2.ZERO, attack_range, 0.0, TAU, 32, Color(1.0, 1.0, 1.0, 0.5), 2.0)
	var label := "P%d" % player_index
	draw_string(ThemeDB.fallback_font, Vector2(-9.0, -20.0), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color.WHITE)
