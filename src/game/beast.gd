class_name Beast
extends CharacterBody2D
## みんなで描いた線から生まれる味方の生き物。
## 見た目・当たり判定・ステータスはすべて線のデータから build() で導出する。
## 判断は子の BehaviorTree が行い、このクラスは敵と同じ「移動・攻撃・被弾」の契約だけを提供する。
##
## 見た目はステッカー風: 白い縁取り + 紙の厚み + クレヨンの塗り + インクの線。
## Visual の下に Body と Weapon を分けて持ち、武器だけを振り回せるようにしている。

signal hp_changed(hp: float, max_hp: float)
signal died(beast: Beast)

## 生き物の見た目の大きさ（長い辺のピクセル数）。
@export var target_size: float = 130.0
@export var body_fill: Color = DoodleStyle.P1_LIGHT
@export var weapon_fill: Color = DoodleStyle.P2_LIGHT
@export var stroke_width: float = 3.0
## 白い縁取りの太さ。
@export var border: float = 7.0
## 紙の厚み（下にずらして描く量）。
@export var thickness: float = 6.0

const ATTACK_WORDS := {
	ShapeAnalyzer.Weapon.NONE: "ポカ",
	ShapeAnalyzer.Weapon.SWORD: "ザシュッ",
	ShapeAnalyzer.Weapon.SPEAR: "ズバッ",
	ShapeAnalyzer.Weapon.HAMMER: "ドカッ",
	ShapeAnalyzer.Weapon.CLAWS: "ガリッ",
	ShapeAnalyzer.Weapon.SHIELD: "ゴンッ",
	ShapeAnalyzer.Weapon.BOW: "ヒュン",
	ShapeAnalyzer.Weapon.UNKNOWN: "ボヨン",
}

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
## 見た目の外接矩形（Visual のローカル座標）。影や HP バーの位置に使う。
var body_rect: Rect2 = Rect2(-20.0, -20.0, 40.0, 40.0)

var _attack_timer := 0.0
var _hit_flash := 0.0
var _t := 0.0
var _built := false
var _dead := false
var _facing := 1.0
var _lunge := 0.0
var _lunge_dir := Vector2.RIGHT
var _weapon_tween: Tween
var _entering := false
var _overlay: Node2D

@onready var _collision: CollisionPolygon2D = $CollisionPolygon2D
@onready var _visual: Node2D = $Visual


class BeastOverlay:
	extends Node2D
	var beast: Beast

	func _process(_delta: float) -> void:
		queue_redraw()

	func _draw() -> void:
		if beast == null or beast.hp >= beast.max_hp or beast.max_hp <= 0.0:
			return
		var y := beast.body_rect.position.y - 16.0
		DoodleStyle.draw_bar(self, Rect2(-34.0, y, 68.0, 8.0), beast.hp / beast.max_hp)


func _ready() -> void:
	add_to_group(&"players")
	add_to_group(&"beasts")
	if not _built:
		hp = max_hp
	_overlay = BeastOverlay.new()
	_overlay.beast = self
	_overlay.z_index = 5
	add_child(_overlay)


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
	_configure_reach()
	hp_changed.emit(hp, max_hp)


## 体の大きさと武器の射程から、BT の「届く距離」と「止まる距離」を決める。
## 体が大きいほど中心から相手までの距離が縮まらないので、半径ぶんを足す。
func reach() -> float:
	return maxf(body_rect.size.x, body_rect.size.y) * 0.5 + attack_range * 0.6


func _configure_reach() -> void:
	var in_range := get_node_or_null("BehaviorTree/Root/HuntEnemy/EngageOrApproach/Engage/IsTargetInRange") as BTIsTargetInRange
	var move := get_node_or_null("BehaviorTree/Root/HuntEnemy/EngageOrApproach/MoveToTarget") as BTMoveToTarget
	if in_range != null:
		in_range.range = reach()
	if move != null:
		move.stop_distance = reach() - 14.0


