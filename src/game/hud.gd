extends CanvasLayer
## 戦闘画面の情報表示。すべて手描き風に自前で描く。ゲームオーバー中も動くよう process_mode は Always。

const RESTART_SCENE := "res://src/draw/draw_phase.tscn"

var _core_hp := 0.0
var _core_max := 1.0
var _wave := 0
var _enemies := 0
var _countdown := 0.0
var _players: Dictionary = {}
var _beast_weapon := ""
var _beast_hp := 0.0
var _beast_max := 0.0
var _has_beast := false
var _game_over := false
var _game_over_wave := 0
var _t := 0.0
var _banner := 0.0
var _banner_text := ""
var _fade := 1.0
var _last_count := -1
var _count_pop := 0.0
var _canvas: HudCanvas


class HudCanvas:
	extends Node2D
	var hud: Node

	func _draw() -> void:
		hud.draw_hud(self)


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_canvas = HudCanvas.new()
	_canvas.hud = self
	add_child(_canvas)


func _process(delta: float) -> void:
	_t += delta
	_banner = maxf(0.0, _banner - delta)
	_fade = maxf(0.0, _fade - delta * 2.2)
	_count_pop = maxf(0.0, _count_pop - delta * 3.0)
	_canvas.queue_redraw()


func set_core_hp(hp: float, max_hp: float) -> void:
	_core_hp = hp
	_core_max = max_hp


func set_wave(wave: int) -> void:
	_wave = wave
	_countdown = 0.0
	_banner = 2.0
	_banner_text = "ウェーブ %d" % wave


func set_enemy_count(count: int) -> void:
	_enemies = count


func set_countdown(seconds: float) -> void:
	_countdown = seconds
	var whole := ceili(seconds)
	if whole != _last_count:
		_last_count = whole
		_count_pop = 1.0


func set_player_status(index: int, hp: float, max_hp: float, downed: bool) -> void:
	_players[index] = {"hp": hp, "max": max_hp, "downed": downed}


func set_beast_status(weapon: String, hp: float, max_hp: float) -> void:
	_has_beast = true
	_beast_weapon = weapon
	_beast_hp = hp
	_beast_max = max_hp


func show_game_over(wave: int) -> void:
	_game_over = true
	_game_over_wave = wave


func _unhandled_input(event: InputEvent) -> void:
	if _game_over and event.is_action_pressed("restart"):
		get_tree().paused = false
		get_tree().change_scene_to_file(RESTART_SCENE)


func draw_hud(c: Node2D) -> void:
	_draw_core_card(c)
	_draw_wave_tag(c)
	_draw_team_cards(c)
	_draw_countdown(c)
	_draw_banner(c)
	DoodleStyle.draw_text(c, DoodleStyle.UI_FONT, Vector2(20.0, 706.0),
		"移動  WASD / 矢印 / スティック     攻撃  J / . / A     修理  K / / / X（お城のそばで）", 14,
		Color(DoodleStyle.INK, 0.55))
	if _game_over:
		_draw_game_over(c)
	if _fade > 0.0:
		c.draw_rect(Rect2(0.0, 0.0, 1280.0, 720.0), Color(1.0, 1.0, 1.0, _fade))


