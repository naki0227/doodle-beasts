extends CanvasLayer
## 戦闘画面の情報表示。暗い板に金の縁、明朝体。ピクセル化の後処理より上にあるので文字はくっきり読める。
## ゲームオーバー中も動くよう process_mode は Always。

const RESTART_SCENE := "res://src/draw/draw_phase.tscn"
const KANJI_NUMBERS := ["〇", "一", "二", "三", "四", "五", "六", "七", "八", "九", "十"]

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
	_fade = maxf(0.0, _fade - delta * 1.6)
	_count_pop = maxf(0.0, _count_pop - delta * 3.0)
	_canvas.queue_redraw()


static func wave_name(n: int) -> String:
	if n <= 10:
		return "第%sの波" % KANJI_NUMBERS[n]
	return "第%dの波" % n


func set_core_hp(hp: float, max_hp: float) -> void:
	_core_hp = hp
	_core_max = max_hp


func set_wave(wave: int) -> void:
	_wave = wave
	_countdown = 0.0
	_banner = 2.4
	_banner_text = wave_name(wave)


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
	_draw_seed_card(c)
	_draw_wave_tag(c)
	_draw_team_cards(c)
	_draw_countdown(c)
	_draw_banner(c)
	DoodleStyle.draw_text(c, DoodleStyle.UI_FONT, Vector2(0.0, 708.0),
		"移動  WASD・矢印・スティック　　杖で打つ  J・.・A　　駒を直す  K・/・X（石碑のそばで）", 14,
		Color(DoodleStyle.CREAM, 0.7), HORIZONTAL_ALIGNMENT_CENTER, 1280.0, 4)
	if _game_over:
		_draw_game_over(c)
	if _fade > 0.0:
		c.draw_rect(Rect2(0.0, 0.0, 1280.0, 720.0), Color(DoodleStyle.GOLD_LIGHT.lerp(Color.WHITE, 0.5), _fade))


func _draw_seed_card(c: Node2D) -> void:
	var rect := Rect2(16.0, 14.0, 310.0, 60.0)
	DoodleStyle.draw_panel(c, rect)
	DoodleStyle.draw_d20(c, Vector2(46.0, 44.0), 16.0)
	var ratio := _core_hp / _core_max if _core_max > 0.0 else 0.0
	DoodleStyle.draw_text(c, DoodleStyle.HAND_FONT, Vector2(76.0, 40.0), "金の駒", 18, DoodleStyle.GOLD_LIGHT)
	DoodleStyle.draw_text(c, DoodleStyle.UI_FONT, Vector2(150.0, 40.0), "%d / %d" % [roundi(_core_hp), roundi(_core_max)], 14, DoodleStyle.CREAM)
	var wobble := sin(_t * 20.0) * 1.5 if ratio < 0.3 and not _game_over else 0.0
	DoodleStyle.draw_bar(c, Rect2(76.0 + wobble, 50.0, 236.0, 12.0), ratio, DoodleStyle.GOLD if ratio > 0.3 else DoodleStyle.HP_LOW)


func _draw_wave_tag(c: Node2D) -> void:
	if _wave <= 0:
		return
	var rect := Rect2(530.0, 14.0, 220.0, 64.0)
	DoodleStyle.draw_panel(c, rect)
	DoodleStyle.draw_text(c, DoodleStyle.HAND_FONT, Vector2(rect.position.x, 46.0), wave_name(_wave), 24, DoodleStyle.CREAM, HORIZONTAL_ALIGNMENT_CENTER, rect.size.x)
	if _countdown <= 0.0:
		DoodleStyle.draw_text(c, DoodleStyle.UI_FONT, Vector2(rect.position.x, 68.0), "のこる霜の獣  %d" % _enemies, 14, DoodleStyle.FROST, HORIZONTAL_ALIGNMENT_CENTER, rect.size.x)
	else:
		DoodleStyle.draw_text(c, DoodleStyle.UI_FONT, Vector2(rect.position.x, 68.0), "ひととき静か", 14, DoodleStyle.FOG, HORIZONTAL_ALIGNMENT_CENTER, rect.size.x)