func _build_shape(body_strokes: Array[PackedVector2Array], weapon_strokes: Array[PackedVector2Array]) -> void:
	var visual := get_node_or_null("Visual") as Node2D
	var collision := get_node_or_null("CollisionPolygon2D") as CollisionPolygon2D
	if visual == null or collision == null:
		return
	for child in visual.get_children():
		visual.remove_child(child)
		child.queue_free()

	var source_rect := StrokeTools.bounds(body_strokes)
	var longest := maxf(1.0, maxf(source_rect.size.x, source_rect.size.y))
	var scale_factor := target_size / longest
	var body := StrokeTools.transformed(body_strokes, -source_rect.get_center(), scale_factor)
	body_rect = StrokeTools.bounds(body)

	var material_shared := DoodleStyle.doodle_material(1.1, 1.0)
	var body_node := Node2D.new()
	body_node.name = "Body"
	visual.add_child(body_node)
	_add_sticker(body_node, body, body_fill, material_shared)

	var weapon_node := Node2D.new()
	weapon_node.name = "Weapon"
	visual.add_child(weapon_node)
	if not weapon_strokes.is_empty():
		var weapon_rect := StrokeTools.bounds(weapon_strokes)
		var weapon_scale := scale_factor * 0.6
		# 武器は持ち手（左端の中央）を Weapon ノードの原点に合わせ、体の右端に付ける。
		var weapon := StrokeTools.transformed(weapon_strokes, -Vector2(weapon_rect.position.x, weapon_rect.get_center().y), weapon_scale)
		weapon_node.position = Vector2(body_rect.end.x - 6.0, body_rect.get_center().y + body_rect.size.y * 0.1)
		_add_sticker(weapon_node, weapon, weapon_fill, material_shared)

	var points := StrokeTools.all_points(body)
	if points.size() >= 3:
		collision.polygon = Geometry2D.convex_hull(points)
	else:
		var fallback := PackedVector2Array()
		for i in range(8):
			fallback.append(Vector2.RIGHT.rotated(TAU * i / 8.0) * 12.0)
		collision.polygon = fallback


## 線をステッカー風に組み立てる。下から順に: 厚み → 縁の影 → 白い縁 → 塗り → インクの線。
## 線は Line2D で描く（閉じた線を多角形に太らせると内側の穴が消えて塗りつぶされるため）。
## 閉じた形の中にある閉じた形（目など）は白で塗る。
func _add_sticker(parent: Node2D, strokes: Array[PackedVector2Array], fill: Color, shared: ShaderMaterial) -> void:
	var fills: Array[PackedVector2Array] = []
	for stroke in strokes:
		if StrokeTools.is_closed(stroke) and _can_fill(stroke):
			fills.append(stroke)
	var layers := [
		{"offset": Vector2(0.0, thickness), "width": stroke_width + border + 1.5, "color": Color("b9ab92")},
		{"offset": Vector2.ZERO, "width": stroke_width + border + 1.5, "color": Color("d8ccb4")},
		{"offset": Vector2.ZERO, "width": stroke_width + border, "color": DoodleStyle.PAPER},
	]
	for layer in layers:
		for polygon in fills:
			_add_polygon(parent, polygon, layer["color"], layer["offset"], shared)
		for stroke in strokes:
			_add_line(parent, stroke, layer["width"] * 2.0, layer["color"], layer["offset"], shared)
	for polygon in fills:
		var color := fill
		for other in fills:
			if other != polygon and _inside(polygon, other):
				color = DoodleStyle.PAPER
				break
		_add_polygon(parent, polygon, color, Vector2.ZERO, shared)
	for stroke in strokes:
		_add_line(parent, stroke, stroke_width * 2.0, DoodleStyle.INK, Vector2.ZERO, shared)


## inner の重心が outer の中にあるか。
static func _inside(inner: PackedVector2Array, outer: PackedVector2Array) -> bool:
	var center := Vector2.ZERO
	for p in inner:
		center += p
	center /= maxf(1.0, inner.size())
	return Geometry2D.is_point_in_polygon(center, outer) and StrokeTools.length(inner) < StrokeTools.length(outer)


static func _can_fill(polygon: PackedVector2Array) -> bool:
	return polygon.size() >= 3 and not Geometry2D.triangulate_polygon(polygon).is_empty()


