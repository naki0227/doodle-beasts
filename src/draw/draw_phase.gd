extends Node2D
## 描画フェーズ。机の上に開いた記録帳。左のページに「からだ」、右のページに「ぶき」を同時に描き、
## 時間切れか両者の完成で合体する。描いている最中に、読み取ったかたちを札に表示する:
## 性格（戦い方）と目の数（見える範囲）、ステータス、武器とその特別な動き。戦闘は自動なので、ここで描く絵が作戦になる。
## 波を守るたびにここへ戻り、増えたインクで描き直す（前の絵が残っている）。残り時間は燃えて短くなるろうそく。

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
var _glow: GlowNode
var _redraw := false
var _wave := 1
var _last_tick := -1


class Overlay:
	extends Node2D
	var phase: Node

	func _draw() -> void:
		phase.draw_overlay(self)


func _ready() -> void:
	Engine.time_scale = 1.0
	Sound.music("bgm_ambient", 1.5)
	var session := get_node_or_null("/root/GameSession")
	if session != null:
		time_limit = session.draw_seconds()
		_redraw = session.is_redraw()
		_wave = session.next_wave
		body_panel.ink_budget = session.ink_budget
		weapon_panel.ink_budget = session.ink_budget
	remaining = time_limit
	_glow = GlowNode.attach(self)
	_glow.z_index = 40
	_overlay = Overlay.new()
	_overlay.phase = self
	_overlay.z_index = 50
	add_child(_overlay)
	body_panel.changed.connect(_refresh_body)
	weapon_panel.changed.connect(_refresh_weapon)
	body_panel.done_changed.connect(_on_done_changed)
	weapon_panel.done_changed.connect(_on_done_changed)
	if session != null and session.has_beast():
		body_panel.load_strokes(session.body_strokes)
		weapon_panel.load_strokes(session.weapon_strokes)
	_refresh_body()
	_refresh_weapon()


func _process(delta: float) -> void:
	_t += delta
	_weapon_pop = maxf(0.0, _weapon_pop - delta * 3.0)
	_flash = maxf(0.0, _flash - delta * 2.0)
	_fade_in = maxf(0.0, _fade_in - delta * 2.0)
	if not merging:
		remaining = maxf(0.0, remaining - delta)
		if body_panel.drawing:
			_refresh_body()
		if weapon_panel.drawing:
			_refresh_weapon()
		var whole := ceili(remaining)
		if whole != _last_tick and whole <= 5 and whole > 0:
			Sound.play("tick", 0.0, 0.0)
		_last_tick = whole
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
		Sound.play("ui", -4.0)
	_weapon_kind = kind


## 合体。線を保存し、線が金に変わる演出のあと戦闘へ。
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
		session.drawings += 1
	Sound.stop_music(2.5)
	await get_tree().create_timer(0.4).timeout
	Sound.play("merge", 0.0, 0.0)
	var gild := create_tween().set_parallel(true)
	gild.tween_property(body_panel, "gild", 1.0, 0.7)
	gild.tween_property(weapon_panel, "gild", 1.0, 0.7)
	await gild.finished
	var tween := create_tween().set_parallel(true).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_BACK)
	var middle := Vector2(640.0, 360.0)
	tween.tween_property(body_panel, "position", middle - body_panel.panel_size * 0.25 + Vector2(-20.0, 0.0), 0.55)
	tween.tween_property(body_panel, "scale", Vector2(0.5, 0.5), 0.55)
	tween.tween_property(weapon_panel, "position", middle - weapon_panel.panel_size * 0.25 + Vector2(20.0, 0.0), 0.55)
	tween.tween_property(weapon_panel, "scale", Vector2(0.5, 0.5), 0.55)
	await tween.finished
	_flash = 1.0
	_merge_text = 0.001
	create_tween().tween_property(self, "_merge_text", 1.0, 1.0)
	await get_tree().create_timer(1.2).timeout
	var fade := create_tween()
	fade.tween_property(self, "_fade_out", 1.0, 0.35)
	await fade.finished
	get_tree().change_scene_to_file(MAIN_SCENE)


func draw_glow_into(canvas: Node2D) -> void:
	var flicker := 0.85 + 0.15 * sin(_t * 11.0) * sin(_t * 6.1)
	DoodleStyle.draw_glow(canvas, _flame_point(), 120.0, DoodleStyle.LANTERN, flicker)
	DoodleStyle.draw_glow(canvas, Vector2(70.0, 520.0), 50.0, DoodleStyle.GOLD, 0.7 + 0.2 * sin(_t * 2.0))
	if merging:
		var k := maxf(body_panel.gild, weapon_panel.gild)
		DoodleStyle.draw_glow(canvas, Vector2(640.0, 360.0), 420.0, DoodleStyle.GOLD, k * 0.8)


func _candle_ratio() -> float:
	return remaining / time_limit if time_limit > 0.0 else 0.0


func _flame_point() -> Vector2:
	return Vector2(1218.0, 560.0 - 40.0 - 170.0 * _candle_ratio() - 12.0)