func _note(c: Node2D, rect: Rect2, color: Color, tilt: float = 0.0) -> void:
	c.draw_set_transform(rect.get_center(), tilt, Vector2.ONE)
	var local := Rect2(-rect.size * 0.5, rect.size)
	c.draw_colored_polygon(DoodleStyle.rounded_rect(Rect2(local.position + Vector2(3.0, 4.0), local.size), 6.0), DoodleStyle.SHADOW)
	DoodleStyle.draw_shape(c, DoodleStyle.rounded_rect(local, 6.0), color, 2.0)
	c.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_core_card(c: Node2D) -> void:
	_note(c, Rect2(16.0, 14.0, 300.0, 62.0), DoodleStyle.PAPER, -0.01)
	# 小さなお城
	var o := Vector2(46.0, 54.0)
	DoodleStyle.draw_shape(c, PackedVector2Array([o + Vector2(-16, 0), o + Vector2(16, 0), o + Vector2(16, -22), o + Vector2(-16, -22)]), DoodleStyle.CASTLE_WALL, 2.0)
	DoodleStyle.draw_shape(c, PackedVector2Array([o + Vector2(-19, -21), o + Vector2(19, -21), o + Vector2(0, -36)]), DoodleStyle.CASTLE_ROOF, 2.0)
	var ratio := _core_hp / _core_max if _core_max > 0.0 else 0.0
	DoodleStyle.draw_text(c, DoodleStyle.HAND_FONT, Vector2(76.0, 40.0), "おしろ", 20, DoodleStyle.INK)
	DoodleStyle.draw_text(c, DoodleStyle.UI_FONT, Vector2(150.0, 40.0), "%d / %d" % [roundi(_core_hp), roundi(_core_max)], 15, DoodleStyle.INK_SOFT)
	var wobble := 0.0
	if ratio < 0.3 and not _game_over:
		wobble = sin(_t * 20.0) * 1.5
	DoodleStyle.draw_bar(c, Rect2(76.0 + wobble, 50.0, 226.0, 14.0), ratio)


func _draw_wave_tag(c: Node2D) -> void:
	if _wave <= 0:
		return
	var rect := Rect2(540.0, 12.0, 200.0, 50.0)
	_note(c, rect, Color("fff3b0"), 0.02)
	DoodleStyle.draw_text(c, DoodleStyle.HAND_FONT, Vector2(rect.position.x, 46.0), "ウェーブ %d" % _wave, 26, DoodleStyle.INK, HORIZONTAL_ALIGNMENT_CENTER, rect.size.x)
	if _countdown <= 0.0:
		DoodleStyle.draw_text(c, DoodleStyle.UI_FONT, Vector2(rect.position.x, 84.0), "のこりの消しゴム  %d" % _enemies, 15, DoodleStyle.INK, HORIZONTAL_ALIGNMENT_CENTER, rect.size.x, 4)


func _draw_team_cards(c: Node2D) -> void:
	var y := 14.0
	for index in [1, 2]:
		if not _players.has(index):
			continue
		var info: Dictionary = _players[index]
		var color: Color = DoodleStyle.PLAYER_COLORS[index]
		_note(c, Rect2(1004.0, y, 260.0, 40.0), DoodleStyle.PAPER, 0.008 * (index * 2 - 3))
		# 鉛筆の印
		var p := Vector2(1022.0, y + 20.0)
		DoodleStyle.draw_shape(c, PackedVector2Array([p + Vector2(-5, -12), p + Vector2(5, -12), p + Vector2(5, 6), p + Vector2(0, 13), p + Vector2(-5, 6)]), color, 2.0)
		DoodleStyle.draw_text(c, DoodleStyle.HAND_FONT, Vector2(1036.0, y + 27.0), "P%d" % index, 18, DoodleStyle.INK)
		if info["downed"]:
			DoodleStyle.draw_text(c, DoodleStyle.UI_FONT, Vector2(1076.0, y + 26.0), "おれちゃった… ふっかつ待ち", 13, DoodleStyle.HP_LOW)
		else:
			DoodleStyle.draw_bar(c, Rect2(1076.0, y + 14.0, 176.0, 12.0), info["hp"] / maxf(1.0, info["max"]))
		y += 46.0
	if _has_beast:
		_note(c, Rect2(1004.0, y, 260.0, 50.0), DoodleStyle.P1_LIGHT.lerp(DoodleStyle.PAPER, 0.4), -0.01)
		DoodleStyle.draw_text(c, DoodleStyle.HAND_FONT, Vector2(1016.0, y + 22.0), "ビースト", 18, DoodleStyle.INK)
		if _beast_max <= 0.0:
			DoodleStyle.draw_text(c, DoodleStyle.UI_FONT, Vector2(1100.0, y + 22.0), "やぶれちゃった…", 14, DoodleStyle.HP_LOW)
		else:
			DoodleStyle.draw_text(c, DoodleStyle.UI_FONT, Vector2(1100.0, y + 22.0), "ぶき: %s" % _beast_weapon, 14, DoodleStyle.INK)
			DoodleStyle.draw_bar(c, Rect2(1016.0, y + 30.0, 236.0, 11.0), _beast_hp / _beast_max)


