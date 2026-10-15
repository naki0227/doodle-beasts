extends Node2D
## タイトル画面の描画を、持ち主（title.gd）に任せる小さなノード。

var title_screen: Node
@export var method_name: StringName = &"draw_text_layer"


func _draw() -> void:
	if title_screen != null:
		title_screen.call(method_name, self)
