extends SceneTree
## ヘッドレスのテスト実行器。
##   godot --headless --path . -s res://tests/run_tests.gd
## 失敗があれば終了コード 1。
## テスト関数の途中で起きたスクリプトエラーはここから見えない（関数が止まるだけ）。
## CI では出力の SCRIPT ERROR も失敗として扱う。

const TEST_SCRIPTS: Array[String] = [
	"res://tests/test_blackboard.gd",
	"res://tests/test_bt_composites.gd",
	"res://tests/test_bt_decorators.gd",
	"res://tests/test_ai_leaves.gd",
	"res://tests/test_enemy_tree.gd",
	"res://tests/test_wave_manager.gd",
	"res://tests/test_shape_analyzer.gd",
	"res://tests/test_beast.gd",
	"res://tests/test_behavior.gd",
]


var _started := false


## ルート Window がツリーに入るのは最初のフレーム以降なので、_init ではなくここで走らせる。
func _process(_delta: float) -> bool:
	if _started:
		return true
	_started = true
	_run_all()
	return true


func _run_all() -> void:
	var total := 0
	var failures := 0
	for path in TEST_SCRIPTS:
		var script := load(path) as GDScript
		if script == null:
			printerr("読み込めません: %s" % path)
			failures += 1
			continue
		for method in script.get_script_method_list():
			var name: String = method["name"]
			if not name.begins_with("test_"):
				continue
			total += 1
			var case := script.new() as GameTestCase
			case.tree = self
			case.setup()
			case.call(name)
			case.teardown()
			if case.failed:
				failures += 1
				printerr("FAIL  %s::%s" % [path.get_file(), name])
				for message in case.messages:
					printerr("      %s" % message)
			else:
				print("ok    %s::%s" % [path.get_file(), name])
	print("")
	print("%d tests, %d failed" % [total, failures])
	quit(1 if failures > 0 else 0)
