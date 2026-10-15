extends Node2D
## 描画フェーズ。左のページに「からだ」、右のページに「ぶき」を同時に描き、時間切れか両者の完了で合体する。
## 描いている最中に解析結果（ステータスと武器の判定）を付箋に表示する。

const MAIN_SCENE := "res://src/game/main.tscn"

@export var time_limit: float = 60.0

@onready var body_panel: DrawPanel = $BodyPanel
@onready var weapon_panel: DrawPanel = $WeaponPanel

var remaining := 0.0
var merging := false

var _t := 0.0
var _body_info: Dictionary = {}
var _weapon_kind: ShapeAnalyzer.Weapon = ShapeAnalyzer.Weapon.NONE
var _weapon_pop := 0.0
var _flash := 0.0
var _merge_text := 0.0
var _fade_in := 1.0
var _fade_out := 0.0
var _overlay: Overlay


class Overlay:
	extends Node2D
	var phase: Node

	func _draw() -> void:
		phase.draw_overlay(self)


func _ready() -> void:
	remaining = time_limit
	_overlay = Overlay.new()
	_overlay.phase = self
	_overlay.z_index = 50
	add_child(_overlay)
	body_panel.changed.connect(_refresh_body)
	weapon_panel.changed.connect(_refresh_weapon)
	body_panel.done_changed.connect(_on_done_changed)
	weapon_panel.done_changed.connect(_on_done_changed)
	var session := get_node_or_null("/root/GameSession")
	if session != null and session.has_beast():
		body_panel.load_strokes(session.body_strokes)
		weapon_panel.load_strokes(session.weapon_strokes)
	_refresh_body()
	_refresh_weapon()


func _process(delta: float) -> void:
	_t += delta
	_weapon_pop = maxf(0.0, _weapon_pop - delta * 3.0)
	_flash = maxf(0.0, _flash - delta * 2.5)
	_fade_in = maxf(0.0, _fade_in - delta * 2.5)
	if not merging:
		remaining = maxf(0.0, remaining - delta)
		if body_panel.drawing:
			_refresh_body()
		if weapon_panel.drawing:
			_refresh_weapon()
		if remaining <= 0.0:
			merge()
	queue_redraw()
	_overlay.queue_redraw()


func _on_done_changed(_done: bool) -> void:
	if body_panel.done and weapon_panel.done:
		merge()


func _refresh_body() -> void:
	_body_info = ShapeAnalyzer.analyze_body(body_panel.strokes_with_current(), body_panel.ink_budget)


func _refresh_weapon() -> void:
	var kind := ShapeAnalyzer.classify_weapon(weapon_panel.strokes_with_current())
	if kind != _weapon_kind:
		_weapon_pop = 1.0
	_weapon_kind = kind


## 合体。線を保存し、演出のあと戦闘へ。
func merge() -> void:
	if merging:
		return
	merging = true
	body_panel.set_done(true)
	weapon_panel.set_done(true)
	body_panel.locked = true
	weapon_panel.locked = true
	var session := get_node_or_null("/root/GameSession")
	if session != null:
		session.store(body_panel.strokes, weapon_panel.strokes, body_panel.ink_budget)
	await get_tree().create_timer(0.5).timeout
	var tween := create_tween().set_parallel(true).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_BACK)
	var middle := Vector2(640.0, 380.0)
	tween.tween_property(body_panel, "position", middle - body_panel.panel_size * 0.25 + Vector2(-30.0, 0.0), 0.6)
	tween.tween_property(body_panel, "scale", Vector2(0.5, 0.5), 0.6)
	tween.tween_property(body_panel, "rotation", -0.15, 0.6)
	tween.tween_property(weapon_panel, "position", middle - weapon_panel.panel_size * 0.25 + Vector2(30.0, 0.0), 0.6)
	tween.tween_property(weapon_panel, "scale", Vector2(0.5, 0.5), 0.6)
	tween.tween_property(weapon_panel, "rotation", 0.15, 0.6)
	await tween.finished
	_flash = 1.0
	_merge_text = 0.001
	var text_tween := create_tween()
	text_tween.tween_property(self, "_merge_text", 1.0, 0.9)
	await get_tree().create_timer(1.1).timeout
	var fade := create_tween()
	fade.tween_property(self, "_fade_out", 1.0, 0.25)
	await fade.finished
	get_tree().change_scene_to_file(MAIN_SCENE)


