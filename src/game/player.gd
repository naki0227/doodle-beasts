class_name Player
extends CharacterBody2D
## 旅人「かたち読み」。つば広の帽子、外套、背負い袋、ランタン付きの杖。
## 戦闘は自動で進む。旅人はビヘイビアツリー（BehaviorBuilder.build_wanderer）で動き、
## 金の駒に近づいた霜の獣を杖で払い、駒が傷んでいれば手をかざして直し、何もなければ持ち場で待つ。
## プレイヤーの操作は記録帳に描くことだけ。player_index は記録帳のどのページを描いた人かを表す。
## HP が 0 になると倒れ、数秒後に石碑のそばで起き上がる。

signal hp_changed(hp: float, max_hp: float)
signal downed_changed(downed: bool)

@export_range(1, 2) var player_index: int = 1
@export var speed: float = 150.0
@export var max_hp: float = 100.0
@export var attack_damage: float = 15.0
@export var attack_range: float = 56.0
@export var attack_interval: float = 0.35
@export var repair_range: float = 100.0
@export var repair_per_second: float = 25.0
@export var respawn_seconds: float = 5.0
## 歩ける範囲（草地）。
@export var play_area: Rect2 = Rect2(30.0, 262.0, 1220.0, 440.0)
@export var color: Color = DoodleStyle.P1

var hp: float
var downed := false
var facing := Vector2.RIGHT
## ランタンの位置（このノードのローカル座標）。光の子ノードが使う。
var lantern_point := Vector2(13.0, -62.0)

var _attack_timer := 0.0
var _respawn_timer := 0.0
var _slash := 0.0
var _slash_dir := Vector2.RIGHT
var _hit_flash := 0.0
var _t := 0.0
var _moving := false
var _repairing := false
var _repairing_hold := 0.0
var _repair_tick := 0.0
var _cloak: Color
var _tree: BehaviorTree


func _ready() -> void:
	hp = max_hp
	color = DoodleStyle.PLAYER_COLORS.get(player_index, color)
	_cloak = DoodleStyle.PLAYER_CLOAKS.get(player_index, DoodleStyle.SLATE)
	add_to_group(&"players")
	material = DoodleStyle.surface_material(0.8, 0.0)
	GlowNode.attach(self)
	_t = player_index * 1.7
	_tree = BehaviorTree.new()
	_tree.name = "BehaviorTree"
	_tree.agent = self
	add_child(_tree)
	var slot := Vector2(-110.0 if player_index == 1 else 110.0, 60.0)
	BehaviorBuilder.install(_tree, BehaviorBuilder.build_wanderer(self, slot))
	hp_changed.emit(hp, max_hp)


func _physics_process(delta: float) -> void:
	_t += delta
	_attack_timer = maxf(0.0, _attack_timer - delta)
	_slash = maxf(0.0, _slash - delta)
	_hit_flash = maxf(0.0, _hit_flash - delta)
	_repairing_hold = maxf(0.0, _repairing_hold - delta)
	_repairing = _repairing_hold > 0.0
	if downed:
		_tree.enabled = false
		_respawn_timer -= delta
		if _respawn_timer <= 0.0:
			_respawn()
		queue_redraw()
		return
	_tree.enabled = true
	_moving = velocity.length() > 5.0
	queue_redraw()


# --- BT の葉ノードから呼ばれる契約 ---

func move_toward_point(point: Vector2, _delta: float) -> void:
	var direction := (point - global_position).normalized()
	velocity = direction * speed
	move_and_slide()
	global_position = global_position.clamp(play_area.position, play_area.end)
	if direction != Vector2.ZERO:
		facing = direction


func stop_moving() -> void:
	velocity = Vector2.ZERO


func attack(target: Node) -> bool:
	if _attack_timer > 0.0:
		return false
	_attack_timer = attack_interval
	var target_2d := target as Node2D
	if target_2d != null:
		var to_target := target_2d.global_position - global_position
		if to_target.length() > 1.0:
			facing = to_target.normalized()
	_slash = 0.18
	_slash_dir = facing
	if target.has_method("take_damage"):
		target.take_damage(attack_damage, self)
		if target_2d != null:
			Fx.burst(target_2d.global_position + Vector2(0.0, -18.0), DoodleStyle.FROST, 0.7, 5)
		Sound.play("hit_light", -3.0)
		Fx.shake(1.5)
	return true


