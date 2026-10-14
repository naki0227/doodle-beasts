extends Node2D
## ゲーム1回分の配線。拠点・プレイヤー・波・HUD をつなぎ、ゲームオーバーとやり直しを扱う。

@onready var core: Core = $Core
@onready var wave_manager: WaveManager = $WaveManager
@onready var hud: CanvasLayer = $HUD
@onready var players: Node2D = $Players

var game_over := false


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
	wave_manager.start()


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