func _draw_team_cards(c: Node2D) -> void:
	var y := 14.0
	for index in [1, 2]:
		if not _players.has(index):
			continue
		var info: Dictionary = _players[index]
		var color: Color = DoodleStyle.PLAYER_COLORS[index]
		DoodleStyle.draw_panel(c, Rect2(1000.0, y, 264.0, 40.0))
		# 帽子の印
		var p := Vector2(1022.0, y + 24.0)
		c.draw_colored_polygon(DoodleStyle.ellipse(p, Vector2(11.0, 3.0), 12), color.darkened(0.2))
		c.draw_colored_polygon(PackedVector2Array([p + Vector2(-5, 0), p + Vector2(5, 0), p + Vector2(4, -9), p + Vector2(-3, -9)]), color)
		DoodleStyle.draw_text(c, DoodleStyle.HAND_FONT, Vector2(1038.0, y + 27.0), "旅人 %d" % index, 15, DoodleStyle.CREAM)
		if info["downed"]:
			DoodleStyle.draw_text(c, DoodleStyle.UI_FONT, Vector2(1104.0, y + 26.0), "凍えて休んでいる…", 13, DoodleStyle.FROST)
		else:
			DoodleStyle.draw_bar(c, Rect2(1104.0, y + 15.0, 148.0, 11.0), info["hp"] / maxf(1.0, info["max"]))
		y += 46.0
	if _has_beast:
		DoodleStyle.draw_panel(c, Rect2(1000.0, y, 264.0, 52.0))
		DoodleStyle.draw_text(c, DoodleStyle.HAND_FONT, Vector2(1014.0, y + 23.0), "よみがえりの獣", 15, DoodleStyle.GOLD_LIGHT)
		if _beast_max <= 0.0:
			DoodleStyle.draw_text(c, DoodleStyle.UI_FONT, Vector2(1140.0, y + 23.0), "くずれてしまった", 13, DoodleStyle.HP_LOW)
		else:
			DoodleStyle.draw_text(c, DoodleStyle.UI_FONT, Vector2(1140.0, y + 23.0), "ぶき：%s" % _beast_weapon, 13, DoodleStyle.CREAM)
			DoodleStyle.draw_bar(c, Rect2(1014.0, y + 32.0, 238.0, 10.0), _beast_hp / _beast_max)


func _draw_countdown(c: Node2D) -> void:
	if _countdown <= 0.0 or _game_over:
		return
	var center := Vector2(640.0, 128.0)
	var whole := ceili(_countdown)
	DoodleStyle.draw_text(c, DoodleStyle.HAND_FONT, center + Vector2(-200.0, -14.0), "霜が来るまで", 20, DoodleStyle.CREAM, HORIZONTAL_ALIGNMENT_CENTER, 400.0, 6)
	var size := int(56.0 * (1.0 + 0.4 * _count_pop))
	DoodleStyle.draw_text(c, DoodleStyle.HAND_FONT, center + Vector2(-100.0, size * 0.6), str(whole), size, DoodleStyle.GOLD_LIGHT, HORIZONTAL_ALIGNMENT_CENTER, 200.0, 8)


func _draw_banner(c: Node2D) -> void:
	if _banner <= 0.0:
		return
	var k := 2.4 - _banner
	var alpha := clampf(k / 0.35, 0.0, 1.0) * clampf(_banner / 0.5, 0.0, 1.0)
	var center := Vector2(640.0, 330.0)
	var band := Rect2(center.x - 640.0, center.y - 58.0, 1280.0, 116.0)
	c.draw_rect(band, Color(DoodleStyle.NIGHT, 0.75 * alpha))
	var line_w := 900.0 * clampf(k / 0.5, 0.0, 1.0)
	c.draw_line(Vector2(center.x - line_w * 0.5, band.position.y + 8.0), Vector2(center.x + line_w * 0.5, band.position.y + 8.0), Color(DoodleStyle.GOLD, alpha), 1.5)
	c.draw_line(Vector2(center.x - line_w * 0.5, band.end.y - 8.0), Vector2(center.x + line_w * 0.5, band.end.y - 8.0), Color(DoodleStyle.GOLD, alpha), 1.5)
	DoodleStyle.draw_text(c, DoodleStyle.HAND_FONT, Vector2(0.0, center.y + 6.0), _banner_text, 52, Color(DoodleStyle.CREAM, alpha), HORIZONTAL_ALIGNMENT_CENTER, 1280.0)
	DoodleStyle.draw_text(c, DoodleStyle.UI_FONT, Vector2(0.0, center.y + 42.0), "霜の獣が、かたちを凍らせにきた", 18, Color(DoodleStyle.FROST, alpha), HORIZONTAL_ALIGNMENT_CENTER, 1280.0)


func _draw_game_over(c: Node2D) -> void:
	c.draw_rect(Rect2(0.0, 0.0, 1280.0, 720.0), Color(DoodleStyle.NIGHT, 0.72))
	DoodleStyle.draw_d20(c, Vector2(640.0, 230.0), 34.0, DoodleStyle.FROST_DEEP, DoodleStyle.NIGHT)
	DoodleStyle.draw_text(c, DoodleStyle.HAND_FONT, Vector2(0.0, 340.0), "金の駒が、凍りついた", 56, DoodleStyle.CREAM, HORIZONTAL_ALIGNMENT_CENTER, 1280.0, 8)
	DoodleStyle.draw_text(c, DoodleStyle.HAND_FONT, Vector2(0.0, 400.0), "%sまで、かたちを守った" % wave_name(_game_over_wave), 26, DoodleStyle.GOLD_LIGHT, HORIZONTAL_ALIGNMENT_CENTER, 1280.0, 6)
	var blink := 0.55 + 0.45 * sin(_t * 3.0)
	DoodleStyle.draw_text(c, DoodleStyle.UI_FONT, Vector2(0.0, 470.0), "R・Start で、もういちど記録帳に描く", 20, Color(DoodleStyle.CREAM, blink), HORIZONTAL_ALIGNMENT_CENTER, 1280.0, 4)