func core_needs_repair() -> bool:
	var core := get_tree().get_first_node_in_group(&"core") as Core
	return core != null and not core.is_destroyed() and core.hp < core.max_hp - 1.0


func repair_core(delta: float) -> void:
	var core := get_tree().get_first_node_in_group(&"core") as Core
	if core == null:
		return
	var to_core := core.global_position - global_position
	if to_core.length() > 1.0:
		facing = to_core.normalized()
	_repairing_hold = 0.15
	core.repair(repair_per_second * delta)
	_repair_tick -= delta
	if _repair_tick <= 0.0:
		_repair_tick = 0.5
		var spot := core.global_position + Vector2(randf_range(-30.0, 30.0), randf_range(-100.0, -20.0))
		Fx.pop_text(spot, "+", DoodleStyle.GOLD_LIGHT, 24)
		Sound.play("repair")


func is_targetable() -> bool:
	return not downed


func take_damage(amount: float, _source: Node = null) -> void:
	if downed:
		return
	hp = maxf(0.0, hp - amount)
	_hit_flash = 0.12
	hp_changed.emit(hp, max_hp)
	Fx.damage_number(global_position + Vector2(0.0, -86.0), amount, DoodleStyle.HP_LOW)
	if hp <= 0.0:
		_down()


func _down() -> void:
	downed = true
	_respawn_timer = respawn_seconds
	velocity = Vector2.ZERO
	set_collision_layer_value(1, false)
	set_collision_mask_value(2, false)
	Fx.burst(global_position + Vector2(0.0, -30.0), DoodleStyle.FROST, 1.2, 12)
	Fx.pop_text(global_position + Vector2(0.0, -80.0), "凍えた…", DoodleStyle.FROST, 22)
	Sound.play("seed_hit", -4.0)
	Fx.shake(6.0)
	downed_changed.emit(true)


func _respawn() -> void:
	downed = false
	hp = max_hp
	set_collision_layer_value(1, true)
	set_collision_mask_value(2, true)
	var core := get_tree().get_first_node_in_group(&"core") as Node2D
	if core != null:
		global_position = core.global_position + Vector2(-90.0 if player_index == 1 else 90.0, 40.0)
	Fx.burst(global_position + Vector2(0.0, -30.0), DoodleStyle.GOLD_LIGHT, 1.0, 8)
	hp_changed.emit(hp, max_hp)
	downed_changed.emit(false)


func draw_glow_into(canvas: Node2D) -> void:
	if downed:
		return
	var flicker := 0.85 + 0.15 * sin(_t * 13.0) * sin(_t * 7.3)
	DoodleStyle.draw_glow(canvas, lantern_point, 60.0, DoodleStyle.LANTERN, flicker)
	if _slash > 0.0:
		DoodleStyle.draw_glow(canvas, Vector2(_slash_dir.x * 30.0, -30.0), 50.0, DoodleStyle.GOLD, _slash / 0.18)
	if _repairing:
		DoodleStyle.draw_glow(canvas, Vector2(facing.x * 16.0, -40.0), 40.0, DoodleStyle.GOLD, 0.8)


