extends Node2D
## 描画フェーズ。左の枠に「からだ」、右の枠に「ぶき」を同時に描き、時間切れか両者の完了で合体する。
## 描いている最中に解析結果（ステータスと武器の判定）を表示する。

const MAIN_SCENE := "res://src/game/main.tscn"

@export var time_limit: float = 60.0

@onready var body_panel: DrawPanel = $BodyPanel
@onready var weapon_panel: DrawPanel = $WeaponPanel
@onready var timer_label: Label = $HUD/Timer
@onready var body_label: Label = $HUD/BodyInfo
@onready var weapon_label: Label = $HUD/WeaponInfo
@onready var center_label: Label = $HUD/Center

var remaining := 0.0
var merging := false


func _ready() -> void:
	remaining = time_limit
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
	if merging:
		return
	remaining = maxf(0.0, remaining - delta)
	timer_label.text = "のこり %d 秒" % ceili(remaining)
	if remaining <= 0.0:
		merge()


func _on_done_changed(_done: bool) -> void:
	if body_panel.done and weapon_panel.done:
		merge()


func _refresh_body() -> void:
	var info := ShapeAnalyzer.analyze_body(body_panel.strokes_with_current(), body_panel.ink_budget)
	body_label.text = "からだ（P1）\n%s\nHP %d  こうげき %d  はやさ %d  まもり %d%%" % [
		info["trait"], roundi(info["hp"]), roundi(info["attack"]), roundi(info["speed"]), roundi(info["defense"] * 100.0)]


func _refresh_weapon() -> void:
	var kind := ShapeAnalyzer.classify_weapon(weapon_panel.strokes_with_current())
	var profile := ShapeAnalyzer.weapon_profile(kind)
	weapon_label.text = "ぶき（P2）\nこれは… %s？\n%s" % [ShapeAnalyzer.weapon_label(kind), profile["hint"]]


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
	center_label.text = "合体！"
	center_label.visible = true
	var tween := create_tween().set_parallel(true).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_BACK)
	var middle := Vector2(640.0, 360.0)
	tween.tween_property(body_panel, "position", middle - body_panel.panel_size * 0.3, 0.8)
	tween.tween_property(body_panel, "scale", Vector2(0.6, 0.6), 0.8)
	tween.tween_property(weapon_panel, "position", middle - weapon_panel.panel_size * 0.3 + Vector2(40.0, 0.0), 0.8)
	tween.tween_property(weapon_panel, "scale", Vector2(0.6, 0.6), 0.8)
	await tween.finished
	await get_tree().create_timer(0.8).timeout
	get_tree().change_scene_to_file(MAIN_SCENE)