func _draw() -> void:
	var heading := "記録帳に、かたちを描く"
	if _redraw:
		heading = "%sへ。かたちを描き直す（インクが増えた）" % DoodleStyle.wave_name(_wave)
	DoodleStyle.draw_text(self, DoodleStyle.HAND_FONT, Vector2(0.0, 26.0), heading, 22, DoodleStyle.CREAM, HORIZONTAL_ALIGNMENT_CENTER, 1280.0, 6)
	_draw_book()
	_draw_candle(Vector2(1218.0, 560.0))
	DoodleStyle.draw_d20(self, Vector2(70.0, 520.0), 18.0)
	if merging:
		return
	_draw_body_label(Rect2(150.0, 36.0, 470.0, 100.0))
	_draw_weapon_label(Rect2(660.0, 36.0, 470.0, 100.0))


func _draw_book() -> void:
	if merging:
		return
	var cover := Rect2(132.0, 140.0, 1016.0, 464.0)
	draw_rect(Rect2(cover.position + Vector2(8.0, 12.0), cover.size), Color(0, 0, 0, 0.45))
	draw_rect(cover, Color("3a271d"))
	draw_rect(cover.grow(-6.0), Color("4b3326"), false, 2.0)
	for x in range(int(cover.position.x) + 16, int(cover.end.x) - 10, 14):
		draw_line(Vector2(x, cover.position.y + 10.0), Vector2(x + 6, cover.position.y + 10.0), Color("8a6a48"), 1.0)
		draw_line(Vector2(x, cover.end.y - 10.0), Vector2(x + 6, cover.end.y - 10.0), Color("8a6a48"), 1.0)
	# 綴じ目の影
	draw_rect(Rect2(620.0, 150.0, 40.0, 440.0), Color(0, 0, 0, 0.35))
	draw_line(Vector2(640.0, 150.0), Vector2(640.0, 590.0), Color(0, 0, 0, 0.5), 3.0)


func _label(rect: Rect2, tilt: float) -> void:
	draw_set_transform(rect.get_center(), tilt, Vector2.ONE)
	var local := Rect2(-rect.size * 0.5, rect.size)
	draw_rect(Rect2(local.position + Vector2(4.0, 6.0), local.size), Color(0, 0, 0, 0.35))
	draw_rect(local, DoodleStyle.PARCHMENT.darkened(0.04))
	draw_rect(local.grow(-4.0), Color(DoodleStyle.SEPIA, 0.35), false, 1.0)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_body_label(rect: Rect2) -> void:
	_label(rect, -0.006)
	var nature: String = _body_info.get("nature", "none")
	var origin := rect.position + Vector2(16.0, 0.0)
	DoodleStyle.draw_text(self, DoodleStyle.HAND_FONT, origin + Vector2(0.0, 28.0), ShapeAnalyzer.nature_label(nature), 22, DoodleStyle.BLOOD)
	DoodleStyle.draw_text(self, DoodleStyle.UI_FONT, origin + Vector2(78.0, 27.0), ShapeAnalyzer.nature_description(nature), 13, DoodleStyle.SEPIA)
	DoodleStyle.draw_text(self, DoodleStyle.UI_FONT, origin + Vector2(0.0, 50.0), ShapeAnalyzer.eyes_text(int(_body_info.get("eyes", 0))), 13, Color(DoodleStyle.SEPIA, 0.85))
	var stats := [
		["体力", _body_info.get("hp", 0.0), 440.0, DoodleStyle.HP_GOOD],
		["力", _body_info.get("attack", 0.0), 58.0, DoodleStyle.HP_LOW],
		["速さ", _body_info.get("speed", 0.0), 400.0, DoodleStyle.SLATE_LIGHT],
		["守り", _body_info.get("defense", 0.0) * 100.0, 60.0, DoodleStyle.GOLD],
	]
	for i in range(stats.size()):
		var stat: Array = stats[i]
		var column := float(i % 2)
		var row := float(i / 2)
		var at := rect.position + Vector2(16.0 + column * 226.0, 72.0 + row * 20.0)
		DoodleStyle.draw_text(self, DoodleStyle.UI_FONT, at, stat[0], 13, DoodleStyle.SEPIA)
		DoodleStyle.draw_bar(self, Rect2(at + Vector2(44.0, -10.0), Vector2(160.0, 10.0)), clampf(stat[1] / stat[2], 0.0, 1.0), stat[3])


