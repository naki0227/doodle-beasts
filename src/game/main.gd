extends Node2D
## ゲーム1回分の配線。拠点・プレイヤー・波・HUD をつなぎ、ゲームオーバーとやり直しを扱う。

@onready var core: Core = $Core
@onready var wave_manager: WaveManager = $WaveManager
@onready var hud: CanvasLayer = $HUD
@onready var players: Node2D = $Players
@onready var allies: Node2D = $Allies

const BEAST_SCENE := preload("res://src/game/beast.tscn")

var game_over := false
var beast: Beast


func _ready() -> void:
	core.hp_changed.connect(hud.set_core_hp)
	core.destroyed.connect(_on_core_destroyed)
	wave_manager.wave_started.connect(hud.set_wave)
	wave_manager.enemy_count_changed.connect(hud.set_enemy_count)
	wave_manager.countdown_changed.connect(hud.set_countdown)
	for node in players.get_children():
		var player := node as Player
		if player == null:
			continue
		player.hp_changed.connect(func(hp: float, max_hp: float) -> void:
			hud.set_player_status(player.player_index, hp, max_hp, player.downed))
		player.downed_changed.connect(func(downed: bool) -> void:
			hud.set_player_status(player.player_index, player.hp, player.max_hp, downed))
		hud.set_player_status(player.player_index, player.hp, player.max_hp, player.downed)
	hud.set_core_hp(core.hp, core.max_hp)
	_spawn_beast_from_session()
	wave_manager.start()


## 描画フェーズで保存した線があれば、そこから生き物を作って拠点のそばに置く。
func _spawn_beast_from_session() -> void:
	var session := get_node_or_null("/root/GameSession")
	if session == null or not session.has_beast():
		return
	beast = BEAST_SCENE.instantiate() as Beast
	beast.position = core.position + Vector2(0.0, -120.0)
	allies.add_child(beast)
	beast.build(session.body_strokes, session.weapon_strokes, session.ink_budget)
	beast.hp_changed.connect(func(hp: float, max_hp: float) -> void:
		hud.set_beast_status(beast.weapon_label(), hp, max_hp))
	beast.died.connect(func(_beast: Beast) -> void:
		hud.set_beast_status("", 0.0, 0.0))
	hud.set_beast_status(beast.weapon_label(), beast.hp, beast.max_hp)


func _on_core_destroyed() -> void:
	if game_over:
		return
	game_over = true
	wave_manager.stop()
	hud.show_game_over(wave_manager.wave)
	get_tree().paused = true


func _draw() -> void:
	var arena := wave_manager.arena
	draw_rect(arena.grow(-2.0), Color(0.3, 0.35, 0.45), false, 3.0)