func _add_polygon(parent: Node2D, polygon: PackedVector2Array, color: Color, offset: Vector2, shared: ShaderMaterial) -> void:
	if not _can_fill(polygon):
		return
	var shape := Polygon2D.new()
	shape.polygon = polygon
	shape.color = color
	shape.position = offset
	shape.material = shared
	parent.add_child(shape)


func _add_line(parent: Node2D, stroke: PackedVector2Array, width: float, color: Color, offset: Vector2, shared: ShaderMaterial) -> void:
	if stroke.size() < 2:
		return
	var line := Line2D.new()
	line.points = stroke
	line.width = width
	line.default_color = color
	line.joint_mode = Line2D.LINE_JOINT_ROUND
	line.begin_cap_mode = Line2D.LINE_CAP_ROUND
	line.end_cap_mode = Line2D.LINE_CAP_ROUND
	line.antialiased = true
	line.position = offset
	line.material = shared
	parent.add_child(line)


func _physics_process(delta: float) -> void:
	_t += delta
	_attack_timer = maxf(0.0, _attack_timer - delta)
	_hit_flash = maxf(0.0, _hit_flash - delta)
	_lunge = maxf(0.0, _lunge - delta * 4.0)
	var visual := get_node_or_null("Visual") as Node2D
	if visual == null or _entering:
		return
	if absf(velocity.x) > 5.0:
		_facing = signf(velocity.x)
	visual.scale.x = move_toward(visual.scale.x, _facing, delta * 9.0)
	var body := visual.get_node_or_null("Body") as Node2D
	var moving := velocity.length() > 5.0
	var hop := -absf(sin(_t * 9.0)) * 7.0 if moving else 0.0
	visual.position = Vector2(0.0, hop) + _lunge_dir * 16.0 * sin(_lunge * PI)
	if body != null:
		if moving:
			body.rotation = sin(_t * 9.0) * 0.07
			body.scale = Vector2(1.0 + 0.05 * absf(cos(_t * 9.0)), 1.0 - 0.05 * absf(cos(_t * 9.0)))
		else:
			body.rotation = lerpf(body.rotation, 0.0, delta * 8.0)
			var breath := sin(_t * 2.6) * 0.03
			body.scale = Vector2(1.0 - breath, 1.0 + breath)
	visual.modulate = Color(1.6, 1.6, 1.6) if _hit_flash > 0.0 else Color.WHITE
	queue_redraw()


func is_targetable() -> bool:
	return not _dead


func move_toward_point(point: Vector2, _delta: float) -> void:
	if _entering:
		return
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
	var target_2d := target as Node2D
	if target_2d != null:
		_play_attack(target_2d)
	return true


## 武器ごとの振り方と、当たりの演出。
func _play_attack(target: Node2D) -> void:
	var to_target := target.global_position - global_position
	_lunge_dir = to_target.normalized() if to_target.length() > 1.0 else Vector2.RIGHT
	if absf(_lunge_dir.x) > 0.1:
		_facing = signf(_lunge_dir.x)
	_lunge = 1.0
	var hit_at := target.global_position + Vector2(0.0, -18.0)
	var shake := 3.0
	var stop := 0.03
	var weapon := get_node_or_null("Visual/Weapon") as Node2D
	if weapon != null and is_inside_tree():
		if _weapon_tween != null and _weapon_tween.is_valid():
			_weapon_tween.kill()
		weapon.rotation = 0.0
		weapon.scale = Vector2.ONE
		var base_x := weapon.position.x
		_weapon_tween = create_tween()
		match weapon_kind:
			ShapeAnalyzer.Weapon.HAMMER:
				_weapon_tween.tween_property(weapon, "rotation", -1.4, 0.12)
				_weapon_tween.tween_property(weapon, "rotation", 0.9, 0.08)
				_weapon_tween.tween_property(weapon, "rotation", 0.0, 0.25)
				shake = 9.0
				stop = 0.08
			ShapeAnalyzer.Weapon.SPEAR:
				_weapon_tween.tween_property(weapon, "position:x", base_x + 26.0, 0.07)
				_weapon_tween.tween_property(weapon, "position:x", base_x, 0.18)
			ShapeAnalyzer.Weapon.CLAWS:
				_weapon_tween.tween_property(weapon, "rotation", 0.5, 0.05)
				_weapon_tween.tween_property(weapon, "rotation", -0.5, 0.06)
				_weapon_tween.tween_property(weapon, "rotation", 0.0, 0.06)
				shake = 2.0
			ShapeAnalyzer.Weapon.SHIELD:
				_weapon_tween.tween_property(weapon, "scale", Vector2(1.3, 1.3), 0.07)
				_weapon_tween.tween_property(weapon, "scale", Vector2.ONE, 0.2)
				shake = 5.0
			ShapeAnalyzer.Weapon.BOW:
				_weapon_tween.tween_property(weapon, "position:x", base_x - 8.0, 0.08)
				_weapon_tween.tween_property(weapon, "position:x", base_x, 0.12)
				_lunge = 0.0
				Fx.arrow(global_position + Vector2(_facing * body_rect.size.x * 0.5, -10.0), hit_at)
			_:
				_weapon_tween.tween_property(weapon, "rotation", -1.0, 0.08)
				_weapon_tween.tween_property(weapon, "rotation", 0.7, 0.07)
				_weapon_tween.tween_property(weapon, "rotation", 0.0, 0.2)
				shake = 4.0
	Fx.burst(hit_at, DoodleStyle.ERASER_PINK, 1.0 + shake * 0.05, 8)
	Fx.pop_text(hit_at + Vector2(0.0, -34.0), ATTACK_WORDS.get(weapon_kind, "ポカ"), DoodleStyle.P2.darkened(0.15), 28 + int(shake))
	Fx.shake(shake)
	Fx.hitstop(stop)


