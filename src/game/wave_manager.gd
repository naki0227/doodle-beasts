class_name WaveManager
extends Node
## CPU 側の波（ウェーブ）を管理する。
## カウントダウン → 画面端から敵を順に出す → 全滅を待つ → 次の波、を繰り返すエンドレス構成。
## auto_continue が false なら、波を守ったところで止まり、wave_cleared を受けた側が次をどうするか決める（記録帳へ戻る）。

signal wave_started(wave: int)
signal wave_cleared(wave: int)
signal countdown_changed(seconds: float)
signal enemy_count_changed(count: int)

enum Phase { IDLE, COUNTDOWN, SPAWNING, FIGHTING }

@export var enemy_scene: PackedScene
@export var enemy_container: Node2D
@export var arena: Rect2 = Rect2(0.0, 0.0, 1280.0, 720.0)
@export var first_wave_delay: float = 4.0
@export var time_between_waves: float = 6.0
@export var spawn_interval: float = 0.5
## 0 なら毎回違う配置。固定すると再現テストがしやすい。
@export var random_seed: int = 0
@export var auto_continue: bool = true

var wave := 0
var phase := Phase.IDLE
var alive := 0
## これまでに出した敵の総数。倒した数は spawned_total - alive。
var spawned_total := 0

var _countdown := 0.0
var _to_spawn := 0
var _spawn_timer := 0.0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	if random_seed != 0:
		_rng.seed = random_seed
	else:
		_rng.randomize()


## 波 n に出す敵の数。
static func enemies_for_wave(n: int) -> int:
	return 3 + 2 * (n - 1)


## 波 n の敵の HP 倍率。
static func hp_multiplier_for_wave(n: int) -> float:
	return 1.0 + 0.15 * (n - 1)


## 波 first_wave から始める（記録帳での描き直しをはさんで、続きの波から再開できる）。
func start(first_wave: int = 1) -> void:
	wave = maxi(0, first_wave - 1)
	phase = Phase.COUNTDOWN
	_countdown = first_wave_delay
	countdown_changed.emit(_countdown)


func stop() -> void:
	phase = Phase.IDLE


func _process(delta: float) -> void:
	match phase:
		Phase.COUNTDOWN:
			_countdown -= delta
			countdown_changed.emit(maxf(0.0, _countdown))
			if _countdown <= 0.0:
				_begin_wave()
		Phase.SPAWNING:
			_spawn_timer -= delta
			if _spawn_timer <= 0.0:
				_spawn_one()
				_spawn_timer = spawn_interval
				if _to_spawn <= 0:
					phase = Phase.FIGHTING
		Phase.FIGHTING:
			if alive <= 0:
				if auto_continue:
					phase = Phase.COUNTDOWN
					_countdown = time_between_waves
					countdown_changed.emit(_countdown)
				else:
					phase = Phase.IDLE
				wave_cleared.emit(wave)


func _begin_wave() -> void:
	wave += 1
	_to_spawn = enemies_for_wave(wave)
	_spawn_timer = 0.0
	phase = Phase.SPAWNING
	wave_started.emit(wave)


func _spawn_one() -> void:
	if enemy_scene == null or enemy_container == null:
		push_error("WaveManager に enemy_scene / enemy_container が設定されていません")
		phase = Phase.IDLE
		return
	var enemy := enemy_scene.instantiate() as Enemy
	enemy.max_hp *= hp_multiplier_for_wave(wave)
	enemy.global_position = random_edge_point()
	enemy.died.connect(_on_enemy_died)
	enemy_container.add_child(enemy)
	_to_spawn -= 1
	alive += 1
	spawned_total += 1
	enemy_count_changed.emit(alive)


func _on_enemy_died(_enemy: Enemy) -> void:
	alive = maxi(0, alive - 1)
	enemy_count_changed.emit(alive)


## アリーナの外周上のランダムな点。
func random_edge_point() -> Vector2:
	var side := _rng.randi_range(0, 3)
	var x := _rng.randf_range(arena.position.x, arena.end.x)
	var y := _rng.randf_range(arena.position.y, arena.end.y)
	match side:
		0:
			return Vector2(x, arena.position.y)
		1:
			return Vector2(arena.end.x, y)
		2:
			return Vector2(x, arena.end.y)
		_:
			return Vector2(arena.position.x, y)
