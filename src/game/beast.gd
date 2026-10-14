class_name Beast
extends CharacterBody2D
## みんなで描いた線から生まれる味方の生き物。
## 見た目・当たり判定・ステータスはすべて線のデータから build() で導出する。
## 判断は子の BehaviorTree が行い、このクラスは敵と同じ「移動・攻撃・被弾」の契約だけを提供する。

signal hp_changed(hp: float, max_hp: float)
signal died(beast: Beast)

## 生き物の見た目の大きさ（長い辺のピクセル数）。
@export var target_size: float = 110.0
@export var body_color: Color = Color(0.35, 0.8, 0.95)
@export var weapon_color: Color = Color(0.95, 0.85, 0.4)
@export var stroke_width: float = 3.0

var max_hp: float = 40.0
var hp: float = 40.0
var attack_damage: float = 3.0
var speed: float = 50.0
## 被ダメージの軽減率（0〜0.8）。
var defense: float = 0.0
var attack_range: float = 44.0
var attack_interval: float = 1.0
var weapon_kind: ShapeAnalyzer.Weapon = ShapeAnalyzer.Weapon.NONE
var analysis: Dictionary = {}
var attacks_landed: int = 0

var _attack_timer := 0.0
var _hit_flash := 0.0
var _bob := 0.0
var _built := false
var _dead := false

@onready var _collision: CollisionPolygon2D = $CollisionPolygon2D
@onready var _visual: Node2D = $Visual


func _ready() -> void:
	add_to_group(&"players")
	add_to_group(&"beasts")
	if not _built:
		hp = max_hp


## 線のデータから生き物を組み立てる。何度呼んでも同じ結果になる。
func build(body_strokes: Array[PackedVector2Array], weapon_strokes: Array[PackedVector2Array], ink_budget: float) -> void:
	analysis = ShapeAnalyzer.analyze_body(body_strokes, ink_budget)
	weapon_kind = ShapeAnalyzer.classify_weapon(weapon_strokes)
	var profile := ShapeAnalyzer.weapon_profile(weapon_kind)
	max_hp = analysis["hp"]
	hp = max_hp
	attack_damage = analysis["attack"] * profile["damage_mul"]
	speed = analysis["speed"]
	defense = clampf(analysis["defense"] + profile["defense_bonus"], 0.0, 0.8)
	attack_range = profile["range"]
	attack_interval = 1.0 * profile["interval_mul"]
	_built = true
	_build_shape(body_strokes, weapon_strokes)
	hp_changed.emit(hp, max_hp)


func _build_shape(body_strokes: Array[PackedVector2Array], weapon_strokes: Array[PackedVector2Array]) -> void:
	var visual := get_node_or_null("Visual") as Node2D
	var collision := get_node_or_null("CollisionPolygon2D") as CollisionPolygon2D
	if visual == null or collision == null:
		return
	for child in visual.get_children():
		child.queue_free()

	var body_rect := StrokeTools.bounds(body_strokes)
	var longest := maxf(1.0, maxf(body_rect.size.x, body_rect.size.y))
	var scale_factor := target_size / longest
	var body := StrokeTools.transformed(body_strokes, -body_rect.get_center(), scale_factor)

	var weapon: Array[PackedVector2Array] = []
	if not weapon_strokes.is_empty():
		var weapon_rect := StrokeTools.bounds(weapon_strokes)
		var weapon_scale := scale_factor * 0.6
		# 武器は体の右端に、左端の中央を合わせて付ける。
		var anchor := Vector2(body_rect.size.x * 0.5 * scale_factor, 0.0)
		var weapon_offset := -Vector2(weapon_rect.position.x, weapon_rect.get_center().y)
		weapon = StrokeTools.transformed(weapon_strokes, weapon_offset, weapon_scale)
		for i in weapon.size():
			var moved := weapon[i]
			for k in moved.size():
				moved[k] += anchor
			weapon[i] = moved

	_add_polygons(visual, body, body_color)
	_add_polygons(visual, weapon, weapon_color)

	var points := StrokeTools.all_points(body)
	if points.size() >= 3:
		collision.polygon = Geometry2D.convex_hull(points)
	else:
		var fallback := PackedVector2Array()
		for i in range(8):
			fallback.append(Vector2.RIGHT.rotated(TAU * i / 8.0) * 12.0)
		collision.polygon = fallback


func _add_polygons(parent: Node2D, strokes: Array[PackedVector2Array], color: Color) -> void:
	for stroke in strokes:
		for polygon in StrokeTools.thicken(stroke, stroke_width):
			var shape := Polygon2D.new()
			shape.polygon = polygon
			shape.color = color
			parent.add_child(shape)


func _physics_process(delta: float) -> void:
	_attack_timer = maxf(0.0, _attack_timer - delta)
	_hit_flash = maxf(0.0, _hit_flash - delta)
	if velocity.length() > 1.0:
		_bob += delta * 10.0
		var visual := get_node_or_null("Visual") as Node2D
		if visual != null:
			visual.rotation = sin(_bob) * 0.12
	queue_redraw()


func is_targetable() -> bool:
	return not _dead


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
		target.take_damage(attack_damage, self)
		attacks_landed += 1
	return true


func take_damage(amount: float, _source: Node = null) -> void:
	if _dead:
		return
	hp = maxf(0.0, hp - amount * (1.0 - defense))
	_hit_flash = 0.1
	hp_changed.emit(hp, max_hp)
	if hp <= 0.0:
		_dead = true
		died.emit(self)
		queue_free()


func weapon_label() -> String:
	return ShapeAnalyzer.weapon_label(weapon_kind)


func _draw() -> void:
	if _hit_flash > 0.0:
		draw_circle(Vector2.ZERO, target_size * 0.6, Color(1.0, 1.0, 1.0, 0.35))
	var ratio := clampf(hp / max_hp, 0.0, 1.0) if max_hp > 0.0 else 0.0
	var bar_y := -target_size * 0.6 - 8.0
	draw_rect(Rect2(-30.0, bar_y, 60.0, 4.0), Color(0.1, 0.1, 0.1))
	draw_rect(Rect2(-30.0, bar_y, 60.0 * ratio, 4.0), Color(0.4, 0.9, 0.5))
