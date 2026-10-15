extends Node2D
## 演出（飛び散り・擬音・ダメージ数字・矢）を置く場所。Fx がこのグループを探して使う。


func _ready() -> void:
	add_to_group(&"fx_layer")