func _draw_weapon_label(rect: Rect2) -> void:
	_label(rect, 0.008)
	var label := ShapeAnalyzer.weapon_label(_weapon_kind)
	var profile := ShapeAnalyzer.weapon_profile(_weapon_kind)
	DoodleStyle.draw_text(self, DoodleStyle.UI_FONT, rect.position + Vector2(16.0, 30.0), "読めたかたち", 14, DoodleStyle.SEPIA)
	var size := int(30.0 * (1.0 + 0.4 * _weapon_pop))
	DoodleStyle.draw_text(self, DoodleStyle.HAND_FONT, rect.position + Vector2(120.0, 38.0 + _weapon_pop * 5.0), label + "？", size, DoodleStyle.BLOOD)
	DoodleStyle.draw_text(self, DoodleStyle.UI_FONT, rect.position + Vector2(16.0, 64.0), profile["hint"], 13, Color(DoodleStyle.SEPIA, 0.85))
	var behavior: String = profile.get("behavior", "")
	if behavior != "":
		DoodleStyle.draw_text(self, DoodleStyle.UI_FONT, rect.position + Vector2(16.0, 86.0), "動き：" + behavior, 13, DoodleStyle.BLOOD)


## 残り時間のろうそく。燃えて短くなり、残り 10 秒で炎が揺れる。
func _draw_candle(base: Vector2) -> void:
	var ratio := _candle_ratio()
	var height := 40.0 + 170.0 * ratio
	DoodleStyle.draw_shape(self, DoodleStyle.ellipse(base + Vector2(0.0, 4.0), Vector2(30.0, 9.0), 16), Color("6d5a3e"), 1.5, DoodleStyle.INK)
	var top := base + Vector2(0.0, -height)
	DoodleStyle.draw_shape(self, PackedVector2Array([base + Vector2(-12, 0), base + Vector2(12, 0), top + Vector2(12, 0), top + Vector2(-12, 0)]), Color("e9dfc6"), 1.5, DoodleStyle.INK)
	draw_colored_polygon(PackedVector2Array([top + Vector2(-12, 0), top + Vector2(-6, 18), top + Vector2(-3, 0)]), Color("f6eedb"))
	draw_line(top, top + Vector2(0.0, -8.0), DoodleStyle.INK, 1.5)
	var urgent := remaining <= 10.0
	var sway := sin(_t * (14.0 if urgent else 6.0)) * (3.0 if urgent else 1.5)
	var flame := top + Vector2(sway, -12.0)
	draw_colored_polygon(PackedVector2Array([flame + Vector2(0, -16), flame + Vector2(6, 0), flame + Vector2(0, 6), flame + Vector2(-6, 0)]), DoodleStyle.LANTERN)
	draw_colored_polygon(PackedVector2Array([flame + Vector2(0, -8), flame + Vector2(3, 1), flame + Vector2(0, 4), flame + Vector2(-3, 1)]), DoodleStyle.CREAM)
	DoodleStyle.draw_text(self, DoodleStyle.HAND_FONT, base + Vector2(-60.0, 46.0), str(ceili(remaining)), 30,
		DoodleStyle.HP_LOW if urgent else DoodleStyle.CREAM, HORIZONTAL_ALIGNMENT_CENTER, 120.0, 6)


func draw_overlay(c: Node2D) -> void:
	if not merging:
		DoodleStyle.draw_text(c, DoodleStyle.UI_FONT, Vector2(0.0, 708.0),
			"スティック・WASD・矢印 で動かす　A・J・. で描く　X・K・/ で一つ消す　Y・L・Enter で封をする　旅人1はマウスでも描ける　戦いは自動",
			14, Color(DoodleStyle.CREAM, 0.75), HORIZONTAL_ALIGNMENT_CENTER, 1280.0, 4)
	if _flash > 0.0:
		c.draw_rect(Rect2(0.0, 0.0, 1280.0, 720.0), Color(DoodleStyle.GOLD_LIGHT.lerp(Color.WHITE, 0.5), _flash))
	if _merge_text > 0.0:
		var k := _merge_text
		var alpha := clampf(k * 3.0, 0.0, 1.0)
		var grow := 1.0 + 0.6 * pow(maxf(0.0, 1.0 - k * 3.0), 2.0)
		c.draw_set_transform(Vector2(640.0, 330.0), 0.0, Vector2(grow, grow))
		for i in range(16):
			var a := TAU * i / 16.0 + _t * 0.3
			c.draw_line(Vector2(cos(a), sin(a)) * 170.0, Vector2(cos(a), sin(a)) * (280.0 + 30.0 * sin(_t * 5.0 + i)), Color(DoodleStyle.GOLD_LIGHT, 0.6 * alpha), 2.0)
		DoodleStyle.draw_text(c, DoodleStyle.HAND_FONT, Vector2(-500.0, 30.0), "かたち、よみがえる", 76, Color(DoodleStyle.GOLD_LIGHT, alpha), HORIZONTAL_ALIGNMENT_CENTER, 1000.0, 12, Color(DoodleStyle.NIGHT, alpha))
		c.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	if _fade_in > 0.0:
		c.draw_rect(Rect2(0.0, 0.0, 1280.0, 720.0), Color(DoodleStyle.NIGHT, _fade_in))
	if _fade_out > 0.0:
		c.draw_rect(Rect2(0.0, 0.0, 1280.0, 720.0), Color(DoodleStyle.GOLD_LIGHT.lerp(Color.WHITE, 0.5), _fade_out))
