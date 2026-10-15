class_name Player
extends CharacterBody2D
## ローカル協力プレイの 1 人分。プレイヤーは「鉛筆」。消しゴムを突いて倒し、お城の絵を描き直して修理する。
## HP が 0 になると倒れ、数秒後にお城のそばで復活する（協力ゲームなので全滅しにくくする）。

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
@export var color: Color = DoodleStyle.P1

var hp: float
var downed := false
var facing := Vector2.RIGHT

var _attack_timer := 0.0
var _respawn_timer := 0.0
var _slash := 0.0
var _slash_dir := Vector2.RIGHT
var _hit_flash := 0.0
var _t := 0.0
var _moving := false
var _repairing := false
var _repair_tick := 0.0
var _blink := 2.0


func _ready() -> void:
	hp = max_hp
	color = DoodleStyle.PLAYER_COLORS.get(player_index, color)
	add_to_group(&"players")
	material = DoodleStyle.doodle_material(0.8, 1.0)
	hp_changed.emit(hp, max_hp)


func _physics_process(delta: float) -> void:
	_t += delta
	_attack_timer = maxf(0.0, _attack_timer - delta)
	_slash = maxf(0.0, _slash - delta)
	_hit_flash = maxf(0.0, _hit_flash - delta)
	_blink -= delta
	if _blink < -0.12:
		_blink = randf_range(1.5, 4.0)
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
	_moving = direction != Vector2.ZERO
	if _moving:
		facing = direction.normalized()

	if Input.is_action_pressed(prefix + "attack") and _attack_timer <= 0.0:
		_attack()
	_repairing = false
	if Input.is_action_pressed(prefix + "repair"):
		_repair(delta)
	queue_redraw()


func is_targetable() -> bool:
	return not downed


func take_damage(amount: float, _source: Node = null) -> void:
	if downed:
		return
	hp = maxf(0.0, hp - amount)
	_hit_flash = 0.12
	hp_changed.emit(hp, max_hp)
	Fx.damage_number(global_position + Vector2(0.0, -76.0), amount, DoodleStyle.HP_LOW)
	if hp <= 0.0:
		_down()


func _attack() -> void:
	_attack_timer = attack_interval
	_slash = 0.16
	_slash_dir = facing
	var hit_any := false
	for node in get_tree().get_nodes_in_group(&"enemies"):
		var enemy := node as Node2D
		if enemy == null or not enemy.has_method("take_damage"):
			continue
		if global_position.distance_to(enemy.global_position) <= attack_range:
			enemy.take_damage(attack_damage, self)
			Fx.burst(enemy.global_position + Vector2(0.0, -16.0), color, 0.7, 5)
			hit_any = true
	if hit_any:
		Fx.pop_text(global_position + facing * 30.0 + Vector2(0.0, -50.0), "ツン", color, 22)
		Fx.shake(2.0)


func _repair(delta: float) -> void:
	var core := get_tree().get_first_node_in_group(&"core") as Core
	if core == null:
		return
	if global_position.distance_to(core.global_position) > repair_range or core.hp >= core.max_hp:
		return
	_repairing = true
	core.repair(repair_per_second * delta)
	_repair_tick -= delta
	if _repair_tick <= 0.0:
		_repair_tick = 0.35
		var spot := core.global_position + Vector2(randf_range(-40.0, 40.0), randf_range(-70.0, 10.0))
		Fx.pop_text(spot, "+", DoodleStyle.HP_GOOD, 26)


func _down() -> void:
	downed = true
	_respawn_timer = respawn_seconds
	velocity = Vector2.ZERO
	set_collision_layer_value(1, false)
	set_collision_mask_value(2, false)
	Fx.burst(global_position + Vector2(0.0, -30.0), color, 1.2, 12)
	Fx.pop_text(global_position + Vector2(0.0, -70.0), "ポキッ", DoodleStyle.HP_LOW, 26)
	Fx.shake(6.0)
	downed_changed.emit(true)


func _respawn() -> void:
	downed = false
	hp = max_hp
	set_collision_layer_value(1, true)
	set_collision_mask_value(2, true)
	var core := get_tree().get_first_node_in_group(&"core") as Node2D
	if core != null:
		global_position = core.global_position + Vector2(-80.0 if player_index == 1 else 80.0, 30.0)
	Fx.burst(global_position + Vector2(0.0, -30.0), color, 1.0, 8)
	hp_changed.emit(hp, max_hp)
	downed_changed.emit(false)


