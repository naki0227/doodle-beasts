class_name Blackboard
extends RefCounted
## ビヘイビアツリーの各ノードが共有する読み書き可能なデータ置き場。
## 「いま狙っている相手」「最後に見た位置」など、ノードをまたいで引き継ぐ値を入れる。

var _data: Dictionary = {}


func set_value(key: StringName, value: Variant) -> void:
	_data[key] = value


func get_value(key: StringName, default: Variant = null) -> Variant:
	return _data.get(key, default)


func has_value(key: StringName) -> bool:
	return _data.has(key)


func erase_value(key: StringName) -> void:
	_data.erase(key)


func clear() -> void:
	_data.clear()
