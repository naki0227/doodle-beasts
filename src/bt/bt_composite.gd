class_name BTComposite
extends BTNode
## 複数の子を持つノード（Sequence / Selector）の共通部分。
##
## [member remember_running] が false のときは毎回先頭の子から評価し直す（反応型）。
## 先に並べた「優先度の高い枝」が成立した瞬間に、後ろの枝の途中状態は捨てられる。
## true のときは RUNNING だった子から再開する（手順を最後までやり切らせたい場合向け）。

@export var remember_running: bool = false

var _running_index: int = -1


func _reset() -> void:
	_running_index = -1


func _start_index() -> int:
	if remember_running and _running_index >= 0:
		return _running_index
	return 0


## 子 index が RUNNING になった。以前 RUNNING だった別の子は途中状態を捨てる。
func _mark_running(children: Array[BTNode], index: int) -> void:
	if _running_index >= 0 and _running_index != index and _running_index < children.size():
		children[_running_index].reset()
	_running_index = index


## この評価で結論が出た。RUNNING だった子の途中状態を捨てる。
func _finish(children: Array[BTNode]) -> void:
	if _running_index >= 0 and _running_index < children.size():
		children[_running_index].reset()
	_running_index = -1