func _draw() -> void:
	DoodleStyle.draw_shadow(self, Vector2(0.0, 2.0), Vector2(13.0, 4.5))
	var body_color := color
	if downed:
		body_color = color.lerp(Color(0.75, 0.75, 0.75), 0.7)
	elif _hit_flash > 0.0:
		body_color = color.lerp(Color.WHITE, 0.7)

	if _slash > 0.0:
		var k := _slash / 0.16
		var center := Vector2(0.0, -26.0)
		var angle := _slash_dir.angle()
		var sweep := 1.1
		var start := angle - sweep + (1.0 - k) * 0.6
		draw_arc(center, attack_range * 0.8, start, start + sweep * 2.0 * (1.2 - k), 18, Color(color, k), 7.0, true)
		draw_arc(center, attack_range * 0.8 + 5.0, start, start + sweep * 2.0 * (1.2 - k), 18, Color(DoodleStyle.INK, k * 0.8), 2.0, true)

	var hop := 0.0
	var tilt := 0.0
	if downed:
		tilt = PI / 2.0
	else:
		if _moving:
			hop = -absf(sin(_t * 14.0)) * 6.0
			tilt = facing.x * 0.18
		if _repairing:
			tilt = sin(_t * 30.0) * 0.25
		if _slash > 0.0:
			tilt += _slash_dir.x * 0.5 * (_slash / 0.16)
	draw_set_transform(Vector2(0.0, hop), tilt, Vector2.ONE)

	# 芯と削った木
	DoodleStyle.draw_shape(self, PackedVector2Array([Vector2(0.0, 0.0), Vector2(-4.0, -8.0), Vector2(4.0, -8.0)]), color.darkened(0.45), 2.0)
	DoodleStyle.draw_shape(self, PackedVector2Array([
		Vector2(-4.0, -8.0), Vector2(4.0, -8.0), Vector2(10.0, -21.0), Vector2(-10.0, -21.0)]), Color("f1d3a0"), 2.0)
	# 軸
	DoodleStyle.draw_shape(self, PackedVector2Array([
		Vector2(-10.0, -21.0), Vector2(10.0, -21.0), Vector2(10.0, -58.0), Vector2(-10.0, -58.0)]), body_color, 2.5)
	draw_line(Vector2(-3.5, -22.0), Vector2(-3.5, -57.0), Color(body_color.darkened(0.25), 0.9), 2.0)
	draw_line(Vector2(3.5, -22.0), Vector2(3.5, -57.0), Color(body_color.darkened(0.25), 0.9), 2.0)
	# 金具と消しゴム
	DoodleStyle.draw_shape(self, PackedVector2Array([
		Vector2(-10.5, -58.0), Vector2(10.5, -58.0), Vector2(10.5, -65.0), Vector2(-10.5, -65.0)]), Color("c8ccd3"), 2.0)
	DoodleStyle.draw_shape(self, DoodleStyle.rounded_rect(Rect2(-9.0, -74.0, 18.0, 10.0), 4.0), DoodleStyle.ERASER_PINK, 2.0)
	# 顔
	var look := facing.x * 1.5
	if downed:
		draw_line(Vector2(-6.0, -42.0), Vector2(-2.0, -38.0), DoodleStyle.INK, 2.0)
		draw_line(Vector2(-6.0, -38.0), Vector2(-2.0, -42.0), DoodleStyle.INK, 2.0)
		draw_line(Vector2(2.0, -42.0), Vector2(6.0, -38.0), DoodleStyle.INK, 2.0)
		draw_line(Vector2(2.0, -38.0), Vector2(6.0, -42.0), DoodleStyle.INK, 2.0)
	elif _blink < 0.0:
		draw_line(Vector2(-6.0 + look, -40.0), Vector2(-2.0 + look, -40.0), DoodleStyle.INK, 2.0)
		draw_line(Vector2(2.0 + look, -40.0), Vector2(6.0 + look, -40.0), DoodleStyle.INK, 2.0)
	else:
		draw_circle(Vector2(-4.0 + look, -40.0), 2.2, DoodleStyle.INK)
		draw_circle(Vector2(4.0 + look, -40.0), 2.2, DoodleStyle.INK)
	draw_arc(Vector2(look, -34.0), 3.0, 0.2, PI - 0.2, 8, DoodleStyle.INK, 1.8, true)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	# 名札と HP
	var tag := "P%d" % player_index
	DoodleStyle.draw_text(self, DoodleStyle.UI_FONT, Vector2(-11.0, -84.0 + hop), tag, 14, DoodleStyle.INK, HORIZONTAL_ALIGNMENT_LEFT, -1, 4, color)
	if downed:
		var left := clampf(_respawn_timer / respawn_seconds, 0.0, 1.0)
		draw_arc(Vector2(0.0, -30.0), 26.0, -PI / 2.0, -PI / 2.0 + TAU * (1.0 - left), 32, Color(color, 0.9), 4.0, true)
		DoodleStyle.draw_text(self, DoodleStyle.HAND_FONT, Vector2(14.0, -50.0 - sin(_t * 3.0) * 4.0), "zzz", 16, DoodleStyle.INK_SOFT)
	elif hp < max_hp:
		DoodleStyle.draw_bar(self, Rect2(-20.0, -98.0, 40.0, 7.0), hp / max_hp)