func _draw() -> void:
	DoodleStyle.draw_text(self, DoodleStyle.HAND_FONT, Vector2(0.0, 40.0), "みんなで ビーストを 描こう！", 32, DoodleStyle.PAPER, HORIZONTAL_ALIGNMENT_CENTER, 1280.0, 8, Color(0, 0, 0, 0.45))
	if merging:
		return
	_draw_body_note(Rect2(70.0, 56.0, 480.0, 86.0))
	_draw_weapon_note(Rect2(730.0, 56.0, 480.0, 86.0))
	_draw_stopwatch(Vector2(640.0, 380.0))


func _sticky(rect: Rect2, color: Color, tilt: float) -> void:
	draw_set_transform(rect.get_center(), tilt, Vector2.ONE)
	var local := Rect2(-rect.size * 0.5, rect.size)
	draw_colored_polygon(DoodleStyle.rounded_rect(Rect2(local.position + Vector2(4.0, 6.0), local.size), 4.0), Color(0, 0, 0, 0.3))
	draw_colored_polygon(DoodleStyle.rounded_rect(local, 4.0), color)
	draw_rect(Rect2(local.position, Vector2(local.size.x, 8.0)), color.darkened(0.08))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_body_note(rect: Rect2) -> void:
	_sticky(rect, Color("fff3a6"), -0.012)
	var trait_text: String = _body_info.get("trait", "")
	DoodleStyle.draw_text(self, DoodleStyle.HAND_FONT, rect.position + Vector2(14.0, 28.0), trait_text, 22, DoodleStyle.INK)
	var stats := [
		["HP", _body_info.get("hp", 0.0), 440.0, DoodleStyle.HP_GOOD],
		["こうげき", _body_info.get("attack", 0.0), 58.0, DoodleStyle.HP_LOW],
		["はやさ", _body_info.get("speed", 0.0), 400.0, DoodleStyle.CASTLE_FLAG],
		["まもり", _body_info.get("defense", 0.0) * 100.0, 60.0, DoodleStyle.SLEEVE_HARD],
	]
	for i in range(stats.size()):
		var stat: Array = stats[i]
		var column := float(i % 2)
		var row := float(i / 2)
		var origin := rect.position + Vector2(14.0 + column * 232.0, 52.0 + row * 20.0)
		DoodleStyle.draw_text(self, DoodleStyle.UI_FONT, origin, stat[0], 13, DoodleStyle.INK)
		DoodleStyle.draw_bar(self, Rect2(origin + Vector2(62.0, -10.0), Vector2(150.0, 10.0)), clampf(stat[1] / stat[2], 0.0, 1.0), stat[3])


func _draw_weapon_note(rect: Rect2) -> void:
	_sticky(rect, Color("ffd6e0"), 0.014)
	var label := ShapeAnalyzer.weapon_label(_weapon_kind)
	var hint: String = ShapeAnalyzer.weapon_profile(_weapon_kind)["hint"]
	DoodleStyle.draw_text(self, DoodleStyle.UI_FONT, rect.position + Vector2(14.0, 30.0), "これは…", 16, DoodleStyle.INK)
	var size := int(36.0 * (1.0 + 0.45 * _weapon_pop))
	DoodleStyle.draw_text(self, DoodleStyle.HAND_FONT, rect.position + Vector2(90.0, 44.0 + _weapon_pop * 6.0), label + "？", size, DoodleStyle.ACCENT_RED)
	DoodleStyle.draw_text(self, DoodleStyle.UI_FONT, rect.position + Vector2(14.0, 74.0), hint, 14, DoodleStyle.INK_SOFT)