func take_damage(amount: float, _source: Node = null) -> void:
	if _dead:
		return
	var dealt := amount * (1.0 - defense)
	hp = maxf(0.0, hp - dealt)
	_hit_flash = 0.1
	hp_changed.emit(hp, max_hp)
	Fx.damage_number(global_position + Vector2(0.0, body_rect.position.y - 26.0), dealt, DoodleStyle.HP_LOW)
	if hp <= 0.0:
		_dead = true
		Fx.burst(global_position, body_fill, 2.5, 24)
		Fx.pop_text(global_position + Vector2(0.0, -60.0), "ビリッ…", DoodleStyle.HP_LOW, 34)
		Fx.shake(12.0)
		died.emit(self)
		queue_free()


## 戦闘開始時の登場演出。空から落ちてきて着地する。
func play_entrance(bt_delay: float = 0.9) -> void:
	var visual := get_node_or_null("Visual") as Node2D
	var tree_node := get_node_or_null("BehaviorTree") as BehaviorTree
	if visual == null or not is_inside_tree():
		return
	_entering = true
	if tree_node != null:
		tree_node.enabled = false
	visual.position = Vector2(0.0, -520.0)
	visual.scale = Vector2(0.8, 1.25)
	var tween := create_tween()
	tween.tween_property(visual, "position:y", 0.0, 0.45).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_callback(func() -> void:
		Fx.burst(global_position + Vector2(0.0, body_rect.end.y * 0.5), DoodleStyle.INK, 2.6, 16)
		Fx.pop_text(global_position + Vector2(0.0, body_rect.position.y - 30.0), "ドーン！", DoodleStyle.ACCENT_RED, 44)
		Fx.shake(14.0))
	tween.tween_property(visual, "scale", Vector2(1.3, 0.7), 0.06)
	tween.tween_property(visual, "scale", Vector2(0.9, 1.12), 0.1)
	tween.tween_property(visual, "scale", Vector2.ONE, 0.12)
	await get_tree().create_timer(bt_delay).timeout
	_entering = false
	if tree_node != null and is_instance_valid(tree_node):
		tree_node.enabled = true


func weapon_label() -> String:
	return ShapeAnalyzer.weapon_label(weapon_kind)


func _draw() -> void:
	var foot := body_rect.end.y + thickness * 0.5
	var squeeze := 1.0
	var visual := get_node_or_null("Visual") as Node2D
	if visual != null:
		squeeze = clampf(1.0 + visual.position.y / 300.0, 0.3, 1.0)
	DoodleStyle.draw_shadow(self, Vector2(0.0, foot), Vector2(body_rect.size.x * 0.42 * squeeze, 10.0 * squeeze))
