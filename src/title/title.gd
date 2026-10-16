extends Node2D
## タイトル画面。夕暮れのはかり野の遠景、崖の上の旅人、草地に立つ見本の獣、題字、はじめかた。
## ボタンかクリックで描画フェーズへ。

const NEXT_SCENE := "res://src/draw/draw_phase.tscn"
const BEAST_SCENE := preload("res://src/game/beast.tscn")
## 題字。設定シート「はかり野 — よみがえりの大地」から取った製品名。
const TITLE := "はかり野"
const SUBTITLE := "よみがえりの大地"
const TAGLINE := "描いたかたちが獣になってよみがえり、そのかたちのとおりに戦う"

var _t := 0.0
var _leaving := false
var _fade := 1.0
var _mascot: Beast

@onready var _text: Node2D = $Text/Canvas
@onready var _foreground: Node2D = $Foreground


func _ready() -> void:
	Engine.time_scale = 1.0
	Sound.music("bgm_ambient", 2.5)
	_text.set("title_screen", self)
	_foreground.set("title_screen", self)
	_mascot = BEAST_SCENE.instantiate() as Beast
	_mascot.target_size = 170.0
	_mascot.position = Vector2(930.0, 560.0)
	add_child(_mascot)
	_mascot.build(SampleDoodles.body(), SampleDoodles.weapon(), 3000.0)
	var tree_node := _mascot.get_node("BehaviorTree") as BehaviorTree
	tree_node.enabled = false


func _process(delta: float) -> void:
	_t += delta
	_fade = maxf(0.0, _fade - delta * 1.5) if not _leaving else minf(1.0, _fade + delta * 3.0)
	if not _leaving:
		for action in ["ui_accept", "p1_done", "p2_done", "p1_attack", "p2_attack"]:
			if Input.is_action_just_pressed(action):
				start()
				break
	if _mascot != null and is_instance_valid(_mascot):
		var weapon := _mascot.get_node_or_null("Visual/Weapon") as Node2D
		if weapon != null:
			weapon.rotation = sin(_t * 1.6) * 0.18
	_text.queue_redraw()
	_foreground.queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and not _leaving:
		start()


func start() -> void:
	if _leaving:
		return
	_leaving = true
	Sound.play("ui", 0.0, 0.0)
	var session := get_node_or_null("/root/GameSession")
	if session != null:
		session.reset_run()
	await get_tree().create_timer(0.4).timeout
	get_tree().change_scene_to_file(NEXT_SCENE)


## 世界の中の手前の景色（ピクセル化される）。崖と、遠くを見る旅人。
func draw_foreground(c: Node2D) -> void:
	var ledge := PackedVector2Array([Vector2(-40, 720), Vector2(-40, 520), Vector2(60, 500), Vector2(170, 512), Vector2(260, 530), Vector2(330, 560), Vector2(380, 720)])
	DoodleStyle.draw_shape(c, ledge, DoodleStyle.STONE_DARK.darkened(0.25), 0.0)
	c.draw_colored_polygon(PackedVector2Array([Vector2(-40, 520), Vector2(60, 500), Vector2(170, 512), Vector2(260, 530), Vector2(250, 540), Vector2(160, 524), Vector2(60, 512), Vector2(-40, 532)]), DoodleStyle.MOSS)
	for i in range(14):
		var x := -30.0 + i * 21.0
		var y := 506.0 + absf(x - 60.0) * 0.08
		c.draw_line(Vector2(x, y), Vector2(x + 3.0, y - 10.0 - (i % 3) * 4.0), DoodleStyle.MOSS_DARK, 2.0)
	# 石碑
	c.draw_colored_polygon(PackedVector2Array([Vector2(36, 506), Vector2(70, 504), Vector2(66, 420), Vector2(52, 410), Vector2(38, 418)]), DoodleStyle.STONE_DARK)
	var rune := Color(DoodleStyle.GOLD_LIGHT, 0.6 + 0.3 * sin(_t * 1.4))
	c.draw_line(Vector2(52, 424), Vector2(52, 494), rune, 2.0)
	c.draw_arc(Vector2(52, 452), 8.0, 0.0, TAU, 14, rune, 1.5)
	# 旅人の後ろ姿（シルエット）
	var p := Vector2(170.0, 512.0)
	var sil := Color("16181e")
	c.draw_colored_polygon(PackedVector2Array([p + Vector2(-10, 0), p + Vector2(10, 0), p + Vector2(8, -36), p + Vector2(-8, -36)]), sil)
	c.draw_colored_polygon(PackedVector2Array([p + Vector2(-15, -40), p + Vector2(-6, -42), p + Vector2(-5, -18), p + Vector2(-14, -16)]), sil)
	c.draw_circle(p + Vector2(0, -42), 6.0, sil)
	c.draw_colored_polygon(DoodleStyle.ellipse(p + Vector2(0, -46), Vector2(16, 3.5), 14), sil)
	c.draw_colored_polygon(PackedVector2Array([p + Vector2(-6, -47), p + Vector2(6, -47), p + Vector2(4, -58), p + Vector2(-4, -58)]), sil)
	c.draw_line(p + Vector2(12, 0), p + Vector2(15, -66), sil, 2.5)
	c.draw_colored_polygon(PackedVector2Array([p + Vector2(-8, -38), p + Vector2(-20 + sin(_t * 2.0) * 3.0, -30), p + Vector2(-8, -30)]), Color("2b3a55"))