func _draw() -> void:
	DoodleStyle.draw_shadow(self, Vector2(0.0, 2.0), Vector2(15.0, 5.0))
	var face := 1.0 if facing.x >= 0.0 else -1.0
	var cloak := _cloak
	var skin := Color("dcc09c")
	if downed:
		cloak = cloak.lerp(DoodleStyle.FOG, 0.5)
	elif _hit_flash > 0.0:
		cloak = cloak.lerp(Color.WHITE, 0.6)

	if _slash > 0.0:
		var k := _slash / 0.18
		var center := Vector2(0.0, -30.0)
		var angle := _slash_dir.angle()
		var start := angle - 1.1 + (1.0 - k) * 0.6
		draw_arc(center, attack_range * 0.8, start, start + 2.2 * (1.2 - k), 18, Color(DoodleStyle.GOLD_LIGHT, k), 5.0, true)

	var hop := 0.0
	var tilt := 0.0
	if downed:
		tilt = PI / 2.0 * face
	else:
		if _moving:
			hop = -absf(sin(_t * 12.0)) * 4.0
			tilt = facing.x * 0.06
		if _slash > 0.0:
			tilt += _slash_dir.x * 0.25 * (_slash / 0.18)
		if _repairing:
			tilt = face * 0.15
	draw_set_transform(Vector2(0.0, hop), tilt, Vector2(face, 1.0))

	# 足
	var step := sin(_t * 12.0) * 3.0 if _moving else 0.0
	draw_rect(Rect2(-6.0 + step, -11.0, 5.0, 11.0), Color("3a2c22"))
	draw_rect(Rect2(2.0 - step, -11.0, 5.0, 11.0), Color("3a2c22"))
	# 背負い袋
	DoodleStyle.draw_shape(self, PackedVector2Array([Vector2(-18, -38), Vector2(-8, -40), Vector2(-7, -16), Vector2(-17, -15)]), Color("6e5640"), 1.5)
	draw_line(Vector2(-17, -30), Vector2(-8, -31), Color("4a3a2c"), 1.5)
	# 外套
	DoodleStyle.draw_shape(self, PackedVector2Array([Vector2(-9, -42), Vector2(9, -42), Vector2(14, -9), Vector2(-14, -9)]), cloak, 1.5)
	draw_line(Vector2(-13, -13), Vector2(13, -13), DoodleStyle.CREAM.darkened(0.15), 2.0)
	for x in [-9.0, -3.0, 3.0, 9.0]:
		draw_circle(Vector2(x, -13.0), 1.2, DoodleStyle.GOLD)
	# 襟巻き（なびく）
	var sway := sin(_t * 4.0) * 2.0 - (4.0 if _moving else 0.0)
	DoodleStyle.draw_shape(self, PackedVector2Array([Vector2(-8, -44), Vector2(9, -44), Vector2(8, -39), Vector2(-7, -38)]), color, 1.0)
	draw_colored_polygon(PackedVector2Array([Vector2(-7, -42), Vector2(-17 + sway, -36), Vector2(-15 + sway, -32), Vector2(-6, -38)]), color.darkened(0.15))
	# 顔
	draw_circle(Vector2(2.0, -47.0), 6.0, skin)
	draw_circle(Vector2(5.0, -47.0), 1.2, DoodleStyle.INK)
	# 帽子
	draw_colored_polygon(PackedVector2Array([Vector2(-6, -51), Vector2(8, -51), Vector2(6, -64), Vector2(-4, -63)]), Color("4a3a2c"))
	draw_line(Vector2(-6, -53), Vector2(8, -53), color.darkened(0.2), 2.0)
	DoodleStyle.draw_shape(self, DoodleStyle.ellipse(Vector2(1.0, -51.0), Vector2(17.0, 4.0), 16), Color("54412f"), 1.2)
	# 杖とランタン
	var staff_top := Vector2(12.0, -74.0)
	if _slash > 0.0:
		staff_top = Vector2(26.0, -60.0)
	draw_line(Vector2(9.0, -24.0), staff_top, Color("7a5c3e"), 2.5)
	var lantern := staff_top + Vector2(2.0, 8.0)
	DoodleStyle.draw_shape(self, PackedVector2Array([lantern + Vector2(-3, -4), lantern + Vector2(3, -4), lantern + Vector2(4, 5), lantern + Vector2(-4, 5)]),
		DoodleStyle.LANTERN if not downed else DoodleStyle.STONE, 1.2)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	lantern_point = Vector2(0.0, hop) + (Vector2(lantern.x * face, lantern.y)).rotated(tilt)

	# 誰かわかる印と HP
	var marker := Vector2(0.0, -86.0 + hop + sin(_t * 3.0) * 2.0)
	if not downed:
		draw_colored_polygon(PackedVector2Array([marker + Vector2(0, -6), marker + Vector2(5, 0), marker + Vector2(0, 6), marker + Vector2(-5, 0)]), color)
	if downed:
		var left := clampf(_respawn_timer / respawn_seconds, 0.0, 1.0)
		draw_arc(Vector2(0.0, -24.0), 24.0, -PI / 2.0, -PI / 2.0 + TAU * (1.0 - left), 32, Color(DoodleStyle.GOLD, 0.9), 3.0, true)
	elif hp < max_hp:
		DoodleStyle.draw_bar(self, Rect2(-20.0, -100.0, 40.0, 6.0), hp / max_hp)
