extends SceneTree
## 入力なしでゲームを数秒間走らせ、敵が波で出て拠点を攻撃するところまでを確認する。
##   godot --headless --path . -s res://tests/simulate.gd
## 拠点がダメージを受けなければ終了コード 1。

const SECONDS := 30.0
const INPUT_SETUP := "res://src/game/input_setup.gd"
const MAIN_SCENE := "res://src/game/main.tscn"

var _started := false
var _elapsed := 0.0
var _main: Node
var _max_enemies := 0


func _process(delta: float) -> bool:
	if not _started:
		_started = true
		var input_setup := (load(INPUT_SETUP) as GDScript).new() as Node
		root.add_child(input_setup)
		_main = (load(MAIN_SCENE) as PackedScene).instantiate()
		root.add_child(_main)
		return false
	_elapsed += delta
	_max_enemies = maxi(_max_enemies, _main.get_node("Enemies").get_child_count())
	if _elapsed < SECONDS:
		return false
	var core: Core = _main.get_node("Core")
	var waves: WaveManager = _main.get_node("WaveManager")
	print("経過 %.1f 秒  ウェーブ %d  同時最大敵数 %d  拠点 HP %.0f / %.0f" % [
		_elapsed, waves.wave, _max_enemies, core.hp, core.max_hp])
	var ok := waves.wave >= 1 and _max_enemies >= 1 and core.hp < core.max_hp
	if not ok:
		printerr("敵が拠点を攻撃していません")
	quit(0 if ok else 1)
	return true