func _draw_stopwatch(center: Vector2) -> void:
	var ratio := remaining / time_limit if time_limit > 0.0 else 0.0
	var urgent := remaining <= 10.0
	var pulse := 1.0 + (0.08 * maxf(0.0, sin(_t * 12.0)) if urgent else 0.0)
	draw_set_transform(center, 0.0, Vector2(pulse, pulse))
	draw_colored_polygon(DoodleStyle.ellipse(Vector2(4.0, 8.0), Vector2(62.0, 62.0), 32), Color(0, 0, 0, 0.3))
	DoodleStyle.draw_shape(self, DoodleStyle.rounded_rect(Rect2(-10.0, -78.0, 20.0, 16.0), 4.0), Color("c8ccd3"), 2.0)
	DoodleStyle.draw_shape(self, DoodleStyle.ellipse(Vector2.ZERO, Vector2(60.0, 60.0), 36), DoodleStyle.PAPER, 3.0)
	var face := DoodleStyle.ACCENT_RED if urgent else DoodleStyle.P1
	if ratio > 0.0:
		var points := PackedVector2Array([Vector2.ZERO])
		var steps := maxi(2, int(36 * ratio))
		for i in range(steps + 1):
			var a := -PI / 2.0 + TAU * ratio * i / steps
			points.append(Vector2(cos(a), sin(a)) * 50.0)
		draw_colored_polygon(points, Color(face, 0.35))
	DoodleStyle.draw_text(self, DoodleStyle.HAND_FONT, Vector2(-60.0, 16.0), str(ceili(remaining)), 44, DoodleStyle.INK, HORIZONTAL_ALIGNMENT_CENTER, 120.0, 6)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	DoodleStyle.draw_text(self, DoodleStyle.HAND_FONT, center + Vector2(-90.0, 100.0), "からだ ＋ ぶき", 22, DoodleStyle.PAPER, HORIZONTAL_ALIGNMENT_CENTER, 180.0, 6, Color(0, 0, 0, 0.45))
	DoodleStyle.draw_text(self, DoodleStyle.HAND_FONT, center + Vector2(-90.0, 132.0), "＝ ビースト", 22, DoodleStyle.P2_LIGHT, HORIZONTAL_ALIGNMENT_CENTER, 180.0, 6, Color(0, 0, 0, 0.45))


func draw_overlay(c: Node2D) -> void:
	if not merging:
		DoodleStyle.draw_text(c, DoodleStyle.UI_FONT, Vector2(0.0, 706.0),
			"スティック / WASD / 矢印 で動かす    A / J / . で描く    X / K / / で一つもどす    Y / L / Enter で完成    P1 はマウスでも描ける",
			14, DoodleStyle.PAPER, HORIZONTAL_ALIGNMENT_CENTER, 1280.0, 4, Color(0, 0, 0, 0.5))
	if _flash > 0.0:
		c.draw_rect(Rect2(0.0, 0.0, 1280.0, 720.0), Color(1.0, 1.0, 1.0, _flash))
	if _merge_text > 0.0:
		var k := _merge_text
		var pop := 1.0 + 2.5 * pow(maxf(0.0, 1.0 - k * 4.0), 2.0)
		var shake := Vector2(sin(_t * 70.0), cos(_t * 60.0)) * 6.0 * maxf(0.0, 1.0 - k * 3.0)
		c.draw_set_transform(Vector2(640.0, 330.0) + shake, -0.08, Vector2(pop, pop))
		for i in range(14):
			var a := TAU * i / 14.0 + _t
			c.draw_line(Vector2(cos(a), sin(a)) * 150.0, Vector2(cos(a), sin(a)) * (260.0 + 30.0 * sin(_t * 9.0 + i)), Color(DoodleStyle.P2_LIGHT, 0.9), 8.0, true)
		DoodleStyle.draw_text(c, DoodleStyle.HAND_FONT, Vector2(-400.0, 40.0), "合体！", 120, DoodleStyle.ACCENT_RED, HORIZONTAL_ALIGNMENT_CENTER, 800.0, 16, DoodleStyle.PAPER)
		c.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	if _fade_in > 0.0:
		c.draw_rect(Rect2(0.0, 0.0, 1280.0, 720.0), Color(1.0, 1.0, 1.0, _fade_in))
	if _fade_out > 0.0:
		c.draw_rect(Rect2(0.0, 0.0, 1280.0, 720.0), Color(1.0, 1.0, 1.0, _fade_out))