## 文字（ピクセル化されない層）。
func draw_text_layer(c: Node2D) -> void:
	var x := 470.0
	DoodleStyle.draw_text(c, DoodleStyle.HAND_FONT, Vector2(x + 4.0, 168.0), TITLE, 104, Color(0, 0, 0, 0.45))
	DoodleStyle.draw_text(c, DoodleStyle.HAND_FONT, Vector2(x, 162.0), TITLE, 104, DoodleStyle.CREAM, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, DoodleStyle.NIGHT)
	var w := DoodleStyle.HAND_FONT.get_string_size(TITLE, HORIZONTAL_ALIGNMENT_LEFT, -1, 104).x
	c.draw_line(Vector2(x, 186.0), Vector2(x + w, 186.0), Color(DoodleStyle.GOLD, 0.9), 1.5)
	DoodleStyle.draw_d20(c, Vector2(x + w + 34.0, 120.0 + sin(_t * 1.6) * 4.0), 18.0)
	DoodleStyle.draw_text(c, DoodleStyle.HAND_FONT, Vector2(x, 226.0), "— " + SUBTITLE, 30, DoodleStyle.GOLD_LIGHT, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, DoodleStyle.NIGHT)
	DoodleStyle.draw_text(c, DoodleStyle.UI_FONT, Vector2(x, 264.0), TAGLINE, 20, DoodleStyle.CREAM, HORIZONTAL_ALIGNMENT_LEFT, -1, 6, DoodleStyle.NIGHT)
	var blink := 0.55 + 0.45 * sin(_t * 3.0)
	var rect := Rect2(490.0, 620.0, 300.0, 46.0)
	DoodleStyle.draw_panel(c, rect, 0.6 + 0.4 * blink)
	DoodleStyle.draw_text(c, DoodleStyle.HAND_FONT, rect.position + Vector2(0.0, 31.0), "A・Enter・クリック で はじめる", 18, Color(DoodleStyle.CREAM, 0.6 + 0.4 * blink), HORIZONTAL_ALIGNMENT_CENTER, rect.size.x)
	DoodleStyle.draw_text(c, DoodleStyle.UI_FONT, Vector2(0.0, 704.0), "1〜2人で協力　ゲームパッド・キーボード・マウス　Remote Play Together 対応", 14, Color(DoodleStyle.CREAM, 0.6), HORIZONTAL_ALIGNMENT_CENTER, 1280.0, 4)
	if _fade > 0.0:
		c.draw_rect(Rect2(0.0, 0.0, 1280.0, 720.0), Color(DoodleStyle.NIGHT, _fade))
