extends Node2D
## 演出を置く場所。Fx がこのグループを探して使う。
## group_name が fx_layer なら世界の中（ピクセル化される）、fx_text_layer なら文字用（くっきり）。

@export var group_name: StringName = &"fx_layer"


func _ready() -> void:
	add_to_group(group_name)