func _draw_countdown(c: Node2D) -> void:
	if _countdown <= 0.0 or _game_over:
		return
	var center := Vector2(640.0, 128.0)
	var whole := ceili(_countdown)
	DoodleStyle.draw_text(c, DoodleStyle.HAND_FONT, center + Vector2(-200.0, -20.0), "つぎの消しゴムが来るまで", 20, DoodleStyle.INK, HORIZONTAL_ALIGNMENT_CENTER, 400.0, 6)
	var size := int(64.0 * (1.0 + 0.5 * _count_pop))
	DoodleStyle.draw_text(c, DoodleStyle.HAND_FONT, center + Vector2(-100.0, size * 0.55), str(whole), size, DoodleStyle.ACCENT_RED, HORIZONTAL_ALIGNMENT_CENTER, 200.0, 10)


func _draw_banner(c: Node2D) -> void:
	if _banner <= 0.0:
		return
	var k := 2.0 - _banner
	var slide := 0.0
	if k < 0.25:
		slide = (1.0 - k / 0.25) * -900.0
	elif _banner < 0.3:
		slide = (1.0 - _banner / 0.3) * 900.0
	var center := Vector2(640.0 + slide, 330.0)
	c.draw_set_transform(center, -0.04, Vector2.ONE)
	var band := Rect2(-360.0, -54.0, 720.0, 108.0)
	c.draw_colored_polygon(PackedVector2Array([band.position + Vector2(-20, 6), band.position + Vector2(band.size.x + 20, -6),
		band.end + Vector2(30, 0), Vector2(band.position.x - 30, band.end.y)]), Color(DoodleStyle.INK, 0.9))
	DoodleStyle.draw_text(c, DoodleStyle.HAND_FONT, Vector2(-360.0, -2.0), _banner_text + "！", 56, DoodleStyle.PAPER, HORIZONTAL_ALIGNMENT_CENTER, 720.0)
	DoodleStyle.draw_text(c, DoodleStyle.UI_FONT, Vector2(-360.0, 36.0), "消しゴム軍団がらくがきを消しにきた！", 20, DoodleStyle.P2_LIGHT, HORIZONTAL_ALIGNMENT_CENTER, 720.0)
	c.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_game_over(c: Node2D) -> void:
	c.draw_rect(Rect2(0.0, 0.0, 1280.0, 720.0), Color(DoodleStyle.PAPER, 0.7))
	var center := Vector2(640.0, 330.0)
	c.draw_set_transform(center, -0.03, Vector2.ONE)
	DoodleStyle.draw_text(c, DoodleStyle.HAND_FONT, Vector2(-500.0, -20.0), "お城が消されちゃった…", 64, DoodleStyle.INK, HORIZONTAL_ALIGNMENT_CENTER, 1000.0, 10)
	DoodleStyle.draw_text(c, DoodleStyle.HAND_FONT, Vector2(-500.0, 50.0), "ウェーブ %d まで守った！" % _game_over_wave, 32, DoodleStyle.ACCENT_RED, HORIZONTAL_ALIGNMENT_CENTER, 1000.0, 8)
	var blink := 0.6 + 0.4 * sin(_t * 4.0)
	DoodleStyle.draw_text(c, DoodleStyle.UI_FONT, Vector2(-500.0, 120.0), "R / Start で もういちど描く", 22, Color(DoodleStyle.INK, blink), HORIZONTAL_ALIGNMENT_CENTER, 1000.0, 6)
	c.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
