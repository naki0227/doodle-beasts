extends SceneTree
## 入力なしでゲームを数秒間走らせ、描いた生き物が敵と戦い、敵が拠点を攻撃するところまでを確認する。
##   godot --headless --path . -s res://tests/simulate.gd
## 拠点がダメージを受けないか、生き物が一度も攻撃しなければ終了コード 1。

const SECONDS := 30.0
const INPUT_SETUP := "res://src/game/input_setup.gd"
const GAME_SESSION := "res://src/game/game_session.gd"
const MAIN_SCENE := "res://src/game/main.tscn"

var _started := false
var _elapsed := 0.0
var _main: Node
var _max_enemies := 0
var _beast: Beast
var _beast_attacks := 0
var _beast_label := ""
var _beast_max_hp := 0.0
var _beast_hp := 0.0
var _beast_died_at := -1.0


func _process(delta: float) -> bool:
	if not _started:
		_started = true
		# 自動読み込みは -s モードでも生きている。無い環境のためだけに手で足す。
		if root.get_node_or_null("InputSetup") == null:
			root.add_child((load(INPUT_SETUP) as GDScript).new())
		var session: Node = root.get_node_or_null("GameSession")
		if session == null:
			session = (load(GAME_SESSION) as GDScript).new()
			session.name = "GameSession"
			root.add_child(session)
		session.store(_sample_body(), _sample_weapon(), 3000.0)
		_main = (load(MAIN_SCENE) as PackedScene).instantiate()
		root.add_child(_main)
		var allies: Node = _main.get_node("Allies")
		if allies.get_child_count() > 0:
			_beast = allies.get_child(0) as Beast
			_beast_label = _beast.weapon_label()
			_beast_max_hp = _beast.max_hp
			print("ビースト生成: %s  HP %.0f  こうげき %.1f  はやさ %.0f  まもり %.0f%%  射程 %.0f" % [
				_beast_label, _beast.max_hp, _beast.attack_damage, _beast.speed, _beast.defense * 100.0, _beast.attack_range])
		return false
	_elapsed += delta
	if is_instance_valid(_beast):
		_beast_attacks = _beast.attacks_landed
		_beast_hp = _beast.hp
	elif _beast != null and _beast_died_at < 0.0:
		_beast_died_at = _elapsed
	_max_enemies = maxi(_max_enemies, _main.get_node("Enemies").get_child_count())
	if _elapsed < SECONDS:
		return false
	var core: Core = _main.get_node("Core")
	var waves: WaveManager = _main.get_node("WaveManager")
	var landed := _beast_attacks if _beast != null else -1
	var beast_text := "ビーストなし"
	if _beast != null:
		var fate := "生存" if _beast_died_at < 0.0 else "%.1f 秒で倒れた" % _beast_died_at
		beast_text = "ビースト（%s）攻撃 %d 回  HP %.0f / %.0f  %s" % [_beast_label, landed, _beast_hp, _beast_max_hp, fate]
	var killed := waves.spawned_total - waves.alive
	print("経過 %.1f 秒  ウェーブ %d  出た敵 %d  倒した敵 %d  拠点 HP %.0f / %.0f  %s" % [
		_elapsed, waves.wave, waves.spawned_total, killed, core.hp, core.max_hp, beast_text])
	var fought := core.hp < core.max_hp or killed >= 1
	var ok := waves.wave >= 1 and waves.spawned_total >= 1 and fought and landed >= 1
	if not ok:
		printerr("戦闘が成立していません（敵が拠点に届かず、倒されてもいないか、ビーストが攻撃していない）")
	quit(0 if ok else 1)
	return true


func _sample_body() -> Array[PackedVector2Array]:
	var circle := PackedVector2Array()
	for i in range(33):
		circle.append(Vector2(260, 260) + Vector2.RIGHT.rotated(TAU * i / 32) * 150.0)
	var spikes: Array[PackedVector2Array] = [circle]
	for i in range(6):
		var direction := Vector2.RIGHT.rotated(TAU * i / 6)
		spikes.append(PackedVector2Array([Vector2(260, 260) + direction * 150.0, Vector2(260, 260) + direction * 200.0]))
	return spikes


func _sample_weapon() -> Array[PackedVector2Array]:
	var line := PackedVector2Array()
	for i in range(21):
		line.append(Vector2(20 + i * 22, 250))
	return [line]
