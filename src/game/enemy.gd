class_name Enemy
extends CharacterBody2D
## CPU 側の敵「霜の獣」。背中に霜の結晶を背負い、かたちを凍らせにやってくる。何をするかは子の BehaviorTree が決める。
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
@export var color: Color = DoodleStyle.FROST_BODY

## 赤い結晶の「硬い霜の獣」（後半の波）になる HP の境目。
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
var _crystal: Color
var _crystal_light: Color


func _ready() -> void:
	hp = max_hp
	hard = max_hp >= HARD_HP
	if hard:
		color = DoodleStyle.EMBER_BODY
		_crystal = DoodleStyle.EMBER
		_crystal_light = DoodleStyle.EMBER.lightened(0.4)
	else:
		_crystal = DoodleStyle.FROST_DEEP
		_crystal_light = DoodleStyle.FROST
	add_to_group(&"enemies")
	material = DoodleStyle.surface_material(0.6, 0.0)
	_t = randf() * 10.0
	Fx.burst(global_position + Vector2(0.0, -10.0), _crystal_light, 0.6, 4)


func _physics_process(delta: float) -> void:
	_t += delta
	_attack_timer = maxf(0.0, _attack_timer - delta)
	_hit_flash = maxf(0.0, _hit_flash - delta)
	_spawn = minf(1.0, _spawn + delta * 2.5)
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
		Fx.burst(global_position.lerp(target_2d.global_position, 0.7) + Vector2(0.0, -20.0), _crystal_light, 0.5, 4)
	return true


func take_damage(amount: float, _source: Node = null) -> void:
	if _dead:
		return
	hp -= amount
	_hit_flash = 0.1
	Fx.damage_number(global_position + Vector2(0.0, -84.0), amount, DoodleStyle.CREAM)
	if hp <= 0.0:
		die()


func die() -> void:
	if _dead:
		return
	_dead = true
	Fx.burst(global_position + Vector2(0.0, -20.0), _crystal_light, 1.5, 16)
	Fx.pop_text(global_position + Vector2(0.0, -50.0), "パキン", _crystal_light, 22)
	Fx.decal(global_position, _crystal_light, 8, 18.0)
	Fx.shake(4.0)
	died.emit(self)
	queue_free()


func _draw() -> void:
	var pop := 1.0 - pow(1.0 - _spawn, 3.0)
	DoodleStyle.draw_shadow(self, Vector2(0.0, 2.0), Vector2(24.0 * pop, 6.0 * pop) * DRAW_SCALE)
	var moving := velocity.length() > 5.0
	var bob := -absf(sin(_t * 9.0)) * 4.0 if moving else sin(_t * 2.0) * 0.8
	var offset := Vector2(0.0, bob) + _lunge_dir * 12.0 * sin(_lunge * PI)
	draw_set_transform(offset + Vector2(0.0, (1.0 - pop) * 16.0), 0.0, Vector2(_face, pop) * DRAW_SCALE)

	var body := color
	var crystal := _crystal
	var light := _crystal_light
	if _hit_flash > 0.0:
		body = body.lerp(Color.WHITE, 0.7)
		crystal = crystal.lerp(Color.WHITE, 0.7)
	# 脚
	var step := sin(_t * 9.0) * 4.0 if moving else 0.0
	for x in [-14.0, -6.0, 8.0, 15.0]:
		var s: float = step if int(x) % 2 == 0 else -step
		draw_line(Vector2(x, -10.0), Vector2(x + s, 0.0), DoodleStyle.INK, 3.0)
	# 体（背を丸めた獣）
	DoodleStyle.draw_shape(self, PackedVector2Array([
		Vector2(-20, -8), Vector2(-24, -20), Vector2(-14, -31), Vector2(2, -34), Vector2(16, -28), Vector2(22, -18), Vector2(18, -8)]), body, 1.5, DoodleStyle.INK)
	# 頭
	DoodleStyle.draw_shape(self, PackedVector2Array([Vector2(14, -24), Vector2(28, -22), Vector2(32, -13), Vector2(20, -8)]), body.lightened(0.08), 1.5, DoodleStyle.INK)
	draw_circle(Vector2(25.0, -18.0), 1.8, light)
	draw_circle(Vector2(29.0, -17.0), 1.5, light)
	draw_polyline(PackedVector2Array([Vector2(22, -11), Vector2(25, -13), Vector2(27, -11), Vector2(30, -13)]), light.darkened(0.2), 1.0)
	# 背中の結晶
	var shards := [[-16.0, -28.0, -24.0, -46.0], [-8.0, -32.0, -10.0, -54.0], [0.0, -34.0, 4.0, -50.0], [8.0, -32.0, 14.0, -44.0], [-22.0, -22.0, -32.0, -32.0]]
	for shard in shards:
		var base := Vector2(shard[0], shard[1])
		var tip := Vector2(shard[2], shard[3])
		var side := (tip - base).orthogonal().normalized() * 4.0
		DoodleStyle.draw_shape(self, PackedVector2Array([base - side, tip, base + side]), crystal, 1.2, crystal.darkened(0.45))
		draw_line(base - side * 0.5, tip, light, 1.2)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	if hp < max_hp:
		DoodleStyle.draw_bar(self, Rect2(-24.0, -92.0, 48.0, 6.0), clampf(hp / max_hp, 0.0, 1.0), DoodleStyle.FROST_DEEP)
