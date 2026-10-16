class_name Core
extends StaticBody2D
## 全員で守る「金の駒」。刻む者の石碑の上に浮かび、新しい世界のかたちを生む種。
## 霜の獣に触れられると石碑に霜とヒビが広がり、HP が 0 になると駒が凍りついてゲームオーバー。
## 旅人（プレイヤー）が近くで手をかざすと直る。

signal hp_changed(hp: float, max_hp: float)
signal destroyed

@export var max_hp: float = 300.0
@export var radius: float = 40.0

var hp: float
var _destroyed := false
var _hit_flash := 0.0
var _t := 0.0
var _cracks: Array[PackedVector2Array] = []
var _frost: Array[Vector3] = []


func _ready() -> void:
	hp = max_hp
	add_to_group(&"core")
	material = DoodleStyle.surface_material(1.0, 0.6)
	GlowNode.attach(self)
	_make_damage_marks()
	hp_changed.emit(hp, max_hp)


func _make_damage_marks() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7331
	for i in range(7):
		var crack := PackedVector2Array()
		var p := Vector2(rng.randf_range(-16.0, 16.0), rng.randf_range(-74.0, -20.0))
		crack.append(p)
		for k in range(4):
			p += Vector2(rng.randf_range(-6.0, 6.0), rng.randf_range(4.0, 10.0))
			crack.append(p)
		_cracks.append(crack)
	for i in range(40):
		_frost.append(Vector3(rng.randf_range(-28.0, 28.0), rng.randf_range(-80.0, 12.0), rng.randf_range(1.0, 2.5)))


func _process(delta: float) -> void:
	_t += delta
	_hit_flash = maxf(0.0, _hit_flash - delta)
	queue_redraw()


func take_damage(amount: float, _source: Node = null) -> void:
	if _destroyed:
		return
	# 盾を持った獣がそばにいれば、傷が減る。
	for node in get_tree().get_nodes_in_group(&"beasts"):
		if node.has_method("shield_reduction"):
			amount *= 1.0 - float(node.shield_reduction(global_position))
	hp = maxf(0.0, hp - amount)
	Sound.play("seed_hit")
	_hit_flash = 0.12
	hp_changed.emit(hp, max_hp)
	Fx.damage_number(global_position + Vector2(0.0, -150.0), amount, DoodleStyle.HP_LOW)
	Fx.decal(global_position + Vector2(randf_range(-40.0, 40.0), randf_range(0.0, 20.0)), DoodleStyle.FROST, 3, 10.0)
	if hp <= 0.0:
		_destroyed = true
		Fx.burst(global_position + Vector2(0.0, -110.0), DoodleStyle.FROST, 3.0, 30)
		Fx.shake(16.0)
		Sound.play("shatter", 3.0, 0.0)
		destroyed.emit()


func repair(amount: float) -> void:
	if _destroyed:
		return
	hp = minf(max_hp, hp + amount)
	hp_changed.emit(hp, max_hp)


func is_destroyed() -> bool:
	return _destroyed


func ratio() -> float:
	return hp / max_hp if max_hp > 0.0 else 0.0


func _seed_center() -> Vector2:
	return Vector2(0.0, -118.0 + sin(_t * 1.6) * 5.0)


func draw_glow_into(canvas: Node2D) -> void:
	var r := ratio()
	var pulse := 0.8 + 0.2 * sin(_t * 2.0)
	if _destroyed:
		return
	DoodleStyle.draw_glow(canvas, _seed_center(), 90.0, DoodleStyle.GOLD, (0.3 + 0.6 * r) * pulse)
	DoodleStyle.draw_glow(canvas, Vector2(0.0, -40.0), 50.0, DoodleStyle.GOLD, 0.25 * r)


func _draw() -> void:
	var r := ratio()
	DoodleStyle.draw_shadow(self, Vector2(0.0, 16.0), Vector2(62.0, 16.0))
	# 土台の敷石
	DoodleStyle.draw_shape(self, DoodleStyle.ellipse(Vector2(0.0, 10.0), Vector2(56.0, 17.0), 22), DoodleStyle.STONE, 2.0, DoodleStyle.INK)
	DoodleStyle.draw_shape(self, DoodleStyle.ellipse(Vector2(0.0, 6.0), Vector2(46.0, 12.0), 20), DoodleStyle.STONE.lightened(0.1), 1.5, DoodleStyle.STONE_DARK)
	# 石碑
	var stone := DoodleStyle.STONE_DARK.lightened(0.15)
	if _hit_flash > 0.0:
		stone = stone.lerp(DoodleStyle.FROST, 0.6)
	DoodleStyle.draw_shape(self, PackedVector2Array([
		Vector2(-24, 6), Vector2(24, 6), Vector2(20, -76), Vector2(8, -88), Vector2(-12, -86), Vector2(-21, -74)]), stone, 2.0, DoodleStyle.INK)
	# 刻まれたルーン（金が HP に応じて光る）
	var rune := Color(DoodleStyle.GOLD_LIGHT, 0.35 + 0.65 * r)
	draw_line(Vector2(0, -78), Vector2(0, -10), rune, 2.0)
	draw_polyline(PackedVector2Array([Vector2(-11, -66), Vector2(0, -56), Vector2(11, -66)]), rune, 2.0)
	draw_polyline(PackedVector2Array([Vector2(-11, -40), Vector2(0, -30), Vector2(11, -40)]), rune, 2.0)
	draw_arc(Vector2(0, -48), 9.0, 0.0, TAU, 16, rune, 1.5)
	# 傷: ヒビと霜
	var damage := 1.0 - r
	for i in range(int(round(damage * _cracks.size()))):
		draw_polyline(_cracks[i], DoodleStyle.INK, 1.5)
	for i in range(int(round(damage * _frost.size()))):
		var f := _frost[i]
		draw_circle(Vector2(f.x, f.y), f.z, Color(DoodleStyle.FROST, 0.85))
	# 金の駒
	if not _destroyed:
		var seed_color := DoodleStyle.GOLD.lerp(DoodleStyle.FROST_DEEP, damage * 0.6)
		DoodleStyle.draw_d20(self, _seed_center(), 16.0, seed_color)
	else:
		DoodleStyle.draw_d20(self, Vector2(0.0, -96.0), 16.0, DoodleStyle.FROST_DEEP, DoodleStyle.INK)
