extends SceneTree
## すべての .gd と .tscn を読み込み、構文エラーや読み込み失敗がないか確かめる。
##   godot --headless --path . -s res://tests/check_scripts.gd


func _initialize() -> void:
	var failures := 0
	var count := 0
	for path in _collect("res://src") + _collect("res://tests"):
		if not (path.ends_with(".gd") or path.ends_with(".tscn")):
			continue
		count += 1
		var resource := load(path)
		if resource == null:
			printerr("読み込めない: %s" % path)
			failures += 1
		elif resource is GDScript and not (resource as GDScript).can_instantiate():
			printerr("コンパイルできない: %s" % path)
			failures += 1
	print("%d ファイル確認、%d 件失敗" % [count, failures])
	quit(1 if failures > 0 else 0)


func _collect(dir_path: String) -> Array[String]:
	var result: Array[String] = []
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return result
	for file in dir.get_files():
		result.append(dir_path.path_join(file))
	for sub in dir.get_directories():
		result.append_array(_collect(dir_path.path_join(sub)))
	return result
