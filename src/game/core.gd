class_name Core
extends StaticBody2D
## 全員で守る「お城の絵」。消しゴムにこすられるとヒビが入り、HP が 0 になると消されてゲームオーバー。
## 鉛筆（プレイヤー）が近くで修理すると描き直される。

signal hp_changed(hp: float, max_hp: float)
signal destroyed

@export var max_hp: float = 300.0
@export var radius: float = 40.0

var hp: float
var _destroyed := false
var _hit_flash := 0.0
var _t := 0.0
var _cracks: Array[PackedVector2Array] = []
var _smudges: Array[Vector3] = []


func _ready() -> void:
	hp = max_hp
	add_to_group(&"core")
	material = DoodleStyle.doodle_material(1.0, 1.0)
	_make_damage_marks()
	hp_changed.emit(hp, max_hp)


func _make_damage_marks() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7331
	for i in range(8):
		var crack := PackedVector2Array()
		var p := Vector2(rng.randf_range(-40.0, 40.0), rng.randf_range(-60.0, 20.0))
		crack.append(p)
		for k in range(4):
			p += Vector2(rng.randf_range(-9.0, 9.0), rng.randf_range(4.0, 11.0))
			crack.append(p)
		_cracks.append(crack)
	for i in range(6):
		_smudges.append(Vector3(rng.randf_range(-42.0, 42.0), rng.randf_range(-70.0, 20.0), rng.randf_range(8.0, 16.0)))


func _process(delta: float) -> void:
	_t += delta
	_hit_flash = maxf(0.0, _hit_flash - delta)
	queue_redraw()


func take_damage(amount: float, _source: Node = null) -> void:
	if _destroyed:
		return
	hp = maxf(0.0, hp - amount)
	_hit_flash = 0.12
	hp_changed.emit(hp, max_hp)
	Fx.damage_number(global_position + Vector2(0.0, -80.0), amount, DoodleStyle.HP_LOW)
	Fx.decal(global_position + Vector2(randf_range(-40.0, 40.0), randf_range(-6.0, 20.0)), DoodleStyle.ERASER_PINK, 3, 10.0)
	if hp <= 0.0:
		_destroyed = true
		Fx.burst(global_position + Vector2(0.0, -30.0), DoodleStyle.CASTLE_WALL, 3.0, 30)
		Fx.shake(16.0)
		destroyed.emit()


func repair(amount: float) -> void:
	if _destroyed:
		return
	hp = minf(max_hp, hp + amount)
	hp_changed.emit(hp, max_hp)


func is_destroyed() -> bool:
	return _destroyed


func _draw() -> void:
	var ratio := hp / max_hp if max_hp > 0.0 else 0.0
	DoodleStyle.draw_shadow(self, Vector2(0.0, 30.0), Vector2(66.0, 14.0))
	var wall := DoodleStyle.CASTLE_WALL
	if _hit_flash > 0.0:
		wall = wall.lerp(Color.WHITE, 0.7)
	var roof := DoodleStyle.CASTLE_ROOF
	# 左右の塔
	for side in [-1.0, 1.0]:
		var x0: float = side * 44.0
		DoodleStyle.draw_shape(self, PackedVector2Array([
			Vector2(x0 - 14.0, 32.0), Vector2(x0 + 14.0, 32.0), Vector2(x0 + 14.0, -56.0), Vector2(x0 - 14.0, -56.0)]), wall)
		DoodleStyle.draw_shape(self, PackedVector2Array([
			Vector2(x0 - 19.0, -54.0), Vector2(x0 + 19.0, -54.0), Vector2(x0, -86.0)]), roof)
		DoodleStyle.draw_shape(self, DoodleStyle.rounded_rect(Rect2(x0 - 5.0, -38.0, 10.0, 14.0), 5.0), DoodleStyle.INK, 2.0)
	# 本丸
	DoodleStyle.draw_shape(self, PackedVector2Array([
		Vector2(-32.0, 32.0), Vector2(32.0, 32.0), Vector2(32.0, -40.0), Vector2(20.0, -40.0), Vector2(20.0, -50.0),
		Vector2(8.0, -50.0), Vector2(8.0, -40.0), Vector2(-8.0, -40.0), Vector2(-8.0, -50.0), Vector2(-20.0, -50.0),
		Vector2(-20.0, -40.0), Vector2(-32.0, -40.0)]), wall)
	# 扉
	var door := PackedVector2Array([Vector2(-12.0, 32.0), Vector2(12.0, 32.0), Vector2(12.0, 6.0)])
	for i in range(9):
		var a := PI * i / 8.0
		door.append(Vector2(cos(a) * 12.0, 6.0 - sin(a) * 12.0))
	door.append(Vector2(-12.0, 6.0))
	DoodleStyle.draw_shape(self, door, Color("8a5a3c"))
	# 旗
	draw_line(Vector2(0.0, -50.0), Vector2(0.0, -96.0), DoodleStyle.INK, 3.0, true)
	var wave := sin(_t * 5.0) * 4.0
	DoodleStyle.draw_shape(self, PackedVector2Array([
		Vector2(0.0, -96.0), Vector2(26.0, -90.0 + wave), Vector2(0.0, -82.0)]), DoodleStyle.CASTLE_FLAG, 2.5)
	# 傷: HP が減るほどヒビと消し跡が増える
	var damage := 1.0 - ratio
	var crack_count := int(round(damage * _cracks.size()))
	for i in range(crack_count):
		draw_polyline(_cracks[i], DoodleStyle.INK, 2.0, true)
	var smudge_count := int(round(maxf(0.0, damage - 0.35) / 0.65 * _smudges.size()))
	for i in range(smudge_count):
		var s := _smudges[i]
		draw_colored_polygon(DoodleStyle.ellipse(Vector2(s.x, s.y), Vector2(s.z, s.z * 0.6), 14), Color(DoodleStyle.PAPER, 0.85))
