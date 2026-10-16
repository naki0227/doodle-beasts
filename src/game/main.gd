extends Node2D
## 戦闘 1 回分の配線。戦闘は自動で進む（獣も旅人もビヘイビアツリーで動く）。
## 金の駒・旅人たち・波・HUD をつなぎ、波を守ったら記録帳へ戻り、駒が凍ったらゲームオーバー。

const BEAST_SCENE := preload("res://src/game/beast.tscn")
const DRAW_SCENE := "res://src/draw/draw_phase.tscn"

## false なら波を守っても記録帳へ戻らず、そのまま次の波へ（シミュレーション用）。
@export var redraw_between_waves: bool = true

@onready var core: Core = $Core
@onready var wave_manager: WaveManager = $WaveManager
@onready var hud: CanvasLayer = $HUD
@onready var players: Node2D = $Players
@onready var allies: Node2D = $Allies

var game_over := false
var beast: Beast


func _ready() -> void:
	Fx.hitstop_enabled = true
	Engine.time_scale = 1.0
	Sound.music("bgm_battle", 2.0)
	var session := get_node_or_null("/root/GameSession")
	if session != null and session.core_hp > 0.0:
		core.hp = minf(core.max_hp, session.core_hp)
	core.hp_changed.connect(hud.set_core_hp)
	core.destroyed.connect(_on_core_destroyed)
	wave_manager.auto_continue = not redraw_between_waves
	wave_manager.wave_started.connect(_on_wave_started)
	wave_manager.wave_cleared.connect(_on_wave_cleared)
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
	var first_wave: int = session.next_wave if session != null else 1
	wave_manager.start(first_wave)


## 記録帳に描いた線から獣を作って、石碑のそばに降ろす。
func _spawn_beast_from_session() -> void:
	var session := get_node_or_null("/root/GameSession")
	if session == null or not session.has_beast():
		return
	beast = BEAST_SCENE.instantiate() as Beast
	beast.position = core.position + Vector2(210.0, 10.0)
	allies.add_child(beast)
	beast.build(session.body_strokes, session.weapon_strokes, session.ink_budget)
	beast.hp_changed.connect(func(hp: float, max_hp: float) -> void:
		hud.set_beast_status(beast.behavior_summary(), hp, max_hp))
	beast.died.connect(func(_beast: Beast) -> void:
		hud.set_beast_status("", 0.0, 0.0))
	hud.set_beast_status(beast.behavior_summary(), beast.hp, beast.max_hp)
	beast.play_entrance()


func _on_wave_started(wave: int) -> void:
	hud.set_wave(wave)
	Sound.play("horn", 0.0, 0.0)


func _on_wave_cleared(wave: int) -> void:
	if game_over:
		return
	if not redraw_between_waves:
		return
	Sound.play("wave_clear", 0.0, 0.0)
	hud.show_wave_cleared(wave)
	var session := get_node_or_null("/root/GameSession")
	if session != null:
		session.wave_cleared(wave, core.hp)
	await get_tree().create_timer(3.2).timeout
	if game_over or not is_inside_tree():
		return
	Sound.music("bgm_ambient", 2.0)
	get_tree().change_scene_to_file(DRAW_SCENE)


func _on_core_destroyed() -> void:
	if game_over:
		return
	game_over = true
	wave_manager.stop()
	hud.show_game_over(wave_manager.wave)
	Sound.stop_music(1.0)
	Sound.play("gameover", 0.0, 0.0)
	await get_tree().create_timer(0.6).timeout
	Engine.time_scale = 1.0
	get_tree().paused = true


func _exit_tree() -> void:
	Fx.hitstop_enabled = false
	Engine.time_scale = 1.0
