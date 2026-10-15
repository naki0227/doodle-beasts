class_name Enemy
extends CharacterBody2D
## CPU 側の敵「消しゴム兵」。らくがきを消しにやってくる。何をするかは子の BehaviorTree が決める。
## このクラスは「できること」（移動・攻撃・被弾）と見た目だけを提供し、判断は BT の葉ノードに任せる。
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
@export var color: Color = DoodleStyle.ERASER_PINK

## 硬い消しゴム（後半の波）になる HP の境目。
const HARD_HP := 39.0
## 見た目の拡大率。
const DRAW_SCALE := 1.5

var hp: float
var hard := false
var _attack_timer := 0.0
var _hit_flash := 0.0
var _t := 0.0
var _spawn := 0.0
var _lunge := 0.0
var _lunge_dir := Vector2.RIGHT
var _face := 1.0
var _dead := false


func _ready() -> void:
	hp = max_hp
	hard = max_hp >= HARD_HP
	if hard:
		color = DoodleStyle.ERASER_GREY
	add_to_group(&"enemies")
	material = DoodleStyle.doodle_material(0.9, 1.0)
	_t = randf() * 10.0
	Fx.burst(global_position + Vector2(0.0, -10.0), color, 0.6, 4)


func _physics_process(delta: float) -> void:
	_t += delta
	_attack_timer = maxf(0.0, _attack_timer - delta)
	_hit_flash = maxf(0.0, _hit_flash - delta)
	_spawn = minf(1.0, _spawn + delta * 3.0)
	_lunge = maxf(0.0, _lunge - delta * 5.0)
	if absf(velocity.x) > 5.0:
		_face = signf(velocity.x)
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
	var target_2d := target as Node2D
	if target_2d != null:
		_lunge = 1.0
		_lunge_dir = (target_2d.global_position - global_position).normalized()
		if absf(_lunge_dir.x) > 0.1:
			_face = signf(_lunge_dir.x)
		var word := "ゴシゴシ" if target_2d.is_in_group(&"core") else "ゴシッ"
		Fx.pop_text(global_position.lerp(target_2d.global_position, 0.6) + Vector2(0.0, -40.0), word, DoodleStyle.ACCENT_RED, 18)
	return true


func take_damage(amount: float, _source: Node = null) -> void:
	if _dead:
		return
	hp -= amount
	_hit_flash = 0.1
	Fx.damage_number(global_position + Vector2(0.0, -62.0), amount)
	if hp <= 0.0:
		die()


func die() -> void:
	if _dead:
		return
	_dead = true
	Fx.burst(global_position + Vector2(0.0, -20.0), color, 1.5, 16)
	Fx.decal(global_position, color.darkened(0.1), 7, 16.0)
	Fx.shake(4.0)
	died.emit(self)
	queue_free()


func _draw() -> void:
	var pop := 1.0 - pow(1.0 - _spawn, 3.0)
	if _spawn < 1.0:
		pop *= 1.0 + 0.25 * sin(_spawn * PI)
	DoodleStyle.draw_shadow(self, Vector2(0.0, 2.0), Vector2(16.0 * pop * DRAW_SCALE, 5.0 * pop * DRAW_SCALE))
	var moving := velocity.length() > 5.0
	var hop := -absf(sin(_t * 11.0)) * 7.0 if moving else 0.0
	var squash := 1.0 + (0.08 * sin(_t * 22.0) if moving else 0.03 * sin(_t * 3.0))
	var offset := Vector2(0.0, hop) + _lunge_dir * 10.0 * sin(_lunge * PI)
	draw_set_transform(offset, 0.0, Vector2(_face * pop * squash, pop / squash) * DRAW_SCALE)

	var body := color
	var sleeve := DoodleStyle.SLEEVE_HARD if hard else DoodleStyle.SLEEVE
	if _hit_flash > 0.0:
		body = body.lerp(Color.WHITE, 0.75)
		sleeve = sleeve.lerp(Color.WHITE, 0.75)
	# 足
	var step := sin(_t * 11.0) * 3.0 if moving else 0.0
	draw_line(Vector2(-7.0, -4.0), Vector2(-7.0 + step, 0.0), DoodleStyle.INK, 3.0, true)
	draw_line(Vector2(7.0, -4.0), Vector2(7.0 - step, 0.0), DoodleStyle.INK, 3.0, true)
	# 本体（右の先がすり減って丸い）
	DoodleStyle.draw_shape(self, DoodleStyle.rounded_rect(Rect2(-18.0, -28.0, 36.0, 24.0), 7.0), body, 2.5)
	# スリーブ
	DoodleStyle.draw_shape(self, PackedVector2Array([
		Vector2(-19.0, -30.0), Vector2(7.0, -30.0), Vector2(7.0, -2.0), Vector2(-19.0, -2.0)]), sleeve, 2.5)
	draw_line(Vector2(-19.0, -8.0), Vector2(7.0, -8.0), Color(DoodleStyle.PAPER, 0.8), 2.0)
	# 怒った目
	var look := 1.5
	for x in [-11.0, -1.0]:
		draw_circle(Vector2(x, -18.0), 4.2, Color.WHITE)
		draw_arc(Vector2(x, -18.0), 4.2, 0.0, TAU, 12, DoodleStyle.INK, 1.5, true)
		draw_circle(Vector2(x + look, -17.0), 2.0, DoodleStyle.INK)
	draw_line(Vector2(-16.0, -25.0), Vector2(-7.0, -22.0), DoodleStyle.INK, 2.5, true)
	draw_line(Vector2(4.0, -25.0), Vector2(-5.0, -22.0), DoodleStyle.INK, 2.5, true)
	if hard:
		draw_line(Vector2(10.0, -22.0), Vector2(14.0, -12.0), DoodleStyle.INK, 2.0, true)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	if hp < max_hp:
		DoodleStyle.draw_bar(self, Rect2(-20.0, -58.0, 40.0, 6.0), clampf(hp / max_hp, 0.0, 1.0), DoodleStyle.HP_LOW)
